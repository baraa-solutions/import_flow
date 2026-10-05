import pytest
from datetime import date, datetime, timezone
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

import main
from database.database import Base, get_db
from modules.import_files.model import ImportFile
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.warehouse_receiving.model import WarehouseReceivingRecord
from modules.financial_settlement.model import LandedCostSettlementRecord
from modules.currencies.model import Currency, ExchangeRate
from modules.suppliers.model import Supplier
from modules.projects.model import Project
from modules.incoterms.model import Incoterm
from modules.smart_tasks.model import SmartTask
from modules.notifications.model import SystemNotification
from modules.file_closure.schemas import (
    FileClosureCreate,
    ClosureChecklistSchema,
    ClosurePrecheckResponse,
    OfficialClosureCertificateResponse,
)
from modules.file_closure.service import (
    get_closure_precheck_service,
    official_close_import_file_service,
)

SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="function")
def db_session():
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    main.app.dependency_overrides[get_db] = override_get_db
    with TestClient(main.app) as c:
        yield c
    main.app.dependency_overrides.clear()


def _seed_sample_ready_shipment(db_session, file_code="IMP-2026-CLO04-01"):
    """Helper to seed a shipment ready for official closure."""
    usd = db_session.query(Currency).filter(Currency.currency_code == "USD").first()
    if not usd:
        usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
        db_session.add(usd)
        db_session.flush()

    rate = db_session.query(ExchangeRate).filter(ExchangeRate.currency_id == usd.currency_id).first()
    if not rate:
        rate = ExchangeRate(
            currency_id=usd.currency_id,
            customs_rate=50.0,
            commercial_rate=50.0,
            effective_date=date.today(),
            is_active=True,
        )
        db_session.add(rate)
        db_session.flush()

    supplier = db_session.query(Supplier).filter(Supplier.supplier_code == "SUP-DE-CLO04").first()
    if not supplier:
        supplier = Supplier(
            supplier_code="SUP-DE-CLO04",
            company_name="Bavaria Precision Tools GmbH",
            supplier_type="Manufacturer",
            registration_type="CargoX",
            foreign_exporter_id="EXP-DE-8899",
            foreign_exporter_country="Germany",
            foreign_exporter_country_code="DE",
            address="Munich, Germany",
            is_active=True,
        )
        db_session.add(supplier)
        db_session.flush()

    incoterm = db_session.query(Incoterm).filter(Incoterm.incoterm_code == "FOB").first()
    if not incoterm:
        incoterm = Incoterm(incoterm_code="FOB", incoterm_name="Free On Board", is_active=True)
        db_session.add(incoterm)
        db_session.flush()

    now_utc = datetime.now(timezone.utc)

    imp = ImportFile(
        import_file_code=file_code,
        company_id=1,
        company_name="Sorour Logistics Co.",
        supplier_id=supplier.supplier_id,
        supplier_name=supplier.company_name,
        status="Under Settlement",
        current_stage="Stage 10: Import File Closure & Archival",
        current_module="Phase 10 - Comprehensive Dossier Export & Digital Archiving",
        progress_percent=99.5,
        next_action="الإغلاق الرسمي والأرشفة الرقمية للملف (CLO-04)",
        shipment_mode="Sea FCL",
        incoterm_code="FOB",
        priority="High",
        acid_number="9876543210123456789",
        form46_no="DEC-46-2026-00445",
        customs_release_permit_no="REL-PERMIT-2026-9912",
        customs_released_at=now_utc,
        inland_actual_arrival_date=now_utc,
        empty_containers_returned_at=now_utc,
        empty_containers_eir_numbers="EIR-MSC-88912",
        financial_settlement_status="SETTLED",
        actual_landed_cost_total_egp=895400.0,
        actual_landed_cost_markup_factor=1.435,
        actual_landed_cost_calculated_at=now_utc,
        dossier_exported_at=now_utc,
        dossier_exported_by="Finance & Logistics Controller",
        is_active=True,
    )
    db_session.add(imp)
    db_session.flush()

    # Customs clearance record
    clearance = CustomsClearanceRecord(
        clearance_code=f"CLR-CUS-{imp.import_file_id:04d}",
        import_file_id=imp.import_file_id,
        declaration_46_no="46/2026/00445",
        status="Final Release Granted",
        is_active=True,
    )
    db_session.add(clearance)

    # Warehouse record
    grn = WarehouseReceivingRecord(
        grn_code=f"GRN-2026-{imp.import_file_id:04d}",
        import_file_id=imp.import_file_id,
        warehouse_name="Main Warehouse - Cairo",
        total_accepted_qty=1200,
        is_active=True,
    )
    db_session.add(grn)

    # Landed Cost Settlement record
    settlement = LandedCostSettlementRecord(
        import_file_id=imp.import_file_id,
        settlement_code=f"SETTLE-2026-{imp.import_file_id:04d}",
        status="Approved",
        total_landed_cost_egp=895400.0,
        average_markup_factor=1.435,
        is_active=True,
    )
    db_session.add(settlement)

    # Task TSK-0904
    task_904 = SmartTask(
        task_code=f"TSK-0904-{imp.import_file_id}",
        title="الإغلاق الرسمي والأرشفة الرقمية للملف (CLO-04)",
        description="استكمال قائمة التحقق النهائية وإصدار شهادة الإغلاق والأرشفة الرقمية.",
        task_type="System Generated",
        import_file_id=imp.import_file_id,
        import_file_code=imp.import_file_code,
        phase_name="Stage 10: Import File Closure & Archival",
        assigned_user="Finance Auditor",
        priority="High",
        status="Pending",
        is_active=True,
    )
    db_session.add(task_904)

    db_session.commit()
    db_session.refresh(imp)
    return imp


def test_closure_precheck_all_passed(db_session, client):
    """Verify precheck returns can_close=True with no blocking reasons for a completed shipment."""
    imp = _seed_sample_ready_shipment(db_session, "IMP-2026-CLO04-PASS")

    response = client.get(f"/api/v1/file-closure/closure-precheck/{imp.import_file_id}")
    assert response.status_code == 200
    data = response.json()

    assert data["import_file_id"] == imp.import_file_id
    assert data["can_close"] is True
    assert len(data["blocking_reasons"]) == 0
    assert data["checklist_status"]["customs_cleared"] is True
    assert data["checklist_status"]["warehouse_received"] is True
    assert data["checklist_status"]["landed_cost_settled"] is True
    assert data["checklist_status"]["dossier_exported"] is True
    assert data["checklist_status"]["empty_containers_returned"] is True
    assert data["actual_landed_cost_egp"] == 895400.0
    assert data["certificate_code_preview"].startswith("CLR-")


def test_closure_precheck_blocking_when_prerequisites_missing(db_session, client):
    """Verify precheck catches missing customs release, warehouse GRN, landed cost, and dossier export."""
    imp = ImportFile(
        import_file_code="IMP-2026-CLO04-BLOCKED",
        company_id=1,
        company_name="Sorour Logistics Co.",
        supplier_id=1,
        supplier_name="Bavaria Precision Tools GmbH",
        status="Under Processing",
        current_stage="Stage 3: Shipping & Tracking",
        progress_percent=30.0,
        shipment_mode="Sea FCL",
        is_active=True,
    )
    db_session.add(imp)
    db_session.commit()
    db_session.refresh(imp)

    response = client.get(f"/api/v1/file-closure/closure-precheck/{imp.import_file_id}")
    assert response.status_code == 200
    data = response.json()

    assert data["can_close"] is False
    assert len(data["blocking_reasons"]) >= 4
    # All major pillars should be flagged as not ok
    assert data["checklist_status"]["customs_cleared"] is False
    assert data["checklist_status"]["warehouse_received"] is False
    assert data["checklist_status"]["landed_cost_settled"] is False
    assert data["checklist_status"]["dossier_exported"] is False


def test_official_close_success(db_session, client):
    """Verify official closure marks ImportFile as Closed (100%), resolves TSK-0904, and issues certificate."""
    imp = _seed_sample_ready_shipment(db_session, "IMP-2026-CLO04-CLOSE-OK")

    payload = {
        "import_file_id": imp.import_file_id,
        "auditor_name": "Dr. Ahmed Sorour (Auditor)",
        "archive_location": "Central Secure Cloud Vault - Volume A/2026",
        "archival_notes": "All documents verified, customs released, warehouse GRN matched, cost settled.",
        "closure_checklist": {
            "docs_verified": True,
            "customs_cleared": True,
            "warehouse_received": True,
            "landed_cost_settled": True,
            "dossier_exported": True,
            "empty_containers_returned": True,
            "tasks_closed": True,
        },
        "is_draft": False,
    }

    response = client.post("/api/v1/file-closure/official-close", json=payload)
    assert response.status_code == 201
    res = response.json()

    assert res["success"] is True
    assert res["status"] == "Closed"
    assert res["progress_percent"] == 100.0
    assert res["closure_code"].startswith("CLR-")
    assert res["auditor_name"] == "Dr. Ahmed Sorour (Auditor)"
    assert res["archive_location"] == "Central Secure Cloud Vault - Volume A/2026"
    assert res["next_action"] == "File archived - read-only historical state"

    # Verify ImportFile in DB
    db_session.refresh(imp)
    assert imp.status == "Closed"
    assert imp.progress_percent == 100.0
    assert imp.closed_at is not None
    assert "Closed" in imp.current_stage or "Archived" in imp.current_stage

    # Verify SmartTask auto-closed
    task = db_session.query(SmartTask).filter(
        SmartTask.import_file_id == imp.import_file_id,
        SmartTask.task_code.ilike("%0904%"),
    ).first()
    assert task is not None
    assert task.status == "Completed"

    # Verify notification dispatched
    notif = db_session.query(SystemNotification).filter(
        SystemNotification.entity_id == imp.import_file_id,
        SystemNotification.category == "FILE_CLOSURE",
    ).first()
    assert notif is not None
    assert "Officially closed" in notif.title
    assert notif.msg_code == "CLO_FILE_CLOSED"


def test_official_close_blocks_unmet_checklist(db_session, client):
    """Verify official close blocks when checklist items are false and not skipped."""
    imp = _seed_sample_ready_shipment(db_session, "IMP-2026-CLO04-FAIL-CHECKLIST")

    payload = {
        "import_file_id": imp.import_file_id,
        "auditor_name": "Auditor Name",
        "archive_location": "Vault",
        "closure_checklist": {
            "docs_verified": True,
            "customs_cleared": False,  # Missing!
            "warehouse_received": True,
            "landed_cost_settled": True,
            "dossier_exported": True,
            "empty_containers_returned": True,
            "tasks_closed": True,
        },
        "is_draft": False,
    }

    response = client.post("/api/v1/file-closure/official-close", json=payload)
    assert response.status_code == 400
    assert "قائمة التحقق" in response.json()["detail"]


def test_closure_precheck_not_found(client):
    """Verify 404 is returned when checking non-existent import file."""
    response = client.get("/api/v1/file-closure/closure-precheck/999999")
    assert response.status_code == 404
