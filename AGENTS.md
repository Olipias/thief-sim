# AGENTS.md — 《小偷模拟器》Agent 工作手册

> 面向所有在本仓库工作的 AI agent（含 OpenCode 多窗口并行）。
> **开工前请完整读完本文件**；细节背景见 `docs/`。本文件与代码冲突时，以代码和测试为准，并顺手修订本文件。

## 0. 项目是什么

《小偷模拟器》是一个 **Godot 4.7** 像素风潜行盗宝游戏，同时是**数位历史（Digital History）专业的 capstone project**。
两大灵魂设定：

- **文物通灵**：接触文物会遭遇附着其上的幽灵——帮助玩家、捣乱，或讲述文物背后的真实历史。
- **史观选择**：重点关卡「大英博物馆」中，掠夺文物取回后玩家可选择**卖给黑市**或**归还中国**，选择影响主线、幽灵态度与结局。

完整愿景、学术规范与设计方向见技能文件 `.opencode/skills/thief-sim/SKILL.md`（相关时自动加载）。

## 1. 读什么（按顺序）

| 顺序 | 文件 | 什么时候读 |
| --- | --- | --- |
| 1 | 本文件 | 每次会话开始 |
| 2 | `docs/ROADMAP.md` | 动手前：认领任务、看并行窗口在改什么 |
| 3 | `docs/ARCHITECTURE.md` | 要理解模块、数据流、动手改代码时 |
| 4 | `docs/DECISIONS.md` | 觉得某个做法奇怪、想推翻一个设计时 |
| 5 | `docs/SOURCES.md` | 涉及真实文物/历史内容时（强制登记） |
| 6 | `CHANGELOG.md` + `README.md` | 了解已完成的进度轨迹 |

## 2. 环境与命令

```bash
~/.local/bin/godot .                    # 运行游戏（等价：./play.sh）
tools/verify.sh                         # ★ 一键全量验证（收尾/提交前必跑）
tools/verify.sh --fast                  # 快速子集：跳过冒烟测试

# 分项命令（verify.sh 内部就是这些）
~/.local/bin/godot --headless --script tests/test_logic.gd       # 纯逻辑单测
~/.local/bin/godot --headless res://tests/test_content.tscn      # 内容一致性（文物/商店/音效/关卡数据）
~/.local/bin/godot --headless res://tests/test_scripts.tscn      # 全部 GDScript 可编译性
~/.local/bin/godot --headless res://tests/smoke_test.tscn        # 场景集成冒烟测试
~/.local/bin/godot --audio-driver Dummy res://tests/screenshot.tscn  # 截图 → /tmp/shot_*.png

# 资源生成（改素材/地图必须走这里，见硬性规则 2）
python3 tools/gen_museum_map.py            # 重新生成 src/levels/museum_map.json
python3 tools/gen_placeholder_sprites.py   # 重新生成 assets/sprites 占位图
python3 tools/gen_sfx.py                  # 重新生成 assets/sfx 音效
```

本机缺少 libasound/libpulse：**headless / 无声运行是正常现象**，与逻辑无关。

## 3. 硬性规则（违反 = 返工）

1. **测试必须全绿**：收尾前跑 `tools/verify.sh`。新功能必须补测试——纯逻辑进 `tests/test_logic.gd`，内容/数据一致性进 `tests/test_content.gd`，场景行为进 `tests/smoke_test.gd`。
2. **生成物禁止手改**：`assets/**`（由 `tools/gen_*.py` 生成）与 `src/levels/museum_map.json`（由 `tools/gen_museum_map.py` 生成）。改素材/地图先改脚本再重新生成；verify 会校验地图与生成脚本是否同步。
3. **版本记录**：每批改动更新 `CHANGELOG.md`（原型期 `v0.x.0` = 一批功能、`v0.x.y` = 修复；含日期与「新增/修改/修复/测试」分类）+ `README.md`「开发进度」+ `docs/ROADMAP.md` 任务状态。写清「改了什么、为什么」，禁止「优化若干」这类含糊描述。
4. **存档兼容**：`user://save.json` 只增字段（读取必须有默认值），不得静默改变旧字段语义；破坏性变更必须写迁移并记入 `docs/DECISIONS.md`。
5. **UI/文案一律中文**，界面按 640×360 整数缩放设计。
6. **世界（World）节点不得挂到 CanvasLayer 下**——相机将失效（教训见 `docs/DECISIONS.md` D-003）。
7. **并行窗口纪律**：只改与你的任务相关的文件；不顺手重构、不整文件重排格式化；动手前先 `git status` / `git diff` 看并行改动；不执行会丢弃他人未提交改动的 git 操作（`reset --hard`、`checkout .`、`clean -fd` 等）。
8. **学术规范**：真实文物/事件必须登记 `docs/SOURCES.md`（含参考来源与史实/演绎分界）；超自然内容（幽灵、通灵）一律注明虚构演绎。

## 4. 任务认领协议（多窗口并行）

1. 打开 `docs/ROADMAP.md`，从「待办」选一条任务，改成 `🚧 进行中｜<窗口/人>｜<日期>` 再动手。
2. 一次只做一条主线；中途想加别的，先回看板记一行。
3. 完成后：跑 `tools/verify.sh` → 更新 CHANGELOG / README → 任务标 `✅ 完成`（保留记录，不要删除条目）。
4. 发现引入的 bug 但暂时不修？记入 ROADMAP「已知问题」。

## 5. 完成定义（DoD）

- [ ] `tools/verify.sh` 全绿（含新增测试）
- [ ] 涉及画面 → 跑过截图场景（`tests/screenshot.tscn`），人眼确认无回归
- [ ] `CHANGELOG.md` 顶部新增条目（版本号 + 日期 + 新增/修改/修复/测试）
- [ ] `README.md`「开发进度」与 `docs/ROADMAP.md` 状态已同步
- [ ] 架构/决策有变 → 更新 `docs/ARCHITECTURE.md` / `docs/DECISIONS.md`

## 6. 已知坑（快速提示）

- Godot 4.7：`*.uid` 文件要提交；`.godot/`（导入缓存）不提交。
- 测试把存档隔离到 `/tmp`（`Game.save_path`）；冒烟测试退出前必须 `Audio.shutdown()`，否则出现"假泄漏"告警。
- `mission_complete` 是**实时推导**的（背包里没有任务目标就为 false）——涉及目标物的改动要照顾"丢出后出口上锁"的行为。
- 平行感知按房间分流：噪音/幽灵哀嚎只影响同房间的警察（`room_index_at`）。
- `--check-only --script` 对引用 autoload 的脚本会误报，不要用它做语法检查；用 `tests/test_scripts.tscn`。

## 7. 文档地图

```
AGENTS.md                 本文件：规则、命令、协作协议（每次会话自动加载）
docs/ARCHITECTURE.md      架构地图、数据流、不变量、改造配方（Recipes）
docs/ROADMAP.md           任务板：里程碑、待办、已知问题（认领处）
docs/DECISIONS.md         决策记录（ADR-lite）：为什么这样做，防止无意推翻
docs/SOURCES.md           史料来源登记：真实文物与演绎分界（学术硬要求）
CHANGELOG.md / README.md  版本轨迹与项目说明
tools/verify.sh           一键验证入口
```
