#!/usr/bin/env python3
"""Art for the safehouse interactables and exploration fog (A-01).

Outputs:
  assets/sprites/safehouse/desk_computer_32x24.png  real desk with computer (E to use)
  assets/sprites/safehouse/storage_box_24x20.png    item storage box
  assets/sprites/safehouse/exit_door_24x40.png      door to leave on foot
  assets/sprites/explore/fog_room_16.png            uniform fog over unvisited area
  assets/sprites/explore/door_unknown_16.png        unexplored door: no destination shown

Rules: no text, no numbers, no ghost/spirit imagery. The fog tile is uniform
and the unknown-door marker has no target hint, so neither leaks the layout.

Run:  python3 tools/gen_explore_art.py
Do not hand-edit the PNGs; change this script and re-run.
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites"

INK = (10, 14, 18, 255)
WOOD = (93, 66, 34, 255)
WOOD_L = (136, 98, 52, 255)
WOOD_D = (58, 40, 22, 255)
PAPER = (233, 223, 199, 255)
PAPER_D = (176, 160, 128, 255)
GOLD = (216, 168, 78, 255)
GOLD_H = (244, 212, 138, 255)
TEAL = (127, 224, 208, 255)
TEAL_D = (57, 110, 106, 255)
SCREEN = (12, 24, 28, 255)
STEEL = (120, 132, 142, 255)
STEEL_D = (70, 80, 92, 255)
DOOR = (74, 52, 30, 255)
DOOR_L = (110, 80, 46, 255)
FOG = (18, 26, 30, 205)


def desk_computer() -> Image.Image:
    im = Image.new("RGBA", (32, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((1, 13, 30, 22), fill=WOOD, outline=INK)
    d.line((2, 14, 29, 14), fill=WOOD_L)
    d.rectangle((3, 20, 5, 23), fill=WOOD_D)
    d.rectangle((26, 20, 28, 23), fill=WOOD_D)
    d.rectangle((9, 2, 22, 11), fill=STEEL_D, outline=INK)
    d.rectangle((10, 3, 21, 10), fill=SCREEN)
    d.line((11, 5, 19, 5), fill=TEAL)
    d.line((11, 7, 17, 7), fill=TEAL_D)
    d.rectangle((14, 12, 17, 12), fill=STEEL_D)
    d.rectangle((6, 11, 25, 13), fill=STEEL, outline=INK)
    d.rectangle((22, 15, 27, 17), fill=PAPER, outline=INK)
    d.line((23, 16, 26, 16), fill=PAPER_D)
    return im


def storage_box() -> Image.Image:
    im = Image.new("RGBA", (24, 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((1, 5, 22, 18), fill=WOOD, outline=INK)
    d.rectangle((1, 2, 22, 6), fill=WOOD_L, outline=INK)
    d.line((2, 9, 21, 9), fill=WOOD_D)
    d.line((2, 14, 21, 14), fill=WOOD_D)
    d.rectangle((9, 8, 14, 11), fill=GOLD, outline=INK)
    d.point((11, 10), fill=INK)
    d.line((3, 4, 20, 4), fill=GOLD)
    return im


def exit_door() -> Image.Image:
    im = Image.new("RGBA", (24, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((1, 1, 22, 39), fill=DOOR, outline=INK)
    d.rectangle((4, 4, 19, 18), outline=DOOR_L)
    d.rectangle((4, 22, 19, 36), outline=DOOR_L)
    d.rectangle((0, 0, 23, 2), fill=WOOD_D, outline=INK)
    d.rectangle((17, 19, 19, 22), fill=GOLD, outline=INK)
    d.point((18, 20), fill=GOLD_H)
    return im


def fog_room() -> Image.Image:
    im = Image.new("RGBA", (16, 16), FOG)
    d = ImageDraw.Draw(im)
    for y in range(0, 16, 4):
        for x in range((y // 4) % 2 * 2, 16, 4):
            d.point((x, y), fill=(40, 56, 60, 255))
    return im


def door_unknown() -> Image.Image:
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((4, 2, 11, 14), fill=DOOR, outline=INK)
    d.point((9, 8), fill=GOLD)
    d.line((5, 3, 10, 3), fill=DOOR_L)
    return im


ICONS = {
    "safehouse/desk_computer_32x24.png": desk_computer,
    "safehouse/storage_box_24x20.png": storage_box,
    "safehouse/exit_door_24x40.png": exit_door,
    "explore/fog_room_16.png": fog_room,
    "explore/door_unknown_16.png": door_unknown,
}


def main() -> None:
    for rel, fn in ICONS.items():
        path = OUT / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        fn().save(path)
        print("wrote", path.relative_to(ROOT), fn().size)


if __name__ == "__main__":
    main()
