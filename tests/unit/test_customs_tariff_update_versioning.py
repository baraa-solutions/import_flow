"""
MD-008 / AGENTS.md 7.2: editing a tariff's rates keeps the effective_from/effective_to history.

The edit form re-sends the stored effective_from, so a PUT with an unchanged effective_from and a
new rate must close the current version and open a new one from today, never overwrite the rate
of a version that past cost snapshots relied on.
"""
from datetime import date, timedelta
from decimal import Decimal

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.customs_tariff import repository
from modules.customs_tariff.model import CustomsTariff
from modules.customs_tariff.schemas import CustomsTariffUpdate
from modules.customs_tariff.service import update_tariff_service
from modules.customs_tariff.validators import resolve_rate_change_effective_date

HS = "8471.30.00"
SINCE = date(2025, 1, 1)


@pytest.fixture
def db():
    engine = create_engine(
        "sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(autocommit=False, autoflush=False, bind=engine)()
    yield session
    session.close()
    Base.metadata.drop_all(bind=engine)


def _tariff(db, effective_from=SINCE, effective_to=None) -> CustomsTariff:
    tariff = CustomsTariff(
        hs_code=HS,
        hs_description="Laptops and notebook computers",
        customs_duty_rate=Decimal("10.00"),
        vat_rate=Decimal("14.00"),
        effective_from=effective_from,
        effective_to=effective_to,
        is_active=True,
    )
    db.add(tariff)
    db.commit()
    db.refresh(tariff)
    return tariff


def test_rate_change_with_unchanged_effective_from_creates_new_version(db):
    original = _tariff(db)
    today = date.today()

    result = update_tariff_service(
        db,
        original.tariff_id,
        CustomsTariffUpdate(customs_duty_rate=Decimal("15.00"), effective_from=SINCE),
    )

    assert result.tariff_id != original.tariff_id
    assert result.effective_from == today
    assert result.customs_duty_rate == Decimal("15.00")

    db.refresh(original)
    assert original.customs_duty_rate == Decimal("10.00")
    assert original.effective_to == today - timedelta(days=1)

    assert len(repository.get_all_tariff_versions_by_hs_code(db, HS)) == 2
    past = repository.get_active_tariff_on_date(db, HS, date(2025, 6, 1))
    assert past.customs_duty_rate == Decimal("10.00")
    current = repository.get_active_tariff_on_date(db, HS, today)
    assert current.customs_duty_rate == Decimal("15.00")


def test_rate_change_without_effective_from_versions_from_today(db):
    original = _tariff(db)

    result = update_tariff_service(
        db, original.tariff_id, CustomsTariffUpdate(vat_rate=Decimal("10.00"))
    )

    assert result.tariff_id != original.tariff_id
    assert result.effective_from == date.today()
    db.refresh(original)
    assert original.vat_rate == Decimal("14.00")


def test_rate_change_with_later_effective_from_versions_from_that_date(db):
    original = _tariff(db)
    starts = date.today() + timedelta(days=30)

    result = update_tariff_service(
        db,
        original.tariff_id,
        CustomsTariffUpdate(customs_duty_rate=Decimal("20.00"), effective_from=starts),
    )

    assert result.effective_from == starts
    db.refresh(original)
    assert original.effective_to == starts - timedelta(days=1)


def test_rate_change_backdated_before_current_version_is_rejected(db):
    original = _tariff(db)

    with pytest.raises(ValueError):
        update_tariff_service(
            db,
            original.tariff_id,
            CustomsTariffUpdate(customs_duty_rate=Decimal("15.00"), effective_from=date(2024, 1, 1)),
        )

    db.refresh(original)
    assert original.customs_duty_rate == Decimal("10.00")
    assert len(repository.get_all_tariff_versions_by_hs_code(db, HS)) == 1


def test_rate_change_on_version_not_yet_in_force_edits_in_place(db):
    upcoming = date.today() + timedelta(days=10)
    original = _tariff(db, effective_from=upcoming)

    result = update_tariff_service(
        db,
        original.tariff_id,
        CustomsTariffUpdate(customs_duty_rate=Decimal("12.00"), effective_from=upcoming),
    )

    assert result.tariff_id == original.tariff_id
    assert result.effective_from == upcoming
    assert result.customs_duty_rate == Decimal("12.00")
    assert len(repository.get_all_tariff_versions_by_hs_code(db, HS)) == 1


def test_metadata_only_change_stays_in_place(db):
    original = _tariff(db)

    result = update_tariff_service(
        db,
        original.tariff_id,
        CustomsTariffUpdate(hs_description="Portable laptops", effective_from=SINCE),
    )

    assert result.tariff_id == original.tariff_id
    assert result.hs_description == "Portable laptops"
    assert result.effective_from == SINCE


def test_explicit_null_effective_to_reopens_version(db):
    original = _tariff(db, effective_to=date(2030, 12, 31))

    result = update_tariff_service(
        db, original.tariff_id, CustomsTariffUpdate(effective_to=None)
    )

    assert result.tariff_id == original.tariff_id
    assert result.effective_to is None


def test_omitted_effective_to_is_kept(db):
    original = _tariff(db, effective_to=date(2030, 12, 31))

    result = update_tariff_service(
        db, original.tariff_id, CustomsTariffUpdate(hs_description="Portable laptops")
    )

    assert result.effective_to == date(2030, 12, 31)


def test_resolve_rate_change_effective_date_rules():
    today = date(2026, 11, 12)
    assert resolve_rate_change_effective_date(SINCE, None, today) == today
    assert resolve_rate_change_effective_date(SINCE, SINCE, today) == today
    assert resolve_rate_change_effective_date(SINCE, date(2027, 1, 1), today) == date(2027, 1, 1)
    with pytest.raises(ValueError):
        resolve_rate_change_effective_date(SINCE, date(2024, 1, 1), today)
    future = date(2027, 1, 1)
    assert resolve_rate_change_effective_date(future, date(2026, 12, 1), today) == date(2026, 12, 1)
