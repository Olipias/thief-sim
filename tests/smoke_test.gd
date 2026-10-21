extends Node
## Integration smoke test: builds the real museum scene headless and
## exercises pickup, bust and escape flows.  Run with:
##   godot --headless res://tests/smoke_test.tscn

var _failures := 0
var _checks := 0


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL - " + msg)


func _ready() -> void:
	Game.save_path = "/tmp/thief_sim_smoke_save.json"
	Game.reset_progress()
	Game.lore_stage.clear()
	Game.lore_found.clear()
	check(Audio._streams.size() == 10, "audio streams loaded")
	Audio.play("pickup")
	await _test_bust_flow()
	await _test_smoke_bomb()
	await _test_noise_alerts()
	await _test_dialogue_box()
	await _test_ghost()
	await _test_ghost_calm()
	await _test_haunting()
	await _test_room_camera()
	await _test_british_museum_level()
	await _test_bag_screen()
	await _test_title_screen()
	await _test_hub_levels()
	await _test_mission_phone()
	await _test_tutorial_balance()
	await _test_dialogue_tree()
	await _test_inspect_page()
	await _test_ghost_talk()
	await _test_backpack_drop()
	await _test_drop_artifact()
	await _test_minimap()
	await _test_escape_flow()
	if _failures > 0:
		print("FAILED %d / %d checks" % [_failures, _checks])
		await _shutdown_audio()
		get_tree().quit(1)
	else:
		print("ALL %d CHECKS PASSED" % _checks)
		await _shutdown_audio()
		get_tree().quit(0)


## Stop all SFX and give the (dummy) audio server time to release its
## playbacks, otherwise exiting reports phantom leak warnings.
func _shutdown_audio() -> void:
	Audio.shutdown()
	await get_tree().create_timer(0.4).timeout
	for i in 5:
		await get_tree().process_frame


func _make_museum(level_id := "museum") -> Museum:
	Game.set_level(level_id)
	var museum := load("res://src/world/museum.tscn").instantiate() as Museum
	museum.level_id = level_id
	add_child(museum)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return museum


func _test_bust_flow() -> void:
	Game.reset_run()
	var museum := await _make_museum()

	check(museum.player != null, "player spawned")
	check(museum.police.size() == 7, "seven police spawned")

	var mask: Artifact = null
	for child in museum.get_children():
		if child is Artifact and child.item_id == "mask":
			mask = child
	check(mask != null, "mission target exists on the map")
	check(mask.try_pickup(), "mission target can be picked up")
	check(Game.mission_complete, "picking the target completes the mission")

	var busted := {"value": false}
	museum.caught.connect(func() -> void: busted["value"] = true)
	var cop: Police = museum.police[0]
	museum.player.global_position = cop.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(busted["value"], "touching a cop busts the run")

	museum.end_game()
	museum.queue_free()
	await get_tree().process_frame


func _test_smoke_bomb() -> void:
	Game.reset_run()
	var museum := await _make_museum()

	var cop: Police = museum.police[1]
	cop.patrol_points = []
	cop.spot_delay_scale = 1.0  # 固定时序，避免受关卡调参影响
	cop.global_position = Vector2(10 * 16 + 8, 6 * 16 + 8)
	museum.player.global_position = cop.global_position + Vector2(40, 0)
	cop._facing = Vector2.RIGHT

	for i in 40:
		await get_tree().physics_frame
	check(cop.is_chasing(), "cop enters chase after spotting the player")

	Game.smoke_count = 1
	museum.player.use_item("smoke")
	await get_tree().physics_frame
	check(Game.smoke_count == 0, "smoke bomb consumed on use")
	check(not cop.is_chasing(), "smoke breaks the chase")
	check(cop._blind_timer > 0.0, "cop is blinded")

	# blinded cop must not re-acquire the player standing in front of it
	for i in 10:
		await get_tree().physics_frame
	check(not cop.is_chasing(), "blinded cop stays unaware")

	museum.player.use_item("smoke")
	await get_tree().physics_frame
	check(Game.smoke_count == 0, "using an empty smoke bomb changes nothing")

	museum.end_game()
	museum.queue_free()
	await get_tree().process_frame


func _test_noise_alerts() -> void:
	Game.reset_run()
	var museum := await _make_museum()
	var cop: Police = museum.police[1]
	cop.patrol_points = []
	cop.spot_delay_scale = 1.0  # 固定时序，避免受关卡调参影响
	cop.global_position = Vector2(10 * 16 + 8, 6 * 16 + 8)
	museum.player.global_position = cop.global_position + Vector2(60, 0)
	var levels: Array[int] = []
	museum.alert_changed.connect(func(level: int) -> void: levels.append(level))

	museum.player.made_noise.emit(museum.player.global_position, 64.0)
	await get_tree().physics_frame
	check(cop.state == Police.State.INVESTIGATE, "cop investigates a noise")
	check(levels.has(1), "alert level 1 raised")
	check(museum.police[0].state == Police.State.PATROL, "distant cop did not hear the noise")

	for i in 30:
		await get_tree().physics_frame
	check(cop.state == Police.State.CHASE, "investigating cop spots the player")
	check(levels.has(2), "alert level 2 raised")

	Game.smoke_count = 1
	museum.player.use_item("smoke")
	await get_tree().physics_frame
	check(not cop.is_chasing(), "smoke resets an investigating chase")

	museum.end_game()
	museum.queue_free()
	await get_tree().process_frame


func _test_dialogue_box() -> void:
	var box := load("res://src/ui/dialogue_box.tscn").instantiate() as DialogueBox
	add_child(box)
	var done := {"value": false}
	box.finished.connect(func() -> void: done["value"] = true)
	box.show_dialogue([
		{"speaker": "老猫", "text": "第一句话。"},
		{"speaker": "老猫", "text": "第二句话。"},
	])
	check(box.is_active(), "dialogue box becomes active")
	box.advance()  # reveal line 1
	box.advance()  # move to line 2
	box.advance()  # reveal line 2
	box.advance()  # close
	check(done["value"], "dialogue finishes after the last line")
	check(not box.is_active(), "dialogue box hides after finishing")
	box.queue_free()
	await get_tree().process_frame


func _test_ghost() -> void:
	var ghost := load("res://src/world/ghost.tscn").instantiate() as Ghost
	ghost.wail_interval = 0.05
	ghost.lifetime = 0.3
	var wails := [0]
	ghost.wailed.connect(func(_pos: Vector2) -> void: wails[0] += 1)
	add_child(ghost)
	check(ghost.is_active(), "ghost is active when spawned")
	await get_tree().create_timer(0.25).timeout
	check(wails[0] >= 2, "ghost wails repeatedly")
	await get_tree().create_timer(0.15).timeout
	check(not ghost.is_active(), "ghost fades out after its lifetime")
	ghost.queue_free()
	await get_tree().process_frame


func _test_ghost_calm() -> void:
	var ghost := load("res://src/world/ghost.tscn").instantiate() as Ghost
	ghost.wail_interval = 0.05
	ghost.lifetime = 5.0
	var wails := [0]
	ghost.wailed.connect(func(_pos: Vector2) -> void: wails[0] += 1)
	add_child(ghost)
	await get_tree().create_timer(0.15).timeout
	check(wails[0] >= 1, "ghost wails before being calmed")
	ghost.calm(0.8)
	var after_calm: int = wails[0]
	await get_tree().create_timer(0.3).timeout
	check(wails[0] == after_calm, "calmed ghost stays quiet")
	await get_tree().create_timer(0.7).timeout
	check(wails[0] > after_calm, "ghost wails again once the calm window ends")
	ghost.queue_free()
	await get_tree().process_frame


func _test_haunting() -> void:
	Game.reset_run()
	var museum := await _make_museum()
	museum.ghost_delay = 0.05
	var cop: Police = museum.police[1]
	cop.patrol_points = []
	cop.global_position = Vector2(10 * 16 + 8, 6 * 16 + 8)
	museum.player.global_position = Vector2(10 * 16 + 8, 8 * 16 + 8)

	var mask: Artifact = null
	for child in museum.get_children():
		if child is Artifact and child.item_id == "mask":
			mask = child
	check(mask != null, "target exists for haunting")
	check(mask.try_pickup(), "target picked up for haunting")
	await get_tree().create_timer(0.2).timeout

	var ghost: Ghost = null
	for child in museum.get_children():
		if child is Ghost:
			ghost = child
	check(ghost != null, "haunting spawns a ghost after the target is taken")
	var toasts: Array[String] = []
	museum.toast.connect(func(text: String, _duration: float) -> void: toasts.append(text))
	if ghost != null:
		check(cop.state != Police.State.CHASE, "cop is calm before the wail")
		ghost.wailed.emit(ghost.global_position)
		await get_tree().physics_frame
		check(cop.state == Police.State.INVESTIGATE, "ghost wail lures a nearby cop")
		check(cop._investigate_stop >= 30.0, "lured cop searches from a distance")
		var warned := false
		for text in toasts:
			if "引来了警察" in text:
				warned = true
		check(warned, "wail that lures a cop warns the player")
		museum._talk_to_ghost()
		check(ghost.wail_cooldown() >= 7.5, "talking to the ghost calms it")

	museum.end_game()
	museum.queue_free()
	await get_tree().process_frame


func _test_room_camera() -> void:
	Game.reset_run()
	var museum := await _make_museum()
	check(museum.rooms.size() == 7, "museum has seven rooms")
	check(museum.room_index_at(museum.player.global_position) == 0, "player starts in room 0")

	var cam: Camera2D = museum.player.get_node("Camera2D")
	var room0: Rect2 = museum.rooms[0]
	check(
		cam.limit_left == int(room0.position.x) and cam.limit_top == int(room0.position.y),
		"camera starts locked to room 0",
	)

	var room3: Rect2 = museum.rooms[3]
	museum.player.global_position = room3.position + Vector2(64, 64)
	await get_tree().process_frame
	await get_tree().process_frame
	check(museum.current_room == 3, "entering a room updates the active room")
	check(
		cam.limit_left == int(room3.position.x) and cam.limit_top == int(room3.position.y),
		"camera follows into room 3",
	)
	check(museum.visited_rooms.has(0) and museum.visited_rooms.has(3), "visited rooms are tracked")
	check(museum.target_room == 3, "minimap knows the target room")
	check(museum.exit_room == 6, "minimap knows the exit room")

	museum.end_game()
	museum.queue_free()
	await get_tree().process_frame


func _test_backpack_drop() -> void:
	Game.reset_run()
	Game.try_pickup("vase")
	var screen := load("res://src/ui/backpack_screen.tscn").instantiate() as BackpackScreen
	add_child(screen)
	await get_tree().process_frame
	screen.open()
	var dropped := {"id": ""}
	screen.drop_requested.connect(func(item_id: String) -> void: dropped["id"] = item_id)

	check(screen.grab_at(Vector2i.ZERO), "mouse grab takes the item")
	check(Game.bag_items.is_empty(), "item leaves the grid while dragged")
	check(screen.place_at(Vector2i(1, 1)), "mouse drop places the item in a free cell")
	check(Game.item_at_cell(Vector2i(1, 1)) == 0, "item occupies the dropped cell")

	check(screen.grab_at(Vector2i(1, 1)), "grab again for the discard test")
	screen.drop_held()
	check(dropped["id"] == "vase", "dragging outside emits drop_requested")
	check(Game.bag_items.is_empty(), "discarded item leaves the bag")
	check(screen.held.is_empty(), "nothing held after discarding")

	screen.close()
	screen.queue_free()
	await get_tree().process_frame


func _test_drop_artifact() -> void:
	Game.reset_run()
	var museum := await _make_museum()
	var mask: Artifact = null
	for child in museum.get_children():
		if child is Artifact and child.item_id == "mask":
			mask = child
	check(mask.try_pickup(), "mask picked before dropping")
	check(Game.mission_complete, "mission complete while carrying the mask")

	var idx := Game.item_at_cell(Vector2i.ZERO)
	Game.erase_item_at(idx)
	check(not Game.mission_complete, "mission completion clears when the target leaves the bag")

	museum.drop_artifact("mask", museum.player.global_position)
	await get_tree().physics_frame
	var dropped: Artifact = null
	for child in museum.get_children():
		if child is Artifact and child.item_id == "mask":
			dropped = child
	check(dropped != null, "dropped target exists in the world again")
	check(
		dropped.global_position.distance_to(museum.player.global_position) < 2.0,
		"artifact dropped at the player position",
	)
	check(dropped.try_pickup(), "dropped artifact can be picked up again")
	check(Game.mission_complete, "mission restored after picking the target back up")

	museum.end_game()
	museum.queue_free()
	await get_tree().process_frame


func _test_minimap() -> void:
	Game.reset_run()
	var museum := await _make_museum()
	var minimap := Minimap.new()
	add_child(minimap)
	minimap.bind(museum)
	await get_tree().process_frame
	check(minimap.museum == museum, "minimap binds to the level")
	check(museum.visited_rooms.has(0), "starting room shows as visited")
	minimap.queue_free()
	museum.end_game()
	museum.queue_free()
	await get_tree().process_frame


func _test_british_museum_level() -> void:
	Game.reset_run()
	var museum := await _make_museum("british_museum")
	check(museum.rooms.size() == 6, "british museum has six rooms")
	check(Game.mission_target_id == "ram_zun", "british museum targets the double-ram zun")
	check(museum.target_item_id() == "ram_zun", "museum resolves the level target")

	var zun: Artifact = null
	for child in museum.get_children():
		if child is Artifact and child.item_id == "ram_zun":
			zun = child
	check(zun != null, "double-ram zun artifact exists in the level")
	check(museum.get_node_or_null("BMDisplayCase") != null, "british museum target room has the BM display case")
	if zun != null:
		var zun_cell := Vector2i(int(zun.global_position.x / 16), int(zun.global_position.y / 16))
		check(museum.is_cell_blocked(zun_cell.x, zun_cell.y), "BM target pedestal blocks movement")
	check(museum.bm_solid_decor_count > 0, "BM solid decor collision exists")
	check(museum.bm_decor_count > 0, "british museum has decoration props")
	check(museum.get_node_or_null("BMDust") != null, "british museum room 3 has dust particles")
	check(museum.get_node_or_null("BMZunReflection") != null, "british museum room 3 has the zun floor reflection")
	check(museum.get_node_or_null("BMGlassGlint") != null, "british museum room 3 has the glass glint")
	if zun != null:
		var zun_sprite: Sprite2D = zun.get_node("Sprite")
		check(zun_sprite.hframes == Artifact.RELIC_FRAMES, "zun displays the 3D turntable strip")
		check(
			zun_sprite.texture.get_width() == Artifact.RELIC_FRAMES * Artifact.RELIC_FRAME_SIZE.x,
			"turntable strip width matches the frame count",
		)
	check(museum.target_room == 3, "double-ram zun stands in the middle gallery")
	check(museum.exit_room == 5, "exit waits in the loading bay")
	check(museum.police.size() == 7, "british museum runs seven guards")

	# 房间独立：门洞可以走，但守卫不会隔房看到玩家。
	var cop0: Police = museum.police[0]
	museum.player.global_position = Vector2(280, 88)
	cop0.global_position = Vector2(264, 88)
	cop0.investigate(museum.player.global_position)
	check(cop0.can_see_player(), "guard sees the player in the same room")
	museum.player.global_position = Vector2(392, 88)
	cop0.investigate(museum.player.global_position)
	check(not cop0.can_see_player(), "guard does not see the player across rooms")

	# 卡住脱困：把守卫放在长椅左侧，路点在长椅右侧，1.5s 内必须离开原位。
	var bench_start := Vector2(264, 328)
	cop0.global_position = bench_start
	cop0.patrol_points = [Vector2(296, 328), Vector2(264, 328)]
	cop0.state = Police.State.PATROL
	cop0.ai_enabled = true
	await get_tree().create_timer(1.5).timeout
	check(cop0.global_position.distance_to(bench_start) > 6.0, "guard unsticks from a solid decoration")

	if zun != null:
		museum.player.global_position = zun.global_position + Vector2(-24, 0)
		check(zun.try_pickup(), "double-ram zun can be picked up")
		check(Game.mission_complete, "carrying the zun completes the mission")

	museum.end_game()
	museum.queue_free()
	await get_tree().process_frame
	Game.set_level("museum")


func _test_bag_screen() -> void:
	Game.reset_run()
	check(Game.try_pickup("mask"), "target auto-placed for the bag screen test")
	var screen := load("res://src/ui/backpack_screen.tscn").instantiate() as BackpackScreen
	add_child(screen)
	await get_tree().process_frame
	screen.open()
	check(screen.is_open(), "backpack screen opens")
	check(screen.grid.custom_minimum_size == Vector2(48, 48), "grid sized for the 2x2 bag")

	check(Game.item_at_cell(Vector2i.ZERO) == 0, "mask sits under the cursor")
	screen.confirm()
	check(not screen.held.is_empty(), "E picks the item into the hand")
	check(Game.bag_items.is_empty(), "item leaves the grid while held")
	screen.rotate_held()
	check(int(screen.held["rot"]) == 1, "R rotates the held item")
	screen.confirm()
	check(screen.held.is_empty(), "rotated mask placed vertically")
	check(Game.bag_used_cells() == 2, "two cells used after placement")

	screen.close()
	check(not screen.is_open(), "backpack screen closes")
	check(Game.item_at_cell(Vector2i(0, 1)) == 0, "mask now occupies the left column")

	screen.queue_free()
	await get_tree().process_frame


func _test_title_screen() -> void:
	var title := load("res://src/ui/title_screen.tscn").instantiate() as TitleScreen
	add_child(title)
	await get_tree().process_frame
	check(title.art.texture != null, "title screen loads key art (author art or placeholder)")
	check(title.continue_button != null, "title screen has a continue button")
	var continued := {"value": false}
	title.continue_requested.connect(func() -> void: continued["value"] = true)
	title.continue_button.pressed.emit()
	check(continued["value"], "continue emits its signal")
	var quit_requested := {"value": false}
	title.quit_requested.connect(func() -> void: quit_requested["value"] = true)
	title.quit_button.pressed.emit()
	check(quit_requested["value"], "quit emits its signal")
	check(title.shop_button != null, "title screen has a scene-placed shop button")
	var shopped := {"value": false}
	title.shop_requested.connect(func() -> void: shopped["value"] = true)
	title.shop_button.pressed.emit()
	check(shopped["value"], "shop button emits shop_requested")
	var primary: Button = title.continue_button if title.continue_button.visible else title.new_game_button
	check(primary.position.y >= 250.0, "primary action is placed in the scene (rooftop ledge)")
	check(title.primary_hint.text != "", "primary action has a scene hint")
	title.queue_free()
	await get_tree().process_frame


func _test_hub_levels() -> void:
	var hub := load("res://src/ui/hub.tscn").instantiate() as Hub
	add_child(hub)
	await get_tree().process_frame
	check(hub.levels_box.get_child_count() == Game.LEVELS.size(), "hub builds one card per level")
	check(hub.levels_box.visible and not hub.shop_box.visible, "level tab is the default")

	var started := {"id": ""}
	hub.start_requested.connect(func(level_id: String) -> void: started["id"] = level_id)
	var card: PanelContainer = hub.levels_box.get_child(1)
	var button: Button = null
	for child in card.get_child(0).get_children():
		if child is Button:
			button = child
	check(button != null, "level card has a start button")
	if button != null:
		button.pressed.emit()
	check(started["id"] == "british_museum", "level card starts its own level")

	hub._show_tab("shop")
	check(hub.shop_box.visible and not hub.levels_box.visible, "shop tab switches content")
	hub.queue_free()
	await get_tree().process_frame


func _test_mission_phone() -> void:
	Game.set_level("british_museum")
	var phone := load("res://src/ui/mission_phone.tscn").instantiate() as MissionPhone
	add_child(phone)
	await get_tree().process_frame
	phone.open()
	check(phone.is_open(), "phone opens")
	check(phone.target_label.text == "商代双羊尊", "phone shows the mission target name")
	check(phone.relic.has_turntable(), "phone shows the 3D turntable of the target")
	check("大英博物馆" in phone.meta_label.text, "phone shows the mission location")
	check(not phone.archive_label.text.is_empty(), "phone shows the archive card")
	check("1936" in phone.archive_label.text, "archive card shows the documented acquisition")
	phone._show_tab("archive")
	await get_tree().process_frame
	check(phone.archive_page.visible and not phone.task_page.visible, "archive tab switches pages")
	check(
		phone.panel.size.x <= 640.0 and phone.panel.size.y <= 360.0,
		"phone panel fits the screen（%s）" % phone.panel.size,
	)
	check(phone.inspect.size.x >= 300.0, "inspect page is laid out（%s）" % phone.inspect.size)
	phone.close()
	check(not phone.is_open(), "phone closes")
	check(Main.toggle_allowed(0.0), "toggle allowed with no cooldown")
	check(not Main.toggle_allowed(0.2), "toggle blocked during cooldown")
	phone.queue_free()
	await get_tree().process_frame
	Game.set_level("museum")


func _test_tutorial_balance() -> void:
	Game.reset_run()
	var museum := await _make_museum("museum")
	var tutorial_scaled := true
	for cop in museum.police:
		if cop.spot_delay_scale <= 1.0:
			tutorial_scaled = false
	check(tutorial_scaled, "tutorial guards react slower (spot_delay_scale > 1)")
	museum.end_game()
	museum.queue_free()
	await get_tree().process_frame

	var bm := await _make_museum("british_museum")
	var normal := true
	for cop in bm.police:
		if cop.spot_delay_scale != 1.0:
			normal = false
	check(normal, "british museum guards keep the normal reaction speed")
	bm.end_game()
	bm.queue_free()
	await get_tree().process_frame
	Game.set_level("museum")


func _test_dialogue_tree() -> void:
	var tree := load("res://src/ui/dialogue_tree.tscn").instantiate() as DialogueTree
	add_child(tree)
	await get_tree().process_frame
	var finished := {"value": false}
	var script_entries: Array = [
		{"speaker": "器灵", "text": "第一句。"},
		{"choices": [{"text": "甲", "goto": "a"}, {"text": "乙", "goto": "b"}]},
		{"label": "a"},
		{"speaker": "器灵", "text": "选了甲。"},
		{"goto": "wrap"},
		{"label": "b"},
		{"speaker": "器灵", "text": "选了乙。"},
		{"label": "wrap"},
		{"card": "mask_1"},
	]
	tree.play(script_entries, Lore.cards("mask"), func() -> void: finished["value"] = true)
	check(tree.is_active(), "dialogue tree becomes active")
	check(tree.speech_panel.visible, "speech panel shows first")

	tree.advance()
	check(tree.choices_box.visible, "choices show up")
	check(tree.choices_box.get_child_count() == 2, "two choices are listed")

	tree._choice_buttons[1].pressed.emit()
	check(not tree.choices_box.visible, "choices hide after selecting")

	tree.advance()
	check(tree.card_panel.visible, "dossier card shows")
	check(tree.card_title.text.contains("商代"), "card carries the historical title")

	tree.advance()
	check(finished["value"], "dialogue tree finishes and calls back")
	check(not tree.is_active(), "dialogue tree is inactive after finishing")
	tree.queue_free()
	await get_tree().process_frame


func _test_inspect_page() -> void:
	Game.reset_progress()
	Game.try_pickup("mask")
	var page := load("res://src/ui/inspect_page.tscn").instantiate() as InspectPage
	add_child(page)
	await get_tree().process_frame
	page.set_item("mask")
	check(page.image.texture != null, "inspect page loads the closeup")
	check(page._marker_buttons.size() == Lore.hotspots("mask").size(), "one marker per hotspot")

	var before := page.fact_label.text
	page._select_hotspot(0)
	check(page.fact_label.text != before, "selecting a hotspot shows its fact")
	check(page.fact_label.text.contains("档案"), "fact is labelled as an archive entry")
	check(page.ghost_label.text.contains("器灵"), "ghost line is labelled as fiction")
	check(Game.hotspot_found("mask", 0), "hotspot discovery is recorded")
	check(page.cards_box.get_child_count() == Lore.cards("mask").size(), "cards are listed")

	# 双羊尊没有剧本，但档案/端详页也要用混元 3D 渲染的特写（而不是 24×24 图标放大）
	page.set_item("ram_zun")
	check(page.image.texture != null, "zun inspect page loads a closeup")
	check(page.image.texture.resource_path.contains("relic_ram_zun_closeup"), "zun inspect uses the 2.5D 3D-render closeup")
	check(page._marker_buttons.is_empty(), "zun has no hotspots yet")
	check(not page.cards_label.visible, "empty card section is hidden for the zun")
	check(not page.progress_label.text.contains("0 / 0"), "no misleading 0/0 hotspot counter")
	page.queue_free()
	await get_tree().process_frame


func _test_ghost_talk() -> void:
	Game.reset_progress()
	var museum := await _make_museum()
	var requested := {"item": "", "stage": -1}
	museum.lore_requested.connect(func(item_id: String, stage: int) -> void:
		requested["item"] = item_id
		requested["stage"] = stage
	)
	museum.ghost_delay = 0.05
	var mask: Artifact = null
	for child in museum.get_children():
		if child is Artifact and child.item_id == "mask":
			mask = child
	mask.try_pickup()
	await get_tree().create_timer(0.2).timeout
	check(museum.ghost != null, "ghost spawns for the mask")
	check(requested["item"] == "mask" and requested["stage"] == 0, "ghost spawn requests lore stage 0")

	Game.advance_lore_stage("mask")
	museum._talk_to_ghost()
	check(requested["stage"] == 1, "talking again plays the next lore stage")

	for i in 5:
		Game.advance_lore_stage("mask")
	museum._talk_to_ghost()
	check(requested["stage"] == 1, "no further stage after the script ends")

	museum.end_game()
	museum.queue_free()
	await get_tree().process_frame


func _test_escape_flow() -> void:
	Game.reset_run()
	var museum := await _make_museum()

	var mask: Artifact = null
	for child in museum.get_children():
		if child is Artifact and child.item_id == "mask":
			mask = child
	mask.try_pickup()

	var exit_area := museum.get_node_or_null("Exit") as Area2D
	check(exit_area != null, "exit zone exists")
	check(not museum._ended, "run still active before escape")

	var escaped := {"value": false}
	var pushed_out := {"value": false}
	museum.escaped.connect(func() -> void: escaped["value"] = true)
	museum.toast.connect(
		func(text: String) -> void:
			if text.begins_with("出口还锁着"):
				pushed_out["value"] = true
	)

	# Try to leave without the mission target first.
	Game.mission_complete = false
	museum.player.global_position = exit_area.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(pushed_out["value"], "exit refuses to open without the target")
	check(not escaped["value"], "no escape without the target")

	# Now grab the target and leave.
	Game.mission_complete = true
	museum.player.global_position = exit_area.global_position + Vector2(40, 0)
	await get_tree().physics_frame
	museum.player.global_position = exit_area.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(escaped["value"], "escape fires once the target is carried out")

	museum.end_game()
	museum.queue_free()
	await get_tree().process_frame
