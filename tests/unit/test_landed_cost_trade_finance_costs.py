"""
Actual landed cost includes trade-finance costs (Trello vpwrZXI4, Pillar 3): bank charges of the file's
finance instruments and the realized FX gain / loss, allocated Value-Based with the other overheads.
"""
from datetime import date
from decimal import Decimal

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.currencies.model import Currency, ExchangeRate
from modules.currencies.service import clear_currency_cache
from modules.financial_settlement.service import (
    aggregate_shipment_invoices_service,
    calculate_actual_landed_cost_service,
)
from modules.import_files.model import ImportFile
from modules.trade_finance.model import FxHedgingAndVariance, ImportFinanceInstrument, LcBankCharge


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(autocommit=False, autoflush=False, bind=engine)()
    cur = Currency(currency_code="USD", currency_name="USD", currency_symbol="$", is_active=True)
    session.add(cur)
    session.flush()
    session.add(ExchangeRate(currency_id=cur.currency_id, customs_rate=Decimal("50"), commercial_rate=Decimal("50"),
                             effective_date=date(2020, 1, 1), is_active=True))
    session.commit()
    clear_currency_cache()
    yield session
    session.close()
    clear_currency_cache()


def _file(db) -> ImportFile:
    imp = ImportFile(
        import_file_code="IMP-2026-TF-01",
        company_name="Sorour Logistics",
        supplier_name="Milano Industrial SpA",
        invoices_data=[{"invoice_no": "INV-1", "amount": 10000.0, "currency": "USD", "exchange_rate": 50.0}],
    )
    db.add(imp)
    db.commit()
    return imp


def _lc(db, imp, status="ISSUED", number="LC-001") -> ImportFinanceInstrument:
    inst = ImportFinanceInstrument(
        instrument_type="LC", instrument_number=number, import_file_id=imp.import_file_id,
        issuing_bank="National Bank of Egypt", amount=10000.0, status=status,
    )
    db.add(inst)
    db.flush()
    return inst


def _charge(db, inst, amount_egp, active=True):
    db.add(LcBankCharge(
        finance_instrument_id=inst.id, charge_type="ISSUANCE_COMMISSION", currency="EGP",
        amount=amount_egp, amount_egp=amount_egp, debit_date=date(2026, 3, 1), is_active=active,
    ))


def _fx(db, inst, variance, settled=True):
    db.add(FxHedgingAndVariance(
        finance_instrument_id=inst.id, foreign_currency="USD", original_amount=10000.0,
        booking_date=date(2026, 3, 1), booking_rate=50.0, booking_total_egp=500000.0,
        settlement_date=date(2026, 4, 1) if settled else None,
        settlement_rate=(50.0 + variance / 10000.0) if settled else None,
        variance_amount_egp=variance if settled else 0.0,
        variance_nature="UNFAVORABLE_LOSS" if variance > 0 else "FAVORABLE_GAIN",
    ))


def _rows(db, imp, prefix):
    return [i for i in aggregate_shipment_invoices_service(db, imp.import_file_id).invoices
            if i.invoice_id.startswith(prefix)]


def test_bank_charges_are_aggregated_as_paid_bank_rows(db):
    imp = _file(db)
    inst = _lc(db, imp)
    _charge(db, inst, 2500.0)
    _charge(db, inst, 750.0)
    _charge(db, inst, 999.0, active=False)
    db.commit()

    rows = _rows(db, imp, "BANK-")
    assert sorted(r.amount_egp for r in rows) == [750.0, 2500.0]
    assert all(r.party_type == "BANK" and r.payment_status == "PAID" for r in rows)
    assert {r.category for r in rows} == {"Bank & Financing Charges"}


def test_realized_fx_loss_and_gain_are_aggregated_unsettled_is_skipped(db):
    imp = _file(db)
    inst = _lc(db, imp)
    _fx(db, inst, 3000.0)
    _fx(db, inst, -1000.0)
    _fx(db, inst, 5000.0, settled=False)
    db.commit()

    rows = _rows(db, imp, "FXV-")
    assert sorted(r.amount_egp for r in rows) == [-1000.0, 3000.0]
    assert {r.category for r in rows} == {"Realized FX Variance"}


def test_cancelled_instruments_are_ignored(db):
    imp = _file(db)
    inst = _lc(db, imp, status="CANCELLED")
    _charge(db, inst, 2500.0)
    db.commit()
    assert _rows(db, imp, "BANK-") == []


def test_actual_landed_cost_includes_trade_finance_costs(db):
    imp = _file(db)
    before = calculate_actual_landed_cost_service(db, imp.import_file_id).actual_total_landed_cost_egp

    inst = _lc(db, imp)
    _charge(db, inst, 2500.0)
    _fx(db, inst, 3000.0)
    db.commit()

    result = calculate_actual_landed_cost_service(db, imp.import_file_id)
    assert round(result.actual_total_landed_cost_egp - before, 2) == 5500.0
    other = next(c for c in result.categories_breakdown if c.category == "Other & Admin")
    assert other.actual_egp == 5500.0
    assert other.invoices_count == 2
