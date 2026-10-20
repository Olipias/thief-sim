class_name RelicCloseup
extends CanvasLayer
## 互动特写层（2.5D）：在像素关卡中按 E 触碰文物 → 淡入、降饱和、聚光、
## 轻微呼吸推近的器物特写；实拍级图像只出现在这一层（见 docs/ART_DIRECTION.md）。
##
## 覆盖层契约：打开 ⇔ 暂停；E 拾取 / Esc 离开；process_mode = ALWAYS。

signal closed
signal pickup_requested(item_id: String)

@onready var root: Control = $Root
@onready var art_wrap: Control = $Root/ArtWrap
@onready var art: TextureRect = $Root/ArtWrap/Art
@onready var title_label: Label = $Root/Title
@onready var story_label: Label = $Root/Story
@onready var pickup_button: Button = $Root/Actions/Pickup
@onready var leave_button: Button = $Root/Actions/Leave
@onready var hint_label: Label = $Root/Hint

var _item_id := ""
var _can_pickup := true
var _t := 0.0
var _base_pos := Vector2.ZERO


func _ready() -> void:
	visible = false
	pickup_button.pressed.connect(_on_pickup)
	leave_button.pressed.connect(close)


func is_open() -> bool:
	return visible


func open(item_id: String, can_pickup := true) -> void:
	_item_id = item_id
	_can_pickup = can_pickup
	title_label.text = Game.item_name(item_id)
	story_label.text = Game.item_story(item_id)
	art.texture = load("res://assets/sprites/relic_%s_closeup.png" % item_id)
	pickup_button.visible = can_pickup
	hint_label.text = "E 拾取 · Esc 离开" if can_pickup else "Esc 返回"
	visible = true
	_t = 0.0
	root.modulate.a = 0.0
	_reset_animation()
	var tween := create_tween()
	tween.tween_property(root, "modulate:a", 1.0, 0.35)
	if can_pickup:
		pickup_button.grab_focus()
	else:
		leave_button.grab_focus()


func _reset_animation() -> void:
	if art_wrap != null:
		_base_pos = art_wrap.position
		art_wrap.scale = Vector2(0.94, 0.94)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _on_pickup() -> void:
	if not _can_pickup:
		close()
		return
	pickup_requested.emit(_item_id)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# 2.5D：极慢的呼吸推近 + 轻微位移，让静态图“活”起来
	var breathe := 1.0 + sin(_t * 0.55) * 0.012
	art_wrap.scale = Vector2(breathe, breathe)
	art_wrap.position = _base_pos + Vector2(sin(_t * 0.37) * 2.0, cos(_t * 0.31) * 1.5)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		if _can_pickup:
			_on_pickup()
		else:
			close()
		get_viewport().set_input_as_handled()
