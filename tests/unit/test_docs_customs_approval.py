"""
Unit tests for Docs Customs Approval Hub (DCA-001)
"""

import main
import pytest
from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from database.database import Base

from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.purchase_orders.model import PurchaseOrder, POLineItem
from modules.import_files.model import ImportFile
from modules.import_documentation.model import AcidRegistrationSession
from fastapi import HTTPException
from modules.docs_customs_approval.model import (
    CustomsDocumentApproval,
    DiscrepancyRectificationTicket,
    DocsCustomsApprovalSession,
)
from modules.docs_customs_approval.schemas import (
    CustomsDocumentApprovalCreate,
    CommercialReviewPayload,
    CustomsBrokerReviewPayload,
    DiscrepancyTicketCreate,
    DiscrepancyTicketResolve,
    DocsCustomsApprovalSessionCreate,
)

import modules.docs_customs_approval.service as service


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:", echo=False)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def setup_import_data(db_session):
    company = ImportCompany(
        company_id=1,
        importer_name="Al-Ahram Trading",
        vat_id="100-200-300",
        vat_id_expiry=date(2028, 1, 1),
        registration_number="CR-12345",
        registration_expiry=date(2028, 1, 1),
        importer_id="CARD-999",
        importer_id_expiry=date(2028, 1, 1),
        address="Cairo, Egypt",
        country="Egypt",
        is_active=True,
    )
    db_session.add(company)

    supplier = Supplier(
        supplier_id=1,
        company_name="Shanghai Machinery Corp",
        supplier_code="SUP-CN-001",
        supplier_type="Manufacturer",
        registration_type="Foreign Exporter",
        foreign_exporter_id="VAT-CN-999",
        foreign_exporter_country="China",
        foreign_exporter_country_code="CN",
        address="Shanghai, China",
        is_active=True,
    )
    db_session.add(supplier)
    db_session.commit()

    po = PurchaseOrder(
        po_id=1,
        po_number="PO-2026-9001",
        project_id=1,
        company_id=company.company_id,
        supplier_id=supplier.supplier_id,
        incoterm_id=1,
        currency_id=1,
        total_amount_fob=50000.0,
        is_active=True,
    )
    db_session.add(po)
    db_session.commit()

    line = POLineItem(
        po_id=po.po_id,
        item_code="ITM-01",
        description_ar="أجهزة تكييف الهواء",
        description_en="Air Conditioners",
        country_of_origin="China",
        quantity=100.0,
        unit_price=500.0,
        total_price=50000.0,
    )
    db_session.add(line)
    db_session.commit()

    file = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-8888",
        custom_file_number="FILE-8888",
        company_id=company.company_id,
        company_name="Al-Ahram Trading",
        supplier_name="Shanghai Machinery Corp",
        po_number="PO-2026-9001",
        acid_number="1234567890123456789",
        status="In Progress",
        current_stage="STAGE_05_DRAFT_DOCS",
        is_active=True,
    )
    db_session.add(file)
    db_session.commit()

    acid = AcidRegistrationSession(
        acid_code="ACID-2026-0001",
        acid_number="1234567890123456789",
        import_file_id=file.import_file_id,
        importer_name="Al-Ahram Trading",
        importer_tax_id="100-200-300",
        exporter_name="Shanghai Machinery Corp",
        exporter_reg_id="VAT-CN-999",
        exporter_country="China",
        proforma_invoice_no="PI-2026-01",
        pol_name="Shanghai",
        pod_name="Alexandria",
        expiry_date=date(2028, 1, 1),
        is_active=True,
    )
    db_session.add(acid)
    db_session.commit()

    return file


def test_create_and_auto_generate_approvals(db_session, setup_import_data):
    file = setup_import_data

    # 1. Create specific approval
    payload = CustomsDocumentApprovalCreate(
        import_file_id=file.import_file_id,
        document_type="Commercial Invoice",
        document_reference_no="INV-2026-01",
        document_date=date(2026, 8, 15),
    )
    approval = service.create_approval_service(db_session, payload)
    assert approval.approval_id is not None
    assert approval.approval_code.startswith("CDA-2026-")
    assert approval.document_type == "Commercial Invoice"

    # 2. Auto generate remaining checklist
    all_approvals = service.auto_generate_approvals_for_import_file_service(db_session, file.import_file_id)
    assert len(all_approvals) >= 7
    types = [a.document_type for a in all_approvals]
    assert "Bill of Lading" in types
    assert "Certificate of Origin" in types
    assert "Bank Form 4" in types


def test_cross_document_matrix_audit(db_session, setup_import_data):
    file = setup_import_data

    audit_res = service.run_cross_document_matrix_check_service(db_session, file.import_file_id)
    assert audit_res.import_file_id == file.import_file_id
    assert audit_res.total_checks >= 5
    assert audit_res.overall_compliance in ("Fully Compliant", "Discrepancies Found")

    # Verify ACID check was performed and matched
    acid_check = next((c for c in audit_res.checks if "ACID" in c.parameter), None)
    assert acid_check is not None
    assert acid_check.status == "Match"


def test_dual_tiered_review_flow(db_session, setup_import_data):
    file = setup_import_data

    payload = CustomsDocumentApprovalCreate(
        import_file_id=file.import_file_id,
        document_type="Bill of Lading",
        document_reference_no="MSCU1234567",
    )
    approval = service.create_approval_service(db_session, payload)

    # 1. Commercial Review
    comm_payload = CommercialReviewPayload(
        reviewer_name="Ahmed Import Specialist",
        status="Approved",
        notes="All commercial terms verified.",
    )
    updated_comm = service.submit_commercial_review_service(db_session, approval.approval_id, comm_payload)
    assert updated_comm.commercial_status == "Approved"
    assert updated_comm.commercial_reviewed_by == "Ahmed Import Specialist"
    assert updated_comm.overall_status == "Under Review"

    # 2. Customs Broker Review
    broker_payload = CustomsBrokerReviewPayload(
        broker_name="Nile Customs Clearance LLC",
        reviewer_name="Mohamed Licensed Broker",
        status="Approved",
        notes="Customs tariff and Egyptian regulatory approvals verified.",
    )
    updated_broker = service.submit_customs_broker_review_service(db_session, approval.approval_id, broker_payload)
    assert updated_broker.customs_status == "Approved"
    assert updated_broker.overall_status == "Approved for Clearance"


def test_discrepancy_rectification_ticket_lifecycle(db_session, setup_import_data):
    file = setup_import_data

    # 1. Create Ticket
    ticket_payload = DiscrepancyTicketCreate(
        import_file_id=file.import_file_id,
        issue_category="HS Code Mismatch",
        severity="Critical",
        description="Invoice HS code 8415.90 differs from PO and ACID 8415.10",
        expected_value="8415.10",
        found_value="8415.90",
        supplier_action_required="Please reissue draft invoice with correct HS Code 8415.10",
    )
    ticket = service.create_rectification_ticket_service(db_session, ticket_payload)
    assert ticket.ticket_id is not None
    assert ticket.ticket_code.startswith("RECT-2026-")
    assert ticket.status == "Open"

    # 2. Resolve Ticket
    resolve_payload = DiscrepancyTicketResolve(
        supplier_response="Amended draft invoice uploaded to CargoX with HS Code 8415.10.",
        resolved_by="Customs Compliance Manager",
        new_status="Resolved",
    )
    resolved = service.resolve_rectification_ticket_service(db_session, ticket.ticket_id, resolve_payload)
    assert resolved.status == "Resolved"
    assert resolved.resolved_by == "Customs Compliance Manager"
    assert resolved.resolved_at is not None


def test_be03_t11_dca_po_of_another_file_sharing_po_number_hs_not_checked(db_session, setup_import_data):
    file1 = setup_import_data
    file2 = ImportFile(
        import_file_id=20,
        import_file_code="IMP-2026-9999",
        custom_file_number="FILE-9999",
        company_name="Al-Ahram Trading",
        supplier_name="Shanghai Machinery Corp",
        po_number="PO-SHARED-123",
        acid_number="9994567890123456789",
        status="In Progress",
        current_stage="STAGE_05_DRAFT_DOCS",
        is_active=True,
    )
    db_session.add(file2)
    file1.po_number = "PO-SHARED-123"
    po2 = PurchaseOrder(
        po_id=201,
        po_number="PO-SHARED-123",
        project_id=1,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        currency_id=1,
        import_file_id=file2.import_file_id,
        total_amount_fob=50000.0,
        is_active=True,
    )
    db_session.add(po2)
    db_session.add(POLineItem(po_id=201, item_code="ITM-99", description_ar="Item", quantity=10, unit_price=10.0))
    db_session.commit()

    audit_res = service.run_cross_document_matrix_check_service(db_session, file1.import_file_id)
    hs_check = next((c for c in audit_res.checks if c.parameter == "HS Code Classification"), None)
    assert hs_check is not None
    assert hs_check.status == "Not Checked"


# ── BE03-T08 DCA Final Session Approvals Tests ──────────────────────────────

def test_be03_t08_final_save_rejected_status_raises_400_lifecycle_not_advanced(db_session, setup_import_data):
    file = setup_import_data
    file.progress_percent = 40.0
    file.current_module = "STEP_08_PO"
    db_session.commit()

    # Create approved rows for all 4 core docs
    doc_types = ["Commercial Invoice", "Packing List", "Bill of Lading", "Certificate of Origin"]
    for i, dt in enumerate(doc_types, start=1):
        db_session.add(CustomsDocumentApproval(
            approval_code=f"CDA-T08-1-{i}",
            import_file_id=file.import_file_id,
            document_type=dt,
            overall_status="Approved for Clearance",
            is_active=True,
        ))
    db_session.commit()

    # Final save with final_invoice_status="Rejected"
    payload = DocsCustomsApprovalSessionCreate(
        import_file_id=file.import_file_id,
        is_draft=False,
        final_invoice_ref="INV-001",
        final_invoice_status="Rejected",
        final_pl_status="Approved",
        draft_bl_status="Approved",
        coo_status="Approved",
        coc_status="Waived / Not Required",
    )

    with pytest.raises(HTTPException) as exc_info:
        service.create_customs_approval_session_service(db_session, payload)

    assert exc_info.value.status_code == 400
    assert exc_info.value.detail["code"] == "DCA_SESSION_NOT_READY"

    # Verify lifecycle not advanced
    db_session.refresh(file)
    assert file.progress_percent == 40.0
    assert "STEP_10" not in (file.current_module or "")


def test_be03_t08_approval_row_under_review_raises_400_with_unapproved_documents(db_session, setup_import_data):
    file = setup_import_data

    # Commercial Invoice, Packing List, Certificate of Origin are "Approved for Clearance"
    # Bill of Lading is "Under Review"
    statuses = {
        "Commercial Invoice": "Approved for Clearance",
        "Packing List": "Approved for Clearance",
        "Bill of Lading": "Under Review",
        "Certificate of Origin": "Approved for Clearance",
    }
    for i, (dt, st) in enumerate(statuses.items(), start=1):
        db_session.add(CustomsDocumentApproval(
            approval_code=f"CDA-T08-2-{i}",
            import_file_id=file.import_file_id,
            document_type=dt,
            overall_status=st,
            is_active=True,
        ))
    db_session.commit()

    payload = DocsCustomsApprovalSessionCreate(
        import_file_id=file.import_file_id,
        is_draft=False,
        final_invoice_status="Approved",
        final_pl_status="Approved",
        draft_bl_status="Approved",
        coo_status="Approved",
        coc_status="Waived / Not Required",
    )

    with pytest.raises(HTTPException) as exc_info:
        service.create_customs_approval_session_service(db_session, payload)

    assert exc_info.value.status_code == 400
    assert exc_info.value.detail["code"] == "DCA_SESSION_NOT_READY"
    assert exc_info.value.detail["unapproved_documents"] == ["Bill of Lading"]


def test_be03_t08_all_approved_returns_session_and_advances_lifecycle(db_session, setup_import_data):
    file = setup_import_data
    file.progress_percent = 40.0
    db_session.commit()

    doc_types = ["Commercial Invoice", "Packing List", "Bill of Lading", "Certificate of Origin"]
    for i, dt in enumerate(doc_types, start=1):
        db_session.add(CustomsDocumentApproval(
            approval_code=f"CDA-T08-3-{i}",
            import_file_id=file.import_file_id,
            document_type=dt,
            overall_status="Approved for Clearance",
            is_active=True,
        ))
    db_session.commit()

    payload = DocsCustomsApprovalSessionCreate(
        import_file_id=file.import_file_id,
        is_draft=False,
        overall_status="DRAFT",  # Should be ignored and set to APPROVED
        final_invoice_status="Approved",
        final_pl_status="Approved",
        draft_bl_status="Approved",
        coo_status="Approved",
        coc_status="Waived / Not Required",
    )

    res = service.create_customs_approval_session_service(db_session, payload)
    assert res.session_id is not None
    assert res.is_draft is False
    assert res.overall_status == "APPROVED"

    db_session.refresh(file)
    assert file.progress_percent >= 60.0
    assert "STEP_10" in (file.current_module or "")


def test_be03_t08_invalid_session_status_value_raises_422(db_session, setup_import_data):
    file = setup_import_data
    from pydantic import ValidationError

    # When constructing schema with invalid status
    with pytest.raises(ValidationError):
        DocsCustomsApprovalSessionCreate(
            import_file_id=file.import_file_id,
            is_draft=True,
            final_invoice_status="INVALID_STATUS",
        )


def test_be03_t08_body_overall_status_ignored_draft_is_draft_final_is_approved(db_session, setup_import_data):
    file = setup_import_data

    # Draft session with client overall_status="APPROVED" -> server sets "DRAFT"
    draft_payload = DocsCustomsApprovalSessionCreate(
        import_file_id=file.import_file_id,
        is_draft=True,
        overall_status="APPROVED",
    )
    draft_res = service.create_customs_approval_session_service(db_session, draft_payload)
    assert draft_res.is_draft is True
    assert draft_res.overall_status == "DRAFT"

