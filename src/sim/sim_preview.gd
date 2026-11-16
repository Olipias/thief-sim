class_name SimPreview
extends RefCounted
## R-02 确定性路线预演灰盒：固定 tick 纯状态转换模拟内核（不依赖渲染帧率）。
##
## 设计约束（docs/DETERMINISTIC_PREVIEW.md）：
##   - 所有状态以整数 tick 推进；巡逻/监控/噪音/发现判定共用同一份内核。
##   - 预演（simulate_route）只修改快照副本；执行（execute_route）从同一快照跑出逐 tick 轨迹。
##   - 同快照 + 同路线 + 同动作 → 逐 tick 状态摘要、事件顺序、首次发现 tick 完全一致（无随机数）。
##   - 失败恢复：restore_full(snapshot) 还原整份起始快照并保留原路线，不清路线、不扣命。
##
## 灰盒范围：一个矩形房间；一名按路点巡逻的保安（walk -> wait 循环，确定时长）；
## 一台周期摆动的监控摄像头；一扇锁门（需解锁动作 tick 数）；一件目标（拿取动作 tick 数）。
## 玩家动作时间轴：路径节点列表 [ {pos: Vector2i, action: "wait"/"crouch"/"unlock"/"take", ticks: int} ]。

const TICK_RATE := 20  # 20 tick/s（灰盒验证频率；只增不改，一致性以 tick 为单位）

## ---------- 状态结构（全部可序列化，快照 = dict 深拷贝） ----------

static func default_snapshot() -> Dictionary:
	return {
		"tick": 0,
		"player": {
			"pos": Vector2i(1, 1),
			"crouch": false,
			"unlock_progress": 0,
			"take_progress": 0,
			"carrying": false,
		},
		"guard": {
			"pos": Vector2i(2, 2),
			"waypoints": [Vector2i(2, 2), Vector2i(12, 2), Vector2i(12, 9), Vector2i(2, 9)],
			"wp_index": 0,
			"move_phase": 0,       # 向下一个路点已移动的格数
			"wait_left": 2,        # 路点停留剩余 tick（GUARD_WAIT_TICKS 起始）
			"facing": Vector2i(1, 0),
			"investigate_pos": Vector2i(-1, -1),  # 噪音调查目标（-1 = 无）
			"investigate_left": 0,
			"alert": 0,            # 0 巡逻 1 调查 2 追击/发现
		},
		"camera": {
			"pivot": Vector2i(13, 1),
			"phase": 0,            # 摆动相位（tick 累加）
			"period": 120,         # 6 秒一个来回（20 tick/s）
		},
		"door_locked": true,
		"target_taken": false,
		"noise": [],           # [{pos, radius, left, source}] 逐 tick 衰减
		"events": [],          # [{tick, kind, detail}] 全局事件流水（快照包含，保证一致性）
	}

## 恒定参数（不进快照：属于规则，不属于状态）
const GUARD_WAIT_TICKS := 40          # 每个路点停留 2 秒
const GUARD_INVESTIGATE_TICKS := 60   # 调查停留 3 秒
const GUARD_ALERT_RANGE := 4          # 发现玩家距离（格；无视锥简化为圆形范围，灰盒阶段）
const GUARD_NOISE_RANGE := 6          # 噪音吸引调查距离
const CAMERA_RANGE := 5               # 监控覆盖距离（格）
const CAMERA_CONE_HALF_TICKS := 30    # 半摆幅 1.5 秒（简化：扇区角随相位扫动，灰盒用距离+相位判定）
const NOISE_LIFETIME_TICKS := 20      # 噪音持续 1 秒
const UNLOCK_TICKS := 40              # 开锁耗时 2 秒（蹲/立同速，灰盒不区分）
const TAKE_TICKS := 20                # 拿取耗时 1 秒
const DOOR_POS := Vector2i(14, 9)
const TARGET_POS := Vector2i(13, 8)
const ROOM_MIN := Vector2i(0, 0)
const ROOM_MAX := Vector2i(14, 10)    # 包含边界（房间 15×11 格）

## ---------- 快照与一致性工具 ----------

static func copy_snapshot(snap: Dictionary) -> Dictionary:
	var out := {}
	for key in snap:
		var value = snap[key]
		if value is Dictionary:
			out[key] = copy_snapshot(value)
		elif value is Array:
			var arr := []
			for item in value:
				if item is Dictionary:
					arr.append(copy_snapshot(item))
				elif item is Array:
					var inner := []
					for sub in item:
						inner.append(sub)
					arr.append(inner)
				else:
					arr.append(item)
			out[key] = arr
		else:
			out[key] = value
	return out


static func snapshot_summary(snap: Dictionary) -> String:
	var g: Dictionary = snap["guard"]
	var p: Dictionary = snap["player"]
	var noise_sig := ""
	for n in snap.get("noise", []):
		noise_sig += "%s/%s/%s;" % [str(n.get("pos")), str(n.get("radius")), str(n.get("left"))]
	return "t=%s|p=%s,%s,u=%s,k=%s|g=%s,w=%s,f=%s,a=%s,i=%s|c.ph=%s|d=%s|n=%s" % [
		str(snap.get("tick")), str(p.get("pos")), str(p.get("crouch")), str(p.get("unlock_progress")), str(p.get("carrying")),
		str(g.get("pos")), str(g.get("wp_index")), str(g.get("facing")), str(g.get("alert")), str(g.get("investigate_pos")),
		str(cam_phase(snap)), str(snap.get("door_locked")), noise_sig,
	]


static func cam_phase(snap: Dictionary) -> String:
	var cam = snap.get("camera", {})
	return str(cam.get("phase", -1))


## ---------- 路径工具（格坐标直线，逐格推进） ----------

static func step_towards(from: Vector2i, to: Vector2i) -> Vector2i:
	var dx := to.x - from.x
	var dy := to.y - from.y
	if dx == 0 and dy == 0:
		return from
	if absi(dx) >= absi(dy):
		return from + Vector2i(1 if dx > 0 else -1, 0)
	return from + Vector2i(0, 1 if dy > 0 else -1)


static func route_distance(from: Vector2i, to: Vector2i) -> int:
	return absi(to.x - from.x) + absi(to.y - from.y)

## ---------- 核心单 tick 状态转换（预演与执行共用） ----------

## route: Array[Dictionary] 节点 {pos: Vector2i, action: String, ticks: int}
## 返回值与修改方式：内核直接在传入快照上推进 1 tick；事件追加到 snap["events"]。
static func tick(snap: Dictionary, route: Array, route_index_ref: Dictionary) -> void:
	snap["tick"] = int(snap["tick"]) + 1
	var p: Dictionary = snap["player"]
	var g: Dictionary = snap["guard"]
	var cam: Dictionary = snap["camera"]

	# 1) 监控摆动相位推进（与渲染无关）
	cam["phase"] = int(cam["phase"]) + 1

	# 2) 噪音衰减
	var alive_noise: Array = []
	for n in snap["noise"]:
		n["left"] = int(n["left"]) - 1
		if int(n["left"]) > 0:
			alive_noise.append(n)
	snap["noise"] = alive_noise

	# 3) 玩家动作时间轴：先处理节点上的持续动作，再走格子
	# node 是 route 里的字典引用；"done"/"pos" 都原地更新（执行时供调用方读取进度）。
	# 注意：route 节点的 "pos" 在 tick 内被归一化为 Vector2i —— 调用方传入的字典会被写回，
	# 因此 route 数组由调用方持有副本（simulate_route/execute_route 均先拷贝 route）。
	var node := {}
	if route_index_ref["i"] < route.size():
		var raw_node = route[route_index_ref["i"]]
		node = raw_node.duplicate() if raw_node is Dictionary else {}
		route[route_index_ref["i"]] = node

	if not node.is_empty():
		var node_pos = node.get("pos", p["pos"])
		var node_at: Vector2i = node_pos if node_pos is Vector2i else Vector2i(node_pos["x"], node_pos["y"])
		node["pos"] = node_at
	if not node.is_empty() and p["pos"] == node["pos"]:
		# 到达当前节点：执行节点动作（wait / crouch / unlock / take）
		var action := String(node.get("action", ""))
		var left := int(node.get("ticks", 0)) - int(node.get("done", 0))
		match action:
			"unlock":
				if snap["door_locked"]:
					p["unlock_progress"] = int(p["unlock_progress"]) + 1
					if int(p["unlock_progress"]) >= UNLOCK_TICKS:
						snap["door_locked"] = false
						snap["events"].append({"tick": snap["tick"], "kind": "door_unlocked", "detail": "node"})
					node["done"] = int(node.get("done", 0)) + 1
				else:
					node["done"] = left
			"take":
				if not snap["target_taken"] and p["pos"] == TARGET_POS:
					p["take_progress"] = int(p["take_progress"]) + 1
					if int(p["take_progress"]) >= TAKE_TICKS:
						snap["target_taken"] = true
						p["carrying"] = true
						snap["events"].append({"tick": snap["tick"], "kind": "target_taken", "detail": "node"})
					node["done"] = int(node.get("done", 0)) + 1
				else:
					node["done"] = left
			"wait":
				node["done"] = int(node.get("done", 0)) + 1
				if int(node.get("done", 0)) >= int(node.get("ticks", 1)):
					route_index_ref["i"] = int(route_index_ref["i"]) + 1
			"crouch":
				p["crouch"] = true
				node["done"] = int(node.get("done", 0)) + 1
				if int(node.get("done", 0)) >= int(node.get("ticks", 1)):
					route_index_ref["i"] = int(route_index_ref["i"]) + 1
			_:
				route_index_ref["i"] = int(route_index_ref["i"]) + 1
		# 动作完成后推进到下一节点
		if action != "" and int(node.get("done", 0)) >= int(node.get("ticks", 1)) and action != "unlock":
			if route_index_ref["i"] < route.size():
				pass
		if action == "unlock" and not snap["door_locked"]:
			route_index_ref["i"] = int(route_index_ref["i"]) + 1
	elif not node.is_empty():
		# 未到达节点：按曼哈顿逐格走向节点（蹲行速度 = 立走，灰盒不区分格速）
		p["pos"] = step_towards(p["pos"], node["pos"])
		p["crouch"] = String(node.get("action", "")) == "crouch"

	# 4) 保安 AI（巡逻 → 噪音调查 → 发现判定）
	if int(g["alert"]) < 2:
		# 调查优先：有噪音在范围内 → 面向噪音源移动并停留
		var noise_target := Vector2i(-1, -1)
		var noise_best := INF
		for n in snap["noise"]:
			var npos: Vector2i = n["pos"] if n["pos"] is Vector2i else Vector2i(n["pos"]["x"], n["pos"]["y"])
			var dist: int = route_distance(g["pos"], npos)
			if dist <= GUARD_NOISE_RANGE and dist < noise_best:
				noise_best = dist
				noise_target = npos
		if noise_target.x >= 0:
			if g["investigate_pos"] != noise_target:
				g["investigate_pos"] = noise_target
				g["investigate_left"] = GUARD_INVESTIGATE_TICKS
				g["alert"] = 1
				snap["events"].append({"tick": snap["tick"], "kind": "guard_investigate", "detail": noise_target})
			g["investigate_left"] = int(g["investigate_left"]) - 1
			if route_distance(g["pos"], noise_target) > 0:
				g["pos"] = step_towards(g["pos"], noise_target)
			# 调查完或噪音消失即回巡逻
			if int(g["investigate_left"]) <= 0 and noise_best > GUARD_NOISE_RANGE:
				g["investigate_pos"] = Vector2i(-1, -1)
				g["alert"] = 0
		else:
			# 正常巡逻：walk -> wait 循环（路点以 x/y 平铺存储，避免类型歧义）
			var wps: Array = g["waypoints"]
			var gpos: Vector2i = g["pos"] if g["pos"] is Vector2i else Vector2i(int(g["pos"]["x"]), int(g["pos"]["y"]))
			var gpos_x: int = gpos.x
			var gpos_y: int = gpos.y
			var wpx: int = int(wps[int(g["wp_index"])].x)
			var wpy: int = int(wps[int(g["wp_index"])].y)
			if int(g["wait_left"]) > 0:
				g["wait_left"] = int(g["wait_left"]) - 1
			elif gpos_x != wpx or gpos_y != wpy:
				var dx := wpx - gpos_x
				var dy := wpy - gpos_y
				var step_x := 0
				var step_y := 0
				if absi(dx) >= absi(dy):
					step_x = 1 if dx > 0 else -1
				else:
					step_y = 1 if dy > 0 else -1
				g["pos"] = Vector2i(gpos_x + step_x, gpos_y + step_y)
				g["facing"] = Vector2i(step_x, step_y)
				g["move_phase"] = int(g["move_phase"]) + 1
			else:
				g["wp_index"] = (int(g["wp_index"]) + 1) % wps.size()
				g["wait_left"] = GUARD_WAIT_TICKS

	# 5) 发现判定（确定性：距离 + （玩家蹲下则半径 -1）），先守卫后监控
	var detected_by := ""
	var guard_range := GUARD_ALERT_RANGE - (1 if bool(p["crouch"]) else 0)
	if route_distance(g["pos"], p["pos"]) <= guard_range:
		detected_by = "guard"
	elif _camera_sees_player(snap):
		detected_by = "camera"
	if detected_by != "":
		g["alert"] = 2
		snap["events"].append({
			"tick": snap["tick"], "kind": "spotted",
			"detail": detected_by, "pos": p["pos"],
		})


static func _camera_sees_player(snap: Dictionary) -> bool:
	var cam: Dictionary = snap["camera"]
	var p: Dictionary = snap["player"]
	var pivot: Vector2i = cam["pivot"] if cam["pivot"] is Vector2i else Vector2i(cam["pivot"]["x"], cam["pivot"]["y"])
	var ppos: Vector2i = p["pos"] if p["pos"] is Vector2i else Vector2i(p["pos"]["x"], p["pos"]["y"])
	var dist := route_distance(pivot, ppos)
	if dist > CAMERA_RANGE:
		return false
	# 灰盒扇区：相位驱动左右半场扫描（0..period/2 扫右半，之后扫左半）
	var half := int(cam["period"]) / 2
	var sweeping_right := int(cam["phase"]) % int(cam["period"]) < half
	var in_right_half: bool = ppos.x >= pivot.x
	return sweeping_right == in_right_half

## ---------- 高层接口：预演 / 执行 / 失败恢复 ----------

## 预演：在快照副本上跑完整路线，返回 {snapshot(最终), trace(逐tick摘要), events, first_spotted}
static func simulate_route(snapshot: Dictionary, route: Array, max_ticks := 1200) -> Dictionary:
	var snap := copy_snapshot(snapshot)
	var copied_route: Array = route.duplicate(true)
	var idx := {"i": 0}
	var trace: Array[String] = []
	var first_spotted := -1
	var events := []
	while int(snap["tick"]) < max_ticks:
		tick(snap, copied_route, idx)
		trace.append(snapshot_summary(snap))
		for e in snap["events"]:
			if int(e["tick"]) == int(snap["tick"]) and not events.has(e):
				events.append(e)
			if String(e["kind"]) == "spotted" and first_spotted == -1:
				first_spotted = int(e["tick"])
		if first_spotted != -1:
			break
	return {"snapshot": snap, "trace": trace, "events": events, "first_spotted": first_spotted}

## 执行：从同一起始快照开始，逐 tick 推进（供真实游戏帧读取渲染）。
## 行为与 simulate_route 完全一致（同一 tick 函数），返回逐步状态流以便逐 tick 对比。
static func execute_route(snapshot: Dictionary, route: Array, max_ticks := 1200) -> Dictionary:
	var snap := copy_snapshot(snapshot)
	var copied_route: Array = route.duplicate(true)
	var idx := {"i": 0}
	var trace: Array[String] = []
	var events := []
	var first_spotted := -1
	while int(snap["tick"]) < max_ticks:
		tick(snap, copied_route, idx)
		trace.append(snapshot_summary(snap))
		for e in snap["events"]:
			if int(e["tick"]) == int(snap["tick"]) and not events.has(e):
				events.append(e)
			if String(e["kind"]) == "spotted" and first_spotted == -1:
				first_spotted = int(e["tick"])
		if first_spotted != -1:
			break
	return {"snapshot": snap, "trace": trace, "events": events, "first_spotted": first_spotted}

## 失败恢复：完整还原起始快照（路线由调用方保留），不清路线、不扣命。
static func restore_full(snapshot: Dictionary, state_target: Dictionary) -> void:
	var restored := copy_snapshot(snapshot)
	for key in restored:
		state_target[key] = restored[key]
