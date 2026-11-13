class_name Player
extends CharacterBody2D
## Top-down pixel movement with a 3-row sprite sheet
## (row 0 = down, row 1 = up, row 2 = side, mirrored for left).

signal used_item(item_id: String)
signal made_noise(position: Vector2, radius: float)
signal inspect_requested(item_id: String)
## 剧情交互触发器（BM Room 3 馆方标签 / 观众留言等），优先于文物拾取。
signal story_trigger_requested(group: String)

const WALK_SPEED := 58.0
const SPRINT_SPEED := 88.0
const SNEAKER_MULTIPLIER := 1.25
const NOISE_RADIUS := 64.0
const NOISE_INTERVAL := 0.35
## 交互冷却（秒）：发出剧情触发/拾取等交互后短时间忽略 E。
## 防同帧双触发：对谈/特写最后一按 E 会关闭界面并解除暂停，同一物理帧里
## Input.is_action_just_pressed 仍可能为 true（UI 把事件标记 handled 不影响 Input 轮询），
## 没有冷却就会把刚关掉的对谈再打开，按住/连按 E 即软锁。
## 与 main.gd 手机/背包的 0.2s toggle 冷却同一思路。
const INTERACT_COOLDOWN := 0.25

@onready var sprite: Sprite2D = $Sprite
@onready var interact_area: Area2D = $InteractArea

var controls_enabled := true
var facing_row := 0
var _walk_time := 0.0
var _sprinting := false
var _sprint_speed := SPRINT_SPEED
var _noise_timer := 0.0
var _step_timer := 0.0
var _interact_cooldown := 0.0


func _ready() -> void:
	_sprint_speed = SPRINT_SPEED * (SNEAKER_MULTIPLIER if Game.has_sneakers else 1.0)


func _physics_process(delta: float) -> void:
	# 冷却在这里递减：对谈打开期间游戏暂停、本函数不跑，冷却正好冻结到关闭那一帧，
	# 用于拦下“关闭界面的同一次按键”。
	_interact_cooldown = maxf(0.0, _interact_cooldown - delta)
	if not controls_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_sprinting = Input.is_action_pressed("sprint") and dir != Vector2.ZERO
	var speed := _sprint_speed if _sprinting else WALK_SPEED
	velocity = dir * speed
	move_and_slide()
	_update_visual(dir, delta)
	_emit_sprinting_noise(delta)
	_play_footsteps(delta)

	if Input.is_action_just_pressed("interact"):
		_try_interact()
	if Input.is_action_just_pressed("use_item"):
		use_item("smoke")


func _emit_sprinting_noise(delta: float) -> void:
	if not _sprinting:
		_noise_timer = 0.0
		return
	_noise_timer -= delta
	if _noise_timer <= 0.0:
		_noise_timer = NOISE_INTERVAL
		made_noise.emit(global_position, NOISE_RADIUS)


func _play_footsteps(delta: float) -> void:
	if velocity == Vector2.ZERO:
		_step_timer = 0.0
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = 0.22 if _sprinting else 0.34
		Audio.play_step()


func use_item(item_id: String) -> void:
	used_item.emit(item_id)


func _update_visual(dir: Vector2, delta: float) -> void:
	if dir == Vector2.ZERO:
		_walk_time = 0.0
		sprite.frame = facing_row * 4
		return
	if absf(dir.x) > absf(dir.y):
		facing_row = 2
		sprite.flip_h = dir.x < 0.0
	else:
		facing_row = 1 if dir.y < 0.0 else 0
	_walk_time += delta * (11.0 if _sprinting else 8.0)
	sprite.frame = facing_row * 4 + 2 + (int(_walk_time) % 2)


func _try_interact() -> void:
	# 冷却期内直接忽略：拦下“关闭对谈的同一帧再次触发交互”。
	if _interact_cooldown > 0.0:
		return

	var trigger := _nearest_story_trigger()
	var target := _closest_artifact()

	if trigger != null and _should_trigger_story(trigger, target):
		_interact_cooldown = INTERACT_COOLDOWN
		story_trigger_requested.emit(trigger.get_groups()[0])
		return

	if target == null:
		return
	# 文物拾取/端详同样加冷却：防止同帧 E 关掉对谈后又拾取/打开旁边的文物特写。
	_interact_cooldown = INTERACT_COOLDOWN
	if target.has_cinematic_closeup():
		inspect_requested.emit(target.item_id)
	else:
		target.try_pickup()


## 供 museum 等外部路径使用：非玩家轮询发起、但同样会打开对谈的交互
## （器灵交谈等）调用它，把玩家交互冷却一并拉起，堵住同帧双触发。
func start_interact_cooldown() -> void:
	_interact_cooldown = INTERACT_COOLDOWN


## 返回最近的剧情触发器（group 为 "story_label" / "story_note" 等）。
func _nearest_story_trigger() -> Area2D:
	var best: Area2D = null
	var best_dist := INF
	for area in interact_area.get_overlapping_areas():
		if area.is_queued_for_deletion() or area.get_parent() != get_parent():
			continue
		if not (area.is_in_group("story_label") or area.is_in_group("story_note")):
			continue
		var dist := global_position.distance_squared_to(area.global_position)
		if dist < best_dist:
			best_dist = dist
			best = area
	return best


## 决定是否触发剧情：只要剧情触发器严格比文物更近就触发；否则让位给文物。
## 已读/未读只影响 museum 里的自动双纸对谈与落档，不影响单次按 E 的优先级：
## 玩家站在双羊尊前时，即使标签未读也应拾取目标，而不是被纸拦住。
func _should_trigger_story(trigger: Area2D, target: Artifact) -> bool:
	if target == null:
		return true
	var t_dist := global_position.distance_squared_to(trigger.global_position)
	var a_dist := global_position.distance_squared_to(target.global_position)
	return t_dist < a_dist - 4.0


func _closest_artifact() -> Artifact:
	var best: Artifact = null
	var best_dist := INF
	for area in interact_area.get_overlapping_areas():
		if area.is_queued_for_deletion():
			continue
		# 过滤旧关卡残留的 artifact：旧关卡的节点仍会在树上存活一帧，
		# 但其父节点（museum）已被 queue_free；只接受与玩家同属于当前 museum 的。
		if area.get_parent() != get_parent():
			continue
		var artifact := area as Artifact
		if artifact == null:
			continue
		var dist := global_position.distance_squared_to(artifact.global_position)
		if dist < best_dist:
			best_dist = dist
			best = artifact
	return best


## Name of the artifact the player could pick up right now ("" if none).
func interactable_name() -> String:
	var target := _closest_artifact()
	return target.display_name() if target != null else ""
