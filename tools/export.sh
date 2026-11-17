#!/usr/bin/env bash
# 一键导出发布包。
# 默认（课堂桌面试玩，plan.md 2026-11-18）：导出 Windows + Linux 到 build/class-demo/，
# 附中文试玩说明与 SHA256；不导出 Web（用户已取消 Cloudflare 前置）。
# 用法：./tools/export.sh [--with-web]（或 GODOT_BIN=/path/to/godot ./tools/export.sh）
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT_BIN:-$HOME/.local/bin/godot}"
if [ ! -x "$GODOT" ]; then
	GODOT="$(command -v godot || true)"
fi
if [ -z "${GODOT:-}" ] || [ ! -x "$GODOT" ]; then
	echo "找不到 Godot。设置 GODOT_BIN=/path/to/godot 后重试。" >&2
	exit 1
fi

WITH_WEB=0
for arg in "$@"; do
	case "$arg" in
		--with-web) WITH_WEB=1 ;;
		*) echo "未知参数: $arg（支持 --with-web）" >&2; exit 2 ;;
	esac
done

TEMPLATES="$HOME/.local/share/godot/export_templates/4.7.2.stable"
if [ ! -f "$TEMPLATES/linux_release.x86_64" ]; then
	echo "缺少 Godot 4.7.2 导出模板：$TEMPLATES" >&2
	echo "下载：https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz" >&2
	echo "解压后把 templates/ 里的文件放到该目录。" >&2
	exit 1
fi

echo "== import =="
"$GODOT" --headless --import

rm -rf build/class-demo
mkdir -p build/class-demo/windows build/class-demo/linux

echo "== windows =="
"$GODOT" --headless --export-release "Windows" build/class-demo/windows/thief-sim.exe

echo "== linux =="
"$GODOT" --headless --export-release "Linux" build/class-demo/linux/thief-sim.x86_64

if [ "$WITH_WEB" -eq 1 ]; then
	mkdir -p build/class-demo/web
	echo "== web（可选保留） =="
	"$GODOT" --headless --export-release "Web" build/class-demo/web/index.html
	find build/class-demo/web -name '*.import' -delete
fi

python3 - <<'PY'
import os
import zipfile

build = os.path.join("build", "class-demo")
win_readme = """小偷模拟器 / Thief Simulator（课堂试玩版）
学生项目 · 数字历史 capstone

操作
  WASD / 方向键    移动
  Shift            疾跑
  C / Ctrl         蹲下（消除跑步噪音）
  E                交互 / 拾取 / 观察文物
  Tab 或 R         进入/退出路线规划（左键点节点、右键删除、可拖动）
  Enter            重算预演（规划时自动算，按一下刷新）
  空格             执行规划路线（方向键/E 接管）
  被发现            进入失败回放：红色高亮原因，按 E/空格 回退重规划
  Q                烟雾弹
  P                手机（任务 / 档案）
  ESC              返回 / 关闭

试玩任务（3–5 分钟）
  1. 用 Tab 规划一条绕开守卫的路线（看节点标签：守卫 ETA / 监控），
     Enter 预演，再空格执行；拿到任务目标后从出口撤离。
  2. 找一件文物，查看展签/档案，区分「据 / 推断 / 设」。

已知限制
  预演为确定性模拟（无执行随机偏移）；真实执行时守卫巡逻带随机偏移，
  预测与现实可能出现偏差，这正是需要观察与接管的原因。
  安全屋独立场景、箱子交易、三主线剧情为后续开发内容。

说明
  Windows 为单文件 exe，无需安装。首次运行可能提示 SmartScreen：
  点“更多信息” → “仍要运行”。
  存档自动保存在 %APPDATA%\\Godot\\app_userdata\\小偷模拟器\\save.json。
  游戏内「声明与说明」列有真实文物来源、虚构说明与字体许可。
  反馈方式：把你看到的问题原话发给开发者。
"""
linux_readme = """小偷模拟器 / Thief Simulator（课堂试玩版）
学生项目 · 数字历史 capstone

运行
  chmod +x thief-sim.x86_64
  ./thief-sim.x86_64

操作
  WASD / 方向键    移动
  Shift            疾跑
  C / Ctrl         蹲下（消除跑步噪音）
  E                交互 / 拾取 / 观察文物
  Tab 或 R         进入/退出路线规划（左键点节点、右键删除、可拖动）
  Enter            重算预演（规划时自动算，按一下刷新）
  空格             执行规划路线（方向键/E 接管）
  被发现            进入失败回放：红色高亮原因，按 E/空格 回退重规划
  Q                烟雾弹
  P                手机（任务 / 档案）
  ESC              返回 / 关闭

试玩任务与已知限制见 Windows 版 README；两者内容一致。
存档自动保存在 ~/.local/share/godot/app_userdata/小偷模拟器/save.json。
"""
open(os.path.join(build, "windows", "README.txt"), "w", encoding="utf-8").write(win_readme)
open(os.path.join(build, "linux", "README.txt"), "w", encoding="utf-8").write(linux_readme)


def zip_dir(src, out):
    if os.path.exists(out):
        os.remove(out)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for base, _, files in os.walk(src):
            for f in files:
                full = os.path.join(base, f)
                z.write(full, os.path.relpath(full, src))


zip_dir(os.path.join(build, "windows"), os.path.join(build, "thief-sim-class-demo-windows.zip"))
zip_dir(os.path.join(build, "linux"), os.path.join(build, "thief-sim-class-demo-linux.zip"))
import hashlib
for name in ["thief-sim-class-demo-windows.zip", "thief-sim-class-demo-linux.zip"]:
    p = os.path.join(build, name)
    h = hashlib.sha256(open(p, "rb").read()).hexdigest()
    print("%-38s %6.1f MB  sha256=%s" % (name, os.path.getsize(p) / 1024 / 1024, h[:16]))
PY

echo "完成。课堂交付：build/class-demo/{windows,linux}/ + 两个 zip（含 README 与哈希）。"
