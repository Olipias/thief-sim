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
@onready var statements: StatementsScreen = $Statements
@onready var collection: CollectionScreen = $Collection
@onready var relic_closeup: RelicCloseup = $RelicCloseup

var _busy := false
var _museum: Museum = null
var _hub: Hub = null
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
	relic_closeup.closed.connect(_on_relic_closeup_closed)
	relic_closeup.pickup_requested.connect(_on_relic_pickup)
	hud.phone_requested.connect(open_phone)
	show_title()


func _process(delta: float) -> void:
	_phone_cooldown = maxf(0.0, _phone_cooldown - delta)
	_bag_cooldown = maxf(0.0, _bag_cooldown - delta)
	if _busy:
		return
	if dialogue.is_active() or relic_closeup.is_open():
		return
	if backpack.is_open():
		# 背包打开时：B 关闭背包；P/ESC 不在这里处理（手机不打开）
		if Input.is_action_just_pressed("bag") and toggle_allowed(_bag_cooldown):
			backpack.close()
			_bag_cooldown = 0.2
		return
	if phone.is_open():
		# 手机打开时：B 也关闭手机（契约 P/B/ESC）；P/ESC 由 MissionPhone 自己处理
		if Input.is_action_just_pressed("bag") and toggle_allowed(_bag_cooldown):
			phone.close()
			_bag_cooldown = 0.2
		return
	if Input.is_action_just_pressed("bag") and toggle_allowed(_bag_cooldown):
		open_backpack()
	elif Input.is_action_just_pressed("phone") and toggle_allowed(_phone_cooldown):
		open_phone()


func open_phone() -> void:
	if _busy or phone.is_open():
		return
	if dialogue.is_active() or dialogue_tree.is_active() or relic_closeup.is_open():
		return
	var in_level := _museum != null and is_instance_valid(_museum)
	var in_hub := _hub != null and is_instance_valid(_hub)
	if not in_level and not in_hub:
		return
	phone.open(in_hub)
	hud.set_compact(true)
	if in_level:
		get_tree().paused = true


func _on_phone_closed() -> void:
	# 兜底：任何关闭手机的路径（P/ESC/点暗区/程序化）都不该把卡片层留在屏幕上
	if dialogue_tree.is_active():
		dialogue_tree.close()
	get_tree().paused = false
	hud.set_compact(false)
	_phone_cooldown = 0.2
	_bag_cooldown = 0.2


## 剧情单卡/短句：用 DialogueTree 占位，escapable=true 允许 P/ESC 直接关闭。
func _on_story_requested(lines: Array, cards: Dictionary, on_finished: Callable) -> void:
	var wrapped := func() -> void:
		if on_finished.is_valid():
			on_finished.call()
	dialogue_tree.play(lines, cards, wrapped, true)
	# 延迟一帧连接 finished：若本对谈的 on_finished 里又开了新故事，新故事的 _on_story_requested
	# 会立即连接它自己的 finished；延迟能保证当前 dt_fin 不会被同一帧内更早的 finished 信号触发。
	var _on_dt_finished := func() -> void:
		if not dialogue_tree.is_active():
			get_tree().paused = false
			hud.set_compact(false)
	await get_tree().process_frame
	if not dialogue_tree.finished.is_connected(_on_dt_finished):
		dialogue_tree.finished.connect(_on_dt_finished, CONNECT_ONE_SHOT)
	hud.set_compact(true)
	get_tree().paused = true


## 互动特写层（2.5D）：靠近有特写图的文物按 E 打开。
func open_relic_closeup(item_id: String) -> void:
	if _museum == null or not is_instance_valid(_museum) or _busy or relic_closeup.is_open():
		return
	relic_closeup.open(item_id, true)
	hud.set_compact(true)
	get_tree().paused = true


func _on_relic_closeup_closed() -> void:
	get_tree().paused = false
	hud.set_compact(false)


func _on_relic_pickup(item_id: String) -> void:
	if _museum != null and is_instance_valid(_museum):
		_museum.pickup_artifact(item_id)
	relic_closeup.close()


## 展签卡（史实）：手机档案页点击卡片时用对谈层展示；不改变暂停状态（手机仍开着）。
## escapable=true：按 P / ESC 先收掉卡片层，逐层返回到手机（见 tests/test_input_flow.gd）。
func _on_card_requested(item_id: String, card_id: String) -> void:
	dialogue_tree.play([{"card": card_id}], Lore.cards(item_id), Callable(), true)


func open_backpack() -> void:
	if dialogue.is_active() or dialogue_tree.is_active() or relic_closeup.is_open():
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
	if statements.is_open():
		statements.close()
	if collection.is_open():
		collection.close()
	if relic_closeup.is_open():
		relic_closeup.close()
	_museum = null
	_hub = null
	_clear_screen()
	_clear_ui()
	hud.set_compact(false)
	hud.unbind_level()
	hud.hide_hud()
	var title := TITLE_SCREEN.instantiate() as TitleScreen
	title.statements_requested.connect(statements.open)
	title.continue_requested.connect(show_menu)
	title.new_game_requested.connect(_on_new_game)
	title.collection_requested.connect(collection.open)
	title.quit_requested.connect(func() -> void: get_tree().quit())
	ui_layer.add_child(title)


func _on_new_game() -> void:
	Game.start_new_game()
	if not Game.story_flag("saw_p00"):
		await _play_hub_story("p00_devil_contract", "saw_p00")
	show_menu()



func show_menu() -> void:
	_busy = false
	get_tree().paused = false
	if backpack.is_open():
		backpack.close()
	if phone.is_open():
		phone.close()
	if statements.is_open():
		statements.close()
	if collection.is_open():
		collection.close()
	if relic_closeup.is_open():
		relic_closeup.close()
	if dialogue_tree.is_active():
		dialogue_tree.close()
	_museum = null
	_hub = null
	_clear_screen()
	_clear_ui()
	hud.set_compact(false)
	hud.unbind_level()
	hud.hide_hud()
	var hub := HUB.instantiate() as Hub
	_hub = hub
	hub.start_requested.connect(start_mission)
	hub.quit_requested.connect(show_title)
	ui_layer.add_child(hub)
	# 据点剧情：P-01 在城西教学关完成后首次回据点触发；
	# H-01 在首次任务结算后回据点触发。
	if Game.story_flag("completed_museum") and not Game.story_flag("saw_p01"):
		await _play_hub_story("p01_door_in_rain", "saw_p01")
	elif Game.story_flag("completed_museum") and not Game.story_flag("saw_h01"):
		await _play_hub_story("h01_label_lesson", "saw_h01")


## 在据点播放一段 DialogueTree 剧情，结束后设置对应 story_flag。
func _play_hub_story(entry_id: String, flag: String) -> void:
	if not Story.has_entry(entry_id):
		return
	get_tree().paused = true
	hud.set_compact(true)
	var on_finished := func() -> void:
		Game.set_story_flag(flag)
	dialogue_tree.play(Story.script(entry_id), Story.cards(entry_id), on_finished, true)
	await dialogue_tree.finished
	get_tree().paused = false
	hud.set_compact(false)


func start_mission(level_id := "museum") -> void:
	if _busy:
		return
	_busy = true
	if dialogue_tree.is_active():
		dialogue_tree.close()
	# H-01/H-02：大英任务前，若因旧档或跳过未看过 H-01，先补播标签课；
	# 再看 H-02（阿岚递地址），保证剧情顺序。
	if level_id == "british_museum":
		if not Game.story_flag("saw_h01"):
			await _play_hub_story("h01_label_lesson", "saw_h01")
		if not Game.story_flag("saw_h02"):
			await _play_hub_story("h02_two_addresses", "saw_h02")
		Game.save_checkpoint("pre_heist")
	Game.set_level(level_id)
	Game.reset_run()
	_clear_screen()
	_clear_ui()
	_hub = null
	var museum := MUSEUM.instantiate() as Museum
	museum.level_id = level_id
	museum.escaped.connect(_on_escaped.bind(museum))
	museum.caught.connect(_on_caught.bind(museum))
	museum.toast.connect(hud.toast)
	museum.prompt_changed.connect(hud.set_prompt)
	museum.alert_changed.connect(hud.set_alert)
	museum.failure_banner_changed.connect(hud.set_failure_banner)
	museum.dialogue_requested.connect(_show_dialogue)
	museum.story_requested.connect(_on_story_requested)
	museum.closeup_requested.connect(open_relic_closeup)
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
	_hub = null
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
	# P2-A/B：城西教学关成功撤离后，跳过独立 ResultScreen，直接回安全屋触发 P-01。
	if success and museum.level_id == "museum":
		show_menu()
		_busy = false
	elif success and museum.level_id == "british_museum":
		Game.save_checkpoint("pre_choice")
		await _play_devil_demand()
		_busy = false
	else:
		var result := RESULT_SCREEN.instantiate() as ResultScreen
		result.continue_requested.connect(show_menu)
		ui_layer.add_child(result)
		result.setup(summary)
		_busy = false


## 大英博物馆成功撤离后：播放恶魔催交剧情，然后进入结局页。
func _play_devil_demand() -> void:
	get_tree().paused = true
	hud.set_compact(true)
	dialogue_tree.play(
		Story.script("p05_devil_demand"),
		Story.cards("p05_devil_demand"),
		Callable(),
		false
	)
	await dialogue_tree.finished
	get_tree().paused = false
	hud.set_compact(false)
	var ending_id := String(Game.story_flags.get("ending_id", ""))
	var result := RESULT_SCREEN.instantiate() as ResultScreen
	result.continue_requested.connect(_on_ending_continue)
	ui_layer.add_child(result)
	result.setup({
		"ending_id": ending_id,
		"money_total": Game.money,
	})


func _on_ending_continue() -> void:
	Game.load_checkpoint("pre_choice")
	show_menu()
