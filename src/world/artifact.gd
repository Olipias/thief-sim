class_name Artifact
extends Area2D
## A collectible artifact sitting in the museum.

signal picked(item_id: String)
signal pickup_blocked(item_id: String)

@export var item_id := "vase"

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	sprite.texture = load("res://assets/sprites/artifact_%s.png" % item_id)
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "position:y", -2.0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_SINE)


func display_name() -> String:
	return Game.item_name(item_id)


func try_pickup() -> bool:
	if not Game.try_pickup(item_id):
		pickup_blocked.emit(item_id)
		return false
	picked.emit(item_id)
	queue_free()
	return true
