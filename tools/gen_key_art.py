#!/usr/bin/env python3
"""生成标题界面占位立绘（assets/art/title_key_art_placeholder.png，640×360）。

真正的立绘由作者提供：把图片放到 `assets/art/title_key_art.png`（或 .jpg）即可，
标题界面会优先使用它；本脚本只负责生成**占位图**，不会覆盖作者文件。

画面：夜空 + 月亮 + 城市剪影 + 被月光照亮的博物馆 + 屋顶上的小偷剪影。
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "art")
SPRITES = os.path.join(ROOT, "assets", "sprites")
W, H = 640, 360


def hexc(s, a=255):
    s = s.lstrip("#")
    return tuple(int(s[i : i + 2], 16) for i in (0, 2, 4)) + (a,)


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    d = ImageDraw.Draw(im)

    # 夜空渐变
    top, bottom = hexc("#0a0d18"), hexc("#1b2033")
    for y in range(H):
        d.line([(0, y), (W, y)], fill=lerp(top, bottom, y / H))

    # 星星
    rng = __import__("random").Random(7)
    for _ in range(90):
        x, y = rng.randrange(W), rng.randrange(0, 200)
        a = rng.randint(40, 150)
        im.putpixel((x, y), (255, 255, 255, a))

    # 月亮 + 光晕
    halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    hd.ellipse((470, 24, 586, 140), fill=(255, 240, 210, 40))
    halo = halo.filter(ImageFilter.GaussianBlur(12))
    im.alpha_composite(halo)
    d.ellipse((494, 48, 562, 116), fill=hexc("#f2e6c8"))
    d.ellipse((504, 58, 552, 106), fill=hexc("#fbf4e0"))

    # 远景城市剪影
    rng2 = __import__("random").Random(11)
    x = -10
    while x < W:
        bw = rng2.randint(26, 54)
        bh = rng2.randint(40, 96)
        d.rectangle((x, 210 - bh, x + bw, 250), fill=hexc("#121626"))
        for wy in range(210 - bh + 6, 244, 10):
            for wx in range(x + 4, x + bw - 4, 8):
                if wx + 1 >= W or wx < 0:
                    continue
                if rng2.random() < 0.35:
                    im.putpixel((wx, wy), hexc("#c9a227", 120))
                    im.putpixel((wx + 1, wy), hexc("#c9a227", 90))
        x += bw + rng2.randint(4, 12)

    # 博物馆主体（台阶 + 柱廊 + 山墙 + 穹顶）
    mx0, mx1, base = 150, 470, 300
    d.rectangle((mx0 - 14, base - 8, mx1 + 14, base + 6), fill=hexc("#171c2c"))  # 台阶
    d.rectangle((mx0, 208, mx1, base - 8), fill=hexc("#1d2334"))                 # 主体
    d.polygon([(mx0 - 10, 208), ((mx0 + mx1) / 2, 176), (mx1 + 10, 208)], fill=hexc("#232a3e"))
    d.rectangle(((mx0 + mx1) / 2 - 26, 150, (mx0 + mx1) / 2 + 26, 178), fill=hexc("#232a3e"))
    d.pieslice(((mx0 + mx1) / 2 - 30, 128, (mx0 + mx1) / 2 + 30, 172), 180, 360, fill=hexc("#2a3148"))
    # 柱廊与暖光窗
    for i in range(7):
        cx = mx0 + 18 + i * 40
        d.rectangle((cx, 214, cx + 10, base - 10), fill=hexc("#2e364e"))
    for i in range(6):
        wx = mx0 + 38 + i * 40
        d.rectangle((wx, 224, wx + 16, base - 26), fill=hexc("#e8b45a", 210))
    # 大门与门前光
    d.rectangle(((mx0 + mx1) / 2 - 18, 250, (mx0 + mx1) / 2 + 18, base - 8), fill=hexc("#f2c368", 235))
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse(((mx0 + mx1) / 2 - 90, 236, (mx0 + mx1) / 2 + 90, 330), fill=(242, 195, 104, 60))
    glow = glow.filter(ImageFilter.GaussianBlur(18))
    im.alpha_composite(glow)

    # 前景屋顶
    d.rectangle((0, 300, W, H), fill=hexc("#0c0f18"))
    d.rectangle((0, 300, W, 304), fill=hexc("#1a2030"))

    # 屋顶上的小偷剪影（用角色贴图第 0 帧放大成剪影）
    sheet = Image.open(os.path.join(SPRITES, "player_sheet.png")).convert("RGBA")
    frame = sheet.crop((0, 0, 16, 24)).resize((48, 72), Image.NEAREST)
    silhouette = Image.new("RGBA", frame.size, hexc("#05070c", 255))
    silhouette.putalpha(frame.getchannel("A"))
    im.alpha_composite(silhouette, (86, 232))

    # 飘浮尘埃
    rng3 = __import__("random").Random(23)
    for _ in range(40):
        x, y = rng3.randrange(120, 520), rng3.randrange(200, 330)
        im.putpixel((x, y), hexc("#f2c368", rng3.randint(40, 120)))

    out = os.path.join(OUT_DIR, "title_key_art_placeholder.png")
    im.convert("RGB").save(out)
    print("wrote", os.path.relpath(out, ROOT), im.size)

    # UI 渐隐遮罩（标题上/下），供标题界面叠在立绘上保证文字可读
    top = Image.new("RGBA", (W, 96), (0, 0, 0, 0))
    td = ImageDraw.Draw(top)
    for y in range(96):
        td.line([(0, y), (W, y)], fill=(2, 2, 4, round(140 * (1.0 - y / 96.0))))
    top_path = os.path.join(OUT_DIR, "shade_top.png")
    top.save(top_path)

    bottom = Image.new("RGBA", (W, 180), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bottom)
    for y in range(180):
        bd.line([(0, y), (W, y)], fill=(2, 2, 4, round(170 * (y / 180.0))))
    bottom_path = os.path.join(OUT_DIR, "shade_bottom.png")
    bottom.save(bottom_path)
    print("wrote", os.path.relpath(top_path, ROOT), top.size)
    print("wrote", os.path.relpath(bottom_path, ROOT), bottom.size)


if __name__ == "__main__":
    main()
