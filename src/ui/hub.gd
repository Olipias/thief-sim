class_name Hub
extends Control
## 据点：关卡选择（任务标签页，卡片显示目标文物 3D 转台）+ 商店标签页。

signal start_requested(level_id: String)
signal quit_requested

const ROWS := ["backpack", "sneakers", "smoke"]
const RELIC_ZOOM := 0.75

@onready var money_label: Label = $MoneyLabel
@onready var feedback: Label = $Feedback
@onready var levels_box: VBoxContainer = $LevelsBox
@onready var shop_box: VBoxContainer = $Shop
@onready var tab_levels: Button = $TabLevels
@onready var tab_shop: Button = $TabShop


func _ready() -> void:
	tab_levels.pressed.connect(func() -> void: _show_tab("levels"))
	tab_shop.pressed.connect(func() -> void: _show_tab("shop"))
	$QuitButton.pressed.connect(func() -> void: quit_requested.emit())
	for id in ROWS:
		var button: Button = _row(id).get_node("HBox/Buy")
		button.pressed.connect(_on_buy.bind(id))
	_build_level_cards()
	_refresh()
	_show_tab("levels")


func _row(id: String) -> PanelContainer:
	return get_node("Shop/Row" + id.capitalize())


func _show_tab(tab: String) -> void:
	var levels_active := tab == "levels"
	levels_box.visible = levels_active
	feedback.visible = not levels_active
	shop_box.visible = not levels_active
	tab_levels.button_pressed = levels_active
	tab_shop.button_pressed = not levels_active


## 每个关卡一张卡片：目标文物（有 3D 转台条则播放动画）+ 名称/报酬 + 开始按钮。
func _build_level_cards() -> void:
	for child in levels_box.get_children():
		child.queue_free()
	for level_id in Game.LEVELS:
		var info: Dictionary = Game.LEVELS[level_id]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 66)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		card.add_child(hbox)

		var relic := RelicView.new()
		relic.zoom = RELIC_ZOOM
		relic.set_item(String(info.get("target", "")))
		hbox.add_child(relic)

		var info_box := VBoxContainer.new()
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := Label.new()
		name_label.text = String(info.get("name", level_id))
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", Color("f5d766"))
		info_box.add_child(name_label)
		var target := String(info.get("target", ""))
		var detail := Label.new()
		detail.text = "目标：%s · 报酬：%d 金币" % [Game.item_name(target), int(info.get("reward", 0))]
		detail.add_theme_color_override("font_color", Color("9fa6b4"))
		info_box.add_child(detail)
		hbox.add_child(info_box)

		var start_button := Button.new()
		start_button.text = "开始行动"
		start_button.custom_minimum_size = Vector2(96, 0)
		start_button.pressed.connect(func() -> void: start_requested.emit(level_id))
		hbox.add_child(start_button)

		levels_box.add_child(card)


func _refresh() -> void:
	money_label.text = "金币 %d" % Game.money
	for id in ROWS:
		_setup_row(id)


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
