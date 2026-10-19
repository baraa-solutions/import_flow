"""
Alembic b7c1d2e3f4a5 (system message codes) + c8d3e4f5a6b7 (email listener codes): additive, defensive
columns + indexes.

- BEHIND DB at f7a1c3e5b9d2 without the columns: startup upgrade adds them through Alembic.
- UNSTAMPED legacy DB: startup step 4b adds the columns and 4c their indexes, then stamps head.
- A create_all DB already has everything: upgrade is a no-op. Downgrade removes the columns.
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

PREVIOUS = "f7a1c3e5b9d2"


HEAD = "c9d0e1f2a3b4"  # current head (user token version BEX-T08)

NEW_COLUMNS = {
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
NEW_INDEXES = {"idx_smart_tasks_step_code": "smart_tasks", "idx_import_files_current_phase_id": "import_files"}


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


def _legacy_db(db_file: Path, stamp: str = None) -> None:
    """Current schema minus the b7c1 columns/indexes, with one legacy row per touched table."""
    engine = create_engine(f"sqlite:///{db_file.as_posix()}")
    try:
        Base.metadata.create_all(bind=engine)
    finally:
        engine.dispose()
    conn = sqlite3.connect(db_file)
    try:
        for index in NEW_INDEXES:
            conn.execute(f'DROP INDEX IF EXISTS "{index}"')
        for table, cols in NEW_COLUMNS.items():
            for col in cols:
                conn.execute(f'ALTER TABLE "{table}" DROP COLUMN "{col}"')
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


def _assert_all_present(db_file: Path):
    for table, cols in NEW_COLUMNS.items():
        present = _columns(db_file, table)
        for col in cols:
            assert col in present, f"{table}.{col}"
            assert present[col][3] == 0  # nullable
            assert present[col][4] is None  # no server default
    for index, table in NEW_INDEXES.items():
        assert index in _indexes(db_file, table), index


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
    db_file = tmp_path / "sorour_logistics.db"
    _legacy_db(db_file, stamp=PREVIOUS)
    assert "msg_code" not in _columns(db_file, "smart_tasks")

    res = _startup(db_file, monkeypatch)

    assert res["status"] == "upgraded_successfully", res
    assert res["migration"]["action"] == "upgraded"
    assert res["migration"]["from_revision"] == PREVIOUS
    assert res["migration"]["to_revision"] == HEAD
    assert not any(c.startswith(("smart_tasks.msg", "import_files.current_step")) for c in res["columns_added"])
    _assert_all_present(db_file)
    conn = sqlite3.connect(db_file)
    try:
        assert conn.execute("SELECT msg_code, msg_params FROM system_notifications").fetchone() == (None, None)
        assert conn.execute("SELECT version_num FROM alembic_version").fetchall() == [(HEAD,)]
    finally:
        conn.close()


def test_unstamped_legacy_db_gets_columns_and_indexes_then_stamped(tmp_path, monkeypatch):
    db_file = tmp_path / "sorour_logistics.db"
    _legacy_db(db_file, stamp=None)

    res = _startup(db_file, monkeypatch)

    assert res["status"] == "upgraded_successfully", res
    assert res["migration"]["state"] == "unstamped"
    assert res["migration"]["action"] == "stamped"
    for table, cols in NEW_COLUMNS.items():
        for col in cols:
            assert f"{table}.{col}" in res["columns_added"]
    assert set(NEW_INDEXES) <= set(res["indexes_added"])
    _assert_all_present(db_file)


def test_upgrade_is_a_no_op_on_a_create_all_db_and_downgrade_removes_columns(tmp_path):
    db_file = tmp_path / "created.db"
    engine = create_engine(f"sqlite:///{db_file.as_posix()}")
    try:
        Base.metadata.create_all(bind=engine)
        conn = sqlite3.connect(db_file)
        conn.execute("CREATE TABLE alembic_version (version_num VARCHAR(32) NOT NULL)")
        conn.execute("INSERT INTO alembic_version (version_num) VALUES (?)", (PREVIOUS,))
        conn.commit()
        conn.close()
        before = {t: _columns(db_file, t) for t in NEW_COLUMNS}
        assert migration_runner.upgrade_to_head(engine) == HEAD
        assert {t: _columns(db_file, t) for t in NEW_COLUMNS} == before
        _assert_all_present(db_file)

        with engine.connect() as connection:
            command.downgrade(migration_runner.build_alembic_config(connection), PREVIOUS)
            connection.commit()
    finally:
        engine.dispose()
    for table, cols in NEW_COLUMNS.items():
        present = _columns(db_file, table)
        assert not any(c in present for c in cols), table
    for index, table in NEW_INDEXES.items():
        assert index not in _indexes(db_file, table)


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
