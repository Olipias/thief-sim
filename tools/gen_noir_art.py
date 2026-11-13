#!/usr/bin/env python3
"""Rebuild reference-led police, safehouse and phone assets."""
from pathlib import Path
from PIL import Image, ImageDraw
import noir_museum_art

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'docs/art_direction/a00_src'


def police():
    source = Image.open(SRC / 'police_noir_generated.png').convert('RGBA')
    sheet = Image.new('RGBA', (96, 96))
    xs, ys = (110, 420, 720, 1030, 1340), (0, 360, 720, 1086)
    for row in range(3):
        for col in range(4):
            cell = source.crop((xs[col], ys[row], xs[col + 1], ys[row + 1]))
            alpha = cell.getchannel('A').point(lambda a: 255 if a >= 128 else 0)
            cell.putalpha(alpha)
            bounds = alpha.getbbox()
            if not bounds:
                raise ValueError(f'empty police frame {row}, {col}')
            cell = cell.crop(bounds)
            cell = cell.resize((max(1, round(cell.width * 29 / 320)),
                                max(1, round(cell.height * 29 / 320))), Image.Resampling.NEAREST)
            pixels = cell.load()
            for y in range(cell.height):
                for x in range(cell.width):
                    r, g, b, a = pixels[x, y]
                    if a and b > r and 12 < b < 80:
                        pixels[x, y] = (min(255, r + 5), min(255, g + 9), min(255, b + 14), a)
            if cell.width > 24 or cell.height > 32:
                raise ValueError(f'police frame exceeds grid {row}, {col}')
            sheet.alpha_composite(cell, (col * 24 + (24 - cell.width) // 2,
                                         row * 32 + 31 - cell.height))
    sheet.save(ROOT / 'assets/sprites/chars/police_noir.png')
    sheet.resize((768, 768), Image.Resampling.NEAREST).save(SRC / 'police_noir_preview.png')


def safehouse():
    source = Image.open(SRC / 'safehouse_noir_generated.png').convert('RGB')
    # Keep a 16:9 viewport; use nearest-neighbour on the final upscale.
    w, h = source.size
    cropped = source.crop((0, (h - round(w * 9 / 16)) // 2, w,
                           (h - round(w * 9 / 16)) // 2 + round(w * 9 / 16)))
    image = cropped.resize((640, 360), Image.Resampling.LANCZOS)
    image.resize((1280, 720), Image.Resampling.NEAREST).save(ROOT / 'assets/art/safehouse_noir.png')


def phone():
    image = Image.new('RGBA', (96, 96), (8, 18, 20, 255))
    d = ImageDraw.Draw(image)
    d.rectangle((0, 0, 95, 95), fill=(5, 10, 13, 255))
    d.rectangle((1, 1, 94, 94), fill=(90, 65, 33, 255))
    d.rectangle((2, 2, 93, 93), fill=(181, 135, 62, 255))
    d.rectangle((3, 3, 92, 92), fill=(48, 38, 26, 255))
    d.rectangle((5, 5, 90, 90), fill=(9, 17, 19, 255))
    d.rectangle((8, 8, 87, 87), outline=(57, 89, 84, 255), fill=(8, 21, 23, 255))
    # The stretchable centre is uniform to avoid broken scan lines in 9-patch.
    image.save(ROOT / 'assets/art/phone_noir_9p.png')


def museum_tiles():
    # Preserve all atlas indices and non-bronze-room themes; redraw the dark
    # stone floors and teal wall panels to match the approved A direction.
    atlas = Image.open(ROOT / 'assets/sprites/bm/bm_tiles.png').convert('RGBA')
    for i in range(4):
        im = Image.new('RGBA', (16, 16), (35 + i * 2, 49 + i * 2, 60 + i * 2, 255))
        d = ImageDraw.Draw(im)
        d.line((0, 15, 15, 15), fill=(26, 37, 45, 255))
        d.line((15, 0, 15, 15), fill=(26, 37, 45, 255))
        d.point((3 + i * 2, 4 + i), fill=(45, 60, 69, 255))
        atlas.paste(im, (i * 16, 0))
    for i in range(5, 8):
        im = Image.new('RGBA', (16, 16), (17, 37 + (i - 5) * 3, 43 + (i - 5) * 3, 255))
        d = ImageDraw.Draw(im)
        d.rectangle((0, 0, 15, 15), outline=(8, 21, 26, 255))
        d.rectangle((3, 2, 12, 13), outline=(43, 72, 75, 255))
        d.line((4, 12, 11, 12), fill=(12, 28, 33, 255))
        atlas.paste(im, (i * 16, 0))
    noir_museum_art.tiles(atlas).save(ROOT / 'assets/sprites/bm/bm_tiles_noir.png')


if __name__ == '__main__':
    police()
    safehouse()
    phone()
    museum_tiles()
    noir_museum_art.decor()
