# 安全屋道具与探索迷雾素材（A-01）

> 2026-11-20 · art · 依据 `docs/OPENCODE_NEXT_PLAN.md` 批次B/C、`docs/EXPLORATION_LOOP.md` §3
> 生成器：`tools/gen_explore_art.py`（不要手改 PNG）。

| 文件 | 尺寸 | 用途 | 接入方 |
| --- | --- | --- | --- |
| `assets/sprites/safehouse/desk_computer_32x24.png` | 32×24 | 安全屋书桌与电脑，按 E 进入电脑界面 | code（R-01） |
| `assets/sprites/safehouse/storage_box_24x20.png` | 24×20 | 文物箱，存取交互 | code（R-05） |
| `assets/sprites/safehouse/exit_door_24x40.png` | 24×40 | 房门，走到门口确认后出发 | code（R-04） |
| `assets/sprites/explore/fog_room_16.png` | 16×16 | 未探区域的统一迷雾，平铺 | code（R-11a） |
| `assets/sprites/explore/door_unknown_16.png` | 16×16 | 未探门标记 | code（R-11a） |

## 约束

- 图内无文字、无数字；不含幽灵或器灵意象。
- `fog_room_16` 是均匀纹理，不画房间边界、目标或出口，避免通过迷雾泄露布局。
- `door_unknown_16` 只表示"有一扇门"，不暗示门后是什么。
- 全部使用 nearest 缩放，不做插值。

## 接入注意（给 code）

- 道具按世界坐标放置，不能挂到 CanvasLayer 下。
- 迷雾覆盖在地图层之上、UI 之下；不要用迷雾图做遮挡判定。
- 新增 PNG 后执行 `godot --headless --import`。

## 状态

素材已交付；代码接入、碰撞与交互仍待对应 R 任务认领。
