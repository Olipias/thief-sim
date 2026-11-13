extends Node
## 场景实例化自检：把 src/ 下所有 .tscn 逐一实例化并存活两帧再释放。
##
## 目的：抓"结构性底层问题"——@onready 节点路径失效、preload 悬空、
## 场景脚本 _ready 崩溃、场景依赖的自动加载缺失等。这些问题静态检查看不见，
## 只有真实例化才暴露；配合 verify.sh 的"引擎报错门禁"（输出里出现
## ERROR/WARNING/泄漏即失败），任何实例化期间的报错都会让验证变红。
##
## 运行：godot --headless res://tests/test_scenes.tscn
## 注意：只扫 src/，不扫 tests/（测试场景的 _ready 会执行测试逻辑，不能当样板例化）。

var _failures := 0
var _checks := 0


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL - " + msg)


func _ready() -> void:
	# 隔离存档，并给场景一个可运行的全局状态（museum 需要任务目标等）
	Game.save_path = "/tmp/thief_sim_scene_check_save.json"
	Game.reset_progress()

	_test_a00_actor_assets()
	_test_noir_art_assets()

	var paths := _collect("res://src")
	check(paths.size() >= 8, "src 下可实例化的场景数量合理（%d 个）" % paths.size())
	for path in paths:
		await _check_scene(path)

	if _failures > 0:
		print("FAILED %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
	else:
		print("ALL %d SCENES OK" % _checks)
		get_tree().quit(0)


## A-00 角色资产规格（Rev.5：主角 noir / 警察同为 24×32 / 96×96；锚点与碰撞固定）。
func _test_a00_actor_assets() -> void:
	var specs := {
		"player": {"sheet": Vector2i(96, 96), "anchor": -10.0, "texture": "res://assets/sprites/chars/player_noir.png"},
		"police": {"sheet": Vector2i(96, 96), "anchor": -10.0, "texture": "res://assets/sprites/chars/police_noir.png"},
	}
	for actor in specs:
		var spec: Dictionary = specs[actor]
		var scene := load("res://src/actors/%s.tscn" % actor) as PackedScene
		check(scene != null, "A-00：%s.tscn 可加载" % actor)
		if scene == null:
			continue
		var inst := scene.instantiate()
		var sprite: Sprite2D = inst.get_node_or_null("Sprite")
		check(sprite != null, "A-00：%s 有 Sprite" % actor)
		if sprite != null:
			check(sprite.texture != null, "A-00：%s 有贴图" % actor)
			if sprite.texture != null:
				var size: Vector2i = spec["sheet"]
				check(
					sprite.texture.get_width() == size.x and sprite.texture.get_height() == size.y,
					"A-00：%s sheet 为 %d×%d" % [actor, size.x, size.y]
				)
				var expected := String(spec["texture"])
				check(sprite.texture.resource_path == expected, "A-00：%s 使用 %s" % [actor, expected])
			check(sprite.hframes == 4 and sprite.vframes == 3, "A-00：%s 为 4 列 × 3 行" % actor)
			check(is_equal_approx(sprite.position.y, float(spec["anchor"])), "A-00：%s 锚点 y=%s" % [actor, spec["anchor"]])
			# 三个方向（下/上/侧）都必须有可读的待机与行走差异；
			# 高清图直接降采样到 24×32 时，上/侧两行常被压成完全相同的帧。
			for row in 3:
				var idle_diff := _frame_difference(sprite.texture, row, 0, 1)
				var walk_diff := _frame_difference(sprite.texture, row, 2, 3)
				check(idle_diff >= 4, "A-00：%s 第 %d 行待机帧有变化（差异 %d px）" % [actor, row, idle_diff])
				check(walk_diff >= 4, "A-00：%s 第 %d 行行走帧有变化（差异 %d px）" % [actor, row, walk_diff])
		var shape_node: CollisionShape2D = inst.get_node_or_null("CollisionShape2D")
		check(shape_node != null and shape_node.shape is RectangleShape2D, "A-00：%s 有矩形碰撞" % actor)
		if shape_node != null and shape_node.shape is RectangleShape2D:
			check((shape_node.shape as RectangleShape2D).size == Vector2(8, 8), "A-00：%s 碰撞 8×8 未变" % actor)
		inst.free()


## 比较同一行两帧的像素差异数量（用于确认行走/待机动画真的会动）。
func _frame_difference(tex: Texture2D, row: int, col_a: int, col_b: int) -> int:
	if tex == null:
		return -1
	var img := tex.get_image()
	if img == null:
		return -1
	if img.is_compressed():
		img.decompress()
	var fw := img.get_width() / 4
	var fh := img.get_height() / 3
	var diff := 0
	for y in fh:
		for x in fw:
			if img.get_pixel(col_a * fw + x, row * fh + y) != img.get_pixel(col_b * fw + x, row * fh + y):
				diff += 1
	return diff


## noir 美术包：装饰尺寸与旧版一致，场景/脚本引用已切到 noir 资产，手机 Tab 有独立样式。
func _test_noir_art_assets() -> void:
	var decor_names := [
		"security_gate", "ticket_desk", "museum_map", "vase_case", "jade_case", "scroll_case",
		"lacquer_cabinet", "mural_panel", "crate_stack", "pallet", "forklift", "pipe_panel",
		"bench", "security_camera", "alarm_beacon", "skylight_panel",
	]
	for item in decor_names:
		var original := load("res://assets/sprites/bm/decor/%s.png" % item) as Texture2D
		var replacement := load("res://assets/sprites/bm/decor_noir/%s.png" % item) as Texture2D
		check(original != null and replacement != null, "noir 装饰可加载：%s" % item)
		if original != null and replacement != null:
			check(original.get_size() == replacement.get_size(), "noir 装饰尺寸不变：%s" % item)

	var hub_scene := load("res://src/ui/hub.tscn") as PackedScene
	check(hub_scene != null, "noir：据点场景可加载")
	if hub_scene != null:
		var hub := hub_scene.instantiate()
		var bg: TextureRect = hub.get_node_or_null("SafehouseBg")
		check(bg != null and bg.texture != null, "noir：据点有背景")
		if bg != null and bg.texture != null:
			check(bg.texture.resource_path == "res://assets/art/safehouse_noir.png", "noir：据点使用 safehouse_noir")
		hub.free()

	var phone_scene := load("res://src/ui/mission_phone.tscn") as PackedScene
	check(phone_scene != null, "noir：手机场景可加载")
	if phone_scene != null:
		var phone := phone_scene.instantiate()
		var panel: PanelContainer = phone.get_node_or_null("Root/Panel")
		check(panel != null, "noir：手机面板存在")
		if panel != null:
			var style := panel.get_theme_stylebox("panel") as StyleBoxTexture
			check(style != null and style.texture != null, "noir：手机 9-patch 样式存在")
			if style != null and style.texture != null:
				check(style.texture.resource_path == "res://assets/art/phone_noir_9p.png", "noir：手机使用 phone_noir_9p")
		var tab: Button = phone.get_node_or_null("Root/Panel/Margin/VBox/Header/TabTask")
		check(tab != null, "noir：任务 Tab 存在")
		if tab != null:
			check(tab.get_theme_stylebox("pressed") != tab.get_theme_stylebox("normal"), "noir：任务 Tab 选中样式独立")
		phone.free()

	var museum_script := load("res://src/world/museum.gd") as GDScript
	check(museum_script != null, "noir：museum.gd 可加载")
	if museum_script != null:
		var constants: Dictionary = museum_script.get_script_constant_map()
		var tiles: Texture2D = constants.get("BM_TILES")
		var case_tex: Texture2D = constants.get("BM_CASE")
		check(tiles != null and tiles.resource_path == "res://assets/sprites/bm/bm_tiles_noir.png", "noir：BM 地砖使用 noir 图集")
		check(case_tex != null and case_tex.resource_path == "res://assets/sprites/bm/bm_case_noir.png", "noir：BM 展柜使用 noir 图")
		var decor: Dictionary = constants.get("BM_DECOR_TEX", {})
		check(decor.size() == 16, "noir：BM 装饰共 16 个")
		for key in decor:
			var tex: Texture2D = decor[key]
			check(tex != null and tex.resource_path.contains("/decor_noir/"), "noir：BM 装饰走 decor_noir（%s）" % key)


func _collect(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_collect(full))
		elif name.ends_with(".tscn"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


func _check_scene(path: String) -> void:
	var packed := load(path) as PackedScene
	check(packed != null, "场景可加载：%s" % path)
	if packed == null:
		return
	var inst := packed.instantiate()
	check(inst != null, "场景可实例化：%s" % path)
	if inst == null:
		return
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	check(is_instance_valid(inst), "实例存活两帧：%s" % path)
	inst.queue_free()
	await get_tree().process_frame
