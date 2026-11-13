extends SceneTree
## 剧情自检：剧情旗标、隐藏结局条件与双羊尊文物志内容。
## 运行：godot --headless --script tests/test_story.gd

var _failures := 0
var _checks := 0


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL - " + msg)


func _new_game():
	var gs = load("res://src/autoload/game_state.gd").new()
	gs.save_path = "/tmp/thief_sim_story_test.json"
	return gs


func _initialize() -> void:
	var Game = _new_game()

	_test_story_flags_default(Game)
	_test_story_flags_write(Game)
	_test_story_flags_unknown(Game)
	_test_hidden_ending(Game)
	_test_ram_zun_lore(Game)

	Game.free()
	if _failures > 0:
		print("FAILED %d / %d checks" % [_failures, _checks])
		quit(1)
	else:
		print("ALL %d CHECKS PASSED" % _checks)
		quit(0)


func _test_story_flags_default(Game) -> void:
	Game.reset_progress()
	check(Game.story_flags.is_empty(), "新游戏：story_flags 为空")
	check(not Game.story_flag("read_label"), "新游戏：read_label 默认 false")
	check(not Game.story_flag("read_note"), "新游戏：read_note 默认 false")
	check(not Game.story_flag("honest_to_mask"), "新游戏：honest_to_mask 默认 false")
	check(not Game.story_flag("zun_trusted"), "新游戏：zun_trusted 默认 false")
	check(Game.story_flags.get("ending_id", "") == "", "新游戏：ending_id 默认空字符串")


func _test_story_flags_write(Game) -> void:
	Game.reset_progress()
	Game.set_story_flag("read_label")
	check(Game.story_flag("read_label"), "set_story_flag：写入 true")
	check(Game.story_flags.get("read_label") == true, "set_story_flag：值类型为 bool")
	Game.set_story_flag("read_note", false)
	check(not Game.story_flag("read_note"), "set_story_flag：写入 false")
	Game.story_flags["ending_id"] = "sell"
	check(Game.story_flags.get("ending_id") == "sell", "ending_id 可直接写入字符串")
	Game.reset_progress()
	check(not Game.story_flag("read_label"), "reset_progress：旗标清空")


func _test_story_flags_unknown(Game) -> void:
	Game.reset_progress()
	check(not Game.story_flag("does_not_exist"), "未知键：返回 false")
	Game.story_flags["weird"] = 123
	check(not Game.story_flag("weird"), "非 bool 值：读取为 false")
	Game.reset_progress()


func _test_hidden_ending(Game) -> void:
	Game.reset_progress()
	check(not Game.hidden_ending_unlocked(), "全空：隐藏结局不解锁")

	Game.set_story_flag("read_label")
	Game.set_story_flag("read_note")
	Game.set_story_flag("honest_to_mask")
	check(not Game.hidden_ending_unlocked(), "缺 zun：隐藏结局不解锁")

	Game.reset_progress()
	Game.set_story_flag("read_label")
	Game.set_story_flag("read_note")
	Game.set_story_flag("honest_to_mask")
	Game.set_story_flag("zun_trusted")
	check(Game.hidden_ending_unlocked(), "zun_trusted：隐藏结局解锁")

	Game.reset_progress()
	Game.set_story_flag("read_label")
	Game.set_story_flag("read_note")
	Game.set_story_flag("honest_to_mask")
	# 将双羊尊进度推到满
	while Game.lore_stage_of("ram_zun") < Lore.stage_count("ram_zun"):
		Game.advance_lore_stage("ram_zun")
	check(Game.hidden_ending_unlocked(), "双羊尊满进度：隐藏结局解锁")

	Game.reset_progress()


func _test_ram_zun_lore(Game) -> void:
	check(Lore.has_lore("ram_zun"), "双羊尊：存在文物志")
	check(Lore.stage_count("ram_zun") == 3, "双羊尊：3 段器灵对谈（%d）" % Lore.stage_count("ram_zun"))
	var cards: Dictionary = Lore.cards("ram_zun")
	check(cards.size() == 3, "双羊尊：3 张展签卡（%d）" % cards.size())
	for key in ["zun_1", "zun_2", "zun_3"]:
		check(cards.has(key), "双羊尊：展签卡 %s 存在" % key)
	var hotspots: Array = Lore.hotspots("ram_zun")
	check(hotspots.size() == 4, "双羊尊：4 个端详热点（%d）" % hotspots.size())
	for i in range(hotspots.size()):
		var h: Dictionary = hotspots[i]
		check(h.has("pos") and h.has("label") and h.has("fact") and h.has("ghost"), "双羊尊热点 %d：含坐标/标签/史实/器灵台词" % i)
		var pos: Vector2 = h["pos"]
		check(pos.x >= 0.0 and pos.x <= 1.0 and pos.y >= 0.0 and pos.y <= 1.0, "双羊尊热点 %d：坐标归一化" % i)
