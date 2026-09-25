"""
scripts/release/run_release_tests.py: the local pre-release test gate (tests run locally only; GitHub only builds).

A fake runner stands in for pytest and flutter, so these tests never run the real suites.
"""
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import pytest

PROJECT_DIR = Path(__file__).resolve().parents[2]
GATE_PATH = PROJECT_DIR / "scripts" / "release" / "run_release_tests.py"


def _load():
    spec = importlib.util.spec_from_file_location("importflow_run_release_tests_under_test", GATE_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


gate = _load()


def _git(repo: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "-c", "user.name=t", "-c", "user.email=t@example.com", *args],
        cwd=repo, check=True, capture_output=True, text=True,
    ).stdout.strip()


@pytest.fixture
def repo(tmp_path):
    root = tmp_path / "repo"
    (root / "frontend").mkdir(parents=True)
    (root / ".claude").mkdir()
    (root / "version.json").write_text('{"version": "2.1.0", "build_number": 210}\n', encoding="utf-8")
    (root / "app.py").write_text("x = 1\n", encoding="utf-8")
    (root / ".claude" / "notes.md").write_text("n\n", encoding="utf-8")
    _git(root, "init", "-q")
    _git(root, "add", "-A")
    _git(root, "commit", "-q", "-m", "release")
    return root


JUNIT_OK = '<testsuites><testsuite tests="10" failures="0" errors="0" skipped="2"/></testsuites>'
JUNIT_FAIL = '<testsuites><testsuite tests="10" failures="1" errors="1" skipped="0"/></testsuites>'


def _flutter_events(passed=3, failed=0, skipped=1):
    lines = [json.dumps({"type": "start"}), "not json at all"]
    lines.append(json.dumps({"type": "testDone", "result": "success", "hidden": True, "skipped": False}))  # loading
    lines += [json.dumps({"type": "testDone", "result": "success", "hidden": False, "skipped": False})] * passed
    lines += [json.dumps({"type": "testDone", "result": "failure", "hidden": False, "skipped": False})] * failed
    lines += [json.dumps({"type": "testDone", "result": "success", "hidden": False, "skipped": True})] * skipped
    return "\n".join(lines) + "\n"


class FakeRunner:
    def __init__(self, junit=JUNIT_OK, backend_exit=0, flutter_out=None, flutter_exit=0):
        self.junit, self.backend_exit = junit, backend_exit
        self.flutter_out = _flutter_events() if flutter_out is None else flutter_out
        self.flutter_exit = flutter_exit
        self.calls = []

    def __call__(self, cmd, cwd=None, env=None, stdout=None, **kwargs):
        self.calls.append({"cmd": list(cmd), "cwd": Path(cwd), "env": env})
        if "pytest" in cmd:
            junit = next(a.split("=", 1)[1] for a in cmd if a.startswith("--junitxml="))
            Path(junit).write_text(self.junit, encoding="utf-8")
            return subprocess.CompletedProcess(cmd, self.backend_exit)
        stdout.write(self.flutter_out)
        return subprocess.CompletedProcess(cmd, self.flutter_exit)


@pytest.fixture(autouse=True)
def _fake_flutter(monkeypatch):
    monkeypatch.setattr(gate.shutil, "which", lambda name: "C:/flutter/bin/flutter.bat" if name == "flutter" else None)


def _result(repo: Path) -> dict:
    head = _git(repo, "rev-parse", "HEAD")
    return json.loads((repo / ".release" / f"tests_{head}.json").read_text(encoding="utf-8"))


def test_green_run_writes_the_result_for_head(repo, capsys):
    runner = FakeRunner()
    assert gate.main([], project_dir=repo, run=runner) == 0

    result = _result(repo)
    assert result["sha"] == _git(repo, "rev-parse", "HEAD") and result["version"] == "2.1.0"
    assert result["backend"] == {"total": 10, "failed": 0, "errors": 0, "skipped": 2, "passed": 8, "exit_code": 0}
    assert result["flutter"] == {"passed": 3, "failed": 0, "skipped": 1, "exit_code": 0}
    assert result["finished_at"].endswith("Z")
    out = capsys.readouterr().out
    assert "Backend: 8 passed" in out and "Flutter: 3 passed" in out


def test_backend_runs_first_then_flutter_never_together(repo):
    runner = FakeRunner()
    gate.main([], project_dir=repo, run=runner)

    assert len(runner.calls) == 2
    backend, flutter = runner.calls
    assert backend["cmd"][1:3] == ["-m", "pytest"] and backend["cwd"] == repo
    assert flutter["cmd"][1:4] == ["test", "-j", "4"] and flutter["cwd"] == repo / "frontend"
    assert "--reporter" in flutter["cmd"]


def test_backend_uses_a_scratch_database(repo):
    runner = FakeRunner()
    gate.main([], project_dir=repo, run=runner)
    db = Path(runner.calls[0]["env"]["DATABASE_PATH"])
    assert db.name == "release_tests.db" and repo not in db.parents


@pytest.mark.parametrize("runner", [
    FakeRunner(junit=JUNIT_FAIL, backend_exit=1),
    FakeRunner(backend_exit=1),
    FakeRunner(flutter_out=_flutter_events(failed=1), flutter_exit=1),
    FakeRunner(flutter_exit=1),
    FakeRunner(flutter_out=_flutter_events(passed=0, skipped=0)),
])
def test_any_failure_exits_non_zero_and_is_recorded(repo, runner):
    assert gate.main([], project_dir=repo, run=runner) == 1
    result = _result(repo)
    assert result["backend"]["exit_code"] != 0 or result["flutter"]["exit_code"] != 0 \
        or result["backend"]["failed"] or result["flutter"]["failed"] or result["flutter"]["passed"] == 0


def test_dirty_tracked_file_refuses_before_running(repo, capsys):
    (repo / "app.py").write_text("x = 2\n", encoding="utf-8")
    runner = FakeRunner()
    assert gate.main([], project_dir=repo, run=runner) == 2
    assert runner.calls == []
    assert "app.py" in capsys.readouterr().err
    assert not (repo / ".release").exists()


def test_staged_change_refuses_too(repo):
    (repo / "app.py").write_text("x = 3\n", encoding="utf-8")
    _git(repo, "add", "app.py")
    assert gate.main([], project_dir=repo, run=FakeRunner()) == 2


def test_claude_dir_and_untracked_files_are_allowed(repo):
    (repo / ".claude" / "notes.md").write_text("changed\n", encoding="utf-8")
    (repo / "scratch.txt").write_text("untracked\n", encoding="utf-8")
    assert gate.main([], project_dir=repo, run=FakeRunner()) == 0


def test_head_change_during_the_run_refuses(repo):
    class Committing(FakeRunner):
        def __call__(self, cmd, **kwargs):
            result = super().__call__(cmd, **kwargs)
            if "pytest" in cmd:
                (repo / "app.py").write_text("x = 9\n", encoding="utf-8")
                _git(repo, "commit", "-qam", "sneaky")
            return result

    assert gate.main([], project_dir=repo, run=Committing()) == 2


def test_missing_flutter_refuses(repo, monkeypatch):
    monkeypatch.setattr(gate.shutil, "which", lambda name: None)
    assert gate.main([], project_dir=repo, run=FakeRunner()) == 2


def test_parse_junit_single_suite_root(tmp_path):
    f = tmp_path / "j.xml"
    f.write_text('<testsuite tests="5" failures="1" errors="0" skipped="1"/>', encoding="utf-8")
    assert gate.parse_junit(f) == {"total": 5, "failed": 1, "errors": 0, "skipped": 1, "passed": 3}


def test_release_dir_is_git_ignored():
    assert ".release/" in (PROJECT_DIR / ".gitignore").read_text(encoding="utf-8").splitlines()
