extends Node
## Screenshot helper (not part of the game): boots the real Main scene and
## grabs key frames.  Run with:
##   godot --audio-driver Dummy res://tests/screenshot.tscn

func _ready() -> void:
	# 截图流程隔离存档，避免覆盖玩家真实进度（也让截图更可复现）
	Game.save_path = "/tmp/thief_sim_screenshot_save.json"
	# 截图要确定性：先清进度，再写入固定状态（避免继承上一次运行/玩家存档）
	Game.reset_progress()
	Game.money = 650
	Game.backpack_level = 1
	Game.smoke_count = 2
	Game.archive_seen = {"mask": true, "ram_zun": true}
	Game.save_game()
	# 鼠标悬停会给按钮加 hover 样式；把指针移到角落，保证 UI 截图可复现
	Input.warp_mouse(Vector2(2, 2))
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

	main.show_menu()
	await _wait(0.6)
	await _shot("/tmp/shot_hub.png")

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
	museum.ghost_delay = 60.0
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
		museum.ghost_delay = 1.6  # 让 room3 截图先拍到，再触发器灵对谈
		museum.player.global_position = mask.global_position + Vector2(0, 28)
		mask.try_pickup()
		await _wait(0.8)
		_skip_dialogue(main)
		await _wait(0.3)
		await _shot("/tmp/shot_room3.png")

	# 文物志：器灵对谈（选项 → 展签卡）
	await _wait(0.9)
	if main.dialogue_tree.is_active():
		await _shot("/tmp/shot_lore_dialogue.png")
		main.dialogue_tree.advance()
		await _wait(0.2)
		main.dialogue_tree.advance()
		await _wait(0.2)
		await _shot("/tmp/shot_lore_choices.png")
		if not main.dialogue_tree._choice_buttons.is_empty():
			main.dialogue_tree._choice_buttons[0].pressed.emit()
			await _wait(0.2)
			main.dialogue_tree.advance()
			await _wait(0.2)
			await _shot("/tmp/shot_lore_card.png")
		while main.dialogue_tree.is_active():
			main.dialogue_tree.advance()
			await _wait(0.05)
		await _wait(0.2)

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

	# busted -> result screen
	if not museum.police.is_empty():
		var catcher: Police = museum.police[2]
		catcher.set_ai_enabled(true)
		museum.player.global_position = catcher.global_position
	await _wait(2.0)
	await _shot("/tmp/shot_result.png")

	# 大英博物馆·中国馆：目标「商代双羊尊」与器灵
	main.show_menu()
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
		bm.ghost_delay = 0.3
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
			await _wait(0.4)
			await _shot("/tmp/shot_bm_ghost.png")
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
	# 据点：销赃页
	var stash: Array[String] = ["vase", "gem", "jade"]
	Game.loot_stash = stash
	main.show_menu()
	await _wait(0.4)
	var hub: Hub = null
	for child in main.get_node("UILayer").get_children():
		if child is Hub:
			hub = child
	if hub != null:
		hub._show_tab("sell")
		await _wait(0.3)
		await _shot("/tmp/shot_sell.png")

	Audio.shutdown()
	# 与冒烟测试相同的优雅退出：等音频服务端释放引用、再跑几帧，避免退出时误报泄漏
	await get_tree().create_timer(0.4).timeout
	for i in 5:
		await get_tree().process_frame
	get_tree().quit()


func _skip_dialogue(main: Main) -> void:
	while main.dialogue.is_active():
		main.dialogue.advance()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved ", path)
