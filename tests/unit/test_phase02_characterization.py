"""
Phase 2 (financial approval) characterization tests: behaviour that docs/plans/phase-02-quality-plan.md
section 2 says must stay identical through the quality fixes. Written green on the code before the fixes.
"""
from datetime import date, timedelta

import pytest
from fastapi import HTTPException

import modules.financial_approval.service as service
from modules.financial_approval.model import BudgetVarianceLog, ImportBudgetApproval
from modules.financial_approval.schemas import (
    CloneImportBudgetRequest,
    ClonePaymentRequestRequest,
    ImportBudgetCreate,
    PaymentRequestCreate,
    PaymentRequestUpdate,
    SwiftReconciliationRequest,
)
from modules.currencies.model import Currency
from modules.notifications.model import SystemNotification
from modules.purchase_orders.model import POLineItem, PurchaseOrder

from test_phase02_support import (
    admin_user,
    make_session,
    plain_user,
    seed_budget,
    seed_consultation,
    seed_file,
    seed_rate,
)


@pytest.fixture
def db():
    session = make_session()
    seed_rate(session, "USD", 50.0)
    seed_rate(session, "EUR", 55.0)
    try:
        yield session
    finally:
        session.close()


def _payment(db, amount=10000.0, rate=50.0, **extra):
    payload = PaymentRequestCreate(
        title=extra.pop("title", "Characterization payment"),
        supplier_name="Supplier Co",
        payment_type=extra.pop("payment_type", "Final Settlement"),
        requested_amount=amount,
        currency_code="USD",
        exchange_rate=rate,
        due_date=date(2026, 9, 1),
        request_date=extra.pop("request_date", date(2026, 8, 10)),
        **extra,
    )
    return service.create_payment_request_service(db, payload)


# 1. Payment EGP value
def test_payment_egp_is_amount_times_rate_unrounded(db):
    p = _payment(db, amount=1234.56, rate=48.37)
    # Money is stored rounded to 2 decimals since ACC2 (was the raw product).
    assert p.requested_amount_egp == round(1234.56 * 48.37, 2)

    updated = service.update_payment_request_service(db, p.payment_id, PaymentRequestUpdate(exchange_rate=51.13))
    assert updated.requested_amount_egp == round(1234.56 * 51.13, 2)


# 2. SWIFT variance golden values
@pytest.mark.parametrize(
    "transferred,variance,status_label",
    [(10000.0, 0.0, "Matched"), (9950.0, -50.0, "Deficit"), (10000.004, 0.0, "Matched"), (10025.0, 25.0, "Surplus")],
)
def test_swift_variance_golden_values(db, transferred, variance, status_label):
    p = _payment(db)
    service.approve_payment_request_service(db, p.payment_id)
    res = service.reconcile_swift_service(db, p.payment_id, SwiftReconciliationRequest(
        swift_reference_no=f"MT103-{transferred}",
        swift_receipt_date=date(2026, 8, 14),
        swift_transferred_amount=transferred,
        swift_transferred_currency="USD",
    ))
    assert res.swift_variance_amount == variance
    assert res.swift_variance_status == status_label
    assert res.swift_processing_days == 4
    assert res.status == "Paid"


def test_swift_processing_days_never_negative(db):
    p = _payment(db, request_date=date(2026, 8, 10))
    service.approve_payment_request_service(db, p.payment_id)
    res = service.reconcile_swift_service(db, p.payment_id, SwiftReconciliationRequest(
        swift_reference_no="MT103-EARLY", swift_receipt_date=date(2026, 8, 1),
        swift_transferred_amount=10000.0, swift_transferred_currency="USD",
    ))
    assert res.swift_processing_days == 0


# 3. Variance engine thresholds
@pytest.mark.parametrize(
    "old,new,logged,pct,hard",
    [
        (1000.0, 1001.0, False, None, None),   # diff 1.0 ignored
        (1000.0, 1001.01, True, 0.1, False),   # diff 1.01 logged
        (0.0, 500.0, True, 100.0, True),       # old value 0 -> 100 %
        (1000.0, 1050.0, True, 5.0, False),    # 5.0 % is not a hard block
        (1000.0, 1050.1, True, 5.01, True),    # 5.01 % is
    ],
)
def test_variance_engine_thresholds(db, old, new, logged, pct, hard):
    imp = seed_file(db)
    seed_consultation(db, imp.import_file_id, fees=new)
    budget = seed_budget(db, imp.import_file_id, clearance_inland_egp=old)

    logs = service.evaluate_and_record_budget_variance_service(db, imp.import_file_id, modified_by="broker_x")
    if not logged:
        assert logs == []
        return
    assert len(logs) == 1
    assert logs[0].field_name == "clearance_inland_egp"
    assert logs[0].budget_id == budget.budget_id
    assert logs[0].variance_percentage == pct
    assert logs[0].is_hard_block is hard
    assert logs[0].threshold_percentage == 5.0


# 4. Status machine on an upstream change
def test_status_machine_draft_auto_updates(db):
    imp = seed_file(db)
    seed_consultation(db, imp.import_file_id, duties=2000.0, fees=900.0)
    budget = seed_budget(db, imp.import_file_id, status="Draft", customs_duties_egp=1000.0, clearance_inland_egp=500.0)

    logs = service.evaluate_and_record_budget_variance_service(db, imp.import_file_id, modified_by="broker_x")
    db.refresh(budget)
    assert budget.budget_status == "Draft"
    assert budget.customs_duties_egp == 2000.0
    assert budget.clearance_inland_egp == 900.0
    assert budget.total_budget_egp == 2900.0
    assert budget.has_unresolved_variance is False
    assert {l.resolution_type for l in logs} == {"auto_updated"}


def test_status_machine_pending_review_needs_revalidation(db):
    imp = seed_file(db)
    seed_consultation(db, imp.import_file_id, fees=900.0)
    budget = seed_budget(db, imp.import_file_id, status="Pending Review", clearance_inland_egp=500.0)
    budget.approved_by = "someone"
    db.commit()

    service.evaluate_and_record_budget_variance_service(db, imp.import_file_id, modified_by="broker_x")
    db.refresh(budget)
    assert budget.budget_status == "Needs Revalidation"
    assert budget.has_unresolved_variance is True
    assert budget.approved_by is None
    assert budget.clearance_inland_egp == 500.0
    assert budget.upstream_modified_by == "broker_x"


def test_status_machine_approved_numbers_untouched_critical_notification(db):
    imp = seed_file(db)
    seed_consultation(db, imp.import_file_id, fees=900.0)
    budget = seed_budget(db, imp.import_file_id, status="Budget Approved", clearance_inland_egp=500.0)

    service.evaluate_and_record_budget_variance_service(db, imp.import_file_id, modified_by="broker_x")
    db.refresh(budget)
    assert budget.budget_status == "Budget Approved"
    assert budget.clearance_inland_egp == 500.0
    assert budget.has_unresolved_variance is True
    notif = db.query(SystemNotification).filter(SystemNotification.entity_id == budget.budget_id).one()
    assert notif.msg_code == "FA_APPROVED_BUDGET_VARIANCE"
    assert notif.severity == "CRITICAL"


# 5. Sync
def test_sync_approved_creates_revision_and_supersedes(db):
    imp = seed_file(db)
    budget = service.create_import_budget_service(db, ImportBudgetCreate(
        title="Sync budget", import_file_id=imp.import_file_id, exchange_rate=50.0,
        customs_duties_egp=1000.0, clearance_inland_egp=500.0,
    ))
    service.approve_import_budget_service(db, budget.budget_id, approved_by="cfo")
    seed_consultation(db, imp.import_file_id, duties=1000.0, fees=900.0)

    result = service.sync_budget_with_upstream_service(
        db, budget.budget_id, current_user=admin_user(), override_justification="Broker fee confirmed"
    )
    assert result.revision_created is True
    assert result.action_taken == "revision_created"
    assert result.budget.budget_code == f"{budget.budget_code}-REV2"
    assert result.budget.budget_code.startswith(f"BGT-{date.today().year}-")
    assert result.budget.budget_status == "Pending Review"
    assert result.budget.revision_number == 2
    assert result.budget.clearance_inland_egp == 900.0
    assert result.budget.total_budget_egp == 1900.0
    db.refresh(budget)
    assert budget.budget_status == "Superseded"


@pytest.mark.parametrize("start,expected", [("Pending Review", "Pending Review"), ("Needs Revalidation", "Pending Review"), ("Draft", "Draft")])
def test_sync_in_place(db, start, expected):
    imp = seed_file(db)
    seed_consultation(db, imp.import_file_id, fees=520.0)
    budget = seed_budget(db, imp.import_file_id, status=start, clearance_inland_egp=500.0)

    result = service.sync_budget_with_upstream_service(db, budget.budget_id, current_user=admin_user())
    assert result.revision_created is False
    assert result.budget.budget_id == budget.budget_id
    assert result.budget.budget_status == expected
    assert result.budget.clearance_inland_egp == 520.0
    assert result.action_taken == ("auto_updated" if start == "Draft" else "revalidation_required")


def test_sync_hard_block_needs_justification_except_draft(db):
    imp = seed_file(db)
    seed_consultation(db, imp.import_file_id, fees=900.0)
    pending = seed_budget(db, imp.import_file_id, status="Pending Review", clearance_inland_egp=500.0)
    with pytest.raises(HTTPException) as exc:
        service.sync_budget_with_upstream_service(db, pending.budget_id, current_user=admin_user())
    assert exc.value.status_code == 400

    imp2 = seed_file(db)
    seed_consultation(db, imp2.import_file_id, fees=900.0)
    draft = seed_budget(db, imp2.import_file_id, status="Draft", clearance_inland_egp=500.0)
    assert service.sync_budget_with_upstream_service(db, draft.budget_id, current_user=admin_user()).budget.clearance_inland_egp == 900.0


# 6. Prefill fallback chain and broker choice
def test_prefill_po_fob_then_line_items(db):
    imp = seed_file(db)
    usd = db.query(Currency).filter_by(currency_code="USD").one()
    refs = dict(import_file_id=imp.import_file_id, currency_id=usd.currency_id, payment_terms="T/T",
                project_id=1, company_id=1, supplier_id=1, incoterm_id=1)  # FKs are not enforced in the test DB
    po1 = PurchaseOrder(po_number="PO-C-1", total_amount_fob=1000.0, **refs)
    po2 = PurchaseOrder(po_number="PO-C-2", total_amount_fob=0.0, **refs)
    db.add_all([po1, po2])
    db.commit()
    db.add(POLineItem(po_id=po2.po_id, item_code="X", description_ar="x", description_en="x", tariff_id=1, quantity=3.0, unit_price=200.0))
    db.commit()

    prefill = service.get_budget_prefill_service(db, imp.import_file_id)
    assert prefill.total_invoice_amount == 1600.0
    assert prefill.invoice_currency == "USD"
    assert prefill.total_invoice_amount_egp == 1600.0 * 50.0
    assert prefill.exchange_rate == 50.0


def test_prefill_invoices_data_then_estimated_cost(db):
    imp = seed_file(db, invoices_data=[{"amount": 700.0, "currency": "EUR"}, {"amount": 0}], estimated_cost=9999.0)
    prefill = service.get_budget_prefill_service(db, imp.import_file_id)
    assert prefill.total_invoice_amount == 700.0
    assert prefill.invoice_currency == "EUR"
    assert prefill.exchange_rate == 55.0

    imp2 = seed_file(db, estimated_cost=300.0, estimated_cost_currency="USD")
    prefill2 = service.get_budget_prefill_service(db, imp2.import_file_id)
    assert prefill2.total_invoice_amount == 300.0
    assert prefill2.total_invoice_amount_egp == 15000.0


def test_prefill_customs_max_and_broker_from_max_fee_session(db):
    imp = seed_file(db)
    seed_consultation(db, imp.import_file_id, duties=5000.0, fees=100.0, broker_id=1, broker_name="Low fee broker")
    seed_consultation(db, imp.import_file_id, duties=3000.0, fees=800.0, broker_id=2, broker_name="High fee broker")
    prefill = service.get_budget_prefill_service(db, imp.import_file_id)
    assert prefill.estimated_customs_duties_egp == 5000.0
    assert prefill.estimated_clearance_fees_egp == 800.0
    assert prefill.broker_id == 2
    assert prefill.broker_name == "High fee broker"
    assert prefill.estimated_grand_total_egp == 5800.0


# 7. Clone resets
def test_payment_clone_resets(db):
    p = _payment(db, title="Original")
    clone = service.clone_payment_request_service(db, p.payment_id, ClonePaymentRequestRequest())
    assert clone.status == "Draft"
    assert clone.title == "Original (Copy)"
    assert clone.request_date == date.today()
    assert clone.due_date == date.today() + timedelta(days=12)
    assert clone.swift_reference_no is None
    assert clone.requested_amount_egp == p.requested_amount * p.exchange_rate


def test_budget_clone_resets_and_unlinks_same_file(db):
    imp = seed_file(db)
    budget = service.create_import_budget_service(db, ImportBudgetCreate(
        title="Original budget", import_file_id=imp.import_file_id, exchange_rate=50.0, invoice_amount_egp=100.0,
    ))
    service.approve_import_budget_service(db, budget.budget_id, approved_by="cfo")
    clone = service.clone_import_budget_service(db, budget.budget_id, CloneImportBudgetRequest())
    assert clone.budget_status == "Pending Review"
    assert clone.approved_by is None and clone.approved_date is None
    assert clone.import_file_id is None
    assert clone.title == "Original budget (Copy)"


# 8. Segregation of duties
def test_segregation_of_duties_modifier_denied_admin_passes(db):
    imp = seed_file(db)
    seed_consultation(db, imp.import_file_id, fees=900.0)
    budget = seed_budget(db, imp.import_file_id, status="Budget Approved", clearance_inland_egp=500.0)
    budget.upstream_modified_by = "customs_agent_ali"
    db.commit()

    with pytest.raises(HTTPException) as exc:
        service.sync_budget_with_upstream_service(
            db, budget.budget_id, current_user=plain_user("customs_agent_ali"), override_justification="mine"
        )
    assert exc.value.status_code == 403

    admin = admin_user()
    admin.username = "customs_agent_ali"  # ADMIN is exempt even as the modifier
    result = service.sync_budget_with_upstream_service(
        db, budget.budget_id, current_user=admin, override_justification="approved by admin"
    )
    assert result.revision_created is True
    assert db.query(ImportBudgetApproval).count() == 2
    assert db.query(BudgetVarianceLog).count() == 0
