"""
PostToolUse hook: verify an edited backend Python module still imports.

Catches definition-time errors (e.g. a missing `from typing import Dict`)
the moment they are written, instead of when the whole app fails to boot.
Only the edited module (and what it imports) is loaded, against a throwaway
database path, so the real sorour_logistics.db is never touched.

Exit code 2 feeds stderr back to Claude so it fixes the error immediately.
"""
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parents[2]
BACKEND_ROOTS = ("modules", "database", "utils")
BACKEND_FILES = ("main.py", "settings.py")
IMPORT_TIMEOUT_SECONDS = 90


def resolve_module_name(file_path: str) -> str | None:
    try:
        relative = Path(file_path).resolve().relative_to(PROJECT_DIR)
    except ValueError:
        return None
    if relative.suffix != ".py":
        return None
    parts = relative.parts
    if len(parts) == 1 and parts[0] in BACKEND_FILES:
        return relative.stem
    if parts[0] not in BACKEND_ROOTS:
        return None
    module_parts = list(relative.with_suffix("").parts)
    if module_parts[-1] == "__init__":
        module_parts.pop()
    return ".".join(module_parts)


def main() -> int:
    payload = json.load(sys.stdin)
    file_path = payload.get("tool_input", {}).get("file_path", "")
    module_name = resolve_module_name(file_path)
    if not module_name:
        return 0

    with tempfile.TemporaryDirectory(prefix="importflow_smoke_") as temp_dir:
        env = {
            **os.environ,
            "SECRET_KEY": "smoke-import-hook-secret-key-not-for-production",
            "ALLOW_DEV_AUTH_BYPASS": "false",
            "DATABASE_PATH": str(Path(temp_dir) / "smoke.db"),
        }
        try:
            result = subprocess.run(
                [sys.executable, "-c", f"import importlib; importlib.import_module({module_name!r})"],
                cwd=PROJECT_DIR,
                env=env,
                capture_output=True,
                text=True,
                timeout=IMPORT_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired:
            print(f"smoke_import: importing {module_name} exceeded {IMPORT_TIMEOUT_SECONDS}s", file=sys.stderr)
            return 0

    if result.returncode != 0:
        print(
            f"Module `{module_name}` no longer imports after this edit "
            f"(the backend will fail to boot):\n{result.stderr[-2000:]}",
            file=sys.stderr,
        )
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
