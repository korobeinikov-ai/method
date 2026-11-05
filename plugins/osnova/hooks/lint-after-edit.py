#!/usr/bin/env python3
"""PostToolUse hook: auto-lint a file right after Claude edits/writes it.

.py  -> ruff check (bugs + style, no formatting noise)
.js/.mjs/.cjs -> node --check (syntax only)
.ts/.tsx -> tsc single-file syntax check (no type resolution)

Only linters installed in trusted system folders (Homebrew /opt/homebrew,
/usr/local, /usr/bin, /bin) are run, plus ruff from ~/.local/bin, where the
package installs it — looked up and run with a fixed system PATH (not the session's) from a neutral folder. Anything else — project node_modules,
folders a downloaded repo could ship — is NEVER run. No trusted tsc → TS skipped.

Exit 2 + stderr = feedback goes back to Claude so it fixes the issues.
Hook failure (no linter, bad input) exits 0 and says why in stderr.
"""
import json
import os
import pwd
import re
import shutil
import subprocess
import sys
import tempfile

# Только системные папки Mac (Homebrew и встроенные). Всё остальное — в том числе
# node_modules проекта и любые папки, которые может подложить скачанный репо, — не запускается.
TRUSTED_PREFIXES = ("/opt/homebrew/", "/usr/local/", "/usr/bin/", "/bin/")
# Единственное исключение — ruff из ~/.local/bin: туда его ставит сам пакет. Ищется последним,
# а домашняя папка берётся у системы, не из переменной сеанса.
USER_BIN = os.path.realpath(os.path.join(pwd.getpwuid(os.getuid()).pw_dir, ".local/bin"))
# Проверки ищутся и запускаются ТОЛЬКО с этим путём поиска — не с путём сеанса: у tsc внутри
# `#!/usr/bin/env node`, и с путём сеанса он подхватил бы чужой node из папки проекта.
CLEAN_PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
CLEAN_ENV = {"PATH": CLEAN_PATH, "HOME": os.environ.get("HOME", ""), "LANG": "en_US.UTF-8"}


def system_tool(name):
    """Linter found via the clean system PATH (ruff also in ~/.local/bin), really located
    in a trusted folder and not inside the session folder; otherwise None."""
    own = name == "ruff"
    found = shutil.which(name, path=f"{CLEAN_PATH}:{USER_BIN}" if own else CLEAN_PATH)
    if not found:
        return None
    real = os.path.realpath(found)
    here = os.path.realpath(os.getcwd())
    trusted = TRUSTED_PREFIXES + ((USER_BIN + "/",) if own else ())
    if not real.startswith(trusted) or real.startswith(here + os.sep):
        return None
    return found


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError as e:
        sys.stderr.write(f"lint-after-edit: непонятный вход, пропускаю: {e}\n")
        return 0

    path = (data.get("tool_input") or {}).get("file_path", "")
    if not path:
        return 0

    if path.endswith(".py"):
        tool, args = system_tool("ruff"), ["check", "--quiet", "--no-cache", os.path.abspath(path)]
    elif path.endswith((".js", ".mjs", ".cjs")):
        tool, args = system_tool("node"), ["--check", os.path.abspath(path)]
    elif path.endswith((".ts", ".tsx", ".mts", ".cts")):
        # single-file: catches syntax errors fast; --noResolve skips imports
        tool, args = system_tool("tsc"), ["--noEmit", "--noResolve", "--skipLibCheck",
                                          "--jsx", "preserve", "--target", "esnext", os.path.abspath(path)]
    else:
        return 0
    if not tool:
        return 0  # linter not installed on this computer — nothing to check

    try:
        result = subprocess.run([tool, *args], check=False, capture_output=True, text=True, timeout=30,
                                env=CLEAN_ENV, cwd=tempfile.gettempdir())
    except (OSError, subprocess.SubprocessError) as e:
        sys.stderr.write(f"lint-after-edit: не смог запустить проверку {tool}: {e}\n")
        return 0

    if result.returncode != 0:
        output = (result.stdout + result.stderr).strip()
        if tool.endswith("tsc"):
            # single-file mode: keep only syntax errors (TS1xxx),
            # drop unresolved-import noise (TS2792 etc.)
            lines = [ln for ln in output.splitlines() if re.search(r"error TS1\d{3}:", ln)]
            if not lines:
                return 0
            output = "\n".join(lines)
        if output:
            print(f"Lint issues in {path}:\n{output[:3000]}", file=sys.stderr)
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
