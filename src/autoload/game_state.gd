extends Node
## Global run & progression state: money, grid backpack, upgrades, save file.
## Autoloaded as "Game".  Stats persist in user://save.json between sessions.

signal backpack_changed
signal money_changed
signal items_changed

const MISSION_REWARD := 200
const DEFAULT_SAVE_PATH := "user://save.json"

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
		"name": "大英博物馆·中国馆",
		"map": "res://src/levels/british_museum.json",
		"target": "ram_zun",
		"reward": 400,
	},
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
	"mask": [Vector2i(0, 0), Vector2i(1, 0)],
	"vase": [Vector2i(0, 0)],
	"gem": [Vector2i(0, 0)],
	"ingot": [Vector2i(0, 0)],
	"scroll": [Vector2i(0, 0), Vector2i(0, 1)],
	"jade": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],
	"ram_zun": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
}

const CATALOG := {
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
	"mask": {
		"era": "商代晚期（约前 13—前 11 世纪）",
		"origin": "陕西汉中城固、洋县一带（城洋铜器群）",
		"collection": "城固县博物馆等",
		"provenance": "1976 年 10 月城固苏村小冢窖藏出土，同坑面具 23 件，同出铜器 400 余件。",
		"legend": "「三千年前的微笑」是观众印象；古人本意无文献记载。",
		"source": "S-002 · docs/SOURCES.md",
		"fiction": "器灵「面具要笑，神才肯来」等台词与对谈剧情为虚构演绎。",
	},
	"ram_zun": {
		"era": "商代晚期（约前 1200–1050 年）",
		"origin": "湖南（风格/工艺推定，非出土地确证）",
		"collection": "大英博物馆 · 1936,1118.1",
		"provenance": "1936 年购自 Eumorfopoulos 收藏；更早流转无公开确证。",
		"legend": "“1860 圆明园劫掠”为民间叙事，无确证。",
		"source": "S-001 · docs/SOURCES.md",
		"fiction": "器灵、通灵与关卡剧情为虚构演绎。",
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

## 文物志进度：item_id → 下一段序号（0 = 还没聊过）；端详已发现热点：item_id → [索引]
var lore_stage: Dictionary = {}
var lore_found: Dictionary = {}

## Items currently carried: {id: String, x: int, y: int, rot: int}
var bag_items: Array[Dictionary] = []
var mission_complete := false

## 当前关卡与本次任务目标（由 set_level 设定；任务判定实时对照它）。
var current_level_id := "museum"
var mission_target_id := "mask"

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
	_recompute_mission()


## 是否存在存档（标题界面据此决定「继续游戏」是否可用）。
func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## 新游戏：清空进度并覆盖存档文件。
func start_new_game() -> void:
	reset_progress()
	save_game()


func level_info() -> Dictionary:
	return LEVELS.get(current_level_id, LEVELS["museum"])


func level_name() -> String:
	return String(level_info().get("name", current_level_id))


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
func try_pickup(item_id: String) -> bool:
	var fit := bag_auto_fit(item_id)
	if fit["x"] < 0:
		return false
	if not place_item({"id": item_id}, int(fit["x"]), int(fit["y"]), int(fit["rot"])):
		return false
	return true


func loot_value() -> int:
	var total := 0
	for item in bag_items:
		total += item_value(String(item["id"]))
	return total


## Settles the run and returns a summary for the result screen.
func finish_run(success: bool) -> Dictionary:
	var summary := {
		"success": false,
		"sold_items": [],
		"sold_value": 0,
		"reward": 0,
		"target_name": "",
		"money_total": money,
	}
	if not success or not mission_complete:
		return summary

	var sold: Array[Dictionary] = []
	for item in bag_items:
		var id := String(item["id"])
		if id != mission_target_id:
			sold.append({"name": item_name(id), "value": item_value(id)})
		else:
			summary["target_name"] = item_name(id)
	var earned := 0
	for item in sold:
		earned += int(item["value"])
	var reward := mission_reward()
	money += earned + reward
	summary["success"] = true
	summary["sold_items"] = sold
	summary["sold_value"] = earned
	summary["reward"] = reward
	summary["money_total"] = money
	money_changed.emit()
	save_game()
	return summary


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
			smoke_count += 1
	items_changed.emit()
	money_changed.emit()
	backpack_changed.emit()
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

func save_game() -> void:
	if not _persistent:
		return
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"money": money,
		"backpack_level": backpack_level,
		"has_sneakers": has_sneakers,
		"smoke_count": smoke_count,
		"bag_items": bag_items,
		"lore_stage": lore_stage,
		"lore_found": lore_found,
	}))


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
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	# 防御性加载：脏档/手改档不得把负数或越界值带进运行状态（有存档兼容测试守卫）
	money = maxi(0, int(data.get("money", 0)))
	backpack_level = clampi(int(data.get("backpack_level", 0)), 0, BAG_SIZES.size() - 1)
	has_sneakers = _as_bool(data.get("has_sneakers", false))
	smoke_count = maxi(0, int(data.get("smoke_count", 0)))
	_restore_bag(data.get("bag_items", []))
	_restore_lore(data.get("lore_stage", {}), data.get("lore_found", {}))
	money_changed.emit()
	items_changed.emit()
	backpack_changed.emit()


## 文物志进度恢复（JSON 数值是 float，统一转 int）。
## 防御式读取：脏档里的非法类型（字典/数组等）跳过，绝不在加载时抛错。
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
		if x >= 0 and y >= 0 and bag_can_place(id, rot, x, y):
			bag_items.append({"id": id, "x": x, "y": y, "rot": rot})
		else:
			var fit := bag_auto_fit(id)
			if fit["x"] >= 0:
				bag_items.append({"id": id, "x": fit["x"], "y": fit["y"], "rot": fit["rot"]})
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
	reset_run()
