import pytest
from datetime import datetime, timezone
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main
from database.database import Base, get_db
from modules.smart_tasks.model import SmartTask
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


def _create_user_with_permissions(db, username: str, permission_codes: list, is_admin: bool = False) -> tuple[User, str]:
    role_code = "ADMIN" if is_admin else f"ROLE_{username.upper()}"
    role = Role(role_code=role_code, name_en=role_code, name_ar=role_code, is_active=True)
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
        role=role_code,
        role_id=role.role_id,
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token({"sub": str(user.user_id), "username": user.username, "role": user.role})
    return user, token


def test_smart_tasks_pagination_and_sorting(client, db_session):
    _, viewer_token = _create_user_with_permissions(db_session, "viewer_user", ["import_files.view"])
    headers = {"Authorization": f"Bearer {viewer_token}"}

    # Seed 120 tasks
    tasks = [
        SmartTask(
            task_code=f"TSK-2026-{i:04d}",
            title=f"مهمة تشغيلية {i:03d} Follow-up",
            description=f"تفاصيل المهمة رقم {i}",
            task_type="Manual To-Do" if i % 2 == 0 else "System Generated",
            priority="High" if i % 3 == 0 else "Medium",
            status="Completed" if i > 100 else "Pending",
            assigned_user="Kamal",
            is_active=True,
        )
        for i in range(1, 121)
    ]
    db_session.add_all(tasks)
    db_session.commit()

    # 1. Bounds check: page_size=0 -> 422, page_size=201 -> 422, page=0 -> 422
    assert client.get("/api/v1/smart-tasks/paginated?page_size=0", headers=headers).status_code == 422
    assert client.get("/api/v1/smart-tasks/paginated?page_size=201", headers=headers).status_code == 422
    assert client.get("/api/v1/smart-tasks/paginated?page=0", headers=headers).status_code == 422

    # 2. Unknown sort field -> 400 LIST_SORT_FIELD_INVALID
    res_sort_invalid = client.get("/api/v1/smart-tasks/paginated?sort=invalid_col", headers=headers)
    assert res_sort_invalid.status_code == 400
    assert "LIST_SORT_FIELD_INVALID" in res_sort_invalid.text

    # 3. Default page 1 (50 items)
    res_p1 = client.get("/api/v1/smart-tasks/paginated?page=1&page_size=50", headers=headers)
    assert res_p1.status_code == 200
    data_p1 = res_p1.json()
    assert data_p1["total"] == 120
    assert data_p1["page"] == 1
    assert data_p1["page_size"] == 50
    assert data_p1["total_pages"] == 3
    assert len(data_p1["items"]) == 50
    assert res_p1.headers.get("X-Total-Count") == "120"

    # 4. Page 3 of 50 -> 20 items (120 seeded rows, page 3 of 50 -> 20 items, total 120)
    res_p3 = client.get("/api/v1/smart-tasks/paginated?page=3&page_size=50", headers=headers)
    assert res_p3.status_code == 200
    data_p3 = res_p3.json()
    assert data_p3["total"] == 120
    assert data_p3["page"] == 3
    assert len(data_p3["items"]) == 20

    # 5. Page past the end returns empty items with accurate total & total_pages
    res_p4 = client.get("/api/v1/smart-tasks/paginated?page=4&page_size=50", headers=headers)
    assert res_p4.status_code == 200
    data_p4 = res_p4.json()
    assert data_p4["items"] == []
    assert data_p4["total"] == 120
    assert data_p4["total_pages"] == 3

    # 6. Search filter `q`
    res_q = client.get("/api/v1/smart-tasks/paginated?q=042", headers=headers)
    assert res_q.status_code == 200
    data_q = res_q.json()
    assert data_q["total"] >= 1
    assert any("042" in it["task_code"] or "042" in it["title"] for it in data_q["items"])

    # 7. Sorting
    res_sort = client.get("/api/v1/smart-tasks/paginated?sort=task_code", headers=headers)
    assert res_sort.status_code == 200
    codes = [it["task_code"] for it in res_sort.json()["items"]]
    assert codes == sorted(codes)


def test_smart_tasks_permissions_matrix(client, db_session):
    _, viewer_token = _create_user_with_permissions(db_session, "viewer", ["import_files.view"])
    _, editor_token = _create_user_with_permissions(db_session, "editor", ["import_files.view", "import_files.edit"])
    _, admin_token = _create_user_with_permissions(db_session, "admin", [], is_admin=True)
    _, no_perm_token = _create_user_with_permissions(db_session, "noperm", [])

    viewer_headers = {"Authorization": f"Bearer {viewer_token}"}
    editor_headers = {"Authorization": f"Bearer {editor_token}"}
    admin_headers = {"Authorization": f"Bearer {admin_token}"}
    no_perm_headers = {"Authorization": f"Bearer {no_perm_token}"}

    # 1. User without import_files.view gets 403 on GET
    res_no_view = client.get("/api/v1/smart-tasks/paginated", headers=no_perm_headers)
    assert res_no_view.status_code == 403

    # 2. Viewer can GET
    res_view = client.get("/api/v1/smart-tasks/paginated", headers=viewer_headers)
    assert res_view.status_code == 200

    # 3. Viewer gets 403 on POST / PUT / DELETE
    payload = {
        "title": "مهمة تجريبية",
        "task_type": "Manual To-Do",
        "priority": "Medium",
    }
    res_post_viewer = client.post("/api/v1/smart-tasks", json=payload, headers=viewer_headers)
    assert res_post_viewer.status_code == 403

    # 4. Editor can POST
    res_post_editor = client.post("/api/v1/smart-tasks", json=payload, headers=editor_headers)
    assert res_post_editor.status_code == 201
    created_id = res_post_editor.json()["task_id"]

    # 5. Viewer gets 403 on PUT
    res_put_viewer = client.put(f"/api/v1/smart-tasks/{created_id}", json={"title": "معدل"}, headers=viewer_headers)
    assert res_put_viewer.status_code == 403

    # 6. Editor can PUT
    res_put_editor = client.put(f"/api/v1/smart-tasks/{created_id}", json={"title": "معدل"}, headers=editor_headers)
    assert res_put_editor.status_code == 200

    # 7. Editor gets 403 on sync-all-active-files (requires admin)
    res_sync_editor = client.post("/api/v1/smart-tasks/sync-all-active-files", headers=editor_headers)
    assert res_sync_editor.status_code == 403

    # 8. Admin can call sync-all-active-files
    res_sync_admin = client.post("/api/v1/smart-tasks/sync-all-active-files", headers=admin_headers)
    assert res_sync_admin.status_code == 200
