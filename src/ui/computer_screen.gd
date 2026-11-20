class_name ComputerScreen
extends CanvasLayer
## 书桌电脑覆盖层（R-01 骨架）：从房内书桌进入，关闭后回桌旁。
## 浏览器/档案库/邮件/聊天/推理板的完整调查界面在后续批次接入（R-03/R-04/E 批）。
## 覆盖层契约与背包/手机一致：open ⇔ 暂停（暂停由 Main 控制），P/B/ESC 关闭。

signal closed

@onready var mission_label: Label = $Root/Panel/Margin/VBox/Body/MissionLabel
@onready var targets_label: Label = $Root/Panel/Margin/VBox/Body/TargetsLabel
@onready var hint_label: Label = $Root/Panel/Margin/VBox/Body/HintLabel


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


func _refresh() -> void:
	mission_label.text = "当前行动：%s（目标 %s）" % [
		Game.level_name(), Game.item_name(Game.mission_target_id),
	]
	var lines := ""
	for id in ["ram_zun", "egypt_heart_scarab", "akrotiri_askos"]:
		lines += "· %s\n" % Game.item_name(id)
	targets_label.text = lines.trim_suffix("\n") if lines != "" else ""
	hint_label.text = "浏览器 / 档案库 / 邮件 / 聊天 / 推理板将在下一批接入。\nP / B / ESC 关闭，回到桌旁。"
