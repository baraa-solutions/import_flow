"""
Foreign Vendor Multi-Currency Sub-Ledger, Credit Limit Governance & 30/60/90 Aging (Trello GzFff0Pc).

The supplier account is kept per currency (never netted across currencies) and is generated from the existing
sources of truth, so nothing is entered twice:

* CREDIT ``INVOICE_BILLED``  one entry per commercial invoice of the supplier's import files, taken from the single
  net FOB valuation engine (``financial_settlement.fob_valuation_service.resolve_fob_valuation``): amount = the
  invoice *payable* (net FOB + supplier financing markup), EGP = the engine's anchored ``payable_egp``. A file that
  only has an estimated cost (basis ESTIMATE) bills nothing: an estimate is not a liability. Duplicated invoices
  are already removed by the engine, so the sub-ledger can never count an invoice twice.
* DEBIT  ``ADVANCE_PAID``    a paid payment request on the ADVANCE_PAYMENT pathway (or typed "Advance Payment").
* DEBIT  ``PAYMENT_SETTLED`` any other paid payment request, and an LC / CAD instrument settled by the bank
  (status SETTLED) for the part of the file payable not already covered by paid requests (no double debit).
* MEMO   ``LC_COMMITTED`` / ``CAD_ACCEPTED`` the bank commitment of an issued LC / accepted CAD. Memo entries are
  shown on the statement but never change the balance (the liability is the invoice; the commitment is how it
  will be paid).

Balance (per currency) = invoices billed - payments. A negative balance is an unapplied advance (the supplier
owes goods). Payments are allocated to invoices of the same currency: first to the invoices of their own import
file, then FIFO by due date. Allocation gives each invoice its open amount, used by the aging.

Due date of an invoice, by the file's exclusive payment pathway (``import_files.payment_term``):

* ADVANCE_PAYMENT  invoice date (the goods are paid before shipment; anything still open is overdue).
* LC               LC shipment deadline + presentation period when known, else LC expiry, else invoice date.
* CAD              CAD instrument expiry (maturity of the accepted draft), else invoice date (D/P at sight).
* OPEN_ACCOUNT     invoice date + credit days read from the supplier payment terms ("Net 60", "90 days").
* not set          invoice date.

Aging buckets on days past due at ``as_of``: CURRENT (<= 0), 1_30, 31_60, 61_90, OVER_90 (> 90).

Credit limit governance: ``suppliers.credit_limit`` <= 0 means no limit. Utilization = the sum of the positive
per-currency balances converted to the limit currency at today's commercial rates (an advance in one currency
does not free credit in another). A new commitment (purchase order) whose projected utilization exceeds the limit
is refused with 409 ``SUPPLIER_CREDIT_LIMIT_EXCEEDED`` under policy BLOCK, unless an ADMIN gives an override
reason (recorded in ``supplier_credit_overrides``); under policy WARN it goes through with the warning.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone
from typing import Callable, Dict, List, Optional, Sequence, Tuple

from fastapi import HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from modules.common.sequence_generator import generate_reference_code

from .model import Supplier, SupplierCreditOverride, SupplierLedgerEntry
from .validators import (
    SUPPLIER_CREDIT_LIMIT_EXCEEDED,
    SUPPLIER_CREDIT_OVERRIDE_FORBIDDEN,
    supplier_coded_error,
    validate_credit_limit_settings,
)

# Entry types / directions / statuses.
ADVANCE_PAID = "ADVANCE_PAID"
LC_COMMITTED = "LC_COMMITTED"
CAD_ACCEPTED = "CAD_ACCEPTED"
INVOICE_BILLED = "INVOICE_BILLED"
PAYMENT_SETTLED = "PAYMENT_SETTLED"
CREDIT = "CREDIT"
DEBIT = "DEBIT"
MEMO = "MEMO"
STATUS_OPEN = "OPEN"
STATUS_PARTIAL = "PARTIAL"
STATUS_SETTLED = "SETTLED"
STATUS_UNAPPLIED = "UNAPPLIED"

# Aging buckets.
BUCKET_CURRENT = "CURRENT"
BUCKET_1_30 = "1_30"
BUCKET_31_60 = "31_60"
BUCKET_61_90 = "61_90"
BUCKET_OVER_90 = "OVER_90"
AGING_BUCKETS: Tuple[str, ...] = (BUCKET_CURRENT, BUCKET_1_30, BUCKET_31_60, BUCKET_61_90, BUCKET_OVER_90)

# Credit decisions.
DECISION_NO_LIMIT = "NO_LIMIT"
DECISION_WITHIN_LIMIT = "WITHIN_LIMIT"
DECISION_WARN = "WARN"
DECISION_BLOCK = "BLOCK"
DECISION_OVERRIDDEN = "OVERRIDDEN"
POLICY_WARN = "WARN"
POLICY_BLOCK = "BLOCK"

MONEY_EPS = 0.005
LEDGER_CODE_PREFIX = "SLE"
WARNING_FILE_NOT_VALUED = "SUPPLIER_LEDGER_FILE_NOT_VALUED"

_DIRECTION_ORDER = {CREDIT: 0, DEBIT: 1, MEMO: 2}
_CREDIT_DAYS_RES = (
    re.compile(r"(?:net|n|o/?a|open\s*account)\s*[-:]?\s*(\d{1,3})\b", re.IGNORECASE),
    re.compile(r"\b(\d{1,3})\s*(?:days?|d\b|يوم|يوما|يومًا|أيام|ايام)", re.IGNORECASE),
)


# ── Value objects ───────────────────────────────────────────────────────────────

@dataclass
class LedgerDraft:
    """One supplier account movement derived from a source row (persisted as ``SupplierLedgerEntry``)."""

    source_key: str
    entry_type: str
    direction: str
    currency: str
    amount_fx: float
    amount_egp: float
    entry_date: date
    due_date: Optional[date] = None
    import_file_id: Optional[int] = None
    payment_id: Optional[int] = None
    finance_instrument_id: Optional[int] = None
    payment_pathway: Optional[str] = None
    reference: Optional[str] = None
    description: Optional[str] = None
    open_amount_fx: float = 0.0
    status: str = STATUS_OPEN
    entry_code: Optional[str] = None  # set once persisted

    @property
    def exchange_rate(self) -> Optional[float]:
        if self.amount_fx <= 0:
            return None
        return round(self.amount_egp / self.amount_fx, 6)


@dataclass
class StatementLine:
    entry: LedgerDraft
    balance_fx: float
    balance_egp: float


@dataclass
class CurrencyBalance:
    currency: str
    billed_fx: float = 0.0
    paid_fx: float = 0.0
    balance_fx: float = 0.0
    open_payable_fx: float = 0.0
    unapplied_fx: float = 0.0
    open_commitments_fx: float = 0.0
    book_balance_egp: float = 0.0
    current_rate: Optional[float] = None
    current_balance_egp: Optional[float] = None


@dataclass
class AgingItem:
    entry: LedgerDraft
    days_past_due: int
    bucket: str


@dataclass
class CurrencyAging:
    currency: str
    buckets: Dict[str, float] = field(default_factory=lambda: {b: 0.0 for b in AGING_BUCKETS})
    total_open_fx: float = 0.0
    unapplied_fx: float = 0.0
    current_rate: Optional[float] = None
    total_open_egp: Optional[float] = None
    items: List[AgingItem] = field(default_factory=list)


@dataclass
class CreditCheck:
    has_limit: bool
    currency: str
    policy: str
    limit_amount: float
    utilization_amount: float
    requested_amount: float
    projected_amount: float
    available_amount: Optional[float]
    utilization_pct: Optional[float]
    exceeded: bool
    allowed: bool
    decision: str


# ── Pure core ───────────────────────────────────────────────────────────────────

def _r(value: float) -> float:
    return round(float(value or 0.0), 2)


def parse_credit_days(payment_terms: Optional[str]) -> int:
    """Credit days of an Open Account term ("Net 60", "OA 90", "60 days", "60 يوم"); 0 when none is stated."""
    text = (payment_terms or "").strip()
    for pattern in _CREDIT_DAYS_RES:
        match = pattern.search(text)
        if match:
            return int(match.group(1))
    return 0


def invoice_due_date(
    pathway: Optional[str],
    invoice_date: date,
    credit_days: int = 0,
    lc_shipment_deadline: Optional[date] = None,
    lc_presentation_days: Optional[int] = None,
    instrument_expiry: Optional[date] = None,
) -> date:
    """Due date of an invoice by payment pathway (see the module docstring)."""
    term = (pathway or "").upper()
    if term == "LC":
        if lc_shipment_deadline is not None:
            return lc_shipment_deadline + timedelta(days=int(lc_presentation_days or 0))
        return instrument_expiry or invoice_date
    if term == "CAD":
        return instrument_expiry or invoice_date
    if term == "OPEN_ACCOUNT":
        return invoice_date + timedelta(days=max(0, int(credit_days or 0)))
    return invoice_date


def aging_bucket(days_past_due: int) -> str:
    """CURRENT (<= 0), 1_30, 31_60, 61_90, OVER_90 (> 90)."""
    if days_past_due <= 0:
        return BUCKET_CURRENT
    if days_past_due <= 30:
        return BUCKET_1_30
    if days_past_due <= 60:
        return BUCKET_31_60
    if days_past_due <= 90:
        return BUCKET_61_90
    return BUCKET_OVER_90


def _invoice_sort_key(d: LedgerDraft) -> tuple:
    return (d.due_date or d.entry_date, d.entry_date, d.source_key)


def allocate_payments(drafts: Sequence[LedgerDraft]) -> None:
    """Sets ``open_amount_fx`` / ``status`` of every draft. Per currency, each payment (by date) settles the
    invoices of its own import file first, then the oldest-due invoices; what is left stays UNAPPLIED."""
    invoices_by_ccy: Dict[str, List[LedgerDraft]] = {}
    payments_by_ccy: Dict[str, List[LedgerDraft]] = {}
    for d in drafts:
        if d.direction == CREDIT:
            d.open_amount_fx = _r(d.amount_fx)
            invoices_by_ccy.setdefault(d.currency, []).append(d)
        elif d.direction == DEBIT:
            payments_by_ccy.setdefault(d.currency, []).append(d)
        else:  # MEMO: open while the commitment is open; caller sets SETTLED when the instrument is settled
            d.open_amount_fx = 0.0 if d.status == STATUS_SETTLED else _r(d.amount_fx)

    for ccy, payments in payments_by_ccy.items():
        invoices = sorted(invoices_by_ccy.get(ccy, []), key=_invoice_sort_key)
        for pay in sorted(payments, key=lambda p: (p.entry_date, p.source_key)):
            remaining = _r(pay.amount_fx)
            own = [i for i in invoices if pay.import_file_id is not None and i.import_file_id == pay.import_file_id]
            others = [i for i in invoices if i not in own]
            for inv in own + others:
                if remaining <= MONEY_EPS:
                    break
                take = min(remaining, inv.open_amount_fx)
                if take <= MONEY_EPS:
                    continue
                inv.open_amount_fx = _r(inv.open_amount_fx - take)
                remaining = _r(remaining - take)
            pay.open_amount_fx = remaining if remaining > MONEY_EPS else 0.0
            pay.status = STATUS_UNAPPLIED if pay.open_amount_fx > 0 else STATUS_SETTLED

    for invoices in invoices_by_ccy.values():
        for inv in invoices:
            if inv.open_amount_fx <= MONEY_EPS:
                inv.open_amount_fx, inv.status = 0.0, STATUS_SETTLED
            elif inv.open_amount_fx < _r(inv.amount_fx) - MONEY_EPS:
                inv.status = STATUS_PARTIAL
            else:
                inv.status = STATUS_OPEN


def _signed(d: LedgerDraft) -> Tuple[float, float]:
    if d.direction == CREDIT:
        return d.amount_fx, d.amount_egp
    if d.direction == DEBIT:
        return -d.amount_fx, -d.amount_egp
    return 0.0, 0.0


def statement_sort_key(d: LedgerDraft) -> tuple:
    return (d.entry_date, _DIRECTION_ORDER.get(d.direction, 9), d.source_key)


def build_statement(drafts: Sequence[LedgerDraft]) -> Dict[str, List[StatementLine]]:
    """Statement of account per currency, chronological, with the running balance (memo lines carry it over)."""
    lines: Dict[str, List[StatementLine]] = {}
    running: Dict[str, Tuple[float, float]] = {}
    for d in sorted(drafts, key=statement_sort_key):
        fx, egp = running.get(d.currency, (0.0, 0.0))
        dfx, degp = _signed(d)
        fx, egp = _r(fx + dfx), _r(egp + degp)
        running[d.currency] = (fx, egp)
        lines.setdefault(d.currency, []).append(StatementLine(entry=d, balance_fx=fx, balance_egp=egp))
    return lines


def summarize_balances(
    drafts: Sequence[LedgerDraft], current_rates: Optional[Dict[str, Optional[float]]] = None,
) -> Dict[str, CurrencyBalance]:
    """Per-currency totals of allocated drafts; ``current_rates`` (ccy -> EGP rate) gives the EGP equivalent."""
    out: Dict[str, CurrencyBalance] = {}
    for d in drafts:
        b = out.setdefault(d.currency, CurrencyBalance(currency=d.currency))
        if d.direction == CREDIT:
            b.billed_fx = _r(b.billed_fx + d.amount_fx)
            b.open_payable_fx = _r(b.open_payable_fx + d.open_amount_fx)
            b.book_balance_egp = _r(b.book_balance_egp + d.amount_egp)
        elif d.direction == DEBIT:
            b.paid_fx = _r(b.paid_fx + d.amount_fx)
            b.unapplied_fx = _r(b.unapplied_fx + d.open_amount_fx)
            b.book_balance_egp = _r(b.book_balance_egp - d.amount_egp)
        else:
            b.open_commitments_fx = _r(b.open_commitments_fx + d.open_amount_fx)
    for b in out.values():
        b.balance_fx = _r(b.billed_fx - b.paid_fx)
        rate = 1.0 if b.currency == "EGP" else (current_rates or {}).get(b.currency)
        b.current_rate = rate
        b.current_balance_egp = _r(b.balance_fx * rate) if rate else None
    return out


def build_aging(
    drafts: Sequence[LedgerDraft], as_of: date, current_rates: Optional[Dict[str, Optional[float]]] = None,
) -> Dict[str, CurrencyAging]:
    """Open invoice amounts per currency in the 30/60/90 buckets, by days past due at ``as_of``."""
    out: Dict[str, CurrencyAging] = {}
    for d in drafts:
        if d.direction == DEBIT and d.open_amount_fx > 0:
            a = out.setdefault(d.currency, CurrencyAging(currency=d.currency))
            a.unapplied_fx = _r(a.unapplied_fx + d.open_amount_fx)
        if d.direction != CREDIT or d.open_amount_fx <= 0:
            continue
        a = out.setdefault(d.currency, CurrencyAging(currency=d.currency))
        days = (as_of - (d.due_date or d.entry_date)).days
        bucket = aging_bucket(days)
        a.buckets[bucket] = _r(a.buckets[bucket] + d.open_amount_fx)
        a.total_open_fx = _r(a.total_open_fx + d.open_amount_fx)
        a.items.append(AgingItem(entry=d, days_past_due=days, bucket=bucket))
    for a in out.values():
        a.items.sort(key=lambda it: -it.days_past_due)
        rate = 1.0 if a.currency == "EGP" else (current_rates or {}).get(a.currency)
        a.current_rate = rate
        a.total_open_egp = _r(a.total_open_fx * rate) if rate else None
    return out


def convert_amount(amount: float, from_ccy: str, to_ccy: str, rate_to_egp: Callable[[str], float]) -> float:
    """Cross conversion through EGP (``rate_to_egp`` returns the EGP rate of a currency; EGP is 1)."""
    if from_ccy == to_ccy:
        return float(amount)
    src = 1.0 if from_ccy == "EGP" else rate_to_egp(from_ccy)
    dst = 1.0 if to_ccy == "EGP" else rate_to_egp(to_ccy)
    return float(amount) * src / dst


def credit_utilization(
    balances: Dict[str, float], limit_currency: str, rate_to_egp: Callable[[str], float],
) -> float:
    """Sum of the positive per-currency balances in the limit currency (advances never offset other currencies)."""
    total = 0.0
    for ccy, bal in balances.items():
        if bal > MONEY_EPS:
            total += convert_amount(bal, ccy, limit_currency, rate_to_egp)
    return _r(total)


def evaluate_credit_limit(
    limit_amount: float, limit_currency: str, policy: str, utilization: float, requested: float,
) -> CreditCheck:
    """Credit decision for a new commitment of ``requested`` (in the limit currency)."""
    limit = _r(limit_amount)
    utilization, requested = _r(utilization), _r(max(0.0, requested))
    projected = _r(utilization + requested)
    policy = (policy or POLICY_BLOCK).upper()
    if limit <= 0:
        return CreditCheck(False, limit_currency, policy, 0.0, utilization, requested, projected, None, None,
                           False, True, DECISION_NO_LIMIT)
    exceeded = projected > limit + MONEY_EPS
    decision = DECISION_WITHIN_LIMIT if not exceeded else (DECISION_WARN if policy == POLICY_WARN else DECISION_BLOCK)
    return CreditCheck(
        has_limit=True,
        currency=limit_currency,
        policy=policy,
        limit_amount=limit,
        utilization_amount=utilization,
        requested_amount=requested,
        projected_amount=projected,
        available_amount=_r(limit - utilization),
        utilization_pct=round(utilization / limit * 100.0, 2),
        exceeded=exceeded,
        allowed=decision != DECISION_BLOCK,
        decision=decision,
    )


# ── Sources (database) ──────────────────────────────────────────────────────────

def _as_date(value) -> Optional[date]:
    from modules.financial_settlement.landed_cost_engine_service import _as_date as settlement_as_date

    return settlement_as_date(value)


def _today() -> date:
    from modules.financial_settlement.landed_cost_engine_service import cairo_today

    return cairo_today()


def _file_rate(lines, currency: str) -> Optional[float]:
    foreign = sum(ln.payable_foreign for ln in lines if ln.currency == currency)
    egp = sum(ln.payable_egp for ln in lines if ln.currency == currency)
    return egp / foreign if foreign > 0 else None


def _primary_instrument(instruments):
    live = [i for i in instruments if (i.status or "").upper() != "CANCELLED"]
    return live[0] if live else None


def _instrument_settlement_rate(inst, currency: str) -> Optional[float]:
    for rec in inst.fx_records or []:
        if not rec.is_active or (rec.foreign_currency or "").upper() != currency or not rec.original_amount:
            continue
        if rec.settlement_total_egp:
            return float(rec.settlement_total_egp) / float(rec.original_amount)
        if rec.booking_rate:
            return float(rec.booking_rate)
    return None


def _payment_drafts(db: Session, supplier_id: int, files_by_id: Dict[int, object]) -> List[LedgerDraft]:
    from modules.financial_approval.model import PaymentRequestSession
    from sqlalchemy import and_, or_

    file_ids = list(files_by_id.keys())
    cond = PaymentRequestSession.supplier_id == supplier_id
    if file_ids:
        cond = or_(cond, and_(PaymentRequestSession.supplier_id.is_(None),
                              PaymentRequestSession.import_file_id.in_(file_ids)))
    rows = (
        db.query(PaymentRequestSession)
        .filter(cond, PaymentRequestSession.is_active == True)  # noqa: E712
        .order_by(PaymentRequestSession.payment_id.asc())
        .all()
    )
    drafts: List[LedgerDraft] = []
    for req in rows:
        if (req.status or "").strip().lower() != "paid":
            continue
        ccy = (req.swift_transferred_currency or req.currency_code or "").strip().upper()
        amount = req.swift_transferred_amount if req.swift_transferred_amount is not None else req.requested_amount
        amount = float(amount or 0.0)
        if not ccy or amount <= 0:
            continue
        imp = files_by_id.get(req.import_file_id) if req.import_file_id else None
        pathway = (getattr(imp, "payment_term", None) or "").upper() or None
        is_advance = pathway == "ADVANCE_PAYMENT" or (req.payment_type or "").strip().lower().startswith("advance")
        egp = req.paid_amount_egp if req.paid_amount_egp is not None else req.requested_amount_egp
        drafts.append(LedgerDraft(
            source_key=f"PAY:{req.payment_id}",
            entry_type=ADVANCE_PAID if is_advance else PAYMENT_SETTLED,
            direction=DEBIT,
            currency=ccy,
            amount_fx=_r(amount),
            amount_egp=_r(egp),
            entry_date=_as_date(req.swift_receipt_date) or _as_date(req.request_date) or _today(),
            import_file_id=req.import_file_id,
            payment_id=req.payment_id,
            payment_pathway=pathway,
            reference=req.swift_reference_no or req.payment_code,
            description=req.title,
        ))
    return drafts


def collect_ledger_drafts(db: Session, supplier: Supplier) -> Tuple[List[LedgerDraft], List[dict]]:
    """All movements of the supplier from the sources of truth, allocated (open amounts / statuses set)."""
    from modules.financial_settlement.fob_valuation_service import BASIS_INVOICE, resolve_fob_valuation
    from modules.financial_settlement.landed_cost_engine_service import SettlementFx
    from modules.import_files.model import ImportFile
    from modules.trade_finance.model import ImportFinanceInstrument

    warnings: List[dict] = []
    fx = SettlementFx(db, "commercial")
    credit_days = parse_credit_days(supplier.payment_terms)
    files = (
        db.query(ImportFile)
        .filter(ImportFile.supplier_id == supplier.supplier_id, ImportFile.is_active == True)  # noqa: E712
        .order_by(ImportFile.import_file_id.asc())
        .all()
    )
    files_by_id = {f.import_file_id: f for f in files}
    drafts: List[LedgerDraft] = []
    payments = _payment_drafts(db, supplier.supplier_id, files_by_id)
    paid_by_file_ccy: Dict[Tuple[int, str], float] = {}
    for p in payments:
        if p.import_file_id is not None:
            key = (p.import_file_id, p.currency)
            paid_by_file_ccy[key] = paid_by_file_ccy.get(key, 0.0) + p.amount_fx
    drafts.extend(payments)

    for imp in files:
        pathway = (imp.payment_term or "").upper() or None
        instruments = (
            db.query(ImportFinanceInstrument)
            .filter(ImportFinanceInstrument.import_file_id == imp.import_file_id,
                    ImportFinanceInstrument.is_active == True)  # noqa: E712
            .order_by(ImportFinanceInstrument.id.asc())
            .all()
        )
        inst = _primary_instrument(instruments)
        try:
            valuation = resolve_fob_valuation(db, imp.import_file_id, fx=fx)
        except HTTPException as exc:  # e.g. a missing FX rate: report it, keep the rest of the account
            detail = exc.detail if isinstance(exc.detail, dict) else {"message": str(exc.detail)}
            warnings.append({"code": WARNING_FILE_NOT_VALUED, "import_file_id": imp.import_file_id,
                             "import_file_code": imp.import_file_code, "reason": detail.get("code") or "ERROR"})
            valuation = None
        lines = valuation.lines if valuation is not None and valuation.basis == BASIS_INVOICE else []

        payable_by_ccy: Dict[str, float] = {}
        for ln in lines:
            if ln.payable_foreign <= 0:
                continue
            inv_date = ln.invoice_date or _as_date(imp.file_opening_date) or _today()
            due = invoice_due_date(
                pathway, inv_date, credit_days,
                lc_shipment_deadline=getattr(inst, "shipment_deadline", None) if inst else None,
                lc_presentation_days=getattr(inst, "presentation_period_days", None) if inst else None,
                instrument_expiry=getattr(inst, "expiry_date", None) if inst else None,
            )
            payable_by_ccy[ln.currency] = payable_by_ccy.get(ln.currency, 0.0) + ln.payable_foreign
            drafts.append(LedgerDraft(
                source_key=f"INV:{imp.import_file_id}:{ln.currency}:{ln.invoice_no.strip().upper()}",
                entry_type=INVOICE_BILLED,
                direction=CREDIT,
                currency=ln.currency,
                amount_fx=_r(ln.payable_foreign),
                amount_egp=_r(ln.payable_egp),
                entry_date=inv_date,
                due_date=due,
                import_file_id=imp.import_file_id,
                payment_pathway=pathway,
                reference=ln.invoice_no,
                description=imp.import_file_code,
            ))

        for ins in instruments:
            itype = (ins.instrument_type or "").upper()
            istatus = (ins.status or "").upper()
            ccy = (ins.currency or "").upper()
            amount = float(ins.amount or 0.0)
            if itype not in ("LC", "CAD") or istatus in ("DRAFT", "CANCELLED") or not ccy or amount <= 0:
                continue
            if itype == "CAD" and istatus not in ("ACCEPTED", "SETTLED"):
                continue
            rate = _instrument_settlement_rate(ins, ccy) or _file_rate(lines, ccy) or fx.rate_or_none(ccy, ins.issue_date) or 0.0
            drafts.append(LedgerDraft(
                source_key=f"FIN:{ins.id}:COMMIT",
                entry_type=LC_COMMITTED if itype == "LC" else CAD_ACCEPTED,
                direction=MEMO,
                currency=ccy,
                amount_fx=_r(amount),
                amount_egp=_r(amount * rate),
                entry_date=_as_date(ins.issue_date) or _as_date(ins.created_at) or _today(),
                due_date=ins.expiry_date,
                import_file_id=imp.import_file_id,
                finance_instrument_id=ins.id,
                payment_pathway=pathway or itype,
                reference=ins.instrument_number,
                description=ins.issuing_bank,
                status=STATUS_SETTLED if istatus == "SETTLED" else STATUS_OPEN,
            ))
            if istatus != "SETTLED":
                continue
            # Bank settlement pays the supplier: debit only what paid requests have not already covered.
            settled = amount
            if ccy in payable_by_ccy:
                already = paid_by_file_ccy.get((imp.import_file_id, ccy), 0.0)
                settled = min(amount, max(0.0, payable_by_ccy[ccy] - already))
            if settled <= MONEY_EPS:
                continue
            drafts.append(LedgerDraft(
                source_key=f"FIN:{ins.id}:SETTLED",
                entry_type=PAYMENT_SETTLED,
                direction=DEBIT,
                currency=ccy,
                amount_fx=_r(settled),
                amount_egp=_r(settled * rate),
                entry_date=max((r.settlement_date for r in ins.fx_records or [] if r.is_active and r.settlement_date),
                               default=None) or _as_date(ins.updated_at) or _today(),
                import_file_id=imp.import_file_id,
                finance_instrument_id=ins.id,
                payment_pathway=pathway or itype,
                reference=ins.instrument_number,
                description=ins.issuing_bank,
            ))

    allocate_payments(drafts)
    return drafts, warnings


def current_rates_for(db: Session, currencies, on_date: Optional[date] = None) -> Dict[str, Optional[float]]:
    from modules.financial_settlement.landed_cost_engine_service import SettlementFx

    fx = SettlementFx(db, "commercial")
    return {c: (1.0 if c == "EGP" else fx.rate_or_none(c, on_date)) for c in sorted(set(currencies))}


# ── Persistence (materialized sub-ledger) ───────────────────────────────────────

def _draft_from_entry(e: SupplierLedgerEntry) -> LedgerDraft:
    return LedgerDraft(
        source_key=e.source_key, entry_type=e.entry_type, direction=e.direction, currency=e.currency,
        amount_fx=float(e.amount_fx or 0.0), amount_egp=float(e.amount_egp or 0.0), entry_date=e.entry_date,
        due_date=e.due_date, import_file_id=e.import_file_id, payment_id=e.payment_id,
        finance_instrument_id=e.finance_instrument_id, payment_pathway=e.payment_pathway, reference=e.reference,
        description=e.description, open_amount_fx=float(e.open_amount_fx or 0.0), status=e.status,
        entry_code=e.entry_code,
    )


_SYNC_FIELDS = (
    "entry_type", "direction", "currency", "amount_fx", "amount_egp", "entry_date", "due_date", "import_file_id",
    "payment_id", "finance_instrument_id", "payment_pathway", "reference", "description", "open_amount_fx", "status",
)


def _apply_draft(entry: SupplierLedgerEntry, d: LedgerDraft, actor: str) -> bool:
    changed = False
    for name in _SYNC_FIELDS:
        value = getattr(d, name)
        if getattr(entry, name) != value:
            setattr(entry, name, value)
            changed = True
    if entry.exchange_rate != d.exchange_rate:
        entry.exchange_rate = d.exchange_rate
        changed = True
    if not entry.is_active:
        entry.is_active, entry.deleted_at, entry.deleted_by = True, None, None
        changed = True
    if changed:
        entry.updated_by = actor
    return changed


def _sync_once(db: Session, supplier: Supplier, actor: str) -> Tuple[List[SupplierLedgerEntry], List[dict]]:
    from .repository import list_supplier_ledger_entries

    drafts, warnings = collect_ledger_drafts(db, supplier)
    existing = {e.source_key: e for e in list_supplier_ledger_entries(db, supplier.supplier_id, include_inactive=True)}
    next_num = int(generate_reference_code(db, SupplierLedgerEntry, LEDGER_CODE_PREFIX, id_field="entry_id")
                   .rsplit("-", 1)[1])
    seen = set()
    for d in drafts:
        seen.add(d.source_key)
        entry = existing.get(d.source_key)
        if entry is None:
            entry = SupplierLedgerEntry(
                entry_code=f"{LEDGER_CODE_PREFIX}-{next_num:06d}", supplier_id=supplier.supplier_id,
                source_key=d.source_key, is_active=True, created_by=actor, updated_by=actor,
            )
            next_num += 1
            _apply_draft(entry, d, actor)
            db.add(entry)
        else:
            _apply_draft(entry, d, actor)
    now = datetime.now(timezone.utc)
    for key, entry in existing.items():
        if key not in seen and entry.is_active:  # source gone (invoice removed, payment cancelled): soft delete
            entry.is_active, entry.deleted_at, entry.deleted_by, entry.updated_by = False, now, actor, actor
    db.flush()
    return list_supplier_ledger_entries(db, supplier.supplier_id), warnings


def sync_supplier_ledger(db: Session, supplier_id: int, actor: str = "system") -> Tuple[List[SupplierLedgerEntry], List[dict]]:
    """Rebuilds the supplier sub-ledger from the sources (idempotent upsert by ``source_key``) and commits."""
    supplier = get_supplier_or_404(db, supplier_id)
    for attempt in (1, 2):
        try:
            entries, warnings = _sync_once(db, supplier, actor)
            db.commit()
            return entries, warnings
        except IntegrityError:  # a concurrent sync took the same code / source key: retry once on fresh data
            db.rollback()
            if attempt == 2:
                raise
    raise AssertionError("unreachable")  # pragma: no cover


def get_supplier_or_404(db: Session, supplier_id: int) -> Supplier:
    supplier = db.get(Supplier, supplier_id)
    if supplier is None:
        raise HTTPException(status_code=404, detail=f"المورد رقم {supplier_id} غير موجود.")
    return supplier


# ── Read services ───────────────────────────────────────────────────────────────

def ledger_drafts_after_sync(db: Session, supplier_id: int, actor: str) -> Tuple[List[LedgerDraft], List[dict]]:
    entries, warnings = sync_supplier_ledger(db, supplier_id, actor)
    return [_draft_from_entry(e) for e in entries], warnings


def get_supplier_realtime_balance(db: Session, supplier_id: int, as_of: Optional[date] = None) -> Dict[str, CurrencyBalance]:
    """Live per-currency balance from the sources (no write), with the EGP equivalent at today's commercial rate."""
    supplier = get_supplier_or_404(db, supplier_id)
    drafts, _ = collect_ledger_drafts(db, supplier)
    rates = current_rates_for(db, {d.currency for d in drafts}, as_of)
    return summarize_balances(drafts, rates)


def supplier_limit_currency(supplier: Supplier) -> str:
    return (supplier.credit_limit_currency or supplier.currency or "USD").strip().upper()


def check_supplier_credit_limit(
    db: Session, supplier_id: int, new_amount: float, currency: Optional[str] = None,
    balances: Optional[Dict[str, CurrencyBalance]] = None,
) -> CreditCheck:
    """Credit decision for a new commitment of ``new_amount`` in ``currency`` (default: the limit currency)."""
    from modules.financial_settlement.landed_cost_engine_service import SettlementFx

    supplier = get_supplier_or_404(db, supplier_id)
    limit_ccy = supplier_limit_currency(supplier)
    policy = supplier.credit_limit_policy or POLICY_BLOCK
    if float(supplier.credit_limit or 0.0) <= 0:
        return evaluate_credit_limit(0.0, limit_ccy, policy, 0.0, float(new_amount or 0.0))
    fx = SettlementFx(db, "commercial")
    if balances is None:
        balances = get_supplier_realtime_balance(db, supplier_id)
    utilization = credit_utilization({c: b.balance_fx for c, b in balances.items()}, limit_ccy, fx.rate)
    requested = convert_amount(float(new_amount or 0.0), (currency or limit_ccy).strip().upper(), limit_ccy, fx.rate)
    return evaluate_credit_limit(float(supplier.credit_limit), limit_ccy, policy, utilization, requested)


def enforce_supplier_credit_limit(
    db: Session,
    supplier_id: int,
    new_amount: float,
    currency: Optional[str],
    *,
    context: str,
    reference: Optional[str],
    actor: Optional[str],
    actor_is_admin: bool = False,
    override_reason: Optional[str] = None,
) -> CreditCheck:
    """Governance guard for a new commitment. BLOCK beyond the limit -> 409 unless an ADMIN gives a reason; the
    override is added to the session (committed with the caller's transaction)."""
    check = check_supplier_credit_limit(db, supplier_id, new_amount, currency)
    if check.decision != DECISION_BLOCK:
        return check
    reason = (override_reason or "").strip()
    if not reason:
        raise supplier_coded_error(
            409, SUPPLIER_CREDIT_LIMIT_EXCEEDED,
            f"تجاوز الحد الائتماني للمورد: الحد {check.limit_amount:,.2f} {check.currency}، المستخدم "
            f"{check.utilization_amount:,.2f}، المطلوب {check.requested_amount:,.2f}. يلزم اعتماد استثنائي من "
            f"مدير النظام مع ذكر السبب.",
            supplier_id=supplier_id, currency=check.currency, limit_amount=check.limit_amount,
            utilization_amount=check.utilization_amount, requested_amount=check.requested_amount,
            projected_amount=check.projected_amount,
        )
    if not actor_is_admin:
        raise supplier_coded_error(
            403, SUPPLIER_CREDIT_OVERRIDE_FORBIDDEN,
            "تجاوز الحد الائتماني للمورد يتطلب اعتماد مدير النظام (ADMIN).",
            supplier_id=supplier_id,
        )
    db.add(SupplierCreditOverride(
        supplier_id=supplier_id, context=context, reference=reference, currency=check.currency,
        limit_amount=check.limit_amount, utilization_amount=check.utilization_amount,
        requested_amount=check.requested_amount, projected_amount=check.projected_amount, reason=reason,
        is_active=True, created_by=actor or "system", updated_by=actor or "system",
    ))
    check.allowed, check.decision = True, DECISION_OVERRIDDEN
    return check


def update_supplier_credit_limit(
    db: Session, supplier_id: int, credit_limit: float, currency: Optional[str], policy: str, actor: str,
) -> Supplier:
    supplier = get_supplier_or_404(db, supplier_id)
    currency_code, policy_code = validate_credit_limit_settings(db, credit_limit, currency, policy)
    supplier.credit_limit = float(credit_limit)
    supplier.credit_limit_currency = currency_code
    supplier.credit_limit_policy = policy_code
    supplier.updated_by = actor
    db.commit()
    db.refresh(supplier)
    return supplier


# ── API response services ───────────────────────────────────────────────────────

def _balance_schema(b: CurrencyBalance):
    from .schemas import SupplierCurrencyBalanceResponse

    return SupplierCurrencyBalanceResponse(**b.__dict__)


def _check_schema(c: CreditCheck):
    from .schemas import SupplierCreditCheckResponse

    return SupplierCreditCheckResponse(**c.__dict__)


def _currency_aging_schema(a: CurrencyAging, with_items: bool = True):
    from .schemas import SupplierAgingItemResponse, SupplierCurrencyAgingResponse

    return SupplierCurrencyAgingResponse(
        currency=a.currency,
        current=a.buckets[BUCKET_CURRENT],
        days_1_30=a.buckets[BUCKET_1_30],
        days_31_60=a.buckets[BUCKET_31_60],
        days_61_90=a.buckets[BUCKET_61_90],
        over_90=a.buckets[BUCKET_OVER_90],
        total_open_fx=a.total_open_fx,
        unapplied_fx=a.unapplied_fx,
        current_rate=a.current_rate,
        total_open_egp=a.total_open_egp,
        items=[
            SupplierAgingItemResponse(
                entry_code=it.entry.entry_code, reference=it.entry.reference, import_file_id=it.entry.import_file_id,
                payment_pathway=it.entry.payment_pathway, entry_date=it.entry.entry_date, due_date=it.entry.due_date,
                amount_fx=it.entry.amount_fx, open_amount_fx=it.entry.open_amount_fx,
                days_past_due=it.days_past_due, bucket=it.bucket,
            )
            for it in a.items
        ] if with_items else [],
    )


def _total_egp(values: List[Optional[float]]) -> Optional[float]:
    if any(v is None for v in values):
        return None
    return _r(sum(values))


def supplier_statement_service(
    db: Session, supplier_id: int, actor: str, currency: Optional[str] = None,
    date_from: Optional[date] = None, date_to: Optional[date] = None,
):
    """Statement of account per currency (opening balance before ``date_from``, running balance per line)."""
    from .schemas import SupplierCurrencyStatementResponse, SupplierLedgerEntryResponse, SupplierStatementResponse

    supplier = get_supplier_or_404(db, supplier_id)
    entries, warnings = sync_supplier_ledger(db, supplier_id, actor)
    drafts = [_draft_from_entry(e) for e in entries]
    rates = current_rates_for(db, {d.currency for d in drafts})
    balances = summarize_balances(drafts, rates)
    ccy_filter = (currency or "").strip().upper() or None
    statements = []
    for ccy, lines in sorted(build_statement(drafts).items()):
        if ccy_filter and ccy != ccy_filter:
            continue
        opening_fx = opening_egp = 0.0
        shown = []
        for ln in lines:
            if date_from and ln.entry.entry_date < date_from:
                opening_fx, opening_egp = ln.balance_fx, ln.balance_egp
                continue
            if date_to and ln.entry.entry_date > date_to:
                continue
            shown.append(ln)
        closing_fx, closing_egp = (shown[-1].balance_fx, shown[-1].balance_egp) if shown else (opening_fx, opening_egp)
        statements.append(SupplierCurrencyStatementResponse(
            currency=ccy, opening_balance_fx=opening_fx, opening_balance_egp=opening_egp,
            closing_balance_fx=closing_fx, closing_balance_egp=closing_egp,
            lines=[
                SupplierLedgerEntryResponse(
                    entry_code=ln.entry.entry_code, source_key=ln.entry.source_key,
                    entry_type=ln.entry.entry_type, direction=ln.entry.direction,
                    payment_pathway=ln.entry.payment_pathway, reference=ln.entry.reference,
                    description=ln.entry.description, import_file_id=ln.entry.import_file_id,
                    payment_id=ln.entry.payment_id, finance_instrument_id=ln.entry.finance_instrument_id,
                    entry_date=ln.entry.entry_date, due_date=ln.entry.due_date, currency=ln.entry.currency,
                    amount_fx=ln.entry.amount_fx, exchange_rate=ln.entry.exchange_rate, amount_egp=ln.entry.amount_egp,
                    open_amount_fx=ln.entry.open_amount_fx, status=ln.entry.status,
                    balance_fx=ln.balance_fx, balance_egp=ln.balance_egp,
                )
                for ln in shown
            ],
        ))
    return SupplierStatementResponse(
        supplier_id=supplier.supplier_id, supplier_code=supplier.supplier_code, company_name=supplier.company_name,
        date_from=date_from, date_to=date_to,
        balances=[_balance_schema(b) for c, b in sorted(balances.items()) if not ccy_filter or c == ccy_filter],
        statements=statements, warnings=warnings,
    )


def supplier_aging_service(db: Session, supplier_id: int, actor: str, as_of: Optional[date] = None):
    from .schemas import SupplierAgingResponse

    supplier = get_supplier_or_404(db, supplier_id)
    day = as_of or _today()
    drafts, warnings = ledger_drafts_after_sync(db, supplier_id, actor)
    aging = build_aging(drafts, day, current_rates_for(db, {d.currency for d in drafts}))
    currencies = [_currency_aging_schema(a) for _, a in sorted(aging.items())]
    return SupplierAgingResponse(
        supplier_id=supplier.supplier_id, supplier_code=supplier.supplier_code, company_name=supplier.company_name,
        as_of=day, currencies=currencies, total_open_egp=_total_egp([c.total_open_egp for c in currencies]),
        warnings=warnings,
    )


def supplier_aging_report_service(db: Session, as_of: Optional[date] = None):
    """Vendor aging of all active suppliers with activity (live, no write); suppliers with nothing open omitted."""
    from .repository import list_suppliers_with_activity
    from .schemas import SupplierAgingReportResponse, SupplierAgingReportRow

    day = as_of or _today()
    rows = []
    for supplier in list_suppliers_with_activity(db):
        drafts, _ = collect_ledger_drafts(db, supplier)
        aging = build_aging(drafts, day, current_rates_for(db, {d.currency for d in drafts}))
        currencies = [_currency_aging_schema(a, with_items=False) for _, a in sorted(aging.items())
                      if a.total_open_fx > 0 or a.unapplied_fx > 0]
        if not currencies:
            continue
        rows.append(SupplierAgingReportRow(
            supplier_id=supplier.supplier_id, supplier_code=supplier.supplier_code,
            company_name=supplier.company_name, currencies=currencies,
            total_open_egp=_total_egp([c.total_open_egp for c in currencies]),
        ))
    return SupplierAgingReportResponse(as_of=day, rows=rows)


def supplier_credit_status_service(db: Session, supplier_id: int):
    from .repository import list_supplier_credit_overrides
    from .schemas import SupplierCreditOverrideResponse, SupplierCreditStatusResponse

    get_supplier_or_404(db, supplier_id)
    balances = get_supplier_realtime_balance(db, supplier_id)
    check = check_supplier_credit_limit(db, supplier_id, 0.0, balances=balances)
    return SupplierCreditStatusResponse(
        supplier_id=supplier_id, credit=_check_schema(check),
        balances=[_balance_schema(b) for _, b in sorted(balances.items())],
        overrides=[SupplierCreditOverrideResponse.model_validate(o) for o in list_supplier_credit_overrides(db, supplier_id)],
    )


def supplier_credit_check_service(db: Session, supplier_id: int, amount: float, currency: Optional[str]):
    return _check_schema(check_supplier_credit_limit(db, supplier_id, amount, currency))
