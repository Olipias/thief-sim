# 课堂演示 RUNBOOK · 2026-11-19

> 现场命令与流程（课前预检过一遍即可，勿临时摸索）。所有命令在仓库根目录执行。

## 0. 环境（课前已固定，勿重装）

- Godot：`~/.local/bin/godot`（4.7.2，防弹窗包装器；`GODOT_ALLOW_GUI=1 ~/.local/bin/godot .` 才弹真窗口）
- Python：`python3 -m pytest`（pytest 已装到 `tools/demo_lib/`，`PYTHONPATH=tools/demo_lib` 生效）
- 依赖版本：`requirements-demo.txt`（pytest>=8,<10）

## 1. 短套件（现场 30–60 秒）

```bash
# 1) 程序逻辑 + 史料边界（含真实 Godot 逻辑/存档/进度套件 + 确定性预演 + 三层边界）
PYTHONPATH=tools/demo_lib python3 -m pytest tests/demo/ -q
```

- `test_logic.py` 用 subprocess 驱动**真实 Godot 测试**（test_logic / test_content / test_save_compat / test_progression / test_sim_preview / test_input_flow），断言退出码 0、无引擎错误、关键断言文本（预演/执行逐 tick 一致、失败恢复、发现归因、开锁 40t）。
- `test_history.py` 校验「据 / 推断 / 设 / 未核实」边界（evidence.gd 与 statements.gd 单一来源）。

## 2. 原生输入流自检（真实按键/鼠标，40–70 秒）

```bash
~/.local/bin/godot --headless res://tests/test_input_flow.tscn
```

- 真实按键驱动：覆盖层开关契约、路线规划（Tab/点击/空格执行/接管）、失败回放（0.6s 定格、回退重规划）、据点剧情、三目标切换、展签卡阅读。
- 收尾输出逐行 `PASS - <断言>` 摘要 + `ALL n CHECKS PASSED`。

## 3. 完整验证（课前已跑并记录；现场不跑）

```bash
tools/verify.sh            # 15 项
tools/verify.sh --visual   # 17 项 + 36 张视觉基线
```

## 4. 桌面包（朋友用）

- 位置：`build/class-demo/thief-sim-class-demo-windows.zip` / `...-linux.zip`
- 内容：exe（内嵌 pck）+ 中文 README（操作键位、3–5 分钟试玩任务、已知限制）
- 干净目录验证：解压 → `chmod +x thief-sim.x86_64` → 运行（Linux 实测通过，退出码 0）

## 5. 演示要打的三个点

1. **确定性预演**：`tests/test_sim_preview.gd` 同快照/同路线预演与执行逐 tick 100% 一致、失败恢复整份快照。
2. **真实游戏接入**：博物馆关卡规划模式（Tab）点路线，Enter 预演显示玩家轨迹/守卫残影/黄色首次发现预警。
3. **史料边界**：安全屋推理板线索卡分「【馆藏档案】/【公开登记】/【虚构】」，pytest 的 test_history 逐条守住「据 / 推断 / 设 / 未核实」。

## 6. 故障排查

- pytest 报找不到 Godot → `export GODOT_BIN=$HOME/.local/bin/godot`
- pytest 报模块缺失 → `pip install --target tools/demo_lib pytest`（已装，勿重装）
- 游戏测试弹窗 → 必须用 `~/.local/bin/godot`（自带 Xvfb 防弹窗包装器）
- 视觉回归失败 → 先看 `/tmp/opencode/visual_diff/`，确认为预期改动后 `python3 tools/check_visual.py --update`
