class_name ResultScreen
extends Control
## Post-heist summary: success or busted.

signal continue_requested

@onready var title_label: Label = $Title
@onready var body_label: Label = $Body
@onready var money_label: Label = $Money
@onready var continue_button: Button = $ContinueButton


func _ready() -> void:
	continue_button.pressed.connect(func() -> void: continue_requested.emit())


func setup(summary: Dictionary) -> void:
	if bool(summary.get("success", false)):
		title_label.text = "行动成功"
		title_label.add_theme_color_override("font_color", Color("7fd18f"))
		var lines: Array[String] = []
		lines.append("已上交任务目标：%s" % summary["target_name"])
		var sold: Array = summary["sold_items"]
		if sold.is_empty():
			lines.append("这次没有带出额外文物。")
		else:
			for item in sold:
				lines.append("· 卖出 %s  +%d 金币" % [item["name"], item["value"]])
			lines.append("额外战利品合计：+%d 金币" % summary["sold_value"])
		lines.append("组织报酬：+%d 金币" % summary["reward"])
		body_label.text = "\n".join(lines)
	else:
		title_label.text = "被逮捕了"
		title_label.add_theme_color_override("font_color", Color("e86a6a"))
		body_label.text = "这一局到此为止，赃物被没收。\n下次行动，留意警察的视野和脚步。"
	money_label.text = "当前金币：%d" % summary["money_total"]
	continue_button.grab_focus()
