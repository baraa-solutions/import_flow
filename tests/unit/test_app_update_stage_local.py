"""
POST /stage-local (spec §B.7): offline update from files on this machine. Signature, schema, sha256/size and
"newer than installed" are enforced; expiry and highest_seen are not (Decision 1). The staged copy is what is hashed.
"""
import pytest
from fastapi import HTTPException

import modules.app_update.service as update_service
import modules.app_update.validators as update_rules
from app_update_testkit import (
    NEW_INSTALLER,
    NEW_VERSION,
    audit_actions,
    events,
    installer_name,
    make_env,
    payload,
    sign,
)
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from modules.app_update.repository import UpdateFileRepository
from modules.app_update.validators import (
    DETAIL_DEV_MODE,
    DETAIL_FILE_NOT_FOUND,
    DETAIL_FILE_TOO_LARGE,
    DETAIL_INVALID_SIGNATURE,
    DETAIL_LOCAL_HASH_MISMATCH,
    DETAIL_NOT_NEWER,
    DETAIL_UNSUPPORTED_FILE_TYPE,
    DETAIL_UPDATE_BUSY,
)
from utils.db_safety import clear_maintenance_mode


@pytest.fixture(autouse=True)
def _no_maintenance_leak():
    clear_maintenance_mode()
    yield
    clear_maintenance_mode()


@pytest.fixture
def env(tmp_path, monkeypatch):
    return make_env(tmp_path, monkeypatch)


def _usb(env, manifest: bytes, installer: bytes = NEW_INSTALLER, names=("manifest.json", "setup.exe")):
    usb = env.tmp / "usb stick"
    usb.mkdir(exist_ok=True)
    manifest_path = usb / names[0]
    installer_path = usb / names[1]
    manifest_path.write_bytes(manifest)
    installer_path.write_bytes(installer)
    return str(manifest_path), str(installer_path)


def _staging(env):
    folder = env.data_dir / "staging"
    return sorted(p.name for p in folder.iterdir()) if folder.exists() else []


def _refused(env, service, paths, status_code, detail):
    with pytest.raises(HTTPException) as exc:
        service.stage_local(*paths, actor="admin")
    assert exc.value.status_code == status_code
    assert exc.value.detail == detail
    return exc


# ─── happy path ──────────────────────────────────────────────────────────────

def test_stage_local_happy_path_then_apply(env):
    raw = sign(env.key, payload())
    service = env.service()
    session = env.session_factory()
    try:
        status = service.stage_local(*_usb(env, raw), actor="admin", db=session)
    finally:
        session.close()
    assert status.state == "ready"
    assert status.version == NEW_VERSION
    assert status.downloaded_bytes == status.total_bytes == len(NEW_INSTALLER)
    assert _staging(env) == sorted([installer_name(NEW_VERSION), "staged_manifest.json"])
    assert (env.data_dir / "staging" / installer_name(NEW_VERSION)).read_bytes() == NEW_INSTALLER
    assert (env.data_dir / "staging" / "staged_manifest.json").read_bytes() == raw
    assert events(env.data_dir)[-1] == "staged_local"
    assert UpdateFileRepository(env.data_dir).load_highest_seen() == (NEW_VERSION, 210)
    assert audit_actions(env.db_path) == [("UPDATE_STAGE_LOCAL", "admin", NEW_VERSION)]

    applied = service.apply(NEW_VERSION, actor="admin")
    assert applied.state == "installing"
    assert len(env.launcher.calls) == 1


def test_expired_manifest_is_accepted(env):
    raw = sign(env.key, payload(expires_at="2026-02-01T00:00:00Z"))
    env.repo.save_highest_seen("9.9.9", 999)  # highest_seen is not enforced either
    assert env.service().stage_local(*_usb(env, raw), actor="admin").state == "ready"


def test_uppercase_suffixes_are_accepted(env):
    raw = sign(env.key, payload())
    paths = _usb(env, raw, names=("MANIFEST.JSON", "SETUP.EXE"))
    assert env.service().stage_local(*paths, actor="admin").state == "ready"


def test_replaces_a_previously_staged_installer(env):
    service = env.ready_service()
    (env.data_dir / "staging" / "old_leftover.exe.part").write_bytes(b"junk")
    status = service.stage_local(*_usb(env, sign(env.key, payload())), actor="admin")
    assert status.state == "ready"
    assert "old_leftover.exe.part" not in _staging(env)


# ─── verification failures ───────────────────────────────────────────────────

def test_bad_signature_is_422(env):
    raw = sign(Ed25519PrivateKey.generate(), payload())
    _refused(env, env.service(), _usb(env, raw), 422, DETAIL_INVALID_SIGNATURE)
    assert _staging(env) == []


def test_malformed_manifest_is_422(env):
    _refused(env, env.service(), _usb(env, b"{not json"), 422, DETAIL_INVALID_SIGNATURE)


def test_hash_mismatch_is_422(env):
    raw = sign(env.key, payload())
    service = env.service()
    _refused(env, service, _usb(env, raw, installer=b"X" * len(NEW_INSTALLER)), 422, DETAIL_LOCAL_HASH_MISMATCH)
    assert _staging(env) == []
    assert service.get_status().state == "idle"


@pytest.mark.parametrize("installer", [NEW_INSTALLER[:-1], NEW_INSTALLER + b"extra"], ids=["short", "long"])
def test_size_mismatch_is_422(env, installer):
    raw = sign(env.key, payload())
    _refused(env, env.service(), _usb(env, raw, installer=installer), 422, DETAIL_LOCAL_HASH_MISMATCH)
    assert _staging(env) == []


def test_hash_is_computed_over_the_written_copy(env, monkeypatch):
    """The source is swapped after validation (TOCTOU): the hash covers the bytes streamed into staging -> 422."""
    raw = sign(env.key, payload())
    manifest_path, installer_path = _usb(env, raw)
    real_validate = update_service.validate_local_file

    def validate_then_swap(path, suffix, max_bytes):
        result = real_validate(path, suffix, max_bytes)
        if suffix == ".exe":
            with open(installer_path, "wb") as fh:
                fh.write(b"W" * len(NEW_INSTALLER))
        return result

    monkeypatch.setattr(update_service, "validate_local_file", validate_then_swap)
    _refused(env, env.service(), (manifest_path, installer_path), 422, DETAIL_LOCAL_HASH_MISMATCH)
    assert _staging(env) == []


def test_copy_is_what_gets_staged(env, monkeypatch):
    """A clean copy is staged byte for byte, and the source file is left untouched."""
    raw = sign(env.key, payload())
    manifest_path, installer_path = _usb(env, raw)
    env.service().stage_local(manifest_path, installer_path, actor="admin")
    staged = env.data_dir / "staging" / installer_name(NEW_VERSION)
    assert staged.read_bytes() == NEW_INSTALLER
    assert open(installer_path, "rb").read() == NEW_INSTALLER


def test_not_newer_is_409(env):
    raw = sign(env.key, payload())
    _refused(env, env.service(installed=NEW_VERSION), _usb(env, raw), 409, DETAIL_NOT_NEWER)
    _refused(env, env.service(installed="2.2.0"), _usb(env, raw), 409, DETAIL_NOT_NEWER)


# ─── file rules ──────────────────────────────────────────────────────────────

def test_missing_file_is_400(env):
    manifest, _ = _usb(env, sign(env.key, payload()))
    _refused(env, env.service(), (manifest, str(env.tmp / "nope.exe")), 400, DETAIL_FILE_NOT_FOUND)
    _refused(env, env.service(), (str(env.tmp / "nope.json"), manifest), 400, DETAIL_FILE_NOT_FOUND)


def test_relative_path_is_400(env):
    _usb(env, sign(env.key, payload()))
    _refused(env, env.service(), ("usb stick/manifest.json", "usb stick/setup.exe"), 400, DETAIL_FILE_NOT_FOUND)


def test_directory_is_400(env):
    manifest, _ = _usb(env, sign(env.key, payload()))
    folder = env.tmp / "folder.exe"
    folder.mkdir()
    _refused(env, env.service(), (manifest, str(folder)), 400, DETAIL_FILE_NOT_FOUND)


def test_wrong_suffix_is_400(env):
    raw = sign(env.key, payload())
    _refused(env, env.service(), _usb(env, raw, names=("manifest.txt", "setup.exe")), 400,
             DETAIL_UNSUPPORTED_FILE_TYPE)
    _refused(env, env.service(), _usb(env, raw, names=("manifest.json", "setup.msi")), 400,
             DETAIL_UNSUPPORTED_FILE_TYPE)


def test_too_large_is_400(env, monkeypatch):
    raw = sign(env.key, payload())
    monkeypatch.setattr(update_rules, "LOCAL_INSTALLER_MAX_BYTES", len(NEW_INSTALLER) - 1)
    _refused(env, env.service(), _usb(env, raw), 400, DETAIL_FILE_TOO_LARGE)
    monkeypatch.setattr(update_rules, "LOCAL_INSTALLER_MAX_BYTES", 1024 ** 3)
    monkeypatch.setattr(update_rules, "LOCAL_MANIFEST_MAX_BYTES", len(raw) - 1)
    _refused(env, env.service(), _usb(env, raw), 400, DETAIL_FILE_TOO_LARGE)


# ─── mode / state guards ─────────────────────────────────────────────────────

def test_dev_mode_is_400(env):
    _refused(env, env.service(apply_supported=False), _usb(env, sign(env.key, payload())), 400, DETAIL_DEV_MODE)
    assert _staging(env) == []


@pytest.mark.parametrize("busy", ["downloading", "verifying", "backing_up", "installing"])
def test_busy_is_409(env, busy):
    service = env.service()
    service._state = busy
    _refused(env, service, _usb(env, sign(env.key, payload())), 409, DETAIL_UPDATE_BUSY)


def test_failure_returns_to_the_prior_failed_state(env):
    service = env.service()
    service._state, service._error_code = "failed", "download_failed"
    raw = sign(env.key, payload())
    _refused(env, service, _usb(env, raw, installer=b"X" * len(NEW_INSTALLER)), 422, DETAIL_LOCAL_HASH_MISMATCH)
    status = service.get_status()
    assert (status.state, status.error_code) == ("failed", "download_failed")


def test_failure_after_ready_becomes_idle_because_staging_was_cleared(env):
    service = env.ready_service()
    raw = sign(env.key, payload())
    _refused(env, service, _usb(env, raw, installer=b"X" * len(NEW_INSTALLER)), 422, DETAIL_LOCAL_HASH_MISMATCH)
    assert service.get_status().state == "idle"
    assert _staging(env) == []


def test_request_schema_caps_path_length():
    from pydantic import ValidationError

    from modules.app_update.schemas import StageLocalRequest

    with pytest.raises(ValidationError):
        StageLocalRequest(manifest_path="C:/" + "a" * 1100, installer_path="C:/x.exe")
    StageLocalRequest(manifest_path="C:/" + "a" * 1000, installer_path="C:/x.exe")


# ─── local drives only (review item 3) ───────────────────────────────────────

@pytest.mark.parametrize("path", [
    r"\fileserver\share\setup.exe",
    r"\?\C:\usb\setup.exe",
    r"\.\C:\usb\setup.exe",
    r"\?\UNC\fileserver\share\setup.exe",
    "//fileserver/share/setup.exe",
    r"C:\usb\setup.exe:hidden",
    r"C:\usb\setup.exe::$DATA",
    "C:setup.exe",
    "setup.exe",
    "",
])
def test_non_local_paths_are_one_generic_400(path):
    with pytest.raises(HTTPException) as exc:
        update_rules.validate_local_file(path, ".exe", 10 ** 9)
    assert exc.value.status_code == 400
    if ":" in path[2:]:  # ADS: the suffix is ".exe:hidden", refused by the string-only suffix check
        assert exc.value.detail in (DETAIL_FILE_NOT_FOUND, DETAIL_UNSUPPORTED_FILE_TYPE)
    else:
        assert exc.value.detail == DETAIL_FILE_NOT_FOUND


@pytest.mark.parametrize("drive_type,allowed", [(2, True), (3, True), (4, False), (5, False), (6, False),
                                                 (0, False), (1, False)])
def test_only_fixed_and_removable_drives(env, monkeypatch, drive_type, allowed):
    manifest, installer = _usb(env, sign(env.key, payload()))
    seen = []

    def fake_drive_type(root):
        seen.append(root)
        return drive_type

    monkeypatch.setattr(update_rules, "get_drive_type", fake_drive_type)
    if allowed:
        assert update_rules.validate_local_file(installer, ".exe", 10 ** 9).name == "setup.exe"
    else:
        with pytest.raises(HTTPException) as exc:
            update_rules.validate_local_file(installer, ".exe", 10 ** 9)
        assert (exc.value.status_code, exc.value.detail) == (400, DETAIL_FILE_NOT_FOUND)
    assert seen and all(len(r) == 3 and r[1:] == ":\\" for r in seen)


def test_network_drive_letter_is_refused_through_the_service(env, monkeypatch):
    monkeypatch.setattr(update_rules, "get_drive_type", lambda root: 4)  # DRIVE_REMOTE (mapped share)
    _refused(env, env.service(), _usb(env, sign(env.key, payload())), 400, DETAIL_FILE_NOT_FOUND)


def test_real_local_drive_is_accepted(env):
    manifest, installer = _usb(env, sign(env.key, payload()))
    assert update_rules.get_drive_type(installer[0] + ":\\") in (2, 3)
    assert update_rules.validate_local_file(installer, ".exe", 10 ** 9).is_file()


# ─── /cancel cannot interrupt stage-local (review item 2) ────────────────────

def test_cancel_during_stage_local_is_409(env, monkeypatch):
    from modules.app_update.service import UpdateService
    from modules.app_update.validators import DETAIL_NO_DOWNLOAD_RUNNING

    service = env.service()
    service._cancel_event = __import__("threading").Event()  # stale event from an earlier download
    real_copy = UpdateService._copy_verified
    seen = {}

    def copy_and_try_cancel(source, part, info):
        seen["state"] = service.get_status().state
        with pytest.raises(HTTPException) as exc:
            service.cancel(actor="admin")
        seen["cancel"] = exc.value.status_code
        return real_copy(source, part, info)

    monkeypatch.setattr(UpdateService, "_copy_verified", staticmethod(copy_and_try_cancel))
    status = service.stage_local(*_usb(env, sign(env.key, payload())), actor="admin")
    assert status.state == "ready"
    assert seen == {"state": "verifying", "cancel": 409}
    assert DETAIL_NO_DOWNLOAD_RUNNING


def test_suffix_is_checked_before_touching_the_file_system(monkeypatch):
    touched = []
    monkeypatch.setattr(update_rules, "get_drive_type", lambda root: touched.append(root) or 3)
    for path in (r"\\fileserver\share\setup.msi", r"C:\does\not\exist\manifest.txt"):
        with pytest.raises(HTTPException) as exc:
            update_rules.validate_local_file(path, ".exe", 10 ** 9)
        assert exc.value.detail == DETAIL_UNSUPPORTED_FILE_TYPE
    assert touched == []
