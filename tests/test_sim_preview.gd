extends SceneTree
## R-02 / R-02b 确定性预演一致性验收（纯逻辑，无场景）。
##
## 运行：godot --headless --script tests/test_sim_preview.gd
## 验收点：
##   1. 预演与执行同快照/同路线/同动作 → 逐 tick 摘要、事件、首次发现 tick 100% 一致。
##   2. 不同"帧率"（以不同 batch 间隔重放同路线）结果一致。
##   3. 失败恢复整份快照（含 tick/守卫/监控相位），重复执行同路线仍一致。
##   4. 修改路线后重新预测一致；规划全冻结（模拟不动原快照）。
##   5. 噪音吸引调查；蹲下缩小发现半径；开锁/拿取动作 tick 数正确。
##   6. 多守卫/多监控、墙体遮挡（通过 context 回调）不影响一致性。

const Sim := preload("res://src/sim/sim_preview.gd")

var _failures := 0
var _checks := 0
var _assertion_log: Array[String] = []


func check(cond: bool, msg: String) -> void:
	_checks += 1
	_assertion_log.append(("PASS - " if cond else "FAIL - ") + msg)
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
	_test_frame_batching()
	_test_multi_noise()
	_test_long_route()
	_test_restore_full()
	_test_unlock_requires_door()
	_test_guard_alert_resets()
	_test_no_random_and_fixed_tick()
	_test_multi_guard_camera()
	_test_wall_occlusion()
	_test_noise_stays_in_room()

	if _failures > 0:
		print("FAILED %d / %d checks" % [_failures, _checks])
		quit(1)
	else:
		for line in _assertion_log:
			print(line)
		print("ALL %d CHECKS PASSED" % _checks)
		quit(0)


func _risky_route() -> Array:
	return [
		{"pos": Vector2i(10, 5), "action": "", "ticks": 0, "done": 0},
		{"pos": Vector2i(10, 5), "action": "wait", "ticks": 40, "done": 0},
	]


func _safe_route() -> Array:
	return [
		{"pos": Vector2i(2, 9), "action": "wait", "ticks": 10, "done": 0},
		{"pos": Vector2i(1, 9), "action": "wait", "ticks": 20, "done": 0},
	]


func _test_deterministic_same_route() -> void:
	var start := Sim.default_snapshot()
	start["guards"][0]["pos"] = Vector2i(12, 5)
	start["guards"][0]["waypoints"] = [Vector2i(12, 5)]
	start["guards"][0]["facing"] = Vector2i(-1, 0)
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

	var again := Sim.execute_route(start, route)
	check(str(again.events) == str(execute.events), "重复执行事件一致（帧率无关）")

	var modified := _risky_route()
	modified[1]["ticks"] = 5
	var pm := Sim.simulate_route(start, modified)
	var em := Sim.execute_route(start, modified)
	check(str(pm.trace) == str(em.trace), "修改路线后预演/执行仍一致")

	var before := Sim.copy_snapshot(start)
	Sim.simulate_route(start, route)
	check(_deep_equal(start, before), "预演不污染源快照（整份深比较）")


func _test_fail_restore_full_snapshot() -> void:
	var start := Sim.default_snapshot()
	start["tick"] = 77
	start["guards"][0]["pos"] = Vector2i(12, 5)
	start["guards"][0]["waypoints"] = [Vector2i(12, 5)]
	start["guards"][0]["facing"] = Vector2i(-1, 0)
	var route := _risky_route()
	var preview := Sim.simulate_route(start, route)
	check(preview.first_spotted != -1, "失败场景触发发现")
	var restored := Sim.copy_snapshot(start)
	check(Sim.snapshot_summary(restored) == Sim.snapshot_summary(start), "恢复快照逐字段一致")
	var re := Sim.execute_route(restored, route)
	check(str(re.trace) == str(preview.trace), "失败恢复后重跑同路线仍逐 tick 一致")


func _test_noise_investigate() -> void:
	var start := Sim.default_snapshot()
	start["noise"].append({"pos": Vector2i(5, 5), "radius_cells": Sim.GUARD_NOISE_RANGE_CELLS, "left": Sim.NOISE_LIFETIME_TICKS, "source": "test"})
	var route := [
		{"pos": Vector2i(1, 1), "action": "wait", "ticks": 5, "done": 0},
	]
	var run := Sim.execute_route(start, route)
	var has_investigate := false
	for e in run.events:
		if String(e["kind"]) == "guard_investigate":
			has_investigate = true
	var g: Dictionary = run.snapshot["guards"][0]
	check(has_investigate, "噪音触发守卫调查事件")
	check(route_distance_child(g["pos"], Vector2i(5, 5)) <= route_distance_child(Vector2i(2, 2), Vector2i(5, 5)), "守卫朝噪音源移动")


static func route_distance_child(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _test_crouch_shrinks_detection() -> void:
	var standing := Sim.default_snapshot()
	standing["player"]["pos"] = Vector2i(4, 2)
	standing["player"]["crouch"] = false
	var crouched := Sim.copy_snapshot(standing)
	crouched["player"]["crouch"] = true
	standing["player"]["pos"] = Vector2i(6, 2)
	var sr := Sim.simulate_route(standing, [{"pos": Vector2i(6, 2), "action": "wait", "ticks": 30, "done": 0}], 40)
	check(sr.first_spotted != -1, "站立距离 4 被发现")
	crouched["player"]["pos"] = Vector2i(6, 2)
	var cr := Sim.simulate_route(crouched, [{"pos": Vector2i(6, 2), "action": "crouch", "ticks": 40, "done": 0}], 30)
	check(cr.first_spotted == -1, "蹲下距离 4 未被发现")


func _test_unlock_and_take() -> void:
	var start := Sim.default_snapshot()
	start["guards"][0]["pos"] = Vector2i(2, 10)
	start["guards"][0]["waypoints"] = [Vector2i(2, 10), Vector2i(4, 10)]
	start["doors"][Sim.DOOR_POS] = true
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

	var take_start := Sim.default_snapshot()
	take_start["doors"][Sim.DOOR_POS] = false
	take_start["guards"][0]["pos"] = Vector2i(2, 10)
	take_start["guards"][0]["waypoints"] = [Vector2i(2, 10), Vector2i(4, 10)]
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
	start["guards"][0]["wait_left"] = 13
	var before := Sim.copy_snapshot(start)
	var route := [
		{"pos": Vector2i(2, 9), "action": "wait", "ticks": 10, "done": 0},
		{"pos": Vector2i(1, 9), "action": "wait", "ticks": 20, "done": 0},
	]
	Sim.execute_route(start, route)
	check(_deep_equal(start, before), "执行也不污染源快照（整份深比较）")


func _test_frame_batching() -> void:
	var start := Sim.default_snapshot()
	var route := _safe_route()
	var reference := Sim.execute_route(start, route, 200)
	for batch in [1, 3, 7, 20]:
		var snap := Sim.copy_snapshot(start)
		var r: Array = route.duplicate(true)
		var idx := {"i": 0}
		var trace: Array[String] = []
		var guard := 0
		while int(snap["tick"]) < 200 and guard < 200:
			for _k in batch:
				if int(snap["tick"]) >= 200:
					break
				Sim.tick(snap, r, idx)
				trace.append(Sim.snapshot_summary(snap))
				var spotted := false
				for e in snap["events"]:
					if int(e["tick"]) == int(snap["tick"]) and String(e["kind"]) == "spotted":
						spotted = true
				if spotted:
					break
			guard += 1
			var any_spotted := false
			for e in snap["events"]:
				if String(e["kind"]) == "spotted":
					any_spotted = true
			if any_spotted:
				break
		check(str(trace) == str(reference.trace), "batch=%d 逐 tick 轨迹与执行一致" % batch)


func _test_multi_noise() -> void:
	var start := Sim.default_snapshot()
	start["player"]["pos"] = Vector2i(14, 10)
	start["cameras"][0]["pos"] = Vector2i(0, 0)
	start["cameras"][0]["phase"] = 0.0
	start["noise"] = [
		{"pos": Vector2i(5, 5), "radius_cells": Sim.GUARD_NOISE_RANGE_CELLS, "left": 20, "source": "a"},
		{"pos": Vector2i(3, 8), "radius_cells": Sim.GUARD_NOISE_RANGE_CELLS, "left": 20, "source": "b"},
		{"pos": Vector2i(10, 5), "radius_cells": Sim.GUARD_NOISE_RANGE_CELLS, "left": 20, "source": "c"},
	]
	var route := [{"pos": Vector2i(14, 10), "action": "wait", "ticks": 80, "done": 0}]
	var a := Sim.simulate_route(start, route, 300)
	var b := Sim.simulate_route(start, route, 300)
	check(str(a.trace) == str(b.trace), "多噪音并发两次预演逐 tick 一致")
	check(str(a.events) == str(b.events), "多噪音并发事件序列一致")
	var first_noise := {}
	for e in a.events:
		if String(e["kind"]) == "guard_investigate":
			first_noise = e
			break
	check(not first_noise.is_empty(), "多噪音触发调查")
	if not first_noise.is_empty():
		check(str(first_noise["detail"]) == str(Vector2i(5, 5)), "最近噪音 (5,5) 优先（实际 %s）" % str(first_noise["detail"]))


func _test_long_route() -> void:
	var start := Sim.default_snapshot()
	start["guards"][0]["pos"] = Vector2i(14, 0)
	start["guards"][0]["waypoints"] = [Vector2i(14, 0), Vector2i(14, 1)]
	start["cameras"][0]["pos"] = Vector2i(14, 0)
	start["cameras"][0]["phase"] = 0.0
	var route: Array = []
	for i in 120:
		var x := 1 + (i % 12)
		var y := 9 if (i % 2 == 0) else 8
		route.append({"pos": Vector2i(x, y), "action": "wait", "ticks": 1, "done": 0})
	var a := Sim.simulate_route(start, route, 5000)
	var b := Sim.simulate_route(start, route, 5000)
	check(a.trace.size() > 300, "长路线产生了足够 tick（%d）" % a.trace.size())
	check(str(a.trace) == str(b.trace), "长路线两次预演逐 tick 一致")
	check(str(a.events) == str(b.events), "长路线事件序列一致")


func _test_restore_full() -> void:
	var start := Sim.default_snapshot()
	start["tick"] = 77
	start["guards"][0]["wait_left"] = 13
	start["cameras"][0]["phase"] = 5.0
	start["noise"] = [{"pos": Vector2i(5, 5), "radius_cells": 6, "left": 9, "source": "x"}]
	var target := Sim.copy_snapshot(start)
	target["tick"] = 0
	target["guards"][0]["wait_left"] = 0
	target["cameras"][0]["phase"] = 0.0
	target["player"]["pos"] = Vector2i(14, 10)
	target["noise"] = []
	Sim.restore_full(start, target)
	check(_deep_equal(start, target), "restore_full 完整还原（含 tick/守卫等待/监控相位/噪音）")


func _test_unlock_requires_door() -> void:
	var start := Sim.default_snapshot()
	start["guards"][0]["pos"] = Vector2i(14, 0)
	start["guards"][0]["waypoints"] = [Vector2i(14, 0), Vector2i(14, 1)]
	start["cameras"][0]["pos"] = Vector2i(14, 0)
	start["cameras"][0]["phase"] = 0.0
	start["player"]["pos"] = Vector2i(1, 1)
	start["doors"][Sim.DOOR_POS] = true
	var route := [{"pos": Vector2i(1, 1), "action": "unlock", "ticks": Sim.UNLOCK_TICKS + 5, "done": 0}]
	var run := Sim.simulate_route(start, route, 100)
	var unlocked := false
	for e in run.events:
		if String(e["kind"]) == "door_unlocked":
			unlocked = true
	check(not unlocked, "非门口执行 unlock 不应开门")
	check(bool(run.snapshot["doors"].get(Sim.DOOR_POS, false)), "门口门锁保持锁定")


func _test_guard_alert_resets() -> void:
	var start := Sim.default_snapshot()
	start["player"]["pos"] = Vector2i(14, 10)
	start["guards"][0]["pos"] = Vector2i(2, 2)
	start["guards"][0]["waypoints"] = [Vector2i(2, 2), Vector2i(5, 2)]
	start["cameras"][0]["pos"] = Vector2i(14, 0)
	start["cameras"][0]["phase"] = 0.0
	start["noise"] = [{"pos": Vector2i(5, 5), "radius_cells": Sim.GUARD_NOISE_RANGE_CELLS, "left": 20, "source": "test"}]
	var route := [{"pos": Vector2i(14, 10), "action": "wait", "ticks": 200, "done": 0}]
	var run := Sim.simulate_route(start, route, 250)
	check(int(run.snapshot["guards"][0]["alert"]) == 0, "噪音调查结束后守卫回到巡逻态（实际 alert=%d）" % int(run.snapshot["guards"][0]["alert"]))


func _test_no_random_and_fixed_tick() -> void:
	check(Sim.TICK_RATE == 20, "TICK_RATE 固定 20")
	var src := FileAccess.get_file_as_string("res://src/sim/sim_preview.gd")
	check(not src.contains("randi") and not src.contains("randf") and not src.contains("randomize"), "sim_preview.gd 不调用随机数")


func _test_multi_guard_camera() -> void:
	var start := Sim.default_snapshot()
	start["guards"] = [
		{"id": "g1", "pos": Vector2i(4, 3), "waypoints": [Vector2i(4, 3)], "wp_index": 0, "move_interval": 1, "move_counter": 0,
		 "wait_left": 0, "facing": Vector2i(1, -1), "investigate_pos": Vector2i(-1, -1), "investigate_left": 0, "alert": 0,
		 "spot_timer": 0, "spot_delay": Sim.SPOT_DELAY_TICKS, "blind_timer": 0, "ai_enabled": true},
		{"id": "g2", "pos": Vector2i(10, 10), "waypoints": [Vector2i(10, 10)], "wp_index": 0, "move_interval": 1, "move_counter": 0,
		 "wait_left": 0, "facing": Vector2i(-1, 0), "investigate_pos": Vector2i(-1, -1), "investigate_left": 0, "alert": 0,
		 "spot_timer": 0, "spot_delay": Sim.SPOT_DELAY_TICKS, "blind_timer": 0, "ai_enabled": true},
	]
	start["cameras"] = [
		{"id": "c1", "pos": Vector2i(4, 1), "phase": 0.0, "sweep_speed": 0.0, "sweep_amp": 0.0, "range_cells": Sim.CAMERA_RANGE_CELLS, "half_angle": Sim.CAMERA_HALF_ANGLE},
		{"id": "c2", "pos": Vector2i(12, 12), "phase": 0.0, "sweep_speed": 0.0, "sweep_amp": 0.0, "range_cells": Sim.CAMERA_RANGE_CELLS, "half_angle": Sim.CAMERA_HALF_ANGLE},
	]
	start["player"]["pos"] = Vector2i(6, 1)
	var route := [{"pos": Vector2i(6, 1), "action": "wait", "ticks": Sim.SPOT_DELAY_TICKS + 5, "done": 0}]
	var run := Sim.simulate_route(start, route, 60)
	check(run.first_spotted != -1, "多守卫/监控场景触发发现")
	var camera_event := false
	for e in run.events:
		if String(e["kind"]) == "spotted" and String(e.get("detail", "")) == "camera":
			camera_event = true
	check(camera_event, "监控摄像头也被纳入发现归因")


func _test_wall_occlusion() -> void:
	var start := Sim.default_snapshot()
	start["guards"][0]["pos"] = Vector2i(2, 2)
	start["guards"][0]["waypoints"] = [Vector2i(2, 2)]
	start["guards"][0]["facing"] = Vector2i(1, 0)
	start["player"]["pos"] = Vector2i(6, 2)
	# 同一房间、距离 4、视野覆盖，但中间 (4,2) 被墙遮挡
	var context := {
		"los_blocked": func(a: Vector2i, b: Vector2i) -> bool:
			return a == Vector2i(2, 2) and b == Vector2i(6, 2),
		"same_room": func(_a: Vector2i, _b: Vector2i) -> bool: return true,
	}
	var route := [{"pos": Vector2i(6, 2), "action": "wait", "ticks": Sim.SPOT_DELAY_TICKS + 5, "done": 0}]
	var run := Sim.simulate_route(start, route, 40, context)
	check(run.first_spotted == -1, "墙体遮挡时不应发现玩家")


func _deep_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not _deep_equal(a[k], b[k]):
				return false
		return true
	if a is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _deep_equal(a[i], b[i]):
				return false
		return true
	return a == b

## 手动感知与共享模拟均只响应同房间的噪音，不能穿墙跨厅引怪。
func _noise_room(a: Vector2i, b: Vector2i) -> bool:
	return (a.x < 6) == (b.x < 6)


func _noise_fixture() -> Dictionary:
	var snap := Sim.default_snapshot()
	snap["player"]["pos"] = Vector2i(2, 20)
	snap["cameras"] = []
	snap["guards"][0]["pos"] = Vector2i(5, 5)
	snap["guards"][0]["waypoints"] = [Vector2i(5, 5)]
	snap["noise"] = [{"pos": Vector2i(6, 5), "radius_cells": 3, "left": 10}]
	return snap


func _test_noise_stays_in_room() -> void:
	var snap := _noise_fixture()
	var route := [{"pos": Vector2i(2, 20), "action": "wait", "ticks": 20, "done": 0}]
	var context := {"same_room": _noise_room}
	Sim.tick(snap, route.duplicate(true), {"i": 0}, context)
	check(int(snap["guards"][0]["alert"]) == 0, "隔壁厅半径内的噪音不触发调查")
	check(snap["events"].is_empty(), "跨房间噪音不生成调查事件")
	snap = _noise_fixture()
	snap["noise"].append({"pos": Vector2i(4, 5), "radius_cells": 3, "left": 10})
	Sim.tick(snap, route.duplicate(true), {"i": 0}, context)
	check(snap["guards"][0]["investigate_pos"] == Vector2i(4, 5), "多个噪音只选择合法同厅来源")
	var gray := _noise_fixture()
	Sim.tick(gray, route.duplicate(true), {"i": 0})
	check(int(gray["guards"][0]["alert"]) == 1, "无房间上下文的单房灰盒仍响应半径噪音")
