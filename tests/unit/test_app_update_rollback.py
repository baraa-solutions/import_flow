"""
POST /rollback (spec §B.5): checks 1-8 change nothing; then copy the live DB aside (pre_restore_, protected),
restore the pre-update backup, write a kind=rollback marker and launch the kept previous installer. Temp DBs only.
"""
import json
from pathlib import Path

import pytest
from fastapi import HTTPException

import modules.app_update.service as update_service
from app_update_testkit import (
    BACKUP_NAME,
    NEW_VERSION,
    OLD_INSTALLER,
    OLD_VERSION,
    audit_actions,
    db_bytes_sha,
    events,
    history,
    insert_items,
    installer_name,
    item_names,
    make_env,
    payload,
    sign,
)
from modules.app_update.repository import PENDING_FILE, UpdateFileRepository, rollback_pending_reason
from modules.app_update.validators import (
    DETAIL_ALREADY_ON_PREVIOUS,
    DETAIL_ASIDE_FAILED,
    DETAIL_BACKUP_CORRUPT,
    DETAIL_BACKUP_NOT_OF_LAST_UPDATE,
    DETAIL_DEV_MODE,
    DETAIL_NO_ROLLBACK_AVAILABLE,
    DETAIL_PREVIOUS_INSTALLER_MISSING,
    DETAIL_RESTORE_FAILED,
    DETAIL_ROLLBACK_CONFIRM_REQUIRED,
    DETAIL_ROLLBACK_INSTALLER_TAMPERED,
    DETAIL_UPDATE_BUSY,
)
from utils.db_safety import (
    check_integrity,
    clear_maintenance_mode,
    enter_maintenance_mode,
    is_maintenance_mode,
    is_protected_backup,
    maintenance_reason,
    sha256_file,
)

ORIGINAL_ROWS = ["item-0", "item-1", "item-2"]
LATER_ROWS = ["after-backup-1", "after-backup-2"]


@pytest.fixture(autouse=True)
def _no_maintenance_leak():
    clear_maintenance_mode()
    yield
    clear_maintenance_mode()


@pytest.fixture
def env(tmp_path, monkeypatch):
    return make_env(tmp_path, monkeypatch)


def _prepare(env, manifest=None, keep_previous=True, **last_overrides):
    """A failed 2.0.3 -> 2.1.0 update: pre-update backup, rows written after it, previous installer kept."""
    raw = manifest if manifest is not None else sign(env.key, payload())
    backup_sha = env.take_pre_update_backup()
    insert_items(env.db_path, LATER_ROWS)
    if keep_previous:
        env.keep_previous_installer()
    env.write_last_update_result(raw, backup_sha, **last_overrides)
    return raw


def _refused(env, service, status_code, detail, backup_file=BACKUP_NAME, confirm=True):
    before = db_bytes_sha(env.db_path)
    with pytest.raises(HTTPException) as exc:
        service.rollback(backup_file, confirm=confirm, actor="admin")
    assert exc.value.status_code == status_code
    assert exc.value.detail == detail
    assert db_bytes_sha(env.db_path) == before  # nothing changed
    assert item_names(env.db_path) == ORIGINAL_ROWS + LATER_ROWS
    assert env.launcher.calls == []
    assert env.disposed == 0
    assert is_maintenance_mode() is False
    assert not (env.data_dir / PENDING_FILE).exists()
    assert not list(env.backups_dir.glob("pre_restore_*"))


# ─── happy path ──────────────────────────────────────────────────────────────

def test_rollback_happy_path(env):
    raw = _prepare(env)
    service = env.service(installed=NEW_VERSION)
    result = service.rollback(BACKUP_NAME, confirm=True, actor="admin")

    # 202 body
    assert result.state == "installing"
    assert result.restored_from == BACKUP_NAME
    assert result.aside_file.startswith("pre_restore_failed_v2.1.0_") and result.aside_file.endswith(".db")

    # rows written after the backup are gone from the live DB, kept in the protected aside copy
    assert item_names(env.db_path) == ORIGINAL_ROWS
    assert check_integrity(env.db_path) == "ok"
    aside = env.backups_dir / result.aside_file
    assert item_names(aside) == ORIGINAL_ROWS + LATER_ROWS
    assert is_protected_backup(aside)

    # marker
    marker = json.loads((env.data_dir / PENDING_FILE).read_text(encoding="utf-8"))
    assert marker["kind"] == "rollback"
    assert marker["from_version"] == NEW_VERSION and marker["to_version"] == OLD_VERSION
    assert marker["backup_file"] == BACKUP_NAME
    assert marker["aside_file"] == result.aside_file
    assert marker["manifest_raw"] == raw.decode("utf-8")
    assert marker["installer_file"] == installer_name(OLD_VERSION)
    assert marker["install_log"] == str(env.data_dir / "logs" / "rollback_2.0.3.log")
    assert marker["db_path"] == str(env.db_path) and marker["app_dir"] == str(env.app_dir)

    # launcher: the previous installer, pinned to the app dir
    previous = env.data_dir / "installers" / installer_name(OLD_VERSION)
    assert env.launcher.calls == [(
        f'"{previous}" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /RELAUNCH=1 '
        f'/DIR="{env.app_dir}" /LOG="{env.data_dir / "logs" / "rollback_2.0.3.log"}"',
        previous.parent,
    )]

    # process state
    assert is_maintenance_mode() is True
    assert env.disposed == 1
    assert service.get_status().state == "installing"
    entries = history(env.data_dir)
    assert [e for e in entries if e["event"] == "rollback_restored"][0]["detail"] == BACKUP_NAME
    assert events(env.data_dir)[-1] == "rollback_launched"
    # audit entry lands in the restored DB (fresh session after the restore)
    assert audit_actions(env.db_path) == [("UPDATE_ROLLBACK", "admin", OLD_VERSION)]


def test_post_rollback_evaluation_gives_rollback_success(env):
    _prepare(env)
    env.service(installed=NEW_VERSION).rollback(BACKUP_NAME, confirm=True, actor="admin")
    clear_maintenance_mode()  # new process after the previous installer ran

    restarted = env.service(installed=OLD_VERSION)
    result = restarted.get_last_result(client_version=OLD_VERSION)
    assert result.result == "success"
    assert result.kind == "rollback"
    assert result.from_version == NEW_VERSION and result.to_version == OLD_VERSION
    assert result.backup_file == BACKUP_NAME
    assert events(env.data_dir)[-1] == "rollback_ok"
    assert not (env.data_dir / PENDING_FILE).exists()


def test_expired_manifest_is_still_accepted(env):
    _prepare(env, manifest=sign(env.key, payload(expires_at="2026-02-01T00:00:00Z")))
    env.repo.save_highest_seen("9.0.0", 900)  # highest_seen is ignored too
    assert env.service(installed=NEW_VERSION).rollback(BACKUP_NAME, True, actor="admin").state == "installing"


def test_rollback_allowed_after_a_successful_update(env):
    _prepare(env, result="success", code=None)
    assert env.service(installed=NEW_VERSION).rollback(BACKUP_NAME, True, actor="admin").state == "installing"


# ─── refusals before any change ──────────────────────────────────────────────

def test_confirm_false_is_400(env):
    _prepare(env)
    _refused(env, env.service(installed=NEW_VERSION), 400, DETAIL_ROLLBACK_CONFIRM_REQUIRED, confirm=False)


def test_dev_mode_is_400(env):
    _prepare(env)
    _refused(env, env.service(installed=NEW_VERSION, apply_supported=False), 400, DETAIL_DEV_MODE)


@pytest.mark.parametrize("busy", ["downloading", "verifying", "backing_up", "installing"])
def test_busy_is_409(env, busy):
    _prepare(env)
    service = env.service(installed=NEW_VERSION)
    service._state = busy
    _refused(env, service, 409, DETAIL_UPDATE_BUSY)


@pytest.mark.parametrize("name", [
    "..\\x.db",
    "../" + BACKUP_NAME,
    "..\\" + BACKUP_NAME,
    "sub/" + BACKUP_NAME,
    "C:\\Windows\\" + BACKUP_NAME,
    "daily_backup_20261001.db",
    BACKUP_NAME + ".json",
])
def test_bad_or_traversal_name_is_409(env, name):
    _prepare(env)
    _refused(env, env.service(installed=NEW_VERSION), 409, DETAIL_BACKUP_NOT_OF_LAST_UPDATE, backup_file=name)


def test_name_other_than_last_is_409(env):
    _prepare(env)
    other = "pre_update_v2.0.3_to_v2.1.0_20261001_101501.db"
    (env.backups_dir / other).write_bytes((env.backups_dir / BACKUP_NAME).read_bytes())
    _refused(env, env.service(installed=NEW_VERSION), 409, DETAIL_BACKUP_NOT_OF_LAST_UPDATE, backup_file=other)


def test_sha_mismatch_is_422(env):
    _prepare(env, backup_sha256="0" * 64)
    _refused(env, env.service(installed=NEW_VERSION), 422, DETAIL_BACKUP_CORRUPT)


def test_missing_backup_file_is_422(env):
    _prepare(env)
    (env.backups_dir / BACKUP_NAME).unlink()
    _refused(env, env.service(installed=NEW_VERSION), 422, DETAIL_BACKUP_CORRUPT)


def test_integrity_failure_is_422(env):
    _prepare(env)
    backup = env.backups_dir / BACKUP_NAME
    backup.write_bytes(b"this is not a sqlite database" * 100)
    env.write_last_update_result(sign(env.key, payload()), sha256_file(backup))  # sha matches, content is junk
    _refused(env, env.service(installed=NEW_VERSION), 422, DETAIL_BACKUP_CORRUPT)


def test_previous_installer_missing_is_409_and_db_unchanged(env):
    _prepare(env, keep_previous=False)
    _refused(env, env.service(installed=NEW_VERSION), 409, DETAIL_PREVIOUS_INSTALLER_MISSING)


def test_previous_installer_with_wrong_hash_is_409(env):
    _prepare(env, keep_previous=False)
    env.keep_previous_installer(data=b"Z" * len(OLD_INSTALLER))
    _refused(env, env.service(installed=NEW_VERSION), 409, DETAIL_PREVIOUS_INSTALLER_MISSING)


def test_no_previous_block_is_409(env):
    _prepare(env, manifest=sign(env.key, payload(previous=None)))
    _refused(env, env.service(installed=NEW_VERSION), 409, DETAIL_NO_ROLLBACK_AVAILABLE)


def test_previous_version_not_the_from_version_is_409(env):
    _prepare(env, manifest=sign(env.key, payload(previous=("2.0.1", OLD_INSTALLER))))
    _refused(env, env.service(installed=NEW_VERSION), 409, DETAIL_NO_ROLLBACK_AVAILABLE)


def test_already_on_previous_version_is_409(env):
    _prepare(env)
    _refused(env, env.service(installed=OLD_VERSION), 409, DETAIL_ALREADY_ON_PREVIOUS)


def test_tampered_manifest_raw_is_409(env):
    raw = sign(env.key, payload()).decode("utf-8").replace("2.0.3", "2.0.2")
    _prepare(env)
    env.write_last_update_result(raw.encode("utf-8"), sha256_file(env.backups_dir / BACKUP_NAME))
    _refused(env, env.service(installed=NEW_VERSION), 409, DETAIL_NO_ROLLBACK_AVAILABLE)


def test_no_last_result_is_409(env):
    env.take_pre_update_backup()
    insert_items(env.db_path, LATER_ROWS)
    env.keep_previous_installer()
    _refused(env, env.service(installed=NEW_VERSION), 409, DETAIL_NO_ROLLBACK_AVAILABLE)


def test_last_result_of_a_rollback_is_409(env):
    _prepare(env, kind="rollback")
    _refused(env, env.service(installed=NEW_VERSION), 409, DETAIL_NO_ROLLBACK_AVAILABLE)


# ─── failures after the changes started ─────────────────────────────────────

def test_aside_copy_fails_is_500_db_unchanged_maintenance_cleared(env, monkeypatch):
    _prepare(env)
    real = update_service.sqlite_online_backup

    def fail_aside(src, dest, **kwargs):
        if str(dest).endswith(".db") and "pre_restore_" in str(dest):
            raise OSError("disk full")
        return real(src, dest, **kwargs)

    monkeypatch.setattr(update_service, "sqlite_online_backup", fail_aside)
    service = env.service(installed=NEW_VERSION)
    with pytest.raises(HTTPException) as exc:
        service.rollback(BACKUP_NAME, confirm=True, actor="admin")
    assert exc.value.status_code == 500
    assert exc.value.detail == DETAIL_ASIDE_FAILED
    assert item_names(env.db_path) == ORIGINAL_ROWS + LATER_ROWS  # nothing restored
    assert audit_actions(env.db_path) == [("UPDATE_ROLLBACK_FAILED", "admin", OLD_VERSION)]
    assert is_maintenance_mode() is False
    assert env.launcher.calls == []
    assert not (env.data_dir / PENDING_FILE).exists()
    assert service.get_status().state == "failed"


def test_restore_fails_is_500_and_maintenance_stays_on(env, monkeypatch):
    _prepare(env)
    real = update_service.sqlite_online_backup

    def fail_restore(src, dest, **kwargs):
        if kwargs.get("overwrite"):
            raise OSError("restore failed")
        return real(src, dest, **kwargs)

    monkeypatch.setattr(update_service, "sqlite_online_backup", fail_restore)
    service = env.service(installed=NEW_VERSION)
    with pytest.raises(HTTPException) as exc:
        service.rollback(BACKUP_NAME, confirm=True, actor="admin")
    assert exc.value.status_code == 500
    assert exc.value.detail == DETAIL_RESTORE_FAILED
    assert is_maintenance_mode() is True
    assert env.launcher.calls == []
    assert not (env.data_dir / PENDING_FILE).exists()
    assert (service.get_status().state, service.get_status().error_code) == ("failed", "restore_failed")
    assert list(env.backups_dir.glob("pre_restore_failed_v2.1.0_*.db"))  # the aside copy exists


def test_launch_fails_is_500_with_path_and_maintenance_stays_on(env):
    _prepare(env)
    env.launcher.raises = OSError("CreateProcess failed")
    service = env.service(installed=NEW_VERSION)
    with pytest.raises(HTTPException) as exc:
        service.rollback(BACKUP_NAME, confirm=True, actor="admin")
    previous = env.data_dir / "installers" / installer_name(OLD_VERSION)
    assert exc.value.status_code == 500
    assert exc.value.detail == (
        f"تم استرجاع قاعدة البيانات لكن تعذّر تشغيل برنامج التثبيت السابق. شغّله يدوياً من: {previous}"
    )
    assert is_maintenance_mode() is True
    assert not (env.data_dir / PENDING_FILE).exists()
    assert item_names(env.db_path) == ORIGINAL_ROWS  # the restore already happened
    assert previous.exists()


def test_previous_installer_swapped_during_restore_is_not_launched(env, monkeypatch):
    _prepare(env)
    real = update_service.sqlite_online_backup
    previous = env.data_dir / "installers" / installer_name(OLD_VERSION)

    def restore_then_swap(src, dest, **kwargs):
        result = real(src, dest, **kwargs)
        if kwargs.get("overwrite"):
            previous.write_bytes(b"Q" * len(OLD_INSTALLER))
        return result

    monkeypatch.setattr(update_service, "sqlite_online_backup", restore_then_swap)
    with pytest.raises(HTTPException) as exc:
        env.service(installed=NEW_VERSION).rollback(BACKUP_NAME, confirm=True, actor="admin")
    assert exc.value.status_code == 500
    assert exc.value.detail == DETAIL_ROLLBACK_INSTALLER_TAMPERED
    assert env.launcher.calls == []
    assert not previous.exists()
    assert is_maintenance_mode() is True
    assert not (env.data_dir / PENDING_FILE).exists()


# ─── rollback only from exactly the updated version (review item 4) ─────────

def test_installed_other_than_the_updated_version_is_409(env):
    _prepare(env)
    _refused(env, env.service(installed="2.2.0"), 409, DETAIL_NO_ROLLBACK_AVAILABLE)


def test_manifest_for_another_version_is_409(env):
    _prepare(env, manifest=sign(env.key, payload(version="2.1.1")))
    _refused(env, env.service(installed=NEW_VERSION), 409, DETAIL_NO_ROLLBACK_AVAILABLE)


# ─── startup maintenance survives rollback failures (review item 1) ─────────

STARTUP_REASON = "R8: migration e1f2 failed"


def test_aside_failure_keeps_startup_maintenance_and_reason(env, monkeypatch):
    _prepare(env)
    enter_maintenance_mode(STARTUP_REASON)
    real = update_service.sqlite_online_backup

    def fail_aside(src, dest, **kwargs):
        if "pre_restore_" in str(dest):
            raise OSError("disk full")
        return real(src, dest, **kwargs)

    monkeypatch.setattr(update_service, "sqlite_online_backup", fail_aside)
    with pytest.raises(HTTPException):
        env.service(installed=NEW_VERSION).rollback(BACKUP_NAME, confirm=True, actor="admin")
    assert is_maintenance_mode() is True
    assert maintenance_reason() == STARTUP_REASON


def test_successful_rollback_keeps_the_startup_reason(env):
    _prepare(env)
    enter_maintenance_mode(STARTUP_REASON)
    env.service(installed=NEW_VERSION).rollback(BACKUP_NAME, confirm=True, actor="admin")
    assert maintenance_reason() == STARTUP_REASON


# ─── the backup is re-verified right before the restore (review item 6) ─────

def test_backup_changed_after_the_checks_is_422_and_db_untouched(env, monkeypatch):
    _prepare(env)
    enter_maintenance_mode(STARTUP_REASON)
    real = update_service.sqlite_online_backup
    backup = env.backups_dir / BACKUP_NAME

    def aside_then_tamper(src, dest, **kwargs):
        result = real(src, dest, **kwargs)
        if "pre_restore_" in str(dest):
            data = bytearray(backup.read_bytes())
            data[-1] ^= 0xFF
            backup.write_bytes(bytes(data))
        return result

    monkeypatch.setattr(update_service, "sqlite_online_backup", aside_then_tamper)
    service = env.service(installed=NEW_VERSION)
    with pytest.raises(HTTPException) as exc:
        service.rollback(BACKUP_NAME, confirm=True, actor="admin")
    assert (exc.value.status_code, exc.value.detail) == (422, DETAIL_BACKUP_CORRUPT)
    assert item_names(env.db_path) == ORIGINAL_ROWS + LATER_ROWS
    assert env.launcher.calls == []
    assert maintenance_reason() == STARTUP_REASON
    assert service.get_status().error_code == "backup_corrupt"
    assert not list(env.backups_dir.glob(".rollback_source_*"))
    assert not (env.data_dir / "rollback_blocked.json").exists()


def test_backup_changed_without_prior_maintenance_clears_it(env, monkeypatch):
    _prepare(env)
    real = update_service.sqlite_online_backup
    backup = env.backups_dir / BACKUP_NAME

    def aside_then_tamper(src, dest, **kwargs):
        result = real(src, dest, **kwargs)
        if "pre_restore_" in str(dest):
            backup.write_bytes(b"garbage")
        return result

    monkeypatch.setattr(update_service, "sqlite_online_backup", aside_then_tamper)
    with pytest.raises(HTTPException):
        env.service(installed=NEW_VERSION).rollback(BACKUP_NAME, confirm=True, actor="admin")
    assert is_maintenance_mode() is False


def test_restore_uses_a_private_copy_that_is_removed(env, monkeypatch):
    _prepare(env)
    real = update_service.sqlite_online_backup
    sources = []

    def spy(src, dest, **kwargs):
        if kwargs.get("overwrite"):
            sources.append(Path(src))
        return real(src, dest, **kwargs)

    monkeypatch.setattr(update_service, "sqlite_online_backup", spy)
    env.service(installed=NEW_VERSION).rollback(BACKUP_NAME, confirm=True, actor="admin")
    assert len(sources) == 1 and sources[0].name.startswith(".rollback_source_")
    assert sources[0].parent == env.backups_dir
    assert not sources[0].exists()
    assert (env.backups_dir / BACKUP_NAME).exists()  # the original backup is kept


# ─── audit / history never decide the outcome (review item 8) ───────────────

def test_step_13_errors_do_not_leave_the_state_stuck(env, monkeypatch):
    from modules.app_update.service import UpdateService

    _prepare(env)

    def broken(self, actor, action, version, reason=None):
        raise ValueError("not an SQLAlchemy error")

    monkeypatch.setattr(UpdateService, "_audit_in_fresh_session", broken)
    service = env.service(installed=NEW_VERSION)
    assert service.rollback(BACKUP_NAME, confirm=True, actor="admin").state == "installing"
    assert service.get_status().state == "installing"
    assert len(env.launcher.calls) == 1


def test_launch_failure_is_audited_as_failed(env):
    _prepare(env)
    env.launcher.raises = OSError("CreateProcess failed")
    with pytest.raises(HTTPException):
        env.service(installed=NEW_VERSION).rollback(BACKUP_NAME, confirm=True, actor="admin")
    assert audit_actions(env.db_path) == [
        ("UPDATE_ROLLBACK", "admin", OLD_VERSION),
        ("UPDATE_ROLLBACK_FAILED", "admin", OLD_VERSION),
    ]


# ─── restart after a failed rollback stays in maintenance (review item 9) ───

def _block(env):
    path = env.data_dir / "rollback_blocked.json"
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else None


@pytest.mark.parametrize("failure", ["launch", "tampered", "restore"])
def test_failed_rollback_after_restore_blocks_the_newer_binary(env, monkeypatch, failure):
    _prepare(env)
    previous = env.data_dir / "installers" / installer_name(OLD_VERSION)
    if failure == "launch":
        env.launcher.raises = OSError("CreateProcess failed")
    else:
        real = update_service.sqlite_online_backup

        def hook(src, dest, **kwargs):
            if kwargs.get("overwrite") and failure == "restore":
                raise OSError("restore failed")
            result = real(src, dest, **kwargs)
            if kwargs.get("overwrite"):
                previous.write_bytes(b"Q" * len(OLD_INSTALLER))
            return result

        monkeypatch.setattr(update_service, "sqlite_online_backup", hook)
    with pytest.raises(HTTPException):
        env.service(installed=NEW_VERSION).rollback(BACKUP_NAME, confirm=True, actor="admin")

    block = _block(env)
    assert block["reason"] == {"launch": "launch_failed", "tampered": "installer_tampered",
                               "restore": "restore_failed"}[failure]
    assert block["from_version"] == NEW_VERSION and block["to_version"] == OLD_VERSION
    assert block["db_path"] == str(env.db_path)
    # restart of the newer binary: the startup upgrade asks this before migrating
    reason = rollback_pending_reason(env.db_path, installed_version=NEW_VERSION, data_dir=env.data_dir)
    assert reason and "rollback pending" in reason and str(previous) in reason
    # the older version installed manually: no block
    assert rollback_pending_reason(env.db_path, installed_version=OLD_VERSION, data_dir=env.data_dir) is None
    # another DB (source run sharing the update dir, K4): no block
    assert rollback_pending_reason(env.tmp / "other.db", installed_version=NEW_VERSION,
                                   data_dir=env.data_dir) is None


def test_restore_failure_writes_no_audit_into_the_uncertain_db(env, monkeypatch):
    _prepare(env)
    real = update_service.sqlite_online_backup

    def fail_restore(src, dest, **kwargs):
        if kwargs.get("overwrite"):
            raise OSError("restore failed")
        return real(src, dest, **kwargs)

    monkeypatch.setattr(update_service, "sqlite_online_backup", fail_restore)
    with pytest.raises(HTTPException):
        env.service(installed=NEW_VERSION).rollback(BACKUP_NAME, confirm=True, actor="admin")
    assert audit_actions(env.db_path) == []


def test_successful_rollback_clears_an_old_block(env):
    _prepare(env)
    env.repo.save_rollback_block({"reason": "launch_failed", "db_path": str(env.db_path), "to_version": OLD_VERSION})
    env.service(installed=NEW_VERSION).rollback(BACKUP_NAME, confirm=True, actor="admin")
    assert _block(env) is None


def test_block_is_cleared_once_the_older_version_runs(env):
    _prepare(env)
    env.launcher.raises = OSError("CreateProcess failed")
    with pytest.raises(HTTPException):
        env.service(installed=NEW_VERSION).rollback(BACKUP_NAME, confirm=True, actor="admin")
    clear_maintenance_mode()
    env.service(installed=NEW_VERSION).evaluate_pending_update()  # newer binary restarted: block stays
    assert _block(env) is not None
    env.service(installed=OLD_VERSION).evaluate_pending_update()  # the older installer was run by hand
    assert _block(env) is None
    assert "rollback_block_cleared" in events(env.data_dir)


def test_rollback_pending_reason_without_a_block_is_none(env):
    assert rollback_pending_reason(env.db_path, installed_version=NEW_VERSION, data_dir=env.data_dir) is None


@pytest.mark.parametrize("content", [
    b"{not json", b"", b"   ", b"null", b"[]", b'"text"', b"42", b"\xff\xfe\x00garbage",
    b'{"reason": "launch_failed", "to_version": "2.0.3"}',          # no db_path
    b'{"db_path": "", "to_version": "2.0.3"}',                        # empty db_path
    b'{"db_path": 17, "to_version": "2.0.3"}',                        # db_path not a string
], ids=["bad_json", "empty", "blank", "null", "list", "string", "number", "not_utf8",
        "missing_db_path", "empty_db_path", "db_path_not_str"])
def test_broken_block_fails_closed(env, content):
    from modules.app_update.repository import ROLLBACK_BLOCK_UNREADABLE_REASON

    env.data_dir.mkdir(parents=True, exist_ok=True)
    (env.data_dir / "rollback_blocked.json").write_bytes(content)
    reason = rollback_pending_reason(env.db_path, installed_version=NEW_VERSION, data_dir=env.data_dir)
    assert reason == ROLLBACK_BLOCK_UNREADABLE_REASON
    assert "rollback state file unreadable" in reason and "ملف حالة التراجع تالف" in reason
    # even when the older version is installed: an unreadable block is never silently ignored
    assert rollback_pending_reason(env.db_path, installed_version=OLD_VERSION, data_dir=env.data_dir) == reason


def test_unreadable_block_fails_closed(env):
    from modules.app_update.repository import ROLLBACK_BLOCK_UNREADABLE_REASON

    (env.data_dir / "rollback_blocked.json").mkdir(parents=True)  # exists, but reading it raises OSError
    assert rollback_pending_reason(env.db_path, installed_version=NEW_VERSION,
                                   data_dir=env.data_dir) == ROLLBACK_BLOCK_UNREADABLE_REASON


def test_valid_block_for_another_db_is_none(env):
    env.repo.save_rollback_block({"reason": "launch_failed", "db_path": str(env.tmp / "other" / "x.db"),
                                  "to_version": OLD_VERSION, "installer_path": "X"})
    assert rollback_pending_reason(env.db_path, installed_version=NEW_VERSION, data_dir=env.data_dir) is None


def test_valid_block_reason_is_bilingual(env):
    env.repo.save_rollback_block({"reason": "launch_failed", "db_path": str(env.db_path),
                                  "to_version": OLD_VERSION, "installer_path": "C:/x/setup.exe"})
    reason = rollback_pending_reason(env.db_path, installed_version=NEW_VERSION, data_dir=env.data_dir)
    assert "rollback pending" in reason and "C:/x/setup.exe" in reason and "يدوياً" in reason


def test_rollback_pending_reason_defaults_to_the_env_update_dir(env, monkeypatch):
    monkeypatch.setenv("UPDATE_DATA_DIR", str(env.data_dir))
    UpdateFileRepository(env.data_dir).save_rollback_block(
        {"reason": "launch_failed", "db_path": str(env.db_path), "to_version": OLD_VERSION, "installer_path": "X"}
    )
    assert rollback_pending_reason(env.db_path, installed_version=NEW_VERSION)


def test_atomic_writes_are_fsynced(env, monkeypatch):
    import os as _os

    synced = []
    real = _os.fsync
    monkeypatch.setattr(_os, "fsync", lambda fd: (synced.append(fd), real(fd))[1])
    env.repo.save_rollback_block({"db_path": str(env.db_path)})
    assert synced
