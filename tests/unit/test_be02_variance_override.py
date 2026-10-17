"""
Unit tests for BE02-T01:
A new variance cancels an earlier override (hard-block bypass) (BE02-F01).
"""
import pytest
from fastapi import HTTPException

import modules.financial_approval.repository as repo
import modules.financial_approval.service as service
from modules.customs_consultation.model import CustomsConsultationSession
from test_phase02_support import (
    admin_user,
    make_session,
    seed_budget,
    seed_consultation,
    seed_file,
    seed_rate,
)


@pytest.fixture
def db():
    session = make_session()
    seed_rate(session, "EGP", 1.0, base=True)
    seed_rate(session, "USD", 50.0)
    try:
        yield session
    finally:
        session.close()


def test_new_variance_cancels_earlier_override(db):
    """
    Test that a new upstream variance clears variance_override_reason and blocks approve.
    Flow:
    1. Budget in Pending Review with customs_duties_egp=100000.
    2. Prefill returns customs 110000 (10% > threshold 5%).
    3. Evaluate: status becomes Needs Revalidation and 1 pending hard log is recorded.
    4. Override with 'approved by GM': log resolution becomes 'overridden'.
    5. Prefill returns customs 132000 (32% variance).
    6. Evaluate again: variance_override_reason is cleared to None.
    7. approve_import_budget_service raises 400 FA_BUDGET_HARD_BLOCK.
    """
    imp = seed_file(db)
    cs = seed_consultation(db, imp.import_file_id, duties=110000.0)
    budget = seed_budget(
        db,
        imp.import_file_id,
        status="Pending Review",
        customs_duties_egp=100000.0,
    )

    # 1. Evaluate: should flag hard block and set Needs Revalidation
    logs = service.evaluate_and_record_budget_variance_service(
        db, imp.import_file_id, modified_by="customs_broker"
    )
    db.refresh(budget)
    assert budget.budget_status == "Needs Revalidation"
    assert budget.has_unresolved_variance is True
    assert len(logs) == 1
    assert logs[0].is_hard_block is True
    assert logs[0].resolution_type == "pending"

    # 2. Override with justification
    adm = admin_user()
    service.override_budget_variance_service(
        db, budget.budget_id, adm, justification_note="approved by GM"
    )
    db.refresh(budget)
    assert budget.has_unresolved_variance is False
    assert budget.variance_override_reason == "approved by GM"
    assert budget.variance_overridden_by == adm.username
    assert repo.first_pending_hard_block(db, budget.budget_id) is None

    # 3. Upstream change: customs duties increase to 132000
    cs.estimated_duties_egp = 132000.0
    db.commit()

    # 4. Evaluate again: must clear the override
    logs2 = service.evaluate_and_record_budget_variance_service(
        db, imp.import_file_id, modified_by="customs_broker_2"
    )
    db.refresh(budget)
    assert budget.budget_status == "Needs Revalidation"
    assert budget.has_unresolved_variance is True
    assert budget.variance_override_reason is None
    assert budget.variance_overridden_by is None
    assert len(logs2) == 1
    assert logs2[0].is_hard_block is True
    assert logs2[0].resolution_type == "pending"

    # 5. Attempt approval: must be blocked by FA_BUDGET_HARD_BLOCK
    with pytest.raises(HTTPException) as exc_info:
        service.approve_import_budget_service(db, budget.budget_id, approved_by="cfo")
    assert exc_info.value.status_code == 400
    assert exc_info.value.detail["code"] == "FA_BUDGET_HARD_BLOCK"
    assert exc_info.value.detail["field_name"] == "customs_duties_egp"


def test_control_override_then_approve_without_new_variance_succeeds(db):
    """
    Control test: override without subsequent evaluation allows budget approval.
    """
    imp = seed_file(db)
    seed_consultation(db, imp.import_file_id, duties=110000.0)
    budget = seed_budget(
        db,
        imp.import_file_id,
        status="Pending Review",
        customs_duties_egp=100000.0,
    )

    # 1. Evaluate: Needs Revalidation
    service.evaluate_and_record_budget_variance_service(
        db, imp.import_file_id, modified_by="customs_broker"
    )
    db.refresh(budget)
    assert budget.budget_status == "Needs Revalidation"

    # 2. Override
    adm = admin_user()
    service.override_budget_variance_service(
        db, budget.budget_id, adm, justification_note="approved by GM"
    )
    db.refresh(budget)

    # 3. Approve directly with no second evaluation -> succeeds
    approved = service.approve_import_budget_service(db, budget.budget_id, approved_by="cfo")
    assert approved.budget_status == "Budget Approved"
    assert approved.approved_by == "cfo"
