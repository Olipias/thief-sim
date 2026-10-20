class_name Player
extends CharacterBody2D
## Top-down pixel movement with a 3-row sprite sheet
## (row 0 = down, row 1 = up, row 2 = side, mirrored for left).

signal used_item(item_id: String)
signal made_noise(position: Vector2, radius: float)
signal inspect_requested(item_id: String)

const WALK_SPEED := 58.0
const SPRINT_SPEED := 88.0
const SNEAKER_MULTIPLIER := 1.25
const NOISE_RADIUS := 64.0
const NOISE_INTERVAL := 0.35

@onready var sprite: Sprite2D = $Sprite
@onready var interact_area: Area2D = $InteractArea

var controls_enabled := true
var facing_row := 0
var _walk_time := 0.0
var _sprinting := false
var _sprint_speed := SPRINT_SPEED
var _noise_timer := 0.0
var _step_timer := 0.0


func _ready() -> void:
	_sprint_speed = SPRINT_SPEED * (SNEAKER_MULTIPLIER if Game.has_sneakers else 1.0)


func _physics_process(delta: float) -> void:
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
		sprite.frame = facing_row * 2
		return
	if absf(dir.x) > absf(dir.y):
		facing_row = 2
		sprite.flip_h = dir.x < 0.0
	else:
		facing_row = 1 if dir.y < 0.0 else 0
	_walk_time += delta * (11.0 if _sprinting else 8.0)
	sprite.frame = facing_row * 2 + (int(_walk_time) % 2)


func _try_interact() -> void:
	var target := _closest_artifact()
	if target == null:
		return
	if target.has_cinematic_closeup():
		inspect_requested.emit(target.item_id)
	else:
		target.try_pickup()


func _closest_artifact() -> Artifact:
	var best: Artifact = null
	var best_dist := INF
	for area in interact_area.get_overlapping_areas():
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
