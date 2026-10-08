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
    DossierExportConfirmRequest,
)
from modules.file_closure.service import (
    get_closure_precheck_service,
    official_close_import_file_service,
    close_import_file_service,
    confirm_dossier_export_service,
)
from modules.file_closure.model import ImportFileClosureRecord
from modules.file_closure.repository import active_purchase_orders
from modules.purchase_orders.model import PurchaseOrder, POLineItem
from modules.customs_tariff.model import CustomsTariff
from modules.inland_transport.schemas import InlandTransportBookingCreate
from modules.inland_transport.service import create_transport_booking_service
from modules.external_service_providers.model import ExternalServiceProvider
from modules.transport_locations.model import TransportLocation
from fastapi import HTTPException

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
    assert res["auditor_name"] == "test-admin"  # BE810-T10: acting user from token
    assert res["archive_location"] == "Central Secure Cloud Vault - Volume A/2026"
    assert res["next_action"] == "File archived - read-only historical state"

    # Verify ImportFile in DB
    db_session.refresh(imp)
    assert imp.status == "Closed"
    assert imp.progress_percent == 100.0
    # FC-05: the phase before closure is kept for a reopen; the closure timestamp lives on the record
    assert imp.closed_at_phase == "Phase 10 - Comprehensive Dossier Export & Digital Archiving"
    assert res["closed_at"]
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
    """FC-01: the server gate blocks (dossier not exported) even when the client checklist says everything is done."""
    imp = _seed_sample_ready_shipment(db_session, "IMP-2026-CLO04-FAIL-CHECKLIST")
    imp.dossier_exported_at = None
    db_session.commit()

    payload = {
        "import_file_id": imp.import_file_id,
        "auditor_name": "Auditor Name",
        "archive_location": "Vault",
        "closure_checklist": {
            "docs_verified": True,
            "customs_cleared": True,  # client flags never gate
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
    detail = response.json()["detail"]
    assert detail["code"] == "FC_CLOSURE_BLOCKED"
    assert detail["blocking"] == ["dossier_exported"]


def test_closure_precheck_not_found(client):
    """Verify 404 is returned when checking non-existent import file."""
    response = client.get("/api/v1/file-closure/closure-precheck/999999")
    assert response.status_code == 404


def test_auditor_name_from_token_not_payload(db_session, client):
    """BE810-T10: auditor_name in request body is ignored; value is taken from current_user."""
    imp = _seed_sample_ready_shipment(db_session, "IMP-2026-CLO04-AUDITOR-TOKEN")
    payload = {
        "import_file_id": imp.import_file_id,
        "auditor_name": "Spoofed Auditor Name",
        "archive_location": "Central Secure Cloud Vault - Volume A/2026",
        "archival_notes": "All verified.",


def test_closure_task_tight_match_unrelated_tasks_stay_open(db_session, client):
    """BE810-F27: Tasks with generic closing titles (e.g. LC closure) stay open; only CLO-04 is closed."""
    imp = _seed_sample_ready_shipment(db_session, "IMP-2026-CLO04-TIGHT-MATCH")

    task_lc = SmartTask(
        task_code=f"TSK-LC-{imp.import_file_id}",
        title="إغلاق الاعتماد المستندي",
        task_type="Financial",
        import_file_id=imp.import_file_id,
        status="Pending",
        is_active=True,
    )
    task_transport = SmartTask(
        task_code=f"TSK-TR-{imp.import_file_id}",
        title="متابعة نقل الشحنة",
        task_type="Logistics",
        import_file_id=imp.import_file_id,
        status="Pending",
        is_active=True,
    )
    db_session.add_all([task_lc, task_transport])
    db_session.commit()

    payload = {
        "import_file_id": imp.import_file_id,
        "auditor_name": "Auditor",
        "archive_location": "Vault",
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
    assert res["auditor_name"] == "test-admin"
    assert res["auditor_name"] != "Spoofed Auditor Name"



    db_session.refresh(task_lc)
    db_session.refresh(task_transport)
    assert task_lc.status == "Pending", "LC closure task must stay open (not matched by broad title)"
    assert task_transport.status == "Pending", "Transport task must stay open"

    # CLO-04 task is auto-closed
    task_904 = db_session.query(SmartTask).filter(
        SmartTask.import_file_id == imp.import_file_id,
        SmartTask.task_code.ilike("%0904%"),
    ).first()
    assert task_904.status == "Completed"


def test_draft_closure_has_closed_at_none(db_session, client):
    """BE810-F30: Draft closure record has closed_at is None."""
    imp = _seed_sample_ready_shipment(db_session, "IMP-2026-CLO04-DRAFT-NULL")
    payload = {
        "import_file_id": imp.import_file_id,
        "auditor_name": "Auditor",
        "archive_location": "Vault",
        "closure_checklist": {
            "docs_verified": True,
        },
        "is_draft": True,
    }
    response = client.post("/api/v1/file-closure", json=payload)
    assert response.status_code == 201
    res = response.json()
    assert res["status"] == "Draft"
    assert res["closed_at"] is None

    rec = db_session.query(ImportFileClosureRecord).filter(
        ImportFileClosureRecord.closure_id == res["closure_id"]
    ).first()
    assert rec.closed_at is None


def test_precheck_closed_file_adds_already_closed_blocking_reason(db_session, client):
    """BE810-F32: Precheck on a closed file returns can_close=False with already_closed blocking key and reason."""
    imp = _seed_sample_ready_shipment(db_session, "IMP-2026-CLO04-ALREADY-CLOSED")
    imp.status = "Closed"
    db_session.commit()

    response = client.get(f"/api/v1/file-closure/closure-precheck/{imp.import_file_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["can_close"] is False
    assert "already_closed" in data["blocking_keys"]
    assert any("مغلق" in r for r in data["blocking_reasons"])


def test_dossier_export_reconfirmation_avoids_duplicate_notification(db_session):
    """BE810-F35: Dossier export re-confirmation avoids duplicate notification and preserves closed task notes."""
    imp = _seed_sample_ready_shipment(db_session, "IMP-2026-CLO04-RE-EXPORT")
    imp.dossier_exported_at = None
    db_session.commit()

    task_903 = SmartTask(
        task_code=f"TSK-0903-{imp.import_file_id}",
        title="تصدير الملف الشامل (CLO-03)",
        import_file_id=imp.import_file_id,
        status="Pending",
        is_active=True,
    )
    db_session.add(task_903)
    db_session.commit()

    req = DossierExportConfirmRequest(import_file_id=imp.import_file_id, export_format="PDF")
    res1 = confirm_dossier_export_service(db_session, req, trusted=True)
    assert res1.success is True

    notif_count_1 = db_session.query(SystemNotification).filter(
        SystemNotification.entity_id == imp.import_file_id,
        SystemNotification.msg_code == "CLO_DOSSIER_EXPORTED",
    ).count()
    assert notif_count_1 == 1

    db_session.refresh(task_903)
    assert task_903.status == "Completed"
    task_903.notes = "Preserved original export note"
    db_session.commit()

    # Re-confirm export
    res2 = confirm_dossier_export_service(db_session, req, trusted=True)
    assert res2.success is True

    notif_count_2 = db_session.query(SystemNotification).filter(
        SystemNotification.entity_id == imp.import_file_id,
        SystemNotification.msg_code == "CLO_DOSSIER_EXPORTED",
    ).count()
    assert notif_count_2 == 1, "Duplicate notification should not be sent"

    db_session.refresh(task_903)
    assert task_903.notes == "Preserved original export note", "Completed task notes must not be overwritten"


def test_inland_transport_task_assigned_to_user_and_phase_8(db_session):
    """BE810-F28 & F27: TR-03 task assigned to acting user, phase 8, and tight TR-01 matching."""
    imp = _seed_sample_ready_shipment(db_session, "IMP-2026-IT-HYGIENE")
    imp.status = "Under Processing"
    db_session.commit()

    carrier = ExternalServiceProvider(
        partner_code="PRV-IT-001",
        partner_name="Nile Express Logistics",
        partner_type="Inland Transport",
        is_active=True,
    )
    db_session.add(carrier)
    db_session.flush()

    now_utc = datetime.now(timezone.utc)
    schema = InlandTransportBookingCreate(
        import_file_id=imp.import_file_id,
        waybill_number="WB-TEST-2026-001",
        carrier_name="Nile Express Logistics",
        carrier_id=carrier.provider_id,
        driver_name="Mahmoud Driver",
        driver_phone="+201012345678",
        truck_plate_number="ط ر ق 1234",
        truck_type="FLATBED",
        pickup_port_location="Alexandria Port",
        destination_warehouse="El-Obour Warehouse",
        planned_departure_at=now_utc,
        expected_arrival_at=now_utc,
        transport_fare_egp=8500.0,
    )
    booking = create_transport_booking_service(db_session, schema, user="logistics-specialist")
    assert booking.transport_id is not None

    downstream_task = db_session.query(SmartTask).filter(
        SmartTask.import_file_id == imp.import_file_id,
        SmartTask.reminder_type == "Warehouse Receiving",
    ).first()
    assert downstream_task is not None
    assert downstream_task.assigned_user == "logistics-specialist"
    assert downstream_task.phase_name == "Phase 8: Inland Transport & Warehouse Receiving"


def test_require_any_permission_untrusted_without_actor_raises_403(db_session):
    """BE810-F31: _require_any_permission raises 403 when actor is None and trusted=False."""
    imp = _seed_sample_ready_shipment(db_session, "IMP-2026-AUTH-GUARD")
    schema = FileClosureCreate(import_file_id=imp.import_file_id, is_draft=True)

    with pytest.raises(HTTPException) as exc:
        close_import_file_service(db_session, schema, actor=None, trusted=False)
    assert exc.value.status_code == 403


def test_active_purchase_orders_eager_loads_relationships(db_session):
    """BE810-F33: active_purchase_orders eager-loads currency, line_items, and tariff to prevent N+1."""
    imp = _seed_sample_ready_shipment(db_session, "IMP-2026-PO-EAGER")

    tariff = CustomsTariff(
        hs_code="8418.10.00",
        hs_description="ثلاجات",
        customs_duty_rate=5.0,
        vat_rate=14.0,
        is_active=True,
    )
    db_session.add(tariff)
    db_session.flush()

    project = Project(
        project_code="PRJ-2026-001",
        project_name="Test Project",
        project_owner="Owner",
        company_id=imp.company_id,
        supplier_id=imp.supplier_id,
        incoterm_id=1,
        is_active=True,
    )
    db_session.add(project)
    db_session.flush()

    po = PurchaseOrder(
        po_number="PO-2026-EAGER-01",
        import_file_id=imp.import_file_id,
        project_id=project.project_id,
        company_id=imp.company_id,
        supplier_id=imp.supplier_id,
        incoterm_id=1,
        currency_id=1,
        total_amount_fob=50000.0,
        is_active=True,
    )
    db_session.add(po)
    db_session.flush()

    item = POLineItem(
        po_id=po.po_id,
        item_code="ITEM-001",
        description_ar="صنف ثلاجات",
        tariff_id=tariff.tariff_id,
        quantity=10,
        unit_price=5000.0,
        total_price=50000.0,
    )
    db_session.add(item)
    db_session.commit()

    pos = active_purchase_orders(db_session, imp.import_file_id)
    assert len(pos) == 1
    loaded_po = pos[0]
    assert loaded_po.currency is not None
    assert len(loaded_po.line_items) == 1
    assert loaded_po.line_items[0].tariff is not None
    assert loaded_po.line_items[0].tariff.hs_code == "8418.10.00"

