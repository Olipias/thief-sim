class_name MissionPhone
extends CanvasLayer
## 任务终端（手机）：右下角图标点开。
## 「任务」页展示任务发布（含目标文物 3D 转台）；「档案」页可端详随身文物
## （特写热点 + 展签卡，见文物志预案 A/B）。

signal closed
signal card_requested(item_id: String, card_id: String)

@onready var dim: ColorRect = $Root/Dim
@onready var panel: PanelContainer = $Root/Panel
@onready var task_page: VBoxContainer = $Root/Panel/Margin/VBox/TaskPage
@onready var archive_page: HBoxContainer = $Root/Panel/Margin/VBox/ArchivePage
@onready var tab_task: Button = $Root/Panel/Margin/VBox/Header/TabTask
@onready var tab_archive: Button = $Root/Panel/Margin/VBox/Header/TabArchive
@onready var item_list: VBoxContainer = $Root/Panel/Margin/VBox/ArchivePage/ItemList
@onready var inspect: InspectPage = $Root/Panel/Margin/VBox/ArchivePage/Inspect
@onready var relic: RelicView = $Root/Panel/Margin/VBox/TaskPage/Body/RelicCard/Relic
@onready var target_label: Label = $Root/Panel/Margin/VBox/TaskPage/Body/Info/TargetName
@onready var meta_label: Label = $Root/Panel/Margin/VBox/TaskPage/Body/Info/Meta
@onready var story_label: Label = $Root/Panel/Margin/VBox/TaskPage/Body/Info/Story
@onready var archive_card: PanelContainer = $Root/Panel/Margin/VBox/TaskPage/Body/Info/ArchiveCard
@onready var archive_label: Label = $Root/Panel/Margin/VBox/TaskPage/Body/Info/ArchiveCard/Archive
@onready var notes_label: Label = $Root/Panel/Margin/VBox/TaskPage/Body/Info/Notes
@onready var footer_label: Label = $Root/Panel/Margin/VBox/Footer

var extra_page: VBoxContainer
var call_label: Label
var _item_ids: Array[String] = []
var _hub_mode := false


func _ready() -> void:
	visible = false
	extra_page = VBoxContainer.new()
	$Root/Panel/Margin/VBox.add_child(extra_page)
	for title in ["日历", "通讯录"]:
		var button := Button.new()
		button.text = title
		button.add_theme_font_size_override("font_size", 10)
		$Root/Panel/Margin/VBox/Header.add_child(button)
		button.pressed.connect(_show_tab.bind(title))
	dim.gui_input.connect(_on_dim_input)
	tab_task.pressed.connect(func() -> void: _show_tab("task"))
	tab_archive.pressed.connect(func() -> void: _show_tab("archive"))
	inspect.card_requested.connect(func(item_id: String, card_id: String) -> void:
		card_requested.emit(item_id, card_id)
	)


func is_open() -> bool:
	return visible


func open(hub_mode := false) -> void:
	if visible:
		return
	_hub_mode = hub_mode
	tab_archive.visible = not _hub_mode
	footer_label.text = "任务 · P / B / ESC 关闭" if _hub_mode else "任务 / 档案 · P / B / ESC 关闭"
	_fill_task()
	_fill_archive()
	visible = true
	_show_tab("task")


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _show_tab(tab: String) -> void:
	task_page.visible = tab == "task"
	archive_page.visible = tab == "archive"
	extra_page.visible = tab == "日历" or tab == "通讯录"
	tab_task.button_pressed = tab == "task"
	tab_archive.button_pressed = tab == "archive"
	for child in extra_page.get_children():
		child.queue_free()
	if tab == "日历":
		var label := Label.new()
		label.text = "行动周历（游戏虚构排期）\n周一：中国厅闭馆维护 · 编号 1936,1118.1\n周三：埃及廊通风检修 · 10.130.1650\n周五：希腊厅激光清洗 · VM-GR-25-012\n记录时间线：1910 圣甲虫捐赠 → 1936 双羊尊入藏\n排期可作为浏览器检索入口；并非真实馆方日程。"
		label.add_theme_font_size_override("font_size", 11)
		extra_page.add_child(label)
	if tab == "通讯录":
		for contact in ["恶魔", "老猫", "中国追索者", "埃及裔学者", "希腊文化基金会"]:
			var button := Button.new()
			button.text = "接听来电：" + contact
			button.add_theme_font_size_override("font_size", 10)
			extra_page.add_child(button)
			button.pressed.connect(func() -> void:
				Game.set_story_flag("contact_" + contact)
				call_label.text = contact + "（虚构人物）\n" + ("我要充满怨恨风味的旧物。查清来源再动手。" if contact == "恶魔" else "先查编号与来源，再比对维修排期。邮件可留下接洽记录。")
				for clue in EvidenceData.clues_for_app("phone_chat"):
					if (contact == "老猫" and clue.id == "zun_chat") or (contact == "希腊文化基金会" and clue.id == "askos_chat"):
						Game.collect_clue(clue.id)
			)
		call_label = Label.new()
		call_label.text = "选择来电查看对话。人物与联络渠道均为虚构。"
		call_label.add_theme_font_size_override("font_size", 10)
		extra_page.add_child(call_label)


func _fill_task() -> void:
	var info := Game.level_info()
	var target_id := Game.mission_target_id
	target_label.text = Game.item_name(target_id)
	var location := Game.level_name()
	if Game.current_level_id == "british_museum":
		location += "·%s" % Game.bm_hall_name(target_id)
	meta_label.text = "行动地点：%s\n委托人：老猫 · 报酬：%d 金币" % [
		location,
		int(info.get("reward", 0)),
	]
	story_label.text = Game.item_story(target_id)
	var archive: Dictionary = Game.ARCHIVE.get(target_id, {})
	archive_card.visible = not archive.is_empty()
	if not archive.is_empty():
		archive_label.text = "文物档案 · %s · %s\n现藏：%s\n流转：%s\n备注：%s" % [
			String(archive.get("era", "")),
			String(archive.get("origin", "")),
			String(archive.get("collection", "")),
			String(archive.get("provenance", "")),
			String(archive.get("legend", "")),
		]
	notes_label.text = "恶魔：我要充满怨恨风味的旧物。\n规划（Tab）可看清守卫路线与监控扇区；\n一次一件；得手后前往出口撤离。"
	relic.zoom = 1.5
	relic.set_item(target_id)


## 档案页：列出随身文物（去重）；点击 → 端详。
func _fill_archive() -> void:
	_item_ids.clear()
	for item in Game.bag_items:
		var id := String(item["id"])
		if not _item_ids.has(id):
			_item_ids.append(id)
	for child in item_list.get_children():
		child.queue_free()
	if _item_ids.is_empty():
		var empty := Label.new()
		empty.text = "背包里还没有文物。"
		empty.add_theme_color_override("font_color", Color("8a8f9c"))
		item_list.add_child(empty)
		inspect.visible = false
		return
	inspect.visible = true
	for id in _item_ids:
		var button := Button.new()
		button.text = Game.item_name(id)
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 24)
		button.pressed.connect(func() -> void: inspect.set_item(id))
		item_list.add_child(button)
	inspect.set_item(_item_ids[0])


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("phone") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("bag"):
		close()
		get_viewport().set_input_as_handled()
