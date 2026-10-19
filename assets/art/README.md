# assets/art

标题界面相关美术。

| 文件 | 来源 | 说明 |
| --- | --- | --- |
| `title_key_art_placeholder.png` | `tools/gen_key_art.py` | 占位立绘；不要手改 |
| `shade_top.png` / `shade_bottom.png` | `tools/gen_key_art.py` | 标题界面上/下渐隐遮罩 |
| `title_key_art.jpg` | 作者提供（源：`docs/art_direction/title_key_art_title_screen.jpg`） | 正式标题立绘；`title_screen.gd` 优先读取，`tools/gen_key_art.py` 不会覆盖 |

> 替换立绘：把新图命名为 `title_key_art.jpg`（或 `.png`）放在本目录即可，无需改代码。推荐 640×360 或 2 倍尺寸（1280×720），16:9；像素图请保持最近邻缩放。
