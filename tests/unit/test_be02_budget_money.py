"""
Unit tests for BE02-T02:
Budget clone converts freight with the freight currency's own rate (BE02-F02).
"""
import pytest
from fastapi import HTTPException

from modules.financial_approval.model import ImportBudgetApproval
from modules.financial_approval.schemas import CloneImportBudgetRequest
from modules.financial_approval.service import (
    _budget_egp_amounts,
    clone_import_budget_service,
)
from test_phase02_support import make_session, seed_file, seed_rate


@pytest.fixture
def db():
    session = make_session()
    seed_rate(session, "EGP", 1.0, base=True)
    seed_rate(session, "USD", 50.0)
    seed_rate(session, "EUR", 55.0)
    try:
        yield session
    finally:
        session.close()


def test_helper_budget_egp_amounts_different_currencies(db):
    """Freight converts with its own rate when currencies differ."""
    # Invoice USD at rate 52.0; Freight EUR at seeded rate 55.0
    inv_egp, frt_egp = _budget_egp_amounts(
        db,
        invoice_foreign=10000.0,
        invoice_currency="USD",
        freight_foreign=2000.0,
        freight_currency="EUR",
        invoice_rate=52.0,
    )
    assert inv_egp == 520000.0
    assert frt_egp == 110000.0


def test_helper_budget_egp_amounts_same_currency(db):
    """Freight converts with invoice_rate when freight currency matches invoice currency."""
    inv_egp, frt_egp = _budget_egp_amounts(
        db,
        invoice_foreign=10000.0,
        invoice_currency="USD",
        freight_foreign=2000.0,
        freight_currency="USD",
        invoice_rate=52.0,
    )
    assert inv_egp == 520000.0
    assert frt_egp == 104000.0


def test_helper_budget_egp_amounts_freight_egp(db):
    """Freight in EGP uses 1.0 rate regardless of invoice currency or rate."""
    inv_egp, frt_egp = _budget_egp_amounts(
        db,
        invoice_foreign=10000.0,
        invoice_currency="USD",
        freight_foreign=50000.0,
        freight_currency="EGP",
        invoice_rate=52.0,
    )
    assert inv_egp == 520000.0
    assert frt_egp == 50000.0


def test_helper_budget_egp_amounts_missing_freight_rate(db):
    """Missing commercial rate for foreign freight raises 400 FA_FX_RATE_MISSING."""
    with pytest.raises(HTTPException) as exc_info:
        _budget_egp_amounts(
            db,
            invoice_foreign=10000.0,
            invoice_currency="USD",
            freight_foreign=2000.0,
            freight_currency="GBP",
            invoice_rate=50.0,
        )
    assert exc_info.value.status_code == 400
    assert exc_info.value.detail["code"] == "FA_FX_RATE_MISSING"
    assert exc_info.value.detail["currency_code"] == "GBP"


def test_clone_budget_different_currencies(db):
    """
    Source budget: invoice USD 10,000 at rate 50 (invoice EGP 500,000), freight EUR 2,000 (freight EGP 110,000),
    customs 80,000, clearance 20,000. Seeded latest commercial EUR rate = 55. Clone with new_exchange_rate=52. Expect:
    - invoice_amount_egp = 520000.0
    - freight_cost_egp = 110000.0
    - total_budget_egp = 730000.0
    """
    f = seed_file(db)
    orig = ImportBudgetApproval(
        budget_code="BGT-TEST-DIFF-01",
        title="Source USD + EUR Budget",
        import_file_id=f.import_file_id,
        invoice_amount_foreign=10000.0,
        invoice_currency="USD",
        invoice_amount_egp=500000.0,
        freight_cost_foreign=2000.0,
        freight_currency="EUR",
        freight_cost_egp=110000.0,
        customs_duties_egp=80000.0,
        clearance_inland_egp=20000.0,
        exchange_rate=50.0,
        total_budget_egp=710000.0,
        budget_status="Budget Approved",
        is_active=True,
    )
    db.add(orig)
    db.commit()
    db.refresh(orig)

    clone_req = CloneImportBudgetRequest(
        new_title="Cloned Budget Rate 52",
        new_exchange_rate=52.0,
        unlink_import_file=True,
    )
    cloned = clone_import_budget_service(db, orig.budget_id, clone_req)

    assert cloned.exchange_rate == 52.0
    assert cloned.invoice_amount_foreign == 10000.0
    assert cloned.invoice_currency == "USD"
    assert cloned.invoice_amount_egp == 520000.0
    assert cloned.freight_cost_foreign == 2000.0
    assert cloned.freight_currency == "EUR"
    assert cloned.freight_cost_egp == 110000.0
    assert cloned.customs_duties_egp == 80000.0
    assert cloned.clearance_inland_egp == 20000.0
    assert cloned.total_budget_egp == 730000.0


def test_clone_budget_mixed_currency_source(db):
    """
    Mixed-currency source: invoice_currency="EGP", rate 1.0, invoice_amount_foreign=1500000,
    freight USD 3,000, seeded USD rate 50.
    Clone with no new rate. Expect freight_cost_egp = 150000.0.
    """
    f = seed_file(db)
    orig = ImportBudgetApproval(
        budget_code="BGT-TEST-MIX-01",
        title="Source Mixed Currency Budget",
        import_file_id=f.import_file_id,
        invoice_amount_foreign=1500000.0,
        invoice_currency="EGP",
        invoice_amount_egp=1500000.0,
        freight_cost_foreign=3000.0,
        freight_currency="USD",
        freight_cost_egp=150000.0,
        customs_duties_egp=50000.0,
        clearance_inland_egp=10000.0,
        exchange_rate=1.0,
        total_budget_egp=1710000.0,
        budget_status="Budget Approved",
        is_active=True,
    )
    db.add(orig)
    db.commit()
    db.refresh(orig)

    clone_req = CloneImportBudgetRequest(
        new_title="Cloned Mixed Budget",
        unlink_import_file=True,
    )
    cloned = clone_import_budget_service(db, orig.budget_id, clone_req)

    assert cloned.exchange_rate == 1.0
    assert cloned.invoice_amount_foreign == 1500000.0
    assert cloned.invoice_currency == "EGP"
    assert cloned.invoice_amount_egp == 1500000.0
    assert cloned.freight_cost_foreign == 3000.0
    assert cloned.freight_currency == "USD"
    assert cloned.freight_cost_egp == 150000.0
    assert cloned.total_budget_egp == 1710000.0


def test_clone_budget_missing_freight_rate_no_row_created(db):
    """
    Missing rate: Freight GBP with no GBP rate gives 400 FA_FX_RATE_MISSING,
    and no new budget row is created.
    """
    f = seed_file(db)
    orig = ImportBudgetApproval(
        budget_code="BGT-TEST-GBP-01",
        title="Source GBP Budget",
        import_file_id=f.import_file_id,
        invoice_amount_foreign=10000.0,
        invoice_currency="USD",
        invoice_amount_egp=500000.0,
        freight_cost_foreign=2500.0,
        freight_currency="GBP",
        freight_cost_egp=100000.0,
        customs_duties_egp=40000.0,
        clearance_inland_egp=15000.0,
        exchange_rate=50.0,
        total_budget_egp=655000.0,
        budget_status="Budget Approved",
        is_active=True,
    )
    db.add(orig)
    db.commit()
    db.refresh(orig)

    count_before = db.query(ImportBudgetApproval).count()

    clone_req = CloneImportBudgetRequest(
        new_title="Cloned GBP Budget",
        unlink_import_file=True,
    )
    with pytest.raises(HTTPException) as exc_info:
        clone_import_budget_service(db, orig.budget_id, clone_req)

    assert exc_info.value.status_code == 400
    assert exc_info.value.detail["code"] == "FA_FX_RATE_MISSING"

    count_after = db.query(ImportBudgetApproval).count()
    assert count_after == count_before
