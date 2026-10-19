class_name Hud
extends CanvasLayer
## In-game overlay: mission, money, backpack, prompts and toasts.

signal phone_requested

@onready var root: Control = $Root
@onready var mission_label: Label = $Root/MissionLabel
@onready var minimap: Minimap = $Root/Minimap
@onready var money_label: Label = $Root/MoneyLabel
@onready var bag_label: Label = $Root/BagLabel
@onready var item_label: Label = $Root/ItemLabel
@onready var prompt_label: Label = $Root/PromptLabel
@onready var toast_label: Label = $Root/ToastLabel
@onready var alert_label: Label = $Root/AlertLabel

var _toast_seq := 0


func _ready() -> void:
	Game.backpack_changed.connect(refresh_backpack)
	Game.money_changed.connect(refresh_money)
	Game.items_changed.connect(refresh_items)
	$Root/PhoneButton.pressed.connect(func() -> void: phone_requested.emit())
	refresh_backpack()
	refresh_money()
	refresh_items()
	set_alert(0)
	set_prompt("")


func show_hud() -> void:
	root.visible = true
	refresh_backpack()
	refresh_money()
	refresh_items()


func hide_hud() -> void:
	root.visible = false


func set_mission_target(target_name: String) -> void:
	mission_label.text = "任务目标：%s" % target_name


## Show the room layout of the active level on the minimap.
func bind_level(level: Museum) -> void:
	minimap.bind(level)


func unbind_level() -> void:
	minimap.bind(null)


func refresh_money() -> void:
	money_label.text = "金币 %d" % Game.money


func refresh_backpack() -> void:
	var names: Array[String] = []
	for item in Game.bag_items:
		names.append(Game.item_name(String(item["id"])))
	var carried := "、".join(names) if not names.is_empty() else "空"
	bag_label.text = "背包 %d/%d格：%s（B 整理）" % [
		Game.bag_used_cells(),
		Game.bag_capacity_cells(),
		carried,
	]


func refresh_items() -> void:
	item_label.text = "烟雾弹 x%d（Q 使用）" % Game.smoke_count


func set_prompt(artifact_name: String) -> void:
	prompt_label.text = "" if artifact_name.is_empty() else "按 E 拾取：%s" % artifact_name


func set_alert(level: int) -> void:
	alert_label.visible = level > 0
	if level >= 2:
		alert_label.text = "！被警察发现了 ！"
		alert_label.add_theme_color_override("font_color", Color("ff5247"))
	elif level == 1:
		alert_label.text = "？附近有警察警觉了…"
		alert_label.add_theme_color_override("font_color", Color("ffd75e"))


## Hide the bottom status rows, e.g. while a dialogue box is open.
func set_compact(compact: bool) -> void:
	item_label.visible = not compact
	bag_label.visible = not compact


func toast(text: String, seconds := 3.5) -> void:
	_toast_seq += 1
	var seq := _toast_seq
	toast_label.text = text
	toast_label.visible = true
	await get_tree().create_timer(seconds).timeout
	if seq == _toast_seq:
		toast_label.visible = false
