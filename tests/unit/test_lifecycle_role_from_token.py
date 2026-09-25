"""
The lifecycle board takes the caller role from the authenticated user (JWT), never from X-User-Role.
"""

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main
import modules.auth.permissions as auth_permissions
import modules.lifecycle_board.repository as repo
import modules.lifecycle_board.service as service
from database.database import Base, get_db
from modules.auth.permissions import invalidate_permission_cache
from modules.auth.security import create_access_token, hash_password
from modules.import_files.model import ImportFile
from modules.lifecycle_board.schemas import SkipStepPayload, StepConfigUpdateRequest
from modules.users.model import User

FILE_CODE = "IMP-2026-0777"
STEP = "STEP_06"


@pytest.fixture
def db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(bind=engine)()
    session.add(ImportFile(import_file_code=FILE_CODE, company_name="Co", supplier_name="Sup", status="Draft", is_active=True))
    session.commit()
    # Make STEP_06 skippable with Manager approval.
    service.update_step_config_service(
        session,
        step_code=STEP,
        payload=StepConfigUpdateRequest(
            skip_policy="single_approval",
            approver_roles=["Manager"],
            justification="Allow freight skip for CIF shipments",
        ),
        current_user_role="MANAGER",
        current_username="seed",
    )
    repo.save_or_update_activity(session, import_file_code=FILE_CODE, step_code=STEP, status="In-Progress")
    invalidate_permission_cache()
    yield session
    session.close()
    invalidate_permission_cache()
    engine.dispose()


def _user(db, username: str, role: str) -> User:
    user = User(
        username=username,
        email=f"{username}@test.com",
        full_name=username,
        hashed_password=hash_password("Password123"),
        role=role,
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _headers(user: User, forged_role: str = "ADMIN") -> dict:
    token = create_access_token({"sub": str(user.user_id), "role": user.role})
    return {"Authorization": f"Bearer {token}", "X-User-Role": forged_role, "X-User-Name": "admin"}


@pytest.fixture
def client(db, monkeypatch):
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)

    def override_get_db():
        yield db

    main.app.dependency_overrides[get_db] = override_get_db
    try:
        yield TestClient(main.app)
    finally:
        main.app.dependency_overrides.pop(get_db, None)


def _skip_body() -> dict:
    return {
        "import_file_code": FILE_CODE,
        "current_step_code": STEP,
        "skip_reason": "CIF shipment, freight booked by supplier",
        "next_step_codes": ["STEP_08"],
    }


def _config_body() -> dict:
    return {"skip_policy": "single_approval", "approver_roles": ["Manager"], "justification": "Policy review update"}


def test_operator_with_forged_admin_header_cannot_skip(client, db):
    operator = _user(db, "op_forger", "LOGISTICS_OPERATOR")
    response = client.post("/api/v1/lifecycle-board/stages/skip", json=_skip_body(), headers=_headers(operator))
    assert response.status_code == 403, response.text
    assert "LOGISTICS_OPERATOR" in response.json()["detail"]
    assert repo.get_activity(db, FILE_CODE, STEP).status == "In-Progress"


def test_operator_with_forged_admin_header_cannot_update_step_config(client, db):
    operator = _user(db, "op_forger2", "OPERATOR")
    response = client.put(f"/api/v1/lifecycle-board/step-configs/{STEP}", json=_config_body(), headers=_headers(operator))
    assert response.status_code == 403, response.text


def test_manager_token_can_skip(client, db):
    manager = _user(db, "gm_user", "GENERAL_MANAGER")
    response = client.post("/api/v1/lifecycle-board/stages/skip", json=_skip_body(), headers=_headers(manager, forged_role="OPERATOR"))
    assert response.status_code == 200, response.text
    assert response.json()["skipped_step"] == STEP
    assert repo.get_activity(db, FILE_CODE, STEP).status == "Skipped"


def test_manager_token_can_update_step_config(client, db):
    manager = _user(db, "mgr_user", "MANAGER")
    response = client.put(f"/api/v1/lifecycle-board/step-configs/{STEP}", json=_config_body(), headers=_headers(manager))
    assert response.status_code == 200, response.text


def test_legacy_admin_with_non_admin_role_id_can_skip_and_configure(client, db):
    """require_admin accepts role="ADMIN" regardless of role_id; the lifecycle checks must agree."""
    from modules.auth.seed_rbac import seed_rbac
    from modules.users.model import Role

    seed_rbac(db)
    finance_role = db.query(Role).filter(Role.role_code == "FINANCE_OFFICER").one()
    mixed = _user(db, "mixed_admin", "ADMIN")
    mixed.role_id = finance_role.role_id
    db.commit()
    invalidate_permission_cache()

    response = client.put(f"/api/v1/lifecycle-board/step-configs/{STEP}", json=_config_body(), headers=_headers(mixed, forged_role="OPERATOR"))
    assert response.status_code == 200, response.text
    response = client.post("/api/v1/lifecycle-board/stages/skip", json=_skip_body(), headers=_headers(mixed, forged_role="OPERATOR"))
    assert response.status_code == 200, response.text


def test_lifecycle_routes_require_token(client):
    assert client.get("/api/v1/lifecycle-board/summary").status_code == 401
    assert client.post("/api/v1/lifecycle-board/stages/skip", json=_skip_body(), headers={"X-User-Role": "ADMIN"}).status_code == 401


@pytest.mark.parametrize("role", [None, "", "   "])
def test_skip_service_without_role_is_403(db, role):
    payload = SkipStepPayload(
        import_file_code=FILE_CODE,
        current_step_code=STEP,
        skip_reason="CIF shipment, freight booked by supplier",
        next_step_codes=["STEP_08"],
    )
    with pytest.raises(HTTPException) as exc:
        service.skip_step_service(db, payload, current_user_role=role)
    assert exc.value.status_code == 403
    assert exc.value.detail == "تعذر تحديد دور المستخدم."
    assert repo.get_activity(db, FILE_CODE, STEP).status == "In-Progress"
