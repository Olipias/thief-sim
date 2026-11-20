extends SceneTree
## Pure-logic tests, run with:
##   godot --headless --script tests/test_logic.gd
## Exits non-zero on failure.

var _failures := 0
var _checks := 0


func _initialize() -> void:
	_test_game_state()
	_test_bag_geometry()
	_test_shop()
	_test_levels()
	_test_new_game()
	_test_lore_progress()
	_test_vision_cone()
	_test_police_world_freeze()
	_test_map()
	_test_evidence_chains()
	if _failures > 0:
		print("FAILED %d / %d checks" % [_failures, _checks])
		quit(1)
	else:
		print("ALL %d CHECKS PASSED" % _checks)
		quit(0)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL - " + msg)


func _test_game_state() -> void:
	var gs = load("res://src/autoload/game_state.gd").new()

	gs.reset_run()
	check(gs.bag_items.is_empty() and not gs.mission_complete, "reset clears run state")
	check(gs.bag_cells() == Vector2i(2, 2), "base bag is 2x2")
	check(gs.bag_capacity_cells() == 4, "base bag has 4 cells")

	check(gs.try_pickup("vase"), "pick up one-cell artifact")
	check(gs.bag_used_cells() == 1, "one cell used")
	check(gs.is_archived("vase"), "picking up an item archives it")
	check(gs.archived_count() == 0, "ordinary loot does not count as a real-artifact archive entry")
	check(not gs.finish_run(true)["success"], "cannot succeed without the mission target")
	check(gs.money == 0, "failed run leaves money untouched")
	check(gs.try_pickup("gem"), "pick up a second one-cell artifact")
	check(gs.try_pickup("mask"), "two-cell mission target still fits")
	check(gs.mission_complete, "target marks mission complete")
	check(gs.is_archived("mask"), "mission target is archived on pickup")
	check(gs.archived_count() == 1, "real-artifact archive counts the target")
	check(gs.bag_used_cells() == 4, "bag is full with 4 cells used")
	check(not gs.try_pickup("ingot"), "cannot pick up with no free cells")
	check(not gs.try_pickup("jade"), "three-cell item does not fit in a 2x2 bag")
	check(gs.loot_value() == 120 + 300, "loot value sums sellable items")

	var summary: Dictionary = gs.finish_run(true)
	check(summary["success"], "escape with target succeeds")
	check(summary["target_name"] == "青铜人面具", "summary names the target")
	check(summary["stash_items"].size() == 2, "extras are moved to the stash")
	check(summary["stash_value"] == 120 + 300, "stash value is reported")
	check(summary["reward"] == gs.MISSION_REWARD, "mission reward granted")
	check(gs.money == gs.MISSION_REWARD, "loot is NOT auto-sold (reward only)")
	check(gs.loot_stash.size() == 2, "loot waits in the stash")
	check(gs.bag_items.is_empty(), "backpack is cleared after the run")
	check(gs.story_flag("completed_museum"), "成功结算记录 completed_museum")
	check(not gs.story_flag("completed_british_museum"), "城西结算不误记大英完成")

	# 手动销赃
	var before: int = gs.money
	var sold: int = gs.sell_stash_item(0)
	check(sold == 120, "selling the first stash item pays its value")
	check(gs.money == before + 120, "money grows after selling")
	check(gs.loot_stash.size() == 1, "sold item leaves the stash")
	var rest: int = gs.sell_all_stash()
	check(rest == 300, "sell-all pays the remaining value")
	check(gs.loot_stash.is_empty() and gs.money == before + 420, "stash is empty after sell-all")

	gs.reset_progress()
	check(not gs.is_archived("mask") and gs.archive_seen.is_empty(), "reset clears the archive collection")
	gs.reset_run()
	check(not gs.finish_run(false)["success"], "busted run reports failure")
	check(gs.loot_stash.is_empty(), "busted run adds nothing to the stash")
	check(not gs.story_flag("completed_museum"), "被逮不记录关卡完成")
	gs.free()


func _test_bag_geometry() -> void:
	var gs = load("res://src/autoload/game_state.gd").new()
	gs.reset_progress()

	check(gs.item_cell_count("mask") == 2, "mask takes two cells")
	check(gs.item_cell_count("jade") == 3, "jade takes three cells")
	check(gs.item_cell_count("vase") == 1, "vase takes one cell")
	check(
		gs.item_shape("scroll", 0) == [Vector2i(0, 0), Vector2i(0, 1)],
		"scroll is vertical by default",
	)
	check(
		gs.item_shape("scroll", 1) == [Vector2i(0, 0), Vector2i(1, 0)],
		"scroll rotates to horizontal",
	)
	check(
		gs.item_shape("jade", 1) == [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		"jade rotates to 1x3",
	)
	check(
		gs.item_shape("mask", 1) == [Vector2i(0, 0), Vector2i(0, 1)],
		"mask rotates to vertical",
	)

	check(not gs.bag_can_place("scroll", 0, 0, 1), "vertical scroll cannot stick out of the bag")
	check(gs.bag_can_place("scroll", 0, 0, 0), "vertical scroll fits on the left column")
	check(gs.try_pickup("scroll"), "scroll auto-placed")
	check(not gs.bag_can_place("vase", 0, 0, 0), "occupied cell is blocked")
	check(gs.bag_can_place("vase", 0, 1, 0), "free cell accepts an item")
	check(gs.item_at_cell(Vector2i(0, 1)) == 0, "item lookup by cell")
	check(gs.bag_first_fit("vase").x == 1, "first fit skips the occupied cell")

	gs.backpack_level = 2  # 3x3 bag
	check(gs.bag_cells() == Vector2i(3, 3), "bag level changes the grid")
	check(gs.bag_can_place("jade", 1, 0, 2), "horizontal jade fits on a free row")
	check(not gs.bag_can_place("jade", 1, 0, 0), "horizontal jade blocked by placed scroll")

	gs.erase_item_at(0)
	check(gs.bag_items.is_empty(), "erased item leaves the bag")

	check(gs.try_pickup("mask"), "target placed for mission recompute")
	check(gs.mission_complete, "target in the bag marks the mission complete")
	var target_index: int = gs.item_at_cell(Vector2i(0, 0))
	gs.erase_item_at(target_index)
	check(not gs.mission_complete, "removing the target clears mission completion")
	check(gs.place_item({"id": "mask"}, 0, 0, 0), "target can be placed back")
	check(gs.mission_complete, "placing the target back restores completion")
	gs.free()


func _test_shop() -> void:
	var gs = load("res://src/autoload/game_state.gd").new()
	gs.reset_progress()

	check(gs.bag_cells() == Vector2i(2, 2), "base bag is 2x2")
	check(gs.upgrade_price("backpack") == 250, "first backpack upgrade costs 250")
	check(not gs.can_buy("backpack"), "cannot buy without money")

	gs.money = 1000
	check(gs.buy("backpack"), "buy backpack upgrade")
	check(gs.bag_cells() == Vector2i(3, 2), "bag grows to 3x2")
	check(gs.money == 750, "money deducted")
	check(gs.upgrade_price("backpack") == 500, "price scales with level")

	check(gs.buy("sneakers"), "buy sneakers")
	check(gs.has_sneakers, "sneakers owned")
	check(gs.is_sold_out("sneakers"), "sneakers cannot be bought twice")
	check(not gs.buy("sneakers"), "second sneakers purchase refused")

	check(gs.buy("smoke"), "buy smoke bomb")
	check(gs.smoke_count == 1, "smoke in inventory")
	check(gs.use_smoke(), "use smoke bomb")
	check(gs.smoke_count == 0, "smoke consumed")
	check(not gs.use_smoke(), "cannot use what you don't have")

	gs.money = 100000
	while gs.buy("backpack"):
		pass
	check(gs.bag_cells() == Vector2i(5, 4), "bag maxes at 5x4")
	check(gs.bag_capacity_cells() == 20, "maxed bag has twenty cells")
	check(gs.is_sold_out("backpack"), "backpack sold out at max")
	gs.free()

	var save_path := "/tmp/thief_sim_test_save.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	var writer = load("res://src/autoload/game_state.gd").new()
	writer.save_path = save_path
	writer._persistent = true
	writer.money = 321
	writer.backpack_level = 2
	writer.has_sneakers = true
	writer.smoke_count = 3
	var saved_items: Array[Dictionary] = [
		{"id": "mask", "x": 0, "y": 0, "rot": 0},
		{"id": "jade", "x": 2, "y": 0, "rot": 0},
	]
	writer.bag_items = saved_items
	writer.mission_complete = true
	writer.save_game()
	writer.free()
	var reader = load("res://src/autoload/game_state.gd").new()
	reader.save_path = save_path
	reader.load_game()
	check(reader.money == 321, "save restores money")
	check(reader.backpack_level == 2 and reader.bag_cells() == Vector2i(3, 3), "save restores bag size")
	check(reader.has_sneakers, "save restores sneakers")
	check(reader.smoke_count == 3, "save restores smoke bombs")
	check(reader.bag_items.size() == 2, "save restores bag items")
	check(reader.item_at_cell(Vector2i(2, 1)) == 1, "saved item keeps its cells")
	check(reader.mission_complete, "target in the saved bag marks the mission")
	reader.free()
	DirAccess.remove_absolute(save_path)


func _test_levels() -> void:
	var gs = load("res://src/autoload/game_state.gd").new()
	gs.reset_progress()
	gs.backpack_level = 2  # 3x3，够装下两件目标

	check(gs.current_level_id == "museum", "default level is the museum")
	check(gs.mission_target_id == "mask", "default mission target is the mask")

	gs.set_level("british_museum")
	check(gs.current_level_id == "british_museum", "level switch updates the current level")
	check(gs.mission_target_id == "ram_zun", "level switch updates the mission target")
	check(gs.level_name() == "大英博物馆", "level name resolves from the registry")
	check(gs.bm_hall_name("ram_zun") == "中国馆", "bm_hall_name maps ram_zun to 中国馆")
	check(gs.bm_hall_name("egypt_heart_scarab") == "埃及馆", "bm_hall_name maps egypt_heart_scarab to 埃及馆")
	check(gs.bm_hall_name("akrotiri_askos") == "希腊馆", "bm_hall_name maps akrotiri_askos to 希腊馆")
	check(gs.mission_reward() == 400, "level reward resolves from the registry")

	check(not gs.try_pickup("mask"), "大英行动拒绝非选定文物")
	check(not gs.mission_complete, "carrying another artifact does not complete the mission")
	check(gs.try_pickup("ram_zun"), "british museum target picked up")
	check(gs.mission_complete, "carrying the level target completes the mission")

	var summary: Dictionary = gs.finish_run(true)
	check(summary["success"], "british museum run succeeds")
	check(summary["target_name"] == "商代双羊尊", "summary names the double-ram zun")
	check(summary["reward"] == 400, "british museum pays its own reward")
	check(summary["stash_items"].is_empty(), "大英行动不再产生额外杂物销赃")
	check(gs.story_flag("completed_british_museum"), "大英成功结算记录 completed_british_museum")

	gs.set_level("museum")
	check(gs.mission_target_id == "mask", "switching back restores the first level")
	check(not gs.mission_complete, "settlement cleared the bag, so the mission is not complete")
	gs.free()


func _test_new_game() -> void:
	var save_path := "/tmp/thief_sim_newgame_save.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	var gs = load("res://src/autoload/game_state.gd").new()
	gs.save_path = save_path
	gs._persistent = true
	check(not gs.has_save(), "no save before playing")

	gs.money = 500
	gs.backpack_level = 2
	gs.smoke_count = 3
	gs.has_sneakers = true
	var items: Array[Dictionary] = [{"id": "mask", "x": 0, "y": 0, "rot": 0}]
	gs.bag_items = items
	gs.save_game()
	check(gs.has_save(), "save file exists after saving")

	gs.start_new_game()
	check(gs.money == 0, "new game clears money")
	check(gs.backpack_level == 0 and gs.bag_cells() == Vector2i(2, 2), "new game resets the bag")
	check(gs.smoke_count == 0 and not gs.has_sneakers, "new game clears items and upgrades")
	check(gs.bag_items.is_empty(), "new game empties the backpack")
	gs.free()

	var reader = load("res://src/autoload/game_state.gd").new()
	reader.save_path = save_path
	reader.load_game()
	check(reader.money == 0 and reader.backpack_level == 0, "new game overwrote the old save")
	reader.free()
	DirAccess.remove_absolute(save_path)


func _test_lore_progress() -> void:
	var lore_script = load("res://src/data/lore.gd")
	var gs = load("res://src/autoload/game_state.gd").new()
	gs.reset_progress()
	var save_path := "/tmp/thief_sim_lore_save.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	gs.save_path = save_path
	gs._persistent = true

	check(lore_script.has_lore("mask"), "mask has a lore entry")
	check(lore_script.cards("mask").size() >= 2, "mask has several dossier cards")
	check(lore_script.hotspots("mask").size() >= 2, "mask has several inspect hotspots")
	check(gs.lore_stage_of("mask") == 0, "lore stage starts at 0")
	check(not gs.hotspot_found("mask", 0), "hotspot starts undiscovered")

	gs.advance_lore_stage("mask")
	check(gs.lore_stage_of("mask") == 0, "lore stage stays at 0 when no stages remain")

	gs.mark_hotspot("mask", 1)
	gs.mark_hotspot("mask", 1)
	check(gs.hotspot_found("mask", 1), "hotspot marked")
	check(not gs.hotspot_found("mask", 0), "other hotspots stay undiscovered")

	var reader = load("res://src/autoload/game_state.gd").new()
	reader.save_path = save_path
	reader.load_game()
	check(reader.hotspot_found("mask", 1), "hotspots survive the save")
	gs.free()
	reader.free()
	DirAccess.remove_absolute(save_path)


func _test_vision_cone() -> void:
	var police_script = load("res://src/actors/police.gd")
	var right := Vector2.RIGHT
	check(police_script.in_cone(Vector2.ZERO, right, Vector2(50, 0), 100.0, deg_to_rad(45)), "sees straight ahead")
	check(police_script.in_cone(Vector2.ZERO, right, Vector2(50, 40), 100.0, deg_to_rad(45)), "sees inside the cone")
	check(not police_script.in_cone(Vector2.ZERO, right, Vector2(50, 80), 100.0, deg_to_rad(45)), "misses outside the cone")
	check(not police_script.in_cone(Vector2.ZERO, right, Vector2(-50, 0), 100.0, deg_to_rad(45)), "misses behind")
	check(not police_script.in_cone(Vector2.ZERO, right, Vector2(150, 0), 100.0, deg_to_rad(45)), "misses beyond range")
	check(not police_script.in_cone(Vector2.ZERO, Vector2.ZERO, Vector2(10, 0), 100.0, deg_to_rad(45)), "zero facing sees nothing")


func _test_map() -> void:
	var res := load("res://src/levels/museum_map.json") as JSON
	check(res != null, "map JSON imports")
	if res == null:
		return
	var data: Dictionary = res.data
	var tiles: Array = data["tiles"]
	var patrols: Dictionary = data["patrols"]
	var rooms: Array = data["rooms"]
	var floor_rects: Array = data["floors"]

	var width := 42
	check(tiles.size() == 54, "map has 54 rows")
	for y in tiles.size():
		check(String(tiles[y]).length() == width, "row %d width" % y)

	check(rooms.size() == 7, "seven rooms in a linear chain")
	for i in rooms.size():
		var r: Array = rooms[i]
		check(int(r[2]) == 20 and int(r[3]) == 12, "room %d is one screen (20x12)" % i)
	check(floor_rects.size() >= 13, "floor rects cover rooms and corridors")

	var walkable := ".~TapXP123456789"
	var solid := "#o.dprsvLW "
	var artifacts := 0
	var targets := 0
	var player_pos := Vector2i(-1, -1)
	var exit_pos := Vector2i(-1, -1)
	var target_pos := Vector2i(-1, -1)
	var cells := {}
	for y in tiles.size():
		var row := String(tiles[y])
		for x in row.length():
			var ch := row[x]
			check(walkable.contains(ch) or solid.contains(ch), "known tile '%s' at %d,%d" % [ch, x, y])
			cells[Vector2i(x, y)] = ch
			if ch == "a":
				artifacts += 1
			elif ch == "T":
				targets += 1
				target_pos = Vector2i(x, y)
			elif ch == "P":
				player_pos = Vector2i(x, y)
			elif ch == "X":
				exit_pos = Vector2i(x, y)

	check(targets == 1, "exactly one mission target")
	check(artifacts >= 4, "at least four extra artifacts")
	check(player_pos.x >= 0, "player spawn exists")
	check(exit_pos.x >= 0, "exit exists")

	var seen := _flood_fill(cells, player_pos, walkable)
	for y in tiles.size():
		var row := String(tiles[y])
		for x in row.length():
			var ch := row[x]
			if "TXa123456".contains(ch):
				check(seen.has(Vector2i(x, y)), "tile '%s' at %d,%d reachable" % [ch, x, y])
	for key in patrols.keys():
		var path: Array = patrols[key]
		check(path.size() >= 2, "patrol %s has a route" % key)
		for point in path:
			var p := Vector2i(int(point[0]), int(point[1]))
			check(seen.has(p), "patrol %s waypoint %s reachable" % [key, p])

	var room_of := func(cell: Vector2i) -> int:
		for i in rooms.size():
			var r: Array = rooms[i]
			var rect := Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
			if rect.has_point(cell):
				return i
		return -1
	check(room_of.call(player_pos) == 0, "player starts in the first room")
	check(room_of.call(target_pos) == 3, "mission target sits in the middle room")
	check(room_of.call(exit_pos) == 6, "exit waits in the last room")
	for key in patrols.keys():
		var home: int = room_of.call(Vector2i(int(patrols[key][0][0]), int(patrols[key][0][1])))
		var stays := true
		for point in patrols[key]:
			if room_of.call(Vector2i(int(point[0]), int(point[1]))) != home:
				stays = false
		check(stays, "patrol %s sticks to its own room" % key)


func _flood_fill(cells: Dictionary, start: Vector2i, walkable: String) -> Dictionary:
	var seen := {start: true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + offset
			if seen.has(nxt) or not cells.has(nxt):
				continue
			if not walkable.contains(String(cells[nxt])):
				continue
			seen[nxt] = true
			stack.append(nxt)
	return seen


func _test_evidence_chains() -> void:
	var gs = load("res://src/autoload/game_state.gd").new()
	gs.reset_progress()
	gs.unlock_all_chains_required = false

	check(not gs.make_link("zun_archive", "zun_tech"), "未收集不能连线")
	check(not gs.verify_chain("unknown"), "未知证据链不能解锁")
	check(not gs.has_clue("zun_archive"), "初始未收集线索")
	check(gs.collect_clue("zun_archive"), "收集线索 zun_archive")
	check(gs.collect_clue("zun_tech"), "收集线索 zun_tech")
	check(gs.collect_clue("zun_chat"), "收集线索 zun_chat")
	check(gs.has_clue("zun_archive"), "has_clue 返回已收集")
	check(not gs.collect_clue("unknown_clue"), "非法线索不写入")

	check(not gs.make_link("zun_archive", "zun_chat"), "同链错误关联被拒绝")
	check(gs.make_link("zun_tech", "zun_archive"), "反向拖线标准化关系")
	check(gs.make_link("zun_archive", "zun_tech"), "建立连线 zun_archive→zun_tech")
	check(gs.make_link("zun_tech", "zun_chat"), "建立连线 zun_tech→zun_chat")
	check(not gs.make_link("zun_archive", "unknown"), "非法端点不建立连线")
	check(gs.has_link("zun_archive", "zun_tech"), "has_link 返回已连")

	check(gs.verify_chain("ram_zun"), "验证中国链成功")
	check(gs.chain_unlocked("ram_zun"), "chain_unlocked 为 true")
	var targets: Array[String] = gs.unlocked_targets()
	check(targets.has("ram_zun"), "单链解锁 ram_zun 目标")

	check(gs.set_bm_target("egypt_heart_scarab"), "切换 BM 目标为 egypt_heart_scarab")
	check(gs.mission_target_id == "egypt_heart_scarab", "set_bm_target 更新 mission_target_id")
	check(not gs.try_pickup("ram_zun"), "大英行动不能拿未选择的目标")
	check(gs.try_pickup("egypt_heart_scarab"), "大英行动能拿选定目标")
	check(not gs.try_pickup("egypt_heart_scarab"), "大英行动不能重复拿第二件")
	gs.reset_run()


	# 检查点：保存后重置，再加载应恢复线索与解锁状态，同时清空结局选择。
	gs.story_flags["ending_id"] = "return"
	gs.save_checkpoint("test_logic_cp")
	gs.reset_progress()
	check(not gs.has_clue("zun_archive"), "重置后线索清空")
	check(gs.load_checkpoint("test_logic_cp"), "加载检查点成功")
	check(gs.has_clue("zun_archive"), "检查点恢复线索")
	check(gs.chain_unlocked("ram_zun"), "检查点恢复链解锁")
	check(not gs.story_flags.has("ending_id"), "检查点回溯清除 ending_id")
	check(gs.bag_items.is_empty(), "检查点回溯清空当次携带物")

	# 全链模式：未全部完成时返回空。
	gs.unlock_all_chains_required = true
	check(gs.unlocked_targets().is_empty(), "全链模式下只完成一条时无目标")
	gs.collect_clue("scarab_archive")
	gs.collect_clue("scarab_browser")
	gs.collect_clue("scarab_mail")
	gs.make_link("scarab_archive", "scarab_browser")
	gs.make_link("scarab_browser", "scarab_mail")
	gs.verify_chain("egypt_heart_scarab")
	gs.collect_clue("askos_archive")
	gs.collect_clue("askos_browser")
	gs.collect_clue("askos_chat")
	gs.make_link("askos_archive", "askos_browser")
	gs.make_link("askos_browser", "askos_chat")
	gs.verify_chain("akrotiri_askos")
	var all: Array[String] = gs.unlocked_targets()
	check(all.size() == 3, "全链模式完成三条后解锁全部目标")

	# 清理测试检查点文件。
	var path: String = gs.checkpoint_path("test_logic_cp")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	gs.free()


func _test_police_world_freeze() -> void:
	var police_script = load("res://src/actors/police.gd")
	var cop = police_script.new()
	cop.ai_enabled = false
	cop.state = police_script.State.CHASE
	cop._spot_timer = 0.25
	cop._lose_timer = 1.2
	cop._patrol_index = 2
	cop.set_frozen(true)
	cop.set_frozen(true)
	check(cop.world_frozen, "守卫世界冻结可重复进入")
	cop.set_frozen(false)
	check(not cop.world_frozen and not cop.ai_enabled, "解冻不覆盖其他原因关闭的AI")
	check(cop.state == police_script.State.CHASE and cop._patrol_index == 2, "解冻不重置追击状态或巡逻进度")
	check(is_equal_approx(cop._spot_timer, 0.25) and is_equal_approx(cop._lose_timer, 1.2), "解冻不重置警觉和丢失目标计时")
	cop.free()
