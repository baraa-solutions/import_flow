"""Trade remedy measures (anti-dumping / safeguard / countervailing): rates come only from registered,
effective measures and the engine refuses instead of guessing missing origin, exporter or quantities."""
from datetime import date
from decimal import Decimal

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main  # noqa: F401  (registers every model on Base)
from database.database import Base
from modules.common.errors import CodedHTTPException
from modules.currencies.model import Currency, ExchangeRate
from modules.customs_tariff import trade_remedy_service as svc
from modules.customs_tariff.schemas import (
    CustomsTariffCreate,
    MultiItemCustomsEstimateLine,
    MultiItemCustomsEstimateRequest,
    TradeRemedyMeasureCreate,
    TradeRemedyMeasureUpdate,
)
from modules.customs_tariff.service import create_tariff_service
from modules.customs_tariff.tariff_calculation_service import estimate_multi_item_customs_duty_service

ON = date(2026, 6, 1)


@pytest.fixture
def db():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()
    usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    egp = Currency(currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="E£", is_active=True,
                   is_base_currency=True)
    session.add_all([usd, egp])
    session.commit()
    session.add(ExchangeRate(currency_id=usd.currency_id, commercial_rate=50.0, customs_rate=50.0,
                             effective_date=date(2020, 1, 1), is_active=True))
    session.commit()
    yield session
    session.close()


def _measure(**overrides) -> TradeRemedyMeasureCreate:
    data = dict(
        measure_type="ANTI_DUMPING", hs_code="7208", origin_country="CN", duty_basis="PERCENT_OF_CIF",
        rate_percent=Decimal("20"), decree_ref="قرار 100/2026", effective_from=date(2026, 1, 1),
    )
    data.update(overrides)
    return TradeRemedyMeasureCreate(**data)


def _resolve(db, hs="7208100000", origin="CN", exporter=None, cif="100000", weight="0", qty="0", on=ON):
    return svc.resolve_trade_remedy_duties(db, hs, origin, exporter, Decimal(cif), Decimal(weight), Decimal(qty), on)


# ── Validation & CRUD ────────────────────────────────────────────────────────

def test_create_assigns_business_code_and_normalises(db):
    m = svc.create_trade_remedy_measure(db, _measure(hs_code="72.08", origin_country="cn"), "lead")
    assert m.measure_code == "TRM-000001"
    assert (m.hs_code, m.origin_country, m.created_by) == ("7208", "CN", "lead")


@pytest.mark.parametrize("overrides, code", [
    ({"rate_percent": None}, "TRM_BASIS_FIELDS_MISSING"),
    ({"duty_basis": "FIXED_PER_TON", "rate_percent": None, "fixed_amount": Decimal("80")}, "TRM_BASIS_FIELDS_MISSING"),
    ({"effective_to": date(2025, 12, 31)}, "TRM_INVALID_DATES"),
    ({"origin_country": "C1"}, "TRM_INVALID_ORIGIN"),
    ({"hs_code": "72AB"}, "TRM_INVALID_HS"),
])
def test_invalid_measures_are_refused(db, overrides, code):
    with pytest.raises(CodedHTTPException) as exc:
        svc.create_trade_remedy_measure(db, _measure(**overrides), "lead")
    assert exc.value.code == code


def test_overlapping_measure_is_refused_but_a_later_period_is_allowed(db):
    svc.create_trade_remedy_measure(db, _measure(effective_to=date(2026, 12, 31)), "lead")
    with pytest.raises(CodedHTTPException) as exc:
        svc.create_trade_remedy_measure(db, _measure(effective_from=date(2026, 6, 1)), "lead")
    assert exc.value.code == "TRM_OVERLAP"
    later = svc.create_trade_remedy_measure(db, _measure(effective_from=date(2027, 1, 1)), "lead")
    assert later.measure_code == "TRM-000002"


def test_update_soft_delete_and_restore(db):
    m = svc.create_trade_remedy_measure(db, _measure(), "lead")
    m = svc.update_trade_remedy_measure(db, m.measure_id, TradeRemedyMeasureUpdate(rate_percent=Decimal("35")), "boss")
    assert (m.rate_percent, m.updated_by) == (Decimal("35"), "boss")
    svc.soft_delete_trade_remedy_measure(db, m.measure_id, "boss")
    assert _resolve(db) == (Decimal("0.00"), [])
    assert svc.list_trade_remedy_measures(db) == []
    svc.restore_trade_remedy_measure(db, m.measure_id, "boss")
    assert _resolve(db)[0] == Decimal("35000.00")


# ── Resolution ───────────────────────────────────────────────────────────────

def test_percent_measure_applies_only_to_its_origin_and_period(db):
    svc.create_trade_remedy_measure(db, _measure(effective_to=date(2026, 12, 31)), "lead")
    total, duties = _resolve(db)
    assert total == Decimal("20000.00")
    assert (duties[0].measure_code, duties[0].decree_ref) == ("TRM-000001", "قرار 100/2026")
    assert _resolve(db, origin="TR") == (Decimal("0.00"), [])
    assert _resolve(db, on=date(2027, 1, 1)) == (Decimal("0.00"), [])
    assert _resolve(db, hs="7209100000") == (Decimal("0.00"), [])


def test_safeguard_for_all_origins_stacks_with_anti_dumping(db):
    svc.create_trade_remedy_measure(db, _measure(), "lead")
    svc.create_trade_remedy_measure(
        db, _measure(measure_type="SAFEGUARD", origin_country=None, rate_percent=Decimal("15")), "lead")
    total, duties = _resolve(db)
    assert total == Decimal("35000.00")
    assert sorted(d.measure_type for d in duties) == ["ANTI_DUMPING", "SAFEGUARD"]
    assert _resolve(db, origin="TR")[0] == Decimal("15000.00")


def test_most_specific_measure_wins(db):
    svc.create_trade_remedy_measure(db, _measure(hs_code="7208", rate_percent=Decimal("20")), "lead")
    svc.create_trade_remedy_measure(db, _measure(hs_code="720810", rate_percent=Decimal("30")), "lead")
    svc.create_trade_remedy_measure(
        db, _measure(hs_code="720810", exporter_name="Baosteel", rate_percent=Decimal("5")), "lead")
    assert _resolve(db)[0] == Decimal("30000.00")
    assert _resolve(db, exporter="BAOSTEEL")[0] == Decimal("5000.00")
    assert _resolve(db, hs="7208900000")[0] == Decimal("20000.00")


def test_origin_specific_measure_needs_the_origin(db):
    svc.create_trade_remedy_measure(db, _measure(), "lead")
    with pytest.raises(CodedHTTPException) as exc:
        _resolve(db, origin=None)
    assert exc.value.code == "CT_TRADE_REMEDY_ORIGIN_MISSING"


def test_exporter_only_measures_need_the_exporter(db):
    svc.create_trade_remedy_measure(db, _measure(exporter_name="Baosteel"), "lead")
    with pytest.raises(CodedHTTPException) as exc:
        _resolve(db)
    assert exc.value.code == "CT_TRADE_REMEDY_EXPORTER_MISSING"


def test_fixed_per_ton_in_usd_uses_weight_and_customs_rate(db):
    svc.create_trade_remedy_measure(
        db, _measure(duty_basis="FIXED_PER_TON", rate_percent=None, fixed_amount=Decimal("80"),
                     fixed_currency="usd"), "lead")
    total, duties = _resolve(db, weight="2500")
    assert total == Decimal("10000.00")  # 2.5 t x 80 USD x 50
    assert (duties[0].fixed_currency, duties[0].exchange_rate) == ("USD", Decimal("50.0"))
    with pytest.raises(CodedHTTPException) as exc:
        _resolve(db, weight="0")
    assert exc.value.code == "CT_TRADE_REMEDY_QTY_MISSING"


def test_fixed_per_unit_in_egp(db):
    svc.create_trade_remedy_measure(
        db, _measure(duty_basis="FIXED_PER_UNIT", rate_percent=None, fixed_amount=Decimal("12.50"),
                     fixed_currency="EGP"), "lead")
    assert _resolve(db, qty="40")[0] == Decimal("500.00")


# ── Customs engine ───────────────────────────────────────────────────────────

def _tariff(db, hs="7208100000", flagged=True):
    create_tariff_service(db, CustomsTariffCreate(
        hs_code=hs, hs_description="Flat-rolled iron", customs_duty_rate=Decimal("10.00"),
        vat_rate=Decimal("14.00"), has_anti_dumping_risk=flagged, effective_from=date(2026, 1, 1),
    ))


def _estimate(db, origin="CN"):
    return estimate_multi_item_customs_duty_service(db, MultiItemCustomsEstimateRequest(
        currency="EGP", exchange_rate=Decimal("1"), insurance_egp=Decimal("0"), freight_egp=Decimal("0"),
        estimate_date=ON,
        lines=[MultiItemCustomsEstimateLine(line_no=1, hs_code="7208100000", value_fc=Decimal("100000"),
                                            weight_kg=Decimal("1000"), origin_country=origin)],
    ))


def test_engine_adds_registered_duty_to_vat_base_and_points_to_the_deposit_account(db):
    _tariff(db)
    svc.create_trade_remedy_measure(db, _measure(), "lead")
    result = _estimate(db)
    line = result.lines[0]
    expected = (line.cif_value_egp * Decimal("0.20")).quantize(Decimal("0.01"))  # CIF includes deemed freight/insurance
    assert line.trade_remedy_duty_egp == expected
    assert line.trade_remedy_duties[0].measure_code == "TRM-000001"
    # VAT base = CIF + import duty + trade remedy duty
    assert line.vat_base_egp == line.cif_value_egp + line.duty_egp + expected
    assert line.vat_egp == (line.vat_base_egp * Decimal("0.14")).quantize(Decimal("0.01"))
    assert result.total_trade_remedy_duty_egp == expected
    assert result.trade_remedy_notice_code == "CT_TRADE_REMEDY_DEPOSIT"
    assert result.trade_remedy_notice_params == {"decree_refs": "قرار 100/2026"}


def test_flagged_item_without_a_registered_measure_adds_nothing_and_says_so(db):
    _tariff(db)
    result = _estimate(db)
    assert result.total_trade_remedy_duty_egp == Decimal("0.00")
    assert result.trade_remedy_notice_code == "CT_TRADE_REMEDY_RATE_MISSING"
    assert result.trade_remedy_notice_params == {"hs_codes": "7208100000"}


def test_unflagged_item_without_measure_has_no_notice(db):
    _tariff(db, flagged=False)
    result = _estimate(db)
    assert (result.total_trade_remedy_duty_egp, result.trade_remedy_notice_code) == (Decimal("0.00"), None)


# ── Nafeza parser: no guessing between several import duty rates ───────────

def test_parser_takes_the_first_duty_row_and_flags_pages_with_several_rates():
    from modules.customs_tariff.tariff_search_service import parse_smart_nafeza_tariff_text_service

    text = "رمز النظام المُنسق\n7208100000\n\nالضرائب\nضريبة الوارد\n5.000 %\nضريبة الوارد\n40.000 %\nضريبة قيمه مضافه\n14.000 %\n"
    result = parse_smart_nafeza_tariff_text_service(text)
    assert result.tariff_data.customs_duty_rate == Decimal("5.000")  # first row, not the highest (40%)
    assert "تنبيه" in result.summary_ar and "40.000%" in result.summary_ar

    single = parse_smart_nafeza_tariff_text_service(text.replace("ضريبة الوارد\n40.000 %\n", ""))
    assert single.tariff_data.customs_duty_rate == Decimal("5.000")
    assert "تنبيه" not in single.summary_ar
