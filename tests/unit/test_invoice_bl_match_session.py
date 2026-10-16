import pytest
from datetime import date
from modules.import_documentation.schemas import (
    InvoiceBLMatchSessionCreate,
    InvoiceBLMatchSessionUpdate,
)
from modules.import_documentation.service import (
    create_invoice_bl_match_session_service,
    list_invoice_bl_match_sessions_service,
    get_invoice_bl_match_session_service,
)
from modules.docs_customs_approval.schemas import (
    DocsCustomsApprovalSessionCreate,
)
from modules.docs_customs_approval.service import (
    create_customs_approval_session_service,
    list_customs_approval_sessions_service,
)
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from database.database import Base
from modules.import_files.model import ImportFile
from modules.docs_customs_approval.model import CustomsDocumentApproval


@pytest.fixture(scope="function")
def db_session():
    from database.database import SessionLocal, Base, engine
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()



def test_invoice_bl_match_session_lifecycle(db_session):
    # 1. Setup an ImportFile
    file = ImportFile(
        custom_file_number="IMP-2026-TEST-MATCH",
        import_file_code="IMP-MATCH-01",
        company_name="Test Importer LLC",
        supplier_name="Global Supplier Inc.",
        progress_percent=50.0,
        is_active=True,
    )
    db_session.add(file)
    db_session.commit()
    db_session.refresh(file)

    # 2. Add sample CustomsDocumentApproval records to verify reflection
    inv_approval = CustomsDocumentApproval(
        approval_code="CDA-TEST-INV",
        import_file_id=file.import_file_id,
        document_type="Commercial Invoice",
        overall_status="Draft",
        is_active=True,
    )
    bl_approval = CustomsDocumentApproval(
        approval_code="CDA-TEST-BL",
        import_file_id=file.import_file_id,
        document_type="Bill of Lading",
        overall_status="Draft",
        is_active=True,
    )
    db_session.add_all([inv_approval, bl_approval])
    db_session.commit()

    # 3. Create Draft Session
    draft_payload = InvoiceBLMatchSessionCreate(
        import_file_id=file.import_file_id,
        invoice_number="INV-2026-999",
        bl_number="MEDU1234567",
        match_score_percentage=94.5,
        overall_status="ACCEPTED_WITH_WARNINGS",
        is_safe_for_certification=True,
        is_draft=True,
        notes="Draft in-progress matching session",
    )
    draft_session = create_invoice_bl_match_session_service(db_session, draft_payload)
    assert draft_session.session_id is not None
    assert draft_session.session_code.startswith("MATCH-")
    assert draft_session.is_draft is True
    assert draft_session.invoice_number == "INV-2026-999"

    # 4. List sessions
    sessions = list_invoice_bl_match_sessions_service(db_session, import_file_id=file.import_file_id)
    assert len(sessions) == 1
    assert sessions[0].session_code == draft_session.session_code

    # Phase 3a DOC-13: certify-and-sync validates the invoice currency against the currency master data, so the
    # USD row must exist (the shared session DB may already hold it).
    from modules.currencies.model import Currency
    if not db_session.query(Currency).filter(Currency.currency_code == "USD").first():
        db_session.add(Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True))
        db_session.commit()

    # 5. Save Certified Session (is_draft = False) -> Should reflect in CustomsDocumentApproval!
    certified_payload = InvoiceBLMatchSessionCreate(
        import_file_id=file.import_file_id,
        invoice_number="INV-2026-999",
        bl_number="MEDU1234567",
        match_score_percentage=100.0,
        overall_status="FULLY_MATCHED",
        is_safe_for_certification=True,
        is_draft=False,
        invoice_data={"invoice_number": "INV-2026-999", "total_amount": 50000.0, "currency": "USD"},
        bl_data={"draft_bl_number": "MEDU1234567", "vessel_name": "MSC GISELLE"},
        notes="Final certified matching session",
        certified_by="Eng. Ahmed Sorour",
    )
    # Phase 3a DOC-12: the certifier is the logged-in user (``user``); the payload's certified_by is ignored.
    cert_session = create_invoice_bl_match_session_service(db_session, certified_payload, user="Eng. Ahmed Sorour")
    assert cert_session.is_draft is False
    assert cert_session.overall_status == "FULLY_MATCHED"

    # 6. Verify reflection in CustomsDocumentApproval
    db_session.refresh(inv_approval)
    db_session.refresh(bl_approval)
    assert inv_approval.commercial_status == "Approved"
    assert inv_approval.document_reference_no == "INV-2026-999"
    assert "STEP_08_MATCH" in inv_approval.commercial_notes
    assert bl_approval.commercial_status == "Approved"
    assert bl_approval.document_reference_no == "MEDU1234567"

    # 7. Verify reflection in ImportFile
    db_session.refresh(file)
    assert file.pi_number == "INV-2026-999"
    assert file.bl_number == "MEDU1234567"


def test_docs_customs_approval_session_lifecycle(db_session):
    # Setup ImportFile
    file = ImportFile(
        custom_file_number="IMP-2026-TEST-APPR",
        import_file_code="IMP-APPR-01",
        company_name="Test Importer LLC",
        supplier_name="Global Supplier Inc.",
        progress_percent=55.0,
        is_active=True,
    )
    db_session.add(file)
    db_session.commit()
    db_session.refresh(file)


    # 1. Draft Session
    draft_payload = DocsCustomsApprovalSessionCreate(
        import_file_id=file.import_file_id,
        overall_status="DRAFT",
        is_draft=True,
        final_invoice_ref="INV-FINAL-101",
        final_invoice_status="Approved",
        draft_bl_ref="BL-DRAFT-777",
        draft_bl_status="Approved",
        notes="Draft review by customs broker",
    )
    draft_res = create_customs_approval_session_service(db_session, draft_payload)
    assert draft_res.session_id is not None
    assert draft_res.session_code.startswith("DOCAPPR-")
    assert draft_res.is_draft is True

    # 2. List sessions
    sessions = list_customs_approval_sessions_service(db_session, import_file_id=file.import_file_id)
    assert len(sessions) == 1

    # 3. Final Certification Session
    # DCA-04 (phase-03b plan, Q3): a final certification must set all five document statuses explicitly
    # (final_invoice / final_pl / draft_bl / coo / coc); the schema defaults are not accepted on a final save,
    # otherwise an empty payload would advance STEP_09 -> STEP_10. Omitting one gives 400 DCA_SESSION_NOT_READY.
    final_payload = DocsCustomsApprovalSessionCreate(
        import_file_id=file.import_file_id,
        overall_status="APPROVED",
        is_draft=False,
        final_invoice_ref="INV-FINAL-101",
        final_invoice_status="Approved",
        final_pl_status="Approved",
        draft_bl_ref="BL-DRAFT-777",
        draft_bl_status="Approved",
        coo_ref="COO-CERT-01",
        coo_status="Approved",
        coc_status="Approved",
        commercial_signoff_by="Commercial Manager",
        customs_signoff_by="Customs Broker",
        customs_broker_name="Al-Amal Customs Clearance",
        notes="All documents certified for customs clearance",
    )
    for i, dt in enumerate(["Commercial Invoice", "Packing List", "Bill of Lading", "Certificate of Origin", "Inspection Certificate"], start=1):
        db_session.add(CustomsDocumentApproval(
            approval_code=f"CDA-IBL-{file.import_file_id}-{i}",
            import_file_id=file.import_file_id,
            document_type=dt,
            overall_status="Approved for Clearance",
            is_active=True,
        ))
    db_session.commit()
    final_res = create_customs_approval_session_service(db_session, final_payload)
    assert final_res.is_draft is False

    assert final_res.overall_status == "APPROVED"

    # Verify ImportFile progression
    db_session.refresh(file)
    assert file.progress_percent >= 60.0
    assert "STEP_10" in file.current_module


def test_invoice_bl_match_session_api_endpoints(db_session):
    from fastapi.testclient import TestClient
    from main import app
    from database.database import get_db

    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    file = ImportFile(
        custom_file_number="IMP-2026-API-TEST",
        import_file_code="IMP-API-01",
        company_name="Test Importer LLC",
        supplier_name="Global Supplier Inc.",
        progress_percent=50.0,
        is_active=True,
    )
    db_session.add(file)
    db_session.commit()
    db_session.refresh(file)

    # 1. POST invoice-bl session
    res = client.post(
        "/api/v1/import-documentation/invoice-bl/sessions",
        json={
            "import_file_id": file.import_file_id,
            "invoice_number": "INV-API-99",
            "bl_number": "MEDU999888",
            "match_score_percentage": 98.0,
            "overall_status": "FULLY_MATCHED",
            "is_draft": True,
        },
    )
    assert res.status_code == 201
    data = res.json()
    assert data["session_code"].startswith("MATCH-")
    session_id = data["session_id"]

    # 2. GET invoice-bl sessions list
    res_list = client.get(f"/api/v1/import-documentation/invoice-bl/sessions?import_file_id={file.import_file_id}")
    assert res_list.status_code == 200
    assert len(res_list.json()) == 1

    # 3. GET single session
    res_single = client.get(f"/api/v1/import-documentation/invoice-bl/sessions/{session_id}")
    assert res_single.status_code == 200
    assert res_single.json()["session_id"] == session_id

    # 4. POST docs-customs-approval session
    res_appr = client.post(
        "/api/v1/docs-customs-approval/sessions",
        json={
            "import_file_id": file.import_file_id,
            "overall_status": "DRAFT",
            "is_draft": True,
            "final_invoice_ref": "INV-API-99",
        },
    )
    assert res_appr.status_code == 201
    appr_data = res_appr.json()
    assert appr_data["session_code"].startswith("DOCAPPR-")

    # 5. GET docs-customs-approval sessions list
    res_appr_list = client.get(f"/api/v1/docs-customs-approval/sessions?import_file_id={file.import_file_id}")
    assert res_appr_list.status_code == 200
    assert len(res_appr_list.json()) == 1

    app.dependency_overrides.clear()

