#!/usr/bin/env python3
"""大英博物馆·中国馆 Room 3 资产包生成器（v0.1）。

产出：
  assets/sprites/bm/bm_tiles.png      16x16 瓦片图集（8 列 × 4 行）
  assets/sprites/bm/bm_props.png      道具图集（32x32 单元，透明底）
  assets/sprites/bm/bm_ui.png         UI 九宫格/部件图集
  assets/sprites/bm/bm_zun_32.png     双羊尊 32x32 目标 sprite
  docs/art_direction/BM_asset_sheet.jpg   资产预览板

素材按 docs/BRITISH_MUSEUM_ART.md 的 Room 3 色板生成；修改本脚本后重新运行即可。
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites", "bm")
DOC = os.path.join(ROOT, "docs", "art_direction")
ARTI = os.path.join(ROOT, "assets", "arti-01", "v2-3fe98b09d1c624a6dc042085dbe27035_r.jpg.png")
FONT_SERIF = "/home/liyutong/.local/share/fonts/noto-cjk/NotoSerifCJKsc-Bold.otf"
FONT_SANS = "/home/liyutong/.local/share/fonts/noto-cjk/NotoSansCJKsc-Regular.otf"

# ---------------------------------------------------------------- palette
INK = (8, 12, 18, 255)
WALL_D = (17, 32, 40, 255)
WALL_M = (25, 48, 56, 255)
WALL_L = (38, 68, 76, 255)
TRIM = (168, 130, 62, 255)
GOLD = (226, 186, 92, 255)
GOLD_HI = (247, 220, 142, 255)
FLOOR_D = (24, 32, 38, 255)
FLOOR_M = (38, 50, 58, 255)
FLOOR_L = (56, 70, 78, 255)
GROUT = (13, 20, 26, 255)
MARBLE = (112, 122, 120, 255)
MARBLE_HI = (168, 176, 168, 255)
MARBLE_D = (62, 72, 72, 255)
CARPET_D = (74, 20, 30, 255)
CARPET_M = (118, 34, 44, 255)
CARPET_L = (164, 58, 66, 255)
ROPE = (156, 42, 48, 255)
BRASS = (140, 104, 48, 255)
GLASS = (116, 168, 178, 255)
GLASS_HI = (206, 238, 236, 255)
CYAN = (127, 224, 208, 255)
WARM = (232, 164, 76, 255)
WOOD_D = (46, 30, 20, 255)
WOOD_M = (78, 52, 32, 255)
PAPER = (226, 214, 190, 255)
PAPER_D = (160, 135, 90, 255)
JADE = (127, 183, 163, 255)
BLUE_W = (220, 235, 240, 255)


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), c)


def rect(im, x0, y0, x1, y1, c):
    ImageDraw.Draw(im).rectangle([x0, y0, x1, y1], fill=c)


def line(im, pts, c, width=1):
    ImageDraw.Draw(im).line(pts, fill=c, width=width)


# ---------------------------------------------------------------- tiles (16x16)
def t_floor(v=0):
    im = img(16, 16)
    base = [(38, 50, 58, 255), (34, 46, 54, 255), (42, 54, 62, 255), (36, 48, 56, 255)][v % 4]
    rect(im, 0, 0, 15, 15, base)
    # 极低对比度接缝：只暗示铺装，不形成“台阶”
    line(im, [(15, 0), (15, 15)], (30, 40, 48, 90))
    line(im, [(0, 15), (15, 15)], (30, 40, 48, 90))
    rng = random.Random(v)
    for _ in range(5):
        px(im, rng.randrange(16), rng.randrange(16), (44, 58, 66, 90))
    return im


def t_floor_crack():
    im = t_floor(1)
    line(im, [(4, 2), (7, 8), (5, 13)], (30, 40, 48, 110))
    line(im, [(7, 8), (12, 6)], (30, 40, 48, 80))
    return im


def t_wall(v=0):
    im = img(16, 16)
    base = [WALL_M, WALL_D, WALL_L, WALL_M][v % 4]
    rect(im, 0, 0, 15, 15, base)
    line(im, [(0, 0), (15, 0)], INK)
    line(im, [(0, 0), (0, 15)], INK)
    rect(im, 3, 3, 12, 12, (0, 0, 0, 0))
    line(im, [(3, 3), (12, 3)], (52, 90, 92, 120))
    line(im, [(3, 12), (12, 12)], (8, 16, 22, 140))
    line(im, [(3, 3), (3, 12)], (52, 90, 92, 90))
    line(im, [(12, 3), (12, 12)], (8, 16, 22, 120))
    return im


def t_wall_trim():
    im = img(16, 16)
    rect(im, 0, 11, 15, 16, TRIM)
    line(im, [(0, 11), (15, 11)], GOLD)
    line(im, [(0, 15), (15, 15)], INK)
    return im


def t_wainscot():
    im = img(16, 16)
    rect(im, 0, 0, 15, 15, WOOD_M)
    line(im, [(0, 4), (15, 4)], WOOD_D)
    line(im, [(0, 9), (15, 9)], WOOD_D)
    line(im, [(4, 0), (4, 15)], (60, 40, 24, 120))
    return im


def t_wall_lamp():
    im = img(16, 16)
    rect(im, 6, 2, 9, 6, BRASS)
    rect(im, 5, 1, 10, 3, GOLD)
    rect(im, 7, 6, 8, 10, GOLD_HI)
    d = ImageDraw.Draw(im)
    d.ellipse([3, 0, 12, 9], fill=(WARM[0], WARM[1], WARM[2], 40))
    return im


def t_carpet(v=0):
    im = img(16, 16)
    base = CARPET_M if v == 0 else CARPET_D
    rect(im, 0, 0, 15, 15, base)
    if v == 0:
        rect(im, 4, 4, 11, 11, CARPET_L)
        px(im, 7, 7, GOLD)
        px(im, 8, 8, GOLD)
    else:
        line(im, [(0, 0), (0, 15)], GOLD)
        line(im, [(15, 0), (15, 15)], GOLD)
    return im


def t_case(v=0):
    im = img(16, 16)
    if v == 0:  # brass horizontal
        rect(im, 0, 6, 15, 9, BRASS)
        line(im, [(0, 6), (15, 6)], GOLD)
    elif v == 1:  # brass vertical
        rect(im, 6, 0, 9, 15, BRASS)
        line(im, [(6, 0), (6, 15)], GOLD)
    elif v == 2:  # glass pane
        rect(im, 0, 0, 15, 15, (GLASS[0], GLASS[1], GLASS[2], 24))
        line(im, [(0, 0), (15, 0)], GLASS_HI)
        line(im, [(0, 15), (15, 15)], GLASS_HI)
    else:  # corner
        rect(im, 0, 6, 9, 9, BRASS)
        rect(im, 6, 0, 9, 9, BRASS)
        px(im, 8, 8, GOLD_HI)
    return im


def t_rope_post():
    im = img(16, 16)
    rect(im, 6, 2, 9, 14, BRASS)
    rect(im, 4, 0, 11, 4, GOLD)
    rect(im, 4, 12, 11, 16, GOLD)
    return im


def t_rope():
    im = img(16, 16)
    line(im, [(0, 8), (5, 6), (10, 9), (15, 7)], ROPE, 2)
    line(im, [(0, 7), (5, 5), (10, 8), (15, 6)], (210, 90, 90, 80))
    return im


def t_column(v=0):
    im = img(16, 16)
    rect(im, 2, 0, 13, 15, MARBLE)
    rect(im, 4, 0, 6, 15, MARBLE_HI)
    rect(im, 10, 0, 13, 15, MARBLE_D)
    if v == 0:
        rect(im, 0, 12, 15, 15, TRIM)
    elif v == 1:
        rect(im, 0, 0, 15, 3, TRIM)
    return im


def t_scroll(v=0):
    im = img(16, 16)
    rect(im, 2, 0, 13, 15, PAPER)
    line(im, [(2, 0), (2, 15)], PAPER_D)
    line(im, [(13, 0), (13, 15)], PAPER_D)
    if v == 0:
        rect(im, 0, 0, 15, 2, TRIM)
    elif v == 1:
        rect(im, 0, 13, 15, 15, TRIM)
    else:
        line(im, [(3, 12), (6, 7), (9, 9), (12, 4)], (58, 78, 72, 220))
        line(im, [(3, 12), (12, 12)], (40, 54, 50, 180))
    return im


def t_crate(v=0):
    im = img(16, 16)
    base = [(78, 52, 32, 255), (92, 64, 40, 255), (64, 44, 28, 255), (110, 78, 48, 255)][v % 4]
    rect(im, 0, 0, 15, 15, base)
    line(im, [(0, 0), (15, 15)], WOOD_D)
    line(im, [(15, 0), (0, 15)], WOOD_D)
    rect(im, 0, 0, 15, 2, (120, 88, 52, 255))
    rect(im, 0, 13, 15, 15, WOOD_D)
    if v % 2 == 1:
        px(im, 7, 7, GOLD)
    return im


def t_warning():
    im = img(16, 16)
    for x in range(-16, 16, 8):
        d = ImageDraw.Draw(im)
        d.polygon([(x, 16), (x + 8, 16), (x + 16, 0), (x + 8, 0)], fill=GOLD)
    return im


def t_floor_light(v=0):
    im = img(16, 16)
    base = [(106, 114, 118, 255), (116, 124, 128, 255), (96, 104, 110, 255)][v % 3]
    rect(im, 0, 0, 15, 15, base)
    line(im, [(15, 0), (15, 15)], (92, 100, 106, 90))
    line(im, [(0, 15), (15, 15)], (92, 100, 106, 90))
    rng = random.Random(v + 3)
    for _ in range(4):
        px(im, rng.randrange(16), rng.randrange(16), (124, 132, 136, 90))
    return im


def t_floor_wood(v=0):
    im = img(16, 16)
    base = [(92, 64, 40, 255), (104, 74, 46, 255), (82, 56, 34, 255)][v % 3]
    rect(im, 0, 0, 15, 15, base)
    line(im, [(0, 5), (15, 5)], (78, 52, 32, 110))
    line(im, [(0, 11), (15, 11)], (78, 52, 32, 110))
    line(im, [(4, 0), (4, 15)], (100, 70, 44, 70))
    line(im, [(12, 0), (12, 15)], (100, 70, 44, 70))
    return im


def t_floor_sand(v=0):
    im = img(16, 16)
    base = [(146, 116, 78, 255), (158, 126, 84, 255), (134, 106, 72, 255)][v % 3]
    rect(im, 0, 0, 15, 15, base)
    rng = random.Random(v + 7)
    for _ in range(10):
        px(im, rng.randrange(16), rng.randrange(16), (138, 110, 74, 110))
    return im


def t_floor_concrete(v=0):
    im = img(16, 16)
    base = [(80, 84, 88, 255), (88, 92, 96, 255), (72, 76, 80, 255)][v % 3]
    rect(im, 0, 0, 15, 15, base)
    rng = random.Random(v + 11)
    for _ in range(6):
        px(im, rng.randrange(16), rng.randrange(16), (68, 72, 76, 120))
    line(im, [(0, 15), (15, 15)], (64, 68, 72, 90))
    return im


def t_wall_neo(v=0):
    im = img(16, 16)
    base = [(58, 74, 90, 255), (72, 88, 104, 255)][v % 2]
    rect(im, 0, 0, 15, 15, base)
    line(im, [(3, 0), (3, 15)], (40, 52, 64, 230))
    line(im, [(12, 0), (12, 15)], (96, 112, 126, 170))
    line(im, [(5, 3), (10, 3)], (126, 142, 154, 140))
    line(im, [(5, 12), (10, 12)], (34, 44, 54, 180))
    return im


def t_wall_blue(v=0):
    im = img(16, 16)
    base = [(26, 58, 82, 255), (38, 74, 102, 255)][v % 2]
    rect(im, 0, 0, 15, 15, base)
    for i in range(3):
        line(im, [(2 + i * 5, 2), (6 + i * 5, 12)], (18, 42, 62, 170))
    line(im, [(0, 0), (15, 0)], (16, 38, 58, 220))
    line(im, [(0, 15), (15, 15)], (12, 30, 46, 220))
    return im


def t_wall_warm(v=0):
    im = img(16, 16)
    base = [(106, 80, 56, 255), (126, 96, 66, 255)][v % 2]
    rect(im, 0, 0, 15, 15, base)
    line(im, [(0, 5), (15, 5)], (84, 62, 44, 210))
    line(im, [(0, 11), (15, 11)], (84, 62, 44, 210))
    line(im, [(6, 0), (6, 15)], (146, 116, 82, 130))
    return im


def t_wall_ochre(v=0):
    im = img(16, 16)
    base = [(138, 90, 58, 255), (158, 104, 66, 255)][v % 2]
    rect(im, 0, 0, 15, 15, base)
    rng = random.Random(v + 10)
    for _ in range(10):
        px(im, rng.randrange(16), rng.randrange(16), (108, 68, 44, 150))
    line(im, [(0, 0), (15, 0)], (96, 60, 38, 220))
    return im


def t_wall_metal(v=0):
    im = img(16, 16)
    base = [(74, 78, 82, 255), (90, 94, 98, 255)][v % 2]
    rect(im, 0, 0, 15, 15, base)
    line(im, [(0, 7), (15, 7)], (58, 62, 66, 230))
    for (x, y) in [(3, 3), (12, 3), (3, 12), (12, 12)]:
        px(im, x, y, (124, 128, 132, 210))
    return im


def t_carpet_blue(v=0):
    im = img(16, 16)
    base = (30, 60, 96, 255) if v == 0 else (44, 78, 118, 255)
    rect(im, 0, 0, 15, 15, base)
    if v == 0:
        rect(im, 5, 5, 10, 10, (60, 100, 140, 255))
        px(im, 7, 7, (200, 220, 240, 220))
    else:
        line(im, [(0, 0), (0, 15)], (200, 220, 240, 190))
        line(im, [(15, 0), (15, 15)], (200, 220, 240, 190))
    return im


def t_case_lacquer(v=0):
    im = img(16, 16)
    if v == 0:
        rect(im, 0, 6, 15, 9, CARPET_M)
        line(im, [(0, 6), (15, 6)], GOLD)
    else:
        rect(im, 6, 0, 9, 15, CARPET_M)
        line(im, [(6, 0), (6, 15)], GOLD)
    return im


def t_case_porcelain(v=0):
    im = img(16, 16)
    if v == 0:
        rect(im, 0, 6, 15, 9, BLUE_W)
        line(im, [(0, 6), (15, 6)], (70, 120, 180, 230))
    else:
        rect(im, 6, 0, 9, 15, BLUE_W)
        line(im, [(6, 0), (6, 15)], (70, 120, 180, 230))
    return im


def t_mural():
    im = img(16, 16)
    rect(im, 0, 0, 15, 15, (96, 60, 38, 255))
    d = ImageDraw.Draw(im)
    d.ellipse([3, 4, 12, 11], fill=(180, 120, 70, 200))
    d.arc([2, 2, 13, 13], 200, 340, fill=(220, 170, 110, 200))
    line(im, [(2, 13), (14, 13)], (70, 44, 30, 210))
    return im


def t_pipe():
    im = img(16, 16)
    rect(im, 0, 6, 15, 10, (78, 84, 90, 255))
    line(im, [(0, 6), (15, 6)], (112, 120, 126, 230))
    line(im, [(0, 10), (15, 10)], (48, 52, 56, 230))
    rect(im, 7, 4, 10, 12, (60, 64, 68, 255))
    return im


def t_fluoro():
    im = img(16, 16)
    rect(im, 0, 0, 15, 15, (30, 34, 40, 255))
    rect(im, 2, 3, 13, 5, (220, 240, 245, 240))
    rect(im, 2, 8, 13, 10, (160, 200, 215, 170))
    return im


def t_skylight():
    im = img(16, 16)
    rect(im, 0, 0, 15, 15, (70, 110, 130, 255))
    line(im, [(0, 0), (15, 15)], (200, 235, 240, 190))
    line(im, [(4, 0), (15, 11)], (200, 235, 240, 120))
    rect(im, 0, 0, 15, 2, (150, 200, 210, 210))
    return im


def t_trim_neo():
    im = img(16, 16)
    rect(im, 0, 10, 15, 15, (140, 148, 150, 255))
    line(im, [(0, 10), (15, 10)], (194, 202, 202, 230))
    line(im, [(0, 15), (15, 15)], (80, 88, 92, 230))
    return im


TILES = [
    ("地面 1", t_floor(0)), ("地面 2", t_floor(1)), ("地面 3", t_floor(2)), ("地面 4", t_floor(3)),
    ("裂缝地", t_floor_crack()), ("墙面 1", t_wall(0)), ("墙面 2", t_wall(1)), ("墙面 3", t_wall(2)),
    ("踢脚线", t_wall_trim()), ("护墙板", t_wainscot()), ("壁灯", t_wall_lamp()), ("红毯", t_carpet(0)),
    ("红毯边", t_carpet(1)), ("柜横", t_case(0)), ("柜竖", t_case(1)), ("玻璃", t_case(2)),
    ("柜角", t_case(3)), ("围栏柱", t_rope_post()), ("围栏绳", t_rope()), ("柱头", t_column(1)),
    ("柱身", t_column(2)), ("柱础", t_column(0)), ("挂轴顶", t_scroll(0)), ("挂轴中", t_scroll(2)),
    ("挂轴底", t_scroll(1)), ("木箱 1", t_crate(0)), ("木箱 2", t_crate(1)), ("警示条", t_warning()),
    ("理石地1", t_floor_light(0)), ("理石地2", t_floor_light(1)), ("木地1", t_floor_wood(0)), ("木地2", t_floor_wood(1)),
    ("沙地1", t_floor_sand(0)), ("沙地2", t_floor_sand(1)), ("水泥1", t_floor_concrete(0)), ("水泥2", t_floor_concrete(1)),
    ("新古典1", t_wall_neo(0)), ("新古典2", t_wall_neo(1)), ("青花墙1", t_wall_blue(0)), ("青花墙2", t_wall_blue(1)),
    ("暖墙1", t_wall_warm(0)), ("暖墙2", t_wall_warm(1)), ("土红墙1", t_wall_ochre(0)), ("土红墙2", t_wall_ochre(1)),
    ("金属墙1", t_wall_metal(0)), ("金属墙2", t_wall_metal(1)), ("蓝毯", t_carpet_blue(0)), ("蓝毯边", t_carpet_blue(1)),
    ("漆柜横", t_case_lacquer(0)), ("漆柜竖", t_case_lacquer(1)), ("瓷柜横", t_case_porcelain(0)), ("瓷柜竖", t_case_porcelain(1)),
    ("壁画", t_mural()), ("管道", t_pipe()), ("日光灯", t_fluoro()), ("天窗", t_skylight()),
    ("新古典线", t_trim_neo()), ("警示线", t_warning()), ("木箱 3", t_crate(2)), ("木箱 4", t_crate(3)),
]


# ---------------------------------------------------------------- decor (visual only)
def d_security_gate():
    im = img(16, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 4, 4, 30], fill=(70, 78, 86, 255))
    d.rectangle([11, 4, 14, 30], fill=(70, 78, 86, 255))
    d.rectangle([1, 2, 14, 6], fill=(96, 106, 114, 255))
    d.line([(3, 8), (3, 28)], fill=(180, 200, 210, 210))
    d.line([(12, 8), (12, 28)], fill=(180, 200, 210, 210))
    d.rectangle([6, 8, 9, 12], fill=(220, 80, 70, 230))
    d.rectangle([6, 14, 9, 18], fill=(120, 200, 150, 230))
    return im


def d_ticket_desk():
    im = img(32, 20)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 5, 30, 18], fill=(84, 54, 32, 255))
    d.rectangle([0, 3, 31, 7], fill=(120, 82, 46, 255))
    d.rectangle([4, 9, 12, 15], fill=PAPER)
    d.rectangle([18, 9, 27, 15], fill=(40, 48, 56, 255))
    d.rectangle([19, 10, 26, 14], fill=(120, 180, 200, 180))
    return im


def d_museum_map():
    im = img(16, 16)
    rect(im, 1, 1, 14, 14, (18, 24, 30, 255))
    d = ImageDraw.Draw(im)
    d.rectangle([1, 1, 14, 14], outline=TRIM)
    for (x, y, w, h) in [(3, 3, 4, 3), (9, 3, 4, 3), (3, 8, 4, 5), (9, 8, 4, 5)]:
        d.rectangle([x, y, x + w, y + h], fill=(52, 74, 84, 255), outline=(120, 160, 170, 220))
    d.rectangle([7, 6, 9, 12], fill=GOLD)
    return im


def d_vase_case():
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 4, 29, 28], fill=(116, 168, 178, 20))
    d.rectangle([0, 2, 31, 30], outline=GLASS_HI)
    d.rectangle([10, 8, 21, 17], fill=BLUE_W)
    d.rectangle([14, 4, 17, 9], fill=BLUE_W)
    d.ellipse([10, 8, 21, 20], outline=(70, 120, 180, 230))
    d.line([(12, 13), (19, 13)], fill=(70, 120, 180, 220))
    d.rectangle([0, 30, 31, 32], fill=BRASS)
    return im


def d_jade_case():
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 4, 29, 28], fill=(116, 168, 178, 20))
    d.rectangle([0, 2, 31, 30], outline=GLASS_HI)
    d.ellipse([8, 10, 24, 26], fill=JADE, outline=(210, 250, 235, 255))
    d.ellipse([14, 16, 18, 20], fill=(42, 95, 82, 255))
    d.rectangle([0, 30, 31, 32], fill=BRASS)
    return im


def d_scroll_case():
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 4, 29, 28], fill=(116, 168, 178, 20))
    d.rectangle([0, 2, 31, 30], outline=GLASS_HI)
    d.rectangle([8, 7, 23, 27], fill=PAPER)
    d.rectangle([6, 5, 25, 8], fill=TRIM)
    d.rectangle([6, 26, 25, 29], fill=TRIM)
    d.line([(10, 22), (13, 14), (17, 18), (22, 10)], fill=(58, 78, 72, 230), width=2)
    d.rectangle([0, 30, 31, 32], fill=BRASS)
    return im


def d_lacquer_cabinet():
    im = img(32, 32)
    rect(im, 2, 4, 29, 30, CARPET_D)
    d = ImageDraw.Draw(im)
    d.rectangle([3, 5, 28, 29], outline=GOLD)
    d.rectangle([4, 6, 15, 28], outline=(120, 30, 40, 255))
    d.rectangle([16, 6, 27, 28], outline=(120, 30, 40, 255))
    d.ellipse([12, 16, 15, 19], fill=GOLD)
    d.ellipse([17, 16, 20, 19], fill=GOLD)
    return im


def d_mural_panel():
    im = img(48, 32)
    rect(im, 0, 0, 47, 31, (96, 60, 38, 255))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 47, 31], outline=TRIM)
    for i in range(4):
        x = 6 + i * 11
        y = 8 + (i % 2) * 8
        d.ellipse([x, y, x + 12, y + 8], fill=(180, 120, 70, 200))
        d.arc([x - 2, y - 4, x + 14, y + 12], 200, 340, fill=(220, 170, 110, 220))
    d.line([(4, 27), (44, 27)], fill=(70, 44, 30, 230))
    return im


def d_crate_stack():
    im = img(32, 32)
    rect(im, 2, 14, 30, 30, WOOD_M)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 14, 30, 30], outline=WOOD_D)
    d.line([(2, 14), (30, 30)], fill=WOOD_D)
    d.line([(30, 14), (2, 30)], fill=WOOD_D)
    d.rectangle([8, 2, 26, 15], fill=(104, 72, 44, 255), outline=WOOD_D)
    d.line([(8, 2), (26, 15)], fill=WOOD_D)
    d.line([(26, 2), (8, 15)], fill=WOOD_D)
    return im


def d_pallet():
    im = img(32, 16)
    rect(im, 0, 8, 31, 13, (96, 66, 40, 255))
    d = ImageDraw.Draw(im)
    for x in range(0, 32, 6):
        d.rectangle([x, 10, x + 3, 15], fill=(70, 46, 28, 255))
    d.rectangle([6, 1, 25, 10], fill=(120, 88, 52, 255), outline=WOOD_D)
    return im


def d_forklift():
    im = img(48, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([8, 10, 30, 24], fill=(196, 160, 60, 255))
    d.rectangle([12, 2, 26, 14], fill=(70, 76, 84, 255))
    d.rectangle([14, 4, 24, 12], fill=(120, 180, 200, 200))
    d.rectangle([28, 4, 31, 28], fill=(80, 86, 94, 255))
    d.rectangle([31, 22, 44, 25], fill=(120, 126, 134, 255))
    d.ellipse([6, 22, 14, 30], fill=(40, 44, 48, 255))
    d.ellipse([24, 22, 32, 30], fill=(40, 44, 48, 255))
    d.rectangle([32, 26, 44, 28], fill=(60, 64, 68, 255))
    return im


def d_pipe_panel():
    im = img(32, 16)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 3, 31, 7], fill=(78, 84, 90, 255))
    d.rectangle([0, 10, 31, 14], fill=(60, 64, 68, 255))
    d.rectangle([6, 1, 10, 9], fill=(90, 96, 102, 255))
    d.rectangle([20, 8, 24, 15], fill=(90, 96, 102, 255))
    d.ellipse([7, 4, 9, 6], fill=(190, 200, 210, 220))
    d.ellipse([21, 11, 23, 13], fill=(190, 200, 210, 220))
    return im


def d_bench():
    im = img(24, 12)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 3, 22, 6], fill=(96, 62, 36, 255))
    d.rectangle([1, 6, 22, 8], fill=(64, 42, 26, 255))
    d.rectangle([3, 8, 6, 12], fill=(40, 44, 48, 255))
    d.rectangle([17, 8, 20, 12], fill=(40, 44, 48, 255))
    return im


def d_security_camera():
    im = img(16, 16)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 6, 9, 11], fill=(58, 64, 72, 255))
    d.rectangle([9, 5, 14, 12], fill=(74, 82, 90, 255))
    d.ellipse([10, 7, 13, 10], fill=(24, 30, 38, 255))
    d.ellipse([11, 8, 12, 9], fill=(150, 210, 230, 220))
    d.line([(2, 6), (2, 2)], fill=(90, 98, 106, 255), width=2)
    d.rectangle([1, 1, 5, 3], fill=(70, 78, 86, 255))
    d.ellipse([12, 2, 14, 4], fill=(220, 70, 60, 230))
    return im


def d_alarm_beacon():
    im = img(16, 16)
    d = ImageDraw.Draw(im)
    d.rectangle([5, 10, 10, 14], fill=(70, 74, 80, 255))
    d.ellipse([3, 3, 12, 12], fill=(180, 40, 36, 230))
    d.ellipse([5, 5, 10, 10], fill=(255, 110, 90, 245))
    d.arc([2, 2, 13, 13], 200, 340, fill=(255, 180, 140, 200))
    return im


def d_skylight_panel():
    im = img(32, 16)
    rect(im, 0, 0, 31, 15, (54, 84, 98, 255))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 31, 15], outline=(150, 190, 200, 230))
    for x in range(0, 32, 8):
        d.line([(x, 0), (x, 15)], fill=(30, 46, 56, 220))
    d.line([(0, 7), (31, 7)], fill=(30, 46, 56, 220))
    d.line([(2, 1), (14, 1)], fill=(200, 235, 240, 120))
    d.line([(18, 1), (29, 1)], fill=(200, 235, 240, 100))
    return im


DECOR = [
    ("security_gate", "安检门", d_security_gate()),
    ("ticket_desk", "售票台", d_ticket_desk()),
    ("museum_map", "展厅地图", d_museum_map()),
    ("vase_case", "青花展柜", d_vase_case()),
    ("jade_case", "玉璧展柜", d_jade_case()),
    ("scroll_case", "手卷展柜", d_scroll_case()),
    ("lacquer_cabinet", "红漆柜", d_lacquer_cabinet()),
    ("mural_panel", "壁画", d_mural_panel()),
    ("crate_stack", "木箱堆", d_crate_stack()),
    ("pallet", "托盘", d_pallet()),
    ("forklift", "叉车", d_forklift()),
    ("pipe_panel", "管道", d_pipe_panel()),
    ("bench", "长椅", d_bench()),
    ("security_camera", "监控", d_security_camera()),
    ("alarm_beacon", "警报灯", d_alarm_beacon()),
    ("skylight_panel", "天窗", d_skylight_panel()),
]


# ---------------------------------------------------------------- props
def p_zun():
    """From the project photo: cut out, downscale to 32x32, quantize, outline."""
    from scipy import ndimage
    src = Image.open(ARTI).convert("RGB")
    a = np.asarray(src).astype(np.float32)
    near_white = a.min(axis=2) > 235
    lab, n = ndimage.label(near_white)
    border = set(lab[0, :]) | set(lab[-1, :]) | set(lab[:, 0]) | set(lab[:, -1])
    bg = np.isin(lab, list(border))
    fg = ~bg
    fg = ndimage.binary_closing(fg, iterations=2)
    fg = ndimage.binary_fill_holes(fg)
    alpha = ndimage.gaussian_filter(fg.astype(np.float32), sigma=1.2)
    alpha = np.clip((alpha - 0.15) / 0.85, 0, 1)
    cut = Image.fromarray(np.dstack([a, alpha * 255]).astype(np.uint8), "RGBA")
    cut = cut.crop(cut.getbbox())
    cut = cut.crop((0, 0, cut.width, cut.height - int(cut.height * 0.08)))
    im = cut.resize((32, 32), Image.LANCZOS)
    g = np.asarray(im.convert("L")).astype(np.float32)
    al = np.asarray(im).astype(np.float32)[..., 3]
    ramp = [(6, 14, 10), (18, 38, 28), (36, 70, 50), (64, 108, 76), (102, 148, 104),
            (154, 188, 128), (226, 186, 92), (247, 226, 158)]
    def tone(v):
        if v < 24: return ramp[0]
        if v < 46: return ramp[1]
        if v < 70: return ramp[2]
        if v < 98: return ramp[3]
        if v < 130: return ramp[4]
        if v < 165: return ramp[5]
        if v < 205: return ramp[6]
        return ramp[7]
    arr = np.zeros((32, 32, 4), np.uint8)
    for y in range(32):
        for x in range(32):
            if al[y, x] > 40:
                arr[y, x, :3] = tone(g[y, x])
                arr[y, x, 3] = 255
    mask = arr[..., 3] > 0
    edge = mask & ~ndimage.binary_erosion(mask, iterations=1)
    arr[edge, :3] = (6, 12, 10)
    arr[edge, 3] = 255
    for y in range(0, 14):
        for x in range(32):
            if arr[y, x, 3] > 0 and g[y, x] > 145:
                arr[y, x, :3] = (226, 186, 92)
    return Image.fromarray(arr, "RGBA")


def p_vase():
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    d.ellipse([8, 6, 24, 26], fill=BLUE_W)
    rect(im, 14, 2, 18, 8, BLUE_W)
    d.ellipse([10, 8, 22, 24], outline=(70, 120, 180, 255))
    line(im, [(12, 14), (20, 14)], (70, 120, 180, 200))
    line(im, [(12, 18), (20, 18)], (70, 120, 180, 200))
    return im


def p_jade():
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    d.ellipse([6, 6, 26, 26], fill=JADE, outline=(210, 250, 235, 255))
    d.ellipse([13, 13, 19, 19], fill=(42, 95, 82, 255))
    return im


def p_scroll_prop():
    im = img(32, 32)
    rect(im, 4, 2, 27, 29, PAPER)
    rect(im, 2, 0, 29, 3, TRIM)
    rect(im, 2, 28, 29, 31, TRIM)
    line(im, [(7, 22), (11, 13), (16, 17), (23, 8)], (58, 78, 72, 220), 2)
    line(im, [(7, 22), (23, 22)], (40, 54, 50, 180))
    return im


def p_case():
    im = img(32, 48)
    rect(im, 2, 4, 29, 44, (GLASS[0], GLASS[1], GLASS[2], 20))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 2, 31, 45], outline=GLASS_HI)
    d.rectangle([2, 0, 29, 3], fill=BRASS)
    d.rectangle([2, 44, 29, 47], fill=BRASS)
    d.line([(0, 46), (31, 46)], fill=GOLD)
    d.line([(4, 42), (12, 8)], fill=(GLASS_HI[0], GLASS_HI[1], GLASS_HI[2], 70))
    return im


def p_pedestal():
    im = img(32, 32)
    rect(im, 4, 4, 27, 24, (54, 56, 54, 255))
    rect(im, 2, 24, 29, 29, MARBLE)
    rect(im, 4, 26, 27, 28, MARBLE_HI)
    rect(im, 6, 0, 25, 6, TRIM)
    return im


def p_lamp():
    return t_wall_lamp().resize((32, 32), Image.NEAREST)


PROPS = [
    ("双羊尊", p_zun()), ("青花瓶", p_vase()), ("玉璧", p_jade()), ("手卷", p_scroll_prop()),
    ("玻璃展柜", p_case()), ("展台", p_pedestal()), ("壁灯", p_lamp()), ("空", img(32, 32)),
]


# ---------------------------------------------------------------- UI
def ui_label():
    im = img(48, 32)
    rect(im, 0, 0, 47, 31, (233, 223, 199, 240))
    d = ImageDraw.Draw(im)
    d.rectangle([1, 1, 46, 30], outline=TRIM)
    d.line([(3, 29), (45, 29)], fill=(120, 100, 70, 180))
    return im


def ui_plaque():
    im = img(48, 24)
    rect(im, 0, 0, 47, 23, (120, 92, 44, 255))
    d = ImageDraw.Draw(im)
    d.rectangle([1, 1, 46, 22], outline=GOLD)
    return im


def ui_seal():
    im = img(24, 24)
    rect(im, 1, 1, 22, 22, (166, 49, 38, 235))
    px(im, 2, 2, (0, 0, 0, 0))
    px(im, 21, 21, (0, 0, 0, 0))
    return im


def ui_slot():
    im = img(16, 16)
    rect(im, 0, 0, 15, 15, (24, 20, 16, 235))
    d = ImageDraw.Draw(im)
    d.rectangle([1, 1, 14, 14], outline=(120, 92, 44, 200))
    px(im, 2, 2, (170, 140, 80, 120))
    return im


def ui_button():
    im = img(48, 16)
    rect(im, 0, 0, 47, 15, (20, 24, 32, 235))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 47, 15], outline=(120, 96, 48, 220))
    d.line([(2, 2), (45, 2)], fill=(201, 162, 39, 120))
    return im


UI = [("展签框", ui_label()), ("黄铜牌", ui_plaque()), ("朱砂印", ui_seal()), ("背包格", ui_slot()),
      ("按钮框", ui_button())]


# ---------------------------------------------------------------- build
def atlas(items, cell, cols, path):
    rows = (len(items) + cols - 1) // cols
    out = img(cols * cell, rows * cell)
    for i, (name, tile) in enumerate(items):
        x = (i % cols) * cell
        y = (i // cols) * cell
        if tile.size != (cell, cell):
            tile = tile.resize((cell, cell), Image.NEAREST)
        out.alpha_composite(tile, (x, y))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.save(path)
    return out


def build_sheet(tiles, props, ui, decor):
    W, H = 1600, 900
    sheet = Image.new("RGB", (W, H), (10, 12, 16))
    d = ImageDraw.Draw(sheet)
    def F(path, s):
        return ImageFont.truetype(path, s)
    d.text((60, 34), "大英博物馆 · 中国馆  /  资产包 v0.2", font=F(FONT_SERIF, 40), fill=(238, 230, 212))
    d.text((62, 84), "六展厅瓦片 · 32×32 道具 · UI 部件  |  生成脚本 tools/gen_bm_art.py", font=F(FONT_SANS, 18), fill=(201, 162, 39))
    # tiles 4x
    d.text((60, 130), "瓦片", font=F(FONT_SERIF, 24), fill=(238, 230, 212))
    sx, sy, scale = 60, 170, 4
    per_row = 8
    for i, (name, tile) in enumerate(tiles):
        if tile.getbbox() is None:
            continue
        x = sx + (i % per_row) * 70
        y = sy + (i // per_row) * 86
        big = tile.resize((64, 64), Image.NEAREST)
        sheet.paste(big.convert("RGB"), (x, y))
        d.rectangle([x - 1, y - 1, x + 64, y + 64], outline=(70, 60, 44))
        d.text((x, y + 66), name[:6], font=F(FONT_SANS, 12), fill=(170, 162, 146))
    # props 3x
    d.text((640, 130), "道具", font=F(FONT_SERIF, 24), fill=(238, 230, 212))
    px0, py0, pscale = 640, 170, 3
    for i, (name, prop) in enumerate(props):
        if prop.getbbox() is None:
            continue
        x = px0 + (i % 8) * 116
        y = py0 + (i // 8) * 130
        big = prop.resize((96, 96), Image.NEAREST)
        sheet.paste(big.convert("RGB"), (x, y), big)
        d.rectangle([x - 1, y - 1, x + 96, y + 96], outline=(70, 60, 44))
        d.text((x, y + 98), name, font=F(FONT_SANS, 12), fill=(170, 162, 146))
    # ui 3x
    d.text((640, 320), "UI 部件", font=F(FONT_SERIF, 24), fill=(238, 230, 212))
    ux0, uy0 = 640, 354
    for i, (name, part) in enumerate(ui):
        x = ux0 + i * 150
        y = uy0
        big = part.resize((part.width * 3, part.height * 3), Image.NEAREST)
        sheet.paste(big.convert("RGB"), (x, y), big)
        d.rectangle([x - 1, y - 1, x + big.width, y + big.height], outline=(70, 60, 44))
        d.text((x, y + big.height + 4), name, font=F(FONT_SANS, 12), fill=(170, 162, 146))
    # palette + note
    # decor section
    d.text((640, 430), "装饰（纯视觉）", font=F(FONT_SERIF, 24), fill=(238, 230, 212))
    for i, (key, name, prop) in enumerate(decor[:8]):
        x = 640 + (i % 4) * 180
        y = 464 + (i // 4) * 118
        big = prop.resize((prop.width * 2, prop.height * 2), Image.NEAREST)
        sheet.paste(big.convert("RGB"), (x, y), big)
        d.rectangle([x - 1, y - 1, x + big.width, y + big.height], outline=(70, 60, 44))
        d.text((x, y + big.height + 4), name, font=F(FONT_SANS, 12), fill=(170, 162, 146))
    pal = [("夜墨", "#0A0E17"), ("石厅蓝", "#26384A"), ("大理石", "#B9B3A6"), ("琥珀", "#E0A44C"),
           ("青铜", "#8C7A4E"), ("铜绿", "#5E8C6A"), ("幽灵青", "#7FE0D0")]
    d.text((640, 700), "色板", font=F(FONT_SERIF, 22), fill=(238, 230, 212))
    for i, (name, hexv) in enumerate(pal):
        c = tuple(int(hexv[j:j + 2], 16) for j in (1, 3, 5))
        x = 640 + i * 120
        d.rectangle([x, 734, x + 26, 760], fill=c, outline=(90, 80, 64))
        d.text((x, 764), hexv, font=F(FONT_SANS, 12), fill=(190, 182, 166))
    d.text((640, 806), "注：v0.4 六展厅瓦片 + 16 类装饰（图中示前 8 类）；装饰不新增碰撞。", font=F(FONT_SANS, 14), fill=(150, 142, 128))
    d.text((640, 830), "生成物禁止手改；改样式请编辑 tools/gen_bm_art.py 后重新运行。", font=F(FONT_SANS, 14), fill=(150, 142, 128))
    sheet.save(os.path.join(DOC, "BM_asset_sheet.jpg"), quality=93)
    print("  wrote BM_asset_sheet.jpg")


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(DOC, exist_ok=True)
    tiles = atlas(TILES, 16, 8, os.path.join(OUT, "bm_tiles.png"))
    props = atlas(PROPS, 32, 8, os.path.join(OUT, "bm_props.png"))
    ui = atlas(UI, 32, 8, os.path.join(OUT, "bm_ui.png"))
    # zun sprite 32x32
    zun = p_zun()
    zun.save(os.path.join(OUT, "bm_zun_32.png"))
    # stand-alone glass case (32x48) for the target room
    p_case().save(os.path.join(OUT, "bm_case.png"))
    print("  wrote assets/sprites/bm/{bm_tiles,bm_props,bm_ui,bm_zun_32,bm_case}.png")
    decor_dir = os.path.join(OUT, "decor")
    os.makedirs(decor_dir, exist_ok=True)
    for key, name, prop in DECOR:
        prop.save(os.path.join(decor_dir, key + ".png"))
    print("  wrote assets/sprites/bm/decor/*.png")
    build_sheet(TILES, PROPS, UI, DECOR)
    print("done")


if __name__ == "__main__":
    main()
