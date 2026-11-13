# P3 / P5 / P6 验收清单（test）

> 依据：`docs/GDD_V2.md`、`src/data/evidence.gd`、`docs/art_direction/EVIDENCE_ART.md`。
> 数据层已由 `tests/test_reasoning.gd`（144 项）锁定；以下 E2E 用例待 code Batch 1 落地后补进
> `tests/test_input_flow.gd` / `tests/test_reasoning.gd`。全部路径以 640×360 逻辑分辨率为准。

## 0. 数据层（已完成）

- [x] 三条链固定为 `ram_zun` / `egypt_stela` / `greek_relief`，每条 3 卡 + 2 连线，连线覆盖全部卡。
- [x] 来源 App 分布：档案库 3 / 浏览器 3 / 邮件 1 / 手机聊天 2；未知 App 返回空。
- [x] 零倒计时：无 `timer` / `countdown` / `time_limit` / `deadline` 字段，正文无「倒计时/限时/读秒」。
- [x] `p00_devil_contract` / `p05_devil_demand` 的 goto、卡片引用、全选项分支可达；p05 三结局卡均可达。
- [x] H-01 第一张卡保留「尤摩弗帕勒斯 / 1936,1118.1」；p05 三张结局卡都有「史实/虚构」声明，且不把 1860 写成史实。

## 1. P2-A 恶魔契约开场

- [ ] 新游戏首次开局先播 `p00_devil_contract`，完成后 `Game.story_flag("saw_p00") == true` 且落盘。
- [ ] 开场三个选项（只拿一件 / 反悔 / 按手印）都能播到结束，不软锁。
- [ ] 跳过开场后仍能进入标题/据点，不重复阻塞（若设计为可跳过）。
- [ ] 已有老档（无 `saw_p00`）进入时只播一次，二周目/读档不重复。

## 2. P2-B 城西教学直连安全屋

- [ ] 城西博物馆成功撤离后**不出现独立 ResultScreen**，直接进入 `Hub` 并播 P-01。
- [ ] 失败/被逮路径保持现有结算（不被直连逻辑吞掉）。
- [ ] 直连后 `saw_p01` 落档；奖励、仓库、背包状态与旧结算一致（不丢金币/赃物）。

## 3. P3 安全屋电脑 / 推理板

- [ ] Hub 顶栏出现「推理（电脑）」标签，640×360 不溢出；键盘/鼠标都能切换。
- [ ] 四个来源可点：电脑·档案库 / 浏览器 / 邮件 / 手机·密信；点击线索卡写入 `Game.story_flag("clue_<id>")` 并即时高亮。
- [ ] 单条链集齐 3 卡后「连线验证」可用；按 `required_links` 两两连线成功 → `chain_<id>_done` 落档，目标解锁。
- [ ] `Game.unlock_all_chains_required = false`：单链完成即解锁对应目标；`true`：三条链全完成才出现目标选择。
- [ ] 未集齐/连线错误时有明确提示，不误写 `chain_*_done`。
- [ ] 全流程无任何倒计时 UI / Timer 节点；暂停阅读不触发失败。

## 4. P5 恶魔催交与检查点

- [ ] 出发大英前写入命名检查点 `pre_heist`；回安全屋面临选择前写入 `pre_choice`。
- [ ] 大英成功撤离回 Hub 先播 `p05_devil_demand`，不再直接弹旧 ResultScreen。
- [ ] 阶段一「直接上交」→ `ending_id` 为顺从；「拒交」→ 先显示 `wrath_scene`，再出阶段二。
- [ ] 阶段二：屈服补交 → 顺从；归还阿岚 → 归还结局；卖给老秤 → 黑市结局；三者均落 `ending_id` 且结局页文案对应。
- [ ] 结局页/安全屋有「从检查点重返安全屋」按钮；回溯保留 `chain_*_done`、线索卡与已解锁目标，清空当次携带物。
- [ ] 检查点回溯后再次进入大英可换另一目标，且一次行动只结算一件。

## 5. P6 三目标注册与素材

- [ ] `Game.CATALOG` / `Game.ARCHIVE` 均有 `egypt_stela`、`greek_relief`（名称/年代/来源/正文齐全）。
- [ ] `Collection` 收集册显示两件新文物，未归档为「？？？」；归档后显示图标与档案。
- [ ] Hub 任务卡只列出已解锁目标；选择埃及/希腊后关卡内目标物、出口条件、结算奖励正确。
- [ ] `Lore.CLOSEUPS` 有 `egypt_stela` / `greek_relief`，文件存在且 360×360；档案/端详页能看到特写。
- [ ] 两件特写当前为**占位图**：界面必须有「占位图，待史料重绘」标注（或正式版前隐藏）；不得当作最终史实图像验收。
- [ ] 图标 16×16、UI 转台条 576×56（12 帧 × 48×56）、推理板 1280×720、电脑边框 96×96（margin 12）；640×360 无溢出/拉伸。

## 6. 每批收尾

- [ ] `tools/verify.sh --fast` 全绿（加入新用例后更新计数）。
- [ ] UI/画面改动后 `tools/verify.sh --visual`，33+ 张基线逐张人眼确认；新增推理板/恶魔分支截图补基线。
- [ ] `CHANGELOG.md` / `README.md` / `docs/ROADMAP.md` 同步；历史表述复核 `docs/SOURCES.md` S-003 / S-004。
