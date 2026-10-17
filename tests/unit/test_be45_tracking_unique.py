"""
Unit tests for BE45-T06:
Enforce at most one active demurrage tracking session per import file,
or per Bill of Lading when there is no import file.
"""
from datetime import date
import pytest
from fastapi import FastAPI, HTTPException, status
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base, get_db
from modules.import_files.model import ImportFile
import modules.inland_transport.model  # noqa: F401
from modules.demurrage_detention.model import DemurrageTracking
from modules.demurrage_detention.schemas import (
    DemurrageTrackingCreate,
    ContainerItemInput,
    EmptyContainerReturnSubmit,
)
import modules.demurrage_detention.service as dd
import modules.demurrage_detention.router as dd_router


@pytest.fixture
def session_factory():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    yield sessionmaker(bind=engine, autoflush=False)
    engine.dispose()


@pytest.fixture
def db(session_factory):
    session = session_factory()
    yield session
    session.close()


@pytest.fixture
def test_import_file(db):
    imp_file = ImportFile(
        import_file_id=100,
        import_file_code="IMP-2026-0100",
        custom_file_number="CUSTOMS-6701068100",
        company_name="Al-Amal Import Co",
        supplier_name="Global Steel Ltd",
        owner="tester",
        is_active=True,
    )
    db.add(imp_file)
    db.commit()
    db.refresh(imp_file)
    return imp_file


def _make_tracking_req(
    import_file_id=None,
    import_file_code=None,
    bill_of_lading_no="MEDU12345678",
    carrier_name="MSC",
    discharge_date=None,
):
    return DemurrageTrackingCreate(
        import_file_id=import_file_id,
        import_file_code=import_file_code,
        carrier_name=carrier_name,
        bill_of_lading_no=bill_of_lading_no,
        discharge_date=discharge_date or date(2026, 1, 1),
        containers=[
            ContainerItemInput(container_no="MSCU1111111", container_type="40ft High Cube")
        ],
        currency="USD",
        exchange_rate=50.0,
    )


def test_create_tracking_unique_per_import_file(db, test_import_file):
    # 1. First tracking succeeds
    req1 = _make_tracking_req(
        import_file_id=test_import_file.import_file_id,
        import_file_code="IGNORED_FAKE",
        bill_of_lading_no="BL001",
    )
    t1 = dd.create_demurrage_tracking_service(db, req1, user="tester")
    assert t1.tracking_id is not None
    assert t1.import_file_id == test_import_file.import_file_id
    # Overwritten from DB custom_file_number
    assert t1.import_file_code == "CUSTOMS-6701068100"

    # 2. Second tracking for the same import file raises 409 Conflict
    req2 = _make_tracking_req(
        import_file_id=test_import_file.import_file_id,
        bill_of_lading_no="BL002",
    )
    with pytest.raises(HTTPException) as exc:
        dd.create_demurrage_tracking_service(db, req2, user="tester")
    assert exc.value.status_code == status.HTTP_409_CONFLICT
    assert "يوجد بالفعل جلسة تتبع أرضيات نشطة لهذا الملف" in exc.value.detail
    assert t1.tracking_code in exc.value.detail


def test_create_tracking_file_not_found(db):
    req = _make_tracking_req(import_file_id=99999, bill_of_lading_no="BL999")
    with pytest.raises(HTTPException) as exc:
        dd.create_demurrage_tracking_service(db, req, user="tester")
    assert exc.value.status_code == status.HTTP_404_NOT_FOUND
    assert "ملف الاستيراد رقم 99999 غير موجود أو غير نشط" in exc.value.detail


def test_create_tracking_file_inactive(db):
    inactive_file = ImportFile(
        import_file_id=200,
        import_file_code="IMP-2026-0200",
        company_name="Inactive Corp",
        supplier_name="Global Supplier",
        owner="tester",
        is_active=False,
    )
    db.add(inactive_file)
    db.commit()

    req = _make_tracking_req(import_file_id=200, bill_of_lading_no="BL200")
    with pytest.raises(HTTPException) as exc:
        dd.create_demurrage_tracking_service(db, req, user="tester")
    assert exc.value.status_code == status.HTTP_404_NOT_FOUND
    assert "ملف الاستيراد رقم 200 غير موجود أو غير نشط" in exc.value.detail


def test_create_tracking_fallback_to_import_file_code(db):
    file_no_custom = ImportFile(
        import_file_id=300,
        import_file_code="IMP-2026-0300",
        custom_file_number=None,
        company_name="Direct Corp",
        supplier_name="Global Supplier",
        owner="tester",
        is_active=True,
    )
    db.add(file_no_custom)
    db.commit()

    req = _make_tracking_req(import_file_id=300, bill_of_lading_no="BL300")
    t = dd.create_demurrage_tracking_service(db, req, user="tester")
    assert t.import_file_code == "IMP-2026-0300"


def test_create_tracking_unique_per_bl_without_file(db):
    # 1. First tracking for B/L succeeds
    req1 = _make_tracking_req(import_file_id=None, bill_of_lading_no="MEDU_STANDALONE")
    t1 = dd.create_demurrage_tracking_service(db, req1, user="tester")
    assert t1.tracking_id is not None
    assert t1.import_file_id is None
    assert t1.import_file_code is None

    # 2. Second tracking for same B/L without file raises 409 Conflict
    req2 = _make_tracking_req(import_file_id=None, bill_of_lading_no="MEDU_STANDALONE")
    with pytest.raises(HTTPException) as exc:
        dd.create_demurrage_tracking_service(db, req2, user="tester")
    assert exc.value.status_code == status.HTTP_409_CONFLICT
    assert "يوجد بالفعل جلسة تتبع أرضيات نشطة لبوليصة الشحن MEDU_STANDALONE" in exc.value.detail

    # 3. Different B/L succeeds
    req3 = _make_tracking_req(import_file_id=None, bill_of_lading_no="MEDU_OTHER")
    t3 = dd.create_demurrage_tracking_service(db, req3, user="tester")
    assert t3.tracking_id is not None


def test_create_tracking_allowed_after_soft_delete(db, test_import_file):
    # Tracking for file
    req_file = _make_tracking_req(import_file_id=test_import_file.import_file_id, bill_of_lading_no="BL-SOFT-FILE")
    t_file = dd.create_demurrage_tracking_service(db, req_file, user="tester")

    # Soft-delete the tracking
    t_file.is_active = False
    db.commit()

    # Now creating a new tracking for the same file succeeds
    t_file_new = dd.create_demurrage_tracking_service(db, req_file, user="tester")
    assert t_file_new.tracking_id != t_file.tracking_id
    assert t_file_new.is_active is True

    # Tracking for B/L standalone
    req_bl = _make_tracking_req(import_file_id=None, bill_of_lading_no="BL-SOFT-STANDALONE")
    t_bl = dd.create_demurrage_tracking_service(db, req_bl, user="tester")

    # Soft-delete the B/L tracking
    t_bl.is_active = False
    db.commit()

    # Now creating a new tracking for the same B/L succeeds
    t_bl_new = dd.create_demurrage_tracking_service(db, req_bl, user="tester")
    assert t_bl_new.tracking_id != t_bl.tracking_id
    assert t_bl_new.is_active is True


def test_record_empty_container_return_multiple_active_trackings(db, test_import_file):
    # Simulate legacy duplicate data: two active trackings for the same import file
    t1 = DemurrageTracking(
        import_file_id=test_import_file.import_file_id,
        tracking_code="DND-DUP-001",
        carrier_name="MSC",
        bill_of_lading_no="BL-DUP1",
        discharge_date=date(2026, 1, 1),
        exchange_rate=50.0,
        is_active=True,
    )
    t2 = DemurrageTracking(
        import_file_id=test_import_file.import_file_id,
        tracking_code="DND-DUP-002",
        carrier_name="MSC",
        bill_of_lading_no="BL-DUP2",
        discharge_date=date(2026, 1, 1),
        exchange_rate=50.0,
        is_active=True,
    )
    db.add_all([t1, t2])
    db.commit()

    payload = EmptyContainerReturnSubmit(
        import_file_id=test_import_file.import_file_id,
        empty_return_date=date(2026, 1, 5),
        eir_number="EIR-12345",
    )
    with pytest.raises(HTTPException) as exc:
        dd.record_empty_container_return_service(db, payload)
    assert exc.value.status_code == status.HTTP_409_CONFLICT
    assert f"يوجد أكثر من جلسة تتبع نشطة لملف الاستيراد رقم {test_import_file.import_file_id}" in exc.value.detail


def test_api_endpoint_conflict_responses(session_factory, test_import_file):
    from modules.auth.router import get_current_user
    from modules.auth.permissions import require_permission
    from modules.users.model import User

    fake_user = User(
        user_id=1,
        username="admin",
        email="admin@example.com",
        is_active=True,
    )

    app = FastAPI()
    app.include_router(dd_router.router)

    def _override_db():
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = _override_db
    app.dependency_overrides[get_current_user] = lambda: fake_user
    app.dependency_overrides[require_permission("demurrage_detention.manage")] = lambda: fake_user
    client = TestClient(app)

    payload = {
        "import_file_id": test_import_file.import_file_id,
        "import_file_code": "CLI_FAKE",
        "carrier_name": "MSC",
        "bill_of_lading_no": "BL-API-1",
        "discharge_date": "2026-01-01",
        "containers": [{"container_no": "MSCU1111111", "container_type": "40ft High Cube"}],
        "currency": "USD",
        "exchange_rate": 50.0,
    }

    # First POST succeeds
    res1 = client.post("/api/v1/demurrage-detention/trackings", json=payload)
    assert res1.status_code == 201
    data1 = res1.json()
    assert data1["import_file_code"] == "CUSTOMS-6701068100"

    # Second POST with same file fails with 409
    payload2 = dict(payload, bill_of_lading_no="BL-API-2")
    res2 = client.post("/api/v1/demurrage-detention/trackings", json=payload2)
    assert res2.status_code == 409
    assert "يوجد بالفعل جلسة تتبع أرضيات نشطة لهذا الملف" in res2.json()["detail"]

    # Post with non-existent file fails with 404
    payload_404 = dict(payload, import_file_id=88888)
    res_404 = client.post("/api/v1/demurrage-detention/trackings", json=payload_404)
    assert res_404.status_code == 404
