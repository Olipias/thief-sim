# A-00 角色 sprite

主角为 862de05 的原版 24×32 sprite（当前 C 方案）；警察由 `tools/gen_a00_art.py` 生成。**不要手改 PNG**。

| 文件 | 单帧 | Sheet | 布局 |
| --- | --- | --- | --- |
| `player_sheet_v2.png` | **24×32** | 96×96 | 4 列 × 3 行（原版，C 方案） |
| `police_sheet_v2.png` | 24×32 | 96×96 | 4 列 × 3 行（警察，待后续同风格重制） |

- 行：0 下 / 1 上 / 2 侧（侧向朝右，向左用 `flip_h`）
- 列：0 待机 A / 1 待机 B / 2 行走 A / 3 行走 B
- 主角接入：`hframes=4`、`vframes=3`、`Sprite2D.position.y=-10`；与警察一致，碰撞不变。
- 主角：恢复 862de05 的原 24×32 sprite；AI 高清 `thief_turnaround_a` 只用于立绘/特写（C 方案）。
- 详细接入与验收见 `docs/art_direction/A00_DELIVERY.md`。
