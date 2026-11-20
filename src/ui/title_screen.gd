class_name TitleScreen
extends Control
## 标题界面：用户指定封面 `assets/art/CPy0UzlakIPj0kfwMuVCR.png`（1376×768，雨夜恶魔与博物馆）
## + 居中集中菜单（CONFIRMED_DESIGN §9：不再依封面人物手部/建筑入口散落按钮）。
##
## 菜单固定排列：继续游戏 / 新游戏 / 文物档案 / 制作人员与声明 / 退出游戏。
## 有效存档突出继续；覆盖旧档需确认。保存摘要移到左上角存档信息行，不放技术性信息。

signal continue_requested
signal new_game_requested
signal quit_requested
signal statements_requested
signal collection_requested

const ART_CANDIDATES := [
	"res://assets/art/CPy0UzlakIPj0kfwMuVCR.png",  # 用户指定封面（1376×768，雨夜恶魔与博物馆）
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
@onready var title_label: Label = $Title
@onready var subtitle: Label = $Subtitle
@onready var title_rule: ColorRect = $TitleRule
@onready var seal: PanelContainer = $Seal
@onready var menu_panel: PanelContainer = $MenuPanel
@onready var continue_button: Button = $ContinueButton
@onready var new_game_button: Button = $NewGameButton
@onready var collection_button: Button = $CollectionButton
@onready var statements_button: Button = $StatementsButton
@onready var quit_button: Button = $QuitButton
@onready var fade: ColorRect = $Fade

var _confirm_new_game := false
var _using_placeholder := false
var _t := 0.0
var _primary: Button = null


func _ready() -> void:
	shade_top.texture = load("res://assets/art/shade_top.png")
	shade_bottom.texture = load("res://assets/art/shade_bottom.png")
	art.texture = _load_key_art()
	hint_label.text = "" if not _using_placeholder else "封面缺省 · 放入 assets/art/CPy0UzlakIPj0kfwMuVCR.png 自动替换"
	continue_button.pressed.connect(_on_continue)
	new_game_button.pressed.connect(_on_new_game)
	collection_button.pressed.connect(func() -> void: collection_requested.emit())
	statements_button.pressed.connect(func() -> void: statements_requested.emit())
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	_layout_buttons()
	_setup_animations()
	_play_intro()


func _load_key_art() -> Texture2D:
	_using_placeholder = false
	for path in ART_CANDIDATES:
		if ResourceLoader.exists(path):
			_using_placeholder = path.contains("placeholder")
			return load(path)
	_using_placeholder = true
	return null


const MENU_X := 424.0
const MENU_W := 192.0
const MENU_SLOT_H := 34.0
const MENU_CENTER_Y := 245.0


## 集中菜单：继续突出（有效存档）；新游戏覆盖确认。
func _layout_buttons() -> void:
	if Game.has_save():
		continue_button.visible = true
		continue_button.text = "继续游戏"
		new_game_button.text = "新游戏"
		_set_font_size(new_game_button, 11)
		_primary = continue_button
	else:
		continue_button.visible = false
		new_game_button.text = "开始游戏"
		_set_font_size(new_game_button, 14)
		_primary = new_game_button
	var order: Array[Button] = [continue_button, new_game_button, collection_button, statements_button, quit_button]
	var visible_buttons: Array[Button] = []
	for btn in order:
		if btn.visible:
			visible_buttons.append(btn)
	var total_h := visible_buttons.size() * MENU_SLOT_H
	var start_y := MENU_CENTER_Y - total_h * 0.5
	for i in range(visible_buttons.size()):
		var btn: Button = visible_buttons[i]
		btn.position = Vector2(MENU_X, start_y + i * MENU_SLOT_H)
		btn.size = Vector2(MENU_W, MENU_SLOT_H - 4.0)
	if Game.has_save():
		save_label.text = "有存档 · 继续上次行动"
	else:
		save_label.text = "尚无存档 · 开始新的行动"
	if _primary != null:
		_primary.grab_focus()


func _set_font_size(button: Button, size: int) -> void:
	button.add_theme_font_size_override("font_size", size)


func _setup_animations() -> void:
	for button in _buttons():
		button.pivot_offset = button.size * 0.5
		button.mouse_entered.connect(func() -> void: _hover(button, 1.06, true))
		button.mouse_exited.connect(func() -> void: _hover(button, 1.0, false))
		button.focus_entered.connect(func() -> void: _hover(button, 1.04, false))
		button.focus_exited.connect(func() -> void: _hover(button, 1.0, false))
	seal.pivot_offset = seal.size * 0.5
	art.pivot_offset = size * 0.5
	resized.connect(func() -> void: art.pivot_offset = size * 0.5)


func _buttons() -> Array[Button]:
	return [continue_button, new_game_button, collection_button, statements_button, quit_button]


func _hover(button: Button, target: float, with_sound: bool) -> void:
	if with_sound:
		Audio.play("blip", -20.0)
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2(target, target), 0.12).set_trans(Tween.TRANS_QUAD)


func _play_intro() -> void:
	# 黑场淡入
	fade.visible = true
	fade.color.a = 1.0
	var fade_tween := create_tween()
	fade_tween.tween_property(fade, "color:a", 0.0, 0.45)
	fade_tween.tween_callback(func() -> void: fade.visible = false)

	# 标题从右侧滑入（菜单位于右侧黑色区域）
	var title_home := title_label.position
	title_label.position = title_home + Vector2(16, 0)
	title_label.modulate.a = 0.0
	var title_tween := create_tween().set_parallel(true)
	title_tween.tween_property(title_label, "modulate:a", 1.0, 0.4)
	title_tween.tween_property(title_label, "position", title_home, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	for label in [subtitle, title_rule, save_label]:
		label.modulate.a = 0.0
		var label_tween := create_tween()
		label_tween.tween_property(label, "modulate:a", 1.0, 0.3).set_delay(0.12)

	# 朱砂印“盖章”
	seal.scale = Vector2(1.8, 1.8)
	seal.rotation = -0.25
	var seal_tween := create_tween().set_parallel(true)
	seal_tween.tween_property(seal, "scale", Vector2.ONE, 0.3).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	seal_tween.tween_property(seal, "rotation", 0.0, 0.3).set_delay(0.15)

	# 选项依次浮起
	var delay := 0.2
	for button in _buttons():
		if not button.visible:
			continue
		var home := button.position
		button.position = home + Vector2(0, 8)
		button.modulate.a = 0.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(button, "modulate:a", 1.0, 0.28).set_delay(delay)
		tween.tween_property(button, "position", home, 0.32).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		delay += 0.07


func _process(delta: float) -> void:
	_t += delta
	# 立绘极慢的推近，让静态图“活着”
	art.scale = Vector2.ONE * (1.0 + 0.006 * sin(_t * 0.25))


func _on_continue() -> void:
	continue_requested.emit()


func _on_new_game() -> void:
	if not Game.has_save():
		new_game_requested.emit()
		return
	if not _confirm_new_game:
		_confirm_new_game = true
		new_game_button.text = "再按一次：清档重来"
		_set_font_size(new_game_button, 10)
		new_game_button.add_theme_color_override("font_color", Color("f0a0a0"))
		return
	new_game_requested.emit()


func _draw() -> void:
	# 立绘加载失败时的兜底底色（正常情况下被 Art 覆盖）
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b0d12"), true)
