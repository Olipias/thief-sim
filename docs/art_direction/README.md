# 美术方向概念图（Art Direction Boards）

本目录是 `docs/ART_DIRECTION.md` 与 `docs/BRITISH_MUSEUM_ART.md` 的配套视觉稿：4 张方向板 + 关卡美术板 + 开始界面立绘 + 总览。

| 文件 | 方向 | 用途 |
| --- | --- | --- |
| `overview.jpg` | 四套方向总览 | 快速对比 |
| `A_nocturne_gilt.jpg` | 冷宫暖器 / Nocturne Gilt | 互动后特写 / 通灵层 |
| `A_pixel_gameplay.jpg` | A 方向全像素实机预演 | 常态玩法 640×360 尺度/明度/UI 检查（全像素，无实拍混入） |
| `A_two_layer_flow.jpg` | A 两层画面流程 | 常态像素玩法 → 按 E 互动 → 文物特写；转场与边界说明 |
| `B_silk_specter.jpg` | 绢本志怪 / Silk & Specter | 文物通灵、器物志、过场 |
| `C_hd2d_diorama.jpg` | 微缩夜馆 / HD-2D Diorama | 宣发、Key Art、单关演示 |
| `D_ink_seal.jpg` | 黑墨朱印 / Ink & Seal | 湖南（推定）原在地祭祀 + 入藏时间线（AI 意象稿，非史料图） |
| `BM_level_board.jpg` | 大英博物馆·中国馆关卡美术 | 6 展厅色板/灯光/动线；Room 3 目标厅优先 |
| `BM_floorplan.jpg` | 大英博物馆平面与动线 | 房间/守卫/目标/出口/流程；技术落地参考 |
| `BM_asset_sheet.jpg` | 大英博物馆资产包 | 六展厅 16×16 瓦片 + 32×32 道具 + UI 部件 + 装饰；生成器 `tools/gen_bm_art.py` |
| `BM_room3_ingame.jpg` | Room 3 实机接入截图 | 主题瓦片 + 玻璃展柜 + 双羊尊目标厅 |
| `BM_rooms_contact.jpg` | 六展厅主题巡检 | Room 0–5 实机截图；冷/暖分区与灯光气质 |
| `BM_archive_ui.jpg` | 文物档案 UI | 任务终端档案卡（可考/不可考/演绎）+ 背包双羊尊图标 |
| `title_key_art_clean.jpg` | 开始界面立绘（C 方向：微缩夜馆） | 1280×720 无字背景；博物馆 + 小偷；标题/菜单由 Godot 绘制 |
| `title_key_art_title_screen.jpg` | 标题界面安全区版 | 与 clean 同源；左侧由 UI 面板压暗 |
| `title_key_art_logo.jpg` | 开始界面立绘（左侧 UI 示意） | 检查标题/菜单安全区与可读性 |
| `title_screen_ingame.jpg` | 标题界面实机截图 | 左侧 UI 栏 + C 方向立绘的组合效果 |

## 本次修订（2026-10-19）

- **A**：新增 `A_pixel_gameplay.jpg`，常态玩法改为全像素、文物使用 32×32 sprite；`A_nocturne_gilt.jpg` 改为「互动后特写/通灵层」，不再作为可操作画面。
- **B**：已给文物加纸色、降对比、深绿描边，减少照片感；构图与绢本语言保留；下一步把实拍文物改为工笔重绘，幽灵从墨烟改为更明确的水墨人形。
- **C**：角色降饱和、压暗，融入微缩模型；明确它是宣发/单关演出层，不是常态玩法。
- **D**：主体改为「湖南（推定）·商代晚期祭祀原在地」，并加 provenance 时间线；已查证：双羊尊 1936 年购自 Eumorfopoulos，具体如何离开中国不可考，「1860 圆明园劫掠」是民间叙事，不能当史实。
- **大英博物馆关卡**：新增 `BM_level_board.jpg` 与 `docs/BRITISH_MUSEUM_ART.md`；Room 3 目标厅作为第一个 Vertical Slice。
- **资产包**：新增 `BM_asset_sheet.jpg`；生成器 `tools/gen_bm_art.py` → `assets/sprites/bm/*.png`（瓦片/道具/UI/双羊尊 32×32/玻璃展柜）。
- **Room 3 接入**：`museum.gd` 为 Room 3 启用主题瓦片 + `BMDisplayCase` 玻璃展柜 + 暖光；实机截图 `BM_room3_ingame.jpg`。
- **六展厅主题接入**：`BM_THEMES` 覆盖 Room 0–5；入口冷理石、瓷器青花、玉器暖木、青铜铜绿、丝路土红、装卸水泥金属；大英博物馆夜色调独立提亮，壁灯颜色按房间分流；实机巡检 `BM_rooms_contact.jpg`。
- **装饰层 v0.3**：13 个纯视觉装饰（安检门/售票台/展厅地图/青花·玉璧·手卷展柜/红漆柜/壁画/木箱/托盘/叉车/管道/长椅），`BM_DECOR` 按房间叠加，不新增碰撞；`BM_rooms_contact.jpg` 同步更新。
- **动效 + 档案 UI v0.4**：监控转头/警报灯闪烁/天窗呼吸；Room 3 尘埃 + 双羊尊倒影 + 玻璃高光；`Game.ARCHIVE` 文物档案卡接入任务终端，背包接入 `bm_zun_32.png` 图标；`BM_archive_ui.jpg`。
- **开始界面**：按 C 方向重绘为「微缩夜馆」立绘（博物馆 + 屋顶小偷 + 玻璃天窗 + 月亮）；`title_screen.tscn` UI 改为左侧竖栏，右侧完整展示画面。

## 生成方式与使用边界

- A/C 的「场景」由 Flux（Pollinations）生成，双羊尊使用项目内实拍图 `assets/arti-01/v2-3fe98b09d1c624a6dc042085dbe27035_r.jpg.png` 抠图合成。
- `A_pixel_gameplay.jpg` 是程序化像素绘制稿；双羊尊由实拍图降采样、限色、重绘为 30×34 像素 sprite，用于验证「全像素」语言，不含实拍抠图。
- B 使用同一张实拍图 + 程序化绢本/墨迹/金箔效果；D 的湖南祭祀版画由 Flux 生成，再经程序化纸张/套色/印章处理。
- `BM_level_board.jpg` 为程序化像素绘制；Room 3 使用 `A_pixel_gameplay.jpg`。
- 大英博物馆六展厅瓦片由 `tools/gen_bm_art.py` 生成；`BM_asset_sheet.jpg` 是 v0.2 资产总览，`BM_rooms_contact.jpg` 是六展厅实机巡检。
- 标题立绘：C 方向微缩博物馆底图由 Flux 生成，玻璃天窗、像素小偷、赃物袋、绳索、手电光锥、月亮与调色为程序化合成。
- `title_key_art_clean.jpg` 是 C 方向无字背景；`title_key_art_logo.jpg` 是左侧 UI 示意；`assets/art/title_key_art.jpg` 使用 clean 版，标题/菜单由 `title_screen.tscn` 绘制。
- 这些图只用于**方向讨论**，不是最终游戏资产，也不代表最终像素精度。
- AI 生成图不直接进游戏；正式资产需人工重绘、统一色板、清理像素网格，并确认模型/素材的商用许可。
- 真实文物与史实来源仍以 `docs/SOURCES.md` 为准（双羊尊为 S-001）。

## 重新生成

概念图的生成 prompt 见 `docs/ART_DIRECTION.md` §7。若只是调整版式，可在 `docs/art_direction/` 内替换同名 JPG，不影响 Godot 导入（本目录有 `.gdignore`）。
