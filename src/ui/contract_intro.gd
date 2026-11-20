class_name ContractIntro
extends Control
## 六格q6开场：5秒自动换格；Space/E/点击推进；Skip直接教学。
signal finished
const PANEL_SECONDS := OpeningCG.PANEL_SECONDS
const PANELS := OpeningCG.PANELS

var panel_index := 0
var elapsed := 0.0
var skip_button: Button
var _caption: Label
var _heading: Label
var _progress: Label
var _art: Texture2D
var _completed := false
var _last_advance_frame := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_art = load(OpeningCG.ART_PATH) as Texture2D
	_heading = _label(13, Color("f4d48a"))
	_caption = _label(13, Color("eee7da"))
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress = _label(10, Color("aaa69e"))
	skip_button = Button.new()
	skip_button.name = "SkipButton"
	skip_button.text = "跳过（Skip）"
	skip_button.add_theme_font_size_override("font_size", 11)
	skip_button.focus_mode = Control.FOCUS_NONE
	add_child(skip_button)
	skip_button.pressed.connect(_finish)
	gui_input.connect(_on_gui_input)
	resized.connect(_layout)
	_layout()
	_refresh()

func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _layout() -> void:
	_heading.position = Vector2(16, 10)
	_heading.size = Vector2(size.x - 160, 24)
	skip_button.position = Vector2(size.x - 120, 7)
	skip_button.size = Vector2(104, 26)
	_caption.position = Vector2(20, size.y - 66)
	_caption.size = Vector2(size.x - 40, 38)
	_progress.position = Vector2(16, size.y - 20)
	_progress.size = Vector2(size.x - 32, 18)
	queue_redraw()

func _process(delta: float) -> void:
	if _completed:
		return
	elapsed += delta
	if elapsed >= PANEL_SECONDS:
		advance()

func advance() -> void:
	if _completed or _last_advance_frame == Engine.get_process_frames():
		return
	_last_advance_frame = Engine.get_process_frames()
	elapsed = 0.0
	if panel_index + 1 >= PANELS.size():
		_finish()
		return
	panel_index += 1
	_refresh()

func _refresh() -> void:
	_heading.text = String(PANELS[panel_index].title)
	_caption.text = String(PANELS[panel_index].caption)
	_progress.text = "%d / %d · 5秒自动切换 · Space / E / 点击下一格 · 虚构演绎" % [panel_index + 1, PANELS.size()]
	queue_redraw()

func _input(event: InputEvent) -> void:
	if _completed:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_SPACE, KEY_E] or event.keycode in [KEY_SPACE, KEY_E]:
			get_viewport().set_input_as_handled()
			advance()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		advance()

func _finish() -> void:
	if _completed:
		return
	_completed = true
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	finished.emit()
	queue_free()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("080b10"))
	if _art == null:
		return
	var points: Array = PANELS[panel_index].points
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	var area := Rect2(16, 38, maxf(1.0, size.x - 32), maxf(1.0, size.y - 112))
	var zoom := minf(area.size.x / bounds.size.x, area.size.y / bounds.size.y)
	var offset := area.position + (area.size - bounds.size * zoom) * 0.5
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	for point in points:
		vertices.append(offset + (point - bounds.position) * zoom)
		uv.append(point / OpeningCG.SOURCE_SIZE)
	draw_polygon(vertices, PackedColorArray([Color.WHITE]), uv, _art)
