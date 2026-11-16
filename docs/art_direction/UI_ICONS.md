# UI 图标集（路线预演 / 手机 / 电脑）

> 2026-11-14 · art · 依据 `READMEnew.md` §3（零倒计时、失败回放红色高亮）
> 生成器：`tools/gen_ui_icons.py`（不要手改 PNG）。输出目录：`assets/sprites/ui/`，全部 16×16。

## 路线预演（plan_*）

| 文件 | 含义 | 使用位置（建议） |
| --- | --- | --- |
| `plan_eta.png` | 保安预计路线（脚印 + 虚线） | 规划节点上的「保安经过」预测 |
| `plan_camera_cover.png` | 监控视野覆盖 | 监控扇区预测 |
| `plan_door_locked.png` / `plan_door_open.png` | 门锁状态 | 节点上的门状态 |
| `plan_noise.png` | 噪音风险（同心弧） | 跑动/推门噪音圈预测 |
| `plan_fail_reason.png` | 失败高亮准星 | 失败回放的原因标注 |

- 图标**不使用时钟/沙漏**，避免暗示倒计时。
- 节点本体用 `assets/sprites/path_node_16.png`，监控头部用 `monitor_cam_16.png`。

## 手机（phone_app_*）

`phone_app_task`（任务卡）、`phone_app_calendar`（日历，只显示日期格，无倒计时）、`phone_app_contacts`（通讯录）、`phone_app_chat`（聊天）。

## 电脑（pc_app_*）

`pc_app_archive`（档案库）、`pc_app_browser`（浏览器）、`pc_app_mail`（邮件）、`pc_app_chat`（聊天）。

## 接入（给 code）

- 用 `TextureRect` 或 `Button.icon`，尺寸 16×16，关闭插值（nearest）。
- 颜色已与 `noir` 色板对齐（金 / 米纸 / 青 / 朱红），不需要额外调色。
- 新增 PNG 后请 `godot --headless --import`。
