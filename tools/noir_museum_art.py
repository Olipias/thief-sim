"""Pixel-art museum atlas and decorations, preserving the existing layout."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets/sprites/bm'
INK = (10, 19, 25, 255)
GOLD = (196, 151, 73, 255)
GLINT = (235, 200, 127, 255)
TEAL = (37, 73, 78, 255)


def tiles(atlas):
    """Redraw the six galleries' floor and wall variants in place."""
    floors = {
        28: ((75, 91, 99), 'stone'), 29: ((81, 97, 104), 'stone'),
        30: ((72, 56, 46), 'wood'), 31: ((77, 60, 48), 'wood'),
        32: ((109, 84, 65), 'sand'), 33: ((116, 91, 70), 'sand'),
        34: ((65, 73, 78), 'stone'), 35: ((72, 79, 83), 'stone'),
    }
    walls = {
        36: (48, 69, 81), 37: (54, 74, 86),
        38: (26, 58, 75), 39: (32, 65, 81),
        40: (74, 56, 49), 41: (82, 60, 50),
        42: (99, 62, 47), 43: (107, 68, 50),
        44: (57, 67, 72), 45: (64, 72, 76),
    }
    for idx, (base, kind) in floors.items():
        im = Image.new('RGBA', (16, 16), (*base, 255)); d = ImageDraw.Draw(im)
        dark = tuple(max(0, c - 9) for c in base) + (255,)
        light = tuple(min(255, c + 8) for c in base) + (255,)
        if kind == 'wood':
            d.line((0, 7, 15, 7), fill=dark); d.line((0, 15, 15, 15), fill=dark)
            d.line((5 if idx % 2 else 10, 0, 5 if idx % 2 else 10, 6), fill=dark)
            d.line((2, 3, 7, 3), fill=light)
        else:
            d.line((0, 15, 15, 15), fill=dark); d.line((15, 0, 15, 15), fill=dark)
            d.point((3 + idx % 5, 3), fill=light); d.point((10, 10 + idx % 3), fill=dark)
            if kind == 'stone': d.line((4, 11, 7, 8), fill=light)
        atlas.paste(im, ((idx % 8) * 16, (idx // 8) * 16))
    for idx, base in walls.items():
        im = Image.new('RGBA', (16, 16), (*base, 255)); d = ImageDraw.Draw(im)
        light = tuple(min(255, c + 15) for c in base) + (255,)
        dark = tuple(max(0, c - 16) for c in base) + (255,)
        d.rectangle((0, 0, 15, 15), outline=dark)
        d.rectangle((3, 2, 12, 13), outline=light)
        d.line((4, 12, 11, 12), fill=dark)
        if idx in (44, 45):
            for xy in ((2, 2), (13, 2), (2, 13), (13, 13)): d.point(xy, fill=light)
        atlas.paste(im, ((idx % 8) * 16, (idx // 8) * 16))
    # Red carpet: subdued pattern, gold only at the edge.
    for idx in (11, 12):
        im = Image.new('RGBA', (16, 16), (91, 31, 39, 255)); d = ImageDraw.Draw(im)
        if idx == 11:
            d.polygon(((8, 4), (12, 8), (8, 12), (4, 8)), outline=(139, 67, 65, 255))
            d.point((8, 8), fill=(183, 139, 80, 255))
        else:
            d.line((1, 0, 1, 15), fill=GOLD); d.line((14, 0, 14, 15), fill=GOLD)
        atlas.paste(im, ((idx % 8) * 16, (idx // 8) * 16))
    return atlas


def display_case():
    im = Image.new('RGBA', (32, 48)); d = ImageDraw.Draw(im)
    d.rectangle((2, 4, 29, 40), fill=(48, 87, 94, 28), outline=(173, 215, 211, 170))
    d.line((4, 7, 4, 33), fill=(215, 236, 229, 190))
    d.line((6, 8, 11, 3), fill=(220, 241, 231, 120))
    d.rectangle((1, 1, 30, 5), fill=(88, 62, 29, 255), outline=INK)
    d.line((2, 2, 29, 2), fill=GLINT)
    d.rectangle((1, 39, 30, 46), fill=(64, 48, 30, 255), outline=INK)
    d.line((2, 40, 29, 40), fill=GOLD); d.line((3, 44, 28, 44), fill=(126, 94, 48, 255))
    return im


def framed_case(kind):
    im = Image.new('RGBA', (32, 32)); d = ImageDraw.Draw(im)
    d.rectangle((2, 3, 29, 27), fill=(25, 49, 56, 210), outline=(139, 181, 182, 255))
    d.line((4, 5, 8, 5), fill=(208, 230, 220, 255)); d.line((4, 6, 4, 15), fill=(188, 219, 213, 180))
    d.rectangle((1, 1, 30, 3), fill=GOLD); d.rectangle((1, 28, 30, 31), fill=(93, 66, 34, 255))
    d.line((2, 28, 29, 28), fill=GLINT)
    if kind == 'vase_case':
        d.polygon(((13, 7), (19, 7), (19, 10), (22, 13), (21, 22), (19, 24), (13, 24), (10, 22), (10, 13), (13, 10)), fill=(204, 224, 222, 255))
        d.line((12, 16, 20, 16), fill=(65, 113, 154, 255)); d.line((12, 19, 20, 19), fill=(65, 113, 154, 255))
    elif kind == 'jade_case':
        d.ellipse((9, 8, 23, 22), fill=(131, 189, 163, 255), outline=(195, 224, 190, 255)); d.ellipse((14, 13, 18, 17), fill=(43, 79, 72, 255))
    else:
        d.rectangle((8, 9, 24, 22), fill=(224, 211, 176, 255), outline=(153, 118, 72, 255))
        d.line((10, 20, 14, 15, 17, 17, 22, 11), fill=(60, 87, 77, 255))
    return im


def decor():
    dest = OUT / 'decor_noir'; dest.mkdir(parents=True, exist_ok=True)
    # Redraw exhibit cases and the centerpiece glass independently.
    for name in ('vase_case', 'jade_case', 'scroll_case'):
        framed_case(name).save(dest / (name + '.png'))
    # Preserve dimensions and transparent footprints of existing props; enrich
    # their edges and material highlights without changing collision geometry.
    for source in (OUT / 'decor').glob('*.png'):
        if source.stem in ('vase_case', 'jade_case', 'scroll_case'):
            continue
        im = Image.open(source).convert('RGBA'); px = im.load(); w, h = im.size
        original = im.copy(); op = original.load()
        for y in range(h):
            for x in range(w):
                r, g, b, a = op[x, y]
                if not a: continue
                # Cool the shadows, retain warm identifying colors and alpha.
                if max(r, g, b) < 115:
                    px[x, y] = (max(0, int(r * .91)), max(0, int(g * .96)), min(255, int(b * 1.07)), a)
                if y > 0 and op[x, y - 1][3] == 0 and a >= 180:
                    px[x, y] = (min(255, r + 15), min(255, g + 13), min(255, b + 9), a)
        im.save(dest / source.name)
    display_case().save(OUT / 'bm_case_noir.png')
