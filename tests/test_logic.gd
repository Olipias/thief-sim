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
	_test_vision_cone()
	_test_map()
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
	check(not gs.finish_run(true)["success"], "cannot succeed without the mission target")
	check(gs.money == 0, "failed run leaves money untouched")
	check(gs.try_pickup("gem"), "pick up a second one-cell artifact")
	check(gs.try_pickup("mask"), "two-cell mission target still fits")
	check(gs.mission_complete, "target marks mission complete")
	check(gs.bag_used_cells() == 4, "bag is full with 4 cells used")
	check(not gs.try_pickup("ingot"), "cannot pick up with no free cells")
	check(not gs.try_pickup("jade"), "three-cell item does not fit in a 2x2 bag")
	check(gs.loot_value() == 120 + 300, "loot value sums sellable items")

	var summary: Dictionary = gs.finish_run(true)
	check(summary["success"], "escape with target succeeds")
	check(summary["target_name"] == "青铜面具", "summary names the target")
	check(summary["sold_value"] == 120 + 300, "extras fetched the expected price")
	check(summary["reward"] == gs.MISSION_REWARD, "mission reward granted")
	check(gs.money == 420 + gs.MISSION_REWARD, "money updated")

	gs.reset_run()
	check(not gs.finish_run(false)["success"], "busted run reports failure")
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
