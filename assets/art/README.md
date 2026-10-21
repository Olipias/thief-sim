# assets/art

标题界面相关美术。

| 文件 | 来源 | 说明 |
| --- | --- | --- |
| `title_key_art_placeholder.png` | `tools/gen_key_art.py` | 占位立绘；不要手改 |
| `shade_top.png` / `shade_bottom.png` | `tools/gen_key_art.py` | 标题界面上/下渐隐遮罩 |
| `title_key_art.png` | 作者提供（1672×941，`file_00000000e0148211a1964f9aec13058a.png` 的原名副本） | 正式标题立绘：屋顶小偷 + 大英博物馆正门；`title_screen.gd` 优先读取，`tools/gen_key_art.py` 不会覆盖 |

> 替换立绘：把新图命名为 `title_key_art.png`（或 `.jpg`）放在本目录即可，无需改代码。推荐 640×360 或更大 16:9；菜单按钮在画面里的落点按 640×360 坐标写在 `src/ui/title_screen.tscn`，换构图后需要同步调整。
