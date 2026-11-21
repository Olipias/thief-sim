extends SceneTree
## 玩家进度自检（独立验收）：结算 / 仓库 / 收集册 / 存档健壮性。
##
## 关注点：任何可能让玩家"丢进度、白干、重复领奖、被没收的赃物复活"的边角。
## 与 test_logic 的分工：那边测规则主路径，这里测跨会话持久化与失败路径。
##
## 运行：godot --headless --script tests/test_progression.gd
## 失败以非零退出码结束；临时存档写入 /tmp。

const DIR := "/tmp/thief_sim_progression"

var _failures := 0
var _checks := 0


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL - " + msg)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	_test_bust_confiscates_and_persists()
	_test_finish_is_idempotent()
	_test_stash_persists()
	_test_sell_edges()
	_test_archive_lifecycle()
	_test_save_robustness()
	_test_new_game_clears_everything()
	_test_r05_reservation_and_delivery()
	_test_r12a_shop_loadout()
	_test_r12a_selective_loadout()
	_test_r12a_smoke_cross_run()

	if _failures > 0:
		print("FAILED %d / %d checks" % [_failures, _checks])
		quit(1)
	else:
		print("ALL %d CHECKS PASSED" % _checks)
		quit(0)


# ---------------------------------------------------------------- R-05 预约/交货

func _test_r05_reservation_and_delivery() -> void:
	var gs = _new_game(DIR + "/r05_trade.json")
	gs.reset_progress()
	gs.loot_stash.clear()
	gs.loot_stash.append("vase")
	gs.loot_stash.append("gem")
	var money0: int = gs.money

	# 预约不扣货、不发钱；取出后打 reserved 标记，交货只收一次钱。
	check(gs.reserve_loot(0), "R-05：预约花瓶成功")
	check(gs.loot_stash.size() == 2 and gs.money == money0, "R-05：预约不扣货不发钱")
	check(int(gs.loot_reserved.get("vase", 0)) == 1, "R-05：预约计数 +1")
	check(gs.take_stash_item(0), "R-05：取出预约花瓶到随身")
	check(gs.loot_stash.size() == 1, "R-05：取出后箱内减少")
	check(not gs.loot_reserved.has("vase"), "R-05：取出一件后预约额度清零")
	check(gs.bag_items.size() == 1 and bool(gs.bag_items[0].get("reserved", false)), "R-05：随身花瓶带 reserved 标记")
	var paid: Dictionary = gs.deliver_reserved_items()
	check(bool(paid.get("ok", false)) and int(paid.get("paid", 0)) == gs.item_value("vase"), "R-05：门口交货按价值付款")
	check(gs.money == money0 + gs.item_value("vase"), "R-05：交货只加一次钱")
	check(gs.bag_items.is_empty(), "R-05：交货后随身清空")
	var again: Dictionary = gs.deliver_reserved_items()
	check(not bool(again.get("ok", false)) and gs.money == money0 + gs.item_value("vase"), "R-05：重复交货不重复付款")

	# 取消预约：不吞货、不退款。
	gs.reset_progress()
	gs.loot_stash.clear()
	gs.loot_stash.append("vase")
	check(gs.reserve_loot(0), "R-05：再次预约")
	check(gs.cancel_loot_reservation(0), "R-05：取消预约")
	check(gs.loot_stash.size() == 1 and gs.loot_reserved.is_empty(), "R-05：取消后货物与计数恢复")

	# 多件同 id：取走一件并交货，不应清掉另一件仍在箱内的预约。
	gs.reset_progress()
	gs.loot_stash.clear()
	gs.loot_stash.append("vase")
	gs.loot_stash.append("vase")
	check(gs.reserve_loot(0) and gs.reserve_loot(1), "R-05：两件花瓶都预约")
	check(int(gs.loot_reserved.get("vase", 0)) == 2, "R-05：预约计数为 2")
	check(gs.take_stash_item(0), "R-05：取出一件预约花瓶")
	check(int(gs.loot_reserved.get("vase", 0)) == 1, "R-05：另一件预约额度仍保留")
	check(gs.deliver_reserved_items().get("ok", false), "R-05：交付随身预约货")
	check(int(gs.loot_reserved.get("vase", 0)) == 1, "R-05：交货不应清掉箱内另一件预约")

	# 预约中的箱内物品不能被旧销赃页直接卖掉（否则预约计数会悬空）。
	gs.reset_progress()
	gs.loot_stash.clear()
	gs.loot_stash.append("vase")
	check(gs.reserve_loot(0), "R-05：预约花瓶用于卖出保护")
	check(gs.sell_stash_item(0) == 0, "R-05：预约中的箱内物品不可直接卖出")
	check(gs.loot_stash.size() == 1, "R-05：预约货仍在箱内")
	check(int(gs.loot_reserved.get("vase", 0)) == 1, "R-05：卖出保护不吞预约计数")

	# 「全部出手」也不能把预约货卖掉；只结算未预约部分。
	gs.loot_stash.append("gem")
	var sold_all: int = gs.sell_all_stash()
	check(sold_all == gs.item_value("gem"), "R-05：全部出手只卖未预约货（实际 %d）" % sold_all)
	check(gs.loot_stash.size() == 1 and String(gs.loot_stash[0]) == "vase", "R-05：全部出手后预约货仍在箱内")
	check(int(gs.loot_reserved.get("vase", 0)) == 1, "R-05：全部出手不清预约计数")

	# 主目标不可进入普通交易。
	gs.reset_progress()
	gs.loot_stash.clear()
	gs.loot_stash.append("ram_zun")
	check(not gs.reserve_loot(0), "R-05：主目标不可普通预约")
	check(gs.loot_reserved.is_empty(), "R-05：主目标未写入预约")

	# 同一件不能重复预约超过库存；连续点两次第二次应失败，且计数仍为 1。
	gs.reset_progress()
	gs.loot_stash.clear()
	gs.loot_stash.append("vase")
	check(gs.reserve_loot(0), "R-05：单件预约成功")
	check(not gs.reserve_loot(0), "R-05：同一件不能重复预约超过库存")
	check(int(gs.loot_reserved.get("vase", 0)) == 1, "R-05：重复预约不增加计数")

	# 读档：预约/随身标记保留；交货后重读不重复付款。
	var path := DIR + "/r05_roundtrip.json"
	gs.save_path = path
	gs.reset_progress()
	gs.loot_stash.clear()
	gs.loot_stash.append("gem")
	gs.reserve_loot(0)
	gs.take_stash_item(0)
	gs.save_game()
	gs.free()
	var reader = _new_game(path)
	reader.load_game()
	check(reader.bag_items.size() == 1 and bool(reader.bag_items[0].get("reserved", false)), "R-05：读档保留随身 reserved 标记")
	var before: int = reader.money
	var r1: Dictionary = reader.deliver_reserved_items()
	check(bool(r1.get("ok", false)) and reader.money == before + reader.item_value("gem"), "R-05：读档后交货付款一次")
	reader.save_game()
	reader.free()
	var reader2 = _new_game(path)
	reader2.load_game()
	var r2: Dictionary = reader2.deliver_reserved_items()
	check(not bool(r2.get("ok", false)) and reader2.money == before + reader2.item_value("gem"), "R-05：交货后重读不重复付款")
	reader2.free()
	# （gs 已在上方 save_game 后 free，不能重复 free——否则 native double-free 中断整个套件。）


## R-12a 采购/备货/出发装载：购买入备货、出发并入携带、局内消耗只动携带数、
## 无钱不可购买、旧档兼容；回放/失败恢复不触碰局外购物（购买即时落盘）。
func _test_r12a_shop_loadout() -> void:
	var gs = _new_game(DIR + "/r12a_shop.json")
	gs.reset_progress()
	gs.money = 500
	var smoke_price: int = gs.upgrade_price("smoke")
	var sneakers_price: int = gs.upgrade_price("sneakers")

	# 购买入备货：一次点击一次扣款一次发货；携带数不动。
	check(gs.buy("smoke"), "R-12a：购买烟雾弹成功")
	check(gs.money == 500 - smoke_price, "R-12a：购买扣款一次")
	check(gs.smoke_stock == 1, "R-12a：备货 +1")
	check(gs.smoke_count == 0, "R-12a：购买不动携带数（库存/携带分离）")
	gs.buy("smoke")
	check(gs.smoke_stock == 2, "R-12a：再买一件备货 +1")

	# 出发装载：备货并入携带并清空。
	gs.load_outgoing_loadout()
	check(gs.smoke_count == 2, "R-12a：出发时备货并入携带")
	check(gs.smoke_stock == 0, "R-12a：装载后备货清空")
	# 馆内消耗只动携带数（use_smoke 既有语义）。
	var carried_before: int = gs.smoke_count
	check(gs.use_smoke(), "R-12a：馆内使用烟雾消耗携带")
	check(gs.smoke_count == carried_before - 1, "R-12a：消耗只减携带数，备货不再变化")

	# 回放不倒退局外购物：消耗回滚由世界快照负责，局外购买落盘不受影响。
	var stock_snapshot: int = gs.smoke_stock
	var money_snapshot: int = gs.money
	gs.save_game()
	var reader = _new_game(DIR + "/r12a_shop.json")
	reader.load_game()
	check(reader.smoke_stock == stock_snapshot, "R-12a：读档备货一致（回放不倒退局外）")
	check(reader.money == money_snapshot, "R-12a：读档金币一致（无重复扣款）")
	reader.free()

	# 无钱不可购买：钱包为零时按钮门禁拒绝。
	gs.money = 0
	check(not gs.can_buy("smoke"), "R-12a：无钱不可购买烟雾弹")
	check(not gs.buy("smoke"), "R-12a：无钱购买失败且不扣款")
	check(gs.money == 0 and gs.smoke_stock == 0, "R-12a：失败购买无副作用")

	# 永久装备：跑鞋购买后立即生效且不重复上架。
	gs.money = sneakers_price
	check(gs.buy("sneakers"), "R-12a：购买跑鞋成功")
	check(gs.has_sneakers, "R-12a：跑鞋立即生效")
	check(not gs.can_buy("sneakers"), "R-12a：已拥有不可再购买")

	# G06/#895 计划上限：范围 [0, 已携带 + 备货]；已带 1/购 2 后总量 3，仍可任选计划。
	gs.money = 300  # 备两颗烟雾弹（240 金）
	gs.buy("smoke")
	gs.buy("smoke")
	gs.load_outgoing_loadout()  # 未设置 → 总量(已带1+备货2=3)全部并入携带
	check(gs.smoke_count == 3 and gs.smoke_stock == 0, "装载：未计划默认全部携带（实际 %d/%d）" % [gs.smoke_count, gs.smoke_stock])
	check(gs.smoke_carry_plan == -1, "装载：计划未设置保持 -1")
	gs.set_smoke_carry_plan(2)
	gs.load_outgoing_loadout()
	check(gs.smoke_count == 2 and gs.smoke_stock == 1, "装载：计划 2 结算为携带 2/备货 1（实际 %d/%d）" % [gs.smoke_count, gs.smoke_stock])
	gs.set_smoke_carry_plan(4)  # 超过总量：夹取到 3，保持在合法范围
	check(gs.smoke_carry_plan == 3, "装载：超量计划夹取到总量（实际 %d）" % gs.smoke_carry_plan)
	gs.set_smoke_carry_plan(0)
	gs.load_outgoing_loadout()
	check(gs.smoke_count == 0 and gs.smoke_stock == 3, "装载：计划 0 全部退回备货（实际 %d/%d）" % [gs.smoke_count, gs.smoke_stock])
	gs.set_smoke_carry_plan(2)
	gs.load_outgoing_loadout()
	check(gs.smoke_count == 2 and gs.smoke_stock == 1, "装载：再次结算到计划 2")
	gs.free()


## G20261121-06.2：玩家明确选择装载量（可选 0），余量留库存；
## 重复出发不复制/不倒退。
func _test_r12a_selective_loadout() -> void:
	var gs = _new_game(DIR + "/r12a_plan.json")
	gs.reset_progress()
	gs.money = 500
	gs.loot_stash.clear()
	# 未设置计划（-1）= 旧行为：全部携带。
	gs.buy("smoke")
	gs.buy("smoke")
	check(gs.smoke_stock == 2, "装载：备货 2 件")
	gs.load_outgoing_loadout()
	check(gs.smoke_count == 2 and gs.smoke_stock == 0, "装载：未计划默认全部携带（v0.26.4 兼容）")

	# 明确计划 0：结算语义——已携带的退回备货（总量守恒）。
	gs.buy("smoke")
	gs.set_smoke_carry_plan(0)
	gs.load_outgoing_loadout()
	check(gs.smoke_count == 0 and gs.smoke_stock == 3, "装载：计划 0 = 携带清零、退回备货（实际 %d/%d）" % [gs.smoke_count, gs.smoke_stock])

	# 明确计划 1/2：结算到计划值；重复出发从当前备货扣除，不复制。
	gs.set_smoke_carry_plan(1)
	gs.load_outgoing_loadout()
	check(gs.smoke_count == 1 and gs.smoke_stock == 2, "装载：计划 1 携带一件（实际 %d/%d）" % [gs.smoke_count, gs.smoke_stock])
	check(gs.smoke_carry_plan == 1, "装载：计划保留供下次沿用")

	# G20261121-06 边界：已携带 2、备货 0 时仍可选择继续带 2；
	# 上限必须是携带+备货总量，不能只看备货。
	gs.smoke_count = 2
	gs.smoke_stock = 0
	gs.smoke_carry_plan = -1
	gs.set_smoke_carry_plan(2)
	check(gs.smoke_carry_plan == 2, "装载：备货 0、已携带 2 仍可选计划 2（实际 %d）" % gs.smoke_carry_plan)
	gs.load_outgoing_loadout()
	check(gs.smoke_count == 2 and gs.smoke_stock == 0, "装载：计划 2 保持携带 2 不回退（实际 %d/%d）" % [gs.smoke_count, gs.smoke_stock])
	gs.set_smoke_carry_plan(5)
	check(gs.smoke_carry_plan == 2, "装载：超过总量按携带+备货夹到 2（实际 %d）" % gs.smoke_carry_plan)
	gs.free()

	# 大英博物馆拾取规则（G20261121-06.1）：普通战利品可拾；主文物一次一件。
	gs = _new_game(DIR + "/r06_bm_pickup.json")
	gs.reset_progress()
	gs.set_level("british_museum")
	gs.reset_run()
	# 主文物：空包先拾目标（双羊尊占 3 格，先于小件拾取）。
	check(gs.try_pickup("ram_zun"), "大英：主文物可拾取")
	check(gs.mission_complete, "大英：携带目标 → mission_complete")
	# 普通战利品随时可拾（新手包 2×2：双羊尊 3 格 + 花瓶 1 格 = 满包）。
	check(gs.try_pickup("vase"), "大英：普通战利品可拾取")
	check(not gs.try_pickup("gem"), "大英：背包满时不再拾取")
	# 已带主文物后再拾另一件主文物被拒（先丢弃花瓶腾位，证明拒绝与格数无关）。
	gs.erase_item_at(1)
	gs.set_bm_target("egypt_heart_scarab")
	check(not gs.try_pickup("egypt_heart_scarab"), "大英：一次行动只带一件主文物")
	# 教学关（museum）没有 Game 层拾取门禁：出口的“必须带目标”由
	# mission_complete/教学关出口逻辑把关，普通物拾取本就允许。
	gs.reset_progress()
	gs.set_level("museum")
	gs.reset_run()
	check(gs.try_pickup("vase"), "教学：普通物可拾（带目标要求由出口把关）")
	check(not gs.mission_complete, "教学：未带目标不完成任务")
	check(gs.try_pickup("mask"), "教学：拾取任务目标")
	check(gs.mission_complete, "教学：带目标完成任务")
	gs.free()


## R-12a 跨次携带：本次总携带数结算、未选携带回备货、重复调用不复制、读档守恒。
func _test_r12a_smoke_cross_run() -> void:
	var gs = _new_game(DIR + "/r12a_smoke_cross.json")
	gs.reset_progress()
	# 上一趟剩 1 颗携带，备货 2；本次选择 0。
	gs.smoke_count = 1
	gs.smoke_stock = 2
	gs.smoke_carry_plan = 0
	gs.load_outgoing_loadout()
	check(gs.smoke_count == 0, "R-12a 跨次：选 0 时携带清零（实际 %d）" % gs.smoke_count)
	check(gs.smoke_stock == 3, "R-12a 跨次：未携带的 1 颗回备货（实际 %d）" % gs.smoke_stock)

	# 再选 2：携带 2、备货 1，总数守恒。
	gs.smoke_carry_plan = 2
	gs.load_outgoing_loadout()
	check(gs.smoke_count == 2, "R-12a 跨次：选 2 后携带 2（实际 %d）" % gs.smoke_count)
	check(gs.smoke_stock == 1, "R-12a 跨次：选 2 后备货 1（实际 %d）" % gs.smoke_stock)
	var total: int = int(gs.smoke_count) + int(gs.smoke_stock)
	# 重复调用不得再搬一次。
	gs.load_outgoing_loadout()
	check(gs.smoke_count + gs.smoke_stock == total, "R-12a 跨次：重复装载不改变总数")
	check(gs.smoke_count == 2 and gs.smoke_stock == 1, "R-12a 跨次：重复装载不额外移物")

	# 读档后总携带/备货仍守恒，重复装载不复制。
	gs.save_path = DIR + "/r12a_smoke_cross.json"
	gs.save_game()
	gs.free()
	var reader = _new_game(DIR + "/r12a_smoke_cross.json")
	reader.load_game()
	check(reader.smoke_count == 2 and reader.smoke_stock == 1, "R-12a 跨次：读档携带/备货守恒")
	reader.load_outgoing_loadout()
	check(reader.smoke_count + reader.smoke_stock == total, "R-12a 跨次：读档后重复装载不复制")
	reader.free()


# ---------------------------------------------------------------- 工具

func _new_game(path: String):
	var gs = load("res://src/autoload/game_state.gd").new()
	gs.save_path = path
	gs._persistent = true
	return gs


func _fresh_path(name: String) -> String:
	var path := DIR + "/" + name
	for suffix in ["", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	return path


func _write_raw(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _reload(path: String):
	var gs = _new_game(path)
	gs.load_game()
	return gs


# ---------------------------------------------------------------- 用例

## 被逮捕 = 没收赃物。没收必须落盘：退出重开/读档后，赃物与任务目标不得复活。
func _test_bust_confiscates_and_persists() -> void:
	var path := _fresh_path("bust.json")
	var gs = _new_game(path)
	gs.reset_progress()
	gs.set_level("museum")
	gs.reset_run()
	check(gs.try_pickup("mask"), "被逮用例：拾取任务目标")
	check(gs.try_pickup("vase"), "被逮用例：拾取普通赃物")
	check(FileAccess.file_exists(path), "拾取会自动落盘（归档 + 背包）")

	var summary: Dictionary = gs.finish_run(false)
	check(not summary["success"], "被逮：结算为失败")
	check(gs.bag_items.is_empty(), "被逮：内存中的赃物被没收")
	check(not gs.mission_complete, "被逮：任务完成标记清空")
	gs.free()

	var reader = _reload(path)
	check(reader.bag_items.is_empty(), "被逮后读档：赃物不得复活")
	check(not reader.mission_complete, "被逮后读档：任务不得处于完成态")
	check(reader.is_archived("mask"), "被逮后读档：接触过的文物档案仍保留（设计如此）")
	reader.free()


## 结算只能发一次奖 / 入一次仓（重复调用或重复信号不得刷钱）。
func _test_finish_is_idempotent() -> void:
	var path := _fresh_path("finish.json")
	var gs = _new_game(path)
	gs.reset_progress()
	gs.set_level("museum")
	gs.reset_run()
	gs.try_pickup("mask")
	gs.try_pickup("vase")
	var first: Dictionary = gs.finish_run(true)
	check(first["success"], "结算：带目标撤离成功")
	var money_after: int = gs.money
	var stash_after: int = gs.loot_stash.size()
	var second: Dictionary = gs.finish_run(true)
	check(not second["success"], "结算：第二次调用被拒绝")
	check(gs.money == money_after, "结算：不会重复发放报酬")
	check(gs.loot_stash.size() == stash_after, "结算：不会重复存入仓库")
	gs.free()


## 仓库与金币必须跨会话保留；报酬与赃物估值分开记账。
func _test_stash_persists() -> void:
	var path := _fresh_path("stash.json")
	var gs = _new_game(path)
	gs.reset_progress()
	gs.set_level("museum")
	gs.reset_run()
	gs.try_pickup("mask")
	gs.try_pickup("vase")   # 120
	gs.try_pickup("gem")    # 300
	var summary: Dictionary = gs.finish_run(true)
	check(int(summary["stash_value"]) == 420, "仓库：估值 = 120 + 300")
	check(gs.money == gs.MISSION_REWARD, "仓库：撤离当下只入账组织报酬")
	gs.free()

	var reader = _reload(path)
	check(reader.loot_stash.size() == 2, "仓库：读档后战利品还在")
	check(reader.stash_value() == 420, "仓库：读档后估值不变")
	check(reader.money == reader.MISSION_REWARD, "仓库：读档后金币不变")
	reader.free()


## 卖店边界：非法下标不得扣物品/加钱；卖空后再次全卖不得刷钱。
func _test_sell_edges() -> void:
	var path := _fresh_path("sell.json")
	var gs = _new_game(path)
	gs.reset_progress()
	var stash: Array[String] = ["vase", "gem"]
	gs.loot_stash = stash
	gs.money = 10

	check(gs.sell_stash_item(-1) == 0, "卖店：非法下标 -1 返回 0")
	check(gs.sell_stash_item(99) == 0, "卖店：越界下标返回 0")
	check(gs.money == 10 and gs.loot_stash.size() == 2, "卖店：非法下标不改变状态")

	check(gs.sell_stash_item(0) == 120, "卖店：卖出第一件得 120")
	check(gs.money == 130, "卖店：金币入账")
	check(gs.loot_stash.size() == 1 and gs.loot_stash[0] == "gem", "卖店：剩余物品正确")

	check(gs.sell_all_stash() == 300, "卖店：全部出手得剩余估值")
	check(gs.money == 430, "卖店：全卖后金币正确")
	check(gs.sell_all_stash() == 0 and gs.money == 430, "卖店：卖空后再次全卖不刷钱")
	gs.free()


## 收集册：首次接触即归档、普通赃物不计入、重置才清空、进度跨会话保留。
func _test_archive_lifecycle() -> void:
	var path := _fresh_path("archive.json")
	var gs = _new_game(path)
	gs.reset_progress()
	check(not gs.is_archived("mask"), "收集册：初始未归档")

	gs.set_level("museum")
	gs.reset_run()
	check(gs.try_pickup("vase"), "收集册：拾取普通赃物")
	check(gs.is_archived("vase"), "收集册：接触即记住（普通赃物也记住）")
	check(gs.archived_count() == 0, "收集册：普通赃物不计入真实文物")
	check(gs.try_pickup("mask"), "收集册：拾取真实文物")
	check(gs.archived_count() == 1, "收集册：真实文物计数 +1")

	gs.reset_run()
	check(gs.is_archived("mask") and gs.archived_count() == 1, "收集册：开新一局不清档案")
	gs.free()

	var reader = _reload(path)
	check(reader.is_archived("mask"), "收集册：读档后仍归档")
	reader.reset_progress()
	check(not reader.is_archived("mask") and reader.archived_count() == 0, "收集册：新游戏清空")
	reader.free()


## 存档健壮性：损坏档不能被当成"可继续"；半写残留不得影响读档；写档不得留下 .tmp。
func _test_save_robustness() -> void:
	var path := _fresh_path("robust.json")
	var gs = _new_game(path)
	gs.reset_progress()
	gs.money = 42
	gs.save_game()
	check(FileAccess.file_exists(path), "存档：写入主档")
	check(not FileAccess.file_exists(path + ".tmp"), "存档：不残留 .tmp 临时文件")

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(typeof(parsed) == TYPE_DICTIONARY, "存档：主档是合法 JSON")
	check(int((parsed as Dictionary).get("money", -1)) == 42, "存档：主档内容正确")

	# 模拟"写到一半崩溃"：主档被截断。不能把损坏档当作可继续，也不能崩。
	_write_raw(path, '{"money": 42, "bag_items": [')
	check(not gs.has_save(), "存档：损坏档不提供「继续游戏」")
	var reader = _reload(path)
	check(reader.money == 0 and reader.bag_items.is_empty(), "存档：损坏档安全回退为空进度")
	reader.free()

	# 残留 .tmp（上次崩溃）不得影响主档读取
	_write_raw(path, '{"money": 7}')
	_write_raw(path + ".tmp", '{"money": 999}')
	var reader2 = _reload(path)
	check(reader2.money == 7, "存档：残留 .tmp 不被当作主档")
	reader2.free()
	DirAccess.remove_absolute(path + ".tmp")
	gs.free()


## 新游戏必须清空一切进度并立刻落盘（避免旧档复活）。
func _test_new_game_clears_everything() -> void:
	var path := _fresh_path("newgame.json")
	var gs = _new_game(path)
	gs.money = 500
	var stash: Array[String] = ["gem"]
	gs.loot_stash = stash
	gs.archive_seen = {"mask": true}
	gs.lore_stage = {"mask": 2}
	gs.save_game()
	check(gs.has_save(), "新游戏用例：旧档已存在")

	gs.start_new_game()
	check(gs.money == 0 and gs.loot_stash.is_empty() and gs.archive_seen.is_empty(), "新游戏：内存进度清空")
	check(gs.lore_stage.is_empty(), "新游戏：文物志进度清空")
	gs.free()

	var reader = _reload(path)
	check(reader.money == 0 and reader.loot_stash.is_empty(), "新游戏：读档确认旧进度未复活")
	check(not reader.is_archived("mask") and reader.lore_stage_of("mask") == 0, "新游戏：档案/文物志已清空")
	reader.free()
