"""
Local pre-release test gate (CTO decision 2026-09-26: tests run locally only; GitHub only builds and publishes).

Runs the full backend pytest suite, THEN the Flutter suite (never both at once: this machine runs out of memory
otherwise), against the committed HEAD, and writes the result to .release/tests_<HEAD sha>.json. The /release-check
skill (check "Local tests") requires that file with 0 failed / 0 errors for the HEAD being released.

  python scripts/release/run_release_tests.py

Rules:
  - Refuses (exit 2) when tracked files outside .claude/ have uncommitted changes: the result must describe HEAD.
    Untracked files are ignored. HEAD must not change while the tests run.
  - Backend: `python -m pytest` with a scratch DATABASE_PATH and --junitxml; counts come from the XML.
  - Flutter: `flutter test -j 4 --reporter json` in frontend/; counts come from the testDone events.
  - Skipped tests are fine (environment-dependent). Any failed test, error or non-zero exit code fails the gate.

Result file: {sha, version, backend {total, passed, failed, errors, skipped, exit_code}, flutter {passed, failed,
skipped, exit_code}, finished_at}.  Exit code: 0 = all green, 1 = a suite failed, 2 = refused / cannot run.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable, Dict, Iterable, List, Optional, Sequence

PROJECT_DIR = Path(__file__).resolve().parents[2]
RESULT_DIR = ".release"
ALLOWED_DIRTY_PREFIXES = (".claude/",)
FLUTTER_CONCURRENCY = "4"

Runner = Callable[..., "subprocess.CompletedProcess"]


class GateError(Exception):
    """The gate cannot run (dirty tree, git missing, ...): exit 2."""


# ─── git ──────────────────────────────────────────────────────────────────────

def _git(project_dir: Path, *args: str) -> str:
    result = subprocess.run(["git", *args], cwd=project_dir, capture_output=True, text=True, timeout=60)
    if result.returncode != 0:
        raise GateError(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout


def head_sha(project_dir: Path) -> str:
    return _git(project_dir, "rev-parse", "HEAD").strip()


def dirty_tracked_files(project_dir: Path) -> List[str]:
    """Tracked files with uncommitted changes (staged or not), except under .claude/."""
    out = _git(project_dir, "status", "--porcelain", "--untracked-files=no")
    dirty = []
    for line in out.splitlines():
        if len(line) < 4:
            continue
        path = line[3:].split(" -> ")[-1].strip().strip('"')
        if not path.startswith(ALLOWED_DIRTY_PREFIXES):
            dirty.append(path)
    return dirty


# ─── result parsing ───────────────────────────────────────────────────────────

def parse_junit(path: Path) -> Dict[str, int]:
    root = ET.parse(path).getroot()
    suites = [root] if root.tag == "testsuite" else list(root.iter("testsuite"))
    counts = {"total": 0, "failed": 0, "errors": 0, "skipped": 0}
    for suite in suites:
        counts["total"] += int(suite.get("tests", 0))
        counts["failed"] += int(suite.get("failures", 0))
        counts["errors"] += int(suite.get("errors", 0))
        counts["skipped"] += int(suite.get("skipped", 0))
    counts["passed"] = counts["total"] - counts["failed"] - counts["errors"] - counts["skipped"]
    return counts


def parse_flutter_json(lines: Iterable[str]) -> Dict[str, int]:
    """Counts from `flutter test --reporter json` testDone events; hidden (loading/setup) entries are ignored."""
    counts = {"passed": 0, "failed": 0, "skipped": 0}
    for line in lines:
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if not isinstance(event, dict) or event.get("type") != "testDone" or event.get("hidden"):
            continue
        if event.get("skipped"):
            counts["skipped"] += 1
        elif event.get("result") == "success":
            counts["passed"] += 1
        else:
            counts["failed"] += 1
    return counts


# ─── suites ───────────────────────────────────────────────────────────────────

def run_backend(project_dir: Path, scratch: Path, run: Runner) -> Dict[str, int]:
    junit = scratch / "backend-junit.xml"
    env = dict(os.environ)
    env["DATABASE_PATH"] = str(scratch / "release_tests.db")  # never the repo DB
    env.setdefault("UPDATE_DATA_DIR", str(scratch / "updates"))
    print("== Backend: python -m pytest (this takes a while) ==", flush=True)
    result = run(
        [sys.executable, "-m", "pytest", "-q", "-W", "ignore", "-p", "no:cacheprovider", f"--junitxml={junit}"],
        cwd=project_dir, env=env,
    )
    if not junit.is_file():
        raise GateError(f"pytest wrote no JUnit report (exit code {result.returncode})")
    counts = parse_junit(junit)
    counts["exit_code"] = result.returncode
    return counts


def run_flutter(project_dir: Path, scratch: Path, run: Runner) -> Dict[str, int]:
    flutter = shutil.which("flutter")
    if not flutter:
        raise GateError("flutter is not on PATH")
    report = scratch / "flutter.jsonl"
    print(f"== Flutter: flutter test -j {FLUTTER_CONCURRENCY} ==", flush=True)
    with open(report, "w", encoding="utf-8") as out:
        result = run(
            [flutter, "test", "-j", FLUTTER_CONCURRENCY, "--reporter", "json"],
            cwd=project_dir / "frontend", stdout=out, stderr=subprocess.STDOUT, text=True,
        )
    counts = parse_flutter_json(report.read_text(encoding="utf-8", errors="replace").splitlines())
    counts["exit_code"] = result.returncode
    return counts


def suite_ok(counts: Dict[str, int], total_key: str) -> bool:
    return (
        counts.get("exit_code") == 0
        and counts.get("failed", 0) == 0
        and counts.get("errors", 0) == 0
        and counts.get(total_key, 0) > 0
    )


# ─── main ─────────────────────────────────────────────────────────────────────

def main(argv: Optional[Sequence[str]] = None, project_dir: Path = PROJECT_DIR, run: Runner = subprocess.run) -> int:
    argparse.ArgumentParser(description="Local pre-release test gate (backend, then Flutter).").parse_args(argv)
    try:
        dirty = dirty_tracked_files(project_dir)
        if dirty:
            shown = ", ".join(dirty[:10]) + (" ..." if len(dirty) > 10 else "")
            raise GateError(f"uncommitted changes to tracked files (commit or stash them first): {shown}")
        sha = head_sha(project_dir)
        version = json.loads((project_dir / "version.json").read_text(encoding="utf-8-sig")).get("version", "")
        print(f"Release tests for {sha[:12]} (version {version})", flush=True)

        with tempfile.TemporaryDirectory(prefix="importflow_release_tests_") as tmp:
            scratch = Path(tmp)
            backend = run_backend(project_dir, scratch, run)
            flutter = run_flutter(project_dir, scratch, run)  # strictly after the backend suite

        if head_sha(project_dir) != sha or dirty_tracked_files(project_dir):
            raise GateError("HEAD or tracked files changed while the tests ran; run the gate again")
    except GateError as error:
        print(f"REFUSED: {error}", file=sys.stderr)
        return 2

    result = {
        "sha": sha,
        "version": version,
        "backend": backend,
        "flutter": flutter,
        "finished_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    }
    out_dir = project_dir / RESULT_DIR
    out_dir.mkdir(exist_ok=True)
    out_file = out_dir / f"tests_{sha}.json"
    out_file.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")

    ok_backend, ok_flutter = suite_ok(backend, "total"), suite_ok(flutter, "passed")
    print()
    print(f"Backend: {backend['passed']} passed, {backend['failed']} failed, {backend['errors']} errors, "
          f"{backend['skipped']} skipped (of {backend['total']}), exit {backend['exit_code']}  "
          f"-> {'OK' if ok_backend else 'FAIL'}")
    print(f"Flutter: {flutter['passed']} passed, {flutter['failed']} failed, {flutter['skipped']} skipped, "
          f"exit {flutter['exit_code']}  -> {'OK' if ok_flutter else 'FAIL'}")
    print(f"Result written to {out_file.relative_to(project_dir).as_posix()}")
    return 0 if ok_backend and ok_flutter else 1


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
