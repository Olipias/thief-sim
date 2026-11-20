#!/usr/bin/env bash
# 《小偷模拟器》一键验证。
#
# 用法：
#   tools/verify.sh          # 全量（含冒烟测试与随机操作自检）
#   tools/verify.sh --fast   # 快速子集：跳过冒烟测试与 monkey（迭代期用）
#   tools/verify.sh --visual # 全量 + 截图视觉回归（需要显示环境；画面改动后跑）
#
# 任何一步失败都会在最后汇总并以非零退出码结束。

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GODOT="${GODOT:-$HOME/.local/bin/godot}"
FAST=0
VISUAL=0
for arg in "$@"; do
	case "$arg" in
		--fast) FAST=1 ;;
		--visual) VISUAL=1 ;;
		-h | --help)
			echo "用法: tools/verify.sh [--fast] [--visual]"
			exit 0
			;;
		*)
			echo "未知参数: $arg（支持 --fast / --visual）"
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

LOG_DIR="${TMPDIR:-/tmp}/thief_sim_verify_logs"
mkdir -p "$LOG_DIR"

# 引擎级报错门禁：即使脚本退出码为 0，"输出里出现 ERROR/WARNING/泄漏"也算失败。
# 背景：底层 bug（坏节点路径、资源泄漏、非法访问、悬空 preload）大多会先在
# 日志里留下痕迹，而不是让测试断言失败。允许清单里的每一行都必须写明理由。
BAD_RE='^(SCRIPT ERROR|ERROR|USER ERROR|WARNING|USER WARNING)|Leaked instance|ObjectDB instance|Parse Error|Invalid (access|call|index|get)|Failed to (load|open)'
# 允许清单（每条都要写理由）：
#  - V-Sync mode：无 vsync 的驱动下必然出现，无害
#  - Parse JSON failed：存档兼容测试会故意喂损坏 JSON，引擎会打印这条错误
ALLOW_RE='V-Sync mode|Parse JSON failed'

step() {
	local name="$1"
	shift
	echo
	echo "==> $name"
	local log="$LOG_DIR/step_$((PASSED + FAILED + 1)).log"
	local status=0
	"$@" >"$log" 2>&1 || status=$?
	cat "$log"
	if [ "$status" -eq 0 ] && grep -E "$BAD_RE" "$log" | grep -qvE "$ALLOW_RE"; then
		status=1
		echo ""
		echo "✗ 输出包含引擎报错/警告：测试输出必须干净。"
		echo "  新引入的请修根因；确属无害的，才允许加入 verify.sh 的 ALLOW_RE 并写明理由。"
	fi
	if [ "$status" -eq 0 ]; then
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
step "输入流自检（真实按键驱动 UI 覆盖层）" "$GODOT" --headless res://tests/test_input_flow.tscn
step "存档兼容自检（老档 / 脏档 / 未来档）" "$GODOT" --headless --script tests/test_save_compat.gd
step "玩家进度自检（结算 / 仓库 / 收集册 / 存档健壮性）" "$GODOT" --headless --script tests/test_progression.gd
step "剧情自检（story_flags / 双羊尊文物志）" "$GODOT" --headless --script tests/test_story.gd
step "确定性预演自检（R-02 灰盒一致性）" "$GODOT" --headless --script tests/test_sim_preview.gd
step "真实场景等价自检（R-02b 预览 vs 执行）" "$GODOT" --headless res://tests/test_museum_sim.tscn
step "探索循环自检（迷雾 / 侦察撤离 / 跨次保留）" "$GODOT" --headless res://tests/test_exploration.tscn
step "剧情验收（独立：隐藏条件 / 双羊全分支播放）" "$GODOT" --headless --script tests/test_story_flow.gd
step "推理数据自检（三链 / 线索数据边界 / 恶魔分支）" "$GODOT" --headless --script tests/test_reasoning.gd
step "场景实例化自检（src/*.tscn）" "$GODOT" --headless res://tests/test_scenes.tscn
if [ "$FAST" -eq 0 ]; then
	step "随机操作自检（monkey，规则不变量）" "$GODOT" --headless res://tests/test_monkey.tscn
	step "冒烟测试（场景集成）" "$GODOT" --headless res://tests/smoke_test.tscn
fi
if [ "$VISUAL" -eq 1 ]; then
	# 后台静默截图：优先使用 xvfb-run 虚拟帧缓冲（完全不弹窗）；若无 xvfb 则放到屏幕外 (-32000,-32000) 避免抢焦点打扰用户桌面
	if command -v xvfb-run >/dev/null 2>&1; then
		step "截图（视觉回归素材 · 后台虚拟显示）" xvfb-run -a "$GODOT" --audio-driver Dummy res://tests/screenshot.tscn
	else
		step "截图（视觉回归素材 · 屏外静默）" "$GODOT" --audio-driver Dummy --windowed --position -32000,-32000 res://tests/screenshot.tscn
	fi
	step "视觉回归（对比 tests/visual_baseline）" python3 tools/check_visual.py
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
