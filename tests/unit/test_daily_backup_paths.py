"""
scripts/daily_backup.py (docs/plans/update-system-plan.md A16, R9, R11, section 7).

- perform_backup(db_path=None, backups_dir=None) defaults to the app database (DATABASE_PATH, else
  <app dir>/sorour_logistics.db where the app dir is the exe folder when frozen) and backups/ next to it;
- retention keeps the newest 7 daily backups whatever their age and never touches protected backups
  or other backup families;
- the CLI is unchanged, and ``scripts.daily_backup`` is importable as a package module (backend.exe).

All on tmp_path; the offsite (Google Drive) step is stubbed so nothing leaves the temp folder.
"""
import hashlib
import importlib
import os
import sqlite3
import sys
import time
from pathlib import Path

import pytest

import scripts.daily_backup as daily_backup
from utils.db_safety import MIN_BACKUPS_KEPT, BackupVerificationError


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _make_db(path: Path) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.execute("CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT)")
    conn.execute("INSERT INTO items VALUES (1, 'kept')")
    conn.commit()
    conn.close()
    return path


def _touch(path: Path, age_days: float) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"x")
    ts = time.time() - age_days * 86400
    os.utime(path, (ts, ts))
    return path


@pytest.fixture(autouse=True)
def no_offsite(monkeypatch):
    calls = []

    def fake_sync(backup_path, meta_path, **kwargs):
        calls.append((backup_path, kwargs))
        return {"status": "SKIPPED", "reason": "TEST"}

    monkeypatch.setattr(daily_backup, "sync_to_google_drive", fake_sync)
    return calls


# ----------------------------------------------------------------------------
# Paths
# ----------------------------------------------------------------------------

def test_scripts_is_an_importable_package():
    import scripts

    assert scripts.__file__ is not None  # regular package (scripts/__init__.py), PyInstaller-friendly
    assert importlib.import_module("scripts.daily_backup") is daily_backup


def test_default_db_path_follows_database_path_env(monkeypatch, tmp_path):
    monkeypatch.setenv("DATABASE_PATH", str(tmp_path / "custom.db"))
    assert daily_backup.default_backup_db_path() == tmp_path / "custom.db"
    assert daily_backup.default_backups_dir() == (tmp_path / "backups").resolve()


def test_default_db_path_is_next_to_the_exe_when_frozen(monkeypatch, tmp_path):
    monkeypatch.delenv("DATABASE_PATH", raising=False)
    exe = tmp_path / "Sorour Logistics" / "backend.exe"
    exe.parent.mkdir()
    exe.write_bytes(b"")
    monkeypatch.setattr(sys, "frozen", True, raising=False)
    monkeypatch.setattr(sys, "executable", str(exe))
    monkeypatch.setattr(sys, "_MEIPASS", str(tmp_path / "_MEI12345"), raising=False)
    assert daily_backup.default_backup_db_path() == exe.parent.resolve() / "sorour_logistics.db"
    assert daily_backup.default_backups_dir() == exe.parent.resolve() / "backups"


def test_default_db_path_in_dev_is_the_repo_root(monkeypatch):
    monkeypatch.delenv("DATABASE_PATH", raising=False)
    repo_root = Path(__file__).resolve().parents[2]
    assert daily_backup.default_backup_db_path() == repo_root / "sorour_logistics.db"


# ----------------------------------------------------------------------------
# perform_backup
# ----------------------------------------------------------------------------

def test_perform_backup_defaults_to_database_path(monkeypatch, tmp_path, no_offsite):
    db = _make_db(tmp_path / "app" / "sorour_logistics.db")
    monkeypatch.setenv("DATABASE_PATH", str(db))
    before = _sha(db)

    backup = daily_backup.perform_backup(retention_days=30)

    assert backup.parent == (tmp_path / "app" / "backups").resolve()
    assert backup.name.startswith("daily_backup_")
    conn = sqlite3.connect(backup)
    assert conn.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
    assert conn.execute("SELECT name FROM items").fetchall() == [("kept",)]
    conn.close()
    assert backup.with_suffix(".json").exists()
    assert _sha(db) == before  # the source is only read
    assert len(no_offsite) == 1


def test_perform_backup_explicit_paths(tmp_path):
    db = _make_db(tmp_path / "somewhere" / "x.db")
    out = tmp_path / "elsewhere"
    backup = daily_backup.perform_backup(db_path=db, backups_dir=out)
    assert backup.parent == out
    assert not (db.parent / "backups").exists()


def test_perform_backup_twice_in_the_same_second_does_not_collide(tmp_path, monkeypatch):
    db = _make_db(tmp_path / "x.db")

    class FrozenNow:
        @staticmethod
        def now(tz=None):
            from datetime import datetime as real

            return real(2026, 9, 24, 23, 0, 0, tzinfo=tz)

        @staticmethod
        def fromtimestamp(ts, tz=None):
            from datetime import datetime as real

            return real.fromtimestamp(ts, tz=tz)

    monkeypatch.setattr(daily_backup, "datetime", FrozenNow)
    first = daily_backup.perform_backup(db_path=db)
    second = daily_backup.perform_backup(db_path=db)
    assert first != second and first.exists() and second.exists()


def test_perform_backup_missing_source_creates_nothing(tmp_path):
    with pytest.raises(FileNotFoundError):
        daily_backup.perform_backup(db_path=tmp_path / "missing.db", backups_dir=tmp_path / "b")
    assert not (tmp_path / "missing.db").exists()
    assert not (tmp_path / "b").exists()


def test_perform_backup_failed_verification_leaves_no_backup(tmp_path, monkeypatch):
    db = _make_db(tmp_path / "x.db")

    def bad_backup(src, dest, **kwargs):
        raise BackupVerificationError("integrity_check failed")

    monkeypatch.setattr(daily_backup, "sqlite_online_backup", bad_backup)
    with pytest.raises(RuntimeError):
        daily_backup.perform_backup(db_path=db)
    assert list((tmp_path / "backups").glob("daily_backup_*")) == []


# ----------------------------------------------------------------------------
# Retention (R9)
# ----------------------------------------------------------------------------

def test_retention_keeps_newest_seven_even_when_all_are_old(tmp_path):
    backups = tmp_path / "backups"
    daily = [_touch(backups / f"daily_backup_2025010{i}_000000.db", age_days=100 + i) for i in range(10)]
    pruned = daily_backup.prune_backups_in_dir(backups, retention_days=30)
    assert pruned == 10 - MIN_BACKUPS_KEPT
    kept = [p for p in daily if p.exists()]
    assert kept == daily[:MIN_BACKUPS_KEPT]  # the newest (smallest age) ones


def test_retention_never_touches_protected_or_other_families(tmp_path):
    backups = tmp_path / "backups"
    for i in range(12):
        _touch(backups / f"daily_backup_2025{i:04d}_000000.db", age_days=1 + i)
    others = [
        _touch(backups / "daily_backup_pre_restore_20200101.db", age_days=900),
        _touch(backups / "pre_update_2.0.3_20200101.db", age_days=900),
        _touch(backups / "pre_install_2.0.3_20200101.db", age_days=900),
        _touch(backups / "pre_migration_update_db_schema_x_20200101.db", age_days=900),
        _touch(backups / "auto_pre_upgrade_v1.0.0_20200101_000000.db", age_days=900),
        _touch(backups / "psync_sorour_logistics_manual_dev_20200101_000000.db", age_days=900),
    ]
    pruned = daily_backup.prune_backups_in_dir(backups, retention_days=30)
    assert pruned == 0  # every daily backup is younger than 30 days
    assert all(p.exists() for p in others)

    for i in range(3):
        _touch(backups / f"daily_backup_2019{i:04d}_000000.db", age_days=400 + i)
    pruned = daily_backup.prune_backups_in_dir(backups, retention_days=30)
    assert pruned == 3
    assert all(p.exists() for p in others)


def test_retention_keep_min_cannot_go_below_the_floor(tmp_path):
    backups = tmp_path / "backups"
    for i in range(9):
        _touch(backups / f"daily_backup_{i}.db", age_days=60 + i)
    assert daily_backup.prune_backups_in_dir(backups, retention_days=1, keep_min=0) == 9 - MIN_BACKUPS_KEPT


def test_perform_backup_runs_retention_in_its_own_backups_dir(tmp_path):
    db = _make_db(tmp_path / "app" / "x.db")
    backups = tmp_path / "app" / "backups"
    old = [_touch(backups / f"daily_backup_2020010{i}_000000.db", age_days=200 + i) for i in range(8)]
    daily_backup.perform_backup(db_path=db, retention_days=30)
    # 1 new + 8 old: the newest 7 stay (the new one + 6 old), 2 oldest are pruned
    assert sum(p.exists() for p in old) == MIN_BACKUPS_KEPT - 1


# ----------------------------------------------------------------------------
# CLI unchanged
# ----------------------------------------------------------------------------

def test_cli_flags_unchanged(monkeypatch, tmp_path):
    captured = {}
    monkeypatch.setattr(daily_backup, "perform_backup", lambda **kw: captured.update(kw))
    monkeypatch.setattr(
        sys, "argv", ["daily_backup.py", "--test", "--retention", "14", "--offsite-dir", str(tmp_path), "--no-encrypt"]
    )
    daily_backup.main()
    assert captured == {"retention_days": 14, "offsite_dir": tmp_path, "encrypt_offsite": False}
