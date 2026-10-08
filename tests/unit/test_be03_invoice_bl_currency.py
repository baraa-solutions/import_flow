"""
Unit tests for BE03-T02:
Invoice/B-L sync never relabels the file's estimated-cost currency (BE03-F02).
"""
import pytest
from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main  # noqa: F401
from database.database import Base
from modules.currencies.model import Currency, ExchangeRate
from modules.incoterms.model import Incoterm
from modules.import_files.model import ImportFile
from modules.import_documentation.schemas import (
    InvoiceBLMatchSessionCreate,
    InvoiceBLSyncRequest,
)
import modules.import_documentation.service as doc_service
from modules.financial_approval.service import get_budget_prefill_service


@pytest.fixture
def db():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()

    # Seed currencies
    usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    eur = Currency(currency_code="EUR", currency_name="Euro", currency_symbol="€", is_active=True)
    egp = Currency(currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="E£", is_active=True, is_base_currency=True)
    session.add_all([usd, eur, egp])
    session.commit()

    session.add(ExchangeRate(currency_id=usd.currency_id, commercial_rate=50.0, customs_rate=50.0, effective_date=date(2020, 1, 1), is_active=True))
    session.add(ExchangeRate(currency_id=eur.currency_id, commercial_rate=55.0, customs_rate=55.0, effective_date=date(2020, 1, 1), is_active=True))

    # Seed incoterm
    session.add(Incoterm(incoterm_code="FOB", incoterm_name="Free on Board", is_active=True))
    session.commit()

    yield session
    session.close()
    engine.dispose()


def test_certify_session_does_not_relabel_file_estimated_currency(db):
    """
    Certifying an invoice/B-L session must not overwrite ImportFile.estimated_cost_currency.
    File: estimated_cost=24500.0, estimated_cost_currency="EUR".
    Invoice: currency="USD".
    Expect:
    - file retains estimated_cost_currency="EUR" and estimated_cost=24500.0.
    - file pi_number is updated to "INV-9".
    - session response has currency_mismatch=True.
    - financial approval prefill fallback returns 24500.0 in EUR.
    """
    f = ImportFile(
        import_file_code="IMP-2026-EUR-01",
        custom_file_number="FILE-EUR-01",
        company_name="Euro Importer Ltd",
        supplier_name="Global Supplier",
        estimated_cost=24500.0,
        estimated_cost_currency="EUR",
        is_active=True,
    )
    db.add(f)
    db.commit()
    db.refresh(f)

    session_create = InvoiceBLMatchSessionCreate(
        import_file_id=f.import_file_id,
        invoice_number="INV-9",
        bl_number="MEDU1",
        is_draft=False,
        is_safe_for_certification=True,
        critical_discrepancies_count=0,
        invoice_data={"invoice_number": "INV-9", "currency": "USD", "incoterm": "FOB"},
        bl_data={"draft_bl_number": "MEDU1"},
    )

    created_session = doc_service.create_invoice_bl_match_session_service(db, session_create, user="certifier")

    db.refresh(f)
    assert f.estimated_cost == 24500.0
    assert f.estimated_cost_currency == "EUR"
    assert f.pi_number == "INV-9"
    assert f.bl_number == "MEDU1"
    assert created_session.currency_mismatch is True

    # Financial approval prefill fallback check (no PO parts, empty invoices_data)
    prefill = get_budget_prefill_service(db, f.import_file_id)
    assert prefill.invoice_currency == "EUR"
    assert prefill.total_invoice_amount_egp == 24500.0 * 55.0


def test_sync_certified_invoice_bl_route_returns_currency_mismatch(db):
    """
    sync_certified_invoice_bl_to_file_service returns currency_mismatch=True and does not change file currency.
    """
    f = ImportFile(
        import_file_code="IMP-2026-EUR-02",
        custom_file_number="FILE-EUR-02",
        company_name="Euro Importer Ltd",
        supplier_name="Global Supplier",
        estimated_cost=10000.0,
        estimated_cost_currency="EUR",
        is_active=True,
    )
    db.add(f)
    db.commit()
    db.refresh(f)

    req = InvoiceBLSyncRequest(
        import_file_id=f.import_file_id,
        invoice_data={"invoice_number": "INV-10", "currency": "USD", "incoterm": "FOB"},
        bl_data={"draft_bl_number": "MEDU2"},
    )

    resp = doc_service.sync_certified_invoice_bl_to_file_service(db, req, user="certifier")
    assert resp["status"] == "success"
    assert resp["currency_mismatch"] is True
    assert resp["currency"] == "USD"
    assert resp["synced_invoice_number"] == "INV-10"

    db.refresh(f)
    assert f.estimated_cost == 10000.0
    assert f.estimated_cost_currency == "EUR"


def test_same_currency_reports_no_mismatch(db):
    """
    When invoice currency matches the file's estimated_cost_currency, currency_mismatch is False.
    """
    f = ImportFile(
        import_file_code="IMP-2026-USD-01",
        custom_file_number="FILE-USD-01",
        company_name="USD Importer Ltd",
        supplier_name="Global Supplier",
        estimated_cost=50000.0,
        estimated_cost_currency="USD",
        is_active=True,
    )
    db.add(f)
    db.commit()
    db.refresh(f)

    session_create = InvoiceBLMatchSessionCreate(
        import_file_id=f.import_file_id,
        invoice_number="INV-11",
        bl_number="MEDU3",
        is_draft=False,
        is_safe_for_certification=True,
        critical_discrepancies_count=0,
        invoice_data={"invoice_number": "INV-11", "currency": "USD", "incoterm": "FOB"},
        bl_data={"draft_bl_number": "MEDU3"},
    )

    created_session = doc_service.create_invoice_bl_match_session_service(db, session_create, user="certifier")

    db.refresh(f)
    assert f.estimated_cost_currency == "USD"
    assert created_session.currency_mismatch is False
