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

var _item_ids: Array[String] = []


func _ready() -> void:
	visible = false
	dim.gui_input.connect(_on_dim_input)
	tab_task.pressed.connect(func() -> void: _show_tab("task"))
	tab_archive.pressed.connect(func() -> void: _show_tab("archive"))
	inspect.card_requested.connect(func(item_id: String, card_id: String) -> void:
		card_requested.emit(item_id, card_id)
	)


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
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
	var task_active := tab == "task"
	task_page.visible = task_active
	archive_page.visible = not task_active
	tab_task.button_pressed = task_active
	tab_archive.button_pressed = not task_active


func _fill_task() -> void:
	var info := Game.level_info()
	var target_id := Game.mission_target_id
	target_label.text = Game.item_name(target_id)
	meta_label.text = "行动地点：%s\n委托人：老猫 · 报酬：%d 金币" % [
		Game.level_name(),
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
	notes_label.text = "· 拿到目标后，出口才会开启\n· 被警察抓到 = 本次行动结束\n· 目标可丢下（B 整理背包），出口会重新上锁"
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
	if event.is_action_pressed("phone") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
