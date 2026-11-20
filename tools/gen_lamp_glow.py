#!/usr/bin/env python3
"""Warm glow overlay for wall lamps (art, 2026-11-21).

Output: assets/sprites/wall_lamp_glow_32.png (32×32, transparent, additive-looking warm halo).
Overlay it centred on wall_lamp.png (16×16). Procedural on purpose: a radial falloff is
easier to control than a generated image. Do not hand-edit the PNG; change this script and re-run.

Run:  python3 tools/gen_lamp_glow.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "wall_lamp_glow_32.png"
SIZE = 32
COLOR = (244, 212, 138)
PEAK = 150


def main() -> None:
    im = Image.new("RGBA", (SIZE, SIZE), COLOR + (0,))
    px = im.load()
    c = (SIZE - 1) / 2
    for y in range(SIZE):
        for x in range(SIZE):
            d = (((x - c) / c) ** 2 + ((y - c) / c) ** 2) ** 0.5
            if d >= 1:
                continue
            a = int(PEAK * (1 - d) ** 2)
            if a > 0:
                px[x, y] = COLOR + (a,)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    im.save(OUT)
    print("wrote", OUT.relative_to(ROOT), im.size)


if __name__ == "__main__":
    main()
