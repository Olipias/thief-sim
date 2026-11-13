extends SceneTree
## P3/P5/P6 数据层验收：安全屋推理链 + 恶魔契约/催交剧本。
##
## 本套件先锁数据契约（零倒计时、三链三卡两连线、结局卡可达、史实边界），
## 待 code 落地 Batch 1 后再补「安全屋 UI / 连线解锁 / 检查点回溯」的 E2E 用例。
##
## 运行：godot --headless --script tests/test_reasoning.gd

var _failures := 0
var _checks := 0

const APPS := {
	"pc_archive": 3,
	"pc_browser": 3,
	"pc_mail": 1,
	"phone_chat": 2,
}
const FORBIDDEN_KEYS := ["timer", "countdown", "time_limit", "deadline", "remaining", "seconds_left"]
const FORBIDDEN_TEXT := ["倒计时", "限时", "读秒"]


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL - " + msg)


func _initialize() -> void:
	_test_evidence_chains()
	_test_evidence_apps()
	_test_no_countdown()
	_test_story_contract()
	_test_devil_branch_reachability()
	_test_history_boundary()
	_run_playback_then_finish()


func _run_playback_then_finish() -> void:
	# --script 模式下主循环尚未启动：等一帧，让场景节点的 @onready 生效
	await process_frame
	await _test_devil_playback()
	if _failures > 0:
		print("FAILED %d / %d checks" % [_failures, _checks])
		quit(1)
	else:
		print("ALL %d CHECKS PASSED" % _checks)
		quit(0)


# ---------------------------------------------------------------- A. 推理链结构

func _test_evidence_chains() -> void:
	var ids := EvidenceData.chain_ids()
	check(ids == ["ram_zun", "egypt_stela", "greek_relief"], "推理链：三条链顺序固定（%s）" % str(ids))
	check(EvidenceData.CHAINS.size() == 3, "推理链：恰好三条（实际 %d）" % EvidenceData.CHAINS.size())

	for chain_id in ids:
		var chain := EvidenceData.chain(chain_id)
		check(not chain.is_empty(), "推理链 %s：存在" % chain_id)
		if chain.is_empty():
			continue
		check(String(chain.get("title", "")).length() >= 6, "推理链 %s：有中文标题" % chain_id)
		check(String(chain.get("target_id", "")) == chain_id, "推理链 %s：target_id 一致" % chain_id)
		check(String(chain.get("flag_unlocked", "")) == "chain_%s_done" % chain_id, "推理链 %s：解锁 flag 命名一致" % chain_id)
		check(String(chain.get("summary", "")).length() >= 30, "推理链 %s：有实质摘要" % chain_id)

		var clues: Dictionary = chain.get("clues", {})
		check(clues.size() == 3, "推理链 %s：3 张线索卡（实际 %d）" % [chain_id, clues.size()])
		var clue_ids := {}
		for clue_key in clues:
			var clue: Dictionary = clues[clue_key]
			var clue_id := String(clue.get("id", ""))
			check(clue_id == String(clue_key), "推理链 %s：线索 key/id 一致（%s）" % [chain_id, clue_key])
			check(not clue_id.is_empty(), "推理链 %s：线索 id 非空" % chain_id)
			clue_ids[clue_id] = true
			check(String(clue.get("title", "")).length() >= 6, "推理链 %s：线索 %s 有标题" % [chain_id, clue_id])
			check(String(clue.get("body", "")).length() >= 40, "推理链 %s：线索 %s 有实质正文" % [chain_id, clue_id])
			check(APPS.has(String(clue.get("source_app", ""))), "推理链 %s：线索 %s 来源 App 合法（%s）" % [chain_id, clue_id, clue.get("source_app", "")])

		var links: Array = chain.get("required_links", [])
		check(links.size() == 2, "推理链 %s：两条连线（实际 %d）" % [chain_id, links.size()])
		var covered := {}
		var links_ok := true
		for link in links:
			if not (link is Array) or link.size() != 2:
				links_ok = false
				continue
			for end_id in link:
				if not clue_ids.has(String(end_id)):
					links_ok = false
				else:
					covered[String(end_id)] = true
		check(links_ok, "推理链 %s：连线的端点都存在" % chain_id)
		check(covered.size() == clues.size(), "推理链 %s：连线覆盖全部 3 张卡" % chain_id)


func _test_evidence_apps() -> void:
	for app_id in APPS:
		var items := EvidenceData.clues_for_app(app_id)
		check(items.size() == int(APPS[app_id]), "线索来源 %s：%d 张（实际 %d）" % [app_id, int(APPS[app_id]), items.size()])
		for item in items:
			check(EvidenceData.CHAINS.has(String(item.get("chain_id", ""))), "线索来源 %s：附带合法 chain_id" % app_id)
			check(String(item.get("source_app", "")) == app_id, "线索来源 %s：source_app 过滤正确" % app_id)
	check(EvidenceData.clues_for_app("unknown_app").is_empty(), "线索来源 unknown_app：返回空")


# ---------------------------------------------------------------- B. 零倒计时

func _test_no_countdown() -> void:
	for chain_id in EvidenceData.chain_ids():
		var bad := _countdown_violations(EvidenceData.chain(chain_id), "EvidenceData.%s" % chain_id)
		check(bad.is_empty(), "EvidenceData.%s：无倒计时字段/文案（%s）" % [chain_id, ", ".join(bad)])
	for entry_id in ["p00_devil_contract", "p05_devil_demand"]:
		var bad := _countdown_violations(Story.ENTRIES.get(entry_id, {}), "Story.%s" % entry_id)
		check(bad.is_empty(), "Story.%s：无倒计时字段/文案（%s）" % [entry_id, ", ".join(bad)])

	var evidence_src := FileAccess.get_file_as_string("res://src/data/evidence.gd")
	check(not evidence_src.contains("Timer"), "EvidenceData：源码不引用 Timer")
	check(not evidence_src.contains("countdown"), "EvidenceData：源码不引用 countdown")


## 递归收集倒计时字段/文案；不把「3 秒内托起」这类氛围描写当倒计时。
func _countdown_violations(value: Variant, path: String, out: Array[String] = []) -> Array[String]:
	if value is Dictionary:
		for key in value:
			var key_text := String(key).to_lower()
			for forbidden in FORBIDDEN_KEYS:
				if key_text.contains(forbidden):
					out.append("%s.%s" % [path, key])
			_countdown_violations(value[key], "%s.%s" % [path, key], out)
	elif value is Array:
		for i in value.size():
			_countdown_violations(value[i], "%s[%d]" % [path, i], out)
	elif value is String:
		for forbidden in FORBIDDEN_TEXT:
			if String(value).contains(forbidden):
				out.append(path)
	return out


# ---------------------------------------------------------------- C. 恶魔剧本结构

func _test_story_contract() -> void:
	for entry_id in ["p00_devil_contract", "p05_devil_demand"]:
		check(Story.has_entry(entry_id), "恶魔剧本：存在 %s" % entry_id)
		if not Story.has_entry(entry_id):
			continue
		var script := Story.script(entry_id)
		var cards := Story.cards(entry_id)
		check(not script.is_empty(), "恶魔剧本 %s：剧本非空" % entry_id)
		var labels := _labels(script)
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
		check(links_ok, "恶魔剧本 %s：goto/选项均可达" % entry_id)
		check(cards_ok, "恶魔剧本 %s：卡片引用均存在" % entry_id)

	# p00 的契约附页可达
	var contract_cards := _reachable_cards(Story.script("p00_devil_contract"))
	check(contract_cards.has("contract_clause"), "P0-0：契约附页 card 可达")
	check(Story.cards("p00_devil_contract").has("contract_clause"), "P0-0：契约附页卡片存在")


func _test_devil_branch_reachability() -> void:
	var cards := _reachable_cards(Story.script("p05_devil_demand"))
	for card_id in ["wrath_scene", "ending_comply_card", "ending_rebel_return_card", "ending_rebel_broker_card"]:
		check(cards.has(card_id), "P5：结局/发火卡可达 %s" % card_id)
		check(Story.cards("p05_devil_demand").has(card_id), "P5：结局/发火卡存在 %s" % card_id)

	var script := Story.script("p05_devil_demand")
	var first_choices: Array = []
	var second_choices: Array = []
	for entry in script:
		if not entry.has("choices"):
			continue
		if first_choices.is_empty():
			first_choices = entry["choices"]
		else:
			second_choices = entry["choices"]
	check(first_choices.size() == 2, "P5：阶段一为「直接上交 / 拒交」两个选择（实际 %d）" % first_choices.size())
	check(second_choices.size() == 3, "P5：阶段二为「屈服 / 归还 / 黑市」三个选择（实际 %d）" % second_choices.size())
	check(String(first_choices[0].get("goto", "")) == "p05_hand_over", "P5：阶段一第一项走直接上交")
	check(String(first_choices[1].get("goto", "")) == "p05_refuse", "P5：阶段一第二项走拒交发火")


func _test_history_boundary() -> void:
	var h01 := Story.cards("h01_label_lesson")
	var first: Dictionary = h01.get("card_1936", {})
	var body := String(first.get("body", ""))
	check(body.contains("尤摩弗帕勒斯") or body.contains("Eumorfopoulos"), "H-01：第一张卡保留尤摩弗帕勒斯可考细节")
	check(body.contains("1936,1118.1"), "H-01：第一张卡保留馆藏编号")

	var p05 := Story.cards("p05_devil_demand")
	for card_id in ["ending_comply_card", "ending_rebel_return_card", "ending_rebel_broker_card"]:
		var text := String((p05.get(card_id, {}) as Dictionary).get("body", ""))
		check(text.contains("虚构") and text.contains("现实"), "P5 %s：包含史实/虚构声明" % card_id)
		check(not text.contains("1860"), "P5 %s：不得把 1860 圆明园说写成史实" % card_id)


# ---------------------------------------------------------------- D. 全分支播放

func _test_devil_playback() -> void:
	var scene := load("res://src/ui/dialogue_tree.tscn") as PackedScene
	check(scene != null, "恶魔剧本播放：DialogueTree 可加载")
	if scene == null:
		return
	var tree := scene.instantiate()
	get_root().add_child(tree)
	await process_frame
	for entry_id in ["p00_devil_contract", "p05_devil_demand"]:
		var script := Story.script(entry_id)
		var cards := Story.cards(entry_id)
		var sizes: Array[int] = []
		for entry in script:
			if entry.has("choices"):
				sizes.append(entry["choices"].size())
		var combos := 1
		for n in sizes:
			combos *= n
		for combo in combos:
			var picks: Array[int] = []
			var value := combo
			for n in sizes:
				picks.append(value % n)
				value /= n
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
			check(not tree.is_active(), "恶魔剧本 %s（选项组合 %d）：可完整播放到结束" % [entry_id, combo])
	tree.queue_free()


# ---------------------------------------------------------------- 工具

func _labels(script: Array) -> Dictionary:
	var labels := {}
	for entry in script:
		if entry.has("label"):
			labels[String(entry["label"])] = true
	return labels


## 从剧本入口做图遍历，返回所有可达的 card id。
func _reachable_cards(script: Array) -> Dictionary:
	var labels := {}
	for i in script.size():
		var entry: Dictionary = script[i]
		if entry.has("label"):
			labels[String(entry["label"])] = i
	var stack: Array[int] = [0]
	var seen := {}
	var cards := {}
	while not stack.is_empty():
		var index: int = stack.pop_back()
		if seen.has(index) or index < 0 or index >= script.size():
			continue
		seen[index] = true
		var entry: Dictionary = script[index]
		if entry.has("card"):
			cards[String(entry["card"])] = true
		if entry.has("goto"):
			stack.append(int(labels.get(String(entry["goto"]), script.size())))
		elif entry.has("choices"):
			for choice in entry["choices"]:
				stack.append(int(labels.get(String(choice.get("goto", "")), script.size())))
		else:
			stack.append(index + 1)
	return cards
