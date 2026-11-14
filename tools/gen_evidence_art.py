#!/usr/bin/env python3
"""Generate P3/P6 evidence-chain art: two new exhibit sets and the safehouse
clue-board / computer frame. Pure pixel drawing, no external assets.

Outputs (all under assets/):
  sprites/artifact_egypt_stela.png        16x16   inventory / list icon
  sprites/artifact_greek_relief.png       16x16
  sprites/relic_egypt_stela_ui_strip.png  576x56  12 frames 48x56 pseudo-turntable
  sprites/relic_greek_relief_ui_strip.png 576x56
  sprites/egypt_stela_closeup.png         360x360 inspect / archive close-up
  sprites/greek_relief_closeup.png        360x360
  art/safehouse_clue_board.png            1280x720 detective board backdrop
  art/safehouse_computer_frame_9p.png     96x96   9-patch (margin 12)

Run:  python3 tools/gen_evidence_art.py
Replace these by re-running the script; do not hand-edit the PNGs.
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "assets" / "sprites"
ART = ROOT / "assets" / "art"
CONCEPT = ROOT / "docs" / "art_direction" / "a00_src"

INK = (24, 18, 14, 255)
INK_SOFT = (56, 44, 34, 255)
SANDSTONE = (201, 163, 106, 255)
SANDSTONE_D = (150, 114, 70, 255)
SANDSTONE_L = (226, 196, 140, 255)
RED = (168, 67, 42, 255)
BLUE = (47, 94, 140, 255)
BLUE_D = (30, 62, 98, 255)
GREEN = (78, 122, 74, 255)
GOLD = (216, 168, 78, 255)
GOLD_H = (244, 212, 138, 255)

MARBLE = (232, 226, 208, 255)
MARBLE_L = (246, 242, 230, 255)
MARBLE_D = (190, 182, 160, 255)
MARBLE_DD = (150, 142, 124, 255)
MARBLE_OUT = (74, 68, 58, 255)
HORSE = (206, 198, 176, 255)


def new(size):
    return Image.new("RGBA", (size, size), (0, 0, 0, 0))


def pixelize_concept(name: str, scale: int, crop=None) -> Image.Image | None:
    """Turn a SiliconFlow concept into the 72px master (reference-led, P6 placeholder).

    Concepts are reference only; the output is a palette-reduced nearest-
    neighbour pixel master, not a traced copy of any museum object.
    """
    path = CONCEPT / name
    if not path.exists():
        return None
    src = Image.open(path).convert("RGB")
    if crop is not None:
        src = src.crop(crop)
    small = src.resize((72, 72), Image.LANCZOS)
    quant = small.quantize(colors=20, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGBA")
    return quant.resize((72 * scale, 72 * scale), Image.NEAREST)


def draw_stela(scale: int) -> Image.Image:
    """Arched painted stela. Concept-led if available, else procedural."""
    concept = pixelize_concept("evidence_egypt_stela_concept.png", scale, crop=(96, 96, 928, 928))
    if concept is not None:
        return concept
    base = 72
    im = new(base)
    d = ImageDraw.Draw(im)
    # body with rounded arch top
    d.rectangle((14, 24, 57, 66), fill=SANDSTONE, outline=INK)
    d.ellipse((14, 6, 57, 49), fill=SANDSTONE, outline=INK)
    d.rectangle((14, 27, 57, 47), fill=SANDSTONE)
    d.ellipse((15, 7, 56, 48), outline=SANDSTONE_L)
    d.rectangle((15, 26, 56, 65), outline=SANDSTONE_L)
    # sun disk and winged sign
    d.ellipse((31, 14, 40, 23), fill=GOLD, outline=INK)
    d.point((35, 18), fill=GOLD_H)
    # painted register: red border and figure scene
    d.rectangle((18, 28, 53, 30), fill=RED)
    d.rectangle((18, 44, 53, 46), fill=RED)
    d.rectangle((20, 31, 51, 43), fill=SANDSTONE_L)
    # seated owner figure (profile) and offering table
    d.ellipse((25, 33, 30, 38), fill=BLUE, outline=INK)  # head
    d.polygon(((23, 39), (32, 39), (33, 43), (22, 43)), fill=BLUE)  # torso/kilt
    d.rectangle((28, 43, 34, 44), fill=GOLD)  # table
    d.line((38, 34, 45, 34), fill=INK)  # offering line
    d.rectangle((38, 36, 44, 42), fill=GREEN, outline=INK)
    # hieroglyph column on the right (cut marks)
    for y in range(31, 43, 3):
        d.rectangle((47, y, 50, y + 1), fill=INK)
    # lapis lower band with chevrons
    d.rectangle((18, 47, 53, 59), fill=BLUE_D)
    for x in range(19, 53, 4):
        d.line((x, 56, x + 2, 52), fill=GOLD)
        d.line((x + 2, 52, x + 4, 56), fill=GOLD)
    # weathering
    for (x, y) in ((17, 40), (56, 58), (21, 62), (50, 14), (43, 63)):
        d.point((x, y), fill=SANDSTONE_D)
    return im.resize((base * scale, base * scale), Image.NEAREST)


def draw_relief(scale: int) -> Image.Image:
    """Marble rider fragment. Concept-led if available, else procedural."""
    concept = pixelize_concept("evidence_greek_relief_concept.png", scale, crop=(120, 120, 900, 900))
    if concept is not None:
        return concept
    base = 72
    im = new(base)
    d = ImageDraw.Draw(im)
    outline = [(6, 16), (14, 8), (30, 6), (40, 10), (50, 4), (64, 10),
               (66, 30), (60, 50), (50, 66), (30, 66), (10, 60), (4, 40)]
    d.polygon(outline, fill=MARBLE, outline=MARBLE_OUT)
    d.polygon([(40, 12), (62, 14), (64, 30), (56, 50), (48, 62), (42, 46)], fill=MARBLE_D)
    # horse head (profile, facing left-up) with ear and eye
    d.polygon([(10, 26), (16, 14), (24, 12), (30, 18), (30, 24), (24, 28), (14, 34)],
              fill=HORSE, outline=MARBLE_OUT)
    d.polygon([(22, 12), (24, 6), (27, 12)], fill=HORSE, outline=MARBLE_OUT)  # ear
    d.point((19, 19), fill=MARBLE_OUT)  # eye
    d.line((16, 14, 22, 24), fill=MARBLE_DD)  # mane edge
    # neck and barrel
    d.polygon([(26, 24), (40, 26), (52, 32), (56, 44), (50, 52), (34, 52), (26, 40)],
              fill=HORSE, outline=MARBLE_OUT)
    # legs (forward pair and rear pair)
    d.polygon([(30, 50), (36, 50), (34, 66), (28, 66)], fill=HORSE, outline=MARBLE_OUT)
    d.polygon([(44, 50), (50, 50), (52, 66), (46, 66)], fill=HORSE, outline=MARBLE_OUT)
    # rider: head, torso leaning forward, arm and rein
    d.ellipse((38, 6, 46, 14), fill=MARBLE_L, outline=MARBLE_OUT)
    d.polygon([(40, 14), (50, 14), (52, 28), (44, 34), (36, 28)], fill=MARBLE_L, outline=MARBLE_OUT)
    d.line((46, 18, 60, 10), fill=MARBLE_OUT)  # reins
    d.line((48, 28, 56, 34), fill=MARBLE_DD)  # arm
    # drapery folds on rider and horse
    for (x0, y0, x1, y1) in ((40, 30, 36, 40), (50, 36, 56, 48), (32, 42, 36, 50)):
        d.line((x0, y0, x1, y1), fill=MARBLE_DD)
    # chipped edges
    for (x, y) in ((8, 42), (62, 22), (46, 64)):
        d.point((x, y), fill=MARBLE_L)
    return im.resize((base * scale, base * scale), Image.NEAREST)


def icon16(kind: str) -> Image.Image:
    im = new(16)
    d = ImageDraw.Draw(im)
    if kind == "stela":
        d.rounded_rectangle((3, 2, 12, 14), radius=4, fill=SANDSTONE, outline=INK)
        d.rectangle((5, 6, 10, 7), fill=RED)
        d.rectangle((5, 10, 10, 11), fill=BLUE)
        d.point((8, 4), fill=GOLD)
    else:
        d.polygon([(2, 4), (7, 2), (13, 4), (14, 10), (11, 14), (5, 13), (2, 9)],
                  fill=MARBLE, outline=MARBLE_OUT)
        d.polygon([(8, 5), (12, 7), (12, 11), (9, 10)], fill=HORSE)
        d.line((8, 7, 6, 12), fill=MARBLE_OUT)
    return im


def ui_strip(master: Image.Image) -> Image.Image:
    """12 frames of 48x56 with horizontal squash to suggest a turntable."""
    frames = 12
    frame_w, frame_h = 48, 56
    strip = Image.new("RGBA", (frames * frame_w, frame_h), (0, 0, 0, 0))
    obj = master.resize((40, 40), Image.NEAREST)
    for i in range(frames):
        squash = max(0.22, abs(math.cos(2 * math.pi * i / frames)))
        w = max(4, round(40 * squash))
        piece = obj.resize((w, 40), Image.NEAREST)
        x = i * frame_w + (frame_w - w) // 2
        strip.alpha_composite(piece, (x, frame_h - 44))
    return strip


def clue_board() -> Image.Image:
    """Detective board for the safehouse, drawn at 640x360 and doubled."""
    w, h = 640, 360
    im = Image.new("RGBA", (w, h), (10, 22, 26, 255))
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / h
        d.line((0, y, w, y), fill=(int(12 + 10 * t), int(26 + 12 * t), int(30 + 10 * t), 255))
    # cork board
    d.rectangle((96, 40, 544, 292), fill=(58, 44, 30, 255), outline=(128, 96, 52, 255))
    d.rectangle((100, 44, 540, 288), fill=(92, 70, 46, 255))
    for x in range(104, 540, 9):
        for y in range(48, 288, 9):
            if (x * 3 + y * 7) % 11 == 0:
                d.point((x, y), fill=(110, 88, 58, 255))
    # three chain columns, three slots each (empty evidence cards)
    cols = [(132, GOLD), (288, (120, 170, 160, 255)), (444, (196, 186, 164, 255))]
    for cx, tint in cols:
        for row in range(3):
            y0 = 76 + row * 70
            d.rectangle((cx, y0, cx + 60, y0 + 46), fill=(232, 222, 196, 235), outline=INK)
            d.line((cx + 4, y0 + 6, cx + 56, y0 + 6), fill=tint)
            d.rectangle((cx + 4, y0 + 10, cx + 26, y0 + 12), fill=(150, 140, 120, 255))
            d.ellipse((cx + 27, y0 + 2, cx + 31, y0 + 6), fill=RED, outline=INK)
    # connection threads between cards in each column
    for cx, tint in cols:
        d.line((cx + 30, 122, cx + 30, 190), fill=tint)
        d.line((cx + 30, 192, cx + 30, 250), fill=tint)
    # desk strip
    d.rectangle((0, 300, w, h), fill=(52, 36, 24, 255))
    d.line((0, 300, w, 300), fill=GOLD)
    return im.resize((1280, 720), Image.NEAREST)


def computer_frame() -> Image.Image:
    """96x96 9-patch: dark bezel, uniform centre so text stays readable."""
    im = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 95, 95), fill=(5, 10, 13, 255))
    d.rectangle((1, 1, 94, 94), fill=(78, 58, 30, 255))
    d.rectangle((2, 2, 93, 93), fill=(160, 120, 56, 255))
    d.rectangle((3, 3, 92, 92), fill=(40, 30, 22, 255))
    d.rectangle((5, 5, 90, 90), fill=(9, 17, 19, 255))
    d.rectangle((8, 8, 87, 87), outline=(57, 89, 84, 255), fill=(8, 21, 23, 255))
    return im


def hall_case(master: Image.Image, accent) -> Image.Image:
    """32x48 display case with the exhibit inside, matching bm_case_noir."""
    im = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((2, 4, 29, 40), fill=(25, 49, 56, 210), outline=(139, 181, 182, 255))
    d.line((4, 6, 4, 38), fill=(188, 219, 213, 180))
    d.rectangle((1, 1, 30, 4), fill=GOLD)
    d.rectangle((1, 41, 30, 47), fill=(93, 66, 34, 255))
    d.line((2, 41, 29, 41), fill=GOLD_H)
    exhibit = master.resize((20, 20), Image.NEAREST)
    im.alpha_composite(exhibit, (6, 12))
    d.rectangle((6, 33, 25, 34), fill=accent)
    return im


def hall_plaque(accent) -> Image.Image:
    """32x16 wall plaque (no text: the game draws the hall name)."""
    im = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 31, 15), fill=(30, 24, 18, 255), outline=(168, 130, 62, 255))
    d.rectangle((2, 3, 29, 12), fill=(233, 223, 199, 255))
    d.rectangle((4, 5, 27, 6), fill=accent)
    d.rectangle((4, 9, 18, 10), fill=(120, 110, 90, 255))
    return im


def monitor_cam() -> Image.Image:
    """16x16 security camera head (P1-B surveillance marker)."""
    im = new(16)
    d = ImageDraw.Draw(im)
    d.rectangle((4, 2, 11, 7), fill=(30, 36, 44, 255), outline=INK)
    d.rectangle((6, 4, 9, 5), fill=(10, 14, 18, 255))
    d.point((9, 4), fill=(226, 74, 58, 255))
    d.rectangle((9, 7, 12, 9), fill=(40, 48, 58, 255), outline=INK)
    d.rectangle((5, 9, 9, 13), fill=(70, 80, 92, 255), outline=INK)
    d.point((7, 14), fill=(120, 180, 190, 255))
    return im


def path_node() -> Image.Image:
    """16x16 route waypoint marker: diamond with a gold core."""
    im = new(16)
    d = ImageDraw.Draw(im)
    d.polygon(((8, 1), (15, 8), (8, 15), (1, 8)), fill=(127, 224, 208, 110), outline=(127, 224, 208, 255))
    d.polygon(((8, 4), (12, 8), (8, 12), (4, 8)), fill=GOLD, outline=INK)
    d.point((8, 8), fill=GOLD_H)
    return im


def main() -> None:
    SPRITES.mkdir(parents=True, exist_ok=True)
    ART.mkdir(parents=True, exist_ok=True)
    stela_master = draw_stela(5)
    relief_master = draw_relief(5)
    outputs = {
        SPRITES / "artifact_egypt_stela.png": icon16("stela"),
        SPRITES / "artifact_greek_relief.png": icon16("relief"),
        SPRITES / "relic_egypt_stela_ui_strip.png": ui_strip(stela_master),
        SPRITES / "relic_greek_relief_ui_strip.png": ui_strip(relief_master),
        SPRITES / "egypt_stela_closeup.png": stela_master,
        SPRITES / "greek_relief_closeup.png": relief_master,
        ART / "safehouse_clue_board.png": clue_board(),
        ART / "safehouse_computer_frame_9p.png": computer_frame(),
        SPRITES / "bm" / "egypt_stela_case.png": hall_case(stela_master, (216, 168, 78, 255)),
        SPRITES / "bm" / "greek_relief_case.png": hall_case(relief_master, (196, 186, 164, 255)),
        SPRITES / "bm" / "egypt_hall_plaque.png": hall_plaque((216, 168, 78, 255)),
        SPRITES / "bm" / "greek_hall_plaque.png": hall_plaque((196, 186, 164, 255)),
        SPRITES / "monitor_cam_16.png": monitor_cam(),
        SPRITES / "path_node_16.png": path_node(),
    }
    for path, img in outputs.items():
        img.save(path)
        print("wrote", path.relative_to(ROOT), img.size)


if __name__ == "__main__":
    main()
