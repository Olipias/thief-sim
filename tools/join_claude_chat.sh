#!/usr/bin/env bash
# Resume the latest local project conversation; no restart loop.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
python=/home/liyutong/agentchattr/.venv/bin/python
if [[ ! -x "$python" ]]; then
  echo '未找到本机 agentchattr Python 环境。' >&2
  exit 2
fi
exec "$python" tools/join_claude_chat.py "$@"
