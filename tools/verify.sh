#!/usr/bin/env bash
# 《小偷模拟器》一键验证。
#
# 用法：
#   tools/verify.sh          # 全量（含冒烟测试）
#   tools/verify.sh --fast   # 快速子集：跳过冒烟测试（迭代期用）
#
# 任何一步失败都会在最后汇总并以非零退出码结束。

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GODOT="${GODOT:-$HOME/.local/bin/godot}"
FAST=0
for arg in "$@"; do
	case "$arg" in
		--fast) FAST=1 ;;
		-h | --help)
			echo "用法: tools/verify.sh [--fast]"
			exit 0
			;;
		*)
			echo "未知参数: $arg（支持 --fast）"
			exit 2
			;;
	esac
done

if [ ! -x "$GODOT" ]; then
	echo "找不到 Godot：$GODOT（可用环境变量 GODOT 指定路径）"
	exit 2
fi

PASSED=0
FAILED=0
FAILED_NAMES=()

step() {
	local name="$1"
	shift
	echo
	echo "==> $name"
	if "$@"; then
		PASSED=$((PASSED + 1))
	else
		FAILED=$((FAILED + 1))
		FAILED_NAMES+=("$name")
	fi
}

step "文档自检（链接 / CHANGELOG 格式）" python3 tools/check_docs.py
step "关卡数据自检（生成物与脚本同步）" python3 tools/check_level.py
step "资源导入（新增/改动贴图与音效）" "$GODOT" --headless --import
step "GDScript 编译检查（src + tests）" "$GODOT" --headless res://tests/test_scripts.tscn
step "逻辑单测" "$GODOT" --headless --script tests/test_logic.gd
step "内容一致性测试" "$GODOT" --headless res://tests/test_content.tscn
if [ "$FAST" -eq 0 ]; then
	step "冒烟测试（场景集成）" "$GODOT" --headless res://tests/smoke_test.tscn
fi

echo
if [ "$FAILED" -eq 0 ]; then
	echo "✅ 全部通过（$PASSED 项）"
	exit 0
fi
echo "❌ 失败 $FAILED 项（通过 $PASSED 项）："
for name in "${FAILED_NAMES[@]}"; do
	echo "   - $name"
done
exit 1
