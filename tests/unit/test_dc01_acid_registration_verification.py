"""
Unit Tests for Task DC-01: ACID Registration & Verification (طلب وقيد الرقم التعريفي المبدئي للشحنة)
Stage 3: Documentation, Nafeza & ACID Operations (BP-014)
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
from modules.currencies.model import Currency
from modules.purchase_orders.model import PurchaseOrder
from modules.import_files.model import ImportFile
from modules.notifications.model import SystemNotification
from modules.smart_tasks.model import SmartTask
from modules.lifecycle_board.model import ShipmentStageActivity
from modules.import_documentation.model import AcidRegistrationSession
from modules.import_documentation.schemas import AcidRegistrationCreate, AcidRegistrationUpdate
from modules.import_documentation.service import (
    create_acid_session_service,
    update_acid_session_service,
    parse_acid_text_service,
    compare_acid_datasets_service,
)
from modules.import_documentation.validators import validate_acid_number, validate_acid_expiry
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
    """Seeds baseline data: company, supplier, project, import file, pending ACID smart task."""
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
    )
    db_session.add(supplier)

    incoterm = Incoterm(incoterm_id=1, incoterm_code="FOB", incoterm_name="Free on Board")
    db_session.add(incoterm)

    project = Project(
        project_id=1,
        project_code="PRJ-2026-001",
        project_name="Extruder Line Expansion 2026",
        project_owner="Logistics Manager",
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        total_budget_usd=500000.0,
    )
    db_session.add(project)

    import_file = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        custom_file_number="FILE-2026-001",
        company_id=1,
        company_name="Delta Industrial Manufacturing SAE",
        supplier_id=1,
        supplier_name="Shanghai Extrusion Machinery Co., Ltd",
        po_number="PO-2026-001",
        pi_number="PI-2026-8899",
        shipment_mode="Sea FCL",
        current_module="Phase 2 - Shipment Initiation",
        current_stage="STEP_05 إصدار رقم ACID نافذة",
        progress_percent=35.0,
        next_action="استخراج وتدقيق الرقم التعريفي المبدئي ACID عبر منظومة نافذة",
        is_active=True,
    )
    db_session.add(import_file)

    # Add prior pending smart task for ACID issuance
    acid_task = SmartTask(
        task_id=1,
        task_code="TSK-ACID-001",
        title="استخراج الرقم التعريفي المبدئي ACID عبر منظومة نافذة (STEP_05)",
        description="التقديم على نافذة للحصول على رقم ACID للشحنة IMP-2026-0001 ومطابقة البيانات.",
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        phase_name="المرحلة الثانية: بداية الشحنة والمالية",
        assigned_user="Logistics Officer",
        priority="High",
        status="Pending",
    )
    db_session.add(acid_task)

    db_session.commit()
    return {
        "company": company,
        "supplier": supplier,
        "project": project,
        "import_file": import_file,
        "acid_task": acid_task,
    }


def test_acid_19_digit_format_validation():
    """Rule ACID-001: Egyptian ACID numbers must be exactly 19 numeric digits, or allow PENDING."""
    # Valid 19 digits must pass without raising exception
    validate_acid_number("1234567890123456789")
    validate_acid_number("5281534391023010013")

    # Valid pending placeholders
    validate_acid_number("PENDING", allow_pending=True)
    validate_acid_number("REQUESTED", allow_pending=True)
    validate_acid_number("DRAFT", allow_pending=True)

    # Invalid: 18 digits or 20 digits
    with pytest.raises(Exception):
        validate_acid_number("123456789012345678")
    with pytest.raises(Exception):
        validate_acid_number("12345678901234567890")

    # Invalid: Non-numeric
    with pytest.raises(Exception):
        validate_acid_number("123456789012345678A")


def test_execution_days_calculation(db_session, seed_data):
    """Verifies that execution_days is accurately computed as (generated_date - requested_date).days."""
    req_date = date(2026, 6, 1)
    gen_date = date(2026, 6, 5)  # 4 execution days
    exp_date = date(2026, 11, 30)

    schema = AcidRegistrationCreate(
        import_file_id=1,
        acid_number="5281534391023010013",
        importer_name="Delta Industrial Manufacturing SAE",
        importer_tax_id="100-200-300",
        exporter_name="Shanghai Extrusion Machinery Co., Ltd",
        exporter_reg_id="EXP-CN-889911",
        exporter_country="China",
        proforma_invoice_no="PI-2026-8899",
        pol_name="Shanghai",
        pod_name="Alexandria",
        requested_date=req_date,
        generated_date=gen_date,
        expiry_date=exp_date,
    )
    result = create_acid_session_service(db_session, schema)

    assert result.acid_number == "5281534391023010013"
    assert result.execution_days == 4
    assert result.days_to_expiry > 0


def test_smart_mts_text_parsing_and_discrepancy(db_session):
    """Verifies smart heuristic parsing of Nafeza MTS text and discrepancy comparison."""
    sample_text = """
    MTS Notification
    Kindly be informed that an Advance Cargo Information request (ACI) has been approved:
    [ACID: 5281534391023010013]
    Requested: 01-Jun-2026 10:00:00 AM   Generated: 04-Jun-2026 02:00:00 PM   Expires: 04-Dec-2026 02:00:00 PM

    Egyptian Importer
    Egyptian Importer Name: Delta Industrial Manufacturing SAE
    Egyptian Importer Tax ID: 100-200-300

    Foreign Exporter
    Foreign Exporter Name: Shanghai Extrusion Machinery Co., Ltd
    Foreign Exporter ID: EXP-CN-889911
    Country of Export: CHINA

    Proforma Invoice No.: PI-2026-8899
    Port of Loading: Shanghai Port
    Port of Discharge: Alexandria Port
    """
    res = parse_acid_text_service(db_session, sample_text)
    parsed = res["parsed_data"]
    assert parsed.get("acid_number") == "5281534391023010013"
    assert parsed.get("importer_tax_id") == "100-200-300"
    assert "Shanghai" in str(parsed.get("pol_name"))

    requested_data = {
        "importer_name": "Delta Industrial Manufacturing SAE",
        "importer_tax_id": "100-200-300",
        "exporter_name": "Shanghai Extrusion Machinery Co., Ltd",
        "exporter_reg_id": "EXP-CN-889911",
        "exporter_country": "CHINA",
        "proforma_invoice_no": "PI-2026-8899",
        "pol_name": "Shanghai Port",
        "pod_name": "Alexandria Port",
    }
    comp = compare_acid_datasets_service(requested_data, parsed)
    assert comp["matched_count"] > 0
    assert len(comp["items"]) > 0
    item_map = {item["field"]: item for item in comp["items"]}
    assert item_map["importer_tax_id"]["is_matched"] is True
    assert item_map["exporter_reg_id"]["is_matched"] is True
    assert item_map["proforma_invoice_no"]["is_matched"] is True


def test_acid_verification_workflow_end_to_end(db_session, seed_data):
    """
    Comprehensive End-to-End DC-01 verification:
    1. Creating/Verifying 19-digit ACID synchronizes ImportFile.
    2. Advances lifecycle step from STEP_05 to STEP_06 with min 40% progress.
    3. Auto-completes prior pending ACID smart task.
    4. Creates next smart task for Freight Booking (BK-01 / STEP_06).
    5. Emits SystemNotification for LOGISTICS_OFFICER.
    """
    req_date = date(2026, 6, 1)
    gen_date = date(2026, 6, 3)  # 2 days
    exp_date = date(2026, 11, 30)

    schema = AcidRegistrationCreate(
        import_file_id=1,
        acid_number="5281534391023010013",
        importer_name="Delta Industrial Manufacturing SAE",
        importer_tax_id="100-200-300",
        exporter_name="Shanghai Extrusion Machinery Co., Ltd",
        exporter_reg_id="EXP-CN-889911",
        exporter_country="China",
        proforma_invoice_no="PI-2026-8899",
        pol_name="Shanghai",
        pod_name="Alexandria",
        requested_date=req_date,
        generated_date=gen_date,
        expiry_date=exp_date,
    )

    created_resp = create_acid_session_service(db_session, schema)
    assert created_resp.acid_number == "5281534391023010013"

    # Now verify the session
    update_schema = AcidRegistrationUpdate(
        status="Verified",
        verification_notes="All documents and Nafeza MTS data strictly matched.",
    )
    verified_resp = update_acid_session_service(db_session, created_resp.acid_id, update_schema)
    assert verified_resp.status == "Verified"

    # 1. Verify ImportFile two-way synchronization
    imp_file = db_session.query(ImportFile).filter(ImportFile.import_file_id == 1).first()
    assert imp_file.acid_number == "5281534391023010013"
    assert imp_file.acid_request_date == req_date
    assert imp_file.acid_issue_date == gen_date
    assert imp_file.acid_expiry_date == exp_date
    assert imp_file.acid_execution_days == 2

    # 2. Verify lifecycle auto-advancement to STEP_06 (Phase 3: Booking & Doc Prep)
    assert imp_file.current_module == "STEP_06 Freight Booking"
    assert imp_file.next_action_code == "NA_STEP06_CONFIRM_BOOKING"
    assert (imp_file.progress_percent or 0.0) >= 40.0

    # 3. Verify prior pending ACID task is completed
    prior_task = db_session.query(SmartTask).filter(SmartTask.task_id == 1).first()
    assert prior_task.status == "Completed"

    # 4. Verify new SmartTask dispatched for Freight Booking (BK-01 / STEP_06)
    booking_task = (
        db_session.query(SmartTask)
        .filter(
            SmartTask.import_file_id == 1,
            SmartTask.assigned_user == "Logistics Officer",
            SmartTask.status == "Pending",
        )
        .first()
    )
    assert booking_task is not None
    assert "freight booking" in booking_task.title
    assert "BK-01" in booking_task.title

    # 5. Verify SystemNotification emitted
    notif = (
        db_session.query(SystemNotification)
        .filter(
            SystemNotification.category == "ACID_VERIFICATION",
            SystemNotification.entity_id == created_resp.acid_id,
        )
        .first()
    )
    assert notif is not None
    assert "5281534391023010013" in notif.title
    assert notif.target_role == "LOGISTICS_OFFICER"


def test_api_acid_registration_endpoints(db_session, seed_data):
    """Verifies FastAPI REST endpoints for ACID session creation and update."""
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    payload = {
        "import_file_id": 1,
        "acid_number": "5281534391023010013",
        "importer_name": "Delta Industrial Manufacturing SAE",
        "importer_tax_id": "100-200-300",
        "exporter_name": "Shanghai Extrusion Machinery Co., Ltd",
        "exporter_reg_id": "EXP-CN-889911",
        "exporter_country": "China",
        "proforma_invoice_no": "PI-2026-8899",
        "pol_name": "Shanghai",
        "pod_name": "Alexandria",
        "requested_date": "2026-06-01",
        "generated_date": "2026-06-04",
        "expiry_date": "2026-11-30",
    }

    res = client.post("/api/v1/import-documentation/acid-sessions", json=payload)
    assert res.status_code in [200, 201]
    data = res.json()
    assert data["acid_number"] == "5281534391023010013"
    acid_id = data["acid_id"]

    # Verify update endpoint
    put_res = client.put(
        f"/api/v1/import-documentation/acid-sessions/{acid_id}",
        json={"status": "Verified", "verification_notes": "API Certified"},
    )
    assert put_res.status_code == 200
    assert put_res.json()["status"] == "Verified"

    app.dependency_overrides.clear()
