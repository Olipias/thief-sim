extends SceneTree
## 完整回退与执行转人工AI的状态守恒；存档隔离/tmp。
var _checks := 0
var _failures := 0

func check(ok: bool, message: String) -> void:
    _checks += 1
    if not ok:
        _failures += 1
        printerr("FAIL - " + message)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = root.get_node("Game")
    DirAccess.make_dir_recursive_absolute("/tmp/thief_snapshot_handoff")
    game.save_path = "/tmp/thief_snapshot_handoff/save.json"
    game.reset_progress()
    game.current_level_id = "museum"
    game.mission_target_id = "mask"
    var museum = load("res://src/world/museum.tscn").instantiate()
    museum.level_id = "museum"
    root.add_child(museum)
    await physics_frame
    await physics_frame
    check(not museum._run_start_snapshot.is_empty(), "纯手动行动也有初始重试快照")
    museum.toggle_planning_mode(true)

    var original_player := Vector2(57.25, 41.75)
    museum.player.global_position = original_player
    var cop = museum.police[0]
    var original_guard := Vector2(72.25, 42.125)
    cop.global_position = original_guard
    cop._facing = Vector2(0.6, 0.8)
    cop._wait_timer = 0.177
    cop._investigate_pos = Vector2(103.5, 71.25)
    cop._investigate_timer = 2.143
    cop._spot_timer = 0.133
    cop._blind_timer = 0.289
    cop._alert_level = 2
    game.smoke_count = 2
    game.money = 777
    game.bag_items.clear()
    check(game.try_pickup("vase", "handoff:vase"), "起点背包有普通物品")
    var snap: Dictionary = museum._build_sim_snapshot()
    check(Vector2(snap["guards"][0]["facing"]) == Vector2(0.6, 0.8), "预演快照保留真实非轴向朝向")
    var sight_guard: Dictionary = snap["guards"][0].duplicate(true)
    sight_guard["pos"] = Vector2i(4, 2)
    var sim = load("res://src/sim/sim_preview.gd")
    check(sim._guard_sees_player(sight_guard, {"pos": Vector2i(4, 3), "crouch": false}, {}),
        "斜向守卫视锥不因截断朝向变成水平")

    museum.player.global_position = Vector2(88, 88)
    cop.global_position = Vector2(24, 24)
    cop._facing = Vector2.LEFT
    cop._wait_timer = 0.0
    cop._investigate_timer = 0.0
    cop._spot_timer = 0.0
    cop._blind_timer = 0.0
    cop._alert_level = 0
    game.bag_items.clear()
    game.smoke_count = 0
    game.save_game() # 模拟拾取/消耗已经把执行态写入磁盘。
    museum._restore_full_snapshot(snap)
    check(museum.player.global_position == original_player, "回退精确保留非格心玩家位置")
    check(cop.global_position == original_guard, "回退精确保留非格心守卫位置")
    check(cop._facing == Vector2(0.6, 0.8), "回退恢复原始非轴向朝向")
    check(is_equal_approx(cop._wait_timer, 0.177), "回退不把等待计时取整为tick")
    check(cop._investigate_pos == Vector2(103.5, 71.25), "回退恢复精确调查位置")
    check(is_equal_approx(cop._investigate_timer, 2.143), "回退恢复原始调查计时")
    check(is_equal_approx(cop._spot_timer, 0.133), "回退恢复原始警觉计时")
    check(is_equal_approx(cop._blind_timer, 0.289), "回退恢复原始致盲计时")
    check(cop._alert_level == 2, "回退恢复警觉显示状态")
    check(game.smoke_count == 2 and game.bag_items.size() == 1, "回退恢复背包与消耗品")
    var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
    check(int(saved.get("smoke_count", -1)) == 2, "回退同步落盘消耗品")
    var saved_bag: Array = saved.get("bag_items", [])
    check(saved_bag.size() == 1 and saved_bag[0].get("id") == "vase", "回退覆盖磁盘背包，重开不能取回回滚收益")
    check(game.money == 777, "潜入回退不修改局外钱包")

    var updated: Dictionary = museum._build_sim_snapshot()
    updated["guards"][0]["spot_timer"] = 7
    updated["guards"][0]["wait_left"] = 9
    updated["guards"][0]["investigate_left"] = 11
    updated["guards"][0]["blind_timer"] = 5
    updated["guards"][0]["wp_index"] = 1
    museum._apply_sim_state(updated)
    check(is_equal_approx(cop._spot_timer, 0.35), "执行警觉计时同步到真实AI")
    check(is_equal_approx(cop._wait_timer, 0.45), "执行等待计时同步到真实AI")
    check(is_equal_approx(cop._investigate_timer, 0.55), "执行调查计时同步到真实AI")
    check(is_equal_approx(cop._blind_timer, 0.25), "执行致盲计时同步到真实AI")
    check(cop._patrol_index == 1, "执行巡逻索引同步到真实AI")
    museum._run_start_snapshot = snap.duplicate(true)
    museum._finish_plan_execution()
    check(not museum._run_start_snapshot.is_empty(), "执行结束或接管不清空合法重试快照")
    museum._rewind_and_replan()
    check(museum.planning_mode and not museum.executing_plan, "结束后仍可回退到规划状态")
    check(museum.player.global_position == original_player, "结束后的重试恢复原始物理起点")

    museum.queue_free()
    await process_frame
    root.get_node("Audio").shutdown()
    print("ALL %d CHECKS %s" % [_checks, "PASSED" if _failures == 0 else "FAILED (%d)" % _failures])
    quit(0 if _failures == 0 else 1)
