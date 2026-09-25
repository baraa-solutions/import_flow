"""
app_update manifest trust rules (plan §4.2, §11): Ed25519 signature over the exact `signed` bytes, key_id map,
relative installer path, version <= installed ignored, mandatory via min_supported_version, host allow-list,
installed-version helper, dev-mode detection. Tests generate their own keypair; no network.
"""
import base64
import json
import sys
from pathlib import Path

import httpx
import pytest
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat

import modules.app_update.service as update_service
from modules.app_update.service import ManifestVerifier, UpdateService, get_installed_version
from modules.app_update.validators import (
    DEFAULT_UPDATE_BASE_URL,
    MANIFEST_MAX_BYTES,
    ManifestError,
    build_installer_url,
    is_apply_supported,
    is_newer,
    resolve_base_url,
    validate_base_url,
    validate_installer_path,
)

SHA = "a" * 64
KEY_ID = "ktest"


def _public_b64(private_key: Ed25519PrivateKey) -> str:
    raw = private_key.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)
    return base64.b64encode(raw).decode()


def _payload(**overrides) -> dict:
    payload = {
        "schema": 1,
        "app": "sorour-logistics",
        "channel": "stable",
        "version": "2.1.0",
        "build_number": 210,
        "released_at": "2026-10-01T10:00:00Z",
        "expires_at": "2099-01-01T00:00:00Z",
        "min_supported_version": "2.0.0",
        "mandatory": False,
        "db_schema_revision": "e1f2a3b4c5d6",
        "release_notes": {"ar": ["تحسينات"], "en": ["Improvements"]},
        "installer": {
            "path": "releases/2.1.0/Sorour_Logistics_Setup_v2.1.0.exe",
            "size_bytes": 1024,
            "sha256": SHA,
        },
        "previous": {
            "version": "2.0.9",
            "installer": {
                "path": "releases/2.0.9/Sorour_Logistics_Setup_v2.0.9.exe",
                "size_bytes": 2048,
                "sha256": "b" * 64,
            },
        },
    }
    payload.update(overrides)
    return payload


def _envelope(private_key: Ed25519PrivateKey, payload: dict, key_id: str = KEY_ID) -> dict:
    signed = json.dumps(payload, separators=(",", ":"), ensure_ascii=False)
    signature = base64.b64encode(private_key.sign(signed.encode("utf-8"))).decode()
    return {"key_id": key_id, "signature": signature, "signed": signed}


def _raw(envelope: dict) -> bytes:
    return json.dumps(envelope, ensure_ascii=False).encode("utf-8")


@pytest.fixture
def signing_key(monkeypatch):
    key = Ed25519PrivateKey.generate()
    monkeypatch.setattr(update_service, "UPDATE_SIGNING_PUBLIC_KEYS", {KEY_ID: _public_b64(key)})
    return key


@pytest.fixture(autouse=True)
def isolated_data_dir(tmp_path, monkeypatch):
    monkeypatch.setenv("UPDATE_DATA_DIR", str(tmp_path / "updates"))
    monkeypatch.delenv("UPDATE_BASE_URL", raising=False)
    return tmp_path / "updates"


# ─── Signature ───────────────────────────────────────────────────────────────

def test_valid_signature_is_accepted(signing_key):
    manifest = ManifestVerifier().verify(_raw(_envelope(signing_key, _payload())))
    assert manifest.version == "2.1.0"
    assert manifest.build_number == 210
    assert manifest.installer.filename == "Sorour_Logistics_Setup_v2.1.0.exe"
    assert manifest.installer.size_bytes == 1024
    assert manifest.installer.sha256 == SHA
    assert manifest.release_notes == {"ar": ["تحسينات"], "en": ["Improvements"]}
    assert manifest.previous is not None and manifest.previous.version == "2.0.9"
    assert manifest.previous.installer.filename == "Sorour_Logistics_Setup_v2.0.9.exe"
    assert manifest.previous.installer.size_bytes == 2048
    assert manifest.previous.installer.sha256 == "b" * 64
    assert manifest.released_at is not None and manifest.released_at.year == 2026
    assert manifest.expires_at.year == 2099 and manifest.expires_at.tzinfo is not None


def test_previous_block_is_optional(signing_key):
    payload = _payload()
    del payload["previous"]
    assert ManifestVerifier().verify(_raw(_envelope(signing_key, payload))).previous is None


def test_tampered_payload_is_rejected(signing_key):
    envelope = _envelope(signing_key, _payload())
    envelope["signed"] = envelope["signed"].replace('"2.1.0"', '"9.9.9"', 1)
    with pytest.raises(ManifestError):
        ManifestVerifier().verify(_raw(envelope))


def test_whitespace_change_in_signed_bytes_is_rejected(signing_key):
    envelope = _envelope(signing_key, _payload())
    envelope["signed"] = envelope["signed"] + " "
    with pytest.raises(ManifestError):
        ManifestVerifier().verify(_raw(envelope))


def test_unknown_key_id_is_rejected(signing_key):
    with pytest.raises(ManifestError):
        ManifestVerifier().verify(_raw(_envelope(signing_key, _payload(), key_id="other")))


def test_signature_from_another_key_is_rejected(signing_key):
    attacker = Ed25519PrivateKey.generate()
    with pytest.raises(ManifestError):
        ManifestVerifier().verify(_raw(_envelope(attacker, _payload())))


def test_second_rotation_slot_is_accepted(monkeypatch):
    old_key, new_key = Ed25519PrivateKey.generate(), Ed25519PrivateKey.generate()
    monkeypatch.setattr(
        update_service, "UPDATE_SIGNING_PUBLIC_KEYS", {"old": _public_b64(old_key), "new": _public_b64(new_key)}
    )
    manifest = ManifestVerifier().verify(_raw(_envelope(new_key, _payload(), key_id="new")))
    assert manifest.key_id == "new"


@pytest.mark.parametrize(
    "raw",
    [b"not json", b"[]", b'{"key_id":"ktest"}', b'{"key_id":"ktest","signature":"%%%","signed":"{}"}'],
)
def test_malformed_envelope_is_rejected(signing_key, raw):
    with pytest.raises(ManifestError):
        ManifestVerifier().verify(raw)


def test_manifest_over_size_cap_is_rejected(signing_key):
    payload = _payload(release_notes={"ar": ["x" * (MANIFEST_MAX_BYTES + 10)], "en": []})
    with pytest.raises(ManifestError):
        ManifestVerifier().verify(_raw(_envelope(signing_key, payload)))


def test_placeholder_key_is_not_usable(monkeypatch):
    # A placeholder (non-base64) key must never count as usable.
    import modules.app_update.service as update_service
    monkeypatch.setattr(update_service, "UPDATE_SIGNING_PUBLIC_KEYS",
                        {"k2026a": "REPLACE_WITH_REAL_ED25519_PUBLIC_KEY_BASE64"})
    assert ManifestVerifier().has_usable_key() is False
    with pytest.raises(ManifestError):
        ManifestVerifier().verify(_raw(_envelope(Ed25519PrivateKey.generate(), _payload(), key_id="k2026a")))


@pytest.mark.parametrize(
    "overrides",
    [
        {"schema": 2},
        {"app": "other-app"},
        {"channel": "beta"},
        {"version": "2.1"},
        {"version": "v2.1.0"},
        {"build_number": -1},
        {"min_supported_version": "latest"},
        {"mandatory": "yes"},
        {"release_notes": {"ar": "text"}},
        {"released_at": "yesterday"},
        {"expires_at": None},
        {"expires_at": "soon"},
        {"expires_at": 1893456000},
        {"expires_at": "2026-09-30T10:00:00Z"},  # not after released_at
    ],
)
def test_signed_but_invalid_payload_is_rejected(signing_key, overrides):
    with pytest.raises(ManifestError):
        ManifestVerifier().verify(_raw(_envelope(signing_key, _payload(**overrides))))


@pytest.mark.parametrize(
    "installer",
    [
        {"path": "releases/2.1.0/setup.exe", "size_bytes": 0, "sha256": SHA},
        {"path": "releases/2.1.0/setup.exe", "size_bytes": 10, "sha256": "zz"},
        {"path": "https://evil.example/setup.exe", "size_bytes": 10, "sha256": SHA},
    ],
)
def test_invalid_installer_block_is_rejected(signing_key, installer):
    with pytest.raises(ManifestError):
        ManifestVerifier().verify(_raw(_envelope(signing_key, _payload(installer=installer))))


# ─── Installer path rules ────────────────────────────────────────────────────

@pytest.mark.parametrize(
    "path",
    [
        "/releases/2.1.0/setup.exe",
        "https://evil.example/releases/setup.exe",
        "//evil.example/releases/setup.exe",
        "releases/../../etc/setup.exe",
        "releases/2.1.0/../setup.exe",
        "releases\\2.1.0\\setup.exe",
        "C:/releases/setup.exe",
        "other/2.1.0/setup.exe",
        "releases/2.1.0/setup.msi",
        "releases//setup.exe",
        "releases/2.1.0/setup.exe?x=1",
        "",
        None,
    ],
)
def test_bad_installer_paths_are_rejected(path):
    with pytest.raises(ManifestError):
        validate_installer_path(path)


def test_absolute_installer_path_in_signed_manifest_is_rejected(signing_key):
    installer = {"path": "/releases/2.1.0/setup.exe", "size_bytes": 10, "sha256": SHA}
    with pytest.raises(ManifestError):
        ManifestVerifier().verify(_raw(_envelope(signing_key, _payload(installer=installer))))


def test_dotdot_in_previous_path_is_rejected(signing_key):
    previous = {"version": "2.0.9", "installer": {"path": "releases/../x.exe", "sha256": SHA, "size_bytes": 5}}
    with pytest.raises(ManifestError):
        ManifestVerifier().verify(_raw(_envelope(signing_key, _payload(previous=previous))))


@pytest.mark.parametrize(
    "previous",
    [
        {"version": "2.0.9"},  # installer block missing
        {"version": "2.0.9", "path": "releases/2.0.9/a.exe", "sha256": SHA, "size_bytes": 5},  # old flat shape
        {"version": "2.0.9", "installer": {"path": "/releases/2.0.9/a.exe", "sha256": SHA, "size_bytes": 5}},
        {"version": "2.0.9", "installer": {"path": "releases/2.0.9/a.exe", "sha256": "x", "size_bytes": 5}},
        {"version": "2.0.9", "installer": {"path": "releases/2.0.9/a.exe", "sha256": SHA, "size_bytes": 0}},
        {"version": "2.1.0", "installer": {"path": "releases/2.1.0/a.exe", "sha256": SHA, "size_bytes": 5}},
        {"version": "old", "installer": {"path": "releases/2.0.9/a.exe", "sha256": SHA, "size_bytes": 5}},
        "releases/2.0.9/a.exe",
    ],
)
def test_invalid_previous_block_is_rejected(signing_key, previous):
    with pytest.raises(ManifestError):
        ManifestVerifier().verify(_raw(_envelope(signing_key, _payload(previous=previous))))


# ─── verify() never leaks a non-ManifestError ────────────────────────────────

def test_lone_surrogate_in_signed_is_manifest_error(signing_key):
    # JSON escape for a lone high surrogate: decodes fine, but .encode("utf-8") raises UnicodeEncodeError.
    raw = ('{"key_id":"ktest","signature":"AAAA","signed":"' + chr(92) + 'ud800"}').encode()
    with pytest.raises(ManifestError):
        ManifestVerifier().verify(raw)


def test_lone_surrogate_in_key_id_is_manifest_error(signing_key):
    raw = ('{"key_id":"' + chr(92) + 'udfff","signature":"AAAA","signed":"{}"}').encode()
    with pytest.raises(ManifestError):
        ManifestVerifier().verify(raw)


def test_deeply_nested_envelope_is_manifest_error(signing_key):
    depth = 30000
    raw = b"[" * depth + b"]" * depth
    assert len(raw) <= MANIFEST_MAX_BYTES
    with pytest.raises(ManifestError):
        ManifestVerifier().verify(raw)


def test_deeply_nested_signed_payload_is_manifest_error(signing_key):
    depth = 25000
    signed = "[" * depth + "]" * depth
    signature = base64.b64encode(signing_key.sign(signed.encode("utf-8"))).decode()
    raw = json.dumps({"key_id": KEY_ID, "signature": signature, "signed": signed}).encode()
    assert len(raw) <= MANIFEST_MAX_BYTES
    with pytest.raises(ManifestError):
        ManifestVerifier().verify(raw)


def test_unexpected_internal_error_is_wrapped(signing_key, monkeypatch):
    def boom(*_args, **_kwargs):
        raise KeyError("unexpected")

    monkeypatch.setattr(ManifestVerifier, "_parse_payload", staticmethod(boom))
    with pytest.raises(ManifestError):
        ManifestVerifier().verify(_raw(_envelope(signing_key, _payload())))


@pytest.mark.parametrize("raw", [None, "text", 123])
def test_non_bytes_input_is_manifest_error(raw):
    with pytest.raises(ManifestError):
        ManifestVerifier().verify(raw)


def test_installer_url_is_base_plus_relative_path():
    url = build_installer_url(DEFAULT_UPDATE_BASE_URL, "releases/2.1.0/Sorour_Logistics_Setup_v2.1.0.exe")
    assert url == "https://kamal-sroor.online/importflow/updates/releases/2.1.0/Sorour_Logistics_Setup_v2.1.0.exe"


# ─── Base URL allow-list ─────────────────────────────────────────────────────

@pytest.mark.parametrize(
    "url",
    [
        "http://kamal-sroor.online/importflow/updates/",
        "https://evil.example/importflow/updates/",
        "https://kamal-sroor.online.evil.example/updates/",
        "https://user:pw@kamal-sroor.online/updates/",
        "https://kamal-sroor.online:8443/updates/",
        "https://kamal-sroor.online/updates/?x=1",
        "ftp://kamal-sroor.online/",
    ],
)
def test_base_url_outside_allow_list_is_rejected(url):
    with pytest.raises(ValueError):
        validate_base_url(url)
    assert resolve_base_url(url) is None


def test_base_url_default_and_valid_override():
    assert resolve_base_url(None) == DEFAULT_UPDATE_BASE_URL
    assert resolve_base_url("https://kamal-sroor.online/importflow/updates-staging") == (
        "https://kamal-sroor.online/importflow/updates-staging/"
    )


# ─── Version comparison in /check ────────────────────────────────────────────

def _check_with(signing_key, tmp_path, installed: str, **overrides):
    raw = _raw(_envelope(signing_key, _payload(**overrides)))

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, content=raw)

    service = UpdateService(
        data_dir=tmp_path / "updates",
        transport=httpx.MockTransport(handler),
        installed_version_provider=lambda: (installed, 1),
        apply_supported_provider=lambda: False,
    )
    return service.check(force=True)


@pytest.mark.parametrize("installed", ["2.1.0", "2.2.0", "10.0.0"])
def test_version_at_or_below_installed_is_ignored(signing_key, tmp_path, installed):
    result = _check_with(signing_key, tmp_path, installed)
    assert result.check_status == "up_to_date"
    assert result.update_available is False
    assert result.mandatory is False
    assert result.installer_size_bytes is None
    assert result.release_notes.ar == [] and result.release_notes.en == []


def test_newer_version_is_offered(signing_key, tmp_path):
    result = _check_with(signing_key, tmp_path, "2.0.3")
    assert result.check_status == "update_available"
    assert result.update_available is True
    assert result.latest_version == "2.1.0"
    assert result.latest_build == 210
    assert result.installer_size_bytes == 1024
    assert result.release_notes.en == ["Improvements"]
    assert result.mandatory is False


def test_mandatory_when_installed_below_min_supported(signing_key, tmp_path):
    result = _check_with(signing_key, tmp_path, "2.0.3", min_supported_version="2.1.0", mandatory=False)
    assert result.update_available is True
    assert result.mandatory is True


def test_mandatory_flag_in_manifest(signing_key, tmp_path):
    result = _check_with(signing_key, tmp_path, "2.0.3", min_supported_version="1.0.0", mandatory=True)
    assert result.mandatory is True


def test_semver_compare_is_numeric():
    assert is_newer("2.10.0", "2.9.9")
    assert not is_newer("2.9.9", "2.10.0")


# ─── Installed version + dev-mode detection ──────────────────────────────────

def test_installed_version_read_from_version_json(tmp_path):
    path = tmp_path / "version.json"
    path.write_text(json.dumps({"version": "2.0.3", "build_number": 205}), encoding="utf-8")
    assert get_installed_version(path) == ("2.0.3", 205)


@pytest.mark.parametrize(
    "content",
    [
        "not json",
        "[]",
        json.dumps({"version": "latest", "build_number": 5}),
        json.dumps({"version": "2.0.3"}),
        json.dumps({"version": "2.0.3", "build_number": "205"}),
        json.dumps({"version": "2.0.3", "build_number": -1}),
    ],
)
def test_installed_version_fails_closed_when_malformed(tmp_path, content):
    bad = tmp_path / "bad.json"
    bad.write_text(content, encoding="utf-8")
    assert get_installed_version(bad) is None


def test_installed_version_fails_closed_when_missing(tmp_path):
    assert get_installed_version(tmp_path / "missing.json") is None


def test_check_is_disabled_when_installed_version_unknown(signing_key, tmp_path):
    requests = []

    def handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        return httpx.Response(200, content=_raw(_envelope(signing_key, _payload())))

    service = UpdateService(
        data_dir=tmp_path / "updates",
        transport=httpx.MockTransport(handler),
        installed_version_provider=lambda: None,
        apply_supported_provider=lambda: True,
    )
    result = service.check(force=True)
    assert result.check_status == "disabled"
    assert result.update_available is False
    assert result.current_version == "unknown"
    assert requests == []


def test_frozen_version_file_is_next_to_executable(tmp_path, monkeypatch):
    exe = tmp_path / "backend.exe"
    exe.write_bytes(b"")
    (tmp_path / "version.json").write_text(json.dumps({"version": "3.4.5", "build_number": 7}), encoding="utf-8")
    monkeypatch.setattr(sys, "frozen", True, raising=False)
    monkeypatch.setattr(sys, "executable", str(exe))
    assert update_service.version_file_path() == Path(exe).resolve().parent / "version.json"
    assert get_installed_version() == ("3.4.5", 7)


def test_apply_supported_only_for_frozen_inno_install(tmp_path, monkeypatch):
    exe = tmp_path / "backend.exe"
    exe.write_bytes(b"")
    monkeypatch.setattr(sys, "executable", str(exe))
    monkeypatch.delattr(sys, "frozen", raising=False)
    assert is_apply_supported() is False  # python main.py
    monkeypatch.setattr(sys, "frozen", True, raising=False)
    assert is_apply_supported() is False  # frozen but not installed by Setup
    (tmp_path / "unins000.exe").write_bytes(b"")
    assert is_apply_supported() is True
