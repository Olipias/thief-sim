extends Node
## G11：真实鼠标验证节点动作，不以直接调用动作切换函数替代输入。
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS - " if ok else "FAIL - ") + label)
	if not ok:
		failures += 1

func click_world(museum: Node2D, at: Vector2) -> void:
	var screen: Vector2 = get_viewport().get_canvas_transform() * at
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = screen
	down.pressed = true
	get_viewport().push_input(down)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = screen
	up.pressed = false
	get_viewport().push_input(up)
	await get_tree().process_frame

func tap_space() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	await get_tree().process_frame
	key = InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = false
	Input.parse_input_event(key)
	await get_tree().process_frame
	await get_tree().process_frame

func _ready() -> void:
	Game.save_path = "/tmp/thief_g11_actions_save.json"
	Game.reset_progress()
	Game.current_level_id = "museum"
	Game.mission_target_id = "mask"
	var museum := preload("res://src/world/museum.tscn").instantiate()
	add_child(museum)
	await get_tree().physics_frame
	for cop in museum.police:
		cop.set_ai_enabled(false)
	museum.toggle_planning_mode(true)
	var point: Vector2 = museum.player.global_position
	await click_world(museum, point)
	check(museum.planned_points.size() == 1, "真实点击添加已知地面路点")
	if museum.planned_points.size() == 1:
		await tap_space()
		check(museum.planning_mode and not museum.executing_plan, "原地无动作路线保留规划，不能凭空推进模拟")
		check(museum._sim_snapshot.is_empty(), "无效空路线不创建执行快照")
		await click_world(museum, point)
		check(museum._plan_node_actions[0] == "wait", "点击路点选择等待")
		await click_world(museum, point)
		check(museum._plan_node_actions[0] == "crouch", "再次点击选择蹲行")
		await click_world(museum, point)
		check(museum._plan_node_actions[0] == "sprint", "普通地面跳过不适用开锁与拿取，能够选择疾跑")
		await click_world(museum, point)
		check(museum._plan_node_actions[0] == "", "疾跑后可返回普通移动")
		var target: Node2D
		for child in museum.get_children():
			if child is Artifact and child.item_id == "mask":
				target = child
				break
		check(target != null, "夹具存在任务物品")
		if target != null:
			target.global_position = point
			await click_world(museum, point)
			await click_world(museum, point)
			await click_world(museum, point)
			check(museum._plan_node_actions[0] == "take", "目标格跳过无效开锁后能够选择拿取")
			var route: Array = museum._planned_sim_route()
			check(not route.is_empty() and route.back().get("action") == "take", "真实输入的拿取动作进入执行时间轴")
			await click_world(museum, point)
			check(museum._plan_node_actions[0] == "sprint", "目标格拿取后仍能选择疾跑")
			# 再次循环到拿取，通过真实空格启动执行，确认不只是选项显示。
			for i in 4:
				await click_world(museum, point)
			check(museum._plan_node_actions[0] == "take", "第二轮循环仍能选择拿取")
			var key := InputEventKey.new()
			key.physical_keycode = KEY_SPACE
			key.pressed = true
			Input.parse_input_event(key)
			await get_tree().process_frame
			await get_tree().process_frame
			check(museum.executing_plan, "真实空格启动路线执行")
			key = InputEventKey.new()
			key.physical_keycode = KEY_SPACE
			key.pressed = false
			Input.parse_input_event(key)
			for i in 90:
				await get_tree().physics_frame
				if not museum.executing_plan:
					break
			var has_mask := false
			for item in Game.bag_items:
				if item.get("id", "") == "mask":
					has_mask = true
			check(has_mask, "真实空格执行拿取后目标实际入包")
	museum.queue_free()
	await get_tree().process_frame
	Audio.shutdown()
	await get_tree().create_timer(0.4, true).timeout
	print(("ALL %d CHECKS PASSED" if failures == 0 else "FAILED / %d checks") % checks)
	get_tree().quit(0 if failures == 0 else 1)
