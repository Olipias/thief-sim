class_name InspectPage
extends Control
## 端详页（文物志的"呈现层 B"）：文物特写 + 可点热点 + 史实/器灵短句 + 展签卡。
##
## 热点数据来自 src/data/lore.gd（归一化坐标）；发现进度存 Game.lore_found（进存档）。
## 展签卡通过信号交给 main 用 DialogueTree 展示（史实与演绎始终视觉分离）。

signal card_requested(item_id: String, card_id: String)

const IMAGE_SIZE := 144.0  # 48×48 特写按 3× 展示

@onready var image: TextureRect = $ImageWrap/Image
@onready var markers: Control = $ImageWrap/Markers
@onready var title_label: Label = $Info/Title
@onready var progress_label: Label = $Info/Progress
@onready var fact_label: Label = $Info/Fact
@onready var ghost_label: Label = $Info/Ghost
@onready var cards_box: VBoxContainer = $Info/Cards

var _item_id := ""
var _hotspots: Array = []
var _marker_buttons: Array[Button] = []


func set_item(item_id: String) -> void:
	_item_id = item_id
	_hotspots = Lore.hotspots(item_id)
	title_label.text = Game.item_name(item_id)
	var path := Lore.closeup_path(item_id)
	if path != "" and ResourceLoader.exists(path):
		image.texture = load(path)
	else:
		var icon := "res://assets/sprites/artifact_%s.png" % item_id
		image.texture = load(icon) if ResourceLoader.exists(icon) else null
	_build_markers()
	_build_cards()
	_select_hotspot(-1)


func _build_markers() -> void:
	for child in markers.get_children():
		child.queue_free()
	_marker_buttons.clear()
	for i in _hotspots.size():
		var hotspot: Dictionary = _hotspots[i]
		var pos: Vector2 = hotspot.get("pos", Vector2(0.5, 0.5))
		var button := Button.new()
		button.text = "?"
		button.custom_minimum_size = Vector2(18, 18)
		button.size = Vector2(18, 18)
		button.position = Vector2(pos.x * IMAGE_SIZE - 9, pos.y * IMAGE_SIZE - 9)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_select_hotspot.bind(i))
		markers.add_child(button)
		_marker_buttons.append(button)
	_refresh_markers()


func _refresh_markers() -> void:
	for i in _marker_buttons.size():
		var found := Game.hotspot_found(_item_id, i)
		_marker_buttons[i].text = "✓" if found else "?"
		_marker_buttons[i].modulate = Color("f5d766") if found else Color(0.75, 0.75, 0.8)


func _select_hotspot(index: int) -> void:
	var total := _hotspots.size()
	var found := 0
	for i in total:
		if Game.hotspot_found(_item_id, i):
			found += 1
	progress_label.text = "已发现 %d / %d" % [found, total]
	if index < 0 or index >= total:
		fact_label.text = "点击「?」标记，端详文物的细节。"
		ghost_label.text = ""
		return
	var hotspot: Dictionary = _hotspots[index]
	Game.mark_hotspot(_item_id, index)
	fact_label.text = "【史实】%s" % String(hotspot.get("fact", ""))
	ghost_label.text = "【器灵】%s" % String(hotspot.get("ghost", ""))
	_refresh_markers()
	# 更新进度（发现数可能刚刚 +1）
	found = 0
	for i in total:
		if Game.hotspot_found(_item_id, i):
			found += 1
	progress_label.text = "已发现 %d / %d" % [found, total]


## 展签卡列表：第 i 张卡在文物志推进到第 i+1 段后解锁。
func _build_cards() -> void:
	for child in cards_box.get_children():
		child.queue_free()
	var cards := Lore.cards(_item_id)
	var unlocked := Game.lore_stage_of(_item_id)
	var index := 0
	for card_id in cards:
		var card: Dictionary = cards[card_id]
		var button := Button.new()
		button.text = String(card.get("title", card_id))
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 22)
		if index < unlocked:
			button.pressed.connect(func() -> void: card_requested.emit(_item_id, String(card_id)))
		else:
			button.disabled = true
			button.text += "（未解锁）"
		cards_box.add_child(button)
		index += 1
