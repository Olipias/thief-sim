class_name TitleScreen
extends Control
## 标题界面：整幅立绘 + 场景化菜单（选项贴在画面里的“手”和博物馆入口上）。
##
## 立绘优先使用作者提供的 `assets/art/title_key_art.png`（任意尺寸、自动 cover 裁切）；
## 没有时回退到 `title_key_art_placeholder.png`。
## 选项是“错开放置”的：开始/继续在屋顶小偷按着的手边，商店在博物馆正门台阶上，
## 声明/退出缩在右下角。带入场、悬停、呼吸光框与指针标记等动效。

signal continue_requested
signal new_game_requested
signal quit_requested
signal statements_requested
signal shop_requested

const ART_CANDIDATES := [
	"res://assets/art/title_key_art.png",
	"res://assets/art/title_key_art.jpg",
	"res://assets/art/title_key_art.jpeg",
	"res://assets/art/title_key_art_placeholder.png",
]

const PRIMARY_RECT := Rect2(190, 298, 120, 26)
const SECONDARY_RECT := Rect2(190, 330, 120, 24)
const GLOW_RECT := Rect2(185, 293, 130, 36)

@onready var art: TextureRect = $Art
@onready var shade_top: TextureRect = $ShadeTop
@onready var shade_bottom: TextureRect = $ShadeBottom
@onready var hint_label: Label = $Hint
@onready var save_label: Label = $SaveInfo
@onready var title_label: Label = $Title
@onready var subtitle: Label = $Subtitle
@onready var title_rule: ColorRect = $TitleRule
@onready var seal: PanelContainer = $Seal
@onready var primary_hint: Label = $PrimaryHint
@onready var shop_hint: Label = $ShopHint
@onready var primary_glow: Panel = $PrimaryGlow
@onready var shop_marker: Panel = $ShopMarker
@onready var continue_button: Button = $ContinueButton
@onready var new_game_button: Button = $NewGameButton
@onready var shop_button: Button = $ShopButton
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
	hint_label.text = "立绘占位图 · 将作者立绘放到 assets/art/title_key_art.png 即可自动替换" if _using_placeholder else ""
	continue_button.pressed.connect(_on_continue)
	new_game_button.pressed.connect(_on_new_game)
	shop_button.pressed.connect(func() -> void: shop_requested.emit())
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


## 场景化布局：主行动放在角色手边；商店贴在博物馆正门台阶上。
func _layout_buttons() -> void:
	continue_button.position = PRIMARY_RECT.position
	continue_button.size = PRIMARY_RECT.size
	new_game_button.size = SECONDARY_RECT.size
	if Game.has_save():
		continue_button.visible = true
		continue_button.text = "继续游戏"
		new_game_button.visible = true
		new_game_button.position = SECONDARY_RECT.position
		new_game_button.text = "新游戏"
		_set_font_size(new_game_button, 11)
		_primary = continue_button
	else:
		continue_button.visible = false
		new_game_button.visible = true
		new_game_button.position = PRIMARY_RECT.position
		new_game_button.text = "开始游戏"
		_set_font_size(new_game_button, 14)
		_primary = new_game_button
	primary_glow.position = GLOW_RECT.position
	primary_glow.size = GLOW_RECT.size
	primary_hint.text = "从这儿开始 ▼"
	if Game.has_save():
		save_label.text = "金币 %d · 背包 %d×%d · 烟雾弹 x%d%s" % [
			Game.money,
			Game.bag_cells().x,
			Game.bag_cells().y,
			Game.smoke_count,
			" · 跑鞋已购" if Game.has_sneakers else "",
		]
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
	shop_marker.pivot_offset = shop_marker.size * 0.5
	seal.pivot_offset = seal.size * 0.5
	art.pivot_offset = size * 0.5
	resized.connect(func() -> void: art.pivot_offset = size * 0.5)


func _buttons() -> Array[Button]:
	return [continue_button, new_game_button, shop_button, statements_button, quit_button]


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

	# 标题从左侧滑入
	var title_home := title_label.position
	title_label.position = title_home + Vector2(-16, 0)
	title_label.modulate.a = 0.0
	var title_tween := create_tween().set_parallel(true)
	title_tween.tween_property(title_label, "modulate:a", 1.0, 0.4)
	title_tween.tween_property(title_label, "position", title_home, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	for label in [subtitle, title_rule, save_label, primary_hint, shop_hint]:
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
	# 主按钮的呼吸光框
	primary_glow.modulate.a = 0.45 + 0.25 * sin(_t * 2.2)
	# 场景标记的呼吸
	var pulse := 0.5 + 0.5 * sin(_t * 2.6)
	shop_marker.modulate.a = 0.45 + 0.45 * pulse
	shop_marker.scale = Vector2.ONE * (0.85 + 0.25 * pulse)
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
