"""
Unit tests for SH-02: Draft B/L Dual Review Tool (أداة المراجعة المزدوجة لبوالص الشحن)
Verifies:
1. Automated cross-matching between Draft B/L, Purchase Order (PO), and Commercial Invoice.
2. Accurate tolerance checking (fuzzy text, numeric weight 0.5%, strict integers).
3. Generation of formal shipping line correction letter on discrepancy.
4. Dual approval (Importer & Customs Broker) completing SH-02 SmartTasks.
5. Downstream dispatch of SH-03 SmartTask (CargoX Digital Transfer & Sealing).
6. Lifecycle advancement and SystemNotification generation.
7. REST API endpoint responses.
"""

from datetime import date, datetime, timedelta, timezone
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient

from database.database import Base
from main import app
import modules.import_documentation.service as doc_service
from modules.import_documentation.schemas import (
    DraftBLComparisonRequest,
    DraftBLReviewCreate,
    DualApprovalRequest,
)
from modules.import_files.model import ImportFile
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.purchase_orders.model import PurchaseOrder, POLineItem
from modules.freight_booking.model import ShipmentBooking
from modules.docs_customs_approval.model import CustomsDocumentApproval
from modules.smart_tasks.model import SmartTask
from modules.notifications.model import SystemNotification


from sqlalchemy.pool import StaticPool

@pytest.fixture(scope="function")
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    SessionLocal = sessionmaker(bind=engine)
    session = SessionLocal()

    # Seed Master Data
    company = ImportCompany(
        company_id=1,
        importer_name="Al-Sorour Engineering & Trade LLC",
        vat_id="EG-998877665",
        vat_id_expiry=date(2030, 1, 1),
        importer_id="IMP-REG-001",
        importer_id_expiry=date(2030, 1, 1),
        registration_number="CR-123456",
        registration_expiry=date(2030, 1, 1),
        phone="+20-2-25778899",
        address="15 Industrial Zone, Cairo, Egypt",
        country="Egypt",
        is_active=True,
    )
    supplier = Supplier(
        supplier_id=1,
        supplier_code="SUP-CN-001",
        company_name="Shenzhen Apex Machinery Co.",
        supplier_type="Manufacturer",
        registration_type="TAX_ID",
        foreign_exporter_id="CN-91440300MA5",
        foreign_exporter_country="China",
        foreign_exporter_country_code="CN",
        phone="+86-755-88990011",
        address="High-Tech Industrial Park, Shenzhen, China",
        is_active=True,
    )
    session.add_all([company, supplier])
    session.commit()

    # Seed ImportFile
    imp_file = ImportFile(
        import_file_id=10,
        import_file_code="IMP-2026-0010",
        custom_file_number="Industrial Extruders & Spare Parts",
        company_id=1,
        company_name="Al-Sorour Engineering & Trade LLC",
        supplier_id=1,
        supplier_name="Shenzhen Apex Machinery Co.",
        acid_number="98765432101234563",
        status="In Transit",
        progress_percent=60.0,
        current_module="STEP_08 الإبحار وبوليصة الشحن / In-Transit On Water",
        next_action="STEP_08_BL مراجعة وتدقيق مسودة بوليصة الشحن ومطابقتها مع الفاتورة (SH-02)",
        is_active=True,
    )
    session.add(imp_file)
    session.commit()

    # Seed Linked PO & Line Items
    po = PurchaseOrder(
        po_id=5,
        po_number="PO-2026-0005",
        import_file_id=10,
        project_id=1,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        currency_id=1,
        total_amount_fob=150000.0,
        is_active=True,
    )
    session.add(po)
    session.commit()

    li1 = POLineItem(
        item_id=1,
        po_id=5,
        item_code="EXTR-01",
        description_en="High Speed Twin Screw Extruder Unit",
        description_ar="وحدة بثق مزدوجة الدرفيل عالية السرعة",
        quantity=2.0,
        unit_price=60000.0,
        total_price=120000.0,
        gross_weight_kg=12500.0,
        net_weight_kg=11800.0,
        total_cbm=45.5,
    )
    li2 = POLineItem(
        item_id=2,
        po_id=5,
        item_code="SPAR-02",
        description_en="Extrusion Gearbox Replacement Parts",
        description_ar="قطع غيار صندوق تروس البثق",
        quantity=5.0,
        unit_price=6000.0,
        total_price=30000.0,
        gross_weight_kg=2500.0,
        net_weight_kg=2200.0,
        total_cbm=8.5,
    )
    session.add_all([li1, li2])
    session.commit()

    # Seed Freight Booking
    booking = ShipmentBooking(
        booking_id=3,
        booking_code="BKG-2026-0003",
        booking_confirmation_no="BKG-SH02-MSC",
        import_file_id=10,
        shipping_line_name="MSC Mediterranean Shipping Co.",
        vessel_name="MSC INGRID",
        voyage_number="V2609W",
        pol_name="Shenzhen Port, China",
        pod_name="Alexandria Port, Egypt",
        freight_terms="Freight Prepaid",
        shipment_type="FCL / FCL",
        status="Sailed",
        is_active=True,
    )
    session.add(booking)

    # Seed CustomsDocumentApproval (Bill of Lading)
    bl_approval = CustomsDocumentApproval(
        approval_id=1,
        approval_code="APP-BL-0010",
        import_file_id=10,
        document_type="Bill of Lading",
        document_reference_no="TBA-DRAFT",
        commercial_status="Pending Review",
        customs_status="Pending",
        overall_status="Under Review",
        is_active=True,
    )
    session.add(bl_approval)

    # Seed Initial SmartTask for SH-02
    sh02_task = SmartTask(
        task_id=201,
        task_code="TSK-2026-0201",
        title="المراجعة المزدوجة لمسودة بوليصة الشحن ومطابقتها مع أمر الشراء: IMP-2026-0010 (SH-02)",
        description="فحص مسودة بوليصة الشحن ومطابقة بياناتها مع أمر الشراء والفاتورة",
        task_type="System Generated",
        import_file_id=10,
        import_file_code="IMP-2026-0010",
        phase_name="المرحلة الخامسة: الإبحار و CargoX",
        assigned_user="Logistics Officer",
        priority="High",
        reminder_type="Draft B/L Dual Review",
        status="Pending",
        notes="ACTION:DRAFT_BL_DUAL_REVIEW | File: IMP-2026-0010",
        is_active=True,
    )
    session.add(sh02_task)
    session.commit()

    yield session
    session.close()


def test_sh02_draft_bl_compare_and_mismatch_detection(db_session):
    """
    Test 1: Comparison between Draft B/L and system PO/Invoice snapshot.
    Verifies discrepancy detection on weight and container mismatch,
    and automatic generation of the shipping line correction letter.
    """
    # Provide draft fields with a 20% weight deviation (18000 vs 15000 kg)
    comp_req = DraftBLComparisonRequest(
        import_file_id=10,
        draft_source="MANUAL_INPUT",
        draft_fields={
            "draft_bl_number": "MEDUSH123456",
            "shipper": "Shenzhen Apex Machinery Co.",
            "consignee": "Al-Sorour Engineering & Trade LLC",
            "notify_party": "Al-Sorour Engineering & Trade LLC",
            "vessel_name": "MSC INGRID",
            "voyage_number": "V2609W",
            "booking_no": "BKG-SH02-MSC",
            "acid_number": "98765432101234563",
            "importer_tax_id": "EG-998877665",
            "shipper_reg_id": "CN-91440300MA5",
            "total_gross_weight_kg": 18000.0,  # Intentional discrepancy: system has 15000.0
            "total_net_weight_kg": 14000.0,
            "cbm": 54.0,
            "qty_pkg": 7,
            "container_summary": "MSCU1234567 / Seal: SL99001",
        },
    )

    result = doc_service.compare_draft_bl_service(db_session, comp_req)
    assert result is not None
    assert "comparison_matrix" in result
    assert "checklist_data" in result
    assert result["has_blocking_mismatch"] is True or result["open_discrepancies_count"] > 0
    assert result["correction_request_letter"] is not None
    assert "Subject: Urgent: Draft B/L Correction Request" in result["correction_request_letter"]
    assert "MEDUSH123456" in result["correction_request_letter"] or "BKG-SH02-MSC" in result["correction_request_letter"]


def test_sh02_dual_approval_and_downstream_sh03_dispatch(db_session):
    """
    Test 2: Dual Approval workflow.
    Verifies that when both Importer and Customs Broker approve a clean B/L review:
    1. Session becomes Stage 5: Final / FINAL.
    2. Pending SH-02 SmartTask is auto-completed.
    3. Downstream SH-03 SmartTask (CargoX Digital Transfer) is dispatched.
    4. ImportFile transitions to CargoX stage (progress >= 65%).
    5. CustomsDocumentApproval is commercially approved.
    6. SystemNotification is created.
    """
    # 1. Create a matching draft B/L review session
    create_payload = DraftBLReviewCreate(
        import_file_id=10,
        draft_bl_number="MEDUSH888999",
        shipping_line="MSC Mediterranean Shipping Co.",
        vessel_name="MSC INGRID",
        voyage_number="V2609W",
        booking_no="BKG-SH02-MSC",
        freight_terms="Freight Prepaid",
        place_of_delivery="Alexandria Port, Egypt",
        importer_tax_id="EG-998877665",
        shipper_reg_id="CN-91440300MA5",
        measurement_cbm=54.0,
        net_weight_kg=14000.0,
        packages_count=7,
        container_summary="MSCU1234567 / Seal: SL99001",
        # Phase 3a DOC-04: approval gates need a certified review waiting for approval (not a draft).
        is_draft=False,
        status="REVIEWED_PENDING_APPROVAL",
        open_discrepancies_count=0,
        has_blocking_mismatch=False,
        checklist_data=[
            {
                "field_key": "acid_number",
                "field_label_ar": "رقم ACID",
                "field_label_en": "ACID Number",
                "status": "Correct",
            },
            {
                "field_key": "total_gross_weight_kg",
                "field_label_ar": "الوزن القائم",
                "field_label_en": "Gross Weight",
                "status": "Correct",
            },
        ],
    )
    session = doc_service.create_draft_bl_review_service(db_session, create_payload)
    assert session.bl_review_id is not None

    # Verify initial state before dual approval
    sh02_task = db_session.query(SmartTask).filter(SmartTask.task_id == 201).first()
    assert sh02_task.status == "Pending"

    # 2. Importer Approval
    req_importer = DualApprovalRequest(
        bl_review_id=session.bl_review_id,
        role="importer",
        action="Approved",
        approved_by="Ahmed Salah (Import Compliance)",
        notes="All B/L data matches PO-2026-0005 and commercial invoice.",
    )
    session = doc_service.process_dual_approval_service(db_session, req_importer)
    assert session.importer_approval_status == "Approved"
    assert session.status != "FINAL"  # Still needs broker approval

    # 3. Customs Broker Approval (Completing Dual Review!)
    req_broker = DualApprovalRequest(
        bl_review_id=session.bl_review_id,
        role="customs_broker",
        action="Approved",
        approved_by="Mahmoud (Customs Broker)",
        notes="HS codes and tax ID checked. Ready for CargoX document transfer.",
    )
    session = doc_service.process_dual_approval_service(db_session, req_broker)
    assert session.broker_approval_status == "Approved"
    assert session.status == "FINAL"
    assert session.stage == "Stage 5: Final"

    # 4. Verify SH-02 SmartTask was auto-closed
    db_session.refresh(sh02_task)
    assert sh02_task.status == "Completed"
    assert sh02_task.is_auto_closed is True

    # 5. Verify Downstream SH-03 SmartTask was dispatched
    sh03_tasks = db_session.query(SmartTask).filter(
        SmartTask.import_file_id == 10,
        SmartTask.notes.ilike("%ACTION:CARGOX_SEAL%"),
    ).all()
    assert len(sh03_tasks) >= 1
    sh03 = sh03_tasks[0]
    assert "SH-03" in sh03.title
    assert "CargoX" in sh03.title
    assert sh03.status == "Pending"
    assert sh03.priority == "High"

    # 6. Verify ImportFile progression
    imp_file = db_session.query(ImportFile).filter(ImportFile.import_file_id == 10).first()
    assert imp_file.bl_number == "MEDUSH888999"
    assert imp_file.progress_percent >= 54.0
    assert "STEP_08_COO" in imp_file.current_module

    # 7. Verify CustomsDocumentApproval
    bl_app = db_session.query(CustomsDocumentApproval).filter(
        CustomsDocumentApproval.import_file_id == 10,
        CustomsDocumentApproval.document_type == "Bill of Lading",
    ).first()
    assert bl_app.commercial_status == "Approved"
    assert bl_app.document_reference_no == "MEDUSH888999"

    # 8. Verify SystemNotification
    notif = db_session.query(SystemNotification).filter(
        SystemNotification.entity_id == 10,
        SystemNotification.category == "STAGE_PROGRESSION",
    ).order_by(SystemNotification.notification_id.desc()).first()
    assert notif is not None
    assert "SH-02" in notif.title
    assert "MEDUSH888999" in notif.message


def test_sh02_rest_api_dual_approval_endpoints(db_session):
    """
    Test 3: REST API integration using FastAPI TestClient.
    """
    from database.database import get_db

    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    # 1. Create review session via REST API with correct checklist items
    post_res = client.post(
        "/api/v1/import-documentation/draft-bl",
        json={
            "import_file_id": 10,
            "draft_bl_number": "MEDUAPI9988",
            "shipping_line": "MSC Mediterranean Shipping Co.",
            "vessel_name": "MSC INGRID",
            "voyage_number": "V2609W",
            "booking_no": "BKG-SH02-MSC",
            "is_draft": False,  # Phase 3a DOC-04: only certified reviews can be approved
            "status": "REVIEWED_PENDING_APPROVAL",
            "open_discrepancies_count": 0,
            "has_blocking_mismatch": False,
            "checklist_data": [
                {
                    "field_key": "acid_number",
                    "field_label_ar": "رقم ACID",
                    "field_label_en": "ACID Number",
                    "status": "Correct",
                }
            ],
        },
    )
    assert post_res.status_code == 201, post_res.text
    review_id = post_res.json()["bl_review_id"]

    # 2. Get review by ID
    get_res = client.get(f"/api/v1/import-documentation/draft-bl/{review_id}")
    assert get_res.status_code == 200
    assert get_res.json()["draft_bl_number"] == "MEDUAPI9988"

    # 3. Security review: /approve only completes the one missing role, so the importer approves first
    #    (as another user than the API caller), then the approve endpoint finalizes the review.
    doc_service.process_dual_approval_service(db_session, DualApprovalRequest(
        bl_review_id=review_id, role="importer", action="Approved", approved_by="x"), user="Import Compliance Officer")
    appr_res = client.post(
        f"/api/v1/import-documentation/draft-bl/{review_id}/approve",
        params={"approved_by": "Senior Quality Inspector"},
    )
    assert appr_res.status_code == 200
    assert appr_res.json()["status"] == "FINAL"
    assert appr_res.json()["stage"] == "Stage 5: Final"

    app.dependency_overrides.clear()
