#!/usr/bin/env python3
"""Generate A-00 art deliverables: 24x32 character sheets, safe house skin,
phone UI skin/mockup and the character board.

Run:  python3 tools/gen_a00_art.py

The actual pixel sprites are drawn by tools/a00_characters.py.  SiliconFlow
concept images live in docs/art_direction/a00_src/ and are used only as
references / board material, never as gameplay textures.
"""
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import a00_characters as chars  # noqa: E402

SPRITES = ROOT / "assets" / "sprites"
CHARS = SPRITES / "chars"
ART = ROOT / "assets" / "art"
DOC = ROOT / "docs" / "art_direction"
SRC = DOC / "a00_src"
SHOT = ROOT / "tests" / "visual_baseline" / "shot_bm_room3.png"

PIX = str(ROOT / "assets" / "fonts" / "fusion-pixel-12px.ttf")
SANS = "/home/liyutong/.local/share/fonts/noto-cjk/NotoSansCJKsc-Regular.otf"
SERIF = "/home/liyutong/.local/share/fonts/noto-cjk/NotoSerifCJKsc-Bold.otf"


def font(size: int, path: str = PIX):
    return ImageFont.truetype(path, size)


def main() -> None:
    for p in (CHARS, ART, DOC, SRC):
        p.mkdir(parents=True, exist_ok=True)

    player_sheet = chars.build_player_sheet()
    police_sheet = chars.build_police_sheet()
    player_sheet.save(CHARS / "player_sheet_v2.png")
    police_sheet.save(CHARS / "police_sheet_v2.png")
    player_sheet.resize((player_sheet.width * 6, player_sheet.height * 6), Image.NEAREST).save(
        SRC / "player_v2_preview.png"
    )
    police_sheet.resize((police_sheet.width * 6, police_sheet.height * 6), Image.NEAREST).save(
        SRC / "police_v2_preview.png"
    )

    bg640 = build_safehouse_background()
    build_hub_mockup(bg640)
    build_phone()
    build_character_board()
    build_concept_board()
    build_scale_preview()
    print("A-00 assets generated:")
    for p in [
        CHARS / "player_sheet_v2.png",
        CHARS / "police_sheet_v2.png",
        ART / "safehouse_bg.png",
        ART / "phone_frame_9p.png",
        DOC / "A00_characters_board.png",
        DOC / "A00_safehouse_ui.png",
        DOC / "A00_phone_ui.png",
        DOC / "A00_concept_board.png",
        DOC / "A00_ingame_scale.png",
    ]:
        print("  ", p.relative_to(ROOT))


def build_safehouse_background() -> Image.Image:
    """Pixelate/grade the SiliconFlow safe-house concept into a 1280x720 bg."""
    src = Image.open(SRC / "a00_safehouse_concept.png").convert("RGB")
    small = src.resize((640, 360), Image.LANCZOS)
    q = small.quantize(colors=40, method=Image.MEDIANCUT, dither=Image.FLOYDSTEINBERG).convert("RGB")
    arr = np.asarray(q).astype(np.float32)
    yy, xx = np.mgrid[0:360, 0:640]
    r = np.sqrt(((xx - 320) / 340) ** 2 + ((yy - 180) / 210) ** 2)
    v = np.clip(1 - (r - 0.55) * 0.45, 0.55, 1)
    arr *= v[..., None]
    for y in range(360):
        f = 0.55 * (1 - y / 90) if y < 90 else (0.35 * ((y - 300) / 60) if y > 300 else 0)
        if f:
            arr[y] *= 1 - f
    bg = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    bg.resize((1280, 720), Image.NEAREST).save(ART / "safehouse_bg.png")
    return bg


def build_hub_mockup(bg640: Image.Image) -> None:
    im = bg640.convert("RGBA")
    d = ImageDraw.Draw(im, "RGBA")
    f12, f10, f8 = font(12), font(10), font(8)
    fs16 = font(16, SERIF)
    GOLD = (216, 168, 78, 255)
    GOLD_H = (244, 212, 138, 255)
    MUTED = (172, 176, 166, 255)
    RED = (166, 49, 38, 255)
    PANEL = (12, 20, 24, 232)
    PANEL2 = (16, 26, 30, 238)
    BORDER = (96, 74, 40, 255)

    d.rectangle([0, 0, 640, 34], fill=(6, 10, 13, 190))
    d.line([(0, 34), (640, 34)], fill=GOLD)
    d.text((16, 8), "神偷组织 · 据点", font=fs16, fill=GOLD)
    d.text((624, 11), "金币 650", font=f12, fill=GOLD_H, anchor="ra")

    def tab(x, w, label, active=False):
        d.rectangle([x, 40, x + w, 64], fill=(GOLD if active else PANEL2), outline=BORDER)
        d.line([(x + 1, 41), (x + w - 1, 41)], fill=(GOLD_H if active else (54, 48, 34, 255)))
        d.text((x + w // 2, 46), label, font=f12,
               fill=((20, 16, 12, 255) if active else (194, 186, 164, 255)), anchor="ma")

    tab(16, 80, "任务", True)
    tab(102, 80, "商店")
    tab(188, 80, "销赃")
    d.rectangle([540, 40, 624, 64], fill=PANEL2, outline=BORDER)
    d.text((582, 46), "返回标题", font=f10, fill=(170, 174, 164, 255), anchor="ma")

    mask = Image.open(SPRITES / "mask_closeup.png").convert("RGBA").resize((48, 48), Image.NEAREST)
    zun = Image.open(SPRITES / "relic_ram_zun_ui_strip.png").convert("RGBA").crop((0, 0, 48, 56)).resize(
        (48, 48), Image.LANCZOS
    )

    def card(y, icon, title, detail):
        d.rectangle([16, y, 624, y + 66], fill=PANEL, outline=BORDER)
        d.rectangle([16, y, 19, y + 66], fill=RED)
        d.rectangle([28, y + 9, 80, y + 57], fill=(226, 216, 192, 245), outline=(120, 94, 50, 255))
        im.alpha_composite(icon, (32, y + 13))
        d.text((90, y + 8), title, font=f12, fill=GOLD_H)
        d.text((90, y + 27), detail, font=f10, fill=(206, 200, 184, 255))
        d.text((90, y + 44), "点击卡片查看任务 · 目标文物已归档", font=f8, fill=(150, 156, 150, 255))
        d.rectangle([520, y + 17, 612, y + 49], fill=GOLD, outline=(120, 88, 40, 255))
        d.rectangle([522, y + 19, 610, y + 47], outline=GOLD_H)
        d.text((566, y + 26), "开始行动", font=f10, fill=(24, 18, 12, 255), anchor="ma")

    card(74, mask, "城西博物馆", "目标：青铜人面具 · 报酬：200 金币")
    card(148, zun, "大英博物馆 · 中国馆", "目标：商代双羊尊 · 报酬：400 金币")

    d.rectangle([0, 322, 640, 360], fill=(6, 10, 13, 150))
    d.text((16, 336), "点击卡片开始行动  ·  任务详情见手机（P）  ·  存档自动保存", font=f8,
           fill=(164, 168, 158, 255))
    ph = Image.open(SPRITES / "phone_icon.png").convert("RGBA").resize((24, 24), Image.NEAREST)
    im.alpha_composite(ph, (596, 292))
    d.ellipse([614, 290, 620, 296], fill=RED)
    im.convert("RGB").resize((1280, 720), Image.NEAREST).save(DOC / "A00_safehouse_ui.png")


def build_phone() -> None:
    # 9-patch frame for code integration (96x96, 24px margins)
    frame = Image.new("RGBA", (96, 96), (8, 12, 14, 255))
    fd = ImageDraw.Draw(frame)
    fd.rectangle([0, 0, 95, 95], outline=(4, 6, 8, 255), width=1)
    fd.rectangle([1, 1, 94, 94], outline=(140, 106, 54, 255), width=3)
    fd.rectangle([4, 4, 91, 91], outline=(216, 168, 78, 255), width=1)
    fd.rectangle([5, 5, 90, 90], fill=(8, 18, 20, 255))
    for x, y in ((8, 8), (82, 8), (8, 82), (82, 82)):
        fd.line([(x, y), (x + 5, y)], fill=(244, 212, 138, 255))
        fd.line([(x, y), (x, y + 5)], fill=(244, 212, 138, 255))
    for yy in range(10, 86, 4):
        fd.line([(10, yy), (85, yy)], fill=(12, 28, 30, 90))
    frame.save(ART / "phone_frame_9p.png")

    # Mockup over a dimmed BM room
    bg = Image.open(SHOT).convert("RGB").resize((640, 360), Image.LANCZOS)
    bg = Image.eval(bg, lambda v: int(v * 0.38))
    im = bg.convert("RGBA")
    d = ImageDraw.Draw(im)
    f8, f9, f10, f14 = font(8), font(9), font(10), font(14)
    fs18, fs10 = font(18, SERIF), font(10, SERIF)
    GOLD = (216, 168, 78, 255)
    GOLD_H = (244, 212, 138, 255)
    CREAM = (233, 223, 199, 255)
    RED = (166, 49, 38, 255)

    d.rectangle([0, 0, 640, 360], fill=(4, 8, 10, 120))

    def rr(box, r, fill, outline=None, width=1):
        d.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)

    rr([80, 10, 560, 350], 12, (28, 24, 20, 255), (150, 116, 58, 255), 2)
    rr([84, 14, 556, 346], 10, (10, 12, 14, 255), (92, 70, 36, 255), 1)
    rr([92, 36, 548, 324], 6, (8, 18, 20, 255), (70, 96, 90, 255), 1)
    d.rectangle([76, 86, 80, 118], fill=(120, 90, 44, 255))
    d.rectangle([76, 126, 80, 160], fill=(96, 72, 36, 255))
    d.rectangle([560, 94, 564, 136], fill=(120, 90, 44, 255))
    d.rounded_rectangle([286, 18, 354, 28], radius=4, fill=(6, 8, 10, 255))
    d.rounded_rectangle([302, 21, 338, 24], radius=1, fill=(70, 64, 50, 255))
    d.ellipse([342, 21, 346, 25], fill=(40, 60, 60, 255))
    for y in range(38, 324, 4):
        d.line([(93, y), (547, y)], fill=(12, 28, 30, 60))

    d.text((100, 42), "神偷组织", font=f9, fill=(154, 180, 164, 255))
    d.text((320, 42), "23:47", font=f9, fill=(210, 196, 160, 255), anchor="ma")
    for i in range(4):
        d.rectangle([478 + i * 4, 49 - i * 2, 480 + i * 4, 53], fill=(154, 196, 170, 255))
    d.rectangle([502, 45, 520, 52], outline=(180, 190, 170, 255))
    d.rectangle([503, 46, 516, 51], fill=(154, 196, 170, 255))
    d.rectangle([521, 47, 522, 50], fill=(180, 190, 170, 255))

    d.text((100, 62), "任务终端", font=fs18, fill=(240, 208, 132, 255))
    d.rectangle([476, 60, 502, 82], fill=RED)
    d.text((489, 64), "密", font=fs10, fill=(244, 238, 223, 255), anchor="ma")
    d.text((489, 74), "档", font=fs10, fill=(244, 238, 223, 255), anchor="ma")
    d.rectangle([400, 62, 466, 82], fill=(210, 166, 84, 255), outline=(120, 90, 44, 255))
    d.text((433, 66), "任务", font=f10, fill=(28, 22, 14, 255), anchor="ma")
    d.rectangle([468, 62, 534, 82], fill=(20, 34, 36, 255), outline=(80, 72, 48, 255))
    d.text((501, 66), "档案", font=f10, fill=(184, 178, 158, 255), anchor="ma")

    d.rounded_rectangle([100, 90, 186, 202], radius=3, fill=(233, 223, 199, 248), outline=(150, 116, 58, 255))
    d.rectangle([102, 92, 184, 200], outline=(226, 206, 160, 255))
    mask = Image.open(SPRITES / "mask_closeup.png").convert("RGBA").resize((64, 64), Image.NEAREST)
    im.alpha_composite(mask, (111, 108))
    d.text((143, 178), "青铜人面具", font=f10, fill=(50, 40, 28, 255), anchor="ma")
    d.line([(108, 188), (178, 188)], fill=(160, 130, 78, 255))
    d.text((143, 190), "馆藏 · 一级", font=f8, fill=(110, 90, 60, 255), anchor="ma")
    d.ellipse([168, 90, 188, 110], fill=RED, outline=(110, 30, 24, 255))
    d.text((178, 95), "藏", font=font(9, SERIF), fill=(244, 238, 223, 255), anchor="ma")

    d.text((196, 90), "青铜人面具", font=f14, fill=GOLD_H)
    d.text((196, 111), "行动地点：城西博物馆", font=f10, fill=(206, 200, 184, 255))
    d.text((196, 126), "委托人：老猫  ·  报酬：200 金币", font=f10, fill=(206, 200, 184, 255))
    story = [
        "商代晚期青铜人面饰，约前 13—前 11 世纪。",
        "1976 年陕西城固苏村小冢窖藏出土，",
        "同批面具 23 件，脸形椭圆、嘴角上扬。",
    ]
    for i, line in enumerate(story):
        d.text((196, 145 + i * 14), line, font=f10, fill=(168, 176, 168, 255))

    d.rounded_rectangle([196, 200, 536, 266], radius=2, fill=(233, 223, 199, 248), outline=(150, 116, 58, 255))
    d.rectangle([198, 202, 534, 264], outline=(226, 206, 160, 255))
    d.text((204, 206), "文物档案 · 商代晚期（约前 13—前 11 世纪）", font=f9, fill=(50, 40, 28, 255))
    d.text((204, 220), "现藏：城固县博物馆等  ·  1976 年城固苏村窖藏出土", font=f9, fill=(70, 58, 42, 255))
    d.text((204, 234), "备注：「三千年前的微笑」——馆里的人这么叫它。", font=f9, fill=(70, 58, 42, 255))

    notes = [
        "· 拿到目标后，出口才会开启",
        "· 被警察抓到 = 本次行动结束",
        "· 目标可丢下（B），出口重新上锁",
    ]
    for i, line in enumerate(notes):
        d.text((196, 278 + i * 12), line, font=f9, fill=(190, 172, 140, 255))
    d.line([(100, 316), (540, 316)], fill=(70, 96, 90, 120))
    d.text((100, 320), "●  ○", font=f9, fill=(180, 170, 140, 255))
    d.text((540, 320), "P / ESC 关闭", font=f9, fill=(150, 154, 146, 255), anchor="ra")
    d.rounded_rectangle([304, 328, 336, 332], radius=2, fill=(120, 116, 104, 180))
    im.convert("RGB").resize((1280, 720), Image.NEAREST).save(DOC / "A00_phone_ui.png")


def build_character_board() -> None:
    W, H = 1280, 720
    BG = (13, 19, 24, 255)
    PANEL = (20, 28, 34, 255)
    GOLD = (216, 168, 78, 255)
    GOLD_H = (244, 212, 138, 255)
    CREAM = (233, 223, 199, 255)
    im = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(im)
    for x in range(0, W, 80):
        d.line([(x, 0), (x, H)], fill=(18, 26, 32, 255))
    for y in range(0, H, 80):
        d.line([(0, y), (W, y)], fill=(18, 26, 32, 255))
    d.rectangle([0, 0, W, 96], fill=(10, 15, 19, 255))
    d.rectangle([0, 94, W, 96], fill=GOLD)
    d.text((36, 18), "A-00 角色美术 · 24×32", font=font(36, SERIF), fill=CREAM)
    d.text((36, 62), "玩家 / 警察 · 3 向 × 4 帧 · 全像素；AI 概念只作方向参考，游戏内使用手工 sprite",
           font=font(16, SANS), fill=(186, 178, 158, 255))
    d.text((1244, 34), "docs/art_direction/A00_characters_board.png", font=font(12, SANS),
           fill=(120, 128, 124, 255), anchor="ra")

    def portrait(path, x, y, w, h, label, sub):
        img = Image.open(path).convert("RGB")
        iw, ih = img.size
        cw = int(ih * 0.62)
        x0 = max(0, (iw - cw) // 2)
        crop = img.crop((x0, 0, x0 + cw, ih))
        crop.thumbnail((w, h), Image.LANCZOS)
        d.rectangle([x - 3, y - 3, x + w + 3, y + h + 3], fill=PANEL, outline=(96, 74, 40, 255))
        im.alpha_composite(crop.convert("RGBA"), (x + (w - crop.width) // 2, y + (h - crop.height) // 2))
        d.rectangle([x - 3, y - 3, x + w + 3, y + h + 3], outline=(120, 92, 48, 255))
        d.text((x, y + h + 10), label, font=font(14, SANS), fill=GOLD_H)
        d.text((x, y + h + 28), sub, font=font(10, SANS), fill=(140, 148, 142, 255))

    portrait(SRC / "a00_player_concept.png", 36, 118, 196, 250, "玩家概念", "SiliconFlow · 方向参考")
    portrait(SRC / "a00_police_concept_v2.png", 252, 118, 196, 250, "警察概念", "SiliconFlow · 方向参考")

    def sheet(path, x, y, label):
        img = Image.open(path).convert("RGBA").resize((384, 384), Image.NEAREST)
        d.rectangle([x - 4, y - 4, x + 388, y + 388], fill=(38, 52, 58, 255),
                    outline=GOLD if "player" in str(path) else (100, 130, 150, 255))
        im.alpha_composite(img, (x, y))
        for c in range(1, 4):
            d.line([(x + c * 96, y), (x + c * 96, y + 384)], fill=(255, 255, 255, 18))
        for r in range(1, 3):
            d.line([(x, y + r * 128), (x + 384, y + r * 128)], fill=(255, 255, 255, 18))
        d.text((x, y - 26), label, font=font(14, SANS), fill=CREAM)
        for r, t in enumerate(["下", "上", "侧"]):
            d.text((x - 14, y + r * 128 + 64), t, font=font(14, SANS), fill=(196, 180, 140, 255),
                   anchor="ma")

    sheet(CHARS / "player_sheet_v2.png", 510, 120, "玩家 96×96 · 12 帧")
    sheet(CHARS / "police_sheet_v2.png", 920, 120, "警察 96×96 · 12 帧")

    def swatches(y, colors, label):
        d.text((36, y), label, font=font(14, SANS), fill=GOLD_H)
        x = 36
        for _, hexv in colors:
            c = tuple(int(hexv[i:i + 2], 16) for i in (1, 3, 5)) + (255,)
            d.rectangle([x, y + 24, x + 26, y + 50], fill=c, outline=(0, 0, 0, 255))
            d.text((x + 13, y + 54), hexv.upper(), font=font(8, SANS), fill=(150, 156, 148, 255), anchor="ma")
            x += 48

    swatches(430, [("暗", "#06080C"), ("影", "#122E36"), ("主", "#1E4860"), ("亮", "#4A7A96"),
                   ("围巾", "#266068"), ("皮", "#704C28"), ("金", "#E0B24E"), ("眼", "#FFCE5C")], "玩家调色板")
    swatches(530, [("暗", "#05080E"), ("帽", "#182A44"), ("主", "#203C5E"), ("亮", "#30547E"),
                   ("肤", "#DC986C"), ("皮带", "#12161C"), ("铜", "#D6A64C"), ("灯", "#FFD070")], "警察调色板")

    d.rectangle([36, 610, 1244, 704], fill=(16, 24, 28, 255), outline=(88, 70, 40, 255))
    specs = [
        ("帧规格", "24×32 / 帧；96×96 / sheet；hframes=4，vframes=3"),
        ("行/列", "行 0 下、1 上、2 侧；列 0 待机 A、1 待机 B、2 行走 A、3 行走 B"),
        ("锚点/碰撞", "Sprite2D.position.y = -10；碰撞 10×8 不变，只换视觉"),
        ("路径", "assets/sprites/chars/player_sheet_v2.png / police_sheet_v2.png"),
        ("接入", "@code：player.gd / police.gd 的 frame 计算改为 row*4 + col；侧行基址 8"),
    ]
    for i, (k, v) in enumerate(specs):
        x = 52 + (i % 3) * 400
        y = 622 + (i // 3) * 34
        d.text((x, y), k, font=font(12, SANS), fill=GOLD)
        d.text((x + 62, y), v, font=font(11, SANS), fill=(190, 192, 184, 255))
    d.text((1244, 690), "概念图只用于方向讨论；正式资产以 assets/sprites/chars/*.png 为准",
           font=font(10, SANS), fill=(120, 128, 124, 255), anchor="ra")
    im.convert("RGB").save(DOC / "A00_characters_board.png", quality=94)


def build_concept_board() -> None:
    W, H = 1280, 720
    im = Image.new("RGBA", (W, H), (13, 19, 24, 255))
    d = ImageDraw.Draw(im)
    for x in range(0, W, 80):
        d.line([(x, 0), (x, H)], fill=(18, 26, 32, 255))
    for y in range(0, H, 80):
        d.line([(0, y), (W, y)], fill=(18, 26, 32, 255))
    d.rectangle([0, 0, W, 92], fill=(10, 15, 19, 255))
    d.rectangle([0, 90, W, 92], fill=(216, 168, 78, 255))
    d.text((36, 16), "A-00 SiliconFlow 概念板", font=font(36, SERIF), fill=(233, 223, 199, 255))
    d.text((36, 60), "概念只用于方向/材质/构图参考；游戏内资产为手工 24×32 sprite 与程序化 UI",
           font=font(15, SANS), fill=(186, 178, 158, 255))

    def cell(x, y, w, h, img_path, title, meta, portrait=False):
        d.rectangle([x, y, x + w, y + h], fill=(20, 28, 34, 255), outline=(88, 70, 40, 255))
        img = Image.open(img_path).convert("RGB")
        if portrait:
            iw, ih = img.size
            cw = int(ih * 0.62)
            x0 = max(0, (iw - cw) // 2)
            img = img.crop((x0, 0, x0 + cw, ih))
        img.thumbnail((w - 20, h - 54), Image.LANCZOS)
        im.alpha_composite(img.convert("RGBA"), (x + (w - img.width) // 2, y + 8))
        d.text((x + 12, y + h - 42), title, font=font(15, SANS), fill=(244, 212, 138, 255))
        d.text((x + 12, y + h - 23), meta, font=font(10, SANS), fill=(146, 154, 148, 255))

    cell(28, 112, 600, 282, SRC / "a00_player_concept.png",
         "玩家 · 盗贼概念", "Kolors · seed 24011 · 1024×1024 · 方向参考", True)
    cell(652, 112, 600, 282, SRC / "a00_police_concept_v2.png",
         "警察 · 夜班守卫概念", "Kolors · seed 24031 · 1024×1024 · 方向参考", True)
    cell(28, 410, 600, 282, SRC / "a00_safehouse_concept.png",
         "安全屋 · 据点概念", "Kolors · seed 24022 · 1280×720 · 已处理为游戏背景")
    cell(652, 410, 600, 282, SRC / "a00_phone_ui_concept.png",
         "电话 UI · 材质概念", "Kolors · seed 24032 · 1280×720 · 只取材质/边框语言")
    d.text((1244, 700), "AI 概念可能含伪文字/伪纹样，不直接进入玩法", font=font(10, SANS),
           fill=(120, 128, 124, 255), anchor="ra")
    im.convert("RGB").save(DOC / "A00_concept_board.png", quality=94)


def build_scale_preview() -> None:
    """Current 16x24 vs A-00 24x32 at 640x360 logical, 2x output."""
    im = Image.new("RGB", (640, 360), (16, 26, 32))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 640, 120], fill=(24, 44, 52))
    d.rectangle([0, 120, 640, 360], fill=(28, 40, 46))
    for x in range(0, 640, 16):
        d.line([(x, 120), (x, 360)], fill=(22, 32, 38))
    for y in range(120, 360, 16):
        d.line([(0, y), (640, y)], fill=(22, 32, 38))
    d.rectangle([220, 120, 400, 360], fill=(88, 20, 30))
    d.rectangle([224, 120, 396, 360], fill=(112, 24, 36))
    # current 16x24 (first down frame), 2x
    cur_p = Image.open(SPRITES / "player_sheet.png").convert("RGBA").crop((0, 0, 16, 24)).resize((32, 48), Image.NEAREST)
    cur_g = Image.open(SPRITES / "police_sheet.png").convert("RGBA").crop((0, 0, 16, 24)).resize((32, 48), Image.NEAREST)
    new_p = Image.open(CHARS / "player_sheet_v2.png").convert("RGBA").crop((0, 0, 24, 32)).resize((48, 64), Image.NEAREST)
    new_g = Image.open(CHARS / "police_sheet_v2.png").convert("RGBA").crop((0, 0, 24, 32)).resize((48, 64), Image.NEAREST)
    im.paste(cur_p, (70, 220), cur_p)
    im.paste(new_p, (180, 204), new_p)
    im.paste(cur_g, (360, 220), cur_g)
    im.paste(new_g, (470, 204), new_g)
    f = font(8)
    for x, t in ((70, "现状 16×24"), (180, "A-00 24×32"), (360, "现状 16×24"), (470, "A-00 24×32")):
        d.text((x, 286), t, font=f, fill=(210, 196, 160))
    d.text((20, 20), "游戏尺度对比（640×360 逻辑，2× 输出）", font=font(12, SANS), fill=(240, 208, 132))
    d.text((20, 44), "左：现有 16×24；右：A-00 24×32。碰撞仍为 10×8，仅视觉升级。",
           font=font(9, SANS), fill=(186, 178, 158))
    im.resize((1280, 720), Image.NEAREST).save(DOC / "A00_ingame_scale.png")


if __name__ == "__main__":
    main()
