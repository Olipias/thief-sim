class_name Main
extends Node
## Scene flow: hideout (shop) -> museum heist -> result screen -> hideout.

const HUB := preload("res://src/ui/hub.tscn")
const TITLE_SCREEN := preload("res://src/ui/title_screen.tscn")
const RESULT_SCREEN := preload("res://src/ui/result_screen.tscn")
const MUSEUM := preload("res://src/world/museum.tscn")

const BRIEFINGS := {
	"museum": [
		{"speaker": "老猫", "text": "新人，第一单活：城西博物馆的「青铜人面具」。"},
		{"speaker": "老猫", "text": "路线是单向的：穿过几间展厅才能到后门。目标在中央大厅的展台上。"},
		{"speaker": "老猫", "text": "包里格子有限，拿不下的就按 B 打开背包调整摆放，腾地方。"},
		{"speaker": "老猫", "text": "巡逻的警察视野内别乱晃。跑步声会引来他们，撑不住就用烟雾弹。"},
		{"speaker": "老猫", "text": "还有——那东西有故事。拿到手别急着走，靠近它按 E 听听。"},
	],
	"british_museum": [
		{"speaker": "老猫", "text": "这一单不一样。目标在大英博物馆中国馆：「商代双羊尊」。"},
		{"speaker": "老猫", "text": "它一百多年前流落出去，存世只有两件——另一件在日本。"},
		{"speaker": "老猫", "text": "中国馆夜里守卫比城西松，但别掉以轻心；路线同样是单向的。"},
		{"speaker": "老猫", "text": "……这件东西，你带出来之后想怎么处理，再说。"},
	],
}

@onready var screen: Node2D = $Screen
@onready var ui_layer: CanvasLayer = $UILayer
@onready var hud: Hud = $HUD
@onready var dialogue: DialogueBox = $Dialogue
@onready var backpack: BackpackScreen = $Backpack
@onready var phone: MissionPhone = $Phone
@onready var dialogue_tree: DialogueTree = $DialogueTree

var _busy := false
var _museum: Museum = null
## 关闭手机/背包后，同一帧的按键会被 _process 再读到；用短冷却防“刚关就又被打开”。
var _phone_cooldown := 0.0
var _bag_cooldown := 0.0


## 关闭手机/背包后短冷却内不再响应同一按键（防止“关了又被同一帧重开”）。
static func toggle_allowed(cooldown: float) -> bool:
	return cooldown <= 0.0


func _ready() -> void:
	dialogue.finished.connect(_on_dialogue_finished)
	backpack.closed.connect(_on_backpack_closed)
	backpack.drop_requested.connect(_on_backpack_drop)
	phone.closed.connect(_on_phone_closed)
	phone.card_requested.connect(_on_card_requested)
	hud.phone_requested.connect(open_phone)
	show_title()


func _process(delta: float) -> void:
	_phone_cooldown = maxf(0.0, _phone_cooldown - delta)
	_bag_cooldown = maxf(0.0, _bag_cooldown - delta)
	if _museum == null or not is_instance_valid(_museum) or _busy:
		return
	if backpack.is_open() or dialogue.is_active() or phone.is_open():
		return
	if Input.is_action_just_pressed("bag") and toggle_allowed(_bag_cooldown):
		open_backpack()
	elif Input.is_action_just_pressed("phone") and toggle_allowed(_phone_cooldown):
		open_phone()


func open_phone() -> void:
	if _museum == null or not is_instance_valid(_museum) or _busy or phone.is_open():
		return
	if dialogue.is_active() or dialogue_tree.is_active():
		return
	phone.open()
	hud.set_compact(true)
	get_tree().paused = true


func _on_phone_closed() -> void:
	# 兜底：任何关闭手机的路径（P/ESC/点暗区/程序化）都不该把卡片层留在屏幕上
	if dialogue_tree.is_active():
		dialogue_tree.close()
	get_tree().paused = false
	hud.set_compact(false)
	_phone_cooldown = 0.2


## 文物志对谈（呈现层 A）：播放指定段落，结束时推进进度。
func _on_lore_requested(item_id: String, stage: int) -> void:
	var stages := Lore.stages(item_id)
	if stage < 0 or stage >= stages.size():
		return
	dialogue_tree.play(stages[stage], Lore.cards(item_id), func() -> void: _on_lore_finished(item_id))
	hud.clear_toast()
	hud.set_compact(true)
	get_tree().paused = true


func _on_lore_finished(item_id: String) -> void:
	Game.advance_lore_stage(item_id)
	get_tree().paused = false
	hud.set_compact(false)


## 展签卡（史实）：手机档案页点击卡片时用对谈层展示；不改变暂停状态（手机仍开着）。
## escapable=true：按 P / ESC 先收掉卡片层，逐层返回到手机（见 tests/test_input_flow.gd）。
func _on_card_requested(item_id: String, card_id: String) -> void:
	dialogue_tree.play([{"card": card_id}], Lore.cards(item_id), Callable(), true)


func open_backpack() -> void:
	if dialogue.is_active() or dialogue_tree.is_active():
		return
	backpack.open()
	hud.set_compact(true)
	get_tree().paused = true


func _on_backpack_closed() -> void:
	get_tree().paused = false
	hud.set_compact(false)
	_bag_cooldown = 0.2


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


func show_title() -> void:
	_busy = false
	get_tree().paused = false
	if backpack.is_open():
		backpack.close()
	if phone.is_open():
		phone.close()
	_museum = null
	_clear_screen()
	_clear_ui()
	hud.set_compact(false)
	hud.unbind_level()
	hud.hide_hud()
	var title := TITLE_SCREEN.instantiate() as TitleScreen
	title.continue_requested.connect(show_menu)
	title.new_game_requested.connect(_on_new_game)
	title.quit_requested.connect(func() -> void: get_tree().quit())
	ui_layer.add_child(title)


func _on_new_game() -> void:
	Game.start_new_game()
	show_menu()


func show_menu() -> void:
	_busy = false
	get_tree().paused = false
	if backpack.is_open():
		backpack.close()
	if phone.is_open():
		phone.close()
	_museum = null
	_clear_screen()
	_clear_ui()
	hud.set_compact(false)
	hud.unbind_level()
	hud.hide_hud()
	var hub := HUB.instantiate() as Hub
	hub.start_requested.connect(start_mission)
	hub.quit_requested.connect(show_title)
	ui_layer.add_child(hub)


func start_mission(level_id := "museum") -> void:
	if _busy:
		return
	_busy = true
	Game.set_level(level_id)
	Game.reset_run()
	_clear_screen()
	_clear_ui()
	var museum := MUSEUM.instantiate() as Museum
	museum.level_id = level_id
	museum.escaped.connect(_on_escaped.bind(museum))
	museum.caught.connect(_on_caught.bind(museum))
	museum.toast.connect(hud.toast)
	museum.prompt_changed.connect(hud.set_prompt)
	museum.alert_changed.connect(hud.set_alert)
	museum.dialogue_requested.connect(_show_dialogue)
	museum.lore_requested.connect(_on_lore_requested)
	screen.add_child(museum)
	_museum = museum
	hud.show_hud()
	hud.bind_level(museum)
	hud.set_mission_target(Game.item_name(Game.mission_target_id))
	_show_dialogue(BRIEFINGS.get(level_id, BRIEFINGS["museum"]))
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
	if phone.is_open():
		phone.close()
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
