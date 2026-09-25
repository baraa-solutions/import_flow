"""
DB safety (docs/plans/update-system-plan.md section 0): backup retention (R9, A8, A10).

Every pruner keeps protected backups and at least the newest MIN_BACKUPS_KEPT of its own family;
the schema-upgrade pruner never removes the newest pre-upgrade snapshot.
"""
import os
import time
from pathlib import Path

import pytest

from database.schema_upgrade_service import SchemaUpgradeService
from utils.db_safety import MIN_BACKUPS_KEPT, is_protected_backup, same_file, select_prunable, unique_backup_name


def _touch(path: Path, age_seconds: float) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"x")
    ts = time.time() - age_seconds
    os.utime(path, (ts, ts))
    return path


@pytest.mark.parametrize("name,protected", [
    ("pre_install_2.0.3_20260101.db", True),
    ("pre_update_2.0.3_20260101.db", True),
    ("pre_migration_2.0.3_20260101.db", True),
    ("pre_restore_20260101.db", True),
    ("psync_sorour_logistics_pre_restore_prod_20260101_000000.db", True),
    ("PRE_INSTALL_upper.db", True),
    ("daily_backup_20260101_000000.db", False),
    ("auto_pre_upgrade_v2.0.3_20260101_000000.db", False),
    ("psync_sorour_logistics_manual_dev_20260101_000000.db", False),
])
def test_is_protected_backup_names(name, protected):
    assert is_protected_backup(Path("backups") / name) is protected


def test_files_inside_protected_folder_are_protected():
    assert is_protected_backup(Path("backups") / "pre_install_2.0.3_20260101" / "sorour_logistics.db")
    assert not is_protected_backup(Path("backups") / "misc" / "sorour_logistics.db")


def test_select_prunable_floors_keep_and_skips_protected(tmp_path):
    files = [_touch(tmp_path / f"own_{i:02d}.db", age_seconds=100 + i) for i in range(10)]
    protected = _touch(tmp_path / "own_pre_update_x.db", age_seconds=10_000)
    prunable = select_prunable(files + [protected], keep=0)
    assert protected not in prunable
    assert len(prunable) == 10 - MIN_BACKUPS_KEPT
    assert set(prunable) == set(files[MIN_BACKUPS_KEPT:])  # the oldest ones


def test_schema_upgrade_pruner_keeps_newest_n_and_other_families(tmp_path):
    backups = tmp_path / "backups"
    snaps = [
        _touch(backups / f"auto_pre_upgrade_v1.0.{i}_202601{i + 1:02d}_000000.db", age_seconds=1_000 - i)
        for i in range(20)
    ]
    others = [
        _touch(backups / "daily_backup_20200101_000000.db", 50_000),
        _touch(backups / "pre_install_1.0.0_20200101.db", 50_000),
        _touch(backups / "pre_update_1.0.0_20200101.db", 50_000),
        _touch(backups / "psync_sorour_logistics_manual_dev_20200101_000000.db", 50_000),
    ]
    removed = SchemaUpgradeService._prune_snapshots(backups, max_auto_backups=15, keep_path=snaps[-1])
    assert len(removed) == 5
    assert all(p.exists() for p in snaps[-15:])
    assert all(p.exists() for p in others)


def test_schema_upgrade_pruner_never_removes_newest_even_with_zero_retention(tmp_path):
    backups = tmp_path / "backups"
    snaps = [
        _touch(backups / f"auto_pre_upgrade_v1.0.{i}_202601{i + 1:02d}_000000.db", age_seconds=1_000 - i)
        for i in range(10)
    ]
    SchemaUpgradeService._prune_snapshots(backups, max_auto_backups=0, keep_path=None)
    assert snaps[-1].exists()
    assert sum(p.exists() for p in snaps) == MIN_BACKUPS_KEPT


def test_schema_upgrade_pruner_orders_by_name_timestamp_not_mtime(tmp_path):
    """A copy2-era snapshot inherits the DB mtime; the timestamp in the name decides what is newest."""
    backups = tmp_path / "backups"
    newest_by_name = _touch(backups / "auto_pre_upgrade_v2.0.0_20261231_235959.db", age_seconds=10_000_000)
    older = [
        _touch(backups / f"auto_pre_upgrade_v1.0.0_202601{i + 1:02d}_000000.db", age_seconds=10 + i)
        for i in range(10)
    ]
    SchemaUpgradeService._prune_snapshots(backups, max_auto_backups=1, keep_path=None)
    assert newest_by_name.exists()
    assert sum(p.exists() for p in older) == MIN_BACKUPS_KEPT - 1


# ---------------------------------------------------------------- shared helpers

def test_unique_backup_name_appends_counter_on_collision(tmp_path):
    stem = "pre_update_v2.0.0_to_v2.1.0_20260101_120000"
    assert unique_backup_name(stem, None) == f"{stem}.db"
    assert unique_backup_name(stem, tmp_path) == f"{stem}.db"
    (tmp_path / f"{stem}.db").write_bytes(b"x")
    assert unique_backup_name(stem, tmp_path) == f"{stem}_1.db"
    (tmp_path / f"{stem}_1.db").write_bytes(b"x")
    assert unique_backup_name(stem, str(tmp_path)) == f"{stem}_2.db"
    assert is_protected_backup(tmp_path / unique_backup_name(stem, tmp_path))


def test_same_file_resolves_and_ignores_case_on_windows(tmp_path):
    db = tmp_path / "sorour_logistics.db"
    db.write_bytes(b"x")
    assert same_file(db, tmp_path / "sub" / ".." / "sorour_logistics.db")
    assert same_file(str(db), db)
    assert not same_file(db, tmp_path / "other.db")
    if os.name == "nt":
        assert same_file(db, str(db).upper())


@pytest.mark.parametrize("a,b", [(None, "x.db"), ("x.db", None), ("", "x.db"), ("x.db", "")])
def test_same_file_empty_is_false(a, b):
    assert same_file(a, b) is False


def test_same_file_unresolvable_is_false(tmp_path):
    assert same_file(tmp_path / "a\x00b.db", tmp_path / "a\x00b.db") is False
