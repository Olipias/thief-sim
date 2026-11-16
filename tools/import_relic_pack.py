#!/usr/bin/env python3
"""Import the user-supplied relic pack; never edit generated assets by hand."""
from pathlib import Path
from zipfile import ZipFile
from PIL import Image
import io

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / 'assets/models/thief-sim-relic-assets.zip'
ITEMS = ('egypt_heart_scarab', 'akrotiri_askos')

def main():
    with ZipFile(PACK) as z:
        for item in ITEMS:
            for suffix, target, size in [
                ('icon', f'artifact_{item}.png', (16, 16)),
                ('strip', f'relic_{item}_strip.png', (288, 28)),
                ('ui_strip', f'relic_{item}_ui_strip.png', (576, 56)),
                ('closeup', f'relic_{item}_closeup.png', (360, 360)),
            ]:
                data = z.read(f'{item}/{item}_{suffix}.png')
                actual = Image.open(io.BytesIO(data)).size
                if suffix == 'icon' and actual == (24, 24):
                    output = io.BytesIO()
                    Image.open(io.BytesIO(data)).resize(size, Image.Resampling.NEAREST).save(output, format='PNG')
                    data = output.getvalue()
                    actual = size
                if size is not None and actual != size:
                    raise ValueError(f'{item}/{suffix}: expected {size}, found {actual}')
                (ROOT / 'assets/sprites' / target).write_bytes(data)
                print(target, actual)
            model = ROOT / 'assets/models/relic_pack' / f'{item}.glb'
            model.parent.mkdir(exist_ok=True)
            model.write_bytes(z.read(f'{item}/{item}.glb'))
        destination = ROOT / 'docs/art_direction/relic_pack_sources.md'
        destination.write_bytes(z.read('SOURCES.md'))

if __name__ == '__main__':
    main()
