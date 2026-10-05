import pytest
from datetime import date, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

import main
from database.database import Base, get_db
from modules.demurrage_detention.schemas import (
    DemurragePolicyCreate,
    DemurrageTrackingCreate,
    ContainerItemInput,
    ContainerIndividualUpdate,
)
from modules.demurrage_detention.service import (
    create_demurrage_policy_service,
    create_demurrage_tracking_service,
    get_dual_clock_status_service,
    update_single_container_service,
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
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    main.app.dependency_overrides[get_db] = override_get_db
    test_client = TestClient(main.app)
    yield test_client
    main.app.dependency_overrides.clear()


class TestDualClockAndContainerLifecycle:
    """
    Tests for LOG-DUAL-001 (Dual Clock Radar) and LOG-CONT-002 (Container-Level Lifecycle).
    """

    def test_dual_clock_safe_and_critical_radar(self, db_session):
        # 1. Create Policy (14 days Carrier Demurrage, 5 days Port Storage)
        policy = create_demurrage_policy_service(
            db_session,
            DemurragePolicyCreate(
                carrier_name="Maersk",
                container_type="40ft High Cube",
                demurrage_free_days=14,
                detention_free_days=7,
                port_storage_free_days=5,
                port_storage_daily_rate_egp=300.0,
            ),
        )

        # 2. Tracking with discharge 3 days ago
        discharge = date.today() - timedelta(days=3)
        tracking = create_demurrage_tracking_service(
            db_session,
            DemurrageTrackingCreate(
                carrier_name="Maersk",
                bill_of_lading_no="MSK-DUAL-001",
                port_name="Alexandria Port",
                discharge_date=discharge,
                containers=[ContainerItemInput(container_no="MSKU1001", container_type="40ft High Cube")],
                currency="USD",
                exchange_rate=48.50,
            ),
        )

        # 3. Test Dual Clock Status
        dual_clock = get_dual_clock_status_service(db_session, tracking.tracking_id)
        assert dual_clock.carrier_clock.carrier_name == "Maersk"
        assert dual_clock.carrier_clock.free_days_allowed == 14
        assert dual_clock.carrier_clock.days_consumed == 3
        assert dual_clock.carrier_clock.days_remaining == 11
        assert dual_clock.carrier_clock.status == "SAFE"

        # Port clock: 3 days consumed of 5 days free -> Critical 72h alert active
        assert dual_clock.port_storage_clock.storage_free_days == 5
        assert dual_clock.port_storage_clock.days_consumed == 3
        assert dual_clock.port_storage_clock.days_remaining == 2
        assert dual_clock.port_storage_clock.is_critical_72h_warning is True
        assert dual_clock.port_storage_clock.status == "CRITICAL_72H_ALERT"
        assert dual_clock.overall_alert_level == "URGENT_STORAGE_72H"

    def test_individual_container_partial_gate_out_and_return(self, db_session):
        # 1. Create Policy
        create_demurrage_policy_service(
            db_session,
            DemurragePolicyCreate(
                carrier_name="CMA CGM",
                container_type="40ft High Cube",
                demurrage_free_days=14,
                detention_free_days=7,
                port_storage_free_days=5,
                port_storage_daily_rate_egp=250.0,
            ),
        )

        # 2. Tracking with 2 containers discharged 18 days ago
        discharge = date.today() - timedelta(days=18)
        tracking = create_demurrage_tracking_service(
            db_session,
            DemurrageTrackingCreate(
                carrier_name="CMA CGM",
                bill_of_lading_no="CMA-MULTI-002",
                port_name="El-Dekheila Port",
                discharge_date=discharge,
                containers=[
                    ContainerItemInput(container_no="CMAU1111", container_type="40ft High Cube"),
                    ContainerItemInput(container_no="CMAU2222", container_type="40ft High Cube"),
                ],
                currency="USD",
                exchange_rate=50.0,
            ),
        )

        # 3. Update Container 1: Gated out on Day 4 and returned empty on Day 8 (Within 14 free days)
        c1_gate_out = discharge + timedelta(days=4)
        c1_return = discharge + timedelta(days=8)
        updated_trk = update_single_container_service(
            db_session,
            tracking.tracking_id,
            "CMAU1111",
            ContainerIndividualUpdate(
                gate_out_date=c1_gate_out,
                empty_return_date=c1_return,
                eir_number="EIR-CMA-9901",
                seal_no="SEAL-001",
            ),
        )

        # Verify Container 1 has ZERO demurrage and ZERO storage fees
        c1_data = next(c for c in updated_trk.containers if c["container_no"] == "CMAU1111")
        assert c1_data["demurrage_fx"] == 0.0
        assert c1_data["storage_egp"] == 0.0
        assert c1_data["eir_number"] == "EIR-CMA-9901"
        assert c1_data["status"] == "Empty-Returned"

        # Verify Container 2 (still on port, 18 days passed) incurs demurrage (> 0)
        c2_data = next(c for c in updated_trk.containers if c["container_no"] == "CMAU2222")
        assert c2_data["demurrage_days"] == 4  # 18 - 14 free days
        assert c2_data["demurrage_fx"] > 0.0
        assert c2_data["storage_days"] == 13  # 18 - 5 free storage days
        assert c2_data["storage_egp"] > 0.0

    def test_dual_clock_and_container_endpoints(self, client, db_session):
        # Create test tracking
        discharge = date.today() - timedelta(days=2)
        tracking = create_demurrage_tracking_service(
            db_session,
            DemurrageTrackingCreate(
                carrier_name="Hapag-Lloyd",
                bill_of_lading_no="HAPAG-7788",
                port_name="Damietta Port",
                discharge_date=discharge,
                containers=[ContainerItemInput(container_no="HLXU9999", container_type="40ft High Cube")],
                # DD-09: no fabricated default rate since the review wave; without an explicit rate the
                # service needs a registered USD commercial rate (409 otherwise), so pass one here.
                currency="USD",
                exchange_rate=50.0,
            ),
        )

        # Test Dual Clock API
        resp_clock = client.get(f"/api/v1/demurrage-detention/trackings/{tracking.tracking_id}/dual-clock")
        assert resp_clock.status_code == 200
        clock_data = resp_clock.json()
        assert "carrier_clock" in clock_data
        assert "port_storage_clock" in clock_data
        assert clock_data["carrier_clock"]["free_days_allowed"] == 14
        assert clock_data["port_storage_clock"]["storage_free_days"] == 5

        # Test PATCH single container API
        patch_payload = {
            "seal_no": "SEAL-HL-77",
            "gate_out_date": date.today().isoformat(),
            "eir_number": "EIR-HL-001",
        }
        resp_patch = client.patch(
            f"/api/v1/demurrage-detention/trackings/{tracking.tracking_id}/containers/HLXU9999",
            json=patch_payload,
        )
        assert resp_patch.status_code == 200
        patch_data = resp_patch.json()
        c_item = next(c for c in patch_data["containers"] if c["container_no"] == "HLXU9999")
        assert c_item["seal_no"] == "SEAL-HL-77"
        assert c_item["eir_number"] == "EIR-HL-001"
        assert c_item["status"] == "Gated-Out"
