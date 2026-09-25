"""
Stop / SubagentStop hook: do not let a turn end while the backend fails to boot.

Runs `import main` against a throwaway database only when backend Python files changed since the last
successful check (fingerprint of `git diff HEAD` + untracked backend .py files), so turns without
backend changes cost nothing. On failure exits 2 so Claude keeps working and fixes the import error.
Claude Code stops honouring a Stop hook after 8 consecutive blocks, so this cannot loop forever.
"""
import hashlib
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parents[2]
CACHE_FILE = PROJECT_DIR / ".claude" / ".cache" / "boot_ok"
BACKEND_PATHS = ["main.py", "settings.py", "modules", "database", "utils"]
BOOT_TIMEOUT_SECONDS = 180


def git(*args: str) -> str:
    result = subprocess.run(["git", *args], cwd=PROJECT_DIR, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return result.stdout


def backend_fingerprint() -> str:
    tracked_diff = git("diff", "HEAD", "--", *BACKEND_PATHS)
    untracked = [
        path for path in git("ls-files", "--others", "--exclude-standard", "--", *BACKEND_PATHS).splitlines()
        if path.endswith(".py")
    ]
    if not tracked_diff and not untracked:
        return ""
    digest = hashlib.sha256(tracked_diff.encode("utf-8"))
    for path in sorted(untracked):
        digest.update(path.encode("utf-8"))
        try:
            digest.update((PROJECT_DIR / path).read_bytes())
        except OSError:
            pass
    return digest.hexdigest()


def main() -> int:
    json.load(sys.stdin)  # consume the hook payload
    fingerprint = backend_fingerprint()
    if not fingerprint:
        return 0
    if CACHE_FILE.exists() and CACHE_FILE.read_text(encoding="utf-8").strip() == fingerprint:
        return 0

    with tempfile.TemporaryDirectory(prefix="importflow_boot_gate_") as temp_dir:
        env = {
            **os.environ,
            "SECRET_KEY": "boot-gate-hook-secret-key-not-for-production-use",
            "ALLOW_DEV_AUTH_BYPASS": "false",
            "DATABASE_PATH": str(Path(temp_dir) / "boot_gate.db"),
        }
        try:
            result = subprocess.run(
                [sys.executable, "-c", "import main"],
                cwd=PROJECT_DIR, env=env, capture_output=True, text=True, timeout=BOOT_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired:
            print(f"boot_gate: `import main` exceeded {BOOT_TIMEOUT_SECONDS}s - not blocking.", file=sys.stderr)
            return 0

    if result.returncode != 0:
        print(
            "The backend no longer boots (`import main` fails on Python 3.12) with the current changes. "
            f"Fix this before finishing:\n{result.stderr[-2500:]}",
            file=sys.stderr,
        )
        return 2

    CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
    CACHE_FILE.write_text(fingerprint, encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
