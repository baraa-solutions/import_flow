"""
Phase 3a package D1 (edge) for modules/import_documentation: router permissions and acting user (DOC-01 / DOC-12),
upload validation (DOC-16), status whitelists (DOC-14), repository not-found / soft-delete rules (DOC-07 / DOC-08),
yearly codes (DOC-10 / DOC-22), and the additive schema contract
(C2 / C4 / C5 / C6).

Router tests replace the service functions with recorders, so they pin the HTTP layer only (the engine is D2).
"""

import importlib
from types import SimpleNamespace
import inspect
from datetime import date, timedelta

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main  # noqa: F401  (registers every model on Base.metadata)
import modules.auth.permissions as auth_permissions
from database.database import Base, get_db
from modules.auth.permissions import invalidate_permission_cache
from modules.auth.security import create_access_token
from modules.auth.seed_rbac import seed_rbac
from modules.import_documentation import validators
from modules.import_documentation.model import (
    AcidRegistrationSession,
    BankingDocumentSession,
    CertificateOfOriginReviewSession,
    CustomsDeclarationDraft,
    DraftBLReviewSession,
    InspectionCertificateReviewSession,
    InvoiceBLMatchSession,
    POPackingReconciliationSession,
    ShipmentDocumentItem,
)
from modules.import_documentation.schemas import (
    AcidRegistrationCreate,
    BankingDocumentUpdate,
    CertificateOfOriginReviewUpdate,
    COODraftTemplateResponse,
    CustomsDeclarationCreate,
    DraftBLReviewUpdate,
    DualApprovalRequest,
    InspectionCertificateReviewUpdate,
    InspectionDraftTemplateResponse,
    InvoiceBLMatchSessionUpdate,
    LegalDocAlertItem,
    POFinalAdjustmentRequest,
    POReconciliationItem,
    POReconciliationSessionCreate,
    POReconciliationSessionUpdate,
    ShipmentDocumentUpdate,
)
from modules.users.model import Role, User
import modules.import_documentation.repository as repo
import modules.import_documentation.service as service

doc_router = importlib.import_module("modules.import_documentation.router")

YEAR = date.today().year
PREFIX = "/api/v1/import-documentation"
ACID_19 = "5281534391023010013"


# ─── Fixtures ────────────────────────────────────────────────────────────────

@pytest.fixture
def session_factory():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    factory = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    invalidate_permission_cache()
    yield factory
    invalidate_permission_cache()
    engine.dispose()


@pytest.fixture
def db(session_factory):
    session = session_factory()
    yield session
    session.close()


def _make_user(db, username: str, role_code: str) -> User:
    role = db.query(Role).filter(Role.role_code == role_code).one()
    user = User(
        username=username, email=f"{username}@test.com", full_name=username,
        hashed_password="not-used", role=role.role_code, role_id=role.role_id, is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _bearer(user: User) -> dict:
    return {"Authorization": f"Bearer {create_access_token({'sub': str(user.user_id), 'role': user.role})}"}


@pytest.fixture(scope="module")
def auth_env():
    """One seeded RBAC database for every HTTP test of the module (the routes under test never write: the
    service functions are replaced by recorders or the request fails validation first)."""
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    factory = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    invalidate_permission_cache()
    session = factory()
    seed_rbac(session)
    users = {
        "viewer": _make_user(session, "doc_viewer", "AUDITOR_VIEWER"),       # view only
        "operator": _make_user(session, "doc_operator", "LOGISTICS_OPERATOR"),  # view + upload + approve
        "manager": _make_user(session, "doc_manager", "GENERAL_MANAGER"),     # view + approve, no upload
        "finance": _make_user(session, "doc_finance", "FINANCE_OFFICER"),     # no import_documentation code
    }
    # plain snapshots: later commits expire ORM instances, and the tests only need these three fields
    users = {k: SimpleNamespace(user_id=u.user_id, username=u.username, role=u.role) for k, u in users.items()}
    session.close()
    yield factory, users
    invalidate_permission_cache()
    engine.dispose()


@pytest.fixture
def users(auth_env):
    return auth_env[1]


class Recorder:
    """Stands in for a service function: records the call and returns a canned value."""

    def __init__(self, result=None):
        self.result = result
        self.calls = []

    def __call__(self, *args, **kwargs):
        self.calls.append((args, kwargs))
        return self.result


@pytest.fixture
def client(auth_env, monkeypatch):
    session_factory = auth_env[0]
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)
    app = FastAPI()
    app.include_router(doc_router.router)

    def override_get_db():
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = override_get_db
    return TestClient(app, raise_server_exceptions=False)


# ─── DOC-01: every route declares the right permission ──────────────────────

def _route_permissions(route) -> set:
    codes = set()
    for dep in route.dependant.dependencies:
        for cell in getattr(dep.call, "__closure__", None) or ():
            if isinstance(cell.cell_contents, str) and cell.cell_contents.startswith("import_documentation."):
                codes.add(cell.cell_contents)
    return codes


APPROVE_ROUTES = {("POST", "/draft-bl/dual-approval"), ("POST", "/draft-bl/{review_id}/approve")}
VIEW_POST_ROUTES = {
    "/acid/parse-text", "/acid/compare", "/acid/templates", "/draft-bl/compare", "/coo/compare",
    "/inspection/compare", "/cross-match-certificates",
}


def test_every_route_declares_exactly_one_expected_permission():
    seen = 0
    for route in doc_router.router.routes:
        path = route.path[len(PREFIX):]
        method = next(iter(route.methods))
        codes = _route_permissions(route)
        if (method, path) in APPROVE_ROUTES:
            expected = "import_documentation.approve"
        elif method == "GET" or path in VIEW_POST_ROUTES:
            expected = "import_documentation.view"
        else:
            expected = "import_documentation.upload"
        assert codes == {expected}, f"{method} {path}: {codes}"
        seen += 1
    assert seen == len(doc_router.router.routes) >= 55


@pytest.mark.parametrize(
    "method,path",
    [
        ("post", "/acid-sessions"),
        ("put", "/acid-sessions/1"),
        ("delete", "/acid-sessions/1"),
        ("post", "/banking-documents"),
        ("post", "/po-reconciliation"),
        ("put", "/draft-bl/1"),
        ("delete", "/coo/1"),
        ("post", "/invoice-bl/certify-and-sync"),
        ("post", "/draft-bl/extract-file"),
    ],
)
def test_viewer_gets_403_on_writes(client, users, method, path):
    resp = getattr(client, method)(f"{PREFIX}{path}", headers=_bearer(users["viewer"]))
    assert resp.status_code == 403
    assert "import_documentation.upload" in resp.json()["detail"]


def test_no_token_is_401(client, users):
    assert client.get(f"{PREFIX}/acid-sessions").status_code == 401


def test_role_without_view_gets_403_on_reads(client, users):
    resp = client.get(f"{PREFIX}/acid-sessions", headers=_bearer(users["finance"]))
    assert resp.status_code == 403
    assert "import_documentation.view" in resp.json()["detail"]


def test_viewer_can_read(client, users, monkeypatch):
    monkeypatch.setattr(service, "list_acid_sessions_service", Recorder([]))
    resp = client.get(f"{PREFIX}/acid-sessions", headers=_bearer(users["viewer"]))
    assert resp.status_code == 200 and resp.json() == []


def test_approve_routes_need_approve_permission(client, users):
    # viewer has no approve -> 403; manager has approve (no upload) -> auth passes, invalid body -> 422
    assert client.post(f"{PREFIX}/draft-bl/dual-approval", json={}, headers=_bearer(users["viewer"])).status_code == 403
    assert client.post(f"{PREFIX}/draft-bl/1/approve", headers=_bearer(users["viewer"])).status_code == 403
    assert client.post(f"{PREFIX}/draft-bl/dual-approval", json={}, headers=_bearer(users["manager"])).status_code == 422


def test_manager_without_upload_cannot_create(client, users):
    resp = client.post(f"{PREFIX}/draft-bl", json={}, headers=_bearer(users["manager"]))
    assert resp.status_code == 403


def test_operator_passes_upload_check(client, users):
    # invalid body -> 422 proves the permission check passed
    assert client.post(f"{PREFIX}/acid-sessions", json={}, headers=_bearer(users["operator"])).status_code == 422


# ─── DOC-12: acting user is the authenticated user ───────────────────────────

def test_dual_approval_passes_logged_in_user_and_ignores_body_identity(client, users, monkeypatch):
    rec = Recorder()
    monkeypatch.setattr(service, "process_dual_approval_service", rec)
    resp = client.post(
        f"{PREFIX}/draft-bl/dual-approval",
        json={"bl_review_id": 3, "role": "importer", "action": "Approved", "approved_by": "Mallory"},
        headers=_bearer(users["operator"]),
    )
    # the recorder returns None, which fails response validation: only the call matters here
    assert rec.calls, resp.text
    args, kwargs = rec.calls[0]
    assert kwargs["user"] == "doc_operator"
    assert args[1].bl_review_id == 3


def test_approve_ignores_approved_by_query_param(client, users, monkeypatch):
    rec = Recorder()
    monkeypatch.setattr(service, "approve_draft_bl_service", rec)
    client.post(f"{PREFIX}/draft-bl/7/approve?approved_by=Mallory", headers=_bearer(users["manager"]))
    args, kwargs = rec.calls[0]
    assert args[1] == 7
    assert kwargs == {"user": "doc_manager"}


def test_checklist_ignores_reviewer_name_query_param(client, users, monkeypatch):
    rec = Recorder()
    monkeypatch.setattr(service, "update_draft_bl_checklist_service", rec)
    client.put(f"{PREFIX}/draft-bl/5/checklist?reviewer_name=Mallory", json=[], headers=_bearer(users["operator"]))
    args, kwargs = rec.calls[0]
    assert args[1:] == (5, [])
    assert kwargs == {"user": "doc_operator"}


@pytest.mark.parametrize(
    "method,path,service_name,body",
    [
        ("delete", "/acid-sessions/4", "soft_delete_acid_session_service", None),
        ("patch", "/acid-sessions/4/restore", "restore_acid_session_service", None),
        ("delete", "/banking-documents/4", "delete_banking_document_service", None),
        ("delete", "/draft-bl/4", "delete_draft_bl_review_service", None),
        ("delete", "/coo/4", "delete_coo_review_service", None),
        ("delete", "/inspection/4", "delete_inspection_review_service", None),
        ("delete", "/po-reconciliation/sessions/4", "delete_po_reconciliation_session_service", None),
        ("post", "/invoice-bl/certify-and-sync", "sync_certified_invoice_bl_to_file_service",
         {"import_file_id": 1, "invoice_data": {}, "bl_data": {}}),
        ("post", "/po-reconciliation", "reconcile_po_final_adjustments_service",
         {"import_file_id": 1, "final_invoice_number": "INV-1", "items": [], "approved_by": "Mallory"}),
    ],
)
def test_mutating_routes_pass_user(client, users, monkeypatch, method, path, service_name, body):
    rec = Recorder({"status": "success"})
    monkeypatch.setattr(service, service_name, rec)
    kwargs = {"json": body} if body is not None else {}
    getattr(client, method)(f"{PREFIX}{path}", headers=_bearer(users["operator"]), **kwargs)
    assert rec.calls, f"{service_name} not called"
    assert rec.calls[0][1]["user"] == "doc_operator"


# ─── DOC-16: uploads ─────────────────────────────────────────────────────────

def test_validate_upload_rules():
    assert validators.validate_upload(" bl.PDF ", b"%PDF") == "bl.PDF"
    with pytest.raises(HTTPException) as exc:
        validators.validate_upload(None, b"x")
    assert exc.value.status_code == 400
    with pytest.raises(HTTPException) as exc:
        validators.validate_upload("", b"x")
    assert exc.value.status_code == 400
    with pytest.raises(HTTPException) as exc:
        validators.validate_upload("tool.exe", b"MZ")
    assert exc.value.status_code == 400 and "exe" in exc.value.detail
    with pytest.raises(HTTPException) as exc:
        validators.validate_upload("noext", b"x")
    assert exc.value.status_code == 400
    with pytest.raises(HTTPException) as exc:
        validators.validate_upload("big.pdf", b"0" * (validators.MAX_UPLOAD_BYTES + 1))
    assert exc.value.status_code == 413
    assert validators.validate_upload("edge.pdf", b"0" * validators.MAX_UPLOAD_BYTES) == "edge.pdf"


def test_upload_route_rejects_exe_and_oversize_before_the_service(client, users, monkeypatch):
    rec = Recorder({})
    monkeypatch.setattr(service, "extract_draft_bl_file_service", rec, raising=False)
    h = _bearer(users["operator"])
    resp = client.post(f"{PREFIX}/draft-bl/extract-file", files={"file": ("evil.exe", b"MZ")}, headers=h)
    assert resp.status_code == 400
    big = b"0" * (21 * 1024 * 1024)
    resp = client.post(f"{PREFIX}/draft-bl/extract-file", files={"file": ("big.pdf", big)}, headers=h)
    assert resp.status_code == 413
    assert rec.calls == []


def test_upload_route_passes_filename_and_bytes(client, users, monkeypatch):
    rec = Recorder({"filename": "bl.pdf"})
    monkeypatch.setattr(service, "extract_draft_bl_file_service", rec, raising=False)
    resp = client.post(
        f"{PREFIX}/draft-bl/extract-file",
        files={"file": ("bl.pdf", b"%PDF-1.4 data")},
        data={"import_file_id": "9"},
        headers=_bearer(users["operator"]),
    )
    assert resp.status_code == 200, resp.text
    assert rec.calls[0][1] == {"filename": "bl.pdf", "content": b"%PDF-1.4 data", "import_file_id": 9}


def test_certificate_upload_route_passes_document_type(client, users, monkeypatch):
    rec = Recorder({"document_type": "EUR1", "extracted_data": {}})
    monkeypatch.setattr(service, "extract_certificate_file_service", rec, raising=False)
    resp = client.post(
        f"{PREFIX}/extract-certificate-file",
        files={"file": ("eur1.txt", b"EUR.1 text")},
        data={"document_type": "EUR1"},
        headers=_bearer(users["operator"]),
    )
    assert resp.status_code == 200, resp.text
    assert rec.calls[0][1] == {
        "document_type": "EUR1", "filename": "eur1.txt", "content": b"EUR.1 text", "import_file_id": None,
    }


def test_po_files_route_passes_optional_tuples(client, users, monkeypatch):
    rec = Recorder()
    monkeypatch.setattr(service, "extract_po_files_and_compare_service", rec, raising=False)
    client.post(
        f"{PREFIX}/po-reconciliation/extract-files-and-compare",
        files={"invoice_file": ("inv.xlsx", b"PK")},
        data={"import_file_id": "2", "packing_text": "PL text"},
        headers=_bearer(users["operator"]),
    )
    kwargs = rec.calls[0][1]
    assert kwargs["invoice"] == ("inv.xlsx", b"PK")
    assert kwargs["packing"] is None
    assert (kwargs["import_file_id"], kwargs["invoice_text"], kwargs["packing_text"]) == (2, None, "PL text")


def test_invoice_bl_files_route_merges_single_and_multi_fields(client, users, monkeypatch):
    rec = Recorder()
    monkeypatch.setattr(service, "extract_invoice_bl_files_and_match_service", rec, raising=False)
    client.post(
        f"{PREFIX}/invoice-bl/extract-files-and-match",
        files=[
            ("invoice_files", ("inv1.pdf", b"1")),
            ("invoice_files", ("inv2.pdf", b"2")),
            ("invoice_file", ("inv3.pdf", b"3")),
            ("bl_file", ("bl.pdf", b"B")),
        ],
        data={"bl_text": "typed B/L"},
        headers=_bearer(users["operator"]),
    )
    kwargs = rec.calls[0][1]
    assert kwargs["invoices"] == [("inv1.pdf", b"1"), ("inv2.pdf", b"2"), ("inv3.pdf", b"3")]
    assert kwargs["bls"] == [("bl.pdf", b"B")]
    assert kwargs["packings"] == []
    assert kwargs["bl_text"] == "typed B/L"


def test_invoice_bl_files_route_rejects_any_bad_file(client, users, monkeypatch):
    rec = Recorder()
    monkeypatch.setattr(service, "extract_invoice_bl_files_and_match_service", rec, raising=False)
    resp = client.post(
        f"{PREFIX}/invoice-bl/extract-files-and-match",
        files=[("invoice_files", ("ok.pdf", b"1")), ("bl_files", ("bad.bat", b"x"))],
        headers=_bearer(users["operator"]),
    )
    assert resp.status_code == 400
    assert rec.calls == []


# ─── DOC-14: status whitelists ───────────────────────────────────────────────

def test_validate_status_whitelists():
    assert validators.validate_status("acid", None) is None
    assert validators.validate_status("acid", "Issued") == "Issued"
    assert validators.validate_status("coo", "Correction Requested") == "Correction Requested"
    assert validators.validate_status("invoice_bl", "DRAFT_SAVED") == "DRAFT_SAVED"
    for kind, bad in [("acid", "verified"), ("banking", "Done"), ("coo", "All"), ("reconciliation", "OK")]:
        with pytest.raises(HTTPException) as exc:
            validators.validate_status(kind, bad)
        assert exc.value.status_code == 400 and bad in exc.value.detail


def test_engine_trigger_values_are_whitelisted():
    # every literal the workflows react to must stay accepted (no recoding this wave)
    assert {"Verified", "Discrepancy_Accepted", "Generated", "Issued", "ACID Issued"} <= validators.STATUS_WHITELISTS["acid"]
    assert {"Received", "Approved by Bank", "Form Issued", "Verified", "Endorsed"} <= validators.STATUS_WHITELISTS["banking"]
    assert {"Verified", "Approved", "Discrepancy_Accepted"} <= validators.STATUS_WHITELISTS["coo"]
    assert {"Verified", "Approved", "Discrepancy_Accepted"} <= validators.STATUS_WHITELISTS["inspection"]
    assert {"MATCHED", "APPROVED", "CERTIFIED", "PASS", "CONFORMING"} <= validators.STATUS_WHITELISTS["reconciliation"]


@pytest.mark.parametrize(
    "method,path,body",
    [
        ("put", "/acid-sessions/1", {"status": "Bogus"}),
        ("put", "/banking-documents/1", {"status": "Bogus"}),
        ("post", "/coo", {"import_file_id": 1, "status": "Bogus"}),
        ("put", "/inspection/1", {"status": "Bogus"}),
        ("post", "/po-reconciliation/sessions", {"import_file_id": 1, "overall_status": "Bogus"}),
        ("put", "/po-reconciliation/sessions/1", {"overall_status": "Bogus"}),
        ("post", "/invoice-bl/sessions", {"import_file_id": 1, "overall_status": "Bogus"}),
    ],
)
def test_routes_reject_unknown_status_with_400(client, users, method, path, body):
    resp = getattr(client, method)(f"{PREFIX}{path}", json=body, headers=_bearer(users["operator"]))
    assert resp.status_code == 400
    assert "Bogus" in resp.json()["detail"]


# ─── Schemas: C2 / C3 / C4 / C5 / C6 ─────────────────────────────────────────

def test_dual_approval_role_and_action_are_closed_sets():
    ok = DualApprovalRequest(bl_review_id=1, role="customs_broker", action="Rejected")
    assert ok.approved_by is None
    with pytest.raises(ValidationError):
        DualApprovalRequest(bl_review_id=1, role="admin", action="Approved")
    with pytest.raises(ValidationError):
        DualApprovalRequest(bl_review_id=1, role="importer", action="Maybe")


def test_dual_approval_bad_role_is_422_over_http(client, users):
    resp = client.post(
        f"{PREFIX}/draft-bl/dual-approval",
        json={"bl_review_id": 1, "role": "boss", "action": "Approved"},
        headers=_bearer(users["operator"]),
    )
    assert resp.status_code == 422


def _adjust_item(**overrides):
    data = dict(item_code="A", description="d", initial_quantity=1, final_quantity=1)
    data.update(overrides)
    return data


def test_final_adjustment_items_reject_negatives_and_accept_packing_item_id():
    req = POFinalAdjustmentRequest(import_file_id=1, final_invoice_number="I", items=[_adjust_item(packing_item_id=5)])
    assert req.items[0].packing_item_id == 5
    assert req.approved_by is None
    for field in ("final_quantity", "final_net_weight_kg", "final_gross_weight_kg", "initial_gross_weight_kg", "final_cbm"):
        with pytest.raises(ValidationError):
            POFinalAdjustmentRequest(import_file_id=1, final_invoice_number="I", items=[_adjust_item(**{field: -1})])
    # response items stay unconstrained (OCR output)
    assert POReconciliationItem(**_adjust_item(final_quantity=-1)).final_quantity == -1


def test_negative_final_quantity_is_422_over_http(client, users):
    resp = client.post(
        f"{PREFIX}/po-reconciliation",
        json={"import_file_id": 1, "final_invoice_number": "I", "items": [_adjust_item(final_quantity=-2)]},
        headers=_bearer(users["operator"]),
    )
    assert resp.status_code == 422


def test_additive_response_fields_default_empty():
    coo = COODraftTemplateResponse(
        import_file_id=1, import_file_code="F", certificate_type="EUR.1", template_data={}, preview_markdown="",
    )
    insp = InspectionDraftTemplateResponse(
        import_file_id=1, import_file_code="F", inspection_agency="SGS", inspection_type="COC",
        template_data={}, preview_markdown="",
    )
    assert coo.missing_fields == [] and insp.missing_fields == []
    alert = LegalDocAlertItem(
        doc_type="ACID", doc_number="1", days_until_expiry=1, is_expired=False, is_critical_breach=False,
        alert_message="x", status="VALID",
    )
    assert alert.message_code is None and alert.message_params is None


# ─── Repository: DOC-07 / DOC-08 / DOC-10 / DOC-22 / DOC-15 / DOC-25 ─────────

def _add(db, model, **data):
    row = model(**data)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@pytest.fixture
def deleted_rows(db):
    return {
        "draft_bl": _add(db, DraftBLReviewSession, bl_review_code="BL-REV-X-1", import_file_id=1, is_active=False),
        "coo": _add(db, CertificateOfOriginReviewSession, coo_review_code="COO-X-1", import_file_id=1,
                    exporter_name="e", importer_name="i", country_of_origin="c", is_active=False),
        "inspection": _add(db, InspectionCertificateReviewSession, inspection_review_code="INSP-X-1",
                           import_file_id=1, is_active=False),
        "recon": _add(db, POPackingReconciliationSession, session_code="REC-X-1", import_file_id=1, is_active=False),
        "match": _add(db, InvoiceBLMatchSession, session_code="MATCH-X-1", import_file_id=1, is_active=False),
        "shipment": _add(db, ShipmentDocumentItem, document_code="DOC-X-1", doc_name="Inv", doc_number="1",
                         is_active=False),
    }


def test_updates_on_deleted_or_missing_rows_return_none_and_stay_inactive(db, deleted_rows):
    r = deleted_rows
    cases = [
        (repo.update_draft_bl_review, r["draft_bl"].bl_review_id, DraftBLReviewUpdate(vessel_name="V")),
        (repo.update_coo_review, r["coo"].coo_review_id, CertificateOfOriginReviewUpdate(certificate_number="N")),
        (repo.update_inspection_review, r["inspection"].inspection_review_id,
         InspectionCertificateReviewUpdate(certificate_number="N")),
        (repo.update_po_reconciliation_session, r["recon"].session_id, POReconciliationSessionUpdate(notes="n")),
        (repo.update_invoice_bl_match_session, r["match"].session_id, InvoiceBLMatchSessionUpdate(notes="n")),
        (repo.update_shipment_document, r["shipment"].document_id, ShipmentDocumentUpdate(doc_number="2")),
    ]
    for fn, row_id, schema in cases:
        assert fn(db, row_id, schema) is None, fn.__name__
        assert fn(db, 99999, schema) is None, fn.__name__
    for row in r.values():
        db.refresh(row)
        assert row.is_active is False


def test_deletes_on_deleted_rows_return_false(db, deleted_rows):
    r = deleted_rows
    assert repo.delete_draft_bl_review(db, r["draft_bl"].bl_review_id) is False
    assert repo.delete_coo_review(db, r["coo"].coo_review_id) is False
    assert repo.delete_inspection_review(db, r["inspection"].inspection_review_id) is False
    assert repo.delete_po_reconciliation_session(db, r["recon"].session_id) is False
    assert repo.delete_invoice_bl_match_session(db, r["match"].session_id) is False


def test_update_on_active_row_keeps_it_active(db):
    row = _add(db, CertificateOfOriginReviewSession, coo_review_code="COO-A-1", import_file_id=1,
               exporter_name="e", importer_name="i", country_of_origin="c", is_active=True)
    updated = repo.update_coo_review(db, row.coo_review_id, CertificateOfOriginReviewUpdate(certificate_number="EUR-9"))
    assert updated.certificate_number == "EUR-9" and updated.is_active is True


def test_update_with_commit_false_only_flushes(db):
    row = _add(db, CertificateOfOriginReviewSession, coo_review_code="COO-A-2", import_file_id=1,
               exporter_name="e", importer_name="i", country_of_origin="c", is_active=True)
    repo.update_coo_review(db, row.coo_review_id, CertificateOfOriginReviewUpdate(certificate_number="N1"), commit=False)
    db.rollback()
    db.refresh(row)
    assert row.certificate_number != "N1"


def test_inactive_reconciliation_lookup_and_reactivate(db):
    assert repo.get_inactive_po_reconciliation_by_file(db, 5) is None
    row = _add(db, POPackingReconciliationSession, session_code=f"REC-{YEAR}-0003", import_file_id=5,
               final_invoice_number="OLD", notes="old", is_active=False)
    found = repo.get_inactive_po_reconciliation_by_file(db, 5)
    assert found.session_id == row.session_id
    again = repo.reactivate_po_reconciliation_session(
        db, found, POReconciliationSessionCreate(import_file_id=5, final_invoice_number="NEW")
    )
    assert again.is_active is True
    assert again.session_code == f"REC-{YEAR}-0003"
    assert (again.final_invoice_number, again.notes) == ("NEW", None)
    assert repo.get_inactive_po_reconciliation_by_file(db, 5) is None


def test_dec46_codes_follow_the_yearly_sequence(db):
    first = repo.create_customs_declaration(db, CustomsDeclarationCreate(import_file_id=1, acid_number=ACID_19))
    second = repo.create_customs_declaration(db, CustomsDeclarationCreate(import_file_id=2, acid_number=ACID_19))
    assert (first.declaration_code, second.declaration_code) == (f"DEC46-{YEAR}-001", f"DEC46-{YEAR}-002")
    assert repo.get_customs_declaration_active(db, second.declaration_id).declaration_code == second.declaration_code


def test_codes_ignore_non_digit_suffixes_and_other_years(db):
    _add(db, DraftBLReviewSession, bl_review_code=f"BL-REV-{YEAR}-0004", import_file_id=1)
    _add(db, DraftBLReviewSession, bl_review_code=f"BL-REV-{YEAR}-0004-v2", import_file_id=1, version_number=2)
    _add(db, DraftBLReviewSession, bl_review_code=f"BL-REV-{YEAR - 1}-0950", import_file_id=1)
    assert repo.generate_bl_review_code(db) == f"BL-REV-{YEAR}-0005"
    _add(db, AcidRegistrationSession, acid_code=f"ACID-{YEAR}-012-COPY", acid_number="PENDING", importer_name="x",
         importer_tax_id="x", exporter_name="x", exporter_reg_id="x", exporter_country="x",
         proforma_invoice_no="x", pol_name="x", pod_name="x", expiry_date=date.today())
    assert repo.generate_acid_code(db) == f"ACID-{YEAR}-001"


def test_draft_bl_version_helpers(db):
    root = _add(db, DraftBLReviewSession, bl_review_code=f"BL-REV-{YEAR}-0001", import_file_id=1)
    v2 = _add(db, DraftBLReviewSession, bl_review_code=f"BL-REV-{YEAR}-0001-v2", import_file_id=1,
              version_number=2, parent_session_id=root.bl_review_id, is_active=False)
    v3 = _add(db, DraftBLReviewSession, bl_review_code=f"BL-REV-{YEAR}-0001-v3", import_file_id=1,
              version_number=3, parent_session_id=v2.bl_review_id)
    _add(db, DraftBLReviewSession, bl_review_code=f"BL-REV-{YEAR}-00010", import_file_id=1)  # not in the chain
    assert repo.get_draft_bl_root(db, v3).bl_review_id == root.bl_review_id
    assert [r.version_number for r in repo.get_draft_bl_versions(db, root.bl_review_code)] == [1, 2, 3]
    assert [r.version_number for r in repo.get_draft_bl_versions(db, root.bl_review_code, include_inactive=False)] == [1, 3]


def _acid_schema(**overrides):
    data = dict(
        acid_number="PENDING", importer_name="Delta", importer_tax_id="100-200-300", exporter_name="Shanghai",
        exporter_reg_id="CN-1", exporter_country="China", proforma_invoice_no="PI-1", pol_name="SHA", pod_name="ALY",
    )
    data.update(overrides)
    return AcidRegistrationCreate(**data)


def test_acid_create_placeholder_number_is_requested_even_with_generated_date(db):
    gen = date.today() - timedelta(days=1)
    for number in ("PENDING", "REQUESTED", "DRAFT"):
        row = repo.create_acid_session(db, _acid_schema(acid_number=number, generated_date=gen))
        assert row.status == "Requested", number
    issued = repo.create_acid_session(db, _acid_schema(acid_number=ACID_19, generated_date=gen))
    assert issued.status == "Verified"


def test_acid_create_without_expiry_defaults_to_issue_plus_90_days(db):
    req = date.today() - timedelta(days=10)
    gen = date.today() - timedelta(days=5)
    with_gen = repo.create_acid_session(db, _acid_schema(acid_number=ACID_19, requested_date=req, generated_date=gen))
    assert with_gen.expiry_date == gen + timedelta(days=90)
    only_req = repo.create_acid_session(db, _acid_schema(requested_date=req))
    assert only_req.expiry_date == req + timedelta(days=90)
    explicit = repo.create_acid_session(db, _acid_schema(requested_date=req, expiry_date=req + timedelta(days=30)))
    assert explicit.expiry_date == req + timedelta(days=30)


def test_banking_update_explicit_null_clears_nullable_and_skips_not_null(db):
    row = _add(db, BankingDocumentSession, bank_doc_code="FORM4-X-1", bank_name="NBE", amount=10.0,
               expiry_date=date.today(), notes="keep?", is_active=True)
    updated = repo.update_banking_document(
        db, row, BankingDocumentUpdate(expiry_date=None, notes=None, bank_name=None, amount=None)
    )
    assert updated.expiry_date is None and updated.notes is None
    assert updated.bank_name == "NBE" and updated.amount == 10.0
    assert repo.delete_banking_document(db, updated) is True
    assert repo.delete_banking_document(db, updated) is False  # already deleted
    assert repo.get_banking_document_active(db, row.bank_doc_id) is None


def test_active_getters(db, deleted_rows):
    r = deleted_rows
    assert repo.get_draft_bl_review_active(db, r["draft_bl"].bl_review_id) is None
    assert repo.get_coo_review_active(db, r["coo"].coo_review_id) is None
    assert repo.get_inspection_review_active(db, r["inspection"].inspection_review_id) is None
    assert repo.get_po_reconciliation_session_active(db, r["recon"].session_id) is None
    assert repo.get_invoice_bl_match_session_active(db, r["match"].session_id) is None
    assert repo.get_shipment_document_active(db, r["shipment"].document_id) is None
    assert repo.get_customs_declaration_active(db, 12345) is None


def test_repository_never_raises_value_error():
    src = inspect.getsource(repo)
    assert "raise ValueError" not in src
    # only the explicit restore paths reactivate: restore_acid_session + reactivate_po_reconciliation_session
    assert src.count(".is_active = True") == 2
