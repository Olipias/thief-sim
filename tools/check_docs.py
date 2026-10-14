#!/usr/bin/env python3
"""文档自检：站内链接可达性 + CHANGELOG 格式 + 必需文档存在。

用法：python3 tools/check_docs.py
失败以非零退出码结束。
"""
import datetime
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

REQUIRED = [
    "AGENTS.md",
    "README.md",
    "CHANGELOG.md",
    "docs/ARCHITECTURE.md",
    "docs/ROADMAP.md",
    "docs/DECISIONS.md",
    "docs/SOURCES.md",
    "tools/verify.sh",
]

DOC_PATHS = ["AGENTS.md", "README.md", "CHANGELOG.md", "docs", ".opencode/skills", ".opencode/commands"]

LINK_RE = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
VERSION_RE = re.compile(r"^## \[(v\d+\.\d+\.\d+)\] - (\d{4}-\d{2}-\d{2})\s*$", re.M)
SKIP_SCHEMES = ("http://", "https://", "mailto:", "user://", "res://")


def iter_docs():
    for entry in DOC_PATHS:
        path = os.path.join(ROOT, entry)
        if os.path.isfile(path) and path.endswith(".md"):
            yield path
        elif os.path.isdir(path):
            for dirpath, dirnames, filenames in os.walk(path):
                dirnames[:] = [d for d in dirnames if d != "node_modules"]
                for name in filenames:
                    if name.endswith(".md"):
                        yield os.path.join(dirpath, name)


def check_links(errors) -> int:
    checked = 0
    for md in iter_docs():
        with open(md, encoding="utf-8") as f:
            text = f.read()
        for link in LINK_RE.findall(text):
            target = link.split("#", 1)[0].strip()
            if not target or target.startswith(SKIP_SCHEMES):
                continue
            resolved = os.path.normpath(os.path.join(os.path.dirname(md), target))
            checked += 1
            if not os.path.exists(resolved):
                errors.append("%s: 链接不可达 -> %s" % (os.path.relpath(md, ROOT), link))
    return checked


def check_changelog(errors) -> int:
    path = os.path.join(ROOT, "CHANGELOG.md")
    with open(path, encoding="utf-8") as f:
        text = f.read()
    entries = VERSION_RE.findall(text)
    if not entries:
        errors.append("CHANGELOG.md: 找不到形如 `## [v0.7.0] - 2026-10-08` 的版本条目")
        return 0
    first = text.find("## [")
    if re.search(r"^## ", text[:first], re.M):
        errors.append("CHANGELOG.md: 首个版本条目前不应有其它二级标题")
    versions = []
    for ver, date in entries:
        nums = tuple(int(x) for x in ver[1:].split("."))
        versions.append((nums, ver))
        try:
            datetime.datetime.strptime(date, "%Y-%m-%d")
        except ValueError:
            errors.append("CHANGELOG.md: %s 的日期不是合法 YYYY-MM-DD：%s" % (ver, date))
    for (newer, va), (older, vb) in zip(versions, versions[1:]):
        if older >= newer:
            errors.append("CHANGELOG.md: 版本顺序错误，%s 应早于 %s" % (vb, va))
    return len(entries)


def main() -> int:
    errors = []

    for rel in REQUIRED:
        if not os.path.exists(os.path.join(ROOT, rel)):
            errors.append("缺必需文件：%s（维护体系的一部分，不要删除）" % rel)

    links = check_links(errors)
    n_entries = check_changelog(errors)

    if errors:
        print("check_docs FAILED:")
        for err in errors:
            print("  -", err)
        return 1
    print("check_docs OK（链接 %d 条可达；CHANGELOG %d 个版本条目）" % (links, n_entries))
    return 0


if __name__ == "__main__":
    sys.exit(main())
