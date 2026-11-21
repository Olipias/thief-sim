extends Node
## R-02b 真实场景 ↔ 确定性内核逐 tick 等价验收。
##
## 运行：godot --headless res://tests/test_museum_sim.tscn
## 验收点：
##   - 同一起始快照 + 同路线 → 预演 trace 与执行 trace 逐 tick 一致。
##   - 守卫视野、墙体遮挡、监控摄像头、噪音调查、拿取动作均触发一致事件。
##   - 完整快照回退还原玩家/守卫/物品/背包/烟雾状态。

const Sim := preload("res://src/sim/sim_preview.gd")
const Museum := preload("res://src/world/museum.gd")
const Police := preload("res://src/actors/police.gd")
const Artifact := preload("res://src/world/artifact.gd")
const SmokePuffClass := preload("res://src/world/smoke_puff.gd")

var _failures := 0
var _checks := 0
var _log: Array[String] = []


func check(cond: bool, msg: String) -> void:
	_checks += 1
	var line := ("PASS - " if cond else "FAIL - ") + msg
	_log.append(line)
	if not cond:
		_failures += 1
		printerr(line)


func _ready() -> void:
	Game.save_path = "/tmp/thief_sim_museum_sim_save.json"
	Game.reset_progress()
	Game.current_level_id = "museum"
	Game.mission_target_id = "mask"
	Game.bag_items.clear()
	Game.smoke_count = 1
	Game.backpack_changed.emit()
	Game.items_changed.emit()

	await _test_safe_route_equivalence()
	await _test_guard_spot_equivalence()
	await _test_wall_occlusion_equivalence()
	await _test_camera_spot_equivalence()
	await _test_noise_investigate_equivalence()
	await _test_take_action_equivalence()
	await _test_full_state_trace_equivalence()
	await _test_full_snapshot_restore()
	await _test_preview_wall_context()
	await _test_full_snapshot_exact_state()
	await _test_full_snapshot_all_entities()
	await _test_multi_guard_equivalence()
	await _test_multi_camera_equivalence()
	await _test_manual_takeover_invalidates_preview()
	await _test_frame_rate_equivalence()

	Audio.shutdown()
	if _failures > 0:
		for line in _log:
			print(line)
		print("FAILED %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
	else:
		for line in _log:
			print(line)
		print("ALL %d CHECKS PASSED" % _checks)
		get_tree().quit(0)


func _make_museum() -> Museum:
	Game.bag_items.clear()
	Game.smoke_count = 1
	Game.backpack_changed.emit()
	Game.items_changed.emit()

	var museum := load("res://src/world/museum.tscn").instantiate() as Museum
	museum.level_id = "museum"
	add_child(museum)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# 把所有守卫移到远处并关掉 AI，避免干扰单一变量的等价测试。
	for cop in museum.police:
		cop.set_ai_enabled(false)
		cop.patrol_points.clear()
		cop._wait_timer = 0.0
		cop._spot_timer = 0.0
		cop._investigate_timer = 0.0
		cop.global_position = _cell_center(2, 2)
		cop._facing = Vector2.DOWN
	return museum


func _cell_center(x: int, y: int) -> Vector2:
	return Vector2(x * 16 + 8, y * 16 + 8)


func _scatter_other_guards(museum: Museum, keep: int) -> void:
	for i in museum.police.size():
		if i == keep:
			continue
		museum.police[i].global_position = _cell_center(17, 9)
		museum.police[i]._facing = Vector2.DOWN


func _spawn_smoke(museum: Museum, at: Vector2) -> SmokePuffClass:
	var node := load("res://src/world/smoke_puff.tscn").instantiate() as SmokePuffClass
	node.position = at
	museum.add_child(node)
	return node


## 执行过程中实时截取 trace 与事件。执行结束后 _sim_snapshot 会被清空，
## 因此事件必须在本函数内累积。
func _capture_execution_trace(museum: Museum, max_ticks := 300) -> Dictionary:
	var trace: Array[String] = []
	var states: Array[String] = []
	var events: Array = []
	var last_tick := -1
	var guard := 0
	while true:
		var snap: Dictionary = museum._sim_snapshot
		var t := int(snap.get("tick", 0))
		if t > 0 and t != last_tick:
			trace.append(Sim.snapshot_summary(snap))
			states.append(var_to_str(snap))
			last_tick = t
		for e in snap.get("events", []):
			if int(e.get("tick", 0)) == t and not events.has(e):
				events.append(e)
		if not museum.executing_plan or guard >= max_ticks:
			break
		await get_tree().physics_frame
		guard += 1
	return {"trace": trace, "states": states, "events": events}


func _events_of_kind(events: Array, kind: String) -> Array:
	var out: Array = []
	for e in events:
		if String(e.get("kind", "")) == kind:
			out.append(e)
	return out


func _first_event_kind(events: Array, kind: String) -> Dictionary:
	for e in events:
		if String(e.get("kind", "")) == kind:
			return e
	return {}


func _compare_trace(name: String, preview_trace: Array[String], exec_trace: Array[String], up_to: int = -1) -> bool:
	# up_to >= 0：必须完整覆盖到该 tick；任一侧提前截断即失败（不能只比共同前缀）。
	# up_to < 0：要求长度相等后逐项比较。
	if up_to >= 0:
		if preview_trace.size() < up_to or exec_trace.size() < up_to:
			printerr("  %s 轨迹长度不足：要求 %d，P=%d E=%d" % [name, up_to, preview_trace.size(), exec_trace.size()])
			return false
		for i in up_to:
			if preview_trace[i] != exec_trace[i]:
				printerr("  %s tick %d 差异：\n    P=%s\n    E=%s" % [name, i, preview_trace[i], exec_trace[i]])
				return false
		return true
	if preview_trace.size() != exec_trace.size():
		printerr("  %s 轨迹长度不一致：P=%d E=%d" % [name, preview_trace.size(), exec_trace.size()])
		return false
	for i in preview_trace.size():
		if preview_trace[i] != exec_trace[i]:
			printerr("  %s tick %d 差异：\n    P=%s\n    E=%s" % [name, i, preview_trace[i], exec_trace[i]])
			return false
	return true


func _test_safe_route_equivalence() -> void:
	var museum := await _make_museum()

	var start := _cell_center(5, 5)
	var target := _cell_center(5, 7)
	museum.player.global_position = start
	museum.planned_points = [target]
	museum._plan_node_actions = [""]

	var snap := museum._build_sim_snapshot()
	var route := museum._planned_sim_route()
	var preview := Sim.simulate_route(snap, route, 200, museum._build_sim_context())

	museum.execute_plan()
	var exec := await _capture_execution_trace(museum)
	var exec_trace: Array[String] = exec["trace"]
	check(preview.first_spotted == -1, "安全路线：预演未发现")
	check(exec_trace.size() >= 2, "安全路线：执行至少推进 2 tick（实际 %d）" % exec_trace.size())
	check(_compare_trace("安全路线", preview.trace, exec_trace, exec_trace.size()), "安全路线：预演与执行逐 tick 一致")
	museum.queue_free()


func _test_guard_spot_equivalence() -> void:
	var museum := await _make_museum()
	var cop: Police = museum.police[0]

	var player_start := _cell_center(5, 5)
	var guard_pos := _cell_center(5, 3)
	museum.player.global_position = player_start
	cop.global_position = guard_pos
	cop._facing = Vector2.DOWN
	_scatter_other_guards(museum, 0)

	# 移动到 (5,7) 后等待，确保在视野内被发现的 tick 落在执行过程中。
	var target := _cell_center(5, 7)
	museum.planned_points = [target]
	museum._plan_node_actions = ["wait"]

	var snap := museum._build_sim_snapshot()
	var route := museum._planned_sim_route()
	var preview := Sim.simulate_route(snap, route, 100, museum._build_sim_context())

	museum.execute_plan()
	var exec := await _capture_execution_trace(museum)
	var exec_trace: Array[String] = exec["trace"]
	var exec_events: Array = exec["events"]
	check(preview.first_spotted != -1, "守卫视野：预演触发发现（tick %d）" % preview.first_spotted)
	var preview_event := _first_event_kind(preview.events, "spotted")
	check(String(preview_event.get("detail", "")) == "guard", "守卫视野：触发实体归因是 guard")
	check(exec_trace.size() >= preview.first_spotted, "守卫视野：执行至少跑到发现 tick（%d >= %d）" % [exec_trace.size(), preview.first_spotted])
	check(_compare_trace("守卫视野", preview.trace, exec_trace, preview.first_spotted), "守卫视野：发现前逐 tick 一致")
	var exec_spotted := _events_of_kind(exec_events, "spotted")
	check(exec_spotted.size() >= 1, "守卫视野：执行也触发 spotted 事件")
	if exec_spotted.size() >= 1:
		check(int(exec_spotted[0].get("tick", -1)) == preview.first_spotted, "守卫视野：执行发现 tick 与预演相同")
		check(String(exec_spotted[0].get("detail", "")) == "guard", "守卫视野：执行发现归因是 guard")
	museum.queue_free()


func _test_wall_occlusion_equivalence() -> void:
	var museum := await _make_museum()
	var cop: Police = museum.police[0]

	# 玩家 (3,2)，守卫 (7,2)，中间隔着 (4,2)-(5,2) 的 'd' 展柜；视线与展柜水平对齐。
	var player_start := _cell_center(3, 2)
	var guard_pos := _cell_center(7, 2)
	museum.player.global_position = player_start
	cop.global_position = guard_pos
	cop._facing = Vector2.LEFT
	_scatter_other_guards(museum, 0)

	var target := _cell_center(3, 3)
	museum.planned_points = [target]
	museum._plan_node_actions = [""]

	var snap := museum._build_sim_snapshot()
	var route := museum._planned_sim_route()
	var preview := Sim.simulate_route(snap, route, 80, museum._build_sim_context())

	museum.execute_plan()
	var exec := await _capture_execution_trace(museum)
	var exec_trace: Array[String] = exec["trace"]
	var exec_events: Array = exec["events"]
	check(preview.first_spotted == -1, "墙体遮挡：预演未触发发现")
	check(exec_trace.size() >= 1, "墙体遮挡：执行推进了至少 1 tick")
	check(_compare_trace("墙体遮挡", preview.trace, exec_trace, exec_trace.size()), "墙体遮挡：预演与执行逐 tick 一致")
	check(_events_of_kind(exec_events, "spotted").is_empty(), "墙体遮挡：执行也未触发 spotted")
	museum.queue_free()


func _test_camera_spot_equivalence() -> void:
	var museum := await _make_museum()

	# 摄像头在玩家左侧，朝右扫描；玩家向右移动并等待，确保进入扇区。
	var cam := Node2D.new()
	cam.name = "cam_test"
	cam.global_position = _cell_center(1, 5)
	museum.add_child(cam)
	museum._bm_cameras.append(cam)
	_scatter_other_guards(museum, -1)

	var player_start := _cell_center(3, 5)
	museum.player.global_position = player_start

	var target := _cell_center(6, 5)
	museum.planned_points = [target]
	museum._plan_node_actions = ["wait"]

	var snap := museum._build_sim_snapshot()
	var route := museum._planned_sim_route()
	var preview := Sim.simulate_route(snap, route, 120, museum._build_sim_context())

	museum.execute_plan()
	var exec := await _capture_execution_trace(museum)
	var exec_trace: Array[String] = exec["trace"]
	var exec_events: Array = exec["events"]
	check(preview.first_spotted != -1, "监控摄像头：预演触发发现")
	var preview_event := _first_event_kind(preview.events, "spotted")
	check(String(preview_event.get("detail", "")) == "camera", "监控摄像头：触发实体归因是 camera")
	check(exec_trace.size() >= preview.first_spotted, "监控摄像头：执行跑到发现 tick")
	check(_compare_trace("监控摄像头", preview.trace, exec_trace, preview.first_spotted), "监控摄像头：发现前逐 tick 一致")
	var exec_spotted := _events_of_kind(exec_events, "spotted")
	check(not exec_spotted.is_empty(), "监控摄像头：执行也触发 spotted")
	if not exec_spotted.is_empty():
		check(int(exec_spotted[0].get("tick", -1)) == preview.first_spotted, "监控摄像头：执行发现 tick 与预演相同")
		check(String(exec_spotted[0].get("detail", "")) == "camera", "监控摄像头：执行发现归因是 camera")
	museum.queue_free()


func _test_noise_investigate_equivalence() -> void:
	var museum := await _make_museum()
	var cop: Police = museum.police[0]

	var player_start := _cell_center(3, 2)
	var guard_pos := _cell_center(3, 6)
	museum.player.global_position = player_start
	cop.global_position = guard_pos
	cop._facing = Vector2.DOWN
	_scatter_other_guards(museum, 0)

	# 向下疾跑，脚步声传入听力范围；守卫在视野外，先调查再发现。
	# 到达后再等待若干 tick，让执行有足够时间产生调查事件。
	var target := _cell_center(3, 5)
	museum.planned_points = [target, target]
	museum._plan_node_actions = ["sprint", "wait"]

	var snap := museum._build_sim_snapshot()
	var route := museum._planned_sim_route()
	var preview := Sim.simulate_route(snap, route, 200, museum._build_sim_context())

	museum.execute_plan()
	var exec := await _capture_execution_trace(museum)
	var exec_trace: Array[String] = exec["trace"]
	var exec_events: Array = exec["events"]
	var preview_investigate := _events_of_kind(preview.events, "guard_investigate")
	var exec_investigate := _events_of_kind(exec_events, "guard_investigate")
	check(not preview_investigate.is_empty(), "噪音调查：预演触发守卫调查事件")
	check(exec_investigate.size() == preview_investigate.size(), "噪音调查：执行与预演调查事件数相同（%d == %d）" % [exec_investigate.size(), preview_investigate.size()])
	if exec_investigate.size() == preview_investigate.size() and not preview_investigate.is_empty():
		for i in preview_investigate.size():
			check(int(exec_investigate[i].get("tick", -1)) == int(preview_investigate[i].get("tick", -2)), "噪音调查：第 %d 个调查事件 tick 一致" % i)
			check(String(exec_investigate[i].get("id", "")) == String(preview_investigate[i].get("id", "")), "噪音调查：第 %d 个调查事件守卫 id 一致" % i)
	var preview_spotted := _first_event_kind(preview.events, "spotted")
	if preview_spotted != {}:
		check(_compare_trace("噪音调查", preview.trace, exec_trace, preview.first_spotted), "噪音调查：发现前逐 tick 一致")
		var exec_spotted := _first_event_kind(exec_events, "spotted")
		check(String(exec_spotted.get("detail", "")) == "guard", "噪音调查：发现归因与预演一致")
	museum.queue_free()


func _test_take_action_equivalence() -> void:
	var museum := await _make_museum()

	# 目标 mask 在 (9,18)，玩家站到相邻 (8,18)。
	var player_start := _cell_center(8, 18)
	museum.player.global_position = player_start
	var target := _cell_center(9, 18)
	museum.planned_points = [target]
	museum._plan_node_actions = ["take"]

	var snap := museum._build_sim_snapshot()
	var route := museum._planned_sim_route()
	var preview := Sim.simulate_route(snap, route, 200, museum._build_sim_context())

	museum.execute_plan()
	var exec := await _capture_execution_trace(museum)
	var exec_trace: Array[String] = exec["trace"]
	var exec_events: Array = exec["events"]
	var preview_taken := _first_event_kind(preview.events, "target_taken")
	check(preview_taken != {}, "拿取动作：预演触发 target_taken 事件")
	if preview_taken != {}:
		check(String(preview_taken.get("detail", "")) == "mask", "拿取动作：预演拿取目标是 mask")
	var exec_taken := _first_event_kind(exec_events, "target_taken")
	check(exec_taken != {}, "拿取动作：执行触发 target_taken 事件")
	if exec_taken != {}:
		check(int(exec_taken.get("tick", -1)) == int(preview_taken.get("tick", -2)), "拿取动作：执行拿取 tick 与预演相同")
		check(String(exec_taken.get("detail", "")) == "mask", "拿取动作：执行拿取目标是 mask")
	var has_mask := false
	for item in Game.bag_items:
		if String(item.get("id", "")) == "mask":
			has_mask = true
	check(has_mask, "拿取动作：执行后 mask 实际入包")
	var artifact_gone := true
	for child in museum.get_children():
		if child is Artifact and child.item_id == "mask":
			artifact_gone = false
	check(artifact_gone, "拿取动作：场景中 mask 文物已移除")
	check(_compare_trace("拿取动作", preview.trace, exec_trace, exec_trace.size()), "拿取动作：预演与执行逐 tick 一致")
	museum.queue_free()


## 双摄像头同时存在：首次发现实体 id 与预演/执行一致。
func _test_multi_camera_equivalence() -> void:
	var museum := await _make_museum()
	_scatter_other_guards(museum, -1)
	for x in [1, 2]:
		var cam := Node2D.new()
		cam.name = "cam_%d" % x
		cam.global_position = _cell_center(x, 5)
		museum.add_child(cam)
		museum._bm_cameras.append(cam)
	museum._bm_time = 0.0
	museum.player.global_position = _cell_center(5, 5)
	museum.planned_points = [_cell_center(5, 7)]
	museum._plan_node_actions = ["wait"]
	var snap := museum._build_sim_snapshot()
	var route := museum._planned_sim_route()
	var context := museum._build_sim_context()
	var preview := Sim.simulate_route(snap, route, 120, context)
	museum.execute_plan()
	var exec := await _capture_execution_trace(museum)
	var preview_event := _first_event_kind(preview.events, "spotted")
	var exec_event := _first_event_kind(exec["events"], "spotted")
	check(not preview_event.is_empty(), "双摄像头：预演触发发现")
	check(not exec_event.is_empty(), "双摄像头：执行触发发现")
	if not preview_event.is_empty() and not exec_event.is_empty():
		check(String(preview_event.get("detail", "")) == "camera", "双摄像头：归因为 camera")
		check(String(preview_event.get("id", "")) == String(exec_event.get("id", "")), "双摄像头：首次发现实体 id 一致")
		check(int(preview_event.get("tick", -1)) == int(exec_event.get("tick", -2)), "双摄像头：首次发现 tick 一致")
	check(_compare_trace("双摄像头", preview.trace, exec["trace"], preview.first_spotted), "双摄像头：发现前逐 tick 一致")
	museum.queue_free()


## 30/60/120 物理帧率下，固定 tick 真实执行轨迹与事件一致；
## 固定物理 60 时，渲染 max_fps=30 也不影响规则状态。
func _test_frame_rate_equivalence() -> void:
	var traces: Array = []
	var events_list: Array = []
	var configs := [
		{"physics": 30, "max_fps": 0, "label": "物理 30"},
		{"physics": 60, "max_fps": 0, "label": "物理 60"},
		{"physics": 120, "max_fps": 0, "label": "物理 120"},
		{"physics": 60, "max_fps": 30, "label": "渲染 30fps"},
	]
	for cfg in configs:
		Engine.physics_ticks_per_second = int(cfg["physics"])
		Engine.max_fps = int(cfg["max_fps"])
		var museum := await _make_museum()
		_scatter_other_guards(museum, -1)
		# 快照里的实体 id 来自节点名；跨 museum 实例比较时统一为稳定名，
		# 避免 Godot 自动生成名（@CharacterBody2D@123）造成假差异。
		for gi in museum.police.size():
			museum.police[gi].name = "guard_%d" % gi
		for ci in museum._bm_cameras.size():
			museum._bm_cameras[ci].name = "camera_%d" % ci
		# 统一起始世界时间与守卫计时，避免不同 fps 的等待帧数污染起点。
		museum._bm_time = 0.0
		for cop in museum.police:
			cop._wait_timer = 0.0
			cop._spot_timer = 0.0
			cop._investigate_timer = 0.0
			cop._blind_timer = 0.0
		museum.player.global_position = _cell_center(5, 5)
		museum.planned_points = [_cell_center(5, 7)]
		museum._plan_node_actions = ["wait"]
		museum.execute_plan()
		var exec := await _capture_execution_trace(museum)
		traces.append(exec["trace"])
		events_list.append(exec["events"])
		museum.queue_free()
		await get_tree().process_frame
	Engine.physics_ticks_per_second = 60
	Engine.max_fps = 0
	check(traces.size() == 4, "帧率：物理 30/60/120 + 渲染 30fps 共四次执行")
	check(str(traces[0]) == str(traces[1]) and str(traces[1]) == str(traces[2]), "帧率：30/60/120 逐 tick 轨迹一致")
	check(str(events_list[0]) == str(events_list[1]) and str(events_list[1]) == str(events_list[2]), "帧率：30/60/120 事件一致")
	check(str(traces[3]) == str(traces[1]), "帧率：渲染 max_fps=30 不改变逐 tick 轨迹")
	check(str(events_list[3]) == str(events_list[1]), "帧率：渲染 max_fps=30 不改变事件")


## 手动接管：取消执行立即恢复守卫 AI，旧预测清空；再次规划从新快照开始，不沿用旧轨迹。
func _test_manual_takeover_invalidates_preview() -> void:
	var museum := await _make_museum()
	_scatter_other_guards(museum, -1)
	var p: Player = museum.player
	p.global_position = _cell_center(5, 5)
	museum.planned_points = [_cell_center(5, 7)]
	museum._plan_node_actions = ["wait"]
	museum.run_preview()
	check(museum._preview_active, "接管：预演已激活")
	# 模拟接管前守卫 AI 处于开启状态，取消执行必须恢复该状态。
	museum.police[0].set_ai_enabled(true)
	museum.execute_plan()
	for i in 4:
		await get_tree().physics_frame
	museum.cancel_plan()
	await get_tree().physics_frame
	check(not museum.executing_plan, "接管：取消执行")
	check(not museum._preview_active, "接管：旧预演轨迹清空")
	check(not museum._run_start_snapshot.is_empty(), "接管：保留重试快照")
	check(museum.police[0].ai_enabled, "接管：守卫 AI 恢复")
	# 新位置重新规划，首帧轨迹应从新位置开始，而不是旧预演缓存。
	p.global_position = _cell_center(9, 5)
	museum.planned_points = [_cell_center(9, 6)]
	museum._plan_node_actions = [""]
	museum.toggle_planning_mode(true)
	museum.run_preview()
	check(museum._preview_active and not museum._preview_cells.is_empty(), "接管：新规划生成预演")
	if not museum._preview_cells.is_empty():
		var first_cell: Vector2i = museum._preview_cells[0]
		check(absi(first_cell.x - 9) <= 1, "接管：新预演从新位置开始（首格 %s）" % str(first_cell))
	museum.toggle_planning_mode(false)
	museum.queue_free()


## 多守卫：两名守卫同时可能发现时，预演与真实执行的首次发现 tick/实体一致。
func _test_multi_guard_equivalence() -> void:
	var museum := await _make_museum()
	var player_start := _cell_center(5, 5)
	museum.player.global_position = player_start
	var cop0: Police = museum.police[0]
	var cop1: Police = museum.police[1]
	cop0.global_position = _cell_center(5, 3)
	cop0._facing = Vector2.DOWN
	cop1.global_position = _cell_center(3, 5)
	cop1._facing = Vector2.RIGHT
	for i in range(2, museum.police.size()):
		museum.police[i].global_position = _cell_center(17, 9)
	museum.planned_points = [_cell_center(5, 7)]
	museum._plan_node_actions = ["wait"]
	var snap := museum._build_sim_snapshot()
	var route := museum._planned_sim_route()
	var context := museum._build_sim_context()
	var preview := Sim.simulate_route(snap, route, 120, context)
	museum.execute_plan()
	var exec := await _capture_execution_trace(museum)
	var exec_trace: Array[String] = exec["trace"]
	var preview_spotted := _first_event_kind(preview.events, "spotted")
	check(not preview_spotted.is_empty(), "多守卫：预演触发发现")
	var exec_spotted := _first_event_kind(exec["events"], "spotted")
	check(not exec_spotted.is_empty(), "多守卫：执行触发发现")
	if not preview_spotted.is_empty() and not exec_spotted.is_empty():
		check(int(preview_spotted.get("tick", -1)) == int(exec_spotted.get("tick", -2)), "多守卫：首次发现 tick 一致")
		check(String(preview_spotted.get("id", "")) == String(exec_spotted.get("id", "")), "多守卫：首次发现实体 id 一致")
	check(_compare_trace("多守卫", preview.trace, exec_trace, preview.first_spotted), "多守卫：发现前逐 tick 一致")
	museum.queue_free()


## G20261121-05：精确回退（非整格）、守卫计时同步、结束/接管后仍保留合法重试快照。
func _test_full_snapshot_exact_state() -> void:
	var museum := await _make_museum()
	_scatter_other_guards(museum, -1)
	var p: Player = museum.player
	var exact := Vector2(57.25, 41.75)
	p.global_position = exact
	var cop: Police = museum.police[0]
	cop._spot_timer = 0.35
	cop._wait_timer = 0.45
	var snap := museum._build_sim_snapshot()
	museum.planned_points = [_cell_center(8, 18)]
	museum._plan_node_actions = [""]
	museum.execute_plan()
	for i in 8:
		await get_tree().physics_frame
	museum.cancel_plan()
	await get_tree().physics_frame
	check(not museum._run_start_snapshot.is_empty(), "G05：结束/接管后保留重试快照")
	museum._restore_full_snapshot(snap)
	await get_tree().physics_frame
	check(p.global_position.is_equal_approx(exact), "G05：玩家回退到精确坐标（实际 %s）" % str(p.global_position))
	check(is_equal_approx(cop._spot_timer, 0.35), "G05：守卫 _spot_timer 精确恢复（实际 %.3f）" % cop._spot_timer)
	check(is_equal_approx(cop._wait_timer, 0.45), "G05：守卫 _wait_timer 精确恢复（实际 %.3f）" % cop._wait_timer)
	museum.queue_free()


## 完整快照覆盖全部守卫/摄像头：每个实体的位置、朝向、计时、AI 状态与装饰时间逐项恢复。
func _test_full_snapshot_all_entities() -> void:
	var museum := await _make_museum()
	for ci in 2:
		var cam := Node2D.new()
		cam.name = "camera_%d" % ci
		cam.global_position = _cell_center(ci + 1, 5)
		museum.add_child(cam)
		museum._bm_cameras.append(cam)
	museum._bm_time = 1.25
	var expected: Array = []
	for i in museum.police.size():
		var cop: Police = museum.police[i]
		cop.name = "guard_%d" % i
		cop.global_position = _cell_center(3 + i, 12)
		cop._facing = Vector2.DOWN if i % 2 == 0 else Vector2.RIGHT
		cop._wait_timer = 0.1 * float(i + 1)
		cop._investigate_timer = 0.05 * float(i + 1)
		cop._spot_timer = 0.01 * float(i + 1)
		cop._blind_timer = 0.02 * float(i + 1)
		cop._patrol_index = i
		cop.set_ai_enabled(i % 2 == 0)
		expected.append({
			"pos": cop.global_position,
			"facing": cop._facing,
			"wait": cop._wait_timer,
			"investigate": cop._investigate_timer,
			"spot": cop._spot_timer,
			"blind": cop._blind_timer,
			"wp": cop._patrol_index,
			"ai": cop.ai_enabled,
		})
	var snap := museum._build_sim_snapshot()
	check(snap.get("guards", []).size() == museum.police.size(), "全快照：包含全部 %d 名守卫" % museum.police.size())
	check(snap.get("cameras", []).size() == 2, "全快照：包含全部 2 个摄像头")
	var phases: Array[float] = []
	for c in snap.get("cameras", []):
		phases.append(float(c.get("phase", 0.0)))

	# 打乱全部实体与时间，再回退。
	museum._bm_time = 9.0
	museum.player.global_position = _cell_center(1, 1)
	for i in museum.police.size():
		var cop: Police = museum.police[i]
		cop.global_position = _cell_center(17, 9)
		cop._facing = Vector2.UP
		cop._wait_timer = 3.0
		cop._investigate_timer = 2.0
		cop._spot_timer = 1.0
		cop._blind_timer = 0.5
		cop._patrol_index = 0
		cop.set_ai_enabled(not cop.ai_enabled)
	museum._restore_full_snapshot(snap)
	# 回退是同步的；立即断言，避免下一物理帧 AI 正常推进造成假差异。
	check(is_equal_approx(museum._bm_time, 1.25), "全快照：装饰时间恢复（实际 %.3f）" % museum._bm_time)
	var all_ok := true
	for i in museum.police.size():
		var cop: Police = museum.police[i]
		var e: Dictionary = expected[i]
		var ok: bool = cop.global_position.is_equal_approx(e["pos"]) \
			and cop._facing.is_equal_approx(e["facing"]) \
			and is_equal_approx(cop._wait_timer, float(e["wait"])) \
			and is_equal_approx(cop._investigate_timer, float(e["investigate"])) \
			and is_equal_approx(cop._spot_timer, float(e["spot"])) \
			and is_equal_approx(cop._blind_timer, float(e["blind"])) \
			and int(cop._patrol_index) == int(e["wp"]) \
			and bool(cop.ai_enabled) == bool(e["ai"])
		if not ok:
			all_ok = false
			printerr("  全快照守卫 %d 未恢复：pos=%s facing=%s wait=%.3f inv=%.3f spot=%.3f blind=%.3f wp=%d ai=%s" % [i, str(cop.global_position), str(cop._facing), cop._wait_timer, cop._investigate_timer, cop._spot_timer, cop._blind_timer, cop._patrol_index, str(cop.ai_enabled)])
	check(all_ok, "全快照：全部守卫位置/朝向/计时/巡逻进度/AI 状态恢复")
	var again := museum._build_sim_snapshot()
	var camera_ok: bool = again.get("cameras", []).size() == phases.size()
	for ci in mini(phases.size(), again.get("cameras", []).size()):
		if not is_equal_approx(float(again["cameras"][ci].get("phase", 0.0)), phases[ci]):
			camera_ok = false
	check(camera_ok, "全快照：全部摄像头相位随装饰时间恢复")
	museum.queue_free()


## 实际 museum.run_preview + execute_plan 的墙阻挡上下文（不是两个独立 Sim 调用互比）。
func _test_preview_wall_context() -> void:
	var museum := await _make_museum()
	_scatter_other_guards(museum, -1)
	var p: Player = museum.player
	var pc := Vector2i(int(p.global_position.x / 16.0), int(p.global_position.y / 16.0))
	var blocked := Vector2i(-1, -1)
	for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		var c: Vector2i = pc + d
		if museum.is_cell_blocked(c.x, c.y):
			blocked = c
			break
	check(blocked.x >= 0, "预演墙阻挡：找到玩家旁的实心格")
	if blocked.x < 0:
		museum.queue_free()
		return
	p.global_position = _cell_center(pc.x, pc.y)
	museum.planned_points = [_cell_center(blocked.x, blocked.y)]
	museum._plan_node_actions = [""]
	museum.run_preview()
	await get_tree().process_frame
	check(museum._preview_active and not museum._preview_cells.is_empty(), "预演墙阻挡：实际 run_preview 生成轨迹")
	var preview_ok := true
	for cell in museum._preview_cells:
		if museum.is_cell_blocked(cell.x, cell.y):
			preview_ok = false
	check(preview_ok, "预演墙阻挡：轨迹不穿实心格")
	museum.execute_plan()
	var exec_cells: Array[Vector2i] = []
	for i in 20:
		await get_tree().physics_frame
		if museum._sim_snapshot.is_empty():
			break
		var ep: Dictionary = museum._sim_snapshot.get("player", {})
		if ep.has("pos"):
			exec_cells.append(Vector2i(ep["pos"]))
	var exec_ok := not exec_cells.is_empty()
	for cell in exec_cells:
		if museum.is_cell_blocked(cell.x, cell.y):
			exec_ok = false
	check(exec_ok, "预演墙阻挡：真实执行也不穿实心格")
	var overlap := mini(museum._preview_cells.size(), exec_cells.size())
	var same := true
	for i in overlap:
		if Vector2i(museum._preview_cells[i]) != exec_cells[i]:
			same = false
	check(same, "预演墙阻挡：实际预演与执行前 %d tick 位置一致" % overlap)
	museum.cancel_plan()
	museum.queue_free()


## 完整状态逐 tick：除摘要外，比较整个快照字典（移动 counter、玩家动作进度、
## 物品/噪音/烟雾/事件等全部字段），避免摘要遗漏字段造成假一致。
func _test_full_state_trace_equivalence() -> void:
	var museum := await _make_museum()
	_scatter_other_guards(museum, -1)
	museum.player.global_position = _cell_center(5, 5)
	museum.planned_points = [_cell_center(5, 7)]
	museum._plan_node_actions = ["wait"]
	var snap := museum._build_sim_snapshot()
	var route := museum._planned_sim_route()
	var context := museum._build_sim_context()
	museum.execute_plan()
	var exec := await _capture_execution_trace(museum)
	check(not museum.executing_plan, "完整状态：执行自然结束（未被 max_ticks 截断）")
	var exec_states: Array = exec["states"]
	var preview_states := _preview_full_states(snap, route, exec_states.size(), context)
	check(preview_states.size() == exec_states.size(), "完整状态：预演/执行 tick 数一致（P=%d E=%d）" % [preview_states.size(), exec_states.size()])
	var same := preview_states.size() == exec_states.size()
	for i in mini(preview_states.size(), exec_states.size()):
		if preview_states[i] != exec_states[i]:
			same = false
			printerr("  完整状态 tick %d 差异：\n    P=%s\n    E=%s" % [i, preview_states[i], exec_states[i]])
			break
	check(same, "完整状态：全部快照字段逐 tick 一致")
	museum.queue_free()


func _preview_full_states(snap: Dictionary, route: Array, ticks: int, context: Dictionary) -> Array[String]:
	var replay := Sim.copy_snapshot(snap)
	var replay_route: Array = route.duplicate(true)
	var idx := {"i": 0}
	var states: Array[String] = []
	for i in ticks:
		Sim.tick(replay, replay_route, idx, context)
		states.append(var_to_str(replay))
	return states


func _test_full_snapshot_restore() -> void:
	var museum := await _make_museum()

	var player_start := _cell_center(8, 18)
	museum.player.global_position = player_start
	museum.planned_points = [_cell_center(9, 18)]
	museum._plan_node_actions = ["take"]

	var start_snap := museum._build_sim_snapshot()
	# 放置一颗烟雾用于验证恢复。
	var smoke := _spawn_smoke(museum, _cell_center(4, 18))
	var smoke_time := smoke._t
	start_snap = museum._build_sim_snapshot()

	museum.execute_plan()
	# 执行若干 tick 后手动完整回退。
	for i in 10:
		await get_tree().physics_frame
	museum._restore_full_snapshot(start_snap)
	await get_tree().physics_frame

	check(museum.player.global_position.is_equal_approx(player_start), "完整快照：玩家位置恢复")
	check(museum.police[0].global_position.is_equal_approx(_cell_center(2, 2)), "完整快照：守卫位置恢复")
	var mask_back := false
	for child in museum.get_children():
		if child is Artifact and child.item_id == "mask":
			mask_back = true
	check(mask_back, "完整快照：目标文物重新出现")
	check(Game.bag_items.is_empty(), "完整快照：背包被清空回起始状态")
	check(Game.smoke_count == 1, "完整快照：烟雾弹数量恢复")
	var smoke_found := false
	for child in museum.get_children():
		if child is SmokePuffClass:
			smoke_found = true
	check(smoke_found, "完整快照：烟雾 puff 恢复")
	museum.queue_free()
