"""pytest 配置：注册 slow marker（场景/输入流套件）。"""
from __future__ import annotations


def pytest_configure(config) -> None:  # noqa: ANN001
    config.addinivalue_line(
        "markers",
        "slow: 场景/输入流类 Godot 套件（耗时较长，可用 -m 'not slow' 跳过）",
    )
