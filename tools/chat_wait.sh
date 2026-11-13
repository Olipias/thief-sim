#!/usr/bin/env bash
# chat_wait.sh —— agentchattr 自唤醒等待器
#
# 用途：agent 会话在每轮结束前用「后台命令」运行本脚本；脚本阻塞轮询频道，
#       一旦出现需要本 agent 处理的新消息就退出（退出码 0），OpenCode 会自动
#       唤醒该会话继续处理 —— 实现「不用人工去窗口发话」的持续调度。
#
# 用法：
#   tools/chat_wait.sh <自己的名字> [频道] [最长等待秒数]    # 阻塞等待新消息
#   tools/chat_wait.sh mark <自己的名字> <已处理最大消息id>  # 处理完后更新水位
#
# 退出码：
#   0 = 有需要处理的新消息（stdout 给出 last_id 与 mark 命令）
#   2 = 超时无新消息（水位已安全推进到当前最大 id）
#   3 = 连续请求失败（网络/服务异常，别死等）
#
# 触发条件（避免被 join/leave 噪音唤醒）：
#   新消息满足其一：type=chat 且（文本含 @<自己的名字> / @all，或发送者是 user）。
#   其余新消息只抬高观察水位，不触发唤醒。
#
# 依赖：curl、python3。token：$AGENTCHATTR_TOKEN → tools/.agentchattr_token（gitignore）。
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_ROOT="${TMPDIR:-/tmp}"
SERVER="${AGENTCHATTR_SERVER:-http://127.0.0.1:8300}"

if [ "${1:-}" = "mark" ]; then
  NAME="${2:-}"; MARK_ID="${3:-}"
  if [ -z "$NAME" ] || [ -z "$MARK_ID" ]; then
    echo "用法: tools/chat_wait.sh mark <自己的名字> <已处理最大消息id>" >&2; exit 1
  fi
  echo "$MARK_ID" > "$STATE_ROOT/agentchattr_wait_${NAME}.last"
  exit 0
fi

SELF="${1:-}"
CHANNEL="${2:-thief}"
MAX_WAIT="${3:-2400}"
POLL=5
STATE="$STATE_ROOT/agentchattr_wait_${SELF}.last"

if [ -z "$SELF" ]; then
  echo "用法: tools/chat_wait.sh <自己的名字> [频道] [最长等待秒数]" >&2; exit 1
fi

TOKEN="${AGENTCHATTR_TOKEN:-}"
if [ -z "$TOKEN" ] && [ -f "$SCRIPT_DIR/.agentchattr_token" ]; then
  TOKEN="$(tr -d '[:space:]' < "$SCRIPT_DIR/.agentchattr_token")"
fi
if [ -z "$TOKEN" ]; then
  echo "缺少 token：设置 AGENTCHATTR_TOKEN 或创建 tools/.agentchattr_token" >&2; exit 3
fi

LAST=0
[ -f "$STATE" ] && LAST="$(cat "$STATE" 2>/dev/null || echo 0)"
DEADLINE=$(( $(date +%s) + MAX_WAIT ))
ERRS=0

fetch_scan() {
  # stdout: max_id<TAB>matched(0/1)<TAB>matched_max_id ；出错输出 -1
  curl -s -m 8 -H "X-Session-Token: $TOKEN" \
    "$SERVER/api/messages?channel=$CHANNEL&limit=50" | \
  WAIT_SELF="$SELF" WAIT_LAST="$LAST" python3 -c '
import json,sys,os
self_name=os.environ.get("WAIT_SELF","")
last=int(os.environ.get("WAIT_LAST","0") or 0)
try:
    msgs=json.load(sys.stdin)
except Exception:
    print("-1\t0\t0"); raise SystemExit
max_id=0; matched=0; matched_max=0
for m in msgs:
    mid=int(m.get("id",0) or 0); max_id=max(max_id,mid)
    if mid<=last: continue
    if (m.get("type") or "chat")!="chat": continue
    text=(m.get("text") or ""); sender=(m.get("sender") or "")
    if sender=="user" or ("@"+self_name) in text or "@all" in text:
        matched=1; matched_max=max(matched_max,mid)
print("%d\t%d\t%d" % (max_id,matched,matched_max))
'
}

while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  OUT="$(fetch_scan)" || OUT="-1	0	0"
  MAX_ID="${OUT%%$'\t'*}"; REST="${OUT#*$'\t'}"
  MATCHED="${REST%%$'\t'*}"; MATCHED_MAX="${REST##*$'\t'}"
  if [ "$MAX_ID" = "-1" ]; then
    ERRS=$((ERRS+1))
    if [ "$ERRS" -ge 3 ]; then echo "连续请求失败，放弃等待" >&2; exit 3; fi
    sleep 10; continue
  fi
  ERRS=0
  if [ "$MATCHED" = "1" ]; then
    echo "NEW_MESSAGES last_id=$MATCHED_MAX"
    echo "处理完后执行: tools/chat_wait.sh mark $SELF $MATCHED_MAX"
    exit 0
  fi
  sleep "$POLL"
done

# 超时且无触发唤醒的新消息：安全推进水位
if [ "${MAX_ID:-0}" -gt "$LAST" ] 2>/dev/null; then echo "$MAX_ID" > "$STATE"; fi
exit 2
