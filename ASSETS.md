> 2026-11-16：用户已选定标题封面 `assets/art/CPy0UzlakIPj0kfwMuVCR.png`（1376×768）。仅登记，待标题UI实现时接入；当前游戏仍可能显示旧封面。本次不修改图片或运行时代码。

# 素材清单与占位说明

本清单记录仓库现有素材，不能据此推定全部素材具有再分发许可。

| 路径 | 用途 | 来源 / 作者 | 许可与署名 | 状态 |
| --- | --- | --- | --- | --- |
| assets/fonts/fusion-pixel-12px.ttf | 中文界面字体 | Fusion Pixel 项目，版权声明见 assets/fonts/OFL.txt | SIL OFL 1.1；分发保留 OFL.txt | 外部字体 |
| assets/art/CPy0UzlakIPj0kfwMuVCR.png | 用户选定的新标题封面，待接入 | 用户提供并指定 | 作者、生成服务与许可未随指定说明，待登记，不推定可自由分发 | 已选定；1376×768，尚未接入 |
| assets/art/title_key_art.png | 标题封面 | 项目作者提供，原图副本见 assets/art/README.md | 授权范围与署名待作者确认 | 非程序生成 |
| assets/art/safehouse*、phone* | 安全屋与手机皮肤 | tools/gen_a00_art.py、gen_noir_art.py；部分源图来自 SiliconFlow 生成概念 | 生成服务条款及原图作者身份待核实 | 生成 / 派生 |
| assets/art/title_key_art_placeholder.png、shade* | 占位封面与遮罩 | tools/gen_key_art.py，项目代码生成 | 仓库未声明统一素材许可；待作者确认 | 程序占位 |
| assets/sprites/ | 瓦片、角色、文物、界面 | tools/gen_placeholder_sprites.py、gen_bm_art.py、gen_noir_player.py、gen_noir_art.py、gen_evidence_art.py、gen_ui_icons.py | 代码生成部分待项目许可确认；概念图派生部分须同时核实上游条款 | 程序 / AI概念派生 |
| assets/sprites/relic_ram_zun* | 文物转台、特写 | 作者提供的腾讯混元 Hunyuan3D 模型，经 tools/blender/render_relic_turntable.py、tools/gen_relic_sprite.py 渲染 | 混元使用条款及作者授权范围待核实；非考古复原 | AI模型派生 |
| assets/models/ | 离线建模储备 | tools/blender/build_ram_zun.py；说明见 assets/models/README.md | 程序模型待项目许可确认；原始混元 GLB 不入库 | 运行时排除 |
| assets/sfx/*.wav | 脚步、拾取、警觉、撤离、界面等 | tools/gen_sfx.py，项目程序合成 | 仓库未声明统一素材许可，待作者确认 | 合成音效 |
| assets/arti-01/ | 文物参考图 | 文件名不能证明作者、来源或许可 | 未知；不能当作可自由分发素材 | 待核实引用及导出排除策略 |
| src/ui/contract_intro.gd | 开场漫画格、剪影与字幕 | 本次新增代码绘制，无新增位图 | 随项目源码；项目总许可待作者确认 | 可替换的演出占位 |

完整文件名与哈希见 [素材文件清单](docs/ASSET_FILES.tsv)，用于审计实际文件，包含未必运行时加载的储备资源。`.import` 为引擎元数据，未列入。历史事实与参考来源见 [史料登记](docs/SOURCES.md)。

发布前待作者提供：正式封面授权、生成服务使用条款/记录、项目素材许可、参考图来源与分发授权。不得把“程序生成 / AI 生成”写成“公有领域”。


## 用户资源包（2026-11-16）
- 输入：assets/models/thief-sim-relic-assets.zip；两件GLB及12帧渲染、24px图标、360px特写。双羊尊沿用既有素材。
- 导入：`python3 tools/import_relic_pack.py`；运行时输出 assets/sprites/artifact_egypt_heart_scarab.png、artifact_akrotiri_askos.png 及 relic_<id>_strip/ui_strip/closeup.png；GLB放 assets/models/relic_pack/，该目录受父级.gdignore隔离。
- 作者/许可/署名：用户提供，包内没有明确模型或渲染图授权书，待作者确认。Met公版参考照片不能自动赋予派生模型许可。原始SOURCES说明保存在 docs/art_direction/relic_pack_sources.md。

选定封面 SHA256：`b72aa7f00f6df5611405f4083f9b9169f5b4e1e509319ab085b9bfccd487cd88`。
