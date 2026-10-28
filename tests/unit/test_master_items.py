"""
Unit tests for Master Items Module (MD-ITEM-001)
Tests CRUD operations, validations, supplier linkages, price histories, and trend analytics.
"""

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi import HTTPException

import main
from database.database import Base
from modules.customs_tariff.model import CustomsTariff
from modules.suppliers.model import Supplier
from modules.purchase_orders.model import PurchaseOrder, POLineItem
from modules.import_files.model import ImportFile
from modules.master_items.model import (
    MasterItem,
    ItemSupplierCatalog,
    ItemPriceHistory,
)
from modules.master_items.schemas import (
    MasterItemCreate,
    MasterItemUpdate,
    ItemSupplierCatalogCreate,
    ItemPriceHistoryCreate,
)
from modules.master_items.service import MasterItemService


@pytest.fixture(scope="function")
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()

    # Seed test tariff
    tariff = CustomsTariff(
        tariff_id=101,
        hs_code="8415820010",
        hs_description="Chiller Air Conditioners",
        customs_duty_rate=5.0,
        vat_rate=14.0,
        schedule_tax_rate=8.0,
        is_active=True,
    )
    session.add(tariff)

    # Seed test supplier
    supplier = Supplier(
        supplier_id=201,
        supplier_code="SUP-TEST-001",
        company_name="Shenzhen Logistics Tech Co.",
        supplier_type="Manufacturer",
        registration_type="CargoX",
        foreign_exporter_id="EXP-12345",
        foreign_exporter_country="China",
        foreign_exporter_country_code="CN",
        address="Shenzhen, China",
        currency="USD",
        is_active=True,
    )
    session.add(supplier)

    session.commit()
    yield session
    session.close()


def test_create_master_item_and_cache_tariff(db_session):
    payload = MasterItemCreate(
        item_code="CHILLER-IND-01",
        description_ar="وحدة تبريد مياه صناعية 50 طن",
        description_en="50 Ton Industrial Chiller Unit",
        tariff_id=101,
        default_uom="SET",
        default_pkg_type="Wooden Crate",
        cbm_per_unit=4.5,
        gross_weight_kg=1200.0,
        net_weight_kg=1100.0,
        product_category="HVAC",
    )

    created = MasterItemService.create_item(db_session, payload, current_username="test_admin")

    assert created.item_id is not None
    assert created.item_code == "CHILLER-IND-01"
    assert created.description_ar == "وحدة تبريد مياه صناعية 50 طن"
    assert created.hs_code == "8415820010"
    assert created.last_customs_duty_pct == 5.0
    assert created.last_vat_pct == 14.0
    assert created.last_schedule_tax_pct == 8.0
    assert created.default_uom == "SET"


def test_unique_item_code_validation(db_session):
    payload = MasterItemCreate(
        item_code="DUP-CODE-01",
        description_ar="صنف أول",
    )
    MasterItemService.create_item(db_session, payload)

    # Attempt to create duplicate item_code
    duplicate = MasterItemCreate(
        item_code="DUP-CODE-01",
        description_ar="صنف مكرر",
    )
    with pytest.raises(HTTPException) as exc_info:
        MasterItemService.create_item(db_session, duplicate)
    assert exc_info.value.status_code == 400
    assert exc_info.value.detail["code"] == "ITEM_CODE_ALREADY_EXISTS"


def test_update_master_item(db_session):
    created = MasterItemService.create_item(
        db_session,
        MasterItemCreate(
            item_code="UPDATE-TEST-01",
            description_ar="صنف قابل للتعديل",
            cbm_per_unit=1.0,
        ),
    )

    updated = MasterItemService.update_item(
        db_session,
        created.item_id,
        MasterItemUpdate(
            description_ar="صنف تم تحديثه",
            cbm_per_unit=2.5,
        ),
        current_username="editor_user",
    )

    assert updated.description_ar == "صنف تم تحديثه"
    assert updated.cbm_per_unit == 2.5
    assert updated.updated_by == "editor_user"


def test_soft_delete_master_item(db_session):
    created = MasterItemService.create_item(
        db_session,
        MasterItemCreate(
            item_code="DELETE-TEST-01",
            description_ar="صنف قابل للحذف",
        ),
    )

    res = MasterItemService.delete_item(db_session, created.item_id, current_username="deleter")
    assert res["success"] is True

    # Ensure get fails with 404
    with pytest.raises(HTTPException) as exc_info:
        MasterItemService.get_item(db_session, created.item_id)
    assert exc_info.value.status_code == 404


def test_search_and_list_items(db_session):
    MasterItemService.create_item(
        db_session,
        MasterItemCreate(
            item_code="YH-625",
            description_ar="ألواح ألياف بوليستر صوتية YH-625",
            product_category="Acoustic Panels",
        ),
    )
    MasterItemService.create_item(
        db_session,
        MasterItemCreate(
            item_code="YH-808",
            description_ar="ألواح ديكورية عازلة YH-808",
            product_category="Acoustic Panels",
        ),
    )
    MasterItemService.create_item(
        db_session,
        MasterItemCreate(
            item_code="VALVE-01",
            description_ar="صمام هيدروليكي صناعي",
            product_category="Hydraulics",
        ),
    )

    # Search by code
    res = MasterItemService.list_items(db_session, search="YH-")
    assert res.total == 2
    assert len(res.items) == 2

    # Filter by category
    cat_res = MasterItemService.list_items(db_session, category="Hydraulics")
    assert cat_res.total == 1
    assert cat_res.items[0].item_code == "VALVE-01"


def test_supplier_catalog_linkage(db_session):
    item = MasterItemService.create_item(
        db_session,
        MasterItemCreate(
            item_code="PANEL-A1",
            description_ar="لوح عازل للصوت A1",
        ),
    )

    link_payload = ItemSupplierCatalogCreate(
        item_id=item.item_id,
        supplier_id=201,
        supplier_item_code="SZ-PANEL-EX",
        supplier_description="Export Grade Acoustic Panel A1",
        last_confirmed_price=12.50,
        last_confirmed_currency="USD",
        min_order_qty=500.0,
        lead_time_days=25,
        is_preferred_supplier=True,
    )

    catalog = MasterItemService.link_supplier(db_session, link_payload)
    assert catalog.catalog_id is not None
    assert catalog.supplier_name == "Shenzhen Logistics Tech Co."
    assert catalog.last_confirmed_price == 12.50
    assert catalog.is_preferred_supplier is True

    # Listing suppliers for item
    suppliers = MasterItemService.list_suppliers_for_item(db_session, item.item_id)
    assert len(suppliers) == 1
    assert suppliers[0].supplier_item_code == "SZ-PANEL-EX"

    # Duplicate link prevention
    with pytest.raises(HTTPException) as exc_info:
        MasterItemService.link_supplier(db_session, link_payload)
    assert exc_info.value.status_code == 400
    assert exc_info.value.detail["code"] == "ITEM_SUPPLIER_LINK_EXISTS"


def test_price_history_and_trend_analytics(db_session):
    item = MasterItemService.create_item(
        db_session,
        MasterItemCreate(
            item_code="TREND-ITEM-01",
            description_ar="صنف لاختبار تقارير الأسعار",
        ),
    )

    # Record 3 purchase deals
    # Deal 1: 10.0 USD, landed cost 620 EGP (rate 50, so FOB 500 EGP, markup 24%)
    MasterItemService.record_price_history(
        db_session,
        ItemPriceHistoryCreate(
            item_id=item.item_id,
            supplier_id=201,
            unit_price_fx=10.0,
            currency="USD",
            exchange_rate=50.0,
            unit_price_egp=500.0,
            landed_cost_egp=620.0,
            landed_cost_markup=24.0,
            quantity=100.0,
            po_date="2026-01-15",
        ),
    )

    # Deal 2: 12.0 USD, landed cost 756 EGP (rate 50, FOB 600 EGP, markup 26%)
    MasterItemService.record_price_history(
        db_session,
        ItemPriceHistoryCreate(
            item_id=item.item_id,
            supplier_id=201,
            unit_price_fx=12.0,
            currency="USD",
            exchange_rate=50.0,
            unit_price_egp=600.0,
            landed_cost_egp=756.0,
            landed_cost_markup=26.0,
            quantity=150.0,
            po_date="2026-03-20",
        ),
    )

    # Deal 3: 11.0 USD, landed cost 682 EGP (rate 50, FOB 550 EGP, markup 24%)
    MasterItemService.record_price_history(
        db_session,
        ItemPriceHistoryCreate(
            item_id=item.item_id,
            supplier_id=201,
            unit_price_fx=11.0,
            currency="USD",
            exchange_rate=50.0,
            unit_price_egp=550.0,
            landed_cost_egp=682.0,
            landed_cost_markup=24.0,
            quantity=200.0,
            po_date="2026-05-10",
        ),
    )

    trends = MasterItemService.get_price_trends(db_session, item.item_id)
    assert trends.total_purchases_count == 3
    assert trends.min_unit_price_fx == 10.0
    assert trends.max_unit_price_fx == 12.0
    assert trends.average_unit_price_fx == 11.0
    assert trends.average_landed_cost_egp == pytest.approx(686.0, 0.1)
    assert trends.average_markup_percent == pytest.approx(24.67, 0.1)
    assert len(trends.history) == 3
