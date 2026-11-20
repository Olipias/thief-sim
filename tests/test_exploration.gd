extends Node
## R-11a / R-13a 探索循环验收：房间迷雾、跨次保留、侦察撤离与普通战利品反刷。
##
## 运行：godot --headless res://tests/test_exploration.tscn
## 验收点：
##   - 进入关卡时只有入口分区揭示，其他房间/走廊隐藏。
##   - 移动到新分区后，该分区被持久化到 Game.level_visited_rooms。
##   - 退出再进入同关卡，已探分区仍揭示，未探分区仍隐藏。
##   - 侦察撤离（OUTCOME_RECON）把普通战利品移入 stash，并记录 instance_id，
##     下次进入关卡同一实例不再刷新。
##   - 新游戏 reset_progress 会清空跨次探索记录。

const Museum := preload("res://src/world/museum.gd")
const Artifact := preload("res://src/world/artifact.gd")

var _failures := 0
var _checks := 0
var _log: Array[String] = []


func check(cond: bool, msg: String) -> void:
	_checks += 1
	var line := ("PASS - " if cond else "FAIL - ") + msg
	_log.append(line)
	if not cond:
		_failures += 1
		printerr(line)


func _ready() -> void:
	Game.save_path = "/tmp/thief_sim_exploration_save.json"
	Game.reset_progress()

	await _test_fog_reveal_on_entry()
	await _test_fog_persists_across_runs()
	await _test_recon_evacuation_and_antiduplicate()
	await _test_reset_clears_exploration()

	Audio.shutdown()
	if _failures > 0:
		for line in _log:
			print(line)
		print("FAILED %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
	else:
		for line in _log:
			print(line)
		print("ALL %d CHECKS PASSED" % _checks)
		get_tree().quit(0)


func _make_museum() -> Museum:
	Game.reset_run()
	Game.current_level_id = "museum"
	Game.mission_target_id = "mask"
	var museum := load("res://src/world/museum.tscn").instantiate() as Museum
	museum.level_id = "museum"
	add_child(museum)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return museum


func _free_museum(museum: Museum) -> void:
	if is_instance_valid(museum):
		museum.queue_free()
		await get_tree().process_frame


func _room_center(museum: Museum, room_idx: int) -> Vector2:
	var r: Rect2 = museum.rooms[room_idx]
	return r.get_center()


func _reveal_zone_at(museum: Museum, pos: Vector2) -> int:
	museum.player.global_position = pos
	await get_tree().process_frame
	await get_tree().process_frame
	return museum._zone_at(pos)


func _find_loot_artifact(museum: Museum) -> Artifact:
	for child in museum.get_children():
		if child is Artifact and child.item_id != museum.target_item_id():
			return child
	return null


func _test_fog_reveal_on_entry() -> void:
	Game.level_visited_rooms.clear()
	Game.level_taken_items.clear()
	var museum := await _make_museum()
	var start_zone := museum._zone_at(museum.player.global_position)
	check(start_zone >= 0, "迷雾：玩家起始分区有效")
	check(museum._is_zone_revealed(start_zone), "迷雾：入口分区已揭示")
	check(Game.is_room_visited("museum", start_zone), "迷雾：入口分区已写入跨次记录")

	var hidden_found := false
	for i in museum.rooms.size():
		var zone := i
		if zone == start_zone:
			continue
		if not museum._is_zone_revealed(zone):
			hidden_found = true
			break
	check(hidden_found, "迷雾：至少有一个其他房间初始隐藏")
	await _free_museum(museum)


func _test_fog_persists_across_runs() -> void:
	Game.level_visited_rooms.clear()
	Game.level_taken_items.clear()
	var museum1 := await _make_museum()
	var start_zone := museum1._zone_at(museum1.player.global_position)
	var second_room := -1
	for i in museum1.rooms.size():
		if i != start_zone and i < museum1.rooms.size():
			second_room = i
			break
	if second_room == -1:
		museum1.queue_free()
		check(false, "跨次保留：没有第二个房间可测（跳过）")
		return
	var second_zone := await _reveal_zone_at(museum1, _room_center(museum1, second_room))
	check(second_zone == second_room, "跨次保留：第二个房间分区索引一致")
	check(museum1._is_zone_revealed(second_zone), "跨次保留：第二个房间已揭示")
	check(Game.is_room_visited("museum", second_zone), "跨次保留：第二个房间已写入记录")
	await _free_museum(museum1)

	var museum2 := await _make_museum()
	check(museum2._is_zone_revealed(start_zone), "跨次保留：重进后入口仍揭示")
	check(museum2._is_zone_revealed(second_zone), "跨次保留：重进后第二个房间仍揭示")
	var still_hidden := false
	for i in museum2.rooms.size():
		if i != start_zone and i != second_zone and not museum2._is_zone_revealed(i):
			still_hidden = true
			break
	check(still_hidden, "跨次保留：未进入的房间仍隐藏")
	await _free_museum(museum2)


func _test_recon_evacuation_and_antiduplicate() -> void:
	Game.level_visited_rooms.clear()
	Game.level_taken_items.clear()
	Game.money = 0
	var museum1 := await _make_museum()
	var start_zone := museum1._zone_at(museum1.player.global_position)
	var second_room := -1
	for i in museum1.rooms.size():
		if i != start_zone:
			second_room = i
			break
	if second_room != -1:
		await _reveal_zone_at(museum1, _room_center(museum1, second_room))

	var loot := _find_loot_artifact(museum1)
	check(loot != null, "侦察撤离：场景中存在普通战利品")
	if loot == null:
		museum1.queue_free()
		return
	var loot_id := loot.item_id
	var loot_instance := loot.instance_id
	check(not loot_instance.is_empty(), "侦察撤离：普通战利品有实例ID")
	# 直接走 Game.try_pickup，避免触发文物 pick 音效导致测试退出时音频资源泄漏。
	var picked := Game.try_pickup(loot_id, loot_instance)
	check(picked, "侦察撤离：战利品拾取成功")
	var in_bag := false
	var bag_instance := ""
	for item in Game.bag_items:
		if String(item.get("id", "")) == loot_id:
			in_bag = true
			bag_instance = String(item.get("instance_id", ""))
	check(in_bag, "侦察撤离：战利品在背包中")
	check(bag_instance == loot_instance, "侦察撤离：背包条目保留实例ID")

	var before_money := Game.money
	var summary := Game.finish_run_outcome(Game.OUTCOME_RECON)
	check(summary["recon"] == true, "侦察撤离：结算标记 recon")
	check(Game.bag_items.is_empty(), "侦察撤离：背包已清空")
	check(loot_id in Game.loot_stash, "侦察撤离：战利品进入 stash")
	check(Game.money == before_money, "侦察撤离：未发放任务报酬")
	check(Game.is_item_taken("museum", loot_instance), "侦察撤离：实例ID已记录")
	await _free_museum(museum1)

	var museum2 := await _make_museum()
	check(Game.is_room_visited("museum", start_zone), "侦察撤离后：已探房间保留")
	if second_room != -1:
		check(Game.is_room_visited("museum", second_room), "侦察撤离后：第二个房间记录保留")
	var respawned := false
	for child in museum2.get_children():
		if child is Artifact and child.instance_id == loot_instance:
			respawned = true
			break
	check(not respawned, "侦察撤离后：已带出实例不再刷新")
	await _free_museum(museum2)


func _test_reset_clears_exploration() -> void:
	Game.level_visited_rooms["museum"] = {0: true, 1: true}
	Game.level_taken_items["museum"] = ["museum:5,5"]
	Game.reset_progress()
	check(Game.level_visited_rooms.is_empty(), "新游戏：已探房间清空")
	check(Game.level_taken_items.is_empty(), "新游戏：已取实例清空")
