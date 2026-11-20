class_name Main
extends Node
## Scene flow: hideout (shop) -> museum heist -> result screen -> hideout.

const HUB := preload("res://src/ui/hub.tscn")
const SAFEHOUSE := preload("res://src/world/safehouse.tscn")
const TITLE_SCREEN := preload("res://src/ui/title_screen.tscn")
const RESULT_SCREEN := preload("res://src/ui/result_screen.tscn")
const MUSEUM := preload("res://src/world/museum.tscn")
const COMPUTER_SCREEN := preload("res://src/ui/computer_screen.tscn")
const BOX_SCREEN := preload("res://src/ui/box_screen.tscn")

const BRIEFINGS := {
	"museum": [
		{"speaker": "老猫", "text": "新人，第一单活：城西博物馆的「青铜人面具」。"},
		{"speaker": "老猫", "text": "路线是单向的：穿过几间展厅才能到后门。目标在中央大厅的展台上。"},
		{"speaker": "老猫", "text": "先按 C 蹲下，再按 Tab 规划路线，空格执行，方向键随时接管。"},
		{"speaker": "老猫", "text": "巡逻的警察视野内别乱晃。跑步声会引来他们，撑不住就用烟雾弹。"},
		{"speaker": "老猫", "text": "按 E 观察和拾取青铜面具，得手后去装卸出口。"},
	],
	"british_museum": [
		{"speaker": "老猫", "text": "这次三个目标共享展厅。手机里有任务，电脑里有线索。"},
		{"speaker": "老猫", "text": "一次只拿你选定的一件。其他展品留在原处。"},
		{"speaker": "老猫", "text": "规划时注意时间、噪音和视线；失败后可以回到房间入口重试。"},
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
@onready var computer: ComputerScreen = $Computer
@onready var box: BoxScreen = $Box

var _busy := false
var _museum: Museum = null
var _hub: Hub = null
var _safehouse: Safehouse = null
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
	computer.closed.connect(_on_device_closed)
	box.closed.connect(_on_device_closed)
	Game.pending_mission_changed.connect(_on_pending_mission_changed)
	show_title()


## 手机「委托」确认/取消后，行动中的 HUD 标签跟随待出发状态。
func _on_pending_mission_changed(level_id: String) -> void:
	if _safehouse != null and is_instance_valid(_safehouse):
		hud.set_mission_target("行动未确认" if level_id == "" else "已确认：%s" % Game.level_name_of(level_id))


func _process(delta: float) -> void:
	_phone_cooldown = maxf(0.0, _phone_cooldown - delta)
	_bag_cooldown = maxf(0.0, _bag_cooldown - delta)
	if _busy:
		return
	if dialogue.is_active() or relic_closeup.is_open():
		return
	if computer.is_open() or box.is_open():
		# 设备覆盖层自己处理 P/B/ESC 关闭；这里拦住 main 的 B/P 轮询，
		# 避免设备开着时同帧又打开背包/手机。
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
	var in_safehouse := _safehouse != null and is_instance_valid(_safehouse)
	if not in_level and not in_hub and not in_safehouse:
		return
	phone.open(in_hub or in_safehouse)
	hud.set_compact(true)
	if in_level or in_safehouse:
		# 安全屋现在是可走动的真实世界：手机作为覆盖层打开时同样暂停世界，
		# 避免“手机开着还能走路”。旧纯 UI 据点（无活动世界）保持原不暂停约定。
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


## --- 安全屋设备覆盖层（R-01） ----------------------------------------------

## 书桌电脑：从房内书桌按 E 进入；关闭回桌旁（覆盖层契约同背包/手机）。
func _open_computer() -> void:
	if _busy or computer.is_open():
		return
	if dialogue.is_active() or dialogue_tree.is_active() or relic_closeup.is_open():
		return
	computer.open()
	hud.set_compact(true)
	get_tree().paused = true


## 文物箱：查看随身/箱内；R-01 暂支持箱内战利品直售（过渡），存取与预约交易 R-05 接入。
func _open_box() -> void:
	if _busy or box.is_open():
		return
	if dialogue.is_active() or dialogue_tree.is_active() or relic_closeup.is_open():
		return
	box.open()
	hud.set_compact(true)
	get_tree().paused = true


## 设备覆盖层关闭（电脑或箱子）：恢复世界与 HUD，短冷却防止同帧重开。
func _on_device_closed() -> void:
	get_tree().paused = false
	hud.set_compact(false)
	_phone_cooldown = 0.2
	_bag_cooldown = 0.2


## 房门出发：只在手机「委托」已确认行动后放行；出发消费准备状态。
## （未准备/取消不切场景——CONFIRMED_DESIGN §4：手机确认 → 走到房门才出发。）
func _on_depart_requested() -> void:
	if _busy:
		return
	var pending := String(Game.pending_mission_level)
	if pending == "":
		hud.toast("先用手机「委托」确认本次行动，再走到房门出发。")
		return
	Game.clear_pending_mission()
	start_mission(pending)


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
	_safehouse = null
	_clear_screen()
	_clear_ui()
	hud.set_compact(false)
	hud.unbind_level()
	hud.hide_hud()
	var title := TITLE_SCREEN.instantiate() as TitleScreen
	title.statements_requested.connect(statements.open)
	title.continue_requested.connect(show_safehouse)
	title.new_game_requested.connect(_on_new_game)
	title.collection_requested.connect(collection.open)
	title.quit_requested.connect(func() -> void: get_tree().quit())
	ui_layer.add_child(title)


func _on_new_game() -> void:
	_busy = true
	Game.start_new_game()
	if not Game.story_flag("saw_p00"):
		var intro := ContractIntro.new()
		ui_layer.add_child(intro)
		await intro.finished
		Game.set_story_flag("saw_p00")
	_busy = false
	start_mission("museum")



## 安全屋（R-01）：正式流程中旧 Hub 栏目页的替代入口。
## 教学/任务撤离、继续游戏、结局返回都进入这个可走动的独立室内场景。
func show_safehouse() -> void:
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
	if computer.is_open():
		computer.close()
	if box.is_open():
		box.close()
	if dialogue_tree.is_active():
		dialogue_tree.close()
	_museum = null
	_hub = null
	_safehouse = null
	_clear_screen()
	_clear_ui()
	hud.set_compact(false)
	hud.unbind_level()
	hud.set_failure_banner("")
	hud.set_prompt("")
	hud.show_hud()
	hud.set_mission_target(Game.item_name(Game.mission_target_id))
	var safehouse := SAFEHOUSE.instantiate() as Safehouse
	safehouse.toast.connect(hud.toast)
	safehouse.prompt_changed.connect(hud.set_prompt)
	safehouse.computer_requested.connect(_open_computer)
	safehouse.box_requested.connect(_open_box)
	safehouse.depart_requested.connect(_on_depart_requested)
	screen.add_child(safehouse)
	_safehouse = safehouse
	Game.unlock_all_chains_required = false
	# HUD 行动栏：手机「委托」确认什么就显示什么；未确认时不显示旧目标避免误导。
	var pending := String(Game.pending_mission_level)
	hud.set_mission_target("行动未确认" if pending == "" else "已确认：%s" % Game.level_name_of(pending))
	# 据点剧情：P-01 在城西教学关完成后首次回安全屋触发；
	# H-01 在首次任务结算后回安全屋触发。
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
	_safehouse = null
	var museum := MUSEUM.instantiate() as Museum
	museum.level_id = level_id
	museum.toast.connect(hud.toast)
	museum.prompt_changed.connect(hud.set_prompt)
	museum.alert_changed.connect(hud.set_alert)
	museum.failure_banner_changed.connect(hud.set_failure_banner)
	museum.dialogue_requested.connect(_show_dialogue)
	museum.story_requested.connect(_on_story_requested)
	museum.closeup_requested.connect(open_relic_closeup)
	screen.add_child(museum)
	_museum = museum
	# 用 lambda 捕获 museum，避免 signal + bind 的参数顺序歧义。
	museum.escaped.connect(func(outcome: String) -> void: _on_escaped(museum, outcome))
	museum.caught.connect(func() -> void: _on_caught(museum))
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


func _on_escaped(museum: Museum, outcome: String) -> void:
	_finish(museum, outcome)


func _on_caught(museum: Museum) -> void:
	_finish(museum, Game.OUTCOME_CAUGHT)


func _finish(museum: Museum, outcome: String) -> void:
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
	_safehouse = null
	museum.end_game()
	hud.set_alert(0)
	hud.set_prompt("")
	hud.set_compact(false)
	await get_tree().create_timer(0.8, false).timeout
	var summary := Game.finish_run_outcome(outcome)
	_clear_screen()
	_clear_ui()
	hud.unbind_level()
	hud.hide_hud()
	# P2-A/B：城西教学关成功撤离后，跳过独立 ResultScreen，直接回安全屋触发 P-01。
	# 侦察撤离同样直接回安全屋，普通战利品已入箱。
	if outcome == Game.OUTCOME_SUCCESS and museum.level_id == "museum":
		show_safehouse()
		_busy = false
	elif outcome == Game.OUTCOME_SUCCESS and museum.level_id == "british_museum":
		Game.save_checkpoint("pre_choice")
		await _play_devil_demand()
		_busy = false
	elif outcome == Game.OUTCOME_RECON:
		show_safehouse()
		_busy = false
	else:
		var result := RESULT_SCREEN.instantiate() as ResultScreen
		result.continue_requested.connect(show_safehouse)
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
	show_safehouse()
