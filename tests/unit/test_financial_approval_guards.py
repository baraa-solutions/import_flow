"""
Phase 2 (financial approval) regression tests for the quality fixes in docs/plans/phase-02-quality-plan.md:
RBAC (FA-01), workflow guards (FA-02/03/19/20), FX (FA-04), SWIFT (FA-05/06), validation (FA-10/12/16),
code generation (FA-13), atomic follow-ups (FA-07/09), prefill (FA-21/26) and file codes (FA-25).
"""
import base64
import importlib
from datetime import date, timedelta

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from pydantic import ValidationError

import modules.auth.permissions as auth_permissions
import modules.financial_approval.repository as repo
import modules.financial_approval.service as service
from database.database import get_db
from modules.auth.permissions import invalidate_permission_cache
from modules.auth.security import create_access_token, hash_password
from modules.auth.seed_rbac import seed_rbac
from modules.financial_approval.model import (
    ImportBudgetApproval,
    OcrCorrectionsLog,
    PaymentRequestSession,
    SwiftExtractionBatch,
)
from modules.financial_approval.schemas import (
    ClonePaymentRequestRequest,
    ImportBudgetCreate,
    ImportBudgetUpdate,
    PaymentRequestCreate,
    PaymentRequestUpdate,
    SmartSwiftFileExtractRequest,
    SmartSwiftReconcileRequest,
    SwiftBatchConfirmRequest,
    SwiftBatchReconcileRequest,
    SwiftFieldUpdateRequest,
    SwiftReconciliationRequest,
)
from modules.shipping_scenarios.model import ShippingEvaluationSession, ShippingScenarioItem
from modules.smart_tasks.model import SmartTask
from modules.users.model import Role, User

from test_phase02_support import (
    admin_user,
    make_session,
    plain_user,
    seed_budget,
    seed_consultation,
    seed_file,
    seed_rate,
)

fa_router = importlib.import_module("modules.financial_approval.router")

# Same OCR sample as tests/unit/test_swift_review_layer.py (USD 43,704.00, ref FT/26228/KZ70Q).
SWIFT_TEXT = """
(1:F01ARAIEGCXXXXX.SN...ISN.）(2:I103CITIUS33XXXXN)(3:(108:XXXXX))(4:
:2O/TRANSACTION REFERENCE NUMBER
FT/26228/KZ70Q
:2BB/BANKOPERATIONCODE
:CRED
:B2A/Value Date,CCY,Amount
260818U5D43704,00
:5OK/ORDERING CUST
/EG780057004001017153610010101
SCAS FOR CONSTRUCTION AND FINISHING
ROAD18
EGYPT,44 ROAD 18
SARIAT EL MAADICAIRO
57A/Accountwith Bank
PCBCCNBJJSS
59/BeneficiaryCustomer
/32250198613609841015
SUZHOU YUHENG TEXTILE CO.,LTD
16 KANGSHENG ROAD ZHITANG TOWN
CHANGSHU CITY SUZHOU CHINA
7O/DETAILS OFPAYMENT
EG0010040 PI NO.YH20260730.6
ALL DOCUMENTS SHOULD BE TRADED
THROUGH AAIB
ZA/DETAILS OF CHARGES
:SHA
"""


@pytest.fixture
def db():
    session = make_session()
    seed_rate(session, "USD", 50.0)
    seed_rate(session, "EUR", 55.0)
    invalidate_permission_cache()
    try:
        yield session
    finally:
        invalidate_permission_cache()
        session.close()


def _payment(db, amount=10000.0, currency="USD", payment_type="Final Settlement", import_file_id=None, **extra):
    return service.create_payment_request_service(db, PaymentRequestCreate(
        title=extra.pop("title", "Guard payment"),
        supplier_name="Supplier Co",
        payment_type=payment_type,
        requested_amount=amount,
        currency_code=currency,
        exchange_rate=extra.pop("exchange_rate", 50.0),
        due_date=date(2026, 9, 1),
        request_date=date(2026, 8, 10),
        import_file_id=import_file_id,
        **extra,
    ))


def _approved(db, **kw):
    p = _payment(db, **kw)
    return service.approve_payment_request_service(db, p.payment_id)


def _swift(ref="MT103-1", amount=10000.0, currency="USD"):
    return SwiftReconciliationRequest(swift_reference_no=ref, swift_receipt_date=date(2026, 8, 14),
                                      swift_transferred_amount=amount, swift_transferred_currency=currency)


def _code(exc) -> str:
    return exc.value.detail["code"]


# ─── FA-02: payment workflow guards ──────────────────────────────────────────

def test_pay_and_reconcile_on_draft_are_rejected(db):
    p = _payment(db)
    with pytest.raises(HTTPException) as exc:
        service.execute_payment_service(db, p.payment_id, "SWF-X")
    assert exc.value.status_code == 400 and _code(exc) == "FA_PAYMENT_STATUS_INVALID"
    with pytest.raises(HTTPException) as exc:
        service.reconcile_swift_service(db, p.payment_id, _swift())
    assert exc.value.status_code == 400
    with pytest.raises(HTTPException) as exc:
        service.smart_reconcile_swift_service(db, SmartSwiftReconcileRequest(
            payment_id=p.payment_id, swift_reference_no="R", swift_receipt_date=date(2026, 8, 14),
            swift_transferred_amount=10000.0))
    assert exc.value.status_code == 400
    db.refresh(p)
    assert p.status == "Draft" and p.swift_reference_no is None


@pytest.mark.parametrize("requested,stored", [("Paid", "Draft"), ("Approved", "Draft"), ("Pending Approval", "Pending Approval"), (None, "Draft")])
def test_create_status_is_server_owned(db, requested, stored):
    p = _payment(db, status=requested)
    assert p.status == stored


def test_approve_only_from_draft_or_pending(db):
    p = _approved(db)
    with pytest.raises(HTTPException) as exc:
        service.approve_payment_request_service(db, p.payment_id)
    assert _code(exc) == "FA_PAYMENT_STATUS_INVALID"


def test_put_on_paid_is_409_and_swift_fields_are_ignored(db):
    p = _payment(db)
    upd = service.update_payment_request_service(db, p.payment_id, PaymentRequestUpdate(
        notes="n", swift_variance_amount=999.0, swift_variance_status="Matched", swift_reference_no="FAKE"))
    assert upd.swift_reference_no is None and upd.swift_variance_status == "Pending" and upd.notes == "n"

    service.approve_payment_request_service(db, p.payment_id)
    service.execute_payment_service(db, p.payment_id, "SWF-PAID")
    with pytest.raises(HTTPException) as exc:
        service.update_payment_request_service(db, p.payment_id, PaymentRequestUpdate(requested_amount=1.0))
    assert exc.value.status_code == 409 and _code(exc) == "FA_PAYMENT_LOCKED"
    assert exc.value.detail["message"] == "لا يمكن تعديل طلب صرف معتمد أو مدفوع."


def test_draft_put_saves_beneficiary_swift_code(db):
    """Review fix: swift_code (beneficiary BIC) is editable; only the SWIFT reconciliation fields are server-owned."""
    p = _payment(db)
    upd = service.update_payment_request_service(db, p.payment_id, PaymentRequestUpdate(swift_code="NBEGEGCX", swift_reference_no="FAKE"))
    assert upd.swift_code == "NBEGEGCX"
    assert upd.swift_reference_no is None
    db.expire_all()
    assert db.query(PaymentRequestSession).filter_by(payment_id=p.payment_id).one().swift_code == "NBEGEGCX"


def test_approved_may_only_be_rejected_through_put(db):
    p = _approved(db)
    with pytest.raises(HTTPException) as exc:
        service.update_payment_request_service(db, p.payment_id, PaymentRequestUpdate(requested_amount=5.0))
    assert exc.value.status_code == 409
    rejected = service.update_payment_request_service(db, p.payment_id, PaymentRequestUpdate(status="Rejected", notes="bank refused"))
    assert rejected.status == "Rejected"
    reopened = service.update_payment_request_service(db, p.payment_id, PaymentRequestUpdate(status="Draft"))
    assert reopened.status == "Draft"


# ─── FA-03 / FA-19: budget workflow guards ───────────────────────────────────

def test_budget_put_ignores_status_and_approver(db):
    budget = seed_budget(db, None, status="Pending Review", customs_duties_egp=100.0)
    upd = service.update_import_budget_service(db, budget.budget_id, ImportBudgetUpdate(
        budget_status="Budget Approved", approved_by="Spoofed CFO", customs_duties_egp=200.0))
    assert upd.budget_status == "Pending Review"
    assert upd.approved_by is None and upd.approved_date is None
    assert upd.total_budget_egp == 200.0


@pytest.mark.parametrize("locked", ["Budget Approved", "Superseded"])
def test_budget_put_on_approved_or_superseded_is_409(db, locked):
    budget = seed_budget(db, None, status=locked)
    with pytest.raises(HTTPException) as exc:
        service.update_import_budget_service(db, budget.budget_id, ImportBudgetUpdate(customs_duties_egp=1.0))
    assert exc.value.status_code == 409 and _code(exc) == "FA_BUDGET_LOCKED"


@pytest.mark.parametrize("start", ["Budget Approved", "Superseded", "Rejected"])
def test_budget_approve_status_guard(db, start):
    budget = seed_budget(db, None, status=start)
    budget.approved_date = date(2020, 1, 1)
    db.commit()
    with pytest.raises(HTTPException) as exc:
        service.approve_import_budget_service(db, budget.budget_id, approved_by="cfo")
    assert exc.value.status_code == 409 and _code(exc) == "FA_BUDGET_STATUS_INVALID"
    db.refresh(budget)
    assert budget.approved_date == date(2020, 1, 1)


def test_sync_superseded_budget_is_409(db):
    imp = seed_file(db)
    budget = seed_budget(db, imp.import_file_id, status="Superseded")
    with pytest.raises(HTTPException) as exc:
        service.sync_budget_with_upstream_service(db, budget.budget_id, current_user=admin_user())
    assert exc.value.status_code == 409


# ─── FA-20: soft delete / restore ────────────────────────────────────────────

def test_delete_paid_or_approved_payment_is_409(db):
    p = _approved(db)
    with pytest.raises(HTTPException) as exc:
        service.soft_delete_payment_request_service(db, p.payment_id)
    assert exc.value.status_code == 409
    service.execute_payment_service(db, p.payment_id, "SWF-DEL")
    with pytest.raises(HTTPException) as exc:
        service.soft_delete_payment_request_service(db, p.payment_id)
    assert exc.value.status_code == 409


def test_delete_approved_budget_is_409(db):
    budget = seed_budget(db, None, status="Budget Approved")
    with pytest.raises(HTTPException) as exc:
        service.soft_delete_import_budget_service(db, budget.budget_id)
    assert exc.value.status_code == 409


def test_restore_reruns_duplicate_guards(db):
    imp = seed_file(db)
    first = _payment(db, payment_type="ADVANCE_PAYMENT", import_file_id=imp.import_file_id)
    service.soft_delete_payment_request_service(db, first.payment_id)
    _payment(db, payment_type="ADVANCE_PAYMENT", import_file_id=imp.import_file_id)
    with pytest.raises(HTTPException) as exc:
        service.restore_payment_request_service(db, first.payment_id)
    assert _code(exc) == "FA_PAYMENT_DUPLICATE_TYPE"

    b1 = seed_budget(db, imp.import_file_id, status="Draft")
    service.soft_delete_import_budget_service(db, b1.budget_id)
    seed_budget(db, imp.import_file_id, status="Draft")
    with pytest.raises(HTTPException) as exc:
        service.restore_import_budget_service(db, b1.budget_id)
    assert _code(exc) == "FA_BUDGET_DUPLICATE_FILE"


# ─── FA-04: no fallback rate ─────────────────────────────────────────────────

def test_create_schemas_require_exchange_rate():
    with pytest.raises(ValidationError):
        PaymentRequestCreate(title="No rate", supplier_name="Sup", requested_amount=1.0, due_date=date(2026, 9, 1))
    with pytest.raises(ValidationError):
        ImportBudgetCreate(title="No rate budget")


def test_prefill_without_rate_is_400(db):
    seed_rate(db, "GBP", 0.0, base=False)  # currency row without a usable rate
    imp = seed_file(db, estimated_cost=100.0, estimated_cost_currency="GBP")
    with pytest.raises(HTTPException) as exc:
        service.get_budget_prefill_service(db, imp.import_file_id)
    assert exc.value.status_code == 400 and _code(exc) == "FA_FX_RATE_MISSING"
    assert exc.value.detail["currency_code"] == "GBP"

    imp2 = seed_file(db, estimated_cost=100.0, estimated_cost_currency="CHF")  # no currency row at all
    with pytest.raises(HTTPException) as exc:
        service.get_budget_prefill_service(db, imp2.import_file_id)
    assert exc.value.detail["currency_code"] == "CHF"


def test_prefill_empty_file_needs_no_rate(db):
    """Review fix: a new file with no invoice amount does not 400 when its currency has no rate."""
    imp = seed_file(db, estimated_cost=0.0, estimated_cost_currency="CHF")
    imp.invoices_data = None
    db.commit()
    prefill = service.get_budget_prefill_service(db, imp.import_file_id)
    assert prefill.total_invoice_amount == 0.0 and prefill.total_invoice_amount_egp == 0.0
    assert prefill.exchange_rate == 50.0  # default invoice currency USD has a rate in this fixture


def test_prefill_empty_file_without_any_rate_returns_null_rate(db):
    from modules.currencies.model import ExchangeRate
    db.query(ExchangeRate).delete()
    db.commit()
    imp = seed_file(db)
    prefill = service.get_budget_prefill_service(db, imp.import_file_id)
    assert prefill.exchange_rate is None and prefill.estimated_grand_total_egp == 0.0


def _po(db, imp, number, amount, currency_code):
    from modules.currencies.model import Currency
    from modules.purchase_orders.model import PurchaseOrder

    cur = db.query(Currency).filter_by(currency_code=currency_code).one() if currency_code else None
    db.add(PurchaseOrder(po_number=number, import_file_id=imp.import_file_id, total_amount_fob=amount,
                         currency_id=cur.currency_id if cur else 999,  # 999: no such currency row payment_terms="T/T",
                         project_id=1, company_id=1, supplier_id=1, incoterm_id=1))  # FKs not enforced here
    db.commit()


def test_prefill_converts_each_po_at_its_own_currency(db):
    """Customs review #6: USD 1000 (x50) + EUR 1000 (x55) = 105,000 EGP, never 2000 x the last PO's rate."""
    imp = seed_file(db)
    _po(db, imp, "PO-MIX-1", 1000.0, "USD")
    _po(db, imp, "PO-MIX-2", 1000.0, "EUR")
    prefill = service.get_budget_prefill_service(db, imp.import_file_id)
    assert prefill.total_invoice_amount_egp == 105000.0
    assert (prefill.invoice_currency, prefill.exchange_rate, prefill.total_invoice_amount) == ("EGP", 1.0, 105000.0)
    assert {p.currency for p in prefill.linked_pos} == {"USD", "EUR"}


def test_prefill_single_currency_keeps_foreign_amount(db):
    imp = seed_file(db)
    _po(db, imp, "PO-ONE-1", 600.0, "EUR")
    _po(db, imp, "PO-ONE-2", 400.0, "EUR")
    prefill = service.get_budget_prefill_service(db, imp.import_file_id)
    assert (prefill.total_invoice_amount, prefill.invoice_currency, prefill.exchange_rate) == (1000.0, "EUR", 55.0)
    assert prefill.total_invoice_amount_egp == 55000.0


def test_prefill_missing_currency_is_400(db):
    """Customs review #10: an amount without a currency is a 400, not a silent USD."""
    imp = seed_file(db)
    _po(db, imp, "PO-NOCUR", 500.0, None)
    with pytest.raises(HTTPException) as exc:
        service.get_budget_prefill_service(db, imp.import_file_id)
    assert exc.value.status_code == 400 and _code(exc) == "FA_CURRENCY_MISSING"
    assert exc.value.detail["source"] == "PO-NOCUR"

    imp2 = seed_file(db, invoices_data=[{"invoice_no": "PI-7", "amount": 300.0}])
    with pytest.raises(HTTPException) as exc:
        service.get_budget_prefill_service(db, imp2.import_file_id)
    assert exc.value.detail["source"] == "PI-7"


def test_prefill_egp_needs_no_rate_row(db):
    imp = seed_file(db, estimated_cost=1000.0, estimated_cost_currency="EGP")
    prefill = service.get_budget_prefill_service(db, imp.import_file_id)
    assert prefill.exchange_rate == 1.0 and prefill.total_invoice_amount_egp == 1000.0


def test_sync_without_rate_is_400_and_budget_untouched(db):
    imp = seed_file(db, estimated_cost=100.0, estimated_cost_currency="CHF")
    budget = seed_budget(db, imp.import_file_id, status="Pending Review", invoice_amount_egp=5.0)
    with pytest.raises(HTTPException) as exc:
        service.sync_budget_with_upstream_service(db, budget.budget_id, current_user=admin_user())
    assert _code(exc) == "FA_FX_RATE_MISSING"
    db.refresh(budget)
    assert budget.invoice_amount_egp == 5.0


def test_clone_without_rate_is_400(db):
    p = _payment(db)
    db.query(PaymentRequestSession).filter_by(payment_id=p.payment_id).update({"exchange_rate": 0.0})
    db.commit()
    with pytest.raises(HTTPException) as exc:
        service.clone_payment_request_service(db, p.payment_id, ClonePaymentRequestRequest())
    assert _code(exc) == "FA_FX_RATE_MISSING"


# ─── FA-05 / FA-06: SWIFT ────────────────────────────────────────────────────

def test_swift_currency_mismatch_is_400(db):
    p = _approved(db)
    with pytest.raises(HTTPException) as exc:
        service.reconcile_swift_service(db, p.payment_id, _swift(currency="EUR"))
    assert exc.value.status_code == 400 and _code(exc) == "FA_SWIFT_CURRENCY_MISMATCH"
    assert exc.value.detail["swift_currency"] == "EUR" and exc.value.detail["currency_code"] == "USD"


def test_duplicate_swift_reference_is_409(db):
    a = _approved(db, title="Payment A")
    b = _approved(db, title="Payment B")
    service.reconcile_swift_service(db, a.payment_id, _swift(ref="MT103-SAME"))
    with pytest.raises(HTTPException) as exc:
        service.reconcile_swift_service(db, b.payment_id, _swift(ref="MT103-SAME"))
    assert exc.value.status_code == 409 and _code(exc) == "FA_SWIFT_REF_ALREADY_USED"
    assert exc.value.detail["payment_code"] == a.payment_code
    with pytest.raises(HTTPException):
        service.execute_payment_service(db, b.payment_id, "MT103-SAME")


def _confirmed_batch(db):
    batch = service.extract_swift_for_review_service(db, SWIFT_TEXT, "s.txt", "Text File")
    service.confirm_swift_batch_review_service(db, batch.batch_id, SwiftBatchConfirmRequest(), acting_user="reviewer1")
    return batch.batch_id


def test_batch_reconcile_twice_on_another_payment_is_409_same_payment_idempotent(db):
    batch_id = _confirmed_batch(db)
    a = _approved(db, amount=43704.0, title="Payment A")
    b = _approved(db, amount=43704.0, title="Payment B")
    paid = service.reconcile_reviewed_batch_service(db, batch_id, SwiftBatchReconcileRequest(payment_id=a.payment_id))
    assert paid.status == "Paid" and paid.swift_variance_status == "Matched"

    again = service.reconcile_reviewed_batch_service(db, batch_id, SwiftBatchReconcileRequest(payment_id=a.payment_id))
    assert again.payment_id == a.payment_id and again.status == "Paid"

    with pytest.raises(HTTPException) as exc:
        service.reconcile_reviewed_batch_service(db, batch_id, SwiftBatchReconcileRequest(payment_id=b.payment_id))
    assert exc.value.status_code == 409 and _code(exc) == "FA_SWIFT_BATCH_ALREADY_RECONCILED"
    db.refresh(b)
    assert b.status == "Approved"


def test_confirm_requires_pending_review_and_edit_after_confirm_reopens(db):
    batch_id = _confirmed_batch(db)
    with pytest.raises(HTTPException) as exc:
        service.confirm_swift_batch_review_service(db, batch_id, SwiftBatchConfirmRequest())
    assert exc.value.status_code == 409 and _code(exc) == "FA_SWIFT_BATCH_STATUS_INVALID"

    resp = service.update_swift_batch_field_service(db, batch_id, "amount", SwiftFieldUpdateRequest(value="43000", user_name="spoof"),
                                                    acting_user="editor1")
    assert resp.status == "EXTRACTED_PENDING_REVIEW" and resp.reviewed_by is None
    log = db.query(OcrCorrectionsLog).filter_by(batch_id=batch_id).one()
    assert log.corrected_by == "editor1"
    confirmed = service.confirm_swift_batch_review_service(db, batch_id, SwiftBatchConfirmRequest(user_name="spoof"), acting_user="reviewer2")
    assert confirmed.batch.reviewed_by == "reviewer2"
    assert confirmed.message_code == "FA_SWIFT_BATCH_CONFIRMED"


def test_matching_only_lists_approved_requests_without_swift(db):
    batch_id = _confirmed_batch(db)
    draft = _payment(db, amount=43704.0, title="Draft one")
    approved = _approved(db, amount=43704.0, title="Approved one")
    result = service.match_reviewed_batch_service(db, batch_id)
    ids = {c["payment_id"] for c in result.candidate_matches}
    assert approved.payment_id in ids and draft.payment_id not in ids
    targeted = service.match_reviewed_batch_service(db, batch_id, target_payment_id=draft.payment_id)
    assert targeted.matched_payment_request["payment_id"] == draft.payment_id


# ─── FA-10 / FA-12: validation ───────────────────────────────────────────────

def test_payment_type_codes_and_legacy_labels(db):
    p = _payment(db, payment_type="Letter of Credit (L/C)")
    assert p.payment_type == "LETTER_OF_CREDIT"
    with pytest.raises(ValidationError):
        PaymentRequestCreate(title="Bad type", supplier_name="Sup", requested_amount=1.0, exchange_rate=50.0,
                             due_date=date(2026, 9, 1), payment_type="متعدد (PO-1 (T/T))")


def test_duplicate_guard_matches_legacy_label_rows(db):
    imp = seed_file(db)
    legacy = _payment(db, import_file_id=imp.import_file_id, payment_type="ADVANCE_PAYMENT")
    db.query(PaymentRequestSession).filter_by(payment_id=legacy.payment_id).update({"payment_type": "Advance Payment"})
    db.commit()
    with pytest.raises(HTTPException) as exc:
        _payment(db, import_file_id=imp.import_file_id, payment_type="ADVANCE_PAYMENT")
    assert _code(exc) == "FA_PAYMENT_DUPLICATE_TYPE"
    assert service.get_payment_request_by_id_service(db, legacy.payment_id).payment_type == "Advance Payment"


def test_explicit_null_amount_is_ignored_not_500(db):
    p = _payment(db, amount=123.0)
    upd = service.update_payment_request_service(db, p.payment_id, PaymentRequestUpdate.model_validate(
        {"requested_amount": None, "exchange_rate": None, "title": None, "notes": "x"}))
    assert upd.requested_amount == 123.0 and upd.requested_amount_egp == 123.0 * 50.0
    with pytest.raises(ValidationError):
        PaymentRequestUpdate(requested_amount=0)
    budget = seed_budget(db, None, status="Draft", customs_duties_egp=10.0)
    b = service.update_import_budget_service(db, budget.budget_id, ImportBudgetUpdate.model_validate({"customs_duties_egp": None}))
    assert b.customs_duties_egp == 10.0


def test_update_import_file_must_be_active(db):
    p = _payment(db)
    with pytest.raises(HTTPException) as exc:
        service.update_payment_request_service(db, p.payment_id, PaymentRequestUpdate(import_file_id=9999))
    assert exc.value.status_code == 400


# ─── FA-13: code generation ──────────────────────────────────────────────────

def test_payment_code_collision_is_retried(db, monkeypatch):
    first = _payment(db, title="First")
    codes = iter([first.payment_code, f"PAY-{date.today().year}-777"])
    monkeypatch.setattr(repo, "next_payment_code", lambda _db: next(codes))
    second = _payment(db, title="Second")
    assert second.payment_code == f"PAY-{date.today().year}-777"


def test_payment_code_collision_exhausted_is_409(db, monkeypatch):
    first = _payment(db, title="First")
    monkeypatch.setattr(repo, "next_payment_code", lambda _db: first.payment_code)
    with pytest.raises(HTTPException) as exc:
        _payment(db, title="Second")
    assert exc.value.status_code == 409 and _code(exc) == "FA_CODE_GENERATION_CONFLICT"


def test_budget_code_skips_revision_suffixes(db):
    year = date.today().year
    for code in (f"BGT-{year}-004", f"BGT-{year}-004-REV2"):
        db.add(ImportBudgetApproval(budget_code=code, title=code, budget_status="Draft", exchange_rate=50.0, is_active=True))
    db.commit()
    created = service.create_import_budget_service(db, ImportBudgetCreate(title="Next budget", exchange_rate=50.0))
    assert created.budget_code == f"BGT-{year}-005"


# ─── FA-07 / FA-09: follow-ups after the commit ──────────────────────────────

def test_follow_up_failure_keeps_the_saved_payment(db, monkeypatch):
    import modules.lifecycle_board.service as lifecycle

    def boom(*args, **kwargs):
        raise RuntimeError("lifecycle down")

    monkeypatch.setattr(lifecycle, "advance_lifecycle_step_service", boom)
    imp = seed_file(db)
    p = _payment(db, import_file_id=imp.import_file_id)
    assert db.query(PaymentRequestSession).filter_by(payment_id=p.payment_id).one().status == "Draft"


def test_paying_one_request_closes_only_its_own_tasks(db):
    imp = seed_file(db)
    a = _payment(db, import_file_id=imp.import_file_id, payment_type="ADVANCE_PAYMENT", title="Advance A")
    b = _payment(db, import_file_id=imp.import_file_id, payment_type="AGAINST_BL", title="Against BL B")
    service.approve_payment_request_service(db, a.payment_id)
    service.execute_payment_service(db, a.payment_id, "SWF-A")

    tasks = db.query(SmartTask).filter(SmartTask.import_file_id == imp.import_file_id, SmartTask.notes.like("REQ_TYPE:%")).all()
    by_payment = {("PayId: %d" % a.payment_id) in t.notes: t.status for t in tasks}
    assert by_payment[True] == "Completed"
    assert by_payment[False] == "Pending"
    assert b.payment_id != a.payment_id


# ─── FA-21 / FA-25 / FA-16 ───────────────────────────────────────────────────

def _freight_item(session_id, amount, currency):
    return ShippingScenarioItem(session_id=session_id, provider_name="Line", vessel_name="V", sailing_date=date(2026, 9, 1),
                                estimated_arrival_date=date(2026, 10, 1), quotation_currency=currency,
                                total_quotation_amount=amount)


def test_highest_freight_is_compared_in_egp(db):
    imp = seed_file(db)
    sess = ShippingEvaluationSession(session_code="SCE-T-1", import_file_id=imp.import_file_id, is_active=True)
    db.add(sess)
    db.commit()
    db.add_all([_freight_item(sess.session_id, 900.0, "EUR"), _freight_item(sess.session_id, 1000.0, "USD")])
    db.commit()
    prefill = service.get_budget_prefill_service(db, imp.import_file_id)
    # EUR 900 = 49,500 EGP < USD 1000 = 50,000 EGP (raw 900 < 1000 too); now EUR 950 = 52,250 EGP wins.
    assert (prefill.estimated_freight_cost, prefill.freight_currency) == (1000.0, "USD")
    db.add(_freight_item(sess.session_id, 950.0, "EUR"))
    db.commit()
    prefill = service.get_budget_prefill_service(db, imp.import_file_id)
    assert (prefill.estimated_freight_cost, prefill.freight_currency) == (950.0, "EUR")
    assert prefill.estimated_freight_cost_egp == 950.0 * 55.0


def test_list_returns_import_file_code_and_searches_it(db):
    imp = seed_file(db, import_file_code="IMP-2026-4242")
    p = _payment(db, import_file_id=imp.import_file_id)
    rows, _ = service.get_all_payment_requests_service(db, search="4242")
    assert [r.payment_id for r in rows] == [p.payment_id]
    assert rows[0].import_file_code == "IMP-2026-4242"
    budget = seed_budget(db, imp.import_file_id)
    brows, _ = service.get_all_import_budgets_service(db, search="IMP-2026-4242")
    assert [r.budget_id for r in brows] == [budget.budget_id]
    assert brows[0].import_file_code == "IMP-2026-4242"


def test_base64_upload_invalid_and_too_large(db, monkeypatch):
    with pytest.raises(HTTPException) as exc:
        service.smart_extract_swift_from_base64_service(db, SmartSwiftFileExtractRequest(filename="a.txt", file_base64="@@not-base64@@"))
    assert exc.value.status_code == 400 and _code(exc) == "FA_SWIFT_FILE_INVALID_BASE64"

    monkeypatch.setattr(service, "MAX_SWIFT_FILE_BYTES", 10)
    big = base64.b64encode(b"x" * 64).decode()
    with pytest.raises(HTTPException) as exc:
        service.smart_extract_swift_from_base64_service(db, SmartSwiftFileExtractRequest(filename="a.txt", file_base64=big))
    assert exc.value.status_code == 413 and _code(exc) == "FA_SWIFT_FILE_TOO_LARGE"


def test_threshold_get_without_row_returns_default(db):
    setting = service.get_variance_threshold_setting_service(db)
    assert setting.setting_value == "5.0"


# ─── FA-14: sync permission lives in the router; SoD in the service ──────────

def test_sync_by_non_modifier_without_role_shortcut_passes_service(db):
    imp = seed_file(db)
    seed_consultation(db, imp.import_file_id, fees=510.0)
    budget = seed_budget(db, imp.import_file_id, status="Pending Review", clearance_inland_egp=500.0)
    result = service.sync_budget_with_upstream_service(db, budget.budget_id, current_user=plain_user("finance_x"))
    assert result.message_code == "FA_BUDGET_SYNC_DONE"
    assert result.message_params == {"budget_code": budget.budget_code, "status": "Pending Review"}


# ─── FA-01 / FA-03 / FA-15: RBAC + acting user through the API ───────────────

@pytest.fixture
def api(db, monkeypatch):
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)
    seed_rbac(db)
    app = FastAPI()
    app.include_router(fa_router.router)

    def override_get_db():
        yield db

    app.dependency_overrides[get_db] = override_get_db
    return TestClient(app, raise_server_exceptions=False)


def _user(db, username, role_code) -> User:
    role = db.query(Role).filter(Role.role_code == role_code).one()
    user = User(username=username, email=f"{username}@test.com", full_name=username,
                hashed_password=hash_password("Password123"), role=role.role_code, role_id=role.role_id, is_active=True)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _bearer(user: User) -> dict:
    return {"Authorization": f"Bearer {create_access_token({'sub': str(user.user_id), 'role': user.role})}"}


BASE = "/api/v1/financial-approval"


@pytest.mark.parametrize("method,path", [
    ("POST", "/payment-requests"),
    ("PUT", "/payment-requests/1"),
    ("POST", "/payment-requests/1/approve"),
    ("POST", "/payment-requests/1/pay"),
    ("POST", "/payment-requests/1/reconcile-swift"),
    ("DELETE", "/payment-requests/1"),
    ("POST", "/import-budgets"),
    ("POST", "/import-budgets/1/approve"),
    ("POST", "/import-budgets/1/sync"),
    ("POST", "/import-budgets/1/override-variance"),
    ("POST", "/swift/smart-reconcile"),
    ("POST", "/swift/review-batch/1/reconcile"),
    ("POST", "/swift/review-batch/1/confirm"),
])
def test_viewer_is_denied_writes(api, db, method, path):
    viewer = _user(db, "auditor1", "AUDITOR_VIEWER")
    resp = api.request(method, BASE + path, headers=_bearer(viewer), json={})
    assert resp.status_code == 403, resp.text


def test_viewer_can_read(api, db):
    viewer = _user(db, "auditor2", "AUDITOR_VIEWER")
    assert api.get(BASE + "/payment-requests", headers=_bearer(viewer)).status_code == 200
    assert api.get(BASE + "/import-budgets", headers=_bearer(viewer)).status_code == 200
    assert api.get(BASE + "/settings/variance-threshold", headers=_bearer(viewer)).status_code == 200
    assert api.get(BASE + "/payment-requests", headers=_bearer(viewer), params={"status": "Nope"}).status_code == 422


def test_operator_may_create_but_not_approve(api, db):
    operator = _user(db, "operator1", "LOGISTICS_OPERATOR")
    assert api.post(BASE + "/payment-requests", headers=_bearer(operator), json={}).status_code == 422  # past auth
    assert api.post(BASE + "/payment-requests/1/approve", headers=_bearer(operator)).status_code == 403


def test_reject_of_pending_or_approved_needs_approve_permission(api, db):
    """Security review: rejecting a Pending Approval / Approved request is an approval decision (.approve);
    a manage-only operator may still reject its own Draft."""
    operator = _user(db, "operator_rej", "LOGISTICS_OPERATOR")
    officer = _user(db, "officer_rej", "FINANCE_OFFICER")
    pending = _payment(db, title="Pending one", status="Pending Approval")
    approved = _approved(db, title="Approved one")
    draft = _payment(db, title="Draft one")
    for item in (pending, approved):
        resp = api.put(f"{BASE}/payment-requests/{item.payment_id}", headers=_bearer(operator), json={"status": "Rejected"})
        assert resp.status_code == 403, resp.text
        assert "financial_approval.approve" in resp.json()["detail"]
    resp = api.put(f"{BASE}/payment-requests/{draft.payment_id}", headers=_bearer(operator), json={"status": "Rejected"})
    assert resp.status_code == 200 and resp.json()["status"] == "Rejected"
    resp = api.put(f"{BASE}/payment-requests/{approved.payment_id}", headers=_bearer(officer), json={"status": "Rejected"})
    assert resp.status_code == 200 and resp.json()["status"] == "Rejected"


def test_budget_approver_is_the_token_user(api, db):
    officer = _user(db, "finance_officer1", "FINANCE_OFFICER")
    budget = seed_budget(db, None, status="Pending Review")
    resp = api.post(f"{BASE}/import-budgets/{budget.budget_id}/approve", headers=_bearer(officer),
                    params={"approved_by": "Finance Manager"})
    assert resp.status_code == 200, resp.text
    assert resp.json()["approved_by"] == "finance_officer1"


def test_api_create_payment_contract(api, db):
    officer = _user(db, "finance_officer2", "FINANCE_OFFICER")
    imp = seed_file(db, import_file_code="IMP-2026-9001")
    body = {"title": "API payment", "supplier_name": "Sup", "payment_type": "Against B/L", "requested_amount": 100.0,
            "exchange_rate": 48.5, "due_date": str(date.today() + timedelta(days=5)), "import_file_id": imp.import_file_id,
            "status": "Paid"}
    resp = api.post(BASE + "/payment-requests", headers=_bearer(officer), json=body)
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["status"] == "Draft"
    assert data["payment_type"] == "AGAINST_BL"
    assert data["import_file_code"] == "IMP-2026-9001"

    missing_rate = {k: v for k, v in body.items() if k != "exchange_rate"}
    assert api.post(BASE + "/payment-requests", headers=_bearer(officer), json=missing_rate).status_code == 422

    pay = api.post(f"{BASE}/payment-requests/{data['payment_id']}/pay", headers=_bearer(officer))
    assert pay.status_code == 400
    assert pay.json()["detail"]["code"] == "FA_PAYMENT_STATUS_INVALID"


def test_swift_edit_author_is_token_user(api, db):
    officer = _user(db, "finance_officer3", "FINANCE_OFFICER")
    batch = service.extract_swift_for_review_service(db, SWIFT_TEXT, "s.txt", "Text File")
    resp = api.put(f"{BASE}/swift/review-batch/{batch.batch_id}/field/amount", headers=_bearer(officer),
                   json={"value": "1.00", "user_name": "admin"})
    assert resp.status_code == 200, resp.text
    assert db.query(OcrCorrectionsLog).filter_by(batch_id=batch.batch_id).one().corrected_by == "finance_officer3"
    assert db.query(SwiftExtractionBatch).filter_by(batch_id=batch.batch_id).one().status == "EXTRACTED_PENDING_REVIEW"


def test_be02_t12_currency_change_requires_new_rate(api, db):
    """BE02-T12: Changing a payment's currency requires a new rate."""
    officer = _user(db, "finance_officer_t12", "FINANCE_OFFICER")
    p = _payment(db, amount=10000.0, currency="USD", exchange_rate=50.0)
    assert p.requested_amount_egp == 500000.0

    # 1. PUT with a different currency_code and no exchange_rate -> 400 FA_PAYMENT_RATE_REQUIRED
    resp = api.put(
        f"{BASE}/payment-requests/{p.payment_id}",
        headers=_bearer(officer),
        json={"currency_code": "EUR"},
    )
    assert resp.status_code == 400
    assert resp.json()["detail"]["code"] == "FA_PAYMENT_RATE_REQUIRED"
    assert "سعر الصرف الجديد" in resp.json()["detail"]["message"]

    # Also test directly via service
    with pytest.raises(HTTPException) as exc:
        service.update_payment_request_service(
            db, p.payment_id, PaymentRequestUpdate(currency_code="EUR")
        )
    assert exc.value.status_code == 400
    assert _code(exc) == "FA_PAYMENT_RATE_REQUIRED"

    # 2. PUT with different currency_code and exchange_rate=55 -> requested_amount_egp == 550000.0
    resp_ok = api.put(
        f"{BASE}/payment-requests/{p.payment_id}",
        headers=_bearer(officer),
        json={"currency_code": "EUR", "exchange_rate": 55.0},
    )
    assert resp_ok.status_code == 200
    data = resp_ok.json()
    assert data["currency_code"] == "EUR"
    assert data["exchange_rate"] == 55.0
    assert data["requested_amount_egp"] == 550000.0

    # Same currency update without exchange_rate -> succeeds without 400
    resp_same = api.put(
        f"{BASE}/payment-requests/{p.payment_id}",
        headers=_bearer(officer),
        json={"currency_code": "EUR", "title": "Updated Title"},
    )
    assert resp_same.status_code == 200

