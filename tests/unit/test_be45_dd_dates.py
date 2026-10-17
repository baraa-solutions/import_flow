"""
Unit tests for BE45-T10:
Demurrage date sanity (future date rejection) and the EIR lifecycle step guard.
"""
from datetime import date, timedelta
import pytest
from pydantic import ValidationError
from fastapi import FastAPI, HTTPException, status
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
from modules.demurrage_detention.model import DemurrageTracking
from modules.demurrage_detention.schemas import (
    DemurrageTrackingCreate,
    DemurrageTrackingUpdate,
    DemurrageSimulationRequest,
    ContainerItemInput,
    ContainerIndividualUpdate,
    EmptyContainerReturnSubmit,
)
from modules.demurrage_detention.validators import validate_demurrage_dates
import modules.demurrage_detention.service as dd
import modules.demurrage_detention.router as dd_router
from modules.common.clock import cairo_today


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


def _create_file(db, file_id: int, code: str, current_step_code: str = "STEP_18", progress: float = 85.0) -> ImportFile:
    imp_file = ImportFile(
        import_file_id=file_id,
        import_file_code=code,
        company_name="Test Corp",
        supplier_name="Global Supplier",
        owner="tester",
        current_step_code=current_step_code,
        progress_percent=progress,
    )
    db.add(imp_file)
    db.commit()
    db.refresh(imp_file)
    return imp_file


def _setup_tracking(db, file_id: int, bl_no: str = "BL-MSC-12345") -> DemurrageTracking:
    today = cairo_today()
    discharge = today - timedelta(days=20)
    gate_out = today - timedelta(days=5)
    tracking_req = DemurrageTrackingCreate(
        import_file_id=file_id,
        bill_of_lading_no=bl_no,
        carrier_name="MSC",
        discharge_date=discharge,
        gate_out_date=gate_out,
        exchange_rate=50.0,
        containers=[
            ContainerItemInput(
                container_no="MSCU1234567",
                container_type="40HC",
                free_days=14,
            )
        ],
    )
    return dd.create_demurrage_tracking_service(db, tracking_req, user="tester")


def test_validator_date_sanity():
    """Direct validator check for future dates vs what-if simulation."""
    today = cairo_today()
    tomorrow = today + timedelta(days=1)
    past = today - timedelta(days=5)

    # 1. Past dates with today -> pass
    validate_demurrage_dates(past - timedelta(days=10), gate_out_date=past, empty_return_date=past, today=today)

    # 2. Future gate_out with today -> 422
    with pytest.raises(HTTPException) as exc:
        validate_demurrage_dates(past, gate_out_date=tomorrow, empty_return_date=None, today=today)
    assert exc.value.status_code == status.HTTP_422_UNPROCESSABLE_CONTENT
    assert "Gate-Out" in exc.value.detail

    # 3. Future return_date with today -> 422
    with pytest.raises(HTTPException) as exc:
        validate_demurrage_dates(past, gate_out_date=past, empty_return_date=tomorrow, today=today)
    assert exc.value.status_code == status.HTTP_422_UNPROCESSABLE_CONTENT
    assert "إعادة الحاوية الفارغة" in exc.value.detail

    # 4. What-if mode (today=None) allows future dates without error
    validate_demurrage_dates(past, gate_out_date=tomorrow, empty_return_date=tomorrow + timedelta(days=2), today=None)


def test_simulator_allows_future_dates():
    """Simulation service allows future gate_out and return dates (what-if)."""
    today = cairo_today()
    sim_req = DemurrageSimulationRequest(
        discharge_date=today - timedelta(days=5),
        gate_out_date=today + timedelta(days=5),
        empty_return_date=today + timedelta(days=10),
        demurrage_free_days=14,
        detention_free_days=7,
        port_storage_free_days=5,
        daily_rate_fx=50.0,
        port_storage_daily_rate_egp=300.0,
        exchange_rate=50.0,
    )
    res = dd.simulate_demurrage_and_detention(sim_req)
    assert res is not None
    assert res.demurrage_free_days == 14
    assert res.detention_free_days == 7


def test_empty_container_return_schema_requires_date():
    """EmptyContainerReturnSubmit requires empty_return_date (or fallback return_date)."""
    with pytest.raises(ValidationError):
        EmptyContainerReturnSubmit(
            import_file_id=1,
            eir_number="EIR-001",
        )

    # empty_return_date explicitly passed
    req1 = EmptyContainerReturnSubmit(
        import_file_id=1,
        eir_number="EIR-001",
        empty_return_date=date(2026, 9, 10),
    )
    assert req1.empty_return_date == date(2026, 9, 10)

    # fallback legacy field return_date
    req2 = EmptyContainerReturnSubmit(
        import_file_id=1,
        eir_number="EIR-002",
        return_date=date(2026, 9, 12),
    )
    assert req2.empty_return_date == date(2026, 9, 12)


def test_tracking_creation_and_update_future_dates_rejected(db):
    """Tracking create, update, and single container update reject future dates."""
    today = cairo_today()
    tomorrow = today + timedelta(days=1)
    past = today - timedelta(days=10)

    _create_file(db, 1, "IMP-001")

    # Future gate-out in creation -> 422
    with pytest.raises(HTTPException) as exc:
        dd.create_demurrage_tracking_service(
            db,
            DemurrageTrackingCreate(
                import_file_id=1,
                bill_of_lading_no="BL-1",
                carrier_name="MSC",
                discharge_date=past,
                gate_out_date=tomorrow,
                exchange_rate=50.0,
            ),
        )
    assert exc.value.status_code == status.HTTP_422_UNPROCESSABLE_CONTENT

    # Valid tracking
    tracking = _setup_tracking(db, 1, "BL-VALID")

    # Future gate-out in update -> 422
    with pytest.raises(HTTPException) as exc:
        dd.recalculate_and_update_tracking_service(
            db,
            tracking.tracking_id,
            DemurrageTrackingUpdate(gate_out_date=tomorrow),
        )
    assert exc.value.status_code == status.HTTP_422_UNPROCESSABLE_CONTENT

    # Future gate-out in container update -> 422
    with pytest.raises(HTTPException) as exc:
        dd.update_single_container_service(
            db,
            tracking.tracking_id,
            "MSCU1234567",
            ContainerIndividualUpdate(gate_out_date=tomorrow),
        )
    assert exc.value.status_code == status.HTTP_422_UNPROCESSABLE_CONTENT


def test_eir_submission_future_date_rejected(db):
    """EIR submission with future empty_return_date raises 422."""
    today = cairo_today()
    tomorrow = today + timedelta(days=1)

    _create_file(db, 2, "IMP-002")
    _setup_tracking(db, 2, "BL-002")

    eir_req = EmptyContainerReturnSubmit(
        import_file_id=2,
        eir_number="EIR-FUTURE",
        empty_return_date=tomorrow,
    )
    with pytest.raises(HTTPException) as exc:
        dd.record_empty_container_return_service(db, eir_req)
    assert exc.value.status_code == status.HTTP_422_UNPROCESSABLE_CONTENT
    assert "في المستقبل" in exc.value.detail


def test_eir_step_guard_advances_to_step_20(db):
    """When import file is at STEP_19, EIR advances tracking to STEP_20."""
    today = cairo_today()
    yesterday = today - timedelta(days=1)

    imp_file = _create_file(db, 3, "IMP-003", current_step_code="STEP_19", progress=90.0)
    _setup_tracking(db, 3, "BL-003")

    eir_req = EmptyContainerReturnSubmit(
        import_file_id=3,
        eir_number="EIR-ADVANCE",
        empty_return_date=yesterday,
        returned_containers=["MSCU1234567"],
    )
    res = dd.record_empty_container_return_service(db, eir_req)
    assert res.all_containers_returned is True

    db.refresh(imp_file)
    assert imp_file.current_step_code == "STEP_20"
    assert imp_file.progress_percent >= 98.0


def test_eir_step_guard_preserves_step_past_step_20(db):
    """When import file is already at STEP_21, EIR preserves STEP_21 and does not roll back."""
    today = cairo_today()
    yesterday = today - timedelta(days=1)

    imp_file = _create_file(db, 4, "IMP-004", current_step_code="STEP_21", progress=100.0)
    _setup_tracking(db, 4, "BL-004")

    eir_req = EmptyContainerReturnSubmit(
        import_file_id=4,
        eir_number="EIR-GUARD",
        empty_return_date=yesterday,
        returned_containers=["MSCU1234567"],
    )
    res = dd.record_empty_container_return_service(db, eir_req)
    assert res.all_containers_returned is True

    db.refresh(imp_file)
    assert imp_file.current_step_code == "STEP_21"
    assert imp_file.progress_percent == 100.0


def test_router_eir_and_simulator_endpoints(session_factory, db, monkeypatch):
    """HTTP router tests for future date rejection and simulation acceptance."""
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)

    user = _create_user_with_permissions(
        db, "dd_user", ["demurrage_detention.manage", "demurrage_detention.view"]
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
    headers = {"Authorization": f"Bearer {create_access_token({'sub': str(user.user_id), 'role': user.role})}"}

    today = cairo_today()
    tomorrow = today + timedelta(days=1)

    # 1. Simulator allows future dates -> 200 OK
    sim_payload = {
        "discharge_date": (today - timedelta(days=2)).isoformat(),
        "gate_out_date": tomorrow.isoformat(),
        "demurrage_free_days": 14,
        "detention_free_days": 7,
        "daily_rate_fx": 50.0,
        "exchange_rate": 50.0,
    }
    r_sim = client.post("/api/v1/demurrage-detention/simulate", json=sim_payload, headers=headers)
    assert r_sim.status_code == 200

    # 2. EIR with tomorrow's date -> 422
    _create_file(db, 5, "IMP-005", current_step_code="STEP_18")
    _setup_tracking(db, 5, "BL-005")

    eir_future_payload = {
        "import_file_id": 5,
        "eir_number": "EIR-HTTP-FUTURE",
        "empty_return_date": tomorrow.isoformat(),
    }
    r_eir_future = client.post(
        "/api/v1/demurrage-detention/empty-container-return",
        json=eir_future_payload,
        headers=headers,
    )
    assert r_eir_future.status_code == 422
    assert "في المستقبل" in r_eir_future.json()["detail"]

    # 3. EIR with valid date on file at STEP_21 -> 201 Created and file stays at STEP_21
    imp6 = _create_file(db, 6, "IMP-006", current_step_code="STEP_21", progress=100.0)
    _setup_tracking(db, 6, "BL-006")

    eir_ok_payload = {
        "import_file_id": 6,
        "eir_number": "EIR-HTTP-OK",
        "empty_return_date": (today - timedelta(days=1)).isoformat(),
    }
    r_eir_ok = client.post(
        "/api/v1/demurrage-detention/empty-container-return",
        json=eir_ok_payload,
        headers=headers,
    )
    assert r_eir_ok.status_code == 201

    db.refresh(imp6)
    assert imp6.current_step_code == "STEP_21"
