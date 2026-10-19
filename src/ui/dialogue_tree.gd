class_name DialogueTree
extends CanvasLayer
## 器灵对谈：带选项与展签卡的对话树（文物志的"呈现层 A"）。
##
## 剧本条目类型（见 src/data/lore.gd）：
##   {"speaker","text"}                 —— 器灵台词（演绎，深色对话框）
##   {"card","id"}                      —— 展签卡（史实，米白纸卡，与台词视觉分离）
##   {"choices":[{"text","goto"}]}      —— 选项，选中跳转到同名 label
##   {"label","name"}                   —— 跳转锚点（不显示）
##   {"goto","name"}                    —— 跳转

signal finished

@onready var speech_panel: PanelContainer = $Root/SpeechPanel
@onready var speaker_label: Label = $Root/SpeechPanel/VBox/Speaker
@onready var speech_text: Label = $Root/SpeechPanel/VBox/Text
@onready var card_panel: PanelContainer = $Root/CardPanel
@onready var card_title: Label = $Root/CardPanel/VBox/Title
@onready var card_body: Label = $Root/CardPanel/VBox/Body
@onready var card_source: Label = $Root/CardPanel/VBox/Source
@onready var choices_box: VBoxContainer = $Root/ChoicesBox

var _script: Array = []
var _cards: Dictionary = {}
var _labels: Dictionary = {}
var _index := 0
var _active := false
var _on_finished: Callable = Callable()
var _choice_buttons: Array[Button] = []
var _choice_index := 0


func _ready() -> void:
	visible = false


func is_active() -> bool:
	return _active


## 播放一段剧本；on_finished 在本段结束时调用（用于推进文物志进度）。
func play(entries: Array, cards: Dictionary, on_finished := Callable()) -> void:
	_script = entries
	_cards = cards
	_on_finished = on_finished
	_index = 0
	_active = true
	_labels.clear()
	for i in _script.size():
		var entry: Dictionary = _script[i]
		if entry.has("label"):
			_labels[String(entry["label"])] = i
	visible = true
	_step()


func _step() -> void:
	_hide_all()
	if _index >= _script.size():
		_finish()
		return
	var entry: Dictionary = _script[_index]
	if entry.has("label"):
		_index += 1
		_step()
		return
	if entry.has("goto"):
		_index = int(_labels.get(String(entry["goto"]), _script.size()))
		_step()
		return
	if entry.has("card"):
		_show_card(String(entry["card"]))
		return
	if entry.has("choices"):
		_show_choices(entry["choices"])
		return
	_show_speech(String(entry.get("speaker", "")), String(entry.get("text", "")))


func advance() -> void:
	if not _active or choices_box.visible:
		return
	_index += 1
	_step()


func _show_speech(speaker: String, text: String) -> void:
	speaker_label.text = speaker
	speaker_label.visible = speaker != ""
	speech_text.text = text
	speech_panel.visible = true


func _show_card(card_id: String) -> void:
	var card: Dictionary = _cards.get(card_id, {})
	card_title.text = String(card.get("title", card_id))
	card_body.text = String(card.get("body", ""))
	card_source.text = String(card.get("source", ""))
	card_panel.visible = true


func _show_choices(choices: Array) -> void:
	_choice_buttons.clear()
	for child in choices_box.get_children():
		child.queue_free()
	for choice in choices:
		var button := Button.new()
		button.text = String(choice.get("text", "…"))
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_choice.bind(String(choice.get("goto", ""))))
		choices_box.add_child(button)
		_choice_buttons.append(button)
	_choice_index = 0
	choices_box.visible = true
	if not _choice_buttons.is_empty():
		_choice_buttons[0].grab_focus()


func _on_choice(goto: String) -> void:
	if not _active:
		return
	_index = int(_labels.get(goto, _script.size()))
	_step()


func _hide_all() -> void:
	speech_panel.visible = false
	card_panel.visible = false
	choices_box.visible = false


func _finish() -> void:
	_active = false
	visible = false
	if _on_finished.is_valid():
		_on_finished.call()
	finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if choices_box.visible:
		var moved := 0
		if event.is_action_pressed("move_up"):
			moved = -1
		elif event.is_action_pressed("move_down"):
			moved = 1
		if moved != 0 and not _choice_buttons.is_empty():
			_choice_index = wrapi(_choice_index + moved, 0, _choice_buttons.size())
			_choice_buttons[_choice_index].grab_focus()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("interact"):
			if not _choice_buttons.is_empty():
				_choice_buttons[_choice_index].pressed.emit()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		advance()
		get_viewport().set_input_as_handled()
