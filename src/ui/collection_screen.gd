class_name CollectionScreen
extends CanvasLayer
## 文物档案收集册：标题页入口，展示真实文物的长期档案与收集进度。
##
## 不属于游戏内覆盖层：打开时不暂停，仅作为标题界面的子页面（与「声明与说明」同层）。
## 解锁状态来自 Game.is_archived()；未归档的页面显示「？？？」与获取提示。

signal closed

const FIELD_ORDER: Array[String] = ["era", "origin", "collection", "provenance", "legend"]

@onready var root: Control = $Root
@onready var progress_label: Label = $Root/Panel/Margin/VBox/Header/Progress
@onready var list_box: VBoxContainer = $Root/Panel/Margin/VBox/Body/ListScroll/List
@onready var image: TextureRect = $Root/Panel/Margin/VBox/Body/Detail/TopRow/ImageFrame/Image
@onready var lock_icon: Label = $Root/Panel/Margin/VBox/Body/Detail/TopRow/ImageFrame/LockIcon
@onready var name_label: Label = $Root/Panel/Margin/VBox/Body/Detail/TopRow/Head/Name
@onready var status_label: Label = $Root/Panel/Margin/VBox/Body/Detail/TopRow/Head/Status
@onready var lore_label: Label = $Root/Panel/Margin/VBox/Body/Detail/TopRow/Head/Lore
@onready var fields_box: VBoxContainer = $Root/Panel/Margin/VBox/Body/Detail/Fields
@onready var locked_label: Label = $Root/Panel/Margin/VBox/Body/Detail/Locked
@onready var close_button: Button = $Root/Panel/Margin/VBox/Footer/CloseButton

var _buttons: Dictionary = {}


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	visible = true
	_build()
	root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(root, "modulate:a", 1.0, 0.25)
	close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _build() -> void:
	progress_label.text = "已归档 %d / %d" % [Game.archived_count(), Collection.IDS.size()]
	for child in list_box.get_children():
		list_box.remove_child(child)
		child.queue_free()
	_buttons.clear()
	var group := ButtonGroup.new()
	for entry in Collection.entries():
		var item_id := String(entry["id"])
		var unlocked := Game.is_archived(item_id)
		var button := Button.new()
		button.text = String(entry["name"]) if unlocked else "？？？"
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(0, 26)
		button.pressed.connect(_select.bind(item_id))
		list_box.add_child(button)
		_buttons[item_id] = button
	_select(Collection.IDS[0])


func _select(item_id: String) -> void:
	var entry := _entry_of(item_id)
	if entry.is_empty():
		return
	var unlocked := Game.is_archived(item_id)
	if _buttons.has(item_id):
		var button: Button = _buttons[item_id]
		button.button_pressed = true
	name_label.text = String(entry["name"]) if unlocked else "？？？"
	image.visible = unlocked
	lock_icon.visible = not unlocked
	if unlocked:
		status_label.text = "已归档"
		image.texture = _load_image(String(entry["image"]))
		_build_fields(entry["archive"])
		fields_box.visible = true
		locked_label.visible = false
		lore_label.text = _lore_progress(item_id)
	else:
		status_label.text = "未归档"
		image.texture = null
		_build_fields({})
		fields_box.visible = false
		locked_label.visible = true
		locked_label.text = String(entry["hint"])
		lore_label.text = ""


func _lore_progress(item_id: String) -> String:
	var stages := Lore.stage_count(item_id)
	if stages <= 0:
		return ""
	var hotspots: Array = Lore.hotspots(item_id)
	var found := 0
	for i in hotspots.size():
		if Game.hotspot_found(item_id, i):
			found += 1
	return "器灵对谈 %d / %d · 端详热点 %d / %d" % [
		Game.lore_stage_of(item_id), stages, found, hotspots.size(),
	]


func _build_fields(archive: Dictionary) -> void:
	for child in fields_box.get_children():
		fields_box.remove_child(child)
		child.queue_free()
	for key in FIELD_ORDER:
		var value := String(archive.get(key, ""))
		if value == "":
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var key_label := Label.new()
		key_label.text = String(Collection.FIELD_LABELS.get(key, key))
		key_label.custom_minimum_size = Vector2(44, 0)
		key_label.add_theme_font_size_override("font_size", 10)
		key_label.add_theme_color_override("font_color", Color("e8c56a"))
		row.add_child(key_label)
		var val_label := Label.new()
		val_label.text = value
		val_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		val_label.add_theme_font_size_override("font_size", 10)
		val_label.add_theme_color_override("font_color", Color("d8cfb8"))
		row.add_child(val_label)
		fields_box.add_child(row)


func _entry_of(item_id: String) -> Dictionary:
	for entry in Collection.entries():
		if String(entry["id"]) == item_id:
			return entry
	return {}


func _load_image(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()
