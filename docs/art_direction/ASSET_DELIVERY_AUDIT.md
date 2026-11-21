# 素材交付审计（G10，2026-11-21）

> 依据：#869（codex，G20261121-10）。范围：运行时代码实际引用的素材、磁盘文件、`ASSETS.md` 与 `docs/ASSET_FILES.tsv` 的登记情况，以及可用于视觉检查的截图入口。
> 方法：只读。未运行 verify、`--visual` 或 godot，未生成新图，未修改 SOURCES、地图生成器或代码。
> 扫描局限：路径核查只是对 `src/` 的静态字面量扫描（`res://assets/...` 形式）。字符串拼接或变量构造的动态路径不在覆盖范围内。
> 许可原则：未知一律写“未知”，不推定可自由分发，不写成公有领域。

## 1. 运行时引用核查

- `src/**/*.gd` 与 `*.tscn` 中的 `res://assets/...` 引用：共 80 个唯一路径。
- 磁盘存在：79 个。
- 不存在：1 个，`res://assets/art/title_key_art.jpg`。位于 `src/ui/title_screen.gd` 第 18 行的候选列表中，列表依次为 `.png`、`.jpg`、`.jpeg`、占位图。这是有意的兜底链，不是缺失素材。当前实际使用 `title_key_art.png` 或用户封面。

## 2. 关键素材的来源与许可状态

| 素材 | 运行时引用 | 来源 | 许可 / 署名 | 状态 |
|---|---|---|---|---|
| 用户封面 `assets/art/CPy0UzlakIPj0kfwMuVCR.png` | `title_screen.gd` 第 16 行，标题首选 | 用户提供并指定 | 作者、生成服务与许可未知；不推定可分发 | 已接入（标题）。`ASSETS.md` 已登记 |
| 开场 q6 六格 `assets/art/opening/q6_chibi_storyboard_dialogue.png` | `src/data/opening_cg.gd` `ART_PATH` | 用户指定原图，经 OpenAI 内置 imagegen 补四个短对白 | 原图条款与署名未知；不声明公有领域 | 已接入（开场）。`ASSETS.md` 已登记 |
| 双羊尊 `relic_ram_zun*`、`artifact_ram_zun.png` | 文物转台、特写 | 作者提供的混元 3D 模型，经 Blender 渲染 | 混元条款与授权范围未知 | 已接入。`ASSETS.md` 已登记 |
| 心形圣甲虫 `relic_egypt_heart_scarab_*`、`artifact_egypt_heart_scarab.png` | 文物条、特写 | 用户资源包（`relic_pack_sources.md`） | 包内无明确授权书；Met 公版参考照片不能自动赋予派生模型许可，未知 | 已接入。`ASSETS.md`「用户资源包」一节已登记 |
| 阿克罗蒂里注壶 `relic_akrotiri_askos_*`、`artifact_akrotiri_askos.png` | 文物条、特写 | 用户资源包 | 同上，未知 | 已接入。`ASSETS.md`「用户资源包」一节已登记 |
| 博物馆瓦片、展柜、装饰（旧 noir 包） | `assets/sprites/bm/*_noir.png` 等 | `tools/gen_bm_art.py`，noir 包 | 程序生成部分待项目许可确认 | 已接入。已登记 |
| 第二、三批 ofox 生成素材（见 §3） | 见 §3 | ofox `openai/gpt-image-2`（API 生成） | 生成服务条款与输出权利未知 | 部分接入。**未登记** |

## 3. 未登记素材（art 批次，本轮补入 ASSETS.md）

`ASSETS.md` 与 `docs/ASSET_FILES.tsv` 中都找不到下列文件；`ASSET_FILES.tsv` 不在本批可改范围，已列为 plan 的待办。

| 路径 | 生成方式 | 运行时引用 | 状态 |
|---|---|---|---|
| `assets/sprites/bm/bm_wall_trim.png` | ofox 网格原图 + 切格 | `museum.gd` | 已接入（code 按列选格） |
| `assets/sprites/bm/bm_floor_wear.png` | ofox 网格原图 + 透明覆盖层处理 | `museum.gd`，开关 `BM_FLOOR_WEAR_ENABLED` 默认关 | 已接入，未开启 |
| `assets/sprites/bm/decor_bm_{china,egypt,greek,silk,jade,dock}.png` | ofox 网格原图 | `museum.gd`（每厅前 3 件） | 已接入；丝路索引 3 为平放小地毯，不用于贴墙 |
| `assets/sprites/bm/case_glass_highlight.png` | ofox 网格原图 + 透明化 | 未引用 | 未接入（C3） |
| `assets/sprites/safehouse/home_{floor,floor2,wall,trim}_16.png` | ofox 网格原图 | `safehouse.gd` | 已接入 |
| `assets/sprites/safehouse/home_{shelf,basket,lantern,cabinet}*.png` | ofox 原图（矮柜已重出） | `safehouse.gd` | 已接入 |
| `assets/sprites/safehouse/{desk_computer,storage_box,exit_door}*.png` | 程序生成（`gen_explore_art.py`） | `safehouse.gd` | 已接入 |
| `assets/sprites/wall_lamp_glow_32.png` | 程序生成（`gen_lamp_glow.py`） | 未引用 | 未接入（C4 美术部分） |
| `assets/sprites/explore/fog_room_16.png`、`door_unknown_16.png` | 程序生成（`gen_explore_art.py`） | 未引用 | 未接入（R-11 待实现） |
| `assets/sprites/monitor_cam_16.png`、`path_node_16.png` | 程序生成（`gen_evidence_art.py`） | 代码未引用 | 图片未接入（R-11/P1-B 规划标记待接） |
| `assets/sprites/ui/phone_app_*.png`、`pc_app_*.png` | 程序生成（`gen_ui_icons.py`） | 代码未引用 | 图片未接入。注意：这只说明图标图片没有被使用，不代表手机功能缺失；R-04 手机 2×2 应用首页已完成（ROADMAP），其使用的图标来源待 code 确认 |
| `tools/gen_external_p0.py`、`gen_explore_art.py`、`gen_lamp_glow.py` | 生成器 | — | 未登记为生成工具 |
| `docs/art_direction/external_raw/*.png` | ofox 原始输出（约 9 MB）与提示词 | — | 原始输出，是否入库待 plan 决定 |

## 4. 视觉检查入口与基线可信度

- 截图由 `tests/screenshot.gd` 生成，对比基线在 `tests/visual_baseline/`（88 个文件）。`tools/check_visual.py` 负责比对。
- 基线全部为 2026-11-21 02:58 生成。之后有以下改动，**旧基线不能证明新功能通过**：
  - R-12a 采购与手机采购入口（code，e64bb2b）。
  - 小地图只显示已探房间（code，0d2921d）。
  - 安全屋灯笼、家具与瓦片改动（code，aa82a32 之后）。
- 基线中没有的画面：手机采购页、迷雾/小地图、推理板拖拽界面、侦察撤离结算。
- `tests/visual_baseline/shot_sell.png.import` 存在，但 `shot_sell.png` 不存在，是孤立导入文件，建议由 test 清理。

## 5. 下一次 `--visual` 必须人工检查的项目

| 项目 | 对应截图 | 检查要点 | 基线状态 |
|---|---|---|---|
| 标题 | `shot_title` | 用户封面完整显示，菜单不遮挡关键画面，无越框 | 有基线，需重看 |
| 安全屋 | `shot_safehouse`、`shot_computer`、`shot_box` | 木板与石板地、墙裙、书架、矮柜、灯笼位置；电脑、箱子、门可辨认；不挡出生点 | 有基线，但早于新瓦片 |
| 手机采购 | 无 | 商品卡可读、价格与库存分开显示、文案无越框 | **缺基线，需新增截图** |
| 迷雾/小地图 | 无 | 未探房间不画框、不出现目标或出口标记 | **缺基线，需新增截图** |
| 推理板拖拽 | 无 | 卡片、连线、错误反馈可辨认；关系位置读档后保留 | **已实现（`test_investigation_board` 24/24，plan 实测）；缺新截图与视觉检查** |
| 失败归因 | `shot_failure_replay` | 红色高亮位置与原因文字正确 | 有基线，但回退逻辑已变 |
| 博物馆六厅 | `shot_bm_room0..5`、`shot_room3` | 墙裙、地面覆盖（若开启）、六厅装饰不压展柜与文物；Room 3 高光（C3 未做） | 有基线，早于新装饰 |

## 6. 缺口与交接

| 缺口 | 归属 | 说明 |
|---|---|---|
| `ASSET_FILES.tsv` 缺 §3 未登记素材 | art | 已于 #902 收尾追加 36 行（磁盘实际文件，sha256）；许可仍未知，登记不构成许可结论 |
| ofox 与 SiliconFlow 生成条款、输出权利 | 用户 / plan | 未核实，需在发布前确认 |
| `case_glass_highlight.png`、`wall_lamp_glow_32.png` 未接入 | code（C3/C4） | 美术已交付，接入由 Claude/code 完成 |
| `fog_room_16.png`、`door_unknown_16.png`、`monitor_cam`、`path_node` 未接入 | code（R-11） | 依赖迷雾系统实现 |
| `phone_app_*`、`pc_app_*` 图标图片未被代码引用 | code（R-04） | R-04 手机应用首页已完成；需确认其图标来源，若要用本批图标则接入 |
| 手机采购、迷雾、推理板等缺视觉基线 | test | 需在合适时机跑一次 `--visual` 并新增基线，art 不自行运行 |
| `shot_sell.png.import` 孤立 | test | 清理 |

## 7. 未做的事

- 没有运行 `verify`、`--visual`、godot。
- 没有生成新图片。
- 没有修改 SOURCES、地图生成器、代码、测试或 `ASSET_FILES.tsv`。
- 没有核实任何生成服务的条款；所有“未知”保持为未知。
