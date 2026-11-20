#!/usr/bin/env python3
"""Copy the approved dialogue artwork to exportable assets; no raster rewriting.

Run after editing the source with imagegen. --check verifies the shipped copy.
"""
from pathlib import Path
import argparse
import struct

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'docs/art_direction/storyboard/q6_chibi_storyboard_dialogue.png'
TARGET = ROOT / 'assets/art/opening/q6_chibi_storyboard_dialogue.png'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    content = SOURCE.read_bytes()
    if content[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('>II', content[16:24]) != (1536, 1024):
        raise SystemExit('开场CG必须为1536×1024 PNG；调整画幅时同时更新OpeningCG多边形坐标。')
    if args.check:
        if not TARGET.exists() or TARGET.read_bytes() != content:
            raise SystemExit('开场CG导出副本未同步，请运行 python3 tools/import_opening_cg.py')
        print('开场CG源图与运行资源一致')
    else:
        TARGET.parent.mkdir(parents=True, exist_ok=True)
        TARGET.write_bytes(content)
        print('已导入开场CG：', TARGET.relative_to(ROOT))

if __name__ == '__main__':
    main()
