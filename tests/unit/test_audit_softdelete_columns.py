"""Tests for Alembic revision a0b1c2d3e4f5 (BEW0-05): Audit and Soft-Delete columns.

Verifies:
1. Revision metadata (revision="a0b1c2d3e4f5", down_revision="f6a7b8c9d0e1").
2. Upgrade adds created_by and updated_by (VARCHAR(100), nullable) to all 25 audit tables.
3. Upgrade adds deleted_at (DateTime, nullable) and deleted_by (VARCHAR(100), nullable) to
   customs_tariffs and financial_settlement_records.
4. Backfill on shipment_bookings populates created_by and updated_by from owner.
5. Legacy rows on other tables keep NULL for audit columns.
6. Upgrade is idempotent (re-running is a no-op).
7. Downgrade drops the added columns cleanly using batch_alter_table.
8. SQLAlchemy models in Base.metadata reflect all 26 tables with the expected columns.
"""
import importlib.util
from pathlib import Path

import pytest
import sqlalchemy as sa
from sqlalchemy import create_engine
from sqlalchemy.pool import StaticPool

import main  # noqa: F401 - registers every model on Base.metadata
from database.database import Base

AUDIT_TABLES = [
    "clearance_expense_types",
    "broker_price_lists",
    "freight_rfq_requests",
    "payment_request_sessions",
    "import_budget_approvals",
    "acid_registration_sessions",
    "banking_document_sessions",
    "shipment_document_items",
    "customs_declaration_drafts",
    "draft_bl_review_sessions",
    "certificate_of_origin_review_sessions",
    "inspection_certificate_review_sessions",
    "po_packing_reconciliation_sessions",
    "invoice_bl_match_sessions",
    "shipment_bookings",
    "customs_tariffs",
    "preferential_agreements",
    "fee_codes",
    "customs_clearance_rfqs",
    "customs_clearance_quotations",
    "clearance_price_list_items",
    "projects",
    "transport_locations",
    "expense_catalog",
    "currencies",
]

SOFT_DELETE_TABLES = [
    "customs_tariffs",
    "financial_settlement_records",
]


def _load_migration():
    path = Path(__file__).resolve().parents[2] / "alembic" / "versions" / "a0b1c2d3e4f5_audit_softdelete_columns.py"
    spec = importlib.util.spec_from_file_location("mig_a0b1c2d3e4f5", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _run_migration(conn, direction: str) -> None:
    from alembic.migration import MigrationContext
    from alembic.operations import Operations

    module = _load_migration()
    ctx = MigrationContext.configure(conn)
    with Operations.context(ctx):
        getattr(module, direction)()


def test_revision_metadata():
    module = _load_migration()
    assert module.revision == "a0b1c2d3e4f5"
    assert module.down_revision == "f6a7b8c9d0e1"


def test_sqlalchemy_models_have_audit_and_softdelete_columns():
    """Verify that every mapped table in Base.metadata has the expected column attributes."""
    for table_name in AUDIT_TABLES:
        table = Base.metadata.tables.get(table_name)
        assert table is not None, f"Table {table_name} not found in Base.metadata"
        cols = {c.name for c in table.columns}
        assert "created_by" in cols, f"Model {table_name} missing created_by"
        assert "updated_by" in cols, f"Model {table_name} missing updated_by"
        assert table.columns["created_by"].nullable is True
        assert table.columns["updated_by"].nullable is True

    for table_name in SOFT_DELETE_TABLES:
        table = Base.metadata.tables.get(table_name)
        assert table is not None, f"Table {table_name} not found in Base.metadata"
        cols = {c.name for c in table.columns}
        assert "deleted_at" in cols, f"Model {table_name} missing deleted_at"
        assert "deleted_by" in cols, f"Model {table_name} missing deleted_by"
        assert table.columns["deleted_at"].nullable is True
        assert table.columns["deleted_by"].nullable is True


def test_migration_upgrade_backfill_downgrade_cycle():
    """Test upgrade adds columns, backfills shipment_bookings, handles legacy rows, and downgrades cleanly."""
    engine = create_engine("sqlite:///:memory:", poolclass=StaticPool)

    def cols(table):
        return {c["name"] for c in sa.inspect(engine).get_columns(table)}

    # Create dummy tables matching the 26 target tables without the new columns
    with engine.begin() as conn:
        for t in AUDIT_TABLES:
            conn.execute(sa.text(f"CREATE TABLE {t} (id INTEGER PRIMARY KEY)"))
        # financial_settlement_records is only in SOFT_DELETE_TABLES
        conn.execute(sa.text("CREATE TABLE financial_settlement_records (id INTEGER PRIMARY KEY, created_by VARCHAR(100), updated_by VARCHAR(100))"))

        # Add owner to shipment_bookings
        conn.execute(sa.text("ALTER TABLE shipment_bookings ADD COLUMN owner VARCHAR(100)"))

        # Insert test rows
        conn.execute(sa.text("INSERT INTO currencies (id) VALUES (1)"))
        conn.execute(sa.text("INSERT INTO shipment_bookings (id, owner) VALUES (1, 'LegacyBroker')"))
        conn.execute(sa.text("INSERT INTO shipment_bookings (id, owner) VALUES (2, NULL)"))
        conn.execute(sa.text("INSERT INTO customs_tariffs (id) VALUES (1)"))
        conn.execute(sa.text("INSERT INTO financial_settlement_records (id, created_by, updated_by) VALUES (1, 'Sys', 'Sys')"))

    # 1. First Upgrade
    with engine.begin() as conn:
        _run_migration(conn, "upgrade")

    # Verify audit columns on all 25 tables
    for t in AUDIT_TABLES:
        c = cols(t)
        assert "created_by" in c, f"Table {t} missing created_by after upgrade"
        assert "updated_by" in c, f"Table {t} missing updated_by after upgrade"

    # Verify soft delete columns
    for t in SOFT_DELETE_TABLES:
        c = cols(t)
        assert "deleted_at" in c, f"Table {t} missing deleted_at after upgrade"
        assert "deleted_by" in c, f"Table {t} missing deleted_by after upgrade"

    # Verify backfill on shipment_bookings
    with engine.connect() as conn:
        row1 = conn.execute(sa.text("SELECT owner, created_by, updated_by FROM shipment_bookings WHERE id = 1")).one()
        assert tuple(row1) == ("LegacyBroker", "LegacyBroker", "LegacyBroker")

        row2 = conn.execute(sa.text("SELECT owner, created_by, updated_by FROM shipment_bookings WHERE id = 2")).one()
        assert tuple(row2) == (None, "system", "system")

        # Legacy rows on other tables keep NULL
        row_curr = conn.execute(sa.text("SELECT created_by, updated_by FROM currencies WHERE id = 1")).one()
        assert tuple(row_curr) == (None, None)

        row_tariff = conn.execute(sa.text("SELECT created_by, updated_by, deleted_at, deleted_by FROM customs_tariffs WHERE id = 1")).one()
        assert tuple(row_tariff) == (None, None, None, None)

    # 2. Idempotent second upgrade
    with engine.begin() as conn:
        _run_migration(conn, "upgrade")

    # 3. Downgrade drops columns
    with engine.begin() as conn:
        _run_migration(conn, "downgrade")

    for t in AUDIT_TABLES:
        c = cols(t)
        assert "created_by" not in c, f"Table {t} still has created_by after downgrade"
        assert "updated_by" not in c, f"Table {t} still has updated_by after downgrade"

    for t in SOFT_DELETE_TABLES:
        c = cols(t)
        assert "deleted_at" not in c, f"Table {t} still has deleted_at after downgrade"
        assert "deleted_by" not in c, f"Table {t} still has deleted_by after downgrade"
