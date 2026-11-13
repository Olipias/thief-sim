extends SceneTree
## 剧情验收（独立）：story_flags / 隐藏结局 / 双羊尊文物志 / 真实播放。
##
## 与 test_story.gd 的分工：那边测数据与基础读写；这里测独立验收口径——
## 旧档不误判隐藏结局、脏旗标不得被当 true、隐藏条件四组合、双羊三段的所有选项分支
## 都能用真实 DialogueTree 播放到结束。
##
## 运行：godot --headless --script tests/test_story_flow.gd
## 失败以非零退出码结束；临时存档写入 /tmp。

const DIR := "/tmp/thief_sim_story_flow"

var _failures := 0
var _checks := 0


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL - " + msg)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	_test_flag_defaults()
	_test_flag_persistence()
	_test_old_save_does_not_unlock_hidden_ending()
	_test_dirty_flags()
	_test_hidden_ending_condition()
	_test_zun_lore_contract()
	_run_playback_then_finish()


func _run_playback_then_finish() -> void:
	# --script 模式下主循环尚未启动：等一帧，让场景节点的 @onready 生效
	await process_frame
	await _test_zun_playback()
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


func _has_prop(obj, prop_name: String) -> bool:
	for p in obj.get_property_list():
		if String(p.name) == prop_name:
			return true
	return false


func _has_story_flags(gs) -> bool:
	return _has_prop(gs, "story_flags") and typeof(gs.story_flags) == TYPE_DICTIONARY


func _flag(gs, key: String, default: Variant) -> Variant:
	var flags: Dictionary = gs.story_flags
	return flags.get(key, default)


func _assert_flags_default(gs, where: String) -> void:
	if not _has_story_flags(gs):
		check(false, "%s：缺少 story_flags（S-01 未落地）" % where)
		return
	check(bool(_flag(gs, "read_label", false)) == false, "%s：read_label 默认 false" % where)
	check(bool(_flag(gs, "read_note", false)) == false, "%s：read_note 默认 false" % where)
	check(bool(_flag(gs, "honest_to_mask", false)) == false, "%s：honest_to_mask 默认 false" % where)
	check(String(_flag(gs, "ending_id", "")) == "", "%s：ending_id 默认空" % where)
	check(bool(_flag(gs, "zun_trusted", false)) == false, "%s：zun_trusted 默认 false" % where)


# ---------------------------------------------------------------- A. flag 存档

func _test_flag_defaults() -> void:
	var path := _fresh_path("defaults.json")
	var gs = _new_game(path)
	gs.reset_progress()
	_assert_flags_default(gs, "新档")
	gs.free()


func _test_flag_persistence() -> void:
	var path := _fresh_path("persist.json")
	var gs = _new_game(path)
	gs.reset_progress()
	if not _has_story_flags(gs):
		check(false, "存档往返：缺少 story_flags（S-01 未落地）")
		gs.free()
		return
	gs.story_flags["read_label"] = true
	gs.story_flags["read_note"] = true
	gs.story_flags["honest_to_mask"] = true
	gs.story_flags["ending_id"] = "return"
	gs.story_flags["zun_trusted"] = true
	gs.save_game()
	gs.free()

	var reader = _new_game(path)
	reader.load_game()
	check(bool(_flag(reader, "read_label", false)), "存档往返：read_label")
	check(bool(_flag(reader, "read_note", false)), "存档往返：read_note")
	check(bool(_flag(reader, "honest_to_mask", false)), "存档往返：honest_to_mask")
	check(String(_flag(reader, "ending_id", "")) == "return", "存档往返：ending_id")
	check(bool(_flag(reader, "zun_trusted", false)), "存档往返：zun_trusted")
	reader.free()


## 旧档（完全没有 story_flags）必须用默认值，且不能误判隐藏结局。
func _test_old_save_does_not_unlock_hidden_ending() -> void:
	var path := _fresh_path("legacy.json")
	_write_raw(path, '{"money": 10, "lore_stage": {"mask": 2}}')
	var gs = _new_game(path)
	gs.load_game()
	_assert_flags_default(gs, "旧档")
	if gs.has_method("hidden_ending_unlocked"):
		check(not gs.hidden_ending_unlocked(), "旧档：不得解锁隐藏结局")
	else:
		check(false, "缺少 Game.hidden_ending_unlocked()（S-08 契约）")
	gs.free()


## 脏类型：不崩；脏值不得被 story_flag() 当成 true；未来字段忽略。
func _test_dirty_flags() -> void:
	var path := _fresh_path("dirty.json")
	_write_raw(
		path,
		'{"story_flags": {"read_label": "yes", "read_note": 3, "honest_to_mask": [], '
		+ '"ending_id": 42, "zun_trusted": "x", "future_flag": true}}'
	)
	var gs = _new_game(path)
	gs.load_game()
	if not _has_story_flags(gs):
		check(false, "脏档：缺少 story_flags（S-01 未落地）")
		gs.free()
		return
	check(not gs.story_flag("read_label"), "脏档：字符串 read_label 不得被判为已读")
	check(not gs.story_flag("read_note"), "脏档：数字 read_note 不得被判为已读")
	check(not gs.story_flag("honest_to_mask"), "脏档：数组 honest_to_mask 不得被判为真")
	check(not gs.story_flag("zun_trusted"), "脏档：字符串 zun_trusted 不得被判为真")
	check(typeof(gs.story_flags.get("ending_id", "")) != TYPE_BOOL, "脏档：ending_id 不得是 bool")
	gs.free()


# ---------------------------------------------------------------- B. 隐藏结局条件

## 隐藏结局：read_label + read_note + 双羊 3/3 + honest_to_mask，四组合。
func _test_hidden_ending_condition() -> void:
	var base_path := _fresh_path("hidden_base.json")
	var gs = _new_game(base_path)
	gs.reset_progress()
	if not _has_story_flags(gs):
		check(false, "隐藏结局：缺少 story_flags（S-01 未落地）")
		gs.free()
		return
	if not gs.has_method("hidden_ending_unlocked"):
		check(false, "缺少 Game.hidden_ending_unlocked()（S-08 需要把条件集中到一个函数）")
		gs.free()
		return

	gs.story_flags["read_label"] = true
	gs.story_flags["read_note"] = true
	gs.story_flags["honest_to_mask"] = true
	gs.lore_stage["ram_zun"] = 3
	check(gs.hidden_ending_unlocked(), "隐藏结局：四条件齐备时解锁")

	gs.story_flags["read_label"] = false
	check(not gs.hidden_ending_unlocked(), "隐藏结局：缺 read_label 不解锁")
	gs.story_flags["read_label"] = true

	gs.story_flags["read_note"] = false
	check(not gs.hidden_ending_unlocked(), "隐藏结局：缺 read_note 不解锁")
	gs.story_flags["read_note"] = true

	gs.story_flags["honest_to_mask"] = false
	check(not gs.hidden_ending_unlocked(), "隐藏结局：缺 honest_to_mask 不解锁")
	gs.story_flags["honest_to_mask"] = true

	gs.lore_stage["ram_zun"] = 2
	check(not gs.hidden_ending_unlocked(), "隐藏结局：双羊对谈未满 3 段不解锁")
	gs.lore_stage["ram_zun"] = 3
	check(gs.hidden_ending_unlocked(), "隐藏结局：条件恢复后重新解锁")
	gs.free()


# ---------------------------------------------------------------- C. 双羊文物志契约

func _test_zun_lore_contract() -> void:
	check(Lore.ENTRIES.has("ram_zun"), "S-02：Lore 中存在 ram_zun 条目")
	if not Lore.ENTRIES.has("ram_zun"):
		return
	var stages: Array = Lore.stages("ram_zun")
	var cards: Dictionary = Lore.cards("ram_zun")
	var hotspots: Array = Lore.hotspots("ram_zun")
	check(stages.size() == 3, "双羊：3 段对谈（实际 %d）" % stages.size())
	check(cards.size() == 3, "双羊：3 张展签卡（实际 %d）" % cards.size())
	check(hotspots.size() == 4, "双羊：4 个端详热点（实际 %d）" % hotspots.size())
	for card_id in ["zun_1", "zun_2", "zun_3"]:
		check(cards.has(card_id), "双羊：存在展签卡 %s" % card_id)
		if cards.has(card_id):
			var body := String((cards[card_id] as Dictionary).get("body", ""))
			check(body.length() >= 40, "双羊：卡片 %s 有实质正文" % card_id)
			check(not body.contains("docs/SOURCES.md"), "双羊：卡片 %s 不直接暴露文档路径" % card_id)

	for stage_index in stages.size():
		var stage: Array = stages[stage_index]
		var labels := {}
		var speakers := {}
		var has_card := false
		for entry in stage:
			if entry.has("label"):
				labels[String(entry["label"])] = true
			if entry.has("speaker"):
				speakers[String(entry["speaker"])] = true
			if entry.has("card"):
				has_card = true
				check(cards.has(String(entry["card"])), "双羊第 %d 段：卡片 %s 存在" % [stage_index + 1, entry["card"]])
		var links_ok := true
		for entry in stage:
			if entry.has("goto") and not labels.has(String(entry["goto"])):
				links_ok = false
			if entry.has("choices"):
				for choice in entry["choices"]:
					if not labels.has(String(choice.get("goto", ""))):
						links_ok = false
		check(links_ok, "双羊第 %d 段：所有 goto/选项目标可达" % (stage_index + 1))
		check(has_card, "双羊第 %d 段：包含展签卡（史实与演绎分离）" % (stage_index + 1))
		check(speakers.has("左羊") and speakers.has("右羊"), "双羊第 %d 段：左右羊都有台词" % (stage_index + 1))


## 用真实的 DialogueTree 播放三段对谈：每个选项分支都必须能走到结束（无死循环/无悬空 goto）。
func _test_zun_playback() -> void:
	if not Lore.ENTRIES.has("ram_zun"):
		check(false, "播放测试：缺少 ram_zun 剧本")
		return
	var scene := load("res://src/ui/dialogue_tree.tscn") as PackedScene
	check(scene != null, "播放测试：DialogueTree 场景可加载")
	if scene == null:
		return
	var tree := scene.instantiate()
	get_root().add_child(tree)
	await process_frame
	var stages: Array = Lore.stages("ram_zun")
	var cards: Dictionary = Lore.cards("ram_zun")
	for stage_index in stages.size():
		var stage: Array = stages[stage_index]
		var choice_points := 0
		for entry in stage:
			if entry.has("choices"):
				choice_points += 1
		var combos := 1
		for i in choice_points:
			combos *= 3
		for combo in combos:
			var picks: Array[int] = []
			var value := combo
			for i in choice_points:
				picks.append(value % 3)
				value /= 3
			tree.play(stage, cards)
			var guard := 0
			var pick_index := 0
			while tree.is_active() and guard < 500:
				if tree.choices_box.visible and not tree._choice_buttons.is_empty():
					var pick: int = picks[pick_index] if pick_index < picks.size() else 0
					pick_index += 1
					tree._choice_buttons[mini(pick, tree._choice_buttons.size() - 1)].pressed.emit()
				else:
					tree.advance()
				guard += 1
			check(not tree.is_active(), "双羊第 %d 段（选项组合 %d）：可完整播放到结束" % [stage_index + 1, combo])
	tree.queue_free()
