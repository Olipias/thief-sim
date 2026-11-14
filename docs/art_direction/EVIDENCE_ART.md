# P3 / P6 证据链美术资产（art）

> 2026-11-14 · art · 依据 `docs/GDD_V2.md` 与 `docs/STORY_PLAN.md` P3/P6
> 生成器：`tools/gen_evidence_art.py`（不要手改 PNG）。概念原图：`docs/art_direction/a00_src/evidence_*_concept.png`。

## 1. 资产清单

| 文件 | 尺寸 | 用途 | 接入方 |
| --- | --- | --- | --- |
| `assets/sprites/artifact_egypt_stela.png` | 16×16 | 背包/列表图标（`artifact_<id>.png` 回退） | code |
| `assets/sprites/artifact_greek_relief.png` | 16×16 | 同上 | code |
| `assets/sprites/relic_egypt_stela_ui_strip.png` | 576×56（12 帧 × 48×56） | 任务卡/手机转台条（`relic_<id>_ui_strip.png`） | code |
| `assets/sprites/relic_greek_relief_ui_strip.png` | 576×56 | 同上 | code |
| `assets/sprites/egypt_stela_closeup.png` | 360×360 | 端详/档案特写 | code（见 §3） |
| `assets/sprites/greek_relief_closeup.png` | 360×360 | 同上 | code（见 §3） |
| `assets/art/safehouse_clue_board.png` | 1280×720 | 安全屋推理板底图（640×360 逻辑 ×2） | code：推理页背景 |
| `assets/art/safehouse_computer_frame_9p.png` | 96×96，margin 12 | 安全屋电脑窗口 9-patch | code：电脑页边框 |

ID 约定与 `src/data/evidence.gd` 一致：`ram_zun`（已有）/ `egypt_stela` / `greek_relief`。

## 1b. Batch 2 追加资产（plan #453）

| 文件 | 尺寸 | 用途 | 接入方 |
| --- | --- | --- | --- |
| `assets/sprites/bm/egypt_stela_case.png` | 32×48 | 埃及馆展柜（同 `bm_case_noir` 尺寸） | code：BM 展柜按目标切换 |
| `assets/sprites/bm/greek_relief_case.png` | 32×48 | 希腊馆展柜 | 同上 |
| `assets/sprites/bm/egypt_hall_plaque.png` | 32×16 | 埃及馆墙上展签底（文字由游戏绘制） | code |
| `assets/sprites/bm/greek_hall_plaque.png` | 32×16 | 希腊馆展签底 | code |
| `assets/sprites/monitor_cam_16.png` | 16×16 | P1-B 监控摄像头头部 | code：监控扇区标记 |
| `assets/sprites/path_node_16.png` | 16×16 | P1-C 路径节点标记 | code：路径点渲染 |

展签与展柜中**不含任何文字**；展厅名由游戏绘制，避免伪造馆藏文字。展柜内的文物仍是占位（见 §2）。

## 2. 状态（诚实说明）

- **16×16 图标、UI 转台条、板底、电脑边框**：程序化像素绘制，可直接接入。
- **两件新文物特写（closeup）**：是 **占位**。从 SiliconFlow 概念图降采样为 72px 母版再 5× 放大。
  - 埃及墓碑概念是**彩绘面板而非拱形石碑**，且含 AI 生成的伪象形文字；**不得当作史料图，也不要让玩家把它读成真实铭文**。正式版需按 `docs/SOURCES.md` S-003 的史料重绘。
  - 希腊浮雕概念是泛化的骑马浮雕，**不是** 1816,0610.28 的忠实复刻；正式版需按 S-004 史料重绘。
- 所有 closeup 都应在界面注明「占位图，待史料重绘」或由 code 在档案页隐藏该图，直到正式版交付。

## 3. 接入注意（给 code）

1. `src/ui/relic_view.gd` 当前只对 `item_id == "mask"` 读取 `<id>_closeup.png`；`src/ui/inspect_page.gd` 走 `Lore.closeup_path()`（`CLOSEUPS` 表）。请把两件新文物加进 `Lore.CLOSEUPS`，而不是在 `relic_view` 里写死 id。
2. 16×16 图标通过 `artifact_<id>.png` 回退路径读取，无需改代码。
3. UI 转台条按 `relic_<id>_ui_strip.png` 命名读取（12 帧、48×56），与 `ram_zun` 一致。
4. 推理板与电脑边框请用 `NinePatchRect`/`StyleBoxTexture`，中心区域保持纯色以便文字可读。
5. 新 PNG 需要 `godot --headless --import` 生成 `.import`；不要提交未导入的状态。

## 4. 验收建议（给 test）

- 16×16 图标与 ui_strip 尺寸：`16×16`、`576×56`、12 帧。
- closeup 为 360×360；`Lore.closeup_path("egypt_stela")` 与 `greek_relief` 非空且文件存在。
- 推理板 1280×720、电脑边框 96×96。
- 视觉：档案页/任务卡中新文物图标不糊、不溢出；closeup 标注占位。

## 5. 复现

```bash
python3 tools/gen_evidence_art.py
```

只会改写本文件列出的 8 个 PNG；概念原图需保留在 `docs/art_direction/a00_src/`，否则 closeup 会回退到程序化母版。
