import pytest
from datetime import date, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

import main  # Ensures all models and routers are registered
from database.database import Base, get_db
from modules.demurrage_detention.schemas import (
    DemurrageSimulationRequest,
    DemurragePolicyCreate,
    DemurragePolicyUpdate,
    DemurrageTrackingCreate,
    DemurrageTrackingUpdate,
    ContainerItemInput,
    PushToSettlementRequest,
    TierRateItem,
)
from modules.demurrage_detention.service import (
    simulate_demurrage_and_detention,
    create_demurrage_policy_service,
    get_demurrage_policies_service,
    update_demurrage_policy_service,
    delete_demurrage_policy_service,
    create_demurrage_tracking_service,
    get_demurrage_trackings_service,
    recalculate_and_update_tracking_service,
    push_demurrage_to_financial_settlement_service,
    calculate_tiered_fee,
)
from modules.import_files.model import ImportFile


# Test database setup
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


class TestDemurrageDetentionEngine:
    def test_tiered_fee_calculation(self):
        tiers = [
            {"from_day": 1, "to_day": 7, "rate_per_day": 40.0},
            {"from_day": 8, "to_day": 14, "rate_per_day": 70.0},
            {"from_day": 15, "to_day": None, "rate_per_day": 120.0},
        ]
        # Case 1: 0 overdue days
        res0 = calculate_tiered_fee(0, tiers)
        assert res0["total_fee"] == 0.0

        # Case 2: 5 overdue days (all in tier 1: 5 * 40 = 200)
        res5 = calculate_tiered_fee(5, tiers)
        assert res5["total_fee"] == 200.0

        # Case 3: 10 overdue days (7 * 40 = 280 + 3 * 70 = 210 -> 490)
        res10 = calculate_tiered_fee(10, tiers)
        assert res10["total_fee"] == 490.0

        # Case 4: 16 overdue days (7*40=280 + 7*70=490 + 2*120=240 -> 1010)
        res16 = calculate_tiered_fee(16, tiers)
        assert res16["total_fee"] == 1010.0

    def test_simulation_safe_free_time(self):
        discharge = date.today() - timedelta(days=5)
        sim = simulate_demurrage_and_detention(DemurrageSimulationRequest(
            carrier_name="MSC",
            container_type="40ft High Cube",
            containers_count=2,
            demurrage_free_days=14,
            discharge_date=discharge,
            calculation_date=date.today(),
            currency="USD",
            exchange_rate=50.0,
        ))
        assert sim.demurrage_days_consumed == 5
        assert sim.demurrage_days_overdue == 0
        assert sim.demurrage_fee_fx == 0.0
        assert sim.status_badge == "SAFE"
        assert "فترة السماح سارية" in sim.countdown_summary_ar

    def test_simulation_warning_imminent(self):
        discharge = date.today() - timedelta(days=12)
        sim = simulate_demurrage_and_detention(DemurrageSimulationRequest(
            carrier_name="Maersk",
            container_type="40ft High Cube",
            containers_count=1,
            demurrage_free_days=14,
            discharge_date=discharge,
            calculation_date=date.today(),
            exchange_rate=50.0,  # DD-02: no default FX rate any more
        ))
        assert sim.demurrage_days_consumed == 12
        assert sim.demurrage_days_overdue == 0
        assert sim.status_badge == "WARNING"
        assert "تحذير: متبقي 2 أيام" in sim.countdown_summary_ar

    def test_simulation_demurrage_and_detention_incurred(self):
        discharge = date(2026, 8, 1)
        gate_out = date(2026, 8, 20)  # 19 days in port (14 free -> 5 overdue)
        empty_return = date(2026, 9, 2)  # 13 days out of port (7 free -> 6 overdue)

        sim = simulate_demurrage_and_detention(DemurrageSimulationRequest(
            carrier_name="CMA CGM",
            container_type="40ft Standard",
            containers_count=1,
            demurrage_free_days=14,
            detention_free_days=7,
            port_storage_free_days=5,
            port_storage_daily_rate_egp=300.0,
            discharge_date=discharge,
            gate_out_date=gate_out,
            empty_return_date=empty_return,
            currency="USD",
            exchange_rate=50.0,
        ))

        assert sim.demurrage_days_overdue == 5
        # Demurrage 5 days @ $40 = $200
        assert sim.demurrage_fee_fx == 200.0

        assert sim.detention_days_overdue == 6
        # Detention 6 days @ $35 = $210
        assert sim.detention_fee_fx == 210.0

        # Port storage: 19 - 5 = 14 overdue days @ 300 = 4200 EGP
        assert sim.storage_days_overdue == 14
        assert sim.storage_fee_egp == 4200.0

        # Total FX = 200 + 210 = 410 USD
        assert sim.total_fee_fx == 410.0
        # Total EGP = (410 * 50) + 4200 = 20500 + 4200 = 24700 EGP
        assert sim.total_cost_egp == 24700.0
        assert sim.status_badge == "DEMURRAGE_AND_DETENTION_INCURRED"

    def test_policy_crud(self, db_session):
        policy_in = DemurragePolicyCreate(
            carrier_name="Hapag-Lloyd",
            container_type="40ft High Cube",
            demurrage_free_days=21,
            detention_free_days=10,
            port_storage_free_days=7,
            currency="EUR",
            port_storage_daily_rate_egp=200.0,
            demurrage_tiers=[
                TierRateItem(from_day=1, to_day=7, rate_per_day=50.0),
                TierRateItem(from_day=8, to_day=None, rate_per_day=90.0),
            ],
            detention_tiers=[
                TierRateItem(from_day=1, to_day=7, rate_per_day=45.0),
                TierRateItem(from_day=8, to_day=None, rate_per_day=85.0),
            ],
            notes="Special negotiated contract",
        )
        created = create_demurrage_policy_service(db_session, policy_in, user="Auditor")
        assert created.policy_id is not None
        assert created.demurrage_free_days == 21

        policies, _ = get_demurrage_policies_service(db_session, carrier_name="Hapag")
        assert len(policies) == 1

        updated = update_demurrage_policy_service(
            db_session, created.policy_id, DemurragePolicyUpdate(demurrage_free_days=25)
        )
        assert updated.demurrage_free_days == 25

        delete_demurrage_policy_service(db_session, created.policy_id)
        remaining, _ = get_demurrage_policies_service(db_session)
        assert len(remaining) == 0

    def test_tracking_lifecycle_and_settlement_integration(self, db_session):
        # 1. Create a dummy import file
        import_file = ImportFile(
            import_file_code="IMP-2026-9001",
            company_name="El-Nasr Import Co",
            supplier_name="Global Steel Exporter",
            current_stage="Customs Clearance",
            status="In Progress",
            created_by="Tester",
        )
        db_session.add(import_file)
        db_session.commit()
        db_session.refresh(import_file)

        # 2. Create tracking session
        discharge = date(2026, 8, 1)
        gate_out = date(2026, 8, 20) # 19 days -> 5 overdue
        empty_return = date(2026, 8, 30) # 10 days -> 3 overdue

        track_in = DemurrageTrackingCreate(
            import_file_id=import_file.import_file_id,
            import_file_code=import_file.import_file_code,
            carrier_name="MSC",
            bill_of_lading_no="MEDUST123456",
            port_name="Alexandria Port",
            discharge_date=discharge,
            gate_out_date=gate_out,
            empty_return_date=empty_return,
            containers=[
                ContainerItemInput(container_no="MSCU1111111", container_type="40ft High Cube"),
                ContainerItemInput(container_no="MSCU2222222", container_type="40ft High Cube"),
            ],
            currency="USD",
            exchange_rate=50.0,
            notes="Two containers discharged",
        )
        tracking = create_demurrage_tracking_service(db_session, track_in, user="Kamal")
        assert tracking.tracking_id is not None
        assert len(tracking.containers) == 2
        assert tracking.total_demurrage_fx > 0
        assert tracking.total_detention_fx > 0

        # 3. Recalculate tracking with modified gate_out
        new_gate_out = date(2026, 8, 18)
        recalculated = recalculate_and_update_tracking_service(
            db_session, tracking.tracking_id, DemurrageTrackingUpdate(gate_out_date=new_gate_out)
        )
        assert recalculated.gate_out_date == new_gate_out

        # 4. Push to financial settlement
        push_res = push_demurrage_to_financial_settlement_service(
            db_session, PushToSettlementRequest(tracking_id=tracking.tracking_id, import_file_id=import_file.import_file_id)
        )
        assert push_res["success"] is True
        assert push_res["settlement_id"] is not None

        # Verify tracking updated status
        db_session.refresh(tracking)
        assert tracking.is_pushed_to_settlement is True
        assert tracking.status == "Pushed to Settlement"

    def test_api_endpoints(self, client, db_session):
        # Simulate endpoint
        resp = client.post("/api/v1/demurrage-detention/simulate", json={
            "carrier_name": "COSCO",
            "container_type": "20ft Standard",
            "containers_count": 1,
            "demurrage_free_days": 14,
            "discharge_date": str(date.today() - timedelta(days=20)),
            "calculation_date": str(date.today()),
            "currency": "USD",
            "exchange_rate": 50.0,
        })
        assert resp.status_code == 200
        data = resp.json()
        assert data["demurrage_days_overdue"] == 6
        assert data["status_badge"] == "DEMURRAGE_INCURRED"
