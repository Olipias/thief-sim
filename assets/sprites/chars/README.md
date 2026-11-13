# A-00 角色 sprite

由 `tools/gen_thief32.py`（主角 32×40）与 `tools/gen_a00_art.py`（警察 24×32）生成，**不要手改 PNG**。

| 文件 | 单帧 | Sheet | 布局 |
| --- | --- | --- | --- |
| `player_sheet_v2.png` | **32×40** | 128×120 | 4 列 × 3 行（主角 Rev.3） |
| `thief32_front.png` / `_side.png` / `_back.png` | 32×40 | — | 三视图单帧 |
| `thief32_turnaround.png` | 32×40 | 96×40 | 正 / 侧 / 背 |
| `police_sheet_v2.png` | 24×32 | 96×96 | 4 列 × 3 行（警察，待后续同风格重制） |

- 行：0 下 / 1 上 / 2 侧（侧向朝右，向左用 `flip_h`）
- 列：0 待机 A / 1 待机 B / 2 行走 A / 3 行走 B
- 主角接入：`hframes=4`、`vframes=3`、`Sprite2D.position.y=-13`；碰撞不变。
- 主角设计：`thief_turnaround_a` 同款礼帽 + 棕褐风衣 + 斜挎包；SiliconFlow 概念见 `docs/art_direction/a00_src/thief_turnaround_a.png`。
- 详细接入与验收见 `docs/art_direction/A00_DELIVERY.md`。
