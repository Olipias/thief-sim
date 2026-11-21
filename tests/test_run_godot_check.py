"""Real-subprocess tests for tools/run_godot_check.py (G12). No Godot is started."""
from __future__ import annotations

import io
import os
import signal
import subprocess
import sys
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import run_godot_check as rgc  # noqa: E402

PY = sys.executable


def _alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def _run(code: str, grace: float = 0.2) -> tuple[int, bool, str, float]:
    buf = io.StringIO()
    start = time.monotonic()
    rc, fatal = rgc.run([PY, "-c", code], fatal_grace=grace, out=buf)
    return rc, fatal, buf.getvalue(), time.monotonic() - start


class RunGodotCheckTests(unittest.TestCase):
    def test_normal_output_and_zero_exit(self):
        rc, fatal, out, _ = _run("print('hello from check')")
        self.assertEqual(rc, 0)
        self.assertFalse(fatal)
        self.assertIn("hello from check", out)

    def test_nonzero_exit_is_preserved(self):
        rc, fatal, out, _ = _run("import sys; print('x'); sys.exit(5)")
        self.assertEqual(rc, 5)
        self.assertFalse(fatal)
        self.assertIn("x", out)

    def test_parse_json_error_is_not_fatal(self):
        rc, fatal, out, _ = _run("print('Parse JSON failed: bad input'); import sys; sys.exit(0)")
        self.assertEqual(rc, 0)
        self.assertFalse(fatal)
        self.assertIn("Parse JSON failed", out)

    def test_fatal_stops_command_and_returns_nonzero(self):
        code = (
            "import os, time\n"
            "print('SCRIPT ERROR: boom', flush=True)\n"
            "print('context line', flush=True)\n"
            "print('PID=%d' % os.getpid(), flush=True)\n"
            "time.sleep(600)\n"
        )
        rc, fatal, out, elapsed = _run(code, grace=0.2)
        self.assertTrue(fatal)
        self.assertNotEqual(rc, 0)
        self.assertIn("SCRIPT ERROR: boom", out)
        self.assertIn("context line", out)
        self.assertLess(elapsed, 10, "must not wait for the 600 s sleep")
        pid = int(next(line.split("=", 1)[1] for line in out.splitlines() if line.startswith("PID=")))
        self.assertFalse(_alive(pid), "the fatal command's process must be terminated")

    def test_fatal_then_zero_exit_still_fails(self):
        rc, fatal, out, _ = _run("print('ERROR: Failed to load script res://x.gd'); import sys; sys.exit(0)")
        self.assertTrue(fatal)
        self.assertEqual(rc, rgc.FATAL_EXIT)
        self.assertNotEqual(rc, 0)

    def test_fatal_then_child_nonzero_is_preserved(self):
        rc, fatal, out, _ = _run("print('SCRIPT ERROR: y'); import sys; sys.exit(7)")
        self.assertTrue(fatal)
        self.assertEqual(rc, 7)

    def test_unrelated_sibling_process_survives(self):
        sibling = subprocess.Popen([PY, "-c", "import time; time.sleep(600)"])
        try:
            rc, fatal, _, _ = _run("import time; print('SCRIPT ERROR: z', flush=True); time.sleep(600)", grace=0.1)
            self.assertTrue(fatal)
            self.assertNotEqual(rc, 0)
            self.assertIsNone(sibling.poll(), "a process outside the command's group must not be killed")
        finally:
            sibling.kill()
            sibling.wait()

    def test_grandchild_in_same_group_is_cleaned_up(self):
        code = (
            "import subprocess, sys, time\n"
            "gc = subprocess.Popen([sys.executable, '-c', 'import os,time; print(\"GC=%d\" % os.getpid(), flush=True); time.sleep(600)'])\n"
            "print('SCRIPT ERROR: w', flush=True)\n"
            "time.sleep(600)\n"
        )
        rc, fatal, out, elapsed = _run(code, grace=0.3)
        self.assertTrue(fatal)
        self.assertNotEqual(rc, 0)
        self.assertLess(elapsed, 15)
        gc_pid = int(next(line.split("=", 1)[1] for line in out.splitlines() if line.startswith("GC=")))
        time.sleep(0.2)
        self.assertFalse(_alive(gc_pid), "grandchild in the command's own group must be terminated")

    def test_cli_requires_command(self):
        with self.assertRaises(SystemExit):
            rgc.main(["--"])


if __name__ == "__main__":
    unittest.main()
