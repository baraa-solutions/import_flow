"""
Unit tests for BE45-T15:
Pagination for Freight Booking and Cargo Shipping list endpoints.
Validates:
- Default limit is 200, skip is 0.
- X-Total-Count header matches total matching rows.
- skip=200 on 250 rows returns remaining 50.
- Query validation (skip >= 0, limit 1..500).
"""
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import modules.auth.permissions as auth_permissions
from database.database import Base, get_db
from modules.auth.permissions import invalidate_permission_cache
from modules.auth.security import create_access_token, hash_password
from modules.auth.seed_rbac import seed_rbac
from modules.users.model import Permission, Role, RolePermission, User
from modules.import_files.model import ImportFile
from modules.freight_booking.model import ShipmentBooking
from modules.cargo_shipping.model import CargoShippingRecord
import modules.freight_booking.router as fb_router
import modules.cargo_shipping.router as cs_router


@pytest.fixture
def session_factory():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    invalidate_permission_cache()
    yield sessionmaker(bind=engine, autoflush=False)
    invalidate_permission_cache()
    engine.dispose()


@pytest.fixture
def db(session_factory):
    session = session_factory()
    seed_rbac(session)
    session.commit()
    yield session
    session.close()


def _create_user_with_permissions(db, username: str, permissions: list[str]) -> User:
    role = Role(
        role_code=f"ROLE_{username.upper()}",
        name_ar=username,
        name_en=username,
        is_active=True,
    )
    db.add(role)
    db.flush()

    for p_code in permissions:
        perm = db.query(Permission).filter(Permission.permission_code == p_code).first()
        if not perm:
            perm = Permission(permission_code=p_code, module_name="test", action="test", name_en=p_code, name_ar=p_code)
            db.add(perm)
            db.flush()
        rp = RolePermission(role_id=role.role_id, permission_id=perm.permission_id)
        db.add(rp)

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
    invalidate_permission_cache()
    return user


@pytest.fixture
def test_client(session_factory, db, monkeypatch):
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)
    user = _create_user_with_permissions(
        db, "paging_tester", ["freight_booking.view", "cargo_shipping.view"]
    )
    app = FastAPI()
    app.include_router(fb_router.router)
    app.include_router(cs_router.router)

    def override_get_db():
        s = session_factory()
        try:
            yield s
        finally:
            s.close()

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app, raise_server_exceptions=False)
    token = create_access_token({"sub": str(user.user_id), "role": user.role})
    client.headers.update({"Authorization": f"Bearer {token}"})
    return client


def test_freight_booking_list_paging(db, test_client):
    """With 250 rows, default call returns 200, X-Total-Count is 250, skip=200 returns 50."""
    bookings = [
        ShipmentBooking(
            booking_code=f"BKG-2026-{i:04d}",
            booking_confirmation_no=f"CONF-{i:04d}",
            shipment_type="Ocean FCL",
            status="Draft",
            is_active=True,
        )
        for i in range(1, 251)
    ]
    db.bulk_save_objects(bookings)
    db.commit()

    # 1. Default call: skip=0, limit=200
    res_default = test_client.get("/api/v1/freight-booking")
    assert res_default.status_code == 200
    data_default = res_default.json()
    assert len(data_default) == 200
    assert res_default.headers["X-Total-Count"] == "250"

    # 2. Skip 200: returns remaining 50
    res_skip = test_client.get("/api/v1/freight-booking?skip=200")
    assert res_skip.status_code == 200
    data_skip = res_skip.json()
    assert len(data_skip) == 50
    assert res_skip.headers["X-Total-Count"] == "250"

    # Verify no overlap between first page and second page
    default_codes = {b["booking_code"] for b in data_default}
    skip_codes = {b["booking_code"] for b in data_skip}
    assert len(default_codes.intersection(skip_codes)) == 0

    # 3. Custom limit: skip=240, limit=20 -> returns 10
    res_custom = test_client.get("/api/v1/freight-booking?skip=240&limit=20")
    assert res_custom.status_code == 200
    data_custom = res_custom.json()
    assert len(data_custom) == 10
    assert res_custom.headers["X-Total-Count"] == "250"

    # 4. Bounds validation
    res_neg_skip = test_client.get("/api/v1/freight-booking?skip=-1")
    assert res_neg_skip.status_code == 422

    res_over_limit = test_client.get("/api/v1/freight-booking?limit=501")
    assert res_over_limit.status_code == 422


def test_cargo_shipping_list_paging(db, test_client):
    """With 250 rows, default call returns 200, X-Total-Count is 250, skip=200 returns 50."""
    imp_file = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-PAGING",
        company_name="Paging Importer",
        supplier_name="Paging Supplier",
    )
    db.add(imp_file)
    db.commit()

    records = [
        CargoShippingRecord(
            cargo_shipping_code=f"SHP-2026-{i:04d}",
            import_file_id=1,
            shipment_type="FCL",
            status="Draft",
            containers_loading_data=[],
            is_active=True,
        )
        for i in range(1, 251)
    ]
    db.bulk_save_objects(records)
    db.commit()

    # 1. Default call: skip=0, limit=200
    res_default = test_client.get("/api/v1/cargo-shipping")
    assert res_default.status_code == 200
    data_default = res_default.json()
    assert len(data_default) == 200
    assert res_default.headers["X-Total-Count"] == "250"

    # 2. Skip 200: returns remaining 50
    res_skip = test_client.get("/api/v1/cargo-shipping?skip=200")
    assert res_skip.status_code == 200
    data_skip = res_skip.json()
    assert len(data_skip) == 50
    assert res_skip.headers["X-Total-Count"] == "250"

    # Verify no overlap
    default_codes = {r["cargo_shipping_code"] for r in data_default}
    skip_codes = {r["cargo_shipping_code"] for r in data_skip}
    assert len(default_codes.intersection(skip_codes)) == 0

    # 3. Custom limit: skip=240, limit=20 -> returns 10
    res_custom = test_client.get("/api/v1/cargo-shipping?skip=240&limit=20")
    assert res_custom.status_code == 200
    data_custom = res_custom.json()
    assert len(data_custom) == 10
    assert res_custom.headers["X-Total-Count"] == "250"

    # 4. Bounds validation
    res_neg_skip = test_client.get("/api/v1/cargo-shipping?skip=-1")
    assert res_neg_skip.status_code == 422

    res_over_limit = test_client.get("/api/v1/cargo-shipping?limit=501")
    assert res_over_limit.status_code == 422
