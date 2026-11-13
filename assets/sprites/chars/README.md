# A-00 角色 sprite

完整包 `handoff_thief_art_complete_2026-11-13` 的 `player_noir.png` / `police_noir.png` 已接入（v0.19.6）；由 `tools/gen_noir_player.py` / `gen_noir_art.py` 生成。**不要手改 PNG**。

| 文件 | 单帧 | Sheet | 布局 |
| --- | --- | --- | --- |
| `player_noir.png` | **24×32** | 96×96 | 4 列 × 3 行（complete noir pack） |
| `police_noir.png` | **24×32** | 96×96 | 4 列 × 3 行（complete noir pack） |
| `player_sheet_v2.png` | 24×32 | 96×96 | 4 列 × 3 行（原版回退） |
| `police_sheet_v2.png` | 24×32 | 96×96 | 4 列 × 3 行（警察，待后续同风格重制） |

- 行：0 下 / 1 上 / 2 侧（侧向朝右，向左用 `flip_h`）
- 列：0 待机 A / 1 待机 B / 2 行走 A / 3 行走 B
- 主角接入：`hframes=4`、`vframes=3`、`Sprite2D.position.y=-10`；与警察一致，碰撞不变。
- 主角/警察：complete noir pack 24×32（黑礼帽 + 浅棕长风衣 / 深蓝制服）；源图在 `docs/art_direction/a00_src/`。
- 详细接入与验收见 `docs/art_direction/A00_DELIVERY.md`。
