#!/usr/bin/env python3
"""截图视觉回归：把当前截图与 tests/visual_baseline/ 里的基线逐像素对比。

用法：
    # 1) 先跑截图场景（需要可用的显示环境；产出 /tmp/shot_*.png）
    ~/.local/bin/godot --audio-driver Dummy res://tests/screenshot.tscn
    # 2) 对比基线（或直接用 tools/verify.sh --visual 一步跑完）
    python3 tools/check_visual.py
    # 3) 画面是"有意改动"时，人眼确认后更新基线
    python3 tools/check_visual.py --update

判定规则：
- 逐像素比较（单通道差 > TOLERANCE 记为不同），差异占比超过该图阈值即失败。
- 默认阈值 2%；含动画/光照的截图在 OVERRIDES 里单独放宽并在注释里说明原因。
- 失败会把差异图写到 /tmp/opencode/visual_diff/（改动像素标红），方便人眼确认。
- 截图缺失 / 尺寸变化 / 多出基线外的截图，都按失败处理（附修复提示）。
- 换机器/显卡驱动后若出现整体细微差异：先看差异图，确认没有真实变化再 `--update`；
  本项目为像素画+最近邻+整数缩放，正常情况下跨显卡应基本一致。

依赖：Pillow（本机已安装）。
"""
import argparse
import glob
import os
import shutil
import sys

from PIL import Image, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_SHOT_DIR = "/tmp"
BASELINE_DIR = os.path.join(ROOT, "tests", "visual_baseline")
DEFAULT_DIFF_DIR = "/tmp/opencode/visual_diff"

TOLERANCE = 8  # 单通道差异容忍（0-255）：吸收无损压缩/渲染抖动
DEFAULT_THRESHOLD = 0.02  # 2% 像素不同即失败

# 动画/光照类截图：两次运行本身就有差异，放宽阈值，只拦"大幅变样"。
# （实测：alert ~10%，smoke ~1.6%，bm_ghost ~1.0%）
OVERRIDES = {
    "shot_alert.png": 0.20,
    "shot_smoke.png": 0.06,
    "shot_bm_ghost.png": 0.06,
}


def threshold_for(name: str) -> float:
    return OVERRIDES.get(name, DEFAULT_THRESHOLD)


def list_shots(shot_dir: str):
    return sorted(glob.glob(os.path.join(shot_dir, "shot_*.png")))


def changed_mask(a: Image.Image, b: Image.Image) -> Image.Image:
    diff = ImageChops.difference(a.convert("RGB"), b.convert("RGB")).convert("L")
    return diff.point(lambda v: 255 if v > TOLERANCE else 0)


def ratio(mask: Image.Image) -> float:
    hist = mask.histogram()
    changed = hist[255] if len(hist) > 255 else 0
    total = mask.size[0] * mask.size[1]
    return changed / total if total else 0.0


def save_diff_visual(base: Image.Image, mask: Image.Image, out_path: str) -> None:
    red = Image.new("RGB", base.size, (255, 30, 30))
    Image.composite(red, base.convert("RGB"), mask).save(out_path)


def update_baselines(shots) -> int:
    if not shots:
        print("没有找到截图（%s/shot_*.png）——请先运行截图场景。" % DEFAULT_SHOT_DIR)
        return 1
    os.makedirs(BASELINE_DIR, exist_ok=True)
    current = {os.path.basename(p) for p in shots}
    for old in glob.glob(os.path.join(BASELINE_DIR, "shot_*.png")):
        if os.path.basename(old) not in current:
            os.remove(old)
            print("移除过期基线：", os.path.basename(old))
    for path in shots:
        dst = os.path.join(BASELINE_DIR, os.path.basename(path))
        shutil.copyfile(path, dst)
        print("更新基线：", os.path.basename(dst))
    print("\n已更新 %d 张基线（tests/visual_baseline/）。请用 git diff 确认后再提交。" % len(shots))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="截图视觉回归")
    parser.add_argument("--update", action="store_true", help="用当前截图更新基线（人眼确认后使用）")
    parser.add_argument("--shot-dir", default=DEFAULT_SHOT_DIR, help="截图目录（默认 /tmp）")
    parser.add_argument("--diff-dir", default=DEFAULT_DIFF_DIR, help="差异图输出目录")
    args = parser.parse_args()

    shots = list_shots(args.shot_dir)
    if args.update:
        return update_baselines(shots)

    baselines = sorted(glob.glob(os.path.join(BASELINE_DIR, "shot_*.png")))
    if not baselines:
        print("没有基线（tests/visual_baseline/ 为空）。先运行截图场景，再执行：")
        print("  python3 tools/check_visual.py --update")
        return 1

    current = {os.path.basename(p): p for p in shots}
    baseline_names = {os.path.basename(p) for p in baselines}
    missing = sorted(baseline_names - set(current))
    extra = sorted(set(current) - baseline_names)

    errors = 0
    print("%-28s %8s %8s  %s" % ("截图", "差异", "阈值", "结果"))
    print("-" * 58)
    for bpath in baselines:
        name = os.path.basename(bpath)
        if name in missing:
            print("%-28s %8s %8s  FAIL（当前截图缺失）" % (name, "-", "-"))
            errors += 1
            continue
        base = Image.open(bpath)
        cur = Image.open(current[name])
        if base.size != cur.size:
            print("%-28s %8s %8s  FAIL（尺寸 %s -> %s）" % (name, "-", "-", base.size, cur.size))
            errors += 1
            continue
        mask = changed_mask(base, cur)
        r = ratio(mask)
        limit = threshold_for(name)
        ok = r <= limit
        print("%-28s %7.2f%% %7.1f%%  %s" % (name, r * 100, limit * 100, "ok" if ok else "FAIL"))
        if not ok:
            errors += 1
            os.makedirs(args.diff_dir, exist_ok=True)
            out = os.path.join(args.diff_dir, name)
            save_diff_visual(base, mask, out)
            print("  差异图：%s" % out)

    if extra:
        for name in extra:
            print("%-28s %8s %8s  FAIL（基线里没有这张图；如属新增，请 --update）" % (name, "-", "-"))
        errors += len(extra)

    print()
    if errors:
        print("视觉回归失败：%d 项。请查看 /tmp/opencode/visual_diff/ 的红色标记图。" % errors)
        print("若是预期内的画面改动：人眼确认后运行 python3 tools/check_visual.py --update")
        return 1
    print("视觉回归通过：%d 张截图与基线一致（阈值内）。" % len(baselines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
