import pytest
from datetime import date, datetime, timezone, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient
from fastapi import HTTPException

import main
from database.database import Base, get_db
from modules.auth.router import get_current_user
from modules.users.model import User
from modules.import_files.model import ImportFile
from modules.freight_booking.model import ShipmentBooking
from modules.cargo_shipping.model import CargoShippingRecord
from modules.demurrage_detention.model import DemurrageTracking, DemurragePolicy
from modules.demurrage_detention.service import recalculate_and_update_tracking_service
from modules.demurrage_detention.schemas import DemurrageTrackingUpdate
from modules.containers.model import ShipmentContainer
from modules.containers.schemas import (
    ContainerCreate,
    ContainerUpdate,
    ContainerGateOutRequest,
    ContainerEmptyReturnRequest,
)
from modules.containers.service import (
    create_container_service,
    get_container_by_id_service,
    get_containers_service,
    update_container_service,
    gate_out_container_service,
    empty_return_container_service,
    delete_container_service,
    sync_containers_from_file_service,
)

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
def mock_user():
    return User(
        user_id=1,
        username="admin_test",
        email="admin@test.com",
        full_name="Admin Test",
        is_active=True,
    )


@pytest.fixture(scope="function")
def client(db_session, mock_user):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    def override_get_current_user():
        return mock_user

    main.app.dependency_overrides[get_db] = override_get_db
    main.app.dependency_overrides[get_current_user] = override_get_current_user
    with TestClient(main.app) as c:
        yield c
    main.app.dependency_overrides.clear()


@pytest.fixture
def sample_import_file(db_session):
    imp_file = ImportFile(
        import_file_code="IMP-2026-CONT-01",
        company_name="Al-Baraa Engineering",
        supplier_name="Global Steel Corp",
        status="ACTIVE",
        is_active=True,
    )
    db_session.add(imp_file)
    db_session.commit()
    db_session.refresh(imp_file)
    return imp_file


class TestContainersService:

    def test_create_container_success(self, db_session, sample_import_file):
        """Creates container entity successfully with normalized number and defaults"""
        req = ContainerCreate(
            container_number="mscu-1234567 ",
            container_type="40HC",
            seal_number="SL-991122",
            import_file_id=sample_import_file.import_file_id,
            carrier_name="MSC",
            tare_weight_kg=3800.0,
            gross_weight_kg=28000.0,
            vgm_weight_kg=28000.0,
            vgm_status="Verified",
        )
        container = create_container_service(db_session, req, user="test_user")

        assert container.container_id is not None
        assert container.container_number == "MSCU1234567"
        assert container.container_type == "40HC"
        assert container.seal_number == "SL-991122"
        assert container.import_file_id == sample_import_file.import_file_id
        assert container.carrier_name == "MSC"
        assert container.status == "Allocated"
        assert container.is_active is True
        assert container.created_by == "test_user"

    def test_create_container_duplicate_number_rejected(self, db_session, sample_import_file):
        """Duplicate container number in same import file raises 409 Conflict"""
        req1 = ContainerCreate(
            container_number="MSCU1234567",
            container_type="40HC",
            import_file_id=sample_import_file.import_file_id,
        )
        create_container_service(db_session, req1)

        req2 = ContainerCreate(
            container_number="mscu 1234567",
            container_type="20GP",
            import_file_id=sample_import_file.import_file_id,
        )
        with pytest.raises(HTTPException) as exc:
            create_container_service(db_session, req2)
        assert exc.value.status_code == 409
        assert "مسجل مسبقاً" in exc.value.detail

    def test_create_container_invalid_number_rejected(self, db_session, sample_import_file):
        """Empty or too short container number raises 422"""
        with pytest.raises(HTTPException) as exc1:
            create_container_service(
                db_session,
                ContainerCreate(
                    container_number="  ",
                    container_type="40HC",
                    import_file_id=sample_import_file.import_file_id,
                ),
            )
        assert exc1.value.status_code == 422

        with pytest.raises(HTTPException) as exc2:
            create_container_service(
                db_session,
                ContainerCreate(
                    container_number="A1",
                    container_type="40HC",
                    import_file_id=sample_import_file.import_file_id,
                ),
            )
        assert exc2.value.status_code == 422

    def test_container_milestone_date_validations(self, db_session, sample_import_file):
        """Validates date sanity: gate_out >= discharge, empty_return >= gate_out"""
        discharge = date(2026, 9, 10)
        gate_out = date(2026, 9, 5)  # Invalid: before discharge

        with pytest.raises(HTTPException) as exc:
            create_container_service(
                db_session,
                ContainerCreate(
                    container_number="MSCU9998881",
                    container_type="40HC",
                    import_file_id=sample_import_file.import_file_id,
                    discharge_date=discharge,
                    gate_out_date=gate_out,
                ),
            )
        assert exc.value.status_code == 422
        assert "لا يمكن أن يسبق تاريخ التفريغ" in exc.value.detail

    def test_container_gate_out_and_empty_return_milestones(self, db_session, sample_import_file):
        """Tracks container gate-out and return empty with EIR and condition"""
        req = ContainerCreate(
            container_number="MSCU7766554",
            container_type="40HC",
            import_file_id=sample_import_file.import_file_id,
            discharge_date=date(2026, 9, 1),
        )
        container = create_container_service(db_session, req, user="logistics_agent")

        # 1. Gate Out
        gate_out_req = ContainerGateOutRequest(
            gate_out_date=date(2026, 9, 5),
            truck_plate_number="ط ص ع 9876",
            driver_name="محمود عبد العزيز",
            notes="تم الخروج مع حراسة جمركية",
        )
        gated = gate_out_container_service(db_session, container.container_id, gate_out_req, user="logistics_agent")
        assert gated.status == "Gate Out"
        assert gated.gate_out_date == date(2026, 9, 5)
        assert "محمود عبد العزيز" in gated.notes

        # 2. Empty Return (EIR)
        return_req = ContainerEmptyReturnRequest(
            empty_return_date=date(2026, 9, 12),
            eir_number="EIR-MSC-2026-5544",
            depot_name="مستودع العامرية للخطوط الملاحية",
            condition_at_return="Good",
            notes="تم استلام إيصال EIR بدون ملاحظات",
        )
        returned = empty_return_container_service(db_session, container.container_id, return_req, user="logistics_agent")
        assert returned.status == "Returned Empty"
        assert returned.empty_return_date == date(2026, 9, 12)
        assert returned.eir_number == "EIR-MSC-2026-5544"
        assert returned.depot_name == "مستودع العامرية للخطوط الملاحية"

    def test_sync_containers_from_file(self, db_session, sample_import_file):
        """Synchronizes and backfills containers from CargoShipping and DemurrageTracking"""
        file_id = sample_import_file.import_file_id

        # 1. Add CargoShippingRecord with loading data
        shipping = CargoShippingRecord(
            cargo_shipping_code="SHP-2026-901",
            import_file_id=file_id,
            shipment_type="FCL",
            containers_loading_data=[
                {
                    "container_no": "CMAU1122334",
                    "container_type": "40HC",
                    "seal_no": "SL-111",
                    "tare_weight_kg": 3900.0,
                    "gross_weight_kg": 27500.0,
                    "vgm_status": "Verified",
                },
                {
                    "container_no": "CMAU5566778",
                    "container_type": "20GP",
                    "seal_no": "SL-222",
                    "tare_weight_kg": 2200.0,
                    "gross_weight_kg": 18000.0,
                    "vgm_status": "Verified",
                },
            ],
            is_active=True,
        )
        db_session.add(shipping)

        # 2. Add DemurrageTracking with dates and charges
        tracking = DemurrageTracking(
            tracking_code="DND-2026-901",
            import_file_id=file_id,
            carrier_name="CMA CGM",
            bill_of_lading_no="CMA998877",
            port_name="Alexandria Port",
            discharge_date=date(2026, 9, 1),
            containers=[
                {
                    "container_no": "CMAU1122334",
                    "container_type": "40HC",
                    "discharge_date": "2026-09-01",
                    "gate_out_date": "2026-09-04",
                    "empty_return_date": "2026-09-10",
                    "demurrage_days": 0,
                    "detention_days": 0,
                    "storage_days": 0,
                    "demurrage_fx": 0.0,
                    "detention_fx": 0.0,
                    "storage_egp": 0.0,
                    "total_egp": 0.0,
                    "status": "Returned Empty",
                    "eir_number": "EIR-CMA-901",
                }
            ],
            exchange_rate=50.0,
            is_active=True,
        )
        db_session.add(tracking)
        db_session.commit()

        # 3. Trigger sync
        synced = sync_containers_from_file_service(db_session, file_id, user="sync_agent")
        assert len(synced) == 2

        c1 = next(c for c in synced if c.container_number == "CMAU1122334")
        assert c1.seal_number == "SL-111"
        assert c1.gate_out_date == date(2026, 9, 4)
        assert c1.empty_return_date == date(2026, 9, 10)
        assert c1.eir_number == "EIR-CMA-901"
        assert c1.status == "Returned Empty"

        c2 = next(c for c in synced if c.container_number == "CMAU5566778")
        assert c2.container_type == "20GP"
        assert c2.seal_number == "SL-222"

    def test_demurrage_recalculation_syncs_to_containers(self, db_session, sample_import_file):
        """Demurrage recalculation updates financial fields on linked ShipmentContainer entities"""
        file_id = sample_import_file.import_file_id

        # 1. Setup policy and container
        policy = DemurragePolicy(
            carrier_name="Maersk",
            container_type="40ft High Cube",
            demurrage_free_days=14,
            detention_free_days=7,
            port_storage_free_days=5,
            currency="USD",
            is_active=True,
        )
        db_session.add(policy)
        db_session.commit()

        container = create_container_service(
            db_session,
            ContainerCreate(
                container_number="MSKU8899001",
                container_type="40HC",
                import_file_id=file_id,
                discharge_date=date(2026, 9, 1),
            ),
        )

        tracking = DemurrageTracking(
            tracking_code="DND-2026-MSK",
            import_file_id=file_id,
            policy_id=policy.policy_id,
            carrier_name="Maersk",
            bill_of_lading_no="MSK123456",
            port_name="Alexandria Port",
            discharge_date=date(2026, 9, 1),
            containers=[
                {
                    "container_no": "MSKU8899001",
                    "container_type": "40ft High Cube",
                }
            ],
            exchange_rate=50.0,
            is_active=True,
        )
        db_session.add(tracking)
        db_session.commit()

        # 2. Recalculate tracking with gate_out after 10 days and empty return after 20 days
        req = DemurrageTrackingUpdate(
            gate_out_date=date(2026, 9, 11),
            empty_return_date=date(2026, 9, 21),
            exchange_rate=50.0,
        )
        recalculate_and_update_tracking_service(db_session, tracking.tracking_id, req, user="demurrage_officer")

        # 3. Refresh container and check sync
        db_session.refresh(container)
        assert container.demurrage_tracking_id == tracking.tracking_id
        assert container.gate_out_date == date(2026, 9, 11)
        assert container.empty_return_date == date(2026, 9, 21)
        assert container.storage_days > 0  # 10 days port stay > 5 free days

    def test_soft_delete_container(self, db_session, sample_import_file):
        """Soft delete marks container is_active=False"""
        c = create_container_service(
            db_session,
            ContainerCreate(
                container_number="TGHU1122334",
                container_type="20GP",
                import_file_id=sample_import_file.import_file_id,
            ),
        )
        deleted = delete_container_service(db_session, c.container_id, user="admin")
        assert deleted.is_active is False

        # Attempt to get should 404
        with pytest.raises(HTTPException) as exc:
            get_container_by_id_service(db_session, c.container_id)
        assert exc.value.status_code == 404


class TestContainersAPIEndpoints:

    def test_create_and_query_container_api(self, client, sample_import_file):
        """Tests POST, GET list, and GET by ID endpoints"""
        file_id = sample_import_file.import_file_id

        # 1. POST /api/v1/containers/
        resp = client.post(
            "/api/v1/containers/",
            json={
                "container_number": "MEDU9988776",
                "container_type": "40HC",
                "seal_number": "SL-9988",
                "import_file_id": file_id,
                "carrier_name": "MSC",
                "gross_weight_kg": 26000.0,
            },
        )
        assert resp.status_code == 201
        data = resp.json()
        container_id = data["container_id"]
        assert data["container_number"] == "MEDU9988776"

        # 2. GET /api/v1/containers/
        list_resp = client.get(f"/api/v1/containers/?import_file_id={file_id}")
        assert list_resp.status_code == 200
        list_data = list_resp.json()
        assert list_data["total"] >= 1
        assert any(item["container_number"] == "MEDU9988776" for item in list_data["items"])

        # 3. GET /api/v1/containers/{id}
        get_resp = client.get(f"/api/v1/containers/{container_id}")
        assert get_resp.status_code == 200
        assert get_resp.json()["container_id"] == container_id

        # 4. POST /api/v1/containers/{id}/gate-out
        go_resp = client.post(
            f"/api/v1/containers/{container_id}/gate-out",
            json={
                "gate_out_date": "2026-09-08",
                "truck_plate_number": "د ق ط 1122",
                "driver_name": "أحمد حسن",
            },
        )
        assert go_resp.status_code == 200
        assert go_resp.json()["status"] == "Gate Out"

        # 5. POST /api/v1/containers/{id}/return-empty
        ret_resp = client.post(
            f"/api/v1/containers/{container_id}/return-empty",
            json={
                "empty_return_date": "2026-09-14",
                "eir_number": "EIR-2026-MEDU",
                "depot_name": "ساحة كنج مريوط",
            },
        )
        assert ret_resp.status_code == 200
        assert ret_resp.json()["status"] == "Returned Empty"
        assert ret_resp.json()["eir_number"] == "EIR-2026-MEDU"

        # 6. DELETE /api/v1/containers/{id}
        del_resp = client.delete(f"/api/v1/containers/{container_id}")
        assert del_resp.status_code == 200
        assert del_resp.json()["is_active"] is False
