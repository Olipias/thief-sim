#!/usr/bin/env python3
"""Resume this project's Claude through agentchattr without changing global config."""
import argparse
import copy
import importlib
from pathlib import Path
import re
import shutil
import sys

PROJECT = Path(__file__).resolve().parent.parent
WRAPPER_ROOT = Path('/home/liyutong/agentchattr')
UUID = re.compile(r'^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$')


def sessions(project=PROJECT, home=None):
    home = Path.home() if home is None else Path(home)
    key = re.sub(r'[^a-zA-Z0-9]', '-', str(project.resolve()))
    directory = home / '.claude/projects' / key
    return sorted((p for p in directory.glob('*.jsonl') if UUID.fullmatch(p.stem)),
                  key=lambda p: p.stat().st_mtime, reverse=True)


def scoped_config(loader, project):
    def load(*args, **kwargs):
        cfg = copy.deepcopy(loader(*args, **kwargs))
        cfg.setdefault('agents', {}).setdefault('claude', {})['cwd'] = str(project.resolve())
        return cfg
    return load


def launch_args(session_id):
    args = ['wrapper.py', 'claude', '--no-restart', '--label', 'Claude Code · thief-sim', '--resume']
    if session_id:
        args.append(session_id)
    return args


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('session', nargs='?')
    parser.add_argument('--picker', action='store_true', help='Show Claude history picker instead of latest session')
    parser.add_argument('--list', action='store_true', help='List local IDs only; never read conversation text')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    rows = sessions()
    if args.list:
        for path in rows:
            print(path.stem)
        return
    if args.session and not UUID.fullmatch(args.session):
        parser.error('会话ID必须是本地Claude的UUID；用--list查看。')
    if args.session and args.session not in {p.stem for p in rows}:
        parser.error('该会话不在当前项目的本地历史目录中。')
    if not rows and not args.picker:
        parser.error('没有找到本项目的Claude历史；可用--picker打开选择器，不自动新建对话。')
    selected = args.session or (None if args.picker else rows[0].stem)
    print('工作目录：', PROJECT, flush=True)
    print('续接会话：', selected or '历史选择器', flush=True)
    print('自动重启：关闭；不会自动发送任务或新提示。', flush=True)
    if args.dry_run:
        return
    if not shutil.which('tmux'):
        parser.error('缺少tmux，未启动Claude。')
    if not (WRAPPER_ROOT / 'wrapper.py').is_file():
        parser.error('找不到agentchattr包装器。')
    sys.path.insert(0, str(WRAPPER_ROOT))
    loader = importlib.import_module('config_loader')
    loader.load_config = scoped_config(loader.load_config, PROJECT)
    wrapper = importlib.import_module('wrapper')
    sys.argv = launch_args(selected)
    wrapper.main()


if __name__ == '__main__':
    main()
