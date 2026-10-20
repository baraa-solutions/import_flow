"""
Unit tests for audit trail actor wiring, audit-log access control, and report exports (BEX-T15).

Verifies:
1. User management operations (toggle status, create, update, permissions) record the actual actor's username in the audit log (performed_by == actor.username).
2. /api/v1/audit-logs routes enforce the 'audit_logs.view' permission: LOGISTICS_OPERATOR without permission gets 403, while admin gets 200.
3. Import file exports (/export-excel and /export-pdf) enforce the 'reports.export' permission: operator without reports.export gets 403, while authorized user gets 200.
4. Legacy rows with progress_percent=NULL do not raise 500 in service.build_export_rows or during export.
"""

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import modules.auth.permissions as auth_permissions
from database.database import Base, get_db
from modules.audit_logs.model import AuditLog
from modules.audit_logs.router import router as audit_logs_router
from modules.auth.permissions import invalidate_permission_cache
from modules.auth.router import router as auth_router
from modules.auth.schemas import UserCreate, UserPermissionsUpdatePayload, UserUpdate
from modules.auth.security import create_access_token, hash_password
from modules.auth.seed_rbac import seed_rbac
from modules.auth.service import AuthService
from modules.import_files.model import ImportFile
from modules.import_files.router import router as import_files_router
from modules.import_files.service import build_export_rows
from modules.users.model import Role, User


@pytest.fixture
def session_factory():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine)
    invalidate_permission_cache()
    yield factory
    invalidate_permission_cache()
    engine.dispose()


@pytest.fixture
def db(session_factory):
    session = session_factory()
    seed_rbac(session)
    yield session
    session.close()


def _make_user(db, username: str, role_code: str) -> User:
    role = db.query(Role).filter(Role.role_code == role_code).one()
    user = User(
        username=username,
        email=f"{username}@test.com",
        full_name=username,
        hashed_password=hash_password("Password123"),
        role=role.role_code,
        role_id=role.role_id,
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def admin_user(db):
    return _make_user(db, "a1", "ADMIN")


@pytest.fixture
def operator_user(db):
    return _make_user(db, "u2", "LOGISTICS_OPERATOR")


@pytest.fixture
def client(session_factory, monkeypatch):
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)
    app = FastAPI()
    app.include_router(audit_logs_router)
    app.include_router(auth_router)
    app.include_router(import_files_router)

    def override_get_db():
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = override_get_db
    return TestClient(app, raise_server_exceptions=False)


def _bearer(user: User) -> dict:
    return {"Authorization": f"Bearer {create_access_token({'sub': str(user.user_id), 'role': user.role})}"}


# ─── 1. Audit Trail Actor Tests ──────────────────────────────────────────────

def test_admin_deactivates_user_records_admin_as_actor(db, admin_user, operator_user):
    auth_service = AuthService(db)
    updated = auth_service.toggle_user_status(operator_user.user_id, actor=admin_user)
    assert updated.is_active is False

    log = (
        db.query(AuditLog)
        .filter(AuditLog.entity_type == "User", AuditLog.entity_id == operator_user.user_id)
        .order_by(AuditLog.log_id.desc())
        .first()
    )
    assert log is not None
    assert log.action == "UPDATE"
    assert log.performed_by == "a1"


def test_user_management_operations_record_actual_actor(db, admin_user):
    auth_service = AuthService(db)

    # 1. Create user
    created = auth_service.register_user(
        UserCreate(
            username="newbie",
            full_name="Newbie User",
            email="newbie@example.com",
            password="StrongPassword123!",
            role="LOGISTICS_OPERATOR",
        ),
        actor=admin_user,
    )
    create_log = (
        db.query(AuditLog)
        .filter(AuditLog.entity_type == "User", AuditLog.entity_id == created.user_id, AuditLog.action == "CREATE")
        .first()
    )
    assert create_log is not None
    assert create_log.performed_by == "a1"

    # 2. Update user
    auth_service.update_user(
        created.user_id,
        UserUpdate(full_name="Newbie Updated"),
        actor=admin_user,
    )
    update_log = (
        db.query(AuditLog)
        .filter(AuditLog.entity_type == "User", AuditLog.entity_id == created.user_id, AuditLog.action == "UPDATE")
        .order_by(AuditLog.log_id.desc())
        .first()
    )
    assert update_log is not None
    assert update_log.performed_by == "a1"

    # 3. Update permissions
    auth_service.update_user_permissions(
        created.user_id,
        UserPermissionsUpdatePayload(role_id=created.role_id, permissions=[]),
        actor=admin_user,
    )
    perm_log = (
        db.query(AuditLog)
        .filter(AuditLog.entity_type == "UserPermissions", AuditLog.entity_id == created.user_id)
        .order_by(AuditLog.log_id.desc())
        .first()
    )
    assert perm_log is not None
    assert perm_log.performed_by == "a1"


# ─── 2. Audit Log Access Control (audit_logs.view) ───────────────────────────

def test_operator_without_audit_logs_view_gets_403(client, operator_user):
    headers = _bearer(operator_user)

    # All audit-log endpoints must return 403 for operator without audit_logs.view
    assert client.get("/api/v1/audit-logs", headers=headers).status_code == 403
    assert client.get("/api/v1/audit-logs/paginated", headers=headers).status_code == 403
    assert client.get(f"/api/v1/audit-logs/User/{operator_user.user_id}", headers=headers).status_code == 403
    assert client.get(f"/api/v1/audit-logs/User/{operator_user.user_id}/paginated", headers=headers).status_code == 403


def test_admin_can_access_audit_logs(client, admin_user):
    headers = _bearer(admin_user)
    res = client.get("/api/v1/audit-logs", headers=headers)
    assert res.status_code == 200

    res_paginated = client.get("/api/v1/audit-logs/paginated", headers=headers)
    assert res_paginated.status_code == 200


# ─── 3. Report Exports & Legacy NULL Progress ────────────────────────────────

def test_export_endpoints_require_reports_export_permission(client, db, operator_user, admin_user):
    # Operator lacks reports.export -> 403
    op_headers = _bearer(operator_user)
    assert client.get("/api/v1/import-files/export-excel", headers=op_headers).status_code == 403
    assert client.get("/api/v1/import-files/export-pdf", headers=op_headers).status_code == 403

    # Admin has full permissions -> 200
    admin_headers = _bearer(admin_user)
    assert client.get("/api/v1/import-files/export-excel", headers=admin_headers).status_code == 200
    assert client.get("/api/v1/import-files/export-pdf", headers=admin_headers).status_code == 200


def test_legacy_null_progress_export_tolerance(client, db, admin_user):
    # Insert an ImportFile and simulate legacy row with progress_percent = NULL
    legacy_file = ImportFile(
        import_file_code="IMP-NULL-PROG-001",
        company_name="Test Company",
        supplier_name="Test Supplier",
        status="ACTIVE",
    )
    db.add(legacy_file)
    db.commit()

    db.execute(
        text("UPDATE import_files SET progress_percent = NULL WHERE import_file_id = :id"),
        {"id": legacy_file.import_file_id},
    )
    db.commit()
    db.expire_all()
    legacy_file = db.query(ImportFile).filter(ImportFile.import_file_id == legacy_file.import_file_id).one()
    assert legacy_file.progress_percent is None

    # 1. Direct unit verification on service.build_export_rows
    excel_rows = build_export_rows([legacy_file], format="excel")
    assert len(excel_rows) == 1
    # Progress column is index 10 in excel
    assert excel_rows[0][10] == "0%"

    pdf_rows = build_export_rows([legacy_file], format="pdf")
    assert len(pdf_rows) == 1
    # Progress column is index 6 in pdf
    assert pdf_rows[0][6] == "0%"

    # 2. HTTP export endpoints succeed with 200 without raising 500
    admin_headers = _bearer(admin_user)
    res_excel = client.get("/api/v1/import-files/export-excel", headers=admin_headers)
    assert res_excel.status_code == 200
    assert "application/vnd.openxmlformats" in res_excel.headers["content-type"]

    res_pdf = client.get("/api/v1/import-files/export-pdf", headers=admin_headers)
    assert res_pdf.status_code == 200
    assert "application/pdf" in res_pdf.headers["content-type"]
