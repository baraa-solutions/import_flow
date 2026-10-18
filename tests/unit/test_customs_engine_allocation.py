from datetime import date
from decimal import Decimal
import pytest
from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.currencies.model import Currency, ExchangeRate
from modules.currencies.service import clear_currency_cache
from modules.customs_tariff.model import CustomsTariff
from modules.customs_tariff.schemas import (
    MultiItemCustomsEstimateLine,
    MultiItemCustomsEstimateRequest,
)
from modules.customs_tariff.service import estimate_multi_item_customs_duty_service, _allocate


@pytest.fixture
def db_session():
    clear_currency_cache()
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = TestingSessionLocal()
    try:
        # Seed currencies
        egp = Currency(currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="LE", is_active=True)
        usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
        session.add_all([egp, usd])
        session.commit()

        # Seed standard tariff HS 8471.30.00: duty 10%, VAT 14%, service fee 1%, others 0%
        tariff_a = CustomsTariff(
            hs_code="8471.30.00",
            hs_description="Laptops and portable computers",
            customs_duty_rate=Decimal("10.00"),
            vat_rate=Decimal("14.00"),
            schedule_tax_rate=Decimal("0.00"),
            development_fee_rate=Decimal("0.00"),
            import_fee_rate=Decimal("0.00"),
            customs_service_fee_rate=Decimal("1.00"),
            effective_from=date(2025, 1, 1),
            is_active=True,
        )
        # Seed standard tariff HS 8471.49.00: duty 10%, VAT 14%, service fee 1%, others 0%
        tariff_b = CustomsTariff(
            hs_code="8471.49.00",
            hs_description="Other digital automatic data processing machines",
            customs_duty_rate=Decimal("10.00"),
            vat_rate=Decimal("14.00"),
            schedule_tax_rate=Decimal("0.00"),
            development_fee_rate=Decimal("0.00"),
            import_fee_rate=Decimal("0.00"),
            customs_service_fee_rate=Decimal("1.00"),
            effective_from=date(2025, 1, 1),
            is_active=True,
        )
        session.add_all([tariff_a, tariff_b])
        session.commit()

        yield session
    finally:
        clear_currency_cache()
        session.close()


def test_allocate_exact_remainder():
    """Unit test for _allocate: ensures sum equals total and remainder cents are distributed stably."""
    # 100 split 3 ways (equal weights)
    shares = _allocate(Decimal("100.00"), [Decimal("1000"), Decimal("1000"), Decimal("1000")])
    assert shares == [Decimal("33.33"), Decimal("33.33"), Decimal("33.34")]
    assert sum(shares) == Decimal("100.00")

    # Unequal weights
    shares2 = _allocate(Decimal("15000.00"), [Decimal("60000"), Decimal("40000")])
    assert shares2 == [Decimal("9000.00"), Decimal("6000.00")]
    assert sum(shares2) == Decimal("15000.00")

    # Empty and zero weights
    assert _allocate(Decimal("100.00"), []) == []
    assert _allocate(Decimal("100.00"), [Decimal("0"), Decimal("0")]) == [Decimal("0.00"), Decimal("0.00")]


def test_exempted_value_allocation_and_taxes_reconciliation(db_session):
    """Test 1: Lines A 60k (exempted 60k) and B 40k; insurance 5k, freight 10k ->
    A cif_value_egp == 0.00, duty == 0, vat == 0, svc_fee == 0, gross_cif == 69000.
    B cif_value_egp == 46000.00, duty == 4600, vat == 7084 ((46000+4600)*0.14).
    cif_total_egp == 115000.00, dutiable_cif_total_egp == 46000.00.
    """
    req = MultiItemCustomsEstimateRequest(
        currency="EGP",
        exchange_rate=Decimal("1.00"),
        estimate_date=date(2026, 6, 1),
        insurance_egp=Decimal("5000.00"),
        freight_egp=Decimal("10000.00"),
        has_insurance_document=True,
        has_freight_document=True,
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                hs_code="8471.30.00",
                value_fc=Decimal("60000.00"),
                exempted_value_fc=Decimal("60000.00"),
            ),
            MultiItemCustomsEstimateLine(
                line_no=2,
                hs_code="8471.49.00",
                value_fc=Decimal("40000.00"),
                exempted_value_fc=Decimal("0.00"),
            ),
        ],
    )
    res = estimate_multi_item_customs_duty_service(db_session, req)

    # Line A checks
    line_a = res.lines[0]
    assert line_a.gross_cif_value_egp == Decimal("69000.00")
    assert line_a.cif_value_egp == Decimal("0.00")
    assert line_a.duty_egp == Decimal("0.00")
    assert line_a.vat_egp == Decimal("0.00")
    assert line_a.customs_service_fee_egp == Decimal("0.00")

    # Line B checks
    line_b = res.lines[1]
    assert line_b.gross_cif_value_egp == Decimal("46000.00")
    assert line_b.cif_value_egp == Decimal("46000.00")
    assert line_b.duty_egp == Decimal("4600.00")
    assert line_b.vat_egp == Decimal("7084.00")  # (46,000 + 4,600) * 0.14 = 7,084.00
    assert line_b.customs_service_fee_egp == Decimal("460.00")

    # Breakdown totals checks
    assert res.cif_total_egp == Decimal("115000.00")
    assert res.dutiable_cif_total_egp == Decimal("46000.00")
    assert res.total_duty_egp == Decimal("4600.00")
    assert res.total_vat_egp == Decimal("7084.00")


def test_declared_cif_with_exempted_lines(db_session):
    """Test 2: Same lines with cif_declared_total_egp=100000 ->
    A cif_value_egp == 0.00, gross_cif == 60000.00
    B cif_value_egp == 40000.00, gross_cif == 40000.00.
    """
    req = MultiItemCustomsEstimateRequest(
        currency="EGP",
        exchange_rate=Decimal("1.00"),
        estimate_date=date(2026, 6, 1),
        cif_declared_total_egp=Decimal("100000.00"),
        insurance_egp=Decimal("5000.00"),
        freight_egp=Decimal("10000.00"),
        has_insurance_document=True,
        has_freight_document=True,
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                hs_code="8471.30.00",
                value_fc=Decimal("60000.00"),
                exempted_value_fc=Decimal("60000.00"),
            ),
            MultiItemCustomsEstimateLine(
                line_no=2,
                hs_code="8471.49.00",
                value_fc=Decimal("40000.00"),
                exempted_value_fc=Decimal("0.00"),
            ),
        ],
    )
    res = estimate_multi_item_customs_duty_service(db_session, req)

    line_a = res.lines[0]
    line_b = res.lines[1]
    assert line_a.gross_cif_value_egp == Decimal("60000.00")
    assert line_a.cif_value_egp == Decimal("0.00")

    assert line_b.gross_cif_value_egp == Decimal("40000.00")
    assert line_b.cif_value_egp == Decimal("40000.00")

    assert res.cif_total_egp == Decimal("100000.00")
    assert res.dutiable_cif_total_egp == Decimal("40000.00")


def test_largest_remainder_cif_reconciliation(db_session):
    """Test 3: currency="USD", exchange_rate=50, 3 lines x value_fc=1000, insurance 50, freight 50 ->
    CIFs [50033.33, 50033.33, 50033.34], cif_total_egp == 150100.00.
    """
    req = MultiItemCustomsEstimateRequest(
        currency="USD",
        exchange_rate=Decimal("50.00"),
        estimate_date=date(2026, 6, 1),
        insurance_egp=Decimal("50.00"),
        freight_egp=Decimal("50.00"),
        has_insurance_document=True,
        has_freight_document=True,
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                hs_code="8471.30.00",
                value_fc=Decimal("1000.00"),
            ),
            MultiItemCustomsEstimateLine(
                line_no=2,
                hs_code="8471.30.00",
                value_fc=Decimal("1000.00"),
            ),
            MultiItemCustomsEstimateLine(
                line_no=3,
                hs_code="8471.30.00",
                value_fc=Decimal("1000.00"),
            ),
        ],
    )
    res = estimate_multi_item_customs_duty_service(db_session, req)

    cifs = [l.cif_value_egp for l in res.lines]
    assert cifs == [Decimal("50033.33"), Decimal("50033.33"), Decimal("50033.34")]
    assert res.cif_total_egp == Decimal("150100.00")
    assert res.dutiable_cif_total_egp == Decimal("150100.00")
    assert sum(cifs) == res.cif_total_egp


def test_exempted_plus_unpaid_exceeds_value_raises_422():
    """Test 4: Line value_fc=1000, exempted_value_fc=1500 raises validation error (422)."""
    with pytest.raises(ValidationError) as exc_info:
        MultiItemCustomsEstimateLine(
            line_no=1,
            hs_code="8471.30.00",
            value_fc=Decimal("1000.00"),
            exempted_value_fc=Decimal("1500.00"),
        )
    assert "القيمة المعفاة والقيمة بدون دفع أكبر من قيمة الصنف" in str(exc_info.value)


def test_exempted_and_unpaid_combined_exceeds_value_raises_422():
    """Test 5: Combined exempted_value_fc + value_without_payment_fc > value_fc raises validation error."""
    with pytest.raises(ValidationError) as exc_info:
        MultiItemCustomsEstimateLine(
            line_no=1,
            hs_code="8471.30.00",
            value_fc=Decimal("1000.00"),
            exempted_value_fc=Decimal("600.00"),
            value_without_payment_fc=Decimal("500.00"),
        )
    assert "القيمة المعفاة والقيمة بدون دفع أكبر من قيمة الصنف" in str(exc_info.value)
