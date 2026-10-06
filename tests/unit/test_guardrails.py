"""
scripts/ci/guardrails.py: tool-agnostic guardrails (git hooks + PR Checks workflow).

The pure classifiers are tested directly; pre-commit / pr-gate run in a throwaway git repo with a fake runner, so
no real import of main, Alembic or pytest happens here.
"""
import importlib.util
import subprocess
import sys
from pathlib import Path

import pytest
import yaml

PROJECT_DIR = Path(__file__).resolve().parents[2]
GUARD_PATH = PROJECT_DIR / "scripts" / "ci" / "guardrails.py"


def _load():
    spec = importlib.util.spec_from_file_location("importflow_guardrails_under_test", GUARD_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


guard = _load()


def _git(repo: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "-c", "user.name=t", "-c", "user.email=t@example.com", "-c", "core.autocrlf=false", *args],
        cwd=repo, check=True, capture_output=True, text=True,
    ).stdout.strip()


class FakeRunner:
    """Stands in for subprocess.run: records calls, answers import / alembic / pytest."""

    def __init__(self, import_fails=False, heads="abc123", pytest_failures=0):
        self.import_fails = import_fails
        self.heads = heads
        self.pytest_failures = pytest_failures
        self.calls = []

    def __call__(self, cmd, **kwargs):
        self.calls.append(cmd)
        env = kwargs.get("env") or {}
        assert env.get("DATABASE_PATH", "").endswith("guard.db"), "children must use the scratch database"
        assert env.get("SECRET_KEY"), "children must get a throwaway SECRET_KEY (no .env write)"
        if cmd[1:3] == ["-m", "pytest"]:
            junit = Path(next(a for a in cmd if a.startswith("--junitxml=")).split("=", 1)[1])
            junit.write_text(
                f'<testsuite tests="3" failures="{self.pytest_failures}" errors="0" skipped="0"/>', encoding="utf-8")
            return subprocess.CompletedProcess(cmd, 1 if self.pytest_failures else 0, "", "")
        code = cmd[2]
        if "get_heads" in code:
            return subprocess.CompletedProcess(cmd, 0, self.heads, "")
        if self.import_fails:
            return subprocess.CompletedProcess(cmd, 1, "", "NameError: name 'Dict' is not defined")
        return subprocess.CompletedProcess(cmd, 0, "", "")


@pytest.fixture
def repo(tmp_path):
    root = tmp_path / "repo"
    (root / "history").mkdir(parents=True)
    (root / "modules" / "suppliers").mkdir(parents=True)
    (root / "tests" / "unit").mkdir(parents=True)
    _git(root, "init", "-q", "-b", "main")
    (root / "history" / "2026-10-05.md").write_text("line 1\nline 2\n", encoding="utf-8")
    (root / "modules" / "suppliers" / "service.py").write_text("x = 1\n", encoding="utf-8")
    (root / "tests" / "unit" / "test_suppliers_service.py").write_text("def test_x():\n    pass\n", encoding="utf-8")
    _git(root, "add", "-A")
    _git(root, "commit", "-q", "-m", "base")
    _git(root, "branch", "base")
    return root


# ─── pure classifiers ─────────────────────────────────────────────────────────

@pytest.mark.parametrize("path", [".env", "deploy/.env.production", "sorour_logistics.db", "x/test.sqlite3",
                                  "sorour_logistics.db-wal", "keys/update.pem"])
def test_blocked_reason_always_blocks_secrets_and_databases(path):
    assert guard.blocked_reason(path, allow_protected=True)


def test_blocked_reason_release_files_need_owner_override():
    assert guard.blocked_reason("version.json", allow_protected=False)
    assert guard.blocked_reason("package_production.py", allow_protected=False)
    assert guard.blocked_reason("version.json", allow_protected=True) is None


@pytest.mark.parametrize("path", [".env.example", "modules/suppliers/service.py", "frontend/lib/main.dart",
                                  "docs/version.json.md"])
def test_blocked_reason_allows_normal_files(path):
    assert guard.blocked_reason(path, allow_protected=False) is None


@pytest.mark.parametrize("old,new,ok", [
    (None, "a\n", True),                      # new file
    ("a\nb\n", "a\nb\nc\n", True),            # append
    ("a\nb", "a\nb\nc\n", True),              # append to a file without a final newline
    ("a\nc\n", "a\nb\nc\n", True),            # merge of two appends lands in the middle
    ("a\nb\n", "a\nB\n", False),              # edited line
    ("a\nb\n", "a\n", False),                 # deleted line
    ("a\n", None, False),                     # deleted file
])
def test_is_append_only(old, new, ok):
    assert guard.is_append_only(old, new) is ok


# Built at runtime so this file itself never trips the pre-commit secret scanner.
FAKE_SECRET_ASSIGNMENT = "SECRET" + '_KEY = "' + "a" * 32 + '"'
FAKE_PRIVATE_KEY_HEADER = "-----BEGIN " + "OPENSSH PRIVATE KEY-----"


def test_secret_hits_catches_keys_but_not_env_lookups_or_allowed_fixtures():
    lines = [
        FAKE_SECRET_ASSIGNMENT,
        FAKE_PRIVATE_KEY_HEADER,
        'secret = os.getenv("SECRET_KEY", "")',
        'password = "short"',
        FAKE_SECRET_ASSIGNMENT + "  # " + guard.ALLOW_SECRET_MARKER,
    ]
    assert len(guard.secret_hits(lines)) == 2


def test_guardrails_files_do_not_trip_their_own_secret_scanner():
    for path in (GUARD_PATH, Path(__file__)):
        assert guard.secret_hits(path.read_text(encoding="utf-8").splitlines()) == []


@pytest.mark.parametrize("path,expected", [
    ("modules/suppliers/service.py", "modules.suppliers.service"),
    ("modules/suppliers/__init__.py", "modules.suppliers"),
    ("utils/money.py", "utils.money"),
    ("main.py", "main"),
    ("seed.py", None),
    ("scripts/ci/guardrails.py", None),
    ("modules/suppliers/README.md", None),
])
def test_backend_module_name(path, expected):
    assert guard.backend_module_name(path) == expected


def test_protected_paths_lists_owner_review_files():
    paths = ["alembic/versions/x.py", "modules/customs_tariff/service.py", "modules/suppliers/service.py",
             "main.py", "frontend/lib/x.dart"]
    assert guard.protected_paths(paths) == ["alembic/versions/x.py", "main.py", "modules/customs_tariff/service.py"]


def test_tests_for_change_picks_module_tests_and_changed_tests(repo):
    (repo / "tests" / "unit" / "test_other.py").write_text("", encoding="utf-8")
    (repo / "tests" / "unit" / "test_supplier_validators.py").write_text("", encoding="utf-8")
    selected, full_reasons = guard.tests_for_change(
        ["modules/suppliers/service.py", "tests/unit/test_other.py", "tests/unit/test_deleted.py"], repo)
    assert full_reasons == []
    assert selected == ["tests/unit/test_other.py", "tests/unit/test_supplier_validators.py",
                        "tests/unit/test_suppliers_service.py"]


@pytest.mark.parametrize("path", ["utils/money.py", "database/database.py", "modules/common/errors.py", "main.py",
                                  "alembic/versions/x.py", "modules/no_tests_here/service.py"])
def test_tests_for_change_flags_full_suite_for_shared_code_or_untested_module(repo, path):
    selected, full_reasons = guard.tests_for_change([path], repo)
    assert selected == [] and len(full_reasons) == 1


def test_guard_tests_exist():
    missing = [t for t in guard.GUARD_TESTS if not (PROJECT_DIR / t).exists()]
    assert missing == []


def test_codeowners_covers_every_protected_prefix():
    codeowners = (PROJECT_DIR / ".github" / "CODEOWNERS").read_text(encoding="utf-8")
    owned = {line.split()[0].lstrip("/") for line in codeowners.splitlines() if line.strip()
             and not line.startswith("#")}
    assert sorted(p for p in guard.PROTECTED_PREFIXES if p not in owned) == []


@pytest.mark.parametrize("name", ["pr_checks.yml", "full_tests.yml"])
def test_pr_workflows_are_safe_for_untrusted_prs(name):
    text = (PROJECT_DIR / ".github" / "workflows" / name).read_text(encoding="utf-8")
    workflow = yaml.safe_load(text)
    triggers = workflow.get("on") or workflow.get(True)
    assert "pull_request_target" not in triggers
    assert workflow["permissions"] == {"contents": "read"}
    assert "secrets." not in text
    for job in workflow["jobs"].values():
        for step in job["steps"]:
            if "actions/checkout" in step.get("uses", ""):
                assert step["with"]["persist-credentials"] is False


def test_required_checks_cannot_be_skipped_or_cancelled_by_a_label():
    """A `labeled` run would cancel the gate (concurrency) and report it as skipped = passing (review 2026-10-05)."""
    workflow = yaml.safe_load((PROJECT_DIR / ".github" / "workflows" / "pr_checks.yml").read_text(encoding="utf-8"))
    triggers = workflow.get("on") or workflow.get(True)
    assert "labeled" not in triggers["pull_request"]["types"]
    assert {job["name"] for job in workflow["jobs"].values()} == {"Backend gate", "Flutter analyze"}
    assert all("if" not in job for job in workflow["jobs"].values())


# ─── pre-commit ───────────────────────────────────────────────────────────────

def test_pre_commit_passes_clean_change(repo):
    (repo / "history" / "2026-10-05.md").write_text("line 1\nline 2\nline 3\n", encoding="utf-8")
    _git(repo, "add", "history/2026-10-05.md")
    runner = FakeRunner()
    assert guard.cmd_pre_commit(repo, run=runner) == 0
    assert runner.calls == []  # no backend file staged -> no import


def test_pre_commit_blocks_history_rewrite_database_and_version(repo, monkeypatch, capsys):
    monkeypatch.delenv(guard.ALLOW_PROTECTED_ENV, raising=False)
    (repo / "history" / "2026-10-05.md").write_text("line 1 edited\nline 2\n", encoding="utf-8")
    (repo / "local.db").write_bytes(b"SQLite")
    (repo / "version.json").write_text("{}", encoding="utf-8")
    _git(repo, "add", "-f", "history/2026-10-05.md", "local.db", "version.json")
    assert guard.cmd_pre_commit(repo, run=FakeRunner()) == 1
    err = capsys.readouterr().err
    assert "history/2026-10-05.md is append-only" in err
    assert "local.db" in err and "version.json" in err


def test_pre_commit_allows_append_to_history_without_final_newline(repo):
    (repo / "history" / "old.md").write_text("entry", encoding="utf-8")
    _git(repo, "add", "history/old.md")
    _git(repo, "commit", "-q", "-m", "old")
    (repo / "history" / "old.md").write_text("entry\nnew entry\n", encoding="utf-8")
    _git(repo, "add", "history/old.md")
    assert guard.cmd_pre_commit(repo, run=FakeRunner()) == 0


def test_pre_commit_blocks_staged_secret(repo, capsys):
    (repo / "modules" / "suppliers" / "config.txt").write_text(FAKE_SECRET_ASSIGNMENT + "\n", encoding="utf-8")
    _git(repo, "add", "modules/suppliers/config.txt")
    assert guard.cmd_pre_commit(repo, run=FakeRunner()) == 1
    assert "possible secret" in capsys.readouterr().err


def test_pre_commit_merge_of_main_ignores_mains_release_and_history_changes(repo, monkeypatch):
    """Merging main (which bumped version.json and appended history) into a task branch, with conflicts."""
    monkeypatch.delenv(guard.ALLOW_PROTECTED_ENV, raising=False)
    notes = repo / "modules" / "suppliers" / "notes.txt"
    history = repo / "history" / "2026-10-05.md"
    (repo / "version.json").write_text('{"version": "1.0.0"}\n', encoding="utf-8")
    _git(repo, "add", "version.json")
    _git(repo, "commit", "-q", "-m", "v1")
    _git(repo, "switch", "-q", "-c", "task")
    notes.write_text("task side\n", encoding="utf-8")
    history.write_text("line 1\nline 2\ntask entry\n", encoding="utf-8")
    _git(repo, "add", "-A")
    _git(repo, "commit", "-q", "-m", "task work")
    _git(repo, "switch", "-q", "main")
    (repo / "version.json").write_text('{"version": "1.1.0"}\n', encoding="utf-8")
    notes.write_text("main side\n", encoding="utf-8")
    history.write_text("line 1\nline 2\nmain entry\n", encoding="utf-8")
    _git(repo, "add", "-A")
    _git(repo, "commit", "-q", "-m", "release 1.1.0")
    _git(repo, "switch", "-q", "task")
    subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@example.com", "merge", "main"],
                   cwd=repo, capture_output=True, text=True)  # conflicts on notes.txt and the history log
    notes.write_text("resolved\n", encoding="utf-8")
    history.write_text("line 1\nline 2\ntask entry\nmain entry\n", encoding="utf-8")
    _git(repo, "add", "-A")
    assert guard.merge_head(repo)
    assert "version.json" not in guard.staged_files(repo)
    assert guard.cmd_pre_commit(repo, run=FakeRunner()) == 0


def test_pre_commit_blocks_backend_module_that_no_longer_imports(repo, capsys):
    (repo / "modules" / "suppliers" / "service.py").write_text("x = 2\n", encoding="utf-8")
    _git(repo, "add", "modules/suppliers/service.py")
    runner = FakeRunner(import_fails=True)
    assert guard.cmd_pre_commit(repo, run=runner) == 1
    assert "modules.suppliers.service" in runner.calls[0][2]
    assert "no longer imports" in capsys.readouterr().err


# ─── pr-gate ──────────────────────────────────────────────────────────────────

def _branch_change(repo: Path):
    _git(repo, "switch", "-q", "-c", "feature")
    (repo / "modules" / "suppliers" / "service.py").write_text("x = 3\n", encoding="utf-8")
    _git(repo, "commit", "-q", "-am", "change")


def test_pr_gate_passes_and_runs_guard_plus_module_tests(repo):
    _branch_change(repo)
    runner = FakeRunner()
    assert guard.cmd_pr_gate(repo, "base", skip_tests=False, run=runner) == 0
    pytest_call = next(c for c in runner.calls if c[1:3] == ["-m", "pytest"])
    assert "tests/unit/test_suppliers_service.py" in pytest_call


@pytest.mark.parametrize("runner_kwargs,message", [
    ({"import_fails": True}, "boot check"),
    ({"heads": "aaa bbb"}, "exactly one head"),
    ({"pytest_failures": 1}, "tests failed"),
])
def test_pr_gate_fails(repo, capsys, runner_kwargs, message):
    _branch_change(repo)
    assert guard.cmd_pr_gate(repo, "base", skip_tests=False, run=FakeRunner(**runner_kwargs)) == 1
    assert message in capsys.readouterr().err


def test_pr_gate_fails_on_history_deletion(repo, capsys):
    _git(repo, "switch", "-q", "-c", "feature")
    (repo / "history" / "2026-10-05.md").write_text("line 1\n", encoding="utf-8")
    _git(repo, "commit", "-q", "-am", "rewrite history")
    assert guard.cmd_pr_gate(repo, "base", skip_tests=True, run=FakeRunner()) == 1
    assert "append-only" in capsys.readouterr().err


def test_pr_gate_stays_fast_but_asks_for_full_suite_on_shared_code(repo, capsys):
    _git(repo, "switch", "-q", "-c", "feature")
    (repo / "utils").mkdir()
    (repo / "utils" / "money.py").write_text("x = 1\n", encoding="utf-8")
    _git(repo, "add", "-A")
    _git(repo, "commit", "-q", "-m", "shared")
    runner = FakeRunner()
    assert guard.cmd_pr_gate(repo, "base", skip_tests=False, run=runner) == 0
    pytest_call = next(c for c in runner.calls if c[1:3] == ["-m", "pytest"])
    assert "tests" not in pytest_call  # never the whole tree inside the fast gate
    out = capsys.readouterr().out
    assert "FULL SUITE NEEDED BEFORE MERGE" in out and "full-tests" in out


def test_pre_push_skips_tags_and_deletions(repo):
    zero = guard.ZERO_SHA
    lines = [f"refs/tags/v1.0.0 {'a' * 40} refs/tags/v1.0.0 {zero}\n",
             f"(delete) {zero} refs/heads/old {'b' * 40}\n"]
    runner = FakeRunner()
    assert guard.cmd_pre_push(repo, iter(lines), run=runner) == 0
    assert runner.calls == []
    assert guard.pushes_needing_gate([f"refs/heads/main {'c' * 40} refs/heads/main {zero}\n"]) == ["refs/heads/main"]


def test_pr_gate_unknown_base_is_exit_2(repo):
    assert guard.main(["pr-gate", "--base", "no-such-ref", "--skip-tests"], project_dir=repo) == 2
