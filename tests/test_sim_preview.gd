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
## 断言摘要（课堂演示与 pytest 驱动器读取）：每次 check 都记录，全绿时打印。
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

	if _failures > 0:
		print("FAILED %d / %d checks" % [_failures, _checks])
		quit(1)
	else:
		# 全绿也打印断言摘要（逐行 PASS），供 pytest 驱动器与课堂演示核对覆盖。
		for line in _assertion_log:
			print(line)
		print("ALL %d CHECKS PASSED" % _checks)
		quit(0)


## 构造一条会撞上巡逻的路线：守卫在远处巡逻，玩家走进其巡逻半径被发现。
func _risky_route() -> Array:
	return [
		{"pos": Vector2i(6, 5), "action": "wait", "ticks": 10, "done": 0},
		{"pos": Vector2i(10, 5), "action": "", "ticks": 0, "done": 0},
		{"pos": Vector2i(11, 5), "action": "wait", "ticks": 40, "done": 0},
	]


func _safe_route() -> Array:
	return [
		{"pos": Vector2i(2, 9), "action": "wait", "ticks": 10, "done": 0},
		{"pos": Vector2i(1, 9), "action": "wait", "ticks": 20, "done": 0},
	]


func _test_deterministic_same_route() -> void:
	var start := Sim.default_snapshot()
	start["guard"]["pos"] = Vector2i(12, 7)
	start["guard"]["waypoints"] = [Vector2i(12, 7), Vector2i(12, 3)]
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
	var before := Sim.copy_snapshot(start)
	Sim.simulate_route(start, route)
	check(_deep_equal(start, before), "预演不污染源快照（整份深比较）")


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
	var before := Sim.copy_snapshot(start)
	var route := [
		{"pos": Vector2i(2, 9), "action": "wait", "ticks": 10, "done": 0},
		{"pos": Vector2i(1, 9), "action": "wait", "ticks": 20, "done": 0},
	]
	Sim.execute_route(start, route)
	check(_deep_equal(start, before), "执行也不污染源快照（整份深比较）")


## ---------- R-02 压力/边界用例（test 补充） ----------

## 不同 batch 间隔（模拟不同渲染帧率）逐 tick 重放，轨迹必须与 execute_route 一致。
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
			# 一个渲染帧推进 batch 个固定 tick；摘要仍逐 tick 记录。
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


## 多噪音并发：最近噪音优先，且两次运行完全一致。
func _test_multi_noise() -> void:
	var start := Sim.default_snapshot()
	start["player"]["pos"] = Vector2i(14, 10)
	start["camera"]["pivot"] = Vector2i(0, 0)
	start["camera"]["phase"] = 0
	start["noise"] = [
		{"pos": Vector2i(5, 5), "radius": Sim.GUARD_NOISE_RANGE, "left": 20, "source": "a"},
		{"pos": Vector2i(3, 8), "radius": Sim.GUARD_NOISE_RANGE, "left": 20, "source": "b"},
		{"pos": Vector2i(10, 5), "radius": Sim.GUARD_NOISE_RANGE, "left": 20, "source": "c"},
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


## 长路线（80 节点/数千 tick）不截断、重复运行一致。
func _test_long_route() -> void:
	var start := Sim.default_snapshot()
	start["guard"]["pos"] = Vector2i(14, 0)
	start["guard"]["waypoints"] = [Vector2i(14, 0), Vector2i(14, 1)]
	start["camera"]["pivot"] = Vector2i(14, 0)
	start["camera"]["phase"] = 0
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


## restore_full 必须完整覆盖目标快照（包括隐蔽计时器/监控相位/噪音/事件）。
func _test_restore_full() -> void:
	var start := Sim.default_snapshot()
	start["tick"] = 77
	start["guard"]["wait_left"] = 13
	start["camera"]["phase"] = 5
	start["noise"] = [{"pos": Vector2i(5, 5), "radius": 6, "left": 9, "source": "x"}]
	var target := Sim.copy_snapshot(start)
	target["tick"] = 0
	target["guard"]["wait_left"] = 0
	target["camera"]["phase"] = 0
	target["player"]["pos"] = Vector2i(14, 10)
	target["noise"] = []
	Sim.restore_full(start, target)
	check(_deep_equal(start, target), "restore_full 完整还原（含 tick/守卫等待/监控相位/噪音）")


## 开锁动作必须发生在门口；在别处执行 unlock 不应开门。
func _test_unlock_requires_door() -> void:
	var start := Sim.default_snapshot()
	start["guard"]["pos"] = Vector2i(14, 0)
	start["guard"]["waypoints"] = [Vector2i(14, 0), Vector2i(14, 1)]
	start["camera"]["pivot"] = Vector2i(14, 0)
	start["camera"]["phase"] = 0
	start["player"]["pos"] = Vector2i(1, 1)
	var route := [{"pos": Vector2i(1, 1), "action": "unlock", "ticks": Sim.UNLOCK_TICKS + 5, "done": 0}]
	var run := Sim.simulate_route(start, route, 100)
	check(bool(run.snapshot["door_locked"]), "非门口执行 unlock 不应开门")


## 噪音调查结束后 guard.alert 必须回到 0（巡逻），不能永久停在调查态。
func _test_guard_alert_resets() -> void:
	var start := Sim.default_snapshot()
	start["player"]["pos"] = Vector2i(14, 10)
	start["guard"]["pos"] = Vector2i(2, 2)
	start["guard"]["waypoints"] = [Vector2i(2, 2), Vector2i(5, 2)]
	start["camera"]["pivot"] = Vector2i(14, 0)
	start["camera"]["phase"] = 0
	start["noise"] = [{"pos": Vector2i(5, 5), "radius": Sim.GUARD_NOISE_RANGE, "left": 20, "source": "test"}]
	var route := [{"pos": Vector2i(14, 10), "action": "wait", "ticks": 200, "done": 0}]
	var run := Sim.simulate_route(start, route, 250)
	check(int(run.snapshot["guard"]["alert"]) == 0, "噪音调查结束后守卫回到巡逻态（实际 alert=%d）" % int(run.snapshot["guard"]["alert"]))


## 零随机数 + 固定 tick 是确定性预演的前提。
func _test_no_random_and_fixed_tick() -> void:
	check(Sim.TICK_RATE == 20, "TICK_RATE 固定 20")
	var src := FileAccess.get_file_as_string("res://src/sim/sim_preview.gd")
	check(not src.contains("randi") and not src.contains("randf") and not src.contains("randomize"), "sim_preview.gd 不调用随机数")


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
