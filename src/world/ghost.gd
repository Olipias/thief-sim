class_name Ghost
extends Node2D
## Vengeful exhibit spirit: drifts after the player and wails, which
## draws patrolling police to investigate.  Harmless, but very annoying.

signal wailed(position: Vector2)

const DEFAULT_WAIL_INTERVAL := 2.8
const DEFAULT_LIFETIME := 14.0
const FOLLOW_DISTANCE := 26.0
const DRIFT_SPEED := 30.0
const FADE_TIME := 1.2

var wail_interval := DEFAULT_WAIL_INTERVAL
var lifetime := DEFAULT_LIFETIME

var _target: Node2D = null
var _wail_timer := 0.0
var _life_timer := 0.0
var _phase := 0.0
var _active := true


func _ready() -> void:
	_target = get_tree().get_first_node_in_group("player")
	_wail_timer = wail_interval
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8)


func is_active() -> bool:
	return _active


func _process(delta: float) -> void:
	if not _active:
		return
	_life_timer += delta
	_phase += delta
	if _life_timer >= lifetime:
		_fade_out()
		return

	if _target != null and is_instance_valid(_target):
		var to_target := _target.global_position - global_position
		if to_target.length() > FOLLOW_DISTANCE:
			global_position += to_target.normalized() * DRIFT_SPEED * delta

	_wail_timer -= delta
	if _wail_timer <= 0.0:
		_wail_timer = wail_interval
		wailed.emit(global_position)
	queue_redraw()


func _fade_out() -> void:
	_active = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var bob := sin(_phase * 2.4) * 1.8
	draw_circle(Vector2(0, -2 + bob), 6.0, Color(0.8, 0.9, 1.0, 0.65))
	draw_circle(Vector2(-2, 2 + bob), 4.5, Color(0.7, 0.85, 1.0, 0.45))
	draw_circle(Vector2(2, 3 + bob), 4.0, Color(0.7, 0.85, 1.0, 0.4))
	draw_circle(Vector2(-2, -3 + bob), 1.2, Color(0.08, 0.16, 0.28, 0.9))
	draw_circle(Vector2(2, -3 + bob), 1.2, Color(0.08, 0.16, 0.28, 0.9))
