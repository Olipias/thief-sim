#!/usr/bin/env python3
"""16x16 UI icon set for the route-planning HUD and safehouse devices.

Outputs under assets/sprites/ui/:
  plan_*.png  route-planning overlay markers (no clock / countdown imagery)
  phone_app_*.png  phone home-screen apps (task / calendar / contacts / chat)
  pc_app_*.png     safehouse computer apps (archive / browser / mail / chat)

Run:  python3 tools/gen_ui_icons.py
Do not hand-edit the PNGs; change this script and re-run.
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "ui"

INK = (10, 14, 18, 255)
PAPER = (233, 223, 199, 255)
PAPER_D = (176, 160, 128, 255)
GOLD = (216, 168, 78, 255)
GOLD_H = (244, 212, 138, 255)
TEAL = (127, 224, 208, 255)
TEAL_D = (57, 110, 106, 255)
RED = (226, 74, 58, 255)
RED_D = (150, 40, 34, 255)
SCREEN = (12, 24, 28, 255)
STEEL = (120, 132, 142, 255)


def new() -> Image.Image:
    return Image.new("RGBA", (16, 16), (0, 0, 0, 0))


def plan_eta() -> Image.Image:
    """Guard route: footprints and a dotted path (not a clock)."""
    im = new()
    d = ImageDraw.Draw(im)
    for (x, y) in ((3, 12), (6, 9), (9, 6), (12, 3)):
        d.rectangle((x, y, x + 1, y + 1), fill=TEAL)
    d.point((12, 2), fill=RED)
    d.line((4, 13, 5, 13), fill=TEAL_D)
    return im


def plan_camera_cover() -> Image.Image:
    """Camera coverage: small camera head with a cone."""
    im = new()
    d = ImageDraw.Draw(im)
    d.polygon(((7, 8), (15, 2), (15, 14)), fill=(127, 224, 208, 90))
    d.rectangle((1, 6, 5, 10), fill=STEEL, outline=INK)
    d.point((4, 8), fill=RED)
    return im


def plan_door_locked() -> Image.Image:
    im = new()
    d = ImageDraw.Draw(im)
    d.rectangle((4, 7, 11, 14), fill=GOLD, outline=INK)
    d.arc((5, 2, 10, 9), 180, 360, fill=STEEL, width=1)
    d.point((7, 10), fill=INK)
    return im


def plan_door_open() -> Image.Image:
    im = new()
    d = ImageDraw.Draw(im)
    d.rectangle((3, 2, 12, 14), outline=GOLD)
    d.polygon(((3, 2), (8, 4), (8, 12), (3, 14)), fill=TEAL_D, outline=GOLD)
    d.point((7, 8), fill=GOLD_H)
    return im


def plan_noise() -> Image.Image:
    """Noise ring: concentric arcs."""
    im = new()
    d = ImageDraw.Draw(im)
    d.ellipse((6, 6, 9, 9), fill=RED)
    d.arc((3, 3, 12, 12), 200, 340, fill=RED)
    d.arc((1, 1, 14, 14), 200, 340, fill=RED_D)
    return im


def plan_fail_reason() -> Image.Image:
    """Failure highlight: red reticle used on the replay frame."""
    im = new()
    d = ImageDraw.Draw(im)
    d.ellipse((2, 2, 13, 13), outline=RED, width=1)
    d.line((8, 0, 8, 3), fill=RED)
    d.line((8, 12, 8, 15), fill=RED)
    d.line((0, 8, 3, 8), fill=RED)
    d.line((12, 8, 15, 8), fill=RED)
    d.point((8, 8), fill=RED)
    return im


def phone_app_task() -> Image.Image:
    im = new()
    d = ImageDraw.Draw(im)
    d.rectangle((3, 2, 12, 13), fill=PAPER, outline=INK)
    d.line((5, 5, 10, 5), fill=GOLD)
    d.line((5, 8, 10, 8), fill=PAPER_D)
    d.line((5, 10, 8, 10), fill=PAPER_D)
    return im


def phone_app_calendar() -> Image.Image:
    im = new()
    d = ImageDraw.Draw(im)
    d.rectangle((2, 3, 13, 13), fill=PAPER, outline=INK)
    d.rectangle((2, 3, 13, 5), fill=RED)
    for x in (4, 7, 10):
        d.point((x, 8), fill=INK)
    d.point((7, 11), fill=RED)
    return im


def phone_app_contacts() -> Image.Image:
    im = new()
    d = ImageDraw.Draw(im)
    d.ellipse((5, 2, 10, 7), fill=PAPER, outline=INK)
    d.rectangle((3, 8, 12, 13), fill=PAPER, outline=INK)
    d.point((7, 4), fill=INK)
    return im


def phone_app_chat() -> Image.Image:
    im = new()
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((2, 3, 13, 10), radius=2, fill=PAPER, outline=INK)
    d.polygon(((5, 10), (5, 13), (8, 10)), fill=PAPER, outline=INK)
    d.line((4, 6, 11, 6), fill=TEAL_D)
    return im


def pc_app_archive() -> Image.Image:
    im = new()
    d = ImageDraw.Draw(im)
    for i, x in enumerate((2, 6, 10)):
        d.rectangle((x, 3 + i % 2, x + 3, 13), fill=GOLD if i else PAPER, outline=INK)
    return im


def pc_app_browser() -> Image.Image:
    im = new()
    d = ImageDraw.Draw(im)
    d.ellipse((2, 2, 13, 13), outline=TEAL, fill=SCREEN)
    d.arc((4, 2, 11, 13), 90, 270, fill=TEAL)
    d.line((2, 8, 13, 8), fill=TEAL)
    return im


def pc_app_mail() -> Image.Image:
    im = new()
    d = ImageDraw.Draw(im)
    d.rectangle((2, 4, 13, 12), fill=PAPER, outline=INK)
    d.line((2, 4, 8, 9), fill=INK)
    d.line((13, 4, 8, 9), fill=INK)
    return im


def pc_app_chat() -> Image.Image:
    im = new()
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((2, 2, 9, 8), radius=2, fill=TEAL_D, outline=INK)
    d.rounded_rectangle((6, 7, 13, 13), radius=2, fill=PAPER, outline=INK)
    return im


ICONS = {
    "plan_eta.png": plan_eta,
    "plan_camera_cover.png": plan_camera_cover,
    "plan_door_locked.png": plan_door_locked,
    "plan_door_open.png": plan_door_open,
    "plan_noise.png": plan_noise,
    "plan_fail_reason.png": plan_fail_reason,
    "phone_app_task.png": phone_app_task,
    "phone_app_calendar.png": phone_app_calendar,
    "phone_app_contacts.png": phone_app_contacts,
    "phone_app_chat.png": phone_app_chat,
    "pc_app_archive.png": pc_app_archive,
    "pc_app_browser.png": pc_app_browser,
    "pc_app_mail.png": pc_app_mail,
    "pc_app_chat.png": pc_app_chat,
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in ICONS.items():
        fn().save(OUT / name)
        print("wrote", (OUT / name).relative_to(ROOT))


if __name__ == "__main__":
    main()
