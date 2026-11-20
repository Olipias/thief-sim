# 规划冻结漏洞修复与试玩交接（v0.23.3）

## 原因与修复范围

原execute_plan只恢复玩家，绕过了退出规划时恢复守卫的逻辑；随后方向键接管只取消自动移动，造成玩家自由走动而守卫永久冻结。旧输入测试预先关闭AI，且未检查真实守卫位移。

现在Museum._sync_world_freeze统一规划、执行、接管、路线完成、失败回放、重试和结束；Police.world_frozen独立于剧情/截图的ai_enabled。冻结子节点时保留物理碰撞，不能在发现信号同步回调中移除正运行的物理体。执行/接管恢复所有世界处理，不清空正常巡逻/警觉/致盲计时。

## 复现与验收

1. 新游戏跳过CG、教学简报进入关卡；按Tab/R进入规划。
2. 持续按WASD/方向键、E、Q：人物不移动，不能拾取/用道具，守卫、监控和世界计时不推进；P打开再关闭手机仍保留规划冻结。
3. 点击地面加路线，按Space执行：人物和真实守卫一起移动，世界计时继续。
4. 分别用方向键和E接管，守卫继续运行；进入有效视野仍能被发现。
5. 路线自然结束、反复Tab/R切换、真实发现后Space重试，均不遗留守卫定身。

## 自动证据

- 首轮真实输入26项复现3项失败：守卫执行时不移动、接管后不移动、规划时致盲计时未冻结。修后扩展到30项，包含E接管与路线自然结束。
- 同一输入用例在tests/test_input_flow.gd与tests/test_planning_freeze.tscn运行；不预先关闭AI，检查真实坐标、计时、道具、真实发现及原因。
- 纯逻辑覆盖独立AI开关、追击/巡逻/警觉计时保持；冒烟验证物理空间与真实监控恢复；monkey检查状态互斥、冻结一致和恢复后无残留。
- 烟雾/噪音冒烟单独测试AI转换时隔离失败UI信号；世界冻结中不能继续使用烟雾。真实发现回放另由实际输入与bust_flow验证，不能用关闭AI冒充感知恢复。

## 发布包复核方法

构建到独立build/planning-fix-v0.23.3目录，保留旧class-demo包。源码工作树有其他批次改动；包内BUILD_INFO.json记录实际运行资源哈希，不仅引用旧Git提交号。

发布模板禁用命令行路径覆盖：外部--script尝试45秒未执行测试，外部场景参数明确报disable_path_overrides；这两次不算通过，也不再延长超时。改用实际原生游戏窗口：

```bash
python3 tools/test_planning_pack_ui.py /absolute/path/to/unpacked/thief-sim.x86_64 /tmp/thief-freeze-native-ui
```

脚本使用已有Xvfb、libX11/libXtst与Pillow，独立虚拟桌面中聚焦真实游戏窗口；不安装依赖，不操作用户桌面，不注入脚本或替换游戏场景。通过开始按钮→CG Skip→教学→Tab规划→真实方向键→Space执行→方向键接管，比较玩家/守卫区域截图。首次自动操作因无窗口管理器未进入游戏，已修正显式聚焦，并加CG/教学入口断言，防止假阳性。

实测Linux解压包 **7/7通过**；源码中的完整专项真实输入 **30/30通过**。这是自动验证，不冒充真人游玩或Windows实机测试。游戏日志只有现有验证器允许的Xvfb不支持V-Sync警告，无引擎ERROR/非法访问。原生包测试的存档隔离在输出目录，不覆盖玩家存档。

## 最终结果与证据

- tools/verify.sh --visual：**18项全部通过**，42张视觉回归；逻辑2549、完整输入210、冒烟166、monkey600步通过。
- [修复前原始日志](planning_freeze_v0.23.3/before.log) · [修复后专项](planning_freeze_v0.23.3/after.log) · [最终全量/视觉](planning_freeze_v0.23.3/verify_visual.log)。
- [Linux发布包输入日志](planning_freeze_v0.23.3/pack_ui.log) · [实际可执行文件与7项结果](planning_freeze_v0.23.3/pack_result.json)。
- [规划前截图](planning_freeze_v0.23.3/04-planning-before.png) · [规划中按移动键后截图](planning_freeze_v0.23.3/05-planning-after-movement.png) · [执行后](planning_freeze_v0.23.3/06-executed.png) · [接管后守卫继续行动](planning_freeze_v0.23.3/08-takeover-guard-continues.png)。已目视确认。
- 三张基线按守卫AI开关保留及冻结时机的正确行为更新（room3/backpack/failure_replay），截图流程固定AI禁用以减少时序偏移；未放宽任何阈值。
- 新包：build/planning-fix-v0.23.3/thief-sim-v0.23.3-planning-fix-windows.zip（45.4MiB）和linux.zip（36.3MiB）；Windows已导出但本机无Windows实机测试。
- SHA256：Windows 1c9af74530efd25226d3615817141351adfc4338bdb73d23bca765ab5a6028ef；Linux 3e58d4463a07d98ffa4b435e0744428a48d677c769cebe98e912a4e0417a98f1。

本轮只修复冻结恢复契约；完整关卡的简化预演模型、完整快照回退和历史内容不因此宣称全部达标。后续仍按DETERMINISTIC_PREVIEW逐项核验。
