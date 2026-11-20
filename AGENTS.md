# AGENTS.md — 《小偷模拟器》Agent 工作手册

> 面向所有在本仓库工作的 AI agent（含 OpenCode 多窗口并行）。
> **开工前请完整读完本文件**；细节背景见 `docs/`。现有行为以代码和测试为准；后续目标以用户最新确认方案为准，不能因旧实现/旧测试存在而继续旧设计。

## 0. 项目是什么

《小偷模拟器》是一个 **Godot 4.7** 像素风潜行盗宝游戏，同时是**数位历史（Digital History）专业的 capstone project**。
当前方向：恶魔契约、文物调查、路线预演与剧情抉择。**2026-11-16 用户试玩后确认的方案见 [当前确认方案](docs/CONFIRMED_DESIGN.md) 和 [GDD](GDD.md)。设计已确认，分批实现中；2026-11-18已接入用户授权的q6开场CG，其他条目以ROADMAP核验。**

- 安全屋为可走动、带碰撞与家具交互的独立2D室内场景，彻底移除旧Hub顶部栏目页；电脑必须是房内可交互道具。
- 签约分镜：2026-11-18已接入q6六格对白图，每格5秒自动推进，点击/E/Space手动推进、Skip跳过，结束自动接教学；交接见 docs/art_direction/storyboard/OPENING_CG_HANDOFF.md，不恢复旧8×18秒占位演出。教学撤离回安全屋。手机选任务准备后，必须走到房门出发。
- 普通文物：存箱 → 手机预约 → 取出 → 门外神秘人交货；主要三文物只走上交恶魔或交给对应国家的剧情，不能普通出售。
- 规划时人物、守卫、监控及世界计时一起冻结；任何退出路径一起恢复，不得形成玩家能走、警察被定住的子弹时间。
- 剧情直白、长文换行分页。标题UI重新设计；封面已指定为 `assets/art/CPy0UzlakIPj0kfwMuVCR.png`，后续使用此图适配；当前只登记，尚未接入，不生成或修改图片。
- 不恢复文物幽灵/器灵哀嚎。真实文物史料与虚构借展/剧情分界仍强制执行。
- 2026-11-19新方向见docs/EXPLORATION_LOOP.md：固定较大展馆、房间迷雾、知识跨次保留、可不带主目标撤离、普通战利品出售后手机购工具。未探区域不露轮廓/目标/出口，布展单不解全图；取消三条链全完成才能出发的旧门槛，不新增六件相似品。先做样板，尚未实现。

新增内容门槛：开工读 `docs/CONTENT_REVIEW.md`，每件文物核查馆藏/流转/追索主张与各方来源，历史文案映射已核查事实ID；恶魔台词独立审校；2026-11-19用户要求完整声明与来源统一放标题“声明”，正篇不逐条贴“此为虚构”，不强制每个结局再弹声明。事实/未知/创作映射保留编辑侧。剧情与线索稿入口docs/narrative/，待审阅后接入。埃及目标已锁定心形圣甲虫，不恢复模糊候选，缺证据不造追索。

首个可玩技术里程碑为 `docs/DETERMINISTIC_PREVIEW.md` 的确定性灰盒，先于完整安全屋：固定tick、同模拟内核/快照、逐tick一致、准确事件归因、失败恢复完整快照且保留路线。废除随机巡逻偏移的预测误差设计。

项目技能入口 `.opencode/skills/thief-sim/SKILL.md` 已同步；旧STORY/GDD_V2/任务排期只供查阅，不作为当前实现指令。

## 1. 读什么（按顺序）

| 顺序 | 文件 | 什么时候读 |
| --- | --- | --- |
| 1 | 本文件 | 每次会话开始 |
| 2 | `docs/CONFIRMED_DESIGN.md` + `GDD.md` | 动手前：读取最新用户裁定；新目标不等于已实现 |
| 3 | `docs/ROADMAP.md` | 动手前：认领任务、看并行窗口在改什么 |
| 4 | `docs/ARCHITECTURE.md` | 要理解模块、数据流、动手改代码时 |
| 5 | `docs/DECISIONS.md` | 觉得某个做法奇怪、想推翻一个设计时 |
| 6 | `docs/SOURCES.md` | 涉及真实文物/历史内容时（强制登记） |
| 7 | `CHANGELOG.md` + `README.md` | 了解已完成的进度轨迹 |

## 2. 环境与命令

```bash
~/.local/bin/godot .                    # 运行游戏（等价：./play.sh）
tools/verify.sh                         # ★ 一键全量验证（收尾/提交前必跑）
tools/verify.sh --fast                  # 快速子集：跳过冒烟测试与 monkey
tools/verify.sh --visual                # 全量 + 截图视觉回归（画面改动后必跑）

# 分项命令（verify.sh 内部就是这些）
~/.local/bin/godot --headless --script tests/test_logic.gd       # 纯逻辑单测
~/.local/bin/godot --headless res://tests/test_content.tscn      # 内容一致性（文物/商店/音效/关卡数据）
~/.local/bin/godot --headless res://tests/test_scripts.tscn      # 全部 GDScript 可编译性
~/.local/bin/godot --headless res://tests/test_input_flow.tscn   # 输入流自检（真实按键驱动 UI 覆盖层）
~/.local/bin/godot --headless --script tests/test_save_compat.gd # 存档兼容（老档/脏档/未来档）
~/.local/bin/godot --headless --script tests/test_progression.gd  # 玩家进度（结算/仓库/收集册/存档健壮性）
~/.local/bin/godot --headless res://tests/test_scenes.tscn       # 场景实例化（src/*.tscn）
~/.local/bin/godot --headless res://tests/test_monkey.tscn       # 随机操作不变量（MONKEY_STEPS / MONKEY_SEED 可调）
~/.local/bin/godot --headless res://tests/smoke_test.tscn        # 场景集成冒烟测试
~/.local/bin/godot --audio-driver Dummy --windowed --position -32000,-32000 res://tests/screenshot.tscn  # 屏外静默截图（不弹窗/不抢焦点）→ /tmp/shot_*.png

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
9. **UI / 输入改动必须过"按键流"**：新增或修改覆盖层、快捷键、界面开关时，必须在 `tests/test_input_flow.tscn` 补用例——用**真实按键/鼠标事件**驱动（只调 `open()/close()` 的伪测试测不到按键路由 bug）。覆盖层开关契约见 `docs/ARCHITECTURE.md` §5（有覆盖层 ⇔ 暂停、B/P/ESC 逐层返回）。
10. **底层逻辑改动必须进机器检查**：
    - 新增存档字段 / 改加载逻辑 → 在 `tests/test_save_compat.gd` 补"缺该字段的老档"与脏档用例；
    - 新增场景 → `tests/test_scenes` 自动覆盖；新增脚本 → 编译检查自动覆盖；
    - 新增"任何时刻都应成立"的规则（资源非负、目标一致、不可入墙…）→ 加进 `tests/test_monkey.gd` 的 `_check_invariants`；
    - **测试输出必须干净**：引擎输出里出现 `ERROR/WARNING/泄漏/非法访问` 会让 verify 失败；禁止随意往允许清单里加行，加行必须写明理由。

## 4. 任务认领协议（多窗口并行）

1. 打开 `docs/ROADMAP.md`，从「待办」选一条任务，改成 `🚧 进行中｜<窗口/人>｜<日期>` 再动手。
2. 一次只做一条主线；中途想加别的，先回看板记一行。
3. 完成后：跑 `tools/verify.sh` → 更新 CHANGELOG / README → 任务标 `✅ 完成`（保留记录，不要删除条目）。
4. 发现引入的 bug 但暂时不修？记入 ROADMAP「已知问题」。
5. **跨窗口通信（2026-11-21）**：按 `docs/AGENT_LINK.md` 使用 `tools/agent_link.py`，agentchattr `#thief`为唯一协作频道。新桥已绑定art/plan/test/code；同一角色只能一个唤醒负责人，不同时重启旧chat_relay/外部agent-bridge。收到任务先确认ID/负责人/文件归属，再执行并回报证据；submitted不等于完成。Codex当前应用窗口仅read/watch；原生Claude Code通过join_claude_chat.sh续接后才能自动唤醒，不能将其误绑旧opencode-a。不能通过等待器进程退出就推断所有宿主都会自动唤醒。

**Claude Code紧预算**：用户报告剩余约2美元。默认待命、不广播唤醒、不承担全仓阅读/轮询/全量测试；只在其他窗口无法替代时分配一个简短明确任务。调度要求见docs/AGENT_LINK.md，不能声称桥能强制计费上限。

## 5. 完成定义（DoD）

- [ ] `tools/verify.sh` 全绿（含新增测试）
- [ ] 涉及 UI/输入 → `tests/test_input_flow.tscn` 有对应用例且通过（新覆盖层/新快捷键必须补）
- [ ] 涉及存档/场景/规则 → `test_save_compat` / `test_scenes` / `test_monkey` 对应覆盖已更新
- [ ] 涉及画面 → `tools/verify.sh --visual` 视觉回归通过（预期改动已 `--update` 基线并人眼确认）
- [ ] 收尾手动过一遍 `docs/MANUAL_QA.md`（约 2 分钟）
- [ ] `CHANGELOG.md` 顶部新增条目（版本号 + 日期 + 新增/修改/修复/测试）
- [ ] `README.md`「开发进度」与 `docs/ROADMAP.md` 状态已同步
- [ ] 架构/决策有变 → 更新 `docs/ARCHITECTURE.md` / `docs/DECISIONS.md`

## 6. 已知坑（快速提示）

- Godot 4.7：`*.uid` 文件要提交；`.godot/`（导入缓存）不提交。
- 测试把存档隔离到 `/tmp`（`Game.save_path`）；冒烟测试退出前必须 `Audio.shutdown()`，否则出现"假泄漏"告警。
- `mission_complete` 仍由实际携带目标推导，不能为普通侦察撤离强行设true。新探索方案需区分侦察撤离/主目标带回/放弃，旧“没目标就锁唯一出口”只保留教学等明确要求，不得沿用到大馆侦察。当前代码迁移仍待R-13。
- 平行感知按房间分流：噪音只影响同房间的警察（幽灵哀嚎为废弃设计，不得恢复）（`room_index_at`）。
- `--check-only --script` 对引用 autoload 的脚本会误报，不要用它做语法检查；用 `tests/test_scripts.tscn`。

## 7. 文档地图

```
AGENTS.md                 本文件：规则、命令、协作协议（每次会话自动加载）
docs/EXPLORATION_LOOP.md 多次探索/迷雾/侦察撤离/采购与经济（11-19新方向）
docs/CONFIRMED_DESIGN.md  当前用户确认方案（开工必读，旧设计冲突时以此为准）
GDD.md                   当前设计摘要
docs/ARCHITECTURE.md      架构地图、数据流、不变量、改造配方（Recipes）
docs/ROADMAP.md           任务板：里程碑、待办、已知问题（认领处）
docs/DECISIONS.md         决策记录（ADR-lite）：为什么这样做，防止无意推翻
docs/SOURCES.md           史料来源登记：真实文物与演绎分界（学术硬要求）
docs/MANUAL_QA.md         手动 QA 清单：机器测不到的观感/手感/音频/历史表述
CHANGELOG.md / README.md  版本轨迹与项目说明
tools/verify.sh           一键验证入口
```
