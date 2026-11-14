# 路线预演验收清单（test · P1 潜行核心）

> 依据：plan #487（规划—执行—失败回放）与 `GDD.md` §5。
> 零倒计时；规划暂停；失败不判死、不扣命；全程静默测试（`--headless` 或 Xvfb 包装器）。

## 0. 建议 code 暴露的最小测试接口（便于自动化，不要求 UI 实现细节）

- `Museum.plan_mode: bool`、`Museum.waypoints: Array[Vector2]`、`Museum.max_waypoints := 5`
- `Museum.add_waypoint(pos) -> bool`、`clear_waypoints()`、`execute_route()`、`return_to_planning()`
- `signal plan_mode_changed(active: bool)`、`signal waypoint_added(index)`、`signal route_node_reached(index)`
- `signal route_failed(reason: String, source: Node2D)`（source 为保安/摄像头）
- `Museum.eta_at(pos) -> float` / `Museum.camera_covers(pos) -> bool` / `Museum.cell_risk(pos) -> String`
- `Player.crouching: bool`、`Player.crouch_speed_scale := 0.65`、跑步噪音在蹲下时为 0
- 失败回放态：`Museum.failure_replay_active`、`Museum.last_failure_reason`、`failure_overlay.visible`

> 若实现命名不同，以代码为准，但测试需要能读写规划模式、节点列表、失败原因与回退动作。

## 1. 规划模式

- [ ] `Tab` / `R` / HUD 按钮任一可进入规划；再次触发退出。
- [ ] 进入规划时关卡暂停或角色停步观察；保安/监控仍可预演，不因暂停而丢失状态。
- [ ] 鼠标左键在**当前房间可行走地面**添加节点；节点不进入墙体/展柜碰撞格。
- [ ] 最多 5 个节点；第 6 个被拒绝并有提示；右键删除最后一个。
- [ ] 每个节点显示预测：最近保安 `ETA ~Xs` 或「安全」、监控覆盖、门锁/地面风险（至少数据层可读，UI 不溢出 640×360）。
- [ ] 清空节点/退出规划后不残留输入锁或暂停死锁。
- [ ] 规划过程无任何倒计时 UI / Timer 节点。

## 2. 蹲下潜行

- [ ] `C` / `Ctrl` 切换蹲下；移速约 **0.65×**；HUD 有可读状态。
- [ ] 蹲下时跑步噪音完全消除（`made_noise` 不发出或强度为 0）；站立/疾跑仍有噪音。
- [ ] 蹲下与规划/执行/失败回放状态互不锁死；执行中按蹲下键可接管。

## 3. 执行模式

- [ ] `Space` / 「执行路线」从第一个节点开始自动移动。
- [ ] 按节点顺序到达；`route_node_reached` 序号正确；到达终点后停下并交还控制。
- [ ] 路径被保安/障碍临时挡住时有合理处理（等待/跳过/失败），不卡死。
- [ ] 执行中按任意 WASD 方向键立即取消自动移动，回到手动控制。
- [ ] 保安巡逻速度/停顿有轻微随机偏移，但同一 seed 下可复现（测试可固定随机种子）。

## 4. 失败回放（非死亡）

- [ ] 被保安视线/监控扇区发现时**不直接弹旧 ResultScreen**，不扣命/金币/背包。
- [ ] 定格约 1.5s：红色高亮连线从发现者（保安/摄像头）到玩家；顶部红色原因横幅。
- [ ] 原因至少覆盖三类：`保安巡逻偏移提前转弯`、`跑动噪音圈惊动保安`、`闯入监控摄像头扇区`。
- [ ] 按 `E` / `Space` / 「重新规划」回退到本房间起点或上一个安全节点，并自动进入规划模式。
- [ ] 回退后玩家可控、无暂停死锁、可再次添加节点/执行；连续失败不累积惩罚。
- [ ] 1.5s 为演出定格，不是倒计时/读秒；无失败计时应激。

## 5. 视觉/静默/回归

- [ ] 规划节点、预测标签、红色失败连线在 640×360 不溢出、不遮挡关键 HUD。
- [ ] 新增截图：规划模式（含节点/预测）、执行中、失败回放（红连线+原因）；基线人眼确认。
- [ ] 所有测试与截图走 `--headless` 或 `tools/verify.sh`（Xvfb 包装器），不弹窗/不抢焦点。
- [ ] 旧幽灵/器灵相关截图与断言保持删除；本清单通过后更新 `verify.sh` 计数。
