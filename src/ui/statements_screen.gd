class_name StatementsScreen
extends CanvasLayer
## 声明与说明：标题界面的正式声明入口（游戏内文本保持世界观叙述，声明集中于此）。
## 不属于游戏内覆盖层：打开时不暂停，仅作为标题界面的子页面。

signal closed

@onready var root: Control = $Root
@onready var sections_box: VBoxContainer = $Root/Panel/Margin/VBox/Scroll/Sections
@onready var close_button: Button = $Root/Panel/Margin/VBox/Footer/CloseButton


func _ready() -> void:
	visible = false
	_build_sections()
	close_button.pressed.connect(close)


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	visible = true
	close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _build_sections() -> void:
	for child in sections_box.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = Statements.TITLE
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("2a2018"))
	sections_box.add_child(title)
	for section in Statements.sections():
		var heading := Label.new()
		heading.text = String(section.get("title", ""))
		heading.add_theme_font_size_override("font_size", 13)
		heading.add_theme_color_override("font_color", Color("6a3a20"))
		sections_box.add_child(heading)
		var body := Label.new()
		body.text = String(section.get("body", ""))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_color_override("font_color", Color("2e2618"))
		sections_box.add_child(body)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 6)
		sections_box.add_child(spacer)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()
