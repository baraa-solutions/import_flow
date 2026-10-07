import pytest
from datetime import date, timedelta
from decimal import Decimal
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from main import app
from database.database import Base, get_db
from modules.import_files.model import ImportFile
from modules.purchase_orders.model import PurchaseOrder, POLineItem
from modules.customs_tariff.model import CustomsTariff, FeeCode
from modules.currencies.model import Currency, ExchangeRate
from modules.freight_quotations.model import FreightRFQRequest, FreightQuotationItem
from modules.financial_settlement.service import simulate_estimated_landed_cost_service
from modules.financial_settlement.schemas import EstimatedLandedCostSimulationRequest


@pytest.fixture
def db_session():
    test_engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=test_engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)
    db = TestingSessionLocal()

    # Seed Fee Codes
    fc1 = FeeCode(
        code="390",
        name_ar="خدمات جمركية",
        collection_group="رسوم النافذة الموحدة",
        calculation_type="flat",
        flat_amount=Decimal("1081.00"),
        is_active=True,
    )
    fc2 = FeeCode(
        code="392",
        name_ar="خدمات معلوماتية",
        collection_group="رسوم النافذة الموحدة",
        calculation_type="flat",
        flat_amount=Decimal("3457.00"),
        is_active=True,
    )
    db.add_all([fc1, fc2])
    db.commit()

    yield db
    db.close()


@pytest.fixture
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    from modules.auth.security import create_access_token, hash_password
    from modules.users.model import User

    user = User(
        username="admin_pl08_test",
        email="admin_pl08@test.com",
        full_name="Admin PL08",
        hashed_password=hash_password("Admin@123"),
        role="ADMIN",
        is_active=True,
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    token = create_access_token({"sub": str(user.user_id), "role": user.role})
    headers = {"Authorization": f"Bearer {token}"}

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app, headers=headers) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture
def base_test_data(db_session):
    # Setup Currency
    usd = Currency(
        currency_code="USD",
        currency_name="US Dollar",
        currency_symbol="$",
        is_active=True,
    )
    db_session.add(usd)
    db_session.flush()

    rate = ExchangeRate(
        currency_id=usd.currency_id,
        customs_rate=Decimal("50.0000"),
        commercial_rate=Decimal("50.0000"),
        effective_date=date.today(),
        is_active=True,
    )
    db_session.add(rate)
    db_session.flush()

    # Setup Tariffs
    tariff1 = CustomsTariff(
        hs_code="8479.89.90",
        hs_description="Industrial Machinery",
        customs_duty_rate=Decimal("5.00"),
        vat_rate=Decimal("14.00"),
        schedule_tax_rate=Decimal("0.00"),
        development_fee_rate=Decimal("0.00"),
        customs_service_fee_rate=Decimal("1.00"),
        is_active=True,
    )
    tariff2 = CustomsTariff(
        hs_code="8504.40.90",
        hs_description="Electrical Converters",
        customs_duty_rate=Decimal("10.00"),
        vat_rate=Decimal("14.00"),
        schedule_tax_rate=Decimal("5.00"),
        development_fee_rate=Decimal("0.00"),
        customs_service_fee_rate=Decimal("1.00"),
        is_active=True,
    )
    db_session.add_all([tariff1, tariff2])
    db_session.flush()

    # Setup Import File
    imp_file = ImportFile(
        import_file_code="IMP-2026-TEST08",
        company_id=1,
        company_name="Test Company",
        supplier_id=1,
        supplier_name="Test Supplier",
        broker_id=1,
        shipment_mode="Sea FCL",
        incoterm_code="FOB",
        estimated_cost=20000.0,
        estimated_cost_currency="USD",
        hs_code="8479.89.90",
        product_category="Testing Machinery",
        is_active=True,
    )
    db_session.add(imp_file)
    db_session.flush()

    from modules.projects.model import Project
    from modules.suppliers.model import Supplier
    from modules.incoterms.model import Incoterm

    supplier = Supplier(
        supplier_code="SUP-EU-001",
        company_name="Test Supplier",
        supplier_type="Manufacturer",
        registration_type="CargoX",
        foreign_exporter_id="EXP-DE-889900",
        foreign_exporter_country="Germany",
        foreign_exporter_country_code="DE",
        address="Germany",
        is_active=True,
    )
    incoterm = Incoterm(incoterm_code="FOB", incoterm_name="Free On Board", is_active=True)
    db_session.add_all([supplier, incoterm])
    db_session.flush()

    project = Project(
        project_code="PRJ-2026-TEST08",
        project_name="Test Project Alpha",
        project_owner="Kamal",
        company_id=1,
        supplier_id=supplier.supplier_id,
        incoterm_id=incoterm.incoterm_id,
        is_active=True,
    )
    db_session.add(project)
    db_session.flush()

    # Setup Purchase Order
    po = PurchaseOrder(
        po_number="PO-2026-0008",
        import_file_id=imp_file.import_file_id,
        project_id=project.project_id,
        company_id=1,
        supplier_id=supplier.supplier_id,
        incoterm_id=incoterm.incoterm_id,
        currency_id=usd.currency_id,
        total_amount_fob=20000.0,
        country_of_origin="CN",
        is_active=True,
    )
    db_session.add(po)
    db_session.flush()

    # PO Items
    item1 = POLineItem(
        po_id=po.po_id,
        item_code="ITM-MAC-01",
        main_description="Machinery A",
        description_ar="ماكينة تعبئة صناعية",
        description_en="Industrial Packing Machine",
        quantity=10,
        unit_price=1500.0,
        total_price=15000.0,
        tariff_id=tariff1.tariff_id,
        gross_weight_kg=3000.0,
        total_cbm=12.0,
        country_of_origin="CN",
    )
    item2 = POLineItem(
        po_id=po.po_id,
        item_code="ITM-CONV-02",
        main_description="Inverter B",
        description_ar="محول طاقة",
        description_en="Power Inverter Converter",
        quantity=50,
        unit_price=100.0,
        total_price=5000.0,
        tariff_id=tariff2.tariff_id,
        gross_weight_kg=1000.0,
        total_cbm=4.0,
        country_of_origin="CN",
    )
    db_session.add_all([item1, item2])
    db_session.commit()

    return {
        "imp_file": imp_file,
        "po": po,
        "tariff1": tariff1,
        "tariff2": tariff2,
        "item1": item1,
        "item2": item2,
        "usd": usd,
    }


def test_estimated_landed_cost_simulation_basic(db_session, base_test_data):
    """
    Test basic calculation of estimated landed cost:
    - Verifies FOB conversion at exchange rate
    - Verifies deemed freight (2%) & insurance (2.5%)
    - Verifies customs duty, VAT, clearance, transport allocation
    - Verifies unit landed cost > FOB unit
    """
    imp_file = base_test_data["imp_file"]
    res = simulate_estimated_landed_cost_service(db_session, imp_file.import_file_id)

    assert res.import_file_id == imp_file.import_file_id
    assert res.total_fob_fc == 20000.0
    assert res.exchange_rate == 50.0
    assert res.total_fob_egp == 1000000.0  # 20,000 * 50

    # Freight deemed 2% of FOB EGP = 20,000
    assert res.total_freight_egp == 20000.0
    # Insurance deemed 2.5% of FOB EGP = 25,000
    assert res.total_insurance_egp == 25000.0

    # Total expenses > 0 and landed cost = FOB + expenses
    assert res.total_expenses_egp > 0
    assert res.total_landed_cost_egp == pytest.approx(res.total_fob_egp + res.total_expenses_egp, 0.01)
    assert res.average_markup_factor > 1.0
    assert res.average_markup_percent > 0.0

    # Items breakdown
    assert len(res.items_breakdown) == 2
    item1_res = next(i for i in res.items_breakdown if i.item_code == "ITM-MAC-01")
    assert item1_res.qty == 10
    assert item1_res.fob_unit_egp == 75000.0  # 1500 * 50
    assert item1_res.unit_landed_cost_egp > item1_res.fob_unit_egp
    assert item1_res.markup_factor > 1.0

    item2_res = next(i for i in res.items_breakdown if i.item_code == "ITM-CONV-02")
    assert item2_res.qty == 50
    assert item2_res.fob_unit_egp == 5000.0  # 100 * 50
    assert item2_res.unit_landed_cost_egp > item2_res.fob_unit_egp

    # Executive summary
    assert "جنيه مصري" in res.executive_summary_ar


def test_estimated_landed_cost_with_awarded_rfq(db_session, base_test_data):
    """
    When an awarded RFQ quotation exists, freight should be pulled from the winning quotation.
    """
    imp_file = base_test_data["imp_file"]

    # Create RFQ with winning quote
    rfq = FreightRFQRequest(
        import_file_id=imp_file.import_file_id,
        rfq_code="RFQ-2026-TEST08",
        title="Freight RFQ Test",
        shipping_method="Ocean FCL",
        crd_date=date.today(),
        pol_name="Shanghai",
        pod_name="Alexandria",
        status="Awarded",
        is_active=True,
    )
    db_session.add(rfq)
    db_session.flush()

    quote = FreightQuotationItem(
        rfq_id=rfq.rfq_id,
        provider_id=1,
        provider_name="Maersk Line",
        ocean_freight_cost=2500.0,
        total_cost=2500.0,
        currency_code="USD",
        sailing_date=date.today(),
        estimated_arrival_date=date.today() + timedelta(days=22),
        transit_days=22,
        is_awarded=True,
    )
    db_session.add(quote)
    db_session.flush()

    rfq.selected_quotation_id = quote.quotation_id
    db_session.commit()

    res = simulate_estimated_landed_cost_service(db_session, imp_file.import_file_id)

    # 2500 USD * 50 EGP = 125,000 EGP
    assert res.total_freight_egp == 125000.0
    freight_exp = next(e for e in res.expenses_breakdown if "Freight" in e.category)
    assert "Maersk Line" in freight_exp.source


def test_estimated_landed_cost_manual_overrides(db_session, base_test_data):
    """
    Test user overrides for freight, insurance, clearance, and transport.
    """
    imp_file = base_test_data["imp_file"]

    overrides = EstimatedLandedCostSimulationRequest(
        exchange_rate_override=52.0,
        freight_amount_egp_override=60000.0,
        insurance_amount_egp_override=15000.0,
        clearance_fees_egp_override=8000.0,
        inland_transport_egp_override=12000.0,
        port_handling_egp_override=7000.0,
        bank_fees_egp_override=3000.0,
        other_expenses_egp_override=2500.0,
        allocation_preference="Weight-Based",
    )

    res = simulate_estimated_landed_cost_service(db_session, imp_file.import_file_id, overrides)

    assert res.exchange_rate == 52.0
    assert res.total_fob_egp == 20000.0 * 52.0
    assert res.total_freight_egp == 60000.0
    assert res.total_insurance_egp == 15000.0
    assert res.total_inland_transport_egp == 12000.0

    # Check that Weight-Based allocation allocated 75% of weight to item 1 (3000kg / 4000kg)
    item1 = next(i for i in res.items_breakdown if i.item_code == "ITM-MAC-01")
    item2 = next(i for i in res.items_breakdown if i.item_code == "ITM-CONV-02")
    assert item1.allocated_inland_transport_egp == pytest.approx(12000.0 * 0.75, 1.0)
    assert item2.allocated_inland_transport_egp == pytest.approx(12000.0 * 0.25, 1.0)


def test_estimated_landed_cost_api_endpoint(client, base_test_data):
    """
    Test POST /api/v1/financial-settlement/simulate-file/{import_file_id} endpoint.
    """
    imp_file = base_test_data["imp_file"]

    # Valid simulation request
    response = client.post(
        f"/api/v1/financial-settlement/simulate-file/{imp_file.import_file_id}",
        json={
            "freight_amount_egp_override": 45000.0,
            "clearance_fees_egp_override": 5000.0,
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["import_file_id"] == imp_file.import_file_id
    assert data["total_freight_egp"] == 45000.0
    assert len(data["items_breakdown"]) == 2
    assert "average_markup_percent" in data

    # Non-existent import file
    err_resp = client.post("/api/v1/financial-settlement/simulate-file/999999")
    assert err_resp.status_code == 404
