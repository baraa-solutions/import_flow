"""
R5 pre-update backup gate (spec §B.3 step 5): any backup failure, including low disk space, cancels the update with
500, clears maintenance mode, writes no marker and never calls the launcher.
"""
import sqlite3

import pytest
from fastapi import HTTPException

import modules.app_update.service as update_service
from app_update_testkit import NEW_VERSION, events, history, make_env
from modules.app_update.repository import PENDING_FILE
from modules.app_update.validators import DETAIL_BACKUP_FAILED
from utils.db_safety import BackupVerificationError, clear_maintenance_mode, is_maintenance_mode


@pytest.fixture(autouse=True)
def _no_maintenance_leak():
    clear_maintenance_mode()
    yield
    clear_maintenance_mode()


@pytest.fixture
def env(tmp_path, monkeypatch):
    return make_env(tmp_path, monkeypatch)


def _assert_cancelled(env, service, exc_info, detail_class: str):
    assert exc_info.value.status_code == 500
    assert exc_info.value.detail == DETAIL_BACKUP_FAILED
    assert env.launcher.calls == []
    assert not (env.data_dir / PENDING_FILE).exists()
    assert is_maintenance_mode() is False
    status = service.get_status()
    assert (status.state, status.error_code, status.error_detail) == ("failed", "backup_failed", DETAIL_BACKUP_FAILED)
    entry = [e for e in history(env.data_dir) if e["event"] == "backup_failed"]
    assert len(entry) == 1 and entry[0]["detail"] == detail_class
    assert "backup_ok" not in events(env.data_dir)
    assert "install_launched" not in events(env.data_dir)
    # the staged installer was not promoted: nothing moved toward installation
    assert not (env.data_dir / "installers").exists() or list((env.data_dir / "installers").iterdir()) == []


def test_sqlite_online_backup_raises(env, monkeypatch):
    service = env.ready_service()
    seen = {}

    def boom(src, dest, **kwargs):
        seen["maintenance_during_backup"] = is_maintenance_mode()
        raise sqlite3.OperationalError("disk I/O error")

    monkeypatch.setattr(update_service, "sqlite_online_backup", boom)
    with pytest.raises(HTTPException) as exc:
        service.apply(NEW_VERSION, actor="admin")
    assert seen["maintenance_during_backup"] is True  # writes were blocked while the copy ran
    _assert_cancelled(env, service, exc, "OperationalError")


def test_backup_verification_error(env, monkeypatch):
    service = env.ready_service()

    def bad_copy(src, dest, **kwargs):
        raise BackupVerificationError("integrity_check failed for copy")

    monkeypatch.setattr(update_service, "sqlite_online_backup", bad_copy)
    with pytest.raises(HTTPException) as exc:
        service.apply(NEW_VERSION, actor="admin")
    _assert_cancelled(env, service, exc, "BackupVerificationError")


def test_low_disk_space(env, monkeypatch):
    db_size = env.db_path.stat().st_size
    env.free_bytes = 2 * db_size + 50 * 1024 * 1024 - 1  # one byte short of the R5 margin
    service = env.ready_service()
    called = []
    monkeypatch.setattr(update_service, "sqlite_online_backup", lambda *a, **k: called.append(a))
    with pytest.raises(HTTPException) as exc:
        service.apply(NEW_VERSION, actor="admin")
    assert called == []  # refused before copying anything
    _assert_cancelled(env, service, exc, "_LowDiskSpace")
    assert not list(env.backups_dir.glob("pre_update_*"))


def test_exactly_enough_disk_space_proceeds(env):
    wal = env.db_path.with_name(env.db_path.name + "-wal")
    db_size = env.db_path.stat().st_size + (wal.stat().st_size if wal.exists() else 0)
    env.free_bytes = 2 * db_size + 50 * 1024 * 1024
    assert env.ready_service().apply(NEW_VERSION, actor="admin").state == "installing"


def test_missing_database_is_a_backup_failure(env):
    service = env.ready_service(db_path=env.app_dir / "absent.db")
    with pytest.raises(HTTPException) as exc:
        service.apply(NEW_VERSION, actor="admin")
    _assert_cancelled(env, service, exc, "FileNotFoundError")


# ─── a startup maintenance (R8/R10) survives every apply failure (review item 1) ─

STARTUP_REASON = "R10: database revision ffffffffffff is unknown to this version"


@pytest.mark.parametrize("failure", ["backup_raises", "low_disk", "rehash_2", "launch"])
def test_apply_failure_keeps_startup_maintenance_and_its_reason(env, monkeypatch, failure):
    from utils.db_safety import enter_maintenance_mode, maintenance_reason

    service = env.ready_service()
    enter_maintenance_mode(STARTUP_REASON)
    if failure == "backup_raises":
        def boom(src, dest, **kwargs):
            raise OSError("disk I/O error")
        monkeypatch.setattr(update_service, "sqlite_online_backup", boom)
    elif failure == "low_disk":
        env.free_bytes = 0
    elif failure == "rehash_2":
        real = update_service.sqlite_online_backup
        staged = env.data_dir / "staging" / "Sorour_Logistics_Setup_v2.1.0.exe"

        def swap(src, dest, **kwargs):
            result = real(src, dest, **kwargs)
            staged.write_bytes(b"Y" * staged.stat().st_size)
            return result
        monkeypatch.setattr(update_service, "sqlite_online_backup", swap)
    else:
        env.launcher.raises = OSError("CreateProcess failed")

    with pytest.raises(HTTPException):
        service.apply(NEW_VERSION, actor="admin")
    assert is_maintenance_mode() is True
    assert maintenance_reason() == STARTUP_REASON


def test_apply_does_not_overwrite_the_startup_reason(env):
    from utils.db_safety import enter_maintenance_mode, maintenance_reason

    service = env.ready_service()
    enter_maintenance_mode(STARTUP_REASON)
    assert service.apply(NEW_VERSION, actor="admin").state == "installing"
    assert maintenance_reason() == STARTUP_REASON


@pytest.mark.parametrize("failure", ["backup_raises", "launch"])
def test_apply_failure_without_prior_maintenance_clears_it(env, monkeypatch, failure):
    service = env.ready_service()
    if failure == "backup_raises":
        monkeypatch.setattr(update_service, "sqlite_online_backup",
                            lambda *a, **k: (_ for _ in ()).throw(OSError("x")))
    else:
        env.launcher.raises = OSError("x")
    with pytest.raises(HTTPException):
        service.apply(NEW_VERSION, actor="admin")
    assert is_maintenance_mode() is False


# ─── audit (review item 8) ───────────────────────────────────────────────────

def test_backup_failure_is_audited_as_failed_and_never_as_apply(env, monkeypatch):
    from app_update_testkit import audit_actions

    service = env.ready_service()
    monkeypatch.setattr(update_service, "sqlite_online_backup",
                        lambda *a, **k: (_ for _ in ()).throw(OSError("x")))
    session = env.session_factory()
    try:
        with pytest.raises(HTTPException):
            service.apply(NEW_VERSION, actor="admin", db=session)
    finally:
        session.close()
    assert audit_actions(env.db_path) == [("UPDATE_APPLY_FAILED", "admin", NEW_VERSION)]
