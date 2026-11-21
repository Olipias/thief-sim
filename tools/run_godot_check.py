#!/usr/bin/env python3
"""Run a check command, forward its output live, and stop it on fatal Godot script errors.

Usage:
  python3 tools/run_godot_check.py [--fatal-grace SEC] -- <command> [args...]

- Output (stdout and stderr merged) is forwarded line by line as it arrives.
- The exit code of the command is returned unchanged, unless a fatal script error was seen.
- A fatal marker ("SCRIPT ERROR:" or "ERROR: Failed to load script") lets the command keep
  printing for --fatal-grace seconds (default 2), then only the command's own process group
  is terminated. The result is non-zero (3), or the command's own non-zero code if it has one,
  even if the command exits 0 after the fatal marker.
- Other errors such as "Parse JSON failed" are not fatal here.
"""
from __future__ import annotations

import argparse
import os
import queue
import signal
import subprocess
import sys
import threading
import time

FATAL_MARKERS = ("SCRIPT ERROR:", "ERROR: Failed to load script")
FATAL_EXIT = 3
DEFAULT_GRACE = 2.0


def is_fatal(line: str) -> bool:
    return any(marker in line for marker in FATAL_MARKERS)


def _kill_group(proc: subprocess.Popen) -> None:
    """Terminate only the group started for this command (start_new_session makes pgid == pid)."""
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        proc.wait(timeout=1)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        proc.wait()


def run(cmd: list[str], fatal_grace: float = DEFAULT_GRACE, out=None) -> tuple[int, bool]:
    """Run cmd. Returns (exit_code, fatal_seen)."""
    out = out or sys.stdout
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        start_new_session=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        bufsize=1,
    )
    lines: queue.Queue = queue.Queue()

    def reader() -> None:
        assert proc.stdout is not None
        for line in proc.stdout:
            lines.put(line)
        lines.put(None)

    thread = threading.Thread(target=reader, daemon=True)
    thread.start()

    fatal = False
    deadline = None
    while True:
        if fatal and time.monotonic() >= deadline:
            break
        timeout = None if deadline is None else max(0.0, deadline - time.monotonic())
        try:
            item = lines.get(timeout=timeout)
        except queue.Empty:
            break
        if item is None:
            break
        out.write(item)
        out.flush()
        if not fatal and is_fatal(item):
            fatal = True
            deadline = time.monotonic() + fatal_grace

    if fatal:
        _kill_group(proc)
    else:
        proc.wait()

    thread.join(timeout=1)
    if proc.stdout is not None:
        proc.stdout.close()

    rc = proc.returncode
    if fatal:
        if rc is None or rc <= 0:
            return FATAL_EXIT, True
        return rc, True
    return rc, False


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--fatal-grace", type=float, default=DEFAULT_GRACE)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    cmd = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not cmd:
        parser.error("missing command after --")
    rc, fatal = run(cmd, fatal_grace=args.fatal_grace)
    if fatal:
        print(f"[run_godot_check] fatal script error detected; exit {rc}", file=sys.stderr, flush=True)
    return rc


if __name__ == "__main__":
    sys.exit(main())
