#!/usr/bin/env python3
"""把双羊尊的 3D 渲染转成 2D 游戏的像素精灵。

输入：tools/blender/render_relic_turntable.py 的渲染结果（默认 /tmp/opencode/relic_turntable）
输出：
  assets/sprites/relic_ram_zun_strip.png   转台动画条（12 帧 × 24×28，关卡内的目标文物）
  assets/sprites/artifact_ram_zun.png      16×16 背包/图鉴图标（由 hero 大图降采样）

流程：统一取所有帧的公共内容框（避免旋转抖动）→ 缩放到帧尺寸（底边对齐）→
共享调色板量化（约 14 色，取自渲染本身）→ 拼条。可重复执行（覆盖输出）。

用法：
    python3 tools/gen_relic_sprite.py
    RELIC_RENDER_DIR=/path/to/renders python3 tools/gen_relic_sprite.py
"""
import glob
import os
import sys

from PIL import Image, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.environ.get("RELIC_RENDER_DIR", "/tmp/opencode/relic_turntable")
OUT_DIR = os.path.join(ROOT, "assets", "sprites")

FRAME_W, FRAME_H = 24, 28
FRAME_COUNT = 12
UI_FRAME_W, UI_FRAME_H = 48, 56  # 手机/标题界面的展示尺寸
PALETTE_COLORS = 14
BOTTOM_MARGIN = 1
ALPHA_CUTOFF = 128
ICON_SIZE = 24  # 背包格子为 24px，1:1 显示最清晰
CLOSEUP_SIZE = 360  # 互动特写层（2.5D）展示尺寸


def load_frames():
    files = sorted(glob.glob(os.path.join(SRC, "f*.png")))
    if len(files) != FRAME_COUNT:
        print("期望 %d 帧，实际 %d 帧（%s）" % (FRAME_COUNT, len(files), SRC), file=sys.stderr)
        sys.exit(1)
    return [Image.open(f).convert("RGBA") for f in files]


def common_bbox(frames):
    box = None
    for im in frames:
        b = im.getbbox()
        if b is None:
            continue
        box = b if box is None else (
            min(box[0], b[0]), min(box[1], b[1]),
            max(box[2], b[2]), max(box[3], b[3]),
        )
    if box is None:
        print("渲染帧全是空白", file=sys.stderr)
        sys.exit(1)
    return box


def fit_into_frame(im, box, frame_w, frame_h, margin):
    """裁剪公共框 → 等比缩放 → 底边居中放入帧画布。"""
    crop = im.crop(box)
    avail_w, avail_h = frame_w, frame_h - margin
    scale = min(avail_w / crop.width, avail_h / crop.height)
    new_w = max(1, round(crop.width * scale))
    new_h = max(1, round(crop.height * scale))
    resized = crop.resize((new_w, new_h), Image.LANCZOS)
    frame = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    x = (frame_w - new_w) // 2
    y = frame_h - margin - new_h
    frame.alpha_composite(resized, (x, y))
    return frame


def build_shared_palette(frames, colors):
    """把所有帧的不透明像素聚成一张长条图，量化出共享调色板。"""
    pixels = []
    for im in frames:
        data = list(im.getdata())
        pixels.extend(p[:3] for p in data if p[3] >= ALPHA_CUTOFF)
    if not pixels:
        print("没有可量化像素", file=sys.stderr)
        sys.exit(1)
    sample = Image.new("RGB", (len(pixels), 1))
    sample.putdata(pixels)
    return sample.quantize(colors=colors, method=Image.MEDIANCUT)


def build_sized_frames(frames, box, frame_w, frame_h, colors):
    """统一增强 → 缩放排布 → 共享调色板量化。返回（帧列表, 调色板）。"""
    tuned = []
    for im in frames:
        im = ImageEnhance.Color(im).enhance(1.25)
        im = ImageEnhance.Contrast(im).enhance(1.10)
        tuned.append(im)
    sized = [fit_into_frame(im, box, frame_w, frame_h, BOTTOM_MARGIN) for im in tuned]
    palette = build_shared_palette(sized, colors)
    return [apply_palette(im, palette) for im in sized], palette


def compose_strip(frames, frame_w, frame_h):
    strip = Image.new("RGBA", (frame_w * len(frames), frame_h), (0, 0, 0, 0))
    for i, im in enumerate(frames):
        strip.alpha_composite(im, (i * frame_w, 0))
    return strip


def apply_palette(frame, palette_img):
    alpha = frame.getchannel("A")
    rgb = frame.convert("RGB")
    quant = rgb.quantize(palette=palette_img, dither=Image.NONE).convert("RGB")
    quant.putalpha(alpha)
    return quant


def main():
    frames = load_frames()
    box = common_bbox(frames)
    print("公共内容框：", box)

    # 关卡内转台条（24×28）
    small, small_palette = build_sized_frames(frames, box, FRAME_W, FRAME_H, PALETTE_COLORS)
    strip_path = os.path.join(OUT_DIR, "relic_ram_zun_strip.png")
    compose_strip(small, FRAME_W, FRAME_H).save(strip_path)
    print("wrote", os.path.relpath(strip_path, ROOT), (FRAME_W * FRAME_COUNT, FRAME_H))

    # 手机/标题界面转台条（48×56，细节更多）
    ui_frames, _ = build_sized_frames(frames, box, UI_FRAME_W, UI_FRAME_H, PALETTE_COLORS + 6)
    ui_path = os.path.join(OUT_DIR, "relic_ram_zun_ui_strip.png")
    compose_strip(ui_frames, UI_FRAME_W, UI_FRAME_H).save(ui_path)
    print("wrote", os.path.relpath(ui_path, ROOT), (UI_FRAME_W * FRAME_COUNT, UI_FRAME_H))

    # 背包/图鉴图标：取侧影最宽的帧（侧视轮廓最易读）→ 24×24
    widest = max(frames, key=lambda im: im.getbbox()[2] - im.getbbox()[0])
    icon_src = ImageEnhance.Color(widest).enhance(1.35)
    icon_src = ImageEnhance.Contrast(icon_src).enhance(1.18)
    icon = fit_into_frame(icon_src, box, ICON_SIZE, ICON_SIZE, 0)
    icon = apply_palette(icon, small_palette)
    icon_path = os.path.join(OUT_DIR, "artifact_ram_zun.png")
    icon.save(icon_path)
    print("wrote", os.path.relpath(icon_path, ROOT), icon.size)

    # 互动特写层（2.5D）：保留渲染的细腻明暗，不量化成像素
    closeup_path = os.path.join(SRC, "closeup.png")
    if os.path.exists(closeup_path):
        closeup = Image.open(closeup_path).convert("RGBA")
        box = closeup.getbbox()
        if box is not None:
            crop = closeup.crop(box)
            scale = min(CLOSEUP_SIZE / crop.width, CLOSEUP_SIZE / crop.height)
            size = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
            art = crop.resize(size, Image.LANCZOS)
            art = ImageEnhance.Color(art).enhance(1.12)
            art = ImageEnhance.Contrast(art).enhance(1.06)
            canvas = Image.new("RGBA", (CLOSEUP_SIZE, CLOSEUP_SIZE), (0, 0, 0, 0))
            canvas.alpha_composite(art, ((CLOSEUP_SIZE - size[0]) // 2, (CLOSEUP_SIZE - size[1]) // 2))
            out_path = os.path.join(OUT_DIR, "relic_ram_zun_closeup.png")
            canvas.save(out_path)
            print("wrote", os.path.relpath(out_path, ROOT), canvas.size)
    else:
        print("缺少 closeup.png，跳过特写图", file=sys.stderr)


if __name__ == "__main__":
    main()
