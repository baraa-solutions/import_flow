"""
PreToolUse hook (Bash): block commands that destroy work or shared state.

- git stash (except `stash list` / `stash show`): the stash stack is shared by every worktree.
- git push --force / -f / --force-with-lease, git reset --hard, git clean -f, git checkout -- <path>,
  git branch -D: irreversible or rewrite history.
- Write SQL (DROP / DELETE / UPDATE / TRUNCATE / ALTER) run through sqlite3 against a *.db file.
- package_production.py: Track 2 formal release only (docs/DEV_WORKFLOW.md).

Exit code 2 blocks the call and tells Claude to ask the user to run it themselves.
"""
import json
import re
import sys

# Matched against the command with heredoc bodies and quoted strings removed, so commit messages,
# echo text and docs that merely mention these commands are not blocked.
COMMAND_PATTERNS = [
    (r"\bgit\s+stash\b(?!\s+(list|show)\b)", "git stash is shared by all worktrees of this repo; use a local WIP commit instead"),
    (r"\bgit\s+push\b[^|;&]*\s(--force(-with-lease)?|-f)\b", "force-push rewrites remote history"),
    (r"\bgit\s+reset\s+[^|;&]*--hard\b", "git reset --hard discards uncommitted work"),
    (r"\bgit\s+clean\s+[^|;&]*-[a-zA-Z]*f", "git clean -f deletes untracked files permanently"),
    (r"\bgit\s+checkout\b[^|;&]*\s--\s", "git checkout -- <path> discards local changes"),
    (r"\bgit\s+branch\s+[^|;&]*-D\b", "git branch -D deletes an unmerged branch"),
    (r"\bpackage_production\.py\b", "package_production.py is Track 2 (formal release) only - see docs/DEV_WORKFLOW.md"),
]

# SQL is normally passed as a quoted argument, so this one keeps quoted strings (heredocs still removed).
SQL_PATTERN = (
    r"sqlite3?\b[^|;&]*\.db\b[^|;&]*\b(?i:DROP|DELETE|UPDATE|TRUNCATE|ALTER|INSERT)\b",
    "write SQL against a live SQLite database",
)

HEREDOC = re.compile(r"<<-?\s*(['\"]?)(\w+)\1[^\n]*\n.*?\n\s*\2\b", re.DOTALL)
QUOTED = re.compile(r"'[^']*'|\"(?:\\.|[^\"\\])*\"")


def main() -> int:
    payload = json.load(sys.stdin)
    command = payload.get("tool_input", {}).get("command", "")
    without_heredocs = HEREDOC.sub(" ", command)
    without_text = QUOTED.sub(" ", without_heredocs)
    checks = [(pattern, reason, without_text) for pattern, reason in COMMAND_PATTERNS]
    checks.append((*SQL_PATTERN, without_heredocs))
    for pattern, reason, text in checks:
        if re.search(pattern, text):
            print(
                f"Blocked by project guard: {reason}.\nCommand: {command}\n"
                "If this is really intended, ask the user to run it themselves.",
                file=sys.stderr,
            )
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
