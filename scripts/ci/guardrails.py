"""
Tool-agnostic guardrails for every contributor (human, Antigravity, Claude, Copilot ...).

The Claude Code hooks in .claude/hooks/ only protect Claude sessions. These checks run from plain git hooks
(.githooks/) and from GitHub Actions (.github/workflows/pr_checks.yml), so they hold whatever editor or AI agent
wrote the change.

  python scripts/ci/guardrails.py pre-commit            # fast, staged files only (run by .githooks/pre-commit)
  python scripts/ci/guardrails.py pr-gate [--base REF]  # boot + alembic + guard tests + tests of touched modules
  python scripts/ci/guardrails.py pre-push              # pr-gate, skipped for tag pushes and branch deletions
  python scripts/ci/guardrails.py junit-summary FILE    # print pytest counts from a --junitxml file (CI)

pre-commit blocks:
  - secrets and live data: .env*, *.db / *.sqlite and their WAL files, private keys;
  - Track 2 release files: version.json, package_production.py (owner override: IMPORTFLOW_ALLOW_PROTECTED=1);
  - deleted or rewritten lines in history/*.md (append-only, CORE_RULES section 9);
  - staged backend modules that no longer import (the backend would fail to boot).
  During a merge (MERGE_HEAD exists) only paths whose staged content differs from BOTH parents are checked, so
  merging main into a task branch never trips on main's own release / history changes.

pr-gate fails on:
  - deleted lines in history/*.md since the base;
  - `import main` failing (boot check, scratch DATABASE_PATH: the real sorour_logistics.db is never touched);
  - more than one Alembic head (two branches each added a migration);
  - any failure in GUARD_TESTS (auth on every route, permission / message catalogs, migration rules) or in the
    test files that belong to the modules and tests the change touched. Shared code (database/, utils/,
    modules/common/, main.py, settings.py, alembic/, requirements.txt) or a module without matching tests prints a
    "full suite needed" notice: the owner adds the `full-tests` label (full_tests.yml) before merging. The gate itself
    stays fast (CTO decision 2026-09-26: full suites on demand only).
It also lists the protected paths the change touches: they need the owner's review (.github/CODEOWNERS).

Exit code: 0 = pass, 1 = a check failed, 2 = cannot run (git missing, bad base ref).
"""
from __future__ import annotations

import argparse
import importlib.util
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Callable, Dict, Iterable, List, Optional, Sequence, TextIO, Tuple

PROJECT_DIR = Path(__file__).resolve().parents[2]
COMPANY_REPO = "baraa-solutions/import_flow"
ALLOW_PROTECTED_ENV = "IMPORTFLOW_ALLOW_PROTECTED"

DATABASE_SUFFIXES = (".db", ".db-wal", ".db-shm", ".db-journal", ".sqlite", ".sqlite3")
RELEASE_FILES = ("version.json", "package_production.py")
ALLOW_SECRET_MARKER = "guardrails: allow-secret"
ZERO_SHA = "0" * 40
BACKEND_ROOTS = ("modules", "database", "utils")
BACKEND_FILES = ("main.py", "settings.py")

# Paths whose changes need the owner's review (mirrors .github/CODEOWNERS; listed so the gate output says why).
PROTECTED_PREFIXES = (
    "alembic/", "database/", "modules/auth/", "modules/customs_tariff/", "modules/customs_clearance/",
    "modules/customs_consultation/", "modules/financial_settlement/", "modules/demurrage_detention/",
    "modules/currencies/", "modules/app_update/", "modules/production_sync/", "modules/common/",
    "scripts/release/", "scripts/ci/", "installer/", ".github/", ".githooks/", ".claude/", ".agents/rules/",
    ".agents/workflows/", ".antigravityrules", ".gitattributes",
    "settings.py", "main.py", "version.json", "package_production.py", "requirements.txt", "AGENTS.md",
)

# A change here can break any module: pr-gate asks for the full suite (label `full-tests`) before merge.
SHARED_PREFIXES = ("database/", "utils/", "modules/common/", "alembic/", "main.py", "settings.py", "requirements.txt")

# Always run by pr-gate: cheap tests that catch the mistakes that break the whole app.
GUARD_TESTS = (
    "tests/unit/test_route_auth_coverage.py",
    "tests/unit/test_router_auth_tightening.py",
    "tests/unit/test_auth_privilege_escalation.py",
    "tests/unit/test_permission_codes_in_catalog.py",
    "tests/unit/test_system_messages_catalog.py",
    "tests/unit/test_migration_linter.py",
    "tests/unit/test_migration_system_message_codes.py",
    "tests/unit/test_guardrails.py",
)

SECRET_PATTERNS = (
    re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    re.compile(r"""(?i)\b(secret_key|api_key|password|token)\b\s*[:=]\s*['"][A-Za-z0-9+/_\-]{24,}['"]"""),
)

Runner = Callable[..., "subprocess.CompletedProcess"]


class GuardError(Exception):
    """The guard cannot run (git missing, unknown base ref): exit 2."""


# ─── git ──────────────────────────────────────────────────────────────────────

def _git(project_dir: Path, *args: str) -> str:
    try:
        result = subprocess.run(["git", "-c", "core.quotepath=off", *args], cwd=project_dir, capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=60)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise GuardError(f"git {' '.join(args)} could not run: {exc}") from exc
    if result.returncode != 0:
        raise GuardError(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout


def default_base_ref(project_dir: Path) -> str:
    """`<remote>/main` of the company repo (named `company` on some machines, `origin` on a fresh clone)."""
    for line in _git(project_dir, "remote", "-v").splitlines():
        parts = line.split()
        if len(parts) >= 2 and COMPANY_REPO in parts[1].lower():
            return f"{parts[0]}/main"
    return "origin/main"


def _lines(output: str) -> List[str]:
    return [line for line in output.splitlines() if line]


def merge_head(project_dir: Path) -> Optional[str]:
    try:
        return _git(project_dir, "rev-parse", "-q", "--verify", "MERGE_HEAD").strip() or None
    except GuardError:
        return None


def staged_files(project_dir: Path, filter_: str = "ACMR") -> List[str]:
    """Staged paths; during a merge only those that also differ from MERGE_HEAD (i.e. not main's own changes)."""
    paths = _lines(_git(project_dir, "diff", "--cached", "--name-only", f"--diff-filter={filter_}"))
    incoming = merge_head(project_dir)
    if incoming:
        ours = set(_lines(_git(project_dir, "diff", "--cached", "--name-only", f"--diff-filter={filter_}", incoming)))
        paths = [p for p in paths if p in ours]
    return paths


def changed_files(project_dir: Path, base: str) -> List[str]:
    return [p for p in _git(project_dir, "diff", "--name-only", f"{base}...HEAD").splitlines() if p]


def is_append_only(old: Optional[str], new: Optional[str]) -> bool:
    """True when every old line survives unchanged and in order in new (lines may only be added)."""
    if old is None:
        return True
    if new is None:
        return False
    remaining = iter(new.splitlines())
    return all(any(line == candidate for candidate in remaining) for line in old.splitlines())


def _blob(project_dir: Path, spec: str) -> Optional[str]:
    try:
        return _git(project_dir, "show", spec)
    except GuardError:
        return None


def history_rewrites(project_dir: Path, paths: Iterable[str], old_refs: Sequence[str],
                     new_ref: Optional[str]) -> List[str]:
    """history/*.md paths whose content at new_ref (None = the index) dropped or edited a line of any old ref."""
    offenders = []
    for path in paths:
        if not (path.startswith("history/") and path.endswith(".md")):
            continue
        new = _blob(project_dir, f"{new_ref}:{path}" if new_ref else f":{path}")
        if not all(is_append_only(_blob(project_dir, f"{ref}:{path}"), new) for ref in old_refs):
            offenders.append(path)
    return offenders


# ─── classification ───────────────────────────────────────────────────────────

def blocked_reason(path: str, allow_protected: bool) -> Optional[str]:
    """Why a staged path must not be committed, or None."""
    name = path.rsplit("/", 1)[-1].lower()
    if name == ".env" or (name.startswith(".env.") and name != ".env.example"):
        return "holds secrets (SECRET_KEY); never commit it"
    if name.endswith(DATABASE_SUFFIXES):
        return "is a SQLite database (live or test data); never commit it"
    if name.endswith((".pem", ".key")) or name in ("id_rsa", "id_ed25519"):
        return "looks like a private key; never commit it"
    if path in RELEASE_FILES and not allow_protected:
        return ("is a Track 2 release file (versions and packaging are the owner's job, docs/DEV_WORKFLOW.md); "
                f"owner override: set {ALLOW_PROTECTED_ENV}=1")
    return None


def secret_hits(added_lines: Iterable[str]) -> List[str]:
    hits = []
    for line in added_lines:
        if ALLOW_SECRET_MARKER in line:
            continue
        if any(pattern.search(line) for pattern in SECRET_PATTERNS):
            hits.append(line.strip()[:120])
    return hits


def backend_module_name(path: str) -> Optional[str]:
    """Dotted module name for a backend .py file (`modules/x/service.py` -> `modules.x.service`), else None."""
    if not path.endswith(".py"):
        return None
    parts = path[:-3].split("/")
    if len(parts) == 1:
        return parts[0] if path in BACKEND_FILES else None
    if parts[0] not in BACKEND_ROOTS:
        return None
    if parts[-1] == "__init__":
        parts.pop()
    return ".".join(parts)


def protected_paths(paths: Iterable[str]) -> List[str]:
    return sorted(p for p in paths if p.startswith(PROTECTED_PREFIXES) or p in PROTECTED_PREFIXES)


def tests_for_change(paths: Iterable[str], project_dir: Path) -> Tuple[List[str], List[str]]:
    """(test files to run, reasons the full suite is needed before merge).

    Changed test files + tests whose name mentions a changed module (`users` also matches `test_user_*`). Shared code,
    or a module with no matching test file, cannot be covered by a targeted run: it adds a full-suite reason.
    """
    selected = set()
    module_names = set()
    full_reasons = []
    for path in paths:
        if path.startswith(SHARED_PREFIXES) or path in SHARED_PREFIXES:
            full_reasons.append(f"shared code changed: {path}")
            continue
        parts = path.split("/")
        name = parts[-1]
        if parts[0] == "tests" and name.startswith("test_") and name.endswith(".py"):
            if (project_dir / path).exists():
                selected.add(path)
        elif parts[0] == "modules" and len(parts) >= 3 and path.endswith(".py"):
            module_names.add(parts[1])
    for module in sorted(module_names):
        stems = {module, module[:-1] if module.endswith("s") else module}
        found = {f.relative_to(project_dir).as_posix() for stem in stems
                 for f in (project_dir / "tests").rglob(f"test_*{stem}*.py")}
        if not found:
            full_reasons.append(f"modules/{module} has no matching test file")
        selected |= found
    return sorted(selected), full_reasons


# ─── subprocess checks ────────────────────────────────────────────────────────

def scratch_env(scratch: Path) -> Dict[str, str]:
    """Environment for every child: scratch DB and a throwaway SECRET_KEY, so no real DB or .env is touched."""
    clean_env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    return {
        **clean_env,
        "DATABASE_PATH": str(scratch / "guard.db"),
        # database/database.py reads DATABASE_URL before DATABASE_PATH: an exported real URL must not leak in.
        "DATABASE_URL": f"sqlite:///{(scratch / 'guard.db').as_posix()}",
        "SECRET_KEY": "guardrails-check-secret-key-not-for-production",
        "ALLOW_DEV_AUTH_BYPASS": "false",
        "PYTHONIOENCODING": "utf-8",
    }


def import_modules(project_dir: Path, modules: Sequence[str], scratch: Path, run: Runner) -> Optional[str]:
    """None when every module imports, else the error tail."""
    if not modules:
        return None
    # Exit 3 = the interpreter lacks the project's packages (wrong python, venv not active), not a broken module.
    code = ("import importlib, sys\ntry:\n    import fastapi, sqlalchemy\nexcept ImportError:\n    sys.exit(3)\n"
            + "".join(f"importlib.import_module({m!r})\n" for m in modules))
    result = run([sys.executable, "-c", code], cwd=project_dir, env=scratch_env(scratch),
                 capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300)
    if result.returncode == 3:
        return (f"{sys.executable} does not have the project's packages (fastapi / sqlalchemy). Activate the "
                "project's .venv or run `pip install -r requirements.txt`; the code itself may be fine.")
    if result.returncode != 0:
        return (result.stderr or result.stdout or "")[-3000:]
    return None


def alembic_heads(project_dir: Path, scratch: Path, run: Runner) -> List[str]:
    code = ("from alembic.config import Config; from alembic.script import ScriptDirectory; "
            "print(' '.join(ScriptDirectory.from_config(Config('alembic.ini')).get_heads()))")
    result = run([sys.executable, "-c", code], cwd=project_dir, env=scratch_env(scratch),
                 capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    if result.returncode != 0:
        raise GuardError(f"cannot read Alembic heads: {(result.stderr or '')[-1000:]}")
    return result.stdout.split()


def _parse_junit(path: Path) -> Dict[str, int]:
    release_runner = project_path("scripts", "release", "run_release_tests.py")
    spec = importlib.util.spec_from_file_location("importflow_release_tests_for_guardrails", release_runner)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.parse_junit(path)


def project_path(*parts: str) -> Path:
    return PROJECT_DIR.joinpath(*parts)


def run_pytest(project_dir: Path, test_files: Sequence[str], scratch: Path, run: Runner) -> Dict[str, int]:
    junit = scratch / "guard_junit.xml"
    result = run([sys.executable, "-m", "pytest", *test_files, "-q", "-p", "no:cacheprovider",
                  f"--junitxml={junit}"], cwd=project_dir, env=scratch_env(scratch), timeout=3600)
    counts = _parse_junit(junit) if junit.exists() else {"total": 0, "passed": 0, "failed": 0, "errors": 1,
                                                         "skipped": 0}
    counts["exit_code"] = result.returncode
    return counts


# ─── commands ─────────────────────────────────────────────────────────────────

def cmd_pre_commit(project_dir: Path, run: Runner = subprocess.run) -> int:
    files = staged_files(project_dir)
    if not files and not staged_files(project_dir, "D"):
        return 0
    incoming = merge_head(project_dir)
    allow_protected = os.environ.get(ALLOW_PROTECTED_ENV) == "1"
    problems = [f"{p} {reason}" for p in files if (reason := blocked_reason(p, allow_protected))]

    history_paths = staged_files(project_dir, "MD")
    old_refs = ["HEAD", incoming] if incoming else ["HEAD"]
    problems += [f"{p} is append-only: add new lines, never edit or delete old ones"
                 for p in history_rewrites(project_dir, history_paths, old_refs, None)]

    diff_args = ["diff", "--cached", "-U0", *([incoming] if incoming else [])]
    added = [line[1:] for line in _git(project_dir, *diff_args).splitlines()
             if line.startswith("+") and not line.startswith("+++")]
    problems += [f"possible secret in staged code: {hit} (if it is a test fixture, add the comment "
                 f"`{ALLOW_SECRET_MARKER}` on that line)" for hit in secret_hits(added)]

    modules = [m for p in files if (m := backend_module_name(p))]
    if modules:
        with tempfile.TemporaryDirectory(prefix="importflow_guard_") as temp_dir:
            error = import_modules(project_dir, modules, Path(temp_dir), run)
        if error:
            problems.append(f"backend no longer imports (the app would not boot):\n{error}")

    if problems:
        print("pre-commit guard BLOCKED this commit:", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        print("Fix the files (or unstage them with `git restore --staged <path>`) and commit again.", file=sys.stderr)
        return 1
    return 0


def cmd_pr_gate(project_dir: Path, base: Optional[str], skip_tests: bool, run: Runner = subprocess.run) -> int:
    base = base or default_base_ref(project_dir)
    try:
        _git(project_dir, "rev-parse", "--verify", f"{base}^{{commit}}")
    except GuardError as exc:
        raise GuardError(f"base ref {base!r} not found; run `git fetch` first or pass --base. ({exc})") from exc

    files = changed_files(project_dir, base)
    failures: List[str] = []
    full_reasons: List[str] = []
    print(f"PR gate: {len(files)} file(s) changed vs {base}")

    fork_point = _git(project_dir, "merge-base", base, "HEAD").strip()
    for path in history_rewrites(project_dir, files, [fork_point], "HEAD"):
        failures.append(f"{path}: lines edited or deleted in an append-only history log")

    protected = protected_paths(files)
    if protected:
        print("Protected paths touched (owner review required, .github/CODEOWNERS):")
        for path in protected:
            print(f"  - {path}")

    with tempfile.TemporaryDirectory(prefix="importflow_gate_") as temp_dir:
        scratch = Path(temp_dir)
        boot_error = import_modules(project_dir, ["main"], scratch, run)
        if boot_error:
            failures.append(f"boot check: `import main` failed:\n{boot_error}")
        else:
            print("Boot check: `import main` OK")

        heads = alembic_heads(project_dir, scratch, run)
        if len(heads) != 1:
            failures.append(f"Alembic must have exactly one head, found {len(heads)}: {heads} "
                            "(merge the migration branches: `alembic merge heads`)")
        else:
            print(f"Alembic: single head {heads[0]}")

        if not skip_tests and not boot_error:
            change_tests, full_reasons = tests_for_change(files, project_dir)
            tests = sorted(set(t for t in GUARD_TESTS if (project_dir / t).exists()) | set(change_tests))
            print(f"Running {len(tests)} test file(s): guard tests + tests of touched modules")
            counts = run_pytest(project_dir, tests, scratch, run)
            print("Tests: total={total} passed={passed} failed={failed} errors={errors} skipped={skipped} "
                  "exit={exit_code}".format(**counts))
            if counts["failed"] or counts["errors"] or counts["exit_code"] not in (0, 5):
                failures.append("tests failed (see the pytest output above)")

    if not skip_tests and full_reasons:
        print("\nFULL SUITE NEEDED BEFORE MERGE (targeted tests cannot cover this change):")
        for reason in full_reasons:
            print(f"  - {reason}")
        print("  -> add the label `full-tests` to the PR (Full Tests workflow), or run "
              "`python scripts/release/run_release_tests.py` locally.")

    if failures:
        print("\nPR gate FAILED:", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1
    print("\nPR gate passed.")
    return 0


def pushes_needing_gate(ref_lines: TextIO) -> List[str]:
    """Local refs from git's pre-push stdin that need the gate (branch pushes; not tags, not deletions)."""
    refs = []
    for line in ref_lines:
        parts = line.split()
        if len(parts) != 4:
            continue
        local_ref, local_sha = parts[0], parts[1]
        if local_sha == ZERO_SHA or local_ref.startswith("refs/tags/"):
            continue
        refs.append(local_ref)
    return refs


def cmd_pre_push(project_dir: Path, ref_lines: TextIO, run: Runner = subprocess.run) -> int:
    refs = pushes_needing_gate(ref_lines)
    if not refs:
        return 0
    try:
        head_ref = _git(project_dir, "symbolic-ref", "-q", "HEAD").strip()
    except GuardError:
        head_ref = "detached HEAD"
    if any(ref != head_ref for ref in refs):
        print(f"pre-push: the gate checks the checked-out branch ({head_ref}); pushing {', '.join(refs)}.")
    return cmd_pr_gate(project_dir, None, skip_tests=False, run=run)


def main(argv: Optional[Sequence[str]] = None, project_dir: Path = PROJECT_DIR) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("pre-commit", help="checks on the staged files")
    gate = sub.add_parser("pr-gate", help="boot + alembic + guard tests + tests of touched modules")
    gate.add_argument("--base", help="base ref (default: <company remote>/main)")
    gate.add_argument("--skip-tests", action="store_true", help="only history, boot and alembic checks")
    push = sub.add_parser("pre-push", help="pr-gate for branch pushes (reads git's pre-push stdin)")
    push.add_argument("remote", nargs="*", help="remote name and URL, as git passes them (informational)")
    summary = sub.add_parser("junit-summary", help="print pytest counts from a --junitxml file")
    summary.add_argument("path", type=Path)
    args = parser.parse_args(argv)
    try:
        if args.command == "junit-summary":
            counts = _parse_junit(args.path)
            print("total={total} passed={passed} failed={failed} errors={errors} skipped={skipped}".format(**counts))
            return 0
        if args.command == "pre-commit":
            return cmd_pre_commit(project_dir)
        if args.command == "pre-push":
            return cmd_pre_push(project_dir, sys.stdin)
        return cmd_pr_gate(project_dir, args.base, args.skip_tests)
    except GuardError as exc:
        print(f"guardrails: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
