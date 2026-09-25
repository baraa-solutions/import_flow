"""
Pre-release gate for Sorour Logistics / ImportFlow ERP (update system: docs/plans/update-system-plan.md sections 4, 11).

Checks (FAIL blocks the release, WARN / INFO are informational):
  1. Version consistency: version.json == frontend/pubspec.yaml == installer/importflow_setup.iss MyAppVersion
     (main.py reads version.json, nothing to compare there).
  2. Legacy installer_url in version.json: WARN only, the signed-manifest updater ignores it.
  3. Release notes: docs/release_notes/<version>.ar.txt and .en.txt exist (the CI build job requires them).
  4. Git tag v<version>: WARN if it does not exist yet, FAIL if it exists but points at another commit than HEAD.
  5. Signing key: FAIL while modules/app_update/service.py UPDATE_SIGNING_PUBLIC_KEYS holds only the placeholder.
  6. Bundle guard (plan section 0, R1/R4): no database / .env / key / backups / destructive script in the Inno Setup
     script, the staged bundle (dist/Sorour_Logistics_Standalone) or a portable zip in dist/releases.
  7. Published manifest (network, skipped with --offline): the manifest at the update base URL verifies with the
     embedded keys (same code path as the client, scripts/release/verify_manifest.py) and its installer answers
     HEAD 200 with the manifest size. WARN when nothing is published / the host is unreachable.
  8. The backend boots: `import main` against a throwaway database.
  9. Local tests: .release/tests_<HEAD sha>.json (written by scripts/release/run_release_tests.py) exists for HEAD and
     reports 0 failed / 0 errors for both the backend and the Flutter suite. Tests run locally only; CI only builds.

Usage:  python .claude/skills/release-check/check_release.py [--offline]
Exit code 0 = no FAIL-level check.
"""
import argparse
import ast
import importlib.util
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parents[3]
BOOT_TIMEOUT_SECONDS = 180
HTTP_TIMEOUT_SECONDS = 30.0

Report = list  # list of (level, check, detail)


def record(report: Report, level: str, check: str, detail: str) -> None:
    report.append((level, check, detail))


def read_text(project_dir: Path, relative_path: str) -> str:
    return (project_dir / relative_path).read_text(encoding="utf-8-sig")


def load_script(relative_path: str, name: str):
    """Release tooling always comes from this checkout, whatever project_dir is being checked."""
    spec = importlib.util.spec_from_file_location(name, PROJECT_DIR / relative_path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module  # dataclasses resolve annotations through sys.modules
    spec.loader.exec_module(module)
    return module


def load_verify_manifest():
    """scripts/release/verify_manifest.py (puts the project on sys.path, so modules.app_update imports after it)."""
    return sys.modules.get("importflow_verify_manifest") or load_script(
        "scripts/release/verify_manifest.py", "importflow_verify_manifest"
    )


# ─── 1. version consistency ───────────────────────────────────────────────────

def check_version_consistency(report: Report, project_dir: Path, version: str) -> None:
    sources = [
        ("frontend/pubspec.yaml", r"^version:\s*([\d.]+)"),
        ("installer/importflow_setup.iss", r'#define MyAppVersion "([\d.]+)"'),
    ]
    mismatches = []
    for path, pattern in sources:
        try:
            found = set(re.findall(pattern, read_text(project_dir, path), re.M))
        except OSError as error:
            mismatches.append(f"{path}: cannot read ({error.strerror})")
            continue
        if not found:
            mismatches.append(f"{path}: no version found")
        elif found != {version}:
            mismatches.append(f"{path}: {sorted(found)}")
    if mismatches:
        record(report, "FAIL", "Version consistency", f"version.json={version}, but " + "; ".join(mismatches))
    else:
        record(report, "PASS", "Version consistency", f"{version} in version.json, pubspec.yaml and the .iss")


# ─── 2. legacy installer_url ──────────────────────────────────────────────────

def check_legacy_installer_url(report: Report, version_info: dict) -> None:
    if version_info.get("installer_url"):
        record(
            report, "WARN", "Legacy installer_url",
            "version.json still has installer_url (retired GitHub flow); the signed-manifest updater ignores it",
        )
    else:
        record(report, "INFO", "Legacy installer_url", "not present in version.json")


# ─── 3. release notes ─────────────────────────────────────────────────────────

def check_release_notes(report: Report, project_dir: Path, version: str) -> None:
    expected = [f"docs/release_notes/{version}.{lang}.txt" for lang in ("ar", "en")]
    missing = [path for path in expected if not (project_dir / path).is_file()]
    if missing:
        record(report, "FAIL", "Release notes", "missing (CI requires both): " + ", ".join(missing))
    else:
        record(report, "PASS", "Release notes", ", ".join(expected))


# ─── 4. git tag ───────────────────────────────────────────────────────────────

def _git(project_dir: Path, *args: str) -> str:
    """stdout of a git command, '' when it fails (unknown ref, not a repo)."""
    result = subprocess.run(["git", *args], cwd=project_dir, capture_output=True, text=True, timeout=30)
    return result.stdout.strip() if result.returncode == 0 else ""


def check_git_tag(report: Report, project_dir: Path, version: str) -> None:
    tag = f"v{version}"
    try:
        head = _git(project_dir, "rev-parse", "HEAD")
        tagged = _git(project_dir, "rev-parse", "-q", "--verify", f"refs/tags/{tag}^{{commit}}")
    except (OSError, subprocess.SubprocessError) as error:
        record(report, "WARN", "Git tag", f"cannot run git: {error}")
        return
    if not head:
        record(report, "WARN", "Git tag", "cannot resolve HEAD (not a git checkout?)")
    elif not tagged:
        record(report, "WARN", "Git tag", f"{tag} does not exist locally yet - tag HEAD when the release commit is final")
    elif tagged != head:
        record(report, "FAIL", "Git tag", f"{tag} points at {tagged[:12]}, HEAD is {head[:12]}: the build would use the tagged commit")
    else:
        record(report, "PASS", "Git tag", f"{tag} points at HEAD ({head[:12]})")


# ─── 9. local tests ───────────────────────────────────────────────────────────

LOCAL_TESTS_HINT = "run python scripts/release/run_release_tests.py"


def check_local_tests(report: Report, project_dir: Path) -> None:
    name = "Local tests"
    try:
        head = _git(project_dir, "rev-parse", "HEAD")
    except (OSError, subprocess.SubprocessError) as error:
        record(report, "FAIL", name, f"cannot run git: {error}")
        return
    if not head:
        record(report, "FAIL", name, f"cannot resolve HEAD; {LOCAL_TESTS_HINT}")
        return
    result_file = project_dir / ".release" / f"tests_{head}.json"
    if not result_file.is_file():
        record(report, "FAIL", name, f"no result for HEAD {head[:12]}; {LOCAL_TESTS_HINT}")
        return
    try:
        data = json.loads(result_file.read_text(encoding="utf-8"))
        backend, flutter = data["backend"], data["flutter"]
        problems = []
        if data.get("sha") != head:
            problems.append("result belongs to another commit")
        for suite_name, suite, total_key in (("backend", backend, "total"), ("flutter", flutter, "passed")):
            failed, errors = int(suite.get("failed", 0)), int(suite.get("errors", 0))
            if failed or errors or int(suite.get("exit_code", 1)) != 0:
                problems.append(f"{suite_name}: {failed} failed, {errors} errors, exit {suite.get('exit_code')}")
            if int(suite.get(total_key, 0)) <= 0:
                problems.append(f"{suite_name}: no tests ran")
    except (ValueError, KeyError, TypeError, AttributeError) as error:
        record(report, "FAIL", name, f"unreadable {result_file.name}: {error}; {LOCAL_TESTS_HINT}")
        return
    if problems:
        record(report, "FAIL", name, "; ".join(problems) + f"; fix and {LOCAL_TESTS_HINT}")
    else:
        record(report, "PASS", name, (
            f"HEAD {head[:12]}: backend {backend.get('passed')} passed / {backend.get('skipped')} skipped, "
            f"flutter {flutter.get('passed')} passed / {flutter.get('skipped')} skipped ({data.get('finished_at')})"
        ))


# ─── 5. signing key ───────────────────────────────────────────────────────────

def read_signing_keys(project_dir: Path) -> dict:
    """UPDATE_SIGNING_PUBLIC_KEYS literal from modules/app_update/service.py, read without importing the app."""
    tree = ast.parse(read_text(project_dir, "modules/app_update/service.py"))
    for node in tree.body:
        target = node.target if isinstance(node, ast.AnnAssign) else (node.targets[0] if isinstance(node, ast.Assign) else None)
        if isinstance(target, ast.Name) and target.id == "UPDATE_SIGNING_PUBLIC_KEYS" and node.value is not None:
            value = ast.literal_eval(node.value)
            if isinstance(value, dict):
                return value
    raise ValueError("UPDATE_SIGNING_PUBLIC_KEYS dict literal not found")


def check_signing_key(report: Report, project_dir: Path) -> dict:
    """Returns the key map read from project_dir ({} if unreadable); check 7 verifies with the same keys."""
    try:
        keys = read_signing_keys(project_dir)
        verifier_class = load_verify_manifest().ManifestVerifier
    except (OSError, ImportError, SyntaxError, ValueError) as error:
        record(report, "FAIL", "Signing key", f"cannot read UPDATE_SIGNING_PUBLIC_KEYS: {error}")
        return {}
    usable = sorted(key_id for key_id, value in keys.items() if verifier_class({key_id: value}).has_usable_key())
    if usable:
        record(report, "PASS", "Signing key", "public key id(s): " + ", ".join(usable))
    else:
        record(
            report, "FAIL", "Signing key",
            "UPDATE_SIGNING_PUBLIC_KEYS holds only the placeholder - no release can verify on a client",
        )
    return keys


# ─── 6. bundle guard ──────────────────────────────────────────────────────────

def check_bundle_guard(report: Report, project_dir: Path) -> None:
    """Production data must never ship: the laptop DB would be overwritten or leaked (plan section 0)."""
    try:
        guard = load_script("scripts/release/bundle_guard.py", "importflow_bundle_guard")
    except (OSError, ImportError, SyntaxError) as error:
        record(report, "FAIL", "Bundle guard", f"cannot load scripts/release/bundle_guard.py: {error}")
        return

    iss = project_dir / "installer" / "importflow_setup.iss"
    staged = project_dir / "dist" / "Sorour_Logistics_Standalone"
    zips = sorted((project_dir / "dist" / "releases").glob("Sorour_Logistics_*_Windows_Portable.zip"))
    dirs = [staged] if staged.is_dir() else []
    violations = guard.run(dirs=dirs, zips=zips, iss_files=[iss])
    scanned = ["installer/importflow_setup.iss"] + [p.relative_to(project_dir).as_posix() for p in [*dirs, *zips]]

    if violations:
        shown = "; ".join(str(v) for v in violations[:5])
        more = f" (+{len(violations) - 5} more)" if len(violations) > 5 else ""
        record(report, "FAIL", "Bundle guard", f"{len(violations)} forbidden item(s): {shown}{more}")
    elif not dirs:
        record(report, "WARN", "Bundle guard", "installer script clean; no staged bundle in dist/ yet - re-run after packaging")
    else:
        record(report, "PASS", "Bundle guard", "clean: " + ", ".join(scanned))


# ─── 7. published manifest ────────────────────────────────────────────────────

def check_published_manifest(
    report: Report, local_version: str, public_keys: dict, transport=None, base_url=None
) -> None:
    """Same logic as `verify_manifest.py --url <base_url> --head-only`, graded for the release gate.

    public_keys = the map check 5 read from the checked repo, so both checks judge the same keys.
    """
    name = "Published manifest"
    try:
        vm = load_verify_manifest()
        # importable once verify_manifest put the project on sys.path
        from modules.app_update.validators import DEFAULT_UPDATE_BASE_URL, parse_version
    except (OSError, ImportError, SyntaxError) as error:
        record(report, "FAIL", name, f"cannot load scripts/release/verify_manifest.py: {error}")
        return
    base_url = base_url or DEFAULT_UPDATE_BASE_URL
    if not vm.ManifestVerifier(public_keys).has_usable_key():
        record(report, "WARN", name, "skipped: no usable signing key to verify with (see Signing key)")
        return

    import httpx

    with httpx.Client(
        transport=transport, follow_redirects=False, timeout=httpx.Timeout(HTTP_TIMEOUT_SECONDS),
        headers={"User-Agent": "ImportFlow-ReleaseCheck/1"},
    ) as client:
        try:
            raw = vm.fetch_manifest(client, base_url)
        except vm.VerificationError as error:
            record(report, "WARN", name, f"none published yet or not readable at {base_url}: {error}")
            return
        except httpx.HTTPError as error:
            record(report, "WARN", name, f"update host unreachable: {type(error).__name__}: {error}")
            return

        try:
            manifest = vm.verify_manifest_bytes(raw, public_keys)
        except vm.VerificationError as error:
            record(report, "FAIL", name, f"published manifest does not verify - clients reject it: {error}")
            return
        try:
            vm.ensure_not_expired(manifest)
        except vm.VerificationError as error:
            record(report, "FAIL", name, f"live {manifest.version}: {error}")
            return
        try:
            live_is_newer = parse_version(manifest.version) > parse_version(local_version)
        except ValueError as error:
            record(report, "FAIL", name, f"cannot compare versions: {error}")
            return
        if live_is_newer:
            record(
                report, "FAIL", name,
                f"live version {manifest.version} is newer than local {local_version}: clients would never take this release",
            )
            return

        try:
            vm.verify_remote_installer(client, base_url, manifest, head_only=True)
        except vm.VerificationError as error:
            record(report, "FAIL", name, f"live {manifest.version} verifies, but its installer does not: {error}")
            return
        except httpx.HTTPError as error:
            record(report, "WARN", name, f"live {manifest.version} verifies; installer HEAD failed: {type(error).__name__}")
            return

    record(
        report, "PASS", name,
        f"live version {manifest.version} (key {manifest.key_id}, expires {manifest.expires_at.date().isoformat()}), "
        f"installer HEAD 200 with the manifest size; local version {local_version}",
    )


# ─── 8. backend boot ──────────────────────────────────────────────────────────

def check_backend_boots(report: Report, project_dir: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="importflow_release_") as temp_dir:
        env = {
            **os.environ,
            "SECRET_KEY": "release-check-secret-key-not-for-production-use",
            "ALLOW_DEV_AUTH_BYPASS": "false",
            "DATABASE_PATH": str(Path(temp_dir) / "release_check.db"),
        }
        try:
            result = subprocess.run(
                [sys.executable, "-c", "import main"],
                cwd=project_dir,
                env=env,
                capture_output=True,
                text=True,
                timeout=BOOT_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired:
            record(report, "FAIL", "Backend boot", f"`import main` exceeded {BOOT_TIMEOUT_SECONDS}s")
            return
    if result.returncode == 0:
        record(report, "PASS", "Backend boot", "`import main` succeeded")
    else:
        last_line = (result.stderr.strip().splitlines() or ["(no stderr)"])[-1]
        record(report, "FAIL", "Backend boot", last_line)


# ─── main ─────────────────────────────────────────────────────────────────────

def run_checks(project_dir: Path, offline: bool = False, transport=None) -> Report:
    report: Report = []
    version_info = json.loads(read_text(project_dir, "version.json"))
    version = str(version_info.get("version", ""))
    check_version_consistency(report, project_dir, version)
    check_legacy_installer_url(report, version_info)
    check_release_notes(report, project_dir, version)
    check_git_tag(report, project_dir, version)
    check_local_tests(report, project_dir)
    public_keys = check_signing_key(report, project_dir)
    check_bundle_guard(report, project_dir)
    if offline:
        record(report, "INFO", "Published manifest", "skipped (--offline)")
    else:
        check_published_manifest(report, version, public_keys, transport=transport)
    check_backend_boots(report, project_dir)
    return report


def main(argv=None, project_dir: Path = PROJECT_DIR, transport=None) -> int:
    parser = argparse.ArgumentParser(description="ImportFlow pre-release gate")
    parser.add_argument("--offline", action="store_true", help="skip the published-manifest network check")
    args = parser.parse_args(argv)

    report = run_checks(project_dir, offline=args.offline, transport=transport)
    for level, check, detail in report:
        print(f"[{level}] {check}: {detail}")
    failed = [r for r in report if r[0] == "FAIL"]
    print(f"\n{len(failed)} failing check(s).")
    return 1 if failed else 0


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
