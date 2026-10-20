# 架构地图（ARCHITECTURE）

> 目的：让 agent 快速建立正确的心智模型，并按配方（Recipes）安全扩展。
> **维护要求**：改动架构（新增模块、数据格式、信号契约、存档字段）时同步更新本文件。

## 1. 总览

```
main.tscn (Main, src/main.gd) —— 唯一场景编排者
├── Screen (Node2D)          世界层：Hub / Museum 场景挂在这里
│                            ⚠ 必须挂在默认画布，不能塞进 CanvasLayer（相机失效，见 D-003）
├── UILayer (CanvasLayer)    全屏界面：标题 TitleScreen、据点 Hub、结算 ResultScreen
├── HUD (CanvasLayer)        任务/金币/背包/提示/警戒/小地图 + 右下角任务终端按钮
├── Backpack (CanvasLayer)   格子背包整理界面
├── Phone (CanvasLayer)      任务终端（手机）：任务发布 + 档案（端详）
├── Statements (CanvasLayer) 声明与说明（标题页入口；非游戏内覆盖层，不暂停）
├── RelicCloseup (CanvasLayer) 互动特写层（2.5D，按 E 触碰重点文物；打开即暂停）
└── Dialogue (CanvasLayer)   打字机对话框

Autoload
├── Game  (src/autoload/game_state.gd)   全局状态：金钱/背包/升级/关卡注册表/存档
└── Audio (src/autoload/audio.gd)        音效池
```

场景流：`Title`（标题/存档）→ `Hub`（据点商店 + 选关）—开始任务→ `Museum`（潜行关卡）—撤离/被捕→ `Result`（结算）→ `Hub`。
界面之间**不互相引用**：一切通过 `main.gd` 连接信号、切换场景、控制暂停（`get_tree().paused`）。

## 2. 模块职责表

| 文件 | 职责 | 关键点 |
| --- | --- | --- |
| `src/main.gd` | 场景流程编排、暂停控制、任务简报 | 手机/背包开关带 0.2s 冷却（`toggle_allowed()`），防关闭后同帧被重开； 世界加到 `Screen`；HUD/对话/背包的信号在这里接线；`start_mission(level_id)` 设定关卡并显示对应简报 |
| `src/actors/player.gd` | 玩家移动（走/跑）、拾取、道具、噪音、脚步 | 信号 `used_item` / `made_noise`；分组 `player`；`controls_enabled` 冻结操控；场景内 `Camera2D`（zoom 2×，即一屏 20×11 格）+ 玩家微光 `Aura` |
| `src/actors/police.gd` | 警察 AI：巡逻 → 调查 → 追击 → 逮捕 | 状态机 `State{PATROL,INVESTIGATE,CHASE}`；`in_cone()` 纯函数（可单测）；视野射线仅被墙阻挡（mask=1）；**视物与逮捕要求与玩家同房间**（`can_see_player()` + `museum.room_index_at`，门洞可走但不隔房索敌）；`blind()` 烟雾致盲（同时熄灭手电）；`alert_level()` 0/1/2；`set_ai_enabled()` 供演出/截图暂停感知 |
| `src/world/museum.gd` | 关卡构建与全部关卡规则 | `level_id` → 地图/目标/器灵台词按关卡解析（`target_item_id()`）；读 JSON 建碰撞/灯光/角色；房间相机；小地图数据；幽灵事件；烟雾弹；噪音与哀嚎按房间分流；出口锁；**大英博物馆六展厅主题**（`BM_THEMES` + `_room_of_tile` + `_draw_bm_tile()`）+ **纯视觉装饰层**（`BM_DECOR` + `_build_bm_decor()`，不新增碰撞）+ **装饰动效与 Room 3 光影**（`_animate_bm_decor()`、`BMDust`/`BMZunReflection`/`BMGlassGlint`）；**视觉/碰撞一致性**（`is_cell_blocked()` + `BM_SOLID_DECOR`，T/a/p 展台与大件装饰有实体） |
| `src/world/artifact.gd` | 场景中的可拾取文物 | 贴图约定 `artifact_<id>.png`（16×16 图标）；若存在 `relic_<id>_strip.png` 则显示 3D 渲染转台动画（12 帧 × 24×28，常量在脚本内）；拾取成功/失败信号 |
| `src/world/ghost.gd` | 幽灵：尾随 + 周期哀嚎 + 寿命渐隐 | `wailed(position)` 由 museum 转给附近警察 |
| `src/world/smoke_puff.gd` | 烟雾视觉（纯表现） | 不承载规则 |
| `src/ui/hub.gd` | 据点：商店购买 + 开始任务 | `ROWS` 决定货架顺序，须与 `Game.UPGRADES` 一致（有测试） |
| `src/ui/hud.gd` | HUD 全部显示 | 监听 `Game` 三信号；`bind_level()` 绑小地图；`toast()` 提示 |
| `src/ui/minimap.gd` | 房间小地图 | 从 `museum.rooms` 坐标自动推列/行；标目标/出口/当前房间/玩家点 |
| `src/ui/backpack_screen.gd` | 背包整理（键盘 + 鼠标拖拽） | 拖出方框 → `drop_requested` 交给 main 丢到场景；打开时由 main 暂停 |
| `src/ui/bag_grid.gd` | 背包格子绘制 | 只负责画，不存数据；`ram_zun` 使用 `bm_zun_32.png` 图标 |
| `src/ui/dialogue_box.gd` | 打字机对话 | `advance()`；暂停由调用方控制 |
| `src/ui/result_screen.gd` | 结算界面 | 展示 `Game.finish_run()` 返回的 summary |
| `src/ui/title_screen.gd` | 标题界面（立绘 + UI） | 立绘优先 `assets/art/title_key_art.jpg` / `.png`（作者图），缺省 `title_key_art_placeholder.png`；渐隐遮罩 `shade_*.png`；继续/新游戏（二次确认）/退出 |
| `src/ui/hub.gd` | 据点：关卡选择 + 商店 | 任务页由 `Game.LEVELS` 动态生成卡片（`RelicView` 展示目标文物）；商店页保留货架；`ROWS` 须与 `UPGRADES` 一致（有测试） |
| `src/ui/mission_phone.gd` | 任务终端（手机） | 右下角按钮或 P 打开；「任务」页读 `Game.level_info()/mission_target_id` + `Game.ARCHIVE` 文物档案卡；「档案」页端详随身文物（热点 + 展签卡）；打开时由 main 暂停 |
| `src/ui/relic_view.gd` | 文物展示控件 | 优先 `relic_<id>_ui_strip.png`（12 帧 × 48×56，常量在此），否则静态图标放大；手机/关卡卡片共用 |
| `src/data/lore.gd` | 文物志数据（静态类 `Lore`） | 剧本（speech/card/choices/label/goto）、展签卡（世界观口吻的史实）、端详热点（归一化坐标）；文本与代码分离，新增文物志只改这里 + `docs/SOURCES.md` |
| `src/data/statements.gd` | 正式声明数据（静态类 `Statements`） | 项目性质、史实/虚构分界、真实文物与来源、3D 模型说明、字体许可、立场与致谢；游戏内**不放**学术引用，全部集中于此 |
| `src/ui/statements_screen.gd` | 声明与说明页（标题入口） | 纸卡 + 滚动列表；非游戏内覆盖层（不暂停），ESC / 按钮关闭 |
| `src/ui/dialogue_tree.gd` | 器灵对谈（选项 + 展签卡） | 播放 `Lore.stages()`；结束时回调推进 `Game.lore_stage`；史实卡与台词视觉分离 |
| `src/ui/relic_closeup.gd` | 互动特写层（2.5D） | 检测 `relic_<id>_closeup.png`；黑场淡入 + 暖光 + 呼吸推近；E 拾取 / Esc 离开；打开 ⇔ 暂停 |
| `src/ui/inspect_page.gd` | 端详页（手机档案页内） | 特写 + 热点标记（发现状态存 `Game.lore_found`）+ 展签卡列表（按进度解锁，点击交给 main 用 DialogueTree 展示） |
| `src/autoload/game_state.gd` | 全部可持久化状态与规则 | 内容表 `CATALOG/SHAPES/UPGRADES/BAG_SIZES` 目前在这里（技术债，见 §8）；**关卡注册表 `LEVELS`**（id/名称/地图/目标/报酬）+ `set_level()` + `mission_target_id`；**`ARCHIVE` 文物档案字段**（与 SOURCES.md 对齐；游戏内显示 `source_label`，不显示文档路径） |
| `src/autoload/audio.gd` | 音效播放 | `SFX` 键→路径；播放器池轮转；退出前 `shutdown()` |
| `src/levels/*.json` | 关卡数据（**生成物**） | `museum_map.json`（城西博物馆）/ `british_museum.json`（大英博物馆·中国馆）；由 `tools/gen_museum_map.py` 生成；verify 校验同步 |
| `tests/*` | 测试与截图 | 见 §7 |
| `tools/*.py` | 资源生成脚本 | 生成物只能由它们更新；含 3D→2D 管线（`gen_relic_sprite.py`） |
| `tools/gen_bm_art.py` | 大英博物馆资产包生成器 | 生成 `assets/sprites/bm/`（六展厅瓦片/道具/UI/双羊尊 32×32/玻璃展柜）与 `assets/sprites/bm/decor/`（13 类纯视觉装饰）；改样式改脚本后重跑 |
| `tools/blender/*.py` | Blender 建模与渲染脚本 | headless 可重跑（`~/bin/blender`）；产出 `assets/models/*`（`.gdignore`，运行时不加载）与转台渲染图 |
| `tools/verify.sh` | 一键验证 | 收尾必跑 |
| `tools/blender/build_ram_zun.py` | 双羊尊 3D 模型生成脚本（程序化建模） | 生成物在 `assets/models/`（带 `.gdignore`，不参与 Godot 导入） |
| `tools/check_level.py` / `check_docs.py` | 生成物同步/文档自检 | 由 verify 调用 |

## 3. 关键数据

### 3.1 全局状态（`Game`）

- 运行局内：`bag_items: Array[{id,x,y,rot}]`、`mission_complete`
- 长期成长：`money`、`backpack_level`、`has_sneakers`、`smoke_count`、`loot_stash`（据点仓库：待售战利品 id 列表）
- 信号：`backpack_changed` / `money_changed` / `items_changed`（UI 只监听，不轮询）
- Σ 存档：`user://save.json`（测试隔离到 `/tmp`）

```json
{ "money": 0, "backpack_level": 0, "has_sneakers": false,
  "smoke_count": 0, "bag_items": [{"id": "mask", "x": 0, "y": 0, "rot": 0}] }
```

- **`mission_complete` 规则**：永远由背包内容实时推导（`_recompute_mission()`），目标丢出→false→出口重新上锁；放回→true。不要新增"曾经拿到过"的状态位。

### 3.2 背包几何

- `SHAPES`：形制 = 格子偏移数组（如面具 2 格横排、玉璧 1×3），运行时旋转 90° 连续步进。
- 合法性：`bag_can_place(id, rot, x, y)`；自动摆放：`bag_auto_fit(id)`（先 0° 后 90°）。
- `BAG_SIZES`：等级 0..5 的格子数（2×2 → 5×4）。
- 相关测试：`tests/test_logic.gd::_test_bag_geometry`。

### 3.3 关卡数据（`src/levels/*.json`，生成物）

多关卡：`museum_map.json`（城西博物馆）与 `british_museum.json`（大英博物馆·中国馆），由 `tools/gen_museum_map.py` 的 `LEVELS` 配置生成；关卡注册表在 `Game.LEVELS`（id → 名称/地图/目标文物/报酬）。

```json
{ "tile_size": 16,
  "rooms":   [[x,y,w,h], ...],   // 房间矩形（格坐标），供相机/小地图/感知分流
  "floors":  [[x,y,w,h], ...],   // 地板矩形（含走廊），仅绘制用
  "tiles":   ["...", ...],       // 每行一个字符串，字符=瓦片
  "patrols": {"1": [[x,y], ...]} // 警察出生点字符 → 巡逻路径（格坐标）
}
```

瓦片图例（改地图看这里；`.~TapXP123456789` 为可行走）：

| 字符 | 含义 | 字符 | 含义 |
| --- | --- | --- | --- |
| `.` | 地板 | `#` | 墙（实心） |
| `~` | 地毯 | `W` `L` | 挂画/壁灯墙（实心） |
| `o` | 柱子（实心） | `d` | 展柜（实心） |
| `r` | 围栏绳（实心） | `s` `v` | 雕像/盆栽（实心） |
| `p` | 展台（实心） | `T` | 任务目标（生成在展台上） |
| `a` | 额外战利品（按 `ARTIFACT_POOL` 轮转） | `P` | 玩家出生点 |
| `X` | 出口 | `1-9` | 警察出生点（键=巡逻路线 ID） |

### 3.4 房间 / 相机 / 小地图

- `museum.rooms` 是房间矩形的权威数据；`room_index_at(pos)` 全局使用。
- 单屏一房间（20×12，相机 zoom 2×）：跨进新房间时相机 `limit_*` 重设（`_apply_camera_limits`），玩家永远只见一屏。
- 夜间氛围（纯表现，不影响判定）：全局 `CanvasModulate` 夜色 + 展品/壁灯暖色 `PointLight2D` + 警察手电筒光锥（`Flashlight`，随朝向旋转、致盲时熄灭）+ 玩家微光；文物光晕挂在文物节点上，被拿走即熄灭。
- 感知分流：噪音（`made_noise`）与幽灵哀嚎只惊动**同房间**且距离内的警察。
- 小地图：从房间坐标去重出列/行自动排布，记录 `visited_rooms`、`target_room`、`exit_room`。
- 尺寸约定：瓦片/灯光 16×16 起；角色 16×24（帧表 2 列 × 3 行）；文物图标 16×16（背包格 24px 内绘制）；**任务目标可用 3D 渲染的转台条** `relic_<id>_strip.png`（12 帧 × 24×28，常量在 `Artifact`）。改尺寸要同时改绘制与生成脚本。

## 4. 关键数据流

- **拾取**：`Player` 按 E → `Artifact.try_pickup()` → `Game.try_pickup()`（自动找位）→ 成功 `picked` / 失败 `pickup_blocked` → `museum` 用 `toast` 反馈；`Game` 发 `backpack_changed` → HUD 刷新。
- **任务目标**：拾取 → `mission_complete=true` 且触发幽灵事件；丢到场景 → 实时重算为 false → 出口拒绝开启（`_on_exit_body_entered` 检查 `Game.mission_complete`）。
- **互动特写**：`Player.inspect_requested` → `Museum.closeup_requested` → `Main.open_relic_closeup()`（暂停）→ 拾取时 `Museum.pickup_artifact()`。
- **战利品**：撤离结算 → 目标上交并发放组织报酬；其余文物进入 `Game.loot_stash`（不自动出售）→ 据点「销赃」页逐件/全部卖出（`sell_stash_item` / `sell_all_stash`）。
- **警察感知**：听到噪音 → `INVESTIGATE`（走去看）→ 视野锥内持续 0.35s（无墙遮挡）→ `CHASE` → 接触 <11px 逮捕；`blind()` 清空状态回巡逻；警戒等级 0/1/2 逐级上报 → HUD。
- **幽灵事件**：拾取目标后延迟 `ghost_delay` 生成 `Ghost`；幽灵周期 `wailed(pos)` → 同房间 96px 内警察 `investigate(pos)`；幽灵超时渐隐自毁。
- **音频**：`Audio.play(name, dB, pitch)` 轮转 10 个播放器，避免互相切断；测试与退出前 `shutdown()`。

## 5. 不变量（改代码前必读）

1. 世界节点不进 CanvasLayer（否则相机静默失效——v0.6.0 修过，别再犯）。
2. `mission_complete` 实时推导，不存历史标记。
3. 生成物只能由 `tools/*.py` 重新生成；不手改 `assets/**` 与 `museum_map.json`。
4. 感知几何保持纯函数（如 `Police.in_cone` 静态方法），保证可单测。
5. 跨房间感知必须按 `room_index_at` 分流（噪音/哀嚎）。
6. 测试存档隔离 `/tmp`；冒烟测试退出前 `Audio.shutdown()`。
7. 存档只增字段且带默认值；UI 文案中文；640×360 布局假设。
8. 背包放置判定单点实现（`Game.bag_can_place`）——UI 不得复制一套碰撞逻辑。
9. **UI 覆盖层契约**（由 `tests/test_input_flow.tscn` 守卫）：有覆盖层打开 ⇔ `get_tree().paused`；B/P/ESC 关闭且**逐层返回**（卡片叠层先收卡片、再关手机）；覆盖层根节点必须 `process_mode=3`（ALWAYS，暂停中才能响应按键）；关闭后的短冷却（0.2s）防止同一按键"刚关又开"。新增/修改覆盖层必须在输入流自检补用例——**只调 `open()/close()` 的测试测不到按键路由 bug**。互动特写层（`RelicCloseup`）同属覆盖层：E 拾取 / Esc 离开。

## 6. 改造配方（Recipes）

### 6.1 加一件文物（当前做法，数据表还在代码里）

1. `src/autoload/game_state.gd` → `CATALOG` 加条目（`name` / `value` / `story` / `is_target`）。
2. 同文件 `SHAPES` 加形制：格子数 1–6、归一化到 (0,0)、4 连通。
3. `tools/gen_placeholder_sprites.py` 的 `ART` 字典加 id 条目（配色 + 16×16 像素图）→ `python3 tools/gen_placeholder_sprites.py` → 生成 `assets/sprites/artifact_<id>.png`。
4. 若要进关卡战利品池：`src/world/museum.gd` 的 `ARTIFACT_POOL` 加 id（不能包含任务目标）。
5. `tools/verify.sh`——`test_content.gd` 会校验以上全部链条。

### 6.2 改地图 / 房间

1. 改 `tools/gen_museum_map.py`：`CONTENT`（房间内容）与 `ROOM_COUNT` 等常量。
2. `python3 tools/gen_museum_map.py` 重新生成 JSON（生成器自带连通性/巡逻合法性校验）。
3. 更新测试中的期望：`tests/test_logic.gd::_test_map` 与 `tests/smoke_test.gd`（房间数、尺寸、目标/出口房间号、警察数）。
4. `tools/verify.sh`。

> 房间数/尺寸/位置是测试断言的一部分：地图改动天然是一次"跨文件"改动，照上表逐处更新。

### 6.3 加音效

`tools/gen_sfx.py` 的 `SOUNDS` 加生成函数 → 运行 → `src/autoload/audio.gd` 的 `SFX` 表登记（键 → 路径）→ verify（会反向检查 assets/sfx 里没有未登记的孤儿 wav）。

### 6.4 加/改 UI 界面

- 界面 = `CanvasLayer` + 独立 `.tscn`；打开/关闭与 `get_tree().paused` 的联动统一由 `main.gd` 控制（参考背包装备：`open_backpack()` / `_on_backpack_closed()`）。
- 只读 `Game` 数据 + 监听信号；需要改状态时调用 `Game` 的方法（保持规则单点）。

### 6.5 加存档字段

1. `save_game()` / `load_game()` 同步加键，读取用默认值（旧档必须能加载）。
2. 需要迁移/破坏性变更：写迁移函数 + 记入 `docs/DECISIONS.md`，并在 CHANGELOG「修改」中说明。

### 6.6 加新关卡（v0.9.0 起已支持）

多关卡已落地（D-012）：`Game.LEVELS` 注册表 + `museum.level_id` 按关卡解析。加一关的步骤：

1. `tools/gen_museum_map.py`：`LEVELS` 加配置（名称/内容字典/输出文件名）并生成 JSON；生成器自带连通性/巡逻校验。
2. `src/autoload/game_state.gd`：`LEVELS` 加条目（名称/地图/目标文物/报酬），目标文物在 `CATALOG` 标 `is_target` 且形制在 `SHAPES`。
3. `src/main.gd`：`BRIEFINGS` 加简报（可选）；`src/ui/hub.tscn` + `hub.gd` 加选关按钮。
4. 目标为**真实文物**时：先在 `docs/SOURCES.md` 登记（含来源与史实/演绎分界）。
5. 测试：`test_logic._test_map` 的地图断言、`test_content` 会自动覆盖新关卡字段；`tools/verify.sh`。

> 不要复制粘贴第二份 `museum.gd`；关卡差异都应数据化（地图 JSON + 注册表 + 简报）。

### 6.7 3D 素材 → 游戏精灵（v0.10.0 起的管线）

已有 3D 模型（`assets/models/*.blend`，程序化生成）时，用离线渲染把它变成 2D 贴图：

1. 写/改渲染脚本（参考 `tools/blender/render_relic_turntable.py`）：打开 blend、透明背景、固定机位、绕 Z 逐帧渲染到 `/tmp/opencode/<name>/`。
   ```bash
   blender --background --factory-startup --python tools/blender/render_relic_turntable.py
   ```
2. 改 `tools/gen_relic_sprite.py` 的输入目录/帧数/尺寸常量并运行，产出 `assets/sprites/relic_<id>_strip.png` 与 `artifact_<id>.png`。
3. 游戏侧无需改代码：`artifact.gd` 检测到 `relic_<id>_strip.png` 即启用转台动画；尺寸常量（`Artifact.RELIC_*`）必须与生成脚本一致（`test_content` 校验）。
4. `tools/verify.sh`（含资源导入步骤）。

> 原则：3D 只在**构建期**使用，运行时是纯 2D（`.gdignore` 隔离 `assets/models/`，见 D-013）。

### 6.7 3D 资产（Blender，与 2D 游戏并行）

- 源脚本：`tools/blender/build_ram_zun.py`（程序化建模，headless 运行，Cycles CPU）。
- 生成物：`assets/models/ram_zun.blend` + `ram_zun.glb`（+ `ram_zun_preview.png`）；目录带 `.gdignore`，Godot 不导入。
- 重新生成：`FINAL=1 blender --background --factory-startup --python tools/blender/build_ram_zun.py`。
- 依赖：本机 Blender 5.x（`~/bin/blender`）；改动形体后按「生成物禁止手改」原则重跑脚本并提交新生成物。
- 边界：3D 资产不参与游戏运行与测试；若要接入引擎（如 3D 档案视图），先在 ROADMAP 建任务并确认技术方案。

## 7. 测试与工具分工

> 所有 godot 步骤都经过 `tools/verify.sh` 的**引擎报错门禁**：输出里出现 `ERROR/WARNING/泄漏/非法访问` 即失败（允许清单须注明理由）。因此"测试通过但日志有异常"不再被忽略。

| 工具 | 位置 | 什么时候加用例 |
| --- | --- | --- |
| 纯逻辑单测 | `tests/test_logic.gd` | 背包/商店/存档/几何/地图结构等无场景逻辑 |
| 内容一致性 | `tests/test_content.gd` | 新增文物/商店项/音效/关卡数据字段时自动覆盖，必要时扩展 |
| 编译检查 | `tests/test_scripts.tscn` | 自动扫描 `src/`、`tests/` 全部 .gd |
| 冒烟测试 | `tests/smoke_test.gd` | 场景行为：拾取/被捕/撤离/警报/幽灵/相机/背包界面 |
| 输入流自检 | `tests/test_input_flow.tscn` | **UI/输入改动必加**：真实按键/鼠标事件驱动，覆盖层开关、互斥、逐层返回、暂停契约 |
| 存档兼容 | `tests/test_save_compat.gd` | 新增存档字段/改加载逻辑时补老档与脏档用例 |
| 场景实例化 | `tests/test_scenes.tscn` | 自动覆盖 `src/` 全部场景（新增场景无需改） |
| 随机操作 | `tests/test_monkey.tscn` | 新增"任何时刻成立"的规则时加不变量；`MONKEY_STEPS` / `MONKEY_SEED` 可加深 |
| 视觉回归 | `tests/visual_baseline/` + `tools/check_visual.py` | 画面改动后 `verify.sh --visual`；预期改动 `--update` 基线 |
| 手动 QA | `docs/MANUAL_QA.md` | 每版收尾人工过一遍（观感/手感/音频/历史表述） |
| 截图 | `tests/screenshot.tscn` | 画面改动后人工核验（输出 `/tmp/shot_*.png`） |
| 一键验证 | `tools/verify.sh` | 收尾必跑；`--fast` 跳过冒烟+monkey；`--visual` 加视觉回归 |
| 地图自检 | `tools/check_level.py` | 校验 `museum_map.json` 与生成器同步 + 生成器语法 |
| 文档自检 | `tools/check_docs.py` | 站内链接可达性 + CHANGELOG 格式 |

## 8. 已知技术债（对应 ROADMAP 任务）

- **内容表在代码里**：`CATALOG` / `SHAPES` / `UPGRADES` 是 `game_state.gd` 的 const。计划迁到 `src/data/*.json` + 加载器 + schema 校验（迁移前注意并行窗口冲突）。
- **单关卡硬编码**：`main.gd` / `museum.gd` 写死了"城西博物馆"。多关卡需要元数据与选关流程。
- **占位美术**：全部由脚本生成，正式素材替换时保持同文件尺寸约定或同步改绘制代码。
- **文档漂移风险**：代码可能领先文档；以测试与代码为准，`verify.sh` 与 ROADMAP 用于对齐。
- 孤儿文件 `src/ui/main_menu.gd.uid`（脚本已删）：待确认后清理（ROADMAP 已知问题）。
