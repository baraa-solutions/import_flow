"""Withholding tax (WHT) rates come from the effective-dated ``tax_rates`` table, not from code.

The seed (MasterDataSyncService.sync_tax_rates / Alembic d9e4f5a6b7c8) keeps the old 1% so the CLO-01
aggregation totals are unchanged; a different configured rate changes them.
"""
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main  # noqa: F401  (registers every model on Base.metadata)
from database.database import Base
from database.master_data_sync_service import TAX_RATE_SEED_FROM, MasterDataSyncService
from modules.customs_clearance.model import ClearanceExpenseInvoice
from modules.financial_settlement.model import TaxRate, WHT_CLEARANCE_SERVICES, WHT_TRANSPORT_SERVICES
from fastapi import HTTPException

from modules.customs_clearance.model import CustomsClearanceRecord
from modules.financial_settlement.service import (
    WHT_RATE_NOT_CONFIGURED,
    aggregate_shipment_invoices_service,
    cairo_date,
    resolve_wht_rate_percent,
    wht_amount_for,
)
from modules.import_files.model import ImportFile

engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

CLEARANCE_TOTAL = 12345.67
TRANSPORT_TOTAL = 7500.0


@pytest.fixture()
def db():
    Base.metadata.create_all(bind=engine)
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


def _seed(db):
    return MasterDataSyncService(db).sync_tax_rates()


def _import_file(db, code="IMP-WHT-001", clearance=CLEARANCE_TOTAL, transport=TRANSPORT_TOTAL):
    imp = ImportFile(
        import_file_code=code,
        company_name="Sorour Logistics Co.",
        supplier_name="Global Steel Inc",
        estimated_cost=10000.0,
        estimated_cost_currency="USD",
        invoices_data=[],
        total_clearance_expenses_egp=clearance,
        inland_transport_cost_egp=transport,
    )
    db.add(imp)
    db.commit()
    return imp


def _clearance_invoice(db, imp, invoice_date, amount=8000.0, code="INV-CLR-WHT"):
    inv = ClearanceExpenseInvoice(
        invoice_code=code,
        import_file_id=imp.import_file_id,
        invoice_number=f"{code}-NO",
        invoice_date=invoice_date,
        provider_name="Al-Amal Customs Brokerage",
        expense_category="BROKERAGE_FEES",
        currency="EGP",
        amount_egp=amount,
        wht_deducted=True,
        wht_amount=0.0,  # not stored -> computed from the configured rate
        net_payable_egp=amount,
        payment_status="Unpaid",
        is_active=True,
    )
    db.add(inv)
    db.commit()
    return inv


def _by_id(result):
    return {i.invoice_id: i for i in result.invoices}


def _legacy_wht(amount):
    """The formula the engine hard-coded before (1%)."""
    return round(amount * 0.01, 2)


# ── seed ──────────────────────────────────────────────────────────────────────────

def test_seed_adds_one_percent_rows_once_and_never_resets_edits(db):
    assert _seed(db) == 2
    rows = db.query(TaxRate).order_by(TaxRate.tax_code).all()
    assert [(r.tax_code, r.rate_percent, r.effective_from) for r in rows] == [
        (WHT_CLEARANCE_SERVICES, Decimal("1.0000"), TAX_RATE_SEED_FROM),
        (WHT_TRANSPORT_SERVICES, Decimal("1.0000"), TAX_RATE_SEED_FROM),
    ]
    assert _seed(db) == 0  # idempotent

    rows[0].is_active = False  # an admin switched it off
    db.commit()
    assert _seed(db) == 0
    assert db.query(TaxRate).filter(TaxRate.tax_code == WHT_CLEARANCE_SERVICES).count() == 1


def test_sync_all_reports_tax_rates(db):
    assert MasterDataSyncService(db).sync_all()["tax_rates_added"] == 2


# ── identical totals with the seeded rate ─────────────────────────────────────────

def test_seeded_rate_keeps_the_old_totals(db):
    _seed(db)
    imp = _import_file(db)

    result = aggregate_shipment_invoices_service(db, imp.import_file_id)
    items = _by_id(result)

    broker, transport = items["BROKER-IMP"], items["TR-IMP"]
    assert broker.withholding_tax_rate == 1.0
    assert broker.withholding_tax_amount_egp == _legacy_wht(CLEARANCE_TOTAL) == 123.46
    assert broker.net_payable_egp == round(CLEARANCE_TOTAL - _legacy_wht(CLEARANCE_TOTAL), 2)
    assert transport.withholding_tax_rate == 1.0
    assert transport.withholding_tax_amount_egp == _legacy_wht(TRANSPORT_TOTAL) == 75.0
    assert transport.net_payable_egp == 7425.0
    assert result.total_withholding_tax_egp == pytest.approx(_legacy_wht(CLEARANCE_TOTAL) + _legacy_wht(TRANSPORT_TOTAL))


def test_seeded_rate_on_a_stored_clearance_invoice_without_amount(db):
    _seed(db)
    imp = _import_file(db, clearance=0.0, transport=0.0)
    inv = _clearance_invoice(db, imp, datetime(2025, 6, 1, tzinfo=timezone.utc))

    item = _by_id(aggregate_shipment_invoices_service(db, imp.import_file_id))[f"BROKER-{inv.invoice_id}"]
    assert item.withholding_tax_rate == 1.0
    assert item.withholding_tax_amount_egp == _legacy_wht(8000.0) == 80.0


def test_stored_wht_amount_still_wins(db):
    _seed(db)
    imp = _import_file(db, clearance=0.0, transport=0.0)
    inv = _clearance_invoice(db, imp, datetime(2025, 6, 1, tzinfo=timezone.utc))
    inv.wht_amount = 55.5
    db.commit()

    item = _by_id(aggregate_shipment_invoices_service(db, imp.import_file_id))[f"BROKER-{inv.invoice_id}"]
    assert item.withholding_tax_amount_egp == 55.5


# ── a different rate changes the totals ───────────────────────────────────────────

def _new_period(db, tax_code, rate, starts):
    current = db.query(TaxRate).filter(TaxRate.tax_code == tax_code, TaxRate.effective_to == None).one()  # noqa: E711
    current.effective_to = starts - timedelta(days=1)
    db.add(TaxRate(tax_code=tax_code, rate_percent=Decimal(str(rate)), effective_from=starts, is_active=True))
    db.commit()


def test_changed_rate_changes_totals_by_effective_date(db):
    _seed(db)
    today = datetime.now(timezone.utc).date()
    _new_period(db, WHT_CLEARANCE_SERVICES, 3, today - timedelta(days=30))
    _new_period(db, WHT_TRANSPORT_SERVICES, 2.5, today - timedelta(days=30))

    imp = _import_file(db)
    items = _by_id(aggregate_shipment_invoices_service(db, imp.import_file_id))
    assert items["BROKER-IMP"].withholding_tax_rate == 3.0
    assert items["BROKER-IMP"].withholding_tax_amount_egp == round(CLEARANCE_TOTAL * 0.03, 2) == 370.37
    assert items["BROKER-IMP"].net_payable_egp == round(CLEARANCE_TOTAL - 370.37, 2)
    assert items["TR-IMP"].withholding_tax_rate == 2.5
    assert items["TR-IMP"].withholding_tax_amount_egp == 187.5

    # Invoices keep the rate valid on their own date.
    imp2 = _import_file(db, code="IMP-WHT-002", clearance=0.0, transport=0.0)
    old = _clearance_invoice(db, imp2, datetime(2025, 6, 1, tzinfo=timezone.utc), code="INV-OLD")
    new = _clearance_invoice(db, imp2, datetime.now(timezone.utc), code="INV-NEW")
    items2 = _by_id(aggregate_shipment_invoices_service(db, imp2.import_file_id))
    assert items2[f"BROKER-{old.invoice_id}"].withholding_tax_amount_egp == 80.0
    assert items2[f"BROKER-{new.invoice_id}"].withholding_tax_amount_egp == 240.0


def test_no_configured_rate_synthetic_rows_warn_and_deduct_nothing(db):
    imp = _import_file(db)
    result = aggregate_shipment_invoices_service(db, imp.import_file_id)
    items = _by_id(result)
    assert items["BROKER-IMP"].withholding_tax_rate == 0.0
    assert items["BROKER-IMP"].withholding_tax_amount_egp == 0.0
    assert items["BROKER-IMP"].net_payable_egp == CLEARANCE_TOTAL
    assert items["TR-IMP"].withholding_tax_amount_egp == 0.0
    joined = " | ".join(result.unsettled_warnings)
    assert WHT_CLEARANCE_SERVICES in joined and WHT_TRANSPORT_SERVICES in joined


def test_no_configured_rate_on_a_real_deducted_invoice_is_a_coded_error(db):
    imp = _import_file(db, clearance=0.0, transport=0.0)
    inv = _clearance_invoice(db, imp, datetime(2025, 6, 1, tzinfo=timezone.utc))
    with pytest.raises(HTTPException) as exc:
        aggregate_shipment_invoices_service(db, imp.import_file_id)
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == WHT_RATE_NOT_CONFIGURED
    assert exc.value.detail["tax_code"] == WHT_CLEARANCE_SERVICES
    assert exc.value.detail["on_date"] == "2025-06-01"
    assert exc.value.detail["invoice_code"] == inv.invoice_code

    # A stored WHT amount needs no rate.
    inv.wht_amount = 80.0
    db.commit()
    item = _by_id(aggregate_shipment_invoices_service(db, imp.import_file_id))[f"BROKER-{inv.invoice_id}"]
    assert item.withholding_tax_amount_egp == 80.0
    assert item.withholding_tax_rate == 0.0


# ── rounding parity with the old formula ──────────────────────────────────────────

def test_wht_amount_rounds_exactly_like_the_old_one_percent_formula():
    assert wht_amount_for(17.5, 1.0) == 0.18 == _legacy_wht(17.5)
    mismatches = [c for c in range(1_000_000) if wht_amount_for(c / 100, 1.0) != _legacy_wht(c / 100)]
    assert mismatches == []


# ── dates: Cairo business date, file release date for the synthetic broker row ───

def test_invoice_date_is_taken_in_cairo_time(db):
    _seed(db)
    _new_period(db, WHT_CLEARANCE_SERVICES, 3, date(2026, 1, 1))
    late_utc = datetime(2025, 12, 31, 23, 0, tzinfo=timezone.utc)  # 2026-01-01 01:00 in Cairo
    assert cairo_date(late_utc) == date(2026, 1, 1)
    assert cairo_date(datetime(2025, 12, 31, 23, 0)) == date(2026, 1, 1)  # naive = UTC

    imp = _import_file(db, clearance=0.0, transport=0.0)
    inv = _clearance_invoice(db, imp, late_utc)
    item = _by_id(aggregate_shipment_invoices_service(db, imp.import_file_id))[f"BROKER-{inv.invoice_id}"]
    assert item.withholding_tax_rate == 3.0
    assert item.withholding_tax_amount_egp == 240.0


def test_synthetic_broker_row_uses_the_customs_release_date(db):
    _seed(db)
    _new_period(db, WHT_CLEARANCE_SERVICES, 3, date(2026, 1, 1))

    released = _import_file(db, code="IMP-WHT-REL", transport=0.0)
    released.customs_released_at = datetime(2025, 6, 1, 10, 0)
    db.commit()
    assert _by_id(aggregate_shipment_invoices_service(db, released.import_file_id))["BROKER-IMP"].withholding_tax_rate == 1.0

    via_record = _import_file(db, code="IMP-WHT-CL", transport=0.0)
    db.add(CustomsClearanceRecord(
        clearance_code="CLR-WHT-1", import_file_id=via_record.import_file_id, release_date=datetime(2025, 7, 1, 9, 0),
    ))
    db.commit()
    assert _by_id(aggregate_shipment_invoices_service(db, via_record.import_file_id))["BROKER-IMP"].withholding_tax_rate == 1.0

    # No release date at all: today (after 2026-01-01) -> 3%.
    unreleased = _import_file(db, code="IMP-WHT-NOW", transport=0.0)
    assert _by_id(aggregate_shipment_invoices_service(db, unreleased.import_file_id))["BROKER-IMP"].withholding_tax_rate == 3.0


# ── lookup edge cases ─────────────────────────────────────────────────────────────

def test_lookup_ignores_inactive_deleted_and_out_of_range_rows(db):
    _seed(db)
    on = date(2026, 3, 1)
    _new_period(db, WHT_CLEARANCE_SERVICES, 5, date(2026, 1, 1))
    assert resolve_wht_rate_percent(db, WHT_CLEARANCE_SERVICES, on) == 5.0
    assert resolve_wht_rate_percent(db, WHT_CLEARANCE_SERVICES, date(2025, 12, 31)) == 1.0
    assert resolve_wht_rate_percent(db, WHT_CLEARANCE_SERVICES, date(1999, 12, 31)) == 0.0

    newest = db.query(TaxRate).filter(TaxRate.rate_percent == Decimal("5")).one()
    newest.deleted_at = datetime.now(timezone.utc)
    newest.deleted_by = "admin"
    db.commit()
    assert resolve_wht_rate_percent(db, WHT_CLEARANCE_SERVICES, on) == 0.0  # 1% row ended 2025-12-31

    newest.deleted_at = None
    newest.is_active = False
    db.commit()
    assert resolve_wht_rate_percent(db, WHT_CLEARANCE_SERVICES, on) == 0.0

    assert resolve_wht_rate_percent(db, "UNKNOWN_TAX", on) == 0.0
