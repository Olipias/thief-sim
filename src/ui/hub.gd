class_name Hub
extends Control
## 据点：关卡选择（任务标签页，卡片显示目标文物 3D 转台）+ 商店标签页。

signal start_requested(level_id: String)
signal quit_requested

const ROWS := ["backpack", "sneakers", "smoke"]
const RELIC_ZOOM := 0.75


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.047, 0.078, 0.094, 0.78)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color("604a28")
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 8.0
	style.content_margin_top = 5.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 5.0
	return style


func _style_panel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", _panel_style())


func _style_button(button: Button, primary := false, font_size := 12) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("d8a84e") if primary else Color(0.063, 0.102, 0.118, 0.82)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color("604a28")
	normal.corner_radius_top_left = 2
	normal.corner_radius_top_right = 2
	normal.corner_radius_bottom_left = 2
	normal.corner_radius_bottom_right = 2
	normal.content_margin_left = 8.0
	normal.content_margin_top = 3.0
	normal.content_margin_right = 8.0
	normal.content_margin_bottom = 3.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("f4d48a") if primary else Color(0.102, 0.165, 0.18, 0.98)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("b88938") if primary else Color("d8a84e")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color("1a120c") if primary else Color("d8a84e"))
	button.add_theme_color_override("font_hover_color", Color("1a120c") if primary else Color("f4d48a"))
	button.add_theme_color_override("font_pressed_color", Color("1a120c"))
	button.add_theme_color_override("font_disabled_color", Color("6a6254"))
	button.add_theme_font_size_override("font_size", font_size)


func _style_static_ui() -> void:
	var tabs: Array[Button] = [tab_levels, tab_shop, tab_sell, tab_reason, sell_all_button]
	for button in tabs:
		_style_button(button)
	var quit: Button = $QuitButton
	_style_button(quit)
	for id in ROWS:
		var row := _row(id)
		_style_panel(row)
		var buy: Button = row.get_node("HBox/Buy")
		_style_button(buy, false, 10)
		var name_label: Label = row.get_node("HBox/Info/Name")
		name_label.add_theme_font_size_override("font_size", 12)
		var desc_label: Label = row.get_node("HBox/Info/Desc")
		desc_label.add_theme_font_size_override("font_size", 9)
		var price_label: Label = row.get_node("HBox/Price")
		price_label.add_theme_font_size_override("font_size", 10)
	var sell_title: Label = $SellBox/SellHeader/SellTitle
	sell_title.add_theme_font_size_override("font_size", 12)
	var sell_total_label: Label = $SellBox/SellHeader/SellTotal
	sell_total_label.add_theme_font_size_override("font_size", 10)
	feedback.add_theme_font_size_override("font_size", 10)
	money_label.add_theme_font_size_override("font_size", 12)
	var hint: Label = $Hint
	hint.add_theme_font_size_override("font_size", 9)

@onready var money_label: Label = $MoneyLabel
@onready var feedback: Label = $Feedback
@onready var levels_box: VBoxContainer = $LevelsBox
@onready var reason_box: VBoxContainer = $ReasonBox
@onready var shop_box: VBoxContainer = $Shop
@onready var sell_box: VBoxContainer = $SellBox
@onready var sell_list: VBoxContainer = $SellBox/SellScroll/SellList
@onready var sell_total: Label = $SellBox/SellHeader/SellTotal
@onready var sell_all_button: Button = $SellBox/SellAll
@onready var tab_levels: Button = $TabLevels
@onready var tab_shop: Button = $TabShop
@onready var tab_sell: Button = $TabSell
@onready var tab_reason: Button = $TabReason
@onready var hint_label: Label = $Hint


func _ready() -> void:
	tab_levels.pressed.connect(func() -> void: _show_tab("levels"))
	tab_shop.pressed.connect(func() -> void: _show_tab("shop"))
	tab_sell.pressed.connect(func() -> void: _show_tab("sell"))
	tab_reason.pressed.connect(func() -> void: _show_tab("reason"))
	sell_all_button.pressed.connect(_on_sell_all)
	$QuitButton.pressed.connect(func() -> void: quit_requested.emit())
	for id in ROWS:
		var button: Button = _row(id).get_node("HBox/Buy")
		button.pressed.connect(_on_buy.bind(id))
	if Game.story_flag("saw_p00"):
		tab_shop.hide()
		tab_sell.hide()
		tab_reason.text = "书桌·电脑"
	_build_level_cards()
	_build_reasoning_ui()
	_refresh()
	_show_tab("levels")
	_style_static_ui()


func _row(id: String) -> PanelContainer:
	return get_node("Shop/Row" + id.capitalize())


func _show_tab(tab: String) -> void:
	levels_box.visible = tab == "levels"
	reason_box.visible = tab == "reason"
	shop_box.visible = tab == "shop"
	sell_box.visible = tab == "sell"
	feedback.visible = tab == "shop" or tab == "reason"
	match tab:
		"levels":
			hint_label.text = "点击卡片开始行动 · 任务详情见手机（P）· 存档自动保存"
		"reason":
			hint_label.text = "收集线索、完成连线，解锁大英博物馆目标"
		"shop":
			hint_label.text = "购买升级 · 金币不足时先去干一票"
		"sell":
			hint_label.text = "选择战利品出手 · 或全部出手"
	tab_levels.button_pressed = tab == "levels"
	tab_shop.button_pressed = tab == "shop"
	tab_sell.button_pressed = tab == "sell"
	tab_reason.button_pressed = tab == "reason"
	if tab == "sell":
		_build_sell_list()
	if tab == "reason":
		_refresh_reasoning()


## 每个关卡一张卡片：目标文物（有 3D 转台条则播放动画）+ 名称/报酬 + 开始按钮。
## 大英博物馆关卡按已解锁目标生成多张卡片（P6）。
func _build_level_cards() -> void:
	for child in levels_box.get_children():
		child.queue_free()

	for level_id in Game.LEVELS:
		var info: Dictionary = Game.LEVELS[level_id]
		if level_id == "british_museum":
			var targets := Game.unlocked_targets()
			if targets.is_empty():
				# 没有解锁目标时显示占位提示，避免玩家困惑。
				var placeholder := _level_placeholder_card("大英博物馆", "先完成推理板上的线索链以解锁目标")
				levels_box.add_child(placeholder)
				continue
			for target_id in targets:
				var card := _build_single_level_card(level_id, info, target_id)
				levels_box.add_child(card)
		else:
			var card := _build_single_level_card(level_id, info, String(info.get("target", "")))
			levels_box.add_child(card)


func _level_placeholder_card(title: String, hint: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 70)
	_style_panel(card)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	card.add_child(hbox)
	var strip := ColorRect.new()
	strip.color = Color("4a4a4a")
	strip.custom_minimum_size = Vector2(3, 0)
	hbox.add_child(strip)
	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 2)
	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color("8a8f9c"))
	info_box.add_child(name_label)
	var hint_label := Label.new()
	hint_label.text = hint
	hint_label.add_theme_font_size_override("font_size", 9)
	hint_label.add_theme_color_override("font_color", Color("6a6a6a"))
	info_box.add_child(hint_label)
	hbox.add_child(info_box)
	return card


func _build_single_level_card(level_id: String, info: Dictionary, target_id: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 70)
	_style_panel(card)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	card.add_child(hbox)

	var strip := ColorRect.new()
	strip.color = Color("a63126")
	strip.custom_minimum_size = Vector2(3, 0)
	hbox.add_child(strip)

	var relic := RelicView.new()
	relic.zoom = RELIC_ZOOM
	relic.set_item(target_id)
	hbox.add_child(relic)

	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 1)
	var name_label := Label.new()
	var display_name := String(info.get("name", level_id))
	if level_id == "british_museum":
		display_name += "·%s" % Game.bm_hall_name(target_id)
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color("f5d766"))
	info_box.add_child(name_label)
	var detail := Label.new()
	detail.text = "目标：%s · 报酬：%d 金币" % [Game.item_name(target_id), int(info.get("reward", 0))]
	detail.add_theme_font_size_override("font_size", 10)
	detail.add_theme_color_override("font_color", Color("c8c2b2"))
	info_box.add_child(detail)
	var hint := Label.new()
	hint.text = "点击卡片开始行动 · 目标文物已归档"
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color("969c96"))
	info_box.add_child(hint)
	hbox.add_child(info_box)

	var start_button := Button.new()
	start_button.text = "开始行动"
	start_button.custom_minimum_size = Vector2(96, 34)
	_style_button(start_button, true, 12)
	start_button.pressed.connect(func() -> void:
		if level_id == "british_museum":
			Game.set_bm_target(target_id)
		start_requested.emit(level_id)
	)
	hbox.add_child(start_button)

	return card


## ---------------------------------------------------------------- 推理板（P3 / P6）

const APP_NAMES := {
	"pc_archive": "电脑·档案库",
	"pc_browser": "电脑·浏览器",
	"pc_mail": "电脑·邮件",
	"phone_chat": "聊天",
	"board": "推理板",
}

const APP_ORDER: Array[String] = ["pc_archive", "pc_browser", "pc_mail", "phone_chat", "board"]

var search_field: LineEdit
var archive_filter: OptionButton
var detail_filter: OptionButton
var evidence_board: EvidenceBoard
var _reason_source_hbox: HBoxContainer
var _clues_scroll: ScrollContainer
var _reason_clues_list: VBoxContainer
var _reason_chains_list: HBoxContainer
var _reason_feedback: Label
var _selected_app: String = "pc_archive"


func _build_reasoning_ui() -> void:
	for child in reason_box.get_children():
		child.queue_free()

	_reason_source_hbox = HBoxContainer.new()
	_reason_source_hbox.add_theme_constant_override("separation", 6)
	reason_box.add_child(_reason_source_hbox)

	for app_id in APP_ORDER:
		var btn := Button.new()
		btn.text = APP_NAMES.get(app_id, app_id)
		btn.toggle_mode = true
		btn.button_group = ButtonGroup.new()
		btn.pressed.connect(_on_reason_app_selected.bind(app_id))
		_style_button(btn, false, 10)
		_reason_source_hbox.add_child(btn)
		if app_id == _selected_app:
			btn.button_pressed = true

	var tools_row := HBoxContainer.new()
	reason_box.add_child(tools_row)
	search_field = LineEdit.new()
	search_field.placeholder_text = "搜索编号、人名、关键词（回车检索）"
	search_field.custom_minimum_size = Vector2(340, 22)
	search_field.add_theme_font_size_override("font_size", 10)
	tools_row.add_child(search_field)
	search_field.text_submitted.connect(func(_query: String) -> void: _refresh_reasoning())
	archive_filter = OptionButton.new()
	for title in ["全部展厅", "中国厅", "埃及厅", "希腊厅"]:
		archive_filter.add_item(title)
	archive_filter.add_theme_font_size_override("font_size", 10)
	tools_row.add_child(archive_filter)
	archive_filter.item_selected.connect(func(_index: int) -> void: _refresh_reasoning())
	detail_filter = OptionButton.new()
	for title in ["全部年代/来源", "商代 / 旧藏购入", "埃及晚期 / 古尔德", "晚期基克拉泽斯 / 西屋"]:
		detail_filter.add_item(title)
	detail_filter.add_theme_font_size_override("font_size", 9)
	tools_row.add_child(detail_filter)
	detail_filter.item_selected.connect(func(_index: int) -> void: _refresh_reasoning())
	evidence_board = EvidenceBoard.new()
	reason_box.add_child(evidence_board)
	evidence_board.changed.connect(func() -> void:
		_build_level_cards()
		for child in _reason_chains_list.get_children():
			child.queue_free()
		for cid in EvidenceData.chain_ids():
			_reason_chains_list.add_child(_make_chain_row(cid))
	)
	var clues_scroll := ScrollContainer.new()
	_clues_scroll = clues_scroll
	clues_scroll.custom_minimum_size = Vector2(0, 160)
	reason_box.add_child(clues_scroll)
	_reason_clues_list = VBoxContainer.new()
	_reason_clues_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reason_clues_list.add_theme_constant_override("separation", 4)
	clues_scroll.add_child(_reason_clues_list)

	var sep := ColorRect.new()
	sep.color = Color("604a28")
	sep.custom_minimum_size = Vector2(0, 1)
	reason_box.add_child(sep)

	_reason_chains_list = HBoxContainer.new()
	_reason_chains_list.add_theme_constant_override("separation", 6)
	reason_box.add_child(_reason_chains_list)

	_reason_feedback = Label.new()
	_reason_feedback.add_theme_font_size_override("font_size", 10)
	_reason_feedback.add_theme_color_override("font_color", Color("d8cfb8"))
	reason_box.add_child(_reason_feedback)


func _on_reason_app_selected(app_id: String) -> void:
	_selected_app = app_id
	_refresh_reasoning()


func _refresh_reasoning() -> void:
	evidence_board.visible = _selected_app == "board"
	_reason_chains_list.visible = _selected_app == "board"
	_clues_scroll.visible = _selected_app != "board"
	evidence_board.refresh()
	# 刷新来源按钮按下状态
	for i in _reason_source_hbox.get_child_count():
		var btn: Button = _reason_source_hbox.get_child(i) as Button
		if btn == null:
			continue
		var app_id := APP_ORDER[i]
		btn.button_pressed = app_id == _selected_app

	# 刷新线索列表
	for child in _reason_clues_list.get_children():
		child.queue_free()
	search_field.visible = _selected_app == "pc_browser"
	archive_filter.visible = _selected_app == "pc_archive"
	detail_filter.visible = _selected_app == "pc_archive"
	var clues := EvidenceData.clues_for_app(_selected_app)
	if _selected_app == "pc_browser":
		var query := search_field.text.strip_edges().to_lower()
		clues = clues.filter(func(clue: Dictionary) -> bool:
			var chain: Dictionary = EvidenceData.chain(clue.chain_id)
			return not query.is_empty() and (str(chain).to_lower().contains(query))
		)
	if _selected_app == "pc_archive" and archive_filter.selected > 0:
		var selected_id := EvidenceData.chain_ids()[archive_filter.selected - 1]
		clues = clues.filter(func(clue: Dictionary) -> bool: return clue.chain_id == selected_id)

	if _selected_app == "pc_archive" and detail_filter.selected > 0:
		var detail_id := EvidenceData.chain_ids()[detail_filter.selected - 1]
		clues = clues.filter(func(clue: Dictionary) -> bool: return clue.chain_id == detail_id)
	if _selected_app == "pc_mail":
		for i in 3:
			var cid := EvidenceData.chain_ids()[i]
			var sender: String = ["中国追索者", "埃及裔学者", "希腊文化基金会"][i]
			var mail := Label.new()
			mail.text = sender + "：若你带回" + Game.item_name(cid) + "，请先联系我。渠道与委托均为虚构。"
			mail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			mail.custom_minimum_size.x = 520
			mail.add_theme_font_size_override("font_size", 10)
			_reason_clues_list.add_child(mail)
			var reply := Button.new()
			reply.text = "已回复：愿意接洽" if Game.story_flag("mail_contact_" + cid) else "回复：愿意接洽 / 不回复则保留邮件"
			reply.add_theme_font_size_override("font_size", 10)
			reply.pressed.connect(func() -> void:
				Game.set_story_flag("mail_contact_" + cid)
				_refresh_reasoning()
			)
			_reason_clues_list.add_child(reply)
	if _selected_app == "phone_chat":
		var chat := Label.new()
		chat.text = "恶魔：" + ("东西带回来了？别让我等。" if Game.story_flag("bm_relic_secured") else "我要的不是最贵的那件。看看编号背后的故事。")
		chat.add_theme_font_size_override("font_size", 11)
		_reason_clues_list.add_child(chat)
	if clues.is_empty():
		var empty := Label.new()
		empty.text = "该来源暂时没有可访问线索。"
		empty.add_theme_font_size_override("font_size", 9)
		empty.add_theme_color_override("font_color", Color("8a8f9c"))
		_reason_clues_list.add_child(empty)
	else:
		for clue in clues:
			_reason_clues_list.add_child(_make_clue_row(clue))

	# 刷新推理链状态
	for child in _reason_chains_list.get_children():
		child.queue_free()
	for chain_id in EvidenceData.chain_ids():
		_reason_chains_list.add_child(_make_chain_row(chain_id))


func _make_clue_row(clue: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	_style_panel(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)

	var collected := Game.has_clue(String(clue.get("id", "")))
	var title := Label.new()
	title.text = String(clue.get("title", ""))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color("f5d766") if collected else Color("8a8f9c"))
	row.add_child(title)

	if collected:
		var badge := Label.new()
		badge.text = "已收集"
		badge.add_theme_font_size_override("font_size", 9)
		badge.add_theme_color_override("font_color", Color("7fd18f"))
		row.add_child(badge)
	else:
		var btn := Button.new()
		btn.text = "收集"
		btn.custom_minimum_size = Vector2(56, 22)
		_style_button(btn, false, 9)
		btn.pressed.connect(func() -> void:
			Game.collect_clue(String(clue.get("id", "")))
			_refresh_reasoning()
			_build_level_cards()
		)
		row.add_child(btn)

	if _selected_app == "pc_mail":
		var reply := Button.new()
		reply.text = "已回复" if Game.story_flag("reply_" + String(clue.id)) else "回复：愿意接洽（虚构渠道）"
		reply.add_theme_font_size_override("font_size", 9)
		reply.pressed.connect(func() -> void:
			Game.set_story_flag("reply_" + String(clue.id))
			_refresh_reasoning()
		)
		vbox.add_child(reply)
	var body := Label.new()
	body.text = String(clue.get("body", "")) + ("\n来源字段：有争议 / 追索中；早期流转记录不完整。" if _selected_app == "pc_archive" else "\n安保、排期及交易渠道为游戏虚构。") if collected else "收集后查看详情"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 9)
	body.add_theme_color_override("font_color", Color("b8c4d4") if collected else Color("5a6270"))
	vbox.add_child(body)

	return panel


func _make_chain_row(chain_id: String) -> PanelContainer:
	var chain: Dictionary = EvidenceData.chain(chain_id)
	var panel := PanelContainer.new()
	_style_panel(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = String(chain.get("title", chain_id))
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color("f5d766"))
	vbox.add_child(title)

	var all_collected := true
	for clue in Game.clues_for_chain(chain_id):
		if not clue.collected:
			all_collected = false
	var links_done := false
	if Game.chain_unlocked(chain_id):
		var unlocked := Label.new()
		unlocked.text = "已解锁盗取方案"
		unlocked.add_theme_font_size_override("font_size", 9)
		unlocked.add_theme_color_override("font_color", Color("7fd18f"))
		vbox.add_child(unlocked)
	elif all_collected:
		var verify := Button.new()
		verify.text = "验证连线"
		verify.custom_minimum_size = Vector2(80, 22)
		_style_button(verify, links_done, 9)
		verify.pressed.connect(func() -> void:
			if Game.verify_chain(chain_id):
				_reason_feedback.text = "%s 解锁成功" % String(chain.get("title", chain_id))
				_refresh_reasoning()
				_build_level_cards()
			else:
				_reason_feedback.text = "线索或连线不足，无法解锁"
		)
		vbox.add_child(verify)

	return panel


func _refresh() -> void:
	money_label.text = "金币 %d" % Game.money
	for id in ROWS:
		_setup_row(id)
	_build_sell_list()


## 销赃页：列出据点仓库里的战利品，逐件或一次性出手。
func _build_sell_list() -> void:
	for child in sell_list.get_children():
		child.queue_free()
	sell_total.text = "估值 %d 金币" % Game.stash_value()
	sell_all_button.disabled = Game.loot_stash.is_empty()
	if Game.loot_stash.is_empty():
		var empty_panel := PanelContainer.new()
		_style_panel(empty_panel)
		var empty := Label.new()
		empty.text = "仓库里还没有战利品。成功撤离并带回文物后，会存放在这里。"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 10)
		empty.add_theme_color_override("font_color", Color("8a8f9c"))
		empty_panel.add_child(empty)
		sell_list.add_child(empty_panel)
		return
	for i in Game.loot_stash.size():
		var id := String(Game.loot_stash[i])
		var panel := PanelContainer.new()
		_style_panel(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_label := Label.new()
		name_label.text = Game.item_name(id)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 11)
		row.add_child(name_label)
		var value_label := Label.new()
		value_label.text = "%d 金币" % Game.item_value(id)
		value_label.custom_minimum_size = Vector2(90, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_color_override("font_color", Color("f5d766"))
		value_label.add_theme_font_size_override("font_size", 10)
		row.add_child(value_label)
		var button := Button.new()
		button.text = "卖出"
		button.custom_minimum_size = Vector2(64, 26)
		_style_button(button, false, 10)
		button.pressed.connect(_on_sell.bind(i))
		row.add_child(button)
		panel.add_child(row)
		sell_list.add_child(panel)


func _on_sell(index: int) -> void:
	var id := String(Game.loot_stash[index]) if index < Game.loot_stash.size() else ""
	var value := Game.sell_stash_item(index)
	if value > 0:
		Audio.play("coin", -7.0)
		feedback.text = "已卖出：%s（+%d 金币）" % [Game.item_name(id), value]
		_refresh()


func _on_sell_all() -> void:
	var total := Game.sell_all_stash()
	if total > 0:
		Audio.play("coin", -7.0)
		feedback.text = "全部出手：+%d 金币" % total
		_refresh()


func _setup_row(id: String) -> void:
	var info: Dictionary = Game.UPGRADES[id]
	var row := _row(id)
	var status := ""
	match id:
		"backpack":
			var size := Game.bag_cells()
			status = "（%d×%d 格）" % [size.x, size.y]
		"sneakers":
			status = "（已拥有）" if Game.has_sneakers else ""
		"smoke":
			status = "（持有 x%d）" % Game.smoke_count
	row.get_node("HBox/Info/Name").text = String(info["name"])
	row.get_node("HBox/Info/Desc").text = String(info["desc"]) + status
	var price_label: Label = row.get_node("HBox/Price")
	var button: Button = row.get_node("HBox/Buy")
	if Game.is_sold_out(id):
		price_label.text = "——"
		button.text = "已满级" if id != "sneakers" else "已拥有"
		button.disabled = true
		return
	var price := Game.upgrade_price(id)
	price_label.text = "%d 金币" % price
	button.text = "购买"
	button.disabled = Game.money < price


func _on_buy(id: String) -> void:
	var info: Dictionary = Game.UPGRADES[id]
	if Game.buy(id):
		Audio.play("coin", -7.0)
		feedback.text = "已购买：%s（余 %d 金币）" % [info["name"], Game.money]
	else:
		Audio.play("denied", -8.0)
		feedback.text = "金币不足，先去干一票吧。"
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and levels_box.visible:
		var first_level := String(Game.LEVELS.keys()[0])
		start_requested.emit(first_level)
		get_viewport().set_input_as_handled()
