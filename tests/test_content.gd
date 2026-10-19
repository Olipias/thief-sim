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
	_test_bm_assets()
	_test_archive()
	_test_upgrades()
	_test_audio_files()
	_test_level_data()
	_test_lore()
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
	var consts := _consts("res://src/autoload/game_state.gd")
	var catalog: Dictionary = consts.get("CATALOG", {})
	var levels: Dictionary = consts.get("LEVELS", {})
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
	check(targets >= 1, "CATALOG 至少一件任务目标（当前 %d）" % targets)

	# 关卡注册表 ↔ 目标文物：双向一致
	check(not levels.is_empty(), "LEVELS 至少一个关卡")
	var target_ids := {}
	for id in catalog:
		if bool((catalog[id] as Dictionary).get("is_target", false)):
			target_ids[id] = true
	for level_id in levels:
		var info: Dictionary = levels[level_id]
		for key in ["name", "map", "target", "reward"]:
			check(info.has(key), "LEVELS[%s] 含字段 %s" % [level_id, key])
		var target := String(info.get("target", ""))
		check(catalog.has(target), "LEVELS[%s] 目标 %s 存在于 CATALOG" % [level_id, target])
		check(target_ids.has(target), "LEVELS[%s] 目标 %s 标记 is_target" % [level_id, target])
		check(String(info.get("map", "")).ends_with(".json"), "LEVELS[%s] 地图为 JSON" % level_id)
		target_ids.erase(target)
	check(target_ids.is_empty(), "每件任务目标都被某个关卡引用（未引用：%s）" % [target_ids.keys()])


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
	var relic_consts := _consts("res://src/world/artifact.gd")
	var frames := int(relic_consts.get("RELIC_FRAMES", 0))
	var frame_size: Vector2i = relic_consts.get("RELIC_FRAME_SIZE", Vector2i.ZERO)
	for id in catalog:
		var path := "res://assets/sprites/artifact_%s.png" % id
		check(FileAccess.file_exists(path), "文物贴图存在：%s" % path)
		# 3D 渲染的转台条（可选）：存在时尺寸必须与 Artifact 常量一致
		var strip := "res://assets/sprites/relic_%s_strip.png" % id
		if FileAccess.file_exists(strip):
			var tex := load(strip) as Texture2D
			check(tex != null, "转台条可加载：%s" % strip)
			if tex != null:
				check(
					tex.get_width() == frames * frame_size.x,
					"转台条宽度 = %d 帧 × %d px（%s）" % [frames, frame_size.x, id],
				)
				check(tex.get_height() == frame_size.y, "转台条高度 = %d px（%s）" % [frame_size.y, id])
		# UI 转台条（手机/标题界面用）：存在时尺寸必须与 RelicView 常量一致
		var ui_consts := _consts("res://src/ui/relic_view.gd")
		var ui_frames := int(ui_consts.get("UI_STRIP_FRAMES", 0))
		var ui_frame_size: Vector2i = ui_consts.get("UI_STRIP_FRAME_SIZE", Vector2i.ZERO)
		var ui_strip := "res://assets/sprites/relic_%s_ui_strip.png" % id
		if FileAccess.file_exists(ui_strip):
			var ui_tex := load(ui_strip) as Texture2D
			check(ui_tex != null, "UI 转台条可加载：%s" % ui_strip)
			if ui_tex != null:
				check(
					ui_tex.get_width() == ui_frames * ui_frame_size.x,
					"UI 转台条宽度 = %d 帧 × %d px（%s）" % [ui_frames, ui_frame_size.x, id],
				)
				check(ui_tex.get_height() == ui_frame_size.y, "UI 转台条高度 = %d px（%s）" % [ui_frame_size.y, id])


## 大英博物馆 Room 3 资产包（tools/gen_bm_art.py 生成）：尺寸必须与图集约定一致。
func _test_bm_assets() -> void:
	var expected := {
		"res://assets/sprites/bm/bm_tiles.png": Vector2i(128, 128),
		"res://assets/sprites/bm/bm_props.png": Vector2i(256, 32),
		"res://assets/sprites/bm/bm_ui.png": Vector2i(256, 32),
		"res://assets/sprites/bm/bm_zun_32.png": Vector2i(32, 32),
		"res://assets/sprites/bm/bm_case.png": Vector2i(32, 48),
	}
	for path in expected:
		check(FileAccess.file_exists(path), "Room 3 资产存在：%s" % path)
		if not FileAccess.file_exists(path):
			continue
		var tex := load(path) as Texture2D
		check(tex != null, "Room 3 资产可加载：%s" % path)
		if tex != null:
			var size: Vector2i = expected[path]
			check(
				tex.get_width() == size.x and tex.get_height() == size.y,
				"Room 3 资产尺寸 %dx%d：%s" % [size.x, size.y, path],
			)
	# 装饰层（纯视觉）：存在且尺寸符合约定
	var decor := {
		"security_gate": Vector2i(16, 32), "ticket_desk": Vector2i(32, 20), "museum_map": Vector2i(16, 16),
		"vase_case": Vector2i(32, 32), "jade_case": Vector2i(32, 32), "scroll_case": Vector2i(32, 32),
		"lacquer_cabinet": Vector2i(32, 32), "mural_panel": Vector2i(48, 32), "crate_stack": Vector2i(32, 32),
		"pallet": Vector2i(32, 16), "forklift": Vector2i(48, 32), "pipe_panel": Vector2i(32, 16),
		"bench": Vector2i(24, 12), "security_camera": Vector2i(16, 16), "alarm_beacon": Vector2i(16, 16),
		"skylight_panel": Vector2i(32, 16),
	}
	for key in decor:
		var path := "res://assets/sprites/bm/decor/%s.png" % key
		check(FileAccess.file_exists(path), "装饰资产存在：%s" % path)
		if not FileAccess.file_exists(path):
			continue
		var tex := load(path) as Texture2D
		check(tex != null, "装饰资产可加载：%s" % path)
		if tex != null:
			var size: Vector2i = decor[key]
			check(
				tex.get_width() == size.x and tex.get_height() == size.y,
				"装饰尺寸 %dx%d：%s" % [size.x, size.y, path],
			)


## 真实文物档案：与 docs/SOURCES.md 对应的字段必须齐全。
func _test_archive() -> void:
	var archive: Dictionary = Game.ARCHIVE
	check(archive.has("ram_zun"), "ARCHIVE 含双羊尊条目")
	var entry: Dictionary = archive.get("ram_zun", {})
	for key in ["era", "origin", "collection", "provenance", "source", "fiction"]:
		check(entry.has(key) and String(entry.get(key, "")) != "", "ARCHIVE[ram_zun] 含字段 %s" % key)
	check("SOURCES" in String(entry.get("source", "")), "ARCHIVE 来源指向 docs/SOURCES.md")


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
	var consts := _consts("res://src/autoload/game_state.gd")
	var levels: Dictionary = consts.get("LEVELS", {})
	var pool: Array = _consts("res://src/world/museum.gd").get("ARTIFACT_POOL", [])
	var catalog: Dictionary = consts.get("CATALOG", {})
	check(not pool.is_empty(), "ARTIFACT_POOL 非空")
	for id in pool:
		var sid := String(id)
		check(catalog.has(sid), "战利品池条目 %s 存在于 CATALOG" % sid)
		check(
			not bool((catalog.get(sid, {}) as Dictionary).get("is_target", false)),
			"战利品池不包含任务目标（%s）" % sid
		)

	for level_id in levels:
		var info: Dictionary = levels[level_id]
		var res := load(String(info["map"])) as JSON
		check(res != null, "[%s] 关卡 JSON 可加载" % level_id)
		if res == null:
			continue
		var data: Dictionary = res.data
		for key in ["tile_size", "rooms", "floors", "tiles", "patrols"]:
			check(data.has(key), "[%s] 关卡 JSON 含字段 %s" % [level_id, key])
		check(int(data.get("tile_size", 0)) == 16, "[%s] tile_size = 16" % level_id)

		# 每张地图恰有一个出生点 / 一个目标 / 一个出口，且目标可生成
		var tiles: Array = data.get("tiles", [])
		var counts := {"P": 0, "T": 0, "X": 0}
		for row in tiles:
			for ch in String(row):
				if counts.has(ch):
					counts[ch] += 1
		check(counts["P"] == 1, "[%s] 恰有一个玩家出生点（%d）" % [level_id, counts["P"]])
		check(counts["T"] == 1, "[%s] 恰有一个任务目标标记（%d）" % [level_id, counts["T"]])
		check(counts["X"] == 1, "[%s] 恰有一个出口（%d）" % [level_id, counts["X"]])


## 文物志数据（src/data/lore.gd）：剧本结构、卡片、热点与引用必须自洽。
func _test_lore() -> void:
	var consts := _consts("res://src/data/lore.gd")
	var entries: Dictionary = consts.get("ENTRIES", {})
	var catalog: Dictionary = _consts("res://src/autoload/game_state.gd").get("CATALOG", {})
	check(not entries.is_empty(), "文物志至少有一条")
	for item_id in entries:
		var entry: Dictionary = entries[item_id]
		check(catalog.has(item_id), "文物志条目 %s 存在于 CATALOG" % item_id)
		check(String(entry.get("title", "")) != "", "文物志[%s] 有标题" % item_id)

		var closeup := String(entry.get("closeup", ""))
		check(closeup != "" and FileAccess.file_exists(closeup), "文物志[%s] 特写图存在（%s）" % [item_id, closeup])

		var cards: Dictionary = entry.get("cards", {})
		check(not cards.is_empty(), "文物志[%s] 有展签卡" % item_id)
		for card_id in cards:
			var card: Dictionary = cards[card_id]
			check(String(card.get("title", "")) != "", "卡片 %s 有标题" % card_id)
			check(String(card.get("body", "")).length() >= 30, "卡片 %s 正文有实质内容" % card_id)
			check(String(card.get("source", "")).contains("SOURCES"), "卡片 %s 标注来源（SOURCES）" % card_id)

		var hotspots: Array = entry.get("hotspots", [])
		check(hotspots.size() >= 2, "文物志[%s] 至少有 2 个端详热点" % item_id)
		for hotspot in hotspots:
			var pos: Vector2 = hotspot.get("pos", Vector2(-1, -1))
			check(pos.x >= 0.0 and pos.x <= 1.0 and pos.y >= 0.0 and pos.y <= 1.0, "热点坐标在 0..1（%s）" % pos)
			for key in ["label", "fact", "ghost"]:
				check(String(hotspot.get(key, "")) != "", "热点含 %s" % key)

		var stages: Array = entry.get("stages", [])
		check(stages.size() >= 2, "文物志[%s] 至少 2 段" % item_id)
		for stage_index in stages.size():
			var stage: Array = stages[stage_index]
			var labels := {}
			for entry_item in stage:
				if entry_item.has("label"):
					labels[String(entry_item["label"])] = true
			for entry_item in stage:
				var keys: Array = entry_item.keys()
				var known := false
				for key in ["speaker", "text", "card", "choices", "label", "goto"]:
					if keys.has(key):
						known = true
				check(known, "第 %d 段条目字段合法（%s）" % [stage_index, keys])
				if entry_item.has("card"):
					check(cards.has(String(entry_item["card"])), "第 %d 段引用的卡片存在（%s）" % [stage_index, entry_item["card"]])
				if entry_item.has("goto"):
					check(labels.has(String(entry_item["goto"])), "第 %d 段跳转目标存在（%s）" % [stage_index, entry_item["goto"]])
				for choice in entry_item.get("choices", []):
					check(String(choice.get("text", "")) != "", "选项有文本")
					check(labels.has(String(choice.get("goto", ""))), "选项跳转目标存在（%s）" % choice.get("goto", ""))
