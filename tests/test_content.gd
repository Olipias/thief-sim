extends Node
## 内容一致性测试：数据表、资源文件、跨模块引用必须自洽。
## 运行：godot --headless res://tests/test_content.tscn
## 非零退出码 = 失败。新增文物/商店项/音效/关卡字段后，本测试应自动覆盖语义。
##
## 为什么是场景（而不是 --script）：部分被检查的脚本（hub.gd 等）引用
## autoload 单例 `Game`，只有场景运行环境下才能编译加载。

var _failures := 0
var _checks := 0


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL - " + msg)


func _ready() -> void:
	_test_catalog()
	_test_shapes()
	_test_sprites()
	_test_upgrades()
	_test_audio_files()
	_test_level_data()
	if _failures > 0:
		print("FAILED %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
	else:
		print("ALL %d CHECKS PASSED" % _checks)
		get_tree().quit(0)


func _consts(script_path: String) -> Dictionary:
	var script := load(script_path) as GDScript
	if script == null:
		check(false, "脚本可加载：%s" % script_path)
		return {}
	return script.get_script_constant_map()


func _test_catalog() -> void:
	var catalog: Dictionary = _consts("res://src/autoload/game_state.gd").get("CATALOG", {})
	check(not catalog.is_empty(), "CATALOG 至少有一件文物")
	var targets := 0
	for id in catalog:
		var info: Dictionary = catalog[id]
		for key in ["name", "value", "is_target", "story"]:
			check(info.has(key), "CATALOG[%s] 含字段 %s" % [id, key])
		check(String(info.get("name", "")) != "", "CATALOG[%s] 有名称" % id)
		check(String(info.get("story", "")) != "", "CATALOG[%s] 有故事文本" % id)
		check(int(info.get("value", -1)) >= 0, "CATALOG[%s] 价值 >= 0" % id)
		if bool(info.get("is_target", false)):
			targets += 1
	check(targets == 1, "CATALOG 中恰有一件任务目标（当前 %d）" % targets)


func _test_shapes() -> void:
	var consts := _consts("res://src/autoload/game_state.gd")
	var catalog: Dictionary = consts.get("CATALOG", {})
	var shapes: Dictionary = consts.get("SHAPES", {})
	for id in catalog:
		check(shapes.has(id), "SHAPES 覆盖 CATALOG 条目 %s" % id)
	for id in shapes:
		check(catalog.has(id), "SHAPES 条目 %s 存在于 CATALOG" % id)
		_check_shape(String(id), shapes[id])


func _check_shape(id: String, cells: Array) -> void:
	check(cells.size() >= 1 and cells.size() <= 6, "SHAPES[%s] 格子数在 1..6（当前 %d）" % [id, cells.size()])
	var seen := {}
	var min_x := 99
	var min_y := 99
	for cell in cells:
		check(typeof(cell) == TYPE_VECTOR2I, "SHAPES[%s] 单元格为 Vector2i" % id)
		if typeof(cell) != TYPE_VECTOR2I:
			continue
		var c: Vector2i = cell
		check(c.x >= 0 and c.y >= 0, "SHAPES[%s] 单元格 %s 非负" % [id, c])
		check(not seen.has(c), "SHAPES[%s] 单元格 %s 不重复" % [id, c])
		seen[c] = true
		min_x = mini(min_x, c.x)
		min_y = mini(min_y, c.y)
	check(min_x == 0 and min_y == 0, "SHAPES[%s] 已归一化（贴住左/上边）" % id)
	# (0,0) 锚点：背包摆放把 (x,y) 当作图形左上角，必须含原点格
	check(seen.has(Vector2i.ZERO), "SHAPES[%s] 含锚点 (0,0)" % id)
	# 4 连通：旋转与显示的前提
	var reach := {}
	if seen.has(Vector2i.ZERO):
		reach[Vector2i.ZERO] = true
		var queue: Array[Vector2i] = [Vector2i.ZERO]
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_back()
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nxt: Vector2i = cur + d
				if seen.has(nxt) and not reach.has(nxt):
					reach[nxt] = true
					queue.append(nxt)
	check(reach.size() == cells.size(), "SHAPES[%s] 为 4 连通图形" % id)


func _test_sprites() -> void:
	var catalog: Dictionary = _consts("res://src/autoload/game_state.gd").get("CATALOG", {})
	for id in catalog:
		var path := "res://assets/sprites/artifact_%s.png" % id
		check(FileAccess.file_exists(path), "文物贴图存在：%s" % path)


func _test_upgrades() -> void:
	var consts := _consts("res://src/autoload/game_state.gd")
	var upgrades: Dictionary = consts.get("UPGRADES", {})
	check(not upgrades.is_empty(), "UPGRADES 非空")
	var kinds := ["level", "permanent", "consumable"]
	for id in upgrades:
		var info: Dictionary = upgrades[id]
		var kind := String(info.get("kind", ""))
		check(kinds.has(kind), "UPGRADES[%s] kind 合法（当前 %s）" % [id, kind])
		check(String(info.get("name", "")) != "", "UPGRADES[%s] 有名称" % id)
		check(int(info.get("price", -1)) >= 0, "UPGRADES[%s] 价格 >= 0" % id)
		if kind == "level":
			check(int(info.get("price_step", -1)) >= 0, "UPGRADES[%s] 含 price_step" % id)
			check(int(info.get("max_level", 0)) >= 1, "UPGRADES[%s] 含 max_level" % id)
	var hub_consts := _consts("res://src/ui/hub.gd")
	var rows: Array = hub_consts.get("ROWS", [])
	check(not rows.is_empty(), "Hub 货架 ROWS 非空")
	for id in rows:
		check(upgrades.has(String(id)), "Hub 货架条目 %s 存在于 UPGRADES" % id)
	for id in upgrades:
		check(rows.has(id), "UPGRADES[%s] 已上架 Hub（ROWS 需同步）" % id)


func _test_audio_files() -> void:
	var sfx: Dictionary = _consts("res://src/autoload/audio.gd").get("SFX", {})
	check(not sfx.is_empty(), "SFX 表非空")
	var dir := DirAccess.open("res://assets/sfx")
	if dir == null:
		check(false, "目录存在：res://assets/sfx")
		return
	var on_disk := {}
	for f in dir.get_files():
		if f.ends_with(".wav"):
			on_disk[f] = true
	for key in sfx:
		var path := String(sfx[key])
		check(path.begins_with("res://assets/sfx/"), "SFX[%s] 位于 assets/sfx（当前 %s）" % [key, path])
		check(FileAccess.file_exists(path), "SFX[%s] 文件存在（%s）" % [key, path])
		on_disk.erase(path.get_file())
	check(on_disk.is_empty(), "assets/sfx 无未登记 wav（孤儿：%s）" % [on_disk.keys()])


func _test_level_data() -> void:
	var res := load("res://src/levels/museum_map.json") as JSON
	check(res != null, "关卡 JSON 可加载")
	if res == null:
		return
	var data: Dictionary = res.data
	for key in ["tile_size", "rooms", "floors", "tiles", "patrols"]:
		check(data.has(key), "关卡 JSON 含字段 %s" % key)
	check(int(data.get("tile_size", 0)) == 16, "tile_size = 16")
	var pool: Array = _consts("res://src/world/museum.gd").get("ARTIFACT_POOL", [])
	var catalog: Dictionary = _consts("res://src/autoload/game_state.gd").get("CATALOG", {})
	check(not pool.is_empty(), "ARTIFACT_POOL 非空")
	for id in pool:
		var sid := String(id)
		check(catalog.has(sid), "战利品池条目 %s 存在于 CATALOG" % sid)
		check(
			not bool((catalog.get(sid, {}) as Dictionary).get("is_target", false)),
			"战利品池不包含任务目标（%s）" % sid
		)
