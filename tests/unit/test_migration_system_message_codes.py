"""
Alembic migration d8e9f0a1b2c3 (stage notes & attachments): creates two new tables.

- BEHIND DB at c7d8e9f0a1b2 without stage_notes tables: startup upgrade adds them via Alembic.
- UNSTAMPED legacy DB: startup stamps head; new tables already present via create_all.
- A create_all DB already has everything: upgrade is a no-op. Downgrade drops the tables.
"""
import sqlite3
from pathlib import Path

import pytest
from alembic import command
from sqlalchemy import create_engine

import database.schema_upgrade_service as sus
import main  # noqa: F401  (registers every model on Base.metadata)
from database import migration_runner
from database.database import Base
from database.schema_upgrade_service import SchemaUpgradeService
from utils import db_safety

# The revision this migration builds on top of
PREVIOUS = "c7d8e9f0a1b2"

# The new head revision (stage notes & attachments)
HEAD = "b8d2f4a6c1e3"

# This migration adds NO columns to existing tables — only creates new tables
NEW_COLUMNS = {}
NEW_INDEXES = {}

# Tables created by d8e9f0a1b2c3
NEW_TABLES = ["stage_notes", "stage_note_attachments", "master_items", "item_supplier_catalog", "item_price_history"]

# Columns/indexes added by earlier migrations (still present at PREVIOUS — kept for reference)
LEGACY_COLUMNS = {
    "smart_tasks": ["msg_code", "msg_params", "step_code"],
    "system_notifications": ["msg_code", "msg_params"],
    "shipment_stage_activity": ["msg_code", "msg_params"],
    "import_files": [
        "current_step_code", "current_phase_id", "current_stage_code",
        "next_action_code", "next_action_params", "hold_reason_code",
    ],
    "guide_entries": ["msg_code", "msg_params"],
    "inbound_email_logs": ["msg_code", "msg_params"],
    "email_settings": ["msg_code", "msg_params"],
}
LEGACY_INDEXES = {"idx_smart_tasks_step_code": "smart_tasks", "idx_import_files_current_phase_id": "import_files"}


class _NoMasterData:
    def __init__(self, session):
        pass

    def sync_all(self):
        return {"status": "stub"}


def _columns(db_file: Path, table: str):
    conn = sqlite3.connect(db_file)
    try:
        return {row[1]: row for row in conn.execute(f'PRAGMA table_info("{table}")')}
    finally:
        conn.close()


def _indexes(db_file: Path, table: str):
    conn = sqlite3.connect(db_file)
    try:
        return {row[1] for row in conn.execute(f'PRAGMA index_list("{table}")')}
    finally:
        conn.close()


def _existing_tables(db_file: Path) -> set:
    conn = sqlite3.connect(db_file)
    try:
        return {row[0] for row in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    finally:
        conn.close()


def _legacy_db(db_file: Path, stamp: str = None) -> None:
    """DB at PREVIOUS revision: full schema minus the NEW_TABLES introduced by d8e9f0a1b2c3.

    Note: LEGACY_INDEXES are also dropped so that unstamped-startup tests can verify
    SchemaUpgradeService re-creates them. LEGACY_COLUMNS are kept intact because
    they already exist at PREVIOUS=c7d8e9f0a1b2.
    """
    engine = create_engine(f"sqlite:///{db_file.as_posix()}")
    try:
        Base.metadata.create_all(bind=engine)
    finally:
        engine.dispose()
    conn = sqlite3.connect(db_file)
    try:
        # Drop legacy indexes (so startup can re-create them — tests validate this)
        for index in LEGACY_INDEXES:
            conn.execute(f'DROP INDEX IF EXISTS "{index}"')
        # Drop the tables that d8e9f0a1b2c3 would create — simulate pre-migration state
        # (drop attachments first due to FK dependency)
        conn.execute('DROP TABLE IF EXISTS "item_price_history"')
        conn.execute('DROP TABLE IF EXISTS "item_supplier_catalog"')
        conn.execute('DROP TABLE IF EXISTS "master_items"')
        conn.execute('DROP TABLE IF EXISTS "stage_note_attachments"')
        conn.execute('DROP TABLE IF EXISTS "stage_notes"')
        conn.execute(
            "INSERT INTO system_notifications (title, message, severity, category, target_role, is_read, created_at, updated_at) "
            "VALUES ('تنبيه قديم', 'رسالة قديمة', 'INFO', 'SYSTEM', 'ALL', 0, '2026-01-01', '2026-01-01')"
        )
        if stamp:
            conn.execute("CREATE TABLE alembic_version (version_num VARCHAR(32) NOT NULL)")
            conn.execute("INSERT INTO alembic_version (version_num) VALUES (?)", (stamp,))
        conn.commit()
    finally:
        conn.close()



def _assert_new_tables_present(db_file: Path):
    """Verify that tables added by d8e9f0a1b2c3 are present."""
    existing = _existing_tables(db_file)
    for table in NEW_TABLES:
        assert table in existing, f"Expected table '{table}' to exist after migration d8e9f0a1b2c3"


def _assert_new_tables_absent(db_file: Path):
    """Verify that tables added by d8e9f0a1b2c3 were removed by downgrade."""
    existing = _existing_tables(db_file)
    for table in NEW_TABLES:
        assert table not in existing, f"Table '{table}' should be dropped after downgrade to {PREVIOUS}"


def _startup(db_file: Path, monkeypatch):
    db_safety.clear_maintenance_mode()
    monkeypatch.setattr(sus, "MasterDataSyncService", _NoMasterData)
    monkeypatch.setattr(SchemaUpgradeService, "_get_version_tag", staticmethod(lambda: "9.9.9"))
    engine = create_engine(f"sqlite:///{db_file.as_posix()}")
    try:
        return SchemaUpgradeService.execute_safe_startup_upgrade(
            db_path=str(db_file), target_engine=engine, metadata=Base.metadata
        )
    finally:
        engine.dispose()
        db_safety.clear_maintenance_mode()


def test_head_is_c8d3():
    assert migration_runner.get_head_revision() == HEAD


def test_behind_db_is_upgraded_by_alembic(tmp_path, monkeypatch):
    """DB stamped at PREVIOUS (c7d8e9f0a1b2) without stage_notes tables: startup upgrades to HEAD."""
    db_file = tmp_path / "sorour_logistics.db"
    _legacy_db(db_file, stamp=PREVIOUS)
    # Confirm stage_notes tables are absent before upgrade
    assert "stage_notes" not in _existing_tables(db_file)
    assert "stage_note_attachments" not in _existing_tables(db_file)
    # Legacy columns from earlier migrations must still be intact at PREVIOUS
    assert "msg_code" in _columns(db_file, "smart_tasks")

    res = _startup(db_file, monkeypatch)

    assert res["status"] == "upgraded_successfully", res
    assert res["migration"]["action"] == "upgraded"
    assert res["migration"]["from_revision"] == PREVIOUS
    assert res["migration"]["to_revision"] == HEAD
    _assert_new_tables_present(db_file)
    conn = sqlite3.connect(db_file)
    try:
        assert conn.execute("SELECT version_num FROM alembic_version").fetchall() == [(HEAD,)]
    finally:
        conn.close()


def test_unstamped_legacy_db_gets_columns_and_indexes_then_stamped(tmp_path, monkeypatch):
    """Unstamped DB (no alembic_version): startup stamps HEAD; new tables present via create_all."""
    db_file = tmp_path / "sorour_logistics.db"
    _legacy_db(db_file, stamp=None)

    res = _startup(db_file, monkeypatch)

    assert res["status"] == "upgraded_successfully", res
    assert res["migration"]["state"] == "unstamped"
    assert res["migration"]["action"] == "stamped"
    # d8e9f0a1b2c3 creates tables (not columns), so columns_added should not include NEW_TABLES columns
    # but legacy indexes should be re-added
    assert set(LEGACY_INDEXES) <= set(res["indexes_added"])
    _assert_new_tables_present(db_file)


def test_upgrade_is_a_no_op_on_a_create_all_db_and_downgrade_removes_tables(tmp_path):
    """create_all DB already has stage_notes tables: upgrade is no-op. Downgrade drops them."""
    db_file = tmp_path / "created.db"
    engine = create_engine(f"sqlite:///{db_file.as_posix()}")
    try:
        Base.metadata.create_all(bind=engine)
        conn = sqlite3.connect(db_file)
        conn.execute("CREATE TABLE alembic_version (version_num VARCHAR(32) NOT NULL)")
        conn.execute("INSERT INTO alembic_version (version_num) VALUES (?)", (PREVIOUS,))
        conn.commit()
        conn.close()
        # Tables already exist — upgrade should be a no-op (migration uses defensive IF NOT EXISTS)
        assert migration_runner.upgrade_to_head(engine) == HEAD
        _assert_new_tables_present(db_file)

        # Downgrade should remove the new tables
        with engine.connect() as connection:
            command.downgrade(migration_runner.build_alembic_config(connection), PREVIOUS)
            connection.commit()
    finally:
        engine.dispose()
    _assert_new_tables_absent(db_file)


def _drop(db_file: Path, *names: str) -> None:
    conn = sqlite3.connect(db_file)
    try:
        for name in names:
            conn.execute(f'DROP INDEX IF EXISTS "{name}"')
        conn.commit()
    finally:
        conn.close()


def test_index_step_scope_and_safety(tmp_path):
    db_file = tmp_path / "idx.db"
    engine = create_engine(f"sqlite:///{db_file.as_posix()}")
    try:
        Base.metadata.create_all(bind=engine)
        _drop(db_file, "idx_smart_tasks_step_code", "idx_smart_tasks_status", "ix_smart_tasks_task_code")
        # BEHIND / up to date: only indexes on columns 4b just added; unique and unknown tables skipped.
        assert SchemaUpgradeService._create_missing_indexes(
            engine, Base.metadata, ["no_such_table.x", "smart_tasks.task_code", "smart_tasks.step_code"]
        ) == ["idx_smart_tasks_step_code"]
        assert SchemaUpgradeService._create_missing_indexes(engine, Base.metadata, []) == []
        # FRESH / UNSTAMPED: every missing non-unique model index, never a unique one; existing ones not re-reported.
        created = SchemaUpgradeService._create_missing_indexes(engine, Base.metadata, [], all_tables=True)
    finally:
        engine.dispose()
    assert created == ["idx_smart_tasks_status"]
    indexes = _indexes(db_file, "smart_tasks")
    assert "idx_smart_tasks_status" in indexes and "ix_smart_tasks_task_code" not in indexes


def test_unstamped_db_also_gets_older_missing_indexes(tmp_path, monkeypatch):
    db_file = tmp_path / "sorour_logistics.db"
    _legacy_db(db_file, stamp=None)
    _drop(db_file, "idx_smart_tasks_status")
    res = _startup(db_file, monkeypatch)
    assert res["status"] == "upgraded_successfully", res
    assert {"idx_smart_tasks_status", "idx_smart_tasks_step_code", "idx_import_files_current_phase_id"} <= set(
        res["indexes_added"]
    )
    assert "idx_smart_tasks_status" in _indexes(db_file, "smart_tasks")
