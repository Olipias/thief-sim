# A-00 SiliconFlow 概念生成记录

> 工具：SiliconFlow MCP `generate_image`；模型：`Kwai-Kolors/Kolors`。
> 说明：`black-forest-labs/FLUX.1-schnell` 在本账号返回 `403 Model disabled`，因此全部使用 Kolors。
> 这些图只用于方向/材质/构图参考，**不直接作为游戏内纹理**。游戏内角色与 UI 为手工像素/程序化绘制。

## 1. 玩家概念

- 文件：`docs/art_direction/a00_src/a00_player_concept.png`
- 尺寸：1024×1024
- Seed：24011
- Steps / CFG：25 / 7.5
- Prompt：

```text
Pixel art character design, 16-bit / 32-bit era, full body, front three-quarter top-down view, a nimble Chinese thief in a dark indigo hooded coat, cloth mask pulled down, leather satchel with brass buckle, lockpicks and small tools on belt, soft boots, fingerless gloves, subtle cyan rim light from the left, warm amber museum light from the right, crisp 1px dark outline, limited 12-color palette, clean silhouette, centered on plain dark charcoal background, no text, no UI, no watermark, character concept sheet, high detail pixel clusters, 24x32 sprite aesthetic scaled up
```

- Negative：

```text
blurry, photorealistic, 3D render, text, watermark, UI, cropped head, extra limbs, low contrast
```

## 2. 警察概念（v2）

- 文件：`docs/art_direction/a00_src/a00_police_concept_v2.png`
- 尺寸：1024×1024
- Seed：24031
- Steps / CFG：28 / 7.5
- Prompt：

```text
Pixel art full body character design, 16-bit era, top-down three-quarter view, a museum night watchman in a practical navy blue uniform, peaked cap with small brass badge, black leather belt with keys and radio, black boots, holding a small flashlight pointed down, standing, muted palette, cool blue ambient with a warm rim light, crisp 1px dark outline, centered full body including boots on plain dark charcoal background, no text, no UI, no extra props, 24x32 sprite aesthetic scaled up
```

- Negative：

```text
bust, portrait, cropped legs, military, ceremonial, photorealistic, 3D render, text, watermark, UI, extra limbs
```

> 第一版警察概念（`a00_police_concept.png`）是半身像、偏军装，未采用；v2 才作为方向参考。

## 3. 安全屋概念

- 文件：`docs/art_direction/a00_src/a00_safehouse_concept.png`
- 尺寸：1280×720
- Seed：24022
- Steps / CFG：28 / 7.5
- Prompt：

```text
Pixel art interior concept, 16-bit / 32-bit era, wide 16:9, hidden thieves safe house behind an old Chinese laundry, dim warm tungsten pendant lamp, corkboard with museum floor plans, red string and photos, workbench with lockpicks and small tools, wooden shelves with crates and Chinese ceramic vases, old CRT monitor, rotary phone, steam, rain-streaked window, dark teal shadows, amber highlights, worn wood and brick, no people, no text, no UI, cinematic composition, empty darker area on the left for UI, high detail pixel art
```

- Negative：

```text
people, characters, text, watermark, UI, photorealistic, 3D render, blurry, modern office, bright daylight
```

## 4. 电话 UI 材质概念

- 文件：`docs/art_direction/a00_src/a00_phone_ui_concept.png`
- 尺寸：1280×720
- Seed：24032
- Steps / CFG：28 / 7.5
- Prompt：

```text
Pixel art game UI concept, 16:9, a diegetic secret society smartphone mission terminal, dark brass and black glass body, cream paper mission card, red wax seal stamp, thin gold hairline borders, small Chinese artifact preview window, two tabs, signal and battery icons, worn leather texture, dark teal background, high detail pixel art, no readable text, no logos, no watermark
```

- Negative：

```text
readable text, logo, photorealistic, 3D render, blurry, modern flat UI, white background
```

> 这张概念偏“机关面板”，只取黄铜边框、黑玻璃、纸卡、朱印的材质语言；最终 UI 版式由 `A00_phone_ui.png` 重新绘制。

## 5. 角色 sprite sheet 探索

- 文件：`docs/art_direction/a00_src/a00_player_sheet_concept.png`
- 尺寸：1024×1024
- Seed：24041
- 结果：只生成了前后两个大角色，不是 3×4 网格；但它的“暗脸 + 金色眼睛 + 围巾 + 斜挎包 + 破边衣摆”被吸收进最终 24×32 sprite。
- 结论：AI 不能稳定产出 12 帧对齐的 sprite sheet，最终帧由 `tools/a00_characters.py` 手工绘制。

## 6. 使用边界

- 概念图不进入 Godot 导入目录（`docs/art_direction/` 有 `.gdignore`）。
- 游戏内资产：`assets/sprites/chars/*.png`、`assets/art/safehouse_bg.png`、`assets/art/phone_frame_9p.png`，全部由 `tools/gen_a00_art.py` 生成。
- 真实文物/史实口径仍以 `docs/SOURCES.md` 为准。

## 7. 主角最终方案（C）

- 用户选择 **C**：玩法保持原 24×32 sprite（从 862de05 恢复，与警察同尺寸）；AI 1280 高清图只用于标题/特写/立绘层。
- 已废弃：48px 填满画面、32×40、24×32 棕褐风衣重绘；`tools/gen_thief32.py` 已删除。
- 保留的高清参考：`thief_turnaround_a.png`（1280×720）、`thief_tall_side_a/b.png`。
- 2026-11-13 用户 handoff：`thief_noir_generated.png` + `tools/gen_noir_player.py` 生成 `player_noir_v2.png`（96×96，24×32 × 4×3），当前已接入 `player.tscn`。
- 结论：AI 1280 插画无法直接塞进 24×32；24×32 玩法需要独立像素 sprite，二者分层使用。

## 8. Complete noir pack（2026-11-13）

- 用户提供 `handoff_thief_art_complete_2026-11-13`：玩家/警察 24×32、安全屋、手机 9-patch、BM 六展厅 tiles/case/decor。
- 已复制到项目并用 `tools/gen_noir_player.py` / `gen_noir_art.py` 重跑验证。
- 代码接入参考：`docs/art_direction/noir_pack/接入参考.patch`。
