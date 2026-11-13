#!/usr/bin/env python3
"""Build the 24x32 player sheet from the generated reference-based artwork."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'docs/art_direction/a00_src/thief_noir_generated.png'
OUTPUT = ROOT / 'assets/sprites/chars/player_noir.png'


def main():
    source = Image.open(SOURCE).convert('RGBA')
    sheet = Image.new('RGBA', (96, 96))
    # The original artwork has fixed, separate cells. Each silhouette is
    # bottom-centred at the same scale to avoid shifting the player's feet.
    xs = (110, 420, 720, 1030, 1340)
    ys = (0, 360, 720, 1086)
    for row in range(3):
        for col in range(4):
            cell = source.crop((xs[col], ys[row], xs[col + 1], ys[row + 1]))
            alpha = cell.getchannel('A').point(lambda a: 255 if a >= 128 else 0)
            cell.putalpha(alpha)
            bounds = alpha.getbbox()
            if not bounds:
                raise ValueError(f'empty sprite at {row}, {col}')
            cell = cell.crop(bounds)
            # A fixed scale retains the proportions between poses.
            cell = cell.resize((max(1, round(cell.width * 29 / 312)),
                                max(1, round(cell.height * 29 / 312))), Image.Resampling.NEAREST)
            if cell.width > 24 or cell.height > 32:
                raise ValueError(f'sprite exceeds frame at {row}, {col}')
            sheet.alpha_composite(cell, (col * 24 + (24 - cell.width) // 2,
                                         row * 32 + 31 - cell.height))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUTPUT)


if __name__ == '__main__':
    main()
