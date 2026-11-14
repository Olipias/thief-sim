#!/usr/bin/env python3
"""chat_relay.py —— @点名 → 直接唤醒目标 agent 会话的中继器（协作 v5）。

原理：agentchattr 的调度只能送达「桥接还连着」的会话；而 OpenCode 的本地
server（opencode serve --service）提供 /api/session/<id>/prompt（steer 投递），
可以把一条提示直接注入任意会话——**不管它当前是否在线**。

本守护进程用 HTTP 轮询聊天室（每 6 秒，纯脚本，零 token），发现新消息里
@了某个 agent，就把一条极简提示注入该 agent 的会话，它就会被唤醒去读积压、
处理任务。@点名从此等于真实唤醒。

- 水位：/tmp/agentchattr_relay.last（重启不重放）
- 日志：/tmp/agentchattr_relay.log；心跳：/tmp/agentchattr_relay.heartbeat
- 目标映射：tools/.relay_targets.json（{"art": "ses_...", ...}）
- token：tools/.agentchattr_token（同 chat_wait.sh）
- 用法：python3 tools/chat_relay.py [--once]
"""
import json
import os
import re
import subprocess
import sys
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOKEN = open(os.path.join(ROOT, "tools", ".agentchattr_token")).read().strip()
CHAT = "http://127.0.0.1:8300"
STATE = "/tmp/agentchattr_relay.last"
LOG = "/tmp/agentchattr_relay.log"
HEART = "/tmp/agentchattr_relay.heartbeat"
TARGETS = json.load(open(os.path.join(ROOT, "tools", ".relay_targets.json")))
POLL = 6
MENTION_RE = re.compile(r"(?<![`\w])@(art|code|test|opencode-a|all)\b", re.I)
CODE_SPAN_RE = re.compile(r"```.*?```|`[^`\n]*`", re.S)


def log(msg):
    line = time.strftime("[%H:%M:%S] ") + msg
    print(line, flush=True)
    try:
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


def http_json(url):
    req = urllib.request.Request(url, headers={"X-Session-Token": TOKEN})
    with urllib.request.urlopen(req, timeout=8) as r:
        return json.load(r)


def inject(session_id, text):
    # 用 opencode CLI 注入（CLI 自带本地 server 的认证，raw HTTP 会 401）
    body = json.dumps({"text": text})
    r = subprocess.run(
        ["/home/liyutong/.opencode/bin/opencode", "api", "post",
         f"/api/session/{session_id}/prompt", "-d", body],
        capture_output=True, text=True, timeout=20)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip() or r.stdout.strip()[-200:])
    return json.loads(r.stdout) if r.stdout.strip().startswith("{") else r.stdout


def main(once=False):
    last = 0
    if os.path.exists(STATE):
        last = int(open(STATE).read().strip() or 0)
    log(f"relay 启动，水位 {last}，目标 {list(TARGETS)}")
    errs = 0
    while True:
        try:
            msgs = http_json(f"{CHAT}/api/messages?channel=thief&limit=50")
            msgs = [m for m in msgs if (m.get("type") or "chat") == "chat"]
            max_id = max([int(m["id"]) for m in msgs], default=last)
            new = [m for m in msgs if int(m["id"]) > last]
            new.sort(key=lambda m: int(m["id"]))
            for m in new:
                mid, sender, text = m["id"], m.get("sender") or "", m.get("text") or ""
                clean_text = CODE_SPAN_RE.sub(" ", text)
                hits = set(x.lower() for x in MENTION_RE.findall(clean_text))
                if "all" in hits:
                    hits = set(k.lower() for k in TARGETS)
                else:
                    hits.discard("")
                for name, sid in TARGETS.items():
                    if name == sender or name.lower() not in hits:
                        continue
                    if name == "plan":
                        continue  # plan 自己有等待器
                    prompt = (f"[relay] #thief 新消息（id={mid}，来自 {sender}）@了你："
                              "请 join 读积压并处理；完成后发结论，然后待命。")
                    try:
                        inject(sid, prompt)
                        log(f"已注入 {name}（{sid[:18]}…）← 消息 {mid} by {sender}")
                    except Exception as e:
                        log(f"注入 {name} 失败：{e}")
            last = max_id
            with open(STATE, "w") as f:
                f.write(str(last))
            open(HEART, "w").write(str(time.time()))
            errs = 0
        except Exception as e:
            errs += 1
            log(f"轮询异常（{errs}）：{e}")
            if errs >= 5:
                log("连续失败，relay 退出（由 plan sweep 负责重启）")
                sys.exit(3)
        if once:
            log("once 模式结束")
            return
        time.sleep(POLL)


if __name__ == "__main__":
    main(once="--once" in sys.argv)
