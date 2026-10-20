import pytest
from datetime import date, timedelta
from decimal import Decimal
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.users.model import User
from modules.customs_tariff.model import CustomsTariff, PreferentialAgreement
from modules.customs_tariff.schemas import (
    CustomsTariffCreate,
    CustomsTariffUpdate,
    CustomsDutyEstimateRequest,
)
from modules.customs_tariff.service import (
    create_tariff_service,
    update_tariff_service,
    get_tariff_by_hs_code_service,
    get_tariff_version_history_service,
    estimate_customs_duty_service,
)
from modules.customs_tariff.repository import (
    get_tariff_by_hs_code,
    get_active_tariff_on_date,
    archive_and_create_new_tariff_version,
)
from modules.customs_tariff.validators import (
    validate_no_overlapping_hs_code_dates,
)


@pytest.fixture
def db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = TestingSessionLocal()

    admin = User(
        username="admin",
        email="admin@example.com",
        full_name="Admin User",
        role="ADMIN",
        is_active=True,
        hashed_password="pw",
    )
    session.add(admin)
    session.commit()

    yield session
    session.close()
    engine.dispose()


def test_hs_code_chronological_phases_creation_and_validation(db):
    """
    Test creating Phase 1 (2025-01-01 to 2026-01-01) and Phase 2 (2026-01-02 onwards).
    Verify that overlapping dates are rejected.
    """
    hs = "8471.30.00"

    # Phase 1: 2025-01-01 to 2026-01-01
    phase1_data = CustomsTariffCreate(
        hs_code=hs,
        hs_description="Laptops - Phase 1 (5% duty, GOEIC)",
        customs_duty_rate=Decimal("5.0"),
        vat_rate=Decimal("14.0"),
        schedule_tax_rate=Decimal("0.0"),
        development_fee_rate=Decimal("0.0"),
        customs_service_fee_rate=Decimal("0.0"),
        effective_from=date(2025, 1, 1),
        effective_to=date(2026, 1, 1),
        requires_inspection=True,
        requires_acid=True,
        regulatory_authority="GOEIC",
    )
    t1 = create_tariff_service(db, phase1_data)
    assert t1.tariff_id is not None
    assert t1.customs_duty_rate == Decimal("5.0")
    assert t1.total_versions == 1

    # Overlapping attempt: 2025-06-01 to 2026-06-01 should fail
    overlap_data = CustomsTariffCreate(
        hs_code=hs,
        hs_description="Overlapping phase",
        customs_duty_rate=Decimal("8.0"),
        vat_rate=Decimal("14.0"),
        effective_from=date(2025, 6, 1),
        effective_to=date(2026, 6, 1),
    )
    with pytest.raises((HTTPException, ValueError)) as exc_info:
        create_tariff_service(db, overlap_data)
    detail_str = str(exc_info.value.detail if hasattr(exc_info.value, "detail") else exc_info.value)
    assert "تتداخل" in detail_str or "تتعارض" in detail_str or "overlap" in detail_str.lower()

    # Phase 2: 2026-01-02 to None (Ongoing)
    phase2_data = CustomsTariffCreate(
        hs_code=hs,
        hs_description="Laptops - Phase 2 (10% duty, NFSA)",
        customs_duty_rate=Decimal("10.0"),
        vat_rate=Decimal("14.0"),
        schedule_tax_rate=Decimal("0.0"),
        development_fee_rate=Decimal("0.0"),
        customs_service_fee_rate=Decimal("0.0"),
        effective_from=date(2026, 1, 2),
        effective_to=None,
        requires_inspection=False,
        requires_acid=True,
        regulatory_authority="NFSA",
    )
    t2 = create_tariff_service(db, phase2_data)
    assert t2.tariff_id is not None
    assert t2.customs_duty_rate == Decimal("10.0")
    assert t2.total_versions == 2


def test_hs_code_chronological_lookup_and_retroactive_protection(db):
    """
    Verify that:
    1. Looking up on 2025-06-15 resolves Phase 1 (5% duty, GOEIC).
    2. Looking up on 2026-03-01 resolves Phase 2 (10% duty, NFSA).
    3. Customs duty calculations on 2025-06-15 do not change retroactively
       even when Phase 2 exists or is modified.
    """
    hs = "8517.12.00"

    # Phase 1: 2025-01-01 to 2026-01-01
    t1 = create_tariff_service(
        db,
        CustomsTariffCreate(
            hs_code=hs,
            hs_description="Smartphones 2025",
            customs_duty_rate=Decimal("5.0"),
            vat_rate=Decimal("14.0"),
            effective_from=date(2025, 1, 1),
            effective_to=date(2026, 1, 1),
            requires_inspection=True,
            regulatory_authority="NTRA-GOEIC",
        ),
    )

    # Phase 2: 2026-01-02 to None
    t2 = create_tariff_service(
        db,
        CustomsTariffCreate(
            hs_code=hs,
            hs_description="Smartphones 2026",
            customs_duty_rate=Decimal("10.0"),
            vat_rate=Decimal("14.0"),
            effective_from=date(2026, 1, 2),
            effective_to=None,
            requires_inspection=False,
            regulatory_authority="NTRA-NEW",
        ),
    )

    # 1. Date-specific lookups
    rec_2025 = get_tariff_by_hs_code(db, hs, on_date=date(2025, 6, 15))
    assert rec_2025 is not None
    assert rec_2025.tariff_id == t1.tariff_id
    assert rec_2025.customs_duty_rate == Decimal("5.0")
    assert rec_2025.regulatory_authority == "NTRA-GOEIC"

    rec_2026 = get_tariff_by_hs_code(db, hs, on_date=date(2026, 3, 1))
    assert rec_2026 is not None
    assert rec_2026.tariff_id == t2.tariff_id
    assert rec_2026.customs_duty_rate == Decimal("10.0")
    assert rec_2026.regulatory_authority == "NTRA-NEW"

    # 2. Calculation on 2025-06-15
    cif_val = Decimal("1000.00")
    req_2025 = CustomsDutyEstimateRequest(
        hs_code=hs,
        cif_value=cif_val,
        freight=Decimal("0.0"),
        origin_country=None,
        estimate_date=date(2025, 6, 15),
    )
    res_2025 = estimate_customs_duty_service(db, req_2025)
    # 5% of 1000 = 50 import duty
    assert res_2025.import_duty_amount == Decimal("50.00")

    # 3. Calculation on 2026-03-01
    req_2026 = CustomsDutyEstimateRequest(
        hs_code=hs,
        cif_value=cif_val,
        freight=Decimal("0.0"),
        origin_country=None,
        estimate_date=date(2026, 3, 1),
    )
    res_2026 = estimate_customs_duty_service(db, req_2026)
    # 10% of 1000 = 100 import duty
    assert res_2026.import_duty_amount == Decimal("100.00")

    # 4. Modifying Phase 2 (e.g. duty becomes 15%)
    # This must NEVER affect the 2025 calculation
    update_tariff_service(
        db=db,
        tariff_id=t2.tariff_id,
        data=CustomsTariffUpdate(
            customs_duty_rate=Decimal("15.0"),
            effective_from=date(2026, 6, 1),
        ),
    )

    # Re-run 2025 calculation
    res_2025_again = estimate_customs_duty_service(db, req_2025)
    assert res_2025_again.import_duty_amount == Decimal("50.00"), "Phase 1 calculation must NOT be affected retroactively!"


def test_search_and_history_reveals_both_phases_with_conditions(db):
    """
    Verify that querying tariff history returns both chronological phases,
    each with its exact tariff rates and full regulatory conditions.
    """
    hs = "9018.90.00"

    # Phase 1: 2025-01-01 to 2026-01-01
    create_tariff_service(
        db,
        CustomsTariffCreate(
            hs_code=hs,
            hs_description="Medical Devices 2025",
            customs_duty_rate=Decimal("2.0"),
            vat_rate=Decimal("5.0"),
            schedule_tax_rate=Decimal("0.0"),
            development_fee_rate=Decimal("0.0"),
            effective_from=date(2025, 1, 1),
            effective_to=date(2026, 1, 1),
            requires_acid=True,
            requires_coo=True,
            requires_inspection=True,
            regulatory_authority="EDA (Egyptian Drug Authority)",
            prior_approval_note="Requires EDA import permit form 2A",
        ),
    )

    # Phase 2: 2026-01-02 onwards
    create_tariff_service(
        db,
        CustomsTariffCreate(
            hs_code=hs,
            hs_description="Medical Devices 2026",
            customs_duty_rate=Decimal("5.0"),
            vat_rate=Decimal("14.0"),
            schedule_tax_rate=Decimal("1.0"),
            development_fee_rate=Decimal("0.0"),
            effective_from=date(2026, 1, 2),
            effective_to=None,
            requires_acid=True,
            requires_coo=True,
            requires_inspection=False,
            regulatory_authority="Unified Procurement Authority (UPA)",
            prior_approval_note="Requires UPA electronic registration",
        ),
    )

    # Service search by hs code returns total_versions == 2
    res = get_tariff_by_hs_code_service(db, hs)
    assert res.total_versions == 2

    # Query history
    history = get_tariff_version_history_service(db, hs)
    assert "versions" in history
    versions = history["versions"]
    assert len(versions) == 2

    # Check that both phases are distinct and contain their specific regulatory conditions
    v_phases = sorted(versions, key=lambda x: x["effective_from"])
    
    # Phase 1 check
    p1 = v_phases[0]
    assert p1["effective_from"] == "2025-01-01"
    assert p1["effective_to"] == "2026-01-01"
    assert p1["customs_duty_rate"] == 2.0
    assert p1["vat_rate"] == 5.0
    assert p1["requires_inspection"] is True
    assert p1["regulatory_authority"] == "EDA (Egyptian Drug Authority)"
    assert p1["prior_approval_note"] == "Requires EDA import permit form 2A"

    # Phase 2 check
    p2 = v_phases[1]
    assert p2["effective_from"] == "2026-01-02"
    assert p2["effective_to"] is None
    assert p2["customs_duty_rate"] == 5.0
    assert p2["vat_rate"] == 14.0
    assert p2["schedule_tax_rate"] == 1.0
    assert p2["requires_inspection"] is False
    assert p2["regulatory_authority"] == "Unified Procurement Authority (UPA)"
    assert p2["prior_approval_note"] == "Requires UPA electronic registration"
