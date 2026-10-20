import pytest
from datetime import datetime, timezone
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main
from database.database import Base, get_db
from modules.users.model import User, Role, Permission, RolePermission
from modules.auth.security import create_access_token, hash_password


SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="function")
def db_session():
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    main.app.dependency_overrides[get_db] = override_get_db
    with TestClient(main.app) as c:
        yield c
    main.app.dependency_overrides.clear()


def _create_user(db, username: str, permission_codes: list, role_code: str = "OPERATOR", is_admin: bool = False) -> tuple[User, str]:
    assigned_code = "ADMIN" if is_admin else role_code
    if is_admin:
        role = db.query(Role).filter(Role.role_code == "ADMIN").first()
        if not role:
            role = Role(role_code="ADMIN", name_en="ADMIN", name_ar="ADMIN", is_active=True)
            db.add(role)
            db.flush()
    else:
        role_unique_code = f"ROLE_{username.upper()}"
        role = db.query(Role).filter(Role.role_code == role_unique_code).first()
        if not role:
            role = Role(role_code=role_unique_code, name_en=role_unique_code, name_ar=role_unique_code, is_active=True)
            db.add(role)
            db.flush()

    for code in permission_codes:
        perm = db.query(Permission).filter(Permission.permission_code == code).first()
        if not perm:
            perm = Permission(
                permission_code=code,
                module_name="test",
                action="test",
                name_en=code,
                name_ar=code,
            )
            db.add(perm)
            db.flush()
        rp = RolePermission(role_id=role.role_id, permission_id=perm.permission_id)
        db.add(rp)

    user = User(
        username=username,
        email=f"{username}@example.com",
        hashed_password=hash_password("Secret123!"),
        full_name=username,
        role=assigned_code,
        role_id=role.role_id,
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token({"sub": str(user.user_id), "username": user.username, "role": user.role})
    return user, token


def test_smart_tasks_permissions_matrix(client, db_session):
    # User with no permissions (cannot view)
    _, no_perm_token = _create_user(db_session, "no_perm", [])
    h_no_perm = {"Authorization": f"Bearer {no_perm_token}"}
    res_get = client.get("/api/v1/smart-tasks/paginated", headers=h_no_perm)
    assert res_get.status_code == 403

    # User with view only (can view, but cannot edit or sync)
    _, viewer_token = _create_user(db_session, "viewer", ["import_files.view"])
    h_viewer = {"Authorization": f"Bearer {viewer_token}"}
    assert client.get("/api/v1/smart-tasks/paginated", headers=h_viewer).status_code == 200
    assert client.post("/api/v1/smart-tasks", json={"title": "T", "task_code": "TSK-001"}, headers=h_viewer).status_code == 403
    assert client.post("/api/v1/smart-tasks/sync-all-active-files", headers=h_viewer).status_code == 403

    # User with edit (can edit, but cannot sync-all which is require_admin)
    _, editor_token = _create_user(db_session, "editor", ["import_files.view", "import_files.edit"])
    h_editor = {"Authorization": f"Bearer {editor_token}"}
    assert client.post("/api/v1/smart-tasks/sync-all-active-files", headers=h_editor).status_code == 403

    # Admin (can sync all)
    _, admin_token = _create_user(db_session, "admin", [], is_admin=True)
    h_admin = {"Authorization": f"Bearer {admin_token}"}
    res_sync = client.post("/api/v1/smart-tasks/sync-all-active-files", headers=h_admin)
    assert res_sync.status_code in (200, 204)


def test_notifications_permissions_matrix(client, db_session):
    # Regular user can view own notifications, but cannot post or trigger expiry check
    _, reg_token = _create_user(db_session, "reg_user", [])
    h_reg = {"Authorization": f"Bearer {reg_token}"}
    assert client.get("/api/v1/notifications/paginated", headers=h_reg).status_code == 200
    assert client.post("/api/v1/notifications", json={"title": "N", "message": "M"}, headers=h_reg).status_code == 403
    assert client.post("/api/v1/notifications/trigger-expiry-check", headers=h_reg).status_code == 403

    # Admin can post notifications
    _, admin_token = _create_user(db_session, "admin_notif", [], is_admin=True)
    h_admin = {"Authorization": f"Bearer {admin_token}"}
    res_create = client.post(
        "/api/v1/notifications",
        json={"title": "N", "message": "M", "severity": "INFO", "category": "SYSTEM", "target_role": "ALL"},
        headers=h_admin,
    )
    assert res_create.status_code == 201


def test_experience_guide_permissions_matrix(client, db_session):
    # User with no view permission
    _, no_view_token = _create_user(db_session, "no_guide", [])
    h_no_view = {"Authorization": f"Bearer {no_view_token}"}
    assert client.get("/api/v1/experience-guide", headers=h_no_view).status_code == 403

    # User with view only
    _, viewer_token = _create_user(db_session, "guide_viewer", ["import_files.view"], role_code="OPERATOR")
    h_viewer = {"Authorization": f"Bearer {viewer_token}"}
    assert client.get("/api/v1/experience-guide", headers=h_viewer).status_code == 200
    assert client.post("/api/v1/experience-guide/autonomous/recalculate", headers=h_viewer).status_code == 403
    assert client.post("/api/v1/experience-guide", json={"title": "G", "content": "C"}, headers=h_viewer).status_code == 403

    # Operator with edit (cannot promote or reject because not MANAGER or ADMIN)
    _, editor_token = _create_user(db_session, "guide_editor", ["import_files.view", "import_files.edit"], role_code="OPERATOR")
    h_editor = {"Authorization": f"Bearer {editor_token}"}
    assert client.post("/api/v1/experience-guide/1/promote", json={"decision_note": "ok"}, headers=h_editor).status_code == 403
    assert client.post("/api/v1/experience-guide/1/reject", json={"rejection_reason": "bad"}, headers=h_editor).status_code == 403

    # Manager with edit
    _, manager_token = _create_user(db_session, "guide_manager", ["import_files.view", "import_files.edit"], role_code="MANAGER")
    h_manager = {"Authorization": f"Bearer {manager_token}"}
    res_promote = client.post("/api/v1/experience-guide/1/promote", json={"decision_note": "ok"}, headers=h_manager)
    # Entry 1 does not exist -> 404, which proves permission check passed!
    assert res_promote.status_code == 404


def test_smart_email_permissions_matrix(client, db_session):
    # User without import_files.view -> 403 on logs
    _, no_view_token = _create_user(db_session, "no_email_view", [])
    h_no_view = {"Authorization": f"Bearer {no_view_token}"}
    assert client.get("/api/v1/smart-email/logs", headers=h_no_view).status_code == 403
    assert client.get("/api/v1/smart-email/logs/1", headers=h_no_view).status_code == 403

    # User with import_files.view -> 200 on logs
    _, viewer_token = _create_user(db_session, "email_viewer", ["import_files.view"])
    h_viewer = {"Authorization": f"Bearer {viewer_token}"}
    assert client.get("/api/v1/smart-email/logs", headers=h_viewer).status_code == 200


def test_observability_permissions_and_bounds(client, db_session):
    _, user_token = _create_user(db_session, "reg_obs", [], role_code="OPERATOR")
    h_user = {"Authorization": f"Bearer {user_token}"}

    # evaluate without force -> 200
    res_eval = client.post("/api/v1/system/observability/alerts/evaluate?force=false", headers=h_user)
    assert res_eval.status_code == 200

    # evaluate with force=true as non-admin -> 403
    res_eval_force = client.post("/api/v1/system/observability/alerts/evaluate?force=true", headers=h_user)
    assert res_eval_force.status_code == 403

    # as admin -> 200
    _, admin_token = _create_user(db_session, "admin_obs", [], is_admin=True)
    h_admin = {"Authorization": f"Bearer {admin_token}"}
    res_admin_force = client.post("/api/v1/system/observability/alerts/evaluate?force=true", headers=h_admin)
    assert res_admin_force.status_code == 200

    # recent-traffic bounds
    assert client.get("/api/v1/system/observability/recent-traffic?limit=0", headers=h_user).status_code == 422
    assert client.get("/api/v1/system/observability/recent-traffic?limit=501", headers=h_user).status_code == 422
    assert client.get("/api/v1/system/observability/recent-traffic?limit=50", headers=h_user).status_code == 200
