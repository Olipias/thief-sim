"""Pytest 入口：用 subprocess 调真实 Godot 测试（课堂 demo 验收用）。

运行：
    PYTHONPATH=tools/demo_lib python3 -m pytest tests/demo -q
或（系统已装 pytest）：
    python3 -m pytest tests/demo -q

要求：Godot 可执行文件在 ~/.local/bin/godot，或用 GODOT=/path/to/godot 覆盖。
所有子进程强制 --headless，不会弹窗。
"""
from __future__ import annotations

import os
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
GODOT = Path(os.environ.get("GODOT", str(Path.home() / ".local" / "bin" / "godot")))

# 课堂 demo 的快速、纯逻辑/数据套件；场景/输入流可用 -m slow 单独跑。
CASES = [
    pytest.param(
        "logic",
        ["--headless", "--script", "tests/test_logic.gd"],
        id="logic",
    ),
    pytest.param(
        "sim_preview",
        ["--headless", "--script", "tests/test_sim_preview.gd"],
        id="sim-preview",
    ),
    pytest.param(
        "content",
        ["--headless", "res://tests/test_content.tscn"],
        id="content",
    ),
    pytest.param(
        "save_compat",
        ["--headless", "--script", "tests/test_save_compat.gd"],
        id="save-compat",
    ),
    pytest.param(
        "input_flow",
        ["--headless", "res://tests/test_input_flow.tscn"],
        id="input-flow",
        marks=pytest.mark.slow,
    ),
]


@pytest.mark.parametrize("name,args", CASES)
def test_godot_suite(name: str, args: list[str]) -> None:
    if not GODOT.is_file():
        pytest.fail(f"找不到 Godot：{GODOT}（用 GODOT 环境变量指定）")
    result = subprocess.run(
        [str(GODOT), *args],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=600,
    )
    combined = (result.stdout or "") + "\n" + (result.stderr or "")
    assert result.returncode == 0, (
        f"[{name}] Godot 退出码 {result.returncode}\n"
        f"STDOUT:\n{result.stdout[-3000:]}\nSTDERR:\n{result.stderr[-3000:]}"
    )
    assert "ALL " in combined, f"[{name}] 未看到 ALL … PASSED 输出：\n{combined[-3000:]}"
