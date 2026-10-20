"""
Unit tests for Database Integrity (BEX-T16).

Verifies:
1. SQLite PRAGMA foreign_keys = ON is enforced:
   - Inserting a child entity (e.g. ImportFile) with a non-existent foreign key (e.g. company_id=999999) raises IntegrityError.
   - Inserting with a valid foreign key succeeds.
2. Shipment stage activity uniqueness (BEX-F41):
   - Unique index `uq_shipment_stage_activity_file_step` prevents duplicate (import_file_code, step_code) pairs.
   - save_or_update_activity safely updates an existing row without violating the unique constraint.
3. Deduplication logic:
   - Existing duplicate rows in shipment_stage_activity are purged, retaining the newest row (highest id).
4. CI foreign key orphan report (scripts/ci/fk_orphan_report.py):
   - Returns 0 when no orphan rows exist.
   - Detects orphaned foreign keys when orphan data is present and reports offending tables and row IDs.
"""

import sqlite3
from pathlib import Path
import pytest
from sqlalchemy import create_engine, event, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.import_companies.model import ImportCompany
from modules.import_files.model import ImportFile
from modules.lifecycle_board.model import ShipmentStageActivity
from modules.lifecycle_board.repository import get_activity, save_or_update_activity
from scripts.ci.fk_orphan_report import check_foreign_keys, generate_report


@pytest.fixture
def integrity_engine(tmp_path):
    """
    Creates a scratch SQLite file engine with PRAGMA foreign_keys = ON,
    mirroring database/database.py configuration.
    """
    db_file = tmp_path / "integrity_test.db"
    engine = create_engine(
        f"sqlite:///{db_file.as_posix()}",
        connect_args={"check_same_thread": False},
    )

    @event.listens_for(engine, "connect")
    def _set_pragmas(dbapi_connection, connection_record):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys = ON;")
        cursor.close()

    Base.metadata.create_all(bind=engine)
    yield engine, db_file
    engine.dispose()


@pytest.fixture
def integrity_session(integrity_engine):
    engine, _ = integrity_engine
    factory = sessionmaker(bind=engine)
    session = factory()
    yield session
    session.close()


# ─── 1. Foreign Key Constraint Enforcement ────────────────────────────────────

from datetime import date

def test_foreign_key_enforcement_rejects_nonexistent_parent(integrity_session):
    """
    BEX-F26: With PRAGMA foreign_keys=ON, inserting an ImportFile with an invalid
    company_id must raise an IntegrityError rather than silently persisting an orphan.
    """
    orphan_file = ImportFile(
        import_file_code="IMP-2026-9999",
        company_id=999999,  # Non-existent company
        company_name="Ghost Company",
        supplier_name="Ghost Supplier",
        supplier_id=None,
        status="active",
        created_by="tester",
    )
    integrity_session.add(orphan_file)

    with pytest.raises(IntegrityError) as exc_info:
        integrity_session.commit()

    assert "FOREIGN KEY constraint failed" in str(exc_info.value)
    integrity_session.rollback()


def test_foreign_key_allows_valid_parent(integrity_session):
    """Inserting with a valid foreign key succeeds cleanly."""
    company = ImportCompany(
        importer_name="Valid Test Co",
        address="123 Test St",
        country="Egypt",
        importer_id="IMP-TEST-001",
        importer_id_expiry=date(2028, 1, 1),
        vat_id="VAT-TEST-001",
        vat_id_expiry=date(2028, 1, 1),
        registration_number="REG-TEST-001",
        registration_expiry=date(2028, 1, 1),
        is_active=True,
    )
    integrity_session.add(company)
    integrity_session.commit()
    integrity_session.refresh(company)

    valid_file = ImportFile(
        import_file_code="IMP-2026-0001",
        company_id=company.company_id,
        company_name=company.importer_name,
        supplier_name="Valid Supplier",
        supplier_id=None,
        status="active",
        created_by="tester",
    )
    integrity_session.add(valid_file)
    integrity_session.commit()
    assert valid_file.import_file_id is not None


# ─── 2. Shipment Stage Activity Uniqueness ────────────────────────────────────

def test_shipment_stage_activity_uniqueness_constraint(integrity_session):
    """
    BEX-F41: Attempting to insert two ShipmentStageActivity rows with the same
    (import_file_code, step_code) pair must violate the unique index.
    """
    act1 = ShipmentStageActivity(
        import_file_code="IMP-2026-0001",
        step_code="STEP_01",
        status="In-Progress",
    )
    integrity_session.add(act1)
    integrity_session.commit()

    # Second row with the same file and step
    act2 = ShipmentStageActivity(
        import_file_code="IMP-2026-0001",
        step_code="STEP_01",
        status="Completed",
    )
    integrity_session.add(act2)

    with pytest.raises(IntegrityError) as exc_info:
        integrity_session.commit()

    assert "UNIQUE constraint failed" in str(exc_info.value)
    integrity_session.rollback()


def test_save_or_update_activity_idempotent_updates(integrity_session):
    """
    save_or_update_activity finds the existing record and updates it in-place,
    never attempting duplicate insertion.
    """
    # 1. Create first activity
    act1 = save_or_update_activity(
        db=integrity_session,
        import_file_code="IMP-2026-0002",
        step_code="STEP_05",
        status="In-Progress",
        assigned_user="user1",
    )
    integrity_session.commit()
    first_id = act1.id

    # 2. Update the same file and step
    act2 = save_or_update_activity(
        db=integrity_session,
        import_file_code="IMP-2026-0002",
        step_code="STEP_05",
        status="Completed",
        assigned_user="user2",
    )
    integrity_session.commit()

    assert act2.id == first_id
    assert act2.status == "Completed"
    assert act2.assigned_user == "user2"

    # Only one record in table for this file and step
    count = (
        integrity_session.query(ShipmentStageActivity)
        .filter(
            ShipmentStageActivity.import_file_code == "IMP-2026-0002",
            ShipmentStageActivity.step_code == "STEP_05",
        )
        .count()
    )
    assert count == 1


# ─── 3. Deduplication Logic ───────────────────────────────────────────────────

def test_deduplication_retains_latest_row(integrity_engine):
    """
    Simulates a database with historical duplicate stage activity rows created before
    the unique constraint. Verifies that the deduplication query retains the row with
    the highest ID and purges earlier duplicates.
    """
    engine, db_file = integrity_engine

    # Temporarily drop unique index to insert test duplicate rows
    conn = sqlite3.connect(db_file)
    try:
        conn.execute("DROP INDEX IF EXISTS uq_shipment_stage_activity_file_step")
        conn.execute(
            "INSERT INTO shipment_stage_activity (id, import_file_code, step_code, status) VALUES (101, 'IMP-DUP', 'STEP_01', 'In-Progress')"
        )
        conn.execute(
            "INSERT INTO shipment_stage_activity (id, import_file_code, step_code, status) VALUES (102, 'IMP-DUP', 'STEP_01', 'Pending')"
        )
        conn.execute(
            "INSERT INTO shipment_stage_activity (id, import_file_code, step_code, status) VALUES (103, 'IMP-DUP', 'STEP_01', 'Completed')"
        )
        conn.commit()

        # Run deduplication query (identical to Alembic revision b8c9d0e1f2a3)
        conn.execute(
            """
            DELETE FROM shipment_stage_activity
            WHERE id NOT IN (
                SELECT MAX(id)
                FROM shipment_stage_activity
                GROUP BY import_file_code, step_code
            )
            """
        )
        conn.commit()

        rows = conn.execute(
            "SELECT id, status FROM shipment_stage_activity WHERE import_file_code = 'IMP-DUP' AND step_code = 'STEP_01'"
        ).fetchall()
        assert len(rows) == 1
        assert rows[0][0] == 103  # highest id retained
        assert rows[0][1] == "Completed"
    finally:
        conn.close()


# ─── 4. CI Foreign Key Orphan Report ──────────────────────────────────────────

def test_fk_orphan_report_clean_database(integrity_engine):
    """Clean database reports 0 violations and returns exit code 0."""
    _, db_file = integrity_engine
    violations = check_foreign_keys(db_file)
    assert violations == []

    exit_code = generate_report(db_file, strict=True)
    assert exit_code == 0


def test_fk_orphan_report_detects_orphans(tmp_path):
    """
    When orphan rows exist in an SQLite file (e.g. written when foreign keys were disabled),
    check_foreign_keys identifies the table, rowid, and parent table.
    """
    db_file = tmp_path / "orphan_test.db"
    conn = sqlite3.connect(db_file)
    try:
        conn.execute("PRAGMA foreign_keys = OFF;")
        conn.execute("CREATE TABLE parents (id INTEGER PRIMARY KEY, name TEXT);")
        conn.execute("CREATE TABLE children (id INTEGER PRIMARY KEY, parent_id INTEGER REFERENCES parents(id));")
        # Insert parent 1 and child referencing parent 1 (valid)
        conn.execute("INSERT INTO parents (id, name) VALUES (1, 'Parent 1');")
        conn.execute("INSERT INTO children (id, parent_id) VALUES (1, 1);")
        # Insert orphan child referencing non-existent parent 999
        conn.execute("INSERT INTO children (id, parent_id) VALUES (2, 999);")
        conn.commit()
    finally:
        conn.close()

    violations = check_foreign_keys(db_file)
    assert len(violations) == 1
    assert violations[0]["table"] == "children"
    assert violations[0]["rowid"] == 2
    assert violations[0]["parent_table"] == "parents"

    exit_code = generate_report(db_file, strict=True)
    assert exit_code == 1
