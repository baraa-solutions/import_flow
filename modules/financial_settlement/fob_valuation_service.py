"""
Single Net FOB Valuation Engine, Applied FX Anchor & Zero Double-Counting Guarantee (Trello qJZNzixC).

One source of truth for the commercial goods value of an import file. Every consumer (CLO-01 invoice ledger,
CLO-02 actual landed cost, PL-08 estimate, reports, customs base) reads the goods value from here instead of
re-deriving it from ``invoices_data``.

Net FOB (per commercial invoice, in the invoice currency)::

    gross_amount               invoice total as billed (before the commercial discount)
  - discount_amount            commercial discount granted by the supplier
  - financing_markup_amount    supplier financing interest / deferred-payment markup included in the price
  = net_fob_foreign            the goods value: the only figure that enters the customs base and the FOB row

    payable_foreign = net_fob_foreign + financing_markup_amount   (what the supplier is actually paid)

The financing markup is a cost of the importer (landed cost, own "Supplier Financing Markup" row) but never part
of the goods value or of the customs / VAT base, so duties are not inflated.

FX Anchor Policy (which rate applies to which figure):

* Accounting / landed cost: the rate of the payment event of the file's exclusive payment pathway
  (``import_files.payment_term``, PR #205):

      LC               trade-finance FX booking of the LC (margin cover)          -> LC_MARGIN_COVER
      CAD              trade-finance FX booking of the collection (document pay)  -> CAD_DOCUMENT_PAYMENT
      ADVANCE_PAYMENT  bank debit of the paid SWIFT requests (outward remittance) -> SWIFT_REMITTANCE
      OPEN_ACCOUNT     bank debit of the maturity settlement                       -> OPEN_ACCOUNT_SETTLEMENT

  Source precedence per currency: active FX records of the file's finance instrument (their *booking* rate),
  else the paid payment requests (``paid_amount_egp / transferred amount``). The part of an invoice not covered
  by an anchor event uses the invoice stored rate, else the commercial rate on the invoice date (provisional).
  Using the FX *booking* rate is what makes ``goods + Realized FX Variance (settlement - booking)`` equal the
  goods at the settlement rate (the #212 review finding): the variance row is never applied on top of a goods
  row valued at another rate.
* Customs value: net FOB x the customs rate in force on the declaration (Form 46) date (PR #211). Financing
  markup excluded.
* Open Account: until the maturity payment, the uncovered amount is revalued mark-to-market at the current
  commercial rate. The difference is *unrealized*: reported (and snapshotted) only, never added to the landed
  cost. On settlement it becomes realized through the anchor rate.

Zero double counting:

* An invoice recorded twice in ``invoices_data`` (same number and currency) counts once (message
  ``FOB_DUPLICATE_INVOICE_IGNORED``).
* The goods value appears in exactly one ledger row per invoice (category ``Commercial Goods``); supplier
  payments only settle that row and are never added as a cost; ``ensure_no_fob_double_count`` checks the
  ledger against the valuation.
"""
from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import date, datetime, timezone
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

from fastapi import status
from sqlalchemy.orm import Session

from modules.common.validators import ensure_file_open, require_active
from modules.import_files.model import ImportFile

from .landed_cost_engine_service import SettlementFx, _as_date, _message, cairo_today
from .schemas import (
    FobInvoiceValuationSchema,
    FobValuationResponse,
    MarkToMarketExposureSchema,
    SettlementMessage,
)
from .validators import coded_error, currency_missing_error

IMPORT_FILE_LABEL_AR = "ملف الشحنة"

# Ledger categories (the goods row and the separated financing markup row).
GOODS_CATEGORY = "Commercial Goods"
GOODS_SOURCE_MODULE = "Commercial Invoice"
FINANCING_MARKUP_CATEGORY = "Supplier Financing Markup"

# FX anchor sources (import_files.fob_rate_source).
FX_SOURCE_SWIFT_REMITTANCE = "SWIFT_REMITTANCE"
FX_SOURCE_LC_MARGIN_COVER = "LC_MARGIN_COVER"
FX_SOURCE_CAD_DOCUMENT_PAYMENT = "CAD_DOCUMENT_PAYMENT"
FX_SOURCE_OPEN_ACCOUNT_SETTLEMENT = "OPEN_ACCOUNT_SETTLEMENT"
FX_SOURCE_INVOICE_RATE = "INVOICE_RATE"
FX_SOURCE_COMMERCIAL_RATE = "COMMERCIAL_RATE"
FX_SOURCE_LOCAL_CURRENCY = "LOCAL_CURRENCY"
FX_SOURCE_MIXED = "MIXED"
FX_SOURCES: Tuple[str, ...] = (
    FX_SOURCE_SWIFT_REMITTANCE,
    FX_SOURCE_LC_MARGIN_COVER,
    FX_SOURCE_CAD_DOCUMENT_PAYMENT,
    FX_SOURCE_OPEN_ACCOUNT_SETTLEMENT,
    FX_SOURCE_INVOICE_RATE,
    FX_SOURCE_COMMERCIAL_RATE,
    FX_SOURCE_LOCAL_CURRENCY,
    FX_SOURCE_MIXED,
)

# Payment pathway (import_files.payment_term / instrument_type) -> anchor source of its payment event.
PATHWAY_ANCHOR_SOURCE: Dict[str, str] = {
    "ADVANCE_PAYMENT": FX_SOURCE_SWIFT_REMITTANCE,
    "LC": FX_SOURCE_LC_MARGIN_COVER,
    "CAD": FX_SOURCE_CAD_DOCUMENT_PAYMENT,
    "OPEN_ACCOUNT": FX_SOURCE_OPEN_ACCOUNT_SETTLEMENT,
}

BASIS_INVOICE = "INVOICE"
BASIS_ESTIMATE = "ESTIMATE"
BASIS_NONE = "NONE"

# Coded errors / messages.
FOB_NET_VALUE_INVALID = "FOB_NET_VALUE_INVALID"
FOB_DOUBLE_COUNT_DETECTED = "FOB_DOUBLE_COUNT_DETECTED"
FOB_DUPLICATE_INVOICE_IGNORED = "FOB_DUPLICATE_INVOICE_IGNORED"
FOB_CUSTOMS_DATE_PENDING = "FOB_CUSTOMS_DATE_PENDING"
FOB_CUSTOMS_RATE_MISSING = "FOB_CUSTOMS_RATE_MISSING"
FOB_MTM_RATE_MISSING = "FOB_MTM_RATE_MISSING"

MONEY_TOLERANCE_EGP = 0.01


# ── Value objects ───────────────────────────────────────────────────────────────

@dataclass(frozen=True)
class FxAnchorEvent:
    """One financial event that fixed an EGP amount for a foreign-currency amount (bank debit / FX booking)."""

    currency: str
    foreign_amount: float
    egp_amount: float
    event_date: Optional[date]
    source: str
    reference: Optional[str] = None

    @property
    def rate(self) -> float:
        return self.egp_amount / self.foreign_amount if self.foreign_amount > 0 else 0.0


@dataclass(frozen=True)
class FobInvoiceInput:
    """A commercial invoice as recorded. ``fallback_rate`` values the part no anchor event covers."""

    invoice_no: str
    currency: str
    gross_amount: float
    fallback_rate: float
    fallback_source: str = FX_SOURCE_INVOICE_RATE
    invoice_date: Optional[date] = None
    discount_amount: float = 0.0
    financing_markup_amount: float = 0.0


@dataclass
class FobInvoiceValuation:
    invoice_no: str
    invoice_date: Optional[date]
    currency: str
    gross_amount: float
    discount_amount: float
    financing_markup_amount: float
    net_fob_foreign: float
    payable_foreign: float
    anchored_foreign: float
    anchor_rate: Optional[float]
    fallback_rate: float
    applied_rate: float
    payable_egp: float
    net_fob_egp: float
    financing_markup_egp: float
    rate_source: str
    rate_date: Optional[date]
    customs_rate: Optional[float] = None
    customs_value_egp: Optional[float] = None

    def egp_for_foreign(self, foreign_amount: float) -> float:
        """EGP value of ``foreign_amount`` of this invoice's payable: anchored first, then the fallback rate."""
        amount = max(0.0, min(float(foreign_amount or 0.0), self.payable_foreign))
        if self.currency == "EGP":
            return round(amount, 2)
        anchored = min(amount, self.anchored_foreign)
        egp = anchored * (self.anchor_rate or 0.0) + (amount - anchored) * self.fallback_rate
        return min(round(egp, 2), self.payable_egp)


@dataclass
class MarkToMarketExposure:
    """Open Account revaluation of the not-yet-settled foreign amount of one currency (unrealized)."""

    currency: str
    open_foreign: float
    booked_rate: float
    current_rate: float
    as_of: date
    unrealized_fx_egp: float  # positive = loss (same sign convention as trade-finance variance)


@dataclass
class FobValuation:
    import_file_id: Optional[int]
    basis: str
    payment_term: Optional[str]
    lines: List[FobInvoiceValuation] = field(default_factory=list)
    duplicates_ignored: List[str] = field(default_factory=list)
    declaration_date: Optional[date] = None
    mark_to_market: List[MarkToMarketExposure] = field(default_factory=list)
    messages: List[SettlementMessage] = field(default_factory=list)

    @property
    def currencies(self) -> List[str]:
        return sorted({ln.currency for ln in self.lines if ln.payable_foreign > 0 or ln.gross_amount > 0})

    @property
    def fob_currency(self) -> Optional[str]:
        ccys = self.currencies
        return ccys[0] if len(ccys) == 1 else None

    @property
    def fob_foreign_amount(self) -> Optional[float]:
        return round(sum(ln.net_fob_foreign for ln in self.lines), 2) if self.fob_currency else None

    @property
    def financing_markup_foreign(self) -> Optional[float]:
        return round(sum(ln.financing_markup_amount for ln in self.lines), 2) if self.fob_currency else None

    @property
    def discount_foreign(self) -> Optional[float]:
        return round(sum(ln.discount_amount for ln in self.lines), 2) if self.fob_currency else None

    @property
    def fob_total_egp(self) -> float:
        return round(sum(ln.net_fob_egp for ln in self.lines), 2)

    @property
    def financing_markup_egp(self) -> float:
        return round(sum(ln.financing_markup_egp for ln in self.lines), 2)

    @property
    def payable_total_egp(self) -> float:
        return round(self.fob_total_egp + self.financing_markup_egp, 2)

    @property
    def fob_exchange_rate(self) -> Optional[float]:
        foreign = self.fob_foreign_amount
        if not foreign:
            return None
        return round(self.fob_total_egp / foreign, 6)

    @property
    def rate_source(self) -> Optional[str]:
        sources = {ln.rate_source for ln in self.lines if ln.payable_foreign > 0}
        if not sources:
            return None
        return sources.pop() if len(sources) == 1 else FX_SOURCE_MIXED

    @property
    def rate_date(self) -> Optional[date]:
        dates = [ln.rate_date for ln in self.lines if ln.rate_date is not None and ln.payable_foreign > 0]
        return max(dates) if dates else None

    @property
    def customs_value_egp(self) -> Optional[float]:
        """Customs FOB base (net goods value at the customs rate of the declaration date); None while unknown."""
        values = [ln.customs_value_egp for ln in self.lines if ln.net_fob_foreign > 0]
        if not values or any(v is None for v in values):
            return None
        return round(sum(values), 2)

    @property
    def customs_exchange_rate(self) -> Optional[float]:
        if not self.fob_currency:
            return None
        rates = {ln.customs_rate for ln in self.lines if ln.net_fob_foreign > 0}
        return rates.pop() if len(rates) == 1 else None

    @property
    def unrealized_fx_egp(self) -> Optional[float]:
        if not self.mark_to_market:
            return None
        return round(sum(m.unrealized_fx_egp for m in self.mark_to_market), 2)


# ── Pure core ───────────────────────────────────────────────────────────────────

def net_fob_foreign(gross_amount: float, discount_amount: float = 0.0, financing_markup_amount: float = 0.0,
                    invoice_no: Optional[str] = None) -> float:
    """Net goods value of an invoice: gross - commercial discount - financing markup (all >= 0, net >= 0)."""
    gross = float(gross_amount or 0.0)
    discount = float(discount_amount or 0.0)
    markup = float(financing_markup_amount or 0.0)
    if gross < 0 or discount < 0 or markup < 0 or gross - discount - markup < -0.005:
        raise coded_error(
            422,
            FOB_NET_VALUE_INVALID,
            f"قيمة الفوب الصافية للفاتورة {invoice_no or '-'} غير صحيحة: الخصم وهامش التمويل لا يجوز أن يكونا "
            f"سالبين أو أن يتجاوزا إجمالي الفاتورة.",
            invoice_no=invoice_no,
            gross_amount=gross,
            discount_amount=discount,
            financing_markup_amount=markup,
        )
    return round(max(0.0, gross - discount - markup), 2)


def _invoice_key(inv: FobInvoiceInput) -> Tuple[str, str]:
    return ((inv.invoice_no or "").strip().upper(), (inv.currency or "").strip().upper())


def dedupe_invoice_inputs(inputs: Sequence[FobInvoiceInput]) -> Tuple[List[FobInvoiceInput], List[str]]:
    """Anti-duplication guard: an invoice number recorded twice in the same currency counts once (first kept)."""
    seen: set = set()
    kept: List[FobInvoiceInput] = []
    duplicates: List[str] = []
    for inv in inputs:
        key = _invoice_key(inv)
        if key[0] and key in seen:
            duplicates.append(inv.invoice_no)
            continue
        seen.add(key)
        kept.append(inv)
    return kept, duplicates


@dataclass
class _AnchorPool:
    foreign: float = 0.0
    egp: float = 0.0
    remaining: float = 0.0
    last_date: Optional[date] = None
    sources: set = field(default_factory=set)

    @property
    def rate(self) -> float:
        return self.egp / self.foreign if self.foreign > 0 else 0.0

    @property
    def source(self) -> str:
        return next(iter(self.sources)) if len(self.sources) == 1 else FX_SOURCE_MIXED


def build_anchor_pools(events: Iterable[FxAnchorEvent]) -> Dict[str, _AnchorPool]:
    """Weighted anchor rate per currency (sum EGP / sum foreign of the events)."""
    pools: Dict[str, _AnchorPool] = {}
    for ev in events:
        ccy = (ev.currency or "").strip().upper()
        if not ccy or ccy == "EGP" or ev.foreign_amount <= 0 or ev.egp_amount <= 0:
            continue
        pool = pools.setdefault(ccy, _AnchorPool())
        pool.foreign += float(ev.foreign_amount)
        pool.egp += float(ev.egp_amount)
        pool.remaining += float(ev.foreign_amount)
        pool.sources.add(ev.source)
        if ev.event_date and (pool.last_date is None or ev.event_date > pool.last_date):
            pool.last_date = ev.event_date
    return pools


def value_invoice(inv: FobInvoiceInput, pool: Optional[_AnchorPool]) -> FobInvoiceValuation:
    """Values one invoice; consumes the covered foreign amount from ``pool``."""
    ccy = (inv.currency or "EGP").strip().upper()
    net = net_fob_foreign(inv.gross_amount, inv.discount_amount, inv.financing_markup_amount, inv.invoice_no)
    markup = round(float(inv.financing_markup_amount or 0.0), 2)
    payable = round(net + markup, 2)

    if ccy == "EGP":
        anchored, anchor_rate, fallback, applied = 0.0, None, 1.0, 1.0
        payable_egp = payable
        source, rate_date = FX_SOURCE_LOCAL_CURRENCY, inv.invoice_date
    else:
        fallback = float(inv.fallback_rate)
        anchored = round(min(pool.remaining, payable), 2) if (pool and pool.remaining > 0) else 0.0
        anchor_rate = pool.rate if pool and pool.foreign > 0 else None
        if pool and anchored > 0:
            pool.remaining = max(0.0, pool.remaining - anchored)
        if anchored <= 0:
            applied = fallback
            payable_egp = round(payable * fallback, 2)
            source, rate_date = inv.fallback_source, inv.invoice_date
        elif anchored >= payable:
            applied = anchor_rate
            payable_egp = round(payable * anchor_rate, 2)
            source, rate_date = pool.source, pool.last_date
        else:
            payable_egp = round(anchored * anchor_rate + (payable - anchored) * fallback, 2)
            applied = payable_egp / payable
            source, rate_date = FX_SOURCE_MIXED, pool.last_date

    markup_egp = round(payable_egp * markup / payable, 2) if payable > 0 and markup > 0 else 0.0
    return FobInvoiceValuation(
        invoice_no=inv.invoice_no,
        invoice_date=inv.invoice_date,
        currency=ccy,
        gross_amount=round(float(inv.gross_amount or 0.0), 2),
        discount_amount=round(float(inv.discount_amount or 0.0), 2),
        financing_markup_amount=markup,
        net_fob_foreign=net,
        payable_foreign=payable,
        anchored_foreign=anchored,
        anchor_rate=round(anchor_rate, 6) if anchor_rate else None,
        fallback_rate=fallback,
        applied_rate=round(applied, 6),
        payable_egp=payable_egp,
        net_fob_egp=round(payable_egp - markup_egp, 2),
        financing_markup_egp=markup_egp,
        rate_source=source,
        rate_date=rate_date,
    )


def value_fob_invoices(
    inputs: Sequence[FobInvoiceInput],
    events: Iterable[FxAnchorEvent] = (),
) -> Tuple[List[FobInvoiceValuation], List[str]]:
    """Net FOB per invoice with the FX anchor applied in invoice order. Returns (lines, duplicate numbers)."""
    kept, duplicates = dedupe_invoice_inputs(inputs)
    pools = build_anchor_pools(events)
    lines = [value_invoice(inv, pools.get((inv.currency or "").strip().upper())) for inv in kept]
    return lines, duplicates


def apply_customs_rates(lines: Sequence[FobInvoiceValuation], customs_rates: Dict[str, Optional[float]]) -> None:
    """Customs base per line: net FOB (financing markup excluded) x the customs rate of the declaration date."""
    for ln in lines:
        rate = 1.0 if ln.currency == "EGP" else customs_rates.get(ln.currency)
        ln.customs_rate = rate
        ln.customs_value_egp = round(ln.net_fob_foreign * rate, 2) if rate else None


def mark_to_market(
    lines: Sequence[FobInvoiceValuation], current_rates: Dict[str, Optional[float]], as_of: date
) -> List[MarkToMarketExposure]:
    """Unrealized revaluation of the open (not anchored) payable per currency: open x (current - booked)."""
    open_by_ccy: Dict[str, Tuple[float, float]] = {}
    for ln in lines:
        if ln.currency == "EGP":
            continue
        open_fc = round(ln.payable_foreign - ln.anchored_foreign, 2)
        if open_fc <= 0:
            continue
        fc, egp = open_by_ccy.get(ln.currency, (0.0, 0.0))
        open_by_ccy[ln.currency] = (fc + open_fc, egp + open_fc * ln.fallback_rate)
    exposures: List[MarkToMarketExposure] = []
    for ccy, (fc, booked_egp) in sorted(open_by_ccy.items()):
        current = current_rates.get(ccy)
        if not current:
            continue
        booked_rate = booked_egp / fc
        exposures.append(MarkToMarketExposure(
            currency=ccy,
            open_foreign=round(fc, 2),
            booked_rate=round(booked_rate, 6),
            current_rate=float(current),
            as_of=as_of,
            unrealized_fx_egp=round(fc * float(current) - booked_egp, 2),
        ))
    return exposures


def ensure_no_fob_double_count(ledger_rows: Sequence[Any], valuation: FobValuation) -> None:
    """Zero double-counting guard: the ledger holds the goods value once per invoice and its goods / markup totals
    equal the single valuation. ``ledger_rows`` are aggregated invoice rows (category, invoice_no, amount_egp)."""
    goods = [r for r in ledger_rows if getattr(r, "category", None) == GOODS_CATEGORY]
    markup = [r for r in ledger_rows if getattr(r, "category", None) == FINANCING_MARKUP_CATEGORY]
    goods_keys = [(r.invoice_no, r.currency) for r in goods]
    goods_total = round(sum(float(r.amount_egp or 0.0) for r in goods), 2)
    markup_total = round(sum(float(r.amount_egp or 0.0) for r in markup), 2)
    if (
        len(goods_keys) != len(set(goods_keys))
        or abs(goods_total - valuation.fob_total_egp) > MONEY_TOLERANCE_EGP
        or abs(markup_total - valuation.financing_markup_egp) > MONEY_TOLERANCE_EGP
    ):
        raise coded_error(
            status.HTTP_409_CONFLICT,
            FOB_DOUBLE_COUNT_DETECTED,
            "تم رصد تكرار في احتساب قيمة البضاعة (FOB) في تسوية الملف: قيمة الفوب يجب أن تُحتسب مرة واحدة فقط.",
            import_file_id=valuation.import_file_id,
            ledger_goods_egp=goods_total,
            valuation_fob_egp=valuation.fob_total_egp,
            ledger_markup_egp=markup_total,
            valuation_markup_egp=valuation.financing_markup_egp,
        )


# ── Database resolution ─────────────────────────────────────────────────────────

def _float(value: Any) -> float:
    try:
        return float(value or 0.0)
    except (TypeError, ValueError):
        return 0.0


def invoice_fallback_rate(inv: Dict[str, Any], currency: str, fx: SettlementFx) -> Tuple[float, str]:
    """Stored invoice rate (1.0 on a foreign currency means "not set"), else the commercial rate on the invoice
    date (409 SETTLEMENT_FX_RATE_MISSING when none)."""
    if currency == "EGP":
        return 1.0, FX_SOURCE_LOCAL_CURRENCY
    stored = _float(inv.get("exchange_rate"))
    if stored > 0 and stored != 1.0:
        return stored, FX_SOURCE_INVOICE_RATE
    return fx.rate(currency, _as_date(inv.get("invoice_date"))), FX_SOURCE_COMMERCIAL_RATE


def fob_invoice_inputs(imp: ImportFile, fx: SettlementFx) -> Tuple[List[FobInvoiceInput], str]:
    """Commercial invoices of the file (``invoices_data``), else the estimated cost as one provisional line."""
    inputs: List[FobInvoiceInput] = []
    invoices = imp.invoices_data if isinstance(imp.invoices_data, list) else []
    default_ccy: Optional[str] = None
    for idx, inv in enumerate(invoices):
        if not isinstance(inv, dict):
            continue
        inv_no = str(inv.get("invoice_no") or inv.get("invoice_number") or f"COMM-{imp.import_file_code}-{idx+1}")
        gross = _float(inv.get("amount") or inv.get("total_amount") or inv.get("total_fob"))
        raw_ccy = inv.get("currency")
        if gross > 0:
            if not raw_ccy or not str(raw_ccy).strip():
                raise currency_missing_error("Commercial Invoice", inv_no)
            ccy = str(raw_ccy).strip().upper()
            default_ccy = default_ccy or ccy
        else:
            ccy = str(raw_ccy).strip().upper() if raw_ccy else (default_ccy or "EGP")
        if ccy == "EGP":
            rate, source = _float(inv.get("exchange_rate")) or 1.0, FX_SOURCE_LOCAL_CURRENCY
        else:
            rate, source = invoice_fallback_rate(inv, ccy, fx)
        inputs.append(FobInvoiceInput(
            invoice_no=inv_no,
            currency=ccy,
            gross_amount=gross,
            fallback_rate=rate,
            fallback_source=source,
            invoice_date=_as_date(inv.get("invoice_date")),
            discount_amount=_float(inv.get("discount_amount")),
            financing_markup_amount=_float(inv.get("financing_markup_amount")),
        ))
    if inputs:
        return inputs, BASIS_INVOICE

    if (imp.estimated_cost or 0) > 0:
        if not imp.estimated_cost_currency or not str(imp.estimated_cost_currency).strip():
            raise currency_missing_error("Import File Estimated Cost", imp.import_file_code)
        ccy = str(imp.estimated_cost_currency).strip().upper()
        opening = _as_date(imp.file_opening_date)
        rate = 1.0 if ccy == "EGP" else fx.rate(ccy, opening)
        inputs.append(FobInvoiceInput(
            invoice_no=f"COMM-{imp.import_file_code}",
            currency=ccy,
            gross_amount=float(imp.estimated_cost),
            fallback_rate=rate,
            fallback_source=FX_SOURCE_LOCAL_CURRENCY if ccy == "EGP" else FX_SOURCE_COMMERCIAL_RATE,
            invoice_date=opening,
        ))
        return inputs, BASIS_ESTIMATE
    return inputs, BASIS_NONE


def collect_fx_anchor_events(db: Session, imp: ImportFile) -> List[FxAnchorEvent]:
    """Anchor events of the file. Per currency: the FX bookings of the file's active finance instrument when any
    (their booking rate pairs with the Realized FX Variance rows), else the paid payment requests (bank debit)."""
    from modules.financial_approval.model import PaymentRequestSession
    from modules.trade_finance.model import ImportFinanceInstrument

    term = (imp.payment_term or "").upper() or None
    instrument_events: List[FxAnchorEvent] = []
    instruments = (
        db.query(ImportFinanceInstrument)
        .filter(
            ImportFinanceInstrument.import_file_id == imp.import_file_id,
            ImportFinanceInstrument.is_active == True,  # noqa: E712
            ImportFinanceInstrument.status != "CANCELLED",
        )
        .order_by(ImportFinanceInstrument.id.asc())
        .all()
    )
    for inst in instruments:
        source = PATHWAY_ANCHOR_SOURCE.get((inst.instrument_type or "").upper(), FX_SOURCE_LC_MARGIN_COVER)
        for rec in inst.fx_records:
            foreign = _float(rec.original_amount)
            booked = _float(rec.booking_total_egp) or round(foreign * _float(rec.booking_rate), 2)
            if not rec.is_active or foreign <= 0 or booked <= 0:
                continue
            instrument_events.append(FxAnchorEvent(
                currency=(rec.foreign_currency or "").upper(), foreign_amount=foreign, egp_amount=booked,
                event_date=rec.booking_date, source=source, reference=inst.instrument_number,
            ))

    covered = {ev.currency for ev in instrument_events}
    request_source = PATHWAY_ANCHOR_SOURCE.get(term or "", FX_SOURCE_SWIFT_REMITTANCE)
    request_events: List[FxAnchorEvent] = []
    paid_requests = (
        db.query(PaymentRequestSession)
        .filter(
            PaymentRequestSession.import_file_id == imp.import_file_id,
            PaymentRequestSession.is_active == True,  # noqa: E712
            PaymentRequestSession.paid_amount_egp.isnot(None),
        )
        .order_by(PaymentRequestSession.payment_id.asc())
        .all()
    )
    for req in paid_requests:
        if (req.status or "").lower() != "paid":
            continue
        ccy = (req.swift_transferred_currency or req.currency_code or "").strip().upper()
        foreign = _float(req.swift_transferred_amount if req.swift_transferred_amount is not None else req.requested_amount)
        if not ccy or ccy in covered or foreign <= 0:
            continue
        request_events.append(FxAnchorEvent(
            currency=ccy, foreign_amount=foreign, egp_amount=_float(req.paid_amount_egp),
            event_date=req.swift_receipt_date, source=request_source,
            reference=req.swift_reference_no or req.payment_code,
        ))
    return instrument_events + request_events


def declaration_date_of(db: Session, imp: ImportFile) -> Optional[date]:
    """Form 46 date of the file (ImportFile sync, else the active clearance record)."""
    if imp.form46_date:
        return _as_date(imp.form46_date)
    from modules.customs_clearance.model import CustomsClearanceRecord

    rec = (
        db.query(CustomsClearanceRecord)
        .filter(
            CustomsClearanceRecord.import_file_id == imp.import_file_id,
            CustomsClearanceRecord.is_active == True,  # noqa: E712
            CustomsClearanceRecord.declaration_46_date.isnot(None),
        )
        .order_by(CustomsClearanceRecord.customs_clearance_id.desc())
        .first()
    )
    return _as_date(rec.declaration_46_date) if rec else None


def resolve_fob_valuation(
    db: Session,
    import_file_id: int,
    fx: Optional[SettlementFx] = None,
    as_of: Optional[date] = None,
) -> FobValuation:
    """The single net FOB valuation of an import file (goods value, FX anchor, customs base, Open Account MTM)."""
    imp = require_active(db, ImportFile, import_file_id, IMPORT_FILE_LABEL_AR, status_code=404)
    fx = fx or SettlementFx(db, "commercial")
    inputs, basis = fob_invoice_inputs(imp, fx)
    events = collect_fx_anchor_events(db, imp) if inputs else []
    lines, duplicates = value_fob_invoices(inputs, events)
    valuation = FobValuation(
        import_file_id=imp.import_file_id,
        basis=basis,
        payment_term=imp.payment_term,
        lines=lines,
        duplicates_ignored=duplicates,
    )
    for inv_no in duplicates:
        valuation.messages.append(_message(FOB_DUPLICATE_INVOICE_IGNORED, invoice_no=inv_no))

    # Customs base: customs rate in force on the declaration date (never today's rate for a past declaration).
    decl_date = declaration_date_of(db, imp)
    valuation.declaration_date = decl_date
    foreign_ccys = sorted({ln.currency for ln in lines if ln.currency != "EGP" and ln.net_fob_foreign > 0})
    if decl_date is None:
        if foreign_ccys:
            valuation.messages.append(_message(FOB_CUSTOMS_DATE_PENDING, severity="info"))
        apply_customs_rates(lines, {})
    else:
        customs_fx = SettlementFx(db, "customs")
        rates: Dict[str, Optional[float]] = {}
        for ccy in foreign_ccys:
            rates[ccy] = customs_fx.rate_or_none(ccy, decl_date)
            if rates[ccy] is None:
                valuation.messages.append(_message(FOB_CUSTOMS_RATE_MISSING, currency=ccy,
                                                   on_date=decl_date.isoformat()))
        apply_customs_rates(lines, rates)

    # Open Account: unrealized revaluation of the open payable until the maturity settlement.
    if (imp.payment_term or "").upper() == "OPEN_ACCOUNT":
        day = as_of or cairo_today()
        current: Dict[str, Optional[float]] = {}
        for ccy in sorted({ln.currency for ln in lines if ln.currency != "EGP"}):
            current[ccy] = fx.rate_or_none(ccy, day)
            if current[ccy] is None:
                valuation.messages.append(_message(FOB_MTM_RATE_MISSING, currency=ccy, on_date=day.isoformat()))
        valuation.mark_to_market = mark_to_market(lines, current, day)
    return valuation


def snapshot_fob_valuation(imp: ImportFile, valuation: FobValuation, actor: str) -> None:
    """Persists the valuation on the import file (one snapshot per file, overwritten by each valuation event)."""
    imp.fob_currency = valuation.fob_currency
    imp.fob_foreign_amount = valuation.fob_foreign_amount
    imp.fob_exchange_rate = valuation.fob_exchange_rate
    imp.fob_total_egp = valuation.fob_total_egp
    imp.financing_markup_amount = valuation.financing_markup_foreign
    imp.financing_markup_egp = valuation.financing_markup_egp
    imp.fob_rate_source = valuation.rate_source
    imp.fob_rate_date = valuation.rate_date
    imp.fob_customs_exchange_rate = valuation.customs_exchange_rate
    imp.fob_customs_value_egp = valuation.customs_value_egp
    imp.fob_unrealized_fx_egp = valuation.unrealized_fx_egp
    imp.fob_valued_at = datetime.now(timezone.utc)
    imp.fob_valued_by = actor
    imp.updated_by = actor


def fob_valuation_response(valuation: FobValuation, snapshot_at: Optional[datetime] = None) -> FobValuationResponse:
    return FobValuationResponse(
        import_file_id=valuation.import_file_id,
        basis=valuation.basis,
        payment_term=valuation.payment_term,
        fob_currency=valuation.fob_currency,
        fob_foreign_amount=valuation.fob_foreign_amount,
        fob_exchange_rate=valuation.fob_exchange_rate,
        fob_total_egp=valuation.fob_total_egp,
        financing_markup_amount=valuation.financing_markup_foreign,
        financing_markup_egp=valuation.financing_markup_egp,
        discount_amount=valuation.discount_foreign,
        payable_total_egp=valuation.payable_total_egp,
        rate_source=valuation.rate_source,
        rate_date=valuation.rate_date,
        declaration_date=valuation.declaration_date,
        customs_exchange_rate=valuation.customs_exchange_rate,
        customs_value_egp=valuation.customs_value_egp,
        unrealized_fx_egp=valuation.unrealized_fx_egp,
        duplicates_ignored=list(valuation.duplicates_ignored),
        lines=[FobInvoiceValuationSchema(**asdict(ln)) for ln in valuation.lines],
        mark_to_market=[MarkToMarketExposureSchema(**asdict(m)) for m in valuation.mark_to_market],
        messages=list(valuation.messages),
        snapshot_at=snapshot_at,
    )


def get_fob_valuation_service(db: Session, import_file_id: int) -> FobValuationResponse:
    """Read-only valuation (nothing persisted)."""
    imp = require_active(db, ImportFile, import_file_id, IMPORT_FILE_LABEL_AR, status_code=404)
    return fob_valuation_response(resolve_fob_valuation(db, import_file_id), imp.fob_valued_at)


def revalue_fob_valuation_service(db: Session, import_file_id: int, actor: str) -> FobValuationResponse:
    """Values the file now and persists the snapshot (FX anchor refresh, Open Account mark-to-market)."""
    imp = require_active(db, ImportFile, import_file_id, IMPORT_FILE_LABEL_AR, status_code=404)
    ensure_file_open(imp)
    valuation = resolve_fob_valuation(db, import_file_id)
    snapshot_fob_valuation(imp, valuation, actor)
    db.commit()
    db.refresh(imp)
    return fob_valuation_response(valuation, imp.fob_valued_at)


__all__ = [
    "fob_valuation_response",
    "get_fob_valuation_service",
    "revalue_fob_valuation_service",
    "GOODS_CATEGORY",
    "GOODS_SOURCE_MODULE",
    "FINANCING_MARKUP_CATEGORY",
    "FX_SOURCES",
    "FxAnchorEvent",
    "FobInvoiceInput",
    "FobInvoiceValuation",
    "FobValuation",
    "MarkToMarketExposure",
    "net_fob_foreign",
    "dedupe_invoice_inputs",
    "build_anchor_pools",
    "value_invoice",
    "value_fob_invoices",
    "apply_customs_rates",
    "mark_to_market",
    "ensure_no_fob_double_count",
    "fob_invoice_inputs",
    "collect_fx_anchor_events",
    "declaration_date_of",
    "resolve_fob_valuation",
    "snapshot_fob_valuation",
]
