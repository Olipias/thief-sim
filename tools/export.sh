#!/usr/bin/env bash
# 一键导出 Web / Windows / Linux 发布包，并压缩到 build/。
# 需要 Godot 4.7.2 + 对应版本的导出模板。
# 用法：./tools/export.sh（或 GODOT_BIN=/path/to/godot ./tools/export.sh）
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

TEMPLATES="$HOME/.local/share/godot/export_templates/4.7.2.stable"
if [ ! -f "$TEMPLATES/web_release.zip" ]; then
	echo "缺少 Godot 4.7.2 导出模板：$TEMPLATES" >&2
	echo "下载：https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz" >&2
	echo "解压后把 templates/ 里的文件放到该目录（应能看到 web_release.zip / windows_release_x86_64.exe）。" >&2
	exit 1
fi

echo "== import =="
"$GODOT" --headless --import

rm -rf build/web build/windows build/linux
mkdir -p build/web build/windows build/linux

echo "== web =="
"$GODOT" --headless --export-release "Web" build/web/index.html
# Web 构建里的 .import 只是编辑器元数据，没必要上传
find build/web -name '*.import' -delete

echo "== windows =="
"$GODOT" --headless --export-release "Windows" build/windows/thief-sim.exe

echo "== linux =="
"$GODOT" --headless --export-release "Linux" build/linux/thief-sim.x86_64

python3 - <<'PY'
import os
import zipfile

build = "build"
win_readme = """小偷模拟器 / Thief Simulator（v0.18.1）
学生项目 · 数字历史 capstone

操作
  WASD / 方向键  移动
  Shift          疾跑
  E              交互 / 拾取
  Q              烟雾弹
  B              背包
  P              手机（任务 / 档案）
  ESC            返回 / 关闭

说明
  单文件 exe，无需安装。首次运行 Windows 可能提示 SmartScreen：
  点“更多信息” → “仍要运行”。
  存档自动保存在 %APPDATA%\\Godot\\app_userdata\\小偷模拟器\\save.json。
  游戏内「声明与说明」列有真实文物来源、虚构说明与字体许可。
"""
linux_readme = """小偷模拟器 / Thief Simulator（v0.18.1）
学生项目 · 数字历史 capstone

运行
  chmod +x thief-sim.x86_64
  ./thief-sim.x86_64

操作
  WASD / 方向键  移动
  Shift          疾跑
  E              交互 / 拾取
  Q              烟雾弹
  B              背包
  P              手机（任务 / 档案）
  ESC            返回 / 关闭

说明
  存档自动保存在 ~/.local/share/godot/app_userdata/小偷模拟器/save.json。
  游戏内「声明与说明」列有真实文物来源、虚构说明与字体许可。
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


zip_dir(os.path.join(build, "web"), os.path.join(build, "thief-sim-web.zip"))
zip_dir(os.path.join(build, "windows"), os.path.join(build, "thief-sim-windows.zip"))
zip_dir(os.path.join(build, "linux"), os.path.join(build, "thief-sim-linux.zip"))
for name in ["thief-sim-web.zip", "thief-sim-windows.zip", "thief-sim-linux.zip"]:
    p = os.path.join(build, name)
    print("%-28s %6.1f MB" % (name, os.path.getsize(p) / 1024 / 1024))
PY

echo "完成。上传 itch.io 用 build/thief-sim-web.zip；Windows 备用包 build/thief-sim-windows.zip。"
