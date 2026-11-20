extends "res://tests/test_input_flow.gd"
## 独立执行完整输入流里的同一冻结回归，直接验证真实玩家和守卫。
func _ready() -> void:
	Game.save_path = "/tmp/thief_sim_planning_freeze_save.json"
	Game.reset_progress()
	main = load("res://src/main.tscn").instantiate() as Main
	add_child(main)
	await _frames(4)
	main.start_mission("museum")
	await _frames(4)
	await _skip_dialogue()
	await _test_planning_world_freeze()
	Audio.shutdown()
	await get_tree().create_timer(0.4, true).timeout
	for line in _assertion_log:
		print(line)
	print("PLANNING_FREEZE: %d/%d PASSED" % [_checks - _failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)
