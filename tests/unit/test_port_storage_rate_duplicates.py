"""
Duplicate port terminal rate cards return 409 Conflict, never 500.

uq_port_terminal_rate_unique = (terminal_code, container_size, is_reefer, effective_date) and covers soft-deleted
rows too, so the application check must look at every row, and an IntegrityError race must still map to 409.
"""

from datetime import date

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker

import main
from database.database import Base, get_db
from modules.port_storage.repository import PortStorageRepository
from modules.port_storage.schemas import PortTerminalRateCreate, PortTerminalRateUpdate
from modules.port_storage.service import (
    create_terminal_rate_service,
    delete_terminal_rate_service,
    update_terminal_rate_service,
)

EFFECTIVE = date(2026, 10, 1)


@pytest.fixture
def db(tmp_path):
    engine = create_engine(f"sqlite:///{tmp_path / 'rates.db'}", connect_args={"check_same_thread": False})
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def _rate(**overrides) -> PortTerminalRateCreate:
    data = {
        "terminal_code": "ACCHCO",
        "terminal_name": "Alexandria Container Handling Co.",
        "container_size": "40ft",
        "is_reefer": False,
        "free_days": 7,
        "tier1_rate_per_day": 120.0,
        "tier2_rate_per_day": 240.0,
        "penal_rate_per_day": 400.0,
        "effective_date": EFFECTIVE,
    }
    data.update(overrides)
    return PortTerminalRateCreate(**data)


def _assert_conflict(exc_info):
    assert exc_info.value.status_code == 409
    assert exc_info.value.detail["code"] == "PORT_TERMINAL_RATE_EXISTS"
    assert "ACCHCO" in exc_info.value.detail["message"]


def test_duplicate_create_returns_409(db):
    create_terminal_rate_service(db, _rate())
    with pytest.raises(HTTPException) as exc_info:
        create_terminal_rate_service(db, _rate(tier1_rate_per_day=150.0))
    _assert_conflict(exc_info)


def test_alias_terminal_code_counts_as_the_same_terminal(db):
    create_terminal_rate_service(db, _rate())
    with pytest.raises(HTTPException) as exc_info:
        create_terminal_rate_service(db, _rate(terminal_code="Alexandria", container_size="40HC"))
    _assert_conflict(exc_info)


def test_different_date_reefer_or_size_is_allowed(db):
    create_terminal_rate_service(db, _rate())
    create_terminal_rate_service(db, _rate(effective_date=date(2026, 11, 1)))
    create_terminal_rate_service(db, _rate(is_reefer=True))
    create_terminal_rate_service(db, _rate(container_size="20ft"))
    rates, total = PortStorageRepository.list_terminal_rates(db, terminal_code="ACCHCO")
    assert total == 4


def test_soft_deleted_rate_still_blocks_and_says_so(db):
    rate = create_terminal_rate_service(db, _rate())
    delete_terminal_rate_service(db, rate.rate_id)
    with pytest.raises(HTTPException) as exc_info:
        create_terminal_rate_service(db, _rate())
    _assert_conflict(exc_info)
    assert "محذوف" in exc_info.value.detail["message"]


def test_update_into_a_duplicate_effective_date_returns_409(db):
    create_terminal_rate_service(db, _rate())
    other = create_terminal_rate_service(db, _rate(effective_date=date(2026, 11, 1)))
    with pytest.raises(HTTPException) as exc_info:
        update_terminal_rate_service(db, other.rate_id, PortTerminalRateUpdate(effective_date=EFFECTIVE))
    _assert_conflict(exc_info)
    db.refresh(other)
    assert other.effective_date == date(2026, 11, 1)


def test_update_without_changing_the_key_is_allowed(db):
    rate = create_terminal_rate_service(db, _rate())
    updated = update_terminal_rate_service(
        db, rate.rate_id, PortTerminalRateUpdate(effective_date=EFFECTIVE, tier1_rate_per_day=130.0)
    )
    assert updated.tier1_rate_per_day == 130.0


def test_update_of_missing_rate_returns_404(db):
    with pytest.raises(HTTPException) as exc_info:
        update_terminal_rate_service(db, 999, PortTerminalRateUpdate(effective_date=EFFECTIVE))
    assert exc_info.value.status_code == 404


def test_integrity_error_race_maps_to_409(db, monkeypatch):
    """The pre-check passed but a concurrent create committed the same key first."""
    monkeypatch.setattr(PortStorageRepository, "find_rate_by_unique_key", staticmethod(lambda *a, **k: None))

    def raise_integrity(db_, rate_obj):
        raise IntegrityError("INSERT", {}, Exception("UNIQUE constraint failed"))

    monkeypatch.setattr(PortStorageRepository, "create_terminal_rate", staticmethod(raise_integrity))
    with pytest.raises(HTTPException) as exc_info:
        create_terminal_rate_service(db, _rate())
    _assert_conflict(exc_info)


def test_api_duplicate_rate_returns_409_not_500(db):
    def override_get_db():
        yield db

    main.app.dependency_overrides[get_db] = override_get_db
    try:
        with TestClient(main.app, raise_server_exceptions=False) as client:
            payload = _rate().model_dump(mode="json")
            first = client.post("/api/v1/port-storage/rates", json=payload)
            assert first.status_code in (200, 201), first.text
            second = client.post("/api/v1/port-storage/rates", json=payload)
            assert second.status_code == 409, second.text
            assert second.json()["detail"]["code"] == "PORT_TERMINAL_RATE_EXISTS"
    finally:
        main.app.dependency_overrides.clear()
