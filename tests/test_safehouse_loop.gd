extends Node
## R-12a/D 闭环集成：真实键鼠驱动的完整经济循环。
##
## 覆盖（Codex #892 要求的可复跑全链）：
##   大英普通拾取（真实 E）→ 侦察撤离（真实走到出口）→ 战利品入箱
##   → 手机交易预约（真实点击）→ 文物箱取出 → 房门交货确认（真实点击）
##   → 手机采购买烟雾（真实点击）→ 委托确认 → 房门出发 → 下趟馆内 Q 消耗。
##
## 运行：godot --headless res://tests/test_safehouse_loop.tscn
## 说明：馆内寻路用既有场景原语（传送 + 场景 API），与冒烟/输入流一致；
## UI 链（手机/文物箱/交货/门）全部真实输入事件驱动。

const SAVE := "/tmp/thief_sim_loop_save.json"

var _failures := 0
var _checks := 0
var main: Main


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL - " + msg)


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


func _physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _skip_dialogue() -> void:
	var guard := 0
	while main.dialogue.is_active() and guard < 60:
		main.dialogue.advance()
		await _frames(1)
		guard += 1


func _find_button_with_text(root: Node, needle: String) -> Button:
	for child in root.get_children():
		if child is Button and (child as Button).text.contains(needle):
			return child
		if child is Control:
			var inner := _find_button_with_text(child, needle)
			if inner != null:
				return inner
	return null


func _ready() -> void:
	Game.save_path = SAVE
	Game.reset_progress()
	# 解锁三链 + 跳过据点剧情，保证循环不被任务门槛/剧情 await 阻塞。
	for flag in ["saw_p00", "saw_p01", "saw_h01", "saw_h02", "chain_ram_zun_done", "chain_egypt_heart_scarab_done", "chain_akrotiri_askos_done"]:
		Game.set_story_flag(flag)
	main = load("res://src/main.tscn").instantiate() as Main
	add_child(main)
	await _frames(4)

	await _phase_bm_recon()
	await _phase_safehouse_trade()
	await _phase_shop_and_next_run()

	Audio.shutdown()
	await get_tree().create_timer(0.4, true).timeout
	await _frames(5)
	if _failures > 0:
		print("FAILED %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
	else:
		print("ALL %d CHECKS PASSED" % _checks)
		get_tree().quit(0)


## 阶段一：大英博物馆拾取普通战利品 → 真实走到出口 → 侦察撤离回安全屋。
func _phase_bm_recon() -> void:
	main.start_mission("british_museum")
	await _frames(4)
	await _skip_dialogue()
	var museum: Museum = main._museum
	check(museum != null, "循环：大英博物馆已进入")
	if museum == null:
		return
	for cop in museum.police:
		cop.set_ai_enabled(false)
	# 测试侧放置一件普通战利品（BM 关卡本身不生成普通物；场景 API 同冒烟测试）。
	museum._spawn_artifact("vase", Vector2(10 * 16 + 8, 8 * 16 + 8))
	await _physics_frames(2)
	var vase: Artifact = null
	for child in museum.get_children():
		if child is Artifact and child.item_id == "vase":
			vase = child
	check(vase != null, "循环：测试战利品已放置")
	if vase == null:
		return
	# 真实 E 拾取普通战利品（大英新规则：普通物可拾）。
	museum.player.global_position = vase.global_position + Vector2(0, 20)
	await _physics_frames(3)
	await _tap(KEY_E)
	await _frames(4)
	check(_has_item("vase"), "循环：大英真实 E 拾取普通战利品")
	check(not Game.mission_complete, "循环：未带主目标不算完成任务")
	# 真实走到出口：传送至出口区域触发撤离（侦察结算）。
	var exit_pos := Vector2.ZERO
	for child in museum.get_children():
		if child is Area2D and child.name == "Exit":
			exit_pos = (child as Area2D).global_position
	check(exit_pos != Vector2.ZERO, "循环：找到出口区域")
	museum.player.global_position = exit_pos
	await _physics_frames(3)
	await _wait(1.2)
	check(main._safehouse != null, "循环：侦察撤离直回安全屋（不弹结算页）")
	check(Game.loot_stash.has("vase"), "循环：侦察撤离普通战利品入箱")
	check(not Game.story_flag("completed_british_museum"), "循环：侦察撤离不记主任务完成")
	Game.set_level("british_museum")  # 重新对准目标上下文（手机委托用）


## 在委托页按关卡名提示找到对应「准备出发」按钮（每行 = 标签 + 按钮）。
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


## 阶段二：手机交易预约 → 文物箱取出预约货 → 房门交货一次性收钱。
func _phase_safehouse_trade() -> void:
	var house := main._safehouse
	if house == null:
		return
	var p: Player = house.player
	# 手机交易：预约花瓶。
	await _tap(KEY_P)
	check(main.phone.is_open(), "交易：打开手机")
	await _click(main.phone.app_button("trade").get_global_rect().get_center())
	check(main.phone.trade_list.is_visible_in_tree(), "交易：交易页打开")
	var reserve: Button = _find_button_with_text(main.phone.trade_list, "预约一件")
	check(reserve != null, "交易：有预约按钮")
	if reserve == null:
		main.phone.close()
		return
	await _click(reserve.get_global_rect().get_center())
	check(int(Game.loot_reserved.get("vase", 0)) == 1, "交易：预约落档（不扣货不发钱）")
	await _tap(KEY_P)
	check(not main.phone.is_open(), "交易：关闭手机")
	await _wait(0.3)
	# 文物箱取出预约货（自动带 reserved 标记）。
	p.global_position = Vector2(272, 142)
	await _physics_frames(3)
	await _tap(KEY_E)
	check(main.box.is_open(), "交易：打开文物箱")
	var stash_row = main.box.stash_list.get_child(0)
	var take: Button = null
	for child in stash_row.get_children():
		if child is Button and (child as Button).text.contains("取出"):
			take = child
	check(take != null, "交易：箱内有取出按钮")
	if take != null:
		await _click(take.get_global_rect().get_center())
	check(Game.bag_items.size() == 1 and bool(Game.bag_items[0].get("reserved", false)), "交易：取出带预约标记")
	await _tap(KEY_ESCAPE)
	check(not main.box.is_open(), "交易：关闭文物箱")
	await _wait(0.3)
	# 房门交货：门口 E → 交货面板 → 确认 → 一次性收钱。
	p.global_position = Vector2(152, 136)
	await _physics_frames(3)
	var money_before := Game.money
	await _tap(KEY_E)
	check(main.delivery.is_open(), "交易：门口 E 打开交货面板")
	var confirm: Button = main.delivery.confirm_button
	await _click(confirm.get_global_rect().get_center())
	await _frames(4)
	check(Game.money == money_before + 120, "交易：交货一次性收 120 金（实际 %d）" % Game.money)
	check(Game.bag_items.is_empty() and Game.loot_reserved.is_empty(), "交易：货清、预约清")
	check(not main.delivery.is_open(), "交易：结算后面板关闭")
	await _wait(0.3)


## 阶段三：手机采购买烟雾 → 委托确认 → 房门出发 → 下趟馆内 Q 消耗携带。
func _phase_shop_and_next_run() -> void:
	var house := main._safehouse
	var p: Player = house.player
	Game.money = 300  # 预置资金用于采购段（交货所得已在阶段二验证）。
	await _tap(KEY_P)
	check(main.phone.is_open(), "采购：打开手机")
	await _click(main.phone.app_button("shop").get_global_rect().get_center())
	check(main.phone.shop_list.is_visible_in_tree(), "采购：采购页打开")
	var buy_smoke: Button = _find_button_with_text(main.phone.shop_list, "购买")
	check(buy_smoke != null and not buy_smoke.disabled, "采购：烟雾弹可购买")
	if buy_smoke == null:
		main.phone.close()
		return
	await _click(buy_smoke.get_global_rect().get_center())
	check(Game.smoke_stock == 1 and Game.money == 180, "采购：一次点击一次扣款一次发货（实际 %d 金）" % Game.money)
	# 委托确认行动（回首页 → 真实点击大英行的准备出发）。
	var home_btn: Button = main.phone.get_node("Root/Panel/Margin/VBox/Header/HomeButton")
	await _click(home_btn.get_global_rect().get_center())
	check(main.phone.home_page.visible, "采购：返回应用首页")
	await _click(main.phone.app_button("task").get_global_rect().get_center())
	check(main.phone.missions_box.is_visible_in_tree(), "采购：委托页打开")
	var prepare: Button = _find_mission_prepare("大英")
	check(prepare != null, "采购：委托有大英「准备出发」")
	if prepare == null:
		main.phone.close()
		return
	await _click(prepare.get_global_rect().get_center())
	check(Game.pending_mission_level == "british_museum", "采购：委托确认落档")
	await _tap(KEY_P)
	check(not main.phone.is_open(), "采购：关闭手机")
	await _wait(0.3)
	# 房门出发：备货并入携带。
	p.global_position = Vector2(152, 136)
	await _physics_frames(3)
	await _tap(KEY_E)
	await _frames(6)
	check(main._museum != null, "采购：出发进入大英")
	check(Game.smoke_count == 1 and Game.smoke_stock == 0, "采购：出发装载 备货1→携带1（实际 %d/%d）" % [Game.smoke_count, Game.smoke_stock])
	await _skip_dialogue()
	# 下趟馆内 Q 消耗（真实 Q 键）。
	var museum: Museum = main._museum
	if museum != null:
		for cop in museum.police:
			cop.set_ai_enabled(false)
	await _tap(KEY_Q)
	await _frames(4)
	check(Game.smoke_count == 0, "采购：馆内 Q 消耗携带烟雾（实际 %d）" % Game.smoke_count)
