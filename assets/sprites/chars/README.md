# A-00 角色 sprite

由 `tools/gen_a00_art.py`（绘制逻辑在 `tools/a00_characters.py`）生成，**不要手改 PNG**。

| 文件 | 单帧 | Sheet | 布局 |
| --- | --- | --- | --- |
| `player_sheet_v2.png` | 24×32 | 96×96 | 4 列 × 3 行 |
| `police_sheet_v2.png` | 24×32 | 96×96 | 4 列 × 3 行 |

- 行：0 下 / 1 上 / 2 侧（侧向朝右，向左用 `flip_h`）
- 列：0 待机 A / 1 待机 B / 2 行走 A / 3 行走 B
- 接入：`hframes=4`、`vframes=3`、`Sprite2D.position.y=-10`；碰撞保持 10×8。
- 详细接入与验收见 `docs/art_direction/A00_DELIVERY.md` §2。
