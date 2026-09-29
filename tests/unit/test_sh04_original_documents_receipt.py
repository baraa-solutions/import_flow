"""
Unit Tests for SH-04: Original Bank Documents Receipt (استلام وتوثيق أصول المستندات البنكية)
Checklist Item #29 - Stage 5: Sailing & CargoX
"""

import pytest
from datetime import datetime, timezone, date
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base, get_db
from main import app
from modules.import_files.model import ImportFile
from modules.original_documents_collection.model import OriginalDocumentsCollectionSession
from modules.original_documents_collection.schemas import (
    OriginalDocumentsCollectionCreate,
    CourierEntry,
    OriginalDocumentItem,
    CourierReceiptProofRequest,
)
from modules.original_documents_collection.service import OriginalDocumentsCollectionService
from modules.smart_tasks.model import SmartTask
from modules.notifications.model import SystemNotification
from modules.docs_customs_approval.model import CustomsDocumentApproval
from modules.lifecycle_board.model import ShipmentStageActivity


@pytest.fixture
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    test_client = TestClient(app)
    yield test_client
    app.dependency_overrides.clear()


@pytest.fixture
def sample_import_file(db_session):
    imp_file = ImportFile(
        import_file_code="IMP-2026-0040",
        custom_file_number="Textiles & Cotton",
        company_id=1,
        company_name="Al-Sorour Textiles Co",
        supplier_id=2,
        supplier_name="Bursa Cotton Corp",
        acid_number="7595528271020210020",
        bl_number="MEDUST445566",
        booking_no="BKG-MSC-4455",
        vessel_name="MSC TINA",
        cargox_envelope_id=40,
        cargox_envelope_code="CGX-ENV-2026-0040",
        cargox_envelope_status="ACCEPTED_BY_CUSTOMS",
        current_module="STEP_11 تحصيل واستلام أصول المستندات",
        current_stage="Phase 5 - Sailing & CargoX",
        progress_percent=70.0,
        next_action="استلام وتوثيق أصول المستندات البنكية (SH-04)",
        status="Open",
        owner="Kamal",
    )
    db_session.add(imp_file)
    db_session.commit()
    db_session.refresh(imp_file)

    # Lifecycle step: STEP_11
    lc_step = ShipmentStageActivity(
        import_file_code=imp_file.import_file_code,
        step_code="STEP_11",
        status="In-Progress",
    )
    db_session.add(lc_step)

    # Pending SH-04 SmartTask
    task = SmartTask(
        task_code="TASK-SH04-TEST",
        import_file_id=imp_file.import_file_id,
        import_file_code=imp_file.import_file_code,
        title="استلام وتوثيق أصول المستندات البنكية للشحنة (SH-04)",
        description="استلام أصول المستندات البنكية لمطابقتها وتجهيز ملف التخليص الجمركي",
        task_type="ORIGINAL_DOCS_RECEIPT",
        priority="High",
        status="Pending",
        assigned_user="Logistics Specialist",
        due_date=date.today().isoformat(),
        created_by="SYSTEM",
    )
    db_session.add(task)
    db_session.commit()
    return imp_file


class TestSH04OriginalDocumentsReceipt:

    def test_auto_populate_and_create_session(self, db_session, sample_import_file):
        auto_data = OriginalDocumentsCollectionService.auto_populate_from_central_archive(
            db_session, sample_import_file.import_file_id
        )
        assert auto_data.import_file_code == sample_import_file.import_file_code
        assert len(auto_data.required_documents) >= 5

        create_payload = OriginalDocumentsCollectionCreate(
            import_file_id=sample_import_file.import_file_id,
            import_file_code=sample_import_file.import_file_code,
            acid_number="7595528271020210020",
            importer_name="Al-Sorour Textiles Co",
            supplier_name="Bursa Cotton Corp",
            status="IN_TRANSIT",
            couriers_list=[
                CourierEntry(
                    courier_no="DHL-9988112233",
                    courier_company="DHL",
                    dispatch_date="2026-09-15",
                    is_received=False,
                )
            ],
            documents_list=[
                OriginalDocumentItem(
                    category="Commercial",
                    document_name="Commercial Invoice",
                    is_required="Yes",
                    responsible_party="Supplier",
                    courier_no="DHL-9988112233",
                    is_received=False,
                ),
                OriginalDocumentItem(
                    category="Commercial",
                    document_name="Packing List",
                    is_required="Yes",
                    responsible_party="Supplier",
                    courier_no="DHL-9988112233",
                    is_received=False,
                ),
                OriginalDocumentItem(
                    category="Shipping",
                    document_name="Final House Bill of Lading",
                    is_required="Yes",
                    responsible_party="Freight Forwarder",
                    courier_no="DHL-9988112233",
                    is_received=False,
                ),
            ],
            notes="Courier in transit from Bursa",
        )

        session = OriginalDocumentsCollectionService.save_or_update_session(
            db_session, create_payload, username="Kamal"
        )
        assert session.collection_id is not None
        assert session.collection_code.startswith("DOC-COL-")
        assert session.status == "IN_TRANSIT"

        # Verify ImportFile synchronization
        db_session.refresh(sample_import_file)
        assert sample_import_file.original_documents_status == "IN_TRANSIT"
        assert sample_import_file.original_documents_session_code == session.collection_code
        assert "DHL-9988112233" in (sample_import_file.original_documents_courier_no or "")

    def test_full_original_documents_receipt_orchestration(self, db_session, sample_import_file):
        create_payload = OriginalDocumentsCollectionCreate(
            import_file_id=sample_import_file.import_file_id,
            import_file_code=sample_import_file.import_file_code,
            acid_number="7595528271020210020",
            importer_name="Al-Sorour Textiles Co",
            supplier_name="Bursa Cotton Corp",
            status="FULLY_RECEIVED",
            couriers_list=[
                CourierEntry(
                    courier_no="DHL-7711223344",
                    courier_company="DHL",
                    dispatch_date="2026-09-16",
                    is_received=True,
                    received_date="2026-09-18",
                    received_by="Kamal",
                    status="DELIVERED",
                )
            ],
            documents_list=[
                OriginalDocumentItem(
                    category="Commercial",
                    document_name="Commercial Invoice",
                    is_required="Yes",
                    is_received=True,
                    received_date="2026-09-18",
                    status="Received",
                ),
                OriginalDocumentItem(
                    category="Commercial",
                    document_name="Packing List",
                    is_required="Yes",
                    is_received=True,
                    received_date="2026-09-18",
                    status="Received",
                ),
                OriginalDocumentItem(
                    category="Shipping",
                    document_name="Final House Bill of Lading",
                    is_required="Yes",
                    is_received=True,
                    received_date="2026-09-18",
                    status="Received",
                ),
            ],
            notes="All hard-copy originals collected and stamped",
        )

        session = OriginalDocumentsCollectionService.save_or_update_session(
            db_session, create_payload, username="Kamal"
        )

        # 1. Verify ImportFile Synchronization
        db_session.refresh(sample_import_file)
        assert sample_import_file.original_documents_status == "FULLY_RECEIVED"
        assert sample_import_file.original_documents_session_code == session.collection_code
        assert sample_import_file.original_documents_received_at is not None
        assert sample_import_file.progress_percent >= 75.0
        assert "STEP_12" in sample_import_file.current_module

        # 2. Verify Prior SH-04 SmartTask Auto-Completed
        old_task = (
            db_session.query(SmartTask)
            .filter(
                SmartTask.import_file_id == sample_import_file.import_file_id,
                SmartTask.task_type == "ORIGINAL_DOCS_RECEIPT",
            )
            .first()
        )
        assert old_task.status == "Completed"

        # 3. Verify Downstream CS-01 SmartTask Dispatched
        downstream_task = (
            db_session.query(SmartTask)
            .filter(
                SmartTask.import_file_id == sample_import_file.import_file_id,
                SmartTask.task_type == "CUSTOMS_BROKER_ASSIGNMENT",
            )
            .first()
        )
        assert downstream_task is not None
        assert "CS-01" in downstream_task.title
        assert downstream_task.status == "Pending"
        assert downstream_task.priority == "High"

        # 4. Verify SystemNotification Dispatched
        notif = (
            db_session.query(SystemNotification)
            .filter(
                SystemNotification.entity_type == "ImportFile",
                SystemNotification.entity_id == sample_import_file.import_file_id,
            )
            .first()
        )
        assert notif is not None
        assert notif.category == "STAGE_PROGRESSION"
        assert "Original bank documents" in notif.title
        assert notif.msg_code == "ODC_ORIGINALS_RECEIVED"

        # 5. Verify CustomsDocumentApproval Created
        approval = (
            db_session.query(CustomsDocumentApproval)
            .filter(
                CustomsDocumentApproval.import_file_id == sample_import_file.import_file_id,
                CustomsDocumentApproval.document_type == "ORIGINAL_DOCUMENTS",
            )
            .first()
        )
        assert approval is not None
        assert approval.overall_status == "Approved for Clearance"
        assert approval.commercial_status == "Approved"
        assert approval.customs_status == "Approved"

    def test_courier_receipt_proof_endpoint(self, client, db_session, sample_import_file):
        # Create initial session
        create_payload = OriginalDocumentsCollectionCreate(
            import_file_id=sample_import_file.import_file_id,
            import_file_code=sample_import_file.import_file_code,
            status="IN_TRANSIT",
            couriers_list=[
                CourierEntry(
                    courier_no="FEDEX-55443322",
                    courier_company="FedEx",
                    dispatch_date="2026-09-16",
                    is_received=False,
                )
            ],
            documents_list=[
                OriginalDocumentItem(
                    category="Commercial",
                    document_name="Commercial Invoice",
                    is_required="Yes",
                    courier_no="FEDEX-55443322",
                    is_received=False,
                ),
            ],
        )
        OriginalDocumentsCollectionService.save_or_update_session(db_session, create_payload)

        # Confirm receipt via REST API
        proof_req = {
            "import_file_id": sample_import_file.import_file_id,
            "courier_no": "FEDEX-55443322",
            "received_date": "2026-09-18",
            "received_time": "14:30",
            "received_by": "Kamal Sorour",
            "pod_reference": "POD-FDX-9988",
            "mark_documents_received": True,
            "notes": "Delivered to head office desk",
        }

        res = client.post(
            "/api/v1/original-documents-collection/couriers/confirm-receipt",
            json=proof_req,
        )
        assert res.status_code == 200
        data = res.json()
        assert data["status"] in ("FULLY_RECEIVED", "FULLY_VERIFIED")
        assert data["received_documents_count"] >= 1

        db_session.refresh(sample_import_file)
        assert sample_import_file.original_documents_status in ("FULLY_RECEIVED", "FULLY_VERIFIED")
        assert sample_import_file.original_documents_received_at is not None
