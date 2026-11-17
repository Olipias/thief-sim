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
	# 标题页的「文物档案」：真实点击博物馆入口处的按钮 → 收集册；ESC 关闭
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
	check(button != null, "标题界面有场景化的「文物档案」按钮")
	if button == null:
		return
	await _click(button.get_global_rect().get_center())
	await _frames(4)
	check(main.collection.is_open(), "点击「文物档案」打开收集册")
	await _tap(KEY_ESCAPE)
	check(not main.collection.is_open(), "ESC 关闭收集册")


func _test_new_game_opening() -> void:
	# P2-A：新游戏先播恶魔契约，结束后进据点；未完成教学关不播 P-01。
	Game.reset_progress()
	main.show_title()
	await _frames(2)
	main._on_new_game()
	await _frames(3)
	var intro: ContractIntro
	for child in main.ui_layer.get_children():
		if child is ContractIntro:
			intro = child
	check(intro != null, "新游戏先播契约分镜")
	check(ContractIntro.PANEL_SECONDS * ContractIntro.PANELS.size() == 144.0, "分镜未跳过时长144秒")
	if intro != null:
		await _click((intro.get_child(0) as Button).get_global_rect().get_center())
	await _frames(4)
	check(Game.story_flag("saw_p00"), "跳过演出后契约进度落档")
	check(main._museum != null, "契约直接进入教学关")
	await _skip_dialogue()


func _test_tutorial_direct_hub() -> void:
	# P2-B：城西教学关成功撤离 → 不弹独立 ResultScreen，直接进安全屋并播 P-01。
	Game.reset_progress()
	Game.set_story_flag("saw_p00")
	main.show_menu()
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
	museum.escaped.emit()
	await _wait(1.2)
	var result_screen := false
	for child in main.ui_layer.get_children():
		if child is ResultScreen:
			result_screen = true
	check(not result_screen, "P2-B：城西成功撤离不弹独立结算页")
	check(main._hub != null, "P2-B：直接进入安全屋")
	check(main.dialogue_tree.is_active(), "P2-B：进安全屋播 P-01")
	if main.dialogue_tree.is_active():
		await _finish_story_tree()
	check(Game.story_flag("saw_p01"), "P2-B：P-01 落档")


func _test_sell_tab() -> void:
	# 据点「销赃」页：真实点击标签 → 逐件卖出 → 全部出手
	Game.reset_progress()
	Game.loot_stash = [] as Array[String]
	var items: Array[String] = ["vase", "gem"]
	Game.loot_stash = items
	Game.set_story_flag("saw_p01")
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
	var first_row: PanelContainer = hub.sell_list.get_child(0)
	var sell_button: Button = first_row.get_child(0).get_child(2)
	await _click(sell_button.get_global_rect().get_center())
	check(Game.money == money_before + 120, "点击卖出获得对应金币")
	check(Game.loot_stash.size() == 1, "卖出的物品移出仓库")

	await _click(hub.sell_all_button.get_global_rect().get_center())
	check(Game.loot_stash.is_empty(), "全部出手后仓库清空")
	check(Game.money == money_before + 420, "全部出手结清剩余金币")


func _test_hub_phone() -> void:
	# P0-2：据点按 P 打开手机，只显示任务页、不暂停、档案页隐藏。
	Game.reset_progress()
	Game.set_story_flag("saw_p01")
	main.show_menu()
	await _frames(4)
	# 等手机/背包关闭留下的按键冷却过去（open_phone 有 0.2s 冷却）。
	await _wait(0.3)
	check(main._hub != null, "P0-2：据点已打开")
	if main._hub == null:
		return
	await _tap(KEY_P)
	check(main.phone.is_open(), "P0-2：据点按 P 打开手机")
	check(not get_tree().paused, "P0-2：据点打开手机不暂停")
	check(not main.phone.tab_archive.visible, "P0-2：据点手机隐藏档案标签")
	check(not main.phone.archive_page.visible, "P0-2：据点手机隐藏档案页")
	check(main.phone.task_page.visible, "P0-2：据点手机显示任务页")
	await _tap(KEY_P)
	check(not main.phone.is_open(), "P0-2：据点再按 P 关闭手机")


func _test_hub_stories() -> void:
	# P-01：城西教学关完成后首次回据点。
	Game.reset_progress()
	Game.set_story_flag("completed_museum")
	main.show_menu()
	await _frames(2)
	check(main.dialogue_tree.is_active(), "P-01：教学关后首次回据点播放剧情")
	if main.dialogue_tree.is_active():
		await _finish_story_tree()
	check(Game.story_flag("saw_p01"), "P-01：saw_p01 落档")
	check(not main.dialogue_tree.is_active(), "P-01：剧情结束后关闭")
	check(main._hub != null, "P-01：剧情结束后回到据点")

	# H-01：完成第一次任务后回据点。
	Game.reset_progress()
	Game.set_story_flag("saw_p01")
	Game.set_story_flag("completed_museum")
	main.show_menu()
	await _frames(2)
	check(main.dialogue_tree.is_active(), "H-01：首次任务后回据点播放标签课")
	if main.dialogue_tree.is_active():
		await _finish_story_tree()
	check(Game.story_flag("saw_h01"), "H-01：saw_h01 落档")
	check(not main.dialogue_tree.is_active(), "H-01：剧情结束后关闭")

	# H-02：大英任务开始前（先跳过 H-01，只测 H-02）。
	Game.reset_progress()
	Game.set_story_flag("saw_p01")
	Game.set_story_flag("saw_h01")
	main.show_menu()
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
	main.show_menu()
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


func _test_route_planning() -> void:
	# 路线预演系统：Tab 进入规划模式 → 左键添加节点 → 空格执行 → 方向键接管 →
	# 程序化进入失败回放 → 空格回退并重新规划。
	var museum: Museum = main._museum
	check(museum != null, "路线预演：当前处于关卡内")
	if museum == null:
		return
	# 关掉守卫 AI，避免测试期间被意外发现。
	for cop in museum.police:
		cop.set_ai_enabled(false)
	await _frames(2)

	await _tap(KEY_TAB)
	check(museum.planning_mode, "Tab 进入规划模式")
	check(not museum.police[0].ai_enabled, "规划模式下守卫 AI 冻结")

	var click_world := museum.player.global_position + Vector2(32, 0)
	# 真实玩家看到的是相机缩放后的屏幕坐标（zoom=2）；用 canvas transform 反推屏幕位置。
	var click_screen: Vector2 = museum.get_viewport().get_canvas_transform() * click_world
	await _click(click_screen)
	check(museum.planned_points.size() == 1, "左键点击添加规划节点")
	check(museum.planned_points[0].distance_to(click_world) < 8.0, "节点落在点击位置附近（世界坐标）")

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
	check(museum.police[0].ai_enabled, "退出规划模式后守卫 AI 恢复")
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
	check(museum.planned_points.is_empty(), "回退后清空规划节点")
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
	await _test_route_planning()
	await _test_leave_scene_clean()
	await _test_relic_closeup()
	await _test_statements_from_title()
	await _test_title_collection()
	await _test_new_game_opening()
	await _test_tutorial_direct_hub()
	await _test_sell_tab()
	await _test_phone_archive_footer()
	await _test_hub_phone()
	await _test_investigation_inputs()
	await _test_hub_stories()
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
	# BM 剧情交互测试只测关卡内行为，跳过据点入场剧情 P-01、H-01 与大英任务前 H-02。
	Game.set_story_flag("saw_p01")
	Game.set_story_flag("saw_h01")
	Game.set_story_flag("saw_h02")
	main.show_menu()
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
	Game.set_story_flag("saw_p00")
	Game.set_story_flag("saw_p01")
	Game.set_story_flag("saw_h01")
	main.show_menu()
	await _frames(4)
	await _wait(0.3)
	await _tap(KEY_P)
	var header := main.phone.tab_task.get_parent()
	await _click((header.get_child(header.get_child_count() - 2) as Button).get_global_rect().get_center())
	check(main.phone.extra_page.visible, "真实鼠标打开日历")
	await _click((header.get_child(header.get_child_count() - 1) as Button).get_global_rect().get_center())
	await _click((main.phone.extra_page.get_child(0) as Button).get_global_rect().get_center())
	check(main.phone.call_label.text.contains("恶魔"), "真实鼠标接听NPC对话")
	await _tap(KEY_ESCAPE)
	await _wait(0.3)
	var hub: Hub = main._hub
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
