"""
Phases 6-7 quality wave regression tests (docs/plans/phase-06-07-quality-plan.md, BE package):
permissions (CL-01 / CCQ-01), release / payment guards (CL-02, CL-05..07), single duty formula and PUT
hardening (CL-03 / CL-04), under-bond and lab codes (CL-08), invoices (CL-09, CL-11, CL-15), restore (CL-16),
audit user (CL-17), best-effort side effects (CL-12), quotations (CCQ-02..09).
"""

import importlib
from datetime import date, datetime, timedelta, timezone

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main  # noqa: F401 - registers every SQLAlchemy model
import modules.auth.permissions as auth_permissions
import modules.customs_clearance.service as cc_service
from database.database import Base, get_db
from modules.auth.permissions import invalidate_permission_cache
from modules.auth.security import create_access_token, hash_password
from modules.auth.seed_rbac import seed_rbac
from modules.customs_clearance.model import ClearanceExpenseInvoice, CustomsClearanceRecord
from modules.customs_clearance.schemas import (
    ClearanceExpenseInvoiceCreate,
    CompleteReleaseSubmit,
    CustomsClearanceUpdate,
    CustomsDutyPaymentSubmit,
    CustomsFinalReleaseSubmit,
    FinalDutyAssessmentSubmit,
    LabTestResultSubmit,
    UnderBondReleaseSubmit,
)
from modules.customs_clearance.service import (
    assess_final_customs_duties_service,
    complete_customs_release_service,
    issue_final_customs_release_service,
    issue_under_bond_release_service,
    record_clearance_invoice_service,
    record_customs_duty_payment_service,
    record_lab_result_and_lift_quarantine_service,
    restore_customs_clearance_service,
    soft_delete_customs_clearance_service,
    update_customs_clearance_service,
)
from modules.customs_clearance_quotations.model import CustomsClearanceQuotationItem, CustomsClearanceRFQ
from modules.customs_clearance_quotations.schemas import (
    ClearancePriceListItemCreate,
    ClearancePriceListItemUpdate,
    CustomsClearanceQuotationCreate,
    CustomsClearanceRFQCreate,
    CustomsClearanceRFQUpdate,
)
from modules.customs_clearance_quotations.service import (
    add_quotation_service,
    award_quotation_service,
    create_price_item_service,
    create_rfq_service,
    delete_quotation_service,
    delete_rfq_service,
    update_price_item_service,
    update_rfq_service,
)
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile
from modules.smart_tasks.model import SmartTask
from modules.users.model import Role, User

cc_router = importlib.import_module("modules.customs_clearance.router")
ccq_router = importlib.import_module("modules.customs_clearance_quotations.router")


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


def _import_file(db, code="IMP-0607-FIX", **fields) -> ImportFile:
    values = dict(import_file_code=code, company_name="Fix Co", supplier_name="Fix Supplier", progress_percent=50.0,
                  owner="tester", is_active=True)
    values.update(fields)
    imp = ImportFile(**values)
    db.add(imp)
    db.commit()
    db.refresh(imp)
    return imp


def _clearance(db, imp, **fields) -> CustomsClearanceRecord:
    values = dict(
        clearance_code=f"CLR-FIX-{imp.import_file_id}-{len(fields)}-{fields.get('status', 'x')[:3]}",
        import_file_id=imp.import_file_id,
        declaration_46_no="46-FIX-001",
        customs_office_name="Alexandria Port Customs",
        status="Customs Duties Assessed - Ready for Payment",
        owner="tester",
    )
    values.update(fields)
    rec = CustomsClearanceRecord(**values)
    db.add(rec)
    db.commit()
    db.refresh(rec)
    return rec


def _assessed(db, imp, total=1000.0, **fields):
    values = dict(import_duty_amount=total, total_duty_payable=total, actual_duty_total=total,
                  assessment_status="Assessed", nafeza_claim_number="CLM-FIX-001",
                  payment_status="Payment Requested")
    values.update(fields)
    return _clearance(db, imp, **values)


def _payment(imp, amount):
    return CustomsDutyPaymentSubmit(import_file_id=imp.import_file_id, bank_receipt_no="RCP-FIX-1",
                                    sadad_number="SAD-FIX-1", paying_bank_name="CIB", duty_paid_amount=amount)


def _provider(db, pid):
    db.add(ExternalServiceProvider(provider_id=pid, partner_code=f"ESP-F{pid}", partner_name=f"Broker {pid}",
                                   partner_type="Customs Broker"))
    db.commit()


# ─── CL-01 / CCQ-01: permissions ─────────────────────────────────────────────

def _make_user(db, username, role_code) -> User:
    role = db.query(Role).filter(Role.role_code == role_code).one()
    user = User(username=username, email=f"{username}@test.com", full_name=username,
                hashed_password=hash_password("Password123"), role=role.role_code, role_id=role.role_id, is_active=True)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _bearer(user):
    return {"Authorization": f"Bearer {create_access_token({'sub': str(user.user_id), 'role': user.role})}"}


@pytest.fixture
def strict(session_factory, monkeypatch):
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)
    session = session_factory()
    seed_rbac(session)
    users = {
        "viewer": _make_user(session, "cc_viewer", "AUDITOR_VIEWER"),
        "customs": _make_user(session, "cc_customs", "CUSTOMS_OFFICER"),
        "admin": _make_user(session, "cc_admin", "ADMIN"),
    }
    app = FastAPI()
    app.include_router(cc_router.router)
    app.include_router(ccq_router.router)

    def override_get_db():
        s = session_factory()
        try:
            yield s
        finally:
            s.close()

    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app, raise_server_exceptions=False), users, session
    session.close()


VIEWER_DENIED = [
    ("POST", "/api/v1/customs-clearance"),
    ("POST", "/api/v1/customs-clearance/record-duty-payment"),
    ("POST", "/api/v1/customs-clearance/issue-final-release"),
    ("POST", "/api/v1/customs-clearance/1/complete-release"),
    ("POST", "/api/v1/customs-clearance/1/pay-duty"),
    ("PUT", "/api/v1/customs-clearance/1"),
    ("POST", "/api/v1/customs-clearance/invoices"),
    ("DELETE", "/api/v1/customs-clearance/invoices/1"),
    ("DELETE", "/api/v1/customs-clearance/1"),
    ("POST", "/api/v1/customs-clearance-quotations/rfqs"),
    ("POST", "/api/v1/customs-clearance-quotations/rfqs/1/award"),
    ("DELETE", "/api/v1/customs-clearance-quotations/quotations/1"),
    ("POST", "/api/v1/customs-clearance-quotations/price-list"),
]


@pytest.mark.parametrize("method,path", VIEWER_DENIED)
def test_viewer_is_denied_mutations(strict, method, path):
    client, users, _ = strict
    res = client.request(method, path, json={}, headers=_bearer(users["viewer"]))
    assert res.status_code == 403, res.text


@pytest.mark.parametrize("path", ["/api/v1/customs-clearance", "/api/v1/customs-clearance-quotations/rfqs"])
def test_viewer_can_read_and_anonymous_is_401(strict, path):
    client, users, _ = strict
    assert client.get(path, headers=_bearer(users["viewer"])).status_code == 200
    assert client.get(path).status_code == 401


def test_release_needs_release_permission_but_update_passes_auth(strict):
    client, users, _ = strict
    # CUSTOMS_OFFICER holds view / update / release: past auth the empty body is a 422.
    assert client.post("/api/v1/customs-clearance/issue-final-release", json={}, headers=_bearer(users["customs"])).status_code == 422
    assert client.post("/api/v1/customs-clearance/record-duty-payment", json={}, headers=_bearer(users["customs"])).status_code == 422


def test_audit_user_comes_from_the_token(strict):
    client, users, session = strict
    imp = _import_file(session)
    res = client.post("/api/v1/customs-clearance", json={"import_file_id": imp.import_file_id},
                      headers=_bearer(users["admin"]))
    assert res.status_code == 201, res.text
    body = res.json()
    assert body["created_by"] == "cc_admin"
    assert body["updated_by"] == "cc_admin"
    assert body["owner"] == "cc_admin"  # defaults to the acting user, never a hard-coded name (CL-17)


# ─── CL-02 / CL-05 / CL-06 / CL-07: payment and release guards ──────────────

def test_release_with_foreign_clearance_id_is_400(db):
    imp_a = _import_file(db, "IMP-FIX-A")
    imp_b = _import_file(db, "IMP-FIX-B")
    rec_b = _assessed(db, imp_b, payment_status="Paid & Verified", duty_paid_amount=1000.0)
    with pytest.raises(HTTPException) as exc:
        issue_final_customs_release_service(db, CustomsFinalReleaseSubmit(
            import_file_id=imp_a.import_file_id, clearance_id=rec_b.customs_clearance_id, release_permit_no="REL-001"))
    assert exc.value.status_code == 400
    assert exc.value.detail["code"] == "CC_RELEASE_RECORD_FILE_MISMATCH"
    db.refresh(imp_a)
    db.refresh(rec_b)
    assert imp_a.is_customs_released is False
    assert rec_b.release_permit_no is None


def test_payment_without_assessment_is_409_and_creates_no_record(db):
    imp = _import_file(db)
    with pytest.raises(HTTPException) as exc:
        record_customs_duty_payment_service(db, _payment(imp, 500.0))
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "CC_DUTY_NOT_ASSESSED"
    assert db.query(CustomsClearanceRecord).count() == 0


def test_partial_payment_is_400_and_full_payment_keeps_assessed_total(db):
    imp = _import_file(db)
    rec = _assessed(db, imp, total=1000.0)
    with pytest.raises(HTTPException) as exc:
        record_customs_duty_payment_service(db, _payment(imp, 999.98))
    assert exc.value.status_code == 400
    assert exc.value.detail["code"] == "CC_DUTY_UNDERPAID"
    assert exc.value.detail["assessed_amount"] == 1000.0

    paid = record_customs_duty_payment_service(db, _payment(imp, 1200.0), user="payer")
    assert paid.duty_paid_amount == 1200.0
    assert paid.actual_duty_total == 1000.0  # no longer overwritten by the paid amount
    assert paid.updated_by == "payer"
    assert paid.customs_clearance_id == rec.customs_clearance_id


def test_release_blocked_for_partially_paid_record_on_both_routes(db):
    imp = _import_file(db, acid_expiry_date=date.today() + timedelta(days=30))
    rec = _assessed(db, imp, total=1000.0, payment_status="Paid & Verified", duty_paid_amount=400.0)
    imp.customs_duty_payment_status = "PAID"
    db.commit()
    with pytest.raises(HTTPException) as main_route:
        issue_final_customs_release_service(db, CustomsFinalReleaseSubmit(
            import_file_id=imp.import_file_id, release_permit_no="REL-002"))
    assert main_route.value.detail["code"] == "CC_DUTY_UNDERPAID"
    with pytest.raises(HTTPException) as legacy_route:
        complete_customs_release_service(db, rec.customs_clearance_id, CompleteReleaseSubmit(
            release_permit_no="REL-002", release_date=datetime.now(timezone.utc)))
    assert legacy_route.value.status_code == 400
    assert legacy_route.value.detail["code"] == "CC_DUTY_UNDERPAID"


def test_release_without_record_is_400_and_does_not_create_one(db):
    imp = _import_file(db, customs_duty_payment_status="PAID", customs_duty_paid_amount=5000.0)
    with pytest.raises(HTTPException) as exc:
        issue_final_customs_release_service(db, CustomsFinalReleaseSubmit(
            import_file_id=imp.import_file_id, release_permit_no="REL-003"))
    assert exc.value.status_code == 400
    assert exc.value.detail["code"] == "CC_DUTY_NOT_PAID"
    assert db.query(CustomsClearanceRecord).count() == 0


def test_assess_requires_declaration_46(db):
    imp = _import_file(db)
    _clearance(db, imp, declaration_46_no=None, status="Inspection & Sampling Recorded")
    with pytest.raises(HTTPException) as exc:
        assess_final_customs_duties_service(db, FinalDutyAssessmentSubmit(
            import_file_id=imp.import_file_id, nafeza_claim_number="CLM-1", cif_base_amount=1.0,
            import_duty_amount=1.0, vat_amount=1.0))
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "CC_ASSESS_REQUIRES_DECLARATION_46"


def test_failing_side_effect_does_not_undo_the_payment(db, monkeypatch):
    imp = _import_file(db)
    _assessed(db, imp, total=1000.0)

    def broken_notify(*args, **kwargs):
        raise RuntimeError("notification store down")

    monkeypatch.setattr(cc_service, "_notify", broken_notify)
    paid = record_customs_duty_payment_service(db, _payment(imp, 1000.0))
    assert paid.payment_status == "Paid & Verified"
    db.expire_all()
    assert db.query(CustomsClearanceRecord).one().duty_paid_amount == 1000.0
    assert db.query(SmartTask).filter(SmartTask.task_type == "CUSTOMS_FINAL_RELEASE").count() == 1


# ─── CL-03 / CL-04: generic PUT ──────────────────────────────────────────────

def test_put_ignores_workflow_fields(db):
    imp = _import_file(db)
    rec = _assessed(db, imp, total=1000.0)
    body = {"payment_status": "Paid & Verified", "status": "Final Release Granted", "duty_paid_amount": 1000.0,
            "actual_duty_total": 1.0, "notes": "edited"}
    updated = update_customs_clearance_service(db, rec.customs_clearance_id, CustomsClearanceUpdate(**body), user="editor")
    assert updated.payment_status == "Payment Requested"
    assert updated.status == "Customs Duties Assessed - Ready for Payment"
    assert updated.duty_paid_amount == 0.0
    assert updated.actual_duty_total == 1000.0
    assert updated.notes == "edited"
    assert updated.updated_by == "editor"


# customs_office_name is nullable since BE67-T17 (no invented office), so a PUT null on it is accepted.
@pytest.mark.parametrize("field", ["vat_amount", "estimated_duty_total"])
def test_put_null_on_money_or_required_field_is_400(db, field):
    imp = _import_file(db)
    rec = _assessed(db, imp)
    with pytest.raises(HTTPException) as exc:
        update_customs_clearance_service(db, rec.customs_clearance_id, CustomsClearanceUpdate(**{field: None}))
    assert exc.value.status_code == 400
    assert exc.value.detail["code"] == "CC_UPDATE_NULL_NOT_ALLOWED"
    assert field in exc.value.detail["fields"]


# ─── CL-16: restore ──────────────────────────────────────────────────────────

def test_restore_with_another_active_record_is_409(db):
    imp = _import_file(db)
    first = _clearance(db, imp, clearance_code="CLR-FIX-R1")
    soft_delete_customs_clearance_service(db, first.customs_clearance_id)
    _clearance(db, imp, clearance_code="CLR-FIX-R2")
    with pytest.raises(HTTPException) as exc:
        restore_customs_clearance_service(db, first.customs_clearance_id)
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "CC_RESTORE_DUPLICATE_ACTIVE"


# ─── CL-08: under-bond and lab results ───────────────────────────────────────

def _under_bond(db, rec):
    return issue_under_bond_release_service(db, rec.customs_clearance_id, UnderBondReleaseSubmit(
        bond_guarantee_ref="BOND-001", temporary_release_date=datetime.now(timezone.utc)))


def test_under_bond_refused_twice_or_after_final_release(db):
    imp = _import_file(db)
    rec = _assessed(db, imp)
    bonded = _under_bond(db, rec)
    assert "Factory bonded warehouse" in bonded.notes
    with pytest.raises(HTTPException) as again:
        _under_bond(db, rec)
    assert again.value.status_code == 409

    imp2 = _import_file(db, "IMP-FIX-REL")
    released = _clearance(db, imp2, status="Final Release Granted")
    with pytest.raises(HTTPException) as after_release:
        _under_bond(db, released)
    assert after_release.value.detail["code"] == "CC_UNDER_BOND_NOT_ALLOWED"


def test_lab_legacy_arabic_label_is_stored_as_code_and_unpaid_duty_blocks_release(db):
    imp = _import_file(db)
    rec = _assessed(db, imp, total=1000.0)
    _under_bond(db, rec)
    result = record_lab_result_and_lift_quarantine_service(db, rec.customs_clearance_id, LabTestResultSubmit(
        lab_test_result="مطابق", lab_certificate_number="LAB-1", test_completion_date=datetime.now(timezone.utc)))
    assert result.lab_test_result == "CONFORMING"
    assert result.quarantine_lock is False
    assert result.dispatch_authorized is False
    assert result.status == "Under Bond Released"
    db.refresh(imp)
    assert imp.is_customs_released is False


def test_lab_conforming_with_paid_duty_releases(db):
    imp = _import_file(db)
    rec = _assessed(db, imp, total=1000.0, payment_status="Paid & Verified", duty_paid_amount=1000.0)
    _under_bond(db, rec)
    result = record_lab_result_and_lift_quarantine_service(db, rec.customs_clearance_id, LabTestResultSubmit(
        lab_test_result="conforming", lab_certificate_number="LAB-2", test_completion_date=datetime.now(timezone.utc)),
        can_release=True)
    assert result.lab_test_result == "CONFORMING"
    assert result.status == "Final Release Granted"
    assert result.dispatch_authorized is True
    db.refresh(imp)
    assert imp.is_customs_released is True

    # Re-entry after the lock is lifted / final release: 409.
    with pytest.raises(HTTPException) as again:
        record_lab_result_and_lift_quarantine_service(db, rec.customs_clearance_id, LabTestResultSubmit(
            lab_test_result="NON_CONFORMING", lab_certificate_number="LAB-2B",
            test_completion_date=datetime.now(timezone.utc)), can_release=True)
    assert again.value.status_code == 409
    assert again.value.detail["code"] == "CC_LAB_RESULT_ALREADY_FINAL"


def test_lab_conforming_without_release_permission_only_lifts_the_lock(db):
    imp = _import_file(db)
    rec = _assessed(db, imp, total=1000.0, payment_status="Paid & Verified", duty_paid_amount=1000.0)
    _under_bond(db, rec)
    result = record_lab_result_and_lift_quarantine_service(db, rec.customs_clearance_id, LabTestResultSubmit(
        lab_test_result="CONFORMING", lab_certificate_number="LAB-5", test_completion_date=datetime.now(timezone.utc)),
        can_release=False)
    assert result.quarantine_lock is False
    assert result.status == "Under Bond Released"
    assert result.dispatch_authorized is False
    db.refresh(imp)
    assert imp.is_customs_released is False


def test_lab_result_via_api_respects_release_permission(strict):
    client, users, session = strict
    imp = _import_file(session)
    rec = _assessed(session, imp, total=1000.0, payment_status="Paid & Verified", duty_paid_amount=1000.0,
                    is_under_bond_release=True, quarantine_lock=True, status="Under Bond Released")
    body = {"lab_test_result": "CONFORMING", "lab_certificate_number": "LAB-API",
            "test_completion_date": datetime.now(timezone.utc).isoformat()}
    res = client.post(f"/api/v1/customs-clearance/{rec.customs_clearance_id}/lab-test-result", json=body,
                      headers=_bearer(users["admin"]))
    assert res.status_code == 200, res.text
    assert res.json()["status"] == "Final Release Granted"


def test_release_refused_while_quarantine_locked(db):
    imp = _import_file(db)
    rec = _assessed(db, imp, total=1000.0, payment_status="Paid & Verified", duty_paid_amount=1000.0,
                    is_under_bond_release=True, quarantine_lock=True, status="Under Bond Released")
    with pytest.raises(HTTPException) as main_route:
        issue_final_customs_release_service(db, CustomsFinalReleaseSubmit(
            import_file_id=imp.import_file_id, release_permit_no="REL-Q1"))
    assert main_route.value.status_code == 409
    assert main_route.value.detail["code"] == "CC_RELEASE_QUARANTINE_LOCKED"
    with pytest.raises(HTTPException) as legacy_route:
        complete_customs_release_service(db, rec.customs_clearance_id, CompleteReleaseSubmit(release_permit_no="REL-Q1"))
    assert legacy_route.value.detail["code"] == "CC_RELEASE_QUARANTINE_LOCKED"


def test_legacy_screen_payloads_are_accepted(strict):
    """The current Flutter screen posts only these keys to /{id}/pay-duty and /{id}/complete-release."""
    client, users, session = strict
    imp = _import_file(session, acid_expiry_date=date.today() + timedelta(days=30))
    rec = _assessed(session, imp, total=1000.0)
    headers = _bearer(users["admin"])
    pay = client.post(f"/api/v1/customs-clearance/{rec.customs_clearance_id}/pay-duty", headers=headers,
                      json={"bank_receipt_no": "RCP-SCREEN-1", "actual_duty_total": 1000.0,
                            "duty_variance_reason": None})
    assert pay.status_code == 200, pay.text
    assert pay.json()["payment_status"] == "Paid & Verified"
    assert pay.json()["actual_duty_total"] == 1000.0
    release = client.post(f"/api/v1/customs-clearance/{rec.customs_clearance_id}/complete-release", headers=headers,
                          json={"release_permit_no": "REL-SCREEN-1"})
    assert release.status_code == 200, release.text
    assert release.json()["status"] == "Final Release Granted"


def test_lab_unknown_result_is_rejected_by_the_schema():
    with pytest.raises(ValidationError):
        LabTestResultSubmit(lab_test_result="maybe", lab_certificate_number="LAB-3",
                            test_completion_date=datetime.now(timezone.utc))
    assert LabTestResultSubmit(lab_test_result="Non-Conforming", lab_certificate_number="LAB-4",
                               test_completion_date=datetime.now(timezone.utc)).lab_test_result == "NON_CONFORMING"


# ─── CL-05 invoices: FX rate, file match, task close, codes ──────────────────

def _invoice(imp, **fields):
    values = dict(import_file_id=imp.import_file_id, invoice_number="INV-1", provider_name="Provider",
                  expense_category="BROKER_FEES", amount_egp=100.0)
    values.update(fields)
    return ClearanceExpenseInvoiceCreate(**values)


def test_foreign_currency_invoice_without_rate_is_400(db):
    imp = _import_file(db)
    with pytest.raises(HTTPException) as exc:
        record_clearance_invoice_service(db, _invoice(imp, currency="USD", amount_fx=100.0, amount_egp=0.0))
    assert exc.value.status_code == 400
    assert exc.value.detail["code"] == "CC_INVOICE_FX_RATE_REQUIRED"
    egp = record_clearance_invoice_service(db, _invoice(imp, currency="EGP", amount_fx=50.0, amount_egp=0.0))
    assert egp.amount_egp == 50.0
    assert egp.exchange_rate == 1.0


def test_invoice_linked_to_another_files_record_is_400(db):
    imp_a = _import_file(db, "IMP-FIX-IA")
    imp_b = _import_file(db, "IMP-FIX-IB")
    rec_b = _clearance(db, imp_b)
    with pytest.raises(HTTPException) as exc:
        record_clearance_invoice_service(db, _invoice(imp_a, customs_clearance_id=rec_b.customs_clearance_id))
    assert exc.value.detail["code"] == "CC_INVOICE_RECORD_FILE_MISMATCH"


def test_cl05_task_closes_with_english_note(db):
    imp = _import_file(db)
    _clearance(db, imp)
    db.add(SmartTask(task_code="CL-05", title="Record clearance invoices", task_type="Manual To-Do",
                     import_file_id=imp.import_file_id, status="Pending"))
    db.add(SmartTask(task_code="TASK-X1", title="Invoices", task_type="CLEARANCE_INVOICES",
                     import_file_id=imp.import_file_id, status="In Progress"))
    db.commit()
    record_clearance_invoice_service(db, _invoice(imp, invoice_number="INV-TASK"), current_user="clerk")
    tasks = db.query(SmartTask).filter(SmartTask.import_file_id == imp.import_file_id).all()
    assert {t.status for t in tasks} == {"Completed"}
    assert all("INV-TASK" in t.notes for t in tasks)


def test_invoice_code_has_no_collision_and_restarts_per_year(db):
    imp = _import_file(db)
    year = datetime.now().year
    for code in (f"CLI-{year - 1}-0007", f"CLI-{year}-0002"):
        db.add(ClearanceExpenseInvoice(invoice_code=code, import_file_id=imp.import_file_id, invoice_number="OLD",
                                       provider_name="Old", expense_category="BROKER_FEES", is_active=False))
    db.commit()
    inv = record_clearance_invoice_service(db, _invoice(imp))
    assert inv.invoice_code == f"CLI-{year}-0003"  # count()+1 would have produced a duplicate


# ─── Quotations (CCQ-02..09) ─────────────────────────────────────────────────

def _rfq_with_quotes(db, *quotes):
    for pid in {q.get("provider_id", 1) for q in quotes} | {1}:
        if not db.get(ExternalServiceProvider, pid):
            _provider(db, pid)
    rfq = create_rfq_service(db, CustomsClearanceRFQCreate(title="RFQ fix", port_name="Alexandria Port"))
    created = []
    for q in quotes:
        values = dict(provider_id=1, provider_name="Broker 1", clearance_fee=100.0)
        values.update(q)
        created.append(add_quotation_service(db, rfq.rfq_id, CustomsClearanceQuotationCreate(**values)))
    return rfq, created


def test_quote_delete_is_soft_and_awarded_quote_cannot_be_deleted(db):
    rfq, (q1, q2) = _rfq_with_quotes(db, {"clearance_fee": 100.0}, {"clearance_fee": 50.0})
    # Soft delete while the RFQ is open (BE67-T19: once awarded, every quotation of the RFQ is locked).
    delete_quotation_service(db, q2.quotation_id)
    row = db.get(CustomsClearanceQuotationItem, q2.quotation_id)
    assert row is not None and row.is_active is False
    db.refresh(rfq)
    assert rfq.lowest_clearance_cost == 100.0

    award_quotation_service(db, rfq.rfq_id, q1.quotation_id)
    with pytest.raises(HTTPException) as exc:
        delete_quotation_service(db, q1.quotation_id)
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] in ("CCQ_RFQ_AWARDED", "CCQ_AWARDED_QUOTE_DELETE")


def test_award_on_deleted_rfq_is_404_cancelled_409_expired_400(db):
    rfq, (q1,) = _rfq_with_quotes(db, {"validity_date": date.today() - timedelta(days=1)})
    with pytest.raises(HTTPException) as expired:
        award_quotation_service(db, rfq.rfq_id, q1.quotation_id)
    assert expired.value.detail["code"] == "CCQ_QUOTE_EXPIRED"

    update_rfq_service(db, rfq.rfq_id, CustomsClearanceRFQUpdate(status="Cancelled"))
    with pytest.raises(HTTPException) as cancelled:
        award_quotation_service(db, rfq.rfq_id, q1.quotation_id)
    assert cancelled.value.status_code == 409

    delete_rfq_service(db, rfq.rfq_id)
    with pytest.raises(HTTPException) as deleted:
        award_quotation_service(db, rfq.rfq_id, q1.quotation_id)
    assert deleted.value.status_code == 404


@pytest.mark.parametrize("new_status", ["Awarded", "Whatever"])
def test_rfq_put_status_is_validated(db, new_status):
    rfq, _ = _rfq_with_quotes(db)
    with pytest.raises(HTTPException) as exc:
        update_rfq_service(db, rfq.rfq_id, CustomsClearanceRFQUpdate(status=new_status))
    assert exc.value.detail["code"] == "CCQ_RFQ_STATUS_INVALID"
    db.refresh(rfq)
    assert rfq.status == "Draft"


def test_quote_total_is_server_computed_and_mixed_currency_lowest_uses_egp(db):
    rfq, (egp, usd) = _rfq_with_quotes(
        db,
        {"clearance_fee": 300.0, "total_cost": 1.0},
        {"clearance_fee": 10.0, "currency": "USD"},
    )
    assert egp.total_cost == 300.0
    db.refresh(rfq)
    assert rfq.lowest_clearance_cost == 300.0


def test_quote_needs_an_active_provider(db):
    rfq = create_rfq_service(db, CustomsClearanceRFQCreate(title="RFQ fix", port_name="Alexandria Port"))
    with pytest.raises(HTTPException) as exc:
        add_quotation_service(db, rfq.rfq_id, CustomsClearanceQuotationCreate(
            provider_id=99, provider_name="Ghost", clearance_fee=10.0))
    assert exc.value.status_code == 400
    with pytest.raises(HTTPException):
        create_rfq_service(db, CustomsClearanceRFQCreate(
            title="RFQ nested", port_name="Alexandria Port",
            quotations=[CustomsClearanceQuotationCreate(provider_id=99, provider_name="Ghost", clearance_fee=10.0)]))
    assert db.query(CustomsClearanceRFQ).count() == 1


def test_rfq_codes_continue_from_the_highest_suffix(db):
    db.add(CustomsClearanceRFQ(rfq_code="CRFQ-000005", title="Old", port_name="P", is_active=False))
    db.commit()
    rfq = create_rfq_service(db, CustomsClearanceRFQCreate(title="RFQ next", port_name="Alexandria Port"))
    assert rfq.rfq_code == "CRFQ-000006"


def test_price_list_date_range_is_validated_on_create_and_update(db):
    _provider(db, 1)  # BE67-T19: price items need an active provider (master data)
    item_data = dict(provider_id=1, provider_name="Broker 1", port_name="Alexandria", unit_price=10.0)
    with pytest.raises(HTTPException) as exc:
        create_price_item_service(db, ClearancePriceListItemCreate(
            **item_data, effective_from=date(2026, 5, 1), effective_to=date(2026, 1, 1)))
    assert exc.value.detail["code"] == "CCQ_PRICE_LIST_DATE_RANGE"
    item = create_price_item_service(db, ClearancePriceListItemCreate(**item_data, effective_from=date(2026, 5, 1)))
    with pytest.raises(HTTPException):
        update_price_item_service(db, item.price_item_id, ClearancePriceListItemUpdate(effective_to=date(2026, 1, 1)))


# ─── customs-rules review follow-ups ─────────────────────────────────────────

def test_payment_requires_assessed_status(db):
    imp = _import_file(db)
    _assessed(db, imp, total=1000.0, assessment_status="Discrepancy")
    with pytest.raises(HTTPException) as exc:
        record_customs_duty_payment_service(db, _payment(imp, 1000.0))
    assert exc.value.detail["code"] == "CC_DUTY_NOT_ASSESSED"


def test_cl02_keeps_unsent_components_and_never_defaults_the_rate(db):
    imp = _import_file(db)
    _clearance(db, imp, development_fee_amount=40.0, customs_service_fees=60.0, customs_exchange_rate=50.25)
    rec = assess_final_customs_duties_service(db, FinalDutyAssessmentSubmit(
        import_file_id=imp.import_file_id, nafeza_claim_number="CLM-KEEP", cif_base_amount=1000.0,
        import_duty_amount=100.0, vat_amount=200.0))
    assert rec.development_fee_amount == 40.0
    assert rec.customs_service_fees == 60.0
    assert rec.total_duty_payable == 400.0
    assert rec.customs_exchange_rate == 50.25


def test_foreign_invoice_with_egp_amount_stores_implied_or_no_rate(db):
    imp = _import_file(db)
    implied = record_clearance_invoice_service(db, _invoice(imp, currency="USD", amount_fx=100.0, amount_egp=4850.0))
    assert implied.exchange_rate == 48.5
    no_fx = record_clearance_invoice_service(db, _invoice(imp, invoice_number="INV-2", currency="USD", amount_egp=500.0))
    assert no_fx.exchange_rate is None
    assert no_fx.amount_egp == 500.0


def test_quote_currency_compared_case_insensitively(db):
    rfq, _ = _rfq_with_quotes(db, {"clearance_fee": 300.0, "currency": "egp"}, {"clearance_fee": 200.0, "currency": "EGP"})
    db.refresh(rfq)
    assert rfq.lowest_clearance_cost == 200.0
