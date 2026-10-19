extends Node
## 随机操作自检（monkey）：固定种子的随机按键/鼠标事件持续驱动 Main 场景，
## 每一步检查一组**底层不变量**（见 _check_invariants）。失败时打印种子与
## 最近操作序列——照着回放即可复现。
##
## 定位：这是"按键流自检"（tests/test_input_flow，确定性用例）的补充——
## 输入流测已知路径，monkey 测未知组合，专抓状态机死角与规则被破坏。
##
## 运行：godot --headless res://tests/test_monkey.tscn
## 扩展方式：往 _check_invariants() 里加"任何时刻都应成立"的规则
## （不要加场景相关的一次性断言——那些属于冒烟测试）。

const SEED := 20261020
const DEFAULT_STEPS := 600
const LEVELS: Array[String] = ["museum", "british_museum"]
const KEYS := [
	KEY_B, KEY_P, KEY_E, KEY_Q, KEY_R, KEY_ESCAPE, KEY_SPACE,
	KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_SHIFT,
]

var _failures := 0
var _checks := 0
var _log: Array[String] = []
var _rng := RandomNumberGenerator.new()
var _seed := SEED
var _step := 0
var _steps := DEFAULT_STEPS
var _level_index := 0
var _lore_injected := false
var _cov := {"bag": 0, "phone": 0, "dialogue": 0, "tree": 0, "levels": 0}
var main: Main


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL - " + msg)


## 带复现信息的失败（只对前 3 次失败打印操作日志，避免刷屏）
func _fail(step: int, msg: String) -> void:
	_failures += 1
	printerr("FAIL - 第 %d 步：%s" % [step, msg])
	if _failures <= 3:
		printerr("  ── 复现：seed=%d，最近操作（旧→新）：" % _seed)
		for line in _log:
			printerr("     " + line)


# ---------------------------------------------------------------- 输入模拟

func _press(code: int) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventKey.new()
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)


func _click(pos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = pos
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = pos
	up.pressed = false
	Input.parse_input_event(up)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _log_event(text: String) -> void:
	_log.append("步%d：%s" % [_step, text])
	if _log.size() > 40:
		_log.pop_front()


# ---------------------------------------------------------------- 不变量

func _any_overlay_open() -> bool:
	return (
		main.backpack.is_open()
		or main.phone.is_open()
		or main.dialogue.is_active()
		or main.dialogue_tree.is_active()
	)


func _overlay_names() -> String:
	var names: Array[String] = []
	if main.backpack.is_open():
		names.append("backpack")
	if main.phone.is_open():
		names.append("phone")
	if main.dialogue.is_active():
		names.append("dialogue")
	if main.dialogue_tree.is_active():
		names.append("dialogue_tree")
	return ",".join(names)


func _check_invariants(step: int) -> void:
	# 覆盖统计（证明 monkey 真的摸到了这些界面，而不是在空跑）
	if main.backpack.is_open():
		_cov["bag"] += 1
	if main.phone.is_open():
		_cov["phone"] += 1
	if main.dialogue.is_active():
		_cov["dialogue"] += 1
	if main.dialogue_tree.is_active():
		_cov["tree"] += 1

	# 1) 覆盖层 ⇔ 暂停（任何界面打开时必须暂停，反之必须能玩）
	var open := _any_overlay_open()
	if open != get_tree().paused:
		_fail(step, "覆盖层与暂停状态不一致（overlays=[%s] paused=%s）" % [_overlay_names(), get_tree().paused])
		return

	# 2) 任务目标一致性：mission_complete 必须与背包实时内容一致
	var has_target := false
	for item in Game.bag_items:
		if Game.item_is_target(String(item["id"])):
			has_target = true
	if has_target != Game.mission_complete:
		_fail(step, "mission_complete=%s 但背包中目标物=%s" % [Game.mission_complete, has_target])
		return

	# 3) 数值不变量
	if Game.money < 0 or Game.smoke_count < 0 or Game.backpack_level < 0:
		_fail(step, "资源出现负值：money=%d smoke=%d bag_lv=%d" % [Game.money, Game.smoke_count, Game.backpack_level])
		return

	# 4) 玩家永远不该卡进实心格；坐标必须有限
	var m := _live_museum()
	if m != null and m.player != null:
		var pos: Vector2 = m.player.global_position
		if not (is_finite(pos.x) and is_finite(pos.y)):
			_fail(step, "玩家坐标非有限值：%s" % pos)
			return
		var tx := int(pos.x / m.TILE)
		var ty := int(pos.y / m.TILE)
		if ty >= 0 and ty < m.tiles.size() and tx >= 0 and tx < String(m.tiles[ty]).length():
			var ch := String(m.tiles[ty])[tx]
			if not m.WALKABLE.contains(ch):
				_fail(step, "玩家进入实心格 %s：tile='%s'（%s）" % [Vector2i(tx, ty), ch, pos])
				return


func _live_museum() -> Museum:
	var m := main._museum
	if m != null and is_instance_valid(m) and m.player != null and is_instance_valid(m.player):
		return m
	return null


# ---------------------------------------------------------------- 主流程

func _ready() -> void:
	Game.save_path = "/tmp/thief_sim_monkey_save.json"
	Game.reset_progress()
	_rng.seed = SEED

	# 允许加深/换种子跑（默认值保证 verify 里足够快；覆盖率断言会防止空跑）
	var env_steps := OS.get_environment("MONKEY_STEPS")
	if env_steps.is_valid_int():
		_steps = clampi(int(env_steps), 50, 20000)
	var env_seed := OS.get_environment("MONKEY_SEED")
	if env_seed.is_valid_int():
		_rng.seed = int(env_seed)
	_seed = _rng.seed

	main = load("res://src/main.tscn").instantiate() as Main
	add_child(main)
	await _frames(4)
	check(main.backpack != null and main.phone != null and main.dialogue_tree != null, "覆盖层节点已接线")

	# 第一局保留任务简报，让随机按键自己把它读完（覆盖 dialogue 层）
	await _enter_level(false)

	for step in _steps:
		_step = step
		await _random_action(step)
		_check_invariants(step)
		# 脚本化场景注入：单靠随机输入摸不到的状态，由测试主动摆出来再随机操作
		if (
			not _lore_injected
			and step % 5 == 0
			and step > 0
			and not _any_overlay_open()
			and not main._busy
			and main._museum != null
		):
			main._on_lore_requested("mask", 0)  # 器灵对谈（对话树）；之后交给随机按键处理
			_lore_injected = true
			await _frames(2)
		# 保证覆盖到两个关卡：换关（先回菜单，清干净再开局）
		if (
			_cov["levels"] < 2
			and step >= 120
			and step % 25 == 0
			and not _any_overlay_open()
			and not main._busy
		):
			main.show_menu()
			await _frames(2)
			await _enter_level(true)
		# 定期：如果已经不在关卡里（被逮/撤离进入结算或菜单），换一关保持覆盖
		elif step % 40 == 0 and main._museum == null and not main._busy:
			await _enter_level(true)

	await _cleanup_inputs()

	# 测试自身的有效性：没摸到关键界面说明随机序列失效，必须调整
	check(_cov["bag"] > 0, "覆盖到背包界面（%d 步）" % _cov["bag"])
	check(_cov["phone"] > 0, "覆盖到手机界面（%d 步）" % _cov["phone"])
	check(_cov["tree"] > 0, "覆盖到对话树界面（%d 步）" % _cov["tree"])
	check(_cov["levels"] >= 2, "覆盖到两个关卡（%d 次开局）" % _cov["levels"])

	print(
		"覆盖统计：背包 %d 步 / 手机 %d 步 / 对话框 %d 步 / 对话树 %d 步 / 开局 %d 次"
		% [_cov["bag"], _cov["phone"], _cov["dialogue"], _cov["tree"], _cov["levels"]]
	)
	if _failures > 0:
		print("FAILED %d 处（seed=%d，%d 步）" % [_failures, _seed, _steps])
		get_tree().quit(1)
	else:
		print("ALL %d 步随机操作通过（seed=%d）" % [_steps, _seed])
		get_tree().quit(0)


func _random_action(_step: int) -> void:
	var roll := _rng.randi_range(0, 9)
	if roll <= 5:
		var code: int = KEYS[_rng.randi() % KEYS.size()]
		_press(code)
		_log_event("按键 %s" % OS.get_keycode_string(code))
		await _frames(1 + _rng.randi() % 3)
	elif roll <= 7:
		var pos := Vector2(_rng.randf_range(0, 1280), _rng.randf_range(0, 720))
		_click(pos)
		_log_event("点击 (%.0f, %.0f)" % [pos.x, pos.y])
		await _frames(2)
	else:
		var frames := 2 + _rng.randi() % 8
		_log_event("等待 %d 帧" % frames)
		await _frames(frames)


func _enter_level(skip_briefing := true) -> void:
	var level := LEVELS[_level_index % LEVELS.size()]
	_level_index += 1
	main.start_mission(level)
	await _frames(4)
	if skip_briefing:
		var guard := 0
		while main.dialogue.is_active() and guard < 40:
			main.dialogue.advance()
			await _frames(1)
			guard += 1
	_cov["levels"] += 1
	_log_event("开局 %s%s" % [level, "（保留简报）" if not skip_briefing else ""])


## 收尾：用真实按键把界面全部关掉（多轮重试用掉冷却），然后必须干净。
func _cleanup_inputs() -> void:
	for _attempt in 24:
		if not _any_overlay_open() and not get_tree().paused:
			return
		if main.dialogue.is_active():
			_press(KEY_E)
			await _frames(3)
			continue
		if main.dialogue_tree.is_active():
			_press(KEY_E)  # 对谈/展签卡都用 E 推进（卡片也可用 ESC，但 E 通吃）
			await _frames(3)
			continue
		if main.backpack.is_open():
			_press(KEY_B)
			await _frames(3)
			continue
		if main.phone.is_open():
			_press(KEY_P)
			await _frames(3)
			continue
		await _wait(0.22)  # 可能处于关闭冷却中，等一拍再试
	check(not _any_overlay_open(), "收尾：全部界面可关闭（overlays=[%s]）" % _overlay_names())
	check(not get_tree().paused, "收尾：游戏未处于暂停")
