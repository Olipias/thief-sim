class_name TitleScreen
extends Control
## 标题界面：立绘 + UI（组织主题：金线框 + 朱砂印 + 墨色遮罩）。
##
## 立绘优先使用作者提供的 `assets/art/title_key_art.png`（或 .jpg，任意尺寸、
## 自动按 cover 裁切）；没有时回退到 `title_key_art_placeholder.png`（工具生成的占位图）。

signal continue_requested
signal new_game_requested
signal quit_requested
signal statements_requested

const ART_CANDIDATES := [
	"res://assets/art/title_key_art.png",
	"res://assets/art/title_key_art.jpg",
	"res://assets/art/title_key_art.jpeg",
	"res://assets/art/title_key_art_placeholder.png",
]

@onready var art: TextureRect = $Art
@onready var shade_top: TextureRect = $ShadeTop
@onready var shade_bottom: TextureRect = $ShadeBottom
@onready var hint_label: Label = $Hint
@onready var save_label: Label = $SaveInfo
@onready var continue_button: Button = $ContinueButton
@onready var new_game_button: Button = $NewGameButton
@onready var quit_button: Button = $QuitButton
@onready var statements_button: Button = $StatementsButton

var _confirm_new_game := false
var _using_placeholder := false


func _ready() -> void:
	shade_top.texture = load("res://assets/art/shade_top.png")
	shade_bottom.texture = load("res://assets/art/shade_bottom.png")
	art.texture = _load_key_art()
	hint_label.text = "立绘占位图 · 将作者立绘放到 assets/art/title_key_art.png 即可自动替换" if _using_placeholder else ""
	continue_button.pressed.connect(_on_continue)
	new_game_button.pressed.connect(_on_new_game)
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	statements_button.pressed.connect(func() -> void: statements_requested.emit())
	continue_button.disabled = not Game.has_save()
	if Game.has_save():
		save_label.text = "存档：金币 %d · 背包 %d×%d · 烟雾弹 x%d%s" % [
			Game.money,
			Game.bag_cells().x,
			Game.bag_cells().y,
			Game.smoke_count,
			" · 跑鞋已购" if Game.has_sneakers else "",
		]
		continue_button.grab_focus()
	else:
		save_label.text = "尚无存档——新开一局吧"
		new_game_button.grab_focus()


func _load_key_art() -> Texture2D:
	_using_placeholder = false
	for path in ART_CANDIDATES:
		if ResourceLoader.exists(path):
			_using_placeholder = path.contains("placeholder")
			return load(path)
	_using_placeholder = true
	return null


func _on_continue() -> void:
	continue_requested.emit()


func _on_new_game() -> void:
	if not _confirm_new_game:
		_confirm_new_game = true
		new_game_button.text = "再按一次：清空存档并新开一局"
		return
	new_game_requested.emit()


func _draw() -> void:
	# 立绘加载失败时的兜底底色（正常情况下被 Art 覆盖）
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b0d12"), true)
