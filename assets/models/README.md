# 3D 资产：双羊尊（ram_zun）

为游戏任务目标「商代双羊尊」（真实文物，见 `docs/SOURCES.md` S-001）制作的 3D 模型。
用途：**离线渲染进游戏**（转台动画与图标，见 `tools/blender/render_relic_turntable.py`
与 `tools/gen_relic_sprite.py`）、展示、以及后续「文物档案 3D 化」等方向的素材储备。
**游戏运行时不加载本目录**（`.gdignore` 隔离，决策见 `docs/DECISIONS.md` D-013）。

## 文件

| 文件 | 说明 |
| --- | --- |
| `e6b392eeb4fe60c7dd831782abaec83f.glb` | **双羊尊扫描件**（50 万面、4K PBR 贴图；项目作者提供）。渲染默认使用它；**本地资产，`.gitignore` 不入库** |
| `ram_zun.blend` | 程序化模型的 Blender 源文件（含影棚灯光/相机），扫描件缺失时的回退 |
| `ram_zun.glb` | 程序化模型的 glTF 导出（仅器身；Y-up；含顶点色铜绿） |
| `ram_zun_preview.png` | 程序化模型的 3/4 视角预览图 |

> 扫描件的来源与许可证待作者补充。由于文件不入库，仓库只包含离线渲染产物（`assets/sprites/relic_ram_zun_*` 等）；
> 拿到仓库但没有扫描件时，`tools/blender/render_relic_turntable.py` 会自动退回程序化模型。

## 渲染（转台 / 图标 / 2.5D 特写）

```bash
# 默认：扫描件 → /tmp/opencode/relic_turntable（f00..f11 + hero + closeup）
blender --background --factory-startup --python tools/blender/render_relic_turntable.py
# 回退：程序化模型
MODEL=procedural blender --background --factory-startup --python tools/blender/render_relic_turntable.py
# 渲染结果 → 游戏精灵
python3 tools/gen_relic_sprite.py
```

渲染脚本会把扫描件等比缩放到与程序化模型相同的尺寸（高 0.443 m、底部 Z=0），复用同一影棚；
小尺寸精灵在 `gen_relic_sprite.py` 里做青铜绿的色调分级，特写层保留扫描件的原始质感。

## 生成方式（程序化建模，勿手改生成物）

模型由脚本程序化生成，与项目「生成物禁止手改」约定一致：

```bash
# 需要 Blender 5.x（本机 ~/bin/blender）。rerun 会覆盖本目录产物：
FINAL=1 blender --background --factory-startup --python tools/blender/build_ram_zun.py
# 只渲染预览到 /tmp/opencode：
RENDER=1 OUTDIR=/tmp/opencode blender --background --factory-startup --python tools/blender/build_ram_zun.py
```

改形体的入口都在 `tools/blender/build_ram_zun.py`：`BODY_TABLE`（器身截面）、
`NECK_OUTER/NECK_INNER`（口沿剖面）、`HEAD_SECTIONS/JAW_SECTIONS`（羊首）、
羊角参数在 `build_head()` 内（螺旋半径/圈数/截面/棱纹）。

## 规格

- 尺寸：0.412 × 0.221 × 0.444 m（宽 × 深 × 高，含羊首）；对齐馆藏数据（高 45.1 cm、宽 41.0 cm）。
- 网格：约 1.2 万面；`Smooth by Angle`（38°）硬边。
- 材质：`Bronze Patina`（顶点色铜绿斑驳，随 glTF COLOR_0 导出）、`Bronze Worn`（羊角/乳钉）、`Bronze Recess`（口沿内腔与口腔）。
- 风格化说明：雷纹/饕餮细密纹饰未逐条建模，以形体、扉棱、饰板与乳钉概括；
  这是**演绎性再现**，不构成考古复原。

## 为什么有 `.gdignore`

Godot 会尝试导入 `assets/**` 下可识别的资源；本目录存放的是 2D 游戏暂不使用的
`.blend/.glb`（且 `.blend` 导入依赖编辑器中的 Blender 路径配置）。`.gdignore`
让 Godot 跳过本目录，避免污染导入管线。将来若要在引擎内使用（如 3D 档案视图），
删除本 `.gdignore` 或把所需文件复制到不自忽略的目录即可。
