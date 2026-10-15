#!/usr/bin/env python3
"""关卡数据与生成器自检。

1. tools/*.py 全部可被 Python 解析（防止生成脚本本身语法坏掉）
2. tools/gen_museum_map.py 自带的结构校验通过（连通性 / 巡逻合法性等），对每个关卡
3. src/levels/<level>.json 与生成器输出完全一致（生成物禁止手改）

用法：python3 tools/check_level.py
失败以非零退出码结束。
"""
import ast
import glob
import importlib.util
import json
import os
import sys

os.environ.setdefault("PYTHONDONTWRITEBYTECODE", "1")
sys.dont_write_bytecode = True

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_generator():
    path = os.path.join(ROOT, "tools", "gen_museum_map.py")
    spec = importlib.util.spec_from_file_location("gen_museum_map", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    errors = []

    # 1) 生成脚本本身能解析
    for path in sorted(glob.glob(os.path.join(ROOT, "tools", "*.py"))):
        try:
            ast.parse(open(path, encoding="utf-8").read())
        except SyntaxError as exc:
            errors.append("%s 语法错误：%s" % (os.path.relpath(path, ROOT), exc))

    gen = load_generator()

    # 2) + 3) 每个关卡：生成器自检通过，且磁盘文件与生成输出一致
    for level_id, info in gen.LEVELS.items():
        tiles, patrols, rects, floors = gen.build(level_id)
        map_errors, _ = gen.validate(tiles, patrols, rects)
        for err in map_errors:
            errors.append("[%s] 生成器校验失败：%s" % (level_id, err))

        json_path = os.path.join(ROOT, "src", "levels", info["out"])
        if not os.path.exists(json_path):
            errors.append("[%s] 缺少关卡文件 %s" % (level_id, info["out"]))
            continue
        with open(json_path, encoding="utf-8") as f:
            data = json.load(f)
        fresh = {
            "tile_size": 16,
            "rooms": rects,
            "floors": floors,
            "tiles": tiles,
            "patrols": patrols,
        }
        for key in ("tile_size", "rooms", "floors", "tiles", "patrols"):
            if data.get(key) != fresh[key]:
                errors.append(
                    "[%s] %s 的 %r 与生成器输出不一致——生成物禁止手改，"
                    "请运行 python3 tools/gen_museum_map.py 重新生成" % (level_id, info["out"], key)
                )

    # 4) 关卡注册表（game_state.LEVELS）里的地图文件必须存在
    registry = os.path.join(ROOT, "src", "autoload", "game_state.gd")
    with open(registry, encoding="utf-8") as f:
        registry_src = f.read()
    for info in gen.LEVELS.values():
        if info["out"] not in registry_src:
            errors.append("game_state.LEVELS 未登记关卡地图 %s" % info["out"])

    if errors:
        print("check_level FAILED:")
        for err in errors:
            print("  -", err)
        return 1
    print(
        "check_level OK（%d 个关卡：生成物与脚本同步）"
        % len(gen.LEVELS)
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
