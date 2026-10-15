class_name Museum
extends Node2D
## Builds and runs the museum heist level from src/levels/museum_map.json.

signal escaped
signal caught
signal toast(text: String)
signal prompt_changed(text: String)
signal alert_changed(level: int)
signal dialogue_requested(lines: Array)

const TILE := 16
const SMOKE_RADIUS := 72.0
const SMOKE_BLIND_TIME := 3.5
const WALKABLE := ".~TapXP123456789"
const NIGHT_TINT := Color(0.33, 0.37, 0.55)
const ARTIFACT_POOL: Array[String] = ["vase", "gem", "scroll", "ingot", "jade"]
## 任务目标被拾取后，其"器灵"的台词（按关卡目标文物 id 取）。
const GHOST_LINES := {
	"mask": "把……面具……放……回去……",
	"ram_zun": "千年了……我听见另一只羊，隔着海……带我们……回家……",
}
const SOLID_CHARS := {
	"#": "wall",
	"o": "pillar",
	"d": "case",
	"p": "pedestal",
}

const TEX_FLOOR_A := preload("res://assets/sprites/floor_a.png")
const TEX_FLOOR_B := preload("res://assets/sprites/floor_b.png")
const TEX_WALL := preload("res://assets/sprites/wall.png")
const TEX_WALL_PAINTING := preload("res://assets/sprites/wall_painting.png")
const TEX_WALL_LAMP := preload("res://assets/sprites/wall_lamp.png")
const TEX_PILLAR := preload("res://assets/sprites/pillar.png")
const TEX_CARPET := preload("res://assets/sprites/carpet.png")
const TEX_PEDESTAL := preload("res://assets/sprites/pedestal.png")
const TEX_CASE := preload("res://assets/sprites/case.png")
const TEX_ROPE := preload("res://assets/sprites/rope.png")
const TEX_STATUE := preload("res://assets/sprites/statue.png")
const TEX_PLANT := preload("res://assets/sprites/plant.png")
const TEX_EXIT := preload("res://assets/sprites/exit_door.png")
const TEX_LIGHT_SOFT := preload("res://assets/sprites/light_soft.png")
const PLAYER_SCENE := preload("res://src/actors/player.tscn")
const POLICE_SCENE := preload("res://src/actors/police.tscn")
const ARTIFACT_SCENE := preload("res://src/world/artifact.tscn")
const SMOKE_SCENE := preload("res://src/world/smoke_puff.tscn")
const GHOST_SCENE := preload("res://src/world/ghost.tscn")

var tiles: Array = []
var patrols: Dictionary = {}
var rooms: Array[Rect2] = []
var floors: Array[Rect2] = []
var player: Player = null
var police: Array[Police] = []

## 关卡 id（由 main 在加入场景树前设置；默认第一关）。
var level_id := "museum"

var _ended := false
var _last_prompt := ""
var _noise_warned := false
var _ghost_spawned := false
var ghost_delay := 3.5
var current_room := -1
var visited_rooms := {}
var target_room := -1
var exit_room := -1


func _ready() -> void:
	y_sort_enabled = true
	_load_map()
	_build_level()


func _load_map() -> void:
	var res := load(_map_path()) as JSON
	var data: Dictionary = res.data
	tiles = data.get("tiles", [])
	patrols = data.get("patrols", {})
	rooms.clear()
	for r in data.get("rooms", []):
		rooms.append(Rect2(
			int(r[0]) * TILE, int(r[1]) * TILE,
			int(r[2]) * TILE, int(r[3]) * TILE,
		))
	floors.clear()
	for f in data.get("floors", []):
		floors.append(Rect2(
			int(f[0]) * TILE, int(f[1]) * TILE,
			int(f[2]) * TILE, int(f[3]) * TILE,
		))


func _map_path() -> String:
	var info: Dictionary = Game.LEVELS.get(level_id, {})
	return String(info.get("map", "res://src/levels/museum_map.json"))


func target_item_id() -> String:
	var info: Dictionary = Game.LEVELS.get(level_id, {})
	return String(info.get("target", "mask"))


func _build_level() -> void:
	_build_collision()
	_add_night_tint()
	var artifact_index := 0
	for y in tiles.size():
		var row: String = tiles[y]
		for x in row.length():
			var ch := row[x]
			var pos := _cell_center(x, y)
			match ch:
				"P":
					_spawn_player(pos)
				"T":
					_spawn_artifact(target_item_id(), pos)
				"a":
					_spawn_artifact(ARTIFACT_POOL[artifact_index % ARTIFACT_POOL.size()], pos)
					artifact_index += 1
				"X":
					_spawn_exit(pos)
					_add_light(pos + Vector2(0, -4), Color(0.55, 1.0, 0.65), 0.7, 0.5)
				"L":
					_add_light(pos + Vector2(0, 2), Color(1.0, 0.82, 0.55), 1.1, 0.62)
				"1", "2", "3", "4", "5", "6", "7", "8", "9":
					_spawn_police(ch, pos)
	_setup_camera()


func _add_night_tint() -> void:
	var modulate := CanvasModulate.new()
	modulate.name = "NightTint"
	modulate.color = NIGHT_TINT
	add_child(modulate)


func _add_light(pos: Vector2, color: Color, energy: float, scale: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = TEX_LIGHT_SOFT
	light.color = color
	light.energy = energy
	light.texture_scale = scale
	light.position = pos
	add_child(light)
	return light


func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "Walls"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for y in tiles.size():
		var row: String = tiles[y]
		for x in row.length():
			if WALKABLE.contains(row[x]):
				continue
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(TILE, TILE)
			shape.shape = rect
			shape.position = _cell_center(x, y)
			body.add_child(shape)


func _spawn_player(pos: Vector2) -> void:
	player = PLAYER_SCENE.instantiate() as Player
	player.position = pos
	player.used_item.connect(_on_player_used_item)
	player.made_noise.connect(_on_player_made_noise)
	add_child(player)


func _spawn_artifact(item_id: String, pos: Vector2) -> void:
	var artifact := ARTIFACT_SCENE.instantiate() as Artifact
	artifact.item_id = item_id
	artifact.position = pos
	artifact.picked.connect(_on_artifact_picked)
	artifact.pickup_blocked.connect(_on_pickup_blocked)
	add_child(artifact)
	if item_id == target_item_id():
		target_room = room_index_at(pos)


func _spawn_police(id: String, pos: Vector2) -> void:
	var cop := POLICE_SCENE.instantiate() as Police
	cop.position = pos
	var path: Array = patrols.get(id, [])
	var points: Array[Vector2] = []
	for p in path:
		points.append(_cell_center(int(p[0]), int(p[1])))
	cop.patrol_points = points
	cop.caught.connect(_on_police_caught)
	cop.alert_changed.connect(_on_police_alert_changed)
	police.append(cop)
	add_child(cop)


func _spawn_exit(pos: Vector2) -> void:
	var area := Area2D.new()
	area.name = "Exit"
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE)
	shape.shape = rect
	area.add_child(shape)
	area.position = pos
	area.body_entered.connect(_on_exit_body_entered)
	add_child(area)
	exit_room = room_index_at(pos)


func _setup_camera() -> void:
	if player == null:
		return
	var idx := room_index_at(player.global_position)
	if idx >= 0:
		current_room = idx
		visited_rooms[idx] = true
		_apply_camera_limits(rooms[idx])


func room_index_at(pos: Vector2) -> int:
	for i in rooms.size():
		if rooms[i].has_point(pos):
			return i
	return -1


func _apply_camera_limits(room: Rect2) -> void:
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam == null:
		return
	var r := room
	var view := get_viewport_rect().size / cam.zoom
	if r.size.x < view.x:
		r.position.x -= (view.x - r.size.x) * 0.5
		r.size.x = view.x
	if r.size.y < view.y:
		r.position.y -= (view.y - r.size.y) * 0.5
		r.size.y = view.y
	cam.limit_left = int(r.position.x)
	cam.limit_top = int(r.position.y)
	cam.limit_right = int(r.end.x)
	cam.limit_bottom = int(r.end.y)


func _cell_center(x: int, y: int) -> Vector2:
	return Vector2(x * TILE + TILE * 0.5, y * TILE + TILE * 0.5)


func _process(_delta: float) -> void:
	if player == null or _ended:
		return
	var idx := room_index_at(player.global_position)
	if idx != -1 and idx != current_room:
		current_room = idx
		visited_rooms[idx] = true
		_apply_camera_limits(rooms[idx])
	var prompt: String = player.interactable_name()
	if prompt != _last_prompt:
		_last_prompt = prompt
		prompt_changed.emit(prompt)


func end_game() -> void:
	_ended = true
	if player != null:
		player.controls_enabled = false
	for cop in police:
		cop.deactivate()
	prompt_changed.emit("")


func _on_artifact_picked(item_id: String) -> void:
	Audio.play("pickup", -7.0)
	var name := Game.item_name(item_id)
	var story := Game.item_story(item_id)
	if item_id == target_item_id():
		toast.emit("拿到任务目标：%s！\n快从出口撤离。" % name)
		_start_haunting()
	elif story != "":
		toast.emit("%s 已放入背包（+%d 金币）\n%s" % [name, Game.item_value(item_id), story])
	else:
		toast.emit("%s 已放入背包（+%d 金币）" % [name, Game.item_value(item_id)])


## Drops an artifact back into the world at the player's position so it
## can be picked up again later.
func drop_artifact(item_id: String, at: Vector2) -> void:
	if _ended or player == null:
		return
	var pos := at
	if room_index_at(pos) == -1:
		pos = player.global_position
	_spawn_artifact(item_id, pos)
	Audio.play("step", -8.0, 0.7)
	if Game.item_is_target(item_id):
		toast.emit("你把任务目标「%s」丢在了地上——出口重新上锁了。" % Game.item_name(item_id), 4.0)
	else:
		toast.emit("你把 %s 丢在了地上。" % Game.item_name(item_id))


## The target artifact is haunted: after a short delay a ghost appears and
## wails, luring patrols to the player's position.
func _start_haunting() -> void:
	if _ghost_spawned or _ended:
		return
	_ghost_spawned = true
	var timer := Timer.new()
	timer.name = "GhostTimer"
	timer.wait_time = ghost_delay
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_spawn_ghost)
	timer.start()


func _spawn_ghost() -> void:
	if _ended or player == null:
		return
	dialogue_requested.emit([
		{"speaker": "？？？", "text": String(GHOST_LINES.get(target_item_id(), "……"))},
	])
	var ghost := GHOST_SCENE.instantiate() as Ghost
	ghost.position = player.global_position + Vector2(-10, 8)
	ghost.wailed.connect(_on_ghost_wailed)
	add_child(ghost)
	Audio.play("ghost", -7.0)
	toast.emit("一股寒意贴上你的后背……它好像会引来警察。", 4.0)


func _on_ghost_wailed(pos: Vector2) -> void:
	if _ended:
		return
	Audio.play("ghost", -13.0, randf_range(0.92, 1.06))
	var src_room := room_index_at(pos)
	for cop in police:
		if room_index_at(cop.global_position) != src_room:
			continue
		if cop.global_position.distance_to(pos) <= 96.0:
			cop.investigate(pos)


func _on_pickup_blocked(item_id: String) -> void:
	Audio.play("denied", -8.0)
	toast.emit("背包已满，装不下 %s 了。" % Game.item_name(item_id))


func _on_player_used_item(item_id: String) -> void:
	if _ended or item_id != "smoke":
		return
	if not Game.use_smoke():
		Audio.play("denied", -8.0)
		toast.emit("没有烟雾弹了，回据点买一些吧。")
		return
	Audio.play("smoke", -6.0)
	var puff := SMOKE_SCENE.instantiate() as Node2D
	puff.position = player.global_position
	add_child(puff)
	var blinded := 0
	for cop in police:
		if cop.global_position.distance_to(player.global_position) <= SMOKE_RADIUS:
			cop.blind(SMOKE_BLIND_TIME)
			blinded += 1
	if blinded > 0:
		toast.emit("烟雾弹散开！%d 名警察暂时失去了目标。" % blinded)
	else:
		toast.emit("烟雾弹散开，但附近没有警察。")


func _on_player_made_noise(pos: Vector2, radius: float) -> void:
	if _ended:
		return
	var src_room := room_index_at(pos)
	var heard := false
	for cop in police:
		if room_index_at(cop.global_position) != src_room:
			continue
		if cop.global_position.distance_to(pos) <= radius and cop.investigate(pos):
			heard = true
	if heard and not _noise_warned:
		_noise_warned = true
		toast.emit("跑步声引来了警察的注意，小心。", 2.5)


func _on_exit_body_entered(body: Node2D) -> void:
	if _ended or body != player:
		return
	if Game.mission_complete:
		_ended = true
		Audio.play("escape", -5.0)
		escaped.emit()
	else:
		Audio.play("denied", -8.0)
		toast.emit("出口还锁着：必须带上任务目标才能撤离。")


func _on_police_caught() -> void:
	if _ended:
		return
	_ended = true
	Audio.play("caught", -4.0)
	caught.emit()


func _on_police_alert_changed() -> void:
	var level := 0
	for cop in police:
		level = maxi(level, cop.alert_level())
	alert_changed.emit(level)


const FLOOR_CHARS := ".~TaXP123456789"


func _draw() -> void:
	var map_size := Vector2(tiles[0].length() * TILE, tiles.size() * TILE)
	draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.03, 0.035, 0.05), true)
	for floor_rect in floors:
		draw_texture_rect(TEX_FLOOR_A, floor_rect, true)
	for y in tiles.size():
		var row: String = tiles[y]
		for x in row.length():
			var ch := row[x]
			if ch == " ":
				continue
			var rect := Rect2(Vector2(x * TILE, y * TILE), Vector2(TILE, TILE))
			if (x + y) % 2 == 1 and FLOOR_CHARS.contains(ch):
				draw_texture_rect(TEX_FLOOR_B, rect, false)
			match ch:
				"~":
					draw_texture_rect(TEX_CARPET, rect, false)
				"#":
					draw_texture_rect(TEX_WALL, rect, false)
				"W":
					draw_texture_rect(TEX_WALL_PAINTING, rect, false)
				"L":
					draw_texture_rect(TEX_WALL_LAMP, rect, false)
				"o":
					draw_texture_rect(TEX_PILLAR, rect, false)
				"d":
					draw_texture_rect(TEX_CASE, rect, false)
				"r":
					draw_texture_rect(TEX_ROPE, rect, false)
				"s":
					draw_texture_rect(TEX_STATUE, rect, false)
				"v":
					draw_texture_rect(TEX_PLANT, rect, false)
				"p":
					draw_texture_rect(TEX_PEDESTAL, rect, false)
				"T":
					draw_texture_rect(TEX_PEDESTAL, rect, false)
				"a":
					draw_texture_rect(TEX_PEDESTAL, rect, false)
				"X":
					draw_texture_rect(TEX_EXIT, rect, false)
