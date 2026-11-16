class_name ContractIntro
extends Control
signal finished
const PANEL_SECONDS := 18.0
const PANELS := [
	["雨夜 · 屋顶", "今晚的目标不是博物馆，只是一只无人认领的旧匣。", "我靠开锁吃饭。欠条却比锁更难打开。"],
	["旧匣 · 封印", "匣盖里没有珠宝，只有一张空白契约。", "锁芯割破手指。血在纸上留下了名字。"],
	["倒影 · 访客", "窗中的倒影晚了一拍。它笑了，我没有。", "恶魔：总算有人肯开门。"],
	["契约 · 条件", "恶魔：我要旧物。充满怨恨风味的那种。", "我：钱呢？　恶魔：先把你欠的账抹掉。"],
	["手印 · 代价", "字浮出来了：每次只取一件，不得毁坏。", "最后一行看不清。窗外的雨声忽然停了。"],
	["问题 · 沉默", "我：如果不交呢？", "它看着我的手。契约上的指纹开始发烫。"],
	["指令 · 面具", "恶魔：先练练手。城西，一张青铜的脸。", "柜子、守卫、出口。拿到以后不要停留。"],
	["黎明前 · 出发", "钥匙在掌心留下黑印。街上的灯一盏盏熄灭。", "方向键移动，C 蹲下，E 观察拾取。别让它等太久。"],
]
var elapsed := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var skip := Button.new()
	skip.text = "跳过演出，进入教学"
	skip.position = Vector2(440, 328)
	skip.add_theme_font_size_override("font_size", 11)
	add_child(skip)
	skip.pressed.connect(func() -> void: finished.emit(); queue_free())

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= PANEL_SECONDS * PANELS.size():
		set_process(false)
		finished.emit()
		queue_free()
	queue_redraw()

func _draw() -> void:
	var index := mini(int(elapsed / PANEL_SECONDS), PANELS.size() - 1)
	var phase := fmod(elapsed, PANEL_SECONDS) / PANEL_SECONDS
	draw_rect(Rect2(0, 0, 640, 360), Color("080e18"))
	# 代码绘制漫画格、城市剪影、契约与访客；缓慢推进与字幕分拍。
	for i in 12:
		var h := 40 + (i * 37 % 90)
		draw_rect(Rect2(i * 58 - phase * 14, 194 - h, 44, h), Color("22303b"))
	draw_rect(Rect2(28, 26, 584, 182), Color("d8a84e"), false, 2)
	draw_colored_polygon(PackedVector2Array([Vector2(230, 190), Vector2(310, 44), Vector2(390, 190)]), Color("06090d"))
	draw_circle(Vector2(294, 102), 3 + phase * 2, Color("e56a4a"))
	draw_circle(Vector2(326, 102), 3 + phase * 2, Color("e56a4a"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(42, 53), PANELS[index][0], HORIZONTAL_ALIGNMENT_LEFT, 540, 18, Color("f4d48a"))
	for line in 2:
		if phase > line * 0.35:
			draw_string(font, Vector2(32, 246 + line * 38), PANELS[index][line + 1], HORIZONTAL_ALIGNMENT_LEFT, 580, 14, Color("e5dfcf"))
	draw_string(font, Vector2(32, 342), "%d / 8 · 虚构演绎" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, 300, 11)
