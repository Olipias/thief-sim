class_name Safehouse
extends Node2D
## R-01 独立安全屋：可走动的俯视角室内世界场景（挂在 Screen 世界层，不进 CanvasLayer）。
##
## 设计约束（docs/CONFIRMED_DESIGN.md §3）：
##   - 角色可走动，有墙体/家具碰撞；不是静态背景叠菜单。
##   - 书桌电脑 / 文物箱 / 房门三处 E 交互；设备界面由交互触发（Main 负责打开覆盖层）。
##   - 手机准备只记录行动，出发发生在房门；未准备/取消不切场景。
##   - 世界节点不挂 CanvasLayer；一次只处理一个主要交互。

signal toast(text: String)
signal prompt_changed(text: String)
signal computer_requested
signal box_requested
signal depart_requested

const TILE := 16
const ROOM_COLS := 20
const ROOM_ROWS := 11
const ROOM_RECT := Rect2(0, 0, ROOM_COLS * TILE, ROOM_ROWS * TILE)

const PLAYER_SCENE := preload("res://src/actors/player.tscn")
const TEX_WALL_LAMP := preload("res://assets/sprites/wall_lamp.png")
const TEX_WALL_PAINTING := preload("res://assets/sprites/wall_painting.png")
const TEX_PLANT := preload("res://assets/sprites/plant.png")
const TEX_CARPET := preload("res://assets/sprites/carpet.png")
const TEX_LIGHT_SOFT := preload("res://assets/sprites/light_soft.png")
const TEX_COMPUTER := preload("res://assets/sprites/safehouse/desk_computer_32x24.png")
const TEX_BOX := preload("res://assets/sprites/safehouse/storage_box_24x20.png")
const TEX_HOME_FLOOR := preload("res://assets/sprites/safehouse/home_floor_16.png")  # 木板 64×16，按 §136 更正取第 0 格
const TEX_HOME_FLOOR2 := preload("res://assets/sprites/safehouse/home_floor2_16.png")  # 石板 64×16，取第 0 格
const TEX_HOME_WALL := preload("res://assets/sprites/safehouse/home_wall_16.png")  # 64×16，4 格
const TEX_HOME_TRIM := preload("res://assets/sprites/safehouse/home_trim_16.png")  # 64×16，顶/底边缘
const TEX_SHELF := preload("res://assets/sprites/safehouse/home_shelf_32x48.png")
const TEX_CABINET := preload("res://assets/sprites/safehouse/home_cabinet_32x20.png")
const TEX_BASKET := preload("res://assets/sprites/safehouse/home_basket_24x20.png")
const TEX_LANTERN := preload("res://assets/sprites/safehouse/home_lantern_16x24.png")
const TEX_DOOR := preload("res://assets/sprites/safehouse/exit_door_24x40.png")

## 家具与对象的摆放（tile 坐标 / 世界像素中心）。
const DESK_POS := Vector2(64, 28)     ## 书桌电脑（32×24）贴顶墙
const BOX_POS := Vector2(272, 118)    ## 文物箱（24×20）贴右墙
const DOOR_POS := Vector2(152, 156)   ## 房门（24×40）底墙中央
const SPAWN_POS := Vector2(160, 88)   ## 玩家出生点（房间中部，远离家具）
## C2 陈设（视觉 + 体积碰撞；均不压住书桌/文物箱/房门/出生点的交互半径）。
const SHELF_POS := Vector2(240, 40)   ## 书架 32×48，顶墙右侧（占 y16..64）
const CABINET_POS := Vector2(40, 150) ## 柜子 32×20，底墙左侧（底边贴 y=160）
const BASKET_POS := Vector2(290, 148) ## 洗衣篮 24×20，右下角
const LANTERN_POSITIONS := [Vector2(8, 70), Vector2(312, 52)]  ## 灯笼 16×24，左右墙面各一

## 夜间室内氛围：比博物馆的冷夜更暖、更亮（住处的灯还开着）。
const HOME_TINT := Color(0.62, 0.58, 0.66)
const INTERACT_COOLDOWN := 0.25

var player: Player = null

var _last_prompt := ""
var _interact_cooldown := 0.0


func _ready() -> void:
	_build_room()
	_spawn_player()
	_setup_camera()


## --- 场景构建 ---------------------------------------------------------------

func _build_room() -> void:
	# 夜色氛围：住处比展馆暖一些。
	var tint := CanvasModulate.new()
	tint.name = "NightTint"
	tint.color = HOME_TINT
	add_child(tint)

	# 地板（内圈 x1..18 / y1..9）与围墙：外圈一圈 + 上下各加一行，
	# 让相机（视口 320×180 > 房间 320×176）越出的 2px 也落在墙面上而不是露底。
	for y in range(-1, ROOM_ROWS + 1):
		for x in ROOM_COLS:
			var border := x == 0 or y <= 0 or x == ROOM_COLS - 1 or y >= ROOM_ROWS - 1
			var spr := Sprite2D.new()
			# C1 noir 瓦片（§136 更正）：地板用「木板第 0 格 / 石板第 0 格」两套文件交替；
			# 围墙用墙瓦；紧贴室内的顶行/底行换成踢脚边缘瓦。
			if not border:
				spr.texture = _tile_region(TEX_HOME_FLOOR if (x + y) % 2 == 0 else TEX_HOME_FLOOR2, 0)
			elif (y == 0 or y == ROOM_ROWS - 1) and x > 0 and x < ROOM_COLS - 1:
				spr.texture = _tile_region(TEX_HOME_TRIM, x % 4)
			else:
				spr.texture = _tile_region(TEX_HOME_WALL, (x + absi(y)) % 4)
			spr.position = Vector2(x * TILE + TILE * 0.5, y * TILE + TILE * 0.5)
			spr.z_index = -10
			add_child(spr)

	# 中间一块地毯，给房间一个视觉锚点。
	for y in range(4, 8):
		for x in range(8, 12):
			var rug := Sprite2D.new()
			rug.texture = TEX_CARPET
			rug.position = _tile_center(x, y)
			rug.z_index = -9
			add_child(rug)

	# 顶墙装饰：两盏壁灯 + 一幅挂画；右上角一盆植物。
	for lamp_x in [3, 13]:
		var lamp := Sprite2D.new()
		lamp.texture = TEX_WALL_LAMP
		lamp.position = _tile_center(lamp_x, 0)
		lamp.z_index = -8
		add_child(lamp)
		_add_light(_tile_center(lamp_x, 2), Color(1.0, 0.85, 0.6), 0.9, 0.5)
	var painting := Sprite2D.new()
	painting.texture = TEX_WALL_PAINTING
	painting.position = _tile_center(8, 0)
	painting.z_index = -8
	add_child(painting)
	var plant := Sprite2D.new()
	plant.texture = TEX_PLANT
	plant.position = _tile_center(17, 0)
	plant.z_index = -8
	add_child(plant)

	# 窗户月光：右侧窗外透进来的冷光。
	_add_light(Vector2(320, 88), Color(0.75, 0.85, 1.0), 0.7, 0.8)

	_add_furniture()
	_add_wall_colliders()
	_add_desk()
	_add_box()
	_add_door()


## 图集（横排 16×16 小格）取第 i 格。
func _tile_region(atlas: Texture2D, index: int) -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = atlas
	t.region = Rect2(index * TILE, 0, TILE, TILE)
	return t


## C2：书架/柜子/洗衣篮（有体积，加碰撞）与两盏灯笼（挂墙，纯视觉 + 暖光）。
func _add_furniture() -> void:
	for spec in [
		{"tex": TEX_SHELF, "pos": SHELF_POS, "solid_off": Vector2(0, 16), "solid": Vector2(32, 16)},
		{"tex": TEX_CABINET, "pos": CABINET_POS, "solid_off": Vector2(0, 3), "solid": Vector2(32, 14)},
		{"tex": TEX_BASKET, "pos": BASKET_POS, "solid_off": Vector2(0, 3), "solid": Vector2(22, 14)},
	]:
		var spr := Sprite2D.new()
		spr.texture = spec["tex"]
		spr.position = spec["pos"]
		spr.z_index = -5
		add_child(spr)
		_add_solid(spec["pos"] + spec["solid_off"], spec["solid"])
	for i in LANTERN_POSITIONS.size():
		var lp: Vector2 = LANTERN_POSITIONS[i]
		var lantern := Sprite2D.new()
		lantern.name = "HomeLantern%d" % (i + 1)
		lantern.texture = TEX_LANTERN
		lantern.position = lp
		lantern.z_index = -8
		add_child(lantern)
		_add_light(lp + Vector2(0, 4), Color(1.0, 0.55, 0.35), 0.5, 0.4)


func _tile_center(x: int, y: int) -> Vector2:
	return Vector2(x * TILE + TILE * 0.5, y * TILE + TILE * 0.5)


func _add_wall_colliders() -> void:
	var specs := [
		{"pos": Vector2(ROOM_RECT.size.x * 0.5, 8), "size": Vector2(ROOM_RECT.size.x, 16)},          # 顶
		{"pos": Vector2(ROOM_RECT.size.x * 0.5, ROOM_RECT.size.y - 8), "size": Vector2(ROOM_RECT.size.x, 16)},  # 底
		{"pos": Vector2(8, ROOM_RECT.size.y * 0.5), "size": Vector2(16, ROOM_RECT.size.y)},          # 左
		{"pos": Vector2(ROOM_RECT.size.x - 8, ROOM_RECT.size.y * 0.5), "size": Vector2(16, ROOM_RECT.size.y)},  # 右
	]
	for s in specs:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = s["size"]
		shape.shape = rect
		body.add_child(shape)
		body.position = s["pos"]
		add_child(body)


func _add_solid(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	body.position = pos
	add_child(body)


func _add_desk() -> void:
	var spr := Sprite2D.new()
	spr.texture = TEX_COMPUTER
	spr.position = DESK_POS
	spr.z_index = -5
	add_child(spr)
	# 书桌本体挡路：站立高度约为贴图下半（桌沿）。
	_add_solid(Vector2(DESK_POS.x, DESK_POS.y + 6), Vector2(44, 22))
	_add_interactable("sh_computer", DESK_POS, "按 E 使用：书桌电脑")


func _add_box() -> void:
	var spr := Sprite2D.new()
	spr.texture = TEX_BOX
	spr.position = BOX_POS
	spr.z_index = -5
	add_child(spr)
	_add_solid(BOX_POS, Vector2(24, 20))
	_add_interactable("sh_box", BOX_POS, "按 E 打开：文物箱")


func _add_door() -> void:
	var spr := Sprite2D.new()
	spr.texture = TEX_DOOR
	spr.position = DOOR_POS
	spr.z_index = -5
	add_child(spr)
	# 门板自身不可穿过；出发交互站在门前。
	_add_solid(DOOR_POS, Vector2(24, 20))
	_add_interactable("sh_door", DOOR_POS, "按 E 出门：前往博物馆")


func _add_interactable(group: String, pos: Vector2, prompt: String) -> void:
	var area := Area2D.new()
	area.name = "Interact_" + group
	area.collision_layer = 8
	area.collision_mask = 2
	area.position = pos
	area.add_to_group(group)
	area.set_meta("prompt", prompt)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	shape.shape = circle
	area.add_child(shape)
	add_child(area)


func _add_light(pos: Vector2, color: Color, energy: float, scale: float) -> void:
	var light := PointLight2D.new()
	light.texture = TEX_LIGHT_SOFT
	light.color = color
	light.energy = energy
	light.texture_scale = scale
	light.position = pos
	add_child(light)


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate() as Player
	player.global_position = SPAWN_POS
	add_child(player)


func _setup_camera() -> void:
	if player == null:
		return
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam == null:
		return
	# 单间安全屋：相机限制到房间矩形；房间小于视口的方向由玩家平滑居中即可。
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(ROOM_RECT.size.x)
	cam.limit_bottom = int(ROOM_RECT.size.y)
	# 进入安全屋时相机立即就位，不从上一个场景的位置滑入。
	cam.reset_smoothing()


## --- 交互与提示 -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if player == null:
		return
	_interact_cooldown = maxf(0.0, _interact_cooldown - delta)
	var target := _nearest_interactable()
	var prompt := ""
	if target != null:
		# 门口提示按随身内容分流：带预约货 → 交货；否则 → 出发。
		if target.is_in_group("sh_door") and not Game.reserved_bag_items().is_empty():
			prompt = "按 E 交货：门口买家"
		else:
			prompt = "按 E " + String(target.get_meta("prompt", ""))
	if prompt != _last_prompt:
		_last_prompt = prompt
		prompt_changed.emit(prompt)
	if target != null and Input.is_action_just_pressed("interact") and _interact_cooldown <= 0.0:
		_interact_cooldown = INTERACT_COOLDOWN
		_activate(target)


## 最近的设备交互点（玩家交互半径内）。
func _nearest_interactable() -> Area2D:
	var best: Area2D = null
	var best_dist := INF
	for area in player.interact_area.get_overlapping_areas():
		if area.is_queued_for_deletion() or area.get_parent() != self:
			continue
		if not (area.is_in_group("sh_computer") or area.is_in_group("sh_box") or area.is_in_group("sh_door")):
			continue
		var dist := player.global_position.distance_squared_to(area.global_position)
		if dist < best_dist:
			best_dist = dist
			best = area
	return best


## 按优先级触发设备：把请求交给 Main 打开对应覆盖层 / 出发。
func _activate(target: Area2D) -> void:
	if target.is_in_group("sh_computer"):
		computer_requested.emit()
	elif target.is_in_group("sh_box"):
		box_requested.emit()
	elif target.is_in_group("sh_door"):
		depart_requested.emit()
