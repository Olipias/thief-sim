#!/usr/bin/env python3
"""Generate placeholder pixel-art sprites for Thief Sim (v2 art pass).

Bigger characters (16x24), denser props, night-museum palette and 2D light
textures.  Everything is regenerated from this script, so it can be replaced
by real art later.  Run:  python3 tools/gen_placeholder_sprites.py
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "sprites")

CHAR_W, CHAR_H = 16, 24


def hexc(s, a=255):
    s = s.lstrip("#")
    return tuple(int(s[i : i + 2], 16) for i in (0, 2, 4)) + (a,)


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def rect(im, x0, y0, x1, y1, c):
    ImageDraw.Draw(im).rectangle([x0, y0, x1, y1], fill=c)


def px(im, x, y, c):
    im.putpixel((x, y), c)


def save(im, name):
    im.save(os.path.join(OUT, name))
    print("  wrote", name)


# ---------------------------------------------------------------------------
# Characters: 16x24 frames, sheet = 2 columns (walk) x 3 rows (down/up/side)
# ---------------------------------------------------------------------------

THIEF = {
    "main": hexc("#2f2f44"),      # hood / coat
    "shade": hexc("#1e1e2c"),
    "light": hexc("#454566"),
    "skin": hexc("#e8b088"),
    "eye": hexc("#14141c"),
    "belt": hexc("#6b5230"),
    "buckle": hexc("#c9a227"),
    "sack": hexc("#8a6a42"),
    "sack_dark": hexc("#63492c"),
    "shoe": hexc("#191922"),
}

POLICE = {
    "main": hexc("#2f5fa8"),      # uniform
    "shade": hexc("#22456f"),
    "light": hexc("#4a7ac4"),
    "skin": hexc("#e8b088"),
    "eye": hexc("#14141c"),
    "belt": hexc("#20242c"),
    "buckle": hexc("#c8ccd4"),
    "sack": hexc("#c9a227"),      # badge / buttons
    "sack_dark": hexc("#8f7318"),
    "shoe": hexc("#14161c"),
    "cap": hexc("#1c3a68"),
}


def char_frame(pal, direction, step, character):
    im = img(CHAR_W, CHAR_H)
    main = pal["main"]
    shade = pal["shade"]
    light = pal["light"]
    skin = pal["skin"]
    eye = pal["eye"]
    is_cop = character == "police"
    head_top = pal["cap"] if is_cop else main

    # --- head (rows 0..8) -------------------------------------------------
    rect(im, 5, 0, 10, 0, head_top)          # rounded crown
    rect(im, 4, 1, 11, 3, head_top)          # upper head
    if is_cop:
        rect(im, 4, 1, 11, 3, pal["cap"])
        rect(im, 4, 3, 11, 3, shade)         # cap band
        if direction != "up":
            rect(im, 5, 3, 10, 3, pal["cap"])
            rect(im, 4, 4, 11, 4, shade)     # visor shadow
    if direction == "up":
        rect(im, 4, 4, 11, 8, main)          # back of head
        rect(im, 4, 4, 11, 5, light)
    else:
        rect(im, 4, 4, 11, 8, main)          # hood/face frame
        face_top = 5 if not is_cop else 5
        rect(im, 5, face_top, 10, 8, skin)   # face
        if direction == "side":
            rect(im, 4, 4, 4, 8, main)
            rect(im, 10, 5, 11, 8, main)
            px(im, 8, 6, eye)                # profile eye
            px(im, 9, 6, eye)
            rect(im, 4, 8, 11, 8, shade)     # jaw shade
        else:
            rect(im, 5, 5, 10, 8, skin)
            px(im, 6, 6, eye)
            px(im, 9, 6, eye)
            px(im, 7, 8, shade)              # mouth shade
            px(im, 8, 8, shade)
    rect(im, 4, 8, 11, 8, shade)             # chin shadow

    # --- torso (rows 9..17) ----------------------------------------------
    rect(im, 4, 9, 11, 17, main)
    rect(im, 4, 9, 4, 17, shade)
    rect(im, 11, 9, 11, 17, shade)
    rect(im, 5, 9, 10, 9, light)             # collar
    # arms
    rect(im, 2, 10, 3, 15, main)
    rect(im, 2, 10, 2, 15, shade)
    rect(im, 12, 10, 13, 15, main)
    rect(im, 13, 10, 13, 15, shade)
    if step == 1:
        rect(im, 2, 15, 3, 16, shade)
        rect(im, 12, 15, 13, 16, shade)
    # belt
    rect(im, 4, 14, 11, 15, pal["belt"])
    px(im, 7, 14, pal["buckle"])
    px(im, 8, 15, pal["buckle"])
    if is_cop:
        rect(im, 6, 11, 6, 12, pal["sack"])  # badge
        rect(im, 9, 11, 9, 12, pal["sack"])
    # coat split
    rect(im, 7, 16, 8, 17, shade)

    # thief's sack
    if character == "thief":
        if direction == "up":
            rect(im, 5, 10, 10, 14, pal["sack"])
            rect(im, 5, 14, 10, 14, pal["sack_dark"])
            rect(im, 7, 9, 8, 10, pal["sack_dark"])
        elif direction == "side":
            rect(im, 1, 11, 3, 15, pal["sack"])
            rect(im, 1, 15, 3, 15, pal["sack_dark"])
            rect(im, 2, 10, 2, 11, pal["sack_dark"])

    # --- legs (rows 18..23) ----------------------------------------------
    if step == 0:
        rect(im, 5, 18, 6, 21, shade)
        rect(im, 9, 18, 10, 21, shade)
        rect(im, 4, 22, 6, 23, pal["shoe"])
        rect(im, 9, 22, 11, 23, pal["shoe"])
    else:
        rect(im, 5, 18, 6, 19, shade)
        rect(im, 9, 18, 10, 19, shade)
        rect(im, 6, 20, 7, 22, shade)
        rect(im, 8, 20, 9, 22, shade)
        rect(im, 5, 22, 7, 23, pal["shoe"])
        rect(im, 8, 22, 10, 23, pal["shoe"])
    return im


def build_sheet(pal, character):
    sheet = img(CHAR_W * 2, CHAR_H * 3)
    for row, direction in enumerate(("down", "up", "side")):
        for col, step in enumerate((0, 1)):
            sheet.paste(char_frame(pal, direction, step, character), (col * CHAR_W, row * CHAR_H))
    return sheet


# ---------------------------------------------------------------------------
# Artifacts: 16x16 icons from ASCII art
# ---------------------------------------------------------------------------

ART = {
    "vase": (
        {"o": "#3a2418", "a": "#c46a3a", "b": "#8f4526", "c": "#e59b6b", "d": "#f2d0a0"},
        [
            "................",
            "................",
            ".....oooooo.....",
            "....oaaaaaao....",
            "....oabbbbao....",
            ".....oaaaao.....",
            "......oaao......",
            ".....oaacoo.....",
            "....oaccccao....",
            "...oaccccaaao...",
            "...obaaaaaabo...",
            "..obaaaaaaaabo..",
            "..obbaaaaaabbo..",
            "...obaaaaaabo...",
            "....oooooooo....",
            "................",
        ],
    ),
    "mask": (
        {"o": "#2c3a2a", "a": "#7fa06a", "b": "#5c7a4c", "c": "#a8c48f", "d": "#16200f", "y": "#d8b23a"},
        [
            "................",
            "....oooooooo....",
            "..ooccccccccoo..",
            ".ocaaaaaaaaaaco.",
            ".oaaaaaaaaaaaao.",
            "oaaaaaaaaaaaaaao",
            "oadaaaaaaaaaadao",
            "oaaaaaaaaaaaaaao",
            "oaaaaaaaaaaaaaao",
            "oaabaaaaaaaabao.",
            ".oaabaaaaaabaao.",
            ".ooaabbbbbaoo...",
            "...ooaaaaoo.....",
            "....oooooo......",
            "................",
            "................",
        ],
    ),
    "ingot": (
        {"o": "#4a3608", "a": "#e8c34a", "b": "#b08c1e", "c": "#f8e38e", "d": "#fff8d8"},
        [
            "................",
            "................",
            "................",
            "................",
            ".....oooooo.....",
            "...ooccccccoo...",
            "..ocaaaaaaaaco..",
            "..oaaaaaaaaaao..",
            "..oabaaaaaabo...",
            "..oabbbbbbbao...",
            "...oooooooooo...",
            "................",
            "................",
            "................",
            "................",
            "................",
        ],
    ),
    "gem": (
        {"o": "#123040", "a": "#3ec6d8", "b": "#1f8ea6", "c": "#9ef2ff", "d": "#ffffff"},
        [
            "................",
            "................",
            "......oooo......",
            ".....occcco.....",
            "....occccddo....",
            "...ocaaaaaabo...",
            "..ocaaaaaaaabo..",
            "..obaaaaaaaaao..",
            "...obaaaaaaabo..",
            "....obaaaaabo...",
            ".....obbbbbbo...",
            "......obbbbo....",
            ".......oooo.....",
            "................",
            "................",
            "................",
        ],
    ),
    "scroll": (
        {"o": "#3a2c1a", "a": "#e8d8a8", "b": "#c4b080", "c": "#f8f0d0", "d": "#8a4a2a"},
        [
            "................",
            "................",
            "...oooooooooo...",
            "..oddddddddddo..",
            "..oadadadadaco..",
            "..oadadadadaco..",
            "..oadadadadaco..",
            "..oadadadadaco..",
            "..oadadadadaco..",
            "..oadadadadaco..",
            "..oadadadadaco..",
            "..oddddddddddo..",
            "...oooooooooo...",
            "................",
            "................",
            "................",
        ],
    ),
    "jade": (
        {"o": "#1e3a2c", "a": "#6fc48a", "b": "#3f8a5c", "c": "#a8e8bc", "d": "#12281e"},
        [
            "................",
            "................",
            "......oooo......",
            "....ooccccoo....",
            "...ocaaaaaaco...",
            "..ocaaaaaaaaao..",
            ".ocaaaaaaaaaaao.",
            ".oaaddddddddaao.",
            ".oaaddddddddaao.",
            ".ocaaaaaaaaaaao.",
            "..ocaaaaaaaaao..",
            "...ocaaaaaaco...",
            "....ooccccoo....",
            "......oooo......",
            "................",
            "................",
        ],
    ),
}
# 注意：ram_zun（商代双羊尊）的美术不在这里生成——它来自 3D 模型渲染管线：
#   tools/blender/render_relic_turntable.py → tools/gen_relic_sprite.py
# 产出 relic_ram_zun_strip.png（关卡内转台动画）与 artifact_ram_zun.png（24×24 图标）。


def build_artifact(name):
    pal, rows = ART[name]
    im = img(16, 16)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                im.putpixel((x, y), hexc(pal[ch]))
    return im


# ---------------------------------------------------------------------------
# Tiles and props (16x16, night-museum palette)
# ---------------------------------------------------------------------------


def build_parquet(shade):
    im = img(16, 16)
    base = hexc("#4a3b2c") if not shade else hexc("#443626")
    line = hexc("#3a2e21") if not shade else hexc("#352a1e")
    hi = hexc("#57462f") if not shade else hexc("#4f3f2c")
    rect(im, 0, 0, 15, 15, base)
    rect(im, 0, 7, 15, 7, line)          # plank seam
    rect(im, 5, 0, 5, 6, line)
    rect(im, 11, 8, 11, 15, line)
    rect(im, 0, 0, 15, 0, hi)
    rect(im, 0, 8, 15, 8, hi)
    px(im, 3, 3, hi)
    px(im, 13, 12, hi)
    return im


def build_wall():
    im = img(16, 16)
    rect(im, 0, 0, 15, 15, hexc("#2b3350"))
    rect(im, 0, 0, 15, 1, hexc("#3a4468"))     # top light
    rect(im, 0, 2, 15, 2, hexc("#232a44"))
    for y in (6, 10, 14):                      # panel joints
        rect(im, 0, y, 15, y, hexc("#232a44"))
    for x in (5, 11):
        rect(im, x, 3, x, 5, hexc("#232a44"))
        rect(im, x + 8 if x == 5 else 3, 7, x + 8 if x == 5 else 3, 9, hexc("#232a44"))
    rect(im, 0, 15, 15, 15, hexc("#1b2136"))
    return im


def build_wall_painting():
    im = build_wall()
    rect(im, 2, 3, 13, 12, hexc("#8a6a2a"))     # frame
    rect(im, 3, 4, 12, 11, hexc("#c9a860"))
    rect(im, 3, 4, 12, 4, hexc("#e2c98c"))
    rect(im, 4, 6, 11, 9, hexc("#6a8aa8"))      # canvas sky
    rect(im, 4, 9, 11, 9, hexc("#4a6a86"))
    rect(im, 4, 10, 11, 10, hexc("#3a5a44"))    # landscape
    return im


def build_carpet():
    im = img(16, 16)
    rect(im, 0, 0, 15, 15, hexc("#7a2f3c"))
    rect(im, 1, 1, 14, 14, hexc("#8c3a48"))
    rect(im, 2, 2, 13, 13, hexc("#7a2f3c"))
    rect(im, 4, 4, 11, 11, hexc("#8c3a48"))
    px(im, 7, 7, hexc("#c9a227"))
    px(im, 8, 8, hexc("#c9a227"))
    px(im, 7, 8, hexc("#c9a227"))
    px(im, 8, 7, hexc("#c9a227"))
    return im


def build_pedestal():
    im = img(16, 16)
    rect(im, 2, 3, 13, 14, hexc("#4e5460"))
    rect(im, 3, 4, 12, 7, hexc("#5e6572"))
    rect(im, 3, 4, 12, 4, hexc("#727a88"))
    rect(im, 2, 14, 13, 14, hexc("#33373f"))
    rect(im, 4, 9, 11, 9, hexc("#454b56"))
    return im


def build_case():
    im = img(16, 16)
    rect(im, 1, 2, 14, 14, hexc("#5a4a2e"))       # wooden base
    rect(im, 2, 3, 13, 9, hexc("#8fb4d6"))        # glass
    rect(im, 2, 3, 13, 3, hexc("#cfe2f2"))
    rect(im, 3, 5, 6, 8, hexc("#d8b23a"))         # exhibit inside
    rect(im, 3, 7, 6, 8, hexc("#b08c1e"))
    rect(im, 10, 6, 12, 8, hexc("#9ef2ff"))       # small gem
    rect(im, 1, 10, 14, 11, hexc("#4a3c24"))      # frame
    rect(im, 1, 12, 14, 14, hexc("#3a2f1c"))
    rect(im, 1, 2, 14, 2, hexc("#6a5836"))
    return im


def build_rope():
    im = img(16, 16)
    rect(im, 2, 4, 3, 14, hexc("#a8863a"))        # post
    rect(im, 2, 4, 3, 4, hexc("#e8c34a"))
    rect(im, 12, 4, 13, 14, hexc("#a8863a"))
    rect(im, 12, 4, 13, 4, hexc("#e8c34a"))
    rect(im, 4, 6, 11, 6, hexc("#e8c34a"))        # rope
    px(im, 7, 7, hexc("#e8c34a"))
    px(im, 8, 7, hexc("#e8c34a"))
    rect(im, 2, 14, 3, 15, hexc("#4a3c24"))
    rect(im, 12, 14, 13, 15, hexc("#4a3c24"))
    return im


def build_statue():
    im = img(16, 16)
    rect(im, 3, 12, 12, 15, hexc("#4e5460"))      # plinth
    rect(im, 4, 13, 11, 13, hexc("#5e6572"))
    rect(im, 5, 4, 10, 11, hexc("#c9ccd4"))       # marble body
    rect(im, 6, 2, 9, 5, hexc("#d8dbe2"))         # head
    rect(im, 6, 3, 9, 3, hexc("#a8adb8"))
    px(im, 7, 3, hexc("#5e6572"))
    px(im, 8, 3, hexc("#5e6572"))
    rect(im, 5, 7, 5, 11, hexc("#a8adb8"))        # shading
    rect(im, 10, 7, 10, 11, hexc("#a8adb8"))
    rect(im, 4, 6, 4, 8, hexc("#d8dbe2"))         # arms
    rect(im, 11, 6, 11, 8, hexc("#d8dbe2"))
    return im


def build_plant():
    im = img(16, 16)
    rect(im, 5, 10, 10, 15, hexc("#8a4a2a"))      # pot
    rect(im, 4, 9, 11, 10, hexc("#a85a34"))
    rect(im, 7, 6, 8, 9, hexc("#3f8a5c"))         # stem
    rect(im, 3, 4, 6, 7, hexc("#4f9a68"))
    rect(im, 9, 3, 12, 6, hexc("#4f9a68"))
    rect(im, 6, 2, 9, 5, hexc("#5caa74"))
    px(im, 4, 3, hexc("#6fc48a"))
    px(im, 11, 2, hexc("#6fc48a"))
    return im


def build_exit():
    im = img(16, 16)
    rect(im, 1, 1, 14, 15, hexc("#2c4a2c"))
    rect(im, 2, 2, 13, 14, hexc("#3f6e3f"))
    rect(im, 5, 4, 10, 8, hexc("#a8e8a8"))
    rect(im, 6, 5, 9, 7, hexc("#2c4a2c"))
    rect(im, 5, 10, 10, 10, hexc("#a8e8a8"))
    return im


def build_wall_lamp():
    im = build_wall()
    rect(im, 6, 2, 9, 5, hexc("#c9a227"))         # sconce
    rect(im, 7, 3, 8, 6, hexc("#f8e38e"))
    rect(im, 5, 5, 10, 6, hexc("#8a6a2a"))
    return im


def build_light_soft(size=128):
    im = img(size, size)
    c = (size - 1) / 2.0
    r = size / 2.0
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) / r
            a = max(0.0, 1.0 - d)
            a = a * a * (3 - 2 * a)
            im.putpixel((x, y), (255, 255, 255, int(a * 255)))
    return im


def build_light_cone(size=128, half_angle=32.0, softness=16.0):
    im = img(size, size)
    c = (size - 1) / 2.0
    r = size / 2.0
    for y in range(size):
        for x in range(size):
            dx = (x - c) / r
            dy = (y - c) / r
            d = math.hypot(dx, dy)
            if d > 1.0:
                continue
            ang = math.degrees(math.atan2(dy, dx))
            if abs(ang) > 90.0:
                continue
            edge = half_angle + softness
            if ang > edge:
                continue
            fade = max(0.0, 1.0 - max(0.0, abs(ang) - half_angle) / softness)
            a = max(0.0, 1.0 - d)
            a = a * a * fade
            im.putpixel((x, y), (255, 255, 255, int(a * 255)))
    return im


def build_phone_icon():
    im = img(16, 16)
    rect(im, 3, 1, 12, 14, hexc("#1a1c24"))      # 机身
    rect(im, 3, 1, 12, 1, hexc("#3a3f4e"))
    rect(im, 4, 2, 11, 11, hexc("#24374e"))      # 屏幕
    rect(im, 4, 2, 11, 2, hexc("#3a5f8a"))
    rect(im, 6, 4, 9, 5, hexc("#f8e38e"))        # 任务卡
    rect(im, 6, 7, 9, 8, hexc("#c9a227"))
    rect(im, 7, 12, 8, 13, hexc("#8a6a2a"))      # home 键
    px(im, 11, 3, hexc("#e86a6a"))               # 通知红点
    px(im, 10, 3, hexc("#e86a6a"))
    return im


def build_icon():
    im = img(64, 64)
    rect(im, 0, 0, 63, 63, hexc("#1a1f30"))
    thief = char_frame(THIEF, "down", 0, "thief")
    big = thief.resize((48, 72), Image.NEAREST).crop((0, 8, 48, 72))
    im.alpha_composite(big, (8, 0))
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    print("characters:")
    save(build_sheet(THIEF, "thief"), "player_sheet.png")
    save(build_sheet(POLICE, "police"), "police_sheet.png")
    print("artifacts:")
    for name in ART:
        save(build_artifact(name), f"artifact_{name}.png")
    print("tiles & props:")
    save(build_parquet(False), "floor_a.png")
    save(build_parquet(True), "floor_b.png")
    save(build_wall(), "wall.png")
    save(build_wall_painting(), "wall_painting.png")
    save(build_wall_lamp(), "wall_lamp.png")
    save(build_carpet(), "carpet.png")
    save(build_pedestal(), "pedestal.png")
    save(build_case(), "case.png")
    save(build_rope(), "rope.png")
    save(build_statue(), "statue.png")
    save(build_plant(), "plant.png")
    save(build_exit(), "exit_door.png")
    save(build_phone_icon(), "phone_icon.png")
    print("lights:")
    save(build_light_soft(), "light_soft.png")
    save(build_light_cone(half_angle=42.0, softness=14.0), "light_cone.png")
    save(build_icon(), os.path.join("..", "..", "icon.png"))


if __name__ == "__main__":
    main()
