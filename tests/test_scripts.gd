extends Node
## 全项目 GDScript 可编译性检查：扫描 src/ 与 tests/ 下所有 .gd，逐个 reload()。
## 运行：godot --headless res://tests/test_scripts.tscn
## 非零退出码 = 失败。
##
## 背景：`godot --check-only --script` 对引用 autoload（Game/Audio）的脚本会误报
## "Identifier not found"，只有真实项目上下文（本场景）才能正确编译它们。

## 这两个脚本是 autoload 本体：它们编译失败的话，本测试根本跑不起来
## （隐式已被检查）；运行时 reload 使用中的单例脚本不稳定，直接跳过。
const SKIP := [
	"res://src/autoload/game_state.gd",
	"res://src/autoload/audio.gd",
	"res://tests/test_scripts.gd",
]

var _failures := 0
var _checks := 0


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL - " + msg)


func _ready() -> void:
	var paths: Array[String] = []
	paths.append_array(_collect("res://src"))
	paths.append_array(_collect("res://tests"))
	paths.sort()
	for path in paths:
		if SKIP.has(path):
			continue
		_check(path)
	if _failures > 0:
		print("FAILED %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
	else:
		print("ALL %d SCRIPTS COMPILE" % _checks)
		get_tree().quit(0)


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
		elif name.ends_with(".gd"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return out


func _check(path: String) -> void:
	var script := load(path) as GDScript
	if script == null:
		check(false, "可加载：%s" % path)
		return
	var err := script.reload()
	check(err == OK, "可编译：%s（错误码 %d）" % [path, err])
