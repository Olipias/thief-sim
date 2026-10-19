extends SceneTree
## 存档兼容自检：老档 / 残缺档 / 脏档 / 未来档必须能安全加载。
##
## 约定（AGENTS.md 硬性规则 4）：存档只增字段、读取必须有默认值；
## 破坏性变更要写迁移。**新增存档字段后，请在下方的用例里补一条"缺该字段的老档"。**
##
## 运行：godot --headless --script tests/test_save_compat.gd
## 失败以非零退出码结束；临时存档写入 /tmp。

const DIR := "/tmp/thief_sim_save_compat"

var _failures := 0
var _checks := 0


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL - " + msg)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	_test_missing_file()
	_test_minimal_legacy_save()
	_test_corrupt_json()
	_test_wrong_types()
	_test_future_fields()
	_test_dirty_bag_entries()
	_test_dirty_lore_entries()
	_test_current_round_trip()

	if _failures > 0:
		print("FAILED %d / %d checks" % [_failures, _checks])
		quit(1)
	else:
		print("ALL %d CHECKS PASSED" % _checks)
		quit(0)


func _new_game(path: String):
	var gs = load("res://src/autoload/game_state.gd").new()
	gs.save_path = path
	return gs


func _write_save(name: String, text: String) -> String:
	var path := DIR + "/" + name
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	return path


## 干净的初始值：任何加载失败时都应回到这些默认值，而不是残留脏数据。
func _defaults_ok(gs, where: String) -> void:
	check(gs.bag_items.is_empty(), "%s：背包为空" % where)
	check(not gs.mission_complete, "%s：任务未完成" % where)
	check(gs.smoke_count >= 0 and gs.money >= 0, "%s：数值非负" % where)


func _test_missing_file() -> void:
	var gs = _new_game(DIR + "/does_not_exist.json")
	gs.load_game()
	check(gs.money == 0 and gs.backpack_level == 0, "无存档：走默认值")
	_defaults_ok(gs, "无存档")
	gs.free()


func _test_minimal_legacy_save() -> void:
	# 远古版本的存档：只有 money 一个字段，其余字段必须走默认值
	var path := _write_save("legacy_min.json", '{"money": 123}')
	var gs = _new_game(path)
	gs.load_game()
	check(gs.money == 123, "老档：money 正确加载")
	check(gs.backpack_level == 0, "老档：缺失字段走默认值（backpack_level）")
	check(not gs.has_sneakers, "老档：缺失字段走默认值（has_sneakers）")
	check(gs.lore_stage_of("mask") == 0, "老档：文物志进度默认 0")
	_defaults_ok(gs, "老档")
	gs.free()


func _test_corrupt_json() -> void:
	var path := _write_save("corrupt.json", '{"money": 100, oops')
	var gs = _new_game(path)
	gs.load_game()
	check(gs.money == 0, "损坏档：不加载、不崩溃、走默认值")
	_defaults_ok(gs, "损坏档")
	gs.free()

	var path2 := _write_save("array.json", "[1, 2, 3]")
	var gs2 = _new_game(path2)
	gs2.load_game()
	check(gs2.money == 0, "非字典档：安全忽略")
	gs2.free()


func _test_wrong_types() -> void:
	var path := _write_save(
		"wrong_types.json",
		'{"money": "abc", "backpack_level": "2", "has_sneakers": "x", "smoke_count": -5, "bag_items": "nope"}'
	)
	var gs = _new_game(path)
	gs.load_game()
	check(typeof(gs.money) == TYPE_INT, "类型脏档：money 类型仍是 int")
	check(typeof(gs.backpack_level) == TYPE_INT, "类型脏档：backpack_level 类型仍是 int")
	check(gs.backpack_level >= 0, "类型脏档：backpack_level 不越界（%d）" % gs.backpack_level)
	check(typeof(gs.has_sneakers) == TYPE_BOOL, "类型脏档：has_sneakers 类型仍是 bool")
	check(gs.bag_items.is_empty(), "类型脏档：坏 bag_items 被安全忽略")
	_defaults_ok(gs, "类型脏档")
	gs.free()


func _test_future_fields() -> void:
	# 来自"未来版本"的存档：多出来的字段必须被忽略，不能崩
	var path := _write_save(
		"future.json",
		'{"money": 7, "future_thing": {"x": 1}, "bag_items_2": [1, 2, 3]}'
	)
	var gs = _new_game(path)
	gs.load_game()
	check(gs.money == 7, "未来档：已知字段正常加载")
	_defaults_ok(gs, "未来档")
	gs.free()


func _test_dirty_bag_entries() -> void:
	var path := _write_save(
		"dirty_bag.json",
		'{"bag_items": [
			{"id": "no_such_item", "x": 0, "y": 0, "rot": 0},
			{"id": 42, "x": 0, "y": 0, "rot": 0},
			{"id": "mask", "x": -9, "y": 999, "rot": 77},
			{"id": "scroll", "x": {}, "y": [], "rot": {}},
			{"id": "jade", "x": 0, "y": 0, "rot": 0},
			"not even a dict",
			7
		]}'
	)
	var gs = _new_game(path)
	gs.load_game()
	var all_valid := true
	for i in gs.bag_items.size():
		var entry: Dictionary = gs.bag_items[i]
		var id := str(entry["id"])
		if not gs.CATALOG.has(id):
			all_valid = false
		var rot := int(entry["rot"])
		if rot < 0 or rot > 3:
			all_valid = false
		if not gs.bag_can_place(id, rot, int(entry["x"]), int(entry["y"]), i):
			all_valid = false
	check(all_valid, "脏背包：保留的每件物品都有合法 id / rot / 摆放位置")
	check(gs.bag_items.size() <= 3, "脏背包：非法条目被丢弃（剩余 %d 件）" % gs.bag_items.size())
	var has_mask := false
	for i in gs.bag_items.size():
		if str(gs.bag_items[i]["id"]) == "mask":
			has_mask = true
	check(has_mask, "脏背包：目标物被修复后保留（任务仍可完成）")
	check(gs.mission_complete or not has_mask, "脏背包：任务完成状态与背包内容一致")
	gs.free()


func _test_dirty_lore_entries() -> void:
	# lore_found 值本应是数组；脏数据（int / 字符串 / 嵌套杂项）不能崩
	var path := _write_save(
		"dirty_lore.json",
		'{"lore_stage": {"mask": "x", "future": 3.7}, "lore_found": {"mask": 5, "other": ["a", 2, {}]}}'
	)
	var gs = _new_game(path)
	gs.load_game()
	check(typeof(gs.lore_stage_of("mask")) == TYPE_INT, "脏文物志：stage 值类型仍是 int")
	check(gs.hotspot_found("mask", 0) == false, "脏文物志：坏 lore_found 不崩且视为未发现")
	_defaults_ok(gs, "脏文物志")
	gs.free()


func _test_current_round_trip() -> void:
	# 当前完整档：写完再读，全部字段一致（新增字段时别忘了同步本用例的断言）
	var path := DIR + "/current.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var writer = _new_game(path)
	writer._persistent = true
	writer.money = 321
	writer.backpack_level = 3
	writer.has_sneakers = true
	writer.smoke_count = 2
	var saved_items: Array[Dictionary] = [
		{"id": "mask", "x": 0, "y": 0, "rot": 0},
		{"id": "jade", "x": 2, "y": 0, "rot": 0},
	]
	writer.bag_items = saved_items
	writer.lore_stage = {"mask": 2}
	writer.lore_found = {"mask": [0, 2]}
	writer.save_game()
	writer.free()

	var reader = _new_game(path)
	reader.load_game()
	check(reader.money == 321, "完整档：money")
	check(reader.backpack_level == 3, "完整档：backpack_level")
	check(reader.has_sneakers, "完整档：has_sneakers")
	check(reader.smoke_count == 2, "完整档：smoke_count")
	check(reader.bag_items.size() == 2, "完整档：bag_items 数量")
	check(reader.mission_complete, "完整档：mission_complete 推导正确")
	check(reader.lore_stage_of("mask") == 2, "完整档：lore_stage")
	check(reader.hotspot_found("mask", 2), "完整档：lore_found")
	reader.free()
	DirAccess.remove_absolute(path)
