"""
PreToolUse hook (Bash): block commands that destroy work or shared state.

- git stash (except `stash list` / `stash show`): the stash stack is shared by every worktree.
- git push --force / -f / --force-with-lease, git reset --hard, git clean -f, git checkout -- <path>,
  git branch -D: irreversible or rewrite history.
- Write SQL (DROP / DELETE / UPDATE / TRUNCATE / ALTER) run through sqlite3 against a *.db file.
- package_production.py: Track 2 formal release only (docs/DEV_WORKFLOW.md).
- The module-docs-writer subagent (hook input `agent_type`) runs read-only commands only: an allowlist of
  read tools, read-only git subcommands and the citation checker; no redirection to files, no command
  substitution.

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

DOCS_WRITER_AGENT = "module-docs-writer"
DOCS_WRITER_TOOLS = {
    "cd", "pwd", "ls", "cat", "head", "tail", "wc", "grep", "rg", "find", "sort", "uniq", "cut", "tr",
    "basename", "dirname", "date", "file", "stat", "echo",
}
DOCS_WRITER_GIT = {"log", "show", "diff", "status", "rev-parse", "ls-files", "ls-tree", "blame", "grep", "merge-base", "cat-file"}
DOCS_WRITER_CHECKER = re.compile(r"^python3?\s+scripts/check_doc_citations\.py(\s|$)")
SEGMENT_SPLIT = re.compile(r"\|\||&&|[|;&\n]")
# Redirections that write no file (2>&1, >/dev/null) are dropped before the checks below.
HARMLESS_REDIRECT = re.compile(r"\d*>>?\s*(&\d+|/dev/null)")
FIND_WRITE_ACTIONS = re.compile(r"\s-(delete|exec|execdir|ok|okdir|fprint\w*|fls)\b")


def docs_writer_violation(command_text: str) -> str | None:
    """Return why a module-docs-writer command is not read-only, or None if it is allowed."""
    if "$(" in command_text or "`" in command_text:
        return "command substitution is not allowed"
    command_text = HARMLESS_REDIRECT.sub(" ", command_text)
    if ">" in command_text:
        return "output redirection to a file is not allowed"
    for segment in SEGMENT_SPLIT.split(command_text):
        words = [word for word in segment.split() if not re.match(r"^\w+=", word)]
        if not words:
            continue
        program = words[0]
        if program == "git":
            subcommand = next((word for word in words[1:] if not word.startswith("-")), "")
            if subcommand not in DOCS_WRITER_GIT:
                return f"git {subcommand} is not a read-only git command"
            if any(word.startswith("--output") for word in words):
                return "git --output writes a file"
        elif program in ("python", "python3"):
            if not DOCS_WRITER_CHECKER.match(" ".join(words)):
                return "python may only run scripts/check_doc_citations.py"
        elif program not in DOCS_WRITER_TOOLS:
            return f"{program} is not on the read-only command list"
        if program == "find" and FIND_WRITE_ACTIONS.search(segment):
            return "find actions that write or execute are not allowed"
    return None


def main() -> int:
    payload = json.load(sys.stdin)
    command = payload.get("tool_input", {}).get("command", "")
    without_heredocs = HEREDOC.sub(" ", command)
    without_text = QUOTED.sub(" ", without_heredocs)
    if payload.get("agent_type") == DOCS_WRITER_AGENT:
        violation = "heredocs are not allowed" if without_heredocs != command else docs_writer_violation(without_text)
        if violation:
            print(
                f"Blocked by project guard: {DOCS_WRITER_AGENT} runs read-only commands only ({violation}).\n"
                f"Command: {command}\nWrite files with the Edit / Write tools.",
                file=sys.stderr,
            )
            return 2
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
