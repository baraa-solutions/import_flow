"""
Single Net FOB Valuation Engine, Applied FX Anchor & Zero Double-Counting Guarantee (Trello qJZNzixC).

Concrete numeric scenarios: financing markups and discounts, several invoices, mixed currencies, an invoice rate
different from the LC booking rate, partial SWIFT anchoring, customs base on the declaration date, Open Account
mark-to-market, and the no-double-counting guarantees across the settlement ledger and the landed cost.
"""
from datetime import date, datetime
from decimal import Decimal

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.currencies.model import Currency, ExchangeRate
from modules.currencies.service import clear_currency_cache
from modules.financial_settlement.actual_settlement_service import _is_goods_invoice
from modules.financial_settlement.fob_valuation_service import (
    FINANCING_MARKUP_CATEGORY,
    FOB_DOUBLE_COUNT_DETECTED,
    FOB_DUPLICATE_INVOICE_IGNORED,
    FOB_NET_VALUE_INVALID,
    FX_SOURCE_COMMERCIAL_RATE,
    FX_SOURCE_INVOICE_RATE,
    FX_SOURCE_LC_MARGIN_COVER,
    FX_SOURCE_MIXED,
    FX_SOURCE_SWIFT_REMITTANCE,
    GOODS_CATEGORY,
    FobInvoiceInput,
    FobValuation,
    FxAnchorEvent,
    apply_customs_rates,
    ensure_no_fob_double_count,
    mark_to_market,
    net_fob_foreign,
    resolve_fob_valuation,
    revalue_fob_valuation_service,
    value_fob_invoices,
)
from modules.financial_settlement.schemas import AggregatedInvoiceItemSchema
from modules.financial_settlement.service import (
    aggregate_shipment_invoices_service,
    calculate_actual_landed_cost_service,
    simulate_estimated_landed_cost_service,
)
from modules.import_files.model import ImportFile
from modules.trade_finance.model import FxHedgingAndVariance, ImportFinanceInstrument


def _inv(no, amount, rate, ccy="USD", markup=0.0, discount=0.0, source=FX_SOURCE_INVOICE_RATE):
    return FobInvoiceInput(invoice_no=no, currency=ccy, gross_amount=amount, fallback_rate=rate,
                           fallback_source=source, discount_amount=discount, financing_markup_amount=markup)


def _event(fc, egp, source=FX_SOURCE_SWIFT_REMITTANCE, ccy="USD", day=date(2026, 3, 10)):
    return FxAnchorEvent(currency=ccy, foreign_amount=fc, egp_amount=egp, event_date=day, source=source)


# ── Pure core ───────────────────────────────────────────────────────────────────

class TestNetFob:
    def test_net_fob_excludes_discount_and_financing_markup(self):
        assert net_fob_foreign(100000.0, 2000.0, 5000.0) == 93000.0

    def test_no_adjustments_keeps_the_gross(self):
        assert net_fob_foreign(24500.0) == 24500.0

    @pytest.mark.parametrize("gross,discount,markup", [(1000.0, 600.0, 500.0), (1000.0, -1.0, 0.0), (-5.0, 0.0, 0.0)])
    def test_invalid_adjustments_are_a_422(self, gross, discount, markup):
        with pytest.raises(HTTPException) as exc:
            net_fob_foreign(gross, discount, markup, "PI-1")
        assert exc.value.status_code == 422
        assert exc.value.detail["code"] == FOB_NET_VALUE_INVALID


class TestFxAnchor:
    def test_no_anchor_uses_the_invoice_rate_and_splits_the_markup(self):
        # 10,000 USD billed incl. 500 financing markup, invoice rate 48.
        lines, _ = value_fob_invoices([_inv("PI-1", 10000.0, 48.0, markup=500.0)])
        ln = lines[0]
        assert (ln.net_fob_foreign, ln.payable_foreign) == (9500.0, 10000.0)
        assert ln.net_fob_egp == 456000.0  # 9,500 x 48
        assert ln.financing_markup_egp == 24000.0  # 500 x 48
        assert ln.payable_egp == 480000.0
        assert ln.rate_source == FX_SOURCE_INVOICE_RATE

    def test_invoice_rate_differs_from_lc_booking_rate_goods_plus_variance_equals_settlement(self):
        # Reviewer #212 scenario: invoice stored at 48, LC margin cover booked at 50, settled at 52.
        lines, _ = value_fob_invoices([_inv("PI-1", 10000.0, 48.0)], [_event(10000.0, 500000.0, FX_SOURCE_LC_MARGIN_COVER)])
        goods_egp = lines[0].net_fob_egp
        variance_egp = round(10000.0 * 52.0 - 10000.0 * 50.0, 2)  # trade-finance Realized FX Variance row
        assert goods_egp == 500000.0  # anchored at the booking rate, not the invoice rate (480,000)
        assert lines[0].rate_source == FX_SOURCE_LC_MARGIN_COVER
        assert goods_egp + variance_egp == 10000.0 * 52.0  # = goods at the settlement rate, no gap, no overlap

    def test_partial_swift_anchor_blends_remittance_and_invoice_rate(self):
        lines, _ = value_fob_invoices([_inv("CI-1", 50000.0, 50.0)], [_event(30000.0, 1530000.0)])
        ln = lines[0]
        assert ln.payable_egp == 2530000.0  # 30,000 x 51 + 20,000 x 50
        assert ln.anchored_foreign == 30000.0
        assert ln.rate_source == FX_SOURCE_MIXED
        assert ln.applied_rate == 50.6
        assert ln.egp_for_foreign(30000.0) == 1530000.0  # paid part = the actual bank debit
        assert ln.egp_for_foreign(50000.0) == 2530000.0

    def test_anchor_is_consumed_in_invoice_order_across_several_invoices(self):
        lines, _ = value_fob_invoices(
            [_inv("A", 20000.0, 50.0), _inv("B", 20000.0, 50.0)], [_event(30000.0, 1530000.0)]
        )
        a, b = lines
        assert (a.net_fob_egp, a.rate_source) == (1020000.0, FX_SOURCE_SWIFT_REMITTANCE)  # 20,000 x 51
        assert (b.net_fob_egp, b.rate_source) == (1010000.0, FX_SOURCE_MIXED)  # 10,000 x 51 + 10,000 x 50

    def test_weighted_anchor_rate_of_several_remittances(self):
        # 6,000 @ 50 + 4,000 @ 52.5 -> 510,000 for 10,000 -> 51.0
        lines, _ = value_fob_invoices([_inv("A", 10000.0, 49.0)], [_event(6000.0, 300000.0), _event(4000.0, 210000.0)])
        assert (lines[0].applied_rate, lines[0].net_fob_egp) == (51.0, 510000.0)

    def test_mixed_currencies_total_egp_without_a_single_foreign_amount(self):
        lines, _ = value_fob_invoices([_inv("U", 10000.0, 50.0), _inv("E", 5000.0, 55.0, ccy="EUR")])
        val = FobValuation(import_file_id=1, basis="INVOICE", payment_term=None, lines=lines)
        assert val.fob_total_egp == 775000.0
        assert (val.fob_currency, val.fob_foreign_amount, val.fob_exchange_rate) == (None, None, None)

    def test_single_currency_summary_rate(self):
        lines, _ = value_fob_invoices([_inv("A", 6000.0, 50.0, markup=1000.0), _inv("B", 4000.0, 50.0)])
        val = FobValuation(import_file_id=1, basis="INVOICE", payment_term="ADVANCE_PAYMENT", lines=lines)
        assert (val.fob_currency, val.fob_foreign_amount, val.financing_markup_foreign) == ("USD", 9000.0, 1000.0)
        assert (val.fob_total_egp, val.financing_markup_egp, val.payable_total_egp) == (450000.0, 50000.0, 500000.0)
        assert val.fob_exchange_rate == 50.0


class TestAntiDuplication:
    def test_duplicate_invoice_counts_once(self):
        lines, dups = value_fob_invoices([_inv("PI-7", 10000.0, 50.0), _inv(" pi-7 ", 10000.0, 50.0)])
        assert len(lines) == 1 and dups == [" pi-7 "]
        assert sum(ln.net_fob_egp for ln in lines) == 500000.0  # not 1,000,000

    def test_same_number_in_another_currency_is_not_a_duplicate(self):
        lines, dups = value_fob_invoices([_inv("PI-7", 100.0, 50.0), _inv("PI-7", 100.0, 55.0, ccy="EUR")])
        assert len(lines) == 2 and dups == []

    def _row(self, no, category, amount):
        return AggregatedInvoiceItemSchema(
            invoice_id=no, invoice_no=no, party_type="SUPPLIER", party_type_ar="", party_name="S",
            category=category, category_ar="", currency="USD", exchange_rate=50.0, amount_fc=0.0,
            amount_egp=amount, paid_amount_egp=0.0, remaining_amount_egp=amount, payment_status="UNPAID",
            source_module="Commercial Invoice",
        )

    def test_guard_accepts_a_consistent_ledger_and_rejects_a_doubled_goods_row(self):
        lines, _ = value_fob_invoices([_inv("A", 10000.0, 50.0, markup=1000.0)])
        val = FobValuation(import_file_id=9, basis="INVOICE", payment_term=None, lines=lines)
        ledger = [self._row("A", GOODS_CATEGORY, 450000.0), self._row("A", FINANCING_MARKUP_CATEGORY, 50000.0)]
        ensure_no_fob_double_count(ledger, val)
        with pytest.raises(HTTPException) as exc:
            ensure_no_fob_double_count(ledger + [self._row("A", GOODS_CATEGORY, 450000.0)], val)
        assert exc.value.status_code == 409 and exc.value.detail["code"] == FOB_DOUBLE_COUNT_DETECTED
        with pytest.raises(HTTPException):  # markup folded into the goods row = counted twice
            ensure_no_fob_double_count([self._row("A", GOODS_CATEGORY, 500000.0), ledger[1]], val)

    def test_only_the_exact_goods_rows_are_fob(self):
        clearance = self._row("CL-9", "Commercial Chamber Fees", 1200.0).model_copy(update={"source_module": "Clearance CL-05"})
        assert not _is_goods_invoice(clearance)
        assert not _is_goods_invoice(self._row("A", FINANCING_MARKUP_CATEGORY, 1.0))
        assert _is_goods_invoice(self._row("A", GOODS_CATEGORY, 1.0))


class TestCustomsAndMarkToMarket:
    def test_customs_base_excludes_markup_and_uses_the_customs_rate(self):
        lines, _ = value_fob_invoices([_inv("A", 10000.0, 50.0, markup=500.0)])
        apply_customs_rates(lines, {"USD": 49.0})
        assert lines[0].customs_value_egp == 465500.0  # 9,500 x 49 (the markup never inflates duties)

    def test_customs_value_unknown_without_a_rate(self):
        lines, _ = value_fob_invoices([_inv("A", 10000.0, 50.0)])
        apply_customs_rates(lines, {})
        val = FobValuation(import_file_id=1, basis="INVOICE", payment_term=None, lines=lines)
        assert val.customs_value_egp is None

    def test_open_account_mark_to_market_on_the_open_part_only(self):
        lines, _ = value_fob_invoices([_inv("A", 10000.0, 50.0)], [_event(4000.0, 204000.0, "OPEN_ACCOUNT_SETTLEMENT")])
        exposures = mark_to_market(lines, {"USD": 52.0}, date(2026, 11, 12))
        assert len(exposures) == 1
        mtm = exposures[0]
        assert (mtm.open_foreign, mtm.booked_rate, mtm.unrealized_fx_egp) == (6000.0, 50.0, 12000.0)  # 6,000 x (52-50)

    def test_fully_settled_open_account_has_no_exposure(self):
        lines, _ = value_fob_invoices([_inv("A", 10000.0, 50.0)], [_event(10000.0, 510000.0)])
        assert mark_to_market(lines, {"USD": 53.0}, date(2026, 11, 12)) == []


# ── Database scenarios ──────────────────────────────────────────────────────────

@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(autocommit=False, autoflush=False, bind=engine)()
    usd = Currency(currency_code="USD", currency_name="USD", currency_symbol="$", is_active=True)
    eur = Currency(currency_code="EUR", currency_name="EUR", currency_symbol="E", is_active=True)
    session.add_all([usd, eur])
    session.flush()
    session.add_all([
        ExchangeRate(currency_id=usd.currency_id, customs_rate=Decimal("49"), commercial_rate=Decimal("50"),
                     effective_date=date(2020, 1, 1), is_active=True),
        ExchangeRate(currency_id=usd.currency_id, customs_rate=Decimal("51"), commercial_rate=Decimal("52"),
                     effective_date=date(2026, 6, 1), is_active=True),
        ExchangeRate(currency_id=eur.currency_id, customs_rate=Decimal("54"), commercial_rate=Decimal("55"),
                     effective_date=date(2020, 1, 1), is_active=True),
    ])
    session.commit()
    clear_currency_cache()
    yield session
    session.close()
    clear_currency_cache()


def _file(db, invoices, code="IMP-2026-FOB-01", payment_term=None, form46_date=None) -> ImportFile:
    imp = ImportFile(import_file_code=code, company_name="Sorour Logistics", supplier_name="Milano Industrial SpA",
                     invoices_data=invoices, payment_term=payment_term, form46_date=form46_date)
    db.add(imp)
    db.commit()
    return imp


def _lc_with_fx(db, imp, booking_rate, settlement_rate, amount=10000.0):
    inst = ImportFinanceInstrument(instrument_type="LC", instrument_number=f"LC-{imp.import_file_id}",
                                   import_file_id=imp.import_file_id, issuing_bank="NBE", amount=amount, status="ISSUED")
    db.add(inst)
    db.flush()
    db.add(FxHedgingAndVariance(
        finance_instrument_id=inst.id, foreign_currency="USD", original_amount=amount,
        booking_date=date(2026, 3, 1), booking_rate=booking_rate, booking_total_egp=round(amount * booking_rate, 2),
        settlement_date=date(2026, 4, 1), settlement_rate=settlement_rate,
        settlement_total_egp=round(amount * settlement_rate, 2),
        variance_amount_egp=round(amount * (settlement_rate - booking_rate), 2), variance_nature="UNFAVORABLE_LOSS",
    ))
    db.commit()


def test_ledger_separates_the_financing_markup_from_the_goods_row(db):
    imp = _file(db, [{"invoice_no": "PI-1", "amount": 10000.0, "currency": "USD", "exchange_rate": 50.0,
                      "financing_markup_amount": 1000.0}])
    agg = aggregate_shipment_invoices_service(db, imp.import_file_id)
    goods = [i for i in agg.invoices if i.category == GOODS_CATEGORY]
    markup = [i for i in agg.invoices if i.category == FINANCING_MARKUP_CATEGORY]
    assert [(g.amount_fc, g.amount_egp) for g in goods] == [(9000.0, 450000.0)]
    assert [(m.amount_fc, m.amount_egp) for m in markup] == [(1000.0, 50000.0)]
    assert agg.total_amount_egp == 500000.0  # supplier payable counted once

    calc = calculate_actual_landed_cost_service(db, imp.import_file_id)
    assert calc.actual_total_fob_egp == 450000.0  # net goods value only
    other = next(c for c in calc.categories_breakdown if c.category == "Other & Admin")
    assert other.actual_egp == 50000.0
    assert calc.actual_total_landed_cost_egp == 500000.0  # goods + markup, nothing twice


def test_lc_booking_rate_anchors_goods_so_variance_is_not_double_counted(db):
    imp = _file(db, [{"invoice_no": "PI-1", "amount": 10000.0, "currency": "USD", "exchange_rate": 48.0}],
                payment_term="LC")
    _lc_with_fx(db, imp, booking_rate=50.0, settlement_rate=52.0)
    agg = aggregate_shipment_invoices_service(db, imp.import_file_id)
    goods = next(i for i in agg.invoices if i.category == GOODS_CATEGORY)
    fxv = next(i for i in agg.invoices if i.category == "Realized FX Variance")
    assert goods.amount_egp == 500000.0 and goods.exchange_rate == 50.0
    assert fxv.amount_egp == 20000.0
    assert goods.amount_egp + fxv.amount_egp == 520000.0  # = 10,000 USD at the 52.00 settlement rate

    calc = calculate_actual_landed_cost_service(db, imp.import_file_id)
    assert calc.actual_total_fob_egp == 500000.0
    assert calc.actual_total_landed_cost_egp == 520000.0


def test_duplicated_invoice_in_invoices_data_is_counted_once_with_a_message(db):
    inv = {"invoice_no": "PI-9", "amount": 10000.0, "currency": "USD", "exchange_rate": 50.0}
    imp = _file(db, [inv, dict(inv)])
    agg = aggregate_shipment_invoices_service(db, imp.import_file_id)
    assert [i.amount_egp for i in agg.invoices if i.category == GOODS_CATEGORY] == [500000.0]
    assert any(m.code == FOB_DUPLICATE_INVOICE_IGNORED for m in agg.messages)


def test_customs_base_uses_the_customs_rate_of_the_declaration_date(db):
    imp = _file(db, [{"invoice_no": "PI-1", "amount": 10000.0, "currency": "USD", "invoice_date": "2026-02-01",
                      "financing_markup_amount": 500.0}],
                form46_date=datetime(2026, 3, 15, 10, 0))
    val = resolve_fob_valuation(db, imp.import_file_id)
    line = val.lines[0]
    assert line.fallback_rate == 50.0 and line.rate_source == FX_SOURCE_COMMERCIAL_RATE  # commercial on invoice date
    assert val.declaration_date == date(2026, 3, 15)
    assert val.customs_exchange_rate == 49.0  # customs rate in force on 15-Mar (not today's 51)
    assert val.customs_value_egp == 465500.0  # 9,500 net x 49
    assert val.fob_total_egp == 475000.0  # accounting: 9,500 x 50


def test_mixed_currency_file_values_each_currency_at_its_own_rate(db):
    imp = _file(db, [
        {"invoice_no": "U-1", "amount": 10000.0, "currency": "USD", "exchange_rate": 50.0},
        {"invoice_no": "E-1", "amount": 5000.0, "currency": "EUR", "exchange_rate": 55.0},
    ])
    val = resolve_fob_valuation(db, imp.import_file_id)
    assert val.fob_total_egp == 775000.0 and val.fob_currency is None
    agg = aggregate_shipment_invoices_service(db, imp.import_file_id)
    assert sorted(i.amount_egp for i in agg.invoices if i.category == GOODS_CATEGORY) == [275000.0, 500000.0]


def test_open_account_revaluation_snapshot_tracks_unrealized_fx(db):
    imp = _file(db, [{"invoice_no": "OA-1", "amount": 10000.0, "currency": "USD", "invoice_date": "2026-03-01",
                      "financing_markup_amount": 400.0}],
                payment_term="OPEN_ACCOUNT")
    resp = revalue_fob_valuation_service(db, imp.import_file_id, actor="finance.user")
    # Booked at the commercial rate of the invoice date (50); current commercial rate 52.
    assert resp.mark_to_market[0].open_foreign == 10000.0
    assert resp.unrealized_fx_egp == 20000.0
    db.refresh(imp)
    assert (imp.fob_currency, imp.fob_foreign_amount, imp.fob_exchange_rate) == ("USD", 9600.0, 50.0)
    assert (imp.fob_total_egp, imp.financing_markup_amount, imp.financing_markup_egp) == (480000.0, 400.0, 20000.0)
    assert imp.fob_rate_source == FX_SOURCE_COMMERCIAL_RATE
    assert imp.fob_unrealized_fx_egp == 20000.0
    assert imp.fob_valued_by == "finance.user" and imp.fob_valued_at is not None
    # Unrealized MTM never enters the landed cost.
    calc = calculate_actual_landed_cost_service(db, imp.import_file_id)
    assert calc.actual_total_landed_cost_egp == 500000.0


def test_estimate_invoice_fallback_uses_the_net_fob(db):
    imp = _file(db, [{"invoice_no": "PI-1", "amount": 10000.0, "currency": "USD", "discount_amount": 200.0,
                      "financing_markup_amount": 800.0}])
    sim = simulate_estimated_landed_cost_service(db, imp.import_file_id)
    assert sim.total_fob_fc == 9000.0  # 10,000 - 200 discount - 800 markup


def test_negative_net_fob_in_invoices_data_is_refused(db):
    imp = _file(db, [{"invoice_no": "PI-1", "amount": 1000.0, "currency": "USD", "financing_markup_amount": 1500.0}])
    with pytest.raises(HTTPException) as exc:
        aggregate_shipment_invoices_service(db, imp.import_file_id)
    assert exc.value.detail["code"] == FOB_NET_VALUE_INVALID
