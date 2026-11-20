# WSL多窗口协作桥

2026-11-21。工具：`tools/agent_link.py`（Python标准库，无需安装插件），已有agentchattr继续作为唯一聊天室，频道为thief。后续开发仍遵守OPENCODE_NEXT_PLAN、CONFIRMED_DESIGN与ROADMAP。

## 已接入与边界

- Codex：通过REST注册身份，直接读取/发送与等待点名；身份令牌存本机私有目录，不冒充user或其他角色。
- art、plan、test、code：按精确OpenCode会话标题绑定；守护进程发现点名后通过现有CLI的queue投递唤醒。HTTP/CLI提交成功只叫submitted，不等于agent已回复或完成。
- 额外窗口已辨认为Claude Code原生TUI，由console启动，不是OpenCode会话。当前不强行往其终端注入按键、不抢占运行；要自动接收点名，需在它完成当前工作并退出后，通过下面包装器恢复原对话。不能绑定到旧opencode-a会话冒充打通。
- 当前Codex应用窗口未提供外部守护进程可调用的入站端点。工作中可用watch持续收消息；本轮结束后不会因本脚本自动启动新回合。需要Codex也能在终端自动唤醒时，可使用agentchattr自带codex包装器启动一个独立CLI窗口；这不是当前应用窗口，不能冒称共享同一对话。

## 常用命令

在仓库根目录运行：

```bash
python3 tools/agent_link.py status
python3 tools/agent_link.py read --limit 30
python3 tools/agent_link.py send '@code 请确认当前认领文件和待验收项目，回复证据。'
python3 tools/agent_link.py send --file /tmp/message.txt
python3 tools/agent_link.py watch --seconds 45 --name codex
python3 tools/agent_link.py start
python3 tools/agent_link.py stop
```

首次注册：`python3 tools/agent_link.py register`，成功后不重复注册。CLI出错不打印令牌；网络/CLI受沙盒限制时按宿主要求授权执行，不绕过权限。会话更换时先sessions查看，再bind，不能模糊匹配到别的项目：

```bash
python3 tools/agent_link.py sessions
python3 tools/agent_link.py bind plan plan --wake
```

bind后工作进程会加载新配置。配置、身份、队列与日志在`.agent-link/`，均被gitignore；令牌文件权限0600。不要提交这份目录或将令牌贴进聊天室。

## 原生Claude Code接入（一次操作）

当前Claude继续完成工作。等它退出后，在同一WSL终端运行：

```bash
cd /home/liyutong/thief-sim
./tools/join_claude_chat.sh
```

脚本复用本机agentchattr包装器与tmux，固定Claude工作目录为本仓库，默认通过明确会话ID续接本项目最近历史，关闭自动重启。先运行`./tools/join_claude_chat.sh --dry-run`可检查目录/会话而不启动Claude；`--list`列本地ID，`--picker`手动选历史。包装器注入现有MCP及自动点名唤醒，Claude应按包装器分配的实际名字join/read/send到thief频道。也可在脚本后传明确会话ID。不要同时打开同一会话的两个写入实例。

在Claude先发一条入群消息并确认收到Codex点名、回复之后，才能标记该链路通过。若缺tmux，脚本明确退出，不会自动安装或改动当前Claude进程。

## 投递与监督协议

1. 每条任务包含任务ID、对应设计条款、负责人、涉及文件、预期验收与证据位置。接收者回复“接受/已有负责人/阻塞”，不要只回收到。
2. Codex可审查、指出问题和请求修复。代码文件仍由当前认领者修改；需要代修时先交接文件，避免两个窗口同时改同一段。plan负责ROADMAP归属与顺序，test负责独立复核，art负责素材和生成器，code负责接入。
3. 问题消息写复现步骤、实际/预期、位置与严重性。修复者回复改动和日志；test独立复核，再由plan更新状态。未验证的项目不能标完成。
4. 新桥的wakes记录submitted只证明API受理；接收者明确回复后可用`ack <消息ID> <角色> <结论>`登记本地回执。状态查询单列回执，不自动将提交当作完成。
5. 同一消息按ID/目标去重；失败保留并退避重试，短时间消息合并唤醒，冷却中不丢任务。提交超时无法确认服务端是否已受理，因此是至少一次投递；接收者须按消息ID去重，不重复执行交易/改文件任务。
6. @all只用于启动协调或重要阻断，不自动互相回复确认引起循环；代码片段/代码块里的@不触发新桥。桥不运行消息中的shell，不自动批准、提交、推送或部署。
7. 守护进程首次启动从当前消息尾部开始，防止重放旧任务；之后用since_id取积压，不限最近50条。只有一个worker持有队列锁。聊天服务重启/清空导致ID重置时，停止并备份队列后重新初始化，不能无记录地抹掉pending任务。

## 旧桥与部署约束

原tools/chat_relay.py和外部agent-bridge均保留。启动新桥接管前检查它们是否运行，同一目标只能有一个唤醒负责人。11-21本次只读进程检查未发现二者运行，因此新桥负责四个已识别角色。旧桥日后不应同时重启；需要恢复旧桥时先stop新桥，或bind不带--wake交还对应角色。

后台进程随WSL关闭而停止，不宣称系统级常驻或自动开机启动；重开WSL后执行start。status心跳过旧表示进程已停或服务阻塞，不能只看PID判断正常。

## 验证

离线专项：`python3 -m unittest discover -s tests -p test_agent_link.py -v`。覆盖代码内点名、同名边界、广播、自发消息、系统消息、超50条、批量合并、冷却队列、失败后重启重试、提交与回执分离、私有权限。

现场验证另记录实际消息ID、角色回复与状态；没有回复时只写submitted/待验证，不能写双向已通。Godot全量回归是仓库收尾门槛，和通信专项分别记录。

本轮现场结果见[接入与回归记录](qa/agent_link_2026-11-21/RESULT.md)：art/test已双向确认，code/plan待明确回执，原生Claude续接和当前Codex空闲唤醒均不得标通过。

## Claude Code预算约束（用户追加）

用户说明Claude Code剩余预算约2美元。该数字是剩余额度，不是授权本工具花完；消息桥不能读取或强制限制计费平台费用。

- Claude默认待命，不承担常驻监督、轮询、全仓阅读、全量测试和反复重试。由Codex/plan/code/test/art承担日常工作。
- 不用@all广播唤醒Claude；只向实际承担任务的角色点名。Claude入群后先一次简短确认，不自动扩展为全面评审。
- 确需Claude处理时只发一个边界明确的小任务，附必要代码片段、已有结论、具体问题和简短输出要求；优先一次完成，避免重复转发长历史与整份文档。
- 每次任务先检查是否能由其他窗口完成；Claude报告余额不足或计费失败后停止向它派活，其他窗口接续，不自动重试模型调用。
- 不凭token数估算后宣称硬控2美元，不更改其模型、密钥或计费配置。实际费用以用户计费平台为准。

## 续接脚本修复

原脚本直接使用包装器默认cwd=..，从仓库启动后会进入/home/liyutong而非本项目，导致历史选择范围错误；默认重启还会掩盖退出原因。现由join_claude_chat.py仅在当前进程覆盖Claude的cwd，不改外部全局配置，传--no-restart及明确本地会话ID。专项3项和dry-run通过，未启动Claude/发模型请求；真实交互续接由用户终端确认。
