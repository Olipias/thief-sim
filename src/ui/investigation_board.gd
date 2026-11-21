class_name InvestigationBoard
extends Control
## 推理板：真实拖卡 → 拖到中央档案建立连线 → 选关系 → 错误反馈/重试。
##
## 设计约束：
##   - 只显示已获得材料；未到现场不会出现实物照片/柜号。
##   - 位置与已连材料写入 Game.story_flags，读档保留。
##   - 正确关系可要求多份材料同时在板面上；缺一份时明确反馈。

signal feedback_changed(text: String)

const CARD_SIZE := Vector2(150, 62)
const CENTRAL_SIZE := Vector2(190, 96)
const POS_KEY := "inv_board_positions"
const LINK_KEY := "inv_board_links"
const CENTRAL_BASE := "文字档案。现场观察前没有实物照片；把材料拖到这里建立关系。"

var target_id := "ram_zun"

var _central: Panel
var _cards: Dictionary = {}          # material_id -> Panel
var _linked: Array[String] = []      # 已连到中央的材料 ID
var _drag_id := ""
var _drag_offset := Vector2.ZERO
var _dragging := false

var _relation_box: VBoxContainer
var _feedback: Label


func _ready() -> void:
	custom_minimum_size = Vector2(0, 220)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	resized.connect(_layout_all)
	_build_shell()


func set_target(id: String) -> void:
	if not Investigation.TARGETS.has(id):
		return
	target_id = id
	_rebuild()


func _build_shell() -> void:
	_central = Panel.new()
	_central.name = "CentralArchive"
	_central.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_central.size = CENTRAL_SIZE
	add_child(_central)
	var title := Label.new()
	title.name = "CentralTitle"
	title.position = Vector2(8, 6)
	title.size = Vector2(CENTRAL_SIZE.x - 16, 36)
	title.add_theme_font_size_override("font_size", 12)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_central.add_child(title)
	var body := Label.new()
	body.name = "CentralBody"
	body.position = Vector2(8, 44)
	body.size = Vector2(CENTRAL_SIZE.x - 16, 46)
	body.add_theme_font_size_override("font_size", 10)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_central.add_child(body)

	_relation_box = VBoxContainer.new()
	_relation_box.name = "RelationBox"
	_relation_box.position = Vector2(8, 0)
	_relation_box.custom_minimum_size = Vector2(0, 42)
	add_child(_relation_box)

	_feedback = Label.new()
	_feedback.name = "Feedback"
	_feedback.add_theme_font_size_override("font_size", 10)
	_feedback.add_theme_color_override("font_color", Color(0.85, 0.72, 0.5, 1))
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_feedback)


func _rebuild() -> void:
	for child in _relation_box.get_children():
		child.queue_free()
	for id in _cards.keys():
		var card: Panel = _cards[id]
		card.queue_free()
	_cards.clear()
	_linked.clear()

	var central_title := _central.get_node_or_null("CentralTitle") as Label
	var central_body := _central.get_node_or_null("CentralBody") as Label
	if central_title != null:
		central_title.text = "%s\n%s" % [Investigation.target_name(target_id), Investigation.target_code(target_id)]
	if central_body != null:
		central_body.text = CENTRAL_BASE
		_update_conclusions()

	var mats := Investigation.unlocked_materials(target_id)
	for mid in mats.keys():
		_make_card(String(mid), mats[mid])
	_load_state()
	_layout_all()
	_rebuild_relation_options("")
	queue_redraw()


func _make_card(material_id: String, mat: Dictionary) -> void:
	var card := Panel.new()
	card.name = "Card_" + material_id
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.clip_contents = true
	card.set_meta("material_id", material_id)
	add_child(card)
	_cards[material_id] = card

	var title := Label.new()
	title.position = Vector2(6, 4)
	title.size = Vector2(CARD_SIZE.x - 12, 34)
	title.text = "%s · %s" % [Investigation.material_type_label(mat.get("type", "")), mat.get("title", material_id)]
	title.add_theme_font_size_override("font_size", 10)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(title)

	var hint := Label.new()
	hint.position = Vector2(6, 38)
	hint.size = Vector2(CARD_SIZE.x - 12, 20)
	hint.text = "拖到中央连线 · 右键断开"
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.65, 0.67, 0.76, 1))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hint)

	card.gui_input.connect(_on_card_gui_input.bind(material_id))


func _on_card_gui_input(event: InputEvent, material_id: String) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_id = material_id
				_dragging = true
				_drag_offset = mb.position
				move_child(_cards[material_id], get_child_count() - 1)
				accept_event()
			else:
				if _dragging and _drag_id == material_id:
					_dragging = false
					var card: Panel = _cards[material_id]
					var board_mouse := card.position + mb.position
					if _central.get_rect().has_point(board_mouse):
						_link_material(material_id)
					else:
						_save_positions()
					accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_unlink_material(material_id)
			accept_event()
	elif event is InputEventMouseMotion and _dragging and _drag_id == material_id:
		var card: Panel = _cards[material_id]
		var board_mouse := card.position + (event as InputEventMouseMotion).position
		card.position = (board_mouse - _drag_offset).clamp(Vector2.ZERO, size - card.size)
		queue_redraw()
		accept_event()


func _link_material(material_id: String) -> void:
	if not (material_id in _linked):
		_linked.append(material_id)
		_save_links()
	_rebuild_relation_options(material_id)
	_queue_feedback("已连接：%s。选择一条关系。" % Investigation.material(target_id, material_id).get("title", material_id))
	queue_redraw()


func _unlink_material(material_id: String) -> void:
	_linked.erase(material_id)
	_save_links()
	_rebuild_relation_options("")
	_queue_feedback("已断开：%s" % Investigation.material(target_id, material_id).get("title", material_id))
	queue_redraw()


func _rebuild_relation_options(material_id: String) -> void:
	for child in _relation_box.get_children():
		child.queue_free()
	if material_id != "":
		var opts := Investigation.relation_options_for_material(target_id, material_id)
		for opt in opts:
			var btn := Button.new()
			btn.text = opt["text"]
			btn.add_theme_font_size_override("font_size", 9)
			btn.pressed.connect(_on_relation_pressed.bind(opt["question_id"], int(opt["relation_index"])))
			_relation_box.add_child(btn)
	if _relation_box.get_child_count() == 0:
		var hint := Label.new()
		hint.text = "把材料卡拖到中央档案，建立连线后在这里选择关系。"
		hint.add_theme_font_size_override("font_size", 9)
		hint.add_theme_color_override("font_color", Color(0.65, 0.67, 0.76, 1))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_relation_box.add_child(hint)
	_layout_relation_box()


func _on_relation_pressed(question_id: String, relation_index: int) -> void:
	var result := Investigation.record_relation(target_id, question_id, relation_index, _linked)
	_queue_feedback(result["feedback"])
	if result["ok"]:
		# 正确关系只更新反馈/结论；保留卡片与连线，方便继续看板。
		_update_conclusions()


func _queue_feedback(text: String) -> void:
	if _feedback == null:
		return
	_feedback.text = text
	feedback_changed.emit(text)


func _update_conclusions() -> void:
	var central_body := _central.get_node_or_null("CentralBody") as Label
	if central_body == null:
		return
	var lines: Array[String] = []
	if Investigation.is_question_answered(target_id, "features"):
		lines.append("已确认：双羊支撑中间壶形容器，羊角先铸并锁接。")
	if Investigation.is_question_answered(target_id, "area"):
		lines.append("下一处：青铜厅内侧临时展位。")
	if Investigation.is_question_answered(target_id, "spot"):
		lines.append("通路：东门内侧 C-17 搬运小车。")
	central_body.text = CENTRAL_BASE if lines.is_empty() else CENTRAL_BASE + "\n" + "\n".join(lines)


func _layout_all() -> void:
	if _central == null:
		return
	var central_pos := (size - CENTRAL_SIZE) * 0.5 - Vector2(0, 12)
	_central.position = central_pos
	_central.size = CENTRAL_SIZE
	for mid in _cards.keys():
		var card: Panel = _cards[mid]
		var np := _saved_position(mid)
		card.position = Vector2(np.x * maxf(1.0, size.x - CARD_SIZE.x), np.y * maxf(1.0, size.y - CARD_SIZE.y - 48))
		card.size = CARD_SIZE
	_layout_relation_box()
	queue_redraw()


func _layout_relation_box() -> void:
	if _relation_box == null:
		return
	_relation_box.position = Vector2(8, maxf(0.0, size.y - 96))
	_relation_box.size = Vector2(size.x - 16, 54)
	if _feedback != null:
		_feedback.position = Vector2(8, maxf(0.0, size.y - 38))
		_feedback.size = Vector2(size.x - 16, 32)


func _draw() -> void:
	if _central == null:
		return
	var center := _central.position + _central.size * 0.5
	for mid in _linked:
		if not _cards.has(mid):
			continue
		var card: Panel = _cards[mid]
		var p := card.position + card.size * 0.5
		draw_line(center, p, Color(0.85, 0.7, 0.35, 0.9), 2.0)
		draw_circle(p, 3.0, Color(0.85, 0.7, 0.35, 1))


# ---------------------------------------------------------------- 持久化
## story_flags 的读档恢复只接受 bool/string；这里把板面位置和连线序列化成字符串，
## 避免改动 game_state 的存档结构。
func _saved_positions() -> Dictionary:
	var raw: Variant = Game.story_flags.get(POS_KEY, "")
	var out := {}
	if typeof(raw) == TYPE_DICTIONARY:
		# 兼容早期开发版直接存字典；正式存档只写字符串。
		return raw
	if typeof(raw) != TYPE_STRING:
		return out
	for part in String(raw).split(";", false):
		var bits := part.split("=", false, 1)
		if bits.size() != 2:
			continue
		var xy := bits[1].split(",", false, 1)
		if xy.size() != 2:
			continue
		var fx := float(xy[0])
		var fy := float(xy[1])
		if not is_finite(fx) or not is_finite(fy):
			continue
		out[bits[0]] = [fx, fy]
	return out


func _saved_position(material_id: String) -> Vector2:
	var key := "%s:%s" % [target_id, material_id]
	var all := _saved_positions()
	if all.has(key):
		var val = all[key]
		if typeof(val) == TYPE_ARRAY and (val as Array).size() >= 2:
			var fx := float(val[0])
			var fy := float(val[1])
			if is_finite(fx) and is_finite(fy):
				return Vector2(fx, fy).clamp(Vector2.ZERO, Vector2(0.96, 0.9))
	return Investigation.default_position(target_id, material_id)


func _save_positions() -> void:
	var all := _saved_positions()
	for mid in _cards.keys():
		var card: Panel = _cards[mid]
		all["%s:%s" % [target_id, mid]] = [
			clampf(card.position.x / maxf(1.0, size.x - CARD_SIZE.x), 0.0, 1.0),
			clampf(card.position.y / maxf(1.0, size.y - CARD_SIZE.y - 48), 0.0, 1.0),
		]
	var parts: Array[String] = []
	for key in all.keys():
		var val: Array = all[key]
		parts.append("%s=%.4f,%.4f" % [key, float(val[0]), float(val[1])])
	Game.story_flags[POS_KEY] = ";".join(parts)
	Game.save_game()


func _saved_links() -> Array[String]:
	var raw: Variant = Game.story_flags.get(LINK_KEY, "")
	var out: Array[String] = []
	if typeof(raw) == TYPE_DICTIONARY:
		for key in (raw as Dictionary).keys():
			out.append(String(key))
		return out
	if typeof(raw) == TYPE_STRING:
		for key in String(raw).split(";", false):
			out.append(key)
	return out


func _save_links() -> void:
	var all: Array[String] = []
	for key in _saved_links():
		if not key.begins_with(target_id + ":"):
			all.append(key)
	for mid in _linked:
		all.append("%s:%s" % [target_id, mid])
	Game.story_flags[LINK_KEY] = ";".join(all)
	Game.save_game()


func _load_state() -> void:
	var saved := _saved_links()
	for mid in Investigation.materials(target_id).keys():
		if ("%s:%s" % [target_id, mid]) in saved and _cards.has(mid):
			_linked.append(String(mid))


# ---------------------------------------------------------------- 测试/外部读取
func card_ids() -> Array[String]:
	var out: Array[String] = []
	for id in _cards.keys():
		out.append(String(id))
	return out


func linked_materials() -> Array[String]:
	return _linked.duplicate()


func get_card(material_id: String) -> Panel:
	return _cards.get(material_id, null)


func get_central_panel() -> Panel:
	return _central


func get_relation_box() -> VBoxContainer:
	return _relation_box


func get_feedback_label() -> Label:
	return _feedback
