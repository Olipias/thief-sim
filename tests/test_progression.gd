extends SceneTree
## 玩家进度自检（独立验收）：结算 / 仓库 / 收集册 / 存档健壮性。
##
## 关注点：任何可能让玩家"丢进度、白干、重复领奖、被没收的赃物复活"的边角。
## 与 test_logic 的分工：那边测规则主路径，这里测跨会话持久化与失败路径。
##
## 运行：godot --headless --script tests/test_progression.gd
## 失败以非零退出码结束；临时存档写入 /tmp。

const DIR := "/tmp/thief_sim_progression"

var _failures := 0
var _checks := 0


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL - " + msg)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	_test_bust_confiscates_and_persists()
	_test_finish_is_idempotent()
	_test_stash_persists()
	_test_sell_edges()
	_test_archive_lifecycle()
	_test_save_robustness()
	_test_new_game_clears_everything()

	if _failures > 0:
		print("FAILED %d / %d checks" % [_failures, _checks])
		quit(1)
	else:
		print("ALL %d CHECKS PASSED" % _checks)
		quit(0)


# ---------------------------------------------------------------- 工具

func _new_game(path: String):
	var gs = load("res://src/autoload/game_state.gd").new()
	gs.save_path = path
	gs._persistent = true
	return gs


func _fresh_path(name: String) -> String:
	var path := DIR + "/" + name
	for suffix in ["", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	return path


func _write_raw(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _reload(path: String):
	var gs = _new_game(path)
	gs.load_game()
	return gs


# ---------------------------------------------------------------- 用例

## 被逮捕 = 没收赃物。没收必须落盘：退出重开/读档后，赃物与任务目标不得复活。
func _test_bust_confiscates_and_persists() -> void:
	var path := _fresh_path("bust.json")
	var gs = _new_game(path)
	gs.reset_progress()
	gs.set_level("museum")
	gs.reset_run()
	check(gs.try_pickup("mask"), "被逮用例：拾取任务目标")
	check(gs.try_pickup("vase"), "被逮用例：拾取普通赃物")
	check(FileAccess.file_exists(path), "拾取会自动落盘（归档 + 背包）")

	var summary: Dictionary = gs.finish_run(false)
	check(not summary["success"], "被逮：结算为失败")
	check(gs.bag_items.is_empty(), "被逮：内存中的赃物被没收")
	check(not gs.mission_complete, "被逮：任务完成标记清空")
	gs.free()

	var reader = _reload(path)
	check(reader.bag_items.is_empty(), "被逮后读档：赃物不得复活")
	check(not reader.mission_complete, "被逮后读档：任务不得处于完成态")
	check(reader.is_archived("mask"), "被逮后读档：接触过的文物档案仍保留（设计如此）")
	reader.free()


## 结算只能发一次奖 / 入一次仓（重复调用或重复信号不得刷钱）。
func _test_finish_is_idempotent() -> void:
	var path := _fresh_path("finish.json")
	var gs = _new_game(path)
	gs.reset_progress()
	gs.set_level("museum")
	gs.reset_run()
	gs.try_pickup("mask")
	gs.try_pickup("vase")
	var first: Dictionary = gs.finish_run(true)
	check(first["success"], "结算：带目标撤离成功")
	var money_after: int = gs.money
	var stash_after: int = gs.loot_stash.size()
	var second: Dictionary = gs.finish_run(true)
	check(not second["success"], "结算：第二次调用被拒绝")
	check(gs.money == money_after, "结算：不会重复发放报酬")
	check(gs.loot_stash.size() == stash_after, "结算：不会重复存入仓库")
	gs.free()


## 仓库与金币必须跨会话保留；报酬与赃物估值分开记账。
func _test_stash_persists() -> void:
	var path := _fresh_path("stash.json")
	var gs = _new_game(path)
	gs.reset_progress()
	gs.set_level("museum")
	gs.reset_run()
	gs.try_pickup("mask")
	gs.try_pickup("vase")   # 120
	gs.try_pickup("gem")    # 300
	var summary: Dictionary = gs.finish_run(true)
	check(int(summary["stash_value"]) == 420, "仓库：估值 = 120 + 300")
	check(gs.money == gs.MISSION_REWARD, "仓库：撤离当下只入账组织报酬")
	gs.free()

	var reader = _reload(path)
	check(reader.loot_stash.size() == 2, "仓库：读档后战利品还在")
	check(reader.stash_value() == 420, "仓库：读档后估值不变")
	check(reader.money == reader.MISSION_REWARD, "仓库：读档后金币不变")
	reader.free()


## 卖店边界：非法下标不得扣物品/加钱；卖空后再次全卖不得刷钱。
func _test_sell_edges() -> void:
	var path := _fresh_path("sell.json")
	var gs = _new_game(path)
	gs.reset_progress()
	var stash: Array[String] = ["vase", "gem"]
	gs.loot_stash = stash
	gs.money = 10

	check(gs.sell_stash_item(-1) == 0, "卖店：非法下标 -1 返回 0")
	check(gs.sell_stash_item(99) == 0, "卖店：越界下标返回 0")
	check(gs.money == 10 and gs.loot_stash.size() == 2, "卖店：非法下标不改变状态")

	check(gs.sell_stash_item(0) == 120, "卖店：卖出第一件得 120")
	check(gs.money == 130, "卖店：金币入账")
	check(gs.loot_stash.size() == 1 and gs.loot_stash[0] == "gem", "卖店：剩余物品正确")

	check(gs.sell_all_stash() == 300, "卖店：全部出手得剩余估值")
	check(gs.money == 430, "卖店：全卖后金币正确")
	check(gs.sell_all_stash() == 0 and gs.money == 430, "卖店：卖空后再次全卖不刷钱")
	gs.free()


## 收集册：首次接触即归档、普通赃物不计入、重置才清空、进度跨会话保留。
func _test_archive_lifecycle() -> void:
	var path := _fresh_path("archive.json")
	var gs = _new_game(path)
	gs.reset_progress()
	check(not gs.is_archived("mask"), "收集册：初始未归档")

	gs.set_level("museum")
	gs.reset_run()
	check(gs.try_pickup("vase"), "收集册：拾取普通赃物")
	check(gs.is_archived("vase"), "收集册：接触即记住（普通赃物也记住）")
	check(gs.archived_count() == 0, "收集册：普通赃物不计入真实文物")
	check(gs.try_pickup("mask"), "收集册：拾取真实文物")
	check(gs.archived_count() == 1, "收集册：真实文物计数 +1")

	gs.reset_run()
	check(gs.is_archived("mask") and gs.archived_count() == 1, "收集册：开新一局不清档案")
	gs.free()

	var reader = _reload(path)
	check(reader.is_archived("mask"), "收集册：读档后仍归档")
	reader.reset_progress()
	check(not reader.is_archived("mask") and reader.archived_count() == 0, "收集册：新游戏清空")
	reader.free()


## 存档健壮性：损坏档不能被当成"可继续"；半写残留不得影响读档；写档不得留下 .tmp。
func _test_save_robustness() -> void:
	var path := _fresh_path("robust.json")
	var gs = _new_game(path)
	gs.reset_progress()
	gs.money = 42
	gs.save_game()
	check(FileAccess.file_exists(path), "存档：写入主档")
	check(not FileAccess.file_exists(path + ".tmp"), "存档：不残留 .tmp 临时文件")

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(typeof(parsed) == TYPE_DICTIONARY, "存档：主档是合法 JSON")
	check(int((parsed as Dictionary).get("money", -1)) == 42, "存档：主档内容正确")

	# 模拟"写到一半崩溃"：主档被截断。不能把损坏档当作可继续，也不能崩。
	_write_raw(path, '{"money": 42, "bag_items": [')
	check(not gs.has_save(), "存档：损坏档不提供「继续游戏」")
	var reader = _reload(path)
	check(reader.money == 0 and reader.bag_items.is_empty(), "存档：损坏档安全回退为空进度")
	reader.free()

	# 残留 .tmp（上次崩溃）不得影响主档读取
	_write_raw(path, '{"money": 7}')
	_write_raw(path + ".tmp", '{"money": 999}')
	var reader2 = _reload(path)
	check(reader2.money == 7, "存档：残留 .tmp 不被当作主档")
	reader2.free()
	DirAccess.remove_absolute(path + ".tmp")
	gs.free()


## 新游戏必须清空一切进度并立刻落盘（避免旧档复活）。
func _test_new_game_clears_everything() -> void:
	var path := _fresh_path("newgame.json")
	var gs = _new_game(path)
	gs.money = 500
	var stash: Array[String] = ["gem"]
	gs.loot_stash = stash
	gs.archive_seen = {"mask": true}
	gs.lore_stage = {"mask": 2}
	gs.save_game()
	check(gs.has_save(), "新游戏用例：旧档已存在")

	gs.start_new_game()
	check(gs.money == 0 and gs.loot_stash.is_empty() and gs.archive_seen.is_empty(), "新游戏：内存进度清空")
	check(gs.lore_stage.is_empty(), "新游戏：文物志进度清空")
	gs.free()

	var reader = _reload(path)
	check(reader.money == 0 and reader.loot_stash.is_empty(), "新游戏：读档确认旧进度未复活")
	check(not reader.is_archived("mask") and reader.lore_stage_of("mask") == 0, "新游戏：档案/文物志已清空")
	reader.free()
