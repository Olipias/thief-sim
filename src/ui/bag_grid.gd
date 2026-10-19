class_name BagGrid
extends Control
## Draws the backpack grid: cells, placed items, cursor and held-item preview.

const CELL := 24

const ICONS := {
	"mask": preload("res://assets/sprites/artifact_mask.png"),
	"vase": preload("res://assets/sprites/artifact_vase.png"),
	"gem": preload("res://assets/sprites/artifact_gem.png"),
	"scroll": preload("res://assets/sprites/artifact_scroll.png"),
	"ingot": preload("res://assets/sprites/artifact_ingot.png"),
	"jade": preload("res://assets/sprites/artifact_jade.png"),
	"ram_zun": preload("res://assets/sprites/bm/bm_zun_32.png"),
}

const ITEM_COLORS := {
	"mask": Color("7fa06a"),
	"vase": Color("c46a3a"),
	"gem": Color("3ec6d8"),
	"scroll": Color("e8d8a8"),
	"ingot": Color("e8c34a"),
	"jade": Color("6fc48a"),
	"ram_zun": Color("8c7a4e"),
}

var screen: BackpackScreen = null


func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(c.x * CELL, c.y * CELL, CELL, CELL)


func _draw() -> void:
	if screen == null:
		return
	var bag := Game.bag_cells()

	for y in bag.y:
		for x in bag.x:
			var r := cell_rect(Vector2i(x, y))
			draw_rect(r, Color(0.11, 0.12, 0.16), true)
			draw_rect(r.grow(-0.5), Color(0.28, 0.3, 0.38), false, 1.0)

	for item in Game.bag_items:
		var id := String(item["id"])
		var color: Color = ITEM_COLORS.get(id, Color.WHITE)
		var cells := Game.item_cells_in_bag(item)
		var min_cell: Vector2i = cells[0]
		var max_cell: Vector2i = cells[0]
		for c in cells:
			min_cell.x = mini(min_cell.x, c.x)
			min_cell.y = mini(min_cell.y, c.y)
			max_cell.x = maxi(max_cell.x, c.x)
			max_cell.y = maxi(max_cell.y, c.y)
			var r := cell_rect(c).grow(-1.0)
			draw_rect(r, Color(color.r, color.g, color.b, 0.3), true)
			draw_rect(r, color, false, 1.0)
		var bbox_center := (Vector2(min_cell) + Vector2(max_cell) + Vector2.ONE) * 0.5 * CELL
		var tex: Texture2D = ICONS.get(id)
		if tex != null:
			draw_texture_rect(tex, Rect2(bbox_center - Vector2(12, 12), Vector2(24, 24)), false)

	if not screen.held.is_empty():
		var held_id := String(screen.held["id"])
		var rot := int(screen.held["rot"])
		var fits := Game.bag_can_place(held_id, rot, screen.cursor.x, screen.cursor.y)
		var tint := Color(0.4, 0.9, 0.5, 0.45) if fits else Color(0.95, 0.35, 0.3, 0.45)
		for c in Game.item_shape(held_id, rot):
			var p := screen.cursor + c
			if p.x >= 0 and p.y >= 0 and p.x < bag.x and p.y < bag.y:
				draw_rect(cell_rect(p).grow(-1.0), tint, true)

	draw_rect(cell_rect(screen.cursor).grow(1.0), Color(0.97, 0.84, 0.35), false, 2.0)
