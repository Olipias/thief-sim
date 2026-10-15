# 3D 资产：双羊尊（ram_zun）

为游戏任务目标「商代双羊尊」（真实文物，见 `docs/SOURCES.md` S-001）制作的 3D 模型。
用途：渲染出图、展示、以及后续「文物档案 3D 化」等方向的素材储备。
**当前游戏（2D 像素）运行时不加载本目录。**

## 文件

| 文件 | 说明 |
| --- | --- |
| `ram_zun.blend` | Blender 源文件（含影棚灯光/相机，可直接出图） |
| `ram_zun.glb` | glTF 二进制导出（仅器身选中导出；Y-up；含顶点色铜绿） |
| `ram_zun_preview.png` | 3/4 视角预览图 |

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
