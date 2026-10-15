"""
BE45-T06: One active demurrage tracking per import file / Bill of Lading.

Enforces:
1. One active tracking session per import_file_id (409 Conflict).
2. Requirement for active ImportFile when import_file_id is provided (404 Not Found if missing/inactive).
3. Server-owned import_file_code derived from ImportFile (client code is ignored).
4. One active tracking session per Bill of Lading when import_file_id is None (409 Conflict).
5. Multiple active trackings detection in EIR return service (409 Conflict).
"""

from datetime import date, timedelta
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.demurrage_detention.model import DemurrageTracking
from modules.demurrage_detention.schemas import (
    DemurrageTrackingCreate,
    ContainerItemInput,
    EmptyContainerReturnSubmit,
)
from modules.demurrage_detention.service import (
    create_demurrage_tracking_service,
    record_empty_container_return_service,
)
from modules.demurrage_detention import repository
from modules.import_files.model import ImportFile


@pytest.fixture
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        f1 = ImportFile(
            import_file_id=1,
            import_file_code="IMP-2026-00001",
            custom_file_number="CFN-6701068100",
            company_name="Test Importer Co",
            supplier_name="Test Supplier Inc",
            is_active=True,
            created_by="test_user",
            updated_by="test_user",
        )
        f_inactive = ImportFile(
            import_file_id=2,
            import_file_code="IMP-2026-00002",
            company_name="Test Inactive Co",
            supplier_name="Test Supplier Inc",
            is_active=False,
            created_by="test_user",
            updated_by="test_user",
        )
        db.add_all([f1, f_inactive])
        db.commit()
        yield db
    finally:
        db.close()


def _sample_payload(
    import_file_id: int | None = 1,
    bill_of_lading_no: str = "MEDUST123456",
    import_file_code: str | None = None,
) -> DemurrageTrackingCreate:
    return DemurrageTrackingCreate(
        import_file_id=import_file_id,
        import_file_code=import_file_code,
        carrier_name="MSC",
        bill_of_lading_no=bill_of_lading_no,
        port_name="Alexandria Port",
        discharge_date=date(2026, 8, 1),
        gate_out_date=date(2026, 8, 15),
        empty_return_date=date(2026, 8, 20),
        containers=[
            ContainerItemInput(container_no="MSCU1111111", container_type="40ft High Cube"),
        ],
        currency="USD",
        exchange_rate=50.0,
        notes="BE45-T06 test tracking",
    )


def test_cannot_create_second_active_tracking_for_same_file(db_session):
    """
    BE45-T06: Attempting to create a second tracking for the same import file
    must raise 409 Conflict with the active tracking code in the detail.
    """
    t1 = create_demurrage_tracking_service(db_session, _sample_payload(import_file_id=1, bill_of_lading_no="BL-001"))
    assert t1.tracking_id is not None
    assert t1.tracking_code.startswith("DND-")

    with pytest.raises(HTTPException) as exc_info:
        create_demurrage_tracking_service(db_session, _sample_payload(import_file_id=1, bill_of_lading_no="BL-002"))

    assert exc_info.value.status_code == 409
    assert "يوجد بالفعل جلسة تتبع نشطة لهذا الملف" in exc_info.value.detail
    assert t1.tracking_code in exc_info.value.detail


def test_cannot_create_tracking_for_missing_or_inactive_file(db_session):
    """
    BE45-T06: Creating a tracking for a missing or soft-deleted/inactive import file raises 404.
    """
    # Missing file
    with pytest.raises(HTTPException) as exc_info:
        create_demurrage_tracking_service(db_session, _sample_payload(import_file_id=99999, bill_of_lading_no="BL-MISSING"))
    assert exc_info.value.status_code == 404

    # Inactive file (import_file_id=2 is is_active=False)
    with pytest.raises(HTTPException) as exc_info2:
        create_demurrage_tracking_service(db_session, _sample_payload(import_file_id=2, bill_of_lading_no="BL-INACTIVE"))
    assert exc_info2.value.status_code == 404


def test_client_sent_import_file_code_ignored_and_derived_from_db(db_session):
    """
    BE45-T06: Client-sent import_file_code ('FAKE') is ignored;
    the stored code is file.custom_file_number or file.import_file_code.
    """
    payload = _sample_payload(import_file_id=1, import_file_code="FAKE_CLIENT_CODE")
    tracking = create_demurrage_tracking_service(db_session, payload)

    assert tracking.import_file_code == "CFN-6701068100"
    assert tracking.import_file_code != "FAKE_CLIENT_CODE"


def test_can_create_tracking_after_first_is_soft_deleted(db_session):
    """
    BE45-T06: If the previous tracking was soft deleted (is_active == False),
    a new tracking can be created for the file.
    """
    t1 = create_demurrage_tracking_service(db_session, _sample_payload(import_file_id=1, bill_of_lading_no="BL-001"))
    repository.delete_tracking(db_session, t1)
    db_session.commit()
    assert t1.is_active is False

    t2 = create_demurrage_tracking_service(db_session, _sample_payload(import_file_id=1, bill_of_lading_no="BL-002"))
    assert t2.tracking_id is not None
    assert t2.tracking_id != t1.tracking_id
    assert t2.is_active is True


def test_unlinked_tracking_single_bl_guard(db_session):
    """
    BE45-T06: When import_file_id is None, active trackings with the same Bill of Lading
    are rejected with 409 Conflict. Different B/Ls succeed.
    """
    t_bl1 = create_demurrage_tracking_service(
        db_session, _sample_payload(import_file_id=None, bill_of_lading_no="MEDU-UNIQUE-01")
    )
    assert t_bl1.tracking_id is not None
    assert t_bl1.import_file_code is None

    # Duplicate unlinked B/L -> 409
    with pytest.raises(HTTPException) as exc_info:
        create_demurrage_tracking_service(
            db_session, _sample_payload(import_file_id=None, bill_of_lading_no="MEDU-UNIQUE-01")
        )
    assert exc_info.value.status_code == 409
    assert "يوجد بالفعل جلسة تتبع نشطة لبوليصة الشحن" in exc_info.value.detail

    # Different unlinked B/L -> Succeeds
    t_bl2 = create_demurrage_tracking_service(
        db_session, _sample_payload(import_file_id=None, bill_of_lading_no="MEDU-UNIQUE-02")
    )
    assert t_bl2.tracking_id != t_bl1.tracking_id


def test_eir_return_raises_409_when_multiple_active_trackings_exist(db_session):
    """
    BE45-T06: record_empty_container_return_service returns 409 if multiple
    active trackings exist for the file (e.g. legacy duplicate rows).
    """
    # Directly insert two active trackings for the file to simulate legacy duplicates
    t1 = DemurrageTracking(
        tracking_code="DND-2026-0001",
        import_file_id=1,
        carrier_name="MSC",
        bill_of_lading_no="BL-DUP-1",
        discharge_date=date(2026, 8, 1),
        exchange_rate=50.0,
        is_active=True,
    )
    t2 = DemurrageTracking(
        tracking_code="DND-2026-0002",
        import_file_id=1,
        carrier_name="MSC",
        bill_of_lading_no="BL-DUP-2",
        discharge_date=date(2026, 8, 1),
        exchange_rate=50.0,
        is_active=True,
    )
    db_session.add_all([t1, t2])
    db_session.commit()

    eir_payload = EmptyContainerReturnSubmit(
        import_file_id=1,
        eir_number="EIR-TEST-001",
        empty_return_date=date.today() - timedelta(days=1),
        returned_containers=["MSCU1111111"],
    )

    with pytest.raises(HTTPException) as exc_info:
        record_empty_container_return_service(db_session, eir_payload)

    assert exc_info.value.status_code == 409
    assert "يوجد أكثر من جلسة تتبع نشطة لملف الاستيراد" in exc_info.value.detail
