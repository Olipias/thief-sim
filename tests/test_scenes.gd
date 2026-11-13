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


## A-00 角色资产规格（Rev.3：主角 32×40 / 128×120；警察 24×32 / 96×96；锚点与碰撞固定）。
func _test_a00_actor_assets() -> void:
	var specs := {
		"player": {"sheet": Vector2i(128, 120), "anchor": -13.0},
		"police": {"sheet": Vector2i(96, 96), "anchor": -10.0},
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
				check(sprite.texture.resource_path.contains("_v2"), "A-00：%s 使用 v2 sheet" % actor)
			check(sprite.hframes == 4 and sprite.vframes == 3, "A-00：%s 为 4 列 × 3 行" % actor)
			check(is_equal_approx(sprite.position.y, float(spec["anchor"])), "A-00：%s 锚点 y=%s" % [actor, spec["anchor"]])
		var shape_node: CollisionShape2D = inst.get_node_or_null("CollisionShape2D")
		check(shape_node != null and shape_node.shape is RectangleShape2D, "A-00：%s 有矩形碰撞" % actor)
		if shape_node != null and shape_node.shape is RectangleShape2D:
			check((shape_node.shape as RectangleShape2D).size == Vector2(8, 8), "A-00：%s 碰撞 8×8 未变" % actor)
		inst.free()


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
