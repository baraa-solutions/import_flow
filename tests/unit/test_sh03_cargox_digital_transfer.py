"""
Unit Tests for SH-03: CargoX Digital Transfer & Sealing (منصة النقل الرقمي CargoX واعتماد الملفات)
Checklist Item #28 - Stage 5: Sailing & CargoX
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
from modules.cargox.model import CargoXEnvelope, CargoXEnvelopeDocument
from modules.cargox.schemas import (
    CargoXEnvelopeCreate,
    CargoXDocumentCreate,
    CargoXSealAndTransferRequest,
)
from modules.cargox.service import CargoXService
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
        import_file_code="IMP-2026-0030",
        custom_file_number="Silk & Fabrics Cargo",
        company_id=1,
        company_name="Al-Sorour Import Co",
        supplier_id=2,
        supplier_name="Suzhou Silk Industrial Ltd",
        acid_number="7595528271020210010",
        bl_number="MEDUST991122",
        booking_no="BKG-MSC-9911",
        vessel_name="MSC ISABELLA",
        current_module="STEP_08_COO",
        current_stage="Phase 5 - Sailing & CargoX",
        progress_percent=65.0,
        next_action="Review CargoX Envelope Documents (SH-03)",
        status="Open",
        owner="Kamal",
    )
    db_session.add(imp_file)
    db_session.commit()
    db_session.refresh(imp_file)

    # Initial lifecycle step
    lc_step = ShipmentStageActivity(
        import_file_code=imp_file.import_file_code,
        step_code="STEP_10",
        status="In-Progress",
    )
    db_session.add(lc_step)

    # Pending SH-03 SmartTask
    task = SmartTask(
        task_code="TASK-SH03-TEST",
        import_file_id=imp_file.import_file_id,
        import_file_code=imp_file.import_file_code,
        title="منصة النقل الرقمي CargoX واعتماد الملفات (SH-03)",
        description="رفع واعتماد المظروف الرقمي وختم الوثائق عبر منصة CargoX",
        task_type="CARGOX_TRANSFER",
        priority="High",
        status="Pending",
        assigned_user="Logistics Coordinator",
        due_date=date.today().isoformat(),
        created_by="SYSTEM",
    )
    db_session.add(task)
    db_session.commit()
    return imp_file


class TestSH03CargoXDigitalTransfer:

    def test_cargox_envelope_creation_and_acid_verification(self, db_session, sample_import_file):
        payload = CargoXEnvelopeCreate(
            import_file_id=sample_import_file.import_file_id,
            import_file_code=sample_import_file.import_file_code,
            acid_number="7595528271020210010",
            importer_company_name="Al-Sorour Import Co",
            importer_tax_number="100-294-812",
            supplier_name="Suzhou Silk Industrial Ltd",
            supplier_cargox_id="CX-SUZHOU-9901",
            bl_number="MEDUST991122",
            notes="Ready for sealing and transfer",
            documents=[
                CargoXDocumentCreate(
                    doc_type="Commercial Invoice",
                    doc_number="INV-2026-901",
                    file_name="Commercial_Invoice_Final.pdf",
                    file_size_kb=420.5,
                    is_mandatory=True,
                    verified_against_acid=True,
                ),
                CargoXDocumentCreate(
                    doc_type="Packing List",
                    doc_number="PL-2026-901",
                    file_name="Packing_List_Final.pdf",
                    file_size_kb=310.0,
                    is_mandatory=True,
                    verified_against_acid=True,
                ),
                CargoXDocumentCreate(
                    doc_type="Draft B/L",
                    doc_number="MEDUST991122",
                    file_name="Bill_of_Lading_Draft.pdf",
                    file_size_kb=650.0,
                    is_mandatory=True,
                    verified_against_acid=True,
                ),
            ],
            mode="MOCK",
        )

        envelope = CargoXService.create_envelope(db_session, payload, created_by="Kamal")
        assert envelope.envelope_id is not None
        assert envelope.envelope_code.startswith("CGX-ENV-")
        assert envelope.import_file_id == sample_import_file.import_file_id
        assert len(envelope.documents) == 3

        report = CargoXService.verify_acid_consistency(db_session, envelope.envelope_id)
        assert report.all_matched is True
        assert report.verification_status == "ALL_DOCUMENTS_ACID_VERIFIED"

    def test_cargox_seal_transfer_orchestration(self, db_session, sample_import_file):
        payload = CargoXEnvelopeCreate(
            import_file_id=sample_import_file.import_file_id,
            import_file_code=sample_import_file.import_file_code,
            acid_number="7595528271020210010",
            importer_company_name="Al-Sorour Import Co",
            supplier_name="Suzhou Silk Industrial Ltd",
            supplier_cargox_id="CX-SUZHOU-9901",
            bl_number="MEDUST991122",
            documents=[
                CargoXDocumentCreate(
                    doc_type="Commercial Invoice",
                    file_name="inv.pdf",
                    verified_against_acid=True,
                ),
                CargoXDocumentCreate(
                    doc_type="Packing List",
                    file_name="pl.pdf",
                    verified_against_acid=True,
                ),
                CargoXDocumentCreate(
                    doc_type="Draft B/L",
                    file_name="bl.pdf",
                    verified_against_acid=True,
                ),
            ],
            mode="MOCK",
        )
        envelope = CargoXService.create_envelope(db_session, payload, created_by="Kamal")

        transfer_res = CargoXService.seal_and_transfer_to_customs(
            db_session,
            envelope.envelope_id,
            CargoXSealAndTransferRequest(bl_number="MEDUST991122", mode="MOCK"),
            updated_by="Kamal",
        )

        assert transfer_res.success is True
        assert transfer_res.status == "ACCEPTED_BY_CUSTOMS"
        assert transfer_res.customs_confirmation_receipt is not None
        assert transfer_res.pki_signature is not None

        # 1. Verify ImportFile Synchronization
        db_session.refresh(sample_import_file)
        assert sample_import_file.cargox_envelope_id == envelope.envelope_id
        assert sample_import_file.cargox_envelope_code == envelope.envelope_code
        assert sample_import_file.cargox_envelope_status == "ACCEPTED_BY_CUSTOMS"
        assert sample_import_file.cargox_transferred_at is not None
        assert "STEP_11" in sample_import_file.current_module
        assert sample_import_file.progress_percent >= 70.0
        assert "original bank documents" in sample_import_file.next_action
        assert sample_import_file.next_action_code == "NA_SH04_COLLECT_ORIGINALS"

        # 2. Verify Prior SH-03 SmartTask Completed
        old_task = (
            db_session.query(SmartTask)
            .filter(
                SmartTask.import_file_id == sample_import_file.import_file_id,
                SmartTask.task_type == "CARGOX_TRANSFER",
            )
            .first()
        )
        assert old_task.status == "Completed"

        # 3. Verify Downstream SH-04 SmartTask Dispatched
        downstream_task = (
            db_session.query(SmartTask)
            .filter(
                SmartTask.import_file_id == sample_import_file.import_file_id,
                SmartTask.task_type == "ORIGINAL_DOCS_RECEIPT",
            )
            .first()
        )
        assert downstream_task is not None
        assert "SH-04" in downstream_task.title
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
        assert "CargoX" in notif.title
        assert notif.category == "STAGE_PROGRESSION"

        # 5. Verify CustomsDocumentApproval Created & Approved
        approval = (
            db_session.query(CustomsDocumentApproval)
            .filter(
                CustomsDocumentApproval.import_file_id == sample_import_file.import_file_id,
                CustomsDocumentApproval.document_type == "CARGOX_ENVELOPE",
            )
            .first()
        )
        assert approval is not None
        assert approval.overall_status == "Approved for Clearance"
        assert approval.commercial_status == "Approved"
        assert approval.customs_status == "Approved"

    def test_cargox_transfer_rest_endpoint(self, client, db_session, sample_import_file):
        payload = CargoXEnvelopeCreate(
            import_file_id=sample_import_file.import_file_id,
            import_file_code=sample_import_file.import_file_code,
            acid_number="7595528271020210010",
            importer_company_name="Al-Sorour Import Co",
            supplier_name="Suzhou Silk Industrial Ltd",
            supplier_cargox_id="CX-SUZHOU-9901",
            bl_number="MEDUST991122",
            documents=[
                CargoXDocumentCreate(
                    doc_type="Commercial Invoice",
                    file_name="inv.pdf",
                    verified_against_acid=True,
                ),
                CargoXDocumentCreate(
                    doc_type="Packing List",
                    file_name="pl.pdf",
                    verified_against_acid=True,
                ),
                CargoXDocumentCreate(
                    doc_type="Draft B/L",
                    file_name="bl.pdf",
                    verified_against_acid=True,
                ),
            ],
            mode="MOCK",
        )
        envelope = CargoXService.create_envelope(db_session, payload)

        res = client.post(
            f"/api/v1/cargox/envelopes/{envelope.envelope_id}/seal-and-transfer",
            json={"bl_number": "MEDUST991122", "mode": "MOCK"},
        )
        assert res.status_code == 200
        data = res.json()
        assert data["success"] is True
        assert data["status"] == "ACCEPTED_BY_CUSTOMS"
        assert data["customs_confirmation_receipt"] is not None
