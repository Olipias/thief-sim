# 当前运行时开场（2026-11-18）

已按用户指定q6图补短对白并接入游戏。以 [OPENING_CG_HANDOFF.md](OPENING_CG_HANDOFF.md) 为准：六格、每格5秒自动播放、Space/E/点击推进、Skip直接教学。下文为早期草稿记录，不作为当前接入指令。

# 分镜草稿（art）

## 第一幕 · 第 1 张（线人用戒指抵款，草稿）

- Excalidraw 画布（可见可编辑，公开链接）：https://excalidraw.com/#json=hTmHO-Jd11RnVhnQzejdB,qIWM4SAqT9oSL-xuHjwRUQ
- 场景文件：`opening_ring_trade.excalidraw`（图片以 dataURL 内嵌）
- 底图：`opening_ring_trade_panel.png`（SiliconFlow Kolors，seed 31001，1280×960）
- 成图：`opening_ring_trade_panel_ring.png`（底图 + 在线人手指上补绘的红光戒指，PIL 绘制）
- 未采用：`opening_ring_trade_panel_v2.png`（seed 31002，线人与戒指都丢失）

### 与当前确认方案的差异（需 plan/用户确认）

`docs/CONFIRMED_DESIGN.md` §2 规定签约分镜交代「主角如何遇到恶魔并签约、恶魔的要求与违约风险、为什么第一单是青铜面具」。本草稿是「线人用戒指抵款」，**不是签约分镜**。若要作为开场，需要把戒指改为恶魔的契约信物，线人替换为恶魔或其使者。

### 已知缺口

- 戒指偏小，只在手指处有红光；不是画面主焦点。
- 主角是长外套而非连帽衫，且站立而非背对。
- 线人是蹲姿，不是靠墙。
- 没有底部细漫画格边框。
- 墙面涂鸦只在右缘可见，铁门在中景右侧。

## 第二轮（2026-11-18）

- 新链接（JPEG 内嵌，约 300KB）：https://excalidraw.com/#json=kzMY37LnEBRLsOlaurPR9,3jT5bNveSvK9hdRqWLWH6g
- 场景文件：`opening_ring_trade_v3.excalidraw`；生成脚本：`build_scene.py`（用法：`python3 build_scene.py <panel.png> <out.excalidraw>`）
- 底图：`opening_ring_trade_panel_v3.png`（Kolors，seed 31003，主角按游戏内造型描述：黑宽檐礼帽、驼色双排扣风衣、白脸、黑手套）
- 成图：`opening_ring_trade_panel_v3_ring.png`（补绘戒指，位置在线人手的指尖附近，仍偏悬空）
- 图像工具 `experimental_image_generate` 被 OpenRouter 护栏拦截，未能使用参考图生成。

### 未解决
- 远端链接是否渲染图片无法在本环境验证（网页抓取只返回空壳页面）。若仍不显示，请直接打开 `opening_ring_trade_v3.excalidraw` 或改用 `opening_ring_trade_panel_v3_ring.png`。
- 主角与游戏形象只是接近：帽子偏灰，没有精确一致；要精确一致需要支持参考图输入的图像模型。
- 戒指是后期补绘，不是模型生成。
- 线人没有靠墙，桥洞结构也不明显。
