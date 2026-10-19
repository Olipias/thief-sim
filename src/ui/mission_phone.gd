class_name MissionPhone
extends CanvasLayer
## 任务终端（手机）：组织配发的终端，右下角图标点开。
## 任务发布页展示当前任务目标——含 3D 渲染的目标文物转台、故事与报酬。

signal closed

const PAPER := Color("ded6c0")

@onready var root: Control = $Root
@onready var dim: ColorRect = $Root/Dim
@onready var relic: RelicView = $Root/Panel/Margin/VBox/Body/RelicCard/Relic
@onready var target_label: Label = $Root/Panel/Margin/VBox/Body/Info/TargetName
@onready var meta_label: Label = $Root/Panel/Margin/VBox/Body/Info/Meta
@onready var story_label: Label = $Root/Panel/Margin/VBox/Body/Info/Story
@onready var archive_card: PanelContainer = $Root/Panel/Margin/VBox/Body/Info/ArchiveCard
@onready var archive_label: Label = $Root/Panel/Margin/VBox/Body/Info/ArchiveCard/Archive
@onready var notes_label: Label = $Root/Panel/Margin/VBox/Body/Info/Notes


func _ready() -> void:
	visible = false
	dim.gui_input.connect(_on_dim_input)


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	_fill()
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _fill() -> void:
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
		archive_label.text = "文物档案 · %s · %s\n现藏：%s\n流转：%s\n备注：%s\n来源：%s · 演绎：%s" % [
			String(archive.get("era", "")),
			String(archive.get("origin", "")),
			String(archive.get("collection", "")),
			String(archive.get("provenance", "")),
			String(archive.get("legend", "")),
			String(archive.get("source", "")),
			String(archive.get("fiction", "")),
		]
	notes_label.text = "· 拿到目标后，出口才会开启\n· 被警察抓到 = 本次行动结束\n· 目标可丢下（B 整理背包），出口会重新上锁"
	relic.zoom = 1.5
	relic.set_item(target_id)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("phone") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
