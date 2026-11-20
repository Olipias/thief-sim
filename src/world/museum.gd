class_name Museum
extends Node2D
## Builds and runs the museum heist level from src/levels/museum_map.json.

signal escaped(outcome: String)
signal caught
signal toast(text: String)
signal prompt_changed(text: String)
signal alert_changed(level: int)
signal failure_banner_changed(reason: String)
signal dialogue_requested(lines: Array)
## 请求进入互动特写层（2.5D）
signal closeup_requested(item_id: String)
## 剧情单卡/短句请求（BM Room 3 标签、留言等；由 main 用 DialogueTree 播放）。
signal story_requested(lines: Array, cards: Dictionary, on_finished: Callable)

const TILE := 16
const SMOKE_RADIUS := 72.0
const SMOKE_BLIND_TIME := 3.5
## 器灵对谈冷却（秒）：防同帧双触发——对谈关闭解除暂停的同一帧，
## 本 _process 的 E 轮询仍可能读到同一个按键（is_action_just_pressed 的边界
## 在同一帧内对 physics/process 两侧都可能成立），把刚关的对谈再打开。
## 与 player.gd / main.gd 的交互冷却同一思路。
const TALK_COOLDOWN := 0.25
const WALKABLE := ".~TapXP123456789"
const NIGHT_TINT := Color(0.33, 0.37, 0.55)
const NIGHT_TINT_BM := Color(0.46, 0.50, 0.66)  ## 大英博物馆：冷夜但保留展厅可读性
## 大英博物馆六厅色温表（CanvasModulate 目标色）。切房间时一次性平滑插值，纯画面。
const BM_ROOM_TINTS := {
	0: Color(0.48, 0.50, 0.64),  # 入口：中性偏暖冷
	1: Color(0.43, 0.50, 0.68),  # 瓷器：冷青
	2: Color(0.49, 0.50, 0.62),  # 玉器书画：暖
	3: Color(0.46, 0.50, 0.66),  # 青铜礼器厅：基准
	4: Color(0.51, 0.50, 0.60),  # 丝路：沙暖
	5: Color(0.44, 0.51, 0.68),  # 装卸区：冷白
}
const TINT_LERP_RATE := 3.0
## V-01 T1/T2：外部素材（EXTERNAL_ART_REQUEST_P0）。文件不存在时整段跳过，纯画面。
const BM_WALL_TRIM_PATH := "res://assets/sprites/bm/bm_wall_trim.png"  # 64×64，4×4 格；实测第 1 列（索引 1/5/9/13）为底边踢脚线条
const BM_FLOOR_WEAR_PATH := "res://assets/sprites/bm/bm_floor_wear.png"  # 64×32，4×2 格
const BM_ROOM_DECOR_KEYS := ["china", "egypt", "greek", "silk", "jade", "dock"]  # 房间序号 0..5 对应 decor_bm_<key>.png
const BM_ROOM_DECOR_COUNT := 3
const BM_FLOOR_WEAR_ENABLED := false  # 素材每格带不透明格线，叠在地面像深色方块；待 art 重做无框/透明版后再开
const BM_FLOOR_WEAR_RATE := 5  # 约 1/5 的地砖叠磨损
const SHADOW_NO_OCCLUDER := " LTa"  ## 虚空/壁灯格/文物格不放遮光体（灯与发光点在其中）
const ARTIFACT_POOL: Array[String] = ["vase", "gem", "scroll", "ingot", "jade"]
## BM Room 3 剧情触发器：馆方标签与观众留言。
## 贴左右墙边，避免与双羊尊展台（T≈(152,296)）的交互半径重叠导致无法拾取。
const BM_LABEL_POS := Vector2(40, 296)
const BM_NOTE_POS := Vector2(280, 296)
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
	"security_gate": preload("res://assets/sprites/bm/decor_noir/security_gate.png"),
	"ticket_desk": preload("res://assets/sprites/bm/decor_noir/ticket_desk.png"),
	"museum_map": preload("res://assets/sprites/bm/decor_noir/museum_map.png"),
	"vase_case": preload("res://assets/sprites/bm/decor_noir/vase_case.png"),
	"jade_case": preload("res://assets/sprites/bm/decor_noir/jade_case.png"),
	"scroll_case": preload("res://assets/sprites/bm/decor_noir/scroll_case.png"),
	"lacquer_cabinet": preload("res://assets/sprites/bm/decor_noir/lacquer_cabinet.png"),
	"mural_panel": preload("res://assets/sprites/bm/decor_noir/mural_panel.png"),
	"crate_stack": preload("res://assets/sprites/bm/decor_noir/crate_stack.png"),
	"pallet": preload("res://assets/sprites/bm/decor_noir/pallet.png"),
	"forklift": preload("res://assets/sprites/bm/decor_noir/forklift.png"),
	"pipe_panel": preload("res://assets/sprites/bm/decor_noir/pipe_panel.png"),
	"bench": preload("res://assets/sprites/bm/decor_noir/bench.png"),
	"security_camera": preload("res://assets/sprites/bm/decor_noir/security_camera.png"),
	"alarm_beacon": preload("res://assets/sprites/bm/decor_noir/alarm_beacon.png"),
	"skylight_panel": preload("res://assets/sprites/bm/decor_noir/skylight_panel.png"),
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
const BM_TILES := preload("res://assets/sprites/bm/bm_tiles_noir.png")
const BM_PROPS := preload("res://assets/sprites/bm/bm_props.png")
const BM_CASE := preload("res://assets/sprites/bm/bm_case_noir.png")
const BM_CASE_HIGHLIGHT := preload("res://assets/sprites/bm/case_glass_highlight.png")  # 32×32 斜向玻璃高光（C3，纯画面）
const BM_ZUN_ICON := preload("res://assets/sprites/bm/bm_zun_32.png")
const PLAYER_SCENE := preload("res://src/actors/player.tscn")
const POLICE_SCENE := preload("res://src/actors/police.tscn")
const ARTIFACT_SCENE := preload("res://src/world/artifact.tscn")
const SMOKE_SCENE := preload("res://src/world/smoke_puff.tscn")
const SmokePuffClass := preload("res://src/world/smoke_puff.gd")

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
var _talk_cooldown := 0.0
var _noise_warned := false
var _patrol_hint_shown := false
var current_room := -1
var visited_rooms := {}
var target_room := -1
var exit_room := -1
var _room_of_tile: Array = []
## 每个格子的迷雾分区索引：房间优先，再按 floors（走廊）补齐；未分区为 -1。
var _zone_of_tile: Array = []
## 已揭示分区（房间/走廊）。key = zone_index。
var _visited_zones := {}
var bm_decor_count := 0
var _bm_time := 0.0
var _bm_cameras: Array[Node2D] = []
var _bm_beacons: Array[Node2D] = []
var _bm_skylights: Array[Node2D] = []
var _bm_glints: Array[Node2D] = []
var _bm_case_highlights: Array[Node2D] = []
var bm_solid_decor_count := 0

## 路线预演系统（P1）：规划节点、自动执行、失败回放。
var planning_mode := false
var executing_plan := false
var _drag_plan_index := -1
var planned_points: Array[Vector2] = []
var plan_point_index := 0
## 只暂停世界子节点；Museum保留输入处理，让规划和失败回放仍可操作。
var _frozen_process_modes: Dictionary = {}
var _frozen_collision_modes: Dictionary = {}
const MAX_PLAN_POINTS := 5
const PLAN_POINT_RADIUS := 5.0
const CAMERA_VISION_RANGE := 112.0
const CAMERA_VISION_HALF_ANGLE := deg_to_rad(42.0)
const FAILURE_REPLAY_FREEZE := 0.6

var failure_replay := false
var failure_reason := ""
var failure_detector: Node2D = null
var failure_line_start: Vector2 = Vector2.ZERO
var failure_line_end: Vector2 = Vector2.ZERO
var _failure_replay_timer := 0.0
var _failure_overlay: Node2D = null
var _mouse_left_was_pressed := false
var _mouse_right_was_pressed := false
var _room_entry_pos: Vector2 = Vector2.ZERO

## 节点动作：与 planned_points 一一对应；""/wait/crouch/stand/unlock/take/sprint。
var _plan_node_actions: Array[String] = []
var _selected_plan_index := -1
var _plan_drag_start := Vector2.ZERO

## R-02b 确定性执行：从同一起始快照驱动真实场景。
var _run_start_snapshot: Dictionary = {}
var _run_start_planned_points: Array[Vector2] = []
var _run_start_node_actions: Array[String] = []
var _sim_snapshot: Dictionary = {}
var _sim_route: Array = []
var _sim_index: Dictionary = {"i": 0}
var _sim_time := 0.0
var _sim_context: Dictionary = {}
var _pre_exec_ai_states: Dictionary = {}

## BM Room 3 的剧情触发器（馆方标签 / 观众留言）。
var _story_triggers: Array[Area2D] = []
## 本局已读过的剧情触发器：group -> true。
var _story_trigger_read: Dictionary = {}
## 上一次响应的剧情触发器；离开其范围后才允许再次按 E 重读（防止 _finish_story_tree 反复打开）。
var _last_story_trigger: Area2D = null
var _night_tint: CanvasModulate = null
var _tex_wall_trim: Texture2D = null
var _tex_floor_wear: Texture2D = null
## 画面层开关：灯光阴影（测试/低配可关）。
var shadows_enabled := true


func _ready() -> void:
	y_sort_enabled = true
	_tex_wall_trim = _load_optional(BM_WALL_TRIM_PATH)
	_tex_floor_wear = _load_optional(BM_FLOOR_WEAR_PATH)
	_load_map()
	_build_room_lookup()
	_build_level()
	_sync_visited_zones()
	if _night_tint != null:
		_night_tint.color = _target_tint()  # 开场直接落在起始房间色温，不从基准色滑入
	_build_bm_decor()
	_build_bm_atmosphere()
	add_to_group("active_heist")
	_build_failure_overlay()
	# 关卡入口相机就位：上一个场景（如安全屋）的相机可能处于不同世界位置，
	# 关闭平滑让视角立即落在入口房间，避免开场镜头从别处滑入。
	if player != null:
		var entry_cam: Camera2D = player.get_node_or_null("Camera2D")
		if entry_cam != null:
			entry_cam.reset_smoothing()


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
	_zone_of_tile.clear()
	for y in tiles.size():
		var row: Array = []
		var line: String = tiles[y]
		for x in line.length():
			row.append(room_index_at(_cell_center(x, y)))
		_room_of_tile.append(row)

	# zone = 房间优先；未命中房间的走廊按 floors 顺序编号。
	for y in tiles.size():
		var line: String = tiles[y]
		var zrow: Array = []
		for x in line.length():
			var zone := int(_room_of_tile[y][x])
			if zone < 0:
				var p := _cell_center(x, y)
				for i in floors.size():
					if floors[i].has_point(p):
						zone = rooms.size() + i
						break
			zrow.append(zone)
		_zone_of_tile.append(zrow)


func _map_path() -> String:
	var info: Dictionary = Game.LEVELS.get(level_id, {})
	return String(info.get("map", "res://src/levels/museum_map.json"))


func target_item_id() -> String:
	# 优先使用 Game 当前任务目标（支持大英博物馆动态切换目标）。
	if Game.current_level_id == level_id:
		return Game.mission_target_id
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
					_spawn_artifact("ram_zun" if level_id == "british_museum" else target_item_id(), pos)
				"a":
					if level_id == "british_museum":
						var room_id := room_index_at(pos)
						var local_cell := Vector2i((pos - rooms[room_id].position) / TILE)
						if room_id == 1 and local_cell == Vector2i(9, 8):
							_spawn_artifact("egypt_heart_scarab", pos)
						elif room_id == 4 and local_cell == Vector2i(16, 9):
							_spawn_artifact("akrotiri_askos", pos)
					else:
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
	modulate.color = _target_tint()
	add_child(modulate)
	_night_tint = modulate


## 当前房间的目标色温；非大英关卡沿用单一夜色。
func _target_tint() -> Color:
	if level_id != "british_museum":
		return NIGHT_TINT
	return BM_ROOM_TINTS.get(current_room, NIGHT_TINT_BM)


func _update_night_tint(delta: float) -> void:
	if _night_tint == null:
		return
	_night_tint.color = _night_tint.color.lerp(_target_tint(), 1.0 - exp(-TINT_LERP_RATE * delta))


func _add_light(pos: Vector2, color: Color, energy: float, scale: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = TEX_LIGHT_SOFT
	light.color = color
	light.energy = energy
	light.texture_scale = scale
	light.position = pos
	if level_id == "british_museum" and shadows_enabled:
		light.shadow_enabled = true  # 只画面：遮光体不参与任何判定
		light.shadow_color = Color(0, 0, 0, 0.55)
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
	_build_light_occluders()


## 墙/展柜遮光体：同行连续格合并成一个矩形，只属画面层（无碰撞、不进模拟）。
func _build_light_occluders() -> void:
	if level_id != "british_museum" or not shadows_enabled:
		return
	var holder := Node2D.new()
	holder.name = "LightOccluders"
	add_child(holder)
	for y in tiles.size():
		var row: String = tiles[y]
		var x := 0
		while x < row.length():
			if not is_cell_blocked(x, y) or SHADOW_NO_OCCLUDER.contains(row[x]):
				x += 1
				continue
			var x0 := x
			while x < row.length() and is_cell_blocked(x, y) and not SHADOW_NO_OCCLUDER.contains(row[x]):
				x += 1
			var occ := LightOccluder2D.new()
			var poly := OccluderPolygon2D.new()
			var r := Rect2(x0 * TILE, y * TILE, (x - x0) * TILE, TILE)
			poly.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
			occ.occluder = poly
			holder.add_child(occ)


func _spawn_player(pos: Vector2) -> void:
	player = PLAYER_SCENE.instantiate() as Player
	player.position = pos
	ContactShadow.attach(player)
	player.used_item.connect(_on_player_used_item)
	player.made_noise.connect(_on_player_made_noise)
	player.inspect_requested.connect(func(item_id: String) -> void: closeup_requested.emit(item_id))
	player.story_trigger_requested.connect(_on_story_trigger_requested)
	add_child(player)
	_room_entry_pos = pos


func _spawn_artifact(item_id: String, pos: Vector2) -> void:
	var cell := _world_to_cell(pos)
	var instance_id := _make_instance_id(item_id, cell)
	# 已带出的普通战利品不再刷新；已完成关卡的主目标也不再刷新。
	if Game.is_item_taken(level_id, instance_id):
		return
	if item_id == target_item_id() and Game.story_flag("completed_" + level_id):
		return
	if item_id == target_item_id() and level_id == "british_museum":
		_add_bm_display_case(pos)
	var artifact := ARTIFACT_SCENE.instantiate() as Artifact
	artifact.item_id = item_id
	artifact.instance_id = instance_id
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


func _make_instance_id(item_id: String, cell: Vector2i) -> String:
	if item_id == target_item_id():
		return "%s:target:%d,%d" % [level_id, cell.x, cell.y]
	return "%s:%d,%d" % [level_id, cell.x, cell.y]


## Room 3 的玻璃展柜 + 暖光，只做一次（目标被丢下再拾取时不重复生成）。
func _add_bm_display_case(pos: Vector2) -> void:
	if has_node("BMDisplayCase"):
		return
	var display_case := Sprite2D.new()
	display_case.name = "BMDisplayCase"
	display_case.texture = BM_CASE
	display_case.position = pos + Vector2(0, -10)
	add_child(display_case)
	# C3 玻璃高光：作为展柜子节点，排序紧随展柜，文物本体（后加入、y 更大）画在其上，不会被遮。
	var highlight := Sprite2D.new()
	highlight.name = "BMCaseHighlight"
	highlight.texture = BM_CASE_HIGHLIGHT
	highlight.position = Vector2(0, -6)
	highlight.z_index = 1  # 压在文物之上才看得见；贴图是细斜纹，不挡文物主体
	highlight.modulate.a = 0.5
	display_case.add_child(highlight)
	_bm_case_highlights.append(highlight)
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
		{"speaker": "", "text": "你读完馆方说明，把目光移向玻璃展柜。标签上的字很小：1936,1118.1。"},
		{"speaker": "", "text": "档案里只写到这一年：它随一位英国收藏家的旧藏进入大英博物馆。再往前，纸页是空的。"},
	]


func _note_lines() -> Array:
	return [
		{"card": "zun_note"},
		{"speaker": "", "text": "观众留言只有一句话：1860，圆明园。别忘了。"},
		{"speaker": "", "text": "墨水是新的，但年份是旧的。"},
	]


func _both_read_lines() -> Array:
	return [
		{"speaker": "", "text": "你看着展签上的 1936 编号，又看着围栏上的 1860 留言。"},
		{"speaker": "", "text": "一个写着入藏与购买；一个写着掠夺与大火。哪一个是你写进调查笔记的依据？"},
		{
			"choices": [
				{"text": "编号。它有日期。", "goto": "num"},
				{"text": "火。它有恨。", "goto": "fire"},
				{"text": "都不够。", "goto": "none"},
				{"text": "都信。也都不全信。", "goto": "both"},
			]
		},
		{"label": "num"},
		{"speaker": "", "text": "你选择相信编号。它有日期、有交易记录、有大英博物馆的馆藏档案。"},
		{"goto": "end"},
		{"label": "fire"},
		{"speaker": "", "text": "你选择相信火。1860 年的圆明园，是许多人记忆中无法被编号抹去的伤口。"},
		{"goto": "end"},
		{"label": "none"},
		{"speaker": "", "text": "你觉得两者都不够。编号不解释来源，留言也不算证据。"},
		{"goto": "end"},
		{"label": "both"},
		{"speaker": "", "text": "你把两者都写进笔记：编号是事实，火是记忆；真相也许就在它们之间的空白里。"},
		{"goto": "end"},
		{"label": "end"},
		{"speaker": "", "text": "你合上笔记本。展厅的灯还亮着，但时间不多。"},
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
	ContactShadow.attach(cop)
	var path: Array = patrols.get(id, [])
	var points: Array[Vector2] = []
	for p in path:
		points.append(_cell_center(int(p[0]), int(p[1])))
	cop.patrol_points = points
	if level_id == "museum":
		cop.spot_delay_scale = 1.6  # 教学关：守卫反应更慢，提高容错
	cop.caught.connect(_on_police_caught)
	cop.spotted_player.connect(_on_police_spotted.bind(cop))
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


func _is_zone_revealed(zone: int) -> bool:
	return zone >= 0 and bool(_visited_zones.get(zone, false))


func _is_adjacent_to_revealed_zone(x: int, y: int) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + int(dx)
			var ny: int = y + int(dy)
			if ny < 0 or ny >= _zone_of_tile.size() or nx < 0 or nx >= _zone_of_tile[ny].size():
				continue
			if _is_zone_revealed(int(_zone_of_tile[ny][nx])):
				return true
	return false


func room_index_at(pos: Vector2) -> int:
	for i in rooms.size():
		if rooms[i].has_point(pos):
			return i
	return -1


## 从跨次存档同步当前关卡的已探分区（房间+走廊）。
func _sync_visited_zones() -> void:
	visited_rooms.clear()
	_visited_zones.clear()
	var saved: Dictionary = Game.level_visited_rooms.get(level_id, {})
	for idx in saved:
		if bool(saved[idx]):
			_visited_zones[int(idx)] = true
			var room_idx := int(idx)
			if room_idx >= 0 and room_idx < rooms.size():
				visited_rooms[room_idx] = true
	# 当前分区立即标记（玩家一定从入口开始，入口属于已探）。
	if player != null:
		var z := _zone_at(player.global_position)
		if z >= 0:
			_mark_zone_visited(z)


func _zone_at(pos: Vector2) -> int:
	var tx := int(pos.x / TILE)
	var ty := int(pos.y / TILE)
	if ty < 0 or ty >= _zone_of_tile.size() or tx < 0 or tx >= _zone_of_tile[ty].size():
		return -1
	return int(_zone_of_tile[ty][tx])


func _mark_zone_visited(zone: int) -> void:
	if zone < 0:
		return
	if not _visited_zones.has(zone):
		_visited_zones[zone] = true
		Game.mark_room_visited(level_id, zone)
		if zone < rooms.size():
			visited_rooms[zone] = true


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


func _physics_process(delta: float) -> void:
	# 自动路线：在物理帧尾立即推进到下一节点，避免 process 顺序导致
	# 执行态与 auto_moving 不同步的瞬态被 monkey 不变量抓到。
	_update_plan_execution()
	if executing_plan and not failure_replay and not _ended:
		_sim_time += delta
		var step_seconds := 1.0 / SimPreview.TICK_RATE
		var guard := 0
		while _sim_time >= step_seconds and guard < 4:
			_sim_time -= step_seconds
			_sim_step()
			guard += 1
			if not executing_plan:
				break


func _process(delta: float) -> void:
	_update_night_tint(delta)
	if not is_world_frozen() and not executing_plan:
		# 执行模式由确定性内核统一推进装饰动画时间，避免渲染帧率影响规则状态。
		_bm_time += delta
		_animate_bm_decor()
		# 世界暂停时，交互冷却也保持不变。
		_talk_cooldown = maxf(0.0, _talk_cooldown - delta)
	if failure_replay:
		_process_failure_replay(delta)
		return
	if player == null or _ended:
		return
	var z := _zone_at(player.global_position)
	if z != -1:
		_mark_zone_visited(z)
	var idx := room_index_at(player.global_position)
	if idx != -1 and idx != current_room:
		current_room = idx
		visited_rooms[idx] = true
		_room_entry_pos = player.global_position
		_apply_camera_limits(rooms[idx])
		if not _patrol_hint_shown and _room_has_police(idx):
			_patrol_hint_shown = true
			toast.emit("前面有守卫在巡逻——先看清手电光锥的方向，再贴着边走。")
	# 规划/执行模式：监控由内核统一检测；规划模式世界冻结不推进感知。
	if not planning_mode and not executing_plan:
		_check_camera_detection()
	_process_planning_input()
	_update_plan_execution()
	var prompt := ""
	if planning_mode:
		prompt = "规划：左键加/选节点（点选切动作）· 右键删 · 空格执行 · Tab/R 退出"
	elif executing_plan:
		prompt = "执行中：按方向键或 E 接管"
	elif player != null and player.crouching:
		prompt = "蹲下潜行中（C/Ctrl 解除）"
	else:
		var nearest_trigger := _nearest_story_trigger()
		if nearest_trigger != null:
			var data: Dictionary = nearest_trigger.get_meta("story_data", {})
			prompt = "按 E 阅读：%s" % data.get("prompt", "")
		else:
			var target_name: String = player.interactable_name()
			prompt = "按 E 拾取：%s" % target_name if target_name != "" else ""
	if prompt != _last_prompt:
		_last_prompt = prompt
		prompt_changed.emit(prompt)
	# R-02 预演：规划模式下每次节点变动实时重算（纯整数运算，开销可忽略）。
	if planning_mode:
		run_preview()


func _room_has_police(idx: int) -> bool:
	for cop in police:
		if is_instance_valid(cop) and room_index_at(cop.global_position) == idx:
			return true
	return false


func _process_planning_input() -> void:
	if player == null or _ended:
		return

	# 失败回放：定格期后按 E / Space 回退重规划
	if failure_replay:
		if _failure_replay_timer >= FAILURE_REPLAY_FREEZE and (
			Input.is_action_just_pressed("plan_execute") or Input.is_action_just_pressed("interact")
		):
			_failure_replay_timer = 0.0
			_rewind_and_replan()
		return

	# Tab / R 切换规划模式
	if Input.is_action_just_pressed("plan_toggle"):
		if planning_mode:
			toggle_planning_mode(false)
		elif not executing_plan:
			toggle_planning_mode(true)
		return

	# 规划模式下：空格执行（鼠标左右键在 _unhandled_input 中处理，使用事件坐标）。
	if planning_mode:
		if Input.is_action_just_pressed("plan_execute") and planned_points.size() >= 1:
			execute_plan()
		elif Input.is_action_just_pressed("plan_preview"):
			run_preview()
		return

	# 非规划/非执行：C / Ctrl 蹲下（按住式）
	if not executing_plan:
		player.set_crouch(Input.is_action_pressed("crouch"))


func _unhandled_input(event: InputEvent) -> void:
	if player == null or _ended or not planning_mode:
		return
	var mouse_position := Vector2.ZERO
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		mouse_position = get_viewport().get_canvas_transform().affine_inverse() * event.position
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_plan_index = -1
				_selected_plan_index = -1
				for i in planned_points.size():
					if planned_points[i].distance_to(mouse_position) < 7.0:
						_drag_plan_index = i
						_selected_plan_index = i
						_plan_drag_start = mouse_position
						break
				if _drag_plan_index < 0 and planned_points.size() < MAX_PLAN_POINTS and _is_walkable_world(mouse_position):
					_add_plan_point(mouse_position)
					_drag_plan_index = planned_points.size() - 1
			else:
				if _selected_plan_index >= 0 and _selected_plan_index < planned_points.size() and _plan_drag_start.distance_to(mouse_position) < 3.0:
					_cycle_node_action(_selected_plan_index)
				_drag_plan_index = -1
				_selected_plan_index = -1
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_remove_last_plan_point()
	elif event is InputEventMouseMotion and _drag_plan_index >= 0 and _drag_plan_index < planned_points.size():
		if _plan_drag_start.distance_to(mouse_position) >= 3.0:
			_selected_plan_index = -1
		if _is_walkable_world(mouse_position):
			planned_points[_drag_plan_index] = mouse_position
			queue_redraw()


func _is_walkable_world(pos: Vector2) -> bool:
	var cx := int(pos.x / TILE)
	var cy := int(pos.y / TILE)
	return _is_walkable_at(cx, cy)


func is_world_frozen() -> bool:
	return planning_mode or failure_replay or _ended


## 所有规划/执行/接管/回放/结束路径共用的恢复入口，不改守卫原AI开关或巡逻进度。
func _sync_world_freeze() -> void:
	var frozen := is_world_frozen()
	if player != null:
		player.controls_enabled = not frozen
		if frozen:
			player.auto_moving = false
			player.velocity = Vector2.ZERO
	for cop in police:
		if is_instance_valid(cop):
			cop.set_frozen(frozen)
	if frozen:
		for child in get_children():
			if child == _failure_overlay or _frozen_process_modes.has(child):
				continue
			_keep_frozen_collisions(child)
			_frozen_process_modes[child] = child.process_mode
			child.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		for child in _frozen_process_modes:
			if is_instance_valid(child):
				child.process_mode = _frozen_process_modes[child]
		_frozen_process_modes.clear()
		for body in _frozen_collision_modes:
			if is_instance_valid(body):
				body.disable_mode = _frozen_collision_modes[body]
		_frozen_collision_modes.clear()
	queue_redraw()


func _keep_frozen_collisions(node: Node) -> void:
	# 暂停处理不能把CharacterBody/Area移出物理世界；感知触发时可能还在当前物理回调中。
	if node is CollisionObject2D and not _frozen_collision_modes.has(node):
		_frozen_collision_modes[node] = node.disable_mode
		node.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	for child in node.get_children():
		_keep_frozen_collisions(child)


func toggle_planning_mode(on: bool) -> void:
	if _ended or failure_replay:
		return
	planning_mode = on
	executing_plan = false
	if player != null:
		player.auto_moving = false
		if on:
			player.set_crouch(false)
	_sync_world_freeze()
	queue_redraw()


func _add_plan_point(pos: Vector2) -> void:
	if planned_points.size() >= MAX_PLAN_POINTS:
		return
	planned_points.append(pos)
	_plan_node_actions.append("")
	queue_redraw()


func _remove_last_plan_point() -> void:
	if planned_points.is_empty():
		return
	planned_points.pop_back()
	if _plan_node_actions.size() > planned_points.size():
		_plan_node_actions.pop_back()
	queue_redraw()


const _ACTION_CYCLE: Array[String] = ["", "wait", "crouch", "unlock", "take", "sprint"]


func _cycle_node_action(index: int) -> void:
	if index < 0 or index >= _plan_node_actions.size():
		return
	var current := _plan_node_actions[index]
	var next := ""
	var found := false
	for action in _ACTION_CYCLE:
		if found:
			next = action
			break
		if action == current:
			found = true
	if not found:
		next = ""
	var cell := Vector2i(int(planned_points[index].x / TILE), int(planned_points[index].y / TILE))
	match next:
		"unlock":
			if not _is_door_cell(cell):
				toast.emit("此位置没有门锁，无法设置开锁。")
				next = ""
		"take":
			if not _is_target_cell(cell):
				toast.emit("此位置没有任务目标，无法设置拿取。")
				next = ""
	_plan_node_actions[index] = next
	queue_redraw()


func _is_door_cell(cell: Vector2i) -> bool:
	# 当前地图未配置独立门锁格；预留门字符 'D' 与显式 doors 注册。
	return _tile_char(cell.x, cell.y) == "D" or false


func _is_target_cell(cell: Vector2i) -> bool:
	for child in get_children():
		if child is Artifact and child.item_id == target_item_id():
			var item_cell := Vector2i(int(child.global_position.x / TILE), int(child.global_position.y / TILE))
			return item_cell == cell
	return false


func execute_plan() -> void:
	if planned_points.is_empty() or player == null or _ended or failure_replay:
		return
	_run_start_snapshot = _build_sim_snapshot()
	_run_start_planned_points = planned_points.duplicate()
	_run_start_node_actions = _plan_node_actions.duplicate()
	_sim_snapshot = SimPreview.copy_snapshot(_run_start_snapshot)
	_sim_route = _planned_sim_route()
	_sim_index = {"i": 0}
	_sim_time = 0.0
	_sim_context = _build_sim_context()
	_pre_exec_ai_states.clear()
	for cop in police:
		if is_instance_valid(cop):
			_pre_exec_ai_states[cop] = cop.ai_enabled
			cop.ai_enabled = false
	planning_mode = false
	executing_plan = true
	plan_point_index = 0
	# 进入执行态后、第一个内核 tick 应用新目标之前，player 的 sim 驱动分支
	# 会按 sim_target_pos 瞬移；旧值（上次执行残留或默认 (0,0)）可能落在墙体里，
	# 去穿透会把玩家顶出地图。先把目标钉在快照位置并清空方向，等待首个 tick。
	player.sim_target_pos = player.global_position
	player.sim_dir = Vector2.ZERO
	player.sim_driven = true
	_sync_world_freeze()
	queue_redraw()


func _update_plan_execution() -> void:
	if not executing_plan or player == null:
		return
	# 手动接管优先于内核推进；任何方向键、交互、使用道具都立即取消执行。
	if Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO or Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("use_item"):
		cancel_plan()


func cancel_plan() -> void:
	_finish_plan_execution(true)


func _finish_plan_execution(clear_route: bool = false) -> void:
	executing_plan = false
	planning_mode = false
	plan_point_index = 0
	_preview_active = false
	if player != null:
		player.auto_moving = false
		player.sim_driven = false
		player.velocity = Vector2.ZERO
	for cop in _pre_exec_ai_states:
		if is_instance_valid(cop):
			cop.ai_enabled = _pre_exec_ai_states[cop]
	_pre_exec_ai_states.clear()
	# 不清理 _sim_snapshot：失败后回退与测试都需要读取最终 tick 的事件与状态。
	# 下一次 execute_plan() 会重新构建新快照。
	_run_start_snapshot.clear()
	# 保留 _run_start_planned_points / _run_start_node_actions，供失败回退时还原路线。
	if clear_route:
		planned_points.clear()
		_plan_node_actions.clear()
	_sync_world_freeze()
	queue_redraw()


func _check_camera_detection() -> void:
	if player == null or failure_replay or _ended or planning_mode:
		return
	for cam in _bm_cameras:
		if cam == null or not is_instance_valid(cam):
			continue
		var facing := Vector2.RIGHT.rotated(cam.rotation)
		if Police.in_cone(cam.global_position, facing, player.global_position, CAMERA_VISION_RANGE, CAMERA_VISION_HALF_ANGLE):
			_on_player_detected(cam, "监控摄像头扇区")
			return


## 把真实世界状态转成 SimPreview 全快照（规划/执行/回退共用）。
func _build_sim_snapshot() -> Dictionary:
	var snap := SimPreview.default_snapshot()
	snap["decor_time"] = _bm_time
	if player != null:
		var p: Dictionary = snap["player"]
		p["pos"] = _world_to_cell(player.global_position)
		p["crouch"] = player.crouching
		p["move_interval"] = _ticks_per_cell(Player.WALK_SPEED)
		p["crouch_move_interval"] = _ticks_per_cell(Player.WALK_SPEED * Player.CROUCH_SPEED_MULTIPLIER)
		p["sprint_move_interval"] = _ticks_per_cell(Player.SPRINT_SPEED)

	snap["guards"] = []
	for cop in police:
		if not is_instance_valid(cop):
			continue
		var g := {
			"id": String(cop.name),
			"pos": _world_to_cell(cop.global_position),
			"waypoints": [],
			"wp_index": cop._patrol_index,
			"move_interval": _ticks_per_cell(Police.PATROL_SPEED),
			"move_counter": 0,
			"investigate_interval": _ticks_per_cell(Police.INVESTIGATE_SPEED),
			"chase_interval": _ticks_per_cell(Police.CHASE_SPEED),
			"wait_left": int(round(cop._wait_timer * SimPreview.TICK_RATE)),
			"facing": _facing_to_cell(cop._facing),
			"investigate_pos": _world_to_cell(cop._investigate_pos) if cop._investigate_pos != Vector2.ZERO else Vector2i(-1, -1),
			"investigate_left": int(round(cop._investigate_timer * SimPreview.TICK_RATE)),
			"alert": _state_to_alert(cop.state),
			"spot_timer": int(round(cop._spot_timer * SimPreview.TICK_RATE)),
			"spot_delay": int(round(cop._spot_delay() * SimPreview.TICK_RATE)),
			"blind_timer": int(round(cop._blind_timer * SimPreview.TICK_RATE)),
			"ai_enabled": cop.ai_enabled,
		}
		for pt in cop.patrol_points:
			g["waypoints"].append(_world_to_cell(pt))
		snap["guards"].append(g)

	snap["cameras"] = []
	for i in _bm_cameras.size():
		var cam: Node2D = _bm_cameras[i]
		if not is_instance_valid(cam):
			continue
		snap["cameras"].append({
			"id": String(cam.name),
			"pos": _world_to_cell(cam.global_position),
			"phase": _bm_time * 0.5 + i * 1.7,
			"sweep_speed": 0.5 * SimPreview.SECONDS_PER_TICK,
			"sweep_amp": 0.35,
			"range_cells": int(round(CAMERA_VISION_RANGE / TILE)),
			"half_angle": CAMERA_VISION_HALF_ANGLE,
		})

	snap["doors"] = {}  # 当前关卡未配置门锁，留空字典保持结构。
	snap["items"] = []
	for child in get_children():
		if child is Artifact:
			snap["items"].append({"id": child.item_id, "pos": _world_to_cell(child.global_position), "taken": false})

	snap["bag_items"] = Game.bag_items.duplicate(true)
	snap["smoke_count"] = Game.smoke_count
	snap["smoke_puffs"] = []
	for child in get_children():
		if child is SmokePuffClass:
			snap["smoke_puffs"].append({"pos": _world_to_cell(child.global_position), "time": child._t})
	return snap


func _world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x / TILE), int(pos.y / TILE))


func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE * 0.5, cell.y * TILE + TILE * 0.5)


func _ticks_per_cell(speed_px_per_sec: float) -> int:
	if speed_px_per_sec <= 0.0:
		return 1
	var tpc := SimPreview.TICK_RATE * TILE / speed_px_per_sec
	return clampi(int(round(tpc)), 1, 60)


func _facing_to_cell(facing: Vector2) -> Vector2i:
	if facing == Vector2.ZERO:
		return Vector2i(1, 0)
	var cell := Vector2i(signi(int(facing.x)), signi(int(facing.y)))
	if cell == Vector2i.ZERO:
		return Vector2i(1, 0)
	return cell


func _state_to_alert(state: Police.State) -> int:
	match state:
		Police.State.PATROL:
			return 0
		Police.State.INVESTIGATE:
			return 1
		Police.State.CHASE:
			return 2
	return 0


func _alert_to_state(alert: int) -> Police.State:
	match alert:
		1:
			return Police.State.INVESTIGATE
		2:
			return Police.State.CHASE
	return Police.State.PATROL


## 已规划节点 → SimPreview 路线（像素坐标转格坐标；每个节点附带动作）。
## 动作语义：wait/unlock/take 是到达后执行；crouch/sprint/stand 是到该节点的移动模式。
func _planned_sim_route() -> Array:
	var route: Array = []
	var last: Vector2i = _world_to_cell(player.global_position) if player != null else Vector2i.ZERO
	for i in planned_points.size():
		var cell := _world_to_cell(planned_points[i])
		var action := _plan_node_actions[i] if i < _plan_node_actions.size() else ""
		if cell != last:
			# 移动模式动作直接附加到移动段；姿态/停留动作在到达后执行。
			var move_action := action if action in ["crouch", "sprint", "stand"] else ""
			route.append({"pos": cell, "action": move_action, "ticks": 0, "done": 0})
			last = cell
			if move_action != "":
				continue
		if action != "" and action not in ["crouch", "sprint", "stand"]:
			route.append({"pos": cell, "action": action, "ticks": _default_action_ticks(action), "done": 0})
	return route


func _default_action_ticks(action: String) -> int:
	match action:
		"wait":
			return SimPreview.TICK_RATE  # 1 秒
		"crouch", "stand", "sprint":
			return SimPreview.TICK_RATE
		"unlock":
			return SimPreview.UNLOCK_TICKS + 5
		"take":
			return SimPreview.TAKE_TICKS + 5
	return 1


func _build_sim_context() -> Dictionary:
	return {
		"los_blocked": _sim_los_blocked,
		"same_room": _sim_same_room,
		"is_cell_blocked": _sim_is_cell_blocked,
	}


func _sim_is_cell_blocked(cell: Vector2i) -> bool:
	return is_cell_blocked(cell.x, cell.y)


func _sim_los_blocked(a: Vector2i, b: Vector2i) -> bool:
	var from := _cell_to_world(a)
	var to := _cell_to_world(b)
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty()


func _sim_same_room(a: Vector2i, b: Vector2i) -> bool:
	return Police.same_room(room_index_at(_cell_to_world(a)), room_index_at(_cell_to_world(b)))


func _sim_step() -> void:
	if _sim_snapshot.is_empty() or not executing_plan:
		return
	SimPreview.tick(_sim_snapshot, _sim_route, _sim_index, _sim_context)
	_apply_sim_state(_sim_snapshot)
	# 先处理本 tick 事件（拿取/开门必须在完成检测之前应用）。
	for e in _sim_snapshot["events"]:
		if int(e["tick"]) != int(_sim_snapshot["tick"]):
			continue
		match String(e["kind"]):
			"spotted":
				var reason := String(e.get("reason", ""))
				var detector := _detector_for_event(e)
				enter_failure_replay(detector, reason)
				return
			"target_taken":
				_apply_target_taken(String(e.get("detail", target_item_id())))
			"door_unlocked":
				pass  # 当前关卡无门锁，结构保留。
	# 路线/动作全部完成后退出执行态。
	if int(_sim_index.get("i", 0)) >= _sim_route.size():
		_finish_plan_execution()


func _apply_sim_state(snap: Dictionary) -> void:
	# 1) 装饰时间与监控角度由内核统一推进。
	_bm_time = float(snap.get("decor_time", _bm_time))
	_animate_bm_decor()

	# 2) 玩家：直接同步到内核算出的像素位置，避免渲染层物理滑动导致漂移。
	if player != null:
		var p: Dictionary = snap["player"]
		var target_pos := _cell_to_world(Vector2i(p["pos"]))
		var dir := (target_pos - player.global_position).normalized()
		player.global_position = target_pos
		player.sim_target_pos = target_pos
		player.sim_dir = dir
		player.crouching = bool(p.get("crouch", false))

	# 3) 守卫（由内核驱动位置与朝向；内部计时器在执行结束/回退时统一恢复）
	var guard_map := {}
	for g in snap.get("guards", []):
		guard_map[g.get("id", "")] = g
	for cop in police:
		if not is_instance_valid(cop):
			continue
		var g: Dictionary = guard_map.get(String(cop.name), {})
		if g.is_empty():
			continue
		cop.global_position = _cell_to_world(Vector2i(g["pos"]))
		cop.state = _alert_to_state(int(g.get("alert", 0)))
		cop._facing = Vector2(g.get("facing", Vector2i(1, 0)))
		cop._alert_level = 1 if int(g.get("alert", 0)) == 1 or float(g.get("spot_timer", 0.0)) > 0.05 else (2 if int(g.get("alert", 0)) == 2 else 0)

	# 4) 监控角度（装饰动画已处理）
	# _animate_bm_decor 在 _bm_time 更新后自动运行。


func _detector_for_event(e: Dictionary) -> Node2D:
	var detail := String(e.get("detail", ""))
	var id := String(e.get("id", ""))
	if detail == "camera":
		for cam in _bm_cameras:
			if is_instance_valid(cam) and String(cam.name) == id:
				return cam
	elif detail == "guard":
		for cop in police:
			if is_instance_valid(cop) and String(cop.name) == id:
				return cop
	return null


func _apply_target_taken(item_id: String) -> void:
	if Game.try_pickup(item_id):
		for child in get_children():
			if child is Artifact and child.item_id == item_id:
				child.picked.emit(item_id)
				child.queue_free()
				break
		toast.emit("拿到任务目标：%s！\n快从出口撤离。" % Game.item_name(item_id))
	else:
		toast.emit("拿取失败：背包已满。")


## 完整快照回退：还原玩家、全部守卫状态与计时、监控、门锁、物品、背包、烟雾与消耗量。
func _restore_full_snapshot(snap: Dictionary) -> void:
	if snap.is_empty():
		return
	_bm_time = float(snap.get("decor_time", _bm_time))
	_animate_bm_decor()

	if player != null:
		var p: Dictionary = snap["player"]
		player.global_position = _cell_to_world(Vector2i(p["pos"]))
		player.crouching = bool(p.get("crouch", false))
		player.sim_driven = false
		player.sim_dir = Vector2.ZERO
		player.velocity = Vector2.ZERO

	var guard_map := {}
	for g in snap.get("guards", []):
		guard_map[g.get("id", "")] = g
	for cop in police:
		if not is_instance_valid(cop):
			continue
		var g: Dictionary = guard_map.get(String(cop.name), {})
		if g.is_empty():
			continue
		cop.global_position = _cell_to_world(Vector2i(g["pos"]))
		cop._patrol_index = int(g.get("wp_index", 0))
		cop._wait_timer = float(g.get("wait_left", 0)) / SimPreview.TICK_RATE
		cop._investigate_pos = _cell_to_world(Vector2i(g["investigate_pos"])) if Vector2i(g.get("investigate_pos", Vector2i(-1, -1))).x >= 0 else Vector2.ZERO
		cop._investigate_timer = float(g.get("investigate_left", 0)) / SimPreview.TICK_RATE
		cop._spot_timer = float(g.get("spot_timer", 0)) / SimPreview.TICK_RATE
		cop._blind_timer = float(g.get("blind_timer", 0)) / SimPreview.TICK_RATE
		cop._facing = Vector2(g.get("facing", Vector2i(1, 0)))
		cop.state = _alert_to_state(int(g.get("alert", 0)))
		cop.ai_enabled = bool(g.get("ai_enabled", true))
		cop._alert_level = 1 if int(g.get("alert", 0)) == 1 or float(g.get("spot_timer", 0.0)) > 0.05 else (2 if int(g.get("alert", 0)) == 2 else 0)

	# 物品：按快照增删
	for child in get_children():
		if child is Artifact:
			child.queue_free()
	for item in snap.get("items", []):
		if not bool(item.get("taken", false)):
			_spawn_artifact(String(item["id"]), _cell_to_world(Vector2i(item["pos"])))

	# 背包与消耗品
	Game.bag_items = snap.get("bag_items", []).duplicate(true)
	Game.smoke_count = int(snap.get("smoke_count", Game.smoke_count))
	Game._recompute_mission()
	Game.backpack_changed.emit()
	Game.items_changed.emit()

	# 烟雾 puff
	for child in get_children():
		if child is SmokePuffClass:
			child.queue_free()
	for puff in snap.get("smoke_puffs", []):
		var node := SMOKE_SCENE.instantiate() as SmokePuffClass
		node.position = _cell_to_world(Vector2i(puff["pos"]))
		node._t = float(puff.get("time", 0.0))
		add_child(node)


var _preview_active := false
var _preview_cells: Array = []
var _preview_guard_cells: Array = []
var _preview_spotted_tick := -1
var _preview_spotted_pos := Vector2i(-1, -1)

## 运行一次预演并缓存结果（规划模式下反复调用开销可忽略：纯整数运算）。
func run_preview() -> void:
	if player == null or planned_points.is_empty():
		_preview_active = false
		_preview_cells = []
		_preview_guard_cells = []
		_preview_spotted_tick = -1
		_preview_spotted_pos = Vector2i(-1, -1)
		queue_redraw()
		return
	var snap := _build_sim_snapshot()
	var route := _planned_sim_route()
	var result := SimPreview.simulate_route(snap, route, 900)
	_preview_spotted_tick = result.first_spotted
	# 重放快照拿每 tick 位置（预演 trace 只是摘要；直接重放最直观且确定性一致）。
	_preview_cells = []
	_preview_guard_cells = []
	var replay := SimPreview.copy_snapshot(snap)
	var replay_route: Array = route.duplicate(true)
	var idx := {"i": 0}
	var t := 0
	while t < 900:
		SimPreview.tick(replay, replay_route, idx)
		t = int(replay["tick"])
		_preview_cells.append(replay["player"]["pos"])
		var guards: Array = replay.get("guards", [])
		if guards.is_empty():
			_preview_guard_cells.append(Vector2i(-1, -1))
		else:
			_preview_guard_cells.append(guards[0]["pos"])
		if result.first_spotted != -1 and int(replay["tick"]) >= result.first_spotted:
			break
	_preview_spotted_pos = Vector2i(-1, -1)
	if _preview_spotted_tick != -1 and _preview_cells.size() >= _preview_spotted_tick:
		_preview_spotted_pos = _preview_cells[_preview_spotted_tick - 1]
	_preview_active = true
	queue_redraw()


## 把预演结果画在规划叠加层上：半透明玩家轨迹 + 守卫残影 + 黄色首次发现预警。
func _draw_preview_overlay() -> void:
	if not _preview_active or _preview_cells.is_empty() or player == null:
		return
	var font := ThemeDB.fallback_font
	var prev: Vector2i = _preview_cells[0]
	for i in range(1, _preview_cells.size()):
		var cell: Vector2i = _preview_cells[i]
		var alpha := 0.12 + 0.25 * (float(i) / float(_preview_cells.size()))
		draw_line(
			Vector2(prev.x * TILE + TILE / 2.0, prev.y * TILE + TILE / 2.0),
			Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE + TILE / 2.0),
			Color(0.45, 0.85, 0.95, alpha), 2.0)
		prev = cell
	var gprev: Vector2i = _preview_guard_cells[0]
	for i in range(1, _preview_guard_cells.size()):
		var gcell: Vector2i = _preview_guard_cells[i]
		if i % 10 == 0:
			draw_circle(Vector2(gcell.x * TILE + TILE / 2.0, gcell.y * TILE + TILE / 2.0), 5.0, Color(0.85, 0.35, 0.35, 0.28))
		gprev = gcell
	if _preview_spotted_tick != -1 and _preview_spotted_pos.x >= 0:
		var pos := Vector2(_preview_spotted_pos.x * TILE + TILE / 2.0, _preview_spotted_pos.y * TILE + TILE / 2.0)
		var pulse := 6.0 + 3.0 * absf(sin(_bm_time * 4.0))
		draw_arc(pos, PLAN_POINT_RADIUS + pulse, 0.0, TAU, 16, Color(1.0, 0.85, 0.25, 0.9), 2.0)
		draw_string(font, pos + Vector2(8, -10), "预演：约 %.1fs 后在此被发现" % (float(_preview_spotted_tick) / SimPreview.TICK_RATE),
			HORIZONTAL_ALIGNMENT_LEFT, 220, 9, Color(1.0, 0.9, 0.45, 0.95))
	else:
		draw_string(font, player.global_position + Vector2(-60, -24),
			"预演：此路线在预演范围内未被发现", HORIZONTAL_ALIGNMENT_LEFT, 240, 9, Color(0.55, 0.95, 0.65, 0.9))


func _on_player_detected(detector: Node2D, reason: String) -> void:
	if is_world_frozen():
		return
	enter_failure_replay(detector, reason)


func enter_failure_replay(detector: Node2D, reason: String) -> void:
	failure_replay = true
	_failure_replay_timer = 0.0
	failure_detector = detector
	failure_reason = reason
	failure_line_start = detector.global_position if detector != null else player.global_position
	failure_line_end = player.global_position
	executing_plan = false
	planning_mode = false
	_sync_world_freeze()
	prompt_changed.emit("按 E / 空格 重新规划")
	failure_banner_changed.emit(failure_reason)
	if _failure_overlay != null:
		_failure_overlay.visible = true
		_failure_overlay.queue_redraw()
	queue_redraw()


func _process_failure_replay(delta: float) -> void:
	_failure_replay_timer += delta
	# 前 0.6s 为定格期，忽略 E / Space 误触；之后才可回退重规划。
	if _failure_replay_timer < FAILURE_REPLAY_FREEZE:
		return
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("plan_execute"):
		_failure_replay_timer = 0.0
		_rewind_and_replan()


func _rewind_and_replan() -> void:
	failure_replay = false
	failure_detector = null
	failure_reason = ""
	plan_point_index = 0
	# 完整回退到执行开始时的快照：保留路线和动作，还原全部实体状态。
	_restore_full_snapshot(_run_start_snapshot)
	for cop in _pre_exec_ai_states:
		if is_instance_valid(cop):
			cop.ai_enabled = _pre_exec_ai_states[cop]
	_pre_exec_ai_states.clear()
	# 还原执行开始时的规划路线与节点动作（即使手动接管曾清空当前路线）。
	if not _run_start_planned_points.is_empty():
		planned_points = _run_start_planned_points.duplicate()
		_plan_node_actions = _run_start_node_actions.duplicate()
	executing_plan = false
	planning_mode = true
	if player != null:
		player.sim_driven = false
	_sync_world_freeze()
	failure_banner_changed.emit("")
	if _failure_overlay != null:
		_failure_overlay.visible = false
		_failure_overlay.queue_redraw()


func _estimate_guard_eta_to_point(point: Vector2) -> float:
	var nearest := INF
	for cop in police:
		if is_instance_valid(cop):
			nearest = mini(nearest, cop.global_position.distance_to(point))
	if nearest == INF:
		return -1.0
	return nearest / Police.PATROL_SPEED


func _nearest_police_distance_to(point: Vector2) -> float:
	var best := INF
	for cop in police:
		if is_instance_valid(cop):
			best = mini(best, cop.global_position.distance_to(point))
	return best


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


func end_game() -> void:
	_ended = true
	planning_mode = false
	executing_plan = false
	_sync_world_freeze()
	for cop in police:
		cop.deactivate()
	prompt_changed.emit("")


## 供特写层“拾取”按钮调用：拾取指定文物（返回是否成功）。
func pickup_artifact(item_id: String) -> bool:
	if is_world_frozen():
		return false
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


func _on_pickup_blocked(item_id: String) -> void:
	Audio.play("denied", -8.0)
	toast.emit("背包已满，装不下 %s 了。" % Game.item_name(item_id))


func _on_player_used_item(item_id: String) -> void:
	if is_world_frozen() or item_id != "smoke":
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
	if is_world_frozen():
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
	if is_world_frozen() or body != player:
		return
	# 面具教学关仍要求完成教学目标；大英博物馆允许侦察撤离。
	if not Game.mission_complete and level_id == "museum":
		Audio.play("denied", -8.0)
		toast.emit("出口还锁着：必须带上任务目标才能撤离。")
		return
	var outcome := Game.OUTCOME_SUCCESS if Game.mission_complete else Game.OUTCOME_RECON
	_end_escape(outcome)


func _end_escape(outcome: String) -> void:
	end_game()
	Audio.play("escape", -5.0)
	escaped.emit(outcome)


func _on_police_spotted(_reason: String, cop: Police) -> void:
	var reason := "保安巡逻视野"
	if is_instance_valid(cop):
		if cop.state == Police.State.INVESTIGATE:
			reason = "跑动噪音引来保安"
		elif cop.state == Police.State.PATROL and not cop.patrol_points.is_empty():
			var nearest_pt := INF
			for pt in cop.patrol_points:
				nearest_pt = mini(nearest_pt, cop.global_position.distance_to(pt))
			if nearest_pt < 8.0:
				reason = "保安提前转弯发现你"
	_on_player_detected(cop, reason)


func _on_police_caught() -> void:
	if _ended or failure_replay:
		return
	_on_player_detected(null, "保安近身抓获")


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


func _load_optional(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## 固定哈希（房间+格坐标），保证每次进房/读档画面一致，不用随机数。
func _cell_hash(room: int, x: int, y: int, salt: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ (room * 83492791) ^ (salt * 2654435761))


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
			if BM_FLOOR_WEAR_ENABLED and _tex_floor_wear != null and ch == "." and _cell_hash(room, x, y, 1) % BM_FLOOR_WEAR_RATE == 0:
				var wi := _cell_hash(room, x, y, 2) % 8
				draw_texture_rect_region(_tex_floor_wear, rect, Rect2((wi % 4) * TILE, (wi / 4) * TILE, TILE, TILE))
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
				if _tex_wall_trim != null:
					var ti := 1 + 4 * (_cell_hash(room, x, y, 3) % 4)
					draw_texture_rect_region(_tex_wall_trim, rect, Rect2((ti % 4) * TILE, (ti / 4) * TILE, TILE, TILE))
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
	_build_room_theme_decor()


## T2：六厅主题装饰（decor_bm_*.png，每张 4 件 32×32）。只在素材存在时挂载；
## 选位固定哈希：贴北墙的空地，远离展台/文物/出口/玩家出生点与守卫格，纯视觉无碰撞。
func _build_room_theme_decor() -> void:
	for room in BM_ROOM_DECOR_KEYS.size():
		var tex := _load_optional("res://assets/sprites/bm/decor_bm_%s.png" % BM_ROOM_DECOR_KEYS[room])
		if tex == null or room >= rooms.size():
			continue
		var candidates: Array[Vector2i] = []
		var r: Rect2 = rooms[room]
		var x0 := int(r.position.x / TILE)
		var y0 := int(r.position.y / TILE)
		for y in range(y0, y0 + int(r.size.y / TILE)):
			for x in range(x0, x0 + int(r.size.x / TILE)):
				if _decor_cell_ok(x, y):
					candidates.append(Vector2i(x, y))
		var placed: Array[Vector2i] = []
		var start := _cell_hash(room, 0, 0, 4)
		for k in candidates.size():
			if placed.size() >= BM_ROOM_DECOR_COUNT:
				break
			var c: Vector2i = candidates[(start + k * 7) % candidates.size()]
			var far := true
			for q in placed:
				if absi(q.x - c.x) < 5:
					far = false
			if not far:
				continue
			var spr := Sprite2D.new()
			spr.name = "BMThemeDecor_%d_%d" % [room, placed.size()]
			spr.texture = tex
			spr.region_enabled = true
			spr.region_rect = Rect2(32 * placed.size(), 0, 32, 32)
			spr.position = _cell_center(c.x, c.y) + Vector2(0, -8)
			add_child(spr)
			placed.append(c)


func _decor_cell_ok(x: int, y: int) -> bool:
	if _tile_char(x, y) != "." or _tile_char(x, y - 1) != "#":
		return false
	for dy in range(-2, 4):
		for dx in range(-3, 4):
			var ch := _tile_char(x + dx, y + dy)
			if "pTaXP123456789dLWr".contains(ch) and ch != " ":
				return false
	return _tile_char(x - 1, y) == "." and _tile_char(x + 1, y) == "."


## Room 3 光影收口：尘埃、展柜玻璃高光、双羊尊地面倒影。
func _build_bm_atmosphere() -> void:
	if level_id != "british_museum":
		return
	var target_pos := _cell_center(10, 20)
	for child in get_children():
		if child is Artifact and child.item_id == target_item_id():
			target_pos = child.position
			break
	for i in rooms.size():
		if i == 3 or not BM_THEMES.has(i):
			continue
		var room_dust := CPUParticles2D.new()
		room_dust.name = "BMDust%d" % i
		room_dust.position = rooms[i].get_center()
		room_dust.amount = 14
		room_dust.lifetime = 7.0
		room_dust.preprocess = 7.0
		room_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		room_dust.emission_rect_extents = rooms[i].size * 0.45
		room_dust.direction = Vector2(0, -1)
		room_dust.spread = 30.0
		room_dust.gravity = Vector2.ZERO
		room_dust.initial_velocity_min = 2.0
		room_dust.initial_velocity_max = 6.0
		room_dust.scale_amount_min = 0.5
		room_dust.scale_amount_max = 1.0
		room_dust.color = Color(1.0, 0.9, 0.72, 0.28)
		add_child(room_dust)
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


func _build_failure_overlay() -> void:
	_failure_overlay = Node2D.new()
	_failure_overlay.name = "FailureOverlay"
	_failure_overlay.z_index = 100
	_failure_overlay.light_mask = 0
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_failure_overlay.material = mat
	_failure_overlay.visible = false
	_failure_overlay.draw.connect(_draw_failure_overlay)
	add_child(_failure_overlay)


func _draw_planning_overlay() -> void:
	if not planning_mode and not executing_plan and planned_points.is_empty():
		return
	var font := ThemeDB.fallback_font
	# 已规划路径连线
	if planned_points.size() >= 2:
		var points := PackedVector2Array()
		points.append(player.global_position if player != null else planned_points[0])
		for p in planned_points:
			points.append(p)
		draw_polyline(points, Color(0.45, 0.85, 0.95, 0.75), 2.0)

	# 节点与预测标签
	for i in planned_points.size():
		var p := planned_points[i]
		var selected := (i == _selected_plan_index)
		draw_circle(p, PLAN_POINT_RADIUS, Color(0.35, 0.78, 0.92, 0.9) if not selected else Color(1.0, 0.85, 0.35, 0.95))
		draw_arc(p, PLAN_POINT_RADIUS + 2.0, 0.0, TAU, 12, Color(0.15, 0.35, 0.45, 0.6), 1.0)
		var action := _plan_node_actions[i] if i < _plan_node_actions.size() else ""
		var action_label := ""
		match action:
			"wait": action_label = "等待"
			"crouch": action_label = "蹲下"
			"stand": action_label = "站立"
			"unlock": action_label = "开锁"
			"take": action_label = "拿取"
			"sprint": action_label = "疾跑"
		var eta := _estimate_guard_eta_to_point(p)
		var label := action_label
		if label != "":
			label += " · "
		label += "安全" if eta < 0.0 else "守卫 ~%.1fs" % eta
		if _is_in_camera_vision(p):
			label += " · 监控"
		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
		var backing := Rect2(p + Vector2(4, -20), text_size + Vector2(4, 4))
		draw_rect(backing, Color(0.05, 0.06, 0.08, 0.72), true)
		draw_string(font, p + Vector2(6, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.92, 0.98, 0.95))


func _is_in_camera_vision(point: Vector2) -> bool:
	for cam in _bm_cameras:
		if cam == null or not is_instance_valid(cam):
			continue
		var facing := Vector2.RIGHT.rotated(cam.rotation)
		if Police.in_cone(cam.global_position, facing, point, CAMERA_VISION_RANGE, CAMERA_VISION_HALF_ANGLE):
			return true
	return false


func _draw_failure_replay() -> void:
	if not failure_replay:
		return
	# 半透明暗屏（仍由 Museum 自身绘制，受夜色/灯光统一调制）
	draw_rect(Rect2(Vector2.ZERO, Vector2(tiles[0].length() * TILE, tiles.size() * TILE)), Color(0.05, 0.0, 0.0, 0.45), true)
	# 红色高亮连线由 FailureOverlay 在 z_index=100 且不受光照影响的环境下绘制


func _draw_failure_overlay() -> void:
	if not failure_replay:
		return
	if failure_detector != null and is_instance_valid(failure_detector):
		_failure_overlay.draw_line(failure_detector.global_position, failure_line_end, Color(1.0, 0.15, 0.15, 0.98), 2.5)
		_failure_overlay.draw_circle(failure_detector.global_position, 7.0, Color(1.0, 0.15, 0.15, 0.85))
	elif failure_line_start != failure_line_end:
		_failure_overlay.draw_line(failure_line_start, failure_line_end, Color(1.0, 0.15, 0.15, 0.98), 2.5)


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
	for hl in _bm_case_highlights:
		hl.modulate.a = 0.5 + 0.12 * sin(t * TAU / 3.5)  # 约 3.5 秒一个呼吸周期


func _draw() -> void:
	var map_size := Vector2(tiles[0].length() * TILE, tiles.size() * TILE)
	draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.03, 0.035, 0.05), true)
	for floor_rect in floors:
		var zone := _zone_at(floor_rect.get_center())
		if _is_zone_revealed(zone):
			draw_texture_rect(TEX_FLOOR_A, floor_rect, true)
	for y in tiles.size():
		var row: String = tiles[y]
		for x in row.length():
			var ch := row[x]
			if ch == " ":
				continue
			var zone: int = int(_zone_of_tile[y][x])
			if not _is_zone_revealed(zone):
				# 墙/门框如果邻接已探分区，仍显示（不然门会悬空）。
				if not _is_adjacent_to_revealed_zone(x, y):
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
	_draw_planning_overlay()
	_draw_preview_overlay()
	_draw_failure_replay()
