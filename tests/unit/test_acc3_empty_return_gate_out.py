"""
Unit tests for ACC3-T04:
No demurrage / storage after empty return; gate-out required:
- Create, PUT, and PATCH container reject empty_return_date without gate_out_date with 422.
- Legacy rows holding empty_return without gate-out cap demurrage and storage at return date.
- EIR recording requires gate-out date per container.
"""
from datetime import date, timedelta
import pytest
from fastapi import HTTPException, status
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.import_files.model import ImportFile
from modules.demurrage_detention.model import DemurrageTracking
from modules.demurrage_detention.schemas import (
    DemurrageSimulationRequest,
    DemurrageTrackingCreate,
    DemurrageTrackingUpdate,
    ContainerItemInput,
    ContainerIndividualUpdate,
    EmptyContainerReturnSubmit,
)
import modules.demurrage_detention.service as dd_service
from modules.demurrage_detention.validators import validate_demurrage_dates
from modules.common.clock import cairo_today


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
    imp_file = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        custom_file_number="6701068100",
        company_name="Egyptian Import Co",
        supplier_name="ABC China",
        owner="Kamal",
    )
    session.add(imp_file)
    session.commit()
    yield session
    session.close()


def test_validator_rejects_empty_return_without_gate_out():
    """Validator directly rejects empty_return_date without gate_out_date when require_gate_out_for_return is True."""
    today = cairo_today()
    discharge = today - timedelta(days=20)
    ret_date = today - timedelta(days=5)

    with pytest.raises(HTTPException) as exc:
        validate_demurrage_dates(
            discharge_date=discharge,
            gate_out_date=None,
            empty_return_date=ret_date,
            today=today,
            require_gate_out_for_return=True,
        )
    assert exc.value.status_code == status.HTTP_422_UNPROCESSABLE_CONTENT
    assert "لا يمكن تسجيل إعادة الحاوية الفارغة بدون تاريخ خروجها من الميناء (Gate-Out)." in exc.value.detail


def test_empty_return_without_gate_out_rejected_on_create(db):
    """Creating a tracking with empty_return_date but no gate_out_date raises 422."""
    today = cairo_today()
    discharge = today - timedelta(days=15)
    ret_date = today - timedelta(days=2)

    req = DemurrageTrackingCreate(
        import_file_id=1,
        carrier_name="MSC",
        bill_of_lading_no="MEDU12345678",
        port_name="Alexandria Port",
        discharge_date=discharge,
        gate_out_date=None,
        empty_return_date=ret_date,
        containers=[
            ContainerItemInput(container_no="MSCU1111111", container_type="40ft High Cube"),
        ],
        currency="USD",
        exchange_rate=50.0,
    )

    with pytest.raises(HTTPException) as exc:
        dd_service.create_demurrage_tracking_service(db, req, user="tester")
    assert exc.value.status_code == status.HTTP_422_UNPROCESSABLE_CONTENT
    assert "لا يمكن تسجيل إعادة الحاوية الفارغة بدون تاريخ خروجها من الميناء (Gate-Out)." in exc.value.detail


def test_empty_return_without_gate_out_rejected_on_update(db):
    """Updating a tracking with empty_return_date while gate_out_date is None raises 422."""
    today = cairo_today()
    discharge = today - timedelta(days=15)

    # Create tracking with only discharge date
    req = DemurrageTrackingCreate(
        import_file_id=1,
        carrier_name="MSC",
        bill_of_lading_no="MEDU12345678",
        port_name="Alexandria Port",
        discharge_date=discharge,
        containers=[
            ContainerItemInput(container_no="MSCU1111111", container_type="40ft High Cube"),
        ],
        currency="USD",
        exchange_rate=50.0,
    )
    tracking = dd_service.create_demurrage_tracking_service(db, req, user="tester")

    # Attempt PUT with empty_return_date without setting gate_out_date
    with pytest.raises(HTTPException) as exc:
        dd_service.recalculate_and_update_tracking_service(
            db,
            tracking.tracking_id,
            DemurrageTrackingUpdate(empty_return_date=today - timedelta(days=2)),
            user="tester",
        )
    assert exc.value.status_code == status.HTTP_422_UNPROCESSABLE_CONTENT
    assert "لا يمكن تسجيل إعادة الحاوية الفارغة بدون تاريخ خروجها من الميناء (Gate-Out)." in exc.value.detail


def test_empty_return_without_gate_out_rejected_on_patch_container(db):
    """Updating a single container with empty_return_date without gate-out raises 422."""
    today = cairo_today()
    discharge = today - timedelta(days=15)

    req = DemurrageTrackingCreate(
        import_file_id=1,
        carrier_name="MSC",
        bill_of_lading_no="MEDU12345678",
        port_name="Alexandria Port",
        discharge_date=discharge,
        containers=[
            ContainerItemInput(container_no="MSCU1111111", container_type="40ft High Cube"),
        ],
        currency="USD",
        exchange_rate=50.0,
    )
    tracking = dd_service.create_demurrage_tracking_service(db, req, user="tester")

    # Attempt PATCH single container with empty_return_date without gate_out_date
    with pytest.raises(HTTPException) as exc:
        dd_service.update_single_container_service(
            db,
            tracking.tracking_id,
            "MSCU1111111",
            ContainerIndividualUpdate(empty_return_date=today - timedelta(days=1)),
            user="tester",
        )
    assert exc.value.status_code == status.HTTP_422_UNPROCESSABLE_CONTENT
    assert "لا يمكن تسجيل إعادة الحاوية الفارغة بدون تاريخ خروجها من الميناء (Gate-Out)." in exc.value.detail


def test_legacy_return_caps_demurrage_and_storage():
    """
    Acceptance criteria worked example:
    Legacy row with discharge 2026-09-01, return 2026-09-10, calc 2026-10-06, no gate-out:
    - Demurrage days consumed = 9, overdue = 0, demurrage_fee_fx = 0.0.
    - Storage days consumed = 9, overdue = 4 (free 5), storage 4 x 250 = 1,000.00 EGP.
    With gate-out 2026-09-08:
    - Storage days consumed = 7, overdue = 2, storage 2 x 250 = 500.00 EGP.
    - Detention days consumed = 2 (free 7), overdue = 0, detention_fee_fx = 0.0.
    """
    # 1. Without gate-out (legacy cap)
    sim1 = dd_service.simulate_demurrage_and_detention(
        DemurrageSimulationRequest(
            carrier_name="MSC",
            container_type="40ft High Cube",
            containers_count=1,
            demurrage_free_days=14,
            detention_free_days=7,
            port_storage_free_days=5,
            port_storage_daily_rate_egp=250.0,
            discharge_date=date(2026, 9, 1),
            gate_out_date=None,
            empty_return_date=date(2026, 9, 10),
            calculation_date=date(2026, 10, 6),
            currency="USD",
            exchange_rate=50.0,
        )
    )
    assert sim1.demurrage_days_consumed == 9
    assert sim1.demurrage_days_overdue == 0
    assert sim1.demurrage_fee_fx == 0.0
    assert sim1.storage_days_consumed == 9
    assert sim1.storage_days_overdue == 4
    assert sim1.storage_fee_egp == 1000.0

    # 2. With gate-out 2026-09-08
    sim2 = dd_service.simulate_demurrage_and_detention(
        DemurrageSimulationRequest(
            carrier_name="MSC",
            container_type="40ft High Cube",
            containers_count=1,
            demurrage_free_days=14,
            detention_free_days=7,
            port_storage_free_days=5,
            port_storage_daily_rate_egp=250.0,
            discharge_date=date(2026, 9, 1),
            gate_out_date=date(2026, 9, 8),
            empty_return_date=date(2026, 9, 10),
            calculation_date=date(2026, 10, 6),
            currency="USD",
            exchange_rate=50.0,
        )
    )
    assert sim2.storage_days_consumed == 7
    assert sim2.storage_days_overdue == 2
    assert sim2.storage_fee_egp == 500.0
    assert sim2.detention_days_consumed == 2
    assert sim2.detention_days_overdue == 0
    assert sim2.detention_fee_fx == 0.0


def test_eir_requires_gate_out_per_container(db):
    """
    EIR recording rejects when any target container has no gate-out date,
    and lists the missing containers in the 422 error detail.
    """
    today = cairo_today()
    discharge = today - timedelta(days=15)
    gate_out_1 = today - timedelta(days=5)

    # Create tracking with 2 containers
    req = DemurrageTrackingCreate(
        import_file_id=1,
        carrier_name="MSC",
        bill_of_lading_no="MEDU99887766",
        port_name="Alexandria Port",
        discharge_date=discharge,
        containers=[
            ContainerItemInput(container_no="MSCU1111111", container_type="40ft High Cube"),
            ContainerItemInput(container_no="MSCU2222222", container_type="40ft High Cube"),
        ],
        currency="USD",
        exchange_rate=50.0,
    )
    tracking = dd_service.create_demurrage_tracking_service(db, req, user="tester")

    # Set gate-out only for MSCU1111111
    dd_service.update_single_container_service(
        db,
        tracking.tracking_id,
        "MSCU1111111",
        ContainerIndividualUpdate(gate_out_date=gate_out_1),
        user="tester",
    )

    # 1. Attempt EIR return for all containers (MSCU2222222 has no gate-out) -> 422
    with pytest.raises(HTTPException) as exc:
        dd_service.record_empty_container_return_service(
            db,
            EmptyContainerReturnSubmit(
                import_file_id=1,
                eir_number="EIR-2026-0001",
                empty_return_date=today - timedelta(days=2),
                returned_containers=["MSCU1111111", "MSCU2222222"],
            ),
            user="tester",
        )
    assert exc.value.status_code == status.HTTP_422_UNPROCESSABLE_CONTENT
    assert "MSCU2222222" in exc.value.detail
    assert "Gate-Out" in exc.value.detail

    # 2. Attempt EIR return only for MSCU1111111 (has gate-out) -> Success
    res = dd_service.record_empty_container_return_service(
        db,
        EmptyContainerReturnSubmit(
            import_file_id=1,
            eir_number="EIR-2026-0001",
            empty_return_date=today - timedelta(days=2),
            returned_containers=["MSCU1111111"],
        ),
        user="tester",
    )
    assert res is not None
    assert "MSCU1111111" in res.returned_containers
