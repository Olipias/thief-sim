class_name BackpackScreen
extends CanvasLayer
## Grid backpack management.  Keyboard (cursor) or mouse (drag & drop).
## Dragging an item outside the grid discards it to the world.
## Opened with B during a heist; the caller pauses the tree while visible.

signal closed
signal drop_requested(item_id: String)

@onready var grid: BagGrid = $Root/Panel/Margin/VBox/Body/Grid
@onready var item_name_label: Label = $Root/Panel/Margin/VBox/Body/Info/ItemName
@onready var item_info_label: Label = $Root/Panel/Margin/VBox/Body/Info/ItemInfo
@onready var item_story_label: Label = $Root/Panel/Margin/VBox/Body/Info/ItemStory
@onready var message_label: Label = $Root/Panel/Margin/VBox/Body/Info/Message

var cursor := Vector2i.ZERO
var held: Dictionary = {}
var message := ""


func _ready() -> void:
	visible = false
	grid.screen = self


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	visible = true
	cursor = Vector2i.ZERO
	held = {}
	message = ""
	_refresh()


func close() -> void:
	if not visible:
		return
	if not held.is_empty():
		var fit := Game.bag_auto_fit(String(held["id"]))
		if fit["x"] >= 0:
			Game.place_item(held, int(fit["x"]), int(fit["y"]), int(held["rot"]))
		held = {}
	visible = false
	closed.emit()


## --- actions (shared by keyboard and mouse) --------------------------------

## Takes the item under the given cell into the hand.
func grab_at(cell: Vector2i) -> bool:
	if not held.is_empty():
		return false
	var idx := Game.item_at_cell(cell)
	if idx < 0:
		return false
	var item: Dictionary = Game.bag_items[idx]
	held = {"id": item["id"], "rot": item["rot"]}
	Game.erase_item_at(idx)
	message = ""
	_refresh()
	return true


## Places the held item with its top-left cell at the given cell.
func place_at(cell: Vector2i) -> bool:
	if held.is_empty():
		return false
	if Game.place_item(held, cell.x, cell.y, int(held["rot"])):
		held = {}
		message = ""
		_refresh()
		return true
	message = "放不下：超出格子或有其他文物挡着"
	_refresh()
	return false


func rotate_held() -> void:
	if held.is_empty():
		return
	held["rot"] = (int(held["rot"]) + 1) % 4
	message = ""
	_refresh()


## Discards the held item to the world (handled by the caller via signal).
func drop_held() -> void:
	if held.is_empty():
		return
	var item_id := String(held["id"])
	held = {}
	message = ""
	_refresh()
	drop_requested.emit(item_id)


## Keyboard confirm: grab the item under the cursor, or place the held one.
func confirm() -> void:
	if held.is_empty():
		grab_at(cursor)
	else:
		place_at(cursor)


## --- input ------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var over_grid: bool = grid.get_global_rect().has_point(event.position)
		if event.pressed:
			if over_grid:
				var cell := _cell_at(event.position)
				_sync_cursor(cell)
				grab_at(cell)
		elif not held.is_empty():
			if over_grid:
				place_at(_cell_at(event.position))
			else:
				drop_held()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if grid.get_global_rect().has_point(event.position):
			_sync_cursor(_cell_at(event.position))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("bag") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return

	var move := Vector2i.ZERO
	if event.is_action_pressed("move_left"):
		move.x -= 1
	if event.is_action_pressed("move_right"):
		move.x += 1
	if event.is_action_pressed("move_up"):
		move.y -= 1
	if event.is_action_pressed("move_down"):
		move.y += 1
	if move != Vector2i.ZERO:
		var bag := Game.bag_cells()
		_sync_cursor(Vector2i(
			clampi(cursor.x + move.x, 0, bag.x - 1),
			clampi(cursor.y + move.y, 0, bag.y - 1),
		))
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		confirm()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("rotate"):
		rotate_held()
		get_viewport().set_input_as_handled()


func _cell_at(global_pos: Vector2) -> Vector2i:
	var local := global_pos - grid.global_position
	var bag := Game.bag_cells()
	return Vector2i(
		clampi(int(local.x / BagGrid.CELL), 0, bag.x - 1),
		clampi(int(local.y / BagGrid.CELL), 0, bag.y - 1),
	)


func _sync_cursor(cell: Vector2i) -> void:
	cursor = cell
	message = ""
	_refresh()


func _refresh() -> void:
	var bag := Game.bag_cells()
	grid.custom_minimum_size = Vector2(bag.x * BagGrid.CELL, bag.y * BagGrid.CELL)
	grid.queue_redraw()
	_update_info()


func _update_info() -> void:
	var id := ""
	if not held.is_empty():
		id = String(held["id"])
	else:
		var idx := Game.item_at_cell(cursor)
		if idx >= 0:
			id = String(Game.bag_items[idx]["id"])
	message_label.text = message
	if id.is_empty():
		item_name_label.text = "空格子"
		item_info_label.text = "拖拽或按 E 拿起文物，放到空位；拖出方框即丢弃到脚下。"
		item_story_label.text = ""
		return
	item_name_label.text = Game.item_name(id)
	var target_tag := "（任务目标）" if Game.item_is_target(id) else ""
	item_info_label.text = "占 %d 格 %s\n价值 %d 金币" % [Game.item_cell_count(id), target_tag, Game.item_value(id)]
	item_story_label.text = Game.item_story(id)
