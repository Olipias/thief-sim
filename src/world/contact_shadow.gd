class_name ContactShadow
extends RefCounted
## 角色脚下的椭圆接触阴影：纯画面，程序绘制，全局共用一张贴图。

static var _tex: ImageTexture


static func texture() -> ImageTexture:
	if _tex == null:
		var w := 20
		var h := 8
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var dx := (x + 0.5 - w * 0.5) / (w * 0.5)
				var dy := (y + 0.5 - h * 0.5) / (h * 0.5)
				var d := dx * dx + dy * dy
				if d <= 1.0:
					img.set_pixel(x, y, Color(0, 0, 0, 0.5 * (1.0 - d * 0.6)))
		_tex = ImageTexture.create_from_image(img)
	return _tex


## 给 actor 挂一个跟随脚底的阴影（画在 actor 本体之下）。
static func attach(actor: Node2D) -> Sprite2D:
	var shadow := Sprite2D.new()
	shadow.name = "ContactShadow"
	shadow.texture = texture()
	shadow.position = Vector2(0, 5)
	shadow.show_behind_parent = true
	actor.add_child(shadow)
	return shadow
