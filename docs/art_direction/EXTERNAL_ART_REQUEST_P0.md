# 外部美术需求单 P0：博物馆墙地与展厅装饰

> 2026-11-20 · art · 依据 `docs/art_direction/` 视觉审计（P0 三项：墙地细节、展厅装饰、展柜高光）
> 生成与后处理：`tools/gen_external_p0.py`（原始图存 `docs/art_direction/external_raw/`，不手改成品）

## 1. 目标

让大英博物馆六个展厅不再只靠颜色区分，墙与地有磨损与边界，每个展厅有 3–5 件主题装饰。风格保持本作的 noir 博物馆基调：深海军蓝墙、金色线脚、暗红地毯、少量冷青玻璃高光。

**参考图只用于细节密度**（层次、物件数量、磨损程度），**不用于风格**：不得复制其像素技法、配色、建筑或街景构图。

## 2. 全局规则（所有资产都必须遵守）

- 像素风，成品按 16px 网格绘制；装饰物件按 32px 级别绘制。
- **不含任何文字、数字、标签、字母**。展厅名由游戏绘制。
- **不含幽灵、器灵、灵体或发光人形**。
- 不写具体馆藏、年代或产地信息。
- 色板取自现有 `assets/sprites/bm/bm_tiles_noir.png`：
  - 墙：`#23313c` `#25333e` `#293742`
  - 金线：`#e2ba5c` `#a8823e`
  - 地毯：`#5b1f27`
  - 米白：`#e2d6be`
  - 木色：`#4e3420` `#2e1e14`
  - 玻璃冷青：`#74a8b2`
- 光源统一为左上方。
- 生成背景统一用纯品红 `#FF00FF`，后处理抠成透明。
- 不要照搬参考街景，不要出现树、招牌、自行车等与博物馆无关的元素。

## 3. P0 资产清单

| 编号 | 成品文件 | 尺寸 | 内容 | 验收要点 |
|---|---|---|---|---|
| W-01 | `assets/sprites/bm/bm_wall_trim.png` | 4×4 格，每格 16px，图集 64×64 | 墙裙上沿、踢脚线、门框侧、墙角，各 2–4 款磨损变体 | 可拼接，无明显接缝；与 `bm_tiles_noir` 墙色一致 |
| W-02 | `assets/sprites/bm/bm_floor_wear.png` | 4×2 格，每格 16px，图集 64×32 | 地面磨损、接缝、水渍、轻微裂纹，共 8 款 | 随机摆放不出现明显重复图案 |
| D-01 | `assets/sprites/bm/decor_bm_china.png` | 每件 32×32，4 件横排，图集 128×32 | 中国青铜厅：青铜礼器台座、红漆屏风一角、木箱角、灯柱底座 | 无文字；不含可辨认的具体馆藏器物 |
| D-02 | `assets/sprites/bm/decor_bm_egypt.png` | 同上 | 埃及厅：砂岩石碑底座、陶罐台、草席卷、小型灯座 | 同上 |
| D-03 | `assets/sprites/bm/decor_bm_greek.png` | 同上 | 希腊厅：白石柱础、残断柱头、石台、帷幔一角 | 同上 |
| D-04 | `assets/sprites/bm/decor_bm_silk.png` | 同上 | 丝路厅：织物展架、陶器堆、驼具木箱、小地毯 | 同上 |
| D-05 | `assets/sprites/bm/decor_bm_jade.png` | 同上 | 玉器厅：深色木台、丝绒垫、灯罩底座、小型屏风 | 同上 |
| D-06 | `assets/sprites/bm/decor_bm_dock.png` | 同上 | 装卸区：木托盘、木箱堆、金属护角、推车一角 | 同上 |

每个 D 图集共 4 件。D-01 至 D-06 合计 24 件，本批只要求每厅 3–4 件，多出的留作备选。

## 4. 生成与后处理流程

1. 通过 ofox 图像接口（`https://api.ofox.ai/v1/images/generations`，模型 `openai/gpt-image-2`）生成 1024×1024 的网格原图，每格为一个素材，背景纯品红。
2. 原图保存到 `docs/art_direction/external_raw/`，并记录提示词与 seed。
3. `tools/gen_external_p0.py` 按网格切格，把每格缩到目标像素，色板量化到上表颜色，品红转透明，写入成品路径。
4. 人工在 Godot 中预览 1×、2× 整数缩放，检查接缝与轮廓。

## 5. 验收

- 成品尺寸与上表完全一致。
- 全部成品无文字、无灵体、无品红残边。
- `tools/verify.sh --visual` 逐张人工检查，基线更新须注明变化原因。
- 接入后各展厅截图能区分出主题，且墙地无可见的规则重复。

## 6. 接入责任

| 步骤 | 负责 |
|---|---|
| 成品放入 `assets/sprites/bm/` 并 `--import` | art |
| `museum.gd` 中墙裙、地面变体与装饰按房间挂载 | Sonnet（见 `SONNET_HANDOFF.md`） |
| 视觉回归与基线 | test |

## 7. 风险

- AI 生成的瓦片容易出现接缝与不规则笔触，需要多轮挑选。已知可能失败的地方：墙裙连续性、地面重复感。
- 生成图可能偏离色板，需要量化步骤把颜色拉回现有色板。
- 本需求单不覆盖标题、角色、安全屋分层，它们在后续单独处理。

## 8. 交付状态（2026-11-20，art）

| 编号 | 成品 | 状态 | 原始图 |
|---|---|---|---|
| W-01 | `assets/sprites/bm/bm_wall_trim.png` 64×64 | 已生成，待接入后截图确认 | `external_raw/wall_grid.png` |
| W-02 | `assets/sprites/bm/bm_floor_wear.png` 64×32 | 已生成，8 款 | `external_raw/floor_grid.png` |
| D-01 | `decor_bm_china.png` 128×32 | 已生成 | `external_raw/decor_china.png` |
| D-02 | `decor_bm_egypt.png` 128×32 | 已生成 | `external_raw/decor_egypt.png` |
| D-03 | `decor_bm_greek.png` 128×32 | 已生成 | `external_raw/decor_greek.png` |
| D-04 | `decor_bm_silk.png` 128×32 | 已生成 | `external_raw/decor_silk.png` |
| D-05 | `decor_bm_jade.png` 128×32 | 已生成 | `external_raw/decor_jade.png` |
| D-06 | `decor_bm_dock.png` 128×32 | 已生成 | `external_raw/decor_dock.png` |

**已知问题（需接入后核对）**
- W-01 是墙裙、踢脚线、门框等边缘件，不是严格无缝的平铺瓦片。放置时需要按用途选格，不能随意整块铺满，否则会出现接缝。
- W-02 的格线是模型画出的深色边框，地面上会呈现网格感。若过于明显，可在 T1 中降低边框对比，或改用无边框的生成提示重做。
- 装饰件中有少量金色抖动噪点，属于 AI 生成的抖动，在 1× 下通常不明显。
- 成品只做了网格切分、抠透明和色板量化，没有手工修像素。

**复现命令**：`python3 tools/gen_external_p0.py process`（不会重新调用 API，只处理 `external_raw/` 下的原图）。

## 9. 第二轮修正（2026-11-20，art，按接入反馈）

- **W-02 地面磨损已重做**：旧版自带棕色方框，已废弃。新版 `assets/sprites/bm/bm_floor_wear.png`（64×32，4×2 格，每格 16px）是**透明背景的深色覆盖层**，内容为裂纹、水渍、划痕、污渍，不含底色与边框。接入时作为叠加层使用，建议透明度约 0.6，仍需人眼确认。原始图 `external_raw/floor_decals.png`。
- **W-01 墙件索引**：接入方已确认图集按列排列。第 1 列（索引 1/5/9/13）为踢脚线横条，第 0 列为上沿条，第 2 列为竖框，第 3 列为 V 形。以接入方实测为准。
- **D 系列索引**：每个 `decor_bm_*.png` 为横排 4 件，索引 0–3 对应从左到右。丝路（silk）索引 0 为展架、1 为陶器堆、2 为木箱、3 为小地毯。小地毯是平放的，不适合贴墙，建议只用索引 0–2，或由 art 另出一件竖向的挂毯。
