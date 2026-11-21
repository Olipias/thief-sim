# 更新日志（Changelog）

本项目所有版本更迭记录于此，方便回顾改了什么、为什么改。
版本号规则（原型期）：**v0.x.0** = 一批新功能，**v0.x.y** = 修复或杂项。

---

## [v0.26.5] - 2026-11-21

### 修复
- 共享预演/执行内核的噪音调查应用真实房间边界，避免半径内的隔壁展厅噪音引来守卫；单房灰盒无回调时保持原行为。

### 测试
- 新增跨房间排除、同房间来源选择与无上下文灰盒回归；修复前 3 项失败，修复后模拟专项 42/42 通过。
- 隔离目录全量验证实际 17 项通过、2 项失败：在途的大英拾取规则与电脑推理板输入用例，已交对应负责人修复，不宣称全绿。证据见 docs/qa/goal_supervision_2026-11-21/noise/。

---

## [v0.26.4] - 2026-11-21

### 新增（R-12a 采购/备货配装，G20261121-01.1）
- **手机采购 App**（安全屋应用首页新增）：商品卡写明消耗品/永久装备、实际效果、价格——烟雾弹（消耗品 120 金，近距离脱身）、跑鞋（永久装备，价格以 `Game.UPGRADES` 为准，当前 400 金；疾跑速度提升）；按 `can_buy` 门禁（无钱禁用），已拥有装备不再上架。一次点击一次扣款一次发货（连点两次 = 两件两笔）。
- **库存与携带分离**：购买入备货 `smoke_stock`（存档只增字段，老档默认 0、脏值/负数按 0）；出发（穿过房门 `start_mission`）时备货并入携带 `smoke_count` 并清空——馆内 Q 消耗只动携带数。局内禁采购（行动中手机无采购入口）。
- **无钱仍能继续**：采购页明示基础调查与地图记录免费；无强制消费。
- **回放不倒退局外购物**：购买即时落盘，museum 回放/失败恢复只回滚世界快照，不触碰备货/金币（progression 用例覆盖读档一致性）。

### 修改
- `tests/test_logic.gd` 旧购买断言按新语义替换（buy→备货→装载→消耗），覆盖范围不减少。
- `reserve_loot` 对齐 test_progression 新契约：同一 id 预约数不得超过箱内存量（重复预约拒绝）。

### 测试
- 输入流 **306 项**（新增采购页/连点扣款/禁用门禁/出发装载/HUD 计数）；进度 **100 项**（新增 R-12a 采购/装载/读档一致性 13 项）；存档兼容 **116 项**（smoke_stock 4 组）；逻辑 2552；`tools/verify.sh` **19 项全绿**。

---

## [v0.26.3] - 2026-11-21

### 修复
- 回退保留玩家/守卫/物品/烟雾的精确世界位置与原始AI计时，不将物理起点取整到格心；斜向守卫朝向不再被整数截断为水平。
- 每tick同步真实守卫的巡逻、警觉、调查、等待与致盲状态，执行结束/人工接管后继续当前AI状态。
- 手动潜入有初始重试快照，结束执行不清空合法重试起点；回退覆盖磁盘背包/消耗品，避免重开取回已回滚收益。

### 测试
- 新增并挂入verify的test_snapshot_handoff：25项通过，含非轴向视锥、精确状态、磁盘回滚、局外钱包不变、结束后重试；独立test_museum_sim已补完整回退用例52项通过。本轮独立临时目录tools/verify.sh全部19项通过，日志snapshot/verify19.log；未声明新采购/电脑或完整项目通过。

## [v0.26.2] - 2026-11-21

### 修复
- Codex按test复现补齐规划迷雾门禁：新增与拖动节点共用已探分区/可走检查，共用_add_plan_point拒绝未知区域，防借路点探索隐藏地图。
- 实际run_preview与轨迹重放接入真实碰撞/视线/同房间上下文，消除预演漏参而实际执行有墙体检查的规则差异。

### 测试
- test_exploration新增隐藏区点击回归由失败转34/34通过，真实场景模拟43/43保持通过；test继续补真实输入与拖动用例。证据docs/qa/goal_supervision_2026-11-21/；本轮全量17项通过/1项失败（R-12a在途备货语义使逻辑购买烟雾旧断言2项失败），日志已交code修正契约测试；不宣称预演全部验收完成。

## [v0.26.1] - 2026-11-21

### 修复（R-11a 小地图信息泄漏，test #650/#659 报告）
- **`src/ui/minimap.gd`**：`_draw` 只按 `visited_rooms`（+当前房间）计算与绘制房间框——未探房间不再画框/占位；`target_room` 黄色标记与 `exit_room` 绿色标记**只在对应房间已被踏入后**显示，不再无条件泄露主目标与出口位置。新增 `known_room_indexes()` 供测试断言防回归。
- **`tests/smoke_test.gd`** `_test_minimap` 增加「未探房间不得出现在已知集合」断言（R-11a 泄漏回归守卫）。

### 测试
- 冒烟 **184 项**全绿（+3 项小地图边界断言）；`tools/verify.sh` **18 项全绿**。

---

## [v0.26.0] - 2026-11-21

### 新增（R-05 文物箱与普通交易闭环）
- **文物箱随身↔箱内转移**：箱内行新增「取出」（取出即到随身；该 id 有预约额度时自动打 `reserved` 预约货标记），随身行新增「存入」（预约标记随货物回到箱内计数）。预约中的箱内行显示「已预约」，且不可走旧直售通道（防预约计数悬空）。
- **手机交易 App 预约/取消**：按 id 聚合显示件数/单价/已预约数；「预约一件 / 取消预约」实时变更——预约不扣货不发钱，买家到门外等待（无倒计时），货物留在箱内直到玩家取出。
- **门口交货确认面板**（`src/ui/delivery_screen.gd/.tscn` 新）：随身预约货清单+总金额，确认后**一次性**移除货物并收款；ESC 取消不结算。门口提示按随身内容分流（带预约货 → 「按 E 交货」）。
- **出发门禁叠加**：背包非空（含未存箱普通物）时门口 E 不得出发（防 `reset_run` 静默丢货），提示先存箱/交货或取消预约。
- 存档只增字段：`loot_reserved`（id→计数，老档缺省空、脏值/主目标/非法 id 拒绝）与 bag 条目 `reserved` 标记（老档缺省未预约）。

### 修改
- 交易契约对齐 test 预写的更强口径（test_progression R-05 用例）：主目标（含教学 mask）不可普通预约；交货只消耗随身预约标记，不清箱内剩余预约额度；预约中的箱内物品禁走 `sell_stash_item`，`sell_all_stash` 只卖未预约货。
- 修复 test_progression 的 `gs` 双重 `free()`（native double-free 中断整个套件）；test_save_compat `_test_dirty_pending_mission` 的折行修复。

### 测试
- 输入流 **285 项**（新增：取出/存回往返、预约→取出带标记→门口交货一次性收 120 金、取消不收钱、出发门禁拦截与提示）；进度 **77 项**（预约/交货/幂等/读档往返全过）；存档兼容 **111 项**；`tools/verify.sh` **18 项全绿**。

---

## [v0.25.6] - 2026-11-21

### 修复
- 修复 `src/world/museum.gd` 迷雾函数的数组类型推断错误，恢复脚本编译。
- 移除进入安全屋时残留的 `unlock_all_chains_required = true`，玩家不再被「三条调查链全完成」旧门槛阻塞。
- 修复 `src/main.gd` 中 `escaped` 信号通过 lambda 连接，避免 `bind` 参数顺序导致执行参数错配。
- 修复 `src/autoload/game_state.gd`：`place_item` 与 `_restore_bag` 现在保留普通战利品的 `instance_id`，确保跨次反刷与侦察撤离结算能正确记录已带出的实例。
- 修复 `tests/test_save_compat.gd` 函数定义与语句挤在同一行的解析错误。

### 新增
- `tests/test_exploration.gd` / `.tscn`：R-11a / R-13a 探索循环验收，覆盖房间迷雾揭示、跨次已探房间保留、侦察撤离（`OUTCOME_RECON`）把普通战利品移入 stash 并记录 instance_id、重进关卡不再刷新已售实例、新游戏清空跨次记录。
- `src/autoload/game_state.gd` 新增 `pending_mission_changed` 信号；`src/ui/hud.gd` 跟随待出发状态更新行动栏，显示「已确认：关卡名」。

### 修改
- `src/world/museum.gd`：计划执行结束后不再清空 `_sim_snapshot`，使失败回退与测试能读取最终 tick 事件与状态。
- `src/autoload/game_state.gd`：`reset_progress()` 现在同时清空 `level_visited_rooms` 与 `level_taken_items`，避免新游戏继承旧探索记录。
- `tests/test_input_flow.gd`：适配 R-04 新手机应用首页与委托页，为大英博物馆房门出发用例跳过前置剧情，补齐 HUD「已确认」断言。
- `tools/verify.sh`：新增「探索循环自检」步骤。

### 测试
- `tests/test_museum_sim.gd` hardened：从 24 项扩展到 43 项，新增执行事件与发现归因对比、完整 trace 重叠检查、守卫隐藏计时字段覆盖。
- `tools/verify.sh --fast` 16 项全绿；`tools/verify.sh --visual` 20 项全绿，43 张视觉基线已按最新 noir/陈设/展柜高光更新。
- 证据归档：`docs/qa/batch_blocker_r02b_r13a_2026-11-21/`。

---

## [v0.25.5] - 2026-11-21

### 新增（R-04 手机应用与实体电脑）
- **手机应用首页（安全屋模式）**：`mission_phone.gd` 以 2×2 应用图标进入 委托 / 交易 / 联系人 / 日历（不复刻旧 Hub 栏目页）；行动中保持旧「任务 / 档案」标签布局。交易页为箱内战利品报价只读展示（预约/门口交货待 R-05）。
- **委托 App「准备出发」**：列出可行动关卡（Game.LEVELS），确认/取消待出发状态；确认只记录 `Game.pending_mission_level`，关闭手机仍留在房间。
- **房门出发门禁**：安全屋房门 E 只放行已确认行动（未确认弹提示不切场景）；出发消费准备状态。HUD 行动栏跟随 `Game.pending_mission_changed`（未确认时显示「行动未确认」）。

### 修改
- **存档只增字段** `pending_mission_level`：老档缺省 / 脏类型 / 非法关卡 id 一律视为未准备；合法值保留（`tests/test_save_compat.gd` 新增 4 组用例）。`reset_progress()` 一并清空。
- `tests/test_input_flow.gd`：安全屋房门用例改为完整门禁流（未确认 E 不切场景 + 手机确认 → 出发消费）；新增交易页断言；`tests/smoke_test.gd` `_fill_task` 更名 `_fill_task_briefing`。
- HUD `toast()` 新增 `toast_requested` 信号（测试/协作观察用）。

### 测试
- 输入流目标 **252 项**、冒烟 **182 项**、`tools/verify.sh` 目标全绿；本批实现时并行修复尚未落地，实际全绿见 v0.25.6。

---

## [v0.25.4] - 2026-11-21

### 修复
- Claude聊天室续接固定项目工作目录；默认通过本地最近会话ID恢复，传--no-restart避免退出后循环；支持dry-run/list/picker，不改变外部agentchattr全局配置。

### 测试
- bash语法、3项专项与本机dry-run通过；没有启动Claude或发送模型请求，真实交互续接待用户终端验证。全量回归在输入流被并行tests/test_input_flow.gd:500的Signal.clear解析错误阻断，读取步骤日志后停止，未声明全绿；证据docs/qa/claude_resume_2026-11-21/。

## [v0.25.3] - 2026-11-21

### 新增
- tools/agent_link.py：agentchattr身份注册、读写、点名等待、精确OpenCode会话绑定、SQLite持久投递、失败重试/突发合并、后台start/stop/status与独立回执；本机配置和令牌不入库。
- tools/join_claude_chat.sh：复用agentchattr原生包装器，通过--resume续接Claude Code；当前运行窗口不强行注入，续接后才可验证其自动点名。
- docs/AGENT_LINK.md：四角色协作、文件归属/修复交接、监督证据、旧桥防重复和Codex应用窗口read/watch边界。

### 测试
- 离线专项7项通过；现场消息602已发送，art在605明确回复并提供任务/文件归属。其余角色与原生Claude的逐项结果后续据实追加；API submitted不冒充已处理。
- tools/verify.sh：16项通过/1项失败，输入流“文物箱：走近按E打开箱界面”失败；冒烟182项通过。并行游戏代码不由本批覆盖，已通过聊天请求负责窗口复核；证据docs/qa/agent_link_2026-11-21/。

## [v0.25.2] - 2026-11-21

### 新增
- C1 安全屋 noir 瓦片：地板取 `home_floor_16` 前两格交替，围墙用 `home_wall_16`，紧贴室内的顶/底行用 `home_trim_16`。
- C2 陈设：书架（顶墙右侧）、柜子（底墙左侧）、洗衣篮（右下角）带体积碰撞；左右墙各挂一盏灯笼（暖光，无阴影）。均不压电脑/文物箱/房门/出生点。
- C3 Room 3 展柜叠 `case_glass_highlight`（展柜子节点，z_index 1，alpha 0.5±0.12，3.5 秒呼吸；纯画面，不进守卫视锥/噪音判定）。高光细斜纹会轻微掠过文物，主体仍清晰。

### 测试
- smoke 增加陈设不压关键点（4px 余量）、两盏灯笼、展柜高光存在断言（182 项）。
- 视觉基线更新，原因：安全屋换 noir 墙地与陈设；Room 3 展柜出现玻璃高光。

### 待办
- C4 墙灯投影（依赖 T3 遮光体，T3 已完成）。

## [v0.25.1] - 2026-11-20

### 修改
- R-02b 执行态位置同步进一步加固：`src/world/museum.gd` 的 `_apply_sim_state` 现在直接把玩家 `global_position` 钉到内核算出的像素坐标；`src/actors/player.gd` 在 `sim_driven` 模式下将速度置零，仅保留朝向动画，杜绝 `move_and_slide` 在极端帧序下把玩家滑出地图的残余窗口。
- 移除排查 monkey 用的临时 `DEBUG` 输出。

### 测试
- `tools/verify.sh --fast` 15 项全绿；`tools/verify.sh --visual` 19 项全绿（43 张截图）；`test_monkey.tscn` 600 步随机操作通过（seed=20261020）。
- R-02b 证据日志已刷新：`docs/qa/batch_a_r02b_2026-11-20/`。

## [v0.25.0] - 2026-11-20

### 新增（R-01 独立安全屋与场景骨架）
- **`src/world/safehouse.gd` / `safehouse.tscn`（新）**：可走动的俯视角室内世界场景（挂 `Screen` 世界层，不进 CanvasLayer）——20×11 格房间、墙体/书桌/文物箱碰撞、夜色暖光氛围、单间相机限位；书桌电脑 / 文物箱 / 房门三处 E 交互（`sh_computer` / `sh_box` / `sh_door`，带提示与交互冷却），把设备请求交给 Main 打开覆盖层。
- **`src/ui/computer_screen.gd` / `.tscn`（新）**：书桌电脑覆盖层（契约同背包/手机：open ⇔ 暂停、P/B/ESC 关闭、process_mode=3）。R-01 为骨架页：显示当前行动与三主目标，完整调查界面待 R-03/R-04/E 批接入。
- **`src/ui/box_screen.gd` / `.tscn`（新）**：文物箱覆盖层，左右分「随身携带 / 箱内存放」；箱内普通战利品暂可直售（旧据点「销赃」页的过渡替代，保持经济闭环；R-05 接入手机预约→门口交货后移除）。

### 修改
- **`src/main.gd`**：正式流程全部改走 `show_safehouse()`——标题「继续游戏」、城西教学撤离、失败结算返回、结局返回都不再进入旧 Hub 栏目页；`show_menu()` 删除（旧 Hub 场景文件保留，供推理板内容测试当独立宿主）。安全屋新增电脑/文物箱/房门信号接线与设备覆盖层开关；设备覆盖层打开时拦截 main 的 B/P 轮询，避免同帧穿透。
- **安全屋手机改为暂停世界**：安全屋现在是可走动的真实世界，手机作为覆盖层打开时同样暂停（旧「据点手机不暂停」约定只适用于无活动世界的纯 UI 时代）。
- **`tests/screenshot.gd`**：hub/销赃页截图改为安全屋/文物箱/电脑覆盖截图（`shot_safehouse` / `shot_box` / `shot_computer`），推理板截图改用独立 Hub 宿主。
- **`src/world/museum.gd`**：关卡入口相机 `reset_smoothing()`——修复从安全屋进入关卡时相机从上一场景位置滑入的问题（预演/执行截图因此从画面中段取帧，视觉基线已随新语义更新）。
- **`src/world/museum.gd`（执行瞬态修复）**：`execute_plan()` 进入执行态时先把 `player.sim_target_pos` 钉在快照位置并清空 `sim_dir`——修复 sim 驱动首帧仍按残留目标瞬移（首次执行时为 `(0,0)`，正好在墙格内，去穿透把玩家顶出地图至 `(-4, 0)`）导致 monkey 不变量报「玩家进入实心格 (0,0)」的瞬态窗口（v0.23.4 登记的已知问题即此根因，seed=20261020/20261021 复现均消除）。

### 测试
- **`tests/test_input_flow.gd`**：新增安全屋真实按键用例——教学撤离直连安全屋、走动碰撞（顶墙/家具不穿透、走动不误开设备）、电脑/文物箱开关与暂停契约、设备开着时 P 不穿透、房门出发切关、箱内直售结清、安全屋手机（打开即暂停、开着不能走路、档案页隐藏）、P-01/H-01 安全屋入场剧情；合计 **235 项全绿**。
- **`tests/smoke_test.gd`**：新增 `_test_safehouse_scene`（玩家/相机/三交互点/Node2D 世界层断言），冒烟 **179 项全绿**。
- `tools/verify.sh` 全量 **16 项通过**（含 monkey seed=20261020/20261021 各 600 步）；`tools/verify.sh --visual` 43 张基线全绿（hub/销赃基线退役，新增 safehouse/box/computer 三张，其余为背景上下文与相机入场语义变化，已逐张人眼确认）。

---

## [v0.24.1] - 2026-11-20

### 新增（V-01 博物馆视觉升级 T3–T6）

- **新增**：大英博物馆墙/展柜 `LightOccluder2D`（同行合并，无碰撞，壁灯/文物格除外）与主灯 `shadow_enabled`；六厅 `BM_ROOM_TINTS` 色温表，切房间指数插值，开场直接落起始房间；警察视锥顶点渐变（判定轮廓线不变）；其余五厅小量 `CPUParticles2D` 尘埃；玩家/警察脚底接触阴影（`src/world/contact_shadow.gd`，程序绘制）。
- **新增（素材可选）**：T1 墙裙/地面磨损、T2 六厅主题装饰的接入代码。素材文件存在才启用，缺失时零影响；变体按（房间,格坐标）固定哈希选取，无随机。墙裙假定图集第 0 行为踢脚线变体、装饰每厅挂 3 件（贴北墙空地，避开展台/文物/灯/出口）。已用临时占位图验证挂载有效，随后删除。
- **素材已接入（2026-11-20 真素材）**：墙裙实测第 1 列（索引 1/5/9/13）是底边踢脚线条，已用；地面磨损每格带不透明格线，叠上去像深色方块，已用 `BM_FLOOR_WEAR_ENABLED=false` 关闭，待 art 重做无框/透明版；六厅装饰已启用（每厅 3 件）。基线更新原因：墙底踢脚线条与六厅装饰。
- **未做**：T7 素材未交付。
- **测试**：smoke 增加遮光体/接触阴影/灯阴影/色温表断言（179 项通过）；视觉基线 bm_both/room0/1/2/3/5/zun 更新，原因：视锥渐变、接触阴影、色温差异、尘埃，差异 2.6–3.0%。
- **已知**：`test_monkey` seed=20261020 第 400 步“执行路线时玩家进入实心格”失败，关掉本批全部改动后仍复现，疑为工作区其他未提交改动，未处理。→ 已在 v0.25.0 修复（见下）。

## [v0.24.0] - 2026-11-20

### 新增
- R-02b 真实场景确定性执行：Museum 从同一起始快照驱动玩家、全部守卫、监控、装饰时间；执行期间禁用警察 AI，避免渲染帧率与随机偏移影响结果。
- 规划节点动作循环：点击已选节点切换 wait/crouch/stand/unlock/take/sprint，非法 unlock/take 给出 toast 反馈。
- 完整快照回退 `_restore_full_snapshot`：还原玩家、全部守卫状态与计时、监控相位、门锁、物品、背包、烟雾与消耗量；失败回退 `_rewind_and_replan` 保留原路线与节点动作。
- 新增 `tests/test_museum_sim.gd` / `.tscn`：在真实 Museum 场景中对比预览 trace 与执行 trace，覆盖安全路线、守卫视野、墙体遮挡、监控摄像头、噪音调查、拿取动作、完整快照回退。

### 修改
- `src/sim/sim_preview.gd` 扩展为多守卫 / 多监控 / 完整快照内核，内建 `in_cone`，修复 `take` 进度与事件触发；`crouch/sprint/stand` 视为移动模式。
- `src/world/museum.gd` 的 `_planned_sim_route` 把移动模式动作绑定到移动段，到达后动作单独成节点。
- `tests/test_input_flow.gd` 适配新执行语义：执行完成才恢复守卫 AI、失败回退保留路线、重试场景把玩家放回安全角。
- `tools/verify.sh` 加入 `tests/test_museum_sim.tscn` 步骤。

### 测试
- `tools/verify.sh --fast` 15 项全绿；`tests/test_sim_preview.gd` 38/38；`tests/test_museum_sim.tscn` 24/24；`tests/test_input_flow.tscn` 235/235。
- 证据与日志归档 `docs/qa/batch_a_r02b_2026-11-20/`。

## [v0.23.6] - 2026-11-20

### 新增
- OpenCode后续开发执行计划：A–G分批工作、可观察验收、测试证据与四级交付标准；明确真实关卡预演双路径、简化快照和清空路线回退仍需补齐。

### 修改
- plan.md转为当前计划入口，旧课堂内容标为历史；ROADMAP补R-02b，README同步开发交接。仅文档，不修改游戏代码或资源。

### 测试
- tools/verify.sh全部16项通过；文档链接/版本检查及git diff --check通过，日志docs/qa/next_plan_2026-11-20.log。本批仅文档，未跑视觉或新玩法手测，新增玩法未实施、不声明通过。

## [v0.23.5] - 2026-11-19

### 新增
- docs/EXPLORATION_LOOP.md：固定展馆、房间迷雾、局部布展情报、跨次调查、侦察撤离与局外采购循环；先小样板验证再扩展，不靠强制趟数制造内容量。
- 剧情探索补丁V2与后续验收表：用文字档案起步、实地观察补图，允许只推进一条主目标；列明旧稿替换位置和真实输入/存档/经济检查。

### 修改
- 确认方案、GDD、agent入口、架构与D-035同步；ROADMAP新增R-11~R-13待办。已带出普通物品按实例防重刷、无钱仍有通路；保留箱子预约交易、确定性预演与世界全冻结。
- 仅同步设计文档，不改运行代码、生成地图、素材或发布包；10–12区域与2–4趟仅为可调初始目标。

### 测试
- tools/verify.sh全部16项通过，git diff --check与文档链接检查通过；原始日志docs/qa/exploration_plan_2026-11-19.log。仅文档变动未跑视觉/新玩法手测；新方案条目全部待实现，不把现有回归通过当成新玩法验收。

## [v0.23.4] - 2026-11-19

### 新增
- docs/narrative/剧情初稿：完整契约/教学/住处/三条调查/潜入/交付分支/普通交易对白；三组各七张线索、关系选择、错误反馈与可选阅读，供用户审阅和后续接入。
- 按本机stop-slop与上游Humanizer-zh完成文字自审；历史字段逐段映射原始馆藏与研究，羊角接合、同类心脏圣甲虫用途、注壶侧嘴/西屋进入调查判断。BM页面403与旧字段待复核据实登记。

### 修改
- 按用户最新要求，完整声明与来源统一放标题“声明”，正篇不重复创作标签、片尾不强制再弹整段声明；同步确认方案、内容流程、GDD与agent入口，作者F/U/X元数据仍保留。
- 文本稿不再在教学后重复派面具任务，不恢复器灵或主要文物出售；死亡代价等具体新写法待用户审阅。

### 测试
- 文稿结构与长度检查通过：三组各7张唯一线索、连线端点完整、149条独立对白最长30字符；文档检查/git diff --check通过，tools/verify.sh 16项全绿。
- 本批仅文本稿与规范，未替换运行时数据、未重导出试玩包，不把旧测试通过当作新稿已实现或真人学习效果达标。

## [v0.23.3] - 2026-11-18

### 修复
- 修复空格执行只恢复玩家、守卫仍被规划冻结，方向键接管后可永久绕过守卫的漏洞。规划/执行/接管/到点完成/失败回放/结束共用Museum._sync_world_freeze。
- 守卫world_frozen与剧情/截图ai_enabled分离；规划保留巡逻、警觉和致盲计时。暂停世界子节点时保留物理碰撞，避免同步发现回调中移除物理体造成非法访问。
- 手动接管优先于物理帧的到点推进；关闭手机不会解除规划冻结，取消路线使旧预测失效。

### 测试
- 新增真实输入冻结回归：修复前26项有3项失败；覆盖WASD/方向键/E/Q、覆盖层、空格执行、方向键/E接管、路线完成、反复切换、真实守卫发现与重试。测试不预先禁用守卫AI。
- 守卫冻结纯逻辑、监控恢复、物理空间与monkey不变量通过；专项30/30，逻辑2549、完整输入210、冒烟166、monkey600步，tools/verify.sh --visual 18项/42张全绿。
- 导出独立v0.23.3 Windows/Linux包，保留旧包；Linux解压后以Xvfb/XTest原生窗口键鼠和截图验证7/7通过，Windows未实机测试。运行资源哈希与包SHA256已登记，详见TEST与docs/qa/PLANNING_FREEZE_FIX.md。

## [v0.23.2] - 2026-11-18

### 新增
- 课堂Loop 1材料：goal.md目标声明、真实聊天摘录、离线三页展示、agent生成的项目SVG与Mermaid源图、约50秒逐句讲稿。

### 修改
- plan.md与课堂RUNBOOK增加材料入口；结构图区分已有代码模块与待实现安全屋/设备/交易，明确目标文件不冒充/goal工具记录。

### 测试
- Chromium离线模式下真实点击与左右按键检查通过，三页SVG加载正常、无横向溢出/JS异常，截图目视确认；文档检查与git diff --check通过，tools/verify.sh 16项全绿。不修改游戏逻辑、存档与游戏画面。

## [v0.23.1] - 2026-11-18

### 新增
- 标题界面改为居中集中菜单，使用用户指定封面 `assets/art/CPy0UzlakIPj0kfwMuVCR.png`；移除旧屋顶/入口场景化按钮布局。

### 修改
- 规划模式世界冻结：进入/退出规划不再调用 `_enter_patrol()` 重置守卫巡逻索引；规划期间暂停 `_animate_bm_decor`、`_check_camera_detection` 与世界计时，避免"玩家能动、警察定住"的子弹时间。

### 修复
- 修复 `toggle_planning_mode(false)` 退出规划时守卫巡逻状态被复位的问题；守卫新增 `set_frozen()` 用于规划冻结，与剧情截图用的 `set_ai_enabled()` 区分。
- 修复标题界面冒烟测试仍引用旧 `primary_hint` 与屋顶布局的问题；修复输入流中收集册按钮路径与 headless 鼠标路由偶发吞点击的问题。

### 构建
- 重新导出课堂桌面包到 `build/class-demo/`，旧顶层 `build/thief-sim-{linux,windows,web}.zip` 已删除。
- Linux 包 `thief-sim-class-demo-linux.zip` SHA256 `6b0d60dd686cc4f4…`，Windows 包 `thief-sim-class-demo-windows.zip` SHA256 `e0185b6104d015ec…`；Linux 解压后 `--headless --quit-after 8` 启动验证通过。

### 课堂材料
- Loop 1 展示页 `docs/demo/loop1/index.html` 已补第四页「Agent 协作进展」，通过 `agentchattr` 读取 `#thief` 真实历史消息整理多 agent 设计决策与交付批次；对应 `docs/demo/loop1/agent_progress.md` 与讲稿已同步。

### 测试
- `tools/verify.sh --visual` 18 项全绿；标题截图基线已更新。
- `tests/test_input_flow.gd` 179 项通过，`tests/smoke_test.gd` 156 项通过。

## [v0.23.0] - 2026-11-18

### 新增
- 用户指定q6六格分镜补四个短对白，保留原图；派生图、完整imagegen提示词与OpenCode交接均在docs/art_direction/storyboard/。
- OpeningCG集中定义画面区域、标题、字幕和时长；tools/import_opening_cg.py导入实际运行位图，不依赖导出包中的docs目录。

### 修改
- ContractIntro改为真实图片逐格播放，每格5秒自动推进；Space/E/左键立即推进并重置计时，右上角Skip和自然结束均直接教学。以最新用户要求取代旧8×18秒占位演出。
- 同步确认方案、GDD、架构、决策、AGENTS与项目技能，明确已实现的开场子项和其他待实现任务。

### 修复
- 忽略长按键echo及同帧重复推进；结束信号只发一次，Main在CG期间阻止背包/手机输入；分镜多边形裁切避开邻格并完整保留对白。

### 测试
- 新增真实Space/E/鼠标/Skip输入与自动结束教学衔接用例，独立开场测试复用同一输入流；内容校验和结束幂等冒烟覆盖。
- 六格游戏截图已目视确认，仅更新七张开场视觉基线。自动播完实测29.933秒。全量门禁结果与既有标题改动失败见TEST.md和开场交接，不宣称全部全绿或真人验收完成。

## [v0.22.7] - 2026-11-18

### 新增（开场动画分镜 · Excalidraw 绘制，用户指定由 art/plan 用 Excalidraw 产出）
- **Excalidraw 分镜画布**（97 元素）：8 格分镜对应 `ContractIntro.PANELS`——雨夜屋顶（雨线+屋顶剪影）、旧匣封印（匣盖裂纹）、倒影访客（双重轮廓：灰=我 / 红=恶魔）、契约条件（契约纸+恶魔带角轮廓）、手印代价（指纹浮现）、问题沉默（烫痕红光）、指令面具（青铜面具剪影+展柜+金绿目纹）、黎明前出发（街道熄灯：亮灯渐灭 + 教学键位标签）；格间推进箭头、底部风格/跳过/来源三行注记。
- **导出**：`docs/art_direction/opening_storyboard_excalidraw.png`（3539×1865，2×，PNG 内嵌可编辑场景）与 `opening_storyboard_excalidraw.svg`（矢量）。
- 对应交付对象：`art`（本用户指定的 Excalidraw 分镜）；正式像素 CG 仍按 `docs/art_direction/OPENING_CODEX_BRIEF.md` 由 codex 产出。

### 测试
- 纯美术资产，不涉及运行代码；`get_canvas_screenshot` 人眼核对通过（8 格布局/台词/注记完整）。

## [v0.22.6] - 2026-11-18

### 新增（课堂自动化与演示入口，plan.md 阶段 C）
- **pytest 套件（`tests/demo/`）**：
  - `test_logic.py`：subprocess 驱动**真实 Godot 测试**（test_logic / test_content / test_save_compat / test_progression / test_sim_preview / test_input_flow），断言退出码 0、无引擎错误（verify.sh 同款白名单）、关键断言文本；并源码级校验「预演/执行共用同一 tick 内核、零随机数、无真实场景函数混入」。
  - `test_history.py`：史料「据 / 推断 / 设 / 未核实」边界——evidence.gd 线索三层分类、1936 入藏不得推导 1860 被掠、圣甲虫不得写成大英实藏、注壶未核实项明示、无民族主义断言、声明页覆盖四件文物。
- **`docs/demo/RUNBOOK.md`**：现场命令（pytest 短套件 / 原生输入流 / 完整验证 / 桌面包位置）、三个演示点、故障排查。
- **依赖**：`requirements-demo.txt`（pytest>=8,<10；pytest 装在 `tools/demo_lib/`，PYTHONPATH 引入，无需系统安装；`tools/demo_lib/` 已 gitignore 不入库）。

### 修改
- **`tests/test_sim_preview.gd` / `tests/test_input_flow.gd`**：全绿时打印逐行 `PASS - <断言>` 摘要（供 pytest 驱动器与课堂演示核对覆盖；失败仍仅打 FAIL 行）。
- **`tests/test_sim_preview.gd`**：`_risky_route` 改为守卫在远处巡逻、玩家走进巡逻半径被发现（预演/执行 23 tick 逐 tick 一致，提升覆盖长度）。

### 测试
- pytest 套件：`tests/demo/` 全部通过（test_logic 13 项 / test_history 11 项，含真实 Godot 子进程套件）。
- `tools/verify.sh --fast` 14 项全绿（test_input_flow 摘要打印不影响断言）。

## [v0.22.5] - 2026-11-18

### 新增（课堂桌面包交付，plan.md 阶段 A/D）
- **`tools/export.sh`**：改为默认导出 **Windows + Linux 桌面包到 `build/class-demo/`**（独立目录，不覆盖旧 web/windows/linux 产物）；`--with-web` 可选保留 Web 导出。Windows/Linux 目录内附**中文试玩说明 README.txt**（新操作键位 Tab 规划/Enter 预演/空格执行/失败回放、3–5 分钟试玩任务、已知限制、SmartScreen 提示），导出后自动输出 zip 与 SHA256。
- **干净目录验证**：`build/class-demo/thief-sim-class-demo-linux.zip` 解压到无源码目录，`chmod +x` 后 `--headless --quit-after 12` 启动正常（退出码 0，无引擎异常）；Linux exe SHA256 `4c803162021088489bde6d3b569736a064bc6a77b2cdb1e623f6e5cbb673faa4`（包 zip `fa611be38bc306d7…`，Windows zip `881fcfc44b070588…`，完整哈希见导出输出）。
- 朋友无需安装 Godot；用户用所选方式分发 zip。

### 测试
- 导出后未改代码；`tools/verify.sh --fast` 维持全绿（本批仅新增导出脚本与包产物）。

### 新增（课堂演示切片 V0-1：确定性预演接入真实关卡，plan.md 阶段 B）
- **`museum.gd`**：新增 `_build_sim_snapshot()`（真实守卫路点/玩家/监控枢轴 → SimPreview 格坐标快照）、`_planned_sim_route()`（规划节点 → 模拟路线）、`run_preview()`（调用 `SimPreview.simulate_route()` 预演并重放缓存每 tick 玩家/守卫轨迹与首次发现位置）、`_draw_preview_overlay()`（世界层绘制半透明玩家轨迹、守卫淡红残影、黄色首次发现预警脉动圈 + 「预演：约 X.Xs 后在此被发现」；无风险路线显示绿色提示）。
- **`project.godot`**：新增 `plan_preview` 输入 action（Enter 键）；规划模式下节点添加/移动实时自动重算预演。
- 预演与执行调用**同一实际内核**（`SimPreview.simulate_route()` 与一致性测试共用 `tick()`），满足 plan.md §2 要求；守卫巡逻随机偏移仅存在于真实执行，预演为确定性预测（差异在课堂上如实说明）。

### 测试
- `test_scripts` 42 脚本编译 / `test_scenes` 146 / `test_input_flow` 164 / `test_sim_preview` 34 / `tools/verify.sh --fast` 14 项全绿。

## [v0.22.3] - 2026-11-18

### 修改
- 按用户选择将plan.md改为桌面试玩：独立导出包、pytest与Godot原生输入/日志/截图自动化、两位好友下载试玩与回归；取消Cloudflare/公网部署和浏览器工具的前置依赖。
- 明确朋友无需安装Godot；保留老师公网URL和Playwright/MCP原文要求的未确认替代状态，不宣称已豁免或全部满足。

### 测试
- 仅计划文档修订，文档链接/版本格式与diff检查通过；未改代码、导出包或运行时测试。

## [v0.22.2] - 2026-11-18

### 新增
- 根目录plan.md：2026-11-19课堂四反馈闭环的OpenCode执行计划、最小可玩Web切片、pytest/Playwright/MCP、Cloudflare大文件部署风险、两位真实好友到回归证据链及5分钟演示脚本。

### 修改
- 将课堂公网链接与好友试用提前，明确Godot原生测试和静态介绍页不能替代课程要求；保留长期安全屋等任务，不在本轮计划编写中开发。

### 测试
- 文档链接/版本格式及diff检查通过；本批仅计划文档，未安装依赖、运行游戏测试、部署或生成好友反馈。

## [v0.22.1] - 2026-11-16

### 修复
- **`src/sim/sim_preview.gd`（R-02 复核修复）**：
  - 非门口位置执行 `unlock` 不再累计开锁进度，防止玩家在别处等待 40 tick 后门被错误解锁；只有 `player.pos == DOOR_POS` 时才推进 `unlock_progress` 并触发 `door_unlocked` 事件。
  - 守卫噪音调查结束后 `guard.alert` 正确回到 0：调查计时用尽即回巡逻态；若噪音提前消失，也立即从调查态切回巡逻态，避免永久停在 `alert = 1`。
  - `snapshot_summary` 增加 `wait_left` / `investigate_left` / `move_phase` / `target_taken`，提升逐 tick 状态可见性，便于后续调试与一致性问题定位。

### 测试
- `tests/test_sim_preview.gd` 原有 18 项 + test 补充的 16 项压力/边界用例 = **34 项全绿**。
- `tools/verify.sh --fast` **14 项全绿**。

---

## [v0.22.0] - 2026-11-16

### 新增（M1/R-02 确定性预演灰盒 · 首个可玩技术里程碑）
- **`src/sim/sim_preview.gd`（新）**：固定 tick（20/s）纯状态转换模拟内核——巡逻（walk→wait 循环）、监控摆动相位、噪音事件（带 ID/tick/位置/半径/来源与逐 tick 衰减）、发现判定（守卫距离判定与监控扇区，蹲下缩小半径 1）、玩家动作时间轴（移动/等待/蹲行/开锁 40t/拿取 20t，全部转整数 tick）。预演 `simulate_route` 与执行 `execute_route` **共用同一 tick 函数**，预演跑快照副本不污染源快照；事件流水（含首次发现 tick、原因实体）全程记录，无随机数、无执行偏移。
- **`tests/test_sim_preview.gd`（新，18 项）**：①同快照/同路线预演与执行逐 tick 摘要 100% 一致；②事件序列与首次发现 tick 一致；③重复执行/不同重放一致（帧率无关）；④失败恢复完整快照后重跑一致（含非零起始 tick）；⑤修改路线后预演/执行仍一致；⑥预演与执行均不污染源快照（规划全冻结）；⑦噪音触发守卫调查并朝源移动；⑧蹲下半径收缩（站立距离 4 发现、蹲下未发现）；⑨开锁 40 tick 解门；⑩拿取 20 tick 入包。
- `tools/verify.sh` 新增「确定性预演自检」步骤（`--fast` 14 项 / 默认 16 项 / `--visual` 18 项）。

### 测试
- `tests/test_sim_preview.gd` 18 项全绿；既有 `--fast` 全部保持通过（输入流 164、内容 555、场景 146、monkey 600、smoke 155）。

## [v0.21.4] - 2026-11-16

### 修改（按用户指令彻底移除闭馆倒计时）
- **`museum.gd`**：删除 `CLOSING_SECONDS` / `closing_remaining` / `_room_entry_seconds` / `_clock_label` 与闭馆倒计时推进、超时失败回放逻辑——风险回归为纯「守卫巡逻 + 视线 + 噪音」，用户可无限时长冷静规划与阅读。
- **`mission_phone.gd`**：任务页注意事项改为「规划（Tab）可看清守卫路线与监控扇区」，不再显示倒计时数值。
- **`main.gd` 简报**：老猫台词去掉「闭馆时间」提法，改为引导玩家用手机任务与电脑线索。
- **`test_monkey.gd`**：删除闭馆剩余时间合法范围不变量；**`test_input_flow.gd`**：删除规划暂停倒计时/执行推进/手机暂停/超时回放恢复等 8 条旧倒计时断言（163 项）。

### 修复
- 移除孤儿文件 `src/ui/main_menu.gd.uid`（对应脚本早已删除，无引用）。

### 测试
- `tools/verify.sh --visual`：17 项全绿；36 张基线已随手机任务页文案更新并经人眼确认（`shot_room3.png` 红色差异为已知守卫巡逻随机偏移的预测对比标记，非新缺陷）。

## [v0.21.3] - 2026-11-16

### 新增
- CONTENT_REVIEW：三主目标逐件核查起始表、教学身份缺口、事实ID映射、多方来源归因、虚构分界与恶魔独立审校。
- END_STATEMENT_V1固定声明文本规范及所有正常结局/跳过演出必经要求；运行时资源待实现。
- DETERMINISTIC_PREVIEW：固定tick、共享模拟内核/完整快照、逐tick一致性与准确失败归因，失败保留路线。

### 修改
- M0锁定具体件目和事实边界，埃及沿用已指定心形圣甲虫；M1首个可玩里程碑先做R-02确定性灰盒，再接安全屋，新增R-09/R-10核查与声明任务。
- 同步AGENTS、项目技能、GDD、架构、决策、SOURCES与验收；废除随机执行偏移，缺证据不强贴现实追索结论。

### 测试
- 仅同步文档，未改运行代码/素材/测试，也未宣称新史料核查或审校完成；链接/版本格式及diff检查通过，SHA256确认src/tests/assets/tools无变化；未重复运行运行时全量，已有守卫脱困失败仍待排查。

## [v0.21.2] - 2026-11-16

### 修改
- 登记用户指定封面 assets/art/CPy0UzlakIPj0kfwMuVCR.png，更新确认方案、GDD、agent入口、素材清单和R-07任务，状态由待提供改为已选定、待接入。
- 仅登记现有图片，不修改游戏代码、图片内容、资源引用或构建。

### 测试
- 核对文件存在、PNG尺寸与SHA256；文档链接/版本格式及diff检查通过。本批没有运行时改动。

## [v0.21.1] - 2026-11-16

### 新增
- 用户确认方案入口 docs/CONFIRMED_DESIGN.md：独立安全屋、实体电脑、手机准备后门口出发、文物箱及预约/取货/门口交易、主要文物仅走恶魔/对应国家剧情。
- R-01至R-08实施任务与新验收矩阵，明确全部待开发。

### 修改
- 同步AGENTS、项目技能、GDD、架构和决策：规划全世界冻结、分镜手动推进直连教学、直白剧情、长文分页、标题集中菜单；封面由用户另行提供。
- 旧栏目流程、纯UI安全屋、旧器灵剧情、固定等待分镜与主要文物普通出售标为被取代；历史记录保留。

### 修复
- 修正文档仍把旧设计作为现行指令的冲突；不声称已修复用户反馈的运行时问题。本批没有修改游戏代码、测试代码、素材或构建。

### 测试
- 文档链接/版本格式与diff检查通过；全量14项通过、1项失败（现有守卫实体装饰脱困冒烟用例）。已登记ROADMAP/TEST及原始日志，未改运行代码或测试断言；旧版自动通过不能代替新方案验收。

## [v0.21.0] - 2026-11-16

### 新增
- 按用户资源包接入心形圣甲虫、阿克罗蒂里彩绘注壶：图标、12帧转台、特写、三方线索与史料登记；保留旧收藏身份，显式迁移行动选择。
- 手机日历、通讯录与来电对话；电脑关键词检索、展厅/年代来源筛选、邮件回复与恶魔聊天。
- 推理板手动拖卡与拖线，错误关系反馈；8格144秒可跳过契约分镜直接接教学。
- 大英行动闭馆计时，规划/界面/回放暂停，超时回放恢复房间入口预算。
- ASSETS.md 文件来源与未知许可登记、完整素材哈希清单；TEST.md 逐项验收与真人盲测协议。

### 修改
- 正式安全屋要求三链全部验证；新增联络记录复用旧存档 story_flags，保持缺字段默认值。

### 修复
- 移除自动补线；大英行动仅可拾取所选文物且最多一件。
- 失败高亮绘图调用改由实际绘图节点执行，避免引擎非法绘图报错。

### 测试
- 最终 `tools/verify.sh --visual` 17项全绿、36张截图通过；CG实时143.958秒；Linux导出与启动通过。未完成验收仍列于 TEST.md。
- 增补真实拖卡/拖线/来电输入流、计时暂停超时回退、错误关联、单件限制与联络存档兼容测试。实际验证结果与未完成项见 TEST.md。

## [v0.20.3] - 2026-11-14

### 修改（路线预演坐标 / UI 层级 / 安全回退点）
- **鼠标点击使用世界坐标**：`Museum._unhandled_input()` 中添加路径节点时改用 `get_global_mouse_position()`，修复相机 `zoom=2` 且跟随玩家时节点落在屏幕坐标处的 P0 问题。
- **安全回退点**：新增 `_room_entry_pos`，玩家出生与每次跨入新房间时记录当前位置；`_rewind_and_replan()` 回退到该安全点，不再回退到可能卡在展柜/墙里的房间几何中心。
- **失败原因横幅移至 HUD**：新增 `Museum.failure_banner_changed` 信号与 `Hud.set_failure_banner()`，失败回放的原因文本在屏幕空间显示；`Museum._draw_failure_replay()` 只保留半透明暗屏与红色高亮连线。
- **节点预测标签优化**：移除世界空间的规划模式提示文字（改由 HUD 底部提示呈现）；节点标签改用半透明深色底板，ETA 改为「距离最近守卫预计到达时间（`守卫 ~Xs` / `安全`）」，并保留监控警告。

### 修改（展签卡解锁与零器灵残留）
- **展签卡拾取/归档后直接可读**：`InspectPage._build_cards()` 移除 `lore_stage` 解锁逻辑，背包或归档中的文物所有展签卡均可点击阅读。
- **收集册文案去器灵**：`CollectionScreen._lore_progress()` 删除「器灵对谈」进度，仅保留「端详热点」进度。
- **清理 `lore.gd` / `audio.gd` 器灵残留**：删除所有 `ghost` 字段与器灵对谈 `stages` 剧本，移除 `ghost.wav` 音效注册；`DialogueTree` 与 `Game.lore_stage` 等 API 为存档兼容继续保留但不再写入新进度。

### 测试
- 更新 `tests/test_story.gd`：移除 `Lore.stage_count` 断言，增加热点无 `ghost` 字段检查。
- 更新 `tests/smoke_test.gd`：音效池数量从 10 调整为 9。
- `tools/verify.sh --fast` 13 项 / `--visual` 30 张基线全绿（视觉基线因 HUD/标签改动已更新并人眼确认）。

## [v0.20.2] - 2026-11-14

### 修改（GDD v2 / READMEnew.md 对齐收口）
- **彻底移除「左羊 / 右羊」器灵说话人**：`Museum._label_lines()` / `_note_lines()` / `_both_read_lines()` 中所有 `speaker: "左羊" / "右羊"` 改为客观展签叙述或玩家内心旁白（`speaker: ""`）；双纸都读后的四选一改为「看着 1936 编号与 1860 留言，选择写进调查笔记的依据」。
- **推理板线索卡展示正文**：`Hub._make_clue_row()` 在标题下方新增自动换行的 `clue.body` 正文小字，未收集时显示「收集后查看详情」，收集后显示史料正文。
- **三目标档案标注争议与追索**：`Game.ARCHIVE` 中 `ram_zun` / `egypt_stela` / `greek_relief` 的 `legend` 字段加入「有争议 / 追索中」字样，明确真实文物的来源争议状态。

### 测试
- `tools/verify.sh --fast` **13 项全绿**；`--visual` **17 项全绿**，30 张视觉基线无变化。

## [v0.20.1] - 2026-11-14

### 新增（路线预演系统 P1：规划—执行—失败回放）
- **蹲下潜行**：`Player` 新增 `crouching` 状态，`C` / `Ctrl` 按住蹲下，移速降低 35%（`CROUCH_SPEED_MULTIPLIER`），跑步噪音完全消除。
- **规划模式**：`Museum` 新增 `planning_mode`，按 `Tab` / `R` 切换；鼠标左键在可行走地面添加路径节点（最多 5 个），右键删除最后一个；节点旁显示 ETA、警戒/监控预测标签；规划模式下守卫 AI 冻结，便于观察。
- **执行模式**：规划节点 ≥1 时按 `Space` 自动沿路径移动；玩家按方向键或 `E` 立即接管。
- **失败回放**：被保安或监控发现时不再直接 Game Over，而是进入 `failure_replay`：红色高亮连线标出发现源 → 玩家，顶部显示失败原因，玩家按 `E` / `Space` 回退到本房间起点并自动进入规划模式。
- **输入映射**：`project.godot` 新增 `plan_toggle`、`plan_execute`、`crouch` 三个 action。
- **保安目击信号**：`Police` 新增 `spotted_player(reason)` 信号，`Museum` 统一通过 `_on_player_detected` 进入失败回放。

### 修改
- `Museum._on_police_caught()` 改为触发失败回放（`保安近身抓获`），保留 `caught` 信号用于实际结算流程兼容。
- `tests/screenshot.gd` 移除旧 `shot_result.png`，新增 `shot_planning.png` 与 `shot_failure_replay.png` 两张基线。

### 测试
- `tests/test_input_flow.gd`：**153** 项（新增路线预演 Tab/点击/执行/接管/失败回退真实输入流）。
- `tests/smoke_test.gd`：**155** 项（更新被捕流程为失败回放 + 回退重规划断言）。
- `tests/test_monkey.gd`：新增路线预演状态不变量（节点数上限、规划/回放时玩家控制冻结、执行模式异常冻结检测）。
- `tools/verify.sh --fast` **13 项全绿**；`--visual` **17 项全绿**，30 张视觉基线（含 2 张新增规划/失败回放）。

## [v0.20.0] - 2026-11-14

### 新增（Batch 1：P2 开场 / P3 推理板 / P5 恶魔分支 / P6-A 三目标注册）
- **P2-A/B/C**：新游戏先播 `p00_devil_contract` 并落档 `saw_p00`；城西教学关成功撤离后跳过独立 `ResultScreen`，直连安全屋触发 P-01；`start_mission("british_museum")` 内先补 H-01 再播 H-02，保证旧档剧情顺序；据点手机页脚按 hub/level 模式切换文案。
- **P3 安全屋推理板**：Hub 新增「推理」标签，支持电脑·档案库 / 浏览器 / 邮件 / 手机·密信四来源收集线索；单条链集齐 3 卡并完成 `required_links` 两两连线后解锁对应大英博物馆目标；`Game` 新增 `collect_clue` / `make_link` / `verify_chain` / `unlocked_targets` / `set_bm_target` API 与 `unlock_all_chains_required` 开关。
- **P5 恶魔催交与检查点**：大英博物馆成功撤离后先播 `p05_devil_demand` 两阶段分支（直接上交 / 拒交发火 → 顺从 / 归还建档 / 背叛交易），写入 `ending_id`；结局页提供「从检查点重返安全屋」按钮；新增 `save_checkpoint` / `load_checkpoint`（`pre_heist` / `pre_choice`），回溯保留已解锁推理链并清空当次携带物与结局选择。
- **P6-A 三目标注册**：`Game.CATALOG` / `ARCHIVE` / `SHAPES`、`Collection.IDS`、`Lore.CLOSEUPS` 注册 `egypt_stela`（EA191）与 `greek_relief`（1816,0610.28）；`Hub` 任务卡按 `unlocked_targets()` 动态生成；`Museum.target_item_id()` 改为跟随 `Game.mission_target_id`，确保埃及/希腊目标实际生成与结算。

### 修改（GDD v2 口径对齐：彻底移除幽灵/器灵系统）
- 按 GDD v2 新口径，**完全移除**博物馆内的幽灵生成、尾随哀嚎、按 E 安抚与器灵台词：
  - `Museum` 删除 `GHOST_LINES`、`GHOST_SCENE`、`_start_haunting`、`_spawn_ghost`、`_talk_to_ghost`、`_on_ghost_wailed`、`_ghost_near`、出口前双羊 stage 3 触发与 `zun_trusted` 相关逻辑。
  - `Main` 删除 `_on_lore_requested` / `_on_lore_finished` 与 `lore_requested` 信号连接；保留 `DialogueTree` 用于剧情单卡/短句/展签卡。
  - `InspectPage` 移除 `ghost_label` 与「【器灵】」台词展示，只保留「【档案】」史实端详。
  - `Game` 删除 `hidden_ending_unlocked()` 与 `zun_trusted` 相关判定。
- 更新 `tests/test_story.gd`、`tests/test_story_flow.gd`、`tests/test_save_compat.gd`、`tests/test_content.gd`、`tests/smoke_test.gd`、`tests/test_input_flow.gd`、`tests/test_monkey.gd`、`tests/screenshot.gd`，删除幽灵/器灵/隐藏结局相关用例。
- 视觉基线从 33 张精简到 29 张（移除 `shot_bm_ghost.png`、`shot_lore_*.png`），`tools/check_visual.py` 同步移除 `shot_bm_ghost.png` 阈值覆盖。
- `DialogueTree._step()` 支持 `{"set_flag": ..., "value": ...}` 条目，用于 `p05_devil_demand` 结局路由与 `saw_p05` 落档。
- `ResultScreen.setup()` 新增 `ending_id` 模式，显示对应结局卡文案与「从检查点重返安全屋」按钮。
- `tests/screenshot.gd` 跳过 H-01，避免 `start_mission("british_museum")` 因剧情异步阻塞截图流程。

### 测试
- `tests/test_input_flow.gd`：**144** 项（新增 P2-A/B 开场直连、P6 埃及/希腊目标选择与生成）。
- `tests/test_logic.gd`：**2536** 项（新增线索收集、连线、链解锁、目标切换、检查点保存/加载/回溯清除 `ending_id`）。
- `tests/test_content.gd`：**651** 项（动态 BM 目标引用规则）。
- `tests/smoke_test.gd`：**162** 项（Collection 4 条目、Hub 解锁后生成 BM 卡片）。
- `tools/verify.sh --fast` **13 项全绿**；`--visual` **17 项全绿**，33 张视觉基线按新 Hub/销赃界面更新并人眼确认。

## [v0.19.8] - 2026-11-14

### 新增（GDD v2 P0：设计 / 史料 / 数据地基，plan）
- `docs/GDD_V2.md`：GDD v2 六大口径——双模式目标解锁（`unlock_all_chains_required`）、彻底零倒计时、检查点回溯、史实三层边界、恶魔「直接上交 / 拒交发火 → 顺从 / 反抗」两阶段分支。
- `docs/SOURCES.md`：新增 **S-003 古埃及第 19 王朝彩绘墓碑（EA191 / 1823,0614.1）**、**S-004 帕特农北翼骑手浮雕（1816,0610.28）** 的史料、争议与虚构边界。
- `src/data/evidence.gd`（新）：三条推理链 `ram_zun` / `egypt_stela` / `greek_relief`，每条 3 张线索卡（电脑档案库 / 浏览器 / 邮件 / 手机聊天）+ 2 条连线规则；无任何倒计时字段。
- `src/data/story.gd`：H-01 第一张卡补「乔治·尤摩弗帕勒斯旧藏 / 1936,1118.1」；新增 `p00_devil_contract`（恶魔契约开场）与 `p05_devil_demand`（催交 → 拒交发火 → 顺从 / 归还 / 黑市三结局）。
- `docs/STORY_PLAN.md`：更新为 P0–P7 任务表与三批次计划；S-12/S-13 开局动画延后等 codex 素材。

### 测试
- `tests/test_reasoning.gd`（**144 项**）：三链结构自洽（3 卡 / 2 连线 / 来源 App 分布）、零倒计时字段与文案；`p00` / `p05` 的 goto/卡片契约、结局卡可达、全部选项组合真实播放；H-01 史实边界与 p05 三结局「史实/虚构」声明。
- `tools/verify.sh` 新增「推理数据自检」步骤：`--fast` **13 项**、默认 **15 项**、`--visual` **17 项**。
- 安全屋 UI / 连线解锁 / 检查点回溯的 E2E 用例待 code Batch 1 落地后补。

## [v0.19.7] - 2026-11-13

### 修复（三修一加，用户实机反馈）
- **P0-1 双羊尊可拾取**：
  - 把 BM Room 3 剧情触发器 `BM_LABEL_POS`/`BM_NOTE_POS` 移到左右墙边 `(40,296)` / `(280,296)`，避开双羊尊展台交互半径。
  - `player._try_interact()` 改为「就近」：剧情触发器只有严格比文物更近时才触发，否则拾取文物；触发器已移到墙边，不再与双羊尊展台交互半径重叠。
  - `_closest_artifact()` / `_nearest_story_trigger()` 增加 `is_queued_for_deletion()` 与同 museum 父节点过滤，避免旧关卡残留 Area2D 干扰距离判断。
- **P0-2 据点可开手机**：`MissionPhone.open(hub_mode)` 支持据点模式，隐藏档案标签/页面且不暂停；`Main` 增加 `_hub` 引用，据点按 P 只显示任务页，`Main.open_phone()` 在关卡外也能打开。
- **P1-3 据点剧情引导**：按 `docs/STORY.md` §4 实现 P-01「雨里的门」、H-01「标签课」、H-02「两个地址」，使用 `DialogueTree`；新增 `src/data/story.gd` 管理剧本与卡片；`Game.finish_run()` 记录 `completed_museum`/`completed_british_museum`；`Main.show_menu()` / `start_mission("british_museum")` 按条件触发剧情并写 `story_flags`。
- **P2-4 据点面板观感**：据点任务/商店/销赃面板收窄并居中（400px），顶部/内容/底部遮罩透明度降低，面板与按钮背景增加透明，让 `safehouse_noir` 背景可辨识。

### 测试
- `tests/test_input_flow.gd`：BM 剧情交互站位改为显式坐标；新增 P0-1 两条回归用例（未读/已读标签时双羊尊前均可拾取），并补「特写内再按 E 真正入包」断言；新增 `_test_hub_phone`（据点手机模式 P0-2）；新增 `_test_hub_stories`（P-01 / H-01 / H-02 播放与落档）；输入流 105 → **129**。
- `tests/test_logic.gd`：补 `finish_run()` 的 `completed_museum` / `completed_british_museum` 落档与「被逮不记录完成」用例；逻辑 2509 → **2513**。
- `tests/test_story_flow.gd`：老档/新档补 `saw_p01` / `saw_h01` / `saw_h02` / `completed_museum` 默认 false；新增据点剧情结构契约（goto/卡片引用）与 P-01/H-01/H-02 全部选项组合的真实 DialogueTree 播放（39 组）；独立剧情 68 → **129**。
- `tests/screenshot.gd`：截图流程跳过据点剧情，避免 `show_menu()` 被 P-01 阻塞影响关卡截图。
- `tools/verify.sh --fast` **12 项全绿**；`--visual` **16 项全绿**，人眼确认后更新基线（据点/销赃界面收窄透明，BM 双纸对谈截图因粒子微调同步更新）。

## [v0.19.6] - 2026-11-13

### 新增（complete noir 美术包）
- **角色**：`player_noir.png` / `police_noir.png`（24×32 / 96×96 / 4×3 / 锚点 -10；碰撞 8×8 不变），由 `tools/gen_noir_player.py`、`tools/gen_noir_art.py` 生成；玩家与警察统一为 noir 风格。
- **据点**：`assets/art/safehouse_noir.png`（1280×720）接入 `hub.tscn`，任务/商店/销赃页统一换背景。
- **电话**：`assets/art/phone_noir_9p.png` + 任务/档案 Tab 独立样式（选中金底、未选中深色描边），9-patch 边距不变。
- **大英博物馆**：`bm_tiles_noir.png`（128×128）、`bm_case_noir.png`（32×48）、`decor_noir/` 16 个装饰（尺寸与原 decor 一致）；`museum.gd` 的 `BM_TILES` / `BM_CASE` / `BM_DECOR_TEX` 全部切到 noir 资源。
- **源图/参考**：`docs/art_direction/a00_src/` 新增 noir 源图与预览，`docs/art_direction/noir_pack/` 保存交接说明、接入参考 patch 与 10 张预览。

### 测试
- `tests/test_scenes.gd`：A-00 改为精确路径断言（`player_noir` / `police_noir`），并新增三方向待机/行走帧差异检查（防高清源图降采样后压成静帧）；新增 noir 资产检查（decor 16 个尺寸、hub/phone 场景引用、手机 Tab 样式、museum 常量）；场景自检 76 → **149**。
- `tests/test_content.gd`：补 `bm_tiles_noir` / `bm_case_noir` 尺寸检查；内容 567 → **573**。
- `tools/verify.sh --visual` **16 项全绿**：逻辑 2509 / 内容 573 / 输入 105 / 存档 88 / 进度 48 / 剧情 32 / 独立剧情 68 / 场景 149 / monkey 600 / 冒烟 162 / 视觉 33。
- 33 张视觉基线与 complete noir 包重建，逐张人眼确认（据点、电话、BM 六厅、玩家/警察同屏比例）。

## [v0.19.5] - 2026-11-13

### 修改（角色比例，用户要求）
- 主角改为 **24×32 / 96×96 / 锚点 -10**，与警察同尺寸；造型保留礼帽 + 棕褐风衣 + 斜挎包，造型沿用原版（git 862de05）24×32 sprite（礼帽+棕褐风衣）；高清概念 `thief_turnaround_a` 只用于立绘/特写；32×40 试验版不再作为游戏资产。
- A-00 交付文档 §2 同步为「主角 24×32；警察 24×32」。

### 测试
- `tests/test_scenes.gd` 的 A-00 规格断言更新为 **96×96 / y=-10**（与警察一致）。
- 33 张视觉基线按 24×32 主角重建；`tools/verify.sh --visual` **16 项全绿**（逻辑 2509 / 内容 567 / 输入 105 / 存档 88 / 进度 48 / 剧情 32 / 独立剧情 68 / 场景 76 / monkey 600 / 冒烟 162 / 视觉 33）。

## [v0.19.4] - 2026-11-13

### 测试（独立验收套件恢复）
- 恢复 `tests/test_story_flow.gd`（68 项）：story_flags 默认/存档往返/旧档/脏档不得被当 true、隐藏结局四组合、双羊尊 3 段 3 卡 4 热点、用真实 DialogueTree 播放全部选项分支。该文件在并行清理中被误删（此前未提交），现已重新落盘并接入 `tools/verify.sh`。
- `tools/verify.sh` 新增「剧情验收（独立）」步骤：默认 14 项，`--visual` 16 项。
- 教训：新增测试文件必须尽快提交；untracked 文件可能在并行清理中丢失。

## [v0.19.3] - 2026-11-13

### 修复（A-00 验收收尾）
- **主角 sprite 规格同步到 Rev.3**：按 `docs/art_direction/A00_DELIVERY.md` Rev.3，主角改为 **32×40 / 128×120 sheet**（`assets/sprites/chars/player_sheet_v2.png`），`src/actors/player.tscn` 锚点回 `-13`，与 `tools/gen_thief32.py` 生成物保持一致；废弃 48×48 方案（与守卫比例失衡）。
- **电话关闭键正式支持 P/B/ESC**：`src/main.gd` 在手机打开时让 B 键关闭手机（不打开背包），`src/ui/mission_phone.gd` 的 `_unhandled_input` 也响应 `bag` 动作；关闭后给背包加 0.2s 冷却，防止手机一关背包立刻弹开。
- **电话 Footer 不再只挂在任务页**：`src/ui/mission_phone.tscn` 将关闭提示移到 `VBox` 层级，任务页/档案页都可见；文案同步为「P / B / ESC 关闭」。
- **monkey 退出音频泄漏**：`tests/test_monkey.gd` 在 `get_tree().quit` 前先 `Audio.shutdown()` 并等待 0.4s，避免 `denied.wav` 播放中途退出报 ObjectDB/资源泄漏；`src/autoload/audio.gd` 的 `shutdown()` 不再立即 `free()` 播放器（与 smoke_test 的兜底方式一致）。

### 测试
- `tests/test_scenes.gd` 同步 Rev.3 主角规格断言（128×120 / y=-13）；`tests/test_input_flow.gd` 交叉键用例改为 B 关闭手机并断言不打开背包（105 项全绿）。
- `tools/verify.sh --fast` 11 项全绿（逻辑 2509 / 内容 567 / 输入流 105 / 存档 88 / 进度 48 / 剧情 32 / 场景 76 / 冒烟 162 / monkey 600）。
- `tools/verify.sh --visual` 15 项全绿；33 张视觉基线因主角 sprite 规格与电话 Footer 位置更新已重新生成并人眼确认。

## [v0.19.1] - 2026-11-13

### 修复（剧情交互 · S-03 收尾）
- **同帧双触发软锁**：按住/连按 E 关闭剧情对谈后，同一帧 `Input.is_action_just_pressed("interact")` 仍为 true → `story_trigger_requested` 再次发出 → 对谈重开并暂停，无限循环。修复：`src/actors/player.gd` 新增 0.25s 交互冷却（发出剧情触发与文物拾取/端详交互时拉起，`_try_interact` 开头拦截，暂停期间冻结）；`src/world/museum.gd` 给器灵对谈的 E 轮询加同款冷却并同步 player 冷却；触发器另加 `body_exited` 驱动冷却（两套机制并存、验证通过，待合并精简）。输入流自检 **100/100**（修复前 93/99 且复跑结果不稳定）；站位等待从 2 个 process 帧改为 3 个物理帧，消除传送后重叠列表未刷新的非确定根因，未删用例、未放宽断言。

### 新增（美术接入 · A-01）
- **A-00 素材接入 Phase 1**：玩家/警察改用 `assets/sprites/chars/*_sheet_v2.png`（96×96，24×32，4 列×3 行，显示偏移 -10，碰撞 10×8 不变）；据点加入安全屋背景（1280×720，不拦截点击）；任务终端 `Root/Panel` 的 `theme_override_styles/panel` 正式指向 `StyleBoxTexture_phone`（`assets/art/phone_frame_9p.png`，margin 12 / content margin 18×16）。接入方式为场景引用替换，旧占位 sheet 保留可回滚；玩法数值与输入映射未动。A00_DELIVERY.md 的 Phase 2 样式（卡片/按钮）未做，进遗留池。

### 修改
- `src/ui/hub.gd`：据点面板/销赃行背景 alpha 从 0.92 改为 1.0，消除安全屋背景下销赃行半透明透出横线的问题。
- `src/ui/inspect_page.tscn`：档案页端详区 ImageWrap 从 144×144 缩至 120×120，Info 与 Cards 间距收紧，解决 640×360 下档案页底部被 Panel 边框裁切的问题。

### 测试
- `tests/test_input_flow.gd` 站位等待改物理帧 + C/D 用例补冷却等待 + 销赃行 PanelContainer 包装修正（101 项）；`tools/verify.sh --fast` 11 项全绿（逻辑 2509 / 内容 567 / 输入流 101 / 存档 88 / 进度 48 / 剧情 32 / 场景 72 / 冒烟 162）。
- `tools/verify.sh --visual` 15 项全绿；33 张视觉基线已用 `tools/check_visual.py --update` 重新生成并人眼确认。

## [v0.19.0] - 2026-11-13

### 新增（剧情地基）
- **剧情旗标进存档（S-01）**：`Game.story_flags`（`src/autoload/game_state.gd`）——一次性剧情节点的持久化，约定键名 `read_label` / `read_note` / `honest_to_mask` / `zun_trusted`（布尔）与 `ending_id`（字符串，如 "sell"/"return"/"third"，供岔路结局路由）。配套访问器 `story_flag()`（未设置/未知键一律 false，值恒为 bool）与 `set_story_flag()`（默认 true，立即落盘）。存档只增字段：老档缺字段默认空、整段类型脏（字符串/数字）重置为空、非法键值过滤，与 `lore_stage`/`lore_found` 同一套防御式容错；新游戏重置一并清空旗标。

### 修改（剧情内容落地）
- **双羊尊文物志进游戏（S-02）**：`src/data/lore.gd` 按 STORY.md §5.1 落地 `ram_zun` 条目——3 段器灵对谈（左羊 = 铸匠记忆 / 右羊 = 流转记忆，双声道）、3 张展签卡（形制与年代 / 湖南推定 / 1936 转手）、4 个端详热点（羊角 / 背脊接缝 / 垫片痕 / 锈色）。大英博物馆的器灵哀嚎现在会进入完整对谈（此前退回单句台词）；对谈推进与展签卡解锁沿用现有文物志系统。
- **smoke_test 两条「双羊没有剧本」断言改正**：改为正面断言——热点按钮数 == `Lore.hotspots("ram_zun").size()`；卡片区可见且数量 == `Lore.cards("ram_zun").size()`；热点进度计数改数据驱动（"0 / %d" % 热点数，不再写死）。

### 新增（剧情交互 / 节奏 / 隐藏结局条件）
- **BM Room 3 标签/留言交互（S-03）**：`src/world/museum.gd` 在双羊尊展柜旁生成两个 `Area2D` 触发器（group `story_label` / `story_note`），`src/actors/player.gd` 按 E 优先响应剧情触发器（再拾取文物）。馆方标签与观众留言用现有 `DialogueTree` 占位播放：标签展签卡 + 左右羊低语 + 旁白；留言皱纸卡 + 低语 + 旁白；两张都读后追加「你信哪个？」四选项对谈。读完后 `Game.set_story_flag("read_label"/"read_note")` 落盘。
- **双羊尊演出节奏与右羊安抚（S-04）**：保留「靠近器灵按 E」播 stage 1；出口前兜底：进入大英博物馆出口触发区时，若双羊文物志还没播完，自动播放下一段（`lore_requested`）。stage 3 播完后 `Game.set_story_flag("zun_trusted")` 并调用 `ghost.calm(999999.0)`，本局右羊不再哀嚎引警；面具关卡与通用 `ghost.gd` 行为不受影响。`src/main.gd` 在 `_on_lore_finished` 中回调 `museum.on_lore_finished(item_id)` 完成后续路由。
- **隐藏结局条件（S-08）**：`Game.hidden_ending_unlocked() -> bool` = `read_label && read_note && (zun_trusted 或双羊对谈已满) && honest_to_mask`；结局 id 约定 `"sell"` / `"return"` / `"third"`。

### 修改
- `src/main.gd`：新增 `story_requested` 信号连接，用 `DialogueTree` 播放剧情单卡/短句（`escapable=true`，允许 P/ESC 直接关闭）；在 `on_finished` 里接续新故事时，延迟一帧连接 `dialogue_tree.finished` 解暂停，避免同一帧内被旧故事的 `finished` 信号误触发。
- `src/ui/dialogue_tree.gd`：`interact` / `ui_accept` 推进与选项选择改用 `Input.is_action_just_pressed`，防止长按 E 一帧多进；保证选项出现后可被单次按键稳定选择。
- `src/world/museum.gd`：剧情触发器冷却改为 `body_exited` 信号驱动（离开范围后才允许再次按 E 重读），并放大触发半径至 26、调整 collision_mask 使触发/离开事件可靠送达。

### 测试
- 新增 `tests/test_story.gd` 剧情自检（61 项）并接入 `tools/verify.sh`：story_flag 默认/写入/未知键/重置、存档往返（含 ending_id）、老档缺字段与整段/键值脏档、双羊尊文物志结构自洽（恰 3 段 / 3 卡 zun_1..3 / 4 热点、坐标 0..1、每段 goto 与选项可达、特写图存在）。
- `tests/test_save_compat.gd` 补 story_flags 用例（88 项）：缺字段老档、整段字符串/数字脏档、键值脏档过滤、完整档往返断言；`_defaults_ok` 增加「剧情旗标为空」检查。
- `tests/smoke_test.gd` 双羊尊端详页断言同步（162 项）；切换条目后补一帧等待让旧卡片按钮出队。
- `tests/test_story_flow.gd`（test 负责，code 确认接口）63 项：story_flags 默认/往返/旧档不误判/脏类型、隐藏结局四组合、双羊 3 段实际播放与 goto 可达；已全绿。

### 文档
- README「开发进度」、ROADMAP M5 P0、STORY_PLAN 任务表（S-01/S-02/S-03/S-04/S-07/S-08 → 👀 待验收）同步。

## [v0.18.4] - 2026-11-13

### 新增（剧情文本）
- **剧情圣经 `docs/STORY.md`（v1.1）**：确定第一卷《两只羊》的一句话、主题与逐场剧本——序章入行、城西博物馆（面具）、据点「标签课」与「两个地址」、大英博物馆·中国馆（双羊尊）、雨夜岔路、出售 / 归还 / 隐藏「第三只羊」三结局。含每个场景的触发、画面、声音、选项、后果与实现映射；§10 为开局动画《雨里的门》6 镜头 / 40–44 秒分镜（字幕、跳过、素材清单、代码落点）。
- **双羊尊文物志全文**：3 段器灵对谈（左羊 = 铸匠记忆、右羊 = 流转记忆）、3 张展签卡（形制 / 湖南推定 / 1936 转手）、4 个端详热点；可直接落 `src/data/lore.gd`，已通过 GDScript 语法解析。
- **学术边界**：把「可考 / 不可考 / 民间传说」写成剧情结构而非免责声明——1860 圆明园说只作为观众留言与沈先生口中的「网上抄的」出现；双羊尊 1936 年购自 Eumorfopoulos 旧藏为可考事实。三结局各配固定史实声明。
- **给 art / code / test 的落地清单**：数据落点、最小新增能力（`story_flags`、标签交互、右羊永久安抚、隐藏结局条件）、必须同步修改的测试断言（含现有 `smoke_test` 的「双羊尊没有剧本」两条）。

### 文档
- 新增 `docs/STORY_PLAN.md`（剧情内容冲刺计划）：S-01..S-15 任务、owner（code / art / test / plan）、三批次、文件边界、验收标准与风险对策；已按该计划向三方发出任务邮件。
- README「开发进度」、ROADMAP M5 P0 同步剧情文本与冲刺状态；本次仅新增文本/计划，不改代码。

## [v0.18.3] - 2026-11-13

### 修复（独立验收发现）
- **被逮捕后赃物会"复活"**：拾取时会自动存档（收集册归档），而失败结算没有落盘清空——退出重开后背包里仍有被没收的目标/赃物，任务还显示完成。现在失败结算会立刻清空赃物与任务标记并保存（`src/autoload/game_state.gd`）。
- **损坏/半写存档被当成「继续游戏」**：`has_save()` 原来只判断文件存在，截断档会让玩家点「继续」后静默读到空进度。现在会校验 JSON；坏档不提供继续，读档安全回退默认值。
- **存档改为原子写**：先写 `save.json.tmp` 再改名覆盖；写到一半中断不会破坏上一次的完整存档。

### 测试
- 新增 **玩家进度自检** `tests/test_progression.gd`（48 项）：被逮没收落盘、结算幂等、仓库持久化、卖店边界、收集册生命周期、损坏档/残留 `.tmp`、新游戏清档。
- `tools/verify.sh` 新增该步骤：全量 12 项，`--visual` 14 项。

## [v0.18.2] - 2026-11-11

### 新增（发布 / 部署）
- **导出与打包**：新增 `export_presets.cfg`（Web / Windows / Linux）；Windows 单文件 exe（内嵌 pck）+ `assets/art/icon.ico`；新增 `tools/export.sh`，一键导入、导出并压缩到 `build/`（已在 `.gitignore` 中排除）。
- **Web 版**：关闭线程（`variant/thread_support=false`），不依赖 SharedArrayBuffer / COOP / COEP，可直接部署到 itch.io、GitHub Pages、Netlify Drop；Web 包约 16 MB。
- **文档**：新增 `docs/DEPLOY.md`（itch.io 上传、Windows zip、GitHub Release/Netlify 备选、音频/存档/许可注意事项）。

### 测试
- 导出冒烟：Linux 包 `--headless` 启动/退出正常（exit 0）；Web 包 `index.html/index.js/index.wasm/index.pck` 齐全、threadless；`tools/verify.sh` 全绿（逻辑 2509 / 内容 433 / 输入流 82 / 存档 69 / 场景 58 / monkey 600 / 冒烟 161）。

## [v0.18.1] - 2026-10-21

### 修改（标题页 / 收集册）
- 标题页的「商店」入口改为 **「文物档案」收集册**（仍在博物馆入口处）：收录真实文物（青铜人面具、商代双羊尊）的档案页、器灵对谈/端详进度与收集状态；未归档条目显示「？？？」与获取提示。**商店回到据点的顶部标签**，标题不再有商店快捷入口。
- 新增 `Collection`（条目数据，复用 `Game.ARCHIVE` + `Lore` 特写）与 `CollectionScreen`（标题页子页面，不暂停，ESC/返回关闭）；标题提示「收集册 · n / 2」。
- 归档规则：行动中**第一次拾取**文物即归档（`Game.archive_seen`，进存档；即便之后被抓也保留这一页）；老档按器灵进度兼容解锁面具；`reset_progress` 清空。

### 测试
- 逻辑 2509（拾取归档 / 普通赃物不计入 / 重置清空）；内容 433（收集册条目、档案字段、特写、未归档提示）；存档 69（缺字段 / 老档器灵兼容 / 脏档过滤 / 完整往返）；输入流 82（真实点击「文物档案」→ 收集册，ESC 关闭）；场景 58；冒烟 161（解锁/未解锁/进度）；monkey 600（archive_seen 合法性）；视觉 30 张（新增 `shot_collection.png`）。`tools/verify.sh --visual` **13 项全绿**。

## [v0.18.0] - 2026-10-21

### 新增 / 修改（标题页）
- **新封面**：`assets/art/title_key_art.png`（1672×941，屋顶小偷 + 大英博物馆正门），替换旧立绘；自动 cover 裁切。
- **场景化菜单**：选项不再堆在左侧竖栏，而是错开放进画面——「开始/继续游戏」贴在角色按着的手边（带「从这儿开始」提示与呼吸光框）、「商店」放在博物馆正门台阶上（标注「补给 · 销赃」，点击直接进据点商店页）、「新游戏」在手掌下方的屋脊、「声明与说明 / 退出游戏」缩在右下角。
- **UI 动效**：黑场淡入、标题左滑、朱砂印盖章、按钮依次浮起、悬停放大 + 轻音效、主按钮呼吸光框、商店位置呼吸标记、立绘极慢推近。
- **无存档时**「开始游戏」直接开局（不再需要二次确认）；有存档时保留「新游戏」二次确认清档。
- 新增 `TitleScreen.shop_requested` → `Main._on_title_shop()` → `Hub.open_shop()`（直达商店页）。

### 测试
- 冒烟 150 项（标题页商店按钮/信号、主行动位于场景内）；输入流 83 项（真实点击标题「商店」→ 据点商店页高亮）；视觉基线 `shot_title.png` 更新为新封面/布局。

## [v0.17.2] - 2026-10-21

### 修改（档案页 / 来源标注）
- **档案页（端详页）**：双羊尊现在直接显示混元 3D 资产渲染的 144×144 特写（此前回退到 24×24 图标放大，模糊）；没有热点/展签卡时显示「暂无细节标记」并隐藏空标题，不再出现误导性的「已发现 0 / 0」和「点击 ?」提示。
- **来源更正**：3D 资产由**腾讯混元（Hunyuan3D）**生成（非摄影扫描）；原始 GLB 本地保留、不入库，仓库只包含离线渲染产物；再分发/商用请遵循腾讯混元相关条款。

### 测试
- 内容 414 项（新增 `Lore.CLOSEUPS` 路径校验）；冒烟 146 项（端详页双羊尊特写、空状态、无 0/0 计数）；视觉基线新增 `shot_bm_archive.png`（共 29 张）。

## [v0.17.1] - 2026-10-21

### 新增（A v2 美术方向提案）
- 新增 `docs/A_V2_ART_SYSTEM.md`：在保留「A/B/C/D 风格矩阵」的前提下，把常态玩法升级为 **A v2「冷宫暖器 2.0」**——角色 24×32、主文物光池/展柜玻璃退后、UI 博物馆标签化、B/D 只在特写/闪回出现；含材质表、六厅色脚本、P0–P4 执行顺序与验收清单。
- 新增对比板 `docs/art_direction/A2_comparison_board.jpg`（现状 vs 目标 + 角色/展柜/UI 三项 callout）与 Room 3 概念稿 `docs/art_direction/A2_room3_upgrade.jpg`。
- 更新 `docs/ART_DIRECTION.md` §11、`docs/ROADMAP.md` 候选池、`docs/art_direction/README.md`、`README.md`。
- 本次只改文档/概念图，未改运行时代码与测试。

## [v0.17.0] - 2026-10-21

### 新增 / 修改（美术资产）
- **双羊尊 3D 呈现改用腾讯混元（Hunyuan3D）生成的 3D 资产**（`assets/models/e6b392….glb`，50 万面 + 4K PBR 贴图；本地资产、`.gitignore` 不入库）：离线重渲染 12 帧转台、hero 大图与 2.5D 特写。渲染脚本把该资产归一化到程序化模型的尺寸（高 0.443 m、底部 Z=0）后复用同一影棚；`MODEL=procedural` 或资产缺失时自动回退，仓库仍可独立跑通。
- **材质/调色**：渲染时压低该资产的镜面高光（Specular IOR Level 0.25）；小尺寸精灵（24×28 关卡转台、48×56 手机展示、24×24 图标）做青铜绿色调分级（R×0.82 / G×0.93 / B×0.78 + 饱和/对比），2.5D 特写保留 4K 贴图的原始纹理质感。
- **截图确定性**：截图脚本先清进度、固定金币/背包/烟雾弹并写档；指针移到角落，避免按钮 hover 样式导致基线漂移。
- 文档：`assets/models/README.md`（混元 3D 资产说明/渲染命令）、`docs/SOURCES.md`（3D 呈现口径）、`docs/DECISIONS.md` D-020、`docs/ARCHITECTURE.md`、`docs/MANUAL_QA.md`。

### 测试
- `tools/verify.sh --visual` **13 项全绿**；视觉基线更新（人眼确认）：`shot_bm_closeup`（特写换混元资产）、`shot_bm_room3` / `shot_bm_zun`（展柜内转台）、`shot_bm_phone` / `shot_hub`（手机与据点转台）。

## [v0.16.3] - 2026-10-21

### 修复（守卫卡在实体装饰旁）
- **警察脱困**：`police.gd` 增加 `_stuck_timer` + `_start_detour()`——移动受阻超过 0.3s 时侧向绕行；巡逻状态同时跳到下一个路点，避免一直顶在长椅/展台/叉车上。
- **碰撞范围收敛**：只给真正落在地面的大件装饰（售票台、长椅、叉车）加额外碰撞；展柜/红漆柜等放在原本已实体的 `d`/`s` 格上，避免 32×32 碰撞外扩挤占巡逻线。Room 3 长椅移到 `(2,20)` / `(17,20)`，Room 2 地面手卷展柜移除。
- 展台 `p/T/a` 仍保持实体碰撞，玩家从相邻格交互/拾取。

### 测试
- 冒烟 141 项（新增：守卫在长椅旁 1.5s 内必须离开原位）。
- `tools/verify.sh` 11 项、`--visual` 13 项全绿。

## [v0.16.2] - 2026-10-21

### 修复（器灵 / 警觉可读性）
- **「站着不动几秒，两名警察突然冲过来」不是隐藏机制**：拿到任务目标 3.5s 后出现的器灵每 2.8s 哀嚎一次，把同房间 6 格内的警察引到它身边——双羊尊展厅的两名警察都在范围内，于是同时被引过来。本轮把它变成可读、可反制的机制：
  - 器灵哀嚎时绘制扩散波纹（世界内可见，能直接看到「它叫了」）；
  - 首次「哀嚎真的引来警察」时提示：**「器灵的哀嚎引来了警察！快离开原地，或按 E 让器灵安静下来。」**；
  - 与器灵交谈（E）会**安抚它 8 秒**（不哀嚎、不引警）——让「交谈」除了听故事还有机械回报；
  - 被哀嚎引来的警察停在约 2.5 格外搜索，不再直接踩到玩家身上。
- **警察发现过程可视化**：头顶新增黄色警觉进度条，发现延迟 0.35s → 0.5s（教学关 1.6× 后为 0.8s），避免「没有预警就突然被追」。
- 移除器灵出现时的长提示（会压住对谈选项）；相关信息改在真正引警时提示。

### 测试
- 冒烟 141 项（新增：被安抚的器灵停止哀嚎、安抚窗口结束恢复哀嚎、哀嚎引警提示、交谈安抚、被引来的警察保持搜索距离；发现时序适配 0.5s）。
- 视觉回归 28 张基线（器灵出现时的旧提示文本移除）。`tools/verify.sh --visual` **13 项全绿**。

## [v0.16.1] - 2026-10-21

### 修复（视觉/碰撞一致性）
- **大英博物馆“地面装饰误读为掩体”**：`p/T/a` 展台以及展柜、红漆柜、长椅、售票台、叉车、木箱等大件装饰补 `StaticBody2D` 碰撞；新增 `Museum.is_cell_blocked()` 统一“实际阻挡”判定，视觉与可走性一致。玩家从相邻格即可与展台文物交互/拾取。
- **地面可读性**：地面瓦片改为低对比平铺，去掉强明暗边/裂缝/台阶感；墙、展柜、展台下方加投影。
- 截图机位避开实体格（Room 2/3），monkey 的“玩家不进入实心格”不变量改用 `is_cell_blocked()`。
- 视觉基线随本轮预期改动更新（28 张）。

### 测试
- `tools/verify.sh --visual` 13 项全绿：逻辑 2504 / 内容 412 / 输入流 78 / 存档兼容 56 / 场景 55 / monkey 600 步 / 冒烟 134 / 视觉回归 28 张基线。

## [v0.16.0] - 2026-10-21

### 新增
- **2.5D 互动特写层**（`RelicCloseup`）：对着**有特写图的文物**（目前为双羊尊）按 E，进入电影感特写——黑场淡入、暖光、缓慢呼吸推近（2.5D 视差），显示文物名与故事；**E 拾取 / Esc 离开**，打开即暂停。特写图由 3D 管线新增渲染（768² 机位 → `relic_ram_zun_closeup.png` 360²），高精度细节只出现在这一层（对齐 ART_DIRECTION 的两层规则）。
- **手动销赃**：关卡结算不再自动卖掉带出的文物——组织报酬自动入账，战利品存入**据点仓库**；据点新增「销赃」页（任务 / 商店 / 销赃），可逐件卖出或全部出手；仓库进存档（只增字段）。

### 修改
- 结算界面：说明战利品已存入仓库、需回据点自行出手。
- `finish_run` 结算后清空背包（目标上交 + 其余入库）。

### 测试
- 逻辑 2504 项（战利品入库、逐件/全部卖出、结算不再自动加钱）；存档兼容 56 项（老档缺 `loot_stash` → 空仓库；脏仓库过滤非法 id）；输入流 78 项（真实按键：E 开特写→E 拾取、Esc 关闭；据点点击「销赃」页并卖出）；monkey 不变量新增仓库合法性；冒烟 134 项；视觉回归 28 张基线（新增特写 / 销赃页）。`tools/verify.sh --visual` **13 项全绿**。

## [v0.15.0] - 2026-10-21

### 变更（文案：游戏内保持世界观叙述，正式声明集中到标题页）
- **游戏内去除学术化标注**：任务终端的「文物档案」卡不再显示「来源 / 演绎」；文物志展签卡不再显示来源行；端详页「【史实】」改为「【档案】」（与「【器灵】」对应）。
- **档案 / 展签文案改写为世界观口吻**：例如「档案里找不到那一页」「馆里的人这么叫它」；史实信息保留，但不再呈现为引用格式。
- **新增标题界面「声明与说明」**（`src/ui/statements_screen.gd/.tscn` + `src/data/statements.gd`）：集中说明项目性质、史实与虚构分界、真实文物与参考资料（双羊尊 / 青铜人面饰）、3D 模型为展示性演绎、字体许可、关于「归还」主题的立场、致谢与权利处理方式。

### 测试
- 内容一致性 412 项（档案字段收敛为 era/origin/collection/provenance/legend；展签卡不再要求来源；新增声明页覆盖检查：真实文物 / 虚构 / SOURCES / 字体 / 3D）。
- 输入流自检 63 项（新增：标题「声明与说明」真实鼠标点击打开、ESC 关闭）。
- 视觉回归：新增 `shot_statements.png` 基线；标题 / 手机 / 端详等 26 张基线更新（已人眼确认）。`tools/verify.sh --visual` **13 项全绿**。

## [v0.14.3] - 2026-10-20

### 新增（底层自检体系 v2）
- **引擎报错门禁**：`tools/verify.sh` 每一步都检查输出——出现 `ERROR / WARNING / 泄漏 / 非法访问` 等引擎级日志即失败（允许清单必须写理由）。过去"测试通过但日志有异常"会被忽略。
- **存档兼容自检** `tests/test_save_compat.gd`（45 项）：老档缺字段、损坏 JSON、类型脏档、未来字段、脏背包/脏文物志、当前档往返；新增存档字段必须补用例。
- **场景实例化自检** `tests/test_scenes.gd`：`src/` 下全部场景逐一实例化并存活两帧——抓 @onready 路径失效、preload 悬空、`_ready` 崩溃。
- **随机操作自检（monkey）** `tests/test_monkey.gd`：固定种子随机按键/鼠标驱动真实场景 600 步，逐帧检查不变量（覆盖层⇔暂停、任务目标一致、玩家不卡墙、资源非负）；失败时打印种子 + 最近操作序列；带覆盖统计防止"空跑"，`MONKEY_STEPS` / `MONKEY_SEED` 可加深。
- **截图视觉回归**：`tests/visual_baseline/`（25 张基线）+ `tools/check_visual.py`；`tools/verify.sh --visual` 跑截图并逐像素对比，超阈值失败并在 `/tmp/opencode/visual_diff/` 产出标红差异图；预期改动用 `--update` 更新基线。
- **手动 QA 清单** `docs/MANUAL_QA.md`：2 分钟人测项（手感/画面/音频/历史表述）与「自动 vs 手动」对照表。
- 截图流程隔离存档（`tests/screenshot.gd`）：不再覆盖玩家真实进度，同时提升截图可复现性。

### 修复（新自检当场发现的加载路径 bug）
- 脏存档 `"id": 42` 会触发 `String(int)` 报错（当前 Godot 版本无此构造器）→ 改用 `str()`；`"has_sneakers": "x"` 触发 `bool(String)` 报错 → 新增 `_as_bool()` 类型安全读取。
- `lore_found` / `lore_stage` 里的非数组/字典脏值会让加载崩溃 → 防御式读取（`_as_int()`）。
- 存档中的负数/越界值（money / smoke_count / backpack_level）现在加载时钳制到合法范围。

### 测试
- `tools/verify.sh`：全量 11 项（新增 存档兼容 / 场景实例化 / monkey）；`--visual` 时 13 项；`--fast` 跳过冒烟与 monkey。全量约 30 秒。

## [v0.14.2] - 2026-10-19

### 修复（实测 bug：卡片叠层按 P 关不掉）
- **逐层返回**：手机里点开展签卡后，P / ESC 现在先收卡片层，再关手机；此前 P 会直接关掉手机、把卡片留在屏幕上，游戏还会提前解除暂停，且卡片挡住手机无法重开。
- **兜底清理**：任何关闭手机的路径（P / ESC / 点暗区 / 程序化调用）都会一并收掉卡片层，杜绝"界面关不干净"的卡死状态。
- 涉及文件：`src/ui/dialogue_tree.gd`（`escapable` 标记 + `close()` + 关闭键处理）、`src/main.gd`（卡片播放传入可关闭标记；手机 `closed` 时兜底）。

### 测试
- 新增 **输入流自检** `tests/test_input_flow.tscn`（59 项）：用真实按键/鼠标事件驱动 Main 场景——B/P/ESC 开关、交叉键互斥、防同帧重开、卡片逐层返回、器灵对谈期间不叠界面、HUD 手机按钮点击，以及"覆盖层 ⇔ 暂停"契约。此前这类 bug 测不到，是因为测试都是直接调 `open()/close()`，绕过了按键路由。
- `tools/verify.sh` 新增该步骤（全量与 `--fast` 均执行）；`AGENTS.md` 增加硬性规则 9「UI/输入改动必须过按键流」与对应 DoD 条目。

## [v0.14.1] - 2026-10-19

### 修复（试玩反馈：教学关容错太低——"第二个房间进门就直面警察灯光"）
- **巡逻路线避开门口**（生成器硬校验）：`tools/gen_museum_map.py` 新增规则——巡逻路线（含线段采样点）与**同房间"门口相邻格"**的距离必须 ≥ **3.5 格**，否则生成失败并列出违规点。据此重排两个关卡的巡逻：博物馆 7 条路线、大英博物馆 6 条路线（含目标房入口/出口附近），玩家进门不再直接撞进手电光锥。
- **教学关守卫反应更慢**：`Police.spot_delay_scale`（默认 1.0）；城西博物馆设为 **1.6**（发现玩家所需时间 ×1.6，给教学留出反应窗口），大英博物馆保持原强度。
- **首见守卫提示**：首次进入有守卫的房间时提示「先看清手电光锥的方向，再贴着边走」（每局一次）。
- 顺带修正：`toast` 信号参数数量、`police.gd` 常量行合并（编辑事故）、两处测试与关卡调参解耦（固定 `spot_delay_scale`）。

### 测试
- 冒烟 132 项（新增：教学关守卫 `spot_delay_scale > 1`、大英博物馆保持 1.0）；生成器校验新增「门口安全距离」规则（`check_level` 覆盖）。`tools/verify.sh` 7 项全绿。

## [v0.14.0] - 2026-10-19

### 新增（文物机制 v1 · 青铜人面具测试，落地 `docs/ARTIFACT_SYSTEM_PROPOSAL.md` 的 A+B 预案）
- **器灵对谈**（`DialogueTree`）：带**选项分支**与**展签卡**的对话树；史实走米白纸卡（含 SOURCES 来源行），器灵台词走深色对话框——**史实与演绎视觉分离**。靠近器灵按 E 交谈，每讲完一段解锁下一段（进度进存档；讲完提示收束）。
- **端详 · 物证勘查**：任务终端新增「档案」页——随身文物列表 + 特写大图（48×48）+ 可点热点（每个热点给「史实一句 + 器灵一句」）+ 展签卡按文物志进度解锁；已发现热点进存档。与 ART_DIRECTION 的「常态全像素 / 互动后高精度特写」两层规则一致。
- **青铜面具 → 青铜人面具**（真实文物）：名称、故事与档案卡改为**城固商代青铜人面饰**；`docs/SOURCES.md` 登记 **S-002**（1976 年苏村小冢窖藏 23 件面具、城洋铜器群 700 余件、三条可核对来源、演绎声明）。
- 文物志数据独立成 `src/data/lore.gd`（剧本 / 展签卡 / 热点，含静态查询接口），避免与并行窗口争用 `game_state.gd`；`Game` 新增 `lore_stage` / `lore_found`（存档只增字段 + 默认值）与展签卡列表解锁规则（第 i 张卡在第 i+1 段后解锁）。
- 新资产：`mask_closeup.png`（48×48 程序化特写，供端详）。

### 修复
- 对话 / 对谈进行中不再能打开手机或背包（原来会叠层）。
- 端详页布局：根节点改为容器，尺寸自动推导（内容不再溢出面板）。

### 测试
- 逻辑 2498 项（文物志进度与上限、存档往返）；内容 385 项（剧本条目类型、卡片/热点字段、跳转与引用校验）；冒烟 130 项（对谈选项→展签卡流程、端详热点发现、器灵交谈请求、手机档案页与面板尺寸）。`tools/verify.sh` 7 项全绿。

## [v0.13.1] - 2026-10-19

### 修复（手动试玩反馈）
- **手机/背包开关竞态**：按 P / B 关闭后，同一帧的 `_process` 又把面板打开，表现为“关不掉”。`main.gd` 增加 0.2s 冷却与 `toggle_allowed()`，关闭事件后不再响应同一按键。
- **守卫跨房间视物**：`police.gd` 的 `can_see_player()` 与逮捕判定加入“同房间”门槛（`museum.room_index_at`）；门洞仍可通行，但守卫不再隔房发现/抓住玩家。玩家引用在 `can_see_player()` 内惰性获取，便于测试与延迟生成。
- **大英博物馆地面可读性**：地面瓦片改为低对比平铺（去掉强明暗边、裂缝与台阶感），墙/展柜下方增加投影提示“这里是可走地面”；六个展厅同步更新。

### 测试
- 逻辑 2488（`in_cone` 等纯函数不变）；内容 304；冒烟 107（新增：同房间可见 / 跨房间不可见、开关冷却）。
- `tools/verify.sh` 7 项全绿。

## [v0.13.0] - 2026-10-19

### 新增（美术方向 / 大英博物馆关卡 / 标题立绘）
- **美术方向提案**：`docs/ART_DIRECTION.md` + `docs/art_direction/` 概念板（A 冷宫暖器、B 绢本志怪、C 微缩夜馆、D 黑墨朱印），并确立「常态玩法全像素 / 互动后高精度特写」两层规则。
- **A 全像素实机预演**：`A_pixel_gameplay.jpg` + `A_two_layer_flow.jpg`；双羊尊在常态玩法中使用 32×32 像素 sprite，实拍级文物只出现在按 E 互动后的特写层。
- **大英博物馆·中国馆关卡美术**：`docs/BRITISH_MUSEUM_ART.md` + `BM_level_board.jpg` / `BM_floorplan.jpg`；6 展厅色板、灯光、动线、资产清单与 Room 3 Vertical Slice 规格。
- **Room 3 资产包 v0.1**：`tools/gen_bm_art.py` → `assets/sprites/bm/`（`bm_tiles.png` 16×16 瓦片、`bm_props.png` 32×32 道具、`bm_ui.png` UI 部件、`bm_zun_32.png` 双羊尊 sprite、`bm_case.png` 玻璃展柜）；预览 `docs/art_direction/BM_asset_sheet.jpg`。
- **Room 3 实机接入**：`museum.gd` 新增房间主题查找 `_room_of_tile` 与 `_draw_bm_tile()`；大英博物馆 Room 3 使用 BM 瓦片/展柜/暖光，目标厅加入 `BMDisplayCase`；文物 glow 在目标厅压低避免过曝。实机截图见 `docs/art_direction/BM_room3_ingame.jpg`。
- **六展厅主题接入（v0.2）**：`BM_THEMES` 覆盖 Room 0–5——入口冷理石/新古典墙、瓷器青花/蓝白展柜、玉器暖木/红漆柜、青铜铜绿/红毯、丝路沙地/土红壁画、装卸水泥/金属/警示线；大英博物馆夜色调独立为 `NIGHT_TINT_BM`，壁灯颜色按房间分流（`_bm_lamp_config()`）。实机巡检 `docs/art_direction/BM_rooms_contact.jpg`。
- **装饰层（v0.3）**：新增 `assets/sprites/bm/decor/*.png` 13 个纯视觉装饰（安检门、售票台、展厅地图、青花/玉璧/手卷展柜、红漆柜、壁画、木箱堆、托盘、叉车、管道、长椅）；`museum.gd` 的 `BM_DECOR` + `_build_bm_decor()` 按房间叠加，参与 y 排序但不新增碰撞。
- **装饰动效 + 文物档案 + Room 3 光影（v0.4）**：监控摄像头转头、警报灯闪烁、天窗呼吸；Room 3 加入 `BMDust` 尘埃、`BMZunReflection` 双羊尊倒影、`BMGlassGlint` 玻璃高光；`Game.ARCHIVE` 新增文物档案字段，任务终端显示档案卡（可考/不可考/民间传说/虚构演绎），背包 `BagGrid` 接入 `bm_zun_32.png` 图标。
- **开始界面立绘**：按 C 方向「微缩夜馆」重绘——整座博物馆 + 屋顶小偷 + 玻璃天窗 + 月亮，不再以单件文物为中心；`assets/art/title_key_art.jpg`（作者图，1280×720，标题界面自动读取）；UI 改为左侧竖栏。
- **D 页面史实校准**：双羊尊 D 画面改为湖南（推定）商代祭祀原在地 + 入藏时间线；`docs/SOURCES.md` S-001 补充核查：1936 年购自 George Eumorfopoulos，具体如何离开中国不可考，「1860 圆明园劫掠」为民间叙事，无确证。

### 修改
- 标题界面 UI 从居中改为**左侧竖栏**（标题/密档印/存档信息/三按钮），不再遮挡博物馆与小偷；立绘读取作者图，`tools/gen_key_art.py` 不会覆盖。
- D 方向 Prompt 改为湖南祭祀场景；新增 §7.1b「常态玩法：全像素」Prompt。

### 测试
- `tools/verify.sh` 7 项全绿：逻辑 2488 / 内容 304（BM 资产/装饰尺寸 + 档案字段）/ 冒烟 103（展柜/装饰数量 + Room 3 尘埃/倒影/玻璃高光 + 档案卡）；截图场景通过，标题界面实机截图见 `docs/art_direction/title_screen_ingame.jpg`。

## [v0.12.0] - 2026-10-19

### 变更（按反馈调整流程与画面）
- **标题界面改为「立绘 + UI」**：移除双羊尊转台；立绘优先读取作者图 `assets/art/title_key_art.png`（或 `.jpg/.jpeg`，任意尺寸按 cover 裁切），缺省回退到工具生成的占位图；上/下渐隐遮罩（`shade_top.png`/`shade_bottom.png`，工具生成）保证文字可读；占位图状态下底部提示替换路径。
- **据点改为「关卡选择 + 商店」两标签页**：任务页每关一张卡片——目标文物的 3D 转台（有转台条则播放动画，否则图标放大）+ 关卡名 + 目标/报酬 + 「开始行动」；商店页保留原货架；右上角「返回标题」。
- 3D 目标文物转台从标题页移到**关卡卡片**（更符合"关卡选择"的语境）。

### 新增
- `tools/gen_key_art.py`：生成占位立绘（夜空 + 月亮 + 城市剪影 + 被照亮的博物馆 + 屋顶小偷剪影，640×360）与 UI 渐隐遮罩；**不会覆盖作者立绘**。

### 测试
- 冒烟测试 96 项（新增：标题立绘加载、关卡卡片数量/顺序、卡片开始行动信号、标签页切换）。`tools/verify.sh` 7 项全绿。

### 说明
- 替换立绘：把图片放到 `assets/art/title_key_art.png`（推荐 640×360 或 2 倍尺寸）即可，无需改代码。

## [v0.11.0] - 2026-10-19

### 新增
- **标题界面（盗贼组织主题）**：墨底蓝图网格 + 金线框 + 朱砂「密档」印；中央是 3D 双羊尊转台（2× 放大）与聚光；选项：继续游戏（载入存档，附金币/背包/道具摘要）、新游戏（二次确认后清空存档）、退出游戏；底部标注目标文物馆藏信息（大英博物馆 1936,1118.1）。
- **任务终端（手机，参考《潜水员戴夫》）**：HUD 右下角终端图标（点击或按 P 打开）；「任务发布」app 显示当前任务——目标文物 3D 转台（48×56 UI 转台条）、行动地点、委托人/报酬、文物故事、注意事项；档案/商店 app 标注开发中。
- **美术管线扩展**：`gen_relic_sprite.py` 增出 UI 尺寸转台条（12 帧 × 48×56，手机/标题用）；`gen_placeholder_sprites.py` 增出终端图标（16×16）。
- `Game.start_new_game()` / `Game.has_save()`：新游戏清空进度并覆盖存档；标题界面据此决定「继续游戏」是否可用。

### 修改
- 启动流程改为：标题界面 → 据点 → 行动（原来直接进据点）；据点「退出」改为「返回标题」。
- 新增输入动作 `phone`（P 键）。

### 测试
- 逻辑 2488 项（新增：新游戏清档与存档覆盖、has_save）；内容 233 项（新增：UI 转台条尺寸校验）；冒烟 90 项（新增：标题界面信号、任务终端内容与 3D 转台装配）。`tools/verify.sh` 7 项全绿。

## [v0.10.0] - 2026-10-19

### 新增
- **3D → 2D 精灵管线**：`tools/blender/render_relic_turntable.py`（打开 `assets/models/ram_zun.blend`，透明背景、Cycles CPU、绕 Z 转台渲染 12 帧 + 1 张 hero 大图）→ `tools/gen_relic_sprite.py`（公共内容框对齐、等比缩放、共享调色板量化）产出游戏贴图。
- **转台动画文物**：`artifact.gd` 支持 `relic_<id>_strip.png`（12 帧 × 24×28，8fps 循环，底边贴合展台、光晕随高度上移）；「商代双羊尊」在关卡内以 3D 渲染的转台动画显示，与占位像素文物明显区分。
- 背包/图鉴图标 `artifact_ram_zun.png` 改由 3D 渲染降采样生成（24×24，与背包格子 1:1）。

### 修改
- 占位美术生成器不再产出 `ram_zun`（其美术改由 3D 管线负责，脚本内注明）。
- `.gitignore` 忽略 Windows 元数据文件 `*:Zone.Identifier`。

### 文档
- `docs/ARCHITECTURE.md`：新增尺寸约定（任务目标可用转台条）、artifact 行与工具行更新、§6 新增「3D 素材 → 游戏精灵」配方。
- `docs/DECISIONS.md` D-013：3D 素材只在构建期离线渲染进 2D 运行时，游戏运行时不加载 3D（`.gdignore` 隔离）。
- `docs/SOURCES.md` S-001 演绎部分补充：3D 模型为**展示性演绎再现**（细密纹饰未逐条建模），不构成考古复原。

### 测试
- 内容一致性 230 项（新增：转台条存在时尺寸须与 `Artifact` 常量一致）；冒烟测试 82 项（新增：双羊尊实际装配转台条）。`tools/verify.sh` 7 项全绿。

## [v0.9.1] - 2026-10-15

### 资产（不改变游戏运行）
- **商代双羊尊 3D 模型**（`assets/models/`，对应任务目标 ram_zun）：Blender 程序化建模——两羊背对背搭成器身、卷角羊首、喇叭口沿、扉棱、胸口饰板与分尾；约 1.2 万面，尺寸 0.412×0.221×0.442 m（对齐馆藏 41.0×45.1 cm）。导出 `ram_zun.blend` + `ram_zun.glb`（含顶点色铜绿 COLOR_0）。
- 生成脚本 `tools/blender/build_ram_zun.py`（headless 可重跑；生成物禁止手改，改形体改脚本）；`assets/models/` 带 `.gdignore`，不参与 Godot 导入（原因与用法见 `assets/models/README.md`）。
- 注明：属**展示性演绎再现**（细密雷纹未逐条建模），不构成考古复原；史实口径以 `docs/SOURCES.md` S-001 为准。

### 测试
- `tools/verify.sh` 全绿（逻辑 2481 / 内容 227 / 冒烟 80 / 编译与自检；3D 资产不参与游戏测试，由 GLB 回读渲染人工核验）。

## [v0.9.0] - 2026-10-14

### 新增
- **关卡注册表与按关卡任务目标**：`Game.LEVELS`（id/名称/地图/目标文物/报酬）+ `Game.set_level()`；任务判定改为实时对照 `mission_target_id`（丢出目标→出口上锁的行为保留），结算报酬按关卡计算。
- **大英博物馆·中国馆关卡**（第二个关卡，6 间 20×12 展厅、42×40 地图、7 名守卫）：目标为**商代双羊尊**，出口在装卸区。
- **商代双羊尊（ram_zun）**：真实文物首次进游戏——3 格 L 形背包形制、16×16 青铜贴图（双羊 + 圆尊 + 铜绿）、器灵台词「千年了……我听见另一只羊，隔着海……带我们……回家……」。
- 据点新增选关按钮（城西博物馆 / 大英博物馆·中国馆），各有独立任务简报。
- 双关卡地图由同一生成器产出（`gen_museum_map.py` 支持多关卡配置）；`check_level.py` 逐个关卡校验生成物同步。

### 修改
- `museum.gd` 支持 `level_id`：地图、任务目标、器灵台词、目标/出口房间全部按关卡解析。
- `tools/verify.sh` 新增「资源导入」步骤——新增贴图/音效后必须先 `--import`，否则运行期 `load()` 失败（本次开发中实际踩到并修复）。

### 文档
- `docs/SOURCES.md` 登记 **S-001 商代双羊尊**：年代/现藏/产地/尺寸/入藏经过、大英博物馆藏品页与论文来源、「圆明园被掠」属不可考传闻的标注、以及幽灵与拟人化叙事的虚构声明。

### 测试
- 逻辑单测 2481 项（新增：关卡注册表切换、目标判定、按关卡报酬）；内容一致性 227 项（新增：LEVELS↔CATALOG 双向一致、每个关卡恰有一个出生点/目标/出口）；冒烟测试 80 项（新增：大英博物馆关卡加载、双羊尊拾取与任务完成）。全部通过。

## [v0.8.1] - 2026-10-14

### 变更（工程维护，不改变游戏行为）
- **建立 agent 维护体系**：根目录 `AGENTS.md` 工作手册（硬性规则、命令、完成定义、多窗口协作协议）；`docs/`（架构地图、任务板 ROADMAP、决策记录 DECISIONS、史料来源登记 SOURCES）；OpenCode 命令 `/verify`、`/ship`。
- **一键验证 `tools/verify.sh`**：文档自检 + 关卡数据自检（生成物与脚本同步）+ GDScript 编译检查 + 逻辑单测 + 内容一致性测试 + 冒烟测试；`--fast` 可跳过冒烟测试。
- **新增测试**：`tests/test_content.gd`（文物/形制/商店/音效/关卡数据跨表一致性，175 项）；`tests/test_scripts.gd`（全量脚本编译检查，18 个脚本）。
- **初始化 git 仓库**：基线提交 + `.gitignore`（忽略 `.godot/` 导入缓存与 Python 缓存）。

### 测试
- `tools/verify.sh` 全绿：逻辑 2466 项 / 内容 175 项 / 冒烟 71 项；编译检查 18 个脚本；自检 2 项。

## [v0.8.0] - 2026-10-08

### 变更（画面升级批次）
- **镜头拉近 2 倍**：一屏从 40×23 格缩到 20×11 格，人物视觉尺寸翻倍；相机限位计算按缩放修正。
- **房间缩小加密度**：博物馆改为 **7 间 20×12 的小展厅**（蛇形相接），小而密、过门频繁，节奏更紧。
- **角色重绘 16×24**（原 12×16）：兜帽/大衣/腰带/挎包/鞋子，行走两帧；警察为制服+大檐帽+徽章版本。
- **文物重绘 16×16**（原 12×12），新增道具：雕像、盆栽、围栏绳（目标展台前）、挂画墙、壁灯墙、木地板/护墙板墙面；展柜改为带玻璃与展品的版本。
- **夜间灯光系统**：全局夜色（CanvasModulate）+ 展品/壁灯暖色点光（PointLight2D）+ **警察手电筒光锥**（随朝向旋转、致盲时熄灭）+ 玩家微光；文物光晕挂在文物节点上，被拿走即熄灭。
- 视锥/手电随缩放微调：视野 96px、半角 48°；交互半径 20→24（适配围栏与展台）。
- 警察新增 `set_ai_enabled()`（暂停感知与移动，保留显示），用于演出与截图流程。

### 测试
- 逻辑单测 2466 项（新地图 42×54、7 房间、目标房 3、出口房 6、新地形字符）；冒烟 71 项（房间相机、7 名警察等适配）。全部通过。

## [v0.7.0] - 2026-10-08

### 新增
- **背包鼠标拖拽**：左键拖拽文物整理摆放（光标吸附格子、放置预览、悬停显示信息）；拖到背包方框外松开即把文物**丢到场景中角色脚下**，之后可以再拾取。键盘（WASD+E+R）操作保留。
- **丢弃与任务目标联动**：任务目标被丢出背包后，出口重新上锁（`mission_complete` 改为按背包实际内容实时计算）；重新拾回即恢复。
- **小地图**（HUD 左上角，元气骑士式房间布局）：显示全部房间的排布，当前房间高亮并带玩家位置点，已探索/未探索房间区分显示，金色标记任务目标房间、绿色标记出口房间。
- 博物馆新增 `drop_artifact()` 与世界生成逻辑；记录 `visited_rooms`/`target_room`/`exit_room` 供小地图使用。

### 测试
- 逻辑单测 6198 项：新增"目标移出背包清除任务状态、放回恢复"用例。
- 冒烟测试 71 项：新增鼠标拾放/拖出丢弃信号、丢到场景后再拾取、小地图绑定与房间数据（访问记录、目标/出口房间）用例。全部通过。

## [v0.6.0] - 2026-10-08

### 新增
- **格子化背包**：文物按形制占格（青铜面具/古画轴 2 格、玉璧 3 格、其余 1 格），支持旋转（R）；拾取时自动寻找空位摆放，放不下则提示整理。
- **背包整理界面**（B 键打开，Esc/B 关闭）：光标移动、拿起/放下、旋转、放置预览（绿/红）、当前文物信息（占格/价值/故事）；打开时游戏暂停。初始背包 2x2，升级扩容至 5x4。
- **线性房间关卡**：博物馆改为五间 40x23 的展厅蛇形相接，门洞走廊单向推进；相机按所在房间锁定，一次只能看到一间房——警察位置不再一览无余。目标在中央大厅（第 3 间），出口在后门展厅（第 5 间）。
- 六名警察分驻各房间巡逻，巡逻路线限制在各自房间内；噪音与幽灵哀嚎只会惊动同一房间的警察。
- 地图生成器重写：按房间矩形生成（含地板矩形、门洞连通校验、巡逻路线房间归属校验）；关卡数据新增 rooms/floors 字段。

### 修复
- **Camera2D 从未影响画面**：世界曾挂在 CanvasLayer「World」下，而 Godot 中 CanvasLayer 内的相机不作用于该层渲染；单屏旧地图掩盖了此问题。世界改为直接挂在 Main 的默认画布，房间相机随之生效。
- 物品旋转后的格子顺序不稳定（归一化后按行列排序）。
- 退出时音频播放引用泄漏警告（停止播放并等待音频服务端释放后再退出）。
- 冒烟测试在 UILayer 下误清背包/对话框节点的问题（背包界面改为独立 CanvasLayer）。

### 测试
- 逻辑单测 6193 项：新增背包几何（形制/旋转/边界/首适位置/占位阻挡）、格子存档往返、新地图结构（五房间、地板矩形、目标/出口房间、巡逻归属）。
- 冒烟测试 51 项：新增房间相机切换、背包界面拾放/旋转；原有用例适配格子背包。全部通过。

## [v0.5.1] - 2026-10-07

### 新增
- 项目 Skill（`.opencode/skills/thief-sim/SKILL.md`）：沉淀数位历史 capstone 定位、文物通灵机制、大英博物馆关卡构想、学术规范与开发约定。
- 本 CHANGELOG：回填全部开发批次，规定后续每次改动必须记录。

### 测试
- 逻辑单测 1031 项 / 冒烟测试 35 项，全部通过。

## [v0.5.0] - 2026-10-07

### 新增
- 复古音效系统：`tools/gen_sfx.py` 纯 Python 合成 10 个 WAV（脚步/拾取/金币/拒绝/警觉/被捕/烟雾/撤离/幽灵/对话音），`Audio` 自动加载单例 + 播放器池。
- 接入：脚步随走跑节奏、拾取/背包满/出口上锁/烟雾弹/警察进入追击/被捕/撤离/幽灵哀嚎/商店购买/对话打字音。

### 修复
- 退出时因音频播放导致的资源泄漏警告（停止播放后等一帧再退出）。

### 测试
- 冒烟测试新增音频流加载检查，共 35 项全过。

## [v0.4.0] - 2026-10-07

### 新增
- 打字机对话系统（`DialogueBox`，E/Enter 继续、跳过打字），对话时暂停游戏并隐藏底部 HUD。
- 任务简报：进入关卡时由「老猫」介绍目标与规则，替换原提示条。
- 幽灵事件：拾取任务目标「青铜面具」后，被诅咒的幽灵出现并尾随玩家；每隔数秒哀嚎，吸引 96px 内警察前来调查——文物通灵系统的首个机制原型。
- 幽灵为程序绘制的半透明灵体（漂浮、跟随、渐隐自毁）。

### 测试
- 新增对话流程、幽灵哀嚎周期与寿命、幽灵引警集成测试，冒烟测试共 34 项全过。

## [v0.3.0] - 2026-10-07

### 新增
- 警察新增 INVESTIGATE 状态：听到噪音（奔跑每 0.35s 发出 64px 噪音）会走到声源处张望，期间发现玩家会加速警觉。
- 分级警戒：警察头顶显示 `?`（警觉）/`!`（追击），HUD 顶部对应显示"？附近有警察警觉了…"/"！被警察发现了！"。
- 调查中的视野锥变为橙色，玩家头顶提示首次被噪音暴露。

### 测试
- 冒烟测试新增噪音调查、警戒等级、致盲重置等用例，共 23 项全过。

## [v0.2.0] - 2026-10-07

### 新增
- 据点界面（Hub）替换原主菜单：显示金币与三行商店条目，可购买、显示状态与不足提示。
- 升级系统：加固背包（容量 +1，最高 +5，价格 250 起步递增）、静音跑鞋（疾跑 +25%）、烟雾弹（消耗品 120 金币）。
- 存档持久化：金币与升级写入 `user://save.json`，跨局/跨次启动保留。
- 烟雾弹玩法（Q 键）：扩散烟雾抵消附近警察追击并致盲 3.5s，HUD 显示余量。
- 玩家使用道具信号、警察致盲状态（视觉变灰、失去视野）。

### 测试
- 逻辑单测扩展商店购买/价格递增/满级与存档读写往返，共 1031 项；冒烟测试新增烟雾弹甩追击，共 17 项。

## [v0.1.0] - 2026-10-07

首个可玩垂直切片。

### 新增
- Godot 4.7 项目骨架：640x360 整数缩放像素视口、GL Compatibility、中文像素字体（Fusion Pixel 12px，OFL）。
- 玩家顶视角移动（WASD/方向键、Shift 疾跑、三向行走动画、碰撞）。
- 博物馆关卡（40x23，脚本生成 + 连通性校验的 JSON 地图）：展厅、陈列柜、柱子遮挡视线、出口、巡逻路线。
- 文物拾取与背包容量：任务目标「青铜面具」+ 随机额外文物（青瓷花瓶/夜明珠/古画轴/金锭/玉璧），E 拾取、容量限制、文物故事提示。
- 警察 NPC：巡逻 → 视野锥（被墙阻挡、射线检测）→ 追击 → 接触逮捕；被捕即本局 GAME OVER。
- 关卡结算：带目标撤离成功（战利品出售 + 组织报酬）或被捕失败；据点/结算界面循环。
- HUD：任务目标、金币、背包、交互提示、提示条。
- 程序生成占位美术（角色/文物/地砖/墙体等）与地图生成脚本。

### 测试
- 逻辑单测 1009 项、场景冒烟测试 11 项，全部通过。
