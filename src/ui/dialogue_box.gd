class_name DialogueBox
extends CanvasLayer
## Typewriter dialogue box.  Gameplay is paused by the caller while active.

signal finished

const CHARS_PER_SECOND := 32.0

@onready var panel: PanelContainer = $Root/Panel
@onready var speaker_label: Label = $Root/Panel/VBox/Speaker
@onready var text_label: Label = $Root/Panel/VBox/Text
@onready var hint_label: Label = $Root/Panel/VBox/Hint

var _lines: Array = []
var _index := 0
var _shown_chars := 0.0
var _active := false


func _ready() -> void:
	visible = false


func show_dialogue(lines: Array) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_index = 0
	_active = true
	visible = true
	_display_current()


func is_active() -> bool:
	return _active


func advance() -> void:
	if not _active:
		return
	var full := _current_text()
	if int(_shown_chars) < full.length():
		_shown_chars = full.length()
		text_label.visible_characters = -1
		return
	_index += 1
	if _index >= _lines.size():
		_finish()
	else:
		_display_current()


func _process(delta: float) -> void:
	if not _active:
		return
	var full := _current_text()
	if int(_shown_chars) < full.length():
		var before := int(_shown_chars)
		_shown_chars = minf(_shown_chars + delta * CHARS_PER_SECOND, full.length())
		var now := int(_shown_chars)
		text_label.visible_characters = now
		if now / 3 > before / 3:
			Audio.play("blip", -22.0, randf_range(0.95, 1.1))


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		advance()
		get_viewport().set_input_as_handled()


func _current_text() -> String:
	return String((_lines[_index] as Dictionary).get("text", ""))


func _display_current() -> void:
	var line: Dictionary = _lines[_index]
	speaker_label.text = String(line.get("speaker", ""))
	speaker_label.visible = speaker_label.text != ""
	text_label.text = String(line.get("text", ""))
	_shown_chars = 0.0
	text_label.visible_characters = 0


func _finish() -> void:
	_active = false
	visible = false
	finished.emit()
