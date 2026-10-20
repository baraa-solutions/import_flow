"""
Unit tests for BE03-T18 (#151):
Audit wiring (created_by, updated_by) across all 9 import documentation tables:
1. acid_registration_sessions
2. banking_document_sessions
3. shipment_document_items
4. customs_declaration_drafts
5. draft_bl_review_sessions
6. certificate_of_origin_review_sessions
7. inspection_certificate_review_sessions
8. invoice_bl_match_sessions
9. po_packing_reconciliation_sessions
"""
from datetime import date
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main  # noqa: F401
from database.database import Base
import modules.currencies.model as curr_models
from modules.import_files.model import ImportFile
from modules.purchase_orders.model import PurchaseOrder, POLineItem, PackingListItem
from modules.suppliers.model import Supplier
from modules.import_companies.model import ImportCompany
from modules.import_documentation.model import (
    AcidRegistrationSession,
    BankingDocumentSession,
    ShipmentDocumentItem,
    CustomsDeclarationDraft,
    DraftBLReviewSession,
    CertificateOfOriginReviewSession,
    InspectionCertificateReviewSession,
    InvoiceBLMatchSession,
    POPackingReconciliationSession,
)
from modules.import_documentation.schemas import (
    AcidRegistrationCreate,
    AcidRegistrationUpdate,
    AcidRegistrationResponse,
    BankingDocumentCreate,
    BankingDocumentUpdate,
    BankingDocumentResponse,
    ShipmentDocumentCreate,
    ShipmentDocumentUpdate,
    ShipmentDocumentResponse,
    CustomsDeclarationCreate,
    CustomsDeclarationResponse,
    DraftBLReviewCreate,
    DraftBLReviewUpdate,
    DraftBLReviewResponse,
    DualApprovalRequest,
    NewDraftVersionRequest,
    CertificateOfOriginReviewCreate,
    CertificateOfOriginReviewUpdate,
    CertificateOfOriginReviewResponse,
    InspectionCertificateReviewCreate,
    InspectionCertificateReviewUpdate,
    InspectionCertificateReviewResponse,
    InvoiceBLMatchSessionCreate,
    InvoiceBLMatchSessionResponse,
    POReconciliationSessionCreate,
    POReconciliationSessionUpdate,
    POReconciliationSessionResponse,
)
import modules.import_documentation.service as service


@pytest.fixture
def db():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()

    company = ImportCompany(
        company_id=1,
        importer_name="Importer Test Co",
        address="Cairo, Egypt",
        country="Egypt",
        importer_id="IMP-001",
        importer_id_expiry=date(2030, 1, 1),
        vat_id="123456789",
        vat_id_expiry=date(2030, 1, 1),
        registration_number="12345",
        registration_expiry=date(2030, 1, 1),
        is_active=True,
    )
    supplier = Supplier(
        supplier_id=1,
        supplier_code="SUPP-001",
        company_name="Supplier Test Co",
        supplier_type="MANUFACTURER",
        registration_type="COMMERCIAL",
        foreign_exporter_id="EXP-12345",
        foreign_exporter_country="Germany",
        foreign_exporter_country_code="DE",
        address="Berlin, Germany",
        is_active=True,
    )
    session.add(company)
    session.add(supplier)

    session.add(ImportFile(
        import_file_id=1,
        import_file_code="IMP-AUDIT-001",
        company_id=1,
        supplier_id=1,
        company_name="Importer Test Co",
        supplier_name="Supplier Test Co",
        po_number="PO-AUDIT-1",
        acid_number="1234567890123456789",
        is_active=True,
    ))
    session.add(curr_models.Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True))
    session.add(curr_models.Currency(currency_code="EUR", currency_name="Euro", currency_symbol="€", is_active=True))
    session.add(curr_models.Currency(currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="EGP", is_active=True))

    session.add(PurchaseOrder(
        po_id=1,
        po_number="PO-AUDIT-1",
        import_file_id=1,
        project_id=1,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        currency_id=1,
        status="DRAFT",
        version=1,
        is_active=True,
    ))
    session.add(POLineItem(item_id=10, po_id=1, item_code="ITEM-1", description_ar="بند 1", quantity=10, unit_price=10.0, total_price=100.0))
    session.add(PackingListItem(packing_item_id=10, po_id=1, item_code="ITEM-1", hs_code="940130", qty_pkg=5, total_gross_weight_kg=50.0))

    session.commit()
    yield session
    session.close()
    engine.dispose()


def test_legacy_rows_deserialize_none_audit_columns(db):
    """Verify that legacy database rows with NULL created_by and updated_by serialize without validation error."""
    # 1. AcidRegistrationSession legacy row
    acid_row = AcidRegistrationSession(
        acid_code="ACID-LEGACY-01",
        import_file_id=1,
        acid_number="9999999999999999999",
        proforma_invoice_no="PI-LEGACY-01",
        exporter_name="Exp",
        exporter_country="Germany",
        exporter_reg_id="DE1",
        importer_name="Imp",
        importer_tax_id="123456789",
        pol_name="Hamburg",
        pod_name="Alexandria",
        status="ACTIVE",
        expiry_date=date(2027, 1, 1),
        is_active=True,
        created_by=None,
        updated_by=None,
    )
    db.add(acid_row)
    db.commit()
    db.refresh(acid_row)

    resp = service.enrich_acid_response(db, acid_row)
    assert resp.created_by is None
    assert resp.updated_by is None

    # 2. BankingDocumentSession legacy row
    bank_row = BankingDocumentSession(
        bank_doc_code="DOC-LEGACY-01",
        import_file_id=1,
        doc_type="Form 4",
        bank_name="National Bank of Egypt",
        amount=1000.0,
        currency_code="USD",
        status="Form Issued",
        is_active=True,
        created_by=None,
        updated_by=None,
    )
    db.add(bank_row)
    db.commit()
    db.refresh(bank_row)

    bank_resp = BankingDocumentResponse.model_validate(bank_row)
    assert bank_resp.created_by is None
    assert bank_resp.updated_by is None

    # 3. PO Reconciliation session legacy row
    po_row = POPackingReconciliationSession(
        session_code="PO-RECON-LEGACY",
        import_file_id=1,
        final_invoice_number="INV-LEG-01",
        final_packing_list_number="PL-LEG-01",
        currency="USD",
        overall_status="MATCHED",
        is_active=True,
        created_by=None,
        updated_by=None,
    )
    db.add(po_row)
    db.commit()
    db.refresh(po_row)

    po_resp = service.enrich_po_reconciliation_session_response(db, po_row)
    assert po_resp.created_by is None
    assert po_resp.updated_by is None


def test_acid_session_audit_wiring(db):
    """Verify created_by and updated_by on ACID session create and update."""
    create_schema = AcidRegistrationCreate(
        import_file_id=1,
        acid_number="1234567890123456789",
        proforma_invoice_no="PI-AUDIT-1",
        exporter_name="Exporter Co",
        exporter_country="Germany",
        exporter_reg_id="DE12345",
        importer_name="Importer Co",
        importer_tax_id="123456789",
        pol_name="Hamburg",
        pod_name="Alexandria",
        issue_date=date.today(),
    )
    resp = service.create_acid_session_service(db, create_schema, user="ahmed_audit")
    assert resp.created_by == "ahmed_audit"
    assert resp.updated_by == "ahmed_audit"

    # Verify directly in DB
    row = db.get(AcidRegistrationSession, resp.acid_id)
    assert row.created_by == "ahmed_audit"
    assert row.updated_by == "ahmed_audit"

    # Update session
    update_schema = AcidRegistrationUpdate(notes="Updated notes")
    up_resp = service.update_acid_session_service(db, resp.acid_id, update_schema, user="mahmoud_editor")
    assert up_resp.created_by == "ahmed_audit"
    assert up_resp.updated_by == "mahmoud_editor"

    db.refresh(row)
    assert row.created_by == "ahmed_audit"
    assert row.updated_by == "mahmoud_editor"


def test_banking_document_audit_wiring(db):
    """Verify created_by and updated_by on Banking Document create and update."""
    create_schema = BankingDocumentCreate(
        import_file_id=1,
        doc_type="Form 4",
        bank_name="National Bank of Egypt",
        amount=5000.0,
        currency_code="USD",
        status="Requested",
    )
    resp = service.create_banking_document_service(db, create_schema, user="sami_bank")
    assert resp.created_by == "sami_bank"
    assert resp.updated_by == "sami_bank"

    row = db.get(BankingDocumentSession, resp.bank_doc_id)
    assert row.created_by == "sami_bank"
    assert row.updated_by == "sami_bank"

    # Update
    update_schema = BankingDocumentUpdate(status="Form Issued", doc_reference_number="F4-9988")
    up_resp = service.update_banking_document_service(db, resp.bank_doc_id, update_schema, user="fatma_updater")
    assert up_resp.created_by == "sami_bank"
    assert up_resp.updated_by == "fatma_updater"

    db.refresh(row)
    assert row.created_by == "sami_bank"
    assert row.updated_by == "fatma_updater"


def test_shipment_document_and_customs_declaration_audit_wiring(db):
    """Verify created_by and updated_by on Shipment Document and Customs Declaration."""
    doc_create = ShipmentDocumentCreate(
        import_file_id=1,
        doc_name="Commercial Invoice #101",
        doc_number="INV-101",
    )
    doc_resp = service.create_shipment_document_service(db, doc_create, user="logistics_user")
    assert doc_resp.created_by == "logistics_user"
    assert doc_resp.updated_by == "logistics_user"

    doc_row = db.get(ShipmentDocumentItem, doc_resp.document_id)
    assert doc_row.created_by == "logistics_user"
    assert doc_row.updated_by == "logistics_user"

    # Update shipment doc via cargox and endorsement service
    up_doc = service.update_cargox_and_bl_endorsement_service(
        db, doc_resp.document_id, cargox_envelope_id="ENV-12345", endorsement_number="END-9988", user="customs_agent"
    )
    assert up_doc.created_by == "logistics_user"
    assert up_doc.updated_by == "customs_agent"

    # Customs Declaration create
    decl_create = CustomsDeclarationCreate(
        import_file_id=1,
        acid_number="1234567890123456789",
        customs_center="Alexandria Port",
        declaration_type="Preliminary",
        status="SUBMITTED",
        declaration_number="DEC-12345",
    )
    decl_resp = service.create_customs_declaration_service(db, decl_create, user="broker_user")
    assert decl_resp.created_by == "broker_user"
    assert decl_resp.updated_by == "broker_user"

    decl_row = db.get(CustomsDeclarationDraft, decl_resp.declaration_id)
    assert decl_row.created_by == "broker_user"
    assert decl_row.updated_by == "broker_user"


def test_draft_bl_review_audit_wiring(db):
    """Verify created_by and updated_by on Draft B/L Review lifecycle."""
    bl_create = DraftBLReviewCreate(
        import_file_id=1,
        po_id=1,
        draft_bl_number="MEDU12345678",
        shipping_line="MSC",
        vessel_name="MSC Oscar",
        voyage_number="2401W",
        booking_no="BK-123",
        is_draft=True,
    )
    saved = service.create_draft_bl_review_service(db, bl_create, user="bl_officer")
    assert saved.created_by == "bl_officer"
    assert saved.updated_by == "bl_officer"

    # Update draft BL
    bl_update = DraftBLReviewUpdate(vessel_name="MSC Grand")
    updated = service.update_draft_bl_review_service(db, saved.bl_review_id, bl_update, user="bl_editor")
    assert updated.created_by == "bl_officer"
    assert updated.updated_by == "bl_editor"

    # Advance to dual approval stage
    saved.is_draft = False
    saved.stage = "Stage 4: Dual Approval"
    saved.status = "REVIEWED_PENDING_APPROVAL"
    saved.open_discrepancies_count = 0
    saved.has_blocking_mismatch = False
    db.commit()

    dual_req = DualApprovalRequest(
        bl_review_id=saved.bl_review_id,
        role="importer",
        action="Approved",
        notes="Importer approved",
    )
    app_res = service.process_dual_approval_service(db, dual_req, user="importer_approver")
    assert app_res.updated_by == "importer_approver"

    # Create new draft version
    ver_req = NewDraftVersionRequest(
        parent_session_id=saved.bl_review_id,
        draft_source="AI_OCR",
        raw_draft_text="B/L MEDU12345678",
    )
    new_ver = service.create_new_draft_version_service(db, ver_req, user="version_creator")
    assert new_ver.created_by == "version_creator"
    assert new_ver.updated_by == "version_creator"
    db.refresh(saved)
    assert saved.updated_by == "version_creator"


def test_coo_and_inspection_audit_wiring(db):
    """Verify created_by and updated_by on COO and Inspection review sessions."""
    # COO
    coo_create = CertificateOfOriginReviewCreate(
        import_file_id=1,
        po_id=1,
        certificate_type="EUR.1",
        certificate_number="EUR-98765",
        country_of_origin="Germany",
        is_draft=True,
    )
    coo = service.create_coo_review_service(db, coo_create, user="coo_creator")
    assert coo.created_by == "coo_creator"
    assert coo.updated_by == "coo_creator"

    coo_update = CertificateOfOriginReviewUpdate(notes="Reviewed draft COO")
    coo_up = service.update_coo_review_service(db, coo.coo_review_id, coo_update, user="coo_editor")
    assert coo_up.created_by == "coo_creator"
    assert coo_up.updated_by == "coo_editor"

    # Inspection
    insp_create = InspectionCertificateReviewCreate(
        import_file_id=1,
        inspection_type="COC",
        certificate_number="COC-12345",
        inspection_agency="SGS",
        notes="Pre-inspection",
        override_reason="Discrepancy accepted by manager",
    )
    insp = service.create_inspection_review_service(db, insp_create, user="insp_user")
    assert insp.created_by == "insp_user"
    assert insp.updated_by == "insp_user"

    insp_update = InspectionCertificateReviewUpdate(
        notes="Inspection report attached",
        override_reason="Discrepancy accepted by manager",
    )
    insp_up = service.update_inspection_review_service(db, insp.inspection_review_id, insp_update, user="insp_checker")
    assert insp_up.created_by == "insp_user"
    assert insp_up.updated_by == "insp_checker"


def test_invoice_bl_match_audit_wiring(db):
    """Verify created_by and updated_by on Invoice-BL match sessions."""
    match_create = InvoiceBLMatchSessionCreate(
        import_file_id=1,
        final_invoice_number="INV-MATCH-01",
        draft_bl_number="BL-MATCH-01",
        is_draft=True,
    )
    sess = service.create_invoice_bl_match_session_service(db, match_create, user="match_user")
    assert sess.created_by == "match_user"
    assert sess.updated_by == "match_user"

    # Updating the draft session through create service with is_draft=True
    match_update = InvoiceBLMatchSessionCreate(
        import_file_id=1,
        final_invoice_number="INV-MATCH-01",
        draft_bl_number="BL-MATCH-01-V2",
        notes="Updated draft matching",
        is_draft=True,
    )
    sess_up = service.create_invoice_bl_match_session_service(db, match_update, user="match_editor")
    assert sess_up.created_by == "match_user"
    assert sess_up.updated_by == "match_editor"


def test_po_reconciliation_audit_wiring(db):
    """Verify created_by and updated_by on PO & Packing reconciliation sessions."""
    recon_create = POReconciliationSessionCreate(
        import_file_id=1,
        final_invoice_number="INV-PO-01",
        final_packing_list_number="PL-PO-01",
        currency="USD",
        overall_status="DRAFT",
    )
    sess = service.create_po_reconciliation_session_service(db, recon_create, user="recon_user")
    assert sess.created_by == "recon_user"
    assert sess.updated_by == "recon_user"

    # Direct DB check
    row = db.get(POPackingReconciliationSession, sess.session_id)
    assert row.created_by == "recon_user"
    assert row.updated_by == "recon_user"

    # Update
    recon_update = POReconciliationSessionUpdate(notes="Updated reconciliation data")
    sess_up = service.update_po_reconciliation_session_service(db, sess.session_id, recon_update, user="recon_editor")
    assert sess_up.created_by == "recon_user"
    assert sess_up.updated_by == "recon_editor"

    db.refresh(row)
    assert row.created_by == "recon_user"
    assert row.updated_by == "recon_editor"
