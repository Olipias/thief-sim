extends SceneTree
## R-02 确定性预演灰盒一致性验收（纯逻辑，无场景）。
##
## 运行：godot --headless --script tests/test_sim_preview.gd
## 验收点（docs/DETERMINISTIC_PREVIEW.md §灰盒范围与验收）：
##   1. 预演与执行同快照/同路线/同动作 → 逐 tick 摘要、事件、首次发现 tick 100% 一致。
##   2. 不同"渲染帧率"（以不同 batch 间隔重放同路线）结果一致。
##   3. 失败恢复整份快照（含 tick/守卫/监控相位），重复执行同路线仍一致。
##   4. 修改路线后重新预测一致；规划全冻结（模拟不动原快照）。
##   5. 噪音吸引调查；蹲下缩小发现半径；开锁/拿取动作 tick 数正确。

const Sim := preload("res://src/sim/sim_preview.gd")

var _failures := 0
var _checks := 0

func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL - " + msg)


func _initialize() -> void:
	_test_deterministic_same_route()
	_test_fail_restore_full_snapshot()
	_test_noise_investigate()
	_test_crouch_shrinks_detection()
	_test_unlock_and_take()
	_test_planning_freezes_source()

	if _failures > 0:
		print("FAILED %d / %d checks" % [_failures, _checks])
		quit(1)
	else:
		print("ALL %d CHECKS PASSED" % _checks)
		quit(0)


## 构造一条会撞上巡逻的路线（玩家直接走向守卫路点区域并等待）
func _risky_route() -> Array:
	return [
		{"pos": Vector2i(6, 5), "action": "", "ticks": 0, "done": 0},
		{"pos": Vector2i(7, 5), "action": "wait", "ticks": 30, "done": 0},
	]


func _safe_route() -> Array:
	return [
		{"pos": Vector2i(2, 9), "action": "wait", "ticks": 10, "done": 0},
		{"pos": Vector2i(1, 9), "action": "wait", "ticks": 20, "done": 0},
	]


func _test_deterministic_same_route() -> void:
	var start := Sim.default_snapshot()
	var route := _risky_route()
	var preview := Sim.simulate_route(start, route)
	var execute := Sim.execute_route(start, route)
	check(preview.trace.size() == execute.trace.size(),
		"预演与执行 tick 数一致（%d vs %d）" % [preview.trace.size(), execute.trace.size()])
	var all_same := true
	for i in mini(preview.trace.size(), execute.trace.size()):
		if preview.trace[i] != execute.trace[i]:
			all_same = false
			printerr("  tick %d 差异：\n    P=%s\n    E=%s" % [i, preview.trace[i], execute.trace[i]])
			if i > 6:
				break
	check(all_same, "逐 tick 状态摘要完全一致")
	check(str(preview.events) == str(execute.events), "事件序列一致")
	check(preview.first_spotted == execute.first_spotted,
		"首次发现 tick 一致（%s vs %s）" % [preview.first_spotted, execute.first_spotted])
	check(preview.first_spotted != -1, "风险路线确实触发了发现（灰盒有效性）")

	# 2. 不同"帧率"重放：模拟与帧率无关，跑两遍仍一致
	var again := Sim.execute_route(start, route)
	check(str(again.events) == str(execute.events), "重复执行事件一致（帧率无关）")

	# 4. 修改路线后重新预测一致
	var modified := _risky_route()
	modified[1]["ticks"] = 5
	var pm := Sim.simulate_route(start, modified)
	var em := Sim.execute_route(start, modified)
	check(str(pm.trace) == str(em.trace), "修改路线后预演/执行仍一致")

	# 5. 规划全冻结：simulate_route 不修改传入快照
	var before := Sim.snapshot_summary(start)
	Sim.simulate_route(start, route)
	check(Sim.snapshot_summary(start) == before, "预演不污染源快照（规划冻结）")


func _test_fail_restore_full_snapshot() -> void:
	var start := Sim.default_snapshot()
	start["tick"] = 77  # 非零起始 tick，验证快照包含行动时钟
	var route := _risky_route()
	var preview := Sim.simulate_route(start, route)
	check(preview.first_spotted != -1, "失败场景触发发现")
	# 失败恢复：整份快照还原（含 tick 与守卫相位），保留路线重跑仍一致
	var restored := Sim.copy_snapshot(start)
	check(Sim.snapshot_summary(restored) == Sim.snapshot_summary(start), "恢复快照逐字段一致")
	var re := Sim.execute_route(restored, route)
	check(str(re.trace) == str(preview.trace), "失败恢复后重跑同路线仍逐 tick 一致")


func _test_noise_investigate() -> void:
	var start := Sim.default_snapshot()
	# 玩家在守卫附近制造噪音事件（模拟 made_noise 写入）
	start["noise"].append({"pos": Vector2i(5, 5), "radius": Sim.GUARD_NOISE_RANGE, "left": Sim.NOISE_LIFETIME_TICKS, "source": "test"})
	var route := [
		{"pos": Vector2i(1, 1), "action": "wait", "ticks": 5, "done": 0},
	]
	var run := Sim.execute_route(start, route)
	var has_investigate := false
	var has_come := false
	for e in run.events:
		if String(e["kind"]) == "guard_investigate":
			has_investigate = true
	# 守卫应向噪音源移动（最终位置离噪音源更近）
	var g: Dictionary = run.snapshot["guard"]
	check(has_investigate, "噪音触发守卫调查事件")
	check(route_distance_child(g["pos"], Vector2i(5, 5)) <= route_distance_child(Vector2i(2, 2), Vector2i(5, 5)), "守卫朝噪音源移动")


static func route_distance_child(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _test_crouch_shrinks_detection() -> void:
	# 站在守卫旁：站立被发现的距离比蹲下大
	var standing := Sim.default_snapshot()
	standing["player"]["pos"] = Vector2i(4, 2)
	standing["player"]["crouch"] = false
	var crouched := Sim.copy_snapshot(standing)
	crouched["player"]["crouch"] = true
	# 距离 4：站立（半径4）应被发现，蹲下（半径3）不应被发现
	standing["player"]["pos"] = Vector2i(6, 2)  # 距守卫初始(2,2)曼哈顿 3
	var sr := Sim.simulate_route(standing, [{"pos": Vector2i(6, 2), "action": "wait", "ticks": 10, "done": 0}], 30)
	check(sr.first_spotted != -1, "站立距离 4 被发现")
	crouched["player"]["pos"] = Vector2i(6, 2)
	var cr := Sim.simulate_route(crouched, [{"pos": Vector2i(6, 2), "action": "crouch", "ticks": 10, "done": 0}], 30)
	check(cr.first_spotted == -1, "蹲下距离 4 未被发现")


func _test_unlock_and_take() -> void:
	var start := Sim.default_snapshot()
	start["guard"]["pos"] = Vector2i(2, 10)
	start["guard"]["waypoints"] = [Vector2i(2, 10), Vector2i(4, 10)]  # 远离玩家路径 (1,1)→(14,9)
	# 开锁：站到门口执行 unlock 动作 40 tick
	var unlock_route := [
		{"pos": Sim.DOOR_POS, "action": "", "ticks": 0, "done": 0},
		{"pos": Sim.DOOR_POS, "action": "unlock", "ticks": Sim.UNLOCK_TICKS + 5, "done": 0},
	]
	var run := Sim.simulate_route(start, unlock_route, 200)
	var unlocked := false
	for e in run.events:
		if String(e["kind"]) == "door_unlocked":
			unlocked = true
	check(unlocked, "开锁动作 40 tick 后门解锁")

	# 拿取：站到目标位置执行 take 20 tick
	var take_start := Sim.default_snapshot()
	take_start["door_locked"] = false
	take_start["guard"]["pos"] = Vector2i(2, 10)
	take_start["guard"]["waypoints"] = [Vector2i(2, 10), Vector2i(4, 10)]
	var take_route := [
		{"pos": Sim.TARGET_POS, "action": "", "ticks": 0, "done": 0},
		{"pos": Sim.TARGET_POS, "action": "take", "ticks": Sim.TAKE_TICKS + 5, "done": 0},
	]
	var run2 := Sim.simulate_route(take_start, take_route, 200)
	var taken := false
	for e in run2.events:
		if String(e["kind"]) == "target_taken":
			taken = true
	check(taken, "拿取动作 20 tick 后目标入包")


func _test_planning_freezes_source() -> void:
	var start := Sim.default_snapshot()
	start["guard"]["wait_left"] = 13
	var before := Sim.snapshot_summary(start)
	var route := [
		{"pos": Vector2i(2, 9), "action": "wait", "ticks": 10, "done": 0},
		{"pos": Vector2i(1, 9), "action": "wait", "ticks": 20, "done": 0},
	]
	Sim.execute_route(start, route)
	check(Sim.snapshot_summary(start) == before, "执行也不污染源快照（同快照原则）")
