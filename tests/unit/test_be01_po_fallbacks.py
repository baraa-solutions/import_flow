"""
Unit tests for BE01-T21 (Task 189):
PO invented fallbacks (clone qty, balance currency).
Verifies:
1. PO clone copies quantity, qty_pcs, qty_pkg as stored (does not invent 1.0 fallback).
2. POBalanceSummaryResponse.currency_code is None when the PO has no linked currency (does not invent "USD").
3. POBalanceSummaryResponse.currency_code preserves the linked currency when present.
"""
from datetime import date, timedelta
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.currencies.model import Currency
from modules.import_companies.model import ImportCompany
from modules.incoterms.model import Incoterm
from modules.projects.model import Project
from modules.purchase_orders.model import PurchaseOrder, POLineItem, PackingListItem
from modules.purchase_orders.schemas import (
    ClonePurchaseOrderRequest,
    POBalanceSummaryResponse,
)
from modules.purchase_orders.service import PurchaseOrderService
from modules.suppliers.model import Supplier


@pytest.fixture
def db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(autocommit=False, autoflush=False, bind=engine)()
    yield session
    session.close()
    engine.dispose()


@pytest.fixture
def master_data(db):
    today = date.today()
    comp = ImportCompany(
        company_id=1,
        importer_name="Test Company",
        address="Cairo",
        country="Egypt",
        importer_id="IMP-100",
        importer_id_expiry=today + timedelta(days=120),
        vat_id="VAT-100",
        vat_id_expiry=today + timedelta(days=90),
        registration_number="REG-100",
        registration_expiry=today + timedelta(days=60),
        is_active=True,
    )
    supp = Supplier(
        supplier_id=1,
        company_name="Test Supplier",
        supplier_code="SUP-001",
        supplier_type="Manufacturer",
        registration_type="CargoX",
        foreign_exporter_id="EXP-100",
        foreign_exporter_country="Germany",
        foreign_exporter_country_code="DE",
        address="Berlin",
        is_active=True,
    )
    inco = Incoterm(incoterm_id=1, incoterm_code="FOB", incoterm_name="Free on Board", is_active=True)
    usd = Currency(currency_id=1, currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    eur = Currency(currency_id=2, currency_code="EUR", currency_name="Euro", currency_symbol="€", is_active=True)
    proj = Project(
        project_id=1,
        project_name="Test Project",
        project_code="PRJ-001",
        project_owner="Eng. Test",
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        is_active=True,
    )
    db.add_all([comp, supp, inco, usd, eur, proj])
    db.commit()
    return {"comp": comp, "supp": supp, "inco": inco, "usd": usd, "eur": eur, "proj": proj}


def test_clone_copies_stored_quantities_without_invented_fallbacks(db, master_data):
    service = PurchaseOrderService(db)

    # Create original PO with specific quantities
    po = PurchaseOrder(
        po_number="PO-ORIG-001",
        po_reference="REF-001",
        company_id=1,
        supplier_id=1,
        project_id=1,
        incoterm_id=1,
        currency_id=master_data["usd"].currency_id,
        exchange_rate=50.0,
        status="APPROVED",
        is_active=True,
    )
    db.add(po)
    db.flush()

    line = POLineItem(
        po_id=po.po_id,
        item_code="RAW-001",
        description_ar="مادة خام أصلية",
        quantity=250.0,
        unit_price=10.0,
        total_price=2500.0,
    )
    packing = PackingListItem(
        po_id=po.po_id,
        hs_code="8471.30",
        item_code="RAW-001",
        qty_pcs=500.0,
        qty_pkg=25.0,
    )
    db.add_all([line, packing])
    db.commit()

    # Clone the PO
    clone_req = ClonePurchaseOrderRequest(
        new_po_number="PO-CLONE-001",
        notes="Cloned for testing BE01-T21",
    )
    cloned_resp = service.clone_purchase_order(po.po_id, clone_req, current_user_name="tester")

    assert cloned_resp.po_number == "PO-CLONE-001"
    assert len(cloned_resp.items) == 1
    assert cloned_resp.items[0].quantity == 250.0

    assert len(cloned_resp.packing_list_items) == 1
    assert cloned_resp.packing_list_items[0].qty_pcs == 500.0
    assert cloned_resp.packing_list_items[0].qty_pkg == 25.0


def test_po_balance_without_currency_returns_none(db, master_data):
    service = PurchaseOrderService(db)

    # PO with unlinked/orphaned currency_id (no linked Currency object)
    po = PurchaseOrder(
        po_number="PO-NO-CURR-001",
        po_reference="REF-NO-CURR",
        company_id=1,
        supplier_id=1,
        project_id=1,
        incoterm_id=1,
        currency_id=9999,
        exchange_rate=1.0,
        status="APPROVED",
        is_active=True,
    )
    db.add(po)
    db.flush()

    line = POLineItem(
        po_id=po.po_id,
        item_code="ITEM-X",
        description_ar="صنف بدون عملة",
        quantity=100.0,
        unit_price=5.0,
        total_price=500.0,
    )
    db.add(line)
    db.commit()

    balance: POBalanceSummaryResponse = service.compute_po_balance(po.po_id)
    assert balance.currency_code is None
    # Ensure "USD" was NOT invented
    assert "USD" not in (balance.currency_code or "")


def test_po_balance_with_valid_currency_preserves_code(db, master_data):
    service = PurchaseOrderService(db)

    po = PurchaseOrder(
        po_number="PO-EUR-001",
        po_reference="REF-EUR",
        company_id=1,
        supplier_id=1,
        project_id=1,
        incoterm_id=1,
        currency_id=master_data["eur"].currency_id,
        exchange_rate=54.0,
        status="APPROVED",
        is_active=True,
    )
    db.add(po)
    db.flush()

    line = POLineItem(
        po_id=po.po_id,
        item_code="ITEM-EUR",
        description_ar="صنف يورو",
        quantity=50.0,
        unit_price=20.0,
        total_price=1000.0,
    )
    db.add(line)
    db.commit()

    balance: POBalanceSummaryResponse = service.compute_po_balance(po.po_id)
    assert balance.currency_code == "EUR"
