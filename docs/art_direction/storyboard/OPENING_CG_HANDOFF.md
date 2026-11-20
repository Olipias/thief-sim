# q6开场CG：OpenCode交接（2026-11-18）

本批已接入游戏代码，不是仅有美术方案。用户最新要求：指定q6图补短对白；每格5秒自动下一格，Space手动推进，提供Skip。此安排取代旧8格×18秒占位演出及逐字等待安排。其他独立安全屋、手机、全部剧情不在本批完成声明内。

## 直接使用的位置

| 文件 | 用途 |
| --- | --- |
| `docs/art_direction/storyboard/q6_chibi_storyboard.png` | 用户指定原图，保留空白气泡版本 |
| `docs/art_direction/storyboard/q6_chibi_storyboard_dialogue.png` | 补对白后的1536×1024六格总图，交付成图 |
| `docs/art_direction/storyboard/q6_dialogue_prompt.txt` | 实际提交给内置imagegen的完整编辑提示词 |
| `assets/art/opening/q6_chibi_storyboard_dialogue.png` | 导出包实际加载的同字节副本，不加载docs图片 |
| `tools/import_opening_cg.py` | 源图→运行图的确定性导入；`--check`检查同步 |
| `src/data/opening_cg.gd` | 六格多边形区域、标题、中文字幕、5秒常量 |
| `src/ui/contract_intro.gd` | 实际播放UI；运行时绘制选中区域，不预切位图 |
| `src/main.gd` 的 `_on_new_game()` | 新游戏→CG→设置saw_p00→直接museum教学 |
| `tests/test_opening_cg.tscn` | 独立真实按键/鼠标验收，不依赖标题测试是否通过 |

运行：仓库根目录执行 `./play.sh`，选择开始/新游戏；有旧档时按标题现有覆盖确认操作。继续游戏不会重播CG。旧导出包没有这些新代码和资源，必须重新导出，不能把旧class-demo包当成已更新版本。

## 播放规则

- 从左到右先上排、再下排，分六次显示。每格字幕立即完整显示，静置5秒自动下一格；名义总长30秒。
- Space、E或点击画面立即下一格，重新开始该格5秒计时；长按echo不推进，同一帧最多一次。
- 右上角“跳过（Skip）”一次性结束；自然播完与跳过走同一个finished信号，直接教学，不先回栏目页。
- Main._busy阻止CG期间打开背包/手机。结束输入先被消费，避免同次按键在教学里再次拾取。
- 沿用现有saw_p00标记，无新存档字段；未加入中途分镜存档。点击新游戏会按既有规则开启新档。
- 640×360基础画布：上方标题/Skip，中间单格图，下方额外中文字幕与进度。按窗口整数缩放；上下左右黑边是保留画幅，不能拉伸或剪掉气泡。

## 气泡对白（仅四处，避免长文挤框）

| 格 | 说话者 | 图内短对白 |
| --- | --- | --- |
| 1 桥下结账 | 线人 | 钱只剩这些了。 |
| 2 戒指抵款 | 线人 | 这枚戒指抵余款。 |
| 3 收下戒指 | 主角 | 这能值几个钱？ |
| 4 回到住处 | 无气泡 | 不新增气泡；底部：回到住处，戒指忽然发烫。 |
| 5 恶魔出现 | 恶魔 | 收下即签约。先偷青铜面具。违约，命归我。 |
| 6 出发 | 无气泡 | 不新增气泡；底部：先去博物馆拿青铜面具。 |

内容审校限本CG：整段为虚构演绎，UI有提示；恶魔仅说明契约、任务、违约后果，没有动机解释、说教或殖民史判断。青铜面具为游戏教学目标，不以图像或字幕声称某一真实馆藏的流转/追索事实。本记录不代表其他恶魔分支已通过独立审校。

## 更换或修改素材

1. 保留原图与当前派生图；位图修改使用图像编辑工具，不手改生成资源。此图使用OpenAI内置imagegen在用户原图上补四处对白，不生成标题封面。
2. 运行 `python3 tools/import_opening_cg.py`，再运行 `python3 tools/import_opening_cg.py --check`。
3. 若图幅或分格变动，同步OpeningCG.SOURCE_SIZE和PANELS.points，逐格检查气泡完整、无邻格混入。
4. Godot导入资源后运行下方测试；改画面必须重新截图、人工查看，再仅更新预期的开场基线。
5. 原图作者/来源条款与分发许可尚未核实，不声明公有领域；素材登记见根目录ASSETS.md，完整文件哈希见docs/ASSET_FILES.tsv。

## 验证命令

```bash
python3 tools/import_opening_cg.py --check
~/.local/bin/godot --headless res://tests/test_opening_cg.tscn
~/.local/bin/godot --headless --script tests/test_intro_timing.gd
tools/verify.sh
tools/verify.sh --visual
```

输入流用真实InputEventKey/InputEventMouseButton验证Space/E/点击/Skip、自动下一格、手动计时重置、长按抑制、CG期间B无效、两条结束路径进入教学及进度标记。内容测试验证资源存在、尺寸、页数/时长和字幕；冒烟测试验证结束信号幂等。`tests/screenshot.gd`生成六格截图及主开场截图；已目视检查，并只更新对应七张基线。

实测：Godot4.7.2，Linux/WSL，无操作自动播放 **29.933秒**，`tests/test_intro_timing.gd`退出0；脚本不加速、不提前设置elapsed，不以此替代真人阅读评价。

独立开场输入15/15通过；最终全量含视觉为14项通过、4项失败（标题输入调试编译错误、标题旧布局冒烟、标题基线）。整套门禁的实际结果与标题改动相关问题见根目录TEST.md的本批记录及docs/qa/opening_cg_2026-11-18/原始日志。不能把单独CG通过说成整个项目全绿；后续OpenCode须复跑当前工作树，不恢复旧CG来规避标题失败。
