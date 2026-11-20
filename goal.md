# 项目目标声明（课堂 Loop 1）

整理日期：2026-11-18。这是根据真实用户需求与当前仓库整理的目标文件，不是 `/goal` 工具执行记录，不证明曾启用 Plan mode。

> 用 Godot 制作一个以文物调查与路线预演为核心的中文潜行游戏：玩家查阅可追溯资料、区分史实与虚构，规划并执行潜入路线，再作出剧情交付选择。

## 本次课堂展示范围

展示实际桌面试玩版本，以及需求讨论 → 确认方案 → 实现计划 → 模块图的过程。后续自动测试与反馈属于 Loop 2–4，不把计划中的功能称为已经完成。

| 展示目标 | 可核验依据 | 范围边界 |
| --- | --- | --- |
| 从用户讨论形成设计决策 | 当前真实聊天、docs/demo/loop1/QA.md、docs/CONFIRMED_DESIGN.md | QA.md是回溯摘录，不是完整Plan-mode导出 |
| 明确开发次序 | plan.md、docs/ROADMAP.md、docs/DETERMINISTIC_PREVIEW.md | 先验证确定性预演，再逐项完善房间与设备 |
| 可解释的路线预演 | src/sim/sim_preview.gd、tests/test_sim_preview.gd | 灰盒一致性测试不等于整个游戏全部行为已验证 |
| 真实资料与虚构剧情分界 | docs/CONTENT_REVIEW.md、docs/SOURCES.md、tests/demo/test_history.py | 自动检查不替代人工史料审阅 |
| 展示agent生成的项目图 | docs/demo/loop1/schematic.svg及schematic.mmd | 图中虚线是待实现设计，不能称为当前已玩到的流程 |

## 本轮不作完成声明的项目

独立安全屋、实体电脑、手机接任务后走门出发、箱子预约交易，按ROADMAP逐项实施与验收；两位好友反馈和三人盲测需要真实参与者。课堂HTTPS/Playwright/MCP要求的桌面替代尚未得到老师确认。

[离线展示页](docs/demo/loop1/index.html) · [45秒讲稿与证据准备](docs/demo/loop1/README.md) · [现有课堂计划](plan.md)
