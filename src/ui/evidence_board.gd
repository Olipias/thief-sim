class_name EvidenceBoard
extends Control
## 拖动卡片标题移动；从卡片右端圆点拖到另一张卡片连线。
signal changed
var cards: Array[Dictionary] = []
var dragging := -1
var linking := -1
var offset := Vector2.ZERO
var message := "拖动卡片排布 · 从右侧圆点拖到另一卡片连线 · 右键卡片清除关联"
const CARD_SIZE := Vector2(164, 36)

func _ready() -> void:
	custom_minimum_size = Vector2(560, 142)
	clip_contents = true
	refresh()

func refresh() -> void:
	cards.clear()
	var index := 0
	for cid in EvidenceData.chain_ids():
		for clue in Game.clues_for_chain(cid):
			if clue.collected:
				cards.append({"id": clue.id, "title": clue.title, "pos": Vector2(8 + (index % 3) * 184, 20 + (index / 3) * 40)})
				index += 1
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101d26"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(5, 12), message, HORIZONTAL_ALIGNMENT_LEFT, size.x - 10, 9, Color("f4d48a"))
	for a in cards:
		for b in cards:
			if Game.has_link(a.id, b.id):
				draw_line(a.pos + CARD_SIZE / 2, b.pos + CARD_SIZE / 2, Color("7fd18f"), 2)
	for card in cards:
		draw_rect(Rect2(card.pos, CARD_SIZE), Color("344753"))
		draw_string(font, card.pos + Vector2(4, 18), String(card.title).substr(0, 13), HORIZONTAL_ALIGNMENT_LEFT, 150, 10)
		draw_string(font, card.pos + Vector2(4, 31), "拖动标题 / 圆点连线", HORIZONTAL_ALIGNMENT_LEFT, 145, 9)
		draw_circle(card.pos + Vector2(156, 22), 5, Color("f4d48a"))
	if linking >= 0:
		draw_line(cards[linking].pos + Vector2(156, 22), get_local_mouse_position(), Color("f4d48a"), 2)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			for i in range(cards.size() - 1, -1, -1):
				var card := cards[i]
				if Rect2(card.pos, CARD_SIZE).has_point(event.position):
					if event.button_index == MOUSE_BUTTON_RIGHT:
						for cid in EvidenceData.chain_ids():
							Game.set_story_flag("chain_" + cid + "_done", false)
						for other in cards:
							Game.set_story_flag("link_" + card.id + "_" + other.id, false)
							Game.set_story_flag("link_" + other.id + "_" + card.id, false)
						changed.emit()
					elif event.button_index == MOUSE_BUTTON_LEFT:
						if event.position.distance_to(card.pos + Vector2(156, 22)) < 12:
							linking = i
						else:
							dragging = i
							offset = event.position - card.pos
					accept_event()
					break
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if linking >= 0:
				message = "关联不成立：比较编号、来源与路线信息。"
				for card in cards:
					if Rect2(card.pos, CARD_SIZE).has_point(event.position) and Game.make_link(cards[linking].id, card.id):
						message = "关联已记录；完成全部关联后点击验证。"
				linking = -1
				dragging = -1
				changed.emit()
			dragging = -1
	elif event is InputEventMouseMotion and dragging >= 0:
		cards[dragging].pos = (event.position - offset).clamp(Vector2(0, 18), (size - CARD_SIZE).max(Vector2.ZERO))
	queue_redraw()
