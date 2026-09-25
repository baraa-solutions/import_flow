"""
SessionStart hook: give the session a short, current picture of the repository.

Adds as context: branch, divergence from origin/main (last fetched state, no network),
uncommitted changes, last commit, and the current version. Kept to a few lines on purpose.
"""
import json
import subprocess
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parents[2]


def git(*args: str) -> str:
    result = subprocess.run(["git", *args], cwd=PROJECT_DIR, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return result.stdout.rstrip() if result.returncode == 0 else ""


def main() -> int:
    branch = git("rev-parse", "--abbrev-ref", "HEAD") or "unknown"
    divergence = git("rev-list", "--left-right", "--count", "origin/main...HEAD").split()
    behind, ahead = (divergence + ["?", "?"])[:2]
    changed = [line for line in git("status", "--porcelain").splitlines() if line.strip()]
    last_commit = git("log", "-1", "--format=%h %ad %s", "--date=format:%Y-%m-%d %H:%M")

    version = "unknown"
    try:
        version = json.loads((PROJECT_DIR / "version.json").read_text(encoding="utf-8-sig")).get("version", version)
    except (OSError, ValueError):
        pass

    lines = [
        f"Repository state at session start: branch `{branch}`, {ahead} commit(s) ahead / {behind} behind origin/main "
        f"(as of last fetch), {len(changed)} uncommitted path(s), last commit: {last_commit}. App version {version}.",
    ]
    if behind not in ("0", "?"):
        lines.append("origin/main has commits this branch lacks - run /git-sync before large changes.")
    if changed:
        preview = ", ".join(line[3:] for line in changed[:8])
        lines.append(f"Uncommitted: {preview}{' ...' if len(changed) > 8 else ''}")

    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": "\n".join(lines),
        }
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
