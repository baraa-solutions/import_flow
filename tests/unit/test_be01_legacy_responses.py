"""
Unit tests for BE01-T16: Legacy-tolerant response schemas (BE01-F21).

Verifies that response schemas for purchase_orders, customs_consultation, and freight_quotations
tolerate legacy database rows that violate today's input rules (e.g. description_ar="A",
quantity=0, hs_code="8", consultation title="X", quotation ocean_freight_cost=NULL).
List endpoints return 200 without throwing ResponseValidationError, while Create schemas
continue to enforce input validation constraints.
"""
from datetime import date, datetime, timezone, timedelta
from decimal import Decimal
import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from main import app
from database.database import Base, get_db
from modules.currencies.model import Currency
from modules.customs_consultation.model import (
    BrokerPriceList,
    BrokerPriceListItem,
    ClearanceExpenseType,
    CustomsChecklistItem,
    CustomsConsultationSession,
)
from modules.customs_consultation.schemas import (
    BrokerPriceListCreate,
    ClearanceExpenseTypeCreate,
    CustomsConsultationCreate,
)
from modules.customs_tariff.model import CustomsTariff
from modules.external_service_providers.model import ExternalServiceProvider
from modules.freight_quotations.model import FreightQuotationItem, FreightRFQRequest
from modules.freight_quotations.schemas import (
    FreightQuotationItemCreate,
    FreightRFQRequestCreate,
)
from modules.import_companies.model import ImportCompany
from modules.incoterms.model import Incoterm
from modules.projects.model import Project
from modules.purchase_orders.model import PackingListItem, POLineItem, PurchaseOrder
from modules.purchase_orders.schemas import (
    PackingListItemCreate,
    POLineItemCreate,
    PurchaseOrderCreate,
)
from modules.suppliers.model import Supplier
from modules.users.model import User

HEADERS = {"X-User-Role": "ADMIN", "X-User-Name": "admin"}


@pytest.fixture
def db_session():
    engine = create_engine(
        "sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    # Simulate legacy database schema where columns were added as plain nullable columns
    t_fqi = Base.metadata.tables["freight_quotation_items"]
    t_bpli = Base.metadata.tables["broker_price_list_items"]
    orig_fqi = t_fqi.c.ocean_freight_cost.nullable
    orig_bpli = t_bpli.c.standard_price.nullable
    t_fqi.c.ocean_freight_cost.nullable = True
    t_bpli.c.standard_price.nullable = True

    try:
        Base.metadata.create_all(engine)
    finally:
        t_fqi.c.ocean_freight_cost.nullable = orig_fqi
        t_bpli.c.standard_price.nullable = orig_bpli

    db = sessionmaker(autocommit=False, autoflush=False, bind=engine)()

    # Seed User for auth
    user = User(
        user_id=1,
        username="admin",
        full_name="Admin User",
        email="admin@example.com",
        role="ADMIN",
        hashed_password="hashed_pw",
        is_active=True,
    )
    db.add(user)

    # Seed master data for POs
    company = ImportCompany(
        company_id=1,
        importer_name="Legacy Importer LLC",
        address="Cairo",
        country="Egypt",
        importer_id="IMP-100200",
        importer_id_expiry=date.today() + timedelta(days=120),
        vat_id="VAT-998877",
        vat_id_expiry=date.today() + timedelta(days=90),
        registration_number="REG-554433",
        registration_expiry=date.today() + timedelta(days=60),
        is_active=True,
    )
    supplier = Supplier(
        supplier_id=1,
        supplier_code="SUP-001",
        company_name="Legacy Supplier Co",
        supplier_type="Manufacturer",
        registration_type="CargoX",
        foreign_exporter_id="EXP-123",
        foreign_exporter_country="Germany",
        foreign_exporter_country_code="DE",
        address="Berlin",
        is_active=True,
    )
    incoterm = Incoterm(incoterm_id=1, incoterm_code="FOB", incoterm_name="Free On Board", is_active=True)
    currency = Currency(currency_id=1, currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    project = Project(
        project_id=1,
        project_code="PRJ-2026-001",
        project_name="Legacy Project",
        project_owner="Eng. Test",
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        is_active=True,
    )
    tariff = CustomsTariff(
        tariff_id=1,
        hs_code="85414000",
        hs_description="Solar Panels",
        customs_duty_rate=Decimal("5.00"),
        vat_rate=Decimal("14.00"),
        is_active=True,
    )
    broker = ExternalServiceProvider(
        provider_id=1,
        partner_code="ESP-000005",
        partner_name="El-Ahram Customs Broker",
        partner_type="Customs Broker",
        is_active=True,
    )
    carrier = ExternalServiceProvider(
        provider_id=2,
        partner_code="ESP-000003",
        partner_name="Maersk Line Shipping",
        partner_type="Shipping Line",
        is_active=True,
    )

    db.add_all([company, supplier, incoterm, currency, project, tariff, broker, carrier])
    db.commit()

    try:
        yield db
    finally:
        db.close()
        engine.dispose()


@pytest.fixture
def client(db_session):
    def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    try:
        yield TestClient(app, raise_server_exceptions=False)
    finally:
        app.dependency_overrides.clear()


# =========================================================================
# 1. Purchase Orders: Legacy-Tolerant Responses
# =========================================================================

def test_purchase_orders_list_tolerates_short_desc_zero_qty_and_short_hs(db_session, client):
    """
    Acceptance criteria:
    - Stored raw po_line_items with description_ar="A" (min_length=2 on create) and quantity=0 (gt=0 on create).
    - Stored raw packing_list_items with hs_code="8" (min_length=2 on create) and qty_pcs=0 (gt=0 on create).
    - GET /api/v1/purchase-orders returns 200 and serializes the legacy rows without 500.
    - Create schemas still reject those invalid inputs.
    """
    po = PurchaseOrder(
        po_number="PO-LEGACY-001",
        po_reference="PO Ref",
        project_id=1,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        currency_id=1,
        exchange_rate=50.0,
        total_amount_fob=0.0,
        total_cbm=0.0,
        total_gross_weight_kg=0.0,
        total_net_weight_kg=0.0,
        total_packages_count=0,
        status="DRAFT",
        is_active=True,
        created_by="admin",
        updated_by="admin",
    )
    db_session.add(po)
    db_session.commit()
    db_session.refresh(po)

    # Insert raw po_line_item violating create constraints: description_ar="A", quantity=0
    raw_item = POLineItem(
        po_id=po.po_id,
        item_code="RAW-1",
        description_ar="A",  # 1 char: violates min_length=2
        quantity=0.0,        # 0.0: violates gt=0
        unit_of_measure="PCS",
        unit_price=0.0,
        total_price=0.0,
        cbm_per_unit=0.0,
        total_cbm=0.0,
        gross_weight_kg=0.0,
        net_weight_kg=0.0,
    )
    # Insert raw packing_list_item violating create constraints: hs_code="8", qty_pcs=0
    raw_pkg = PackingListItem(
        po_id=po.po_id,
        hs_code="8",         # 1 char: violates min_length=2
        item_code="RAW-1",
        qty_pcs=0.0,         # 0.0: violates gt=0
        qty_pkg=0.0,         # 0.0: violates gt=0
        package_type="Carton",
        net_weight_unit_kg=0.0,
        gross_weight_unit_kg=0.0,
        total_net_weight_kg=0.0,
        total_gross_weight_kg=0.0,
        total_cbm=0.0,
        chargeable_weight_kg=0.0,
        is_stackable=True,
    )
    db_session.add_all([raw_item, raw_pkg])
    db_session.commit()

    # GET /api/v1/purchase-orders must return 200 without ResponseValidationError
    res = client.get("/api/v1/purchase-orders", headers=HEADERS)
    assert res.status_code == 200, res.text
    records = res.json()
    assert len(records) >= 1
    target = next(r for r in records if r["po_number"] == "PO-LEGACY-001")
    assert target["po_id"] == po.po_id

    # Verify line items serialized correctly
    assert len(target["items"]) == 1
    assert target["items"][0]["description_ar"] == "A"
    assert target["items"][0]["quantity"] == 0.0

    # Verify packing list items serialized correctly
    assert len(target["packing_list_items"]) == 1
    assert target["packing_list_items"][0]["hs_code"] == "8"
    assert target["packing_list_items"][0]["qty_pcs"] == 0.0

    # Detail endpoint also succeeds
    detail_res = client.get(f"/api/v1/purchase-orders/{po.po_id}", headers=HEADERS)
    assert detail_res.status_code == 200, detail_res.text

    # But Create schemas still enforce validation
    with pytest.raises(ValidationError):
        POLineItemCreate(description_ar="A", quantity=10.0)

    with pytest.raises(ValidationError):
        POLineItemCreate(description_ar="Valid Arabic", quantity=0.0)

    with pytest.raises(ValidationError):
        PackingListItemCreate(hs_code="8", item_code="RAW-1", qty_pcs=1.0, qty_pkg=1.0)

    with pytest.raises(ValidationError):
        PackingListItemCreate(hs_code="8541", item_code="RAW-1", qty_pcs=0.0, qty_pkg=1.0)


# =========================================================================
# 2. Customs Consultation: Legacy-Tolerant Responses
# =========================================================================

def test_customs_consultation_list_tolerates_short_title(db_session, client):
    """
    Acceptance criteria:
    - Stored raw customs_consultations with title="X" (min_length=2 on create).
    - Stored raw clearance_expense_types with name_ar="C" (min_length=2 on create).
    - Stored raw broker_price_lists with title="B" and items with standard_price=NULL.
    - List endpoints return 200 and serialize the rows.
    - Create schemas still reject invalid input.
    """
    # 1. Raw consultation with short title
    consultation = CustomsConsultationSession(
        consultation_code="CSL-LEGACY-001",
        title="X",  # 1 char: violates min_length=2
        broker_id=1,
        broker_name="El-Ahram Customs Broker",
        overall_status="Pending Review",
        estimated_duties_egp=0.0,
        total_broker_fees_egp=0.0,
        is_active=True,
        created_by="admin",
        updated_by="admin",
    )
    db_session.add(consultation)

    # 2. Raw expense type with short name_ar
    expense_type = ClearanceExpenseType(
        expense_code="EXP-LEG-01",
        name_ar="C",  # 1 char: violates min_length=2
        category="Customs Clearance",
        default_unit="PER_INVOICE",
        default_currency="EGP",
        display_order=1,
        is_active=True,
        created_by="admin",
        updated_by="admin",
    )
    db_session.add(expense_type)

    # 3. Raw broker price list with short title and NULL price item
    price_list = BrokerPriceList(
        price_list_code="BPL-LEG-01",
        title="B",  # 1 char: violates min_length=2
        broker_id=1,
        broker_name="El-Ahram Customs Broker",
        effective_from=date(2026, 1, 1),
        version=1,
        is_active=True,
        created_by="admin",
        updated_by="admin",
    )
    db_session.add(price_list)
    db_session.commit()
    db_session.refresh(price_list)

    price_item = BrokerPriceListItem(
        price_list_id=price_list.price_list_id,
        expense_name="E",  # 1 char
        category="Port Expenses",
        unit_type="Per Container",
        standard_price=None,  # Legacy NULL
        currency="EGP",
        is_active=True,
    )
    db_session.add(price_item)
    db_session.commit()
    # Force standard_price to NULL via raw SQL to simulate legacy NULL row
    db_session.execute(
        text("UPDATE broker_price_list_items SET standard_price = NULL WHERE item_id = :id"),
        {"id": price_item.item_id},
    )
    db_session.commit()
    db_session.expire_all()

    # GET /api/v1/customs-consultations
    res_csl = client.get("/api/v1/customs-consultations", headers=HEADERS)
    assert res_csl.status_code == 200, res_csl.text
    records_csl = res_csl.json()
    assert any(r["title"] == "X" for r in records_csl)

    # GET /api/v1/customs-consultations/expense-types
    res_exp = client.get("/api/v1/customs-consultations/expense-types", headers=HEADERS)
    assert res_exp.status_code == 200, res_exp.text
    records_exp = res_exp.json()
    assert any(r["name_ar"] == "C" for r in records_exp)

    # GET /api/v1/customs-consultations/price-lists
    res_bpl = client.get("/api/v1/customs-consultations/price-lists", headers=HEADERS)
    assert res_bpl.status_code == 200, res_bpl.text
    records_bpl = res_bpl.json()
    target_bpl = next(r for r in records_bpl if r["title"] == "B")
    assert target_bpl["items"][0]["expense_name"] == "E"
    assert target_bpl["items"][0]["standard_price"] is None

    # Verify Create schemas still reject short inputs
    with pytest.raises(ValidationError):
        CustomsConsultationCreate(title="X", broker_id=1, broker_name="Broker")

    with pytest.raises(ValidationError):
        ClearanceExpenseTypeCreate(name_ar="C", category="Clearance")

    with pytest.raises(ValidationError):
        BrokerPriceListCreate(title="B", broker_id=1, broker_name="Broker", effective_from=date(2026, 1, 1))


# =========================================================================
# 3. Freight Quotations: Legacy-Tolerant Responses
# =========================================================================

def test_freight_quotations_list_tolerates_null_ocean_freight_cost_and_short_title(db_session, client):
    """
    Acceptance criteria:
    - Stored raw freight_rfq_requests with title="Q" (min_length=2 on create).
    - Stored raw freight_quotations with ocean_freight_cost=NULL (nullable DB column).
    - GET /api/v1/freight-quotations returns 200 and serializes ocean_freight_cost as None.
    - Create schemas still require valid input.
    """
    rfq = FreightRFQRequest(
        rfq_code="RFQ-LEGACY-001",
        title="Q",  # 1 char: violates min_length=2
        shipping_method="Ocean FCL",
        crd_date=date(2026, 9, 1),
        pol_name="Shanghai",
        pod_name="Alexandria",
        status="Draft",
        total_cbm=40.0,
        total_gross_weight_kg=15000.0,
        chargeable_weight_kg=15000.0,
        is_active=True,
    )
    db_session.add(rfq)
    db_session.commit()
    db_session.refresh(rfq)

    # Raw quote with ocean_freight_cost = NULL
    quote = FreightQuotationItem(
        rfq_id=rfq.rfq_id,
        provider_id=2,
        provider_name="Maersk Line Shipping",
        currency_code="USD",
        ocean_freight_cost=None,  # Raw NULL
        local_charges_cost=0.0,
        inland_cost=0.0,
        total_cost=0.0,
        sailing_date=date(2026, 9, 5),
        estimated_arrival_date=date(2026, 10, 1),
        transit_days=26,
        free_days_at_pod=14,
        is_awarded=False,
    )
    db_session.add(quote)
    db_session.commit()
    # Force ocean_freight_cost to NULL via raw SQL to simulate legacy NULL row
    db_session.execute(
        text("UPDATE freight_quotation_items SET ocean_freight_cost = NULL WHERE quotation_id = :id"),
        {"id": quote.quotation_id},
    )
    db_session.commit()
    db_session.expire_all()

    # GET /api/v1/freight-quotations returns 200
    res = client.get("/api/v1/freight-quotations", headers=HEADERS)
    assert res.status_code == 200, res.text
    records = res.json()
    assert len(records) >= 1
    target = next(r for r in records if r["rfq_code"] == "RFQ-LEGACY-001")
    assert target["title"] == "Q"
    assert len(target["quotations"]) == 1
    # ocean_freight_cost must be serialized as null (None), never a fabricated 0.0
    assert target["quotations"][0]["ocean_freight_cost"] is None

    # Detail endpoint also succeeds
    res_detail = client.get(f"/api/v1/freight-quotations/{rfq.rfq_id}", headers=HEADERS)
    assert res_detail.status_code == 200, res_detail.text
    assert res_detail.json()["quotations"][0]["ocean_freight_cost"] is None

    # Verify Create schema still requires valid input
    with pytest.raises(ValidationError):
        FreightRFQRequestCreate(
            title="Q",
            shipping_method="Ocean FCL",
            crd_date=date(2026, 9, 1),
            pol_name="Shanghai",
            pod_name="Alexandria",
        )

    with pytest.raises(ValidationError):
        FreightQuotationItemCreate(
            provider_id=2,
            provider_name="Maersk",
            sailing_date=date(2026, 9, 5),
            estimated_arrival_date=date(2026, 10, 1),
            ocean_freight_cost=None,  # Required ge=0.0 on create
        )
