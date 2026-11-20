extends Node
## Screenshot helper (not part of the game): boots the real Main scene and
## grabs key frames.  Run with:
##   godot --audio-driver Dummy res://tests/screenshot.tscn

func _ready() -> void:
	# 后台静默运行：不抢用户桌面焦点、放到屏幕可视区外，且绝不调用 Input.warp_mouse 抢占系统鼠标
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-32000, -32000))
	# 截图流程隔离存档，避免覆盖玩家真实进度（也让截图更可复现）
	Game.save_path = "/tmp/thief_sim_screenshot_save.json"
	# 截图要确定性：先清进度，再写入固定状态（避免继承上一次运行/玩家存档）
	Game.reset_progress()
	Game.money = 650
	Game.backpack_level = 1
	Game.smoke_count = 2
	Game.archive_seen = {"mask": true, "ram_zun": true}
	# 截图流程只关注 UI 与关卡画面，跳过据点剧情，避免 show_menu/start_mission 被剧情阻塞。
	Game.set_story_flag("saw_p01")
	Game.set_story_flag("saw_h01")
	Game.set_story_flag("saw_h02")
	Game.save_game()
	var main := load("res://src/main.tscn").instantiate() as Main
	add_child(main)
	await _wait(0.8)
	await _shot("/tmp/shot_title.png")

	# 声明与说明
	var title: TitleScreen = null
	for child in main.get_node("UILayer").get_children():
		if child is TitleScreen:
			title = child
	if title != null:
		title.statements_button.pressed.emit()
		await _wait(0.4)
		await _shot("/tmp/shot_statements.png")
		main.statements.close()
		await _wait(0.2)

	# 文物档案收集册（标题页入口）
	main.collection.open()
	await _wait(0.4)
	await _shot("/tmp/shot_collection.png")
	main.collection.close()
	await _wait(0.2)

	main.show_safehouse()
	await _wait(0.6)
	await _shot("/tmp/shot_safehouse.png")

	# 安全屋设备：书桌电脑覆盖层（R-01）
	main._open_computer()
	await _wait(0.3)
	await _shot("/tmp/shot_computer.png")
	main.computer.close()
	await _wait(0.2)

	var intro := ContractIntro.new()
	main.ui_layer.add_child(intro)
	intro.panel_index = 4
	intro._refresh()
	intro.set_process(false)
	intro.queue_redraw()
	await _wait(0.2)
	await _shot("/tmp/shot_contract_intro.png")
	for page in range(OpeningCG.PANELS.size()):
		intro.panel_index = page
		intro._refresh()
		await _wait(0.1)
		await _shot("/tmp/shot_contract_intro_%02d.png" % (page + 1))
	intro.queue_free()

	# 旧 Hub 推理板内容改用独立宿主截图（正式流程已不进入旧栏目页）
	var hub := (load("res://src/ui/hub.tscn") as PackedScene).instantiate() as Hub
	main.ui_layer.add_child(hub)
	hub._show_tab("reason")
	for cid in EvidenceData.chain_ids():
		for clue in Game.clues_for_chain(cid):
			Game.collect_clue(clue.id)
	hub._on_reason_app_selected("board")
	await _wait(0.3)
	await _shot("/tmp/shot_evidence_board.png")
	hub.queue_free()
	await _wait(0.2)

	# 手机：通讯录 / 日历（安全屋内打开；安全屋手机同样暂停世界）
	main.open_phone()
	main.phone._show_tab("通讯录")
	await _wait(0.3)
	await _shot("/tmp/shot_contacts.png")
	main.phone._show_tab("日历")
	await _wait(0.3)
	await _shot("/tmp/shot_calendar.png")
	main.phone.close()
	await _wait(0.2)
	for id in ["egypt_heart_scarab", "akrotiri_askos"]:
		main.relic_closeup.open(id, false)
		await _wait(0.5)
		await _shot("/tmp/shot_pack_%s.png" % id)
		main.relic_closeup.close()

	main.start_mission()
	await _wait(0.6)
	await _shot("/tmp/shot_dialogue.png")
	_skip_dialogue(main)

	var museum: Museum = null
	for child in main.get_node("Screen").get_children():
		if child is Museum:
			museum = child
	if museum == null or museum.player == null:
		get_tree().quit()
		return
	for cop in museum.police:
		cop.set_ai_enabled(false)

	# room 0: entrance hall
	museum.player.global_position = Vector2(8 * 16, 8 * 16)
	await _wait(1.0)
	await _shot("/tmp/shot_room0.png")

	# room 1: gallery with carpet and paintings
	museum.player.global_position = Vector2(22 * 16 + 160, 96)
	await _wait(1.2)
	await _shot("/tmp/shot_gallery.png")

	# suspicion: the room-0 guard investigates a noise
	var cop: Police = museum.police[1]
	cop.set_ai_enabled(true)
	cop.patrol_points = []
	cop.global_position = Vector2(8 * 16 + 8, 6 * 16 + 8)
	museum.player.global_position = Vector2(10 * 16 + 8, 6 * 16 + 8)
	museum.player.made_noise.emit(museum.player.global_position, 64.0)
	await _wait(0.15)
	await _shot("/tmp/shot_alert.png")

	# smoke him off
	museum.player.use_item("smoke")
	await _wait(0.25)
	await _shot("/tmp/shot_smoke.png")
	# 此后截图固定关闭AI；规划冻结/恢复应保留这个独立开关。
	for p_cop in museum.police:
		p_cop.set_ai_enabled(false)

	# 路线预演：规划模式 + 节点连线 + 预测标签（清掉 smoke toast 保持画面干净）
	main.hud.clear_toast()
	museum.toggle_planning_mode(true)
	museum.planned_points = [
		Vector2(9 * 16, 8 * 16),
		Vector2(11 * 16, 7 * 16),
		Vector2(13 * 16, 9 * 16),
	]
	await _wait(0.4)
	await _shot("/tmp/shot_planning.png")
	museum.toggle_planning_mode(false)
	await _wait(0.2)
	# 退出规划不再覆盖截图固定关闭的AI，也不会额外跑动0.2秒。

	# 任务终端（手机）
	main.open_phone()
	await _wait(0.4)
	await _shot("/tmp/shot_phone.png")
	main.phone.close()
	await _wait(0.2)

	# room 3: central hall, grab the target
	var mask: Artifact = null
	for child in museum.get_children():
		if child is Artifact and child.item_id == "mask":
			mask = child
	if mask != null:
		museum.player.global_position = mask.global_position + Vector2(0, 28)
		mask.try_pickup()
		await _wait(0.8)
		_skip_dialogue(main)
		await _wait(0.3)
		await _shot("/tmp/shot_room3.png")

	# 手机档案页：端详（热点 + 展签卡）
	main.open_phone()
	await _wait(0.3)
	main.phone._show_tab("archive")
	await _wait(0.3)
	main.phone.inspect._select_hotspot(0)
	await _wait(0.2)
	await _shot("/tmp/shot_inspect.png")
	main.phone.close()
	await _wait(0.2)

	# backpack management screen
	main.open_backpack()
	await _wait(0.4)
	await _shot("/tmp/shot_backpack.png")
	main.backpack.close()
	await _wait(0.2)

	# 路线预演失败回放：红色高亮连线 + 原因标签
	if not museum.police.is_empty():
		var catcher: Police = museum.police[2]
		catcher.global_position = Vector2(10 * 16 + 8, 6 * 16 + 8)
		museum.player.global_position = catcher.global_position + Vector2(36, 0)
		museum.enter_failure_replay(catcher, "保安巡逻视野")
		await _wait(0.4)
		await _shot("/tmp/shot_failure_replay.png")
		museum._rewind_and_replan()
		await _wait(0.2)

	# 大英博物馆·中国馆：目标「商代双羊尊」
	main.show_safehouse()
	await _wait(0.3)
	main.start_mission("british_museum")
	await _wait(0.6)
	_skip_dialogue(main)
	var bm: Museum = null
	for child in main.get_node("Screen").get_children():
		if child is Museum:
			bm = child
	if bm != null and bm.player != null:
		for bm_cop in bm.police:
			bm_cop.set_ai_enabled(false)
		# 六展厅主题巡检（Room 0..5）
		var bm_spots := {
			0: Vector2(8 * 16 + 8, 8 * 16 + 8),
			1: Vector2(31 * 16 + 8, 6 * 16 + 8),
			2: Vector2(31 * 16 + 8, 16 * 16 + 8),
			3: Vector2(6 * 16 + 8, 21 * 16 + 8),
			4: Vector2(9 * 16 + 8, 34 * 16 + 8),
			5: Vector2(31 * 16 + 8, 34 * 16 + 8),
		}
		for room_id in bm_spots:
			bm.player.global_position = bm_spots[room_id]
			await _wait(0.8)
			await _shot("/tmp/shot_bm_room%d.png" % room_id)
		var zun: Artifact = null
		for child in bm.get_children():
			if child is Artifact and child.item_id == "ram_zun":
				zun = child
		if zun != null:
			bm.player.global_position = zun.global_position + Vector2(-28, 0)
			await _wait(1.2)
			await _shot("/tmp/shot_bm_zun.png")
			# 2.5D 互动特写层（按 E 触碰文物）
			main.open_relic_closeup("ram_zun")
			await _wait(0.5)
			await _shot("/tmp/shot_bm_closeup.png")
			main.relic_closeup.close()
			await _wait(0.2)
			# 任务终端里的 3D 双羊尊
			main.open_phone()
			await _wait(0.4)
			await _shot("/tmp/shot_bm_phone.png")
			main.phone.close()
			await _wait(0.2)
			zun.try_pickup()
			await _wait(0.8)
			_skip_dialogue(main)
			# 背包里的双羊尊 32×32 图标（bm_zun_32.png）
			main.open_backpack()
			await _wait(0.4)
			await _shot("/tmp/shot_bm_backpack.png")
			main.backpack.close()
			await _wait(0.2)
			# 档案页：双羊尊的端详图（混元 3D 渲染的特写，而非 24×24 图标放大）
			main.open_phone()
			await _wait(0.4)
			main.phone._show_tab("archive")
			await _wait(0.3)
			await _shot("/tmp/shot_bm_archive.png")
			main.phone.close()
			await _wait(0.2)
		# 大英博物馆 Room 3 剧情：馆方标签 / 观众留言 / 双纸对谈（S-03）
		bm.player.global_position = bm.BM_LABEL_POS + Vector2(0, -18)
		await _wait(0.3)
		bm.player.story_trigger_requested.emit("story_label")
		await _wait(0.4)
		await _shot("/tmp/shot_bm_label.png")
		_skip_dialogue_tree(main)
		await _wait(0.2)
		bm.player.global_position = bm.BM_NOTE_POS + Vector2(0, -18)
		await _wait(0.2)
		bm.player.story_trigger_requested.emit("story_note")
		await _wait(0.4)
		await _shot("/tmp/shot_bm_note.png")
		_advance_tree_to_choices(main)
		await _wait(0.2)
		if not main.dialogue_tree._choice_buttons.is_empty():
			main.dialogue_tree._choice_buttons[0].grab_focus()
		await _shot("/tmp/shot_bm_both.png", true)
		_skip_dialogue_tree(main)
		await _wait(0.2)
	# 安全屋：文物箱（箱内战利品过渡直售，R-05 换手机预约交货）
	var stash: Array[String] = ["vase", "gem", "jade"]
	Game.loot_stash = stash
	main.show_safehouse()
	await _wait(0.4)
	main._open_box()
	await _wait(0.3)
	await _shot("/tmp/shot_box.png")
	main.box.close()
	await _wait(0.2)

	Audio.shutdown()
	# 与冒烟测试相同的优雅退出：等音频服务端释放引用、再跑几帧，避免退出时误报泄漏
	await get_tree().create_timer(0.4).timeout
	for i in 5:
		await get_tree().process_frame
	get_tree().quit()


func _skip_dialogue(main: Main) -> void:
	while main.dialogue.is_active():
		main.dialogue.advance()


## 剧情对谈/展签卡：一路确认选项直到结束（截图流程用；真实玩家由按键驱动）。
func _skip_dialogue_tree(main: Main) -> void:
	var guard := 0
	while main.dialogue_tree.is_active() and guard < 200:
		if main.dialogue_tree.choices_box.visible and not main.dialogue_tree._choice_buttons.is_empty():
			main.dialogue_tree._choice_buttons[0].pressed.emit()
		else:
			main.dialogue_tree.advance()
		guard += 1


## 推进对谈直到出现选项（用于截取「双纸对谈」的选项画面）。
func _advance_tree_to_choices(main: Main) -> void:
	var guard := 0
	while main.dialogue_tree.is_active() and guard < 200:
		if main.dialogue_tree.choices_box.visible:
			return
		main.dialogue_tree.advance()
		guard += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(path: String, keep_focus := false) -> void:
	# 截图要可复现：默认清掉键盘焦点（绝不调用 Input.warp_mouse 抢占系统鼠标）；
	# 选项类截图需要"当前选中"焦点框，调用时 keep_focus=true（并显式 grab_focus）。
	if not keep_focus:
		get_viewport().gui_release_focus()
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved ", path)
