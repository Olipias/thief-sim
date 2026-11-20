# R-02b / R-13a / 编译流程修复验收

日期：2026-11-21。

## 修复项

- `src/world/museum.gd` 迷雾函数类型推断修复（`_is_adjacent_to_revealed_zone` 中 `dx/dy` 显式 `int()`）。
- `src/main.gd` 移除 `Game.unlock_all_chains_required = true`，进入安全屋不再要求三链全完成。
- `src/main.gd` `escaped` 信号改为 lambda 连接，避免 `bind` 参数顺序问题。
- `src/autoload/game_state.gd` `place_item` / `_restore_bag` 保留 `instance_id`。
- `src/autoload/game_state.gd` `reset_progress()` 清空 `level_visited_rooms` 与 `level_taken_items`。
- `tests/test_save_compat.gd` 修复第 189 行解析错误。

## 新增验收

- `tests/test_museum_sim.gd` 从 24 项扩展到 43 项：对比执行事件、发现归因、完整 trace 重叠、守卫隐藏计时字段。
- `tests/test_exploration.gd` / `.tscn` 25 项：房间迷雾、跨次保留、侦察撤离、实例反刷。

## 验证结果

- `tools/verify.sh --fast`：16 项全部通过。
- `tools/verify.sh --visual`：20 项全部通过，43 张视觉基线已更新（`python3 tools/check_visual.py --update`）。
- 输入流：252 项通过。
- 冒烟测试：182 项通过。
- monkey：600 步通过。

## 日志

- `step_*.log`：本次 `tools/verify.sh --visual` 完整步骤输出。
