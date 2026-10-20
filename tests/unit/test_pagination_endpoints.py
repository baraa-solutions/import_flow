import pytest
from datetime import date, datetime, timezone
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main
from database.database import Base, get_db
from modules.smart_tasks.model import SmartTask
from modules.audit_logs.model import AuditLog
from modules.notifications.model import SystemNotification
from modules.transport_locations.model import TransportLocation
from modules.suppliers.model import Supplier
from modules.import_companies.model import ImportCompany
from modules.external_service_providers.model import ExternalServiceProvider
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


def _create_user(db, username: str, permission_codes: list, is_admin: bool = False) -> tuple[User, str]:
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


def test_transport_locations_pagination(client, db_session):
    _, token = _create_user(db_session, "operator", ["import_files.view"])
    headers = {"Authorization": f"Bearer {token}"}

    locations = [
        TransportLocation(
            un_locode=f"EG{i:03d}",
            location_name=f"Port {i:03d}",
            location_type="Sea Port",
            country="Egypt",
            city="Alexandria",
            is_active=True,
        )
        for i in range(1, 121)
    ]
    db_session.add_all(locations)
    db_session.commit()

    # Page 3 of 50 -> 20 items (101..120)
    res = client.get("/api/v1/transport-locations/paginated?page=3&page_size=50", headers=headers)
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["total"] == 120
    assert data["page"] == 3
    assert data["page_size"] == 50
    assert data["total_pages"] == 3
    assert len(data["items"]) == 20
    assert res.headers.get("x-total-count") == "120"

    # Bounds
    assert client.get("/api/v1/transport-locations/paginated?page=0", headers=headers).status_code == 422
    assert client.get("/api/v1/transport-locations/paginated?page_size=201", headers=headers).status_code == 422

    # Invalid sort column -> 400 LIST_SORT_FIELD_INVALID
    res_bad_sort = client.get("/api/v1/transport-locations/paginated?sort=non_existent_column", headers=headers)
    assert res_bad_sort.status_code == 400
    assert "LIST_SORT_FIELD_INVALID" in res_bad_sort.text


def test_suppliers_pagination(client, db_session):
    _, token = _create_user(db_session, "operator", ["import_files.view"])
    headers = {"Authorization": f"Bearer {token}"}

    suppliers = [
        Supplier(
            supplier_code=f"SUP-{i:06d}",
            company_name=f"Supplier Enterprise {i:03d}",
            supplier_type="Manufacturer",
            registration_type="Factory Registration",
            foreign_exporter_id=f"EXP-{i:06d}",
            foreign_exporter_country="Germany",
            foreign_exporter_country_code="DE",
            address="Industrial Zone 1",
            is_active=True,
        )
        for i in range(1, 121)
    ]
    db_session.add_all(suppliers)
    db_session.commit()

    res = client.get("/api/v1/suppliers/paginated?page=3&page_size=50", headers=headers)
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["total"] == 120
    assert len(data["items"]) == 20
    assert res.headers.get("x-total-count") == "120"

    res_bad = client.get("/api/v1/suppliers/paginated?sort=invalid_field", headers=headers)
    assert res_bad.status_code == 400
    assert "LIST_SORT_FIELD_INVALID" in res_bad.text


def test_import_companies_pagination(client, db_session):
    _, token = _create_user(db_session, "operator", ["import_files.view"])
    headers = {"Authorization": f"Bearer {token}"}

    companies = [
        ImportCompany(
            importer_name=f"Import Corp {i:03d}",
            address=f"Street {i}",
            country="Egypt",
            importer_id=f"IMP-{i:06d}",
            importer_id_expiry=date(2030, 1, 1),
            vat_id=f"VAT-{i:06d}",
            vat_id_expiry=date(2030, 1, 1),
            registration_number=f"REG-{i:06d}",
            registration_expiry=date(2030, 1, 1),
            is_active=True,
        )
        for i in range(1, 121)
    ]
    db_session.add_all(companies)
    db_session.commit()

    res = client.get("/api/v1/import-companies/paginated?page=3&page_size=50", headers=headers)
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["total"] == 120
    assert len(data["items"]) == 20
    assert res.headers.get("x-total-count") == "120"

    res_bad = client.get("/api/v1/import-companies/paginated?sort=invalid_field", headers=headers)
    assert res_bad.status_code == 400
    assert "LIST_SORT_FIELD_INVALID" in res_bad.text


def test_external_service_providers_pagination(client, db_session):
    _, token = _create_user(db_session, "operator", ["import_files.view"])
    headers = {"Authorization": f"Bearer {token}"}

    partners = [
        ExternalServiceProvider(
            partner_code=f"ESP-{i:06d}",
            partner_name=f"Partner Bank {i:03d}",
            partner_type="Bank",
            is_active=True,
        )
        for i in range(1, 121)
    ]
    db_session.add_all(partners)
    db_session.commit()

    res = client.get("/api/v1/external-service-providers/paginated?page=3&page_size=50", headers=headers)
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["total"] == 120
    assert len(data["items"]) == 20
    assert res.headers.get("x-total-count") == "120"

    res_bad = client.get("/api/v1/external-service-providers/paginated?sort=invalid_field", headers=headers)
    assert res_bad.status_code == 400
    assert "LIST_SORT_FIELD_INVALID" in res_bad.text


def test_audit_logs_pagination(client, db_session):
    _, token = _create_user(db_session, "admin", [], is_admin=True)
    headers = {"Authorization": f"Bearer {token}"}

    logs = [
        AuditLog(
            entity_type="ImportFile",
            entity_id=1,
            action="UPDATE",
            changes_summary=f"Audit step {i}",
            performed_at=datetime.now(timezone.utc),
        )
        for i in range(1, 121)
    ]
    db_session.add_all(logs)
    db_session.commit()

    res = client.get("/api/v1/audit-logs/paginated?page=3&page_size=50", headers=headers)
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["total"] == 120
    assert len(data["items"]) == 20
    assert res.headers.get("x-total-count") == "120"

    # Entity timeline
    res_entity = client.get("/api/v1/audit-logs/ImportFile/1/paginated?page=3&page_size=50", headers=headers)
    assert res_entity.status_code == 200
    assert res_entity.json()["total"] == 120
    assert len(res_entity.json()["items"]) == 20


def test_notifications_pagination(client, db_session):
    user, token = _create_user(db_session, "notif_user", [])
    headers = {"Authorization": f"Bearer {token}"}

    notifications = [
        SystemNotification(
            title=f"Notification {i}",
            message=f"Body {i}",
            severity="INFO",
            category="SYSTEM",
            target_role="ALL",
            created_at=datetime.now(timezone.utc),
        )
        for i in range(1, 121)
    ]
    db_session.add_all(notifications)
    db_session.commit()

    res = client.get("/api/v1/notifications/paginated?page=3&page_size=50", headers=headers)
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["total"] == 120
    assert len(data["items"]) == 20
    assert res.headers.get("x-total-count") == "120"
