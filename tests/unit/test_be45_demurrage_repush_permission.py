"""
Unit tests for BE45-T03:
Require financial_settlement.calculate on every re-push of an already pushed tracking
across recalculate_and_update_tracking, update_single_container,
register_free_days_agreement, and record_empty_container_return.
"""
from datetime import date, datetime, timezone
import pytest
from fastapi import FastAPI, HTTPException
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
import modules.inland_transport.model  # noqa: F401
from modules.demurrage_detention.model import DemurrageTracking, DemurragePolicy
from modules.demurrage_detention.schemas import (
    DemurrageTrackingCreate,
    DemurrageTrackingUpdate,
    ContainerItemInput,
    ContainerIndividualUpdate,
    FreeDaysAgreementRegister,
    EmptyContainerReturnSubmit,
)
import modules.demurrage_detention.service as dd
import modules.demurrage_detention.router as dd_router


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
    imp_file = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        company_name="Test Corp",
        supplier_name="Global Supplier",
        owner="tester",
    )
    session.add(imp_file)
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


def _setup_tracking(db, is_pushed: bool = False) -> DemurrageTracking:
    tracking_req = DemurrageTrackingCreate(
        import_file_id=1,
        bill_of_lading_no="BL-MSC-12345",
        carrier_name="MSC",
        discharge_date=date(2026, 9, 1),
        exchange_rate=50.0,
        containers=[
            ContainerItemInput(
                container_no="MSCU1234567",
                container_type="40HC",
                free_days=14,
            )
        ],
    )
    tracking = dd.create_demurrage_tracking_service(db, tracking_req, user="tester")
    if is_pushed:
        tracking.is_pushed_to_settlement = True
        db.commit()
        db.refresh(tracking)
    return tracking


def test_service_demurrage_repush_permission_guard(db):
    """
    Direct service call testing:
    User with only demurrage_detention.manage cannot modify or re-push pushed tracking.
    """
    dem_user = _create_user_with_permissions(db, "dem_user", ["demurrage_detention.manage", "demurrage_detention.view"])
    settle_user = _create_user_with_permissions(
        db, "settle_user", ["demurrage_detention.manage", "demurrage_detention.view", "financial_settlement.calculate"]
    )

    # 1. Non-pushed tracking: dem_user can update without settlement permission
    tracking = _setup_tracking(db, is_pushed=False)
    upd_req = DemurrageTrackingUpdate(notes="Updated non-pushed")
    res = dd.recalculate_and_update_tracking_service(db, tracking.tracking_id, upd_req, actor=dem_user)
    assert res.notes == "Updated non-pushed"

    # Single container update on non-pushed
    c_upd = ContainerIndividualUpdate(seal_no="SEAL-999")
    res_c = dd.update_single_container_service(db, tracking.tracking_id, "MSCU1234567", c_upd, actor=dem_user)
    assert res_c.containers[0]["seal_no"] == "SEAL-999"

    # 2. Mark tracking as pushed: now dem_user gets 403 on all mutations
    tracking.is_pushed_to_settlement = True
    db.commit()
    db.refresh(tracking)

    with pytest.raises(HTTPException) as exc:
        dd.recalculate_and_update_tracking_service(db, tracking.tracking_id, upd_req, actor=dem_user)
    assert exc.value.status_code == 403
    assert "financial_settlement.calculate" in exc.value.detail

    with pytest.raises(HTTPException) as exc:
        dd.update_single_container_service(db, tracking.tracking_id, "MSCU1234567", c_upd, actor=dem_user)
    assert exc.value.status_code == 403
    assert "financial_settlement.calculate" in exc.value.detail

    bk02_req = FreeDaysAgreementRegister(
        import_file_id=1,
        carrier_name="MSC",
        agreed_demurrage_free_days=21,
    )
    with pytest.raises(HTTPException) as exc:
        dd.register_free_days_agreement_service(db, bk02_req, actor=dem_user)
    assert exc.value.status_code == 403
    assert "financial_settlement.calculate" in exc.value.detail

    eir_req = EmptyContainerReturnSubmit(
        import_file_id=1,
        return_date=date(2026, 9, 15),
        depot_name="Alexandria Depot",
        eir_number="EIR-001",
        returned_containers=["MSCU1234567"],
    )
    with pytest.raises(HTTPException) as exc:
        dd.record_empty_container_return_service(db, eir_req, actor=dem_user)
    assert exc.value.status_code == 403
    assert "financial_settlement.calculate" in exc.value.detail

    # 3. User with settlement permission can perform the updates on pushed tracking
    upd_req2 = DemurrageTrackingUpdate(notes="Updated by settle_user")
    res2 = dd.recalculate_and_update_tracking_service(db, tracking.tracking_id, upd_req2, actor=settle_user)
    assert res2.notes == "Updated by settle_user"


def test_router_demurrage_repush_permission_endpoints(session_factory, db, monkeypatch):
    """
    HTTP Router endpoint testing:
    Verify PUT /trackings/{id}, PATCH /trackings/{id}/containers/{no},
    POST /free-days-agreement, POST /empty-container-return through TestClient.
    """
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)

    dem_user = _create_user_with_permissions(db, "dem_user2", ["demurrage_detention.manage", "demurrage_detention.view"])
    settle_user = _create_user_with_permissions(
        db, "settle_user2", ["demurrage_detention.manage", "demurrage_detention.view", "financial_settlement.calculate"]
    )

    app = FastAPI()
    app.include_router(dd_router.router)

    def override_get_db():
        s = session_factory()
        try:
            yield s
        finally:
            s.close()

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app, raise_server_exceptions=False)

    dem_headers = {"Authorization": f"Bearer {create_access_token({'sub': str(dem_user.user_id), 'role': dem_user.role})}"}
    settle_headers = {"Authorization": f"Bearer {create_access_token({'sub': str(settle_user.user_id), 'role': settle_user.role})}"}

    # Tracking not pushed: dem_user can PUT and PATCH (200)
    tracking = _setup_tracking(db, is_pushed=False)

    r_put = client.put(
        f"/api/v1/demurrage-detention/trackings/{tracking.tracking_id}",
        json={"notes": "Non-pushed edit"},
        headers=dem_headers,
    )
    assert r_put.status_code == 200

    r_patch = client.patch(
        f"/api/v1/demurrage-detention/trackings/{tracking.tracking_id}/containers/MSCU1234567",
        json={"seal_no": "SEAL-111"},
        headers=dem_headers,
    )
    assert r_patch.status_code == 200

    # Now mark pushed
    tracking.is_pushed_to_settlement = True
    db.commit()

    # Now dem_user gets 403 on PUT
    r_put_blocked = client.put(
        f"/api/v1/demurrage-detention/trackings/{tracking.tracking_id}",
        json={"notes": "Blocked edit"},
        headers=dem_headers,
    )
    assert r_put_blocked.status_code == 403
    assert "financial_settlement.calculate" in r_put_blocked.json()["detail"]

    # dem_user gets 403 on PATCH
    r_patch_blocked = client.patch(
        f"/api/v1/demurrage-detention/trackings/{tracking.tracking_id}/containers/MSCU1234567",
        json={"seal_no": "SEAL-222"},
        headers=dem_headers,
    )
    assert r_patch_blocked.status_code == 403
    assert "financial_settlement.calculate" in r_patch_blocked.json()["detail"]

    # dem_user gets 403 on POST /free-days-agreement
    r_bk02_blocked = client.post(
        "/api/v1/demurrage-detention/free-days-agreement",
        json={
            "import_file_id": 1,
            "carrier_name": "MSC",
            "agreed_demurrage_free_days": 20,
        },
        headers=dem_headers,
    )
    assert r_bk02_blocked.status_code == 403
    assert "financial_settlement.calculate" in r_bk02_blocked.json()["detail"]

    # dem_user gets 403 on POST /empty-container-return
    r_eir_blocked = client.post(
        "/api/v1/demurrage-detention/empty-container-return",
        json={
            "import_file_id": 1,
            "return_date": "2026-09-15",
            "depot_name": "Alexandria Depot",
            "eir_number": "EIR-002",
            "returned_containers": ["MSCU1234567"],
        },
        headers=dem_headers,
    )
    assert r_eir_blocked.status_code == 403
    assert "financial_settlement.calculate" in r_eir_blocked.json()["detail"]

    # settle_user has financial_settlement.calculate -> succeeds with 200
    r_put_ok = client.put(
        f"/api/v1/demurrage-detention/trackings/{tracking.tracking_id}",
        json={"notes": "Allowed edit by settlement user"},
        headers=settle_headers,
    )
    assert r_put_ok.status_code == 200
