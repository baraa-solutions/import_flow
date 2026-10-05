import pytest
from datetime import datetime, timezone
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from database.database import Base
from modules.import_files.model import ImportFile
from modules.import_documentation.model import DraftBLReviewSession, CertificateOfOriginReviewSession
from modules.docs_customs_approval.model import CustomsDocumentApproval
from modules.import_documentation.schemas import (
    DraftBLReviewCreate,
    CertificateOfOriginReviewCreate,
)
import modules.import_documentation.service as service


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()

    # Create dummy import file
    file = ImportFile(
        import_file_id=101,
        import_file_code="IMP-2026-TEST-PARITY",
        custom_file_number="FILE-PARITY-001",
        company_id=1,
        company_name="Test Importer Corp",
        supplier_id=1,
        supplier_name="Test Global Exporter Ltd",
        status="Under Review",
        is_active=True,
    )
    session.add(file)

    # Add Customs Document Approvals rows
    bl_app = CustomsDocumentApproval(
        approval_code="APP-BL-001",
        import_file_id=101,
        document_type="Bill of Lading",
        commercial_status="Pending",
        customs_status="Pending",
        overall_status="Under Review",
        is_active=True,
    )
    coo_app = CustomsDocumentApproval(
        approval_code="APP-COO-001",
        import_file_id=101,
        document_type="Certificate of Origin",
        commercial_status="Pending",
        customs_status="Pending",
        overall_status="Under Review",
        is_active=True,
    )
    session.add(bl_app)
    session.add(coo_app)
    session.commit()

    yield session
    session.close()


def test_draft_bl_draft_save_does_not_approve_customs(db_session):
    schema = DraftBLReviewCreate(
        import_file_id=101,
        draft_bl_number="DRAFT-BL-TEMP-001",
        shipping_line="MSC Mediterranean Shipping",
        vessel_name="MSC GISELLE",
        is_draft=True,
    )

    created = service.create_draft_bl_review_service(db_session, schema)
    assert created.is_draft is True
    assert created.status == "DRAFT"
    assert created.draft_bl_number == "DRAFT-BL-TEMP-001"

    # Verify customs approval is NOT updated
    bl_app = db_session.query(CustomsDocumentApproval).filter(
        CustomsDocumentApproval.import_file_id == 101,
        CustomsDocumentApproval.document_type == "Bill of Lading",
    ).first()
    assert bl_app.commercial_status == "Pending"


def test_draft_bl_certified_save_approves_customs(db_session):
    schema = DraftBLReviewCreate(
        import_file_id=101,
        draft_bl_number="MEDU12345678",
        shipping_line="MSC Mediterranean Shipping",
        vessel_name="MSC GISELLE",
        booking_no="BK-9988",
        status="APPROVED",
        is_draft=False,
        approved_by="Auditor General",
    )

    created = service.create_draft_bl_review_service(db_session, schema)
    assert created.is_draft is False
    assert created.status == "APPROVED"
    assert created.stage == "Stage 5: Final"

    # Verify customs approval IS updated
    bl_app = db_session.query(CustomsDocumentApproval).filter(
        CustomsDocumentApproval.import_file_id == 101,
        CustomsDocumentApproval.document_type == "Bill of Lading",
    ).first()
    assert bl_app.commercial_status == "Approved"
    assert bl_app.document_reference_no == "MEDU12345678"
    # Single-language storage (docs/plans/single-language-storage-plan.md, rule 1):
    # system-written notes are stored in English, never in the UI language.
    assert bl_app.commercial_notes == "Draft B/L MEDU12345678 approved (SH-02 / STEP_08_BL)."
    assert not any("؀" <= ch <= "ۿ" for ch in bl_app.commercial_notes)

    # Verify ImportFile updated
    imp_file = db_session.query(ImportFile).filter(ImportFile.import_file_id == 101).first()
    assert imp_file.bl_number == "MEDU12345678"


def test_coo_draft_save_does_not_approve_customs(db_session):
    schema = CertificateOfOriginReviewCreate(
        import_file_id=101,
        certificate_type="EUR.1",
        certificate_number="EUR1-DRAFT-99",
        exporter_name="Global Shipper",
        importer_name="Test Importer Corp",
        country_of_origin="Germany",
        destination_country="Egypt",
        is_draft=True,
    )

    created = service.create_coo_review_service(db_session, schema)
    assert created.is_draft is True
    assert created.status == "Draft Generated"

    coo_app = db_session.query(CustomsDocumentApproval).filter(
        CustomsDocumentApproval.import_file_id == 101,
        CustomsDocumentApproval.document_type == "Certificate of Origin",
    ).first()
    assert coo_app.commercial_status == "Pending"


def test_coo_certified_save_approves_customs(db_session):
    schema = CertificateOfOriginReviewCreate(
        import_file_id=101,
        certificate_type="EUR.1",
        certificate_number="EUR1-OFFICIAL-2026",
        exporter_name="Global Shipper",
        importer_name="Test Importer Corp",
        country_of_origin="Germany",
        destination_country="Egypt",
        is_draft=False,
        reviewed_by="Origin Inspector",
    )

    created = service.create_coo_review_service(db_session, schema)
    assert created.is_draft is False
    assert created.status == "Approved"

    coo_app = db_session.query(CustomsDocumentApproval).filter(
        CustomsDocumentApproval.import_file_id == 101,
        CustomsDocumentApproval.document_type == "Certificate of Origin",
    ).first()
    assert coo_app.commercial_status == "Approved"
    assert coo_app.document_reference_no == "EUR1-OFFICIAL-2026"
    # Single-language storage (rule 1): system-written notes are English.
    assert coo_app.commercial_notes == (
        "Certificate of origin EUR.1 - EUR1-OFFICIAL-2026 approved (STEP_08_COO)."
    )
    assert not any("؀" <= ch <= "ۿ" for ch in coo_app.commercial_notes)


def test_sessions_filtering_and_deletion(db_session):
    # Save a draft BL and a certified BL
    s1 = service.create_draft_bl_review_service(
        db_session,
        DraftBLReviewCreate(import_file_id=101, draft_bl_number="BL-DRAFT-1", is_draft=True)
    )
    s2 = service.create_draft_bl_review_service(
        db_session,
        DraftBLReviewCreate(import_file_id=101, draft_bl_number="BL-CERT-2", is_draft=False)
    )

    # Filter is_draft = True
    drafts = service.get_draft_bl_reviews_service(db_session, import_file_id=101, is_draft=True)
    assert any(d.draft_bl_number == "BL-DRAFT-1" for d in drafts)

    # Delete draft session
    del_res = service.delete_draft_bl_review_service(db_session, s1.bl_review_id)
    assert del_res["deleted"] is True

    # Check that deleted is inactive
    active_drafts = service.get_draft_bl_reviews_service(db_session, import_file_id=101, is_draft=True)
    assert not any(d.bl_review_id == s1.bl_review_id for d in active_drafts)
