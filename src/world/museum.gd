class_name Museum
extends Node2D
## Builds and runs the museum heist level from src/levels/museum_map.json.

signal escaped
signal caught
signal toast(text: String)
signal prompt_changed(text: String)
signal alert_changed(level: int)
signal dialogue_requested(lines: Array)
## 文物志对谈请求（item_id 与要播放的段序号；由 main 交给 DialogueTree）。
signal lore_requested(item_id: String, stage: int)
## 请求进入互动特写层（2.5D）
signal closeup_requested(item_id: String)
## 剧情单卡/短句请求（BM Room 3 标签、留言等；由 main 用 DialogueTree 播放）。
signal story_requested(lines: Array, cards: Dictionary, on_finished: Callable)

const TILE := 16
const SMOKE_RADIUS := 72.0
const SMOKE_BLIND_TIME := 3.5
const WALKABLE := ".~TapXP123456789"
const NIGHT_TINT := Color(0.33, 0.37, 0.55)
const NIGHT_TINT_BM := Color(0.46, 0.50, 0.66)  ## 大英博物馆：冷夜但保留展厅可读性
const ARTIFACT_POOL: Array[String] = ["vase", "gem", "scroll", "ingot", "jade"]
## 任务目标被拾取后，其"器灵"的台词（按关卡目标文物 id 取）。
const GHOST_LINES := {
	"mask": "把……面具……放……回去……",
	"ram_zun": "千年了……我听见另一只羊，隔着海……带我们……回家……",
}

## BM Room 3 剧情触发器：馆方标签与观众留言。
const BM_LABEL_POS := Vector2(168, 312)
const BM_NOTE_POS := Vector2(120, 312)
const BM_LABEL_CARDS := {
	"zun_label": {
		"title": "馆方说明 · 商代双羊尊",
		"body": "商代晚期，约公元前 1200—1050 年\n青铜\n传出自湖南\n1936 年购自乔治·尤摩弗帕勒斯旧藏\n馆藏编号 1936,1118.1",
	}
}
const BM_NOTE_CARDS := {
	"zun_note": {
		"title": "观众留言，非馆方说明",
		"body": "1860，圆明园。别忘了。",
	}
}
const SOLID_CHARS := {
	"#": "wall",
	"o": "pillar",
	"d": "case",
	"p": "pedestal",
}

## 大英博物馆 Room 3 瓦片图集索引（8 列 × 4 行，每格 16×16）。
const BM_COLS := 8
const BM_FLOOR := [0, 1, 2, 3]
const BM_WALL := [5, 6, 7]
const BM_TRIM := 8
const BM_LAMP := 10
const BM_CARPET := 11
const BM_CARPET_EDGE := 12
const BM_CASE_H := 13
const BM_CASE_V := 14
const BM_CASE_CORNER := 16
const BM_ROPE_POST := 17
const BM_ROPE := 18
const BM_COLUMN_TOP := 19
const BM_COLUMN_MID := 20
const BM_COLUMN_BASE := 21
const BM_SCROLL_MID := 23
const BM_PEDESTAL_REGION := Rect2(160, 0, 32, 32)  ## bm_props 第 5 格（展台）

## 六个展厅的主题：房间索引 → 图集索引。
## floor/wall 是变体数组；carpet=-1 表示该房间没有红毯。
const BM_THEMES := {
	0: {  # 入口大厅：冷理石 + 新古典墙 + 天窗
		"floor": [28, 29], "wall": [36, 37], "trim": 56,
		"carpet": -1, "carpet_edge": -1,
		"case_h": BM_CASE_H, "case_v": BM_CASE_V, "lamp": BM_LAMP, "scroll": BM_SCROLL_MID,
	},
	1: {  # 瓷器厅：冷理石 + 青花墙 + 瓷柜
		"floor": [28, 29], "wall": [38, 39], "trim": 56,
		"carpet": 46, "carpet_edge": 47,
		"case_h": 50, "case_v": 51, "lamp": BM_LAMP, "scroll": BM_SCROLL_MID,
	},
	2: {  # 玉器与书画厅：木地板 + 暖墙 + 红漆柜
		"floor": [30, 31], "wall": [40, 41], "trim": 56,
		"carpet": BM_CARPET, "carpet_edge": BM_CARPET_EDGE,
		"case_h": 48, "case_v": 49, "lamp": BM_LAMP, "scroll": BM_SCROLL_MID,
	},
	3: {  # 青铜礼器厅（目标）
		"floor": BM_FLOOR, "wall": BM_WALL, "trim": BM_TRIM,
		"carpet": BM_CARPET, "carpet_edge": BM_CARPET_EDGE,
		"case_h": BM_CASE_H, "case_v": BM_CASE_V, "lamp": BM_LAMP, "scroll": BM_SCROLL_MID,
	},
	4: {  # 丝路与敦煌厅：沙地 + 土红墙 + 壁画
		"floor": [32, 33], "wall": [42, 43], "trim": 56,
		"carpet": -1, "carpet_edge": -1,
		"case_h": BM_CASE_H, "case_v": BM_CASE_V, "lamp": BM_LAMP, "scroll": 52,
	},
	5: {  # 装卸区：水泥地 + 金属墙 + 警示线 + 日光灯
		"floor": [34, 35], "wall": [44, 45], "trim": 57,
		"carpet": -1, "carpet_edge": -1,
		"case_h": BM_CASE_H, "case_v": BM_CASE_V, "lamp": 54, "scroll": 53,
	},
}

## 装饰层：纯视觉 Sprite，不新增碰撞；key → 贴图。
const BM_DECOR_TEX := {
	"security_gate": preload("res://assets/sprites/bm/decor/security_gate.png"),
	"ticket_desk": preload("res://assets/sprites/bm/decor/ticket_desk.png"),
	"museum_map": preload("res://assets/sprites/bm/decor/museum_map.png"),
	"vase_case": preload("res://assets/sprites/bm/decor/vase_case.png"),
	"jade_case": preload("res://assets/sprites/bm/decor/jade_case.png"),
	"scroll_case": preload("res://assets/sprites/bm/decor/scroll_case.png"),
	"lacquer_cabinet": preload("res://assets/sprites/bm/decor/lacquer_cabinet.png"),
	"mural_panel": preload("res://assets/sprites/bm/decor/mural_panel.png"),
	"crate_stack": preload("res://assets/sprites/bm/decor/crate_stack.png"),
	"pallet": preload("res://assets/sprites/bm/decor/pallet.png"),
	"forklift": preload("res://assets/sprites/bm/decor/forklift.png"),
	"pipe_panel": preload("res://assets/sprites/bm/decor/pipe_panel.png"),
	"bench": preload("res://assets/sprites/bm/decor/bench.png"),
	"security_camera": preload("res://assets/sprites/bm/decor/security_camera.png"),
	"alarm_beacon": preload("res://assets/sprites/bm/decor/alarm_beacon.png"),
	"skylight_panel": preload("res://assets/sprites/bm/decor/skylight_panel.png"),
}

## 房间索引 → 装饰（cell + offset）。offset 用于让贴图跨格或贴墙。
const BM_DECOR := {
	0: [
		{"tex": "security_gate", "cell": Vector2i(18, 5), "offset": Vector2(0, -8)},
		{"tex": "ticket_desk", "cell": Vector2i(4, 1), "offset": Vector2(0, -6)},
		{"tex": "museum_map", "cell": Vector2i(10, 0), "offset": Vector2(0, 4)},
		{"tex": "bench", "cell": Vector2i(13, 1), "offset": Vector2(0, -4)},
		{"tex": "security_camera", "cell": Vector2i(2, 0), "offset": Vector2(0, 4)},
		{"tex": "skylight_panel", "cell": Vector2i(8, 0), "offset": Vector2(8, 4)},
	],
	1: [
		{"tex": "vase_case", "cell": Vector2i(26, 3), "offset": Vector2(8, 8)},
		{"tex": "vase_case", "cell": Vector2i(36, 6), "offset": Vector2(8, 8)},
		{"tex": "museum_map", "cell": Vector2i(30, 0), "offset": Vector2(0, 4)},
		{"tex": "security_camera", "cell": Vector2i(24, 0), "offset": Vector2(0, 4)},
	],
	2: [
		{"tex": "jade_case", "cell": Vector2i(33, 19), "offset": Vector2(0, -4)},
		{"tex": "lacquer_cabinet", "cell": Vector2i(25, 22), "offset": Vector2(0, -8)},
		{"tex": "lacquer_cabinet", "cell": Vector2i(38, 17), "offset": Vector2(0, -8)},
		{"tex": "mural_panel", "cell": Vector2i(27, 14), "offset": Vector2(8, -4)},
		{"tex": "security_camera", "cell": Vector2i(36, 14), "offset": Vector2(0, 4)},
	],
	3: [
		{"tex": "bench", "cell": Vector2i(2, 20), "offset": Vector2(0, -4)},
		{"tex": "bench", "cell": Vector2i(17, 20), "offset": Vector2(0, -4)},
		{"tex": "museum_map", "cell": Vector2i(10, 14), "offset": Vector2(0, 4)},
		{"tex": "security_camera", "cell": Vector2i(2, 14), "offset": Vector2(0, 4)},
		{"tex": "alarm_beacon", "cell": Vector2i(17, 14), "offset": Vector2(0, 4)},
		{"tex": "skylight_panel", "cell": Vector2i(8, 14), "offset": Vector2(8, 4)},
	],
	4: [
		{"tex": "mural_panel", "cell": Vector2i(6, 28), "offset": Vector2(8, -4)},
		{"tex": "mural_panel", "cell": Vector2i(13, 28), "offset": Vector2(8, -4)},
		{"tex": "scroll_case", "cell": Vector2i(4, 31), "offset": Vector2(8, 8)},
		{"tex": "scroll_case", "cell": Vector2i(13, 34), "offset": Vector2(8, 8)},
		{"tex": "bench", "cell": Vector2i(9, 36), "offset": Vector2(0, -4)},
		{"tex": "security_camera", "cell": Vector2i(2, 28), "offset": Vector2(0, 4)},
	],
	5: [
		{"tex": "crate_stack", "cell": Vector2i(26, 39), "offset": Vector2(0, -8)},
		{"tex": "crate_stack", "cell": Vector2i(30, 39), "offset": Vector2(0, -8)},
		{"tex": "crate_stack", "cell": Vector2i(34, 39), "offset": Vector2(0, -8)},
		{"tex": "crate_stack", "cell": Vector2i(38, 39), "offset": Vector2(0, -8)},
		{"tex": "pallet", "cell": Vector2i(28, 38), "offset": Vector2(0, -4)},
		{"tex": "forklift", "cell": Vector2i(24, 36), "offset": Vector2(0, -8)},
		{"tex": "pipe_panel", "cell": Vector2i(22, 32), "offset": Vector2(8, 0)},
		{"tex": "pipe_panel", "cell": Vector2i(41, 32), "offset": Vector2(-8, 0)},
		{"tex": "security_camera", "cell": Vector2i(23, 28), "offset": Vector2(0, 4)},
		{"tex": "alarm_beacon", "cell": Vector2i(40, 28), "offset": Vector2(0, 4)},
	],
}

## 大英博物馆里“看起来是实体”的装饰，给它们补碰撞，避免玩家误判。
const BM_SOLID_DECOR := {
	"ticket_desk": Vector2(30, 18),
	"bench": Vector2(20, 8),
	"forklift": Vector2(44, 24),
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
# Room 3（大英博物馆·青铜礼器厅）主题资产；由 tools/gen_bm_art.py 生成。
const BM_TILES := preload("res://assets/sprites/bm/bm_tiles.png")
const BM_PROPS := preload("res://assets/sprites/bm/bm_props.png")
const BM_CASE := preload("res://assets/sprites/bm/bm_case.png")
const BM_ZUN_ICON := preload("res://assets/sprites/bm/bm_zun_32.png")
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
var _wail_warned := false
var _patrol_hint_shown := false
var _ghost_spawned := false
var ghost: Ghost = null
var ghost_delay := 3.5
var current_room := -1
var visited_rooms := {}
var target_room := -1
var exit_room := -1
var _room_of_tile: Array = []
var bm_decor_count := 0
var _bm_time := 0.0
var _bm_cameras: Array[Node2D] = []
var _bm_beacons: Array[Node2D] = []
var _bm_skylights: Array[Node2D] = []
var _bm_glints: Array[Node2D] = []
var bm_solid_decor_count := 0

## BM Room 3 的剧情触发器（馆方标签 / 观众留言）。
var _story_triggers: Array[Area2D] = []
## 本局已读过的剧情触发器：group -> true。
var _story_trigger_read: Dictionary = {}
## 上一次响应的剧情触发器；离开其范围后才允许再次按 E 重读（防止 _finish_story_tree 反复打开）。
var _last_story_trigger: Area2D = null
## 大英博物馆：出口前自动播放双羊 stage 3 的状态。
var _pending_zun_stage := -1
var _zun_stage3_triggered := false


func _ready() -> void:
	y_sort_enabled = true
	_load_map()
	_build_room_lookup()
	_build_level()
	_build_bm_decor()
	_build_bm_atmosphere()


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


func _build_room_lookup() -> void:
	_room_of_tile.clear()
	for y in tiles.size():
		var row: Array = []
		var line: String = tiles[y]
		for x in line.length():
			row.append(room_index_at(_cell_center(x, y)))
		_room_of_tile.append(row)


func _map_path() -> String:
	var info: Dictionary = Game.LEVELS.get(level_id, {})
	return String(info.get("map", "res://src/levels/museum_map.json"))


func target_item_id() -> String:
	var info: Dictionary = Game.LEVELS.get(level_id, {})
	return String(info.get("target", "mask"))


func _build_level() -> void:
	_build_collision()
	_add_night_tint()
	_spawn_story_triggers()
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
					var lamp := _bm_lamp_config(pos) if level_id == "british_museum" else {
						"color": Color(1.0, 0.82, 0.55), "energy": 1.1, "scale": 0.62,
					}
					_add_light(pos + Vector2(0, 2), lamp["color"], lamp["energy"], lamp["scale"])
				"1", "2", "3", "4", "5", "6", "7", "8", "9":
					_spawn_police(ch, pos)
	_setup_camera()


## 大英博物馆各展厅的壁灯气质：入口暖、瓷器冷、丝路低暖、后场冷白。
func _bm_lamp_config(pos: Vector2) -> Dictionary:
	match room_index_at(pos):
		1:
			return {"color": Color(0.75, 0.9, 1.0), "energy": 1.0, "scale": 0.62}
		4:
			return {"color": Color(1.0, 0.72, 0.42), "energy": 0.9, "scale": 0.6}
		5:
			return {"color": Color(0.85, 0.95, 1.0), "energy": 1.2, "scale": 0.68}
		_:
			return {"color": Color(1.0, 0.82, 0.55), "energy": 1.1, "scale": 0.62}


func _add_night_tint() -> void:
	var modulate := CanvasModulate.new()
	modulate.name = "NightTint"
	modulate.color = NIGHT_TINT_BM if level_id == "british_museum" else NIGHT_TINT
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


## 实际阻挡判定：地图非走格 + 大英博物馆的 T/a/p 展台。
func is_cell_blocked(x: int, y: int) -> bool:
	var ch := _tile_char(x, y)
	if ch == " ":
		return true
	if not WALKABLE.contains(ch):
		return true
	if level_id == "british_museum" and "pTa".contains(ch):
		return true
	return false


func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "Walls"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for y in tiles.size():
		var row: String = tiles[y]
		for x in row.length():
			if not is_cell_blocked(x, y):
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
	player.inspect_requested.connect(func(item_id: String) -> void: closeup_requested.emit(item_id))
	player.story_trigger_requested.connect(_on_story_trigger_requested)
	add_child(player)


func _spawn_artifact(item_id: String, pos: Vector2) -> void:
	if item_id == target_item_id() and level_id == "british_museum":
		_add_bm_display_case(pos)
	var artifact := ARTIFACT_SCENE.instantiate() as Artifact
	artifact.item_id = item_id
	artifact.position = pos
	artifact.picked.connect(_on_artifact_picked)
	artifact.pickup_blocked.connect(_on_pickup_blocked)
	add_child(artifact)
	if item_id == target_item_id():
		target_room = room_index_at(pos)
		if level_id == "british_museum":
			var glow := artifact.get_node_or_null("Glow") as PointLight2D
			if glow != null:
				glow.energy = 0.0
				glow.texture_scale = 0.0


## Room 3 的玻璃展柜 + 暖光，只做一次（目标被丢下再拾取时不重复生成）。
func _add_bm_display_case(pos: Vector2) -> void:
	if has_node("BMDisplayCase"):
		return
	var display_case := Sprite2D.new()
	display_case.name = "BMDisplayCase"
	display_case.texture = BM_CASE
	display_case.position = pos + Vector2(0, -10)
	add_child(display_case)
	_add_light(pos + Vector2(0, -6), Color(1.0, 0.72, 0.42), 0.45, 0.45)


## 大英博物馆 Room 3 的可交互剧情物：馆方标签 + 观众留言。
func _spawn_story_triggers() -> void:
	if level_id != "british_museum":
		return
	_story_triggers.clear()
	_story_trigger_read.clear()
	_last_story_trigger = null
	_add_story_trigger("story_label", BM_LABEL_POS, "馆方标签", BM_LABEL_CARDS, _label_lines(), _on_label_read)
	_add_story_trigger("story_note", BM_NOTE_POS, "观众留言", BM_NOTE_CARDS, _note_lines(), _on_note_read)


func _add_story_trigger(group: String, pos: Vector2, prompt: String, cards: Dictionary, lines: Array, on_finished: Callable) -> void:
	var area := Area2D.new()
	area.name = "StoryTrigger_" + group
	area.collision_layer = 8
	area.collision_mask = 2
	area.position = pos
	area.add_to_group(group)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	shape.shape = circle
	area.add_child(shape)
	area.body_exited.connect(_on_story_trigger_exited.bind(area))
	area.set_meta("story_data", {"prompt": prompt, "lines": lines, "cards": cards, "on_finished": on_finished})
	add_child(area)
	_story_triggers.append(area)


func _label_lines() -> Array:
	return [
		{"card": "zun_label"},
		{"speaker": "右羊", "text": "买。他记得买的那一天。"},
		{"speaker": "左羊", "text": "他不记得做我的那一天。"},
		{"speaker": "", "text": "标签上的字很小。你凑近时，玻璃里映出两张脸。一张是你的，一张不是。"},
	]


func _note_lines() -> Array:
	return [
		{"card": "zun_note"},
		{"speaker": "右羊", "text": "火。他们总说火。"},
		{"speaker": "左羊", "text": "我不记得火。我记得范土是湿的。"},
		{"speaker": "右羊", "text": "你记得的太早了。早得没人信。"},
		{"speaker": "", "text": "留言的墨水是新的。"},
	]


func _both_read_lines() -> Array:
	return [
		{"speaker": "左羊", "text": "两件事。一件有编号。一件有火。"},
		{"speaker": "右羊", "text": "你信哪个？"},
		{
			"choices": [
				{"text": "编号。它有日期。", "goto": "num"},
				{"text": "火。它有恨。", "goto": "fire"},
				{"text": "都不够。", "goto": "none"},
				{"text": "都信。也都不全信。", "goto": "both"},
			]
		},
		{"label": "num"},
		{"speaker": "左羊", "text": "那你信的是买它的人。"},
		{"speaker": "右羊", "text": "至少他没说谎。"},
		{"goto": "end"},
		{"label": "fire"},
		{"speaker": "右羊", "text": "恨不用证据。"},
		{"speaker": "左羊", "text": "可它也不是记忆。"},
		{"goto": "end"},
		{"label": "none"},
		{"speaker": "左羊", "text": "对。都不够。"},
		{"speaker": "右羊", "text": "那你为什么还站着？"},
		{"goto": "end"},
		{"label": "both"},
		{"speaker": "左羊", "text": "这是读书人的说法。"},
		{"speaker": "右羊", "text": "这是活人的说法。"},
		{"goto": "end"},
		{"label": "end"},
		{"speaker": "左羊", "text": "走吧。灯要灭了。"},
	]


func _on_label_read() -> void:
	Game.set_story_flag("read_label")
	_story_trigger_read["story_label"] = true
	if Game.story_flag("read_note") and not _story_trigger_read.get("both_read", false):
		_trigger_both_read()


func _on_note_read() -> void:
	Game.set_story_flag("read_note")
	_story_trigger_read["story_note"] = true
	if Game.story_flag("read_label") and not _story_trigger_read.get("both_read", false):
		_trigger_both_read()


func _trigger_both_read() -> void:
	_story_trigger_read["both_read"] = true
	story_requested.emit(_both_read_lines(), {}, Callable())


func _spawn_police(id: String, pos: Vector2) -> void:
	var cop := POLICE_SCENE.instantiate() as Police
	cop.museum = self
	cop.position = pos
	var path: Array = patrols.get(id, [])
	var points: Array[Vector2] = []
	for p in path:
		points.append(_cell_center(int(p[0]), int(p[1])))
	cop.patrol_points = points
	if level_id == "museum":
		cop.spot_delay_scale = 1.6  # 教学关：守卫反应更慢，提高容错
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


func _process(delta: float) -> void:
	_bm_time += delta
	_animate_bm_decor()
	if player == null or _ended:
		return
	var idx := room_index_at(player.global_position)
	if idx != -1 and idx != current_room:
		current_room = idx
		visited_rooms[idx] = true
		_apply_camera_limits(rooms[idx])
		if not _patrol_hint_shown and _room_has_police(idx):
			_patrol_hint_shown = true
			toast.emit("前面有守卫在巡逻——先看清手电光锥的方向，再贴着边走。")
	var prompt := ""
	var nearest_trigger := _nearest_story_trigger()
	if _ghost_near():
		prompt = "按 E 与器灵交谈"
	elif nearest_trigger != null:
		var data: Dictionary = nearest_trigger.get_meta("story_data", {})
		prompt = "按 E 阅读：%s" % data.get("prompt", "")
	else:
		var target_name: String = player.interactable_name()
		prompt = "按 E 拾取：%s" % target_name if target_name != "" else ""
	if prompt != _last_prompt:
		_last_prompt = prompt
		prompt_changed.emit(prompt)
	if _ghost_near() and Input.is_action_just_pressed("interact"):
		_talk_to_ghost()


func _room_has_police(idx: int) -> bool:
	for cop in police:
		if is_instance_valid(cop) and room_index_at(cop.global_position) == idx:
			return true
	return false


func _nearest_story_trigger() -> Area2D:
	if player == null:
		return null
	var best: Area2D = null
	var best_dist := INF
	for area in player.interact_area.get_overlapping_areas():
		if not (area.is_in_group("story_label") or area.is_in_group("story_note")):
			continue
		var dist := player.global_position.distance_squared_to(area.global_position)
		if dist < best_dist:
			best_dist = dist
			best = area
	return best


func _on_story_trigger_requested(group: String) -> void:
	if _ended:
		return
	for trigger in _story_triggers:
		if not trigger.is_in_group(group):
			continue
		# 离开触发器范围前禁止重复按 E 重开；离开后回来可重读。
		if trigger == _last_story_trigger:
			return
		_last_story_trigger = trigger
		var data: Dictionary = trigger.get_meta("story_data", {})
		var on_finished: Callable = data.get("on_finished", Callable())
		story_requested.emit(data.get("lines", []), data.get("cards", {}), on_finished)
		return


## 玩家离开剧情触发器范围后，才允许再次按 E 重读同一张。
func _on_story_trigger_exited(body: Node2D, trigger: Area2D) -> void:
	if body != player:
		return
	if _last_story_trigger == trigger:
		_last_story_trigger = null


func _ghost_near() -> bool:
	return (
		ghost != null
		and is_instance_valid(ghost)
		and player != null
		and player.global_position.distance_to(ghost.global_position) < 36.0
	)


func end_game() -> void:
	_ended = true
	if player != null:
		player.controls_enabled = false
	for cop in police:
		cop.deactivate()
	prompt_changed.emit("")


## 供特写层“拾取”按钮调用：拾取指定文物（返回是否成功）。
func pickup_artifact(item_id: String) -> bool:
	for child in get_children():
		if child is Artifact and child.item_id == item_id:
			return child.try_pickup()
	return false


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
	# 有文物志的文物：走对谈（第一段），否则退回单句台词
	var target := target_item_id()
	if Lore.has_lore(target) and Game.lore_stage_of(target) == 0:
		lore_requested.emit(target, 0)
	else:
		dialogue_requested.emit([
			{"speaker": "？？？", "text": String(GHOST_LINES.get(target, "……"))},
		])
	ghost = GHOST_SCENE.instantiate() as Ghost
	ghost.position = player.global_position + Vector2(-10, 8)
	ghost.wailed.connect(_on_ghost_wailed)
	add_child(ghost)
	Audio.play("ghost", -7.0)
	# 若双羊已信任玩家，本局不再哀嚎（面具逻辑不受影响）。
	if level_id == "british_museum" and Game.story_flag("zun_trusted"):
		ghost.calm(999999.0)
	# 不在器灵出现时弹提示：此时通常正开着对谈/台词，提示会压住选项；
	# "它会引来警察 + 按 E 可以安抚"在哀嚎真正引警时用 toast 说明。


## 与器灵交谈：播放下一段文物志（讲完则提示）。
func _talk_to_ghost() -> void:
	if _ended:
		return
	var target := target_item_id()
	var stage := Game.lore_stage_of(target)
	var spoke := false
	if Lore.has_lore(target) and stage < Lore.stage_count(target):
		lore_requested.emit(target, stage)
		spoke = true
	if ghost != null and is_instance_valid(ghost):
		# 交谈的机械回报：器灵被安抚，短时间内不再哀嚎（也就不会引来警察）。
		ghost.calm(8.0)
		if spoke:
			toast.emit("器灵安静了下来——短时间内不会再哀嚎。", 3.0)
		else:
			toast.emit("器灵沉默着，但安静了下来——短时间内不会再哀嚎。", 3.5)


func _on_ghost_wailed(pos: Vector2) -> void:
	if _ended:
		return
	# 双羊信任玩家后，右羊不再哀嚎引警（面具逻辑不受影响）。
	if level_id == "british_museum" and Game.story_flag("zun_trusted"):
		return
	Audio.play("ghost", -13.0, randf_range(0.92, 1.06))
	var src_room := room_index_at(pos)
	var lured := 0
	for cop in police:
		if room_index_at(cop.global_position) != src_room:
			continue
		if cop.global_position.distance_to(pos) <= 96.0:
			# 循声搜索：停在两格半外张望，而不是直接踩到玩家身上
			if cop.investigate(pos, Police.INVESTIGATE_TIME, 40.0):
				lured += 1
	if lured > 0 and not _wail_warned:
		_wail_warned = true
		toast.emit("器灵的哀嚎引来了警察！\n快离开原地，或按 E 让器灵安静下来。", 4.5)


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
	if not Game.mission_complete:
		Audio.play("denied", -8.0)
		toast.emit("出口还锁着：必须带上任务目标才能撤离。")
		return
	# 大英博物馆：撤离前自动播双羊最后一段（若还没播完），播完才撤离。
	if level_id == "british_museum" and _should_trigger_zun_stage3():
		_trigger_zun_stage3()
		return
	_end_escape()


func _end_escape() -> void:
	_ended = true
	Audio.play("escape", -5.0)
	escaped.emit()


## 是否需要在出口前自动补播双羊文物志。
func _should_trigger_zun_stage3() -> bool:
	if _zun_stage3_triggered:
		return false
	if not Lore.has_lore("ram_zun"):
		return false
	var stage := Game.lore_stage_of("ram_zun")
	return stage < Lore.stage_count("ram_zun")


func _trigger_zun_stage3() -> void:
	_zun_stage3_triggered = true
	var stage := Game.lore_stage_of("ram_zun")
	_pending_zun_stage = stage
	lore_requested.emit("ram_zun", stage)


## 文物志对谈结束后的回调（main.gd 在 advance_lore_stage 后调用）。
func on_lore_finished(item_id: String) -> void:
	if item_id != "ram_zun":
		return
	# 双羊最后一段播完后，标记信任并停止本局哀嚎。
	if Game.lore_stage_of("ram_zun") >= Lore.stage_count("ram_zun"):
		Game.set_story_flag("zun_trusted")
		if ghost != null and is_instance_valid(ghost):
			ghost.calm(999999.0)
	# 若这是出口前的兜底触发，播完继续撤离流程。
	if _pending_zun_stage >= 0:
		_pending_zun_stage = -1
		if not _ended and Game.mission_complete:
			_end_escape()


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


func _tile_char(x: int, y: int) -> String:
	if y < 0 or y >= tiles.size():
		return " "
	var row: String = tiles[y]
	if x < 0 or x >= row.length():
		return " "
	return row[x]


func _is_walkable_at(x: int, y: int) -> bool:
	return not is_cell_blocked(x, y)


func _is_solid_at(x: int, y: int) -> bool:
	var ch := _tile_char(x, y)
	return ch == "#" or ch == "o" or ch == "d" or ch == "p" or ch == "T" or ch == "a"


func _is_carpet_at(x: int, y: int) -> bool:
	return _tile_char(x, y) == "~"


func _is_bm_room(x: int, y: int) -> bool:
	if level_id != "british_museum":
		return false
	if y < 0 or y >= _room_of_tile.size():
		return false
	var row: Array = _room_of_tile[y]
	if x < 0 or x >= row.size():
		return false
	return BM_THEMES.has(int(row[x]))


func _bm_rect(index: int) -> Rect2:
	return Rect2((index % BM_COLS) * TILE, (index / BM_COLS) * TILE, TILE, TILE)


## 墙/展柜下方的地面投影：强化“这里是可走地面”的读图线索。
func _draw_wall_shadow_on_floor(x: int, y: int, rect: Rect2) -> void:
	if not _is_solid_at(x, y - 1):
		return
	draw_rect(Rect2(rect.position, Vector2(TILE, 3)), Color(0, 0, 0, 0.22), true)
	draw_rect(Rect2(rect.position, Vector2(TILE, 1)), Color(0, 0, 0, 0.32), true)


## 只负责大英博物馆的房间主题瓦片；返回 false 时由默认绘制流程接管。
func _draw_bm_tile(ch: String, x: int, y: int, rect: Rect2, room: int) -> bool:
	var theme: Dictionary = BM_THEMES.get(room, BM_THEMES[3])
	var floors: Array = theme["floor"]
	var floor_index: int = int(floors[(x * 3 + y * 5) % floors.size()])
	match ch:
		".", "P", "X", "1", "2", "3", "4", "5", "6", "7", "8", "9":
			draw_texture_rect_region(BM_TILES, rect, _bm_rect(floor_index))
			_draw_wall_shadow_on_floor(x, y, rect)
			if ch == "X":
				draw_texture_rect(TEX_EXIT, rect, false)
			return true
		"~":
			var carpet: int = int(theme.get("carpet", -1))
			var carpet_edge: int = int(theme.get("carpet_edge", -1))
			if carpet < 0:
				draw_texture_rect_region(BM_TILES, rect, _bm_rect(floor_index))
				return true
			var edge := (
				not _is_carpet_at(x - 1, y)
				or not _is_carpet_at(x + 1, y)
				or not _is_carpet_at(x, y - 1)
				or not _is_carpet_at(x, y + 1)
			)
			draw_texture_rect_region(BM_TILES, rect, _bm_rect(carpet_edge if edge else carpet))
			_draw_wall_shadow_on_floor(x, y, rect)
			return true
		"#":
			var walls: Array = theme["wall"]
			draw_texture_rect_region(BM_TILES, rect, _bm_rect(int(walls[(x + y) % walls.size()])))
			if _is_walkable_at(x, y + 1):
				draw_texture_rect_region(BM_TILES, rect, _bm_rect(int(theme["trim"])))
			# 墙底阴影：让墙看起来是“立起来的”，地面是平的
			draw_rect(Rect2(rect.position + Vector2(0, TILE - 2), Vector2(TILE, 2)), Color(0, 0, 0, 0.32), true)
			return true
		"W":
			var walls_w: Array = theme["wall"]
			draw_texture_rect_region(BM_TILES, rect, _bm_rect(int(walls_w[0])))
			draw_texture_rect_region(BM_TILES, rect, _bm_rect(int(theme["scroll"])))
			return true
		"L":
			var walls_l: Array = theme["wall"]
			draw_texture_rect_region(BM_TILES, rect, _bm_rect(int(walls_l[0])))
			draw_texture_rect_region(BM_TILES, rect, _bm_rect(int(theme["lamp"])))
			return true
		"o":
			draw_texture_rect_region(BM_TILES, rect, _bm_rect(BM_COLUMN_MID))
			if _is_walkable_at(x, y + 1):
				draw_texture_rect_region(BM_TILES, rect, _bm_rect(BM_COLUMN_BASE))
			if not _is_walkable_at(x, y - 1):
				draw_texture_rect_region(BM_TILES, rect, _bm_rect(BM_COLUMN_TOP))
			return true
		"d":
			var horiz := _is_solid_at(x - 1, y) or _is_solid_at(x + 1, y)
			var vert := _is_solid_at(x, y - 1) or _is_solid_at(x, y + 1)
			var case_index: int = int(theme["case_h"])
			if vert and not horiz:
				case_index = int(theme["case_v"])
			draw_texture_rect_region(BM_TILES, rect, _bm_rect(case_index))
			return true
		"r":
			draw_texture_rect_region(BM_TILES, rect, _bm_rect(BM_ROPE))
			if _tile_char(x - 1, y) != "r":
				draw_texture_rect_region(BM_TILES, rect, _bm_rect(BM_ROPE_POST))
			if _tile_char(x + 1, y) != "r":
				draw_texture_rect_region(BM_TILES, rect, _bm_rect(BM_ROPE_POST))
			return true
		"p", "T", "a":
			draw_texture_rect_region(BM_TILES, rect, _bm_rect(floor_index))
			draw_texture_rect_region(
				BM_PROPS, Rect2(rect.position + Vector2(-8, -16), Vector2(32, 32)), BM_PEDESTAL_REGION
			)
			return true
		"s":
			draw_texture_rect_region(BM_TILES, rect, _bm_rect(floor_index))
			draw_texture_rect(TEX_STATUE, rect, false)
			return true
		"v":
			draw_texture_rect_region(BM_TILES, rect, _bm_rect(floor_index))
			draw_texture_rect(TEX_PLANT, rect, false)
			return true
	return false


## 叠加纯视觉装饰；不改碰撞、不影响玩法判定。
func _build_bm_decor() -> void:
	if level_id != "british_museum":
		return
	for room in BM_DECOR:
		if not BM_THEMES.has(room):
			continue
		for item in BM_DECOR[room]:
			var key := String(item["tex"])
			var tex: Texture2D = BM_DECOR_TEX.get(key)
			if tex == null:
				continue
			var spr := Sprite2D.new()
			spr.name = "BMDecor_%d_%d" % [room, bm_decor_count]
			spr.texture = tex
			var cell: Vector2i = item["cell"]
			spr.position = _cell_center(cell.x, cell.y) + (item["offset"] as Vector2)
			add_child(spr)
			if BM_SOLID_DECOR.has(key):
				var body := StaticBody2D.new()
				body.name = "BMDecorSolid_%d" % bm_solid_decor_count
				body.collision_layer = 1
				body.collision_mask = 0
				var shape := CollisionShape2D.new()
				var rect := RectangleShape2D.new()
				rect.size = BM_SOLID_DECOR[key]
				shape.shape = rect
				body.position = spr.position
				body.add_child(shape)
				add_child(body)
				bm_solid_decor_count += 1
			match key:
				"security_camera":
					_bm_cameras.append(spr)
				"alarm_beacon":
					_bm_beacons.append(spr)
				"skylight_panel":
					_bm_skylights.append(spr)
			bm_decor_count += 1


## Room 3 光影收口：尘埃、展柜玻璃高光、双羊尊地面倒影。
func _build_bm_atmosphere() -> void:
	if level_id != "british_museum":
		return
	var target_pos := _cell_center(10, 20)
	for child in get_children():
		if child is Artifact and child.item_id == target_item_id():
			target_pos = child.position
			break
	var dust := CPUParticles2D.new()
	dust.name = "BMDust"
	dust.position = target_pos
	dust.amount = 36
	dust.lifetime = 6.0
	dust.preprocess = 6.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(140, 80)
	dust.direction = Vector2(0, -1)
	dust.spread = 25.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 2.0
	dust.initial_velocity_max = 8.0
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.2
	dust.color = Color(1.0, 0.9, 0.72, 0.35)
	add_child(dust)
	var reflection := Sprite2D.new()
	reflection.name = "BMZunReflection"
	reflection.texture = BM_ZUN_ICON
	reflection.flip_v = true
	reflection.modulate = Color(1, 1, 1, 0.16)
	reflection.position = target_pos + Vector2(0, 34)
	add_child(reflection)
	var glint := Line2D.new()
	glint.name = "BMGlassGlint"
	glint.points = PackedVector2Array([Vector2(-9, -20), Vector2(2, 20)])
	glint.width = 1.0
	glint.default_color = Color(0.8, 1.0, 1.0, 0.5)
	glint.position = target_pos + Vector2(0, -6)
	add_child(glint)
	_bm_glints.append(glint)


func _animate_bm_decor() -> void:
	var t := _bm_time
	for i in _bm_cameras.size():
		_bm_cameras[i].rotation = sin(t * 0.5 + i * 1.7) * 0.35
	for i in _bm_beacons.size():
		_bm_beacons[i].modulate.a = 0.55 + 0.45 * sin(t * 3.2 + i)
	for i in _bm_skylights.size():
		_bm_skylights[i].modulate.a = 0.78 + 0.16 * sin(t * 0.9 + i * 0.8)
	for glint in _bm_glints:
		glint.modulate.a = 0.25 + 0.35 * absf(sin(t * 1.4))


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
			if _is_bm_room(x, y) and _draw_bm_tile(ch, x, y, rect, int(_room_of_tile[y][x])):
				continue
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
