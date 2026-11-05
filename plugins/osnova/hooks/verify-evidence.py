#!/usr/bin/env python3
"""PostToolUse hook: log "verification evidence" for verify-gate.py.

Counts as evidence (adapted from anthropics/cwc-long-running-agents):
- Bash commands that run/test/inspect something (tests, builds, curl, logs...)
- Read of a screenshot (.png/.jpg)

verify-gate.py consumes the log when a git commit is allowed, so every
commit needs fresh proof. Fail-open: any error exits 0.
"""
import json
import re
import sys
import tempfile
from pathlib import Path

EVIDENCE_RE = re.compile(
    r"pytest|npm (test|run)|pnpm (test|run)|npx |next (build|dev)|tsc\b"
    r"|playwright|curl |node |python3? |railway (logs|run)|psql|vitest|jest"
    r"|check\.sh",  # общий прогон проверок проекта — тоже улика
)


def log_path(session_id):
    return Path(tempfile.gettempdir()) / f"claude-verify-{session_id or 'default'}.log"


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:  # noqa: BLE001
        return 0

    tool = data.get("tool_name", "")
    ti = data.get("tool_input") or {}
    entry = None

    if tool == "Bash":
        cmd = ti.get("command", "")
        # a git commit itself is not evidence
        if EVIDENCE_RE.search(cmd) and "git commit" not in cmd:
            entry = f"bash: {cmd[:200]}"
    elif tool == "Read":
        p = ti.get("file_path", "")
        if p.endswith((".png", ".jpg", ".jpeg")):
            entry = f"screenshot: {p}"

    if entry:
        try:
            with open(log_path(data.get("session_id")), "a") as f:
                f.write(entry + "\n")
        except OSError as e:
            sys.stderr.write(f"verify-evidence: не записал улику проверки: {e}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
