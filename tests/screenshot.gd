extends Node
## Screenshot helper (not part of the game): boots the real Main scene and
## grabs key frames.  Run with:
##   godot --audio-driver Dummy res://tests/screenshot.tscn

func _ready() -> void:
	Game.money = 650
	Game.smoke_count = 2
	var main := load("res://src/main.tscn").instantiate() as Main
	add_child(main)
	await _wait(0.8)
	await _shot("/tmp/shot_title.png")

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
		museum.player.global_position = mask.global_position + Vector2(0, 28)
		mask.try_pickup()
		await _wait(0.8)
		_skip_dialogue(main)
		await _wait(0.3)
		await _shot("/tmp/shot_room3.png")

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
			2: Vector2(31 * 16 + 8, 20 * 16 + 8),
			3: Vector2(9 * 16 + 8, 20 * 16 + 8),
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
			bm.player.global_position = zun.global_position + Vector2(0, 28)
			await _wait(1.2)
			await _shot("/tmp/shot_bm_zun.png")
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
	Audio.shutdown()
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
