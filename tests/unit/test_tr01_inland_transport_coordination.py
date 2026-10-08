import pytest
from datetime import datetime, timedelta, timezone
from fastapi import HTTPException
from fastapi.testclient import TestClient

from main import app
from database.database import get_db, Base
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from modules.import_files.model import ImportFile
from modules.inland_transport.model import InlandTransportBooking
from modules.inland_transport.schemas import (
    InlandTransportBookingCreate,
    InlandTransportBookingUpdate,
    InlandTransportGateOutSubmit,
    InlandTransportArrivalSubmit,
)
from modules.inland_transport.service import (
    create_transport_booking_service,
    update_transport_booking_service,
    soft_delete_transport_booking_service,
    restore_transport_booking_service,
    record_port_gate_out_service,
    record_warehouse_arrival_service,
    get_transport_booking_by_file_service,
)

# Test in-memory SQLite database setup
TEST_SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(
    TEST_SQLALCHEMY_DATABASE_URL,
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
def client(db_session, monkeypatch):
    import modules.auth.permissions as auth_permissions
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", True)

    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()

def _create_sample_file(db) -> ImportFile:
    imp_file = ImportFile(
        import_file_code="IMP-2026-0095",
        custom_file_number="Machinery Import",
        company_id=1,
        company_name="Delta Industrial Machinery LLC",
        supplier_id=2,
        supplier_name="Bavaria Tech GmbH",
        port_of_discharge="El Dekheila Port",
        delivery_order_no="DO-2026-HAPAG-5511",
        form46_no="DEC-2026-DKH-5511",
        is_customs_released=True,
        customs_release_permit_no="REL-2026-DKH-0044",
        current_module="Phase 7 - Customs Clearance & Release",
        current_stage="Customs Released",
        progress_percent=95.0,
        next_action="تنسيق سيارات النقل الداخلي (TR-01)",
        is_active=True,
    )
    db.add(imp_file)
    db.commit()
    db.refresh(imp_file)
    return imp_file

def test_create_transport_booking_success(db_session):
    imp_file = _create_sample_file(db_session)
    now = datetime.now(timezone.utc)
    departure = now + timedelta(hours=2)
    arrival = now + timedelta(hours=8)

    payload = InlandTransportBookingCreate(
        import_file_id=imp_file.import_file_id,
        waybill_number="WB-2026-DKH-001",
        booking_date=now,
        carrier_name="شركة النصر لخدمات النقل البري",
        truck_plate_number="ط ر س 4821",
        truck_type="Flatbed Trailer (تريلا مسطح)",
        driver_name="محمود عبد المنعم عطية",
        driver_phone="01012345678",
        driver_national_id="28801011234567",
        container_numbers="MSCU1234567, TGHU7654321",
        pickup_port_location="ميناء الدخيلة - رصيف الحاويات 92",
        destination_warehouse="مستودع الشركة الرئيسي - العاشر من رمضان",
        planned_departure_at=departure,
        expected_arrival_at=arrival,
        transport_fare_egp=8500.0,
        status="Booking Confirmed",
        tracking_notes="نقل حاويتين بحالة سليمة وتنسيق تفريغ رافعة شوكية",
    )

    booking = create_transport_booking_service(db_session, payload, user="TransportOfficer")

    assert booking.transport_id is not None
    assert booking.transport_code.startswith("TR-")
    assert booking.truck_plate_number == "ط ر س 4821"
    assert booking.driver_name == "محمود عبد المنعم عطية"
    assert booking.transport_fare_egp == 8500.0
    assert booking.status == "Booking Confirmed"

    # Verify ImportFile synchronization
    db_session.refresh(imp_file)
    assert imp_file.inland_transport_status == "BOOKED"
    assert imp_file.inland_transport_booking_no == "WB-2026-DKH-001"
    assert imp_file.inland_carrier_name == "شركة النصر لخدمات النقل البري"
    assert imp_file.inland_truck_plate_no == "ط ر س 4821"
    assert imp_file.inland_driver_name == "محمود عبد المنعم عطية"
    assert imp_file.inland_driver_phone == "01012345678"
    assert imp_file.inland_transport_cost_egp == 8500.0
    assert imp_file.progress_percent >= 97.0
    assert "Inland Transport" in imp_file.current_stage

def test_record_port_gate_out_and_arrival(db_session):
    imp_file = _create_sample_file(db_session)
    now = datetime.now(timezone.utc)

    payload = InlandTransportBookingCreate(
        import_file_id=imp_file.import_file_id,
        waybill_number="WB-2026-DKH-002",
        carrier_name="شركة الصفا للنقل",
        truck_plate_number="ق ن د 9912",
        truck_type="FLATBED",
        driver_name="عادل سالم الشاذلي",
        driver_phone="01198765432",
        pickup_port_location="ميناء الإسكندرية باب 27",
        destination_warehouse="مستودع 6 أكتوبر",
        planned_departure_at=now,
        expected_arrival_at=now + timedelta(hours=6),
        transport_fare_egp=7200.0,
    )
    booking = create_transport_booking_service(db_session, payload)

    # 1. Record Port Gate Out
    gate_out_time = now + timedelta(hours=1)
    gate_out_payload = InlandTransportGateOutSubmit(
        actual_departure_at=gate_out_time,
        gate_pass_no="GP-2026-DKH-5599",
        notes="خرجت الشاحنة عبر باب 27 بعد سداد رسوم الميزان",
    )
    updated_booking = record_port_gate_out_service(db_session, booking.transport_id, gate_out_payload)
    assert updated_booking.status == "In Transit"
    assert updated_booking.actual_departure_at is not None

    db_session.refresh(imp_file)
    assert imp_file.inland_transport_status == "IN_TRANSIT"
    assert imp_file.inland_departure_date is not None

    # 2. Record Warehouse Arrival
    arrival_time = now + timedelta(hours=5)
    arrival_payload = InlandTransportArrivalSubmit(
        actual_arrival_at=arrival_time,
        seal_intact=True,
        seal_number="SEAL-EGY-991122",
        notes="وصلت الشاحنة سالمة وجاري فحص الأختام للتفريغ",
    )
    arrived_booking = record_warehouse_arrival_service(db_session, booking.transport_id, arrival_payload)
    assert arrived_booking.status == "Arrived at Warehouse"
    assert arrived_booking.actual_arrival_at is not None

    db_session.refresh(imp_file)
    assert imp_file.inland_transport_status == "ARRIVED"
    assert imp_file.inland_actual_arrival_date is not None

def test_transport_validation_rules(db_session):
    imp_file = _create_sample_file(db_session)
    now = datetime.now(timezone.utc)

    # Test invalid plate number
    with pytest.raises(Exception) as exc_plate:
        create_transport_booking_service(
            db_session,
            InlandTransportBookingCreate(
                import_file_id=imp_file.import_file_id,
                waybill_number="WB-001",
                carrier_name="Carrier",
                truck_plate_number="",
                truck_type="FLATBED",
                driver_name="Driver",
                driver_phone="01012345678",
                pickup_port_location="Port",
                destination_warehouse="WH",
                planned_departure_at=now,
                expected_arrival_at=now + timedelta(hours=2),
                transport_fare_egp=5000.0,
            ),
        )
    assert "truck_plate_number" in str(exc_plate.value) or "لوحة الشاحنة" in str(exc_plate.value)

    # Test invalid dates (arrival before departure)
    with pytest.raises(Exception) as exc_date:
        create_transport_booking_service(
            db_session,
            InlandTransportBookingCreate(
                import_file_id=imp_file.import_file_id,
                waybill_number="WB-001",
                carrier_name="Carrier",
                truck_plate_number="ط ر س 1234",
                truck_type="FLATBED",
                driver_name="Driver",
                driver_phone="01012345678",
                pickup_port_location="Port",
                destination_warehouse="WH",
                planned_departure_at=now + timedelta(hours=4),
                expected_arrival_at=now, # Before departure!
                transport_fare_egp=5000.0,
            ),
        )
    assert "الوصول المتوقع" in str(exc_date.value)

def test_inland_transport_rest_api(client, db_session):
    imp_file = _create_sample_file(db_session)
    now = datetime.now(timezone.utc)
    departure = now + timedelta(hours=1)
    arrival = now + timedelta(hours=6)

    # 1. POST /bookings
    post_res = client.post(
        "/api/v1/inland-transport/bookings",
        json={
            "import_file_id": imp_file.import_file_id,
            "waybill_number": "WB-API-001",
            "carrier_name": "شركة الهلال للنقل",
            "truck_plate_number": "أ ب ج 7711",
            "truck_type": "FLATBED",
            "driver_name": "سيد متولي الدسوقي",
            "driver_phone": "01234567890",
            "pickup_port_location": "ميناء بورسعيد",
            "destination_warehouse": "مستودع العاشر",
            "planned_departure_at": departure.isoformat(),
            "expected_arrival_at": arrival.isoformat(),
            "transport_fare_egp": 9500.0,
        },
    )
    assert post_res.status_code == 201
    booking_data = post_res.json()
    assert booking_data["transport_code"].startswith("TR-")
    assert booking_data["truck_plate_number"] == "أ ب ج 7711"
    transport_id = booking_data["transport_id"]

    # 2. GET /bookings/by-file/{import_file_id}
    get_file_res = client.get(f"/api/v1/inland-transport/bookings/by-file/{imp_file.import_file_id}")
    assert get_file_res.status_code == 200
    assert get_file_res.json()["transport_id"] == transport_id

    # 3. POST /bookings/{id}/gate-out
    gate_out_res = client.post(
        f"/api/v1/inland-transport/bookings/{transport_id}/gate-out",
        json={
            "actual_departure_at": departure.isoformat(),
            "gate_pass_no": "GP-9911",
            "notes": "انطلقت الشاحنة",
        },
    )
    assert gate_out_res.status_code == 200
    assert gate_out_res.json()["status"] == "In Transit"

    # 4. POST /bookings/{id}/warehouse-arrival
    arrival_res = client.post(
        f"/api/v1/inland-transport/bookings/{transport_id}/warehouse-arrival",
        json={
            "actual_arrival_at": arrival.isoformat(),
            "seal_intact": True,
            "notes": "وصلت بالسلامة",
        },
    )
    assert arrival_res.status_code == 200
    assert arrival_res.json()["status"] == "Arrived at Warehouse"

    # 5. DELETE /bookings/{id}
    del_res = client.delete(f"/api/v1/inland-transport/bookings/{transport_id}")
    assert del_res.status_code == 204


def _booking_payload(imp_file, waybill="WB-2026-DKH-777"):
    now = datetime.now(timezone.utc)
    return InlandTransportBookingCreate(
        import_file_id=imp_file.import_file_id,
        waybill_number=waybill,
        booking_date=now,
        carrier_name="Nasr Transport",
        truck_plate_number="ABC 4821",
        truck_type="FLATBED",
        driver_name="Mahmoud Attia",
        driver_phone="01012345678",
        driver_national_id="28801011234567",
        container_numbers="MSCU1234567",
        pickup_port_location="El Dekheila Port",
        destination_warehouse="Main Warehouse",
        planned_departure_at=now + timedelta(hours=2),
        expected_arrival_at=now + timedelta(hours=8),
        transport_fare_egp=8500.0,
        status="Booking Confirmed",
    )


def test_create_booking_dispatches_tr03_task_and_closes_tr01_task(db_session):
    from modules.smart_tasks.model import SmartTask

    imp_file = _create_sample_file(db_session)
    tr01 = SmartTask(
        task_code="TSK-TR01-TEST",
        title="Book inland transport trucks to the warehouse (TR-01) - IMP-2026-0095",
        import_file_id=imp_file.import_file_id,
        status="Pending",
        msg_code="CC_TASK_INLAND_TRANSPORT",
    )
    db_session.add(tr01)
    db_session.commit()

    create_transport_booking_service(db_session, _booking_payload(imp_file), user="TransportOfficer")

    db_session.refresh(tr01)
    assert tr01.status == "Completed"
    assert tr01.is_auto_closed is True

    tr03 = db_session.query(SmartTask).filter(SmartTask.msg_code == "TR_TASK_TRACK_ARRIVAL_GRN").all()
    assert len(tr03) == 1
    task = tr03[0]
    assert task.import_file_id == imp_file.import_file_id
    assert task.step_code == "STEP_19"
    assert task.status == "Pending"
    assert "TR-03" in task.title
    assert task.due_date is not None


def test_second_booking_does_not_duplicate_tr03_task(db_session):
    from modules.smart_tasks.model import SmartTask

    imp_file = _create_sample_file(db_session)
    create_transport_booking_service(db_session, _booking_payload(imp_file, "WB-A"), user="TransportOfficer")
    create_transport_booking_service(db_session, _booking_payload(imp_file, "WB-B"), user="TransportOfficer")

    count = db_session.query(SmartTask).filter(
        SmartTask.import_file_id == imp_file.import_file_id,
        SmartTask.msg_code == "TR_TASK_TRACK_ARRIVAL_GRN",
    ).count()
    assert count == 1


def test_failure_after_task_step_leaves_no_booking_and_no_task(db_session, monkeypatch):
    """Phase B review: booking, file sync and the TR-03 task are one transaction (single commit)."""
    from modules.smart_tasks.model import SmartTask
    import modules.inland_transport.service as tr_service

    imp_file = _create_sample_file(db_session)
    file_id = imp_file.import_file_id
    commits = []
    real_commit = db_session.commit

    def failing_commit():
        commits.append(1)
        raise RuntimeError("simulated failure at the final commit")

    monkeypatch.setattr(db_session, "commit", failing_commit)
    with pytest.raises(RuntimeError):
        tr_service.create_transport_booking_service(db_session, _booking_payload(imp_file, "WB-FAIL"), user="T")
    assert len(commits) == 1  # nothing was committed before the final commit
    monkeypatch.setattr(db_session, "commit", real_commit)
    db_session.rollback()

    assert db_session.query(InlandTransportBooking).filter(InlandTransportBooking.waybill_number == "WB-FAIL").count() == 0
    assert db_session.query(SmartTask).filter(
        SmartTask.import_file_id == file_id, SmartTask.msg_code == "TR_TASK_TRACK_ARRIVAL_GRN"
    ).count() == 0


def test_inland_transport_cost_resync_multiple_bookings(db_session):
    """BE810-T01: File inland_transport_cost_egp equals sum of active booking fares."""
    imp_file = _create_sample_file(db_session)
    payload_a = _booking_payload(imp_file, "WB-RESYNC-A")
    payload_a.transport_fare_egp = 3000.0
    payload_b = _booking_payload(imp_file, "WB-RESYNC-B")
    payload_b.transport_fare_egp = 2000.0

    create_transport_booking_service(db_session, payload_a, user="OfficerA")
    create_transport_booking_service(db_session, payload_b, user="OfficerB")

    db_session.refresh(imp_file)
    assert imp_file.inland_transport_cost_egp == 5000.0
    assert imp_file.inland_transport_booking_no == "WB-RESYNC-B"


def test_inland_transport_cost_resync_update_and_delete(db_session):
    """BE810-T01: PUT fare 0 resyncs cost; soft delete resyncs cost and header fields."""
    imp_file = _create_sample_file(db_session)
    payload_a = _booking_payload(imp_file, "WB-UPD-A")
    payload_a.transport_fare_egp = 3000.0
    payload_b = _booking_payload(imp_file, "WB-UPD-B")
    payload_b.transport_fare_egp = 2000.0

    bk_a = create_transport_booking_service(db_session, payload_a, user="OfficerA")
    bk_b = create_transport_booking_service(db_session, payload_b, user="OfficerB")

    db_session.refresh(imp_file)
    assert imp_file.inland_transport_cost_egp == 5000.0

    # PUT B fare to 0 -> cost becomes 3000.0
    update_transport_booking_service(
        db_session, bk_b.transport_id, InlandTransportBookingUpdate(transport_fare_egp=0.0), user="OfficerB"
    )
    db_session.refresh(imp_file)
    assert imp_file.inland_transport_cost_egp == 3000.0

    # Delete A -> cost becomes 0.0, header fields fallback to active booking B
    soft_delete_transport_booking_service(db_session, bk_a.transport_id, user="OfficerA")
    db_session.refresh(imp_file)
    assert imp_file.inland_transport_cost_egp == 0.0
    assert imp_file.inland_transport_booking_no == "WB-UPD-B"

    # Delete B -> cost becomes 0.0, header fields become None
    soft_delete_transport_booking_service(db_session, bk_b.transport_id, user="OfficerB")
    db_session.refresh(imp_file)
    assert imp_file.inland_transport_cost_egp == 0.0
    assert imp_file.inland_transport_booking_no is None
    assert imp_file.inland_carrier_name is None
    assert imp_file.inland_truck_plate_no is None


def test_settlement_aggregation_after_booking_fare_zeroed(db_session):
    """BE810-T01: Financial settlement aggregation does not charge corrected 0 fare."""
    from modules.financial_settlement.service import aggregate_shipment_invoices_service

    imp_file = _create_sample_file(db_session)
    payload = _booking_payload(imp_file, "WB-SETTLE-01")
    payload.transport_fare_egp = 5000.0

    bk = create_transport_booking_service(db_session, payload, user="Officer")
    db_session.refresh(imp_file)
    assert imp_file.inland_transport_cost_egp == 5000.0

    # Correct fare to 0
    update_transport_booking_service(
        db_session, bk.transport_id, InlandTransportBookingUpdate(transport_fare_egp=0.0), user="Officer"
    )
    db_session.refresh(imp_file)
    assert imp_file.inland_transport_cost_egp == 0.0

    # Aggregate settlement invoices
    resp = aggregate_shipment_invoices_service(db_session, imp_file.import_file_id)
    transport_invoices = [inv for inv in resp.invoices if inv.party_type == "TRANSPORT" or inv.category == "Inland Trucking"]
    for inv in transport_invoices:
        assert inv.amount_egp == 0.0
    # Specifically assert no 5000.0 transport invoice
    assert not any(inv.amount_egp == 5000.0 for inv in transport_invoices)


def test_restore_transport_booking_success(db_session):
    """BE810-T15: Delete then restore reactivates booking and resyncs file cost and fields."""
    imp_file = _create_sample_file(db_session)
    payload = _booking_payload(imp_file, "WB-RESTORE-01")
    payload.transport_fare_egp = 4200.0

    bk = create_transport_booking_service(db_session, payload, user="Officer")
    db_session.refresh(imp_file)
    assert imp_file.inland_transport_cost_egp == 4200.0

    # Delete
    soft_delete_transport_booking_service(db_session, bk.transport_id, user="Officer")
    db_session.refresh(bk)
    db_session.refresh(imp_file)
    assert bk.is_active is False
    assert imp_file.inland_transport_cost_egp == 0.0

    # Restore
    restored = restore_transport_booking_service(db_session, bk.transport_id, user="Officer")
    db_session.refresh(imp_file)
    assert restored.is_active is True
    assert imp_file.inland_transport_cost_egp == 4200.0
    assert imp_file.inland_transport_booking_no == "WB-RESTORE-01"


def test_restore_transport_booking_duplicate_waybill_raises_409(db_session):
    """BE810-T15: Restoring when an active booking exists with same waybill raises 409 IT_BOOKING_EXISTS."""
    from fastapi import HTTPException

    imp_file = _create_sample_file(db_session)
    payload1 = _booking_payload(imp_file, "WB-DUP-WAYBILL")
    bk1 = create_transport_booking_service(db_session, payload1, user="Officer")

    # Soft delete booking 1
    soft_delete_transport_booking_service(db_session, bk1.transport_id, user="Officer")

    # Create new active booking 2 with the same waybill
    payload2 = _booking_payload(imp_file, "WB-DUP-WAYBILL")
    bk2 = create_transport_booking_service(db_session, payload2, user="Officer")

    # Attempting to restore booking 1 must raise 409
    with pytest.raises(HTTPException) as exc:
        restore_transport_booking_service(db_session, bk1.transport_id, user="Officer")
    assert exc.value.status_code == 409
    assert exc.value.detail.get("code") == "IT_BOOKING_EXISTS"


def test_restore_transport_booking_api(client, db_session):
    """BE810-T15: PATCH /api/v1/inland-transport/bookings/{id}/restore reactivates booking via API."""
    imp_file = _create_sample_file(db_session)
    payload = _booking_payload(imp_file, "WB-RESTORE-API")
    payload.transport_fare_egp = 3500.0

    bk = create_transport_booking_service(db_session, payload, user="Officer")
    soft_delete_transport_booking_service(db_session, bk.transport_id, user="Officer")

    resp = client.patch(f"/api/v1/inland-transport/bookings/{bk.transport_id}/restore")
    assert resp.status_code == 200
    data = resp.json()
    assert data["transport_id"] == bk.transport_id
    assert data["is_active"] is True
    assert data["transport_fare_egp"] == 3500.0

    db_session.refresh(imp_file)
    assert imp_file.inland_transport_cost_egp == 3500.0


def test_restore_transport_booking_404(client):
    resp = client.patch("/api/v1/inland-transport/bookings/999999/restore")
    assert resp.status_code == 404


def test_restore_transport_booking_closed_file_is_409(db_session):
    """Restore on a Closed file returns 409 IMPORT_FILE_CLOSED and booking remains inactive."""
    imp_file = _create_sample_file(db_session)
    payload = _booking_payload(imp_file, "WB-CLOSED-RESTORE")
    payload.transport_fare_egp = 5000.0

    bk = create_transport_booking_service(db_session, payload, user="Officer")
    soft_delete_transport_booking_service(db_session, bk.transport_id, user="Officer")

    imp_file.status = "Closed"
    db_session.commit()

    with pytest.raises(HTTPException) as exc:
        restore_transport_booking_service(db_session, bk.transport_id, user="Officer")
    assert exc.value.status_code == 409
    assert exc.value.detail.get("code") == "IMPORT_FILE_CLOSED"

    db_session.refresh(bk)
    assert bk.is_active is False


def test_restore_transport_booking_permissions(client, db_session, monkeypatch):
    """View-only user receives 403; user with warehouse_receiving.receive succeeds."""
    from modules.auth.security import create_access_token
    from modules.users.model import User, Role
    from modules.auth.seed_rbac import seed_rbac
    import modules.auth.permissions as ap

    seed_rbac(db_session)
    viewer_role = db_session.query(Role).filter(Role.role_code == "AUDITOR_VIEWER").first()
    operator_role = db_session.query(Role).filter(Role.role_code == "LOGISTICS_OPERATOR").first()

    viewer = User(username="it_view_user", full_name="IT Viewer", email="it_viewer@test.com", hashed_password="x", role="AUDITOR_VIEWER", role_id=viewer_role.role_id, is_active=True)
    operator = User(username="it_op_user", full_name="IT Operator", email="it_operator@test.com", hashed_password="x", role="LOGISTICS_OPERATOR", role_id=operator_role.role_id, is_active=True)
    db_session.add_all([viewer, operator])
    db_session.commit()

    imp_file = _create_sample_file(db_session)
    payload = _booking_payload(imp_file, "WB-PERM-TEST")
    bk = create_transport_booking_service(db_session, payload, user="it_op_user")
    soft_delete_transport_booking_service(db_session, bk.transport_id, user="it_op_user")

    monkeypatch.setattr(ap, "ALLOW_DEV_AUTH_BYPASS", False)

    viewer_token = create_access_token({"sub": str(viewer.user_id), "role": viewer.role})
    res = client.patch(f"/api/v1/inland-transport/bookings/{bk.transport_id}/restore", headers={"Authorization": f"Bearer {viewer_token}"})
    assert res.status_code == 403

    operator_token = create_access_token({"sub": str(operator.user_id), "role": operator.role})
    res = client.patch(f"/api/v1/inland-transport/bookings/{bk.transport_id}/restore", headers={"Authorization": f"Bearer {operator_token}"})
    assert res.status_code == 200
    assert res.json()["is_active"] is True


# ─── BE810-T13: IT Create Validation & Defaults Hardening ─────────────────────


def test_create_booking_status_delivered_raises_400(client, db_session):
    """BE810-T13: create with status 'Delivered' -> 400 IT_STATUS_INVALID."""
    imp_file = _create_sample_file(db_session)
    now = datetime.now(timezone.utc)
    payload = {
        "import_file_id": imp_file.import_file_id,
        "waybill_number": "WB-STATUS-DELIV",
        "carrier_name": "Carrier A",
        "truck_plate_number": "TRK 111",
        "truck_type": "FLATBED",
        "driver_name": "Driver A",
        "driver_phone": "01012345678",
        "pickup_port_location": "Port",
        "destination_warehouse": "WH",
        "planned_departure_at": now.isoformat(),
        "expected_arrival_at": (now + timedelta(hours=4)).isoformat(),
        "transport_fare_egp": 5000.0,
        "status": "Delivered",
    }
    resp = client.post("/api/v1/inland-transport/bookings", json=payload)
    assert resp.status_code == 400
    detail = resp.json().get("detail", {})
    assert detail.get("code") == "IT_STATUS_INVALID"


def test_create_booking_in_transit_without_departure_date_raises_400(client, db_session):
    """BE810-T13: 'In Transit' on create requires actual_departure_at."""
    imp_file = _create_sample_file(db_session)
    now = datetime.now(timezone.utc)
    payload = {
        "import_file_id": imp_file.import_file_id,
        "waybill_number": "WB-IN-TRANSIT-NO-DEP",
        "carrier_name": "Carrier A",
        "truck_plate_number": "TRK 111",
        "truck_type": "FLATBED",
        "driver_name": "Driver A",
        "driver_phone": "01012345678",
        "pickup_port_location": "Port",
        "destination_warehouse": "WH",
        "planned_departure_at": now.isoformat(),
        "expected_arrival_at": (now + timedelta(hours=4)).isoformat(),
        "transport_fare_egp": 5000.0,
        "status": "In Transit",
    }
    resp = client.post("/api/v1/inland-transport/bookings", json=payload)
    assert resp.status_code == 400
    assert "actual_departure_at" in str(resp.json()) or "موعد المغادرة الفعلي" in str(resp.json())


def test_create_booking_actual_arrival_at_rejected(client, db_session):
    """BE810-T13: actual_arrival_at on create -> 400."""
    imp_file = _create_sample_file(db_session)
    now = datetime.now(timezone.utc)
    payload = {
        "import_file_id": imp_file.import_file_id,
        "waybill_number": "WB-ARRIVAL-ON-CREATE",
        "carrier_name": "Carrier A",
        "truck_plate_number": "TRK 111",
        "truck_type": "FLATBED",
        "driver_name": "Driver A",
        "driver_phone": "01012345678",
        "pickup_port_location": "Port",
        "destination_warehouse": "WH",
        "planned_departure_at": now.isoformat(),
        "expected_arrival_at": (now + timedelta(hours=4)).isoformat(),
        "actual_arrival_at": (now + timedelta(hours=5)).isoformat(),
        "transport_fare_egp": 5000.0,
    }
    resp = client.post("/api/v1/inland-transport/bookings", json=payload)
    assert resp.status_code == 400
    assert "لا يمكن تسجيل موعد الوصول الفعلي" in str(resp.json())


def test_create_booking_unknown_carrier_id_raises_400(client, db_session):
    """BE810-T13: unknown carrier_id 999999 -> 400 IT_CARRIER_INVALID."""
    imp_file = _create_sample_file(db_session)
    now = datetime.now(timezone.utc)
    payload = {
        "import_file_id": imp_file.import_file_id,
        "waybill_number": "WB-UNKNOWN-CARRIER",
        "carrier_id": 999999,
        "carrier_name": "Any Name",
        "truck_plate_number": "TRK 111",
        "truck_type": "FLATBED",
        "driver_name": "Driver A",
        "driver_phone": "01012345678",
        "pickup_port_location": "Port",
        "destination_warehouse": "WH",
        "planned_departure_at": now.isoformat(),
        "expected_arrival_at": (now + timedelta(hours=4)).isoformat(),
        "transport_fare_egp": 5000.0,
    }
    resp = client.post("/api/v1/inland-transport/bookings", json=payload)
    assert resp.status_code == 400
    detail = resp.json().get("detail", {})
    assert detail.get("code") == "IT_CARRIER_INVALID"


def test_create_booking_valid_carrier_id_sets_carrier_name(db_session):
    """BE810-T13: valid carrier_id loads partner_name into carrier_name."""
    from modules.external_service_providers.model import ExternalServiceProvider

    provider = ExternalServiceProvider(
        partner_code="PRV-IT-TEST-01",
        partner_name="Al-Ahram Transport Logistics",
        partner_type="Inland Transport",
        is_active=True,
    )
    db_session.add(provider)
    db_session.commit()
    db_session.refresh(provider)

    imp_file = _create_sample_file(db_session)
    payload = _booking_payload(imp_file, "WB-CARRIER-SET")
    payload.carrier_id = provider.provider_id
    payload.carrier_name = None

    booking = create_transport_booking_service(db_session, payload, user="Officer")
    assert booking.carrier_name == "Al-Ahram Transport Logistics"
    assert booking.carrier_id == provider.provider_id


def test_create_booking_invalid_truck_type_spaceship_raises_400(client, db_session):
    """BE810-T13: truck type 'Spaceship' -> 400 IT_TRUCK_TYPE_INVALID."""
    imp_file = _create_sample_file(db_session)
    now = datetime.now(timezone.utc)
    payload = {
        "import_file_id": imp_file.import_file_id,
        "waybill_number": "WB-SPACESHIP",
        "carrier_name": "Carrier A",
        "truck_plate_number": "TRK 111",
        "truck_type": "Spaceship",
        "driver_name": "Driver A",
        "driver_phone": "01012345678",
        "pickup_port_location": "Port",
        "destination_warehouse": "WH",
        "planned_departure_at": now.isoformat(),
        "expected_arrival_at": (now + timedelta(hours=4)).isoformat(),
        "transport_fare_egp": 5000.0,
    }
    resp = client.post("/api/v1/inland-transport/bookings", json=payload)
    assert resp.status_code == 400
    detail = resp.json().get("detail", {})
    assert detail.get("code") == "IT_TRUCK_TYPE_INVALID"


def test_update_booking_invalid_truck_type_spaceship_raises_400(client, db_session):
    """BE810-T13: updating truck type to 'Spaceship' via PUT -> 400 IT_TRUCK_TYPE_INVALID."""
    imp_file = _create_sample_file(db_session)
    payload = _booking_payload(imp_file, "WB-PUT-SPACESHIP")
    bk = create_transport_booking_service(db_session, payload, user="Officer")

    resp = client.put(
        f"/api/v1/inland-transport/bookings/{bk.transport_id}",
        json={"truck_type": "Spaceship"},
    )
    assert resp.status_code == 400
    detail = resp.json().get("detail", {})
    assert detail.get("code") == "IT_TRUCK_TYPE_INVALID"


def test_create_booking_missing_required_fields_raises_422(client, db_session):
    """BE810-T13: missing fare, destination_warehouse or truck_type -> 422."""
    imp_file = _create_sample_file(db_session)
    now = datetime.now(timezone.utc)
    base_payload = {
        "import_file_id": imp_file.import_file_id,
        "waybill_number": "WB-MISSING-FIELDS",
        "carrier_name": "Carrier A",
        "truck_plate_number": "TRK 111",
        "truck_type": "FLATBED",
        "driver_name": "Driver A",
        "driver_phone": "01012345678",
        "pickup_port_location": "Port",
        "destination_warehouse": "WH",
        "planned_departure_at": now.isoformat(),
        "expected_arrival_at": (now + timedelta(hours=4)).isoformat(),
        "transport_fare_egp": 5000.0,
    }

    # Missing fare -> 422
    payload_no_fare = dict(base_payload)
    del payload_no_fare["transport_fare_egp"]
    resp = client.post("/api/v1/inland-transport/bookings", json=payload_no_fare)
    assert resp.status_code == 422

    # Missing destination_warehouse -> 422
    payload_no_wh = dict(base_payload)
    del payload_no_wh["destination_warehouse"]
    resp = client.post("/api/v1/inland-transport/bookings", json=payload_no_wh)
    assert resp.status_code == 422

    # Missing truck_type -> 422
    payload_no_tt = dict(base_payload)
    del payload_no_tt["truck_type"]
    resp = client.post("/api/v1/inland-transport/bookings", json=payload_no_tt)
    assert resp.status_code == 422


def test_create_booking_in_transit_with_departure_allowed(client, db_session):
    """BE810-T13: In Transit status is allowed on create when actual_departure_at is provided."""
    imp_file = _create_sample_file(db_session)
    now = datetime.now(timezone.utc)
    payload = {
        "import_file_id": imp_file.import_file_id,
        "waybill_number": "WB-IN-TRANSIT-OK",
        "carrier_name": "Carrier A",
        "truck_plate_number": "TRK 222",
        "truck_type": "FLATBED",
        "driver_name": "Driver B",
        "driver_phone": "01012345678",
        "pickup_port_location": "Port",
        "destination_warehouse": "WH",
        "planned_departure_at": now.isoformat(),
        "expected_arrival_at": (now + timedelta(hours=4)).isoformat(),
        "actual_departure_at": now.isoformat(),
        "transport_fare_egp": 5000.0,
        "status": "In Transit",
    }
    resp = client.post("/api/v1/inland-transport/bookings", json=payload)
    assert resp.status_code == 201
    assert resp.json()["status"] == "In Transit"


def test_update_booking_unknown_carrier_id_raises_400(client, db_session):
    """BE810-T13: PUT with unknown carrier_id returns 400 IT_CARRIER_INVALID."""
    imp_file = _create_sample_file(db_session)
    payload = _booking_payload(imp_file, "WB-PUT-CARRIER-INVALID")
    bk = create_transport_booking_service(db_session, payload, user="Officer")

    resp = client.put(
        f"/api/v1/inland-transport/bookings/{bk.transport_id}",
        json={"carrier_id": 999999},
    )
    assert resp.status_code == 400
    assert resp.json().get("detail", {}).get("code") == "IT_CARRIER_INVALID"
