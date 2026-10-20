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
var _wail_pulse := 0.0  # 哀嚎波纹剩余时间（秒）


func _ready() -> void:
	_target = get_tree().get_first_node_in_group("player")
	_wail_timer = wail_interval
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8)


func is_active() -> bool:
	return _active


## 安抚：在 seconds 秒内不再哀嚎（玩家按 E 与器灵交谈后调用）。
func calm(seconds: float) -> void:
	_wail_timer = maxf(_wail_timer, seconds)


## 距离下一次哀嚎还有多久（测试/调试用）。
func wail_cooldown() -> float:
	return _wail_timer


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
		_wail_pulse = 0.7
		wailed.emit(global_position)
	if _wail_pulse > 0.0:
		_wail_pulse = maxf(0.0, _wail_pulse - delta)
	queue_redraw()


func _fade_out() -> void:
	_active = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)


func _draw() -> void:
	# 哀嚎波纹：让"它刚才叫了"在世界里可见（警察正是被这一声引来的）。
	if _wail_pulse > 0.0:
		var k := 1.0 - _wail_pulse / 0.7
		draw_arc(Vector2.ZERO, 9.0 + k * 38.0, 0.0, TAU, 32, Color(0.78, 0.9, 1.0, (1.0 - k) * 0.55), 1.5)
	var bob := sin(_phase * 2.4) * 1.8
	draw_circle(Vector2(0, -2 + bob), 6.0, Color(0.8, 0.9, 1.0, 0.65))
	draw_circle(Vector2(-2, 2 + bob), 4.5, Color(0.7, 0.85, 1.0, 0.45))
	draw_circle(Vector2(2, 3 + bob), 4.0, Color(0.7, 0.85, 1.0, 0.4))
	draw_circle(Vector2(-2, -3 + bob), 1.2, Color(0.08, 0.16, 0.28, 0.9))
	draw_circle(Vector2(2, -3 + bob), 1.2, Color(0.08, 0.16, 0.28, 0.9))
