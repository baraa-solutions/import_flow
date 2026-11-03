"""
Unit Tests for Lifecycle Board Guards, RBAC Permissions, and Acting User (BEX-T01).

Acceptance Criteria:
1. AUDITOR_VIEWER: POST /stages/sync -> 403; GET /summary -> 200.
2. LOGISTICS_OPERATOR on a file whose only In-Progress step is STEP_05:
   - sync STEP_21 -> 409 LC_CLOSURE_STEP_RESERVED
   - sync STEP_10 -> 409 LC_STEP_NOT_ACTIVE
   - sync STEP_05 -> 200, and STEP_01..04 are not touched when they were not In-Progress.
3. Unknown code IMP-2099-9999 -> 404 LC_FILE_NOT_FOUND and
   SELECT count(*) FROM shipment_stage_activity WHERE import_file_code='IMP-2099-9999' == 0.
   Missing code & id -> 422 LC_FILE_REF_REQUIRED.
   Closed/Archived/On Hold files -> 409 LC_FILE_NOT_ACTIVE.
4. The completed activity's assigned_user == token's username even if body sends assigned_user="ceo".
5. ADMIN with auto_complete_prior=True on STEP_07 completes STEP_01..STEP_06.
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main
import modules.auth.permissions as auth_permissions
import modules.lifecycle_board.repository as repo
from database.database import Base, get_db
from modules.auth.permissions import invalidate_permission_cache
from modules.auth.security import create_access_token, hash_password
from modules.auth.seed_rbac import seed_rbac
from modules.import_files.model import ImportFile
from modules.lifecycle_board.model import ShipmentStageActivity
from modules.users.model import Role, User

FILE_CODE = "IMP-2026-9001"


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


def _create_user(db, username: str, role_code: str) -> User:
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


def _seed_active_file(db, code: str = FILE_CODE, status: str = "Open", is_active: bool = True) -> ImportFile:
    file_rec = ImportFile(
        import_file_code=code,
        company_name="Test Company Egypt",
        supplier_name="Global Supplier",
        acid_number="5281534391025810014",
        status=status,
        is_active=is_active,
    )
    db.add(file_rec)
    db.commit()
    db.refresh(file_rec)
    return file_rec


# ─── Test 1: RBAC Enforcement for AUDITOR_VIEWER vs LOGISTICS_OPERATOR ───────

def test_auditor_viewer_rbac_permissions(client, test_db):
    """AUDITOR_VIEWER has lifecycle_board.view but lacks lifecycle_board.advance."""
    auditor = _create_user(test_db, "auditor_user", "AUDITOR_VIEWER")
    headers = _auth_headers(auditor)

    # 1. GET /summary succeeds (200)
    resp = client.get("/api/v1/lifecycle-board/summary", headers=headers)
    assert resp.status_code == 200, resp.text

    # 2. GET /step-configs succeeds (200)
    resp = client.get("/api/v1/lifecycle-board/step-configs", headers=headers)
    assert resp.status_code == 200, resp.text

    # 3. POST /stages/sync is denied (403)
    sync_payload = {
        "completed_step_code": "STEP_05",
        "import_file_code": FILE_CODE,
    }
    resp = client.post("/api/v1/lifecycle-board/stages/sync", json=sync_payload, headers=headers)
    assert resp.status_code == 403, resp.text
    assert "lifecycle_board.advance" in resp.json()["detail"]

    # 4. POST /stages/advance is denied (403)
    advance_payload = {
        "import_file_code": FILE_CODE,
        "current_step_code": "STEP_05",
    }
    resp = client.post("/api/v1/lifecycle-board/stages/advance", json=advance_payload, headers=headers)
    assert resp.status_code == 403, resp.text


# ─── Test 2: Active Step Guards & Closure Step Reservation ──────────────────

def test_logistics_operator_active_step_guards(client, test_db):
    """
    LOGISTICS_OPERATOR on a file whose only In-Progress step is STEP_05:
    - sync STEP_21 -> 409 LC_CLOSURE_STEP_RESERVED
    - sync STEP_10 -> 409 LC_STEP_NOT_ACTIVE
    - sync STEP_05 -> 200, and STEP_01..04 remain untouched (not auto-completed).
    """
    _seed_active_file(test_db, FILE_CODE)
    repo.save_or_update_activity(test_db, FILE_CODE, "STEP_05", status="In-Progress")

    operator = _create_user(test_db, "operator_user", "LOGISTICS_OPERATOR")
    headers = _auth_headers(operator)

    # Case A: Attempt STEP_21 via HTTP -> 409 LC_CLOSURE_STEP_RESERVED
    resp = client.post("/api/v1/lifecycle-board/stages/sync", json={
        "completed_step_code": "STEP_21",
        "import_file_code": FILE_CODE,
    }, headers=headers)
    assert resp.status_code == 409, resp.text
    detail = resp.json()["detail"]
    assert detail["code"] == "LC_CLOSURE_STEP_RESERVED"

    # Case B: Attempt STEP_10 which is not In-Progress -> 409 LC_STEP_NOT_ACTIVE
    resp = client.post("/api/v1/lifecycle-board/stages/sync", json={
        "completed_step_code": "STEP_10",
        "import_file_code": FILE_CODE,
    }, headers=headers)
    assert resp.status_code == 409, resp.text
    detail = resp.json()["detail"]
    assert detail["code"] == "LC_STEP_NOT_ACTIVE"
    assert detail["step_code"] == "STEP_10"

    # Case C: Advance STEP_05 (currently In-Progress) -> 200 OK
    resp = client.post("/api/v1/lifecycle-board/stages/sync", json={
        "completed_step_code": "STEP_05",
        "import_file_code": FILE_CODE,
        "auto_complete_prior": True,  # Non-admin: ignored / forced False
    }, headers=headers)
    assert resp.status_code == 200, resp.text

    # Verify STEP_05 is completed
    act_05 = repo.get_activity(test_db, FILE_CODE, "STEP_05")
    assert act_05 is not None
    assert act_05.status == "Completed"

    # Verify STEP_01..STEP_04 were NOT touched or created as Completed
    for prior in ["STEP_01", "STEP_02", "STEP_03", "STEP_04"]:
        act_prior = repo.get_activity(test_db, FILE_CODE, prior)
        assert act_prior is None, f"{prior} should not have been created/completed"


# ─── Test 3: Unknown File 404, No Orphans, and File Status Guards ────────────

def test_unknown_file_returns_404_and_leaves_no_orphan_rows(client, test_db):
    """Unknown code IMP-2099-9999 -> 404 and zero activities in DB."""
    operator = _create_user(test_db, "operator_user2", "LOGISTICS_OPERATOR")
    headers = _auth_headers(operator)
    unknown_code = "IMP-2099-9999"

    resp = client.post("/api/v1/lifecycle-board/stages/sync", json={
        "completed_step_code": "STEP_05",
        "import_file_code": unknown_code,
    }, headers=headers)
    assert resp.status_code == 404, resp.text
    assert resp.json()["detail"]["code"] == "LC_FILE_NOT_FOUND"

    # Verify zero activities were created for the unknown file
    count = test_db.query(ShipmentStageActivity).filter(
        ShipmentStageActivity.import_file_code == unknown_code
    ).count()
    assert count == 0


def test_missing_file_ref_returns_422(client, test_db):
    """Missing both import_file_code and import_file_id -> 422 LC_FILE_REF_REQUIRED."""
    operator = _create_user(test_db, "operator_user3", "LOGISTICS_OPERATOR")
    headers = _auth_headers(operator)

    resp = client.post("/api/v1/lifecycle-board/stages/sync", json={
        "completed_step_code": "STEP_05",
    }, headers=headers)
    assert resp.status_code == 422, resp.text
    assert resp.json()["detail"]["code"] == "LC_FILE_REF_REQUIRED"


@pytest.mark.parametrize("bad_status", ["Closed", "Archived", "On Hold"])
def test_inactive_file_status_conflict_guards(client, test_db, bad_status):
    """Files in Closed, Archived, or On Hold state return 409 LC_FILE_NOT_ACTIVE."""
    code = f"IMP-STATUS-{bad_status.replace(' ', '')}"
    _seed_active_file(test_db, code=code, status=bad_status)
    repo.save_or_update_activity(test_db, code, "STEP_05", status="In-Progress")

    operator = _create_user(test_db, f"op_{bad_status.lower()[:3]}", "LOGISTICS_OPERATOR")
    headers = _auth_headers(operator)

    resp = client.post("/api/v1/lifecycle-board/stages/sync", json={
        "completed_step_code": "STEP_05",
        "import_file_code": code,
    }, headers=headers)
    assert resp.status_code == 409, resp.text
    detail = resp.json()["detail"]
    assert detail["code"] == "LC_FILE_NOT_ACTIVE"
    assert detail["status"] == bad_status


def test_soft_deleted_file_returns_404(client, test_db):
    """A soft-deleted (is_active=False) file returns 404 LC_FILE_NOT_FOUND."""
    code = "IMP-DELETED-01"
    _seed_active_file(test_db, code=code, is_active=False)

    operator = _create_user(test_db, "op_deleted", "LOGISTICS_OPERATOR")
    headers = _auth_headers(operator)

    resp = client.post("/api/v1/lifecycle-board/stages/sync", json={
        "completed_step_code": "STEP_05",
        "import_file_code": code,
    }, headers=headers)
    assert resp.status_code == 404, resp.text
    assert resp.json()["detail"]["code"] == "LC_FILE_NOT_FOUND"


# ─── Test 4: Acting User Derivation from Token ──────────────────────────────

def test_acting_user_recorded_from_token_not_payload(client, test_db):
    """
    The completed activity's assigned_user is strictly derived from the JWT actor,
    ignoring any assigned_user supplied in the request body.
    """
    _seed_active_file(test_db, FILE_CODE)
    repo.save_or_update_activity(test_db, FILE_CODE, "STEP_05", status="In-Progress")

    operator = _create_user(test_db, "real_operator", "LOGISTICS_OPERATOR")
    headers = _auth_headers(operator)

    resp = client.post("/api/v1/lifecycle-board/stages/sync", json={
        "completed_step_code": "STEP_05",
        "import_file_code": FILE_CODE,
        "assigned_user": "ceo_spoofer",  # Should be completely ignored
    }, headers=headers)
    assert resp.status_code == 200, resp.text

    act = repo.get_activity(test_db, FILE_CODE, "STEP_05")
    assert act.assigned_user == "real_operator"
    assert act.assigned_user != "ceo_spoofer"


# ─── Test 5: Admin auto_complete_prior completes prior steps ────────────────

def test_admin_auto_complete_prior_completes_prior_steps(client, test_db):
    """
    ADMIN with auto_complete_prior=True on STEP_07 completes STEP_01..STEP_06.
    """
    file_code = "IMP-ADMIN-FLOW-01"
    _seed_active_file(test_db, file_code)
    repo.save_or_update_activity(test_db, file_code, "STEP_07", status="In-Progress")

    admin = _create_user(test_db, "admin_user", "ADMIN")
    headers = _auth_headers(admin)

    resp = client.post("/api/v1/lifecycle-board/stages/sync", json={
        "completed_step_code": "STEP_07",
        "import_file_code": file_code,
        "auto_complete_prior": True,
    }, headers=headers)
    assert resp.status_code == 200, resp.text

    # Assert STEP_07 completed
    act_07 = repo.get_activity(test_db, file_code, "STEP_07")
    assert act_07.status == "Completed"
    assert act_07.assigned_user == "admin_user"

    # Assert prior steps STEP_01 through STEP_06 were auto-completed
    for step_num in range(1, 7):
        code = f"STEP_0{step_num}"
        act = repo.get_activity(test_db, file_code, code)
        assert act is not None, f"Expected {code} to be auto-completed"
        assert act.status == "Completed"


# ─── Test 6: Advance from Reference Recorded Status ─────────────────────────

def test_advance_step_with_pending_reference_status(client, test_db):
    """
    A step with 'Reference recorded – pending full documentation' is accepted as active.
    """
    file_code = "IMP-PENDING-REF-01"
    _seed_active_file(test_db, file_code)
    repo.save_or_update_activity(
        test_db,
        file_code,
        "STEP_05",
        status="Reference recorded – pending full documentation",
    )

    operator = _create_user(test_db, "op_ref", "LOGISTICS_OPERATOR")
    headers = _auth_headers(operator)

    resp = client.post("/api/v1/lifecycle-board/stages/sync", json={
        "completed_step_code": "STEP_05",
        "import_file_code": file_code,
    }, headers=headers)
    assert resp.status_code == 200, resp.text

    act_05 = repo.get_activity(test_db, file_code, "STEP_05")
    assert act_05.status == "Completed"


# ─── Test 7: set-active guards against already Completed or Skipped steps ───

def test_set_active_rejects_completed_or_skipped_steps(client, test_db):
    """
    POST /stages/set-active rejects steps already marked Completed or Skipped with 409 LC_STEP_ALREADY_COMPLETED.
    """
    file_code = "IMP-SET-ACTIVE-01"
    _seed_active_file(test_db, file_code)
    repo.save_or_update_activity(test_db, file_code, "STEP_01", status="Completed")
    repo.save_or_update_activity(test_db, file_code, "STEP_02", status="Skipped")

    operator = _create_user(test_db, "op_set_act", "LOGISTICS_OPERATOR")
    headers = _auth_headers(operator)

    # Trying to re-open Completed STEP_01
    resp = client.post("/api/v1/lifecycle-board/stages/set-active", json={
        "import_file_code": file_code,
        "active_step_codes": ["STEP_01"],
    }, headers=headers)
    assert resp.status_code == 409, resp.text
    assert resp.json()["detail"]["code"] == "LC_STEP_ALREADY_COMPLETED"

    # Trying to re-open Skipped STEP_02
    resp2 = client.post("/api/v1/lifecycle-board/stages/set-active", json={
        "import_file_code": file_code,
        "active_step_codes": ["STEP_02"],
    }, headers=headers)
    assert resp2.status_code == 409, resp2.text
    assert resp2.json()["detail"]["code"] == "LC_STEP_ALREADY_COMPLETED"


# ─── Test 8: set-active sequence guards for non-admin vs admin ───────────────

def test_set_active_sequence_guard_non_admin(client, test_db):
    """
    Non-admin cannot jump forward via set-active (409 LC_STEP_SEQUENCE_INVALID),
    while an admin can set any valid uncompleted step active.
    Actor's username is stored in assigned_user.
    """
    file_code = "IMP-SET-ACTIVE-02"
    _seed_active_file(test_db, file_code)
    repo.save_or_update_activity(test_db, file_code, "STEP_05", status="In-Progress")

    operator = _create_user(test_db, "op_seq_guard", "LOGISTICS_OPERATOR")
    op_headers = _auth_headers(operator)

    # Non-admin attempting to jump ahead to STEP_19
    resp = client.post("/api/v1/lifecycle-board/stages/set-active", json={
        "import_file_code": file_code,
        "active_step_codes": ["STEP_19"],
    }, headers=op_headers)
    assert resp.status_code == 409, resp.text
    assert resp.json()["detail"]["code"] == "LC_STEP_SEQUENCE_INVALID"

    # Non-admin activating current step STEP_05 (e.g. resume) succeeds and sets assigned_user
    resp_ok = client.post("/api/v1/lifecycle-board/stages/set-active", json={
        "import_file_code": file_code,
        "active_step_codes": ["STEP_05"],
    }, headers=op_headers)
    assert resp_ok.status_code == 200, resp_ok.text
    act_05 = repo.get_activity(test_db, file_code, "STEP_05")
    assert act_05.assigned_user == "op_seq_guard"

    # Admin attempting to activate STEP_19 succeeds
    admin = _create_user(test_db, "admin_seq_override", "ADMIN")
    admin_headers = _auth_headers(admin)

    resp_admin = client.post("/api/v1/lifecycle-board/stages/set-active", json={
        "import_file_code": file_code,
        "active_step_codes": ["STEP_19"],
    }, headers=admin_headers)
    assert resp_admin.status_code == 200, resp_admin.text
    act_19 = repo.get_activity(test_db, file_code, "STEP_19")
    assert act_19.status == "In-Progress"
    assert act_19.assigned_user == "admin_seq_override"


# ─── Test 9: target_step_codes guard on advance / sync for non-admin ─────────

def test_target_step_codes_guard_non_admin(client, test_db):
    """
    Non-admin cannot jump through target_step_codes on sync or advance (409 LC_TARGET_STEP_INVALID).
    Admin can specify forward target steps.
    """
    file_code = "IMP-TARGET-GUARD-01"
    _seed_active_file(test_db, file_code)
    repo.save_or_update_activity(test_db, file_code, "STEP_05", status="In-Progress")

    operator = _create_user(test_db, "op_tgt_guard", "LOGISTICS_OPERATOR")
    op_headers = _auth_headers(operator)

    # Non-admin attempting to target STEP_19 from STEP_05 on sync
    resp_sync = client.post("/api/v1/lifecycle-board/stages/sync", json={
        "completed_step_code": "STEP_05",
        "import_file_code": file_code,
        "target_step_codes": ["STEP_19"],
    }, headers=op_headers)
    assert resp_sync.status_code == 409, resp_sync.text
    assert resp_sync.json()["detail"]["code"] == "LC_TARGET_STEP_INVALID"

    # Non-admin advancing to natural next STEP_06 succeeds
    resp_sync_ok = client.post("/api/v1/lifecycle-board/stages/sync", json={
        "completed_step_code": "STEP_05",
        "import_file_code": file_code,
        "target_step_codes": ["STEP_06"],
    }, headers=op_headers)
    assert resp_sync_ok.status_code == 200, resp_sync_ok.text

    # Now file is at STEP_06. Admin can advance to STEP_10 directly
    admin = _create_user(test_db, "admin_tgt_guard", "ADMIN")
    admin_headers = _auth_headers(admin)

    resp_admin = client.post("/api/v1/lifecycle-board/stages/sync", json={
        "completed_step_code": "STEP_06",
        "import_file_code": file_code,
        "target_step_codes": ["STEP_10"],
    }, headers=admin_headers)
    assert resp_admin.status_code == 200, resp_admin.text
    act_10 = repo.get_activity(test_db, file_code, "STEP_10")
    assert act_10.status == "In-Progress"
