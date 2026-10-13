"""
Unit tests for BE02-T05:
Backfill legacy budget columns and make sync NULL-safe (BE02-F05).
"""
import importlib.util
from datetime import date
from pathlib import Path
import pytest
import sqlalchemy as sa

from modules.financial_approval.model import ImportBudgetApproval, PaymentRequestSession
from modules.financial_approval import service
from test_phase02_support import make_session, seed_file, seed_rate, seed_consultation


from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from database.database import Base


@pytest.fixture
def db():
    engine = create_engine(
        "sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    # Simulate legacy database schema where columns were added as plain nullable columns
    t_bgt = Base.metadata.tables["import_budget_approvals"]
    t_pay = Base.metadata.tables["payment_request_sessions"]
    orig_bgt_rev = t_bgt.c.revision_number.nullable
    orig_bgt_var = t_bgt.c.has_unresolved_variance.nullable
    orig_bgt_ver = t_bgt.c.version.nullable
    orig_pay_ver = t_pay.c.version.nullable

    t_bgt.c.revision_number.nullable = True
    t_bgt.c.has_unresolved_variance.nullable = True
    t_bgt.c.version.nullable = True
    t_pay.c.version.nullable = True

    try:
        Base.metadata.create_all(engine)
    finally:
        t_bgt.c.revision_number.nullable = orig_bgt_rev
        t_bgt.c.has_unresolved_variance.nullable = orig_bgt_var
        t_bgt.c.version.nullable = orig_bgt_ver
        t_pay.c.version.nullable = orig_pay_ver

    session = sessionmaker(autocommit=False, autoflush=False, bind=engine)()
    seed_rate(session, "EGP", 1.0, base=True)
    seed_rate(session, "USD", 50.0)
    try:
        yield session
    finally:
        session.close()


def _admin_user():
    from modules.users.model import User
    return User(user_id=1, username="admin_tester", role="ADMIN", is_active=True)


def _load_migration():
    path = (
        Path(__file__).resolve().parents[2]
        / "alembic"
        / "versions"
        / "a1b2c3d4e5f6_fa_legacy_budget_backfill.py"
    )
    spec = importlib.util.spec_from_file_location("mig_a1b2c3d4e5f6", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_sync_approved_budget_null_revision_creates_rev2(db):
    """
    Acceptance criteria for BE02-T05:
    Syncing an Approved budget whose revision_number is NULL creates BGT-YYYY-NNN-REV2
    instead of raising TypeError / 500 (None + 1).
    """
    f = seed_file(db)
    budget = ImportBudgetApproval(
        budget_code="BGT-2026-001",
        title="Legacy Approved Budget",
        import_file_id=f.import_file_id,
        invoice_amount_foreign=10000.0,
        invoice_currency="USD",
        invoice_amount_egp=500000.0,
        exchange_rate=50.0,
        customs_duties_egp=50000.0,
        clearance_inland_egp=20000.0,
        total_budget_egp=570000.0,
        budget_status="Budget Approved",
        revision_number=1,
        version=1,
        upstream_modified_by="other_modifier",
        is_active=True,
    )
    db.add(budget)
    db.commit()
    db.refresh(budget)

    # Force revision_number to NULL via raw SQL to simulate legacy row
    db.execute(
        sa.text("UPDATE import_budget_approvals SET revision_number = NULL WHERE budget_id = :id"),
        {"id": budget.budget_id},
    )
    db.commit()
    db.refresh(budget)
    assert budget.revision_number is None

    # Upstream costs: consultation fee
    seed_consultation(db, f.import_file_id, duties=50000.0, fees=25000.0)

    # User other than upstream_modified_by syncs
    actor = _admin_user()
    result = service.sync_budget_with_upstream_service(
        db,
        budget.budget_id,
        current_user=actor,
        override_justification="Sync legacy budget with live costs",
    )

    assert result.revision_created is True
    assert result.budget.revision_number == 2
    assert result.budget.budget_code == "BGT-2026-001-REV2"
    assert result.budget.budget_status == "Pending Review"

    db.refresh(budget)
    assert budget.budget_status == "Superseded"
    assert budget.has_unresolved_variance is False


def test_migration_backfills_null_columns(db):
    """
    Migration backfills revision_number=1, has_unresolved_variance=0, version=1
    on import_budget_approvals, and version=1 on payment_request_sessions.
    """
    from alembic.migration import MigrationContext
    from alembic.operations import Operations

    f = seed_file(db)
    budget = ImportBudgetApproval(
        budget_code="BGT-2026-LEGACY-02",
        title="Legacy Unfilled Budget",
        import_file_id=f.import_file_id,
        invoice_amount_egp=100000.0,
        total_budget_egp=100000.0,
        budget_status="Pending Review",
        revision_number=1,
        version=1,
        is_active=True,
    )
    db.add(budget)

    payment = PaymentRequestSession(
        payment_code="PAY-2026-LEGACY-01",
        title="Legacy Payment",
        import_file_id=f.import_file_id,
        supplier_name="Global Supplier",
        requested_amount_egp=50000.0,
        due_date=date.today(),
        status="Draft",
        version=1,
        is_active=True,
    )
    db.add(payment)
    db.commit()

    # Raw UPDATE to NULL out the target columns
    db.execute(
        sa.text(
            "UPDATE import_budget_approvals "
            "SET revision_number = NULL, has_unresolved_variance = NULL, version = NULL "
            "WHERE budget_id = :id"
        ),
        {"id": budget.budget_id},
    )
    db.execute(
        sa.text(
            "UPDATE payment_request_sessions "
            "SET version = NULL "
            "WHERE payment_id = :id"
        ),
        {"id": payment.payment_id},
    )
    db.commit()

    # Verify they are NULL before migration
    b_row = db.execute(
        sa.text("SELECT revision_number, has_unresolved_variance, version FROM import_budget_approvals WHERE budget_id = :id"),
        {"id": budget.budget_id},
    ).fetchone()
    assert b_row[0] is None
    assert b_row[1] is None
    assert b_row[2] is None

    p_row = db.execute(
        sa.text("SELECT version FROM payment_request_sessions WHERE payment_id = :id"),
        {"id": payment.payment_id},
    ).fetchone()
    assert p_row[0] is None

    # Run migration upgrade
    mig = _load_migration()
    ctx = MigrationContext.configure(db.connection())
    with Operations.context(ctx):
        mig.upgrade()
    db.commit()

    # Verify backfill results
    b_after = db.execute(
        sa.text("SELECT revision_number, has_unresolved_variance, version FROM import_budget_approvals WHERE budget_id = :id"),
        {"id": budget.budget_id},
    ).fetchone()
    assert b_after[0] == 1
    assert b_after[1] in (0, False)
    assert b_after[2] == 1

    p_after = db.execute(
        sa.text("SELECT version FROM payment_request_sessions WHERE payment_id = :id"),
        {"id": payment.payment_id},
    ).fetchone()
    assert p_after[0] == 1

    # Downgrade is a safe no-op
    with Operations.context(ctx):
        mig.downgrade()
