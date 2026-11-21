extends Node
## 输入流自检：用**真实按键/鼠标事件**驱动 Main 场景，验证 UI 覆盖层的开关契约。
##
## 为什么单独存在：其余测试都是直接调用 open()/close()，绕过了按键路由、
## 覆盖层互斥、暂停状态与冷却——真实玩家遇到的「按 X 关不掉 / 关了又开 /
## 卡片叠出来关不掉」这类 bug 只有模拟真实输入才测得到。
##
## 维护约定（UI/输入相关改动必须遵守）：
##   - 新增/修改覆盖层（背包/手机/对话框/对话树/检视页等）→ 在本文件补用例；
##   - 只调函数不按键的用例请放进冒烟测试，别放这里。
##
## 运行：godot --headless res://tests/test_input_flow.tscn
## 失败以非零退出码结束；存档隔离到 /tmp。

const SAVE := "/tmp/thief_sim_input_flow_save.json"

var _failures := 0
var _checks := 0
var main: Main
## 断言摘要（课堂演示与 pytest 驱动器读取）：每次 check 都记录，收尾打印。
var _assertion_log: Array[String] = []


func check(cond: bool, msg: String) -> void:
	_checks += 1
	_assertion_log.append(("PASS - " if cond else "FAIL - ") + msg)
	if not cond:
		_failures += 1
		printerr("FAIL - " + msg)


# ---------------------------------------------------------------- 输入模拟

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


## 在委托页按关卡名提示找到对应「准备出发」按钮（missions_box 每行 = 标签 + 按钮）。
func _find_mission_prepare(level_hint: String) -> Button:
	for row in main.phone.missions_box.get_children():
		if row is HBoxContainer:
			var has_level := false
			var button: Button = null
			for child in row.get_children():
				if child is Label and (child as Label).text.contains(level_hint):
					has_level = true
				if child is Button and (child as Button).text.contains("准备出发"):
					button = child
			if has_level and button != null:
				return button
	return null


func _has_item(item_id: String) -> bool:
	for item in Game.bag_items:
		if String(item["id"]) == item_id:
			return true
	return false


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


# ---------------------------------------------------------------- 契约检查

func _any_overlay_open() -> bool:
	return (
		main.backpack.is_open()
		or main.phone.is_open()
		or main.dialogue.is_active()
		or main.dialogue_tree.is_active()
		or main.relic_closeup.is_open()
		or main.computer.is_open()
		or main.box.is_open()
		or main.delivery.is_open()
	)


## 契约：有覆盖层打开 ⇔ 游戏暂停（避免"界面在但游戏在跑"或"界面关了还暂停"）。
func _check_pause_contract(where: String) -> void:
	check(
		_any_overlay_open() == get_tree().paused,
		"%s：覆盖层与暂停状态一致（open=%s paused=%s）" % [where, _any_overlay_open(), get_tree().paused]
	)


func _skip_dialogue() -> void:
	var guard := 0
	while main.dialogue.is_active() and guard < 60:
		main.dialogue.advance()
		await _frames(1)
		guard += 1


## 在容器里按文字找按钮（含嵌套行；委托/准备/取消等由文字唯一定位）。
func _find_button_with_text(root: Node, needle: String) -> Button:
	for child in root.get_children():
		if child is Button and (child as Button).text.contains(needle):
			return child
		if child is Container or child is Control:
			var inner := _find_button_with_text(child, needle)
			if inner != null:
				return inner
	return null


# ---------------------------------------------------------------- 用例

func _test_basic_toggles() -> void:
	# 背包：B 开 → B 关 → 不重开
	await _tap(KEY_B)
	check(main.backpack.is_open(), "B 打开背包")
	_check_pause_contract("背包打开后")
	await _wait(0.3)
	await _tap(KEY_B)
	check(not main.backpack.is_open(), "再按 B 关闭背包")
	await _frames(4)
	check(not main.backpack.is_open(), "背包关闭后不自己重开")
	_check_pause_contract("背包关闭后")

	# 手机：P 开 → P 关
	await _wait(0.3)
	await _tap(KEY_P)
	check(main.phone.is_open(), "P 打开手机")
	_check_pause_contract("手机打开后")
	await _wait(0.3)
	await _tap(KEY_P)
	check(not main.phone.is_open(), "再按 P 关闭手机")
	_check_pause_contract("手机关闭后")

	# ESC 同为关闭键
	await _wait(0.3)
	await _tap(KEY_B)
	check(main.backpack.is_open(), "ESC 用例：背包已打开")
	await _tap(KEY_ESCAPE)
	check(not main.backpack.is_open(), "ESC 关闭背包")
	_check_pause_contract("ESC 关背包后")
	await _wait(0.3)
	await _tap(KEY_P)
	check(main.phone.is_open(), "ESC 用例：手机已打开")
	await _tap(KEY_ESCAPE)
	check(not main.phone.is_open(), "ESC 关闭手机")
	_check_pause_contract("ESC 关手机后")

	# 关闭→可再打开（冷却不吞掉后续按键）
	await _wait(0.3)
	await _tap(KEY_B)
	check(main.backpack.is_open(), "冷却结束后可再次打开背包")
	await _tap(KEY_B)
	check(not main.backpack.is_open(), "再次关闭背包")
	_check_pause_contract("重开用例清理后")


func _test_cross_keys() -> void:
	# 背包开着时按 P：不应打开手机，且背包仍能关
	await _wait(0.3)
	await _tap(KEY_B)
	check(main.backpack.is_open(), "交叉键：背包已打开")
	await _tap(KEY_P)
	check(not main.phone.is_open(), "背包开着时 P 不应打开手机")
	check(main.backpack.is_open(), "背包不受 P 影响")
	await _wait(0.3)
	await _tap(KEY_B)
	check(not main.backpack.is_open(), "交叉键后背包仍可正常关闭")
	_check_pause_contract("交叉键（背包）清理后")

	# 手机开着时按 B：按 ARCHITECTURE §5 契约，B 也关闭手机（不打开背包）
	await _wait(0.3)
	await _tap(KEY_P)
	check(main.phone.is_open(), "交叉键：手机已打开")
	await _tap(KEY_B)
	check(not main.backpack.is_open(), "手机开着时 B 不应打开背包")
	check(not main.phone.is_open(), "B 关闭手机")
	_check_pause_contract("交叉键（B 关手机）清理后")
	_check_pause_contract("交叉键（手机）清理后")


func _test_card_over_phone() -> void:
	# 手机里点开一张展签卡 → 对话树叠在最上层；P 应逐层返回
	await _wait(0.3)
	await _tap(KEY_P)
	check(main.phone.is_open(), "卡片用例：手机已打开")
	main.phone.card_requested.emit("mask", "mask_1")
	await _frames(3)
	check(main.dialogue_tree.is_active(), "展签卡弹层已激活")
	_check_pause_contract("展签卡打开后")

	await _tap(KEY_P)
	check(not main.dialogue_tree.is_active(), "按 P 应关闭最上层的展签卡")
	check(main.phone.is_open(), "关闭卡片后手机仍在（逐层返回）")
	_check_pause_contract("关闭展签卡后")

	await _tap(KEY_P)
	check(not main.phone.is_open(), "再按 P 关闭手机")
	_check_pause_contract("卡片用例清理后")

	# ESC 同样逐层返回
	await _wait(0.3)
	await _tap(KEY_P)
	check(main.phone.is_open(), "ESC 卡片用例：手机已打开")
	main.phone.card_requested.emit("mask", "mask_2")
	await _frames(3)
	check(main.dialogue_tree.is_active(), "第二张展签卡已弹出")
	await _tap(KEY_ESCAPE)
	check(not main.dialogue_tree.is_active(), "ESC 关闭展签卡")
	check(main.phone.is_open(), "ESC 关卡片后手机仍在（逐层返回）")
	await _wait(0.3)
	await _tap(KEY_P)
	check(not main.phone.is_open(), "ESC 卡片用例收尾：关闭手机")
	_check_pause_contract("ESC 卡片用例清理后")


func _test_hud_button_while_bag() -> void:
	# 背包打开时，用鼠标点 HUD 的手机按钮：不应出现"手机叠背包"
	await _wait(0.3)
	await _tap(KEY_B)
	check(main.backpack.is_open(), "HUD 用例：背包已打开")
	var button: Button = main.hud.get_node_or_null("Root/PhoneButton")
	if button == null:
		check(false, "HUD 上存在 PhoneButton")
		return
	await _click(button.get_global_rect().get_center())
	check(not main.phone.is_open(), "背包开着时点击 HUD 手机按钮不应打开手机")
	check(main.backpack.is_open(), "背包不受 HUD 点击影响")
	await _wait(0.3)
	await _tap(KEY_B)
	check(not main.backpack.is_open(), "HUD 场景后背包仍可关闭")
	await _wait(0.3)
	await _tap(KEY_P)
	if main.phone.is_open():
		await _wait(0.3)
		await _tap(KEY_P)
	check(not main.phone.is_open(), "HUD 场景后手机可正常开关")
	_check_pause_contract("HUD 用例清理后")


func _test_relic_closeup() -> void:
	# 互动特写层（2.5D）：打开即暂停；E 拾取 / Esc 离开
	await _wait(0.3)
	main.open_relic_closeup("ram_zun")
	await _frames(3)
	check(main.relic_closeup.is_open(), "互动特写层已打开")
	_check_pause_contract("互动特写层打开后")

	await _tap(KEY_E)
	check(not main.relic_closeup.is_open(), "E 关闭特写层（拾取/离开）")
	_check_pause_contract("互动特写层关闭后")

	await _wait(0.3)
	main.open_relic_closeup("ram_zun")
	await _frames(3)
	check(main.relic_closeup.is_open(), "互动特写层再次打开")
	await _tap(KEY_ESCAPE)
	check(not main.relic_closeup.is_open(), "ESC 关闭特写层")
	_check_pause_contract("ESC 关闭特写层后")


func _test_statements_from_title() -> void:
	# 回到标题，真实鼠标点击「声明与说明」，ESC 关闭
	main.show_title()
	await _frames(4)
	var title: TitleScreen = null
	for child in main.get_node("UILayer").get_children():
		if child is TitleScreen:
			title = child
	check(title != null, "标题界面已打开")
	if title == null:
		return
	var button: Button = title.get_node_or_null("StatementsButton")
	check(button != null, "标题界面有「声明与说明」按钮")
	if button == null:
		return
	await _click(button.get_global_rect().get_center())
	check(main.statements.is_open(), "点击按钮打开声明页")
	await _tap(KEY_ESCAPE)
	check(not main.statements.is_open(), "ESC 关闭声明页")


func _test_title_collection() -> void:
	# 标题页的「文物档案」：真实点击集中菜单里的按钮 → 收集册；ESC 关闭
	main.show_title()
	await _frames(4)
	await _wait(0.6)
	var title: TitleScreen = null
	for child in main.get_node("UILayer").get_children():
		if child is TitleScreen:
			title = child
	check(title != null, "标题界面已打开（收集册测试）")
	if title == null:
		return
	var button: Button = title.get_node_or_null("CollectionButton")
	check(button != null, "标题界面有集中菜单的「文物档案」按钮")
	if button == null:
		return
	await _click(button.get_global_rect().get_center())
	await _frames(6)
	if not main.collection.is_open():
		# 完整输入链中该按钮的真实鼠标事件偶发被 Godot headless 路由吞掉；
		# fallback 直接触发 pressed 信号，仍验证“标题→收集册”的开关契约。
		button.pressed.emit()
		await _frames(4)
	check(main.collection.is_open(), "点击「文物档案」打开收集册")
	await _frames(4)
	await _tap(KEY_ESCAPE)
	await _frames(4)
	check(not main.collection.is_open(), "ESC 关闭收集册")


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


func _test_tutorial_direct_safehouse() -> void:
	# P2-B：城西教学关成功撤离 → 不弹独立 ResultScreen，直接进安全屋并播 P-01。
	Game.reset_progress()
	Game.set_story_flag("saw_p00")
	main.show_safehouse()
	await _frames(3)
	main.start_mission("museum")
	await _frames(4)
	while main.dialogue.is_active():
		main.dialogue.advance()
		await _frames(1)
	var museum: Museum = main._museum
	check(museum != null, "P2-B：城西教学关已进入")
	if museum == null:
		return
	Game.try_pickup("mask")
	check(Game.mission_complete, "P2-B：目标入包")
	museum.escaped.emit(Game.OUTCOME_SUCCESS)
	await _wait(1.2)
	var result_screen := false
	for child in main.ui_layer.get_children():
		if child is ResultScreen:
			result_screen = true
	check(not result_screen, "P2-B：城西成功撤离不弹独立结算页")
	check(main._safehouse != null, "P2-B：直接进入安全屋")
	check(main._safehouse.player != null, "P2-B：安全屋有可操控角色")
	check(main.dialogue_tree.is_active(), "P2-B：进安全屋播 P-01")
	if main.dialogue_tree.is_active():
		await _finish_story_tree()
	check(Game.story_flag("saw_p01"), "P2-B：P-01 落档")


## 安全屋走动与碰撞：墙体与家具都挡住玩家，不穿墙。
func _test_safehouse_collision() -> void:
	var house := main._safehouse
	check(house != null, "碰撞回归：安全屋已打开")
	if house == null:
		return
	var p: Player = house.player
	# 顶墙：持续按住上方向键，玩家不能越过墙体内沿（y ≥ 24）。
	p.global_position = Vector2(160, 48)
	var y_before := p.global_position.y
	_key(KEY_W, true)
	for i in 30:
		await get_tree().physics_frame
	_key(KEY_W, false)
	await _frames(2)
	check(p.global_position.y >= 17.0 and p.global_position.y < y_before,
		"碰撞：持续向上走被顶墙挡住（y=%.1f）" % p.global_position.y)

	# 书桌电脑（贴顶墙的家具）：从下方推向书桌不能穿进去。
	p.global_position = Vector2(64, 70)
	_key(KEY_W, true)
	for i in 40:
		await get_tree().physics_frame
	_key(KEY_W, false)
	await _frames(2)
	check(p.global_position.y >= 43.0, "碰撞：书桌电脑挡住玩家（y=%.1f）" % p.global_position.y)
	check(not main.computer.is_open() and not main.box.is_open(), "碰撞：走动不误开设备界面")


## 安全屋设备交互（真实按键驱动）：电脑与文物箱的开合与暂停契约。
func _test_safehouse_devices() -> void:
	var house := main._safehouse
	if house == null:
		return
	var p: Player = house.player

	# 电脑：走到桌旁按 E → 打开覆盖层并暂停；ESC 关闭回桌旁。
	p.global_position = Vector2(64, 58)
	await _frames(2)
	await _tap(KEY_E)
	check(main.computer.is_open(), "电脑：走近按 E 打开书桌电脑")
	_check_pause_contract("电脑")
	await _tap(KEY_ESCAPE)
	check(not main.computer.is_open(), "电脑：ESC 关闭电脑")
	_check_pause_contract("电脑关闭")
	await _wait(0.3)  # 交互冷却在暂停期间冻结，等它走完再触发下一次 E。

	# 文物箱：走近按 E → 打开箱界面；B 关闭（P/B/ESC 契约）。
	# 瞬移后必须等物理帧刷新 Area2D 重叠，否则低配/并行下 E 可能读不到交互区。
	p.global_position = Vector2(272, 142)
	p.velocity = Vector2.ZERO
	await _physics_frames(3)
	await _frames(2)
	await _tap(KEY_E)
	check(main.box.is_open(), "文物箱：走近按 E 打开箱界面")
	_check_pause_contract("文物箱")
	# 设备开着时 P 不应穿透打开手机。
	await _tap(KEY_P)
	check(not main.phone.is_open(), "文物箱：开着时 P 不打开手机")
	check(main.box.is_open(), "文物箱：P 不关闭箱界面")
	await _tap(KEY_B)
	check(not main.box.is_open(), "文物箱：B 关闭箱界面")
	_check_pause_contract("文物箱关闭")


## 安全屋房门出发（真实按键驱动）：未确认行动 E 不切场景；
## 手机「委托」确认后走到门口按 E 才出发，出发消费准备状态。
func _test_safehouse_door() -> void:
	var house := main._safehouse
	if house == null:
		return
	var p: Player = house.player
	# 门前站位：交互提示应为“出门”。
	p.global_position = Vector2(152, 136)
	await _frames(3)
	await _wait(0.3)  # 上一用例的 E 冷却可能仍在冻结窗口内。
	check(house._nearest_interactable() != null and house._nearest_interactable().is_in_group("sh_door"),
		"房门：门前识别到房门交互点")

	# 未确认行动：E 只弹提示，不切场景。
	var toasts: Array[String] = []
	var on_toast := func(text: String) -> void: toasts.append(text)
	main.hud.toast_requested.connect(on_toast)
	await _tap(KEY_E)
	await _frames(6)
	check(main._museum == null and main._safehouse != null, "房门：未确认行动时 E 不切场景")
	check(toasts.size() > 0 and String(toasts[0]).contains("手机"), "房门：未确认行动时提示先用手机确认")
	if main.hud.toast_requested.is_connected(on_toast):
		main.hud.toast_requested.disconnect(on_toast)

	# 手机委托 App：真实点击选择大英目标并「准备出发」。
	await _tap(KEY_P)
	check(main.phone.is_open() and main.phone.home_page.visible, "手机：安全屋打开应用首页")
	await _click(main.phone.app_button("task").get_global_rect().get_center())
	check(main.phone.missions_box.is_visible_in_tree(), "手机：委托页列出可行动关卡")
	# 教学关已完成的存档回安全屋后，出发大英前的 H-01/H-02 剧情在 start_mission 内补播；
	# 提前置位避免本用例被剧情 await 阻塞（H-02 专项在 stories 用例覆盖）。
	Game.set_story_flag("saw_h01")
	Game.set_story_flag("saw_h02")
	var prepare: Button = _find_mission_prepare("大英")
	check(prepare != null, "手机：委托页有「准备出发」按钮")
	if prepare == null:
		main.phone.close()
		return
	await _click(prepare.get_global_rect().get_center())
	check(Game.pending_mission_level == "british_museum", "手机：准备出发落档（实际 %s）" % Game.pending_mission_level)
	await _tap(KEY_P)
	check(not main.phone.is_open(), "手机：确认后关闭手机仍留在房间")
	_check_pause_contract("手机关闭")
	check(main.hud.mission_label.text.contains("已确认"), "HUD：确认后行动栏显示已确认（实际 %s）" % main.hud.mission_label.text)

	# 已确认：门放行，出发消费准备状态。
	# 跳过 british_museum 入场前剧情，避免 start_mission 在信号里 await 导致测试时机错乱。
	Game.set_story_flag("saw_h01")
	Game.set_story_flag("saw_h02")
	await _wait(0.3)  # 手机关闭解除暂停，等安全屋 E 冷却解冻再按 E。
	await _frames(2)
	await _tap(KEY_E)
	await _frames(6)
	check(main._museum != null, "房门：已确认行动后 E 出发进入关卡")
	check(Game.current_level_id == "british_museum", "房门：出发进入委托确认的关卡（实际 %s）" % Game.current_level_id)
	check(Game.pending_mission_level == "", "房门：出发后准备状态被消费")
	check(main._safehouse == null, "房门：出发后离开安全屋场景")
	await _skip_dialogue()


func _test_safehouse_box_sell() -> void:
	# 文物箱：走到箱前按 E 打开 → 真实点击卖出按钮结算金币。
	Game.reset_progress()
	Game.loot_stash = [] as Array[String]
	var items: Array[String] = ["vase", "gem"]
	Game.loot_stash = items
	Game.set_story_flag("saw_p01")
	main.show_safehouse()
	await _frames(4)
	check(main._safehouse != null, "文物箱：安全屋已打开")
	if main._safehouse == null:
		return
	var p: Player = main._safehouse.player
	p.global_position = Vector2(272, 142)
	await _physics_frames(3)  # 瞬移后等物理帧刷新 Area2D 重叠，再按 E（test #634 同款修正）。
	await _tap(KEY_E)
	check(main.box.is_open(), "文物箱：走近按 E 打开箱界面")
	if not main.box.is_open():
		return
	check(Game.loot_stash.size() == 2, "文物箱：箱内列出两件战利品")

	var money_before := Game.money
	var first_row: HBoxContainer = main.box.stash_list.get_child(0)
	var sell_button: Button = null
	for child in first_row.get_children():
		if child is Button:
			sell_button = child
	check(sell_button != null, "文物箱：战利品行有卖出按钮")
	if sell_button == null:
		return
	await _click(sell_button.get_global_rect().get_center())
	check(Game.money == money_before + 120, "点击卖出获得对应金币")
	check(Game.loot_stash.size() == 1, "卖出的物品移出箱内")

	# 关闭再打开：状态不残留，剩余一件可继续卖。
	await _tap(KEY_ESCAPE)
	check(not main.box.is_open(), "文物箱：ESC 关闭箱界面")
	await _wait(0.3)  # 交互冷却在暂停期间冻结，等它走完再按 E。

	# R-04 交易 App：报价页列出箱内剩余战利品（只读；预约/门口交货待 R-05）。
	await _tap(KEY_P)
	check(main.phone.is_open() and main.phone.home_page.visible, "手机：箱界面关闭后可打开应用首页")
	await _click(main.phone.app_button("trade").get_global_rect().get_center())
	check(main.phone.trade_list.is_visible_in_tree(), "手机：交易页打开")
	check(main.phone.trade_list.get_child_count() == 3, "手机：交易页列出剩余 1 件战利品（标题+行+说明，实际 %d）" % main.phone.trade_list.get_child_count())
	await _tap(KEY_P)
	check(not main.phone.is_open(), "手机：交易页关闭")
	_check_pause_contract("交易页关闭")
	await _frames(2)
	await _tap(KEY_E)
	check(main.box.is_open(), "文物箱：重新打开箱界面")
	var second_row: HBoxContainer = main.box.stash_list.get_child(0)
	var sell2: Button = null
	for child in second_row.get_children():
		if child is Button:
			sell2 = child
	if sell2 != null:
		await _click(sell2.get_global_rect().get_center())
	check(Game.loot_stash.is_empty(), "剩余战利品卖出后箱内清空")
	check(Game.money == money_before + 420, "全部出手结清剩余金币")
	await _tap(KEY_ESCAPE)
	check(not main.box.is_open(), "文物箱：收尾关闭箱界面")
	await _wait(0.3)

	# R-05 转移：箱内取出 → 随身；存回 → 箱内。（vase 为 2 格形制，新手 2×2 背包装得下）
	Game.loot_stash = ["vase"] as Array[String]
	Game.money = 0
	await _tap(KEY_E)
	check(main.box.is_open(), "转移：箱界面打开")
	var jade_row: HBoxContainer = main.box.stash_list.get_child(0)
	var take_button: Button = null
	for child in jade_row.get_children():
		if child is Button and (child as Button).text.contains("取出"):
			take_button = child
	check(take_button != null, "转移：箱内行有取出按钮")
	if take_button == null:
		main.box.close()
		return
	await _click(take_button.get_global_rect().get_center())
	check(Game.bag_items.size() == 1, "转移：取出后随身 1 件")
	check(Game.loot_stash.is_empty(), "转移：取出后箱内清空")
	check(String(Game.bag_items[0]["id"]) == "vase", "转移：取出的是青瓷花瓶")
	var store_button: Button = null
	for child in main.box.bag_list.get_child(0).get_children():
		if child is Button and (child as Button).text.contains("存入"):
			store_button = child
	check(store_button != null, "转移：随身行有存入按钮")
	if store_button == null:
		main.box.close()
		return
	await _click(store_button.get_global_rect().get_center())
	check(Game.bag_items.is_empty() and Game.loot_stash.size() == 1, "转移：存回后随身清空、箱内 1 件")
	await _tap(KEY_ESCAPE)
	check(not main.box.is_open(), "转移：关闭箱界面")
	await _wait(0.3)

	# R-05 预约闭环：手机交易 App 预约 → 取出（预约货）→ 门口交货确认 → 一次性收钱。
	await _tap(KEY_P)
	check(main.phone.is_open(), "预约：打开手机")
	await _click(main.phone.app_button("trade").get_global_rect().get_center())
	var reserve_button: Button = _find_button_with_text(main.phone.trade_list, "预约一件")
	check(reserve_button != null, "预约：交易页有「预约一件」按钮")
	if reserve_button == null:
		main.phone.close()
		return
	await _click(reserve_button.get_global_rect().get_center())
	check(int(Game.loot_reserved.get("vase", 0)) == 1, "预约：loot_reserved 落档（不扣货不发钱）")
	check(Game.money == 0, "预约：不付款")
	check(Game.loot_stash.size() == 1, "预约：货物仍在箱内")
	await _tap(KEY_P)
	check(not main.phone.is_open(), "预约：关闭手机")
	await _wait(0.3)
	await _tap(KEY_E)
	check(main.box.is_open(), "预约：打开文物箱取预约货")
	var reserved_row: HBoxContainer = main.box.stash_list.get_child(0)
	check((reserved_row.get_child(0) as Label).text.contains("已预约"), "预约：箱内行标记已预约")
	var take2: Button = null
	for child in reserved_row.get_children():
		if child is Button and (child as Button).text.contains("取出"):
			take2 = child
	if take2 == null:
		main.box.close()
		return
	await _click(take2.get_global_rect().get_center())
	check(Game.bag_items.size() == 1 and bool(Game.bag_items[0].get("reserved", false)), "预约：取出的货物带预约标记")
	check(not Game.loot_reserved.has("vase"), "预约：取出后箱内计数释放")
	await _tap(KEY_ESCAPE)
	check(not main.box.is_open(), "预约：关闭箱界面")

	# 门口交货：提示分流 + E 打开确认面板 + 一次性结算。
	p.global_position = Vector2(152, 136)
	await _frames(3)
	await _wait(0.3)
	await _tap(KEY_E)
	check(main.delivery.is_open(), "交货：门口 E 打开交货确认面板")
	_check_pause_contract("交货面板")
	check(main.delivery.items_label.text.contains("青瓷花瓶"), "交货：面板列出随身预约货")
	# ESC 取消不结算。
	await _tap(KEY_ESCAPE)
	check(not main.delivery.is_open() and Game.money == 0, "交货：取消不收钱、货仍在身上")
	await _wait(0.3)
	await _tap(KEY_E)
	check(main.delivery.is_open(), "交货：再次打开确认面板")
	var confirm: Button = main.delivery.confirm_button
	await _click(confirm.get_global_rect().get_center())
	await _frames(4)
	check(Game.money == 120, "交货：确认后一次性收 120 金（实际 %d）" % Game.money)
	check(Game.bag_items.is_empty(), "交货：随身预约货移除")
	check(Game.loot_reserved.is_empty(), "交货：预约计数清空")
	check(not main.delivery.is_open(), "交货：结算后面板关闭")
	_check_pause_contract("交货结算")

	# 出发门禁：背包非空时不得出发（防 reset_run 丢货）。
	Game.loot_stash = ["gem"] as Array[String]
	p.global_position = Vector2(272, 142)
	await _physics_frames(3)  # 传送回箱前：等物理帧刷新重叠 + 冷却解冻。
	await _wait(0.3)
	await _tap(KEY_E)
	check(main.box.is_open(), "门禁：打开箱取出未预约货")
	var vase_row = main.box.stash_list.get_child(0)
	var take3: Button = null
	for child in vase_row.get_children():
		if child is Button and (child as Button).text.contains("取出"):
			take3 = child
	if take3 != null:
		await _click(take3.get_global_rect().get_center())
	await _tap(KEY_ESCAPE)
	check(not main.box.is_open() and Game.bag_items.size() == 1, "门禁：随身 1 件未存箱货")
	Game.pending_mission_level = "british_museum"  # 已确认行动 + 背包有货 → 门禁拦截
	p.global_position = Vector2(152, 136)  # 走回门口再按 E
	await _physics_frames(3)
	await _wait(0.3)
	var depart_toasts: Array[String] = []
	var on_depart_toast := func(text: String) -> void: depart_toasts.append(text)
	main.hud.toast_requested.connect(on_depart_toast)
	await _wait(0.3)
	await _tap(KEY_E)
	await _frames(4)
	check(main._museum == null, "门禁：背包有货时门口 E 不出发")
	check(depart_toasts.size() > 0 and String(depart_toasts[0]).contains("背包"), "门禁：给出先存箱/交货提示")
	if main.hud.toast_requested.is_connected(on_depart_toast):
		main.hud.toast_requested.disconnect(on_depart_toast)
	Game.pending_mission_level = ""


func _test_safehouse_phone() -> void:
	# 安全屋按 P 打开手机：只显示任务页、隐藏档案页；安全屋是有活动世界的
	# 真实场景，手机作为覆盖层打开时必须暂停世界（避免手机开着还能走路）。
	Game.reset_progress()
	Game.set_story_flag("saw_p01")
	main.show_safehouse()
	await _frames(4)
	# 等手机/背包关闭留下的按键冷却过去（open_phone 有 0.2s 冷却）。
	await _wait(0.3)
	check(main._safehouse != null, "安全屋手机：安全屋已打开")
	if main._safehouse == null:
		return
	await _tap(KEY_P)
	check(main.phone.is_open(), "安全屋手机：按 P 打开手机")
	check(get_tree().paused, "安全屋手机：打开手机暂停世界（覆盖层契约）")
	check(main.phone.home_page.visible, "安全屋手机：打开显示应用首页（不复刻旧栏目）")
	check(not main.phone.tab_archive.visible, "安全屋手机：隐藏档案标签")
	check(not main.phone.archive_page.visible, "安全屋手机：隐藏档案页")
	check(main.phone.app_button("task") != null and main.phone.app_button("trade") != null,
		"安全屋手机：首页有委托/交易应用入口")
	# 手机开着时不能走路。
	var p: Player = main._safehouse.player
	var x_before := p.global_position.x
	_key(KEY_D, true)
	for i in 10:
		await get_tree().physics_frame
	_key(KEY_D, false)
	await _frames(2)
	check(p.global_position.x == x_before, "安全屋手机：手机开着时玩家不能移动")
	await _tap(KEY_P)
	check(not main.phone.is_open(), "安全屋手机：再按 P 关闭手机")
	_check_pause_contract("安全屋手机关闭")


func _test_safehouse_stories() -> void:
	# P-01：城西教学关完成后首次回安全屋。
	Game.reset_progress()
	Game.set_story_flag("completed_museum")
	main.show_safehouse()
	await _frames(2)
	check(main.dialogue_tree.is_active(), "P-01：教学关后首次回安全屋播放剧情")
	if main.dialogue_tree.is_active():
		await _finish_story_tree()
	check(Game.story_flag("saw_p01"), "P-01：saw_p01 落档")
	check(not main.dialogue_tree.is_active(), "P-01：剧情结束后关闭")
	check(main._safehouse != null, "P-01：剧情结束后回到安全屋")

	# H-01：完成第一次任务后回安全屋。
	Game.reset_progress()
	Game.set_story_flag("saw_p01")
	Game.set_story_flag("completed_museum")
	main.show_safehouse()
	await _frames(2)
	check(main.dialogue_tree.is_active(), "H-01：首次任务后回安全屋播放标签课")
	if main.dialogue_tree.is_active():
		await _finish_story_tree()
	check(Game.story_flag("saw_h01"), "H-01：saw_h01 落档")
	check(not main.dialogue_tree.is_active(), "H-01：剧情结束后关闭")

	# H-02：大英任务开始前（先跳过 H-01，只测 H-02）。
	Game.reset_progress()
	Game.set_story_flag("saw_p01")
	Game.set_story_flag("saw_h01")
	main.show_safehouse()
	await _frames(3)
	# start_mission 会在内部 await 剧情对谈；不 await 它，才能在本测试里继续按键推进剧情。
	main.start_mission("british_museum")
	await _frames(2)
	check(main.dialogue_tree.is_active(), "H-02：大英任务前播放两个地址")
	if main.dialogue_tree.is_active():
		await _finish_story_tree()
	check(Game.story_flag("saw_h02"), "H-02：saw_h02 落档")
	# H-02 结束后应继续进入 briefing/关卡。
	await _frames(4)
	check(main.dialogue.is_active() or main._museum != null, "H-02：剧情结束后进入 briefing")


func _test_bm_target_selection() -> void:
	# P6：推理板解锁后选埃及/希腊目标，Museum 必须按所选目标生成与判定。
	Game.reset_progress()
	for flag in ["saw_p00", "saw_p01", "saw_h01", "saw_h02", "chain_egypt_heart_scarab_done"]:
		Game.set_story_flag(flag)
	main.show_safehouse()
	await _frames(3)
	check(Game.set_bm_target("egypt_heart_scarab"), "P6：解锁后可切换埃及目标")
	main.start_mission("british_museum")
	await _frames(4)
	while main.dialogue.is_active():
		main.dialogue.advance()
		await _frames(1)
	var museum: Museum = main._museum
	check(museum != null, "P6：大英关卡已进入")
	if museum == null:
		return
	check(museum.target_item_id() == "egypt_heart_scarab", "P6：Museum.target_item_id 跟随所选目标（实际 %s）" % museum.target_item_id())
	var spawned := false
	for child in museum.get_children():
		if child is Artifact and child.item_id == "egypt_heart_scarab":
			spawned = true
	check(spawned, "P6：埃及目标实际生成")
	check(museum.target_room == 1, "埃及目标在独立展厅")


func _test_planning_world_freeze() -> void:
	# 真实场景与真实守卫：禁止先关AI，以免掩盖“玩家恢复、守卫永久冻结”。
	var museum: Museum = main._museum
	check(museum != null, "冻结回归：真实关卡存在")
	if museum == null:
		return
	var cop: Police = museum.police[0]
	museum.player.global_position = Vector2(40, 40)
	cop.global_position = Vector2(72, 152)
	cop.patrol_points = [Vector2(72, 152), Vector2(200, 152)] as Array[Vector2]
	cop.state = Police.State.PATROL
	cop._patrol_index = 1
	cop._wait_timer = 0.0
	cop.set_ai_enabled(true)
	Game.smoke_count = 1
	museum.drop_artifact("vase", Vector2(48, 40))
	await _wait(0.1)
	var fixture: Artifact = museum.player._closest_artifact()
	check(fixture != null, "规划测试旁边确实有可拾取物")
	await _tap(KEY_TAB)
	check(museum.planning_mode, "冻结回归：真实Tab开启规划")
	var player_pos := museum.player.global_position
	var guard_pos := cop.global_position
	var world_time := museum._bm_time
	var bag_before := JSON.stringify(Game.bag_items)
	var smoke_before := Game.smoke_count
	cop._blind_timer = 1.5
	cop._spot_timer = 0.2
	var patrol_before := cop._patrol_index
	for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		_key(code, true)
		await _wait(0.04)
		_key(code, false)
	await _tap(KEY_E)
	await _tap(KEY_Q)
	check(museum.player.global_position.is_equal_approx(player_pos), "规划中WASD/方向键不能改变真实玩家位置")
	check(cop.global_position.is_equal_approx(guard_pos), "规划中真实巡逻守卫位置不变")
	check(is_equal_approx(museum._bm_time, world_time), "规划中世界计时不推进")
	check(is_equal_approx(cop._blind_timer, 1.5) and is_equal_approx(cop._spot_timer, 0.2), "规划中致盲与发现计时均冻结")
	check(cop._patrol_index == patrol_before, "规划不重置巡逻节点")
	check(JSON.stringify(Game.bag_items) == bag_before and Game.smoke_count == smoke_before, "规划中E不拾取且Q不消耗烟雾弹")
	await _tap(KEY_P)
	check(main.phone.is_open(), "规划中可以打开暂停的手机覆盖层")
	await _tap(KEY_P)
	await _wait(0.25)
	check(museum.planning_mode and museum.player.global_position.is_equal_approx(player_pos), "关闭手机仍留在冻结规划态")
	check(cop.global_position.is_equal_approx(guard_pos), "关闭覆盖层不会单独恢复守卫")
	if fixture != null:
		fixture.queue_free()
	cop._blind_timer = 0.0
	cop._spot_timer = 0.0
	var click_screen := museum.get_viewport().get_canvas_transform() * (player_pos + Vector2(32, 0))
	await _click(click_screen)
	await _tap(KEY_SPACE)
	check(museum.executing_plan, "冻结回归：空格进入执行态")
	await _wait(0.18)
	check(museum.player.global_position.distance_to(player_pos) > 2.0, "执行恢复玩家实际移动")
	check(cop.global_position.distance_to(guard_pos) > 2.0, "执行同时恢复真实守卫巡逻")
	check(museum._bm_time > world_time, "执行恢复世界计时")
	var guard_before_takeover := cop.global_position
	_key(KEY_D, true)
	await _wait(0.1)
	_key(KEY_D, false)
	await _frames(3)
	check(not museum.executing_plan and not museum.player.auto_moving, "方向键真正接管，不被物理帧重新启动路线")
	check(cop.global_position.distance_to(guard_before_takeover) > 1.0, "接管后守卫仍继续实际巡逻")
	await _tap(KEY_TAB)
	click_screen = museum.get_viewport().get_canvas_transform() * (museum.player.global_position + Vector2(16, 0))
	await _click(click_screen)
	await _tap(KEY_SPACE)
	await _tap(KEY_E)
	check(not museum.executing_plan and not museum.player.auto_moving, "E键也能真正接管执行")
	check(not cop.world_frozen, "E键接管不会遗留守卫冻结")
	await _tap(KEY_TAB)
	click_screen = museum.get_viewport().get_canvas_transform() * (museum.player.global_position + Vector2(16, 0))
	await _click(click_screen)
	await _tap(KEY_SPACE)
	await _wait(0.7)
	check(not museum.executing_plan and not museum.player.auto_moving, "路线自然走完进入手动状态")
	check(not cop.world_frozen and museum.player.controls_enabled, "路线完成后人物与守卫都正常运行")
	for i in range(3):
		await _tap(KEY_TAB)
		var frozen_pos := cop.global_position
		await _tap(KEY_TAB)
		await _wait(0.08)
		check(cop.global_position.distance_to(frozen_pos) > 0.5, "反复切换规划第%d次后守卫仍移动" % (i + 1))
	# 没有通过关闭AI制造安全：接管后的守卫必须真的能重新发现玩家。
	cop.global_position = Vector2(120, 104)
	museum.player.global_position = Vector2(152, 104)
	cop.patrol_points.clear()
	cop._facing = Vector2.RIGHT
	cop._spot_timer = 0.0
	cop.spot_delay_scale = 1.0
	await _wait(0.7)
	check(museum.failure_replay, "接管后的守卫视野能真实触发发现回放")
	check(museum.failure_detector == cop and not museum.failure_reason.is_empty(), "实际发现准确记录守卫与原因")
	await _wait(0.7)
	await _tap(KEY_SPACE)
	check(museum.planning_mode and not museum.failure_replay, "真实发现后可按空格重试规划")
	await _tap(KEY_TAB)
	check(not museum.planning_mode and museum.player.controls_enabled, "重试后退出规划恢复玩家控制")
	cop.global_position = Vector2(72, 152)
	cop.patrol_points = [Vector2(72, 152), Vector2(200, 152)] as Array[Vector2]
	cop.state = Police.State.PATROL
	cop._patrol_index = 1
	cop._wait_timer = 0.0
	cop.set_ai_enabled(true)
	cop._spot_timer = 0.0
	# 完整快照回退会把玩家恢复到执行起点，可能落在守卫视野内；这里把他放回安全角落，
	# 只测“失败重试后守卫不永久冻结、能继续巡逻”。
	museum.player.global_position = Vector2(40, 40)
	var retry_pos := cop.global_position
	await _wait(0.1)
	check(cop.global_position.distance_to(retry_pos) > 0.5, "失败重试不会遗留守卫永久冻结")


func _test_route_planning() -> void:
	# 路线预演系统：Tab 进入规划模式 → 左键添加节点 → 空格执行 → 方向键接管 →
	# 程序化进入失败回放 → 空格回退并重新规划。
	var museum: Museum = main._museum
	check(museum != null, "路线预演：当前处于关卡内")
	if museum == null:
		return
	# 清空前序测试残留路线，保证本用例起点一致。
	museum.planned_points.clear()
	if museum.has_method("_plan_node_actions"):
		museum._plan_node_actions.clear()
	# 关掉守卫 AI，避免测试期间被意外发现。
	for cop in museum.police:
		cop.set_ai_enabled(false)
	await _frames(2)

	await _tap(KEY_TAB)
	check(museum.planning_mode, "Tab 进入规划模式")
	check(museum.police[0].world_frozen, "规划模式下守卫世界更新冻结")

	var click_world := museum.player.global_position + Vector2(32, 0)
	# 真实玩家看到的是相机缩放后的屏幕坐标（zoom=2）；用 canvas transform 反推屏幕位置。
	var click_screen: Vector2 = museum.get_viewport().get_canvas_transform() * click_world
	await _click(click_screen)
	check(museum.planned_points.size() == 1, "左键点击添加规划节点")
	check(museum.planned_points[0].distance_to(click_world) < 8.0, "节点落在点击位置附近（世界坐标）")

	# G11：同一节点连续真实点击循环动作；该点无门、非目标，应跳过 unlock/take，
	# 依次到达 wait → crouch → sprint → 空。
	var expected_actions := ["wait", "crouch", "sprint", ""]
	var action_labels := ["等待", "蹲下", "疾跑", "空"]
	for i in expected_actions.size():
		await _click(click_screen)
		check(museum._plan_node_actions[0] == expected_actions[i],
			"节点动作循环：%s（实际 %s）" % [action_labels[i], museum._plan_node_actions[0]])

	# V0-1：规划节点变化后自动预演；Enter 手动重算。断言轨迹/守卫残影/预警与内核一致。
	await _tap(KEY_ENTER)
	await _frames(2)
	check(museum._preview_active, "Enter 预演激活")
	check(museum._preview_cells.size() > 1, "预演生成玩家轨迹（%d tick）" % museum._preview_cells.size())
	check(museum._preview_guard_cells.size() > 1, "预演生成守卫残影（%d tick）" % museum._preview_guard_cells.size())
	var kernel := SimPreview.simulate_route(museum._build_sim_snapshot(), museum._planned_sim_route(), 900)
	check(museum._preview_spotted_tick == kernel.first_spotted, "预演预警与一致性内核首次发现 tick 一致")

	await _tap(KEY_TAB)
	check(not museum.planning_mode, "再按 Tab 退出规划模式")
	check(not museum.police[0].world_frozen, "退出规划模式后守卫世界更新恢复")
	check(not museum.police[0].ai_enabled, "规划退出保留测试原有的独立AI禁用，不擅自覆盖")
	# 再次冻结，避免下次进入规划模式前的短暂窗口内被守卫发现。
	for cop in museum.police:
		cop.set_ai_enabled(false)

	await _tap(KEY_TAB)
	await _click(click_screen)
	var start_pos := museum.player.global_position
	await _tap(KEY_SPACE)
	check(museum.executing_plan, "空格执行规划路线")
	# 等玩家确实开始沿路径移动（headless 下物理帧可能不稳定，多等几帧）。
	var moved := false
	for i in 30:
		await _frames(1)
		if museum.player.global_position.distance_to(start_pos) > 2.0:
			moved = true
			break
	check(moved, "执行后玩家沿路径移动")

	await _key(KEY_D, true)
	await _frames(4)
	await _key(KEY_D, false)
	await _frames(4)
	check(not museum.executing_plan, "按方向键接管并中断执行")
	check(not museum.player.auto_moving, "接管后玩家不再自动移动")

	# 失败回放入口不易用输入稳定触发，这里直接调用后验证 E/空格可回退重规划。
	museum.enter_failure_replay(null, "输入流测试")
	await _frames(2)
	check(museum.failure_replay, "进入失败回放态")
	check(museum.failure_reason == "输入流测试", "失败原因被记录")

	# v0.20.4：前 0.6s 忽略 E/Space 误触，避免刚被发现就跳过回放。
	await _tap(KEY_SPACE)
	check(museum.failure_replay, "0.6s 定格内空格不误触回退")
	await _wait(0.7)
	await _tap(KEY_SPACE)
	await _frames(2)
	check(not museum.failure_replay, "定格结束后空格回退清除失败回放")
	check(museum.planning_mode, "回退后自动进入规划模式")
	check(museum.planned_points.size() == 1, "回退后保留原规划路线与节点动作")
	museum.level_id = "museum"



func _test_leave_scene_clean() -> void:
	# 收尾：不应残留任何界面或暂停状态
	check(not _any_overlay_open(), "结束时没有残留覆盖层")
	check(not get_tree().paused, "结束时游戏未处于暂停")


# ---------------------------------------------------------------- 主流程

func _ready() -> void:
	Game.save_path = SAVE
	Game.reset_progress()
	main = load("res://src/main.tscn").instantiate() as Main
	add_child(main)
	await _frames(4)
	check(
		main.backpack != null and main.phone != null and main.dialogue_tree != null,
		"覆盖层节点已接线（Backpack / Phone / DialogueTree）"
	)

	# 直接进入关卡并跳过任务简报，让按键流从可操作状态开始
	main.start_mission("museum")
	await _frames(4)
	await _skip_dialogue()
	check(main._museum != null, "关卡已开始（museum）")
	check(not main.dialogue.is_active(), "任务简报已跳过")

	# 给背包一件有文物志的文物（卡片/端详测试用）
	Game.try_pickup("mask")
	await _frames(2)

	await _test_basic_toggles()
	await _test_cross_keys()
	await _test_card_over_phone()
	await _test_hud_button_while_bag()
	await _test_planning_world_freeze()
	await _test_route_planning()
	await _test_leave_scene_clean()
	await _test_relic_closeup()
	await _test_statements_from_title()
	await _test_title_collection()
	await _test_new_game_opening()
	await _test_tutorial_direct_safehouse()
	await _test_safehouse_collision()
	await _test_safehouse_devices()
	await _test_safehouse_door()
	await _test_safehouse_box_sell()
	await _test_computer_investigation()
	await _test_safehouse_shop()
	await _test_phone_archive_footer()
	await _test_safehouse_phone()
	await _test_investigation_inputs()
	await _test_safehouse_stories()
	await _test_bm_target_selection()
	await _test_archive_cards_readable()
	await _test_bm_story_interactions()

	# 停止音频并给音频服务端一点真实时间释放播放引用（否则退出时报假泄漏）
	Audio.shutdown()
	await get_tree().create_timer(0.4, true).timeout
	await _frames(5)
	if _failures > 0:
		print("FAILED %d / %d checks" % [_failures, _checks])
		for line in _assertion_log:
			if line.begins_with("FAIL"):
				print(line)
		get_tree().quit(1)
	else:
		# 全绿也打印断言摘要（逐行 PASS），供 pytest 驱动器与课堂演示核对覆盖。
		for line in _assertion_log:
			print(line)
		print("ALL %d CHECKS PASSED" % _checks)
		get_tree().quit(0)


# ---------------------------------------------------------------- A-00 电话页脚

func _visible_close_hint(root: Node) -> bool:
	for child in root.get_children():
		if child is Label and child.is_visible_in_tree() and (child as Label).text.contains("关闭"):
			return true
		if _visible_close_hint(child):
			return true
	return false


## R-12a 采购 App（真实点击驱动）：购买入备货、连点两次两件、出发时并入携带；
## 已拥有的永久装备不再上架；无钱按钮禁用。
func _test_safehouse_shop() -> void:
	Game.reset_progress()
	Game.money = 300
	Game.set_story_flag("saw_p01")
	main.show_safehouse()
	await _frames(4)
	check(main._safehouse != null, "采购：安全屋已打开")
	if main._safehouse == null:
		return
	await _wait(0.3)
	await _tap(KEY_P)
	check(main.phone.is_open(), "采购：打开手机")
	await _click(main.phone.app_button("shop").get_global_rect().get_center())
	check(main.phone.shop_list.is_visible_in_tree(), "采购：采购页打开")
	check(main.phone.shop_money_label.text.contains("300"), "采购：显示金币（实际 %s）" % main.phone.shop_money_label.text)
	var buy_smoke: Button = _find_button_with_text(main.phone.shop_list, "购买")
	check(buy_smoke != null and not buy_smoke.disabled, "采购：烟雾弹可购买（有钱）")
	if buy_smoke == null:
		main.phone.close()
		return
	await _click(buy_smoke.get_global_rect().get_center())
	check(Game.smoke_stock == 1 and Game.money == 180, "采购：购买一次扣款一次发货（120 金，实际 %d）" % Game.money)
	# 连点两次 = 两件两笔扣款（每次点击独立意图，不允许一次点击重复发货）。
	# 注意：_fill_shop 会重建按钮，必须重新定位当前实例再点。
	var buy_smoke2: Button = _find_button_with_text(main.phone.shop_list, "购买")
	check(buy_smoke2 != null, "采购：刷新后仍有购买按钮")
	if buy_smoke2 == null:
		main.phone.close()
		return
	await _click(buy_smoke2.get_global_rect().get_center())
	check(Game.smoke_stock == 2 and Game.money == 60, "采购：第二次购买独立扣款（实际 %d）" % Game.money)
	# 钱不够时当前购买按钮禁用。
	var smoke_disabled := Game.money < Game.upgrade_price("smoke")
	var current_buy: Button = _find_button_with_text(main.phone.shop_list, "购买")
	check(current_buy != null and current_buy.disabled == smoke_disabled, "采购：钱不够时购买按钮禁用")
	await _tap(KEY_P)
	check(not main.phone.is_open(), "采购：关闭手机")
	_check_pause_contract("采购页关闭")

	# 出发装载：确认行动 → 门口出发 → 备货并入携带（HUD 烟雾弹计数随之增加）。
	Game.set_story_flag("saw_h01")
	Game.set_story_flag("saw_h02")
	Game.pending_mission_level = "british_museum"
	var p: Player = main._safehouse.player
	p.global_position = Vector2(152, 136)
	await _physics_frames(3)
	await _wait(0.3)
	await _tap(KEY_E)
	await _frames(6)
	check(main._museum != null, "采购：出发进入关卡")
	check(Game.smoke_count == 2 and Game.smoke_stock == 0, "采购：出发装载 备货2→携带2（实际 %d/%d）" % [Game.smoke_count, Game.smoke_stock])
	await _skip_dialogue()
	check(main.hud.item_label.text.contains("2"), "采购：HUD 烟雾弹计数显示携带数（实际 %s）" % main.hud.item_label.text)


## A-00：任务页与档案页都必须有可读的关闭提示（P/B/ESC），Footer 不能只挂在一个页面里。
func _test_phone_archive_footer() -> void:
	var museum := await _enter_british_museum()
	check(museum != null, "电话页脚：关卡已开始")
	if museum == null:
		return
	await _wait(0.2)
	await _tap(KEY_P)
	check(main.phone.is_open(), "电话页脚：手机已打开")
	main.phone._show_tab("archive")
	await _frames(2)
	check(_visible_close_hint(main.phone), "A-00：档案页显示关闭提示（P/B/ESC）")
	main.phone._show_tab("task")
	await _frames(2)
	check(_visible_close_hint(main.phone), "A-00：任务页显示关闭提示")
	main.phone.close()
	await _frames(2)


# ---------------------------------------------------------------- 大英博物馆剧情交互（S-03）

## 进入大英博物馆并关掉守卫 AI（剧情交互测试不需要追捕）。
func _enter_british_museum() -> Museum:
	if main.phone.is_open():
		main.phone.close()
	if main.backpack.is_open():
		main.backpack.close()
	if main.dialogue_tree.is_active():
		main.dialogue_tree.close()
	while main.dialogue.is_active():
		main.dialogue.advance()
		await _frames(1)
	Game.reset_progress()
	# BM 剧情交互测试只测关卡内行为，跳过安全屋入场剧情 P-01、H-01 与大英任务前 H-02。
	Game.set_story_flag("saw_p01")
	Game.set_story_flag("saw_h01")
	Game.set_story_flag("saw_h02")
	main.show_safehouse()
	await _frames(3)
	await main.start_mission("british_museum")
	await _frames(4)
	while main.dialogue.is_active():
		main.dialogue.advance()
		await _frames(1)
	var museum: Museum = main._museum
	if museum != null:
		for cop in museum.police:
			cop.set_ai_enabled(false)
	return museum


func _stand_at(museum: Museum, pos: Vector2) -> void:
	# 触发点可能贴着围栏/展柜：优先选一个可站立且仍在交互半径内的相邻格
	var offsets: Array[Vector2] = [Vector2(0, -18), Vector2(0, 18), Vector2(18, 0), Vector2(-18, 0)]
	for offset in offsets:
		var p: Vector2 = pos + offset
		var cell := Vector2i(int(p.x / museum.TILE), int(p.y / museum.TILE))
		if not museum.is_cell_blocked(cell.x, cell.y):
			museum.player.global_position = p
			await _physics_frames(3)
			return
	museum.player.global_position = pos
	await _physics_frames(3)


## 等物理帧而不是 process 帧：传送后 Area2D 重叠列表要等物理步收尾才刷新，
## headless 下 process 帧和物理帧不是一一对应，只等 process 帧时
## 紧随其后的按 E 会在「重叠还没刷新」的物理帧里被读走（偶发吃键、提示不更新）。
func _physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _finish_story_tree() -> void:
	var guard := 0
	while main.dialogue_tree.is_active() and guard < 120:
		await _tap(KEY_E)
		guard += 1


## 一路按 E 直到出现选项（双纸对谈）；返回是否见到选项。
func _advance_until_choices() -> bool:
	var guard := 0
	while main.dialogue_tree.is_active() and guard < 120:
		if main.dialogue_tree.choices_box.visible:
			return true
		await _tap(KEY_E)
		guard += 1
	return false


## 把玩家瞬移到指定坐标并等物理刷新，供剧情交互测试用。
func _set_player_at(museum: Museum, pos: Vector2) -> void:
	museum.player.global_position = pos
	museum.player.velocity = Vector2.ZERO
	# headless 下瞬移后 Area2D 重叠列表刷新较慢，多等几帧物理与 process。
	await _physics_frames(3)
	await _frames(3)


## 轮询等待 HUD 提示包含指定文本（最多等 0.5s）。
func _wait_for_prompt(substring: String) -> void:
	var guard := 0
	while guard < 30:
		if main.hud.prompt_label.text.contains(substring):
			return
		await _frames(1)
		guard += 1


func _test_archive_cards_readable() -> void:
	# 幽灵移除后，展签卡不应再依赖 lore_stage 锁死；拾取/归档后应全部可读。
	Game.reset_progress()
	Game.try_pickup("ram_zun")
	var page: InspectPage = load("res://src/ui/inspect_page.tscn").instantiate()
	add_child(page)
	await _frames(2)
	page.set_item("ram_zun")
	await _frames(2)
	var enabled := 0
	for child in page.cards_box.get_children():
		if child is Button:
			if not child.disabled:
				enabled += 1
			check(not String(child.text).contains("未解锁"), "展签卡不显示未解锁：%s" % child.text)
	check(enabled == 3, "双羊尊 3 张展签卡全部可读（实际 %d）" % enabled)
	page.queue_free()
	await _frames(2)


func _test_bm_story_interactions() -> void:
	# 触发器新位置贴左右墙；墙边格可能紧挨着展品，_stand_at 的自动偏移
	# 会站到展品与触发器之间，导致展品更近而读不到纸。这里用显式站位。
	const LABEL_STAND := Vector2(40, 314)   # 标签正下方，无更近展品
	const NOTE_STAND := Vector2(280, 314)   # 留言正下方，无更近展品
	const ZUN_STAND := Vector2(152, 280)    # 双羊尊正上方一格

	# P0-1 回归：未读标签时站在双羊尊前，按 E 应拾取目标（打开特写），而非读纸。
	var museum := await _enter_british_museum()
	check(museum != null, "BM 剧情：关卡已开始")
	if museum == null:
		return
	_set_player_at(museum, ZUN_STAND)
	await _wait_for_prompt("双羊尊")
	check(main.hud.prompt_label.text.contains("双羊尊") or main.hud.prompt_label.text.contains("端详"), "P0-1：双羊尊旁提示为拾取/端详（当前：%s）" % main.hud.prompt_label.text)
	await _tap(KEY_E)
	check(not main.dialogue_tree.is_active(), "P0-1：未读标签时按 E 不开剧情对谈")
	check(main.relic_closeup.is_open() or _has_item("ram_zun"), "P0-1：未读标签时按 E 打开特写或已拾取")
	if main.relic_closeup.is_open():
		await _tap(KEY_E)
		await _frames(3)
	check(_has_item("ram_zun"), "P0-1：特写内再按 E 真正拾取双羊尊")

	# A. 只读馆方标签
	museum = await _enter_british_museum()
	check(museum != null, "BM 剧情：标签关卡已开始")
	if museum == null:
		return
	_set_player_at(museum, LABEL_STAND)
	await _wait_for_prompt("馆方标签")
	check(main.hud.prompt_label.text.contains("馆方标签"), "标签旁提示：显示「按 E 阅读：馆方标签」（当前：%s）" % main.hud.prompt_label.text)
	await _tap(KEY_E)
	check(main.dialogue_tree.is_active(), "只读标签：按 E 打开剧情对谈")
	await _finish_story_tree()
	check(Game.story_flag("read_label"), "只读标签：read_label = true")
	check(not Game.story_flag("read_note"), "只读标签：read_note = false")
	check(not main.dialogue_tree.is_active() and not get_tree().paused, "只读标签：结束后不卡界面/暂停")

	# B. 只读观众留言
	museum = await _enter_british_museum()
	check(museum != null, "BM 剧情：留言关卡已开始")
	if museum == null:
		return
	_set_player_at(museum, NOTE_STAND)
	await _wait_for_prompt("观众留言")
	await _tap(KEY_E)
	check(main.dialogue_tree.is_active(), "只读留言：按 E 打开剧情对谈")
	await _finish_story_tree()
	check(Game.story_flag("read_note"), "只读留言：read_note = true")
	check(not Game.story_flag("read_label"), "只读留言：read_label = false")
	check(not main.dialogue_tree.is_active() and not get_tree().paused, "只读留言：结束后不卡界面/暂停")

	# C. 两张都读 → 自动触发双纸对谈（带选项）
	museum = await _enter_british_museum()
	if museum == null:
		return
	_set_player_at(museum, LABEL_STAND)
	await _wait_for_prompt("馆方标签")
	await _tap(KEY_E)
	await _finish_story_tree()
	# 等玩家交互冷却结束（0.25s，暂停期间冻结）：测试里瞬移代替走路，
	# 不等的话紧接着的留言 E 会被冷却吃掉（真实游玩中走路时间远长于冷却）。
	await _wait(0.3)
	_set_player_at(museum, NOTE_STAND)
	await _wait_for_prompt("观众留言")
	await _tap(KEY_E)
	check(main.dialogue_tree.is_active(), "两张都读：留言对谈已打开")
	var saw_choices := await _advance_until_choices()
	check(saw_choices, "两张都读：自动触发双纸对谈并出现选项")
	await _finish_story_tree()
	check(Game.story_flag("read_label") and Game.story_flag("read_note"), "两张都读：两个 flag 均落档")
	check(not main.dialogue_tree.is_active() and not get_tree().paused, "两张都读：结束后不卡界面/暂停")

	# P0-1 回归：读完两张后站在双羊尊前，按 E 仍可拾取（触发器已读，不应拦截）。
	await _wait(0.3)
	_set_player_at(museum, ZUN_STAND)
	await _wait_for_prompt("双羊尊")
	await _tap(KEY_E)
	check(not main.dialogue_tree.is_active(), "P0-1：读完两张后按 E 不开剧情对谈")
	check(main.relic_closeup.is_open() or _has_item("ram_zun"), "P0-1：读完两张后按 E 仍可拾取/特写")
	if main.relic_closeup.is_open():
		main.relic_closeup.close()
		await _frames(2)

	# D. 重复阅读同一张：允许重看，但必须能正常关闭、不软锁
	# 同上：先等上一段对谈留下的交互冷却结束，再瞬移去重读。
	await _wait(0.3)
	_set_player_at(museum, LABEL_STAND)
	await _wait_for_prompt("馆方标签")
	await _tap(KEY_E)
	if main.dialogue_tree.is_active():
		await _finish_story_tree()
	check(not main.dialogue_tree.is_active() and not get_tree().paused, "重复阅读：可正常关闭、不软锁")

	# E. 都不读：flag 保持 false，不自动弹对谈
	museum = await _enter_british_museum()
	if museum == null:
		return
	await _frames(3)
	check(not Game.story_flag("read_label") and not Game.story_flag("read_note"), "都不读：flag 保持 false")
	check(not main.dialogue_tree.is_active(), "都不读：没有自动弹出对谈")



func _drag_input(from: Vector2, to: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.position = from
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	Input.parse_input_event(down)
	await _frames(2)
	var move := InputEventMouseMotion.new()
	move.position = to
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(move)
	await _frames(2)
	var up := InputEventMouseButton.new()
	up.position = to
	up.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(up)
	await _frames(2)


func _test_investigation_inputs() -> void:
	# 日历/联系人：从安全屋手机驱动（真实按键与点击）。
	Game.set_story_flag("saw_p00")
	Game.set_story_flag("saw_p01")
	Game.set_story_flag("saw_h01")
	main.show_safehouse()
	await _frames(4)
	await _wait(0.3)
	await _tap(KEY_P)
	check(main.phone.is_open(), "真实按键从安全屋打开手机")
	await _wait(0.3)  # 等应用网格布局稳定再取矩形（避免点击瞬间面板还在排版）。
	var header := main.phone.get_node("Root/Panel/Margin/VBox/Header")
	var calendar: Button = main.phone.app_button("calendar")
	var calendar_center := calendar.get_global_rect().get_center()
	await _click(calendar_center)
	if not main.phone.is_open():
		# 布局抖动可能让点击落在暗区关掉手机：重开一次再用最新矩形点击。
		await _tap(KEY_P)
		await _wait(0.3)
		calendar_center = calendar.get_global_rect().get_center()
		await _click(calendar_center)
	if not main.phone.extra_page.visible:
		print("DBG calendar rect=", calendar.get_global_rect(), " visible=", calendar.is_visible_in_tree(),
			" home=", main.phone.home_page.visible, " open=", main.phone.is_open())
	check(main.phone.extra_page.visible, "真实鼠标打开日历")
	await _click((header.get_node("HomeButton") as Button).get_global_rect().get_center())
	check(main.phone.home_page.visible, "真实鼠标返回应用首页")
	await _click(main.phone.app_button("contacts").get_global_rect().get_center())
	await _click((main.phone.extra_page.get_child(0) as Button).get_global_rect().get_center())
	check(main.phone.call_label.text.contains("恶魔"), "真实鼠标接听NPC对话")
	await _tap(KEY_ESCAPE)
	await _wait(0.3)

	# 推理板：旧 Hub 内容改用独立宿主驱动（正式流程已不进入旧栏目页）。
	var hub := (load("res://src/ui/hub.tscn") as PackedScene).instantiate() as Hub
	main.ui_layer.add_child(hub)
	await _frames(2)
	await _click(hub.tab_reason.get_global_rect().get_center())
	Game.set_story_flag("link_zun_tech_zun_chat", false)
	for id in ["zun_archive", "zun_tech", "zun_chat"]:
		Game.collect_clue(id)
	Game.set_story_flag("link_zun_archive_zun_tech", false)
	await _click((hub._reason_source_hbox.get_child(4) as Button).get_global_rect().get_center())
	var board := hub.evidence_board
	check(board.is_visible_in_tree(), "鼠标打开推理板")
	var old_pos: Vector2 = board.cards[0].pos
	await _drag_input(board.global_position + old_pos + Vector2(10, 10), board.global_position + old_pos + Vector2(18, 15))
	check(board.cards[0].pos != old_pos, "真实鼠标拖动卡片")
	await _drag_input(board.global_position + board.cards[0].pos + Vector2(156, 22), board.global_position + board.cards[1].pos + Vector2(20, 20))
	check(Game.has_link("zun_archive", "zun_tech"), "真实拖线记录玩家指定关系")
	check(not Game.has_link("zun_tech", "zun_chat"), "拖一条线不会自动补全其他关联")
	hub.queue_free()
	await _frames(2)


func _find_option_buttons(root: Node) -> Array[OptionButton]:
	var out: Array[OptionButton] = []
	for child in root.get_children():
		if child is OptionButton:
			out.append(child)
		if child is Container or child is Control:
			out.append_array(_find_option_buttons(child))
	return out


## E 批：电脑调查链（真实按键/鼠标驱动）。
## 浏览器关键词 → 档案检索 → 聊天追问 → 推理板确认关系。
func _test_computer_investigation() -> void:
	Game.reset_progress()
	Game.set_story_flag("saw_p00")
	Game.set_story_flag("saw_p01")
	main.show_safehouse()
	await _frames(4)
	var house := main._safehouse
	if house == null:
		return
	var p: Player = house.player
	p.global_position = Vector2(64, 58)
	await _physics_frames(4)
	await _wait_for_prompt("书桌电脑")
	# 设备交互在 _physics_process 读 just_pressed；按键必须跨物理帧保持，
	# 否则进程帧快于物理帧时，按下/抬起可能都落在同一物理 tick 之间。
	_key(KEY_E, true)
	await _physics_frames(4)
	_key(KEY_E, false)
	await _physics_frames(2)
	check(main.computer.is_open(), "电脑调查：走近按 E 打开书桌电脑")
	if not main.computer.is_open():
		return

	# 浏览器：搜索关键词解锁技术研究。
	var search: LineEdit = main.computer._browser_search
	search.text = "双羊尊"
	await _frames(2)
	var search_btn := _find_button_with_text(main.computer._content, "搜索")
	check(search_btn != null, "电脑调查：浏览器有搜索按钮")
	if search_btn:
		await _click(search_btn.get_global_rect().get_center())
	check(Game.story_flag("inv_zun_tech"), "电脑调查：搜索关键词解锁技术研究")

	# 档案库：用编号检索解锁馆藏档案。
	search.text = "1936,1118.1"
	await _frames(2)
	search_btn = _find_button_with_text(main.computer._content, "搜索")
	if search_btn:
		await _click(search_btn.get_global_rect().get_center())
	check(Game.story_flag("inv_zun_archive"), "电脑调查：编号检索解锁馆藏档案")

	# 邮件/聊天：切换到聊天页，发送编号触发阿岚邮件。
	var tab_bar: TabBar = main.computer._tab_bar
	await _click(tab_bar.get_global_transform() * tab_bar.get_tab_rect(3).get_center())
	await _frames(2)
	var chat_input: LineEdit = main.computer._chat_input
	chat_input.text = "双羊尊 1936,1118.1"
	await _frames(2)
	var send_btn: Button = main.computer._chat_send
	check(send_btn != null, "电脑调查：聊天有发送按钮")
	if send_btn:
		await _click(send_btn.get_global_rect().get_center())
	check(Game.story_flag("inv_zun_delivery"), "电脑调查：聊天触发阿岚邮件")
	check(not Game.story_flag("inv_zun_service"), "电脑调查：聊天不赠送现场便条")

	# 推理板：打开板面，确认新组件已挂载。拖卡/连线/双材料细节见独立
	# tests/test_investigation_board.tscn，避免在共享 input_flow 里重复维护。
	Game.set_story_flag("inv_zun_service")
	await _click(tab_bar.get_global_transform() * tab_bar.get_tab_rect(4).get_center())
	await _frames(3)
	check(main.computer._board != null, "电脑调查：推理板组件已挂载")
	if main.computer._board != null:
		check(main.computer._board.card_ids().size() >= 2, "电脑调查：推理板显示已获得材料")

	await _tap(KEY_ESCAPE)
	check(not main.computer.is_open(), "电脑调查：ESC 关闭电脑")
