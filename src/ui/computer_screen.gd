class_name ComputerScreen
extends CanvasLayer
## 书桌电脑覆盖层（E 批）：浏览器 / 档案库 / 邮件 / 聊天 / 推理板。
##
## 覆盖层契约与背包/手机一致：open ⇔ 暂停（暂停由 Main 控制），P/B/ESC 关闭。
## 数据来自 src/data/investigation.gd，进度通过 Game.story_flag 持久化。

signal closed

const TAB_NAMES := ["浏览器", "档案库", "邮件", "聊天", "推理板"]

@onready var panel: PanelContainer = $Root/Panel
@onready var vbox: VBoxContainer = $Root/Panel/Margin/VBox
@onready var body: VBoxContainer = $Root/Panel/Margin/VBox/Body

var _tab_bar: TabBar
var _content: VBoxContainer

# 浏览器
var _browser_search: LineEdit
var _browser_results: VBoxContainer

# 邮件
var _mail_list: ItemList
var _mail_body: Label

# 聊天
var _chat_log: RichTextLabel
var _chat_input: LineEdit
var _chat_send: Button

# 推理板
var _board: InvestigationBoard
var _board_target: OptionButton
var _board_question: OptionButton
var _board_material: OptionButton
var _board_relation: OptionButton
var _board_feedback: Label


func _ready() -> void:
	visible = false
	# 清除 R-01 骨架期留下的占位标签。
	for child in body.get_children():
		child.queue_free()

	# 让电脑面板占满屏幕并留边距。
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 18
	panel.offset_top = 14
	panel.offset_right = -18
	panel.offset_bottom = -14

	_tab_bar = TabBar.new()
	_tab_bar.tab_count = TAB_NAMES.size()
	for i in TAB_NAMES.size():
		_tab_bar.set_tab_title(i, TAB_NAMES[i])
	_tab_bar.tab_changed.connect(_on_tab_changed)
	vbox.add_child(_tab_bar)
	vbox.move_child(_tab_bar, 1)

	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	body.add_child(_content)

	_refresh()


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	visible = true
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("bag") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_tab_changed(tab: int) -> void:
	_refresh_content(tab)


func _refresh() -> void:
	if _tab_bar == null:
		return
	_refresh_content(_tab_bar.current_tab)


func _refresh_content(tab: int) -> void:
	for child in _content.get_children():
		child.queue_free()

	match TAB_NAMES[tab]:
		"浏览器": _build_browser()
		"档案库": _build_archive()
		"邮件": _build_mail()
		"聊天": _build_chat()
		"推理板": _build_board()


# ---------------------------------------------------------------- 浏览器
func _build_browser() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_content.add_child(row)

	_browser_search = LineEdit.new()
	_browser_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_browser_search.placeholder_text = "输入关键词或编号"
	_browser_search.text_submitted.connect(_on_browser_search)
	row.add_child(_browser_search)

	var btn := Button.new()
	btn.text = "搜索"
	btn.pressed.connect(_on_browser_search.bind(""))
	row.add_child(btn)

	var help := Label.new()
	help.add_theme_font_size_override("font_size", 10)
	help.add_theme_color_override("font_color", Color(0.65, 0.67, 0.75, 1))
	help.text = "试试：双羊尊、1936,1118.1、C-17、青铜传统"
	_content.add_child(help)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(scroll)

	_browser_results = VBoxContainer.new()
	_browser_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_browser_results.add_theme_constant_override("separation", 6)
	scroll.add_child(_browser_results)


func _on_browser_search(_text: String = "") -> void:
	var kw := _browser_search.text.strip_edges()
	for child in _browser_results.get_children():
		child.queue_free()

	if kw == "":
		return

	var found := false
	# 网页结果
	for key in Investigation.search_web(kw):
		var parts := key.split(":")
		if parts.size() < 2:
			continue
		var tid := parts[0]
		var mid := parts[1]
		var mat := Investigation.material(tid, mid)
		Game.set_story_flag(mat.get("unlock", ""))
		_browser_results.add_child(_make_card("网页 · " + mat.get("title", ""), mat.get("body", "")))
		found = true

	# 档案结果
	for key in Investigation.search_archive(kw):
		var parts := key.split(":")
		if parts.size() < 2:
			continue
		var tid := parts[0]
		var mid := parts[1]
		var mat := Investigation.material(tid, mid)
		Game.set_story_flag(mat.get("unlock", ""))
		_browser_results.add_child(_make_card("档案 · " + mat.get("title", ""), mat.get("body", "")))
		found = true

	if not found:
		var none := Label.new()
		none.add_theme_font_size_override("font_size", 11)
		none.text = "没有匹配结果。换个关键词，或等阿岚发来资料。"
		_browser_results.add_child(none)


# ---------------------------------------------------------------- 档案库
func _build_archive() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var any := false
	for tid in Investigation.target_ids():
		for mid in Investigation.materials(tid).keys():
			var mat := Dictionary(Investigation.material(tid, mid))
			if mat.get("type", "") != "archive":
				continue
			var flag := mat.get("unlock", "") as String
			if flag == "" or Game.story_flag(flag):
				list.add_child(_make_card(mat.get("title", ""), mat.get("body", "")))
				any = true
	if not any:
		var hint := Label.new()
		hint.add_theme_font_size_override("font_size", 11)
		hint.text = "档案库为空。在浏览器用编号检索已解锁的目标。"
		list.add_child(hint)


# ---------------------------------------------------------------- 邮件
func _build_mail() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var any := false
	for tid in Investigation.target_ids():
		for mid in Investigation.materials(tid).keys():
			var mat := Dictionary(Investigation.material(tid, mid))
			if mat.get("type", "") != "mail":
				continue
			var flag := mat.get("unlock", "") as String
			if flag == "" or Game.story_flag(flag):
				list.add_child(_make_card(mat.get("title", ""), mat.get("body", "")))
				any = true
	if not any:
		var hint := Label.new()
		hint.add_theme_font_size_override("font_size", 11)
		hint.text = "没有新邮件。和联系人聊聊，也许能收到附件。"
		list.add_child(hint)


# ---------------------------------------------------------------- 聊天
func _build_chat() -> void:
	_chat_log = RichTextLabel.new()
	_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log.bbcode_enabled = true
	_chat_log.scroll_active = true
	_content.add_child(_chat_log)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_content.add_child(row)

	_chat_input = LineEdit.new()
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.placeholder_text = "发给阿岚..."
	_chat_input.text_submitted.connect(_on_chat_sent)
	row.add_child(_chat_input)

	_chat_send = Button.new()
	_chat_send.text = "发送"
	_chat_send.pressed.connect(_on_chat_sent.bind(""))
	row.add_child(_chat_send)

	_append_chat("系统", "联系人：阿岚。把目标名字或编号发给她，她会回邮件。")
	if Game.story_flag("inv_zun_delivery"):
		_append_chat("阿岚", "C-17 的搬运备注已经发到你邮箱了。展位在青铜厅内侧。")
	if Game.story_flag("inv_scarab_delivery"):
		_append_chat("阿岚", "E-09 的布展备注已经发到你邮箱了。展位在埃及厅。")
	if Game.story_flag("inv_askos_delivery"):
		_append_chat("阿岚", "G-04 的布展备注已经发到你邮箱了。展位在希腊厅。")


func _on_chat_sent(_text: String = "") -> void:
	var msg := _chat_input.text.strip_edges()
	if msg == "":
		return
	_append_chat("我", msg)
	_chat_input.text = ""

	var replied := false
	if msg.contains("双羊尊") or msg.contains("1936,1118.1") or msg.contains("C-17"):
		if not Game.story_flag("inv_zun_delivery"):
			Game.set_story_flag("inv_zun_delivery")
			_append_chat("阿岚", "收到。我把 C-17 的搬运备注发到你邮箱。")
			replied = true
	if msg.contains("圣甲虫") or msg.contains("10.130.1650") or msg.contains("E-09"):
		if not Game.story_flag("inv_scarab_delivery"):
			Game.set_story_flag("inv_scarab_delivery")
			_append_chat("阿岚", "收到。我把 E-09 的布展备注发到你邮箱。")
			replied = true
	if msg.contains("注壶") or msg.contains("阿克罗蒂里") or msg.contains("VM-GR-25-012") or msg.contains("G-04"):
		if not Game.story_flag("inv_askos_delivery"):
			Game.set_story_flag("inv_askos_delivery")
			_append_chat("阿岚", "收到。我把 G-04 的布展备注发到你邮箱。")
			replied = true
	if not replied:
		_append_chat("阿岚", "查到了我会直接发邮件。你先去现场看看门牌。")


func _append_chat(speaker: String, text: String) -> void:
	var color := "#a8acb8" if speaker == "系统" else "#e0e2e8"
	_chat_log.append_text("[color=%s][b]%s[/b]：%s[/color]\n" % [color, speaker, text])
	_chat_log.scroll_to_line(_chat_log.get_line_count())


# ---------------------------------------------------------------- 推理板
func _build_board_legacy() -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	_content.add_child(header)

	var target_label := Label.new()
	target_label.text = "目标："
	header.add_child(target_label)

	_board_target = OptionButton.new()
	for tid in Investigation.target_ids():
		_board_target.add_item(Investigation.target_name(tid))
	_board_target.item_selected.connect(_on_board_target_changed)
	header.add_child(_board_target)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	# 中央档案卡
	var tid := Investigation.target_ids()[_board_target.selected if _board_target.selected >= 0 else 0]
	var materials := Investigation.unlocked_materials(tid)
	var note: Dictionary = {}
	if materials.has("zun_name"):
		note = materials["zun_name"]
	else:
		# 恶魔清单对所有目标共用，但 ID 不同；取任意 name 型笔记。
		for mid in materials.keys():
			var mat: Dictionary = materials[mid]
			if mat.get("type", "") == "note":
				note = mat
				break
	if not note.is_empty():
		list.add_child(_make_card(note.get("title", ""), note.get("body", "")))

	# 三个问题
	for q in Investigation.questions(tid):
		var qid: String = q["id"]
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		list.add_child(box)

		var title := Label.new()
		title.add_theme_font_size_override("font_size", 12)
		title.text = q["text"]
		box.add_child(title)

		if Investigation.is_question_answered(tid, qid):
			var done := Label.new()
			done.add_theme_font_size_override("font_size", 10)
			done.add_theme_color_override("font_color", Color(0.5, 0.85, 0.55, 1))
			done.text = "已确认"
			box.add_child(done)
		elif not Investigation.can_answer_question(tid, qid):
			var missing := Label.new()
			missing.add_theme_font_size_override("font_size", 10)
			missing.add_theme_color_override("font_color", Color(0.85, 0.55, 0.55, 1))
			var req_names: Array[String] = []
			for req in Investigation.question_requires(tid, qid):
				var mat := Investigation.material(tid, req)
				req_names.append(mat.get("title", req))
			missing.text = "缺少材料：%s" % ", ".join(req_names)
			box.add_child(missing)
		else:
			var hbox := HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 4)
			box.add_child(hbox)

			var mat_opt := OptionButton.new()
			mat_opt.add_item("选择材料")
			for mid in materials.keys():
				var mat: Dictionary = materials[mid]
				if qid in mat.get("answers", []):
					mat_opt.add_item(mat.get("title", mid))
					mat_opt.set_item_metadata(mat_opt.item_count - 1, mid)
			mat_opt.item_selected.connect(_on_board_material_changed.bind(mat_opt))
			hbox.add_child(mat_opt)

			var rel_opt := OptionButton.new()
			rel_opt.add_item("选择关系")
			hbox.add_child(rel_opt)

			var confirm := Button.new()
			confirm.text = "确认"
			confirm.pressed.connect(_on_board_confirm.bind(tid, qid, mat_opt, rel_opt))
			hbox.add_child(confirm)

	_board_feedback = Label.new()
	_board_feedback.add_theme_font_size_override("font_size", 10)
	_board_feedback.add_theme_color_override("font_color", Color(0.9, 0.7, 0.5, 1))
	_board_feedback.text = "用材料回答问题。答对后进度会保留。"
	_content.add_child(_board_feedback)


func _on_board_target_changed(_idx: int) -> void:
	_refresh_content(_tab_bar.current_tab)


func _on_board_material_changed(_idx: int, mat_opt: OptionButton) -> void:
	# 找到关系选项控件（同 HBox 的下一个 OptionButton）。
	var hbox := mat_opt.get_parent() as HBoxContainer
	var rel_opt: OptionButton = null
	for child in hbox.get_children():
		if child is OptionButton and child != mat_opt:
			rel_opt = child
			break
	if rel_opt == null:
		return
	rel_opt.clear()
	rel_opt.add_item("选择关系")
	if mat_opt.selected <= 0:
		return
	var meta = mat_opt.get_item_metadata(mat_opt.selected)
	if meta == null:
		return
	var mid: String = meta
	var tid := Investigation.target_ids()[_board_target.selected]
	for q in Investigation.questions(tid):
		var qid: String = q["id"]
		var mat: Dictionary = Investigation.material(tid, mid)
		if qid in mat.get("answers", []):
			for rel in Investigation.relations(tid, qid):
				rel_opt.add_item(rel["text"])
			break


func _on_board_confirm(tid: String, qid: String, mat_opt: OptionButton, rel_opt: OptionButton) -> void:
	if mat_opt.selected <= 0 or rel_opt.selected <= 0:
		_board_feedback.text = "先选择材料和关系。"
		return
	var material_id: String = mat_opt.get_item_metadata(mat_opt.selected)
	var result := Investigation.answer_question(tid, qid, material_id, rel_opt.selected - 1)
	_board_feedback.text = result["feedback"]
	if result["ok"]:
		_refresh_content(_tab_bar.current_tab)


# ---------------------------------------------------------------- 推理板（E 批：真实拖卡/连线）
func _build_board() -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	_content.add_child(header)

	var target_label := Label.new()
	target_label.text = "推理对象："
	header.add_child(target_label)

	var target_opt := OptionButton.new()
	var ready := Investigation.ready_target_ids()
	for tid in ready:
		target_opt.add_item(Investigation.target_name(tid))
	target_opt.item_selected.connect(_on_board_target_changed_new)
	header.add_child(target_opt)

	_board = InvestigationBoard.new()
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(_board)
	if not ready.is_empty():
		_board.set_target(ready[0])


func _on_board_target_changed_new(idx: int) -> void:
	if _board != null:
		var ready := Investigation.ready_target_ids()
		if idx >= 0 and idx < ready.size():
			_board.set_target(ready[idx])


# ---------------------------------------------------------------- 通用卡片
func _make_card(title: String, body: String) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 3)

	var title_label := Label.new()
	title_label.add_theme_font_size_override("font_size", 11)
	title_label.add_theme_color_override("font_color", Color(0.85, 0.87, 0.92, 1))
	title_label.text = title
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(title_label)

	var body_label := Label.new()
	body_label.add_theme_font_size_override("font_size", 10)
	body_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8, 1))
	body_label.text = body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(body_label)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(0.3, 0.32, 0.38, 1)
	card.add_child(sep)

	return card
