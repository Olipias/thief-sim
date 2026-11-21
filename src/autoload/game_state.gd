extends Node
## Global run & progression state: money, grid backpack, upgrades, save file.
## Autoloaded as "Game".  Stats persist in user://save.json between sessions.

signal backpack_changed
signal money_changed
signal items_changed
signal pending_mission_changed(level_id: String)

const MISSION_REWARD := 200
const DEFAULT_SAVE_PATH := "user://save.json"

## 行动结算类型
const OUTCOME_SUCCESS := "success"
const OUTCOME_RECON := "recon"
const OUTCOME_CAUGHT := "caught"

## 关卡注册表：id → 名称 / 地图数据 / 任务目标文物 / 组织报酬。
## 新增关卡时在此登记，并保证目标文物在 CATALOG 中 is_target=true。
const LEVELS := {
	"museum": {
		"name": "城西博物馆",
		"map": "res://src/levels/museum_map.json",
		"target": "mask",
		"reward": 200,
	},
	"british_museum": {
		"name": "大英博物馆",
		"map": "res://src/levels/british_museum.json",
		"target": "ram_zun",
		"reward": 400,
	},
}

## 大英博物馆各目标对应的展厅名（P6）。
const BM_HALL_NAMES := {
	"ram_zun": "中国馆",
	"egypt_stela": "埃及馆",
	"egypt_heart_scarab": "埃及馆",
	"greek_relief": "希腊馆",
	"akrotiri_askos": "希腊馆",
}

## Grid size (in cells) per backpack upgrade level.
const BAG_SIZES: Array[Vector2i] = [
	Vector2i(2, 2),
	Vector2i(3, 2),
	Vector2i(3, 3),
	Vector2i(4, 3),
	Vector2i(4, 4),
	Vector2i(5, 4),
]

## Footprints in cell offsets.  Rotation is 90° clockwise steps at runtime.
const SHAPES := {
	"egypt_heart_scarab": [Vector2i(0, 0), Vector2i(1, 0)],
	"akrotiri_askos": [Vector2i(0, 0), Vector2i(0, 1)],
	"mask": [Vector2i(0, 0), Vector2i(1, 0)],
	"vase": [Vector2i(0, 0)],
	"gem": [Vector2i(0, 0)],
	"ingot": [Vector2i(0, 0)],
	"scroll": [Vector2i(0, 0), Vector2i(0, 1)],
	"jade": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],
	"ram_zun": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
	"egypt_stela": [Vector2i(0, 0), Vector2i(1, 0)],
	"greek_relief": [Vector2i(0, 0), Vector2i(0, 1)],
}

const CATALOG := {
	"egypt_heart_scarab": {
		"name": "心形圣甲虫", "value": 0, "is_target": true,
		"story": "埃及晚期深绿色石材护符，约前664–332年，长6.1厘米。大都会艺术博物馆编号10.130.1650，Helen Miller Gould于1910年捐赠。游戏借展与追索人物均为虚构。",
	},
	"akrotiri_askos": {
		"name": "阿克罗蒂里彩绘注壶", "value": 0, "is_target": true,
		"story": "约前1650–1615年的陶制注壶，发现于阿克罗蒂里西屋。UNESCO失窃文物虚拟博物馆编号VM-GR-25-012，由希腊提交；公开条目未交代失窃经过及现藏地。游戏展出地点为虚构。",
	},
	"mask": {
		"name": "青铜人面具",
		"value": 0,
		"is_target": true,
		"story": "商代晚期青铜人面饰（约前 13—前 11 世纪），1976 年陕西城固苏村小冢窖藏出土，同批面具 23 件。脸形椭圆，嘴角上扬，被观众称作「三千年前的微笑」。现藏城固县博物馆。",
	},
	"ram_zun": {
		"name": "商代双羊尊",
		"value": 0,
		"is_target": true,
		"story": "商代晚期青铜酒器（约前1200–1050年），相传出自湖南，存世仅两件。双羊相背共负一尊，羊角盘曲，是南方青铜器独有的写实与浪漫。另一件如今在东京，这一件自1936年起站在大英博物馆的展柜里。",
	},
	"egypt_stela": {
		"name": "书吏彩绘墓碑",
		"value": 0,
		"is_target": false,
		"story": "新王国第19王朝石灰岩彩绘祠堂形墓碑（约前1250年），出自底比斯代尔麦地那工匠村。1823年经英国驻埃及总领事Henry Salt之手售予大英博物馆，编号EA191。碑主为王陵石匠Qaha，边缘留有楔槽。",
	},
	"greek_relief": {
		"name": "帕特农骑手浮雕",
		"value": 0,
		"is_target": false,
		"story": "古典时期潘泰列克大理石浮雕（约前447–432年），原属雅典卫城帕特农神庙北翼浮雕带。1801–1805年由额尔金伯爵团队拆运，1816年英国议会购入，编号1816,0610.28。",
	},
	"vase": {
		"name": "青瓷花瓶",
		"value": 120,
		"is_target": false,
		"story": "瓶底烧着「景德年制」，可景德年间根本没有这个年号。",
	},
	"gem": {
		"name": "夜明珠",
		"value": 300,
		"is_target": false,
		"story": "珠中的光点会缓慢移动，像被关在里面的萤火虫。",
	},
	"scroll": {
		"name": "古画轴",
		"value": 60,
		"is_target": false,
		"story": "画卷展开后会多出一截空白，第二天再看，空白处似乎有了墨痕。",
	},
	"ingot": {
		"name": "金锭",
		"value": 80,
		"is_target": false,
		"story": "金锭侧面刻着一个「囚」字，边缘被指印磨得发亮。",
	},
	"jade": {
		"name": "玉璧",
		"value": 200,
		"is_target": false,
		"story": "内圈有一道新裂痕，凑近能听见极轻的叹息。",
	},
}

## 文物档案（真实文物必填；与 docs/SOURCES.md 一一对应）。
const ARCHIVE := {
	"egypt_heart_scarab": {
		"era": "埃及晚期（约前664–332年）", "origin": "埃及",
		"collection": "大都会艺术博物馆 · 10.130.1650",
		"provenance": "Helen Miller Gould于1910年捐赠，早期流转尚未详述。",
		"legend": "本件正式追索未核实；游戏标记有争议 / 追索中仅指虚构委托，不能代指现实请求。",
	},
	"akrotiri_askos": {
		"era": "晚期基克拉泽斯一期（约前1650–1615年）", "origin": "阿克罗蒂里西屋",
		"collection": "现藏地未公开确认 · UNESCO VM-GR-25-012",
		"provenance": "UNESCO失窃文物虚拟博物馆收录，由希腊提交；未详述失窃经过。",
		"legend": "归属议题有争议 / 追索中；游戏展出、维护与中间人均属虚构。",
	},
	"mask": {
		"era": "商代晚期（约前 13—前 11 世纪）",
		"origin": "汉中城固、洋县一带",
		"collection": "城固县博物馆等",
		"provenance": "1976 年，城固苏村的一处姜窖下，23 张脸重见天日。",
		"legend": "「三千年前的微笑」——馆里的人这么叫它。",
	},
	"ram_zun": {
		"era": "商代晚期（约前 1200—1050 年）",
		"origin": "湖南（风格推定）",
		"collection": "大英博物馆 · 1936,1118.1",
		"provenance": "1936 年，它随一位英国收藏家的旧藏进入大英博物馆。",
		"legend": "中国学界与民间长期关注其来源，相关文物追索中；大英博物馆档案只记录到 1936 年收购。",
	},
	"egypt_stela": {
		"era": "新王国第 19 王朝（约前 1250 年）",
		"origin": "底比斯（代尔麦地那工匠村）",
		"collection": "大英博物馆 · EA191",
		"provenance": "19 世纪初经英国驻埃及总领事 Henry Salt 收集，1823 年售予大英博物馆。",
		"legend": "其脱离埃及的具体授权文件存在争议，埃及方面多次提出追索。",
	},
	"greek_relief": {
		"era": "古典时期（约前 447–432 年）",
		"origin": "雅典卫城帕特农神庙北翼浮雕带",
		"collection": "大英博物馆 · 1816,0610.28",
		"provenance": "1801–1805 年由额尔金伯爵团队拆运，1816 年英国议会购入交大英博物馆。",
		"legend": "希腊政府与国际学者长期质疑当年奥斯曼许可文书的原件存否与权限范围，相关归属有争议、追索中。",
	},
}

const UPGRADES := {
	"backpack": {
		"name": "加固背包",
		"desc": "背包格子扩容",
		"kind": "level",
		"price": 250,
		"price_step": 250,
		"max_level": 5,
	},
	"sneakers": {
		"name": "静音跑鞋",
		"desc": "疾跑速度提升 25%",
		"kind": "permanent",
		"price": 400,
	},
	"smoke": {
		"name": "烟雾弹",
		"desc": "脱身道具：附近警察短暂失去目标",
		"kind": "consumable",
		"price": 120,
	},
}

var money := 0
var backpack_level := 0
var has_sneakers := false
var smoke_count := 0

## R-12a 备货库存：手机「采购」买下的烟雾弹数量（只增字段，老档默认 0）。
## 库存与携带分离：购买入备货，不改变携带数；出发（start_mission）时按
## `smoke_carry_plan` 并入携带 smoke_count 并清空——进馆后 Q 消耗只影响携带数。
## 回放/失败恢复不改备货。
var smoke_stock := 0

## 出发计划携带数（R-12a 玩家明确选择，可为 0）：-1 = 未设置（默认全部携带，
## 兼容 v0.26.4 语义）；0..smoke_stock 为明确选择。存档只增字段，脏值按 -1。
## 装载量 = clamp(plan, 0, stock)；重复出发不会复制（每次装载都从当前备货扣除）。
var smoke_carry_plan := -1

## 文物志进度：item_id → 下一段序号（0 = 还没聊过）；端详已发现热点：item_id → [索引]
var lore_stage: Dictionary = {}
var lore_found: Dictionary = {}

## 剧情旗标：一次性剧情节点（读标签/留言、面具诚实、双羊信任、结局路由）的持久化。
## 键名约定：read_label / read_note / honest_to_mask / ending_id（字符串）。
## 只增字段进存档：老档缺该键默认为空（读写见 _restore_story_flags）。
var story_flags: Dictionary = {}

## 据点仓库：成功带出但尚未出售的战利品（item_id 列表，玩家在「销赃」页自行决定是否出手）
var loot_stash: Array[String] = []

## R-04 待出发行动：手机「委托」确认后记录的 level_id（"" = 未准备）。
## 出发门禁：安全屋房门只放行已准备的行动；出发时消费（清空），返回安全屋后重新准备。
## 只增字段进存档：老档缺该键默认 ""（读写见 _restore_pending_mission）。
var pending_mission_level := ""

## 文物档案收集：玩家在行动中接触过的文物 id（标题页「文物档案」收集册的解锁依据）
var archive_seen: Dictionary = {}

## 跨次探索知识：level_id → { zone_index: true }。zone 0..rooms.size()-1 为房间，后续为 corridor floor rect。
var level_visited_rooms: Dictionary = {}

## 已带出的普通战利品实例：level_id → ["level:x,y", ...]，防止同一实例重复刷新。
var level_taken_items: Dictionary = {}

## Items currently carried: {id: String, x: int, y: int, rot: int, instance_id?: String}
var bag_items: Array[Dictionary] = []
var mission_complete := false

## 当前关卡与本次任务目标（由 set_level 设定；任务判定实时对照它）。
var current_level_id := "museum"
var mission_target_id := "mask"

## 大英博物馆目标选择（P6）：在 Hub 推理板解锁后切换。
var bm_selected_target := "ram_zun"

## 目标解锁模式（GDD v2）：false = 单条推理链完成即解锁对应目标；true = 三条链全完成才可选。
var unlock_all_chains_required := false

var save_path := DEFAULT_SAVE_PATH
var _persistent := false


func _ready() -> void:
	_persistent = true
	load_game()


## --- bag geometry -----------------------------------------------------------

func bag_cells() -> Vector2i:
	return BAG_SIZES[clampi(backpack_level, 0, BAG_SIZES.size() - 1)]


func bag_capacity_cells() -> int:
	var size := bag_cells()
	return size.x * size.y


func bag_used_cells() -> int:
	var total := 0
	for item in bag_items:
		total += item_cell_count(String(item["id"]))
	return total


func item_cell_count(item_id: String) -> int:
	return (SHAPES.get(item_id, [Vector2i(0, 0)]) as Array).size()


func item_shape(item_id: String, rot: int) -> Array[Vector2i]:
	var base: Array = SHAPES.get(item_id, [Vector2i(0, 0)])
	var cells: Array[Vector2i] = []
	for cell in base:
		var v: Vector2i = cell
		for i in rot % 4:
			v = Vector2i(v.y, -v.x)
		cells.append(v)
	return _normalize(cells)


func _normalize(cells: Array[Vector2i]) -> Array[Vector2i]:
	var min_x := 0
	var min_y := 0
	for c in cells:
		min_x = mini(min_x, c.x)
		min_y = mini(min_y, c.y)
	var out: Array[Vector2i] = []
	for c in cells:
		out.append(c - Vector2i(min_x, min_y))
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return out


func item_cells_in_bag(item: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var origin := Vector2i(int(item["x"]), int(item["y"]))
	for c in item_shape(String(item["id"]), int(item["rot"])):
		out.append(origin + c)
	return out


func bag_can_place(item_id: String, rot: int, gx: int, gy: int, ignore_index := -1) -> bool:
	var size := bag_cells()
	var cells := item_shape(item_id, rot)
	for c in cells:
		var p := Vector2i(gx, gy) + c
		if p.x < 0 or p.y < 0 or p.x >= size.x or p.y >= size.y:
			return false
	for i in bag_items.size():
		if i == ignore_index:
			continue
		var occupied := item_cells_in_bag(bag_items[i])
		for c in cells:
			var p := Vector2i(gx, gy) + c
			if occupied.has(p):
				return false
	return true


## First top-left position the item fits at, trying both orientations.
## Returns Vector2i(-1, -1) when it does not fit anywhere.
func bag_first_fit(item_id: String, rot := 0) -> Vector2i:
	var size := bag_cells()
	for y in size.y:
		for x in size.x:
			if bag_can_place(item_id, rot, x, y):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## Search any fit, preferring the given rotation then the rotated variant.
func bag_auto_fit(item_id: String) -> Dictionary:
	for rot in [0, 1]:
		var pos := bag_first_fit(item_id, rot)
		if pos.x >= 0:
			return {"x": pos.x, "y": pos.y, "rot": rot}
	return {"x": -1, "y": -1, "rot": 0}


func item_at_cell(cell: Vector2i) -> int:
	for i in bag_items.size():
		if item_cells_in_bag(bag_items[i]).has(cell):
			return i
	return -1


func remove_item_at(index: int) -> Dictionary:
	if index < 0 or index >= bag_items.size():
		return {}
	return bag_items[index]


func place_item(item: Dictionary, gx: int, gy: int, rot: int) -> bool:
	var item_id := String(item["id"])
	if not bag_can_place(item_id, rot, gx, gy):
		return false
	var placed := {"id": item_id, "x": gx, "y": gy, "rot": rot}
	var instance_id := String(item.get("instance_id", ""))
	if not instance_id.is_empty():
		placed["instance_id"] = instance_id
	bag_items.append(placed)
	_recompute_mission()
	backpack_changed.emit()
	return true


func erase_item_at(index: int) -> void:
	if index >= 0 and index < bag_items.size():
		bag_items.remove_at(index)
		_recompute_mission()
		backpack_changed.emit()


## The mission target counts as carried only while it is actually in the bag.
func _recompute_mission() -> void:
	mission_complete = false
	for item in bag_items:
		if String(item["id"]) == mission_target_id:
			mission_complete = true
			return


## --- level registry --------------------------------------------------------

## 切换关卡：设定当前关卡与本次任务目标（进关卡前调用）。
func set_level(level_id: String) -> void:
	if not LEVELS.has(level_id):
		return
	current_level_id = level_id
	mission_target_id = String((LEVELS[level_id] as Dictionary)["target"])
	# 大英博物馆目标由推理板动态选择，不由 LEVELS 静态表决定。
	if level_id == "british_museum":
		mission_target_id = bm_selected_target
	_recompute_mission()


## 是否存在**有效**存档（标题界面据此决定「继续游戏」是否可用）。
## 损坏/半写档不算——宁可让玩家走"新游戏"，也不能让「继续」读到空进度。
func has_save() -> bool:
	return typeof(_read_save_dict()) == TYPE_DICTIONARY


## 新游戏：清空进度并覆盖存档文件。
func start_new_game() -> void:
	reset_progress()
	save_game()


func level_name_of(level_id: String) -> String:
	if not LEVELS.has(level_id):
		return level_id
	return String((LEVELS[level_id] as Dictionary).get("name", level_id))


func level_info() -> Dictionary:
	return LEVELS.get(current_level_id, LEVELS["museum"])


func level_name() -> String:
	return String(level_info().get("name", current_level_id))


## 大英博物馆当前/指定目标对应的展厅名（P6）。
func bm_hall_name(target_id: String = "") -> String:
	var id := target_id if target_id != "" else bm_selected_target
	return String(BM_HALL_NAMES.get(id, "中国馆"))


func level_map_path() -> String:
	return String(level_info().get("map", "res://src/levels/museum_map.json"))


func mission_reward() -> int:
	return int(level_info().get("reward", MISSION_REWARD))


## --- per-mission state -----------------------------------------------------

func reset_run() -> void:
	bag_items.clear()
	mission_complete = false
	backpack_changed.emit()


func item_name(item_id: String) -> String:
	return String((CATALOG.get(item_id, {}) as Dictionary).get("name", item_id))


func item_value(item_id: String) -> int:
	return int((CATALOG.get(item_id, {}) as Dictionary).get("value", 0))


func item_story(item_id: String) -> String:
	return String((CATALOG.get(item_id, {}) as Dictionary).get("story", ""))


func item_is_target(item_id: String) -> bool:
	return bool((CATALOG.get(item_id, {}) as Dictionary).get("is_target", false))


## Auto-places the item into the grid (tries both rotations).
## instance_id 用于普通战利品跨次反刷；主目标可空。
##
## 拾取规则（#770/G20261121-06）：
##   - 城西教学关维持旧约束（必须先带目标，单一出口教学要求）。
##   - 大英博物馆：普通战利品可拾；主要文物一次最多带一件（含任务目标，
##     已带任何主文物时再拾另一件主文物会被拒绝）——"一次行动只带走一件"。
func try_pickup(item_id: String, instance_id := "") -> bool:
	if current_level_id == "british_museum":
		if item_is_target(item_id):
			# 主要文物：已带一件（任何主文物）即拒绝第二件。
			for carried in bag_items:
				if item_is_target(String(carried["id"])):
					return false
		# 普通战利品：可自由拾取（受背包格数限制）。
	var fit := bag_auto_fit(item_id)
	if fit["x"] < 0:
		return false
	var payload := {"id": item_id}
	if not instance_id.is_empty():
		payload["instance_id"] = instance_id
	if not place_item(payload, int(fit["x"]), int(fit["y"]), int(fit["rot"])):
		return false
	# 第一次接触 = 归档（即便之后被抓/丢掉，档案页也保留这一页）
	if not archive_seen.has(item_id):
		archive_seen[item_id] = true
		save_game()
	return true


func loot_value() -> int:
	var total := 0
	for item in bag_items:
		total += item_value(String(item["id"]))
	return total


## Settles the run and returns a summary for the result screen.
## 保留旧 bool 签名做兼容：true = 成功带出目标，false = 被逮捕。
func finish_run(success: bool) -> Dictionary:
	return finish_run_outcome(OUTCOME_SUCCESS if success else OUTCOME_CAUGHT)


## 三结局结算：成功带出目标 / 侦察撤离 / 被逮捕。
## outcome: OUTCOME_SUCCESS | OUTCOME_RECON | OUTCOME_CAUGHT
func finish_run_outcome(outcome: String) -> Dictionary:
	var summary := {
		"success": false,
		"recon": false,
		"stash_items": [],
		"stash_value": 0,
		"reward": 0,
		"target_name": "",
		"money_total": money,
		"outcome": outcome,
	}
	match outcome:
		OUTCOME_CAUGHT:
			# 被逮捕：本次携带的赃物全部没收，且立刻落盘——
			# 否则上次拾取时的自动存档会让赃物在"退出重开"后复活。
			bag_items.clear()
			mission_complete = false
			backpack_changed.emit()
			save_game()
			return summary
		OUTCOME_RECON:
			# 侦察撤离：普通战利品入箱，不记主任务完成，不拿报酬。
			var taken: Array[Dictionary] = []
			for item in bag_items:
				var id := String(item["id"])
				taken.append({"name": item_name(id), "value": item_value(id)})
				loot_stash.append(id)
				var instance_id := String(item.get("instance_id", ""))
				if not instance_id.is_empty():
					mark_item_taken(current_level_id, instance_id)
			var stash_value := 0
			for item in taken:
				stash_value += int(item["value"])
			bag_items.clear()
			mission_complete = false
			summary["recon"] = true
			summary["stash_items"] = taken
			summary["stash_value"] = stash_value
			money_changed.emit()
			backpack_changed.emit()
			save_game()
			return summary
		OUTCOME_SUCCESS:
			if not mission_complete:
				# 守卫：调用方若在未带出目标时上报成功，不做任何结算（正常流程不会到这）
				return summary
			var taken: Array[Dictionary] = []
			for item in bag_items:
				var id := String(item["id"])
				var instance_id := String(item.get("instance_id", ""))
				if id != mission_target_id:
					taken.append({"name": item_name(id), "value": item_value(id)})
					loot_stash.append(id)
				else:
					summary["target_name"] = item_name(id)
				if not instance_id.is_empty():
					mark_item_taken(current_level_id, instance_id)
			var stash_value := 0
			for item in taken:
				stash_value += int(item["value"])
			var reward := mission_reward()
			money += reward
			# 赃物不再自动出售：全部存入据点仓库，由玩家在「销赃」页决定
			bag_items.clear()
			mission_complete = false
			# 记录关卡完成，用于据点剧情（H-01 等）触发判定。
			if current_level_id == "museum":
				set_story_flag("completed_museum")
			elif current_level_id == "british_museum":
				set_story_flag("completed_british_museum")
			summary["success"] = true
			summary["stash_items"] = taken
			summary["stash_value"] = stash_value
			summary["reward"] = reward
			summary["money_total"] = money
			money_changed.emit()
			backpack_changed.emit()
			save_game()
			return summary
		_:
			# 未知 outcome 按被捕处理，避免状态悬空。
			bag_items.clear()
			mission_complete = false
			backpack_changed.emit()
			save_game()
			return summary


## --- 文物档案收集 ------------------------------------------------------------

## 已归档：接触过，或（老档兼容）器灵对谈已推进过。
func is_archived(item_id: String) -> bool:
	return archive_seen.has(item_id) or lore_stage_of(item_id) > 0


## 已归档的“真实文物”数量（ARCHIVE 里的条目；不含普通赃物）。
func archived_count() -> int:
	var total := 0
	for item_id in ARCHIVE:
		if is_archived(String(item_id)):
			total += 1
	return total


## --- loot stash ------------------------------------------------------------

func stash_value() -> int:
	var total := 0
	for id in loot_stash:
		total += item_value(id)
	return total


## R-05 预约：item_id → 已预约件数（货物仍留在箱内，预约不扣货不发钱）。
## 只增字段进存档：老档缺省 = {}；脏值按 0 处理。交货/取消按计数释放。
var loot_reserved: Dictionary = {}

## 玩家随身预约货标记：bag_items 条目上的 "reserved": true（取出预约物时打上，
## 存回箱内/交货时清除）。与 loot_reserved 计数一进一出，保持守恒。


## 预约一件箱内战利品（index 对应 loot_stash）：不扣货不发钱，买家到门外等待。
## 主目标（含教学 mask）不可进入普通交易；同一 id 的预约数不得超过箱内存量。
func reserve_loot(index: int) -> bool:
	if index < 0 or index >= loot_stash.size():
		return false
	var id := loot_stash[index]
	if not CATALOG.has(id) or item_is_target(id):
		return false
	var stock := 0
	for stash_id in loot_stash:
		if stash_id == id:
			stock += 1
	if int(loot_reserved.get(id, 0)) >= stock:
		return false
	loot_reserved[id] = int(loot_reserved.get(id, 0)) + 1
	save_game()
	return true


## 取消一件预约（按 item_id 计数减一）：不吞物、不退款，货物回到普通箱内。
func cancel_loot_reservation(index: int) -> bool:
	if index < 0 or index >= loot_stash.size():
		return false
	var id := loot_stash[index]
	var count := int(loot_reserved.get(id, 0))
	if count <= 0:
		return false
	if count == 1:
		loot_reserved.erase(id)
	else:
		loot_reserved[id] = count - 1
	save_game()
	return true


## 取出一件箱内战利品到随身：若该 id 尚有预约额度，取出的这件即预约货（打标记）。
## 返回是否成功（成功时 bag 已通过 bag_auto_fit 放置）。
func take_stash_item(index: int) -> bool:
	if index < 0 or index >= loot_stash.size():
		return false
	var id := loot_stash[index]
	var placed := bag_auto_fit(id)
	if int(placed.get("x", -1)) < 0:
		return false
	loot_stash.remove_at(index)
	var payload := {"id": id, "x": int(placed["x"]), "y": int(placed["y"]), "rot": int(placed.get("rot", 0))}
	var count := int(loot_reserved.get(id, 0))
	if count > 0:
		payload["reserved"] = true
		if count == 1:
			loot_reserved.erase(id)
		else:
			loot_reserved[id] = count - 1
	bag_items.append(payload)
	backpack_changed.emit()
	save_game()
	return true


## 存入一件随身物品进箱（index 对应 bag_items）：预约标记随之回到箱内计数。
func stash_bag_item(index: int) -> bool:
	if index < 0 or index >= bag_items.size():
		return false
	var item: Dictionary = bag_items[index]
	var id := String(item["id"])
	bag_items.remove_at(index)
	loot_stash.append(id)
	if bool(item.get("reserved", false)):
		loot_reserved[id] = int(loot_reserved.get(id, 0)) + 1
	_recompute_mission()
	backpack_changed.emit()
	save_game()
	return true


## 随身预约货（用于门禁与交货清单）：[{index, id, value}]。
func reserved_bag_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in bag_items.size():
		var item: Dictionary = bag_items[i]
		if bool(item.get("reserved", false)):
			var id := String(item["id"])
			out.append({"index": i, "id": id, "value": item_value(id)})
	return out


## 门口交货一次性结算：移除随身预约货并按价值收钱。返回 {paid, items, ok}。
## 幂等：结算后随身不再有 reserved 标记，重复调用/读档重放不会二次收款。
## 只消耗本次交付件数的预约额度：箱内其他预约不受影响。
func deliver_reserved_items() -> Dictionary:
	var goods := reserved_bag_items()
	var result := {"ok": false, "paid": 0, "items": []}
	if goods.is_empty():
		return result
	var paid := 0
	var names := []
	# 从大到小移除，避免索引位移吞错条目。
	for i in range(goods.size() - 1, -1, -1):
		var index := int(goods[i]["index"])
		var id := String(goods[i]["id"])
		var value := int(goods[i]["value"])
		if index < 0 or index >= bag_items.size():
			return {"ok": false, "paid": 0, "items": []}
		if not bool(bag_items[index].get("reserved", false)):
			return {"ok": false, "paid": 0, "items": []}
		names.append(item_name(id))
		paid += value
		bag_items.remove_at(index)
	money += paid
	# 预约额度只描述"箱内承诺"：取出时已随货物转移到随身标记，
	# 交货只消耗随身标记，不再动箱内剩余预约（另一件的承诺保持有效）。
	money_changed.emit()
	backpack_changed.emit()
	save_game()
	result["ok"] = true
	result["paid"] = paid
	result["items"] = names
	return result


## 卖出一件仓库战利品（index 对应 loot_stash），返回卖得金币。
## 已预约的物品不可走旧直售通道（否则预约计数悬空、买家门口空手）。
func sell_stash_item(index: int) -> int:
	if index < 0 or index >= loot_stash.size():
		return 0
	var id := loot_stash[index]
	if int(loot_reserved.get(id, 0)) > 0:
		return 0
	var value := item_value(id)
	loot_stash.remove_at(index)
	money += value
	money_changed.emit()
	save_game()
	return value


## 全部出手，返回总金币。只卖**未预约**的箱内物品（预约货留给门口买家）。
func sell_all_stash() -> int:
	var total := 0
	var sold_indexes: Array[int] = []
	for i in loot_stash.size():
		var id := loot_stash[i]
		if int(loot_reserved.get(id, 0)) > 0:
			continue
		total += item_value(id)
		sold_indexes.append(i)
	if total <= 0:
		return 0
	for i in range(sold_indexes.size() - 1, -1, -1):
		loot_stash.remove_at(sold_indexes[i])
	money += total
	money_changed.emit()
	save_game()
	return total


## --- upgrades & shop -------------------------------------------------------

func upgrade_level(id: String) -> int:
	match id:
		"backpack":
			return backpack_level
		"sneakers":
			return 1 if has_sneakers else 0
		"smoke":
			return smoke_count
	return 0


func upgrade_price(id: String) -> int:
	var info: Dictionary = UPGRADES[id]
	match String(info["kind"]):
		"level":
			return int(info["price"]) + int(info["price_step"]) * backpack_level
		_:
			return int(info["price"])


func is_sold_out(id: String) -> bool:
	var info: Dictionary = UPGRADES[id]
	match String(info["kind"]):
		"level":
			return backpack_level >= int(info["max_level"])
		"permanent":
			return has_sneakers
		_:
			return false


func can_buy(id: String) -> bool:
	return UPGRADES.has(id) and not is_sold_out(id) and money >= upgrade_price(id)


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	money -= upgrade_price(id)
	match id:
		"backpack":
			backpack_level += 1
		"sneakers":
			has_sneakers = true
		"smoke":
			# R-12a：购买入备货库存（库存/携带分离），出发时并入携带数。
			smoke_stock += 1
	items_changed.emit()
	money_changed.emit()
	backpack_changed.emit()
	save_game()
	return true


## 出发装载（R-12a）：把携带数**结算到玩家计划值**（带差量在携带↔备货间搬运，总量守恒）。
## plan = -1（未设置）默认全部携带（携带+备货总量并入携带，兼容 v0.26.4）；
## 0 = 明确不带（已携带的退回备货）；>0 取 min(plan, 总量)。重复调用不再搬运。
func load_outgoing_loadout() -> void:
	var total := smoke_count + smoke_stock
	var plan := smoke_carry_plan if smoke_carry_plan >= 0 else total
	plan = clampi(plan, 0, total)
	var delta := plan - smoke_count
	if delta == 0:
		return
	if delta > 0:
		var moved: int = mini(delta, smoke_stock)
		smoke_stock -= moved
		smoke_count += moved
	else:
		var moved_back: int = mini(-delta, smoke_count)
		smoke_stock += moved_back
		smoke_count -= moved_back
	items_changed.emit()
	save_game()


## 手机采购页的携带计划调整：玩家明确选择本次出发带多少（0 = 不带）。
## 合法范围 [0, smoke_count + smoke_stock]：已携带数也算可用（保持不回退）。
## 超范围夹取；同值返回 false（无变化）。
func set_smoke_carry_plan(count: int) -> bool:
	var plan := clampi(count, 0, smoke_count + smoke_stock)
	if plan == smoke_carry_plan:
		return false
	smoke_carry_plan = plan
	save_game()
	return true


## Returns true when a smoke bomb was actually used.
func use_smoke() -> bool:
	if smoke_count <= 0:
		return false
	smoke_count -= 1
	items_changed.emit()
	save_game()
	return true


## --- persistence ------------------------------------------------------------

## 读取并校验存档（损坏/半写档返回 null）。has_save / load_game 共用。
func _read_save_dict() -> Variant:
	if not FileAccess.file_exists(save_path):
		return null
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return null
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return null
	return data


func save_game() -> void:
	if not _persistent:
		return
	var text := JSON.stringify({
		"money": money,
		"backpack_level": backpack_level,
		"has_sneakers": has_sneakers,
		"smoke_count": smoke_count,
		"bag_items": bag_items,
		"lore_stage": lore_stage,
		"lore_found": lore_found,
		"story_flags": story_flags,
		"loot_stash": loot_stash,
		"archive_seen": archive_seen,
		"bm_selected_target": bm_selected_target,
		"pending_mission_level": pending_mission_level,
		"loot_reserved": loot_reserved,
		"smoke_stock": smoke_stock,
		"smoke_carry_plan": smoke_carry_plan,
		"level_visited_rooms": level_visited_rooms,
		"level_taken_items": level_taken_items,
	})
	# 原子写：先写 .tmp 再改名覆盖。写到一半崩溃时主档保持上一次的完整状态，
	# 不会出现"半截 JSON → 读档失败 → 玩家进度归零"。
	var tmp_path := save_path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()
	var err := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(tmp_path),
		ProjectSettings.globalize_path(save_path)
	)
	if err != OK:
		# 极少数平台不允许覆盖式改名：退回直接写主档（至少保证存得上）
		var direct := FileAccess.open(save_path, FileAccess.WRITE)
		if direct != null:
			direct.store_string(text)
			direct.close()
		if FileAccess.file_exists(tmp_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))


## 从 JSON/Variant 安全取 int：脏数据类型不匹配时返回默认值，绝不抛错。
func _as_int(value: Variant, default := 0) -> int:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			return int(value)
		TYPE_BOOL:
			return 1 if bool(value) else 0
		TYPE_STRING:
			return int(value)
		_:
			return default


## 从 JSON/Variant 安全取 bool：只接受 bool/数值，字符串等一律用默认值。
func _as_bool(value: Variant, default := false) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return bool(value)
		TYPE_INT:
			return int(value) != 0
		TYPE_FLOAT:
			return absf(float(value)) > 0.0
		_:
			return default


func load_game() -> void:
	var data: Variant = _read_save_dict()
	if typeof(data) != TYPE_DICTIONARY:
		return
	# 防御性加载：脏档/手改档不得把负数或越界值带进运行状态（有存档兼容测试守卫）
	money = maxi(0, int(data.get("money", 0)))
	backpack_level = clampi(int(data.get("backpack_level", 0)), 0, BAG_SIZES.size() - 1)
	has_sneakers = _as_bool(data.get("has_sneakers", false))
	smoke_count = maxi(0, int(data.get("smoke_count", 0)))
	_restore_bag(data.get("bag_items", []))
	_restore_lore(data.get("lore_stage", {}), data.get("lore_found", {}))
	_restore_story_flags(data.get("story_flags", {}))
	_restore_stash(data.get("loot_stash", []))
	_restore_archive(data.get("archive_seen", {}))
	_restore_level_visited(data.get("level_visited_rooms", {}))
	_restore_level_taken(data.get("level_taken_items", {}))
	_restore_pending_mission(data.get("pending_mission_level", ""))
	_restore_loot_reserved(data.get("loot_reserved", {}))
	# 防御式读取（_as_int 检查 typeof）：字典/数组/布尔等脏类型一律按 0。
	smoke_stock = maxi(0, _as_int(data.get("smoke_stock", 0), 0))
	# 出发计划：老档缺省 -1（全部携带，兼容 v0.26.4）；脏类型按 -1。
	var plan_raw: Variant = data.get("smoke_carry_plan", -1)
	smoke_carry_plan = _as_int(plan_raw, -1) if (typeof(plan_raw) == TYPE_INT or typeof(plan_raw) == TYPE_FLOAT) else -1
	if smoke_carry_plan < -1:
		smoke_carry_plan = -1
	bm_selected_target = _migrate_selected_target(str(data.get("bm_selected_target", "ram_zun")))
	money_changed.emit()
	items_changed.emit()
	backpack_changed.emit()


## 文物志进度恢复（JSON 数值是 float，统一转 int）。
## 防御式读取：脏档里的非法类型（字典/数组等）跳过，绝不在加载时抛错。
func _restore_pending_mission(saved: Variant) -> void:
	# 只接受合法关卡 id；老档缺省 / 脏数据一律视为未准备。
	var level := str(saved) if typeof(saved) == TYPE_STRING else ""
	pending_mission_level = level if LEVELS.has(level) else ""


## R-05 预约恢复：只接受 {普通战利品 item id → 非负整数计数}；脏值/主目标/非法 id 丢弃。
func _restore_loot_reserved(saved: Variant) -> void:
	loot_reserved.clear()
	if typeof(saved) != TYPE_DICTIONARY:
		return
	for key in saved:
		var id := str(key)
		var count := _as_int(saved[key], 0)
		# 只有普通战利品可预约：主目标（含教学 mask）与非法 id 一律拒绝。
		if not CATALOG.has(id) or item_is_target(id) or count <= 0:
			continue
		loot_reserved[id] = count


## 手机「委托」确认行动：记录待出发关卡（出发门禁依据），返回是否成功。
func prepare_mission(level_id: String) -> bool:
	if not LEVELS.has(level_id):
		return false
	pending_mission_level = level_id
	pending_mission_changed.emit(level_id)
	save_game()
	return true


## 出发时消费 / 玩家取消准备。
func clear_pending_mission() -> void:
	if pending_mission_level == "":
		return
	pending_mission_level = ""
	pending_mission_changed.emit("")
	save_game()


func _restore_lore(saved_stage: Variant, saved_found: Variant) -> void:
	lore_stage.clear()
	if typeof(saved_stage) == TYPE_DICTIONARY:
		for key in saved_stage:
			lore_stage[str(key)] = maxi(0, _as_int(saved_stage[key]))
	lore_found.clear()
	if typeof(saved_found) == TYPE_DICTIONARY:
		for key in saved_found:
			var arr: Array[int] = []
			var values: Variant = saved_found[key]
			if typeof(values) == TYPE_ARRAY:
				for value in values:
					arr.append(_as_int(value))
			lore_found[str(key)] = arr


## 剧情旗标恢复：老档缺字段 → 空；整段类型脏（字符串/数字等）→ 重置为空；
## 键值只保留 bool（旗标）与 String（ending_id），其余丢弃，绝不在加载时抛错。
func _restore_story_flags(saved: Variant) -> void:
	story_flags.clear()
	if typeof(saved) != TYPE_DICTIONARY:
		return
	for key in saved:
		var value: Variant = saved[key]
		if typeof(value) == TYPE_BOOL or typeof(value) == TYPE_STRING:
			story_flags[str(key)] = value


## 仓库恢复：只保留 CATALOG 里存在的 id。
func _restore_stash(saved: Variant) -> void:
	loot_stash.clear()
	if typeof(saved) != TYPE_ARRAY:
		return
	for value in saved:
		if typeof(value) != TYPE_STRING:
			continue
		var id: String = value
		if CATALOG.has(id):
			loot_stash.append(id)


## 收集册恢复：只保留 CATALOG 里存在的 id（脏档里的数组/数字忽略）。
func _restore_archive(saved: Variant) -> void:
	archive_seen.clear()
	if typeof(saved) != TYPE_DICTIONARY:
		return
	for key in saved:
		var id := str(key)
		if CATALOG.has(id) and _as_bool(saved[key], false):
			archive_seen[id] = true


func _restore_level_visited(saved: Variant) -> void:
	level_visited_rooms.clear()
	if typeof(saved) != TYPE_DICTIONARY:
		return
	for level_id in saved:
		var src: Variant = saved[level_id]
		if typeof(src) != TYPE_DICTIONARY:
			continue
		var room_map := {}
		for room_idx in src:
			if _as_bool(src[room_idx], false):
				room_map[int(room_idx)] = true
		level_visited_rooms[str(level_id)] = room_map


func _restore_level_taken(saved: Variant) -> void:
	level_taken_items.clear()
	if typeof(saved) != TYPE_DICTIONARY:
		return
	for level_id in saved:
		var src: Variant = saved[level_id]
		if typeof(src) != TYPE_ARRAY:
			continue
		var list: Array[String] = []
		for v in src:
			if typeof(v) == TYPE_STRING:
				list.append(str(v))
		level_taken_items[str(level_id)] = list


## --- 跨次探索：房间已探与普通战利品实例 ----------------------------------

func is_room_visited(level_id: String, room_idx: int) -> bool:
	var map: Dictionary = level_visited_rooms.get(level_id, {})
	return bool(map.get(room_idx, false))


func mark_room_visited(level_id: String, room_idx: int) -> void:
	if not level_visited_rooms.has(level_id):
		level_visited_rooms[level_id] = {}
	var map: Dictionary = level_visited_rooms[level_id]
	if not bool(map.get(room_idx, false)):
		map[room_idx] = true
		save_game()


func taken_instance_ids(level_id: String) -> Array[String]:
	var list: Array = level_taken_items.get(level_id, [])
	if typeof(list) != TYPE_ARRAY:
		return []
	var out: Array[String] = []
	for v in list:
		if typeof(v) == TYPE_STRING:
			out.append(str(v))
	return out


func is_item_taken(level_id: String, instance_id: String) -> bool:
	return instance_id in taken_instance_ids(level_id)


func mark_item_taken(level_id: String, instance_id: String) -> void:
	if instance_id.is_empty():
		return
	if not level_taken_items.has(level_id):
		level_taken_items[level_id] = []
	var list: Array = level_taken_items[level_id]
	if not list.has(instance_id):
		list.append(instance_id)
		save_game()


## --- 文物志（器灵对谈 / 端详）---------------------------------------------

func lore_stage_of(item_id: String) -> int:
	return int(lore_stage.get(item_id, 0))


func advance_lore_stage(item_id: String) -> void:
	lore_stage[item_id] = mini(lore_stage_of(item_id) + 1, Lore.stage_count(item_id))
	save_game()


func hotspot_found(item_id: String, index: int) -> bool:
	var arr: Array = lore_found.get(item_id, [])
	return arr.has(index)


func mark_hotspot(item_id: String, index: int) -> void:
	var arr: Array = lore_found.get(item_id, [])
	if arr.has(index):
		return
	arr.append(index)
	lore_found[item_id] = arr
	save_game()


## --- 剧情旗标 ---------------------------------------------------------------

## 剧情旗标读取：未设置/未知键一律 false；值恒为 bool。
## ending_id 是字符串（如 "sell"/"return"/"third"），用 story_flags.get("ending_id", "") 直读。
func story_flag(key: String) -> bool:
	var value: Variant = story_flags.get(key, false)
	return typeof(value) == TYPE_BOOL and bool(value)


## 剧情旗标写入：默认 true；与文物志进度一样立即落盘。
func set_story_flag(key: String, value: bool = true) -> void:
	story_flags[key] = value
	save_game()


## --- 推理链与线索（P3 / P6）------------------------------------------------

func has_clue(clue_id: String) -> bool:
	return story_flag("clue_" + clue_id)


## 记录线索已收集；不存在的 clue_id 返回 false。
func collect_clue(clue_id: String) -> bool:
	var exists := false
	for cid in EvidenceData.chain_ids():
		var chain: Dictionary = EvidenceData.chain(cid)
		if (chain.get("clues", {}) as Dictionary).has(clue_id):
			exists = true
			break
	if not exists:
		return false
	if has_clue(clue_id):
		return true
	set_story_flag("clue_" + clue_id)
	return true


func clues_for_chain(chain_id: String) -> Array[Dictionary]:
	var chain: Dictionary = EvidenceData.chain(chain_id)
	var out: Array[Dictionary] = []
	var clues: Dictionary = chain.get("clues", {})
	for clue_id in clues:
		var copy: Dictionary = clues[clue_id].duplicate()
		copy["collected"] = has_clue(clue_id)
		out.append(copy)
	return out


## 在两条线索卡之间画线；只记录合法端点。
func make_link(from_id: String, to_id: String) -> bool:
	if not has_clue(from_id) or not has_clue(to_id):
		return false
	for cid in EvidenceData.chain_ids():
		for link in EvidenceData.chain(cid).get("required_links", []):
			if (link[0] == from_id and link[1] == to_id) or (link[1] == from_id and link[0] == to_id):
				set_story_flag("link_" + String(link[0]) + "_" + String(link[1]))
				return true
	return false

func has_link(from_id: String, to_id: String) -> bool:
	return story_flag("link_" + from_id + "_" + to_id)


## 验证某条链：3 张线索卡均已收集，且 required_links 两两连线完成。
## 验证通过即写入 chain flag（见 EvidenceData.flag_unlocked）。
func verify_chain(chain_id: String) -> bool:
	if not EvidenceData.chain_ids().has(chain_id):
		return false
	if chain_unlocked(chain_id):
		return true
	var chain: Dictionary = EvidenceData.chain(chain_id)
	var clues: Dictionary = chain.get("clues", {})
	for clue_id in clues:
		if not has_clue(clue_id):
			return false
	var links: Array = chain.get("required_links", [])
	for link in links:
		if not (link is Array) or link.size() != 2:
			return false
		if not has_link(String(link[0]), String(link[1])):
			return false
	var flag := String(chain.get("flag_unlocked", "chain_%s_done" % chain_id))
	set_story_flag(flag)
	return true


func chain_unlocked(chain_id: String) -> bool:
	var chain: Dictionary = EvidenceData.chain(chain_id)
	return story_flag(String(chain.get("flag_unlocked", "chain_%s_done" % chain_id)))


## 当前已解锁的 BM 目标 ID 列表（受 unlock_all_chains_required 开关影响）。
func unlocked_targets() -> Array[String]:
	var ids := EvidenceData.chain_ids()
	var done: Array[String] = []
	for cid in ids:
		if chain_unlocked(cid):
			done.append(cid)
	if unlock_all_chains_required:
		if done.size() == ids.size():
			return done
		return [] as Array[String]
	return done


## 切换大英博物馆本次要拿的目标。
func set_bm_target(target_id: String) -> bool:
	if not CATALOG.has(target_id) or not item_is_target(target_id):
		return false
	bm_selected_target = target_id
	set_level("british_museum")
	save_game()
	return true


## --- 检查点（P5）-------------------------------------------------------------

const CHECKPOINT_PREFIX := "user://checkpoint_"

func checkpoint_path(name: String) -> String:
	return CHECKPOINT_PREFIX + name + ".json"


func save_checkpoint(name: String) -> void:
	var file := FileAccess.open(checkpoint_path(name), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"story_flags": story_flags,
		"lore_stage": lore_stage,
		"lore_found": lore_found,
		"archive_seen": archive_seen,
		"money": money,
		"backpack_level": backpack_level,
		"has_sneakers": has_sneakers,
		"smoke_count": smoke_count,
		"loot_stash": loot_stash,
		"bm_selected_target": bm_selected_target,
	}))
	file.close()


func load_checkpoint(name: String) -> bool:
	var path := checkpoint_path(name)
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	_restore_story_flags(data.get("story_flags", {}))
	# 结局选择需要能重选，因此回溯时擦除上一次的 ending_id。
	story_flags.erase("ending_id")
	_restore_lore(data.get("lore_stage", {}), data.get("lore_found", {}))
	_restore_archive(data.get("archive_seen", {}))
	_restore_stash(data.get("loot_stash", []))
	money = maxi(0, _as_int(data.get("money", 0)))
	backpack_level = clampi(_as_int(data.get("backpack_level", 0)), 0, BAG_SIZES.size() - 1)
	has_sneakers = _as_bool(data.get("has_sneakers", false))
	smoke_count = maxi(0, _as_int(data.get("smoke_count", 0)))
	bm_selected_target = _migrate_selected_target(str(data.get("bm_selected_target", "ram_zun")))
	reset_run()
	save_game()
	return true


## Re-places saved items, dropping/fixing any that no longer fit.
func _restore_bag(saved: Variant) -> void:
	bag_items.clear()
	mission_complete = false
	if typeof(saved) != TYPE_ARRAY:
		return
	for entry in saved:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id := str(entry.get("id", ""))
		if not CATALOG.has(id):
			continue
		var x := _as_int(entry.get("x", -1), -1)
		var y := _as_int(entry.get("y", -1), -1)
		var rot := posmod(_as_int(entry.get("rot", 0)), 4)
		var instance_id := str(entry.get("instance_id", ""))
		var placed := {}
		if x >= 0 and y >= 0 and bag_can_place(id, rot, x, y):
			placed = {"id": id, "x": x, "y": y, "rot": rot}
		else:
			var fit := bag_auto_fit(id)
			if fit["x"] >= 0:
				placed = {"id": id, "x": fit["x"], "y": fit["y"], "rot": fit["rot"]}
		if not placed.is_empty():
			if not instance_id.is_empty():
				placed["instance_id"] = instance_id
			# R-05 预约货标记：老档缺省视为未预约（只增字段）。
			if bool(entry.get("reserved", false)):
				placed["reserved"] = true
			bag_items.append(placed)
		if item_is_target(id):
			mission_complete = true


## Test helper: wipe progression without touching the save file.
func reset_progress() -> void:
	money = 0
	backpack_level = 0
	has_sneakers = false
	smoke_count = 0
	lore_stage.clear()
	lore_found.clear()
	loot_stash.clear()
	archive_seen.clear()
	pending_mission_level = ""
	loot_reserved.clear()
	smoke_stock = 0
	smoke_carry_plan = -1
	story_flags.clear()
	bm_selected_target = "ram_zun"
	level_visited_rooms.clear()
	level_taken_items.clear()
	reset_run()


## 目标更换只迁移行动选择；旧背包/收藏/线索保持原来的文物语义。
func _migrate_selected_target(id: String) -> String:
	return {"egypt_stela": "egypt_heart_scarab", "greek_relief": "akrotiri_askos"}.get(id, id) if id in ["egypt_stela", "greek_relief", "ram_zun", "egypt_heart_scarab", "akrotiri_askos"] else "ram_zun"
