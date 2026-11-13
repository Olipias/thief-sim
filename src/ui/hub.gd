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
	var tabs: Array[Button] = [tab_levels, tab_shop, tab_sell, sell_all_button]
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
@onready var shop_box: VBoxContainer = $Shop
@onready var sell_box: VBoxContainer = $SellBox
@onready var sell_list: VBoxContainer = $SellBox/SellScroll/SellList
@onready var sell_total: Label = $SellBox/SellHeader/SellTotal
@onready var sell_all_button: Button = $SellBox/SellAll
@onready var tab_levels: Button = $TabLevels
@onready var tab_shop: Button = $TabShop
@onready var tab_sell: Button = $TabSell
@onready var hint_label: Label = $Hint


func _ready() -> void:
	tab_levels.pressed.connect(func() -> void: _show_tab("levels"))
	tab_shop.pressed.connect(func() -> void: _show_tab("shop"))
	tab_sell.pressed.connect(func() -> void: _show_tab("sell"))
	sell_all_button.pressed.connect(_on_sell_all)
	$QuitButton.pressed.connect(func() -> void: quit_requested.emit())
	for id in ROWS:
		var button: Button = _row(id).get_node("HBox/Buy")
		button.pressed.connect(_on_buy.bind(id))
	_build_level_cards()
	_refresh()
	_show_tab("levels")
	_style_static_ui()


func _row(id: String) -> PanelContainer:
	return get_node("Shop/Row" + id.capitalize())


func _show_tab(tab: String) -> void:
	levels_box.visible = tab == "levels"
	shop_box.visible = tab == "shop"
	sell_box.visible = tab == "sell"
	feedback.visible = tab == "shop"
	match tab:
		"levels":
			hint_label.text = "点击卡片开始行动 · 任务详情见手机（P）· 存档自动保存"
		"shop":
			hint_label.text = "购买升级 · 金币不足时先去干一票"
		"sell":
			hint_label.text = "选择战利品出手 · 或全部出手"
	tab_levels.button_pressed = tab == "levels"
	tab_shop.button_pressed = tab == "shop"
	tab_sell.button_pressed = tab == "sell"
	if tab == "sell":
		_build_sell_list()


## 每个关卡一张卡片：目标文物（有 3D 转台条则播放动画）+ 名称/报酬 + 开始按钮。
func _build_level_cards() -> void:
	for child in levels_box.get_children():
		child.queue_free()
	for level_id in Game.LEVELS:
		var info: Dictionary = Game.LEVELS[level_id]
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
		relic.set_item(String(info.get("target", "")))
		hbox.add_child(relic)

		var info_box := VBoxContainer.new()
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_box.add_theme_constant_override("separation", 1)
		var name_label := Label.new()
		name_label.text = String(info.get("name", level_id))
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", Color("f5d766"))
		info_box.add_child(name_label)
		var target := String(info.get("target", ""))
		var detail := Label.new()
		detail.text = "目标：%s · 报酬：%d 金币" % [Game.item_name(target), int(info.get("reward", 0))]
		detail.add_theme_font_size_override("font_size", 10)
		detail.add_theme_color_override("font_color", Color("c8c2b2"))
		info_box.add_child(detail)
		var hint := Label.new()
		hint.text = "点击卡片查看任务 · 目标文物已归档"
		hint.add_theme_font_size_override("font_size", 8)
		hint.add_theme_color_override("font_color", Color("969c96"))
		info_box.add_child(hint)
		hbox.add_child(info_box)

		var start_button := Button.new()
		start_button.text = "开始行动"
		start_button.custom_minimum_size = Vector2(96, 34)
		_style_button(start_button, true, 12)
		start_button.pressed.connect(func() -> void: start_requested.emit(level_id))
		hbox.add_child(start_button)

		levels_box.add_child(card)


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
	if event.is_action_pressed("interact"):
		var first_level := String(Game.LEVELS.keys()[0])
		start_requested.emit(first_level)
		get_viewport().set_input_as_handled()
