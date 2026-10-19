class_name RelicView
extends Control
## 文物展示控件：优先播放 3D 渲染的 UI 转台条（relic_<id>_ui_strip.png），
## 否则退回静态图标（artifact_<id>.png）放大显示。供任务终端与标题界面使用。

const UI_STRIP_FRAMES := 12
const UI_STRIP_FRAME_SIZE := Vector2i(48, 56)
const UI_STRIP_FPS := 6.0
const ICON_SCALE := 3.0

## 额外缩放（标题界面可放大展示）。
var zoom := 1.0

var _texture: Texture2D = null
var _frames := 1
var _frame_size := Vector2i.ZERO
var _scale := 1.0
var _time := 0.0


func set_item(item_id: String) -> void:
	var ui_path := "res://assets/sprites/relic_%s_ui_strip.png" % item_id
	if ResourceLoader.exists(ui_path):
		_texture = load(ui_path)
		_frames = UI_STRIP_FRAMES
		_frame_size = UI_STRIP_FRAME_SIZE
		_scale = zoom
	else:
		_texture = load("res://assets/sprites/artifact_%s.png" % item_id)
		_frames = 1
		_frame_size = Vector2i(_texture.get_width(), _texture.get_height())
		_scale = ICON_SCALE * zoom
	custom_minimum_size = Vector2(_frame_size.x * _scale, _frame_size.y * _scale)
	queue_redraw()


func has_turntable() -> bool:
	return _frames > 1


func _process(delta: float) -> void:
	if _frames <= 1:
		return
	_time += delta * UI_STRIP_FPS
	queue_redraw()


func _draw() -> void:
	if _texture == null:
		return
	var frame := int(_time) % _frames
	var src := Rect2(Vector2(frame * _frame_size.x, 0), _frame_size)
	var dst_size := Vector2(_frame_size) * _scale
	var dst := Rect2((size - dst_size) * 0.5, dst_size)
	draw_texture_rect_region(_texture, dst, src)
