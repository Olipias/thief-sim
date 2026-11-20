# Sonnet 交接：博物馆视觉升级（P0/P1 执行单）

> 2026-11-20 · art 编写 · 依据 `docs/art_direction/` 视觉审计报告与 `EXTERNAL_ART_REQUEST_P0.md`
> 使用方式：把本文件整份交给 Sonnet；它先读第 1 节的文档，再按第 3 节逐条执行。

## 1. 开工前必读（按顺序）

| 顺序 | 文件 | 为什么读 |
|---|---|---|
| 1 | `AGENTS.md` | 项目硬规则：World 不挂 CanvasLayer、生成物不手改、测试必跑、并行窗口纪律 |
| 2 | `docs/ROADMAP.md` | 认领任务，改成 `🚧 进行中｜Sonnet｜日期` 后再动手；注意 A-01 为 art 认领 |
| 3 | `docs/ARCHITECTURE.md` §5（覆盖层与暂停契约） | 不要改动覆盖层与输入路由 |
| 4 | `docs/art_direction/EXTERNAL_ART_REQUEST_P0.md` | 素材规格、色板、命名；生成物在这里定义 |
| 5 | `docs/art_direction/EXPLORE_ART.md` | 迷雾与安全屋道具的接入约束（迷雾不得作为遮挡判定） |
| 6 | `docs/DECISIONS.md` D-003 | 为什么 World 节点不能挂 CanvasLayer |

**不要读**：`.godot/`、`build/`、`.git/`、`tests/visual_baseline/` 中与任务无关的截图、`handoff_*` 旧目录、旧 README 草稿。`museum.gd` 约 70KB，只按行号段读取，不要整文件读。

## 2. 当前事实（已核实，见审计报告）

- 渲染：`gl_compatibility`，默认纹理过滤为 Nearest，视口 640×360，整数缩放。
- 灯光：`CanvasModulate` 与 `PointLight2D` 已在 `museum.gd`（约 395–466 行）、`safehouse.gd`（约 61、200 行）、`artifact.gd` 使用。
- **没有** `.gdshader` 文件，**没有** `LightOccluder2D`，**没有** `shadow_enabled` 设置。
- 墙与地为平铺的 `bm_tiles_noir.png` 变体，视觉重复明显。
- 展厅 decor 数量少（`assets/sprites/bm/decor_noir/` 共 16 个）。

## 3. 任务清单（按顺序执行，每条独立验收）

### T1 墙裙与地面变体接入（依赖外部美术素材）

- 素材：`assets/sprites/bm/bm_wall_trim.png`（64×64，4×4 格，16px）、`assets/sprites/bm/bm_floor_wear.png`（64×32，4×2 格）。
- 做法：在 `museum.gd` 的房间瓦片选择处，墙与地从原有变体数组中**追加**新格，按房间随机但种子固定（不得每次进房间随机变化，避免读档后画面跳动）。墙裙放在墙底一行。
- 验收：`tools/verify.sh --visual` 逐张人工检查；墙地无明显规则重复；`test_scenes` 通过。
- **状态**：素材已于 2026-11-20 生成（见 `EXTERNAL_ART_REQUEST_P0.md` §8）。W-01 为边缘件，不是无缝瓦片，放置时按用途选格；W-02 格线较明显，接入后截图确认是否需要降低对比。

### T2 展厅主题装饰挂载（依赖外部美术素材）

- 素材（已生成）：`assets/sprites/bm/decor_bm_{china,egypt,greek,silk,jade,dock}.png`（每张 128×32，4 件横排，每件 32×32）。
- 做法：在现有 `BM_DECOR` 装饰层按房间挂载，**纯视觉**，不新增碰撞，不改变守卫路线与视线判定。每厅挂 3–4 件。
- 验收：六厅截图能区分主题；`test_scenes` 通过；装饰不挡门、不挡展柜交互热点。

### T3 灯光遮挡与阴影（不依赖新素材，先做）

- 做法：为墙体与展柜添加 `LightOccluder2D`（使用矩形多边形，贴合墙根与展柜底座，不要包住玩家可走区域）；主灯（展柜光、墙灯）开启 `shadow_enabled`，并限制阴影半径。
- 约束：**不得**让阴影或遮挡体影响守卫视锥、噪音或任何模拟判定；它们只是画面。
- 验收：阴影不穿墙；`test_sim_preview` 与 `test_logic` 全绿；截图人工确认阴影方向与左上光源一致。

### T4 统一色温表（不依赖新素材）

- 做法：把各房间 `CanvasModulate` 颜色集中到一张表（常量字典），房间之间用一次性插值过渡，不做硬切。
- 验收：六厅色温视觉一致；切房间无闪烁。

### T5 视锥渐变与尘埃粒子（不依赖新素材）

- 做法：视锥可视化增加边缘渐变；展厅加少量尘埃粒子（`CPUParticles2D` 优先，数量小，低开销）。
- 约束：粒子与渐变**只属于画面层**，不得作为判定输入。
- 验收：`test_sim_preview` 逐 tick 一致不受影响；截图区域变化在 `check_visual` 阈值内（5%）。

### T6 角色接触阴影（不依赖新素材）

- 做法：为玩家、守卫、警察各加一个椭圆接触阴影精灵（程序绘制或小尺寸 PNG，若用 PNG 则经 `tools/` 脚本生成）。
- 验收：移动时阴影跟随，不穿地面。

### T7 展柜玻璃高光与墙灯投影（依赖外部美术，可放最后）

- 素材：待 art 另行交付；未到位前不做。

## 4. 每条任务的通用门槛

1. UI 或输入改动必须有真实按键/鼠标测试（`tests/test_input_flow.tscn`）。
2. 新增"任何时刻都应成立"的规则加入 `tests/test_monkey.gd`。
3. 运行 `tools/verify.sh --fast`；画面改动再跑 `tools/verify.sh --visual`。
4. 基线更新必须写明视觉变化原因；**不得**用覆盖基线掩盖错图或缺界面。
5. 更新 `CHANGELOG.md`、`README.md` 开发进度与 `docs/ROADMAP.md`。
6. 测试输出必须干净：引擎 `ERROR/WARNING` 会让 verify 失败，不得往允许清单里随意加行。
7. 本机无音频驱动，headless 输出中的 libasound 警告属于正常现象。

## 5. 不做的事（明确排除）

- 不写 shader，除非 T3–T6 完成后仍有明确效果缺口，并先向 plan 报告。
- 不改玩法、路线判定、守卫逻辑、存档字段。
- 不生成或修改图片；素材只通过 art 的脚本与外部生成流程产出，Sonnet 只接入。
- 不恢复幽灵、器灵或任何灵体效果。
- 不在展厅中加入具体馆藏信息文字。

## 6. 交付物

- 代码改动文件列表与原因。
- 每条 T 任务的验收结果（通过、失败、待素材）。
- 截图路径与基线变化说明。
- 未完成项及阻塞原因。

## 7. 第二批（2026-11-21）：安全屋 noir 化与展柜高光

### 美术已交付的素材

| 文件 | 尺寸 | 用途 |
|---|---|---|
| `assets/sprites/safehouse/home_floor_16.png` | 64×16（4 格） | 安全屋地板，两种交替使用 |
| `assets/sprites/safehouse/home_wall_16.png` | 64×16（4 格） | 安全屋墙面 |
| `assets/sprites/safehouse/home_trim_16.png` | 64×16（4 格） | 墙裙/踢脚 |
| `assets/sprites/safehouse/home_shelf_32x48.png` | 32×48 | 书架（纯视觉，靠墙） |
| `assets/sprites/safehouse/home_basket_24x20.png` | 24×20 | 洗衣篮（纯视觉） |
| `assets/sprites/safehouse/home_lantern_16x24.png` | 16×24 | 红灯笼（挂墙，纯视觉） |
| `assets/sprites/safehouse/home_cabinet_32x20.png` | 32×20 | 矮柜（纯视觉，靠墙） |
| `assets/sprites/bm/case_glass_highlight.png` | 32×32 | 展柜玻璃高光（半透明覆盖层，叠在展柜上） |

### Claude 需要做的事

**C1 安全屋接入 noir 瓦片**（`src/world/safehouse.gd`，`_build_room`）
- 地板：`TEX_FLOOR_A/B` 改为 `home_floor_16.png` 的第 0、1 格，继续用 `(x+y)%2` 交替。
- 墙与墙裙：`TEX_WALL` 改为 `home_wall_16.png` 第 0 格；顶/底边缘用 `home_trim_16.png`。
- 地毯 `carpet.png` 与 `plant.png`、`wall_lamp.png`、`wall_painting.png` 暂保留，之后可统一。
- 验收：`test_scenes` 通过；安全屋截图墙地不再是通用占位风格。

**C2 安全屋陈设摆放**（纯视觉，不新增碰撞）
- 书架放在顶墙右侧，柜子放在底墙左侧，洗衣篮放在角落。
- 红灯笼挂在墙面两处，避开电脑与房门。
- 注意：书架、矮柜是有体积的家具，**若要挡路，需要另行加 `_add_solid`**，本批不加，由你决定是否需要碰撞。
- 摆放不得挡住 `DESK_POS`、`BOX_POS`、`DOOR_POS`，也不得压住玩家 `SPAWN_POS` 附近。

**C3 展柜玻璃高光**（`src/world/museum.gd` 或 `BMDisplayCase`）
- 在展柜上方叠加 `case_glass_highlight.png`，透明度约 0.5，可加轻微的缓慢闪动（周期 3–4 秒）。
- 只属于画面层，不得参与守卫视锥、噪音或任何模拟判定。
- 验收：Room 3 截图确认高光不遮挡文物本体，`check_visual` 阈值内。

**C4 墙灯与展柜投影**（可选，依赖 T3 的遮挡体）
- 墙灯下方加一个小的投影精灵，仅在 `LightOccluder2D` 已存在时做。

### 验收与基线

- 完成 C1–C3 后运行 `tools/verify.sh --visual`，逐张人工检查安全屋与 Room 3 截图。
- 基线更新必须写明变化（"安全屋地面由通用瓦片换为 noir 瓦片"之类），不要覆盖掉错图。
- 未完成的 C4 请在 ROADMAP 标注为待办。

### 文件名补充（2026-11-21 核对）
- 地板有两套：`home_floor_16.png`（木板，4 格）与 `home_floor2_16.png`（石板，4 格）。C1 中"地板两种交替"应分别用这两个文件的第 0 格，不要混用同一文件的不同行。
- 墙面只有一套：`home_wall_16.png`，取第 0 格。
- 展柜高光 `case_glass_highlight.png` 已是单张 32×32、透明背景，直接叠加即可，不需要切格。

### 第三批补充（2026-11-21）：矮柜重出与墙灯光晕

- `assets/sprites/safehouse/home_cabinet_32x20.png`：已按 ofox 候选重出，选素平双门款，木色色板、无抖动，取代上一版偏红的矮柜。
- `assets/sprites/wall_lamp_glow_32.png`（32×32，透明，程序生成，`tools/gen_lamp_glow.py`）：墙灯光晕，居中叠在 `wall_lamp.png`（16×16）上。
  - 建议用加法混合（CanvasItemMaterial blend_mode ADD）叠加；若用普通混合，透明度约 0.4–0.5。
  - 只属于画面层，不参与判定。
  - 这是 C4 的美术部分，投影仍依赖 T3 的遮挡体。
