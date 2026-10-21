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


func check(cond: bool, msg: String) -> void:
	_checks += 1
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

	# 手机开着时按 B：不应打开背包，且手机仍能关
	await _wait(0.3)
	await _tap(KEY_P)
	check(main.phone.is_open(), "交叉键：手机已打开")
	await _tap(KEY_B)
	check(not main.backpack.is_open(), "手机开着时 B 不应打开背包")
	check(main.phone.is_open(), "手机不受 B 影响")
	await _wait(0.3)
	await _tap(KEY_P)
	check(not main.phone.is_open(), "交叉键后手机仍可正常关闭")
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


func _test_lore_over_museum() -> void:
	# 关卡内触发器灵对谈（等效于靠近文物按 E）：期间 B/P 不应叠开界面
	await _wait(0.3)
	main._museum.lore_requested.emit("mask", 0)
	await _frames(3)
	check(main.dialogue_tree.is_active(), "器灵对谈已开始")
	_check_pause_contract("对谈开始时")

	await _tap(KEY_B)
	check(not main.backpack.is_open(), "对谈中 B 不应打开背包")
	await _tap(KEY_P)
	check(not main.phone.is_open(), "对谈中 P 不应打开手机")

	# 用真实按键走完对谈（E 推进 / 确认选项）
	var guard := 0
	while main.dialogue_tree.is_active() and guard < 80:
		await _tap(KEY_E)
		guard += 1
	check(not main.dialogue_tree.is_active(), "器灵对谈可用 E 走完并关闭（%d 步内）" % guard)
	_check_pause_contract("对谈结束后")


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


func _test_title_shop() -> void:
	# 标题页的「商店」：真实点击画面里博物馆入口处的按钮 → 据点商店页
	main.show_title()
	await _frames(4)
	await _wait(0.6)
	var title: TitleScreen = null
	for child in main.get_node("UILayer").get_children():
		if child is TitleScreen:
			title = child
	check(title != null, "标题界面已打开（商店测试）")
	if title == null:
		return
	var button: Button = title.get_node_or_null("ShopButton")
	check(button != null, "标题界面有场景化的「商店」按钮")
	if button == null:
		return
	await _click(button.get_global_rect().get_center())
	await _frames(4)
	var hub: Hub = null
	for child in main.get_node("UILayer").get_children():
		if child is Hub:
			hub = child
	check(hub != null, "点击「商店」进入据点")
	if hub != null:
		check(hub.shop_box.visible, "点击「商店」直接显示商店页")
		check(hub.tab_shop.button_pressed, "商店标签处于高亮")


func _test_sell_tab() -> void:
	# 据点「销赃」页：真实点击标签 → 逐件卖出 → 全部出手
	Game.loot_stash = [] as Array[String]
	var items: Array[String] = ["vase", "gem"]
	Game.loot_stash = items
	main.show_menu()
	await _frames(4)
	var hub: Hub = null
	for child in main.get_node("UILayer").get_children():
		if child is Hub:
			hub = child
	check(hub != null, "据点已打开")
	if hub == null:
		return
	var tab: Button = hub.get_node_or_null("TabSell")
	check(tab != null, "据点有「销赃」标签")
	if tab == null:
		return
	await _click(tab.get_global_rect().get_center())
	check(hub.sell_box.visible, "点击「销赃」切换到仓库页")
	check(hub.sell_list.get_child_count() == 2, "仓库列出两件战利品")

	var money_before := Game.money
	var first_row: HBoxContainer = hub.sell_list.get_child(0)
	var sell_button: Button = first_row.get_child(2)
	await _click(sell_button.get_global_rect().get_center())
	check(Game.money == money_before + 120, "点击卖出获得对应金币")
	check(Game.loot_stash.size() == 1, "卖出的物品移出仓库")

	await _click(hub.sell_all_button.get_global_rect().get_center())
	check(Game.loot_stash.is_empty(), "全部出手后仓库清空")
	check(Game.money == money_before + 420, "全部出手结清剩余金币")


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
	await _test_lore_over_museum()
	await _test_hud_button_while_bag()
	await _test_leave_scene_clean()
	await _test_relic_closeup()
	await _test_statements_from_title()
	await _test_title_shop()
	await _test_sell_tab()

	# 停止音频并给音频服务端一点真实时间释放播放引用（否则退出时报假泄漏）
	Audio.shutdown()
	await get_tree().create_timer(0.4, true).timeout
	await _frames(5)
	if _failures > 0:
		print("FAILED %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
	else:
		print("ALL %d CHECKS PASSED" % _checks)
		get_tree().quit(0)
