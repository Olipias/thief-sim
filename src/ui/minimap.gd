class_name Minimap
extends Control
## Soul-Knight-style room layout: rooms of the current level, visited state,
## current room with a player dot, plus target and exit markers.

const ROOM_BOX := Vector2(18, 10)
const GAP := Vector2(3, 3)

var museum: Museum = null


func bind(level: Museum) -> void:
	museum = level
	queue_redraw()


func _process(_delta: float) -> void:
	if museum != null and is_instance_valid(museum):
		queue_redraw()


## R-11a 信息边界：当前应绘制（已知）的房间索引集合 = visited + 当前房间。
## 未探房间绝不画框；target/exit 标记只在 visited 后出现。供测试断言防泄漏回归。
func known_room_indexes() -> Array:
	var known := {}
	if museum == null or not is_instance_valid(museum):
		return []
	for i in museum.rooms.size():
		if museum.visited_rooms.has(i) or i == museum.current_room:
			known[i] = true
	return known.keys()


func _draw() -> void:
	if museum == null or not is_instance_valid(museum) or museum.rooms.is_empty():
		return
	# R-11a 信息边界：只以 visited_rooms 为准绘制——未探房间不画框，
	# target/exit 标记只在对应房间已探后出现，不泄露全图轮廓/目标/出口。
	var known_list := known_room_indexes()
	if known_list.is_empty():
		return
	var known := {}
	for i in known_list:
		known[i] = true
	var col_keys := {}
	var row_keys := {}
	for i in known:
		var r: Rect2 = museum.rooms[i]
		col_keys[r.position.x] = true
		row_keys[r.position.y] = true
	var cols: Array = col_keys.keys()
	var rows: Array = row_keys.keys()
	cols.sort()
	rows.sort()

	var total := Vector2(
		cols.size() * ROOM_BOX.x + (cols.size() - 1) * GAP.x,
		rows.size() * ROOM_BOX.y + (rows.size() - 1) * GAP.y,
	)
	draw_rect(Rect2(Vector2(-4, -4), total + Vector2(8, 8)), Color(0.04, 0.05, 0.07, 0.72), true)

	for i in known:
		var r: Rect2 = museum.rooms[i]
		var col: int = cols.find(r.position.x)
		var row: int = rows.find(r.position.y)
		var box := Rect2(Vector2(col, row) * (ROOM_BOX + GAP), ROOM_BOX)
		var fill := Color(0.19, 0.22, 0.29, 0.95)
		var border := Color(0.45, 0.5, 0.6, 0.9)
		if i == museum.current_room:
			fill = Color(0.24, 0.3, 0.42, 0.95)
			border = Color(0.97, 0.84, 0.35)
		draw_rect(box, fill, true)
		draw_rect(box, border, false, 1.0)

		# 目标/出口标记：只在对应房间已被玩家踏入后显示（现场核对才标记）。
		if museum.visited_rooms.has(i):
			if i == museum.target_room:
				draw_rect(Rect2(box.position + Vector2(2, 2), Vector2(4, 4)), Color(0.97, 0.84, 0.35), true)
			if i == museum.exit_room:
				draw_rect(Rect2(box.position + box.size - Vector2(6, 6), Vector2(4, 4)), Color(0.35, 0.85, 0.45), true)

		if i == museum.current_room and museum.player != null and is_instance_valid(museum.player):
			var rel: Vector2 = (museum.player.global_position - r.position) / r.size
			var dot: Vector2 = box.position + Vector2(
				clampf(rel.x, 0.0, 1.0) * box.size.x,
				clampf(rel.y, 0.0, 1.0) * box.size.y,
			)
			draw_circle(dot, 1.7, Color.WHITE)
