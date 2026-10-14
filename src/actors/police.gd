class_name Police
extends CharacterBody2D
## Patrols waypoints, reacts to noise, spots the player inside a vision cone
## (blocked by walls), then chases. Touching the player = busted.
##
## States: PATROL -> INVESTIGATE (noise / suspicion) -> CHASE.
## Alert levels reported through alert_changed(): 0 calm, 1 suspicious, 2 chase.

signal caught
signal alert_changed

enum State { PATROL, INVESTIGATE, CHASE }

const PATROL_SPEED := 34.0
const INVESTIGATE_SPEED := 46.0
const CHASE_SPEED := 74.0
const VISION_RANGE := 96.0
const VISION_HALF_ANGLE := deg_to_rad(48.0)
const SPOT_DELAY := 0.35
const INVESTIGATE_SPOT_MULTIPLIER := 1.5
const LOSE_TIME := 2.2
const CATCH_DISTANCE := 11.0
const WAYPOINT_WAIT := 0.4
const INVESTIGATE_TIME := 3.0

@onready var sprite: Sprite2D = $Sprite
@onready var flashlight: PointLight2D = $Flashlight

var patrol_points: Array[Vector2] = []
var active := true
var ai_enabled := true
var state := State.PATROL

var _player: Node2D = null
var _facing := Vector2.DOWN
var _patrol_index := 0
var _spot_timer := 0.0
var _lose_timer := 0.0
var _wait_timer := 0.0
var _walk_time := 0.0
var _caught_emitted := false
var _blind_timer := 0.0
var _investigate_pos := Vector2.ZERO
var _investigate_timer := 0.0
var _look_timer := 0.0
var _alert_level := 0


static func in_cone(origin: Vector2, facing: Vector2, target: Vector2, range_px: float, half_angle: float) -> bool:
	var to_target := target - origin
	if to_target.length_squared() > range_px * range_px:
		return false
	if facing == Vector2.ZERO:
		return false
	return absf(facing.angle_to(to_target)) <= half_angle


func deactivate() -> void:
	active = false
	velocity = Vector2.ZERO
	queue_redraw()


## Freezes perception and movement while keeping the guard visible
## (used for cutscenes / screenshots).
func set_ai_enabled(on: bool) -> void:
	ai_enabled = on
	if not on:
		velocity = Vector2.ZERO
	queue_redraw()


func alert_level() -> int:
	return _alert_level


func is_chasing() -> bool:
	return state == State.CHASE


## Noise response: walk over to the position and look around.
## Returns true when the noise was actually accepted.
func investigate(pos: Vector2, seconds := INVESTIGATE_TIME) -> bool:
	if not active or _blind_timer > 0.0 or state == State.CHASE:
		return false
	_investigate_pos = pos
	_investigate_timer = seconds
	if pos.distance_to(global_position) > 4.0:
		_facing = (pos - global_position).normalized()
	state = State.INVESTIGATE
	queue_redraw()
	return true


## Smoke bomb: lose the player and cannot see anything for a while.
func blind(seconds: float) -> void:
	_blind_timer = maxf(_blind_timer, seconds)
	_spot_timer = 0.0
	if state != State.PATROL:
		_enter_patrol()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not active:
		return
	if _blind_timer > 0.0:
		_blind_timer = maxf(0.0, _blind_timer - delta)
	sprite.modulate = Color(0.65, 0.7, 0.85) if _blind_timer > 0.0 else Color.WHITE
	flashlight.enabled = _blind_timer <= 0.0
	flashlight.rotation = _facing.angle()
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	if not ai_enabled:
		velocity = Vector2.ZERO
		_update_visual(delta)
		queue_redraw()
		return

	match state:
		State.PATROL:
			_process_patrol(delta)
		State.INVESTIGATE:
			_process_investigate(delta)
		State.CHASE:
			_process_chase(delta)

	move_and_slide()
	_update_visual(delta)
	_sync_alert()
	_try_catch()
	queue_redraw()


func _process_patrol(delta: float) -> void:
	if _player != null and _can_see_player():
		_spot_timer += delta
		if _spot_timer >= SPOT_DELAY:
			_enter_chase()
			return
	else:
		_spot_timer = maxf(0.0, _spot_timer - delta * 2.0)

	if patrol_points.is_empty():
		velocity = Vector2.ZERO
		return
	var target: Vector2 = patrol_points[_patrol_index]
	var to_target := target - global_position
	if to_target.length() < 3.0:
		_wait_timer -= delta
		velocity = Vector2.ZERO
		if _wait_timer <= 0.0:
			_patrol_index = (_patrol_index + 1) % patrol_points.size()
			_wait_timer = WAYPOINT_WAIT
		return
	velocity = to_target.normalized() * PATROL_SPEED
	_facing = velocity.normalized()


func _process_investigate(delta: float) -> void:
	if _player != null and _can_see_player():
		_spot_timer += delta * INVESTIGATE_SPOT_MULTIPLIER
		if _spot_timer >= SPOT_DELAY:
			_enter_chase()
			return
	else:
		_spot_timer = maxf(0.0, _spot_timer - delta)

	_investigate_timer -= delta
	if _investigate_timer <= 0.0:
		_enter_patrol()
		return

	var to_target := _investigate_pos - global_position
	if to_target.length() > 6.0:
		velocity = to_target.normalized() * INVESTIGATE_SPEED
		_facing = velocity.normalized()
	else:
		velocity = Vector2.ZERO
		_look_timer -= delta
		if _look_timer <= 0.0:
			_look_timer = 0.7
			_facing = _facing.rotated(TAU * 0.25)


func _process_chase(delta: float) -> void:
	if _player != null and _can_see_player():
		_lose_timer = LOSE_TIME
		var to_player := _player.global_position - global_position
		if to_player.length() > CATCH_DISTANCE * 0.5:
			velocity = to_player.normalized() * CHASE_SPEED
			_facing = velocity.normalized()
		else:
			velocity = Vector2.ZERO
		return

	_lose_timer -= delta
	if _lose_timer > 0.0:
		velocity = _facing * CHASE_SPEED * 0.6
	else:
		_enter_patrol()


func _enter_chase() -> void:
	if state == State.CHASE:
		return
	state = State.CHASE
	_lose_timer = LOSE_TIME
	Audio.play("alert", -9.0)


func _enter_patrol() -> void:
	state = State.PATROL
	_spot_timer = 0.0
	_investigate_timer = 0.0
	_patrol_index = _nearest_waypoint()


func _nearest_waypoint() -> int:
	var best := 0
	var best_dist := INF
	for i in patrol_points.size():
		var dist := global_position.distance_squared_to(patrol_points[i])
		if dist < best_dist:
			best_dist = dist
			best = i
	return best


func _can_see_player() -> bool:
	if _blind_timer > 0.0:
		return false
	var target: Vector2 = _player.global_position
	if not in_cone(global_position, _facing, target, VISION_RANGE, VISION_HALF_ANGLE):
		return false
	# Only walls block sight; the ray mask excludes actors on purpose.
	var query := PhysicsRayQueryParameters2D.create(global_position, target, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty()


func _try_catch() -> void:
	if _caught_emitted or _player == null or not is_instance_valid(_player):
		return
	if global_position.distance_to(_player.global_position) <= CATCH_DISTANCE:
		_caught_emitted = true
		active = false
		velocity = Vector2.ZERO
		caught.emit()


func _sync_alert() -> void:
	var level := 0
	if _blind_timer <= 0.0:
		if state == State.CHASE:
			level = 2
		elif state == State.INVESTIGATE or _spot_timer > 0.05:
			level = 1
	if level != _alert_level:
		_alert_level = level
		alert_changed.emit()


func _update_visual(delta: float) -> void:
	var moving := velocity != Vector2.ZERO
	if moving:
		_walk_time += delta * 8.0
	if absf(_facing.x) > absf(_facing.y):
		sprite.flip_h = _facing.x < 0.0
		sprite.frame = 4 + (int(_walk_time) % 2 if moving else 0)
	else:
		var row := 1 if _facing.y < 0.0 else 0
		sprite.frame = row * 2 + (int(_walk_time) % 2 if moving else 0)


func _draw() -> void:
	if not active:
		return
	var color := Color(1.0, 0.82, 0.25, 0.10)
	if state == State.CHASE:
		color = Color(1.0, 0.25, 0.2, 0.16)
	elif state == State.INVESTIGATE or _spot_timer > 0.0:
		color = Color(1.0, 0.55, 0.15, 0.14)

	if _blind_timer <= 0.0:
		var points := PackedVector2Array([Vector2.ZERO])
		var steps := 12
		for i in steps + 1:
			var angle := _facing.angle() - VISION_HALF_ANGLE + 2.0 * VISION_HALF_ANGLE * i / steps
			points.append(Vector2.RIGHT.rotated(angle) * VISION_RANGE)
		draw_colored_polygon(points, color)

		var font := ThemeDB.fallback_font
		if state == State.CHASE:
			draw_string(font, Vector2(-3, -14), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.3, 0.25))
		elif _alert_level >= 1:
			draw_string(font, Vector2(-4, -14), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.8, 0.3))
