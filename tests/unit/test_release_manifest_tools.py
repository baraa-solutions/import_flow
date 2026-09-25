"""
Release tooling for the signed update manifest (docs/plans/update-system-plan.md sections 4.2-4.4, 9, 11).

- scripts/release/build_manifest.py builds the payload; scripts/release/sign_manifest.py (stand-alone, stdlib +
  cryptography only) signs it and adds expires_at / previous; scripts/release/verify_manifest.py verifies with the
  same ManifestVerifier as the app. Sign -> verify accepts; any byte change, wrong key or installer mismatch rejects.
- The private key never reaches stdout/stderr.
- .github/workflows/build_and_release.yml builds and uploads `update-payload` only (no publish secrets);
  .github/workflows/publish_update.yml is the manual "Publish update" button: dispatch-only, environment
  `production-updates`, ref/tag guard first, manifest.json uploaded only after the public installer check.
"""
import ast
import base64
import hashlib
import importlib.util
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import httpx
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

PROJECT_DIR = Path(__file__).resolve().parents[2]
BUILD_PATH = PROJECT_DIR / "scripts" / "release" / "build_manifest.py"
SIGN_PATH = PROJECT_DIR / "scripts" / "release" / "sign_manifest.py"
SIGN_REQUIREMENTS = PROJECT_DIR / "scripts" / "release" / "requirements-sign.txt"
VERIFY_PATH = PROJECT_DIR / "scripts" / "release" / "verify_manifest.py"
WORKFLOW_PATH = PROJECT_DIR / ".github" / "workflows" / "build_and_release.yml"
PUBLISH_WORKFLOW_PATH = PROJECT_DIR / ".github" / "workflows" / "publish_update.yml"
HTACCESS_PATH = PROJECT_DIR / "docs" / "plans" / "hostinger_htaccess.txt"

BASE_URL = "https://kamal-sroor.online/importflow/updates/"
VERSION = "2.1.0"
INSTALLER_NAME = f"Sorour_Logistics_Setup_v{VERSION}.exe"
KEY_ID = "k2026a"


def _load(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


build_manifest = _load(BUILD_PATH, "importflow_build_manifest_under_test")
sign_manifest = _load(SIGN_PATH, "importflow_sign_manifest_under_test")
verify_manifest = _load(VERIFY_PATH, "importflow_verify_manifest_under_test")


# ─── fixtures ─────────────────────────────────────────────────────────────────

def _pem(key: Ed25519PrivateKey) -> str:
    return key.private_bytes(
        serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()
    ).decode("ascii")


def _seed_b64(key: Ed25519PrivateKey) -> str:
    raw = key.private_bytes(serialization.Encoding.Raw, serialization.PrivateFormat.Raw, serialization.NoEncryption())
    return base64.b64encode(raw).decode("ascii")


def _pub(key: Ed25519PrivateKey) -> str:
    return build_manifest.public_key_b64(key)


def _pem_body(pem: str) -> str:
    return "".join(line for line in pem.splitlines() if not line.startswith("-----"))


@pytest.fixture
def signing_key():
    return Ed25519PrivateKey.generate()


@pytest.fixture
def key_file(tmp_path, signing_key):
    path = tmp_path / "signing.pem"
    path.write_text(_pem(signing_key), encoding="ascii")
    return path


@pytest.fixture
def installer(tmp_path):
    path = tmp_path / "dist" / INSTALLER_NAME
    path.parent.mkdir()
    path.write_bytes(b"MZ" + os.urandom(8192))
    return path


@pytest.fixture
def notes(tmp_path):
    ar = tmp_path / "notes.ar.txt"
    en = tmp_path / "notes.en.txt"
    ar.write_text("# comment\n- تحسين سرعة التقارير\n\n• إصلاح حفظ الملفات\n", encoding="utf-8")
    en.write_text("* Faster reports\nFixed file saving\n", encoding="utf-8")
    return ar, en


@pytest.fixture(autouse=True)
def _no_env_key(monkeypatch):
    monkeypatch.delenv(build_manifest.KEY_ENV_VAR, raising=False)


def _build_signed(tmp_path, installer, key_file, notes, *extra) -> Path:
    out = tmp_path / "manifest.json"
    code = build_manifest.main([
        "--installer", str(installer), "--version", VERSION, "--build", "210",
        "--notes-ar", str(notes[0]), "--notes-en", str(notes[1]),
        "--sign", "--key-file", str(key_file), "--key-id", KEY_ID, "--out", str(out), *extra,
    ])
    assert code == 0
    return out


def _verify(manifest: Path, signing_key, *extra, transport=None) -> int:
    return verify_manifest.main(
        ["--manifest", str(manifest), "--public-key", f"{KEY_ID}={_pub(signing_key)}", *extra], transport=transport
    )


# ─── build + sign ─────────────────────────────────────────────────────────────

def test_sign_then_verify_accepts(tmp_path, installer, key_file, notes, signing_key):
    manifest = _build_signed(tmp_path, installer, key_file, notes, "--min-supported-version", "2.0.0",
                             "--db-schema-revision", "d3e4f5a6b7c8", "--released-at", "2026-10-01T10:00:00Z")

    assert _verify(manifest, signing_key, "--installer", str(installer)) == 0

    envelope = json.loads(manifest.read_text(encoding="utf-8"))
    assert envelope["key_id"] == KEY_ID
    payload = json.loads(envelope["signed"])
    assert payload["version"] == VERSION and payload["build_number"] == 210
    assert payload["installer"] == {
        "path": f"releases/{VERSION}/{INSTALLER_NAME}",
        "size_bytes": installer.stat().st_size,
        "sha256": hashlib.sha256(installer.read_bytes()).hexdigest(),
    }
    assert payload["release_notes"] == {
        "ar": ["تحسين سرعة التقارير", "إصلاح حفظ الملفات"],
        "en": ["Faster reports", "Fixed file saving"],
    }
    assert payload["min_supported_version"] == "2.0.0"
    assert payload["mandatory"] is False
    assert payload["db_schema_revision"] == "d3e4f5a6b7c8"
    assert payload["released_at"] == "2026-10-01T10:00:00Z"


def test_verified_by_the_app_service_verifier(tmp_path, installer, key_file, notes, signing_key):
    from modules.app_update.service import ManifestVerifier

    manifest = _build_signed(tmp_path, installer, key_file, notes, "--mandatory")
    verified = ManifestVerifier({KEY_ID: _pub(signing_key)}).verify(manifest.read_bytes())

    assert verified.version == VERSION
    assert verified.mandatory is True
    assert verified.installer.filename == INSTALLER_NAME


def test_one_byte_change_in_signed_payload_rejects(tmp_path, installer, key_file, notes, signing_key, capsys):
    manifest = _build_signed(tmp_path, installer, key_file, notes)
    envelope = json.loads(manifest.read_text(encoding="utf-8"))
    signed = envelope["signed"]
    idx = signed.index('"build_number":210') + len('"build_number":21')
    envelope["signed"] = signed[:idx] + "1" + signed[idx + 1:]  # 210 -> 211, still valid JSON
    manifest.write_text(json.dumps(envelope, ensure_ascii=False), encoding="utf-8")

    assert _verify(manifest, signing_key) == 1
    assert "signature does not match" in capsys.readouterr().err


def test_one_byte_flip_anywhere_in_file_rejects(tmp_path, installer, key_file, notes, signing_key):
    manifest = _build_signed(tmp_path, installer, key_file, notes)
    raw = bytearray(manifest.read_bytes())
    start = raw.index(b"sha256") + 12
    raw[start] = ord("0") if raw[start] != ord("0") else ord("1")
    manifest.write_bytes(bytes(raw))

    assert _verify(manifest, signing_key) == 1


def test_wrong_public_key_rejects(tmp_path, installer, key_file, notes):
    manifest = _build_signed(tmp_path, installer, key_file, notes)
    other = Ed25519PrivateKey.generate()

    assert _verify(manifest, other) == 1


def test_unknown_key_id_rejects(tmp_path, installer, key_file, notes, signing_key):
    manifest = _build_signed(tmp_path, installer, key_file, notes)

    code = verify_manifest.main(["--manifest", str(manifest), "--public-key", f"k2027b={_pub(signing_key)}"])
    assert code == 1


def test_placeholder_embedded_keys_reject(tmp_path, installer, key_file, notes, monkeypatch, capsys):
    import modules.app_update.service as service

    monkeypatch.setattr(service, "UPDATE_SIGNING_PUBLIC_KEYS", {KEY_ID: "REPLACE_WITH_REAL_ED25519_PUBLIC_KEY_BASE64"})
    manifest = _build_signed(tmp_path, installer, key_file, notes)

    assert verify_manifest.main(["--manifest", str(manifest)]) == 1
    assert "placeholder" in capsys.readouterr().err


def test_embedded_keys_are_the_default(tmp_path, installer, key_file, notes, signing_key, monkeypatch):
    import modules.app_update.service as service

    monkeypatch.setattr(service, "UPDATE_SIGNING_PUBLIC_KEYS", {KEY_ID: _pub(signing_key)})
    manifest = _build_signed(tmp_path, installer, key_file, notes)

    assert verify_manifest.main(["--manifest", str(manifest), "--installer", str(installer)]) == 0


def test_installer_hash_mismatch_rejects(tmp_path, installer, key_file, notes, signing_key, capsys):
    manifest = _build_signed(tmp_path, installer, key_file, notes)
    data = bytearray(installer.read_bytes())
    data[100] ^= 0xFF  # same size, different content
    installer.write_bytes(bytes(data))

    assert _verify(manifest, signing_key, "--installer", str(installer)) == 1
    assert "sha256" in capsys.readouterr().err


def test_installer_size_mismatch_rejects(tmp_path, installer, key_file, notes, signing_key):
    manifest = _build_signed(tmp_path, installer, key_file, notes)
    installer.write_bytes(installer.read_bytes() + b"x")

    assert _verify(manifest, signing_key, "--installer", str(installer)) == 1


def test_unsigned_payload_then_sign(tmp_path, installer, key_file, notes, signing_key):
    unsigned = tmp_path / "manifest.unsigned.json"
    assert build_manifest.main([
        "--installer", str(installer), "--version", VERSION, "--build", "210",
        "--notes-ar", str(notes[0]), "--notes-en", str(notes[1]), "--out", str(unsigned),
    ]) == 0
    # an unsigned payload is never accepted by the client
    assert _verify(unsigned, signing_key) == 1

    signed = tmp_path / "manifest.json"
    assert sign_manifest.main([
        "--in", str(unsigned), "--installer", str(installer), "--key-file", str(key_file), "--out", str(signed),
    ]) == 0
    assert _verify(signed, signing_key, "--installer", str(installer)) == 0
    before = json.loads(json.loads(unsigned.read_text(encoding="utf-8"))["signed"])
    after = json.loads(json.loads(signed.read_text(encoding="utf-8"))["signed"])
    assert after == before  # the signer keeps the build payload (incl. expires_at) byte-for-byte


def test_sign_from_unsigned_refuses_a_different_installer(tmp_path, installer, key_file, notes):
    unsigned = tmp_path / "manifest.unsigned.json"
    assert build_manifest.main([
        "--installer", str(installer), "--version", VERSION, "--build", "210", "--out", str(unsigned),
    ]) == 0
    installer.write_bytes(b"MZ" + os.urandom(8192))

    code = sign_manifest.main([
        "--in", str(unsigned), "--installer", str(installer),
        "--key-file", str(key_file), "--out", str(tmp_path / "manifest.json"),
    ])
    assert code == 1
    assert not (tmp_path / "manifest.json").exists()


def test_release_info_file_is_cross_checked(tmp_path, installer, key_file, signing_key):
    info = {
        "version": VERSION, "build": 210, "filename": INSTALLER_NAME,
        "size": installer.stat().st_size, "sha256": hashlib.sha256(installer.read_bytes()).hexdigest(),
    }
    info_path = tmp_path / "release_info.json"
    info_path.write_text(json.dumps(info), encoding="utf-8")
    out = tmp_path / "manifest.json"
    assert build_manifest.main([
        "--release-info", str(info_path), "--installer", str(installer),
        "--sign", "--key-file", str(key_file), "--out", str(out),
    ]) == 0
    assert _verify(out, signing_key, "--installer", str(installer)) == 0

    info["sha256"] = "0" * 64
    info_path.write_text(json.dumps(info), encoding="utf-8")
    assert build_manifest.main([
        "--release-info", str(info_path), "--installer", str(installer), "--out", str(tmp_path / "x.json"),
    ]) == 1


@pytest.mark.parametrize(
    "extra",
    [
        ["--min-supported-version", "2.2.0"],  # newer than the release
        ["--min-supported-version", "2.1"],
        ["--version", "2.1.0-beta"],
    ],
)
def test_invalid_build_arguments_fail(tmp_path, installer, extra):
    args = ["--installer", str(installer), "--build", "210", "--out", str(tmp_path / "m.json")]
    if "--version" not in extra:
        args += ["--version", VERSION]
    assert build_manifest.main(args + extra) == 1
    assert not (tmp_path / "m.json").exists()


def test_installer_filename_must_pass_the_client_path_rule(tmp_path):
    bad = tmp_path / "setup file.exe"
    bad.write_bytes(b"MZ" + b"\0" * 64)
    code = build_manifest.main([
        "--installer", str(bad), "--version", VERSION, "--build", "1", "--out", str(tmp_path / "m.json"),
    ])
    assert code == 1


def test_sign_without_any_key_fails(tmp_path, installer, capsys):
    code = build_manifest.main([
        "--installer", str(installer), "--version", VERSION, "--build", "1", "--sign", "--out", str(tmp_path / "m.json"),
    ])
    assert code == 1
    assert build_manifest.KEY_ENV_VAR in capsys.readouterr().err


def test_key_from_env_var_pem_and_raw_seed(tmp_path, installer, signing_key, monkeypatch):
    for material in (_pem(signing_key), _seed_b64(signing_key)):
        monkeypatch.setenv(build_manifest.KEY_ENV_VAR, material)
        out = tmp_path / "manifest.json"
        assert build_manifest.main([
            "--installer", str(installer), "--version", VERSION, "--build", "1", "--sign", "--out", str(out),
        ]) == 0
        assert _verify(out, signing_key) == 0


def test_garbage_key_error_does_not_echo_the_key(tmp_path, installer, monkeypatch, capsys):
    secret = "Zm9vYmFyYmF6cXV4c2VjcmV0dmFsdWU="
    monkeypatch.setenv(build_manifest.KEY_ENV_VAR, secret)
    code = build_manifest.main([
        "--installer", str(installer), "--version", VERSION, "--build", "1", "--sign", "--out", str(tmp_path / "m.json"),
    ])
    captured = capsys.readouterr()
    assert code == 1
    assert secret not in captured.out + captured.err


# ─── key generation / no key on stdout ────────────────────────────────────────

def test_generate_key_prints_public_only(tmp_path, capsys):
    key_out = tmp_path / "secure" / "update_signing.pem"
    assert build_manifest.main(["--generate-key", "--key-out", str(key_out), "--key-id", KEY_ID]) == 0
    captured = capsys.readouterr()

    pem = key_out.read_text(encoding="ascii")
    private_key = serialization.load_pem_private_key(pem.encode("ascii"), password=None)
    assert isinstance(private_key, Ed25519PrivateKey)
    public = _pub(private_key)
    assert f'"{KEY_ID}": "{public}",' in captured.out
    output = captured.out + captured.err
    assert "PRIVATE KEY" not in output
    assert _pem_body(pem) not in output
    assert _seed_b64(private_key) not in output


def test_generate_key_refuses_to_overwrite(tmp_path):
    key_out = tmp_path / "update_signing.pem"
    key_out.write_text("existing", encoding="ascii")

    assert build_manifest.main(["--generate-key", "--key-out", str(key_out)]) == 1
    assert key_out.read_text(encoding="ascii") == "existing"


@pytest.mark.skipif(os.name == "nt", reason="POSIX permission bits")
def test_generated_key_file_is_owner_only(tmp_path):
    key_out = tmp_path / "update_signing.pem"
    assert build_manifest.main(["--generate-key", "--key-out", str(key_out)]) == 0
    assert (key_out.stat().st_mode & 0o777) == 0o600


def test_cli_process_never_writes_private_key_to_stdout(tmp_path, installer):
    """End-to-end in a child process: generate, then sign from the env var; neither leaks the key."""
    env = dict(os.environ)
    env.pop(build_manifest.KEY_ENV_VAR, None)
    key_out = tmp_path / "k.pem"
    gen = subprocess.run(
        [sys.executable, str(BUILD_PATH), "--generate-key", "--key-out", str(key_out)],
        capture_output=True, text=True, env=env, cwd=str(tmp_path), timeout=120,
    )
    assert gen.returncode == 0, gen.stderr
    pem = key_out.read_text(encoding="ascii")
    private_key = serialization.load_pem_private_key(pem.encode("ascii"), password=None)

    env[build_manifest.KEY_ENV_VAR] = pem
    out = tmp_path / "manifest.json"
    sign = subprocess.run(
        [sys.executable, str(BUILD_PATH), "--installer", str(installer), "--version", VERSION, "--build", "1",
         "--sign", "--out", str(out)],
        capture_output=True, text=True, env=env, cwd=str(tmp_path), timeout=120,
    )
    assert sign.returncode == 0, sign.stderr
    for proc in (gen, sign):
        output = proc.stdout + proc.stderr
        assert "PRIVATE KEY" not in output
        assert _pem_body(pem) not in output
        assert _seed_b64(private_key) not in output
    assert _verify(out, private_key) == 0


# ─── --url (public HTTPS check) ───────────────────────────────────────────────

def _server(manifest_bytes: bytes, installer_bytes: bytes, *, content_length=None, served=None, log=None):
    body = installer_bytes if served is None else served
    path = f"/importflow/updates/releases/{VERSION}/{INSTALLER_NAME}"

    def handler(request: httpx.Request) -> httpx.Response:
        if log is not None:
            log.append((request.method, str(request.url)))
        if request.url.path == "/importflow/updates/manifest.json":
            return httpx.Response(200, content=manifest_bytes)
        if request.url.path == path:
            length = str(len(body) if content_length is None else content_length)
            if request.method == "HEAD":
                return httpx.Response(200, headers={"content-length": length})
            return httpx.Response(200, content=body)
        return httpx.Response(404)

    return httpx.MockTransport(handler)


def test_url_check_accepts_matching_public_installer(tmp_path, installer, key_file, notes, signing_key):
    manifest = _build_signed(tmp_path, installer, key_file, notes)
    log = []
    transport = _server(manifest.read_bytes(), installer.read_bytes(), log=log)

    assert _verify(manifest, signing_key, "--url", BASE_URL, transport=transport) == 0
    methods = [m for m, _ in log]
    assert methods == ["HEAD", "GET"]
    assert all("nocache=" in url for _, url in log), "requests must bypass caches"


def test_url_check_rejects_wrong_content_length(tmp_path, installer, key_file, notes, signing_key, capsys):
    manifest = _build_signed(tmp_path, installer, key_file, notes)
    transport = _server(manifest.read_bytes(), installer.read_bytes(), content_length=1)

    assert _verify(manifest, signing_key, "--url", BASE_URL, transport=transport) == 1
    assert "Content-Length" in capsys.readouterr().err


def test_url_check_rejects_wrong_public_bytes(tmp_path, installer, key_file, notes, signing_key, capsys):
    manifest = _build_signed(tmp_path, installer, key_file, notes)
    tampered = bytearray(installer.read_bytes())
    tampered[10] ^= 0x01
    transport = _server(manifest.read_bytes(), installer.read_bytes(), served=bytes(tampered))

    assert _verify(manifest, signing_key, "--url", BASE_URL, transport=transport) == 1
    assert "sha256" in capsys.readouterr().err


def test_url_check_does_not_follow_redirects(tmp_path, installer, key_file, notes, signing_key):
    manifest = _build_signed(tmp_path, installer, key_file, notes)
    transport = httpx.MockTransport(lambda r: httpx.Response(302, headers={"location": "https://evil.example/x.exe"}))

    assert _verify(manifest, signing_key, "--url", BASE_URL, transport=transport) == 1


def test_url_must_pass_the_client_allow_list(tmp_path, installer, key_file, notes, signing_key):
    manifest = _build_signed(tmp_path, installer, key_file, notes)

    assert _verify(manifest, signing_key, "--url", "http://kamal-sroor.online/importflow/updates/") == 2
    assert _verify(manifest, signing_key, "--url", "https://evil.example/importflow/updates/") == 2


def test_published_manifest_must_match_expected_file(tmp_path, installer, key_file, notes, signing_key):
    manifest = _build_signed(tmp_path, installer, key_file, notes)
    transport = _server(manifest.read_bytes(), installer.read_bytes())
    args = ["--url", BASE_URL, "--public-key", f"{KEY_ID}={_pub(signing_key)}", "--head-only"]

    assert verify_manifest.main(args + ["--expect-manifest", str(manifest)], transport=transport) == 0

    other = tmp_path / "other.json"
    other.write_bytes(manifest.read_bytes() + b" ")
    assert verify_manifest.main(args + ["--expect-manifest", str(other)], transport=transport) == 1


def test_verify_requires_an_input():
    assert verify_manifest.main([]) == 2


# ─── workflow ─────────────────────────────────────────────────────────────────

WORKFLOW_TEXT = WORKFLOW_PATH.read_text(encoding="utf-8")


PUBLISH_WORKFLOW_TEXT = PUBLISH_WORKFLOW_PATH.read_text(encoding="utf-8")


@pytest.fixture(scope="module")
def workflow():
    yaml = pytest.importorskip("yaml")
    return yaml.safe_load(WORKFLOW_TEXT)


@pytest.fixture(scope="module")
def publish_workflow():
    yaml = pytest.importorskip("yaml")
    return yaml.safe_load(PUBLISH_WORKFLOW_TEXT)


def _step_index(steps, predicate, description):
    matches = [i for i, step in enumerate(steps) if predicate(step)]
    assert matches, f"publish job has no step that {description}"
    return matches[0]


def _run(step) -> str:
    return str(step.get("run", ""))


def test_build_workflow_never_publishes(workflow):
    assert set(workflow["jobs"]) == {"build-and-release", "release"}
    for job in workflow["jobs"].values():
        assert "environment" not in job
    for needle in ("UPDATE_SIGNING_KEY_ED25519", "HOSTINGER", "sftp", "sign_manifest.py", "production-updates"):
        assert needle not in WORKFLOW_TEXT, needle
    secrets = set(re.findall(r"secrets\.([A-Z0-9_]+)", WORKFLOW_TEXT))
    assert secrets <= {"GITHUB_TOKEN"}














def test_all_actions_are_pinned_by_commit_sha(workflow, publish_workflow):
    for wf, text in ((workflow, WORKFLOW_TEXT), (publish_workflow, PUBLISH_WORKFLOW_TEXT)):
        uses = [step["uses"] for job in wf["jobs"].values() for step in job["steps"] if "uses" in step]
        assert uses
        for ref in uses:
            assert re.fullmatch(r"[\w.-]+/[\w.-]+@[0-9a-f]{40}", ref), f"not pinned by SHA: {ref}"
        for line in text.splitlines():
            if re.search(r"uses: \S+@[0-9a-f]{40}", line):
                assert re.search(r"# v\d+\.\d+\.\d+\s*$", line), f"missing version comment: {line.strip()}"


def test_build_job_ships_the_unsigned_payload_to_publish(workflow):
    steps = workflow["jobs"]["build-and-release"]["steps"]
    build = _step_index(steps, lambda s: "build_manifest.py" in _run(s), "builds the unsigned manifest")
    upload = _step_index(
        steps, lambda s: s.get("with", {}).get("name") == "update-payload", "uploads the update payload",
    )
    iscc = _step_index(steps, lambda s: "ISCC.exe" in _run(s), "compiles the installer")

    assert iscc < build < upload
    assert "--sign" not in _run(steps[build])
    assert "manifest.unsigned.json" in steps[upload]["with"]["path"]


def test_htaccess_denies_partial_uploads_and_disables_manifest_cache():
    text = HTACCESS_PATH.read_text(encoding="utf-8")

    assert "Options -Indexes" in text
    assert re.search(r'<FilesMatch "\\\.\(part\|tmp\)\$">\s*Require all denied', text)
    assert 'Header set Cache-Control "no-store, max-age=0"' in text


# ─── stand-alone signer: expires_at / previous ────────────────────────────────

def _unsigned(tmp_path, installer, version=VERSION) -> Path:
    exe = installer
    if version != VERSION:
        exe = installer.with_name(f"Sorour_Logistics_Setup_v{version}.exe")
        exe.write_bytes(b"MZ" + os.urandom(4096))
    out = tmp_path / f"manifest.{version}.unsigned.json"
    assert build_manifest.main([
        "--installer", str(exe), "--version", version, "--build", "1", "--out", str(out),
    ]) == 0
    return out


def _sign(tmp_path, unsigned, key_file, *extra, name="manifest.json") -> Path:
    out = tmp_path / name
    assert sign_manifest.main(["--in", str(unsigned), "--key-file", str(key_file), "--out", str(out), *extra]) == 0
    return out


def _payload(manifest: Path) -> dict:
    return json.loads(json.loads(manifest.read_text(encoding="utf-8"))["signed"])


def _dt(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def test_expires_at_defaults_to_released_at_plus_90_days_and_is_configurable(tmp_path, installer, key_file):
    unsigned = _unsigned(tmp_path, installer)

    default = _payload(_sign(tmp_path, unsigned, key_file, name="a.json"))
    week = _payload(_sign(tmp_path, unsigned, key_file, "--expires-days", "7", name="b.json"))
    explicit = _payload(_sign(tmp_path, unsigned, key_file, "--expires-at", "2099-01-01T00:00:00Z", name="c.json"))

    assert re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", default["expires_at"])
    assert _dt(default["expires_at"]) - _dt(default["released_at"]) == timedelta(days=90)
    assert _dt(week["expires_at"]) - _dt(week["released_at"]) == timedelta(days=7)
    assert explicit["expires_at"] == "2099-01-01T00:00:00Z"


def test_build_manifest_writes_expires_at(tmp_path, installer):
    out = tmp_path / "unsigned.json"
    assert build_manifest.main([
        "--installer", str(installer), "--version", VERSION, "--build", "1", "--released-at", "2026-10-01T10:00:00Z",
        "--expires-days", "45", "--out", str(out),
    ]) == 0
    payload = json.loads(json.loads(out.read_text(encoding="utf-8"))["signed"])
    assert payload["expires_at"] == "2026-11-15T10:00:00Z"


@pytest.mark.parametrize("extra", [["--expires-days", "0"], ["--expires-days", "400"],
                                   ["--expires-at", "2001-01-01T00:00:00Z"], ["--expires-at", "soon"]])
def test_invalid_expiry_fails(tmp_path, installer, key_file, extra):
    unsigned = _unsigned(tmp_path, installer)
    out = tmp_path / "manifest.json"

    assert sign_manifest.main(["--in", str(unsigned), "--key-file", str(key_file), "--out", str(out), *extra]) == 1
    assert not out.exists()


def test_previous_block_comes_from_the_live_manifest(tmp_path, installer, key_file, signing_key):
    from modules.app_update.service import ManifestVerifier

    live = _sign(tmp_path, _unsigned(tmp_path, installer, "2.0.9"), key_file, name="live.json")
    live_installer = _payload(live)["installer"]
    new = _sign(tmp_path, _unsigned(tmp_path, installer), key_file, "--previous-from-manifest", str(live))

    previous = _payload(new)["previous"]
    assert previous == sign_manifest.build_previous_block("2.0.9", live_installer)
    verified = ManifestVerifier({KEY_ID: _pub(signing_key)}).verify(new.read_bytes())
    assert verified.previous is not None and verified.previous.version == "2.0.9"
    assert verified.previous.installer.sha256 == live_installer["sha256"]


def test_republishing_the_same_version_keeps_its_previous(tmp_path, installer, key_file):
    first = _sign(tmp_path, _unsigned(tmp_path, installer, "2.0.9"), key_file, name="first.json")
    live = _sign(tmp_path, _unsigned(tmp_path, installer), key_file, "--previous-from-manifest", str(first),
                 name="live.json")
    again = _sign(tmp_path, _unsigned(tmp_path, installer), key_file, "--previous-from-manifest", str(live),
                  name="again.json")

    assert _payload(again)["previous"]["version"] == "2.0.9"


def test_live_manifest_newer_than_release_is_refused(tmp_path, installer, key_file):
    live = _sign(tmp_path, _unsigned(tmp_path, installer, "3.0.0"), key_file, name="live.json")
    out = tmp_path / "manifest.json"

    code = sign_manifest.main(["--in", str(_unsigned(tmp_path, installer)), "--key-file", str(key_file),
                               "--out", str(out), "--previous-from-manifest", str(live)])
    assert code == 1
    assert not out.exists()


def test_live_manifest_signed_by_another_key_gives_no_previous(tmp_path, installer, key_file):
    other_key = tmp_path / "other.pem"
    other_key.write_text(_pem(Ed25519PrivateKey.generate()), encoding="ascii")
    live = _sign(tmp_path, _unsigned(tmp_path, installer, "2.0.9"), other_key, name="live.json")

    new = _sign(tmp_path, _unsigned(tmp_path, installer), key_file, "--previous-from-manifest", str(live))
    assert "previous" not in _payload(new)


def test_missing_live_manifest_gives_no_previous(tmp_path, installer, key_file):
    new = _sign(tmp_path, _unsigned(tmp_path, installer), key_file,
                "--previous-from-manifest", str(tmp_path / "absent.json"))
    assert "previous" not in _payload(new)


def test_signer_generate_key_matches_build_manifest(tmp_path, capsys):
    key_out = tmp_path / "k.pem"
    assert sign_manifest.main(["--generate-key", "--key-out", str(key_out)]) == 0
    out = capsys.readouterr().out
    key = serialization.load_pem_private_key(key_out.read_bytes(), password=None)
    assert f'"{KEY_ID}": "{_pub(key)}",' in out
    assert _pem_body(key_out.read_text(encoding="ascii")) not in out


# ─── signer isolation ─────────────────────────────────────────────────────────

def _imported_roots(path: Path) -> set:
    tree = ast.parse(path.read_text(encoding="utf-8"))
    roots = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            roots.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom):
            assert node.level == 0, "the signer must not use relative imports"
            roots.add(node.module.split(".")[0])
    return roots


def test_signer_imports_only_stdlib_and_cryptography():
    roots = _imported_roots(SIGN_PATH)
    forbidden = {"modules", "fastapi", "sqlalchemy", "httpx", "pydantic", "database", "utils", "settings", "main"}

    assert not roots & forbidden
    assert roots - set(sys.stdlib_module_names) == {"cryptography"}
    assert "__import__" not in SIGN_PATH.read_text(encoding="utf-8")
    assert "importlib" not in roots


def test_signer_runs_isolated_without_the_app_on_sys_path(tmp_path, installer, key_file, signing_key):
    """`python -I` from an unrelated cwd: proves no hidden dependency on the repo or app packages."""
    unsigned = _unsigned(tmp_path, installer)
    out = tmp_path / "isolated.json"
    env = {k: v for k, v in os.environ.items() if not k.startswith("PYTHON")}
    proc = subprocess.run(
        [sys.executable, "-I", str(SIGN_PATH), "--in", str(unsigned), "--key-file", str(key_file), "--out", str(out)],
        capture_output=True, text=True, cwd=str(tmp_path), env=env, timeout=120,
    )
    assert proc.returncode == 0, proc.stderr
    assert "modules" not in proc.stdout + proc.stderr
    assert _verify(out, signing_key) == 0


def test_signer_size_cap_matches_the_client():
    from modules.app_update.validators import MANIFEST_APP, MANIFEST_MAX_BYTES, MANIFEST_SCHEMA

    assert sign_manifest.MANIFEST_MAX_BYTES == MANIFEST_MAX_BYTES
    assert sign_manifest.MANIFEST_SCHEMA == MANIFEST_SCHEMA
    assert sign_manifest.MANIFEST_APP == MANIFEST_APP


def test_sign_requirements_are_fully_hash_pinned():
    text = SIGN_REQUIREMENTS.read_text(encoding="utf-8")
    logical = [ln for ln in text.replace("\\\n", " ").splitlines() if ln.strip() and not ln.lstrip().startswith("#")]
    names = set()
    for line in logical:
        req, *rest = line.split()
        assert re.fullmatch(r"[A-Za-z0-9_.-]+==[0-9][A-Za-z0-9.]*", req), f"not pinned exactly: {req}"
        assert rest and all(re.fullmatch(r"--hash=sha256:[0-9a-f]{64}", h) for h in rest), f"missing hashes: {req}"
        names.add(req.split("==")[0].lower())
    assert names == {"cryptography", "cffi", "pycparser"}


# ─── workflow: least privilege + signer isolation ─────────────────────────────

def test_build_job_is_read_only_and_does_not_persist_credentials(workflow):
    assert workflow["permissions"] == {"contents": "read"}
    build = workflow["jobs"]["build-and-release"]
    assert build["permissions"] == {"contents": "read", "actions": "read"}  # actions: read for the CI gate
    assert not any("action-gh-release" in str(s.get("uses", "")) for s in build["steps"])


def test_every_checkout_disables_persisted_credentials(workflow, publish_workflow):
    checkouts = [
        step for wf in (workflow, publish_workflow) for job in wf["jobs"].values() for step in job["steps"]
        if str(step.get("uses", "")).startswith("actions/checkout@")
    ]
    assert checkouts
    for step in checkouts:
        assert step.get("with", {}).get("persist-credentials") is False


def test_only_the_release_job_can_write(workflow):
    jobs = workflow["jobs"]
    writers = [name for name, job in jobs.items() if "write" in json.dumps(job.get("permissions", {}))]
    assert writers == ["release"]
    release = jobs["release"]
    assert release["needs"] in ("build-and-release", ["build-and-release"])
    assert release["permissions"] == {"contents": "write"}
    assert not any(str(s.get("uses", "")).startswith("actions/checkout@") for s in release["steps"])
    assert not any("run" in s for s in release["steps"]), "the write job runs no project code"
    assert any("action-gh-release" in str(s.get("uses", "")) for s in release["steps"])






# ─── re-sign (expiry refresh) ─────────────────────────────────────────────────

def test_resign_refreshes_only_expires_at(tmp_path, installer, key_file, signing_key):
    from modules.app_update.service import ManifestVerifier

    first = _sign(tmp_path, _unsigned(tmp_path, installer, "2.0.9"), key_file, name="first.json")
    live = _sign(tmp_path, _unsigned(tmp_path, installer), key_file, "--previous-from-manifest", str(first),
                 name="live.json")
    out = tmp_path / "resigned.json"

    assert sign_manifest.main(["--resign", str(live), "--key-file", str(key_file), "--out", str(out),
                               "--expires-days", "60"]) == 0
    before, after = _payload(live), _payload(out)
    assert {k: v for k, v in after.items() if k != "expires_at"} == {k: v for k, v in before.items() if k != "expires_at"}
    assert abs(_dt(after["expires_at"]) - (datetime.now(timezone.utc) + timedelta(days=60))) < timedelta(minutes=5)
    verified = ManifestVerifier({KEY_ID: _pub(signing_key)}).verify(out.read_bytes())
    assert verified.previous is not None and verified.previous.version == "2.0.9"


def test_resign_default_is_90_days_from_now(tmp_path, installer, key_file):
    live = _sign(tmp_path, _unsigned(tmp_path, installer), key_file, name="live.json")
    out = tmp_path / "resigned.json"

    assert sign_manifest.main(["--resign", str(live), "--key-file", str(key_file), "--out", str(out)]) == 0
    expected = datetime.now(timezone.utc) + timedelta(days=90)
    assert abs(_dt(_payload(out)["expires_at"]) - expected) < timedelta(minutes=5)


def test_resign_refuses_a_manifest_not_signed_by_this_key(tmp_path, installer, key_file):
    other_key = tmp_path / "other.pem"
    other_key.write_text(_pem(Ed25519PrivateKey.generate()), encoding="ascii")
    live = _sign(tmp_path, _unsigned(tmp_path, installer), other_key, name="live.json")
    out = tmp_path / "resigned.json"

    assert sign_manifest.main(["--resign", str(live), "--key-file", str(key_file), "--out", str(out)]) == 1
    assert not out.exists()


def test_resign_refuses_a_tampered_manifest(tmp_path, installer, key_file):
    live = _sign(tmp_path, _unsigned(tmp_path, installer), key_file, name="live.json")
    envelope = json.loads(live.read_text(encoding="utf-8"))
    envelope["signed"] = envelope["signed"].replace('"mandatory":false', '"mandatory":true')
    live.write_text(json.dumps(envelope), encoding="utf-8")

    assert sign_manifest.main(["--resign", str(live), "--key-file", str(key_file),
                               "--out", str(tmp_path / "x.json")]) == 1


# ─── re-sign workflow ─────────────────────────────────────────────────────────

RESIGN_WORKFLOW_PATH = PROJECT_DIR / ".github" / "workflows" / "resign_update_manifest.yml"


@pytest.fixture(scope="module")
def resign_workflow():
    yaml = pytest.importorskip("yaml")
    return yaml.safe_load(RESIGN_WORKFLOW_PATH.read_text(encoding="utf-8"))


def test_resign_workflow_is_monthly_and_manual(resign_workflow):
    triggers = resign_workflow.get("on", resign_workflow.get(True))
    assert set(triggers) == {"schedule", "workflow_dispatch"}
    assert triggers["schedule"][0]["cron"].split()[2] not in ("*",), "monthly: fixed day of month"
    assert resign_workflow["permissions"] == {"contents": "read"}


def test_resign_job_is_gated_by_the_check_and_the_environment(resign_workflow):
    jobs = resign_workflow["jobs"]
    check, resign = jobs["check"], jobs["resign"]

    assert "environment" not in check
    assert "secrets." not in json.dumps(check)
    assert resign["needs"] in ("check", ["check"])
    assert resign["environment"] == "production-updates"
    assert "needs.check.outputs.due" in resign["if"]
    assert resign["permissions"] == {"contents": "read"}


def test_resign_job_signs_isolated_and_uploads_only_the_manifest(resign_workflow):
    steps = resign_workflow["jobs"]["resign"]["steps"]
    venv = _step_index(steps, lambda s: "requirements-sign.txt" in _run(s), "creates the signer venv")
    sign = _step_index(steps, lambda s: "sign_manifest.py" in _run(s), "re-signs")
    app_deps = _step_index(steps, lambda s: "requirements.txt" in _run(s) and "requirements-sign" not in _run(s),
                           "installs app dependencies")
    verify = _step_index(steps, lambda s: "verify_manifest.py" in _run(s) and "--manifest" in _run(s), "verifies")
    upload = _step_index(steps, lambda s: "manifest.json.tmp" in _run(s), "uploads the manifest")
    prepare_ssh = _step_index(steps, lambda s: "HOSTINGER_SSH_KEY" in _run(s), "writes the SSH key")
    cleanup = _step_index(steps, lambda s: "shred" in _run(s), "removes the SSH key")

    assert venv < sign < app_deps < verify < prepare_ssh < upload < cleanup
    assert "--resign" in _run(steps[sign]) and "-I scripts/release/sign_manifest.py" in _run(steps[sign])
    assert "--require-hashes" in _run(steps[venv])
    assert set(steps[sign]["env"]) == {"UPDATE_SIGNING_KEY_ED25519"}
    for i, step in enumerate(steps):
        if i != sign:
            assert "UPDATE_SIGNING_KEY_ED25519" not in json.dumps(step)
    upload_run = _run(steps[upload])
    assert "posix-rename $REMOTE_DIR/manifest.json.tmp $REMOTE_DIR/manifest.json" in upload_run
    assert ".exe" not in upload_run and "releases/" not in upload_run, "re-sign must never touch installers"
    assert steps[cleanup].get("if") == "always()"
    assert "StrictHostKeyChecking yes" in json.dumps(steps)
    for step in steps:
        assert "cache" not in step.get("with", {})


def test_resign_workflow_actions_pinned_and_checkout_without_credentials(resign_workflow):
    text = RESIGN_WORKFLOW_PATH.read_text(encoding="utf-8")
    for job in resign_workflow["jobs"].values():
        for step in job["steps"]:
            if "uses" in step:
                assert re.fullmatch(r"[\w.-]+/[\w.-]+@[0-9a-f]{40}", step["uses"])
            if str(step.get("uses", "")).startswith("actions/checkout@"):
                assert step["with"]["persist-credentials"] is False
    for line in text.splitlines():
        if re.search(r"uses: \S+@[0-9a-f]{40}", line):
            assert re.search(r"# v\d+\.\d+\.\d+\s*$", line)
    assert not re.search(r"StrictHostKeyChecking[ =]+(no|accept-new)", text, re.IGNORECASE)


def test_verify_rejects_an_expired_manifest(tmp_path, installer, key_file, signing_key, capsys):
    live = _sign(tmp_path, _unsigned(tmp_path, installer), key_file, name="live.json")
    payload = _payload(live)
    payload["released_at"], payload["expires_at"] = "2020-01-01T00:00:00Z", "2020-04-01T00:00:00Z"
    expired = tmp_path / "expired.json"
    expired.write_bytes(sign_manifest.sign_payload(sign_manifest.serialise_payload(payload), signing_key, KEY_ID))

    assert _verify(expired, signing_key) == 1
    assert "expired" in capsys.readouterr().err


# ─── round 3: no Python next to the SSH key, ref guards, tag-only release ─────

def _no_python_after_ssh_key(steps):
    prepare = _step_index(steps, lambda s: "HOSTINGER_SSH_KEY" in _run(s), "writes the SSH key")
    for step in steps[prepare:]:
        assert not re.search(r"(^|[\s;|&(\"/])python3?(\s|$)", _run(step)), f"Python runs next to the SSH key: {step.get('name')}"
        assert "verify_manifest.py" not in _run(step) and "sign_manifest.py" not in _run(step)
        assert "setup-python" not in str(step.get("uses", ""))




def test_resign_runs_no_python_while_the_ssh_key_exists(resign_workflow):
    _no_python_after_ssh_key(resign_workflow["jobs"]["resign"]["steps"])




def test_resign_guards_the_ref_before_any_code_runs(resign_workflow):
    steps = resign_workflow["jobs"]["resign"]["steps"]
    guard = _run(steps[0])
    assert '"refs/heads/main"' in guard and "exit 1" in guard
    assert "uses" not in steps[0]


def test_release_job_runs_for_tags_only(workflow):
    assert workflow["jobs"]["release"]["if"] == "github.ref_type == 'tag'"


def test_publish_time_mandatory_and_min_supported_version(tmp_path, installer, key_file, signing_key):
    from modules.app_update.service import ManifestVerifier

    unsigned = _unsigned(tmp_path, installer)
    out = _sign(tmp_path, unsigned, key_file, "--mandatory", "--min-supported-version", "2.0.0")
    payload = _payload(out)
    assert payload["mandatory"] is True and payload["min_supported_version"] == "2.0.0"
    assert ManifestVerifier({KEY_ID: _pub(signing_key)}).verify(out.read_bytes()).mandatory is True

    plain = _payload(_sign(tmp_path, unsigned, key_file, name="plain.json"))
    assert plain["mandatory"] is False and plain["min_supported_version"] is None

    code = sign_manifest.main(["--in", str(unsigned), "--key-file", str(key_file), "--out", str(tmp_path / "x.json"),
                               "--min-supported-version", "9.0.0"])
    assert code == 1


# ─── publish_update.yml: sign / verify / upload ───────────────────────────────

def _jobs(publish_workflow):
    return publish_workflow["jobs"]


def test_publish_workflow_is_a_dispatch_only_button_in_three_jobs(publish_workflow):
    triggers = publish_workflow.get("on", publish_workflow.get(True))
    assert set(triggers) == {"workflow_dispatch"}
    inputs = triggers["workflow_dispatch"]["inputs"]
    assert inputs["tag"]["required"] is True
    assert set(inputs) == {"tag", "mandatory", "min_supported_version", "expires_days"}
    assert publish_workflow["permissions"] == {"contents": "read"}

    jobs = _jobs(publish_workflow)
    assert set(jobs) == {"sign", "verify", "upload"}
    assert jobs["sign"]["environment"] == "production-updates"
    assert jobs["upload"]["environment"] == "production-updates"
    assert "environment" not in jobs["verify"], "verify installs unhashed packages: no environment, no secrets"
    assert jobs["sign"]["permissions"] == {"contents": "read", "actions": "read"}
    assert jobs["verify"]["permissions"] == {"contents": "read"}
    assert jobs["upload"]["permissions"] == {"contents": "read"}
    assert jobs["verify"]["needs"] in ("sign", ["sign"])
    assert "verify" in jobs["upload"]["needs"]


def test_publish_and_resign_share_one_concurrency_group(publish_workflow, resign_workflow):
    assert publish_workflow["concurrency"]["group"] == resign_workflow["jobs"]["resign"]["concurrency"]["group"]
    assert publish_workflow["concurrency"]["cancel-in-progress"] is False


def test_publish_guard_runs_first_main_only_and_checks_the_tag(publish_workflow):
    steps = _jobs(publish_workflow)["sign"]["steps"]
    guard = _run(steps[0])
    assert "uses" not in steps[0]
    assert '[[ "$GITHUB_REF" == "refs/heads/main" ]]' in guard
    assert "refs/tags/$RELEASE_TAG\" ]]" not in guard and '== "refs/tags/' not in guard, "no run from a tag"
    assert "^v[0-9]+\\.[0-9]+\\.[0-9]+$" in guard, "tag input must be v<semver>"
    assert "git/ref/tags/$RELEASE_TAG" in guard, "tag must exist"
    assert "contents/version.json?ref=refs/tags/$RELEASE_TAG" in guard, "tag must equal version.json at the tag"
    assert guard.count("exit 1") >= 5
    assert publish_workflow["env"]["RELEASE_TAG"] == "${{ inputs.tag }}"


def test_publish_downloads_the_payload_of_the_green_tag_push_build(publish_workflow):
    steps = _jobs(publish_workflow)["sign"]["steps"]
    find = _step_index(steps, lambda s: "actions/workflows/build_and_release.yml/runs" in _run(s), "finds the build run")
    download = _step_index(steps, lambda s: "download-artifact" in str(s.get("uses", "")), "downloads the payload")

    assert 0 < find < download
    run = _run(steps[find])
    assert "commits/refs/tags/$RELEASE_TAG" in run
    assert "status=success" in run and "head_sha=" in run
    assert '.event == \\"push\\"' in run and '.head_branch == \\"$RELEASE_TAG\\"' in run
    assert steps[find]["id"] == "build_run"
    with_ = steps[download]["with"]
    assert with_["name"] == "update-payload"
    assert with_["run-id"] == "${{ steps.build_run.outputs.run_id }}"
    assert with_["github-token"] == "${{ github.token }}"


def test_sign_job_installs_only_the_hashed_signer_and_holds_the_key_in_one_step(publish_workflow):
    steps = _jobs(publish_workflow)["sign"]["steps"]
    venv = _step_index(steps, lambda s: "requirements-sign.txt" in _run(s), "creates the signer venv")
    sign = _step_index(steps, lambda s: "sign_manifest.py" in _run(s), "signs")
    upload = _step_index(steps, lambda s: s.get("with", {}).get("name") == "signed-update", "uploads the signed update")

    assert venv < sign < upload
    assert "--require-hashes" in _run(steps[venv]) and "--only-binary :all:" in _run(steps[venv])
    assert '"$RUNNER_TEMP/signer-venv/bin/python" -I scripts/release/sign_manifest.py' in _run(steps[sign])
    assert set(steps[sign]["env"]) == {"UPDATE_SIGNING_KEY_ED25519"}
    assert "installer_name" in steps[upload]["with"]["path"] and "manifest.json" in steps[upload]["with"]["path"]
    for step in steps:
        assert "requirements.txt" not in _run(step).replace("requirements-sign.txt", ""), "no unhashed installs here"
        assert "cache" not in step.get("with", {}), step.get("name")


def test_signing_key_secret_only_reaches_the_sign_step(workflow, publish_workflow):
    holders = [
        (job_name, step.get("name"))
        for job_name, job in _jobs(publish_workflow).items()
        for step in job.get("steps", [])
        if "UPDATE_SIGNING_KEY_ED25519" in json.dumps(step)
    ]
    assert holders == [("sign", "Sign Update Manifest")]
    for job in _jobs(publish_workflow).values():
        assert "UPDATE_SIGNING_KEY_ED25519" not in json.dumps(job.get("env", {}))
    assert "UPDATE_SIGNING_KEY_ED25519" not in json.dumps(publish_workflow.get("env", {}))
    assert "UPDATE_SIGNING_KEY_ED25519" not in json.dumps(workflow)


def test_verify_job_uses_the_tag_code_and_no_secrets(publish_workflow):
    verify = _jobs(publish_workflow)["verify"]
    assert "secrets." not in json.dumps(verify)
    steps = verify["steps"]
    checkout = _step_index(steps, lambda s: str(s.get("uses", "")).startswith("actions/checkout@"), "checks out")
    deps = _step_index(steps, lambda s: "requirements.txt" in _run(s), "installs app dependencies")
    check = _step_index(steps, lambda s: "verify_manifest.py" in _run(s), "verifies")

    assert checkout < deps < check
    assert steps[checkout]["with"]["ref"] == "refs/tags/${{ inputs.tag }}"
    assert "--installer" in _run(steps[check]) and "expected_sha256=" in _run(steps[check])


def test_upload_job_is_shell_only(publish_workflow):
    upload = _jobs(publish_workflow)["upload"]
    for step in upload["steps"]:
        uses = str(step.get("uses", ""))
        assert not uses.startswith(("actions/checkout@", "actions/setup-python@")), step.get("name")
        run = _run(step)
        assert not re.search(r"(^|[\s;|&(\"/])(python3?|pip3?)(\s|$)", run), f"Python/pip in upload: {step.get('name')}"
    secrets = set(re.findall(r"secrets\.([A-Z0-9_]+)", json.dumps(upload)))
    assert secrets == {"HOSTINGER_SSH_KEY", "HOSTINGER_KNOWN_HOSTS"}


def test_upload_publishes_manifest_last_after_public_installer_verification(publish_workflow):
    steps = _jobs(publish_workflow)["upload"]["steps"]
    prepare_ssh = _step_index(steps, lambda s: "HOSTINGER_SSH_KEY" in _run(s), "writes the SSH key")
    installer_upload = _step_index(
        steps, lambda s: "sftp" in _run(s) and ".part" in _run(s) and "posix-rename" in _run(s),
        "uploads the installer as .part then renames it",
    )
    public_check = _step_index(
        steps, lambda s: "curl" in _run(s) and "sha256sum" in _run(s) and "$EXPECTED_SHA256" in _run(s)
        and "Content-Length" in _run(s), "verifies the public HTTPS installer against the verified manifest",
    )
    manifest_upload = _step_index(steps, lambda s: "manifest.json.tmp" in _run(s), "uploads manifest.json.tmp")
    published = _step_index(steps, lambda s: "cmp -s" in _run(s), "compares the published manifest")
    prune = _step_index(steps, lambda s: "ls -1" in _run(s) and "rmdir" in _run(s), "prunes old releases")
    remove_now = _step_index(steps, lambda s: "shred" in _run(s) and "if" not in s, "removes the SSH key after prune")
    backstop = _step_index(steps, lambda s: "shred" in _run(s) and s.get("if") == "always()", "always() cleanup")

    assert prepare_ssh < installer_upload < public_check < manifest_upload < published < prune < remove_now < backstop
    assert "posix-rename $REMOTE_DIR/manifest.json.tmp $REMOTE_DIR/manifest.json" in _run(steps[manifest_upload])
    assert all("manifest.json.tmp" not in _run(s) for s in steps[:public_check])
    assert not any("upload-artifact" in str(s.get("uses", "")) for s in steps[prepare_ssh:remove_now])


def test_upload_ssh_pins_the_host_key_and_protects_the_key_file(publish_workflow):
    steps = _jobs(publish_workflow)["upload"]["steps"]
    prepare = _run(steps[_step_index(steps, lambda s: "HOSTINGER_SSH_KEY" in _run(s), "writes the SSH key")])

    assert "StrictHostKeyChecking yes" in prepare
    assert "install -m 600" in prepare and "umask 077" in prepare
    assert "HOSTINGER_KNOWN_HOSTS" in prepare
    assert not re.search(r"StrictHostKeyChecking[ =]+(no|accept-new)", PUBLISH_WORKFLOW_TEXT, re.IGNORECASE)


# ─── ci.yml (tests before merge, in parallel) + deterministic sharding ───────

CI_WORKFLOW_PATH = PROJECT_DIR / ".github" / "workflows" / "ci.yml"
SHARD_PATH = PROJECT_DIR / "scripts" / "ci" / "shard_tests.py"
shard_tests = _load(SHARD_PATH, "importflow_shard_tests_under_test")


@pytest.fixture(scope="module")
def ci_workflow():
    yaml = pytest.importorskip("yaml")
    return yaml.safe_load(CI_WORKFLOW_PATH.read_text(encoding="utf-8"))


def test_ci_triggers_on_pull_requests_and_main(ci_workflow):
    triggers = ci_workflow.get("on", ci_workflow.get(True))
    assert set(triggers) == {"pull_request", "push", "workflow_dispatch"}
    assert triggers["pull_request"]["branches"] == ["main"]
    assert triggers["push"]["branches"] == ["main"]
    assert ci_workflow["permissions"] == {"contents": "read"}


def test_ci_runs_four_backend_shards_frontend_and_a_single_required_check(ci_workflow):
    jobs = ci_workflow["jobs"]
    assert set(jobs) == {"backend-tests", "frontend-tests", "ci-ok"}

    backend = jobs["backend-tests"]
    assert backend["strategy"]["matrix"]["shard"] == [1, 2, 3, 4]
    assert backend["strategy"]["fail-fast"] is False
    run = next(_run(s) for s in backend["steps"] if "python -m pytest" in _run(s))
    assert "shard_tests.py --shards 4 --index" in run and "--junitxml=" in run
    assert any("upload-artifact" in str(s.get("uses", "")) and s.get("if") == "always()" for s in backend["steps"])

    frontend = jobs["frontend-tests"]
    runs = " ".join(_run(s) for s in frontend["steps"])
    assert "flutter test -j 2" in runs
    assert "flutter analyze --no-fatal-infos --no-fatal-warnings" in runs
    flutter = next(s for s in frontend["steps"] if "flutter-action" in str(s.get("uses", "")))
    assert flutter["with"]["flutter-version"] == "3.44.6" and flutter["with"]["cache"] is True

    ok = jobs["ci-ok"]
    assert ok["name"] == "ci-ok" and ok["if"] == "always()"
    assert set(ok["needs"]) == {"backend-tests", "frontend-tests"}
    assert '"success"' in _run(ok["steps"][0]) and "exit 1" in _run(ok["steps"][0])


def test_ci_actions_pinned_and_checkouts_without_credentials(ci_workflow):
    text = CI_WORKFLOW_PATH.read_text(encoding="utf-8")
    for job in ci_workflow["jobs"].values():
        for step in job["steps"]:
            if "uses" in step:
                assert re.fullmatch(r"[\w.-]+/[\w.-]+@[0-9a-f]{40}", step["uses"]), step["uses"]
            if str(step.get("uses", "")).startswith("actions/checkout@"):
                assert step["with"]["persist-credentials"] is False
    for line in text.splitlines():
        if re.search(r"uses: \S+@[0-9a-f]{40}", line):
            assert re.search(r"# v\d+\.\d+\.\d+\s*$", line), line
    assert "secrets." not in text


def test_shards_are_deterministic_disjoint_and_complete():
    files = shard_tests.collect_test_files()
    assert files and all(f.startswith(("tests/unit/", "tests/integration/")) for f in files)
    assert "tests/unit/test_release_manifest_tools.py" in files

    first = shard_tests.split(files, 4)
    assert first == shard_tests.split(list(reversed(files)), 4), "order of discovery must not matter"
    flat = [f for shard in first for f in shard]
    assert sorted(flat) == files and len(flat) == len(set(flat))
    assert all(first), "every shard gets work"


def test_shard_cli(tmp_path, capsys):
    (tmp_path / "tests" / "unit").mkdir(parents=True)
    for i, size in enumerate([500, 400, 300, 200, 100]):
        (tmp_path / "tests" / "unit" / f"test_{i}.py").write_text("x" * size, encoding="utf-8")

    printed = []
    for index in (1, 2):
        assert shard_tests.main(["--shards", "2", "--index", str(index)], root=tmp_path) == 0
        printed.append(capsys.readouterr().out.split())
    assert sorted(printed[0] + printed[1]) == [f"tests/unit/test_{i}.py" for i in range(5)]
    assert printed[0] == ["tests/unit/test_0.py", "tests/unit/test_3.py", "tests/unit/test_4.py"]

    assert shard_tests.main(["--shards", "2", "--index", "3"], root=tmp_path) == 2
    assert shard_tests.main(["--shards", "2", "--index", "1"], root=tmp_path / "empty") == 2
