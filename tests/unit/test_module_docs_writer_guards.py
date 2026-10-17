"""
Tests for the module-docs-writer guard rails: the write-scope rule in .claude/hooks/protect_files.py,
the read-only Bash rule in .claude/hooks/guard_bash.py, and scripts/check_doc_citations.py.

The hooks are run as Claude Code runs them: a subprocess with the hook JSON on stdin; exit code 2 blocks.
"""
import json
import subprocess
import sys
from pathlib import Path

import pytest

from scripts.check_doc_citations import find_citation_errors

PROJECT_DIR = Path(__file__).resolve().parents[2]
PROTECT_FILES_HOOK = PROJECT_DIR / ".claude" / "hooks" / "protect_files.py"
GUARD_BASH_HOOK = PROJECT_DIR / ".claude" / "hooks" / "guard_bash.py"
DOCS_WRITER = "module-docs-writer"


def run_hook(hook: Path, payload: dict) -> int:
    result = subprocess.run(
        [sys.executable, str(hook)], input=json.dumps(payload), capture_output=True, text=True, timeout=30
    )
    return result.returncode


def write_payload(relative_path: str, agent_type: str | None = DOCS_WRITER) -> dict:
    payload = {"tool_name": "Edit", "tool_input": {"file_path": str(PROJECT_DIR / relative_path)}}
    if agent_type:
        payload["agent_type"] = agent_type
    return payload


def bash_payload(command: str, agent_type: str | None = DOCS_WRITER) -> dict:
    payload = {"tool_name": "Bash", "tool_input": {"command": command}}
    if agent_type:
        payload["agent_type"] = agent_type
    return payload


# --- protect_files.py: write scope -------------------------------------------------------------

@pytest.mark.parametrize(
    "relative_path",
    [
        "docs/modules/import_documentation.md",
        "docs/modules/README.md",
        "docs/phase_03_import_documentation.md",
        ".claude/agent-memory/module-docs-writer/MEMORY.md",
    ],
)
def test_docs_writer_may_write_docs(relative_path):
    assert run_hook(PROTECT_FILES_HOOK, write_payload(relative_path)) == 0


@pytest.mark.parametrize(
    "relative_path",
    [
        "modules/import_documentation/service.py",
        "frontend/lib/features/import_documentation/screens/nafeza_acid_screen.dart",
        "tests/unit/test_suppliers.py",
        "docs/phase_03/tasks/BP-014_request_&_verify_acid_number.md",
        "docs/modules/notes.txt",
        "history/2026-10-16.md",
        ".claude/agent-memory/backend-developer/MEMORY.md",
        ".claude/agents/module-docs-writer.md",
    ],
)
def test_docs_writer_blocked_outside_docs(relative_path):
    assert run_hook(PROTECT_FILES_HOOK, write_payload(relative_path)) == 2


def test_docs_writer_blocked_outside_project():
    payload = {"tool_name": "Write", "tool_input": {"file_path": "/tmp/outside.md"}, "agent_type": DOCS_WRITER}
    assert run_hook(PROTECT_FILES_HOOK, payload) == 2


@pytest.mark.parametrize("agent_type", [None, "backend-developer"])
def test_other_agents_keep_normal_write_rules(agent_type):
    assert run_hook(PROTECT_FILES_HOOK, write_payload("modules/import_documentation/service.py", agent_type)) == 0


# --- guard_bash.py: read-only commands ---------------------------------------------------------

@pytest.mark.parametrize(
    "command",
    [
        "git rev-parse --short HEAD",
        "git status --porcelain -- modules/import_documentation frontend/lib/features/import_documentation",
        "git log --oneline -5 -- modules/import_documentation",
        "grep -n \"@router\\.\" modules/import_documentation/router.py | head -40",
        "wc -l modules/import_documentation/service.py 2>/dev/null",
        "python scripts/check_doc_citations.py docs/modules/import_documentation.md",
        "python3 scripts/check_doc_citations.py docs/modules/import_documentation.md 2>&1",
        "find frontend/test -name '*import_documentation*'",
    ],
)
def test_docs_writer_read_only_commands_allowed(command):
    assert run_hook(GUARD_BASH_HOOK, bash_payload(command)) == 0


@pytest.mark.parametrize(
    "command",
    [
        "echo x > modules/import_documentation/service.py",
        "cat a >> docs/modules/x.md",
        "sed -i 's/a/b/' modules/import_documentation/service.py",
        "rm docs/modules/README.md",
        "git checkout main",
        "git commit -m docs",
        "git add docs/modules",
        "git diff --output=patch.txt",
        "python -c \"open('x','w')\"",
        "python -m pytest tests/unit",
        "find . -name '*.pyc' -delete",
        "echo $(rm -rf docs)",
        "cat <<EOF > x.md\nhello\nEOF",
        "ls | tee out.txt",
    ],
)
def test_docs_writer_write_commands_blocked(command):
    assert run_hook(GUARD_BASH_HOOK, bash_payload(command)) == 2


def test_other_agents_keep_normal_bash_rules():
    assert run_hook(GUARD_BASH_HOOK, bash_payload("sed -i 's/a/b/' x.py", agent_type="backend-developer")) == 0
    assert run_hook(GUARD_BASH_HOOK, bash_payload("git reset --hard", agent_type=None)) == 2


# --- check_doc_citations.py ---------------------------------------------------------------------

@pytest.fixture
def code_root(tmp_path):
    module_dir = tmp_path / "modules" / "import_documentation"
    module_dir.mkdir(parents=True)
    (module_dir / "service.py").write_text("".join(f"line {n}\n" for n in range(1, 11)), encoding="utf-8")
    (tmp_path / "main.py").write_text("a\nb\nc\n", encoding="utf-8")
    return tmp_path


def test_valid_citations_pass(code_root):
    doc = (
        "Tracker (`modules/import_documentation/service.py:4`) and `:6-8`.\n"
        "Router mount `main.py:3`. Plain code `ACID` is ignored.\n"
    )
    assert find_citation_errors(doc, code_root) == []


def test_bare_file_name_is_rejected(code_root):
    errors = find_citation_errors("See `service.py:4`.", code_root)
    assert len(errors) == 1 and "bare file name" in errors[0]


def test_missing_file_is_rejected(code_root):
    errors = find_citation_errors("See `modules/import_documentation/router.py:1`.", code_root)
    assert len(errors) == 1 and "does not exist" in errors[0]


@pytest.mark.parametrize("citation", ["`modules/import_documentation/service.py:11`", "`modules/import_documentation/service.py:9-12`"])
def test_line_past_end_is_rejected(code_root, citation):
    errors = find_citation_errors(citation, code_root)
    assert len(errors) == 1 and "past the end" in errors[0]


def test_short_citation_needs_a_full_one_first(code_root):
    errors = find_citation_errors("Default 90 days (`:6`).", code_root)
    assert len(errors) == 1 and "no full citation" in errors[0]


def test_short_citation_checks_previous_file_range(code_root):
    errors = find_citation_errors("`modules/import_documentation/service.py:2` then `:40`", code_root)
    assert len(errors) == 1 and "past the end" in errors[0]


def test_short_citation_does_not_carry_to_the_next_doc_line(code_root):
    doc = "| A | `modules/import_documentation/service.py:2` |\n| B | `:3` |\n"
    errors = find_citation_errors(doc, code_root)
    assert len(errors) == 1 and "line 2" in errors[0] and "no full citation" in errors[0]


@pytest.mark.parametrize("doc", ["Default 90 days (:6).", "see `modules/import_documentation/service.py:2` and :7-8 too"])
def test_plain_line_hint_outside_backticks_is_rejected(code_root, doc):
    errors = find_citation_errors(doc, code_root)
    assert len(errors) == 1 and "outside backticks" in errors[0]


def test_times_and_urls_are_not_line_hints(code_root):
    assert find_citation_errors("Run at 12:35 via https://pub.dev:443 in a 2:1 ratio.", code_root) == []


def test_reversed_range_is_rejected(code_root):
    errors = find_citation_errors("`modules/import_documentation/service.py:8-3`", code_root)
    assert len(errors) == 1 and "bad line range" in errors[0]
