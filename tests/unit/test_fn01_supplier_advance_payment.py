"""
Unit Tests for Task FN-01: Supplier Advance Payment Request (إصدار طلب سداد الدفعة المقدمة للمورد)
Stage 2: Financial Approvals & Down Payments
"""

import pytest
from datetime import date, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient

from database.database import Base, get_db
from main import app

from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.projects.model import Project
from modules.incoterms.model import Incoterm
from modules.currencies.model import Currency, ExchangeRate
from modules.customs_tariff.model import CustomsTariff
from modules.purchase_orders.model import PurchaseOrder, POLineItem
from modules.import_files.model import ImportFile
from modules.notifications.model import SystemNotification
from modules.smart_tasks.model import SmartTask
from modules.lifecycle_board.model import ShipmentStageActivity
from modules.financial_approval.schemas import PaymentRequestCreate
from modules.financial_approval.service import (
    create_payment_request_service,
    get_budget_prefill_service,
)
from fastapi import HTTPException


from sqlalchemy.pool import StaticPool


@pytest.fixture
def db_session():
    """Sets up an isolated SQLite in-memory database."""
    engine = create_engine(
        "sqlite:///:memory:",
        echo=False,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    TestingSession = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSession()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def seed_data(db_session):
    """Seeds baseline data: company, supplier with bank info, incoterm, currency, PO, import file."""
    company = ImportCompany(
        company_id=1,
        importer_name="Delta Industrial Manufacturing SAE",
        vat_id="100-200-300",
        registration_number="CR-778899",
        address="Industrial Zone, 10th of Ramadan",
        country="Egypt",
        importer_id="IMP-EG-100200",
        importer_id_expiry=date(2028, 1, 1),
        vat_id_expiry=date(2028, 1, 1),
        registration_expiry=date(2028, 1, 1),
    )
    db_session.add(company)

    # 2. Supplier with full banking details
    supplier = Supplier(
        supplier_id=1,
        supplier_code="SUP-CN-001",
        company_name="Shanghai Extrusion Machinery Co., Ltd",
        supplier_type="Manufacturer",
        registration_type="Direct",
        foreign_exporter_id="EXP-CN-889911",
        cargox_platform_id="CGX-CN-889911",
        foreign_exporter_country="China",
        foreign_exporter_country_code="CN",
        address="Pudong New District, Shanghai, China",
        email="export@shanghaiextrusion.cn",
        bank_name="Bank of China - Shanghai Pudong Branch",
        swift_code="BKCHCN2S",
        account_number="662288990011",
        iban="CN66BKCH662288990011",
    )
    db_session.add(supplier)

    # 3. Project
    project = Project(
        project_id=1,
        project_code="PRJ-2026-001",
        project_name="Extruder Line Expansion 2026",
        project_owner="Finance Manager",
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        total_budget_usd=250000.0,
    )
    db_session.add(project)

    # 4. Incoterm
    incoterm = Incoterm(incoterm_id=1, incoterm_code="FOB", incoterm_name="Free On Board")
    db_session.add(incoterm)

    # 5. Currency & Exchange Rate (USD = 48.50 EGP)
    currency = Currency(
        currency_id=1,
        currency_code="USD",
        currency_name="US Dollar",
        currency_symbol="$",
        is_active=True,
    )
    db_session.add(currency)
    db_session.commit()

    rate = ExchangeRate(
        currency_id=1,
        commercial_rate=48.50,
        customs_rate=48.40,
        effective_date=date.today(),
        is_active=True,
    )
    db_session.add(rate)

    # 6. Customs Tariff
    tariff = CustomsTariff(
        tariff_id=1,
        hs_code="8477.20.00",
        hs_description="ماكينات بثق اللدائن والمطاط - Extruders for rubber or plastics",
        customs_duty_rate=5.0,
        vat_rate=14.0,
    )
    db_session.add(tariff)
    db_session.commit()

    # 7. Import File
    imp_file = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        custom_file_number="6701068100",
        company_id=1,
        company_name="Delta Industrial Manufacturing SAE",
        supplier_id=1,
        supplier_name="Shanghai Extrusion Machinery Co., Ltd",
        shipment_mode="Sea FCL",
        current_stage="Phase 1: Import Planning & Feasibility",
        current_module="STEP_01: دراسات ومفاضلة نولون الشحن",
        progress_percent=15.0,
        po_ids=[1],
        is_active=True,
    )
    db_session.add(imp_file)
    db_session.commit()

    # 8. Purchase Order with 2 Line Items ($85,000 total)
    po = PurchaseOrder(
        po_id=1,
        po_number="PO-2026-8801",
        po_reference="Extruder Machine Line - 500kW",
        proforma_invoice_number="PI-2026-8801",
        import_file_id=1,
        project_id=1,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        currency_id=1,
        exchange_rate=48.50,
        total_amount_fob=85000.0,
        payment_terms="30% Advance, 70% against Shipping Docs",
        status="Draft",
        is_active=True,
    )
    db_session.add(po)
    db_session.commit()

    po_item1 = POLineItem(
        po_id=1,
        item_code="EXT-500",
        description_ar="ماكينة بثق صناعية 500 كيلوواط",
        description_en="Industrial Extruder Machine 500kW",
        quantity=2.0,
        unit_price=30000.0,
        tariff_id=1,
        net_weight_kg=8500.0,
        gross_weight_kg=9200.0,
    )
    po_item2 = POLineItem(
        po_id=1,
        item_code="SPR-100",
        description_ar="وحدات هيدروليكية وقطع غيار",
        description_en="Hydraulic Units & Spare Parts Kits",
        quantity=5.0,
        unit_price=5000.0,
        tariff_id=1,
        net_weight_kg=3200.0,
        gross_weight_kg=3500.0,
    )
    db_session.add_all([po_item1, po_item2])
    db_session.commit()

    return {
        "company": company,
        "supplier": supplier,
        "project": project,
        "import_file": imp_file,
        "po": po,
    }


def test_fn01_supplier_advance_payment_request_creation(db_session, seed_data):
    """
    Test FN-01: Issuing Supplier Advance Payment Request:
    - Calculates 30% advance on PO total ($85,000 -> $25,500 USD).
    - Converts to EGP ($25,500 * 48.50 = 1,236,750 EGP).
    - Generates PAY-2026-XXX payment code.
    - Pre-populates beneficiary bank details from Foreign Supplier.
    - Creates SystemNotification for FINANCE_OFFICER.
    - Creates SmartTask assigned to Finance Officer.
    - Advances Lifecycle Board to STEP_04 (Phase 2).
    """
    po = seed_data["po"]
    supplier = seed_data["supplier"]
    imp_file = seed_data["import_file"]

    advance_percent = 30.0
    advance_amount_usd = float(po.total_amount_fob) * (advance_percent / 100.0)
    assert advance_amount_usd == 25500.0

    payload = PaymentRequestCreate(
        title="30% Advance Payment for Extruder Line (PO-2026-8801)",
        import_file_id=imp_file.import_file_id,
        po_id=po.po_id,
        supplier_id=supplier.supplier_id,
        supplier_name=supplier.company_name,
        payment_type="Advance Payment",
        requested_amount=advance_amount_usd,
        advance_percentage=advance_percent,
        currency_code="USD",
        exchange_rate=48.50,
        due_date=date.today() + timedelta(days=7),
        status="Pending Approval",
        beneficiary_name=supplier.company_name,
        bank_name=supplier.bank_name,
        swift_code=supplier.swift_code,
        iban_account_no=supplier.iban,
        notes="Advance payment required to commence manufacturing.",
    )

    result = create_payment_request_service(db_session, payload)

    # 1. Verification of Created Payment Request
    assert result.payment_id is not None
    assert result.payment_code.startswith("PAY-")
    assert result.requested_amount == 25500.0
    assert result.requested_amount_egp == 25500.0 * 48.50
    assert result.status == "Pending Approval"
    assert result.payment_type == "ADVANCE_PAYMENT"  # Phase 2 quality (C2): PAYMENT_TYPE codes
    assert result.bank_name == "Bank of China - Shanghai Pudong Branch"
    assert result.swift_code == "BKCHCN2S"
    assert result.iban_account_no == "CN66BKCH662288990011"

    # 2. Automated Notification for Finance Department
    notif = (
        db_session.query(SystemNotification)
        .filter(SystemNotification.entity_id == result.payment_id)
        .first()
    )
    assert notif is not None
    assert notif.target_role == "FINANCE_OFFICER"
    assert "Supplier advance payment request" in notif.title
    assert notif.msg_code == "FA_PAYMENT_REQUEST_CREATED"
    assert "USD" in notif.message and "EGP" in notif.message

    # 3. Automated Smart Task for Finance Officer
    task = (
        db_session.query(SmartTask)
        .filter(SmartTask.import_file_id == imp_file.import_file_id)
        .first()
    )
    assert task is not None
    assert task.assigned_user == "Finance Officer"
    assert task.priority == "High"
    assert task.status == "Pending"
    assert task.reminder_type == "Advance Payment"
    assert "advance payment" in task.title
    assert task.msg_code == "FA_TASK_SUPPLIER_PAYMENT"
    assert "USD" in task.description

    # 4. Lifecycle Board Advancement to STEP_04
    db_session.refresh(imp_file)
    assert imp_file.current_module == "STEP_04 Finance Approvals & Budget"
    assert imp_file.next_action_code == "NA_STEP04_APPROVE_ADVANCE_PAYMENT"
    assert imp_file.progress_percent >= 30.0

    step4_activity = (
        db_session.query(ShipmentStageActivity)
        .filter(
            ShipmentStageActivity.import_file_code == imp_file.import_file_code,
            ShipmentStageActivity.step_code == "STEP_04",
        )
        .first()
    )
    assert step4_activity is not None
    assert step4_activity.status in ("In-Progress", "Completed")


def test_fn01_budget_prefill_pulls_supplier_bank_and_po_data(db_session, seed_data):
    """
    Verify get_budget_prefill_service extracts:
    - Supplier bank details (Bank name, SWIFT, IBAN).
    - Linked PO totals and payment terms summary.
    """
    imp_file = seed_data["import_file"]
    prefill = get_budget_prefill_service(db_session, imp_file.import_file_id)

    assert prefill.import_file_id == imp_file.import_file_id
    assert prefill.supplier_name == "Shanghai Extrusion Machinery Co., Ltd"
    assert prefill.bank_name == "Bank of China - Shanghai Pudong Branch"
    assert prefill.swift_code == "BKCHCN2S"
    assert prefill.iban == "CN66BKCH662288990011"
    assert prefill.total_invoice_amount == 85000.0
    assert prefill.invoice_currency == "USD"
    assert len(prefill.linked_pos) == 1
    assert prefill.linked_pos[0].po_number == "PO-2026-8801"
    assert "30% Advance" in prefill.payment_terms_summary


def test_fn01_duplicate_advance_payment_prevention(db_session, seed_data):
    """
    Verify duplicate prevention: Cannot create two active 'Advance Payment' requests for the same import file.
    """
    imp_file = seed_data["import_file"]
    supplier = seed_data["supplier"]

    payload1 = PaymentRequestCreate(
        title="First Advance Payment",
        import_file_id=imp_file.import_file_id,
        supplier_name=supplier.company_name,
        payment_type="Advance Payment",
        requested_amount=25500.0,
        currency_code="USD",
        exchange_rate=48.50,
        due_date=date.today() + timedelta(days=7),
    )
    create_payment_request_service(db_session, payload1)

    # Attempt second advance payment for same file
    payload2 = PaymentRequestCreate(
        title="Second Duplicate Advance Payment",
        import_file_id=imp_file.import_file_id,
        supplier_name=supplier.company_name,
        payment_type="Advance Payment",
        requested_amount=10000.0,
        currency_code="USD",
        exchange_rate=48.50,
        due_date=date.today() + timedelta(days=7),
    )

    with pytest.raises(HTTPException) as exc_info:
        create_payment_request_service(db_session, payload2)
    assert exc_info.value.status_code == 400
    assert "يوجد بالفعل طلب سداد مالي قيد الإجراء" in str(exc_info.value.detail)


def test_fn01_fastapi_rest_api_advance_payment(db_session, seed_data):
    """
    Test REST endpoint POST /api/v1/financial-approval/payment-requests
    """
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    imp_file = seed_data["import_file"]
    supplier = seed_data["supplier"]

    payload = {
        "title": "REST API Advance Payment Request",
        "import_file_id": imp_file.import_file_id,
        "supplier_id": supplier.supplier_id,
        "supplier_name": supplier.company_name,
        "payment_type": "Advance Payment",
        "requested_amount": 25500.0,
        "advance_percentage": 30.0,
        "currency_code": "USD",
        "exchange_rate": 48.50,
        "due_date": (date.today() + timedelta(days=10)).isoformat(),
        "status": "Pending Approval",
        "beneficiary_name": supplier.company_name,
        "bank_name": supplier.bank_name,
        "swift_code": supplier.swift_code,
        "iban_account_no": supplier.iban,
        "notes": "Testing via TestClient",
    }

    response = client.post("/api/v1/financial-approval/payment-requests", json=payload)
    assert response.status_code == 201, response.text
    data = response.json()

    assert data["payment_id"] is not None
    assert data["payment_code"].startswith("PAY-")
    assert data["requested_amount"] == 25500.0
    assert data["requested_amount_egp"] == 25500.0 * 48.50
    assert data["status"] == "Pending Approval"
    assert data["advance_percentage"] == 30.0
    assert data["swift_code"] == "BKCHCN2S"

    app.dependency_overrides.clear()
