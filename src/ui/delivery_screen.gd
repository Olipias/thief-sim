class_name DeliveryScreen
extends CanvasLayer
## R-05 门口交货确认：展示随身预约货清单与总金额，玩家确认后一次性结算。
## 覆盖层契约同背包/手机：open ⇔ 暂停（暂停由 Main 控制），P/B/ESC 关闭。
## 重复确认不会重复收款：结算后随身预约货清空，面板随之刷新为空态。

signal closed
signal confirm_requested

@onready var items_label: Label = $Root/Panel/Margin/VBox/Body/Items
@onready var total_label: Label = $Root/Panel/Margin/VBox/Body/Total
@onready var confirm_button: Button = $Root/Panel/Margin/VBox/Body/Buttons/Confirm
@onready var cancel_button: Button = $Root/Panel/Margin/VBox/Body/Buttons/Cancel

var _goods: Array[Dictionary] = []


func _ready() -> void:
	visible = false
	confirm_button.pressed.connect(func() -> void: confirm_requested.emit())
	cancel_button.pressed.connect(close)


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


func _refresh() -> void:
	_goods = Game.reserved_bag_items()
	if _goods.is_empty():
		items_label.text = "身上没有待交货的预约物。"
		total_label.text = "—"
		confirm_button.visible = false
		return
	confirm_button.visible = true
	var lines := ""
	var total := 0
	for goods in _goods:
		var id := String(goods["id"])
		lines += "· %s    %d 金币\n" % [Game.item_name(id), int(goods["value"])]
		total += int(goods["value"])
	items_label.text = lines.trim_suffix("\n")
	total_label.text = "合计 %d 金币" % total
