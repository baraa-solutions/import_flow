"""
Pre-release gate for Sorour Logistics / ImportFlow ERP.

Checks (static + boot) that must pass before cutting a release:
  1. Version is identical in version.json, pubspec.yaml and the Inno Setup script (main.py reads version.json).
  2. version.json installer_url / installer_filename point at the SAME version.
  3. The installer at installer_url is actually published (HTTP HEAD).
  4. version.json carries a sha256 for the installer (the auto-updater has nothing to verify otherwise).
  5. The backend boots: `import main` against a throwaway database.
  6. Bundle guard (plan section 0, R1/R4): the Inno Setup script, the staged bundle
     (dist/Sorour_Logistics_Standalone) and any portable zip in dist/releases contain no database,
     .env, key, backups/updates folder or destructive maintenance script.

Usage:  python .claude/skills/release-check/check_release.py
Exit code 0 = all FAIL-level checks passed.
"""
import importlib.util
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parents[3]
BOOT_TIMEOUT_SECONDS = 180

results: list[tuple[str, str, str]] = []


def record(level: str, check: str, detail: str) -> None:
    results.append((level, check, detail))


def read_text(relative_path: str) -> str:
    return (PROJECT_DIR / relative_path).read_text(encoding="utf-8-sig")


def check_version_consistency(version_info: dict) -> None:
    expected = version_info.get("version", "")
    sources = {
        "frontend/pubspec.yaml": re.findall(r"^version:\s*([\d.]+)", read_text("frontend/pubspec.yaml"), re.M),
        # main.py no longer hard-codes the version: it reads version.json via utils.db_safety.read_installed_version().
        "installer/importflow_setup.iss": re.findall(r'#define MyAppVersion "([\d.]+)"', read_text("installer/importflow_setup.iss")),
    }
    mismatches = []
    for source, found in sources.items():
        values = {v if isinstance(v, str) else next(x for x in v if x) for v in found}
        if not values:
            mismatches.append(f"{source}: no version found")
        elif values != {expected}:
            mismatches.append(f"{source}: {sorted(values)}")
    if mismatches:
        record("FAIL", "Version consistency", f"version.json={expected}, but " + "; ".join(mismatches))
    else:
        record("PASS", "Version consistency", f"{expected} everywhere")


def check_installer_metadata(version_info: dict) -> None:
    version = version_info.get("version", "")
    url = version_info.get("installer_url", "")
    filename = version_info.get("installer_filename", "")
    tag = f"v{version}"
    url_matches = f"/download/{tag}/" in url and url.endswith(f"/{filename}")
    if not url_matches or tag not in filename:
        record("FAIL", "Installer metadata", f"version {version} but installer_url={url!r}, installer_filename={filename!r}")
    else:
        record("PASS", "Installer metadata", f"installer_url and installer_filename both point at {tag}")

    if url:
        check_installer_reachable(url)

    if re.fullmatch(r"[0-9a-f]{64}", str(version_info.get("installer_sha256", ""))):
        record("PASS", "Installer checksum", "installer_sha256 present")
    else:
        record(
            "WARN",
            "Installer checksum",
            "version.json has no installer_sha256 - the auto-updater runs the downloaded installer unverified",
        )


def check_installer_reachable(url: str) -> None:
    """Clients download installer_url from main's version.json; a 404 breaks every in-app update."""
    request = urllib.request.Request(url, method="HEAD", headers={"User-Agent": "importflow-release-check"})
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            record("PASS", "Installer published", f"HTTP {response.status}")
    except urllib.error.HTTPError as error:
        level = "WARN" if error.code == 404 else "FAIL"
        record(
            level,
            "Installer published",
            f"HTTP {error.code} for {url} - expected before CI publishes this version; "
            "if version.json is already on main, every client's in-app update fails",
        )
    except urllib.error.URLError as error:
        record("WARN", "Installer published", f"could not reach GitHub: {error.reason}")


def check_backend_boots() -> None:
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
                cwd=PROJECT_DIR,
                env=env,
                capture_output=True,
                text=True,
                timeout=BOOT_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired:
            record("FAIL", "Backend boot", f"`import main` exceeded {BOOT_TIMEOUT_SECONDS}s")
            return
    if result.returncode == 0:
        record("PASS", "Backend boot", "`import main` succeeded")
    else:
        last_line = (result.stderr.strip().splitlines() or ["(no stderr)"])[-1]
        record("FAIL", "Backend boot", last_line)


def load_bundle_guard():
    guard_path = PROJECT_DIR / "scripts" / "release" / "bundle_guard.py"
    spec = importlib.util.spec_from_file_location("importflow_bundle_guard", guard_path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module  # dataclasses resolve annotations through sys.modules
    spec.loader.exec_module(module)
    return module


def check_bundle_guard() -> None:
    """Production data must never ship: the laptop DB would be overwritten or leaked (plan section 0)."""
    try:
        guard = load_bundle_guard()
    except (OSError, ImportError, SyntaxError) as error:
        record("FAIL", "Bundle guard", f"cannot load scripts/release/bundle_guard.py: {error}")
        return

    iss = PROJECT_DIR / "installer" / "importflow_setup.iss"
    staged = PROJECT_DIR / "dist" / "Sorour_Logistics_Standalone"
    zips = sorted((PROJECT_DIR / "dist" / "releases").glob("Sorour_Logistics_*_Windows_Portable.zip"))
    dirs = [staged] if staged.is_dir() else []
    violations = guard.run(dirs=dirs, zips=zips, iss_files=[iss])
    scanned = ["installer/importflow_setup.iss"] + [p.relative_to(PROJECT_DIR).as_posix() for p in [*dirs, *zips]]

    if violations:
        shown = "; ".join(str(v) for v in violations[:5])
        more = f" (+{len(violations) - 5} more)" if len(violations) > 5 else ""
        record("FAIL", "Bundle guard", f"{len(violations)} forbidden item(s): {shown}{more}")
    elif not dirs:
        record("WARN", "Bundle guard", "installer script clean; no staged bundle in dist/ yet - re-run after packaging")
    else:
        record("PASS", "Bundle guard", "clean: " + ", ".join(scanned))


def main() -> int:
    version_info = json.loads(read_text("version.json"))
    check_version_consistency(version_info)
    check_installer_metadata(version_info)
    check_bundle_guard()
    check_backend_boots()

    for level, check, detail in results:
        print(f"[{level}] {check}: {detail}")
    failed = [r for r in results if r[0] == "FAIL"]
    print(f"\n{len(failed)} failing check(s).")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
