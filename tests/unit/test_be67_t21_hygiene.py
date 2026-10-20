"""
Unit tests for BE67-T21: Clearance list paging, tariff messages, history agreement filtering, and multi-estimate currency required.
"""
from datetime import date
from decimal import Decimal
import pytest
from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.customs_clearance.service import list_customs_clearances_service
from modules.customs_tariff.model import CustomsTariff, PreferentialAgreement
from modules.customs_tariff.schemas import MultiItemCustomsEstimateRequest, MultiItemCustomsEstimateLine
from modules.customs_tariff.service import (
    get_tariff_by_id_service,
    get_tariff_version_history_service,
)


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()


def test_clearance_list_paging_and_total_count(db):
    for i in range(5):
        rec = CustomsClearanceRecord(
            clearance_code=f"CLR-2026-000{i+1}",
            import_file_id=10,
            status="Draft",
            owner="admin",
        )
        db.add(rec)
    db.commit()

    # Page limit=2, skip=1
    items, total = list_customs_clearances_service(db, skip=1, limit=2)
    assert total == 5
    assert len(items) == 2


def test_tariff_arabic_404_detail(db):
    with pytest.raises(HTTPException) as exc_info:
        get_tariff_by_id_service(db, 99999)
    assert exc_info.value.status_code == 404
    assert "سجل التعريفة الجمركية غير موجود" in exc_info.value.detail


def test_tariff_history_filters_agreements_by_period_and_keeps_null_rates(db):
    from unittest.mock import patch

    # Setup tariff version in DB
    t = CustomsTariff(
        hs_code="8471.30.00",
        hs_description="Laptops",
        customs_duty_rate=5.0,
        vat_rate=14.0,
        customs_service_fee_rate=1.0,
        effective_from=date(2025, 1, 1),
        effective_to=date(2025, 12, 31),
        is_active=False,
    )
    db.add(t)

    # Agreement active in 2025
    ag1 = PreferentialAgreement(
        hs_code="8471.30.00",
        agreement_name="EU Agreement 2025",
        reduction_type="percentage_of_duty",
        reduction_percentage=Decimal("1.00"),
        origin_countries="DE,FR",
        effective_from=date(2025, 1, 1),
        effective_to=date(2025, 12, 31),
    )
    # Agreement active in 2026 (outside 2025 version period)
    ag2 = PreferentialAgreement(
        hs_code="8471.30.00",
        agreement_name="EU Agreement 2026",
        reduction_type="percentage_of_duty",
        reduction_percentage=Decimal("1.00"),
        origin_countries="DE,FR",
        effective_from=date(2026, 1, 1),
        effective_to=date(2026, 12, 31),
    )
    db.add(ag1)
    db.add(ag2)
    db.commit()

    # Create mock version where vat_rate and customs_service_fee_rate are None
    mock_v = CustomsTariff(
        tariff_id=t.tariff_id,
        hs_code=t.hs_code,
        hs_description=t.hs_description,
        customs_duty_rate=5.0,
        effective_from=date(2025, 1, 1),
        effective_to=date(2025, 12, 31),
        is_active=False,
    )
    mock_v.vat_rate = None
    mock_v.customs_service_fee_rate = None

    with patch("modules.customs_tariff.repository.get_all_tariff_versions_by_hs_code", return_value=[mock_v]):
        res = get_tariff_version_history_service(db, "8471.30.00")
        assert len(res["versions"]) == 1
        v0 = res["versions"][0]
        assert v0["vat_rate"] is None
        assert v0["customs_service_fee_rate"] is None

        # Agreements should only include ag1, not ag2
        assert v0["agreements_count"] == 1
        assert v0["agreements"][0]["agreement_name"] == "EU Agreement 2025"



def test_multi_estimate_currency_required():
    # Without currency -> raises ValidationError
    with pytest.raises(ValidationError):
        MultiItemCustomsEstimateRequest(
            lines=[
                MultiItemCustomsEstimateLine(
                    line_no=1,
                    hs_code="8471.30.00",
                    value_fc=Decimal("1000.00"),
                )
            ]
        )

    # With currency -> valid
    req = MultiItemCustomsEstimateRequest(
        currency="USD",
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                hs_code="8471.30.00",
                value_fc=Decimal("1000.00"),
            )
        ],
    )
    assert req.currency == "USD"
