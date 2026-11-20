extends Node
## 独立开场验收；完整test_input_flow也保留同样用例，避免标题调试影响本批核验。
var main: Main
var _checks := 0
var _failures := 0
func check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print(("PASS - " if ok else "FAIL - ") + message)

func _ready() -> void:
	Game.save_path = "/tmp/thief_sim_opening_cg_save.json"
	Game.reset_progress()
	main = load("res://src/main.tscn").instantiate() as Main
	add_child(main)
	await _frames(4)
	await _test_new_game_opening()
	Audio.shutdown()
	await get_tree().create_timer(0.4, true).timeout
	print("OPENING_CG: %d/%d PASSED" % [_checks - _failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)

func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _tap(code: int) -> void:
	_key(code, true)
	await _frames(2)
	_key(code, false)
	await _frames(2)


func _click(pos: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = pos
	Input.parse_input_event(move)
	await _frames(1)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = pos
	down.pressed = true
	Input.parse_input_event(down)
	await _frames(2)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = pos
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _skip_dialogue() -> void:
	var guard := 0
	while main.dialogue.is_active() and guard < 60:
		main.dialogue.advance()
		await _frames(1)
		guard += 1


func _test_new_game_opening() -> void:
	Game.reset_progress()
	main.show_title()
	await _frames(2)
	main._on_new_game()
	await _frames(3)
	var intro: ContractIntro
	for child in main.ui_layer.get_children():
		if child is ContractIntro:
			intro = child
	check(intro != null, "新游戏先播q6图片分镜")
	check(ContractIntro.PANEL_SECONDS == 5.0 and ContractIntro.PANELS.size() == 6, "六格每格5秒，自动总长30秒")
	if intro == null:
		return
	check(intro.panel_index == 0, "开场从第一格开始")
	await _tap(KEY_SPACE)
	check(intro.panel_index == 1, "真实Space推进一格")
	check(intro.elapsed < 0.5, "手动推进后重新开始5秒计时")
	var repeat := InputEventKey.new()
	repeat.physical_keycode = KEY_SPACE
	repeat.pressed = true
	repeat.echo = true
	Input.parse_input_event(repeat)
	await _frames(2)
	check(intro.panel_index == 1, "按住Space的重复事件不会连续跳格")
	_key(KEY_SPACE, false)
	intro.elapsed = ContractIntro.PANEL_SECONDS - 0.001
	await _frames(3)
	check(intro.panel_index == 2, "达到5秒自动切换下一格")
	await _click(Vector2(320, 180))
	check(intro.panel_index == 3, "真实鼠标点击画面推进一格")
	await _tap(KEY_E)
	check(intro.panel_index == 4, "E兼容推进一格")
	await _tap(KEY_B)
	check(not main.backpack.is_open(), "CG期间B不打开背包干扰播放")
	var completions := {"count": 0}
	intro.finished.connect(func() -> void: completions.count += 1)
	await _click(intro.skip_button.get_global_rect().get_center())
	await _frames(4)
	check(completions.count == 1, "真实Skip只发出一次结束信号")
	check(Game.story_flag("saw_p00"), "跳过演出后契约进度落档")
	check(main._museum != null and main._safehouse == null, "Skip直接进入教学而非栏目页")
	await _skip_dialogue()

	# 自动播完的同一入口也必须直连教学，而非只验证Skip。
	Game.reset_progress()
	main.show_title()
	await _frames(2)
	main._on_new_game()
	await _frames(3)
	for child in main.ui_layer.get_children():
		if child is ContractIntro:
			intro = child
	intro.panel_index = 5
	intro._refresh()
	intro.elapsed = ContractIntro.PANEL_SECONDS - 0.001
	await _frames(4)
	check(Game.story_flag("saw_p00"), "最后一格自动结束也落档")
	check(main._museum != null and main._safehouse == null, "自动播完直接进入教学")
	await _skip_dialogue()

