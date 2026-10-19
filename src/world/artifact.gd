class_name Artifact
extends Area2D
## A collectible artifact sitting in the museum.
##
## 默认贴图为 16×16 的 `artifact_<id>.png`（程序生成占位美术）；
## 若存在 `relic_<id>_strip.png`（3D 模型渲染的转台动画条），则改用
## 转台动画显示——目前用于任务目标「商代双羊尊」。

signal picked(item_id: String)
signal pickup_blocked(item_id: String)

const RELIC_FRAMES := 12
const RELIC_FRAME_SIZE := Vector2i(24, 28)
const RELIC_FPS := 8.0
const RELIC_BASELINE := 4.0  ## 底边相对节点中心的下沉量（与展台贴合）

@export var item_id := "vase"

@onready var sprite: Sprite2D = $Sprite
@onready var glow: PointLight2D = $Glow

var _relic_frames := 0
var _relic_time := 0.0


func _ready() -> void:
	var relic_path := "res://assets/sprites/relic_%s_strip.png" % item_id
	if ResourceLoader.exists(relic_path):
		sprite.texture = load(relic_path)
		sprite.hframes = RELIC_FRAMES
		sprite.vframes = 1
		sprite.frame = 0
		sprite.position = Vector2(0, RELIC_BASELINE - RELIC_FRAME_SIZE.y / 2.0)
		glow.position = Vector2(0, -10)
		glow.texture_scale = 0.55
		_relic_frames = RELIC_FRAMES
		set_process(true)
		return
	sprite.texture = load("res://assets/sprites/artifact_%s.png" % item_id)
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "position:y", -2.0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	if _relic_frames <= 0:
		return
	_relic_time += delta * RELIC_FPS
	sprite.frame = int(_relic_time) % _relic_frames


func display_name() -> String:
	return Game.item_name(item_id)


func try_pickup() -> bool:
	if not Game.try_pickup(item_id):
		pickup_blocked.emit(item_id)
		return false
	picked.emit(item_id)
	queue_free()
	return true
