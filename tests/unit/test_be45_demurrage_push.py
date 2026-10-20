"""
Unit tests for BE45-T02:
Recalculate before pushing demurrage, live dual clock, and is_provisional in push response.
"""
from datetime import date, datetime
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.auth.seed_rbac import seed_rbac
from modules.users.model import User, Role, Permission, RolePermission
from modules.import_files.model import ImportFile
import modules.inland_transport.model  # noqa: F401
from modules.financial_settlement.model import LandedCostSettlementRecord
from modules.financial_settlement.repository import get_settlement_by_import_file_id
from modules.demurrage_detention.model import DemurrageTracking
from modules.demurrage_detention.schemas import (
    DemurrageTrackingCreate,
    ContainerItemInput,
    PushToSettlementRequest,
)
import modules.demurrage_detention.service as dd


@pytest.fixture
def session_factory():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    yield sessionmaker(bind=engine, autoflush=False)
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


def _create_settle_user(db) -> User:
    role = Role(
        role_code="ROLE_SETTLE_USER",
        name_ar="Settle User",
        name_en="Settle User",
        is_active=True,
    )
    db.add(role)
    db.flush()

    for p_code in ["demurrage_detention.manage", "demurrage_detention.view", "financial_settlement.calculate"]:
        perm = db.query(Permission).filter(Permission.permission_code == p_code).first()
        if not perm:
            perm = Permission(permission_code=p_code, module_name="test", action="test", name_en=p_code, name_ar=p_code)
            db.add(perm)
            db.flush()
        rp = RolePermission(role_id=role.role_id, permission_id=perm.permission_id)
        db.add(rp)

    user = User(
        username="settle_user",
        email="settle_user@test.com",
        full_name="Settle User",
        hashed_password="pw",
        role=role.role_code,
        role_id=role.role_id,
        is_active=True,
    )
    db.add(user)
    db.commit()
    return user


def test_be45_t02_recalculate_before_push_and_dual_clock(db, monkeypatch):
    """
    Tracking: discharge 2026-09-01, 1 container 40HC, no policy (default tiers 40/70/120,
    5 free days demurrage, storage 7 free days at 250 EGP), rate 50.0.
    Created while today = 2026-09-01, so stored totals are 0.
    Push with today = 2026-09-21:
    - consumed 20, overdue 15, demurrage (7x40 + 7x70 + 1x120) = 890.00 USD; storage (20-7) x 250 = 3250.00 EGP.
    - Carrier row amount_fx 890.00 and amount_egp 44500.00. Storage row 3250.00.
    - is_provisional: True
    - Stored tracking totals in DB match fresh recalculation.
    - Dual clock status reflects live calculation.
    """
    actor = _create_settle_user(db)

    # 1. Freeze today to discharge date 2026-09-01 on creation
    monkeypatch.setattr(dd, "_today", lambda: date(2026, 9, 1))

    create_req = DemurrageTrackingCreate(
        import_file_id=1,
        bill_of_lading_no="BL-MSC-4501",
        carrier_name="MSC",
        port_name="Alexandria Port",
        discharge_date=date(2026, 9, 1),
        exchange_rate=50.0,
        containers=[
            ContainerItemInput(
                container_no="MSCU9876543",
                container_type="40HC",
            )
        ],
    )
    tracking = dd.create_demurrage_tracking_service(db, create_req, user="tester")

    # Stored totals right after creation on discharge date must be 0
    assert tracking.total_demurrage_fx == 0.0
    assert tracking.total_detention_fx == 0.0
    assert tracking.total_storage_egp == 0.0
    assert tracking.total_cost_egp == 0.0

    # 2. Advance time to 2026-09-21 (20 days after discharge)
    sim_date = date(2026, 9, 21)
    monkeypatch.setattr(dd, "_today", lambda: sim_date)

    # Test Dual Clock live recalculation: should show live numbers without DB mutation
    dual_clock = dd.get_dual_clock_status_service(db, tracking.tracking_id)
    assert dual_clock.carrier_clock.accrued_demurrage_fx == 890.0
    assert dual_clock.port_storage_clock.accrued_storage_egp == 3250.0
    assert dual_clock.carrier_clock.days_consumed == 20
    assert dual_clock.carrier_clock.days_remaining == 0
    assert dual_clock.carrier_clock.status == "OVERDUE_DEMURRAGE"
    assert dual_clock.port_storage_clock.status == "OVERDUE_STORAGE"

    # Tracking record in DB is still untouched (no commit happened yet)
    db.refresh(tracking)
    assert tracking.total_demurrage_fx == 0.0

    # 3. Push to settlement with today = 2026-09-21
    push_req = PushToSettlementRequest(
        tracking_id=tracking.tracking_id,
        import_file_id=1,
    )
    push_res = dd.push_demurrage_to_financial_settlement_service(db, push_req, user="tester", actor=actor)

    # Assert push response
    assert push_res["success"] is True
    assert push_res["is_provisional"] is True
    assert push_res["settlement_id"] is not None

    # Assert tracking totals in DB were refreshed by recalculation
    db.refresh(tracking)
    assert tracking.total_demurrage_fx == 890.00
    assert tracking.total_detention_fx == 0.00
    assert tracking.total_storage_egp == 3250.00
    assert tracking.total_cost_egp == round((890.00 * 50.0) + 3250.00, 2)  # 47750.00
    assert tracking.is_pushed_to_settlement is True

    # Assert settlement expense invoices written
    settlement = get_settlement_by_import_file_id(db, 1)
    assert settlement is not None
    invoices = settlement.expense_invoices
    assert len(invoices) == 2

    # Carrier charges
    carrier_row = next(i for i in invoices if i["currency"] == "USD")
    assert carrier_row["amount_fx"] == 890.00
    assert carrier_row["exchange_rate"] == 50.0
    assert carrier_row["amount_egp"] == 44500.00

    # Port storage
    storage_row = next(i for i in invoices if i["currency"] == "EGP")
    assert storage_row["amount_fx"] == 3250.00
    assert storage_row["exchange_rate"] == 1.0
    assert storage_row["amount_egp"] == 3250.00


def test_be45_t02_is_provisional_false_when_containers_returned(db, monkeypatch):
    """
    When all containers have an empty_return_date, the push is final (is_provisional = False).
    """
    actor = _create_settle_user(db)
    monkeypatch.setattr(dd, "_today", lambda: date(2026, 9, 21))

    create_req = DemurrageTrackingCreate(
        import_file_id=1,
        bill_of_lading_no="BL-MSC-4502",
        carrier_name="MSC",
        port_name="Alexandria Port",
        discharge_date=date(2026, 9, 1),
        gate_out_date=date(2026, 9, 10),
        empty_return_date=date(2026, 9, 15),
        exchange_rate=50.0,
        containers=[
            ContainerItemInput(
                container_no="MSCU1111111",
                container_type="40HC",
                free_days=14,
            )
        ],
    )
    tracking = dd.create_demurrage_tracking_service(db, create_req, user="tester")

    push_req = PushToSettlementRequest(
        tracking_id=tracking.tracking_id,
        import_file_id=1,
    )
    push_res = dd.push_demurrage_to_financial_settlement_service(db, push_req, user="tester", actor=actor)

    assert push_res["success"] is True
    assert push_res["is_provisional"] is False
