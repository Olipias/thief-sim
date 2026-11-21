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
	_test_dirty_stash()
	_test_dirty_archive()
	_test_dirty_story_flags()
	_test_dirty_pending_mission()
	_test_dirty_loot_reserved()
	_test_dirty_smoke_stock()
	_test_relic_selection_migration()
	_test_investigation_flags()
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
	check(gs.loot_stash.is_empty(), "%s：仓库为空" % where)
	check(gs.archive_seen.is_empty(), "%s：收集册为空" % where)
	check(gs.story_flags.is_empty(), "%s：剧情旗标为空" % where)


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


## 仓库字段：老档缺失 → 空仓库；脏条目（非字符串 / 未知 id）→ 丢弃。
func _test_dirty_stash() -> void:
	var legacy := _write_save("legacy_no_stash.json", '{"money": 10}')
	var gs = _new_game(legacy)
	gs.load_game()
	check(gs.loot_stash.is_empty(), "老档缺 loot_stash：默认空仓库")
	check(gs.money == 10, "老档缺 loot_stash：其余字段正常")
	gs.free()

	var dirty := _write_save("dirty_stash.json", '{"money": 5, "loot_stash": ["vase", 123, "not_real", "gem"]}')
	var gs2 = _new_game(dirty)
	gs2.load_game()
	check(gs2.loot_stash.size() == 2, "脏仓库：只保留合法条目")
	check(gs2.loot_stash.has("vase") and gs2.loot_stash.has("gem"), "脏仓库：合法 id 保留")
	check(gs2.stash_value() == 120 + 300, "脏仓库：估值按 CATALOG 计算")
	gs2.free()


## R-04 待出发字段：老档缺失 → ""；脏类型 / 非法关卡 id → ""；合法值保留。
func _test_dirty_pending_mission() -> void:
	var legacy := _write_save("legacy_no_pending.json", '{"money": 10}')
	var gs = _new_game(legacy)
	gs.load_game()
	check(gs.pending_mission_level == "", "老档缺 pending_mission_level：默认未准备")
	check(gs.money == 10, "老档缺 pending_mission_level：其余字段正常")
	gs.free()

	var dirty := _write_save("dirty_pending.json", '{"money": 5, "pending_mission_level": 42}')
	var gs2 = _new_game(dirty)
	gs2.load_game()
	check(gs2.pending_mission_level == "", "脏 pending（非字符串）：视为未准备")
	gs2.free()

	var bad_level := _write_save("bad_pending.json", '{"money": 5, "pending_mission_level": "not_a_level"}')
	var gs3 = _new_game(bad_level)
	gs3.load_game()
	check(gs3.pending_mission_level == "", "非法关卡 id：视为未准备")
	gs3.free()

	var good := _write_save("good_pending.json", '{"money": 5, "pending_mission_level": "british_museum"}')
	var gs4 = _new_game(good)
	gs4.load_game()
	check(gs4.pending_mission_level == "british_museum", "合法待出发关卡保留")
	gs4.free()


## R-05 预约字段：老档缺失 → 空；脏类型/非法 id/主目标 → 过滤。
func _test_dirty_loot_reserved() -> void:
	var legacy := _write_save("legacy_no_reserved.json", '{"money": 10, "loot_stash": ["vase"]}')
	var gs = _new_game(legacy)
	gs.load_game()
	check(gs.loot_reserved.is_empty(), "老档缺 loot_reserved：默认空")
	check(gs.loot_stash.size() == 1, "老档缺 loot_reserved：箱内物品保留")
	gs.free()

	var dirty := _write_save("dirty_reserved.json", '{"loot_reserved": "not_a_dict"}')
	var gs2 = _new_game(dirty)
	gs2.load_game()
	check(gs2.loot_reserved.is_empty(), "脏 loot_reserved（非字典）：按空")
	gs2.free()

	var mixed := _write_save("mixed_reserved.json", '{"loot_reserved": {"vase": 2, "gem": -1, "ram_zun": 1, "mask": 1, "not_item": 3}}')
	var gs3 = _new_game(mixed)
	gs3.load_game()
	check(int(gs3.loot_reserved.get("vase", 0)) == 2, "合法预约计数保留")
	check(not gs3.loot_reserved.has("gem"), "负数预约计数丢弃")
	check(not gs3.loot_reserved.has("ram_zun"), "主目标不可恢复普通预约")
	check(not gs3.loot_reserved.has("mask"), "教学主目标不可恢复普通预约")
	check(not gs3.loot_reserved.has("not_item"), "非法 item id 预约丢弃")
	gs3.free()


## R-12a 备货库存：老档缺失 → 0；脏类型/负数 → 0；合法值保留。
func _test_dirty_smoke_stock() -> void:
	var legacy := _write_save("legacy_no_stock.json", '{"money": 10, "smoke_count": 2}')
	var gs = _new_game(legacy)
	gs.load_game()
	check(gs.smoke_stock == 0, "老档缺 smoke_stock：默认无备货")
	check(gs.smoke_count == 2, "老档缺 smoke_stock：携带数保留")
	gs.free()

	var dirty := _write_save("dirty_stock.json", '{"smoke_stock": "three"}')
	var gs2 = _new_game(dirty)
	gs2.load_game()
	check(gs2.smoke_stock == 0, "脏 smoke_stock（非数值）：按 0")
	gs2.free()

	var negative := _write_save("negative_stock.json", '{"smoke_stock": -2}')
	var gs3 = _new_game(negative)
	gs3.load_game()
	check(gs3.smoke_stock == 0, "负数备货按 0")
	gs3.free()

	var good := _write_save("good_stock.json", '{"smoke_stock": 3}')
	var gs4 = _new_game(good)
	gs4.load_game()
	check(gs4.smoke_stock == 3, "合法备货保留")
	gs4.free()

	# G20261121-06：非数值脏类型（字典/数组/布尔）不得让读取崩溃或产生怪值。
	var dict_stock := _write_save("dict_stock.json", '{"smoke_stock": {"a": 1}}')
	var gs5 = _new_game(dict_stock)
	gs5.load_game()
	check(gs5.smoke_stock == 0, "脏 smoke_stock（字典）：按 0 不崩")
	gs5.free()
	var arr_stock := _write_save("arr_stock.json", '{"smoke_stock": [1, 2]}')
	var gs6 = _new_game(arr_stock)
	gs6.load_game()
	check(gs6.smoke_stock == 0, "脏 smoke_stock（数组）：按 0 不崩")
	gs6.free()
	var plan_dirty := _write_save("plan_dirty.json", '{"smoke_carry_plan": {"x": 1}}')
	var gs7 = _new_game(plan_dirty)
	gs7.load_game()
	check(gs7.smoke_carry_plan == -1, "脏 smoke_carry_plan（字典）：按未设置 -1")
	gs7.free()
	# R-12a 出发携带计划：老档缺字段 = 未设置（-1，兼容全部携带）；
	# 合法 0/N 保留；越界负数与布尔/字符串脏值回 -1。
	var plan_legacy := _write_save("plan_legacy.json", '{"smoke_stock": 2}')
	var gs8 = _new_game(plan_legacy)
	gs8.load_game()
	check(gs8.smoke_carry_plan == -1, "老档缺 smoke_carry_plan：默认 -1（全部携带）")
	gs8.free()
	var plan_zero := _write_save("plan_zero.json", '{"smoke_stock": 2, "smoke_carry_plan": 0}')
	var gs9 = _new_game(plan_zero)
	gs9.load_game()
	check(gs9.smoke_carry_plan == 0, "合法 smoke_carry_plan=0 保留（明确不带）")
	gs9.free()
	var plan_two := _write_save("plan_two.json", '{"smoke_stock": 2, "smoke_carry_plan": 2}')
	var gs10 = _new_game(plan_two)
	gs10.load_game()
	check(gs10.smoke_carry_plan == 2, "合法 smoke_carry_plan=2 保留")
	gs10.free()
	var plan_negative := _write_save("plan_negative.json", '{"smoke_carry_plan": -5}')
	var gs11 = _new_game(plan_negative)
	gs11.load_game()
	check(gs11.smoke_carry_plan == -1, "负数 smoke_carry_plan 按 -1（未设置）")
	gs11.free()
	var plan_bool := _write_save("plan_bool.json", '{"smoke_carry_plan": true}')
	var gs12 = _new_game(plan_bool)
	gs12.load_game()
	check(gs12.smoke_carry_plan == -1, "脏 smoke_carry_plan（布尔）：按 -1")
	gs12.free()
	var plan_string := _write_save("plan_string.json", '{"smoke_carry_plan": "2"}')
	var gs13 = _new_game(plan_string)
	gs13.load_game()
	check(gs13.smoke_carry_plan == -1, "脏 smoke_carry_plan（字符串）：按 -1")
	gs13.free()


## 收集册字段：老档缺失 → 空；老档有端详进度 → 兼容解锁；脏条目过滤。
func _test_dirty_archive() -> void:
	var legacy := _write_save("legacy_no_archive.json", '{"money": 10}')
	var gs = _new_game(legacy)
	gs.load_game()
	check(gs.archive_seen.is_empty(), "老档缺 archive_seen：默认空收集册")
	check(not gs.is_archived("mask"), "老档缺 archive_seen：未归档")
	gs.free()

	var lore_only := _write_save("lore_only_archive.json", '{"lore_stage": {"mask": 1}}')
	var gs2 = _new_game(lore_only)
	gs2.load_game()
	check(gs2.is_archived("mask"), "老档的端详进度可兼容解锁档案")
	gs2.free()

	var dirty := _write_save("dirty_archive.json", '{"archive_seen": {"mask": true, "nope": true, "vase": false, "gem": "yes", "5": true}}')
	var gs3 = _new_game(dirty)
	gs3.load_game()
	check(gs3.archive_seen.size() == 1, "脏收集册：只保留合法且为 true 的条目")
	check(gs3.is_archived("mask") and not gs3.is_archived("vase"), "脏收集册：true 保留、false/未知丢弃")
	check(gs3.archived_count() == 1, "脏收集册：真实文物计数正确")
	gs3.free()


## 剧情旗标字段：老档缺失 → 空字典；整段类型脏（字符串/数字）→ 重置；键值脏 → 过滤。
func _test_dirty_story_flags() -> void:
	var legacy := _write_save("legacy_no_flags.json", '{"money": 10}')
	var gs = _new_game(legacy)
	gs.load_game()
	check(gs.story_flags.is_empty(), "老档缺 story_flags：默认空旗标")
	check(not gs.story_flag("read_label"), "老档缺 story_flags：旗标读取为 false")
	check(gs.money == 10, "老档缺 story_flags：其余字段正常")
	gs.free()

	var dirty_str := _write_save("dirty_flags_str.json", '{"money": 5, "story_flags": "nope"}')
	var gs2 = _new_game(dirty_str)
	gs2.load_game()
	check(gs2.story_flags.is_empty(), "脏旗标：整段为字符串时重置为空")
	check(gs2.money == 5, "脏旗标：整段类型脏不影响其余字段")
	gs2.free()

	var dirty_num := _write_save("dirty_flags_num.json", '{"money": 5, "story_flags": 42}')
	var gs3 = _new_game(dirty_num)
	gs3.load_game()
	check(gs3.story_flags.is_empty(), "脏旗标：整段为数字时重置为空")
	gs3.free()

	# 键值脏：合法 bool 与 ending_id 字符串保留，数字/数组等非法值丢弃
	var dirty_values := _write_save(
		"dirty_flags_values.json",
		'{"story_flags": {"read_label": true, "saw_p01": 5, "ending_id": "return", "junk": {"x": 1}}}'
	)
	var gs4 = _new_game(dirty_values)
	gs4.load_game()
	check(gs4.story_flag("read_label"), "脏旗标：合法布尔值保留")
	check(String(gs4.story_flags.get("ending_id", "")) == "return", "脏旗标：ending_id 字符串保留")
	check(not gs4.story_flag("saw_p01"), "脏旗标：非布尔值丢弃（读取为 false）")
	check(gs4.story_flags.size() == 2, "脏旗标：非法键值对被过滤（%d）" % gs4.story_flags.size())
	gs4.free()


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
	writer.archive_seen = {"mask": true, "ram_zun": true}
	writer.story_flags = {"read_label": true, "read_note": true, "honest_to_mask": true, "ending_id": "return"}
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
	check(reader.archive_seen.size() == 2 and reader.is_archived("ram_zun"), "完整档：archive_seen")
	check(reader.story_flag("read_label") and reader.story_flag("read_note"), "完整档：story_flags 布尔旗标（标签/留言）")
	check(reader.story_flag("honest_to_mask"), "完整档：story_flags 布尔旗标（面具）")
	check(String(reader.story_flags.get("ending_id", "")) == "return", "完整档：ending_id 字符串")
	reader.free()
	DirAccess.remove_absolute(path)


func _test_investigation_flags() -> void:
	var path := _write_save("investigation_legacy.json", '{}')
	var gs = _new_game(path)
	gs._persistent = true
	gs.load_game()
	check(not gs.story_flag("contact_恶魔"), "旧档缺联系人记录默认未接听")
	check(not gs.story_flag("mail_contact_ram_zun"), "旧档缺邮件记录默认未回复")
	gs.set_story_flag("contact_恶魔")
	gs.set_story_flag("mail_contact_ram_zun")
	gs.load_game()
	check(gs.story_flag("contact_恶魔") and gs.story_flag("mail_contact_ram_zun"), "来电与邮件存档往返")
	gs.free()
	path = _write_save("investigation_dirty.json", '{"story_flags":{"contact_恶魔":[],"mail_contact_ram_zun":{}}}')
	gs = _new_game(path)
	gs.load_game()
	check(not gs.story_flag("contact_恶魔") and not gs.story_flag("mail_contact_ram_zun"), "脏联系人与邮件记录安全忽略")
	gs.free()


func _test_relic_selection_migration() -> void:
	for pair in [["egypt_stela", "egypt_heart_scarab"], ["greek_relief", "akrotiri_askos"]]:
		var path := _write_save("relic_migration.json", JSON.stringify({"bm_selected_target": pair[0], "archive_seen": {pair[0]: true}}))
		var gs = _new_game(path)
		gs.load_game()
		check(gs.bm_selected_target == pair[1], "旧行动选择迁移到资源包新目标")
		check(gs.archive_seen.has(pair[0]) and not gs.archive_seen.has(pair[1]), "旧收藏不伪造成新文物发现")
		check(not gs.chain_unlocked(pair[1]), "新文物需要重新完成调查链")
		gs.free()
