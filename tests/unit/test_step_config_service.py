"""
Unit Tests for Configurable Step Risk Classification & Pending Reference (Section 10)
"""

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi import HTTPException

from database.database import Base
from modules.import_files.model import ImportFile
from modules.lifecycle_board.model import (
    ShipmentStageActivity,
    StepConfig,
    StepConfigAuditLog,
    PendingReferenceRecord,
)
from modules.audit_logs.model import AuditLog
import modules.lifecycle_board.service as service
import modules.lifecycle_board.repository as repo
from modules.lifecycle_board.schemas import (
    StepConfigUpdateRequest,
    RegisterPendingReferenceRequest,
    SkipStepPayload,
)


@pytest.fixture
def db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()

    # Seed test import file
    file1 = ImportFile(
        import_file_code="IMP-2026-0004",
        company_name="SCAS Logistics",
        supplier_name="Sinopec Corp",
        status="Draft",
        is_active=True,
    )
    session.add(file1)
    session.commit()

    yield session
    session.close()


def test_step_configs_default_initialization(db):
    """Section 10.2 & 10.6: All 21 steps default to blocked, approver_roles=['Manager']"""
    configs = service.get_all_step_configs_service(db)
    assert len(configs) >= 21
    for cfg in configs:
        assert cfg.skip_policy == "blocked"
        assert cfg.reason_required is True
        assert "Manager" in cfg.approver_roles
        assert cfg.supports_pending_reference is False


def test_unconfigured_step_defaults_to_blocked(db):
    """Section 10.2: Any step with no explicit DB config defaults to blocked"""
    cfg = service.get_step_config_service(db, "STEP_01")
    assert cfg.skip_policy == "blocked"
    assert cfg.reason_required is True
    assert "Manager" in cfg.approver_roles


def test_manager_authorization_guard(db):
    """Section 10.7: Only Manager/Admin role can modify step_config; others rejected with 403"""
    payload = StepConfigUpdateRequest(
        skip_policy="single_approval",
        justification="Legitimate test justification",
    )

    # Operator role -> Denied
    with pytest.raises(HTTPException) as exc_info:
        service.update_step_config_service(
            db,
            step_code="STEP_02",
            payload=payload,
            current_user_role="OPERATOR",
            current_username="operator1",
        )
    assert exc_info.value.status_code == 403
    assert "فقط دور المدير" in exc_info.value.detail

    # Manager role -> Allowed
    res = service.update_step_config_service(
        db,
        step_code="STEP_02",
        payload=payload,
        current_user_role="MANAGER",
        current_username="manager1",
    )
    assert res.skip_policy == "single_approval"
    assert res.last_modified_by == "manager1"


def test_mandatory_justification_validation(db):
    """Section 10.3 & 10.7: Classification changes strictly require justification >= 5 chars"""
    with pytest.raises(Exception): # Pydantic or service validation
        payload = StepConfigUpdateRequest(
            skip_policy="single_approval",
            justification="ok", # Too short
        )
        service.update_step_config_service(
            db,
            step_code="STEP_02",
            payload=payload,
            current_user_role="MANAGER",
        )


def test_rule_change_audit_trail_logging(db):
    """Section 10.3: Changes to classification rules are logged separately in StepConfigAuditLog"""
    payload = StepConfigUpdateRequest(
        skip_policy="dual_approval",
        supports_pending_reference=True,
        approver_roles=["Manager", "ADMIN"],
        justification="Board approved new compliance exception matrix 2026",
    )
    service.update_step_config_service(
        db,
        step_code="STEP_12",
        payload=payload,
        current_user_role="ADMIN",
        current_username="admin",
    )

    logs = service.get_step_config_audit_logs_service(db, step_code="STEP_12")
    assert len(logs) >= 1
    latest = logs[0]
    assert latest.step_code == "STEP_12"
    assert latest.action == "UPDATE_POLICY"
    assert latest.changed_by == "admin"
    assert latest.old_policy == "blocked"
    assert latest.new_policy == "dual_approval"
    assert latest.new_supports_pending_reference is True
    assert "Board approved" in latest.justification


def test_skip_step_enforces_live_config_blocked(db):
    """Section 10.1 & 10.5: Attempting to skip a 'blocked' step raises HTTP 400"""
    # Initialize STEP_05 as In-Progress
    repo.save_or_update_activity(
        db,
        import_file_code="IMP-2026-0004",
        step_code="STEP_05",
        status="In-Progress",
    )

    payload = SkipStepPayload(
        import_file_code="IMP-2026-0004",
        current_step_code="STEP_05",
        skip_reason="Trying to skip ACID without policy change",
    )

    with pytest.raises(HTTPException) as exc_info:
        service.skip_step_service(db, payload, current_user_role="OPERATOR")
    assert exc_info.value.status_code == 400
    assert "محظورة من التخطي" in exc_info.value.detail


def test_skip_step_succeeds_when_policy_allows(db):
    """Section 10.5: Changing policy to single_approval enables skip with audit logging"""
    # 1. Manager allows STEP_01 to be single_approval
    update_payload = StepConfigUpdateRequest(
        skip_policy="single_approval",
        approver_roles=["Manager"],
        justification="Freight is CIF handled by supplier per agreement",
    )
    service.update_step_config_service(
        db,
        step_code="STEP_01",
        payload=update_payload,
        current_user_role="MANAGER",
        current_username="manager",
    )

    # 2. Activity in progress
    repo.save_or_update_activity(
        db,
        import_file_code="IMP-2026-0004",
        step_code="STEP_01",
        status="In-Progress",
    )

    # 3. Execute skip
    payload = SkipStepPayload(
        import_file_code="IMP-2026-0004",
        current_step_code="STEP_01",
        skip_reason="Shipment CIF, freight study not needed",
        next_step_codes=["STEP_02"],
    )
    res = service.skip_step_service(
        db,
        payload,
        current_user_role="MANAGER",
        current_username="manager",
    )
    assert res["skipped_step"] == "STEP_01"
    assert res["skip_policy"] == "single_approval"

    # Verify DB state
    act = repo.get_activity(db, "IMP-2026-0004", "STEP_01")
    assert act.status == "Skipped"

    # Verify Central Audit Log
    logs = db.query(AuditLog).filter(AuditLog.action == "SKIP_STAGE").all()
    assert len(logs) >= 1
    assert "STEP_01" in logs[-1].changes_summary


def test_register_pending_reference_eligibility_rejection(db):
    """Section 10.4: If step does not support pending reference, rejected with HTTP 400"""
    payload = RegisterPendingReferenceRequest(
        import_file_code="IMP-2026-0004",
        step_code="STEP_05",
        reference_number="ACID-REF-10029",
        reason_text="Pending final Nafeza issuance",
    )

    with pytest.raises(HTTPException) as exc_info:
        service.register_pending_reference_service(db, payload, current_username="operator")
    assert exc_info.value.status_code == 400
    assert "غير مؤهلة لتسجيل مرجع معلق" in exc_info.value.detail


def test_register_pending_reference_success_and_non_completion(db):
    """Section 10.4: Bank Form 4 scenario - records ref, status is 6th distinct, step NOT completed"""
    # 1. Enable supports_pending_reference on STEP_12
    cfg_payload = StepConfigUpdateRequest(
        skip_policy="dual_approval",
        supports_pending_reference=True,
        justification="Enable Bank Form 4 early reference registration",
    )
    service.update_step_config_service(
        db,
        step_code="STEP_12",
        payload=cfg_payload,
        current_user_role="MANAGER",
        current_username="manager",
    )

    # 2. Register pending reference
    ref_payload = RegisterPendingReferenceRequest(
        import_file_code="IMP-2026-0004",
        step_code="STEP_12",
        reference_number="FORM4-BANK-MISR-88301",
        reason_text="Awaiting final commercial stamp from central bank branch",
        expected_completion_date="2026-09-20",
    )
    res = service.register_pending_reference_service(
        db,
        ref_payload,
        current_username="ahmed_ops",
    )
    assert res.reference_number == "FORM4-BANK-MISR-88301"
    assert res.status == "Reference recorded – pending full documentation"

    # 3. Verify stage activity: status is 6th distinct, completed_at is None
    act = repo.get_activity(db, "IMP-2026-0004", "STEP_12")
    assert act is not None
    assert act.status == "Reference recorded – pending full documentation"
    assert act.completed_at is None # CRITICAL: Step remains incomplete!
    assert "FORM4-BANK-MISR-88301" in act.action_data

    # 4. Verify dedicated PendingReferenceRecord
    pending_refs = repo.get_pending_references(db, import_file_code="IMP-2026-0004", step_code="STEP_12")
    assert len(pending_refs) == 1
    assert pending_refs[0].reference_number == "FORM4-BANK-MISR-88301"
    assert pending_refs[0].status == "Pending Documentation"
