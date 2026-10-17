"""
Unit tests for BE01-T06:
Prefill sums values per currency, handles mixed currencies, and separates HS items by (hs_code, currency).
"""
from datetime import date
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main  # Register all models in Base.metadata
from database.database import Base
from modules.currencies.model import Currency
from modules.customs_tariff.model import CustomsTariff
from modules.import_files.model import ImportFile
from modules.import_requirements.service import (
    PREFILL_MIXED_CURRENCY,
    PREFILL_NO_HS,
    get_import_file_prefill_service,
)
from modules.purchase_orders.model import POLineItem, PurchaseOrder


@pytest.fixture
def session_factory():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    yield sessionmaker(bind=engine, autoflush=False)
    engine.dispose()


@pytest.fixture
def db(session_factory):
    session = session_factory()

    # Seed currencies
    usd = Currency(currency_id=1, currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    eur = Currency(currency_id=2, currency_code="EUR", currency_name="Euro", currency_symbol="€", is_active=True)
    session.add_all([usd, eur])
    session.commit()

    # Seed a standard tariff
    tariff = CustomsTariff(
        tariff_id=1,
        hs_code="8415820010",
        hs_description="Air conditioning machines",
        customs_duty_rate=10,
        vat_rate=14,
        effective_from=date(2020, 1, 1),
    )
    session.add(tariff)
    session.commit()

    yield session
    session.close()


def _create_file(db, code="IMP-2026-001", **extra):
    file_obj = ImportFile(
        import_file_code=code,
        company_name="Test Company",
        supplier_name="Test Supplier",
        status="Draft",
        is_active=True,
        **extra,
    )
    db.add(file_obj)
    db.commit()
    db.refresh(file_obj)
    return file_obj


def test_prefill_single_currency_sums_po_lines(db):
    """
    PO1 USD lines 600 + 400, PO2 USD line 500:
    shipment_value == 1500.0, currency == "USD", no PREFILL_MIXED_CURRENCY message.
    """
    file_obj = _create_file(db, code="IMP-2026-PO-SINGLE")

    # PO1 in USD with lines 600 + 400
    po1 = PurchaseOrder(
        po_number="PO-2026-01",
        import_file_id=file_obj.import_file_id,
        currency_id=1,  # USD
        project_id=1,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
    )
    # PO2 in USD with line 500
    po2 = PurchaseOrder(
        po_number="PO-2026-02",
        import_file_id=file_obj.import_file_id,
        currency_id=1,  # USD
        project_id=1,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
    )
    db.add_all([po1, po2])
    db.commit()

    db.add_all([
        POLineItem(po_id=po1.po_id, item_code="L1", description_ar="وصف 1", description_en="Item 1", tariff_id=1, quantity=1, unit_price=600, total_price=600),
        POLineItem(po_id=po1.po_id, item_code="L2", description_ar="وصف 2", description_en="Item 2", tariff_id=1, quantity=1, unit_price=400, total_price=400),
        POLineItem(po_id=po2.po_id, item_code="L3", description_ar="وصف 3", description_en="Item 3", tariff_id=1, quantity=1, unit_price=500, total_price=500),
    ])
    db.commit()

    res = get_import_file_prefill_service(db, file_obj.import_file_id)

    assert res.shipment_value == 1500.0
    assert res.currency == "USD"
    # No mixed currency message
    msg_codes = [m.code for m in res.messages]
    assert PREFILL_MIXED_CURRENCY not in msg_codes
    # Only one HS item grouping lines together
    assert len(res.hs_code_items) == 1
    assert res.hs_code_items[0].hs_code == "8415820010"
    assert res.hs_code_items[0].currency == "USD"
    assert res.hs_code_items[0].item_value == 1500.0


def test_prefill_mixed_currency_returns_none_and_mixed_currency_message(db):
    """
    PO1 USD 1000 + PO2 EUR 500:
    shipment_value is None, currency is None,
    message PREFILL_MIXED_CURRENCY with currencies == "EUR, USD",
    two HS items when both lines share HS 8415820010 (one USD 1000, one EUR 500).
    """
    file_obj = _create_file(db, code="IMP-2026-PO-MIXED")

    # PO1 in USD
    po1 = PurchaseOrder(
        po_number="PO-2026-USD",
        import_file_id=file_obj.import_file_id,
        currency_id=1,  # USD
        project_id=1,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
    )
    # PO2 in EUR
    po2 = PurchaseOrder(
        po_number="PO-2026-EUR",
        import_file_id=file_obj.import_file_id,
        currency_id=2,  # EUR
        project_id=1,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
    )
    db.add_all([po1, po2])
    db.commit()

    db.add_all([
        POLineItem(po_id=po1.po_id, item_code="AC-USD", description_ar="تكييف دولار", description_en="AC USD", tariff_id=1, quantity=2, unit_price=500, total_price=1000),
        POLineItem(po_id=po2.po_id, item_code="AC-EUR", description_ar="تكييف يورو", description_en="AC EUR", tariff_id=1, quantity=1, unit_price=500, total_price=500),
    ])
    db.commit()

    res = get_import_file_prefill_service(db, file_obj.import_file_id)

    # Values must be None
    assert res.shipment_value is None
    assert res.currency is None

    # Message PREFILL_MIXED_CURRENCY must be present with currencies="EUR, USD"
    mixed_msg = next((m for m in res.messages if m.code == PREFILL_MIXED_CURRENCY), None)
    assert mixed_msg is not None
    assert mixed_msg.params.get("currencies") == "EUR, USD"

    # Two separate HS items because currencies differ
    assert len(res.hs_code_items) == 2
    by_curr = {i.currency: i for i in res.hs_code_items}
    assert "USD" in by_curr
    assert "EUR" in by_curr
    assert by_curr["USD"].hs_code == "8415820010"
    assert by_curr["USD"].item_value == 1000.0
    assert by_curr["EUR"].hs_code == "8415820010"
    assert by_curr["EUR"].item_value == 500.0


def test_prefill_single_invoice_currency_sums(db):
    """
    File with no POs, but two invoices both in EUR:
    shipment_value == 500.0, currency == "EUR".
    """
    file_obj = _create_file(
        db,
        code="IMP-2026-INV-SINGLE",
        invoices_data=[
            {"amount": 300.0, "currency": "EUR", "hs_code": "8415820010", "description": "Part A"},
            {"amount": 200.0, "currency": "EUR", "hs_code": "8415820010", "description": "Part B"},
        ],
    )

    res = get_import_file_prefill_service(db, file_obj.import_file_id)

    assert res.shipment_value == 500.0
    assert res.currency == "EUR"
    msg_codes = [m.code for m in res.messages]
    assert PREFILL_MIXED_CURRENCY not in msg_codes


def test_prefill_mixed_invoices_returns_none_and_mixed_currency_message(db):
    """
    File with no POs, but invoices in different currencies:
    shipment_value is None, currency is None, PREFILL_MIXED_CURRENCY present.
    """
    file_obj = _create_file(
        db,
        code="IMP-2026-INV-MIXED",
        invoices_data=[
            {"amount": 400.0, "currency": "USD", "hs_code": "8415820010"},
            {"amount": 250.0, "currency": "EUR", "hs_code": "8415820010"},
        ],
    )

    res = get_import_file_prefill_service(db, file_obj.import_file_id)

    assert res.shipment_value is None
    assert res.currency is None
    mixed_msg = next((m for m in res.messages if m.code == PREFILL_MIXED_CURRENCY), None)
    assert mixed_msg is not None
    assert mixed_msg.params.get("currencies") == "EUR, USD"


def test_prefill_quantity_zero_not_invented_as_one(db):
    """
    PO line with total_price=None, unit_price=50.0, quantity=0.0:
    Line item value is 0.0, does not invent quantity 1.0.
    """
    file_obj = _create_file(db, code="IMP-2026-QTY-ZERO")
    po = PurchaseOrder(
        po_number="PO-2026-Z",
        import_file_id=file_obj.import_file_id,
        currency_id=1,
        project_id=1,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
    )
    db.add(po)
    db.commit()

    db.add(POLineItem(po_id=po.po_id, item_code="Z1", description_ar="كمية صفر", description_en="Zero qty", tariff_id=1, quantity=0.0, unit_price=50.0, total_price=None))
    db.commit()

    res = get_import_file_prefill_service(db, file_obj.import_file_id)
    assert res.shipment_value == 0.0
    assert res.hs_code_items[0].item_value == 0.0


def test_prefill_without_any_data_never_fabricates(db):
    """
    File without POs, invoices or estimated cost:
    shipment_value is None, currency is None, PREFILL_NO_HS message added.
    """
    file_obj = _create_file(db, code="IMP-2026-EMPTY", estimated_cost=0.0, estimated_cost_currency=None)
    res = get_import_file_prefill_service(db, file_obj.import_file_id)

    assert res.shipment_value is None
    assert res.currency is None
    assert res.hs_code_items == []
    assert any(m.code == PREFILL_NO_HS for m in res.messages)
