"""
Unit Tests for Task FN-02: Budget Approval & Swift MT103 (اعتماد الميزانية وسداد السويفت البنكي)
Stage 2: Financial Approvals & Down Payments
"""

import pytest
from datetime import date, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi import HTTPException
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
from modules.financial_approval.model import (
    PaymentRequestSession,
    ImportBudgetApproval,
    BudgetVarianceLog,
)
from modules.financial_approval.schemas import (
    PaymentRequestCreate,
    SwiftReconciliationRequest,
    ImportBudgetCreate,
)
from modules.financial_approval.service import (
    create_payment_request_service,
    create_import_budget_service,
    approve_import_budget_service,
    approve_payment_request_service,
    execute_payment_service,
    reconcile_swift_service,
)


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
    """Seeds baseline master data."""
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

    incoterm = Incoterm(incoterm_id=1, incoterm_code="FOB", incoterm_name="Free On Board")
    db_session.add(incoterm)

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

    tariff = CustomsTariff(
        tariff_id=1,
        hs_code="8477.20.00",
        hs_description="ماكينات بثق اللدائن والمطاط - Extruders for rubber or plastics",
        customs_duty_rate=5.0,
        vat_rate=14.0,
    )
    db_session.add(tariff)
    db_session.commit()

    import_file = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        custom_file_number="6701068100",
        company_id=1,
        company_name="Delta Industrial Manufacturing SAE",
        supplier_id=1,
        supplier_name="Shanghai Extrusion Machinery Co., Ltd",
        shipment_mode="Sea FCL",
        current_stage="Phase 2: Approvals & ACID",
        current_module="STEP_04 اعتمادات الميزانية وسداد الموردين",
        progress_percent=30.0,
        po_ids=[1],
        status="active",
        is_active=True,
    )
    db_session.add(import_file)

    po = PurchaseOrder(
        po_id=1,
        po_number="PO-2026-001",
        po_reference="Extruder Machine Line - 500kW",
        proforma_invoice_number="PI-2026-001",
        import_file_id=1,
        company_id=1,
        supplier_id=1,
        project_id=1,
        incoterm_id=1,
        currency_id=1,
        exchange_rate=48.50,
        total_amount_fob=100000.0,
        payment_terms="30% Advance, 70% against Shipping Documents",
        status="Confirmed",
        is_active=True,
    )
    db_session.add(po)
    db_session.commit()

    return {
        "company": company,
        "supplier": supplier,
        "project": project,
        "import_file": import_file,
        "po": po,
    }


def test_approve_import_budget_workflow(db_session, seed_data):
    """
    Test budget approval workflow:
    - Status set to 'Budget Approved'
    - approved_by and approved_date set
    - SystemNotification created for FINANCE_OFFICER
    - Auto-completes prior budget SmartTask
    - Advances ImportFile lifecycle to STEP_05 (min progress 35%)
    """
    # 1. Create Import Budget
    budget_schema = ImportBudgetCreate(
        title="اعتماد الميزانية التقديرية للشحنة",
        import_file_id=1,
        po_id=1,
        project_id=1,
        exchange_rate=48.50,
        invoice_amount_foreign=100000.0,
        invoice_amount_egp=4850000.0,
        freight_cost_foreign=5000.0,
        freight_cost_egp=242500.0,
        customs_duties_egp=250000.0,
        clearance_inland_egp=50000.0,
        notes="Budget initial draft",
    )
    budget = create_import_budget_service(db_session, budget_schema)
    assert budget.budget_status == "Pending Review"

    # 2. Add an open SmartTask for budget review
    smart_task = SmartTask(
        task_code="TSK-2026-BGT-01",
        title="[IMP-2026-0001] — مراجعة واعتماد الميزانية التقديرية للشحنة",
        description="يرجى مراجعة الميزانية التقديرية واعتمادها للبدء في سداد الدفعة المقدمة للمورد.",
        task_type="System Generated",
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        phase_name="Phase 2: Approvals & ACID",
        assigned_user="Finance Manager",
        priority="High",
        reminder_type="Budget Review",
        status="Pending",
        notes="REQ_TYPE:BUDGET_APPROVAL | File: IMP-2026-0001",
        is_active=True,
    )
    db_session.add(smart_task)
    db_session.commit()

    # 3. Approve the budget
    approved = approve_import_budget_service(
        db=db_session,
        budget_id=budget.budget_id,
        approved_by="Dr. Ahmed Sorour (CFO)",
    )

    # Assertions
    assert approved.budget_status == "Budget Approved"
    assert approved.approved_by == "Dr. Ahmed Sorour (CFO)"
    assert approved.approved_date == date.today()

    # Check notification was created for FINANCE_OFFICER
    notif = db_session.query(SystemNotification).filter(
        SystemNotification.entity_type == "ImportBudget",
        SystemNotification.entity_id == budget.budget_id,
        SystemNotification.target_role == "FINANCE_OFFICER",
    ).first()
    assert notif is not None
    assert "Estimated budget approved" in notif.title
    assert notif.msg_code.startswith("FA_BUDGET_APPROVED")

    # Check SmartTask was auto-completed
    db_session.refresh(smart_task)
    assert smart_task.status == "Completed"
    assert smart_task.is_auto_closed == True

    # Check ImportFile lifecycle advanced to STEP_05
    imp_file = db_session.query(ImportFile).filter(ImportFile.import_file_id == 1).first()
    assert imp_file.progress_percent >= 35.0


def test_approve_import_budget_hard_block_variance(db_session, seed_data):
    """
    Test that unresolved variance exceeding threshold blocks budget approval
    unless override reason is provided.
    """
    budget_schema = ImportBudgetCreate(
        title="ميزانية فارق التكاليف",
        import_file_id=1,
        po_id=1,
        project_id=1,
        exchange_rate=48.50,
        invoice_amount_foreign=100000.0,
        invoice_amount_egp=4850000.0,
        freight_cost_foreign=5000.0,
        freight_cost_egp=242500.0,
        customs_duties_egp=250000.0,
        clearance_inland_egp=50000.0,
        notes="Variance test",
    )
    budget = create_import_budget_service(db_session, budget_schema)

    # Add hard block variance log
    var_log = BudgetVarianceLog(
        budget_id=budget.budget_id,
        import_file_id=1,
        field_name="النولون البحري (Ocean Freight)",
        old_value=242500.0,
        new_value=300000.0,
        variance_amount=57500.0,
        variance_percentage=23.7,
        is_hard_block=True,
        resolution_type="pending",
    )
    db_session.add(var_log)
    budget.has_unresolved_variance = True
    db_session.commit()

    # Attempt approval without override -> Should raise 400 Bad Request
    with pytest.raises(HTTPException) as exc_info:
        approve_import_budget_service(db_session, budget.budget_id)
    assert exc_info.value.status_code == 400
    assert exc_info.value.detail["code"] == "FA_BUDGET_HARD_BLOCK"
    assert "لا يمكن اعتماد الميزانية" in exc_info.value.detail["message"]

    # Provide override reason -> Approval succeeds
    budget.variance_override_reason = "Approved by GM due to peak shipping season rate hike"
    db_session.commit()

    approved = approve_import_budget_service(db_session, budget.budget_id)
    assert approved.budget_status == "Budget Approved"


def test_approve_payment_request_emits_notification(db_session, seed_data):
    """
    Test payment request approval emits SystemNotification for FINANCE_OFFICER.
    """
    payment_schema = PaymentRequestCreate(
        payment_type="Advance Payment",
        title="دفعة مقدمة 30% ماكينات البثق",
        import_file_id=1,
        po_id=1,
        supplier_id=1,
        supplier_name="Shanghai Extrusion Machinery Co., Ltd",
        currency_code="USD",
        exchange_rate=48.50,
        requested_amount=30000.0,
        due_date=date.today() + timedelta(days=5),
        status="Pending Approval",
    )
    payment = create_payment_request_service(db_session, payment_schema)

    approved_pay = approve_payment_request_service(db_session, payment.payment_id)
    assert approved_pay.status == "Approved"

    notif = db_session.query(SystemNotification).filter(
        SystemNotification.entity_type == "PaymentRequest",
        SystemNotification.entity_id == payment.payment_id,
        SystemNotification.target_role == "FINANCE_OFFICER",
        SystemNotification.msg_code.like("FA_PAYMENT_REQUEST_APPROVED%"),
    ).first()
    assert notif is not None
    assert "Payment request approved" in notif.title


def test_execute_payment_advances_lifecycle_and_generates_acid_task(db_session, seed_data):
    """
    Test execute_payment_service:
    - Status set to 'Paid'
    - swift_reference_no recorded
    - swift_no synced to ImportFile
    - Advances lifecycle from STEP_04 to STEP_05
    - Auto-completes prior payment SmartTask
    - Generates ACID SmartTask for Logistics Officer
    - Emits SystemNotification for LOGISTICS_OFFICER
    """
    payment_schema = PaymentRequestCreate(
        payment_type="Advance Payment",
        title="دفعة مقدمة 30% ماكينات البثق",
        import_file_id=1,
        po_id=1,
        supplier_id=1,
        supplier_name="Shanghai Extrusion Machinery Co., Ltd",
        currency_code="USD",
        exchange_rate=48.50,
        requested_amount=30000.0,
        due_date=date.today() + timedelta(days=5),
    )
    payment = create_payment_request_service(db_session, payment_schema)
    # Phase 2 quality (FA-02): create ignores status="Approved"; approval goes through /approve.
    approve_payment_request_service(db_session, payment.payment_id)

    # Execute payment with SWIFT MT103 reference
    paid_item = execute_payment_service(
        db=db_session,
        payment_id=payment.payment_id,
        swift_reference_no="SWF-BKCH-2026-09911",
    )

    # Assertions on payment
    assert paid_item.status == "Paid"
    assert paid_item.swift_reference_no == "SWF-BKCH-2026-09911"

    # Assertions on ImportFile
    imp = db_session.query(ImportFile).filter(ImportFile.import_file_id == 1).first()
    assert imp.swift_no == "SWF-BKCH-2026-09911"
    assert imp.progress_percent >= 35.0

    # Notification for LOGISTICS_OFFICER
    notif = db_session.query(SystemNotification).filter(
        SystemNotification.entity_type == "PaymentRequest",
        SystemNotification.entity_id == payment.payment_id,
        SystemNotification.target_role == "LOGISTICS_OFFICER",
    ).first()
    assert notif is not None
    assert "Payment and SWIFT transfer done" in notif.title
    assert notif.msg_code == "FA_SWIFT_PAID"

    # SmartTask for Logistics Officer to obtain ACID
    acid_task = db_session.query(SmartTask).filter(
        SmartTask.import_file_id == 1,
        SmartTask.title.ilike("%ACID%"),
    ).first()
    assert acid_task is not None
    assert acid_task.assigned_user in ["Logistics Officer", "Kamal"]
    assert acid_task.status == "Pending"


def test_reconcile_swift_service_variance_and_lifecycle(db_session, seed_data):
    """
    Test reconcile_swift_service:
    - Turnaround days calculation
    - Variance calculation (Matched, Deficit, Surplus)
    - Automatically updates swift_no in ImportFile
    - Auto-advances lifecycle to STEP_05
    """
    payment_schema = PaymentRequestCreate(
        payment_type="Advance Payment",
        title="دفعة مقدمة للمورد",
        import_file_id=1,
        po_id=1,
        supplier_id=1,
        supplier_name="Shanghai Extrusion Machinery Co., Ltd",
        currency_code="USD",
        exchange_rate=48.50,
        requested_amount=50000.0,
        due_date=date.today() + timedelta(days=3),
    )
    payment = create_payment_request_service(db_session, payment_schema)
    approve_payment_request_service(db_session, payment.payment_id)  # FA-02: reconcile from Approved only

    # SWIFT reconciliation payload with minor bank fee deficit (-25 USD)
    recon_payload = SwiftReconciliationRequest(
        swift_reference_no="MT103-NBE-778899",
        swift_receipt_date=date.today() + timedelta(days=2),
        swift_transferred_amount=49975.0,
        swift_transferred_currency="USD",
        swift_reconciliation_notes="خصم عمولة مراسل خارجي بقيمة 25 دولار",
    )

    reconciled = reconcile_swift_service(
        db=db_session,
        payment_id=payment.payment_id,
        payload=recon_payload,
    )

    assert reconciled.status == "Paid"
    assert reconciled.swift_reference_no == "MT103-NBE-778899"
    assert reconciled.swift_transferred_amount == 49975.0
    assert reconciled.swift_variance_amount == -25.0
    assert reconciled.swift_variance_status == "Deficit"
    assert reconciled.swift_processing_days >= 2

    # ImportFile synchronization
    imp = db_session.query(ImportFile).filter(ImportFile.import_file_id == 1).first()
    assert imp.swift_no == "MT103-NBE-778899"
    assert imp.progress_percent >= 35.0


def test_api_budget_approve_and_swift_reconcile_endpoints(db_session, seed_data):
    """
    Test REST API endpoints using FastAPI TestClient:
    - POST /api/v1/financial-approval/import-budgets/{id}/approve
    - POST /api/v1/financial-approval/payment-requests/{id}/reconcile-swift
    """
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    try:
        # 1. Test Budget Approve Endpoint
        budget_schema = ImportBudgetCreate(
            title="اعتماد الميزانية التقديرية عبر API",
            import_file_id=1,
            po_id=1,
            project_id=1,
            exchange_rate=48.50,
            invoice_amount_foreign=100000.0,
            invoice_amount_egp=4850000.0,
            freight_cost_foreign=5000.0,
            freight_cost_egp=242500.0,
            customs_duties_egp=250000.0,
            clearance_inland_egp=50000.0,
            notes="API budget test",
        )
        budget = create_import_budget_service(db_session, budget_schema)

        resp_budget = client.post(
            f"/api/v1/financial-approval/import-budgets/{budget.budget_id}/approve",
            params={"approved_by": "Finance Director"},
        )
        assert resp_budget.status_code == 200, resp_budget.text
        data_budget = resp_budget.json()
        assert data_budget["budget_status"] == "Budget Approved"
        # Phase 2 quality (FA-03): the approved_by query parameter is ignored; the approver is the authenticated user.
        assert data_budget["approved_by"] and data_budget["approved_by"] != "Finance Director"

        # 2. Test SWIFT Reconcile Endpoint
        payment_schema = PaymentRequestCreate(
            payment_type="Advance Payment",
            title="طلب دفعة للاختبار عبر API",
            import_file_id=1,
            po_id=1,
            supplier_id=1,
            supplier_name="Shanghai Extrusion Machinery Co., Ltd",
            currency_code="USD",
            exchange_rate=48.50,
            requested_amount=20000.0,
            due_date=date.today() + timedelta(days=7),
            status="Approved",
        )
        pay = create_payment_request_service(db_session, payment_schema)
        assert pay.status == "Draft"  # FA-02: status on create is server-owned
        resp_approve = client.post(f"/api/v1/financial-approval/payment-requests/{pay.payment_id}/approve")
        assert resp_approve.status_code == 200, resp_approve.text

        swift_payload = {
            "swift_reference_no": "SWF-API-TEST-12345",
            "swift_receipt_date": str(date.today()),
            "swift_transferred_amount": 20000.0,
            "swift_transferred_currency": "USD",
            "swift_reconciliation_notes": "مطابقة تامة عبر API",
        }
        resp_swift = client.post(
            f"/api/v1/financial-approval/payment-requests/{pay.payment_id}/reconcile-swift",
            json=swift_payload,
        )
        assert resp_swift.status_code == 200, resp_swift.text
        data_swift = resp_swift.json()
        assert data_swift["status"] == "Paid"
        assert data_swift["swift_reference_no"] == "SWF-API-TEST-12345"
        assert data_swift["swift_variance_status"] == "Matched"
        assert data_swift["swift_variance_amount"] == 0.0

    finally:
        app.dependency_overrides.clear()
