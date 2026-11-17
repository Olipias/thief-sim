# 课堂 demo pytest 骨架

用 pytest 包裹真实 Godot 测试，便于课堂/CI 统一入口；所有子进程都带 `--headless`，不弹窗。

## 运行

```bash
# 项目内已 vendored 一份 pytest；也可 pip install -r requirements-demo.txt
PYTHONPATH=tools/demo_lib python3 -m pytest tests/demo -q

# 只跑快速逻辑/数据套件（跳过 input-flow）
PYTHONPATH=tools/demo_lib python3 -m pytest tests/demo -q -m "not slow"

# 指定 Godot
GODOT=/path/to/godot python3 -m pytest tests/demo -q
```

## 覆盖

- `logic`：`tests/test_logic.gd`
- `sim-preview`：`tests/test_sim_preview.gd`（R-02 确定性预演）
- `content`：`tests/test_content.tscn`
- `save-compat`：`tests/test_save_compat.gd`
- `input-flow`（`slow`）：`tests/test_input_flow.tscn`，真实按键/鼠标流

> 这些只是入口包装；真正断言仍在 Godot 测试里维护。新增套件时同步更新 `CASES`。
