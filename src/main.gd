class_name Main
extends Node
## Scene flow: hideout (shop) -> museum heist -> result screen -> hideout.

const HUB := preload("res://src/ui/hub.tscn")
const RESULT_SCREEN := preload("res://src/ui/result_screen.tscn")
const MUSEUM := preload("res://src/world/museum.tscn")

const BRIEFING := [
	{"speaker": "老猫", "text": "新人，第一单活：城西博物馆的「青铜面具」。"},
	{"speaker": "老猫", "text": "路线是单向的：穿过五间展厅才能到后门。目标在中央大厅的展台上。"},
	{"speaker": "老猫", "text": "包里格子有限，拿不下的就按 B 打开背包调整摆放，腾地方。"},
	{"speaker": "老猫", "text": "巡逻的警察视野内别乱晃。跑步声会引来他们，撑不住就用烟雾弹。"},
]

@onready var screen: Node2D = $Screen
@onready var ui_layer: CanvasLayer = $UILayer
@onready var hud: Hud = $HUD
@onready var dialogue: DialogueBox = $Dialogue
@onready var backpack: BackpackScreen = $Backpack

var _busy := false
var _museum: Museum = null


func _ready() -> void:
	dialogue.finished.connect(_on_dialogue_finished)
	backpack.closed.connect(_on_backpack_closed)
	backpack.drop_requested.connect(_on_backpack_drop)
	show_menu()


func _process(_delta: float) -> void:
	if _museum == null or not is_instance_valid(_museum) or _busy:
		return
	if backpack.is_open() or dialogue.is_active():
		return
	if Input.is_action_just_pressed("bag"):
		open_backpack()


func open_backpack() -> void:
	backpack.open()
	hud.set_compact(true)
	get_tree().paused = true


func _on_backpack_closed() -> void:
	get_tree().paused = false
	hud.set_compact(false)


func _on_backpack_drop(item_id: String) -> void:
	if _museum != null and is_instance_valid(_museum) and _museum.player != null:
		_museum.drop_artifact(item_id, _museum.player.global_position)
	backpack.close()


func _clear_screen() -> void:
	for child in screen.get_children():
		child.queue_free()


func _clear_ui() -> void:
	for child in ui_layer.get_children():
		child.queue_free()


func show_menu() -> void:
	_busy = false
	get_tree().paused = false
	if backpack.is_open():
		backpack.close()
	_museum = null
	_clear_screen()
	_clear_ui()
	hud.set_compact(false)
	hud.unbind_level()
	hud.hide_hud()
	var hub := HUB.instantiate() as Hub
	hub.start_requested.connect(start_mission)
	hub.quit_requested.connect(func() -> void: get_tree().quit())
	ui_layer.add_child(hub)


func start_mission() -> void:
	if _busy:
		return
	_busy = true
	Game.reset_run()
	_clear_screen()
	_clear_ui()
	var museum := MUSEUM.instantiate() as Museum
	museum.escaped.connect(_on_escaped.bind(museum))
	museum.caught.connect(_on_caught.bind(museum))
	museum.toast.connect(hud.toast)
	museum.prompt_changed.connect(hud.set_prompt)
	museum.alert_changed.connect(hud.set_alert)
	museum.dialogue_requested.connect(_show_dialogue)
	screen.add_child(museum)
	_museum = museum
	hud.show_hud()
	hud.bind_level(museum)
	hud.set_mission_target(Game.item_name("mask"))
	_show_dialogue(BRIEFING)
	_busy = false


func _show_dialogue(lines: Array) -> void:
	dialogue.show_dialogue(lines)
	hud.set_compact(true)
	get_tree().paused = true


func _on_dialogue_finished() -> void:
	get_tree().paused = false
	hud.set_compact(false)


func _on_escaped(museum: Museum) -> void:
	_finish(museum, true)


func _on_caught(museum: Museum) -> void:
	_finish(museum, false)


func _finish(museum: Museum, success: bool) -> void:
	if _busy:
		return
	_busy = true
	get_tree().paused = false
	if backpack.is_open():
		backpack.close()
	_museum = null
	museum.end_game()
	hud.set_alert(0)
	hud.set_prompt("")
	hud.set_compact(false)
	await get_tree().create_timer(0.8, false).timeout
	var summary := Game.finish_run(success)
	_clear_screen()
	_clear_ui()
	hud.unbind_level()
	hud.hide_hud()
	var result := RESULT_SCREEN.instantiate() as ResultScreen
	result.continue_requested.connect(show_menu)
	ui_layer.add_child(result)
	result.setup(summary)
	_busy = false
