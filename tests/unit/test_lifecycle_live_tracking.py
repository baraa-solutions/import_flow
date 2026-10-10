"""
Unit Tests for Lifecycle Board: No Invented Data & Bounded Live Tracking (BEX-T03).

Acceptance Criteria:
1. An active file with no booking, no demurrage record and target_free_days=NULL
   produces a LiveLogisticsTrackingItem with:
   - carrier_name=None, vessel_name=None, pol_name=None, pod_name=None
   - shipment_mode=None, incoterm_code=None, priority=None
   - demurrage_risk_level="Unknown", free_days_total=None, free_days_remaining=None
   - not counted in high_risk_demurrage_count.
2. GET /summary on an empty activity table creates 0 rows (GET does not write).
3. Live tracking pre-fetches are bounded to active files only (import_file_id IN (active_ids)).
4. ShipmentStageCard preserves raw null values for shipment_mode, incoterm_code,
   priority, estimated_cost, and estimated_cost_currency without fabricated defaults.
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main
import modules.auth.permissions as auth_permissions
from database.database import Base, get_db
from modules.auth.permissions import invalidate_permission_cache
from modules.auth.security import create_access_token, hash_password
from modules.auth.seed_rbac import seed_rbac
from modules.cargo_shipping.model import CargoShippingRecord
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.demurrage_detention.model import DemurrageTracking
from modules.freight_booking.model import ShipmentBooking
from modules.import_files.model import ImportFile
from modules.lifecycle_board.model import ShipmentStageActivity
import modules.lifecycle_board.service as service
from modules.users.model import Role, User


@pytest.fixture
def test_db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(bind=engine)()
    seed_rbac(session)
    invalidate_permission_cache()
    yield session
    session.close()


@pytest.fixture
def client(test_db):
    app = main.app

    def override_get_db():
        try:
            yield test_db
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()


def _create_user(db, username: str, role_code: str) -> User:
    role = db.query(Role).filter(Role.role_code == role_code).one()
    user = User(
        username=username,
        email=f"{username}@sorourlogistics.com",
        full_name=f"Test {username}",
        hashed_password=hash_password("Secret123!"),
        role=role_code,
        role_id=role.role_id,
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _auth_headers(user: User) -> dict:
    token = create_access_token({"sub": str(user.user_id), "role": user.role})
    return {"Authorization": f"Bearer {token}"}


def test_no_invented_data_on_minimal_file(test_db):
    """
    Active file with no booking, no demurrage, target_free_days=None, and no ports
    must yield None for carrier, vessel, ports, and risk level 'Unknown'.
    """
    f = ImportFile(
        import_file_code="IMP-2026-MIN01",
        company_name="Min Co",
        supplier_name="Min Supp",
        is_active=True,
    )
    test_db.add(f)
    test_db.commit()

    # Clear nullable ports and target free days to test files with no port data
    test_db.query(ImportFile).filter(ImportFile.import_file_id == f.import_file_id).update({
        ImportFile.port_of_loading: None,
        ImportFile.port_of_discharge: None,
        ImportFile.target_free_days: None,
    })
    test_db.commit()
    test_db.refresh(f)

    res = service.get_live_logistics_tracking_service(test_db)
    assert res.total_active_shipments == 1
    assert res.high_risk_demurrage_count == 0

    item = res.items[0]
    assert item.carrier_name is None
    assert item.vessel_name is None
    assert item.pol_name is None
    assert item.pod_name is None
    assert item.demurrage_risk_level == "Unknown"
    assert item.free_days_total is None
    assert item.free_days_remaining is None
    assert item.demurrage_status == "No Active Session"
    assert item.used_free_days == 0
    assert item.accumulated_demurrage_fx == 0.0
    assert item.accumulated_demurrage_egp == 0.0


def test_get_summary_does_not_write_to_db(test_db, client):
    """
    GET /summary on an empty activity table must NOT write any fabricated
    STEP_0n activities (HTTP GET idempotence / read safety).
    """
    # Create 3 active import files
    for i in range(1, 4):
        test_db.add(
            ImportFile(
                import_file_code=f"IMP-2026-EMPTY{i}",
                company_name=f"Co {i}",
                supplier_name=f"Supp {i}",
                is_active=True,
            )
        )
    test_db.commit()

    assert test_db.query(ShipmentStageActivity).count() == 0

    # 1. Direct service call
    summary = service.get_board_summary_service(test_db)
    assert summary.total_active_files == 0
    assert len(summary.all_shipments) == 0
    assert test_db.query(ShipmentStageActivity).count() == 0

    # 2. HTTP GET call
    user = _create_user(test_db, "ops_user", "LOGISTICS_OPERATOR")
    headers = _auth_headers(user)
    response = client.get("/api/v1/lifecycle-board/summary", headers=headers)
    assert response.status_code == 200
    assert test_db.query(ShipmentStageActivity).count() == 0


def test_bounded_queries_filter_by_active_files_only(test_db):
    """
    With 3 files (1 active, 2 inactive) and 3 bookings, the queries for
    bookings, cargo, and demurrage must be filtered to active_ids only.
    """
    active_file = ImportFile(
        import_file_code="IMP-2026-ACT01",
        company_name="Active Co",
        supplier_name="Active Supp",
        is_active=True,
        target_free_days=21,
    )
    inactive_file1 = ImportFile(
        import_file_code="IMP-2026-INACT01",
        company_name="Inactive Co 1",
        supplier_name="Inactive Supp 1",
        is_active=False,
    )
    inactive_file2 = ImportFile(
        import_file_code="IMP-2026-INACT02",
        company_name="Inactive Co 2",
        supplier_name="Inactive Supp 2",
        is_active=False,
    )
    test_db.add_all([active_file, inactive_file1, inactive_file2])
    test_db.commit()

    # Add bookings for all 3 files
    b_active = ShipmentBooking(
        booking_code="BKG-ACT-01",
        import_file_id=active_file.import_file_id,
        shipping_line_name="CMA CGM",
        vessel_name="CMA Jacques Saade",
        free_demurrage_days=21,
    )
    b_inact1 = ShipmentBooking(
        booking_code="BKG-INACT-01",
        import_file_id=inactive_file1.import_file_id,
        shipping_line_name="Ghost Carrier 1",
        vessel_name="Ghost Vessel 1",
    )
    b_inact2 = ShipmentBooking(
        booking_code="BKG-INACT-02",
        import_file_id=inactive_file2.import_file_id,
        shipping_line_name="Ghost Carrier 2",
        vessel_name="Ghost Vessel 2",
    )
    test_db.add_all([b_active, b_inact1, b_inact2])
    test_db.commit()

    executed_queries = []

    def capture_queries(conn, cursor, statement, parameters, context, executemany):
        executed_queries.append((statement, parameters))

    engine = test_db.get_bind()
    event.listen(engine, "before_cursor_execute", capture_queries)
    try:
        res = service.get_live_logistics_tracking_service(test_db)
    finally:
        event.remove(engine, "before_cursor_execute", capture_queries)

    # Verify results
    assert res.total_active_shipments == 1
    item = res.items[0]
    assert item.import_file_code == "IMP-2026-ACT01"
    assert item.carrier_name == "CMA CGM"
    assert item.vessel_name == "CMA Jacques Saade"

    # Verify that the booking query had the active ID in its filter and excluded inactive ones
    booking_queries = [
        (q, p) for q, p in executed_queries
        if "shipment_bookings" in q.lower()
    ]
    assert len(booking_queries) >= 1
    for q, p in booking_queries:
        q_lower = q.lower()
        assert "where" in q_lower, f"Booking query has no WHERE clause: {q}"
        assert "import_file_id in" in q_lower or "import_file_id =" in q_lower, (
            f"Booking query does not filter on import_file_id: {q}"
        )

    all_booking_params = []
    for q, p in booking_queries:
        if isinstance(p, (list, tuple)):
            all_booking_params.extend(p)
        elif isinstance(p, dict):
            all_booking_params.extend(p.values())

    assert active_file.import_file_id in all_booking_params
    assert inactive_file1.import_file_id not in all_booking_params
    assert inactive_file2.import_file_id not in all_booking_params


def test_stage_card_raw_values_without_fabricated_defaults(test_db, monkeypatch):
    """
    ShipmentStageCard in get_board_summary_service must return raw nulls
    for shipment_mode, incoterm_code, priority, estimated_cost, and currency
    when not present on the file record.
    """
    from unittest.mock import MagicMock
    from modules.lifecycle_board.schemas import ShipmentStageCard

    # 1. Schema default check: schema fields default to None, not "Sea FCL" / "FOB" / "High" / 0.0 / "USD"
    card_raw = ShipmentStageCard(
        import_file_code="IMP-RAW",
        company_name="Co",
        supplier_name="Supp",
        step_code="STEP_01",
        step_name_en="Step 1",
        step_name_ar="المرحلة 1",
        status="In-Progress",
    )
    assert card_raw.shipment_mode is None
    assert card_raw.incoterm_code is None
    assert card_raw.priority is None
    assert card_raw.estimated_cost is None
    assert card_raw.estimated_cost_currency is None

    # 2. Service pass-through check: get_board_summary_service preserves None from file_rec
    mock_act = ShipmentStageActivity(
        import_file_code="IMP-MOCK-01",
        step_code="STEP_01",
        status="In-Progress",
        started_at="2026-10-08 10:00:00",
    )
    mock_file = MagicMock()
    mock_file.import_file_code = "IMP-MOCK-01"
    mock_file.company_name = "Mock Co"
    mock_file.supplier_name = "Mock Supp"
    mock_file.po_number = None
    mock_file.shipment_mode = None
    mock_file.incoterm_code = None
    mock_file.priority = None
    mock_file.estimated_cost = None
    mock_file.estimated_cost_currency = None

    monkeypatch.setattr(
        service.repo,
        "get_active_shipments_with_details",
        lambda db: [(mock_act, mock_file)],
    )

    summary = service.get_board_summary_service(test_db)
    assert len(summary.all_shipments) == 1
    card = summary.all_shipments[0]

    assert card.shipment_mode is None
    assert card.incoterm_code is None
    assert card.priority is None
    assert card.estimated_cost is None
    assert card.estimated_cost_currency is None


def test_live_tracking_raw_values_without_fabricated_defaults(test_db, monkeypatch):
    """
    LiveLogisticsTrackingItem in get_live_logistics_tracking_service must return raw nulls
    for shipment_mode, incoterm_code, priority without fallback defaults.
    """
    from unittest.mock import MagicMock

    mock_file = MagicMock()
    mock_file.import_file_id = 999
    mock_file.import_file_code = "IMP-MOCK-LIVE"
    mock_file.company_name = "Mock Co"
    mock_file.supplier_name = "Mock Supp"
    mock_file.po_number = None
    mock_file.shipment_mode = None
    mock_file.incoterm_code = None
    mock_file.priority = None
    mock_file.required_eta = None
    mock_file.port_of_loading = None
    mock_file.port_of_discharge = None
    mock_file.target_free_days = None
    mock_file.selected_scenario = None
    mock_file.is_customs_released = False
    mock_file.custom_file_number = None
    mock_file.invoices_data = None
    mock_file.pi_number = None
    mock_file.packing_lists_data = None
    mock_file.acid_number = None
    mock_file.form4_no = None
    mock_file.form46_no = None
    mock_file.bl_number = None
    mock_file.vessel_name = None
    mock_file.initial_starting_step = "STEP_01"
    mock_file.next_action = None
    mock_file.next_action_code = None
    mock_file.next_action_params = None

    class MockQuery:
        def filter(self, *args, **kwargs):
            return self
        def all(self):
            return [mock_file]

    orig_query = test_db.query

    def mock_query_fn(model, *args, **kwargs):
        if model == ImportFile:
            return MockQuery()
        return orig_query(model, *args, **kwargs)

    monkeypatch.setattr(test_db, "query", mock_query_fn)

    res = service.get_live_logistics_tracking_service(test_db)
    assert res.total_active_shipments == 1
    item = res.items[0]

    assert item.shipment_mode is None
    assert item.incoterm_code is None
    assert item.priority is None
    assert item.carrier_name is None
    assert item.vessel_name is None
    assert item.pol_name is None
    assert item.pod_name is None
    assert item.demurrage_risk_level == "Unknown"
    assert item.free_days_total is None
    assert item.free_days_remaining is None
