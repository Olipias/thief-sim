class_name SimPreview
extends RefCounted
## R-02b 确定性路线预演内核：固定 tick 纯状态转换，支持多守卫/多监控/全快照。


##
## 设计约束（docs/DETERMINISTIC_PREVIEW.md + docs/OPENCODE_NEXT_PLAN.md §A）：
##   - 所有状态以整数 tick 推进；巡逻/调查/监控/动作/噪音/发现共用同一份内核。
##   - 预演（simulate_route）只修改快照副本；执行从同一快照跑出逐 tick 轨迹。
##   - 同快照 + 同路线 + 同动作 → 逐 tick 状态摘要、事件顺序、首次发现 tick、触发实体 ID 与原因一致。
##   - 失败恢复：restore_full(snapshot) 还原整份起始快照并保留原路线，不清路线、不扣命。
##
## 状态全部用可序列化的 Variant（Vector2i/Vector2/int/bool/Array/Dictionary）表示；
## 快照 = dict 深拷贝。渲染层只读取快照，不决定模拟。

const TICK_RATE := 20  # 20 tick/s（固定；一致性以 tick 为单位）
const SECONDS_PER_TICK := 1.0 / TICK_RATE

## ---------- 恒定规则参数（不进快照） ----------

const GUARD_WAIT_TICKS := 40          # 每个路点停留 2 秒
const GUARD_INVESTIGATE_TICKS := 60   # 调查停留 3 秒
const GUARD_ALERT_RANGE_CELLS := 4    # 发现玩家距离（格；蹲下 -1）
const GUARD_NOISE_RANGE_CELLS := 6    # 噪音吸引调查距离（格）
const CAMERA_RANGE_CELLS := 7         # 监控覆盖距离（格）= 112px / 16
const CAMERA_HALF_ANGLE := deg_to_rad(42.0)
const NOISE_LIFETIME_TICKS := 20      # 噪音持续 1 秒
const UNLOCK_TICKS := 40              # 开锁耗时 2 秒
const TAKE_TICKS := 20                # 拿取耗时 1 秒
const SPOT_DELAY_TICKS := 10          # 0.5 秒发现延迟
const INVESTIGATE_SPOT_MULTIPLIER := 1.5
const CATCH_DISTANCE_CELLS := 1       # 近身抓获距离（格，≈11px）

## 灰盒默认值：1 tick / cell，保证旧测试的步进节奏不变
const PLAYER_WALK_INTERVAL := 1
const PLAYER_CROUCH_INTERVAL := 1
const PLAYER_SPRINT_INTERVAL := 1
const GUARD_PATROL_INTERVAL := 1
const GUARD_INVESTIGATE_INTERVAL := 1
const GUARD_CHASE_INTERVAL := 1

## 灰盒默认坐标（旧单守卫/单摄像头测试用）
const DOOR_POS := Vector2i(14, 9)
const TARGET_POS := Vector2i(13, 8)
const ROOM_MIN := Vector2i(0, 0)
const ROOM_MAX := Vector2i(14, 10)


## ---------- 快照工厂 ----------

static func default_snapshot() -> Dictionary:
	return {
		"tick": 0,
		"decor_time": 0.0,
		"player": {
			"pos": Vector2i(1, 1),
			"crouch": false,
			"unlock_progress": 0,
			"take_progress": 0,
			"carrying": false,
			"move_interval": PLAYER_WALK_INTERVAL,
			"move_counter": 0,
			"crouch_move_interval": PLAYER_CROUCH_INTERVAL,
			"sprint_move_interval": PLAYER_SPRINT_INTERVAL,
		},
		"guards": [{
			"id": "guard",
			"pos": Vector2i(2, 2),
			"waypoints": [Vector2i(2, 2), Vector2i(12, 2), Vector2i(12, 9), Vector2i(2, 9)],
			"wp_index": 0,
			"move_interval": GUARD_PATROL_INTERVAL,
			"move_counter": 0,
			"wait_left": GUARD_WAIT_TICKS,
			"facing": Vector2i(1, 0),
			"investigate_pos": Vector2i(-1, -1),
			"investigate_left": 0,
			"alert": 0,
			"spot_timer": 0,
			"spot_delay": SPOT_DELAY_TICKS,
			"blind_timer": 0,
			"ai_enabled": true,
		}],
		"cameras": [{
			"id": "camera",
			"pos": Vector2i(13, 1),
			"phase": 0.0,
			"sweep_speed": 0.5 * SECONDS_PER_TICK,
			"sweep_amp": 0.35,
			"range_cells": CAMERA_RANGE_CELLS,
			"half_angle": CAMERA_HALF_ANGLE,
		}],
		"doors": {},  # Vector2i -> bool (locked)
		"items": [{"id": "target", "pos": TARGET_POS, "taken": false}],
		"bag_items": [],
		"smoke_count": 0,
		"smoke_puffs": [],
		"noise": [],
		"events": [],
	}


## ---------- 深拷贝（快照复制） ----------

static func copy_snapshot(snap: Dictionary) -> Dictionary:
	var out := {}
	for key in snap:
		out[key] = _copy_value(snap[key])
	return out


static func _copy_value(value: Variant) -> Variant:
	if value is Dictionary:
		var d := {}
		for k in value:
			d[k] = _copy_value(value[k])
		return d
	if value is Array:
		var a := []
		for item in value:
			a.append(_copy_value(item))
		return a
	return value


## ---------- 摘要与调试 ----------

static func snapshot_summary(snap: Dictionary) -> String:
	var parts: Array[String] = ["t=%d" % int(snap.get("tick", 0))]
	var p: Dictionary = snap.get("player", {})
	parts.append("p=%s,c=%s,carry=%s" % [str(p.get("pos")), str(p.get("crouch")), str(p.get("carrying"))])
	var guard_parts: Array[String] = []
	for g in snap.get("guards", []):
		guard_parts.append("%s:%s:%s:%s:%s:%s:%s:%s:%s" % [
			str(g.get("id")), str(g.get("pos")), str(g.get("wp_index")),
			str(g.get("facing")), str(g.get("alert")), str(g.get("wait_left")),
			str(g.get("spot_timer")), str(g.get("investigate_left")), str(g.get("blind_timer"))
		])
	parts.append("g=[" + ",".join(guard_parts) + "]")
	var cam_parts: Array[String] = []
	for c in snap.get("cameras", []):
		var rot := sin(float(c.get("phase", 0.0))) * float(c.get("sweep_amp", 0.35))
		cam_parts.append("%s:%s:%.3f" % [str(c.get("id")), str(c.get("pos")), rot])
	parts.append("c=[" + ",".join(cam_parts) + "]")
	parts.append("d=%s" % str(snap.get("doors", {})))
	parts.append("i=%s" % str(snap.get("items", [])))
	var noise_sig := ""
	for n in snap.get("noise", []):
		noise_sig += "%s/%s/%s;" % [str(n.get("pos")), str(n.get("radius_cells")), str(n.get("left"))]
	parts.append("n=%s" % noise_sig)
	return "|".join(parts)


## ---------- 路径工具 ----------

static func step_towards(from: Vector2i, to: Vector2i) -> Vector2i:
	var dx := to.x - from.x
	var dy := to.y - from.y
	if dx == 0 and dy == 0:
		return from
	if absi(dx) >= absi(dy):
		return from + Vector2i(1 if dx > 0 else -1, 0)
	return from + Vector2i(0, 1 if dy > 0 else -1)


static func route_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func in_cone(origin: Vector2, facing: Vector2, target: Vector2, range_px: float, half_angle: float) -> bool:
	var to_target := target - origin
	if to_target.length_squared() > range_px * range_px:
		return false
	if facing == Vector2.ZERO:
		return false
	return absf(facing.angle_to(to_target)) <= half_angle


static func _cell_center_px(cell: Vector2i, tile: int) -> Vector2:
	return Vector2(cell.x * tile + tile * 0.5, cell.y * tile + tile * 0.5)


## ---------- 核心单 tick 状态转换 ----------

## context 可含：
##   - "los_blocked": Callable(from_cell: Vector2i, to_cell: Vector2i) -> bool
##   - "same_room": Callable(a_cell: Vector2i, b_cell: Vector2i) -> bool
static func tick(snap: Dictionary, route: Array, route_index_ref: Dictionary, context: Dictionary = {}) -> void:
	snap["tick"] = int(snap["tick"]) + 1
	snap["decor_time"] = float(snap.get("decor_time", 0.0)) + SECONDS_PER_TICK

	# 1) 噪音衰减
	var alive_noise: Array = []
	for n in snap["noise"]:
		n["left"] = int(n["left"]) - 1
		if int(n["left"]) > 0:
			alive_noise.append(n)
	snap["noise"] = alive_noise

	# 2) 玩家动作时间轴
	_tick_player(snap, route, route_index_ref, context)

	# 3) 守卫 AI 与发现判定
	for g in snap["guards"]:
		_tick_guard(g, snap, context)

	# 4) 监控摄像头
	for c in snap["cameras"]:
		_tick_camera(c, snap, context)

	# 5) 烟雾 puff 计时
	for puff in snap["smoke_puffs"]:
		puff["time"] = float(puff.get("time", 0.0)) + SECONDS_PER_TICK
	var alive_puffs: Array = []
	for puff in snap["smoke_puffs"]:
		if float(puff.get("time", 0.0)) < 0.9:
			alive_puffs.append(puff)
	snap["smoke_puffs"] = alive_puffs


static func _signi(v: int) -> int:
	return 1 if v > 0 else (-1 if v < 0 else 0)


static func _tick_player(snap: Dictionary, route: Array, route_index_ref: Dictionary, context: Dictionary = {}) -> void:
	var p: Dictionary = snap["player"]
	var node := {}
	var idx: int = int(route_index_ref.get("i", 0))
	if idx < route.size():
		var raw_node = route[idx]
		node = raw_node.duplicate() if raw_node is Dictionary else {}
		route[idx] = node

	if not node.is_empty():
		var node_pos = node.get("pos", p["pos"])
		var node_at: Vector2i = node_pos if node_pos is Vector2i else Vector2i(int(node_pos["x"]), int(node_pos["y"]))
		node["pos"] = node_at

	if not node.is_empty() and Vector2i(p["pos"]) == Vector2i(node["pos"]):
		# 到达当前节点：执行动作
		var action := String(node.get("action", ""))
		var ticks := int(node.get("ticks", 0))
		var done := int(node.get("done", 0))
		match action:
			"unlock":
				var doors: Dictionary = snap.get("doors", {})
				var cell := Vector2i(p["pos"])
				if doors.has(cell) and bool(doors[cell]):
					p["unlock_progress"] = int(p["unlock_progress"]) + 1
					if int(p["unlock_progress"]) >= UNLOCK_TICKS:
						doors[cell] = false
						snap["events"].append({"tick": snap["tick"], "kind": "door_unlocked", "detail": str(cell)})
				node["done"] = done + 1
				if not bool(doors.get(cell, false)):
					route_index_ref["i"] = idx + 1
			"take":
				var cell := Vector2i(p["pos"])
				var target_id := ""
				if p.get("take_target_id", "") != "":
					target_id = String(p["take_target_id"])
				else:
					for item in snap["items"]:
						if not bool(item.get("taken", false)) and Vector2i(item.get("pos", Vector2i.ZERO)) == cell:
							target_id = String(item.get("id", ""))
							p["take_target_id"] = target_id
							break
				if target_id != "":
					p["take_progress"] = int(p["take_progress"]) + 1
					if int(p["take_progress"]) >= TAKE_TICKS:
						for item in snap["items"]:
							if String(item.get("id", "")) == target_id:
								item["taken"] = true
								break
						p["carrying"] = true
						p["take_target_id"] = ""
						p["take_progress"] = 0
						snap["events"].append({"tick": snap["tick"], "kind": "target_taken", "detail": target_id})
				else:
					p["take_progress"] = 0
				node["done"] = done + 1
				if p["take_progress"] == 0 and target_id != "":
					route_index_ref["i"] = idx + 1
			"wait", "":
				p["crouch"] = false
				node["done"] = done + 1
				if done + 1 >= ticks:
					route_index_ref["i"] = idx + 1
			"crouch":
				p["crouch"] = true
				node["done"] = done + 1
				if done + 1 >= ticks:
					route_index_ref["i"] = idx + 1
			"stand":
				p["crouch"] = false
				node["done"] = done + 1
				if done + 1 >= ticks:
					route_index_ref["i"] = idx + 1
			"sprint":
				p["crouch"] = false
				node["done"] = done + 1
				if done + 1 >= ticks:
					route_index_ref["i"] = idx + 1
			_:
				route_index_ref["i"] = idx + 1
	else:
		# 未到达节点：按当前动作决定移速与姿态，逐格前进
		var action := "" if node.is_empty() else String(node.get("action", ""))
		var interval: int = int(p.get("move_interval", PLAYER_WALK_INTERVAL))
		match action:
			"crouch":
				interval = int(p.get("crouch_move_interval", PLAYER_CROUCH_INTERVAL))
				p["crouch"] = true
			"sprint":
				interval = int(p.get("sprint_move_interval", PLAYER_SPRINT_INTERVAL))
				p["crouch"] = false
			_:
				p["crouch"] = false
		p["move_counter"] = int(p.get("move_counter", 0)) - 1
		if int(p["move_counter"]) <= 0:
			var target: Vector2i = Vector2i(node.get("pos", p["pos"])) if not node.is_empty() else Vector2i(p["pos"])
			var current: Vector2i = Vector2i(p["pos"])
			var next := step_towards(current, target)
			var blocked_cb: Callable = context.get("is_cell_blocked", Callable())
			if blocked_cb.is_valid() and next != current and blocked_cb.call(next):
				var dx := _signi(target.x - current.x)
				var dy := _signi(target.y - current.y)
				var alt_x := current + Vector2i(dx, 0)
				var alt_y := current + Vector2i(0, dy)
				if dx != 0 and not blocked_cb.call(alt_x):
					next = alt_x
				elif dy != 0 and not blocked_cb.call(alt_y):
					next = alt_y
				else:
					next = current
			p["pos"] = next
			p["move_counter"] = maxi(1, interval)
			if action == "sprint" and next != current:
				# 疾跑脚步声：每移动一格产生一次噪音（寿命 1 秒）
				snap["noise"].append({
					"pos": Vector2i(p["pos"]),
					"radius_cells": 4,
					"left": NOISE_LIFETIME_TICKS,
					"source": "sprint",
				})


static func _tick_guard(g: Dictionary, snap: Dictionary, context: Dictionary) -> void:
	var p: Dictionary = snap["player"]

	# 致盲
	if int(g.get("blind_timer", 0)) > 0:
		g["blind_timer"] = int(g["blind_timer"]) - 1
		if int(g.get("alert", 0)) != 0:
			g["alert"] = 0
			g["investigate_pos"] = Vector2i(-1, -1)
			g["investigate_left"] = 0
			g["spot_timer"] = 0
		return

	var spotted_now := false
	if _guard_sees_player(g, p, context):
		var mul := 1.0
		if int(g.get("alert", 0)) == 1:
			mul = INVESTIGATE_SPOT_MULTIPLIER
		g["spot_timer"] = float(g.get("spot_timer", 0.0)) + mul
		if float(g.get("spot_timer", 0.0)) >= float(g.get("spot_delay", SPOT_DELAY_TICKS)):
			spotted_now = true
	else:
		g["spot_timer"] = maxf(0.0, float(g.get("spot_timer", 0.0)) - 1.0)

	if spotted_now:
		g["alert"] = 2
		var reason := _guard_spot_reason(g)
		snap["events"].append({
			"tick": snap["tick"],
			"kind": "spotted",
			"detail": "guard",
			"id": str(g.get("id", "")),
			"pos": Vector2i(p["pos"]),
			"reason": reason,
		})
		return

	# 调查
	if int(g.get("alert", 0)) < 2:
		var noise_target := _nearest_noise(g, snap)
		if noise_target.x >= 0:
			if Vector2i(g.get("investigate_pos", Vector2i(-1, -1))) != noise_target:
				g["investigate_pos"] = noise_target
				g["investigate_left"] = GUARD_INVESTIGATE_TICKS
				g["alert"] = 1
				snap["events"].append({"tick": snap["tick"], "kind": "guard_investigate", "detail": noise_target, "id": str(g.get("id", ""))})
			g["investigate_left"] = int(g.get("investigate_left", 0)) - 1
			if route_distance(Vector2i(g["pos"]), noise_target) > 0:
				_move_guard(g, "investigate", noise_target)
			if int(g.get("investigate_left", 0)) <= 0:
				g["investigate_pos"] = Vector2i(-1, -1)
				g["alert"] = 0
			return
		elif int(g.get("alert", 0)) == 1:
			g["alert"] = 0
			g["investigate_pos"] = Vector2i(-1, -1)
			g["investigate_left"] = 0

	# 巡逻
	var wps: Array = g.get("waypoints", [])
	if wps.is_empty():
		return
	var wait_left: int = int(g.get("wait_left", 0))
	if wait_left > 0:
		g["wait_left"] = wait_left - 1
		return
	var target_cell = wps[int(g.get("wp_index", 0))]
	if Vector2i(g["pos"]) == Vector2i(target_cell):
		g["wp_index"] = (int(g.get("wp_index", 0)) + 1) % wps.size()
		g["wait_left"] = GUARD_WAIT_TICKS
	else:
		_move_guard(g, "patrol", Vector2i(target_cell))


static func _move_guard(g: Dictionary, state: String, target: Vector2i) -> void:
	var interval: int = int(g.get("move_interval", GUARD_PATROL_INTERVAL))
	match state:
		"investigate":
			interval = int(g.get("investigate_interval", GUARD_INVESTIGATE_INTERVAL))
		"chase":
			interval = int(g.get("chase_interval", GUARD_CHASE_INTERVAL))
	g["move_counter"] = int(g.get("move_counter", 0)) - 1
	if int(g.get("move_counter", 0)) <= 0:
		var from: Vector2i = Vector2i(g["pos"])
		var step: Vector2i = step_towards(from, target)
		g["pos"] = step
		g["facing"] = Vector2i(step.x - from.x, step.y - from.y)
		if g["facing"] == Vector2i.ZERO:
			g["facing"] = Vector2i(1, 0)
		g["move_counter"] = maxi(1, interval)


static func _nearest_noise(g: Dictionary, snap: Dictionary) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := INF
	for n in snap.get("noise", []):
		var npos: Vector2i = n["pos"] if n["pos"] is Vector2i else Vector2i(int(n["pos"]["x"]), int(n["pos"]["y"]))
		var radius: int = int(n.get("radius_cells", GUARD_NOISE_RANGE_CELLS))
		var dist: int = route_distance(Vector2i(g["pos"]), npos)
		if dist <= radius and dist < best_dist:
			best_dist = dist
			best = npos
	return best


static func _guard_sees_player(g: Dictionary, p: Dictionary, context: Dictionary) -> bool:
	var gpos: Vector2i = Vector2i(g["pos"])
	var ppos: Vector2i = Vector2i(p["pos"])
	var same_room_cb: Callable = context.get("same_room", Callable())
	if same_room_cb.is_valid() and not same_room_cb.call(gpos, ppos):
		return false
	var range_cells: int = GUARD_ALERT_RANGE_CELLS - (1 if bool(p.get("crouch", false)) else 0)
	if route_distance(gpos, ppos) > range_cells:
		return false
	var los_cb: Callable = context.get("los_blocked", Callable())
	if los_cb.is_valid() and los_cb.call(gpos, ppos):
		return false
	var facing: Vector2 = Vector2(g.get("facing", Vector2i(1, 0)))
	return in_cone(Vector2(gpos) * 16.0 + Vector2(8, 8), facing, Vector2(ppos) * 16.0 + Vector2(8, 8), range_cells * 16.0, deg_to_rad(48.0))


static func _guard_spot_reason(g: Dictionary) -> String:
	if int(g.get("alert", 0)) == 1:
		return "跑动噪音引来保安"
	var waypoints: Array = g.get("waypoints", [])
	if not waypoints.is_empty():
		var nearest := INF
		for pt in waypoints:
			var w: Vector2i = Vector2i(pt)
			nearest = mini(nearest, route_distance(Vector2i(g["pos"]), w))
		if nearest <= 1:
			return "保安提前转弯发现你"
	return "保安巡逻视野"


static func _tick_camera(c: Dictionary, snap: Dictionary, context: Dictionary) -> void:
	c["phase"] = float(c.get("phase", 0.0)) + float(c.get("sweep_speed", 0.5 * SECONDS_PER_TICK))
	var p: Dictionary = snap["player"]
	var cpos: Vector2i = Vector2i(c.get("pos", Vector2i.ZERO))
	var ppos: Vector2i = Vector2i(p["pos"])
	var same_room_cb: Callable = context.get("same_room", Callable())
	if same_room_cb.is_valid() and not same_room_cb.call(cpos, ppos):
		return
	var range_cells: int = int(c.get("range_cells", CAMERA_RANGE_CELLS))
	if route_distance(cpos, ppos) > range_cells:
		return
	var los_cb: Callable = context.get("los_blocked", Callable())
	if los_cb.is_valid() and los_cb.call(cpos, ppos):
		return
	var rot := sin(float(c.get("phase", 0.0))) * float(c.get("sweep_amp", 0.35))
	var facing := Vector2.RIGHT.rotated(rot)
	if in_cone(Vector2(cpos) * 16.0 + Vector2(8, 8), facing, Vector2(ppos) * 16.0 + Vector2(8, 8), range_cells * 16.0, float(c.get("half_angle", CAMERA_HALF_ANGLE))):
		snap["events"].append({
			"tick": snap["tick"],
			"kind": "spotted",
			"detail": "camera",
			"id": str(c.get("id", "")),
			"pos": Vector2i(p["pos"]),
			"reason": "监控摄像头扇区",
		})


## ---------- 高层接口 ----------

## 预演：在快照副本上跑完整路线，返回 {snapshot(最终), trace(逐tick摘要), events, first_spotted}
static func simulate_route(snapshot: Dictionary, route: Array, max_ticks := 1200, context: Dictionary = {}) -> Dictionary:
	var snap := copy_snapshot(snapshot)
	var copied_route: Array = route.duplicate(true)
	var idx := {"i": 0}
	var trace: Array[String] = []
	var events := []
	var first_spotted := -1
	while int(snap["tick"]) < max_ticks:
		tick(snap, copied_route, idx, context)
		trace.append(snapshot_summary(snap))
		for e in snap["events"]:
			if int(e["tick"]) == int(snap["tick"]) and not events.has(e):
				events.append(e)
			if String(e["kind"]) == "spotted" and first_spotted == -1:
				first_spotted = int(e["tick"])
		if first_spotted != -1:
			break
	return {"snapshot": snap, "trace": trace, "events": events, "first_spotted": first_spotted}


## 执行：与 simulate_route 同一 tick 函数，返回逐步状态流。
static func execute_route(snapshot: Dictionary, route: Array, max_ticks := 1200, context: Dictionary = {}) -> Dictionary:
	return simulate_route(snapshot, route, max_ticks, context)


## 失败恢复：完整还原起始快照（路线由调用方保留）。
static func restore_full(snapshot: Dictionary, state_target: Dictionary) -> void:
	var restored := copy_snapshot(snapshot)
	state_target.clear()
	for key in restored:
		state_target[key] = restored[key]
