"""
Phase 3b regression tests (docs/plans/phase-03b-quality-plan.md): one or more tests per fixed finding.
Strict auth (no dev bypass) with seeded RBAC roles and bearer tokens.
"""

import importlib
from datetime import date

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import modules.auth.permissions as auth_permissions
from database.database import Base, get_db
from modules.auth.permissions import invalidate_permission_cache
from modules.auth.security import create_access_token, hash_password
from modules.auth.seed_rbac import seed_rbac
from modules.cargo_shipping.model import CargoShippingRecord
from modules.customs_tariff.model import CustomsTariff
from modules.docs_customs_approval.model import (
    CustomsDocumentApproval,
    DiscrepancyRectificationTicket,
    DocsCustomsApprovalSession,
)
from modules.docs_customs_approval.schemas import DocsCustomsApprovalSessionCreate
import modules.docs_customs_approval.service as dca_service
from modules.import_documentation.model import AcidRegistrationSession
from modules.import_files.model import ImportFile
from modules.incoterms.model import Incoterm
from modules.notifications.model import SystemNotification
from modules.original_documents_collection.schemas import (
    CourierEntry,
    OriginalDocumentItem,
    OriginalDocumentsCollectionCreate,
)
from modules.original_documents_collection.service import OriginalDocumentsCollectionService as ODC
from modules.purchase_orders.model import POLineItem, PurchaseOrder
from modules.smart_document_upload.model import UploadSession
import modules.smart_document_upload.repository as sdu_repo
from modules.smart_tasks.model import SmartTask
from modules.users.model import Role, User

ODC_ROUTER = importlib.import_module("modules.original_documents_collection.router")
DCA_ROUTER = importlib.import_module("modules.docs_customs_approval.router")
SDU_ROUTER = importlib.import_module("modules.smart_document_upload.router")

ACID = "1234567890123456789"


@pytest.fixture
def factory():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    invalidate_permission_cache()
    yield sessionmaker(bind=engine, autoflush=False)
    invalidate_permission_cache()
    engine.dispose()


@pytest.fixture
def db(factory):
    s = factory()
    seed_rbac(s)
    yield s
    s.close()


def _user(db, username, role_code):
    role = db.query(Role).filter(Role.role_code == role_code).one()
    u = User(username=username, email=f"{username}@t.com", full_name=username, hashed_password=hash_password("Password123"),
             role=role.role_code, role_id=role.role_id, is_active=True)
    db.add(u)
    db.commit()
    db.refresh(u)
    return u


@pytest.fixture
def operator(db):
    return _user(db, "op3b", "LOGISTICS_OPERATOR")


@pytest.fixture
def viewer(db):
    return _user(db, "viewer3b", "AUDITOR_VIEWER")


@pytest.fixture
def customs_officer(db):
    return _user(db, "broker3b", "CUSTOMS_OFFICER")


@pytest.fixture
def admin(db):
    return _user(db, "admin3b", "ADMIN")


def _h(u):
    return {"Authorization": f"Bearer {create_access_token({'sub': str(u.user_id), 'role': u.role})}"}


@pytest.fixture
def client(factory, monkeypatch):
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)
    app = FastAPI()
    for m in (ODC_ROUTER, DCA_ROUTER, SDU_ROUTER):
        app.include_router(m.router)

    def override():
        s = factory()
        try:
            yield s
        finally:
            s.close()

    app.dependency_overrides[get_db] = override
    return TestClient(app, raise_server_exceptions=False)


@pytest.fixture
def imp(db):
    f = ImportFile(import_file_code="IMP-2026-RG01", custom_file_number="RG01", company_name="Imp Co",
                   supplier_name="Sup Co", acid_number=ACID, is_active=True, progress_percent=40.0)
    db.add(f)
    db.commit()
    db.refresh(f)
    return f


def _odc_payload(f, docs, couriers=None, status="DRAFT"):
    return OriginalDocumentsCollectionCreate(import_file_id=f.import_file_id, import_file_code=f.import_file_code,
                                             status=status, couriers_list=couriers or [], documents_list=docs)


def _doc(name, received=False, verified=False, courier=None):
    return OriginalDocumentItem(document_name=name, courier_no=courier, is_received=received, is_verified=verified,
                                status="Verified" if verified else ("Received" if received else "Pending"))


# ── Permissions (DCA-02, ODC-01, SDU-01) ──────────────────────────────────────

VIEWER_FORBIDDEN = [
    ("post", "/api/v1/original-documents-collection/sessions"),
    ("post", "/api/v1/original-documents-collection/couriers/confirm-receipt"),
    ("post", "/api/v1/docs-customs-approval"),
    ("post", "/api/v1/docs-customs-approval/auto-generate/1"),
    ("post", "/api/v1/docs-customs-approval/matrix-check/1"),
    ("post", "/api/v1/docs-customs-approval/tickets"),
    ("put", "/api/v1/docs-customs-approval/tickets/1"),
    ("post", "/api/v1/docs-customs-approval/tickets/1/resolve"),
    ("post", "/api/v1/docs-customs-approval/sessions"),
    ("put", "/api/v1/docs-customs-approval/1"),
    ("post", "/api/v1/docs-customs-approval/1/commercial-review"),
    ("post", "/api/v1/docs-customs-approval/1/customs-review"),
    ("delete", "/api/v1/docs-customs-approval/1"),
    ("post", "/api/v1/smart-upload/apply/commercial-invoice"),
    ("post", "/api/v1/smart-upload/apply/bill-of-lading"),
    ("delete", "/api/v1/smart-upload/sessions/1"),
]


@pytest.mark.parametrize("method,path", VIEWER_FORBIDDEN)
def test_viewer_gets_403_on_mutating_routes(client, viewer, method, path):
    kwargs = {} if method == "delete" else {"json": {}}
    r = getattr(client, method)(path, headers=_h(viewer), **kwargs)
    assert r.status_code == 403


def test_viewer_can_read(client, viewer, imp):
    assert client.get("/api/v1/original-documents-collection/couriers/alerts", headers=_h(viewer)).status_code == 200
    assert client.get("/api/v1/docs-customs-approval/sessions", headers=_h(viewer)).status_code == 200


def test_customs_review_needs_customs_permission(client, operator, db, imp):
    a = dca_service.create_approval_service(db, dca_service.CustomsDocumentApprovalCreate(
        import_file_id=imp.import_file_id, document_type="Bill of Lading"))
    r = client.post(f"/api/v1/docs-customs-approval/{a.approval_id}/customs-review", headers=_h(operator),
                    json={"broker_name": "B", "status": "Approved"})
    assert r.status_code == 403  # LOGISTICS_OPERATOR lacks customs_clearance.update


# ── DCA-01 matrix ─────────────────────────────────────────────────────────────

def test_matrix_without_sources_is_not_checked(db, imp):
    res = dca_service.run_cross_document_matrix_check_service(db, imp.import_file_id)
    rows = {c.parameter: c.status for c in res.checks}
    for p in ("HS Code Classification", "Total Value & Currency", "Gross Weight (KG)", "Total Volume (CBM)"):
        assert rows[p] == "Not Checked"
    assert res.not_checked_checks >= 4
    assert res.overall_compliance != "Fully Compliant"
    # no fake demo values
    assert all("14,250" not in (c.packing_val or "") and "Shanghai" not in (c.invoice_val or "") for c in res.checks)


def test_matrix_invalid_acid_is_mismatch(db, imp):
    imp.acid_number = "12345"
    db.commit()
    res = dca_service.run_cross_document_matrix_check_service(db, imp.import_file_id)
    acid = next(c for c in res.checks if "ACID" in c.parameter)
    assert acid.status == "Mismatch"
    assert res.overall_compliance == "Critical Blocker"


def _full_sources(db, f):
    db.add(Incoterm(incoterm_id=1, incoterm_code="FOB", incoterm_name="Free On Board"))
    db.add(CustomsTariff(tariff_id=1, hs_code="8415.10", hs_description="Air conditioners"))
    db.flush()
    po = PurchaseOrder(po_id=1, po_number="PO-2026-RG1", project_id=1, company_id=1, supplier_id=1, incoterm_id=1,
                       currency_id=1, total_amount_fob=1000.0, total_gross_weight_kg=500.0, total_cbm=10.0, is_active=True)
    db.add(po)
    db.flush()
    db.add(POLineItem(po_id=1, description_ar="صنف", quantity=1, unit_price=1000, total_price=1000, tariff_id=1))
    f.po_number = "PO-2026-RG1"
    f.incoterm_code = "FOB"
    f.port_of_loading = "Shanghai Port"
    f.port_of_discharge = "Alexandria Port"
    f.invoices_data = [{"invoice_no": "I1", "amount": 1000.0}]
    f.packing_lists_data = [{"pl_no": "P1", "gross_weight_kg": 505.0, "cbm": 10.1}]
    db.add(AcidRegistrationSession(
        acid_code="ACID-RG", acid_number=ACID, import_file_id=f.import_file_id, importer_name="I", importer_tax_id="1",
        exporter_name="E", exporter_reg_id="X", exporter_country="CN", proforma_invoice_no="PI", pol_name="Shanghai",
        pod_name="Alexandria", expiry_date=date(2028, 1, 1), generated_data={"hs_code": "841510"}, is_active=True))
    for i, t in enumerate(["Commercial Invoice", "Packing List", "Bill of Lading", "Certificate of Origin",
                           "Inspection Certificate", "Fumigation Certificate", "Bank Form 4"]):
        db.add(CustomsDocumentApproval(approval_code=f"CDA-RG-{i}", import_file_id=f.import_file_id, document_type=t,
                                       commercial_status="Approved", customs_status="Approved",
                                       overall_status="Approved for Clearance"))
    db.commit()


def test_matrix_real_sources_fully_compliant(db, imp):
    _full_sources(db, imp)
    res = dca_service.run_cross_document_matrix_check_service(db, imp.import_file_id)
    assert {c.parameter: c.status for c in res.checks if c.status != "Match"} == {}
    assert res.overall_compliance == "Fully Compliant"
    assert res.not_checked_checks == 0


def test_matrix_weight_difference_is_warning(db, imp):
    _full_sources(db, imp)
    imp.packing_lists_data = [{"pl_no": "P1", "gross_weight_kg": 600.0, "cbm": 10.0}]
    db.commit()
    res = dca_service.run_cross_document_matrix_check_service(db, imp.import_file_id)
    assert next(c for c in res.checks if c.parameter == "Gross Weight (KG)").status == "Warning"
    assert res.overall_compliance == "Discrepancies Found"


# ── DCA-03 statuses and signers ───────────────────────────────────────────────

def test_put_ignores_statuses_and_review_uses_token_user(client, admin, db, imp):
    a = dca_service.create_approval_service(db, dca_service.CustomsDocumentApprovalCreate(
        import_file_id=imp.import_file_id, document_type="Bill of Lading"))
    r = client.put(f"/api/v1/docs-customs-approval/{a.approval_id}", headers=_h(admin),
                   json={"overall_status": "Approved for Clearance", "commercial_status": "Approved",
                         "customs_status": "Approved", "document_reference_no": "BL-9"})
    assert r.status_code == 200
    body = r.json()
    assert body["overall_status"] == "Draft"
    assert body["commercial_status"] == "Pending"
    assert body["document_reference_no"] == "BL-9"

    r = client.post(f"/api/v1/docs-customs-approval/{a.approval_id}/commercial-review", headers=_h(admin),
                    json={"reviewer_name": "someone else", "status": "APPROVED"})
    assert r.status_code == 200
    assert r.json()["commercial_reviewed_by"] == admin.username
    assert r.json()["commercial_status"] == "Approved"


def test_review_unknown_status_is_422(db, imp):
    a = dca_service.create_approval_service(db, dca_service.CustomsDocumentApprovalCreate(
        import_file_id=imp.import_file_id, document_type="Bill of Lading"))
    with pytest.raises(HTTPException) as e:
        dca_service.submit_commercial_review_service(
            db, a.approval_id, dca_service.CommercialReviewPayload(status="Totally fine"), current_user_name="u")
    assert e.value.status_code == 422


# ── DCA-04 sessions ───────────────────────────────────────────────────────────

FIVE = dict(final_invoice_status="Approved", final_pl_status="Approved", draft_bl_status="Approved",
            coo_status="Approved", coc_status="Waived / Not Required")


def test_empty_final_session_is_400(db, imp):
    with pytest.raises(HTTPException) as e:
        dca_service.create_customs_approval_session_service(
            db, DocsCustomsApprovalSessionCreate(import_file_id=imp.import_file_id, is_draft=False))
    assert e.value.status_code == 400
    assert e.value.detail["code"] == "DCA_SESSION_NOT_READY"
    assert len(e.value.detail["missing_statuses"]) == 5


def test_open_ticket_blocks_final(db, imp):
    db.add(DiscrepancyRectificationTicket(ticket_code="T-1", import_file_id=imp.import_file_id,
                                          issue_category="Other", description="xxxxxx", status="Open"))
    db.commit()
    with pytest.raises(HTTPException) as e:
        dca_service.create_customs_approval_session_service(
            db, DocsCustomsApprovalSessionCreate(import_file_id=imp.import_file_id, is_draft=False, **FIVE))
    assert e.value.detail["open_tickets_count"] == 1


def test_final_session_locked_and_signed_by_user(db, imp, customs_officer):
    res = dca_service.create_customs_approval_session_service(
        db, DocsCustomsApprovalSessionCreate(import_file_id=imp.import_file_id, is_draft=False,
                                             customs_signoff_by="spoof", created_by="spoof", **FIVE),
        current_user=customs_officer)
    assert res.customs_signoff_by == customs_officer.username
    assert res.created_by == customs_officer.username
    db.refresh(imp)
    assert "STEP_10" in imp.current_module
    for draft in (True, False):
        with pytest.raises(HTTPException) as e:
            dca_service.create_customs_approval_session_service(
                db, DocsCustomsApprovalSessionCreate(import_file_id=imp.import_file_id, is_draft=draft, **FIVE),
                current_user=customs_officer)
        assert e.value.status_code == 409
        assert e.value.detail["code"] == "DCA_SESSION_FINAL_LOCKED"
    assert db.query(DocsCustomsApprovalSession).count() == 1


def test_final_session_failure_before_lifecycle_rolls_back(db, imp, customs_officer, monkeypatch):
    """BE03-T17: Failure before lifecycle call leaves session uncertified and lifecycle not advanced."""
    def fail_tracking(*args, **kwargs):
        raise RuntimeError("simulated set_file_tracking failure")

    monkeypatch.setattr(dca_service, "set_file_tracking", fail_tracking)

    with pytest.raises(RuntimeError, match="simulated set_file_tracking failure"):
        dca_service.create_customs_approval_session_service(
            db, DocsCustomsApprovalSessionCreate(import_file_id=imp.import_file_id, is_draft=False,
                                                 customs_signoff_by="spoof", created_by="spoof", **FIVE),
            current_user=customs_officer)

    db.rollback()
    assert db.query(DocsCustomsApprovalSession).filter_by(import_file_id=imp.import_file_id).count() == 0
    db.refresh(imp)
    assert "STEP_10" not in (imp.current_module or "")


def test_soft_delete_and_restore_transaction_hygiene(db, imp):
    """BE03-T17: repo flushes only; rollback undoes soft delete or restore."""
    from modules.import_documentation.repository import soft_delete_acid_session, restore_acid_session
    from modules.import_documentation.model import AcidRegistrationSession

    acid = AcidRegistrationSession(
        acid_code="ACID-2026-999",
        acid_number="1234567890123456789",
        importer_name="Imp",
        importer_tax_id="123",
        exporter_name="Exp",
        exporter_reg_id="EXP-1",
        exporter_country="US",
        proforma_invoice_no="PI-1",
        pol_name="POL",
        pod_name="POD",
        expiry_date=date(2026, 12, 31),
        is_active=True,
    )
    db.add(acid)
    db.commit()
    db.refresh(acid)

    # 1. soft_delete flushes; rollback reverts it
    ok = soft_delete_acid_session(db, acid.acid_id)
    assert ok is True
    assert acid.is_active is False
    db.rollback()
    db.refresh(acid)
    assert acid.is_active is True

    # 2. soft delete and commit
    ok = soft_delete_acid_session(db, acid.acid_id)
    assert ok is True
    db.commit()
    db.refresh(acid)
    assert acid.is_active is False

    # 3. restore_acid_session flushes; rollback reverts it
    restored = restore_acid_session(db, acid.acid_id)
    assert restored is not None
    assert restored.is_active is True
    db.rollback()
    db.refresh(acid)
    assert acid.is_active is False


def test_final_session_needs_customs_permission(client, operator, imp):
    r = client.post("/api/v1/docs-customs-approval/sessions", headers=_h(operator),
                    json={"import_file_id": imp.import_file_id, "is_draft": False, **FIVE})
    assert r.status_code == 403
    r = client.post("/api/v1/docs-customs-approval/sessions", headers=_h(operator),
                    json={"import_file_id": imp.import_file_id, "is_draft": True})
    assert r.status_code == 201


# ── DCA-05 / DCA-07 codes and tickets ─────────────────────────────────────────

def test_codes_follow_year_and_skip_gaps(db, imp):
    year = date.today().year
    db.add(CustomsDocumentApproval(approval_code=f"CDA-{year}-0007", import_file_id=imp.import_file_id,
                                   document_type="EUR.1"))
    db.commit()
    a = dca_service.create_approval_service(db, dca_service.CustomsDocumentApprovalCreate(
        import_file_id=imp.import_file_id, document_type="Packing List"))
    assert a.approval_code == f"CDA-{year}-0008"


def test_ticket_rules(db, imp):
    other = ImportFile(import_file_code="IMP-OTHER", company_name="c", supplier_name="s", is_active=True)
    db.add(other)
    db.commit()
    a = dca_service.create_approval_service(db, dca_service.CustomsDocumentApprovalCreate(
        import_file_id=other.import_file_id, document_type="Packing List"))
    with pytest.raises(HTTPException) as e:
        dca_service.create_rectification_ticket_service(db, dca_service.DiscrepancyTicketCreate(
            import_file_id=imp.import_file_id, approval_id=a.approval_id, issue_category="Other",
            description="wrong file link"))
    assert e.value.status_code == 400
    with pytest.raises(HTTPException) as e:
        dca_service.create_rectification_ticket_service(db, dca_service.DiscrepancyTicketCreate(
            import_file_id=imp.import_file_id, issue_category="Other", severity="Huge", description="bad severity"))
    assert e.value.status_code == 422
    t = dca_service.create_rectification_ticket_service(db, dca_service.DiscrepancyTicketCreate(
        import_file_id=imp.import_file_id, issue_category="Other", severity="critical", description="valid one"))
    assert t.severity == "Critical"
    resolved = dca_service.resolve_rectification_ticket_service(
        db, t.ticket_id, dca_service.DiscrepancyTicketResolve(supplier_response="ok", resolved_by="spoof"),
        current_user_name="real-user")
    assert resolved.resolved_by == "real-user"
    with pytest.raises(HTTPException) as e:
        dca_service.resolve_rectification_ticket_service(
            db, t.ticket_id, dca_service.DiscrepancyTicketResolve(supplier_response="again"), current_user_name="u")
    assert e.value.status_code == 409
    assert e.value.detail["code"] == "DCA_TICKET_CLOSED"


# ── ODC-02 / 03 / 05 / 07 / 08 / 10 ──────────────────────────────────────────

def _odc_approval(db, f):
    return db.query(CustomsDocumentApproval).filter_by(import_file_id=f.import_file_id,
                                                       document_type="ORIGINAL_DOCUMENTS").first()


def test_fully_received_does_not_approve_dca(db, imp):
    ODC.save_or_upsert_collection_session(db, _odc_payload(imp, [_doc("CI", True), _doc("PL", True)]))
    assert _odc_approval(db, imp) is None


def test_fully_verified_approves_commercial_tier_only(db, imp):
    ODC.save_or_upsert_collection_session(db, _odc_payload(imp, [_doc("CI", True, True)]), username="checker")
    a = _odc_approval(db, imp)
    assert a.commercial_status == "Approved"
    assert a.commercial_reviewed_by == "checker"
    assert a.customs_status == "Pending"
    assert a.overall_status == "Under Review"
    assert a.approval_code.startswith(f"CDA-{date.today().year}-")


def test_draft_save_leaves_sh04_task_open(db, imp):
    db.add(SmartTask(task_code="T-SH04", import_file_id=imp.import_file_id, import_file_code=imp.import_file_code,
                     title="Collect originals (SH-04)", task_type="ORIGINAL_DOCS_RECEIPT", priority="High",
                     status="Pending", assigned_user="x", due_date="2026-10-10", created_by="s"))
    db.commit()
    ODC.save_or_upsert_collection_session(db, _odc_payload(imp, [_doc("CI", True), _doc("PL")]))
    assert db.query(SmartTask).filter_by(task_code="T-SH04").one().status == "Pending"
    ODC.save_or_upsert_collection_session(db, _odc_payload(imp, [_doc("CI", True), _doc("PL", True)]),
                                          username="receiver")
    task = db.query(SmartTask).filter_by(task_code="T-SH04").one()
    assert task.status == "Completed"
    # The closing note is persisted in the real ``notes`` column (SmartTask has no completion_notes column).
    assert "DOC-COL-" in (task.notes or "")
    assert task.updated_by == "receiver"


def test_session_by_file_is_404_when_missing(client, viewer, db, imp):
    url = f"/api/v1/original-documents-collection/sessions/by-file/{imp.import_file_id}"
    r = client.get(url, headers=_h(viewer))
    assert r.status_code == 404
    assert r.json()["detail"]["code"] == "ODC_SESSION_NOT_FOUND"
    ODC.save_or_upsert_collection_session(db, _odc_payload(imp, [_doc("CI")]))
    r = client.get(url, headers=_h(viewer))
    assert r.status_code == 200
    assert r.json()["import_file_id"] == imp.import_file_id


def test_confirm_receipt_exact_awb_only(db, imp):
    couriers = [CourierEntry(courier_no="9912345", courier_company="DHL", dispatch_date="2026-09-01")]
    docs = [_doc("CI", courier="9912345"), _doc("Unassigned doc")]
    ODC.save_or_upsert_collection_session(db, _odc_payload(imp, docs, couriers))
    req = dict(import_file_id=imp.import_file_id, received_date="2026-09-05", received_by="me")
    with pytest.raises(HTTPException) as e:
        ODC.confirm_courier_receipt(db, ODC_ROUTER.CourierReceiptProofRequest(courier_no="12345", **req))
    assert e.value.status_code == 404
    assert e.value.detail["code"] == "ODC_COURIER_NOT_FOUND"
    res = ODC.confirm_courier_receipt(db, ODC_ROUTER.CourierReceiptProofRequest(courier_no=" 9912345 ", **req))
    docs_by_name = {d.document_name: d for d in res.documents_list}
    assert docs_by_name["CI"].is_received is True
    assert docs_by_name["Unassigned doc"].is_received is False
    assert res.status == "PARTIALLY_RECEIVED"
    assert len(res.couriers_list) == 1


def test_receipt_date_and_notification_set_once(db, imp):
    docs = [_doc("CI", True)]
    ODC.save_or_upsert_collection_session(db, _odc_payload(imp, docs))
    db.refresh(imp)
    first = imp.original_documents_received_at
    ODC.save_or_upsert_collection_session(db, _odc_payload(imp, docs))
    db.refresh(imp)
    assert imp.original_documents_received_at == first
    assert db.query(SystemNotification).filter_by(entity_id=imp.import_file_id,
                                                  msg_code="ODC_ORIGINALS_RECEIVED").count() == 1


def test_unknown_status_and_bad_date_are_422(db, imp):
    with pytest.raises(HTTPException) as e:
        ODC.save_or_upsert_collection_session(db, _odc_payload(imp, [_doc("CI")], status="WHATEVER"))
    assert e.value.status_code == 422
    bad_doc = _doc("CI")
    bad_doc.received_date = "21/08/2026"
    with pytest.raises(HTTPException) as e:
        ODC.save_or_upsert_collection_session(db, _odc_payload(imp, [bad_doc]))
    assert e.value.status_code == 422
    doc = _doc("CI")
    doc.status = "in transit"
    res = ODC.save_or_upsert_collection_session(db, _odc_payload(imp, [doc]))
    assert res.documents_list[0].status == "In Transit"


def test_inactive_import_file_is_404(db, imp):
    imp.is_active = False
    db.commit()
    with pytest.raises(HTTPException) as e:
        ODC.save_or_upsert_collection_session(db, _odc_payload(imp, [_doc("CI")]))
    assert e.value.status_code == 404


def test_export_by_import_file_id_and_filename(client, viewer, db, imp):
    ODC.save_or_upsert_collection_session(db, _odc_payload(imp, [_doc("CI")]))
    r = client.get(f"/api/v1/original-documents-collection/export/excel/{imp.import_file_id}", headers=_h(viewer))
    assert r.status_code == 200
    assert "Original%20Documents%20Collection%20-%20IMP-2026-RG01.xlsx" in r.headers["content-disposition"]
    assert client.get("/api/v1/original-documents-collection/export/excel/999", headers=_h(viewer)).status_code == 404


def test_google_fallback_url_is_escaped():
    url = ODC.build_carrier_tracking_url("Local & Co", "AB 12")
    assert " " not in url and "&" not in url.split("?q=")[1]


# ── SDU-01 apply ──────────────────────────────────────────────────────────────

def _incoterm(db, code="CIF"):
    db.add(Incoterm(incoterm_code=code, incoterm_name=code))
    db.commit()


def test_apply_invoice_validation(client, operator, db, imp):
    _incoterm(db)
    url = "/api/v1/smart-upload/apply/commercial-invoice"
    base = {"import_file_id": imp.import_file_id}
    r = client.post(url, headers=_h(operator), json={**base, "invoice_data": {"acid_number": "123"}})
    assert r.status_code == 400 and r.json()["detail"]["code"] == "SDU_ACID_INVALID"
    r = client.post(url, headers=_h(operator), json={**base, "invoice_data": {"acid_number": "9" * 19}})
    assert r.status_code == 409 and r.json()["detail"]["code"] == "SDU_ACID_CONFLICT"
    r = client.post(url, headers=_h(operator), json={**base, "invoice_data": {"incoterms": "XYZ"}})
    assert r.status_code == 400
    r = client.post(url, headers=_h(operator), json={**base, "invoice_data": {"invoice_value": "abc"}})
    assert r.status_code == 422
    r = client.post(url, headers=_h(operator), json={**base, "invoice_data": {"invoice_value": -5}})
    assert r.status_code == 422
    r = client.post(url, headers=_h(operator), json={**base, "invoice_data": {
        "acid_number": ACID, "incoterms": "cif", "invoice_value": 100.0, "currency": "eur", "extra_key": 1}})
    assert r.status_code == 200
    body = r.json()
    assert body["applied"] is True and body["msg_code"] == "SDU_INVOICE_APPLIED" and "message_ar" in body
    db.refresh(imp)
    assert imp.incoterm_code == "CIF" and imp.estimated_cost_currency == "EUR"


def test_apply_invoice_inactive_file_404(client, operator, db, imp):
    imp.is_active = False
    db.commit()
    r = client.post("/api/v1/smart-upload/apply/commercial-invoice", headers=_h(operator),
                    json={"import_file_id": imp.import_file_id, "invoice_data": {}})
    assert r.status_code == 404


def test_apply_bl_merges_containers(client, operator, db, imp):
    db.add(CargoShippingRecord(cargo_shipping_code="SHP-RG", import_file_id=imp.import_file_id,
                               containers_loading_data=[{"container_no": "MSCU1112223", "seal_no": "OLD",
                                                         "container_type": "20GP", "vgm_status": "Pending",
                                                         "tracking_status": "At Yard"}]))
    db.commit()
    r = client.post("/api/v1/smart-upload/apply/bill-of-lading", headers=_h(operator), json={
        "import_file_id": imp.import_file_id,
        "bl_data": {"containers": [{"container_no": "mscu1112223", "seal_no": "NEW"},
                                   {"container_no": "TGHU9998887"}]}})
    assert r.status_code == 200 and r.json()["containers_applied"] == 2
    rec = db.query(CargoShippingRecord).filter_by(cargo_shipping_code="SHP-RG").one()
    db.refresh(rec)
    by_no = {c["container_no"]: c for c in rec.containers_loading_data}
    assert by_no["MSCU1112223"]["seal_no"] == "NEW"
    assert by_no["MSCU1112223"]["vgm_status"] == "Pending"
    assert by_no["MSCU1112223"]["container_type"] == "20GP"
    assert by_no["TGHU9998887"]["container_type"] is None
    assert by_no["TGHU9998887"]["vgm_status"] is None


# ── SDU-02 / 03 / 04 / 05 ─────────────────────────────────────────────────────

def test_extract_rejects_exe_and_oversize(client, operator):
    r = client.post("/api/v1/smart-upload/extract/commercial-invoice", headers=_h(operator),
                    files={"file": ("x.exe", b"MZ\x90", "application/octet-stream")})
    assert r.status_code == 415
    big = b"%PDF-" + b"0" * (21 * 1024 * 1024)
    r = client.post("/api/v1/smart-upload/extract/bill-of-lading", headers=_h(operator),
                    files={"file": ("big.pdf", big, "application/pdf")})
    assert r.status_code == 413


def test_parse_multi_caps_file_count(client, operator):
    files = [("files", (f"f{i}.txt", b"hello", "text/plain")) for i in range(11)]
    r = client.post("/api/v1/smart-upload/parse-multi/import-file", headers=_h(operator), files=files)
    assert r.status_code == 400


def test_cross_check_tolerance_validation(client, operator):
    url = "/api/v1/smart-upload/cross-check/invoice-vs-bl"
    assert client.post(url, headers=_h(operator), json={"weight_tolerance_pct": "abc"}).status_code == 422
    assert client.post(url, headers=_h(operator), json={"weight_tolerance_pct": 50}).status_code == 422
    r = client.post(url, headers=_h(operator), json={
        "invoice_data": {"acid_number": "1" * 19}, "bl_data": {"acid_number": "2" * 19}})
    assert r.status_code == 200
    body = r.json()
    assert body["issues"][0]["code"] == "XCHK_ACID_MISMATCH"
    assert "ACID number mismatch" in body["correction_notice_en"]
    assert "عدم تطابق" not in body["correction_notice_en"]


def test_upload_session_ref_after_gap_and_user(client, operator, db):
    year = date.today().year
    db.add(UploadSession(session_ref=f"UPLOAD-{year}-00005", module_name="x", filename="f"))
    db.commit()
    r = client.post("/api/v1/smart-upload/parse/import-file", headers=_h(operator),
                    files={"file": ("../../inv?.txt", b"Invoice No: INV-1\n", "text/plain")})
    assert r.status_code == 200
    body = r.json()
    assert body["session_ref"] == f"UPLOAD-{year}-00006"
    assert body["filename"] == "inv.txt"
    rec = db.query(UploadSession).filter_by(session_ref=f"UPLOAD-{year}-00006").one()
    assert rec.created_by == operator.user_id
    assert sdu_repo._generate_session_ref(db) == f"UPLOAD-{year}-00007"


# ── Security review 03b: SDU permissions (lead decision: upload for extraction, view for history) ──────

TXT = {"file": ("doc.txt", b"Invoice No: INV-1\nB/L No: MSCU1\n", "text/plain")}


@pytest.fixture
def finance(db):
    return _user(db, "fin3b", "FINANCE_OFFICER")


def test_sdu_extraction_needs_upload_permission(client, viewer, customs_officer):
    # AUDITOR_VIEWER (no import_documentation.upload): every extraction / cross-check route is 403.
    for path in ("/api/v1/smart-upload/parse/import-file", "/api/v1/smart-upload/upload/cargo-shipping",
                 "/api/v1/smart-upload/extract/commercial-invoice", "/api/v1/smart-upload/extract/bill-of-lading"):
        assert client.post(path, headers=_h(viewer), files=TXT).status_code == 403, path
    r = client.post("/api/v1/smart-upload/upload", headers=_h(viewer), files=TXT, data={"module_name": "invoice"})
    assert r.status_code == 403
    files = [("files", ("a.txt", b"x", "text/plain"))]
    assert client.post("/api/v1/smart-upload/parse-multi/import-file", headers=_h(viewer), files=files).status_code == 403
    r = client.post("/api/v1/smart-upload/parse-text/supplier-entity", headers=_h(viewer), data={"raw_text": "Acme"})
    assert r.status_code == 403
    assert client.post("/api/v1/smart-upload/cross-check/invoice-vs-bl", headers=_h(viewer), json={}).status_code == 403
    # CUSTOMS_OFFICER holds import_documentation.upload.
    assert client.post("/api/v1/smart-upload/parse/cargo-shipping", headers=_h(customs_officer), files=TXT).status_code == 200
    assert client.post("/api/v1/smart-upload/extract/bill-of-lading", headers=_h(customs_officer), files=TXT).status_code == 200
    r = client.post("/api/v1/smart-upload/cross-check/invoice-vs-bl", headers=_h(customs_officer), json={})
    assert r.status_code == 200


def test_sdu_session_reads_need_view_permission(client, viewer, finance, db):
    rec = UploadSession(session_ref="UPLOAD-2026-90001", module_name="cargo-shipping", filename="bl.pdf")
    db.add(rec)
    db.commit()
    # FINANCE_OFFICER has no import_documentation.view.
    assert client.get("/api/v1/smart-upload/sessions", headers=_h(finance)).status_code == 403
    assert client.get(f"/api/v1/smart-upload/sessions/{rec.id}", headers=_h(finance)).status_code == 403
    r = client.get("/api/v1/smart-upload/sessions", headers=_h(viewer))
    assert r.status_code == 200 and [s["session_ref"] for s in r.json()] == ["UPLOAD-2026-90001"]
    assert client.get(f"/api/v1/smart-upload/sessions/{rec.id}", headers=_h(viewer)).status_code == 200


def test_sdu_error_details_do_not_echo_client_filename(client, operator):
    r = client.post("/api/v1/smart-upload/parse/import-file", headers=_h(operator),
                    files={"file": ("<script>evil.exe", b"MZ\x90", "application/octet-stream")})
    assert r.status_code == 415
    assert "evil" not in str(r.json()["detail"])
    r = client.post("/api/v1/smart-upload/parse/import-file", headers=_h(operator),
                    files={"file": ("secret-name.pdf", b"MZ\x90", "application/pdf")})
    assert r.status_code == 415
    assert "secret-name" not in str(r.json()["detail"])


def test_fallback_extraction_error_is_generic():
    import modules.smart_document_upload.service as sdu_service

    assert sdu_service._fallback_text_extraction("broken.xlsx", b"PK\x03\x04not-a-zip") == ""


# ── Security review 03b: apply targets ────────────────────────────────────────

def test_apply_rejects_closed_file_and_records_user(client, operator, db, imp):
    db.add(CargoShippingRecord(cargo_shipping_code="SHP-CL", import_file_id=imp.import_file_id))
    db.commit()
    r = client.post("/api/v1/smart-upload/apply/commercial-invoice", headers=_h(operator),
                    json={"import_file_id": imp.import_file_id, "invoice_data": {"invoice_value": 10}})
    assert r.status_code == 200
    db.refresh(imp)
    assert imp.updated_by == operator.username
    r = client.post("/api/v1/smart-upload/apply/bill-of-lading", headers=_h(operator), json={
        "import_file_id": imp.import_file_id, "bl_data": {"containers": [{"container_no": "TGHU1234567"}]}})
    assert r.status_code == 200
    rec = db.query(CargoShippingRecord).filter_by(cargo_shipping_code="SHP-CL").one()
    db.refresh(rec)
    assert rec.updated_by == operator.username

    imp.status = "Closed"
    db.commit()
    for path, body in (("commercial-invoice", {"invoice_data": {"invoice_value": 10}}),
                       ("bill-of-lading", {"bl_data": {"containers": [{"container_no": "TGHU7654321"}]}})):
        r = client.post(f"/api/v1/smart-upload/apply/{path}", headers=_h(operator),
                        json={"import_file_id": imp.import_file_id, **body})
        assert r.status_code == 409, path
        assert r.json()["detail"]["code"] == "SDU_FILE_CLOSED"


# ── Security review 03b: DCA four-eyes ────────────────────────────────────────

def test_same_user_cannot_sign_both_review_tiers(client, admin, customs_officer, db, imp):
    a = dca_service.create_approval_service(db, dca_service.CustomsDocumentApprovalCreate(
        import_file_id=imp.import_file_id, document_type="Bill of Lading"))
    url = f"/api/v1/docs-customs-approval/{a.approval_id}"
    assert client.post(f"{url}/commercial-review", headers=_h(admin), json={"status": "Approved"}).status_code == 200
    r = client.post(f"{url}/customs-review", headers=_h(admin), json={"broker_name": "B", "status": "Approved"})
    assert r.status_code == 409
    assert r.json()["detail"]["code"] == "DCA_SAME_REVIEWER"
    r = client.post(f"{url}/customs-review", headers=_h(customs_officer), json={"broker_name": "B", "status": "Approved"})
    assert r.status_code == 200
    assert r.json()["overall_status"] == "Approved for Clearance"
    # The reverse direction: the broker cannot re-sign the commercial tier.
    r = client.post(f"{url}/commercial-review", headers=_h(customs_officer), json={"status": "Approved"})
    assert r.status_code == 409


# ── Diff review 03b follow-ups ────────────────────────────────────────────────

@pytest.fixture
def manager(db):
    return _user(db, "gm3b", "GENERAL_MANAGER")


def test_apply_invoice_without_extracted_total(client, operator, db, imp):
    # Real extractor output for an invoice with no total: invoice_value comes back as 0.0.
    from modules.smart_document_upload.extractors.commercial_invoice import CommercialInvoiceExtractor

    extracted = CommercialInvoiceExtractor().extract("COMMERCIAL INVOICE\nInvoice No: INV-NO-TOTAL\n", {})
    assert not extracted.get("invoice_value")
    imp.estimated_cost = 777.0
    db.commit()
    r = client.post("/api/v1/smart-upload/apply/commercial-invoice", headers=_h(operator),
                    json={"import_file_id": imp.import_file_id, "invoice_data": extracted})
    assert r.status_code == 200, r.text
    assert r.json()["applied"] is True
    db.refresh(imp)
    assert imp.estimated_cost == 777.0  # "no total" never overwrites the stored value


def test_extraction_accepts_any_screen_permission(client, manager, viewer):
    # GENERAL_MANAGER has no import_documentation.upload but uses smart upload from quotations / scenarios.
    assert client.post("/api/v1/smart-upload/parse/import-file", headers=_h(manager), files=TXT).status_code == 200
    assert client.post("/api/v1/smart-upload/cross-check/invoice-vs-bl", headers=_h(manager), json={}).status_code == 200
    assert client.get("/api/v1/smart-upload/sessions", headers=_h(manager)).status_code == 200
    assert client.post("/api/v1/smart-upload/parse/import-file", headers=_h(viewer), files=TXT).status_code == 403


def test_matrix_sent_to_supplier_ticket_is_blocker(db, imp):
    db.add(DiscrepancyRectificationTicket(ticket_code="T-S", import_file_id=imp.import_file_id,
                                          issue_category="Other", description="sent ticket", status="Sent to Supplier"))
    db.commit()
    res = dca_service.run_cross_document_matrix_check_service(db, imp.import_file_id)
    assert res.open_tickets_count == 1
    assert res.overall_compliance == "Critical Blocker"


def test_draft_session_does_not_stamp_customs_signoff(db, imp, operator):
    res = dca_service.create_customs_approval_session_service(
        db, DocsCustomsApprovalSessionCreate(import_file_id=imp.import_file_id, is_draft=True,
                                             customs_signoff_by="x", customs_signoff_date=date(2026, 1, 1)),
        current_user=operator)
    assert res.customs_signoff_by is None
    assert res.customs_signoff_date is None


def test_sh04_does_not_stamp_commercial_for_customs_signer(db, imp):
    db.add(CustomsDocumentApproval(approval_code="CDA-OD-1", import_file_id=imp.import_file_id,
                                   document_type="ORIGINAL_DOCUMENTS", commercial_status="Pending",
                                   customs_status="Approved", customs_reviewed_by="broker", overall_status="Under Review"))
    db.commit()
    ODC.save_or_upsert_collection_session(db, _odc_payload(imp, [_doc("CI", True, True)]), username="broker")
    a = _odc_approval(db, imp)
    db.refresh(a)
    assert a.commercial_status == "Pending"
    assert a.commercial_reviewed_by is None


def test_apply_bl_without_shipping_record_is_409(client, operator, imp):
    r = client.post("/api/v1/smart-upload/apply/bill-of-lading", headers=_h(operator), json={
        "import_file_id": imp.import_file_id, "bl_data": {"containers": [{"container_no": "TGHU1234567"}]}})
    assert r.status_code == 409
    assert r.json()["detail"]["code"] == "SDU_NO_SHIPPING_RECORD"


def test_lifecycle_advances_only_on_transition(db, imp, monkeypatch):
    import modules.lifecycle_board.service as lc

    calls = []
    real = lc.advance_lifecycle_step_service
    monkeypatch.setattr(lc, "advance_lifecycle_step_service", lambda **kw: calls.append(kw) or real(**kw))
    ODC.save_or_upsert_collection_session(db, _odc_payload(imp, [_doc("CI", True)]))
    ODC.save_or_upsert_collection_session(db, _odc_payload(imp, [_doc("CI", True, True)]))
    ODC.save_or_upsert_collection_session(db, _odc_payload(imp, [_doc("CI", True, True)]))
    assert len(calls) == 1
