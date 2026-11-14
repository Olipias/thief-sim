extends SceneTree
## 剧情验收（独立）：story_flags 持久化与据点剧情真实播放。
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
	_test_dirty_flags()
	_test_hub_story_contract()
	_test_hub_story_playback()
	_run_playback_then_finish()


func _run_playback_then_finish() -> void:
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
	check(bool(_flag(gs, "saw_p01", false)) == false, "%s：saw_p01 默认 false" % where)
	check(bool(_flag(gs, "saw_h01", false)) == false, "%s：saw_h01 默认 false" % where)
	check(bool(_flag(gs, "saw_h02", false)) == false, "%s：saw_h02 默认 false" % where)
	check(bool(_flag(gs, "completed_museum", false)) == false, "%s：completed_museum 默认 false" % where)


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
	gs.save_game()
	gs.free()

	var reader = _new_game(path)
	reader.load_game()
	check(bool(_flag(reader, "read_label", false)), "存档往返：read_label")
	check(bool(_flag(reader, "read_note", false)), "存档往返：read_note")
	check(bool(_flag(reader, "honest_to_mask", false)), "存档往返：honest_to_mask")
	check(String(_flag(reader, "ending_id", "")) == "return", "存档往返：ending_id")
	reader.free()


## 脏类型：不崩；脏值不得被 story_flag() 当成 true；未来字段忽略。
func _test_dirty_flags() -> void:
	var path := _fresh_path("dirty.json")
	_write_raw(
		path,
		'{"story_flags": {"read_label": "yes", "read_note": 3, "honest_to_mask": [], '
		+ '"ending_id": 42, "future_flag": true}}'
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
	check(typeof(gs.story_flags.get("ending_id", "")) != TYPE_BOOL, "脏档：ending_id 不得是 bool")
	gs.free()


# ---------------------------------------------------------------- B. 据点剧情

const HUB_STORIES := ["p01_door_in_rain", "h01_label_lesson", "h02_two_addresses"]


## 结构契约：每段剧本非空、所有 goto/选项目标可达、卡片引用存在。
func _test_hub_story_contract() -> void:
	check(Story.ENTRIES.size() >= 3, "据点剧情：至少 3 段（实际 %d）" % Story.ENTRIES.size())
	for entry_id in HUB_STORIES:
		check(Story.has_entry(entry_id), "据点剧情：存在 %s" % entry_id)
		if not Story.has_entry(entry_id):
			continue
		var script := Story.script(entry_id)
		var cards := Story.cards(entry_id)
		check(not script.is_empty(), "据点剧情 %s：剧本非空" % entry_id)
		var labels := {}
		for entry in script:
			if entry.has("label"):
				labels[String(entry["label"])] = true
		var links_ok := true
		var cards_ok := true
		for entry in script:
			if entry.has("goto") and not labels.has(String(entry["goto"])):
				links_ok = false
			if entry.has("choices"):
				for choice in entry["choices"]:
					if not labels.has(String(choice.get("goto", ""))):
						links_ok = false
			if entry.has("card") and not cards.has(String(entry["card"])):
				cards_ok = false
		check(links_ok, "据点剧情 %s：goto/选项均可达" % entry_id)
		check(cards_ok, "据点剧情 %s：卡片引用均存在" % entry_id)


## 用真实 DialogueTree 播放所有选项组合，确保每条分支都能走到结束。
func _test_hub_story_playback() -> void:
	var scene := load("res://src/ui/dialogue_tree.tscn") as PackedScene
	check(scene != null, "据点剧情播放：DialogueTree 可加载")
	if scene == null:
		return
	var tree := scene.instantiate()
	get_root().add_child(tree)
	await process_frame
	for entry_id in HUB_STORIES:
		var script := Story.script(entry_id)
		var cards := Story.cards(entry_id)
		var choice_points := 0
		for entry in script:
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
			tree.play(script, cards)
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
			check(not tree.is_active(), "据点剧情 %s（选项组合 %d）：可完整播放到结束" % [entry_id, combo])
	tree.queue_free()
