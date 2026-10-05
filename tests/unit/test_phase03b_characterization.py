"""
Phase 3b characterization tests (docs/plans/phase-03b-quality-plan.md section 3).

Pin the behaviour that the 03b fixes must keep identical (section 2): ODC counters, status ladder and
FULLY_VERIFIED orchestration, courier alert levels, the DCA two-tier review rules and DC-04 document rows,
the SDU upload guards, the parse response shape and the cross-checker output. Written green on the
pre-fix code; a test that changes on purpose says why.
"""

from datetime import date, timedelta

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base, get_db
from main import app
from modules.common.clock import cairo_today
from modules.docs_customs_approval.model import CustomsDocumentApproval, DiscrepancyRectificationTicket
from modules.docs_customs_approval.schemas import (
    CommercialReviewPayload,
    CustomsBrokerReviewPayload,
    CustomsDocumentApprovalCreate,
)
import modules.docs_customs_approval.service as dca_service
from modules.import_files.model import ImportFile
from modules.lifecycle_board.model import ShipmentStageActivity
from modules.original_documents_collection.schemas import (
    CourierEntry,
    OriginalDocumentItem,
    OriginalDocumentsCollectionCreate,
)
from modules.original_documents_collection.service import OriginalDocumentsCollectionService as ODC
from modules.smart_document_upload.cross_checker import cross_check_invoice_vs_bl
from modules.smart_document_upload.validators import MAX_FILE_SIZE_BYTES, validate_file_size
from modules.smart_tasks.model import SmartTask


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(autocommit=False, autoflush=False, bind=engine)()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


@pytest.fixture
def client(db):
    def override_get_db():
        yield db

    app.dependency_overrides[get_db] = override_get_db
    try:
        yield TestClient(app)
    finally:
        app.dependency_overrides.pop(get_db, None)


@pytest.fixture
def import_file(db):
    f = ImportFile(
        import_file_code="IMP-2026-3B01",
        custom_file_number="FILE-3B01",
        company_name="Char Importer",
        supplier_name="Char Supplier",
        acid_number="1234567890123456789",
        progress_percent=40.0,
        is_active=True,
    )
    db.add(f)
    db.commit()
    db.refresh(f)
    return f


def _doc(name: str, received: bool = False, verified: bool = False, courier: str = None) -> OriginalDocumentItem:
    return OriginalDocumentItem(
        document_name=name,
        courier_no=courier,
        is_received=received,
        received_date="2026-09-18" if received else None,
        is_verified=verified,
        verified_by="Verifier" if verified else None,
        status="Verified" if verified else ("Received" if received else "Pending"),
    )


def _payload(f: ImportFile, docs, couriers=None, status: str = "DRAFT") -> OriginalDocumentsCollectionCreate:
    return OriginalDocumentsCollectionCreate(
        import_file_id=f.import_file_id,
        import_file_code=f.import_file_code,
        status=status,
        couriers_list=couriers or [],
        documents_list=docs,
    )


# ── 1. ODC counters, status ladder and FULLY_VERIFIED orchestration ──────────────

def test_odc_partial_receipt_counters(db, import_file):
    res = ODC.save_or_upsert_collection_session(
        db,
        _payload(import_file, [_doc("Commercial Invoice", True, True), _doc("Packing List", True), _doc("B/L")]),
        username="char",
    )
    assert res.status == "PARTIALLY_RECEIVED"
    assert res.total_documents_count == 3
    assert res.received_documents_count == 2
    assert res.verified_documents_count == 1
    assert res.pending_documents_count == 1
    assert res.completion_percentage == 33.3


def test_odc_fully_verified_orchestration(db, import_file):
    docs = [_doc(n, True, True) for n in ("Commercial Invoice", "Packing List", "B/L")]
    res = ODC.save_or_upsert_collection_session(db, _payload(import_file, docs), username="char")
    assert res.status == "FULLY_VERIFIED"
    assert res.completion_percentage == 100.0

    db.refresh(import_file)
    assert import_file.original_documents_status == "FULLY_VERIFIED"
    assert import_file.original_documents_session_code == res.collection_code
    assert import_file.original_documents_received_at is not None
    assert import_file.progress_percent >= 75.0
    assert import_file.next_action_code == "NA_CS01_ASSIGN_BROKER"

    step12 = db.query(ShipmentStageActivity).filter_by(
        import_file_code=import_file.import_file_code, step_code="STEP_12"
    ).one()
    assert step12.status == "In-Progress"
    step11 = db.query(ShipmentStageActivity).filter_by(
        import_file_code=import_file.import_file_code, step_code="STEP_11"
    ).one()
    assert step11.status == "Completed"

    # Saving again keeps a single CS-01 task (created once).
    ODC.save_or_upsert_collection_session(db, _payload(import_file, docs), username="char")
    cs01 = db.query(SmartTask).filter_by(
        import_file_id=import_file.import_file_id, task_type="CUSTOMS_BROKER_ASSIGNMENT"
    ).all()
    assert len(cs01) == 1
    assert cs01[0].msg_code == "ODC_TASK_ASSIGN_BROKER"


# ── 2. Courier alerts ───────────────────────────────────────────────────────────

def test_courier_alert_levels_and_sort(db, import_file):
    today = cairo_today()
    couriers = [
        CourierEntry(courier_no="INFO-1", courier_company="Aramex", dispatch_date=str(today - timedelta(days=1))),
        CourierEntry(courier_no="WARN-3", courier_company="FedEx", dispatch_date=str(today - timedelta(days=3))),
        CourierEntry(courier_no="CRIT-5", courier_company="DHL", dispatch_date=str(today - timedelta(days=5))),
    ]
    ODC.save_or_upsert_collection_session(db, _payload(import_file, [], couriers))
    res = ODC.get_courier_alerts(db)
    assert [a.courier_no for a in res.alerts] == ["CRIT-5", "WARN-3", "INFO-1"]
    assert [a.alert_level for a in res.alerts] == ["CRITICAL", "WARNING", "INFO"]
    assert res.delayed_count == 2
    assert res.pending_receipt_count == 3


def test_flat_courier_status_threshold(db, import_file):
    # Pinned pre-fix value was DELAYED at 4 days. Q4 (safe default) moves the flat DELAYED threshold to the
    # alert SLA (5 days) so both views agree: 4 days is now IN_TRANSIT, 5 days DELAYED.
    today = cairo_today()
    couriers = [
        CourierEntry(courier_no="D4", courier_company="DHL", dispatch_date=str(today - timedelta(days=4))),
        CourierEntry(courier_no="D5", courier_company="DHL", dispatch_date=str(today - timedelta(days=5))),
        CourierEntry(courier_no="D0", courier_company="DHL", dispatch_date=str(today)),
    ]
    ODC.save_or_upsert_collection_session(db, _payload(import_file, [], couriers))
    by_no = {c.courier_no: c for c in ODC.get_all_couriers_flat(db)}
    assert by_no["D4"].status == "IN_TRANSIT"
    assert by_no["D5"].status == "DELAYED"
    assert by_no["D0"].status == "DISPATCHED"


# ── 3. DCA dual review ──────────────────────────────────────────────────────────

def _approval(db, f, doc_type="Bill of Lading"):
    return dca_service.create_approval_service(
        db, CustomsDocumentApprovalCreate(import_file_id=f.import_file_id, document_type=doc_type)
    )


def test_dca_dual_review_approved_for_clearance(db, import_file):
    a = _approval(db, import_file)
    dca_service.submit_commercial_review_service(
        db, a.approval_id, CommercialReviewPayload(reviewer_name="x", status="Approved")
    )
    res = dca_service.submit_customs_broker_review_service(
        db, a.approval_id, CustomsBrokerReviewPayload(broker_name="B", reviewer_name="y", status="Approved")
    )
    assert res.overall_status == "Approved for Clearance"


def test_dca_customs_rejection_requires_rectification(db, import_file):
    a = _approval(db, import_file)
    dca_service.submit_commercial_review_service(
        db, a.approval_id, CommercialReviewPayload(reviewer_name="x", status="Approved")
    )
    res = dca_service.submit_customs_broker_review_service(
        db, a.approval_id, CustomsBrokerReviewPayload(broker_name="B", reviewer_name="y", status="Rejected")
    )
    assert res.overall_status == "Rectification Required"


# ── 4. DCA matrix DC-04 rows ────────────────────────────────────────────────────

def _add_approval(db, f, doc_type, commercial, customs, overall, code):
    db.add(CustomsDocumentApproval(
        approval_code=code, import_file_id=f.import_file_id, document_type=doc_type,
        commercial_status=commercial, customs_status=customs, overall_status=overall,
    ))
    db.commit()


def test_dca_matrix_document_rows(db, import_file):
    import_file.form4_no = "F4-123"
    db.commit()
    _add_approval(db, import_file, "Commercial Invoice", "Approved", "Approved", "Approved for Clearance", "C-1")
    _add_approval(db, import_file, "Packing List", "Rejected", "Pending", "Rectification Required", "C-2")
    res = dca_service.run_cross_document_matrix_check_service(db, import_file.import_file_id)
    rows = {c.parameter: c for c in res.checks}
    assert rows["Commercial Invoice Verification"].status == "Match"
    assert rows["Packing List Verification"].status == "Mismatch"
    assert rows["Bank Form 4 / LC Verification"].status == "Match"
    assert rows["Bank Form 4 / LC Verification"].invoice_val == "F4-123"
    assert rows["Fumigation Certificate (ISPM 15)"].status == "Missing"
    # 2 of 7 mandatory documents approved (invoice + Form 4 fallback)
    assert res.completeness_percent == round(2 / 7 * 100, 1)
    assert res.overall_compliance == "Critical Blocker"


def test_dca_matrix_open_ticket_is_critical_blocker(db, import_file):
    db.add(DiscrepancyRectificationTicket(
        ticket_code="T-1", import_file_id=import_file.import_file_id, issue_category="Other",
        description="Open ticket", status="Open",
    ))
    db.commit()
    res = dca_service.run_cross_document_matrix_check_service(db, import_file.import_file_id)
    assert res.open_tickets_count == 1
    assert res.overall_compliance == "Critical Blocker"


# ── 5. SDU guards, parse shape, cross-checker ───────────────────────────────────

def test_sdu_magic_bytes_rejection():
    with pytest.raises(HTTPException) as exe:
        validate_file_size(b"MZ\x90\x00rest", "invoice.txt")
    assert exe.value.status_code == 415
    with pytest.raises(HTTPException) as pdf:
        validate_file_size(b"not a pdf", "invoice.pdf")
    assert pdf.value.status_code == 415


def test_sdu_size_limit():
    with pytest.raises(HTTPException) as big:
        validate_file_size(b"%PDF-" + b"x" * MAX_FILE_SIZE_BYTES, "big.pdf")
    assert big.value.status_code == 413


def test_sdu_parse_text_file_response_shape(client):
    text = b"COMMERCIAL INVOICE\nInvoice No: INV-3B-1\nTotal Amount: 1,000.00 USD\nIncoterms: FOB\n"
    r = client.post(
        "/api/v1/smart-upload/parse/import-file",
        files={"file": ("inv.txt", text, "text/plain")},
        data={"save_session": "false"},
    )
    assert r.status_code == 200
    body = r.json()
    for key in (
        "session_id", "session_ref", "module_name", "filename", "file_type", "file_size_bytes",
        "extraction_status", "confidence_score", "extracted_fields", "missing_fields", "extraction_notes",
        "raw_text_preview", "supplier_verified", "importer_verified",
    ):
        assert key in body
    assert body["module_name"] == "import-file"
    assert body["file_type"] == "text"
    assert body["file_size_bytes"] == len(text)
    assert body["extraction_status"] in ("SUCCESS", "PARTIAL", "FAILED")
    assert body["raw_text_preview"].startswith("COMMERCIAL INVOICE")


def test_cross_checker_acid_mismatch_golden():
    res = cross_check_invoice_vs_bl(
        {"acid_number": "1111111111111111111"}, {"acid_number": "2222222222222222222"}
    )
    acid = next(m for m in res["audit_matrix"] if m["check_code"] == "CHK_ACID")
    assert acid["status"] == "CRITICAL"
    assert acid["severity"] == "BLOCKING"
    assert res["critical_errors"][0] == "عدم تطابق رقم القيد الجمركي المسبق (ACID) بين الفاتورة والبوليصة"
    assert res["verdict"] == "CRITICAL_MISMATCH"
    assert len(res["audit_matrix"]) == 10


def test_cross_checker_weight_at_tolerance_edge():
    res = cross_check_invoice_vs_bl(
        {"total_gross_weight_kg": 1000}, {"total_gross_weight_kg": 1030}, weight_tolerance_pct=3.0
    )
    w = next(m for m in res["audit_matrix"] if m["check_code"] == "CHK_GROSS_WEIGHT")
    assert w["status"] == "WARNING"
    assert w["variance_percentage"] == 3.0
    assert w["variance_kg"] == 30.0
    assert "فرق وزن طفيف 30.0 كجم (3.0%) ضمن حدود التفاوت المقبولة" in res["warnings"]

    over = cross_check_invoice_vs_bl(
        {"total_gross_weight_kg": 1000}, {"total_gross_weight_kg": 1031}, weight_tolerance_pct=3.0
    )
    w2 = next(m for m in over["audit_matrix"] if m["check_code"] == "CHK_GROSS_WEIGHT")
    assert w2["status"] == "CRITICAL"
