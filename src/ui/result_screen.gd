class_name ResultScreen
extends Control
## Post-heist summary: success or busted.
## 成功撤离：组织报酬自动入账；带出的战利品不自动出售，存入据点仓库由玩家决定。

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
		lines.append("组织报酬：+%d 金币" % summary["reward"])
		var stash: Array = summary.get("stash_items", [])
		if stash.is_empty():
			lines.append("这次没有多带东西。")
		else:
			lines.append("带出的战利品已存入据点仓库：")
			for item in stash:
				lines.append("· %s（估值 %d 金币）" % [item["name"], item["value"]])
			lines.append("回据点后在「销赃」页自行决定是否出手。")
		body_label.text = "\n".join(lines)
	else:
		title_label.text = "被逮捕了"
		title_label.add_theme_color_override("font_color", Color("e86a6a"))
		body_label.text = "这一局到此为止，赃物被没收。\n下次行动，留意警察的视野和脚步。"
	money_label.text = "当前金币：%d" % summary["money_total"]
	continue_button.grab_focus()
