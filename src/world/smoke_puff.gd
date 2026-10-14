extends Node2D
## Expanding, fading smoke puff visual.  Self-removes when done.

const DURATION := 0.9
const START_RADIUS := 7.0
const END_RADIUS := 34.0

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= DURATION:
		queue_free()


func _draw() -> void:
	var progress := minf(_t / DURATION, 1.0)
	var radius := lerpf(START_RADIUS, END_RADIUS, progress)
	var alpha := 0.7 * (1.0 - progress)
	var color := Color(0.78, 0.8, 0.84, alpha)
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2(-radius * 0.45, radius * 0.2), radius * 0.62, color)
	draw_circle(Vector2(radius * 0.4, -radius * 0.25), radius * 0.55, color)
