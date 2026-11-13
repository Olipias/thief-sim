# A-00 交付：主角 32×40 / 警察 24×32 + 安全屋 + 电话 UI

> 2026-11-13 · art（agent-mail：OrangeThrush）· UI 收口修改 `src/ui/hub.*`、`mission_phone.*`、`relic_view.gd`；主角 32×40 接入 `player.tscn`；未改 `tests/`、角色/故事逻辑
> 依据：用户 #thief id 53 / id 67；plan 的 A-00 范围（`docs/STORY_PLAN.md` §3D）。
> 概念图见 `a00_src/`；生成脚本 `tools/gen_a00_art.py` + `tools/a00_characters.py`。
>
> **Rev.3（2026-11-13）**：主角按用户指定 `a00_src/thief_turnaround_a.png`（礼帽 + 棕褐风衣 + 斜挎包）重做；游戏内用 **32×40 / 128×120 sheet**，角色高约 39px，与 24×32 守卫同屏不突兀。48px 填满 canvas 的版本已废弃（太大且像制服）；1280×720 AI turnaround 保留为高分辨率设计参考。警察仍为 24×32。

## 0. 一句话

主角按 `thief_turnaround_a` 设计重做为 **32×40 游戏 sprite**（39px 高），警察保持 **24×32**，均为 **3 向 × 4 帧**；给据点一张可直接铺的 **安全屋背景** 与一套 **博物馆标签化 UI**；给任务终端一套 **黄铜手机边框 + 纸卡/朱印** 的皮肤。全部为纯像素/程序化资产，AI 概念只作方向参考。

---

## 1. 交付物

| 文件 | 尺寸 | 用途 | 接入方 |
| --- | --- | --- | --- |
| `assets/sprites/chars/player_sheet_v2.png` | **128×120** | **主角 32×40 × 12 帧（Rev.3）** | `player.tscn/gd` |
| `assets/sprites/chars/thief32_front.png` / `_side.png` / `_back.png` | 32×40 | 主角三视图单帧 | 评审/参考 |
| `assets/sprites/chars/thief32_turnaround.png` | 96×40 | 正 / 侧 / 背三视图 | 评审 |
| `assets/sprites/chars/police_sheet_v2.png` | 96×96 | 警察 24×32 × 12 帧 | `police.tscn/gd` |
| `docs/art_direction/a00_src/police_v2_preview.png` | 576×576 | 6× 预览（不进游戏） | 评审 |
| `assets/art/safehouse_bg.png` | 1280×720 | 据点背景（640×360 逻辑 ×2） | `hub.tscn` |
| `assets/art/phone_frame_9p.png` | 96×96 | 电话 9-patch 边框（margin 12） | `mission_phone.tscn` |
| `docs/art_direction/A00_characters_board.png` | 1280×720 | 旧 24×32 角色规格板（历史） | 评审 |
| `docs/art_direction/A00_thief32_turnaround.png` | 960×400 | 主角 32×40 三视图 10× 预览 | 评审/验收 |
| `docs/art_direction/A00_thief32_sheet.png` | 1024×960 | 主角 128×120 sheet 8× 预览 | 评审/验收 |
| `docs/art_direction/A00_thief32_ingame.png` | 1280×720 | 新主角实机尺度（与 24×32 守卫同屏） | 评审/验收 |
| `docs/art_direction/A00_safehouse_ui.png` | 1280×720 | 据点 UI 目标稿 | 评审/接入 |
| `docs/art_direction/A00_phone_ui.png` | 1280×720 | 电话 UI 目标稿 | 评审/接入 |
| `docs/art_direction/A00_concept_board.png` | 1280×720 | SiliconFlow 概念总览 | 评审 |
| `docs/art_direction/A00_ingame_scale.png` | 1280×720 | 现有 16×24 vs A-00 24×32 的游戏尺度对比 | 评审/验收 |
| `docs/art_direction/a00_src/*.png` | — | AI 概念原图（不导入 Godot） | 参考 |

> `docs/art_direction/` 有 `.gdignore`，概念图不会被 Godot 导入。

---

## 2. 角色 sprite（主角 32×40；警察 24×32）

### 2.1 规格

- 主角：单帧 **32×40**；sheet **128×120**：**4 列 × 3 行**；角色高约 39px。
- 警察：仍为 24×32 / 96×96，待后续同风格重制。
- 行：`0 = 下`、`1 = 上`、`2 = 侧`（侧向默认朝右，向左用 `flip_h`）。
- 列：`0 = 待机 A`、`1 = 待机 B`、`2 = 行走 A`、`3 = 行走 B`。
- 主角锚点：`Sprite2D.position.y = -13`（40px 帧高，脚底在原点）；警察仍为 `-10`。
- 碰撞：不改（当前 `8×8`）；只换视觉，不改手感、视锥、交互距离。
- `hframes = 4`、`vframes = 3`。

### 2.2 设计

- 主角（Rev.3）：`thief_turnaround_a` 同款礼帽 + 棕褐长风衣 + 斜挎皮包 + 白手套 + 棕靴；无兜帽/围巾/发光眼；不再用 48px 填满画面。
- 警察：深藏青制服、帽徽、胸牌、对讲机、腰带、手电筒、胡子；暖光在右，冷光在左。
- 调色板见 `A00_characters_board.png` 底部；每个角色 8 色主色 + 轮廓/高光。
- 待机 A/B 为同一站姿（呼吸暂以 1 帧占位）；行走 A/B 为脚部 1px 交替。后续可补 4 帧步态。

### 2.3 接入（@code）

**`src/actors/player.tscn`**

```ini
[ext_resource type="Texture2D" path="res://assets/sprites/chars/player_sheet_v2.png" id="2_sheet"]
...
[node name="Sprite" type="Sprite2D" parent="."]
position = Vector2(0, -13)
texture = ExtResource("2_sheet")
hframes = 4
vframes = 3
```

**`src/actors/player.gd`**（`_update_visual`）

```gdscript
func _update_visual(dir: Vector2, delta: float) -> void:
    if dir == Vector2.ZERO:
        _walk_time = 0.0
        sprite.frame = facing_row * 4          # 待机 A
        return
    if absf(dir.x) > absf(dir.y):
        facing_row = 2
        sprite.flip_h = dir.x < 0.0
    else:
        facing_row = 1 if dir.y < 0.0 else 0
    _walk_time += delta * (11.0 if _sprinting else 8.0)
    sprite.frame = facing_row * 4 + 2 + (int(_walk_time) % 2)   # 行走 A/B
```

**`src/actors/police.tscn`**：同 player，替换贴图、`position.y = -10`、`hframes=4`、`vframes=3`。

**`src/actors/police.gd`**（`_update_visual`）

```gdscript
func _update_visual(delta: float) -> void:
    var moving := velocity != Vector2.ZERO
    if moving:
        _walk_time += delta * 8.0
    var col := 0
    if moving:
        col = 2 + int(_walk_time) % 2          # 行走 A/B
    if absf(_facing.x) > absf(_facing.y):
        sprite.flip_h = _facing.x < 0.0
        sprite.frame = 8 + col                 # 侧行基址 = 2*4
    else:
        var row := 1 if _facing.y < 0.0 else 0
        sprite.frame = row * 4 + col
```

**注意**：
- 如果脚底看起来悬空/入地，只调 `Sprite2D.position.y`（±1），不要动碰撞体。
- 旧贴图 `player_sheet.png` / `police_sheet.png` 保留不动，方便回滚。
- 不要在 `_update_visual` 里每帧重设 `texture`/`hframes`。

### 2.4 验收

- [ ] 1× 截图能区分玩家/警察；侧面能看出朝向。
- [ ] 行走 4 帧（待机 2 + 行走 2）不抖动；脚底不悬空。
- [ ] 碰撞 8×8、视锥、交互距离未变。
- [ ] 手机/背包截图中的角色不被裁切。

---

## 3. 安全屋（据点）

### 3.1 设计

- 背景：`assets/art/safehouse_bg.png`——旧洗衣店后屋/仓库：吊灯、软木板（博物馆平面图 + 红线 + 照片）、工作台、瓷器货架、CRT、电话、雨窗、木箱。
- UI 目标稿：`A00_safehouse_ui.png`。
- 布局（640×360 逻辑）：
  - 顶部 0–34：标题「神偷组织 · 据点」+ 金币。
  - 34–64：任务 / 商店 / 销赃 / 返回标题。
  - 74–140、148–214：两张任务卡（与现有 `LevelsBox` 位置一致）。
  - 322–360：底部提示。
  - 右下：手机图标（可选 Phase 2）。
- 卡片：深青黑 92% + 1px 黄铜边；左侧 3px 朱红书脊；目标文物放在米色小卡上；右侧金色「开始行动」。
- 色板：
  - 面板 `#0C1418` / 92%
  - 边框 `#604A28`
  - 金 `#D8A84E`，亮金 `#F4D48A`
  - 米纸 `#E9DFC7`
  - 朱红 `#A63126`
  - 正文 `#CEC8B8`，次要 `#9AA096`

### 3.2 接入（@code）

**Phase 1（低风险，先做）**：在 `src/ui/hub.tscn` 的 `Background` 之后加一层背景，`mouse_filter = 2`：

```ini
[ext_resource type="Texture2D" path="res://assets/art/safehouse_bg.png" id="2_bg"]

[node name="SafehouseBg" type="TextureRect" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
texture = ExtResource("2_bg")
expand_mode = 1
stretch_mode = 6
mouse_filter = 2
```

**Phase 2（样式）**：
- `hub.gd` 动态创建的 `PanelContainer` 加 `StyleBoxFlat`：`bg_color = Color("#0C1418", 0.92)`、`border_width_* = 1`、`border_color = Color("#604A28")`、`corner_radius_* = 2`。
- 动态 `Button`（开始行动）：`bg_color = Color("#D8A84E")`、`font_color = Color("#1A120C")`、`border_color = Color("#785828")`。
- `TabLevels/TabShop/TabSell`：激活金底深字，未激活深底金字；`QuitButton` 深底。
- 标题可换 Noto Serif（与标题页一致）；不换也不影响可读性。
- 商店/销赃页沿用同一套面板/按钮样式；不改 `hub.gd` 的经济逻辑。

**不要**：把背景图放到 `CanvasLayer` 下（相机/输入坑见 `docs/DECISIONS.md` D-003）；背景节点必须 `mouse_filter=2`。

### 3.3 验收

- [ ] 背景铺满 640×360，不变形、不裁切关键物（软木板/工作台）。
- [ ] 点卡片/按钮不被背景拦截。
- [ ] 文字在背景上可读；卡片不透明度足够。
- [ ] 商店/销赃页视觉一致，无布局溢出。

---

## 4. 电话 UI（任务终端）

### 4.1 设计

- 目标稿：`A00_phone_ui.png`（640×360 ×2）。
- 机身：80–560 × 10–350；屏幕 92–548 × 36–324；黄铜外框 + 黑玻璃 + 顶部听筒/摄像头 + 侧键。
- 版面：
  - 状态栏：神偷组织 / 时间 / 信号 / 电池。
  - 标题「任务终端」+ 朱印「密档」+ 任务/档案 tabs。
  - 左：米色文物卡（文物图 + 名称 + 馆藏级别）。
  - 右：目标名、地点、委托人/报酬、3 行故事。
  - 下：米色档案卡（年代/现藏/流转/备注）。
  - 底部：3 条行动注意 + `P / ESC 关闭`。
- 字体：标题 14–18px（Noto Serif/Fusion Pixel）；正文 10px；档案/注释 9px；页脚 9px。
- 色板：屏幕 `#081214`，黄铜 `#8C6A36`，金 `#D8A84E`，米纸 `#E9DFC7`，朱红 `#A63126`，正文 `#CEC8B8`。
- **不要**直接使用 AI 电话概念图（有伪文字/伪纹样）；只用它的材质语言。

### 4.2 接入（@code）

**Phase 1（低风险）**：把 `mission_phone.tscn` 的 `Panel` 皮肤从 `StyleBoxFlat_phone` 换成 9-patch：

```ini
[ext_resource type="Texture2D" path="res://assets/art/phone_frame_9p.png" id="4_frame"]

[sub_resource type="StyleBoxTexture" id="StyleBoxTexture_phone"]
texture = ExtResource("4_frame")
texture_margin_left = 12.0
texture_margin_top = 12.0
texture_margin_right = 12.0
texture_margin_bottom = 12.0
content_margin_left = 18.0
content_margin_top = 16.0
content_margin_right = 18.0
content_margin_bottom = 16.0
```

把 `Root/Panel` 的 `theme_override_styles/panel` 指向 `StyleBoxTexture_phone`；保留现有 `MarginContainer/VBox` 内容与逻辑。9-patch 中心是深青黑 + 扫描线；内容会叠在上面。

**Phase 2（可选，更像手机）**：
- 加一个全屏 `TextureRect` 的完整手机机身（透明屏幕区），把 `Panel` 固定为屏幕大小并居中；需要改 `Panel` 的 anchors/custom_minimum_size，属于布局改动，建议单独提交。
- 任务/档案 tabs 改成金底/深底；档案卡用米纸 `StyleBoxFlat`（现有 `StyleBoxFlat_paper` 已接近）。
- **不改** `mission_phone.gd` 的开关逻辑；P/B/ESC 关闭仍由现有输入流测试覆盖。

### 4.3 验收

- [ ] `P` / `B` / `ESC` 仍能关闭电话；不出现同帧重开。
- [ ] 9-patch 拉伸后边框不糊、角花不变形。
- [ ] 640×360 下档案卡/注意项不溢出；正文可读。
- [ ] 任务页/档案页切换正常；背包文物点击端详正常。

---

## 5. SiliconFlow 记录

- 模型：`Kwai-Kolors/Kolors`（FLUX.1-schnell 在本账号返回 `403 Model disabled`）。
- 概念图与 seed：
  - 玩家：`a00_player_concept.png`，seed 24011，1024²。
  - 警察：`a00_police_concept_v2.png`，seed 24031，1024²（第一版半身像未采用）。
  - 安全屋：`a00_safehouse_concept.png`，seed 24022，1280×720。
  - 电话材质：`a00_phone_ui_concept.png`，seed 24032，1280×720。
  - sprite sheet 探索：`a00_player_sheet_concept.png`，seed 24041（只作设计参考，不是 12 帧网格）。
- 完整 prompt/negative 见 `a00_src/prompts.md`。
- 角色最终帧由 `tools/a00_characters.py` 手工绘制；AI 概念只提供“暗脸金眼、围巾、斜挎包、破边衣摆”等语言。AI 无法稳定产出 3×4 对齐帧，直接切片会破坏一致性。
- 安全屋背景由概念图 **640×360 降采样 + 40 色量化 + 渐变暗角** 得到，再由 `tools/gen_a00_art.py` 输出 1280×720；伪文字在 640 下是纹理，不应被读成真实馆藏文字。
- 电话概念只取材质语言，最终 UI 由程序化绘制，避免伪文字。

---

## 6. 交接

### @code（A-01）

1. 先接 **角色**：`player.tscn`、`police.tscn`、两处 `_update_visual`；跑 `tools/verify.sh --fast`。
2. 再接 **安全屋背景**（Phase 1）+ 电话 9-patch（Phase 1）；不改经济/开关逻辑。
3. 最后做 **样式**（Phase 2）：卡片/按钮/tabs；如果时间不够，Phase 1 已能明显提升。
4. 不要动 `assets/sprites/player_sheet.png` / `police_sheet.png` 旧图；保留回滚。
5. 截图前确认相机/UI 缩放；更新视觉基线前先人眼确认。

### @test（A-02）

1. 资源存在/尺寸：主角 sheet 必须 128×120（32×40），`position.y=-13`；警察 96×96（24×32），`position.y=-10`；两者 `hframes=4`、`vframes=3`。
2. 角色：四向移动 + 行走动画；侧向 `flip_h`；碰撞 8×8 不变。
3. 据点：背景不拦截点击；卡片/商店/销赃/返回标题可点。
4. 电话：P/B/ESC 关闭；任务/档案切换；9-patch 不变形。
5. `tools/verify.sh` 全量 + `--visual`；基线经人眼确认后更新。

### 边界

- art 未改 `src/`、`tests/`；以上代码片段是交接建议，由 code 实施。
- 真实文物/史实口径仍以 `docs/SOURCES.md` 为准；本批不新增史实内容。

---

## 7. 验收清单

- [ ] 两张 96×96 sheet 已导入，无缺失引用。
- [ ] 主角 32×40、警察 24×32；3 向 × 4 帧；待机/行走映射正确；主角脚底不悬空。
- [ ] 锚点 -10，碰撞 8×8 未变。
- [ ] 安全屋背景 1280×720 全屏铺满，`mouse_filter=2`。
- [ ] 卡片/按钮/标签样式与目标稿一致（或至少 Phase 1 背景接入）。
- [ ] 电话 9-patch 边框不变形；P/B/ESC 关闭。
- [ ] 640×360 下文本不溢出；截图基线人眼确认。
- [ ] `tools/verify.sh` 全量 + `--visual` 通过。
