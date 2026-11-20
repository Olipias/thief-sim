#!/usr/bin/env python3
"""P0 museum wall/floor/decor art via ofox image API (see docs/art_direction/EXTERNAL_ART_REQUEST_P0.md).

Modes:
  python3 tools/gen_external_p0.py gen      # call ofox, save raw grids to docs/art_direction/external_raw/
  python3 tools/gen_external_p0.py process  # slice raw grids -> assets/sprites/bm/*.png
  python3 tools/gen_external_p0.py all

The API key is read from ~/.config/opencode/secrets/ofox_api_key.txt (never printed or committed).
Raw images are kept; processed PNGs are generated and must not be hand-edited.
"""
import base64
import json
import sys
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "docs" / "art_direction" / "external_raw"
OUT = ROOT / "assets" / "sprites" / "bm"
KEY_FILE = Path.home() / ".config" / "opencode" / "secrets" / "ofox_api_key.txt"
ENDPOINT = "https://api.ofox.ai/v1/images/generations"
MODEL = "openai/gpt-image-2"
MAGENTA = (255, 0, 255)

PALETTE = [
    (35, 49, 60), (37, 51, 62), (41, 55, 66), (226, 186, 92), (168, 130, 62),
    (91, 31, 39), (226, 214, 190), (78, 52, 32), (46, 30, 20), (116, 168, 178),
    (16, 16, 16), (90, 98, 106), (140, 140, 132), (60, 44, 34), (120, 40, 48),
    (200, 200, 190),
]

NEG = (
    "no text, no letters, no numbers, no characters, no people, no ghosts, no spirits, "
    "no glowing figures, no trees, no signs, no bicycles, no photo, no 3D render, no blur"
)

BASE = (
    "pixel art, dark museum interior palette, deep navy walls #293742, gold trim #e2ba5c, "
    "dark outline, flat orthographic front view, no perspective, crisp pixels. "
)

HOME_PALETTE = [
    (24, 58, 62), (31, 74, 78), (18, 42, 46), (58, 36, 22), (92, 58, 34), (46, 28, 18),
    (226, 186, 92), (168, 130, 62), (196, 52, 46), (120, 30, 30), (16, 16, 16), (90, 98, 106),
    (200, 190, 170), (240, 210, 140),
]

JOBS = {
    "home_tiles": {
        "size": "1024x1024",
        "prompt": BASE + "A 4 by 4 grid of square tiles separated by thin magenta #FF00FF gutters, "
        "warm-dark home interior: row 1 dark wooden floor planks, row 2 dark slate floor tiles with wet sheen, "
        "row 3 teal wood-panel wall tiles, row 4 brass-trim wainscot base tiles. Each cell one seamless tile. " + NEG,
    },
    "home_props": {
        "size": "1024x1024",
        "prompt": BASE + "A 2 by 2 grid of four isolated props on solid magenta #FF00FF background, each centred: "
        "tall wooden bookshelf with small clay jars and boxes, wicker laundry basket with cloth, "
        "small red paper lantern hanging with tassel, low wooden cabinet with brass handles. "
        "Warm light from upper left. " + NEG,
    },
    "home_cabinet2": {
        "size": "1024x1024",
        "prompt": BASE + "A 2 by 2 grid of four isolated low wooden sideboard cabinets on solid magenta #FF00FF "
        "background, each centred, wide and short (landscape proportion, about 3 to 2 width to height), "
        "dark stained wood, two brass handles, two doors, slight wear, warm light from upper left, "
        "no contents, no props. " + NEG,
    },
    "case_glass": {
        "size": "1024x1024",
        "prompt": BASE + "A 2 by 2 grid of four isolated glass reflection highlight overlays on solid magenta "
        "#FF00FF background, each a few thin diagonal cool cyan light streaks on glass, no frame, no outline, "
        "no solid fill, edges fade out. " + NEG,
    },
    "wall_grid": {
        "size": "1024x1024",
        "prompt": BASE + "A 4 by 4 grid of square tiles separated by thin magenta #FF00FF gutters, "
        "each cell one seamless 16x16-style wall or trim tile, shown large. Row 1: wainscot top edge, "
        "skirting board, door frame side, wall corner. Row 2: same kinds with light wear. "
        "Row 3: same kinds with scratches. Row 4: same kinds with grime and water stain. " + NEG,
    },
    "floor_grid": {
        "size": "1024x1024",
        "prompt": BASE + "A 4 by 4 grid of square floor tiles separated by thin magenta #FF00FF gutters, "
        "grey-navy stone floor, seams, subtle water stains, small cracks, scuffs. Each cell is one "
        "seamless tile. " + NEG,
    },
    "floor_decals": {
        "size": "1024x1024",
        "prompt": BASE + "A 4 by 4 grid of isolated floor wear overlays on solid magenta #FF00FF background, "
        "each cell one small decal: hairline crack, water stain patch, scuff mark, grime patch, "
        "dark seam line, scratch cluster. Decals are semi-transparent-looking dark marks only, "
        "NO square tile frame, NO border, NO brown outline, NO base floor fill, edges fade out. " + NEG,
    },
    "decor_china": {
        "size": "1024x1024",
        "prompt": BASE + "A 2 by 2 grid of four isolated museum props on solid magenta #FF00FF background, "
        "each prop centred in its cell: bronze ritual vessel pedestal, red lacquer screen corner, wooden crate "
        "corner, lamp base. Warm gold highlights from upper left. " + NEG,
    },
    "decor_egypt": {
        "size": "1024x1024",
        "prompt": BASE + "A 2 by 2 grid of four isolated museum props on solid magenta #FF00FF background, "
        "each centred: sandstone stele base, clay jar on plinth, rolled reed mat, small lamp base. "
        "Warm gold highlights from upper left. " + NEG,
    },
    "decor_greek": {
        "size": "1024x1024",
        "prompt": BASE + "A 2 by 2 grid of four isolated museum props on solid magenta #FF00FF background, "
        "each centred: white marble column base, broken column capital, stone plinth, draped cloth corner. "
        "Warm light from upper left. " + NEG,
    },
    "decor_silk": {
        "size": "1024x1024",
        "prompt": BASE + "A 2 by 2 grid of four isolated museum props on solid magenta #FF00FF background, "
        "each centred: textile display stand, stacked pottery, wooden camel-saddle crate, small rug. "
        "Warm light from upper left. " + NEG,
    },
    "decor_jade": {
        "size": "1024x1024",
        "prompt": BASE + "A 2 by 2 grid of four isolated museum props on solid magenta #FF00FF background, "
        "each centred: dark wood pedestal with velvet pad, lamp shade base, small folding screen, "
        "display plinth. Cool teal glass highlight. " + NEG,
    },
    "decor_dock": {
        "size": "1024x1024",
        "prompt": BASE + "A 2 by 2 grid of four isolated props on solid magenta #FF00FF background, "
        "each centred: wooden pallet, stacked wooden crates, metal corner guards, hand truck corner. "
        "Warm light from upper left. " + NEG,
    },
}


def api_key() -> str:
    return KEY_FILE.read_text(encoding="utf-8").strip()


def gen_one(name: str, job: dict) -> Path:
    body = json.dumps({"model": MODEL, "prompt": job["prompt"], "size": job["size"], "n": 1}).encode()
    req = urllib.request.Request(
        ENDPOINT, data=body, method="POST",
        headers={"Authorization": "Bearer " + api_key(), "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=600) as resp:
        data = json.loads(resp.read())
    b64 = data["data"][0].get("b64_json")
    if not b64:
        raise RuntimeError(f"{name}: no b64_json in response")
    RAW.mkdir(parents=True, exist_ok=True)
    path = RAW / f"{name}.png"
    path.write_bytes(base64.b64decode(b64))
    (RAW / f"{name}.prompt.txt").write_text(job["prompt"] + "\n", encoding="utf-8")
    print("saved", path.relative_to(ROOT), flush=True)
    return path


def cut_cells(src: Image.Image, cols: int, rows: int) -> list:
    cw, ch = src.width // cols, src.height // rows
    return [src.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)) for r in range(rows) for c in range(cols)]


def key_magenta(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if abs(r - 255) < 60 and g < 80 and abs(b - 255) < 60:
                px[x, y] = (0, 0, 0, 0)
    return im


def decal_alpha(im: Image.Image, color: tuple = (10, 14, 18), gain: float = 1.2) -> Image.Image:
    """Marks on magenta: alpha from distance to magenta, colour fixed."""
    im = im.convert("RGB")
    out = Image.new("RGBA", im.size, color + (0,))
    src, dst = im.load(), out.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b = src[x, y]
            dist = ((255 - r) ** 2 + g ** 2 + (255 - b) ** 2) ** 0.5
            a = min(255, int(dist * gain))
            if a > 12:
                dst[x, y] = color + (a,)
    return out


def shrink_decal(im: Image.Image, size: int) -> Image.Image:
    return decal_alpha(im.resize((size * 4, size * 4), Image.LANCZOS)).resize((size, size), Image.BOX)


def shrink(im: Image.Image, size: int, palette: list | None = None, box: tuple | None = None) -> Image.Image:
    w, h = box or (size, size)
    im = im.resize((w, h), Image.LANCZOS)
    rgb = im.convert("RGB")
    alpha = im.getchannel("A")
    q = rgb.quantize(palette=_pal_image(palette or PALETTE)).convert("RGB")
    q.putalpha(alpha.point(lambda a: 255 if a > 127 else 0))
    return q


def _pal_image(colors: list | None = None) -> Image.Image:
    p = Image.new("P", (1, 1))
    flat = []
    for c in (colors or PALETTE):
        flat += list(c)
    flat += [0] * (768 - len(flat))
    p.putpalette(flat)
    return p


def process_grid(raw: Path, cols: int, rows: int, size: int, out_name: str, pick: list | None = None,
                 out_cols: int = 4, out_rows: int | None = None, decal: bool = False) -> None:
    src = Image.open(raw).convert("RGB")
    cells = cut_cells(src, cols, rows)
    chosen = [cells[i] for i in pick] if pick else cells
    small = [shrink_decal(c, size) if decal else shrink(key_magenta(c), size) for c in chosen]
    n = len(small)
    o_rows = out_rows or (n + out_cols - 1) // out_cols
    sheet = Image.new("RGBA", (out_cols * size, o_rows * size), (0, 0, 0, 0))
    for i, im in enumerate(small):
        sheet.paste(im, ((i % out_cols) * size, (i // out_cols) * size))
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / out_name
    sheet.save(path)
    print("wrote", path.relative_to(ROOT), sheet.size, flush=True)


def process_decor(raw: Path, out_name: str) -> None:
    src = key_magenta(Image.open(raw))
    cells = cut_cells(src, 2, 2)
    small = [shrink(c, 32) for c in cells]
    sheet = Image.new("RGBA", (128, 32), (0, 0, 0, 0))
    for i, im in enumerate(small):
        sheet.paste(im, (i * 32, 0))
    path = OUT / out_name
    sheet.save(path)
    print("wrote", path.relative_to(ROOT), sheet.size, flush=True)


WOOD_PALETTE = [
    (16, 10, 6), (30, 20, 12), (46, 30, 18), (62, 42, 26), (80, 54, 32), (100, 70, 40),
    (130, 92, 52), (168, 130, 62), (226, 186, 92), (24, 58, 62), (40, 40, 40), (200, 190, 170),
]


def shrink_wood(im: Image.Image, box: tuple) -> Image.Image:
    alpha = im.resize(box, Image.LANCZOS).getchannel("A")
    rgb = im.convert("RGB").resize(box, Image.LANCZOS)
    q = rgb.quantize(palette=_pal_image(WOOD_PALETTE), dither=Image.Dither.NONE).convert("RGB")
    q.putalpha(alpha.point(lambda a: 255 if a > 127 else 0))
    return q


def process_extra() -> None:
    OUT_HOME = ROOT / "assets" / "sprites" / "safehouse"
    OUT_HOME.mkdir(parents=True, exist_ok=True)
    tiles = Image.open(RAW / "home_tiles.png").convert("RGB")
    cells = cut_cells(tiles, 4, 4)
    names = {0: "home_floor_a", 1: "home_floor_b", 2: "home_wall", 3: "home_trim"}
    for row, key in enumerate(["floor", "floor2", "wall", "trim"]):
        row_cells = cells[row * 4:row * 4 + 4]
        sheet = Image.new("RGBA", (64, 16), (0, 0, 0, 0))
        for i, c in enumerate(row_cells):
            sheet.paste(shrink(key_magenta(c), 16, HOME_PALETTE), (i * 16, 0))
        path = OUT_HOME / f"home_{key}_16.png"
        sheet.save(path)
        print("wrote", path.relative_to(ROOT), sheet.size, flush=True)
    props = Image.open(RAW / "home_props.png").convert("RGB")
    pc = cut_cells(props, 2, 2)
    specs = [("home_shelf_32x48.png", (32, 48)), ("home_basket_24x20.png", (24, 20)),
             ("home_lantern_16x24.png", (16, 24)), ("home_cabinet_32x20.png", (32, 20))]
    cab = cut_cells(Image.open(RAW / "home_cabinet2.png").convert("RGB"), 2, 2)[0]
    pc = pc[:3] + [cab]
    for c, (name, box) in zip(pc, specs):
        if name == "home_cabinet_32x20.png":
            im = shrink_wood(key_magenta(c), box)
        else:
            im = shrink(key_magenta(c), 0, HOME_PALETTE, box=box)
        path = OUT_HOME / name
        im.save(path)
        print("wrote", path.relative_to(ROOT), im.size, flush=True)
    glass = Image.open(RAW / "case_glass.png").convert("RGB")
    gc = cut_cells(glass, 2, 2)
    bg = ROOT / "assets" / "sprites" / "bm" / "case_glass_highlight.png"
    gl = decal_alpha(gc[0].resize((256, 256), Image.LANCZOS), color=(116, 168, 178), gain=1.0).resize((32, 32), Image.BOX)
    gl.save(bg)
    print("wrote", bg.relative_to(ROOT), gl.size, flush=True)


def process() -> None:
    process_grid(RAW / "wall_grid.png", 4, 4, 16, "bm_wall_trim.png", out_cols=4, out_rows=4)
    process_grid(RAW / "floor_decals.png", 4, 4, 16, "bm_floor_wear.png",
                 pick=list(range(8)), out_cols=4, out_rows=2, decal=True)
    for theme in ["china", "egypt", "greek", "silk", "jade", "dock"]:
        raw = RAW / f"decor_{theme}.png"
        if raw.exists():
            process_decor(raw, f"decor_bm_{theme}.png")


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    if mode in ("gen", "all"):
        for name, job in JOBS.items():
            gen_one(name, job)
    if mode in ("process", "all"):
        process()
        process_extra()


if __name__ == "__main__":
    main()
