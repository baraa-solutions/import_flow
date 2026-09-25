"""
PreToolUse hook: guard files that must never be rewritten by an agent.

- history/*.md is append-only (AGENTS.md section 18): a full Write over an
  existing file is blocked; Edit (appending a new task entry) is allowed.
- .env holds the generated SECRET_KEY: no edits.
- *.db / *.db-wal / *.db-shm are live SQLite databases: no edits.

Exit code 2 blocks the tool call and shows the reason to Claude.
"""
import json
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parents[2]
DATABASE_SUFFIXES = (".db", ".db-wal", ".db-shm", ".sqlite", ".sqlite3")


def block(reason: str) -> int:
    print(reason, file=sys.stderr)
    return 2


def main() -> int:
    payload = json.load(sys.stdin)
    tool_name = payload.get("tool_name", "")
    file_path = payload.get("tool_input", {}).get("file_path", "")
    if not file_path:
        return 0

    target = Path(file_path).resolve()
    name = target.name.lower()

    if name == ".env" or name.startswith(".env."):
        return block(f"Blocked: {target.name} holds secrets (SECRET_KEY). Ask the user to edit it manually.")

    if name.endswith(DATABASE_SUFFIXES):
        return block(f"Blocked: {target.name} is a live SQLite database. Change data through the app or a migration.")

    try:
        relative = target.relative_to(PROJECT_DIR)
    except ValueError:
        return 0

    is_history_log = relative.parts[:1] == ("history",) and target.suffix == ".md"
    if tool_name == "Write" and is_history_log and target.exists():
        return block(
            f"Blocked: {relative.as_posix()} is append-only (AGENTS.md section 18). "
            "Use Edit to append the new task entry at the end of the file instead of overwriting it."
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
