class_name BoxScreen
extends CanvasLayer
## 文物箱覆盖层（R-01 骨架）：左右分别是「随身携带」与「箱内存放」。
## 存取转移与手机预约交易在 R-05 接入；当前箱内普通战利品暂可直售，
## 保持经济闭环可用（旧据点「销赃」页的过渡替代，接入手机交易后移除）。
## 覆盖层契约与背包/手机一致：open ⇔ 暂停（暂停由 Main 控制），P/B/ESC 关闭。

signal closed
signal sold(item_id: String, price: int)

@onready var bag_list: VBoxContainer = $Root/Panel/Margin/VBox/Body/Columns/BagColumn/BagList
@onready var stash_list: VBoxContainer = $Root/Panel/Margin/VBox/Body/Columns/StashColumn/StashList
@onready var money_label: Label = $Root/Panel/Margin/VBox/Header/Money
@onready var message_label: Label = $Root/Panel/Margin/VBox/Message


func _ready() -> void:
	visible = false


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


func _row_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(48, 20)
	btn.add_theme_stylebox_override("normal", _button_style())
	btn.add_theme_stylebox_override("hover", _button_style(Color(0.30, 0.34, 0.44)))
	btn.add_theme_stylebox_override("pressed", _button_style(Color(0.38, 0.42, 0.54)))
	return btn


func _button_style(bg := Color(0.20, 0.23, 0.31)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


func _row_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(104, 0)
	return label


func _refresh() -> void:
	money_label.text = "金币 %d" % Game.money
	message_label.text = ""
	for child in bag_list.get_children():
		child.queue_free()
	for child in stash_list.get_children():
		child.queue_free()

	if Game.bag_items.is_empty():
		bag_list.add_child(_row_label("（空）"))
	else:
		for item in Game.bag_items:
			var id := String(item["id"])
			bag_list.add_child(_row_label("%s（随身）" % Game.item_name(id)))
	if Game.loot_stash.is_empty():
		stash_list.add_child(_row_label("（空）"))
	else:
		for i in Game.loot_stash.size():
			var id := String(Game.loot_stash[i])
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			row.add_child(_row_label("%s %d金" % [Game.item_name(id), Game.item_value(id)]))
			var sell := _row_button("卖出")
			sell.pressed.connect(_on_sell_pressed.bind(i))
			row.add_child(sell)
			stash_list.add_child(row)


## 过渡行为：箱内普通战利品直售；R-05 手机预约→门口交货接入后移除。
func _on_sell_pressed(index: int) -> void:
	if index < 0 or index >= Game.loot_stash.size():
		return
	var id := String(Game.loot_stash[index])
	var price: int = Game.sell_stash_item(index)
	sold.emit(id, price)
	message_label.text = "已卖出 %s，+%d 金币" % [Game.item_name(id), price]
	_refresh()
