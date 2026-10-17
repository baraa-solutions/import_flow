"""
Unit Tests for Lifecycle Board Transactions, Skip Policy, and Config Authorisation (BEX-T02).

Acceptance Criteria:
1. Forced exception after prior-step updates (monkeypatch `_close_step_tasks` to raise) leaves no activity
   changed (atomic rollback; count of Completed activities before / after equal).
2. Skip on a `dual_approval` step:
   - Non-ADMIN (including GENERAL_MANAGER) -> 409 LC_SKIP_DUAL_APPROVAL_REQUIRED.
   - ADMIN -> 200 OK, step is marked Skipped with audit log.
3. Update step config with unknown approver role:
   - `approver_roles=["NOPE"]` -> 422 LC_APPROVER_ROLE_UNKNOWN.
4. Route permissions on `PUT /api/v1/lifecycle-board/step-configs/{step_code}`:
   - Requires `users.manage` (non-holders receive 403; ADMIN and users with users.manage receive 200).
5. `commit=False` parameter on `advance_lifecycle_step_service` allows caller-controlled transactions.
6. Atomic single-transaction writes for skip and register_pending_reference with AuditLog.
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main
import modules.auth.permissions as auth_permissions
import modules.lifecycle_board.repository as repo
import modules.lifecycle_board.service as service
from database.database import Base, get_db
from modules.audit_logs.model import AuditLog
from modules.auth.permissions import invalidate_permission_cache
from modules.auth.security import create_access_token, hash_password
from modules.auth.seed_rbac import seed_rbac
from modules.common.errors import CodedHTTPException
from modules.import_files.model import ImportFile
from modules.lifecycle_board.model import PendingReferenceRecord, ShipmentStageActivity, StepConfig
from modules.lifecycle_board.schemas import (
    RegisterPendingReferenceRequest,
    SkipStepPayload,
    StepConfigUpdateRequest,
)
from modules.users.model import Permission, Role, User, UserPermission

FILE_CODE = "IMP-2026-8801"


@pytest.fixture
def test_db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(bind=engine)()
    seed_rbac(session)
    invalidate_permission_cache()
    yield session
    session.close()
    invalidate_permission_cache()
    engine.dispose()


def _create_user(db, username: str, role_code: str, extra_permissions: tuple = ()) -> User:
    role = db.query(Role).filter(Role.role_code == role_code).one()
    user = User(
        username=username,
        email=f"{username}@sorourlogistics.com",
        full_name=f"Test {username}",
        hashed_password=hash_password("Secret123!"),
        role=role_code,
        role_id=role.role_id,
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    for perm_code in extra_permissions:
        p = db.query(Permission).filter(Permission.permission_code == perm_code).first()
        if p:
            db.add(UserPermission(user_id=user.user_id, permission_id=p.permission_id, is_granted=True))
    if extra_permissions:
        db.commit()
        invalidate_permission_cache()

    return user


def _auth_headers(user: User) -> dict:
    token = create_access_token({"sub": str(user.user_id), "role": user.role})
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def client(test_db, monkeypatch):
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)

    def override_get_db():
        yield test_db

    main.app.dependency_overrides[get_db] = override_get_db
    try:
        with TestClient(main.app) as c:
            yield c
    finally:
        main.app.dependency_overrides.pop(get_db, None)


def _seed_active_file(db, code: str = FILE_CODE) -> ImportFile:
    file_rec = ImportFile(
        import_file_code=code,
        company_name="Test Enterprise Cairo",
        supplier_name="Global Supplier Co",
        status="Open",
        is_active=True,
    )
    db.add(file_rec)
    db.commit()
    db.refresh(file_rec)
    return file_rec


# ─── 1. Atomic Rollback Test ──────────────────────────────────────────────────

def test_advance_atomic_rollback_on_task_creation_failure(test_db, monkeypatch):
    """Monkeypatching _close_step_tasks to raise causes complete rollback:

    No activities remain Completed when the transaction is aborted.
    """
    _seed_active_file(test_db)

    # Seed prior steps as In-Progress
    repo.save_or_update_activity(test_db, FILE_CODE, "STEP_01", status="In-Progress")
    repo.save_or_update_activity(test_db, FILE_CODE, "STEP_02", status="In-Progress")
    repo.save_or_update_activity(test_db, FILE_CODE, "STEP_03", status="In-Progress")
    test_db.commit()

    completed_before = test_db.query(ShipmentStageActivity).filter(
        ShipmentStageActivity.import_file_code == FILE_CODE,
        ShipmentStageActivity.status == "Completed",
    ).count()
    assert completed_before == 0

    # Simulate unexpected failure during task management (step 9 of advance service)
    def boom(*args, **kwargs):
        raise RuntimeError("Simulated crash during SmartTask synchronization")

    monkeypatch.setattr(service, "_close_step_tasks", boom)

    with pytest.raises(RuntimeError, match="Simulated crash"):
        try:
            service.advance_lifecycle_step_service(
                db=test_db,
                completed_step_code="STEP_03",
                import_file_code=FILE_CODE,
                target_step_codes=["STEP_04"],
                auto_complete_prior=True,
            )
        except Exception:
            test_db.rollback()
            raise

    # Verify atomic rollback: no activity was committed as Completed
    completed_after = test_db.query(ShipmentStageActivity).filter(
        ShipmentStageActivity.import_file_code == FILE_CODE,
        ShipmentStageActivity.status == "Completed",
    ).count()
    assert completed_after == 0

    # Original steps are still in their original state
    step1 = repo.get_activity(test_db, FILE_CODE, "STEP_01")
    assert step1.status == "In-Progress"
    step2 = repo.get_activity(test_db, FILE_CODE, "STEP_02")
    assert step2.status == "In-Progress"
    step3 = repo.get_activity(test_db, FILE_CODE, "STEP_03")
    assert step3.status == "In-Progress"


# ─── 2. Caller-controlled commit: bool = False ───────────────────────────────

def test_advance_with_commit_false_leaves_uncommitted_work(test_db):
    """Passing commit=False flushes the changes without committing, allowing the caller

    to roll back completely.
    """
    _seed_active_file(test_db)
    repo.save_or_update_activity(test_db, FILE_CODE, "STEP_01", status="In-Progress")
    test_db.commit()

    service.advance_lifecycle_step_service(
        db=test_db,
        completed_step_code="STEP_01",
        import_file_code=FILE_CODE,
        target_step_codes=["STEP_02"],
        commit=False,
    )

    # Caller explicitly aborts transaction
    test_db.rollback()

    act = repo.get_activity(test_db, FILE_CODE, "STEP_01")
    assert act.status == "In-Progress"
    step2 = repo.get_activity(test_db, FILE_CODE, "STEP_02")
    assert step2 is None


# ─── 3. Dual Approval Skip Policy: Non-Admin 409 vs Admin 200 ────────────────

def test_skip_dual_approval_policy_enforcement(client, test_db):
    """Steps configured with skip_policy="dual_approval" require ADMIN.

    GENERAL_MANAGER and LOGISTICS_OPERATOR receive 409 LC_SKIP_DUAL_APPROVAL_REQUIRED.
    ADMIN succeeds with 200.
    """
    _seed_active_file(test_db)
    repo.save_or_update_activity(test_db, FILE_CODE, "STEP_05", status="In-Progress")
    test_db.commit()

    # Configure STEP_05 with dual_approval policy
    service.update_step_config_service(
        db=test_db,
        step_code="STEP_05",
        payload=StepConfigUpdateRequest(
            skip_policy="dual_approval",
            approver_roles=["GENERAL_MANAGER"],
            justification="Requires strict dual signature approval",
        ),
        current_username="sys_admin",
    )

    gm_user = _create_user(test_db, "general_mgr", "GENERAL_MANAGER")
    admin_user = _create_user(test_db, "admin_user", "ADMIN")

    skip_payload = {
        "import_file_code": FILE_CODE,
        "current_step_code": "STEP_05",
        "skip_reason": "Skipping step 5 per regulatory dispensation",
        "next_step_codes": ["STEP_06"],
    }

    # 1. Non-admin (GENERAL_MANAGER) receives 409 LC_SKIP_DUAL_APPROVAL_REQUIRED
    res_gm = client.post(
        "/api/v1/lifecycle-board/stages/skip",
        json=skip_payload,
        headers=_auth_headers(gm_user),
    )
    assert res_gm.status_code == 409, res_gm.text
    err_body = res_gm.json()["detail"]
    assert err_body["code"] == "LC_SKIP_DUAL_APPROVAL_REQUIRED"
    assert err_body["step_code"] == "STEP_05"

    # Step remains In-Progress
    act = repo.get_activity(test_db, FILE_CODE, "STEP_05")
    assert act.status == "In-Progress"

    # 2. ADMIN receives 200 OK and skips successfully
    res_admin = client.post(
        "/api/v1/lifecycle-board/stages/skip",
        json=skip_payload,
        headers=_auth_headers(admin_user),
    )
    assert res_admin.status_code == 200, res_admin.text
    assert res_admin.json()["skipped_step"] == "STEP_05"
    assert res_admin.json()["skip_policy"] == "dual_approval"

    # Step is now Skipped and next step is activated
    act_after = repo.get_activity(test_db, FILE_CODE, "STEP_05")
    assert act_after.status == "Skipped"

    # Audit log was created
    audit = test_db.query(AuditLog).filter(
        AuditLog.entity_code == FILE_CODE,
        AuditLog.action == "SKIP_STAGE",
    ).first()
    assert audit is not None
    assert audit.performed_by == admin_user.username


# ─── 4. Unknown Approver Roles Validation (422 LC_APPROVER_ROLE_UNKNOWN) ──────

def test_update_step_config_rejects_unknown_approver_roles(test_db):
    """Setting approver_roles to a role that does not exist in roles table raises 422."""
    payload = StepConfigUpdateRequest(
        approver_roles=["NOT_A_REAL_ROLE"],
        justification="Testing unknown role validation",
    )

    with pytest.raises(CodedHTTPException) as exc_info:
        service.update_step_config_service(
            db=test_db,
            step_code="STEP_07",
            payload=payload,
        )

    assert exc_info.value.status_code == 422
    assert exc_info.value.code == "LC_APPROVER_ROLE_UNKNOWN"
    assert exc_info.value.params["role_code"] == "NOT_A_REAL_ROLE"


def test_update_step_config_accepts_valid_system_roles(test_db):
    """Setting approver_roles to known roles (e.g. GENERAL_MANAGER, ADMIN) succeeds."""
    payload = StepConfigUpdateRequest(
        skip_policy="single_approval",
        approver_roles=["GENERAL_MANAGER", "ADMIN"],
        justification="Valid system roles assigned for step approval",
    )

    res = service.update_step_config_service(
        db=test_db,
        step_code="STEP_07",
        payload=payload,
        current_username="admin_user",
    )

    assert res.skip_policy == "single_approval"
    assert res.approver_roles == ["GENERAL_MANAGER", "ADMIN"]


# ─── 5. Route Permissions on PUT /step-configs/{step_code} ────────────────────

def test_step_config_route_requires_users_manage_permission(client, test_db):
    """PUT /step-configs/{step_code} requires permission 'users.manage'."""
    operator = _create_user(test_db, "operator_user", "LOGISTICS_OPERATOR")
    gm_without_manage = _create_user(test_db, "gm_no_perm", "GENERAL_MANAGER")
    gm_with_manage = _create_user(
        test_db, "gm_with_perm", "GENERAL_MANAGER", extra_permissions=("users.manage",)
    )
    admin = _create_user(test_db, "super_admin", "ADMIN")

    update_payload = {
        "skip_policy": "single_approval",
        "approver_roles": ["ADMIN"],
        "justification": "Authorized security update",
    }

    # 1. LOGISTICS_OPERATOR without users.manage -> 403 Forbidden
    r1 = client.put(
        "/api/v1/lifecycle-board/step-configs/STEP_08_PO",
        json=update_payload,
        headers=_auth_headers(operator),
    )
    assert r1.status_code == 403, r1.text

    # 2. GENERAL_MANAGER without users.manage -> 403 Forbidden
    r2 = client.put(
        "/api/v1/lifecycle-board/step-configs/STEP_08_PO",
        json=update_payload,
        headers=_auth_headers(gm_without_manage),
    )
    assert r2.status_code == 403, r2.text

    # 3. GENERAL_MANAGER with users.manage -> 200 OK
    r3 = client.put(
        "/api/v1/lifecycle-board/step-configs/STEP_08_PO",
        json=update_payload,
        headers=_auth_headers(gm_with_manage),
    )
    assert r3.status_code == 200, r3.text
    assert r3.json()["skip_policy"] == "single_approval"

    # 4. ADMIN -> 200 OK
    r4 = client.put(
        "/api/v1/lifecycle-board/step-configs/STEP_08_PO",
        json=update_payload,
        headers=_auth_headers(admin),
    )
    assert r4.status_code == 200, r4.text


# ─── 6. Register Pending Reference Single Transaction ─────────────────────────

def test_register_pending_reference_atomic_transaction(test_db):
    """register_pending_reference_service updates activity, creates PendingReferenceRecord,

    and writes AuditLog in a single atomic commit.
    """
    _seed_active_file(test_db)
    repo.save_or_update_activity(test_db, FILE_CODE, "STEP_04", status="In-Progress")
    test_db.commit()

    # Enable pending reference eligibility for STEP_04
    service.update_step_config_service(
        db=test_db,
        step_code="STEP_04",
        payload=StepConfigUpdateRequest(
            supports_pending_reference=True,
            justification="Allow bank transfer reference pending final receipt",
        ),
    )

    req = RegisterPendingReferenceRequest(
        import_file_code=FILE_CODE,
        step_code="STEP_04",
        reference_number="BANK-REF-998877",
        reason_text="Awaiting SWIFT confirmation receipt from central bank",
        expected_completion_date="2026-11-01",
    )

    res = service.register_pending_reference_service(
        db=test_db,
        payload=req,
        current_username="accountant_ops",
    )

    assert res.reference_number == "BANK-REF-998877"
    assert res.status == "Reference recorded – pending full documentation"

    # Verify PendingReferenceRecord committed
    pend_rec = test_db.query(PendingReferenceRecord).filter(
        PendingReferenceRecord.import_file_code == FILE_CODE,
        PendingReferenceRecord.step_code == "STEP_04",
    ).first()
    assert pend_rec is not None
    assert pend_rec.reference_number == "BANK-REF-998877"

    # Verify StageActivity committed with 6th status
    act = repo.get_activity(test_db, FILE_CODE, "STEP_04")
    assert act.status == "Reference recorded – pending full documentation"

    # Verify AuditLog committed
    audit = test_db.query(AuditLog).filter(
        AuditLog.entity_code == FILE_CODE,
        AuditLog.action == "REGISTER_PENDING_REFERENCE",
    ).first()
    assert audit is not None
    assert audit.performed_by == "accountant_ops"
