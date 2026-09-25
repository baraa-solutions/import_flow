"""
Tests for the /release-check gate (.claude/skills/release-check/check_release.py).

Every check runs against a throw-away repo in tmp_path. The published-manifest check gets an httpx.MockTransport and a
manifest signed by scripts/release/build_manifest.py with a test key: no real network, never the real signing key.
"""
import importlib.util
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import httpx
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

import modules.app_update.service as app_update_service

PROJECT_DIR = Path(__file__).resolve().parents[2]
BASE_URL = "https://kamal-sroor.online/importflow/updates/"
VERSION = "2.1.0"
PLACEHOLDER = "REPLACE_WITH_REAL_ED25519_PUBLIC_KEY_BASE64"


def _load(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


check_release = _load(PROJECT_DIR / ".claude" / "skills" / "release-check" / "check_release.py", "release_check_under_test")
build_manifest = _load(PROJECT_DIR / "scripts" / "release" / "build_manifest.py", "release_check_build_manifest")


def _levels(report, check):
    return [level for level, name, _ in report if name == check]


def _detail(report, check):
    return next(detail for _, name, detail in report if name == check)


def _git(repo: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True, text=True).stdout.strip()


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _service_source(keys: dict) -> str:
    return f"from typing import Dict\n\nUPDATE_SIGNING_PUBLIC_KEYS: Dict[str, str] = {keys!r}\n"


def _pub(key: Ed25519PrivateKey) -> str:
    return build_manifest.public_key_b64(key)


@pytest.fixture
def signing_key():
    return Ed25519PrivateKey.generate()


@pytest.fixture
def repo(tmp_path, signing_key):
    """A release-ready repo: versions agree, notes present, real key, commit tagged v<version>."""
    root = tmp_path / "repo"
    _write(root / "version.json", f'{{"version": "{VERSION}", "build_number": 210}}\n')
    _write(root / "frontend" / "pubspec.yaml", f"name: frontend\nversion: {VERSION}+210\n")
    _write(root / "installer" / "importflow_setup.iss", f'#define MyAppName "Sorour Logistics"\n#define MyAppVersion "{VERSION}"\n')
    _write(root / "docs" / "release_notes" / f"{VERSION}.ar.txt", "تحسينات\n")
    _write(root / "docs" / "release_notes" / f"{VERSION}.en.txt", "Improvements\n")
    _write(root / "modules" / "app_update" / "service.py", _service_source({"k2026a": _pub(signing_key)}))
    _git(root, "init", "-q")
    _git(root, "-c", "user.name=t", "-c", "user.email=t@example.com", "add", "-A")
    _git(root, "-c", "user.name=t", "-c", "user.email=t@example.com", "commit", "-q", "-m", "release")
    _git(root, "tag", f"v{VERSION}")
    return root


@pytest.fixture
def no_boot(monkeypatch):
    monkeypatch.setattr(
        check_release, "check_backend_boots", lambda report, project_dir: check_release.record(report, "PASS", "Backend boot", "stub")
    )


# ─── version consistency ──────────────────────────────────────────────────────

def test_versions_agree_pass(repo):
    report = []
    check_release.check_version_consistency(report, repo, VERSION)
    assert _levels(report, "Version consistency") == ["PASS"]


def test_version_mismatch_fails(repo):
    _write(repo / "frontend" / "pubspec.yaml", "name: frontend\nversion: 2.0.9+209\n")
    report = []
    check_release.check_version_consistency(report, repo, VERSION)
    assert _levels(report, "Version consistency") == ["FAIL"]
    assert "pubspec.yaml: ['2.0.9']" in _detail(report, "Version consistency")


def test_iss_without_version_fails(repo):
    _write(repo / "installer" / "importflow_setup.iss", '#define MyAppName "Sorour Logistics"\n')
    report = []
    check_release.check_version_consistency(report, repo, VERSION)
    assert "importflow_setup.iss: no version found" in _detail(report, "Version consistency")


# ─── legacy installer_url ─────────────────────────────────────────────────────

def test_legacy_installer_url_is_warn_only():
    report = []
    check_release.check_legacy_installer_url(report, {"installer_url": "https://github.com/x/releases/download/v1/x.exe"})
    check_release.check_legacy_installer_url(report, {"version": VERSION})
    assert _levels(report, "Legacy installer_url") == ["WARN", "INFO"]


# ─── release notes ────────────────────────────────────────────────────────────

def test_release_notes_present_pass(repo):
    report = []
    check_release.check_release_notes(report, repo, VERSION)
    assert _levels(report, "Release notes") == ["PASS"]


def test_missing_release_notes_fail(repo):
    (repo / "docs" / "release_notes" / f"{VERSION}.en.txt").unlink()
    report = []
    check_release.check_release_notes(report, repo, VERSION)
    assert _levels(report, "Release notes") == ["FAIL"]
    assert f"{VERSION}.en.txt" in _detail(report, "Release notes")
    assert f"{VERSION}.ar.txt" not in _detail(report, "Release notes")


# ─── git tag ──────────────────────────────────────────────────────────────────

def test_tag_at_head_passes(repo):
    report = []
    check_release.check_git_tag(report, repo, VERSION)
    assert _levels(report, "Git tag") == ["PASS"]


def test_missing_tag_warns(repo):
    _git(repo, "tag", "-d", f"v{VERSION}")
    report = []
    check_release.check_git_tag(report, repo, VERSION)
    assert _levels(report, "Git tag") == ["WARN"]


def test_tag_on_another_commit_fails(repo):
    _write(repo / "later.txt", "x\n")
    _git(repo, "-c", "user.name=t", "-c", "user.email=t@example.com", "add", "-A")
    _git(repo, "-c", "user.name=t", "-c", "user.email=t@example.com", "commit", "-q", "-m", "later")
    report = []
    check_release.check_git_tag(report, repo, VERSION)
    assert _levels(report, "Git tag") == ["FAIL"]


def test_annotated_tag_at_head_passes(repo):
    _git(repo, "tag", "-d", f"v{VERSION}")
    _git(repo, "-c", "user.name=t", "-c", "user.email=t@example.com", "tag", "-a", f"v{VERSION}", "-m", "release")
    report = []
    check_release.check_git_tag(report, repo, VERSION)
    assert _levels(report, "Git tag") == ["PASS"]


def test_not_a_git_checkout_warns(tmp_path):
    report = []
    check_release.check_git_tag(report, tmp_path, VERSION)
    assert _levels(report, "Git tag") == ["WARN"]


# ─── signing key ──────────────────────────────────────────────────────────────

def test_real_key_passes_with_key_ids(repo, signing_key):
    _write(repo / "modules" / "app_update" / "service.py",
           _service_source({"k2026a": _pub(signing_key), "k2027a": PLACEHOLDER}))
    report = []
    check_release.check_signing_key(report, repo)
    assert _levels(report, "Signing key") == ["PASS"]
    assert _detail(report, "Signing key").endswith("k2026a")


def test_placeholder_only_fails(repo):
    _write(repo / "modules" / "app_update" / "service.py", _service_source({"k2026a": PLACEHOLDER}))
    report = []
    check_release.check_signing_key(report, repo)
    assert _levels(report, "Signing key") == ["FAIL"]


def test_missing_key_map_fails(repo):
    _write(repo / "modules" / "app_update" / "service.py", "X = 1\n")
    report = []
    check_release.check_signing_key(report, repo)
    assert _levels(report, "Signing key") == ["FAIL"]


def test_real_repo_key_map_is_readable():
    keys = check_release.read_signing_keys(PROJECT_DIR)
    assert keys == app_update_service.UPDATE_SIGNING_PUBLIC_KEYS


# ─── bundle guard ─────────────────────────────────────────────────────────────

def test_bundle_guard_warns_when_nothing_staged(repo):
    report = []
    check_release.check_bundle_guard(report, repo)
    assert _levels(report, "Bundle guard") == ["WARN"]


def test_bundle_guard_fails_on_database_in_staged_bundle(repo):
    _write(repo / "dist" / "Sorour_Logistics_Standalone" / "sorour_logistics.db", "x")
    report = []
    check_release.check_bundle_guard(report, repo)
    assert _levels(report, "Bundle guard") == ["FAIL"]


# ─── published manifest ───────────────────────────────────────────────────────

def _signed_manifest(tmp_path: Path, key: Ed25519PrivateKey, version: str = VERSION, extra=()) -> tuple:
    work = tmp_path / f"build_{version}"
    installer = work / f"Sorour_Logistics_Setup_v{version}.exe"
    _write(work / "notes.ar.txt", "تحسينات\n")
    _write(work / "notes.en.txt", "Improvements\n")
    installer.write_bytes(b"MZ" + b"\x00" * 4096)
    key_file = work / "signing.pem"
    key_file.write_bytes(key.private_bytes(
        serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()
    ))
    out = work / "manifest.json"
    assert build_manifest.main([
        "--installer", str(installer), "--version", version, "--build", "210",
        "--notes-ar", str(work / "notes.ar.txt"), "--notes-en", str(work / "notes.en.txt"),
        "--sign", "--key-file", str(key_file), "--key-id", "k2026a", "--out", str(out), *extra,
    ]) == 0
    return out.read_bytes(), installer.stat().st_size


def _server(manifest: bytes, version: str, size: int, *, manifest_status: int = 200, log=None):
    installer_path = f"/importflow/updates/releases/{version}/Sorour_Logistics_Setup_v{version}.exe"

    def handler(request: httpx.Request) -> httpx.Response:
        if log is not None:
            log.append(request.method)
        if request.url.path == "/importflow/updates/manifest.json":
            return httpx.Response(manifest_status, content=manifest if manifest_status == 200 else b"")
        if request.url.path == installer_path and request.method == "HEAD":
            return httpx.Response(200, headers={"content-length": str(size)})
        return httpx.Response(404)

    return httpx.MockTransport(handler)


@pytest.fixture
def keys(signing_key):
    return {"k2026a": _pub(signing_key)}


def test_published_manifest_same_version_passes(tmp_path, signing_key, keys):
    raw, size = _signed_manifest(tmp_path, signing_key)
    log = []
    report = []
    check_release.check_published_manifest(report, VERSION, keys, transport=_server(raw, VERSION, size, log=log))
    assert _levels(report, "Published manifest") == ["PASS"]
    assert f"live version {VERSION}" in _detail(report, "Published manifest")
    assert log == ["GET", "HEAD"], "head-only: the installer must not be downloaded"


def test_published_older_version_passes(tmp_path, signing_key, keys):
    raw, size = _signed_manifest(tmp_path, signing_key, version="2.0.9")
    report = []
    check_release.check_published_manifest(report, VERSION, keys, transport=_server(raw, "2.0.9", size))
    assert _levels(report, "Published manifest") == ["PASS"]
    assert "live version 2.0.9" in _detail(report, "Published manifest")


def test_nothing_published_warns(tmp_path, signing_key, keys):
    report = []
    check_release.check_published_manifest(report, VERSION, keys, transport=_server(b"", VERSION, 0, manifest_status=404))
    assert _levels(report, "Published manifest") == ["WARN"]
    assert "HTTP 404" in _detail(report, "Published manifest")


def test_unreachable_host_warns(keys):
    def handler(request):
        raise httpx.ConnectError("no route", request=request)

    report = []
    check_release.check_published_manifest(report, VERSION, keys, transport=httpx.MockTransport(handler))
    assert _levels(report, "Published manifest") == ["WARN"]


def test_bad_signature_fails(tmp_path, signing_key, keys):
    raw, size = _signed_manifest(tmp_path, Ed25519PrivateKey.generate())  # signed with a key the client does not trust
    report = []
    check_release.check_published_manifest(report, VERSION, keys, transport=_server(raw, VERSION, size))
    assert _levels(report, "Published manifest") == ["FAIL"]
    assert "does not verify" in _detail(report, "Published manifest")


def test_live_version_newer_than_local_fails(tmp_path, signing_key, keys):
    raw, size = _signed_manifest(tmp_path, signing_key, version="2.2.0")
    report = []
    check_release.check_published_manifest(report, VERSION, keys, transport=_server(raw, "2.2.0", size))
    assert _levels(report, "Published manifest") == ["FAIL"]
    assert "newer than local" in _detail(report, "Published manifest")


def test_installer_size_mismatch_fails(tmp_path, signing_key, keys):
    raw, size = _signed_manifest(tmp_path, signing_key)
    report = []
    check_release.check_published_manifest(report, VERSION, keys, transport=_server(raw, VERSION, size + 1))
    assert _levels(report, "Published manifest") == ["FAIL"]
    assert "Content-Length" in _detail(report, "Published manifest")


def test_placeholder_key_skips_network():
    def handler(request):
        raise AssertionError("no request expected without a usable key")

    report = []
    check_release.check_published_manifest(
        report, VERSION, {"k2026a": PLACEHOLDER}, transport=httpx.MockTransport(handler)
    )
    assert _levels(report, "Published manifest") == ["WARN"]


def test_expired_manifest_fails(tmp_path, signing_key, keys, monkeypatch):
    raw, size = _signed_manifest(tmp_path, signing_key)
    vm = check_release.load_verify_manifest()

    class _FutureClock(datetime):
        @classmethod
        def now(cls, tz=None):
            return datetime(2999, 1, 1, tzinfo=timezone.utc)

    monkeypatch.setattr(vm, "datetime", _FutureClock)  # clock of the shared ensure_not_expired helper
    report = []
    check_release.check_published_manifest(report, VERSION, keys, transport=_server(raw, VERSION, size))
    assert _levels(report, "Published manifest") == ["FAIL"]
    assert "expired" in _detail(report, "Published manifest")


def test_checks_5_and_7_judge_the_repo_keys(repo, tmp_path, signing_key, no_boot, capsys):
    raw, size = _signed_manifest(tmp_path, signing_key)
    assert check_release.main([], project_dir=repo, transport=_server(raw, VERSION, size)) == 0
    _write(repo / "modules" / "app_update" / "service.py", _service_source({"k2026a": PLACEHOLDER}))
    assert check_release.main([], project_dir=repo, transport=_server(raw, VERSION, size)) == 1
    out = capsys.readouterr().out
    assert "[FAIL] Signing key" in out and "[WARN] Published manifest: skipped" in out


# ─── backend boot + main ──────────────────────────────────────────────────────

def test_backend_boot_failure_is_reported(monkeypatch, tmp_path):
    def fake_run(*args, **kwargs):
        return subprocess.CompletedProcess(args, 1, stdout="", stderr="Traceback\nNameError: name 'Dict' is not defined\n")

    monkeypatch.setattr(check_release.subprocess, "run", fake_run)
    report = []
    check_release.check_backend_boots(report, tmp_path)
    assert report == [("FAIL", "Backend boot", "NameError: name 'Dict' is not defined")]


def test_main_offline_ready_repo_exits_zero(repo, no_boot, capsys):
    def handler(request):
        raise AssertionError("--offline must not touch the network")

    code = check_release.main(["--offline"], project_dir=repo, transport=httpx.MockTransport(handler))
    out = capsys.readouterr().out
    assert code == 0, out
    assert "[INFO] Published manifest: skipped (--offline)" in out
    assert "[PASS] Git tag" in out and "[WARN] Bundle guard" in out
    assert "0 failing check(s)." in out


def test_main_fails_on_placeholder_key_and_missing_notes(repo, no_boot, capsys):
    _write(repo / "modules" / "app_update" / "service.py", _service_source({"k2026a": PLACEHOLDER}))
    (repo / "docs" / "release_notes" / f"{VERSION}.ar.txt").unlink()
    code = check_release.main(["--offline"], project_dir=repo)
    out = capsys.readouterr().out
    assert code == 1
    assert "[FAIL] Signing key" in out and "[FAIL] Release notes" in out
    assert "2 failing check(s)." in out


def test_main_online_uses_the_published_manifest(repo, tmp_path, signing_key, no_boot, capsys):
    raw, size = _signed_manifest(tmp_path, signing_key)
    code = check_release.main([], project_dir=repo, transport=_server(raw, VERSION, size))
    out = capsys.readouterr().out
    assert code == 0, out
    assert "[PASS] Published manifest: live version 2.1.0" in out


def test_no_retired_github_checks_remain():
    source = (PROJECT_DIR / ".claude" / "skills" / "release-check" / "check_release.py").read_text(encoding="utf-8")
    for retired in ("installer_filename", "installer_sha256", "github.com", "urllib", "kamal-sroor.online", "base64"):
        assert retired not in source
