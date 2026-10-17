import pytest
from datetime import date, timedelta
from unittest.mock import patch
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

import main
from database.database import Base, get_db
from modules.auth.router import get_current_user
from modules.users.model import User
from modules.import_files.model import ImportFile
from modules.shipment_updates.model import ShipmentUpdateLog
from modules.demurrage_detention.model import DemurragePolicy, DemurrageTracking
from modules.demurrage_detention.service import get_containers_radar_overview_service
import modules.demurrage_detention.service as demurrage_service


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

    test_user = User(
        user_id=1,
        username="test_admin",
        full_name="Test Admin",
        role="Admin",
        is_active=True,
    )

    def override_get_current_user():
        return test_user

    main.app.dependency_overrides[get_db] = override_get_db
    main.app.dependency_overrides[get_current_user] = override_get_current_user
    with TestClient(main.app) as c:
        yield c
    main.app.dependency_overrides.clear()


class TestBE45Paging2AndRadar:

    def test_shipment_updates_paging_defaults_and_limits(self, db_session, client):
        # Insert 250 update logs
        logs = [
            ShipmentUpdateLog(
                update_code=f"UPD-2026-{i:05d}",
                import_file_id=1,
                import_file_code=f"IMP-2026-{i:05d}",
                update_category="Daily Check-in",
                target_phase="Phase 4",
                phase_status="In Progress",
                log_date="2026-08-15",
                note=f"Update note {i}",
                created_by="system",
                is_active=True,
            )
            for i in range(1, 251)
        ]
        db_session.bulk_save_objects(logs)
        db_session.commit()

        # 1. Default limit (200)
        res = client.get("/api/v1/shipment-updates")
        assert res.status_code == 200
        data = res.json()
        assert len(data) == 200
        assert res.headers.get("X-Total-Count") == "250"

        # 2. skip=200 -> remaining 50
        res = client.get("/api/v1/shipment-updates?skip=200")
        assert res.status_code == 200
        data = res.json()
        assert len(data) == 50
        assert res.headers.get("X-Total-Count") == "250"

        # 3. Custom skip and limit
        res = client.get("/api/v1/shipment-updates?skip=10&limit=15")
        assert res.status_code == 200
        data = res.json()
        assert len(data) == 15
        assert res.headers.get("X-Total-Count") == "250"

        # 4. Bounds validation
        assert client.get("/api/v1/shipment-updates?skip=-1").status_code == 422
        assert client.get("/api/v1/shipment-updates?limit=0").status_code == 422
        assert client.get("/api/v1/shipment-updates?limit=501").status_code == 422

    def test_demurrage_policies_paging(self, db_session, client):
        # Insert 250 policies
        policies = [
            DemurragePolicy(
                carrier_name=f"Carrier {i}",
                container_type="40ft High Cube",
                demurrage_free_days=14,
                detention_free_days=7,
                port_storage_free_days=5,
                port_storage_daily_rate_egp=250.0,
                currency="USD",
                created_by="system",
                is_active=True,
            )
            for i in range(1, 251)
        ]
        db_session.bulk_save_objects(policies)
        db_session.commit()

        # 1. Default limit (200)
        res = client.get("/api/v1/demurrage-detention/policies")
        assert res.status_code == 200
        data = res.json()
        assert len(data) == 200
        assert res.headers.get("X-Total-Count") == "250"

        # 2. skip=200 -> 50
        res = client.get("/api/v1/demurrage-detention/policies?skip=200")
        assert res.status_code == 200
        data = res.json()
        assert len(data) == 50
        assert res.headers.get("X-Total-Count") == "250"

        # 3. Bounds validation
        assert client.get("/api/v1/demurrage-detention/policies?skip=-1").status_code == 422
        assert client.get("/api/v1/demurrage-detention/policies?limit=0").status_code == 422
        assert client.get("/api/v1/demurrage-detention/policies?limit=501").status_code == 422

    def test_demurrage_trackings_paging(self, db_session, client):
        today = date.today()
        # Insert 250 trackings
        trackings = [
            DemurrageTracking(
                tracking_code=f"DND-2026-{i:04d}",
                import_file_id=1,
                carrier_name="MSC",
                bill_of_lading_no=f"BL{i}",
                port_name="Alexandria Port",
                discharge_date=today,
                currency="USD",
                exchange_rate=50.0,
                status="Free Time Active",
                created_by="system",
                is_active=True,
            )
            for i in range(1, 251)
        ]
        db_session.bulk_save_objects(trackings)
        db_session.commit()

        # 1. Default limit (200)
        res = client.get("/api/v1/demurrage-detention/trackings")
        assert res.status_code == 200
        data = res.json()
        assert len(data) == 200
        assert res.headers.get("X-Total-Count") == "250"

        # 2. skip=200 -> 50
        res = client.get("/api/v1/demurrage-detention/trackings?skip=200")
        assert res.status_code == 200
        data = res.json()
        assert len(data) == 50
        assert res.headers.get("X-Total-Count") == "250"

        # 3. Bounds validation
        assert client.get("/api/v1/demurrage-detention/trackings?skip=-1").status_code == 422
        assert client.get("/api/v1/demurrage-detention/trackings?limit=0").status_code == 422
        assert client.get("/api/v1/demurrage-detention/trackings?limit=501").status_code == 422

    def test_radar_filter_excludes_returned_and_closed(self, db_session):
        today = date.today()
        imp_file = ImportFile(
            import_file_id=1,
            import_file_code="IMP-2026-0001",
            company_name="Test Company",
            supplier_name="Test Supplier",
            is_active=True,
        )
        db_session.add(imp_file)
        db_session.commit()

        t_active = DemurrageTracking(
            tracking_code="DND-2026-0001",
            import_file_id=1,
            carrier_name="MSC",
            bill_of_lading_no="BL1",
            discharge_date=today - timedelta(days=2),
            currency="USD",
            exchange_rate=50.0,
            status="Free Time Active",
            is_active=True,
        )
        t_none_status = DemurrageTracking(
            tracking_code="DND-2026-0002",
            import_file_id=1,
            carrier_name="Maersk",
            bill_of_lading_no="BL2",
            discharge_date=today - timedelta(days=2),
            currency="USD",
            exchange_rate=50.0,
            status=None,
            is_active=True,
        )
        t_returned = DemurrageTracking(
            tracking_code="DND-2026-0003",
            import_file_id=1,
            carrier_name="CMA",
            bill_of_lading_no="BL3",
            discharge_date=today - timedelta(days=10),
            currency="USD",
            exchange_rate=50.0,
            status="All Containers Returned",
            is_active=True,
        )
        t_closed = DemurrageTracking(
            tracking_code="DND-2026-0004",
            import_file_id=1,
            carrier_name="Hapag",
            bill_of_lading_no="BL4",
            discharge_date=today - timedelta(days=10),
            currency="USD",
            exchange_rate=50.0,
            status="Closed",
            is_active=True,
        )
        db_session.add_all([t_active, t_none_status, t_returned, t_closed])
        db_session.commit()

        overview = get_containers_radar_overview_service(db_session)
        tracked_codes = [item.bill_of_lading_no for item in overview.radar_items]

        # BL1 and BL2 are active/None status -> included
        assert "BL1" in tracked_codes
        assert "BL2" in tracked_codes
        # BL3 (All Containers Returned) and BL4 (Closed) -> excluded
        assert "BL3" not in tracked_codes
        assert "BL4" not in tracked_codes
        assert overview.total_containers_tracked == 2

    def test_radar_system_parameter_calls_cached_once(self, db_session):
        today = date.today()
        imp_file = ImportFile(
            import_file_id=1,
            import_file_code="IMP-2026-0001",
            company_name="Test Company",
            supplier_name="Test Supplier",
            is_active=True,
        )
        db_session.add(imp_file)
        db_session.commit()

        # Create 5 active trackings
        for i in range(1, 6):
            t = DemurrageTracking(
                tracking_code=f"DND-2026-{i:04d}",
                import_file_id=1,
                carrier_name=f"Carrier {i}",
                bill_of_lading_no=f"BL-{i}",
                discharge_date=today - timedelta(days=2),
                currency="USD",
                exchange_rate=50.0,
                status="Free Time Active",
                is_active=True,
            )
            db_session.add(t)
        db_session.commit()

        call_count = 0
        import modules.common.system_parameters as sys_params
        real_get_parameter = sys_params.get_parameter

        def counting_get_parameter(*args, **kwargs):
            nonlocal call_count
            call_count += 1
            return real_get_parameter(*args, **kwargs)

        with patch("modules.common.system_parameters.get_parameter", side_effect=counting_get_parameter), \
             patch("modules.demurrage_detention.service.get_parameter", side_effect=counting_get_parameter):
            overview = get_containers_radar_overview_service(db_session)
            assert overview.total_containers_tracked == 5

            # System parameters should be queried once per request (default_tariff),
            # never repeated per tracking (which would have been 5 * 6 = 30 calls)
            assert call_count <= 8
            initial_count = call_count

            # Add 5 more trackings and verify that call count remains constant per request
            for j in range(6, 11):
                t2 = DemurrageTracking(
                    tracking_code=f"DND-2026-{j:04d}",
                    import_file_id=1,
                    carrier_name=f"Carrier {j}",
                    bill_of_lading_no=f"BL-{j}",
                    discharge_date=today - timedelta(days=2),
                    currency="USD",
                    exchange_rate=50.0,
                    status="Free Time Active",
                    is_active=True,
                )
                db_session.add(t2)
            db_session.commit()

            call_count = 0
            overview2 = get_containers_radar_overview_service(db_session)
            assert overview2.total_containers_tracked == 10
            # Call count with 10 trackings must be identical to call count with 5 trackings!
            assert call_count == initial_count
            assert call_count <= 8
