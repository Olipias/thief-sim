"""课堂演示 pytest 套件：历史文案边界（据 / 推断 / 设 / 未核实）。

依据 docs/CONTENT_REVIEW.md 与 docs/SOURCES.md：现实事实和主张只能来自已核查
事实 ID；未核实的不得扩大成「没有追索」或「已正式索回」；虚构（恶魔、同馆借展、
安保、NPC 接洽与交付）单独标注。数据单一来源 src/data/evidence.gd 与
statements.gd；本套件只校验边界，不另造一套「史实」。
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = (ROOT / "src" / "data" / "evidence.gd").read_text(encoding="utf-8")
STATEMENTS = (ROOT / "src" / "data" / "statements.gd").read_text(encoding="utf-8")
REVIEW = (ROOT / "docs" / "CONTENT_REVIEW.md").read_text(encoding="utf-8")
SOURCES = (ROOT / "docs" / "SOURCES.md").read_text(encoding="utf-8")


def _clue_block(clue_id: str) -> str:
    match = re.search(rf'"{clue_id}":\s*\{{[^}}]*?"body":\s*"([^"]*)"', EVIDENCE, re.S)
    assert match, f"{clue_id} 线索块缺失"
    return match.group(1)


class TestEvidenceBoundary:
    """线索数据的三层边界：据（馆藏可考）/ 推断（标注依据）/ 设（显式虚构）。"""

    def test_archive_clues_use_verifiable_facts(self):
        """『据』类：馆藏档案只用编号/年份/捐赠人等可核字段。"""
        zun_archive = _clue_block("zun_archive")
        assert "1936,1118.1" in zun_archive
        assert "George Eumorfopoulos" in zun_archive or "购自" in zun_archive
        scarab_archive = _clue_block("scarab_archive")
        assert "10.130.1650" in scarab_archive
        assert "1910年捐赠" in scarab_archive
        askos_archive = _clue_block("askos_archive")
        assert "VM-GR-25-012" in askos_archive

    def test_unverified_stays_unverified(self):
        """未核实项保持未核实：不得从一般争议推导单件结论。"""
        zun_archive = _clue_block("zun_archive")
        assert "没有公开确证" in zun_archive, "双羊尊早期流转未核实项缺失"
        assert "不能据此断言" in zun_archive, "缺边界说明"
        scarab_browser = _clue_block("scarab_browser")
        assert "未提供本件正式追索记录" in scarab_browser, "圣甲虫未核实项缺失"
        askos_archive = _clue_block("askos_archive")
        assert "未交代现藏地与失窃经过" in askos_archive, "注壶未核实项缺失"

    def test_inference_is_labelled_not_leap(self):
        """『推断』类：有依据且不得跨级跳跃（1936 入藏 ≠ 1860 被掠）。"""
        zun_tech = _clue_block("zun_tech")
        assert "推定" in zun_tech or "并不是" in zun_tech, "产地推定应标注为推定"
        # 关键史观：不得从入藏记录推导掠夺事实
        assert "1860" not in zun_tech, "推断不得混入未经核实的 1860 断言"

    def test_fiction_blocks_labelled(self):
        """『设』类：恶魔/安保/接洽/交易显式标注虚构。"""
        for clue_id in ["zun_chat", "scarab_mail", "askos_chat"]:
            body = _clue_block(clue_id)
            assert "虚构" in body, f"{clue_id} 缺虚构标注"

    def test_no_nationalist_slurs_or_hard_claims(self):
        """不出现无依据的民族主义断言或单方面定性。"""
        for banned in ("可耻的掠夺", "强盗逻辑", "必须归还", "已确认被抢"):
            assert banned not in EVIDENCE, f"出现不当中文断言：{banned}"
            assert banned not in STATEMENTS, f"出现不当中文断言：{banned}"


class TestStatementsBoundary:
    """声明页：三件文物+教学面饰、来源可查、未核实明示。"""

    def test_all_four_artifacts_covered(self):
        for relic in ["商代双羊尊", "青铜人面饰", "心形圣甲虫", "阿克罗蒂里彩绘注壶"]:
            assert relic in STATEMENTS, f"声明页缺 {relic}"

    def test_unverified_boundary_stated(self):
        for phrase in ["未核实", "没有公开确证"]:
            assert phrase in STATEMENTS, f"声明页缺「{phrase}」边界"

    def test_fiction_disclaimer_present(self):
        assert "虚构演绎" in STATEMENTS, "缺虚构演绎声明"


class TestContentReviewConsistency:
    """核查表与数据一致：三目标 ID/编号与 evidence.gd 对齐，不伪造完成。"""

    def test_three_targets_locked_in_review(self):
        for marker in ["1936,1118.1", "10.130.1650", "VM-GR-25-012"]:
            assert marker in REVIEW, f"核查表缺编号 {marker}"

    def test_review_marks_unverified_claims(self):
        assert "未核实" in REVIEW, "核查表应有未核实标记"
        assert "不能编造埃及官方声明" in REVIEW or "无来源不得写为现实主张" in REVIEW, (
            "核查表应有防伪造声明条款"
        )

    def test_sources_covers_all_three(self):
        for relic in ["双羊尊", "心形圣甲虫", "阿克罗蒂里"]:
            assert relic in SOURCES, f"SOURCES 缺 {relic}"
