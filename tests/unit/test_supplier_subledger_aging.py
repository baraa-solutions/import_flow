"""
Foreign Vendor Multi-Currency Sub-Ledger, Credit Limit Governance & 30/60/90 Aging (Trello GzFff0Pc).

Concrete numbers: multi-currency balances with EGP equivalents, partial payments and allocation, aging bucket
boundaries (30/31/60/61/90/91 days), LC commitments (memo) and bank settlement, credit-limit breach / WARN /
ADMIN override (also through purchase order creation) and no double counting against the net FOB engine.
"""
from datetime import date, timedelta
from decimal import Decimal

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.currencies.model import Currency, ExchangeRate
from modules.currencies.service import clear_currency_cache
from modules.financial_approval.model import PaymentRequestSession
from modules.financial_settlement.fob_valuation_service import resolve_fob_valuation
from modules.import_files.model import ImportFile
from modules.suppliers import ledger_service as ls
from modules.suppliers.ledger_service import (
    BUCKET_1_30,
    BUCKET_31_60,
    BUCKET_61_90,
    BUCKET_CURRENT,
    BUCKET_OVER_90,
    CREDIT,
    DEBIT,
    INVOICE_BILLED,
    PAYMENT_SETTLED,
    LedgerDraft,
    aging_bucket,
    allocate_payments,
    build_aging,
    build_statement,
    check_supplier_credit_limit,
    credit_utilization,
    enforce_supplier_credit_limit,
    evaluate_credit_limit,
    invoice_due_date,
    parse_credit_days,
    summarize_balances,
    supplier_aging_service,
    supplier_credit_status_service,
    supplier_statement_service,
    sync_supplier_ledger,
    update_supplier_credit_limit,
)
from modules.suppliers.model import Supplier, SupplierCreditOverride, SupplierLedgerEntry
from modules.suppliers.validators import (
    SUPPLIER_CREDIT_LIMIT_EXCEEDED,
    SUPPLIER_CREDIT_LIMIT_INVALID,
    SUPPLIER_CREDIT_OVERRIDE_FORBIDDEN,
)
from modules.trade_finance.model import FxHedgingAndVariance, ImportFinanceInstrument


# ── Pure core ───────────────────────────────────────────────────────────────────

def _d(key, direction, amount, ccy="USD", egp=None, entry_date=date(2026, 1, 1), due=None, file_id=None):
    return LedgerDraft(source_key=key, entry_type=INVOICE_BILLED if direction == CREDIT else PAYMENT_SETTLED,
                       direction=direction, currency=ccy, amount_fx=amount,
                       amount_egp=egp if egp is not None else amount * 50.0, entry_date=entry_date, due_date=due,
                       import_file_id=file_id)


class TestAgingBuckets:
    @pytest.mark.parametrize("days,bucket", [
        (-5, BUCKET_CURRENT), (0, BUCKET_CURRENT), (1, BUCKET_1_30), (30, BUCKET_1_30), (31, BUCKET_31_60),
        (60, BUCKET_31_60), (61, BUCKET_61_90), (90, BUCKET_61_90), (91, BUCKET_OVER_90), (400, BUCKET_OVER_90),
    ])
    def test_bucket_boundaries(self, days, bucket):
        assert aging_bucket(days) == bucket


class TestDueDates:
    @pytest.mark.parametrize("terms,days", [
        ("Net 60", 60), ("OA 90", 90), ("Open Account 45", 45), ("60 days", 60), ("90 يوم", 90),
        ("30% advance, 70% against BL", 0), ("LC at Sight", 0), (None, 0),
        ("T/T in 2 installments, 90 days", 90), ("Plan 30 / 60 days", 60), ("Net60", 60), ("N 45", 0),
    ])
    def test_credit_days_from_payment_terms(self, terms, days):
        assert parse_credit_days(terms) == days

    def test_due_date_per_pathway(self):
        inv = date(2026, 8, 1)
        assert invoice_due_date("ADVANCE_PAYMENT", inv, 60) == inv
        assert invoice_due_date(None, inv, 60) == inv
        assert invoice_due_date("OPEN_ACCOUNT", inv, 60) == date(2026, 9, 30)
        assert invoice_due_date("LC", inv, lc_shipment_deadline=date(2026, 8, 20), lc_presentation_days=21) == date(2026, 9, 10)
        assert invoice_due_date("LC", inv, instrument_expiry=date(2026, 10, 1)) == date(2026, 10, 1)
        assert invoice_due_date("CAD", inv, instrument_expiry=date(2026, 9, 15)) == date(2026, 9, 15)
        assert invoice_due_date("CAD", inv) == inv  # D/P at sight


class TestAllocationAndStatement:
    def test_payment_settles_its_own_file_first_then_oldest_due(self):
        a = _d("INV:A", CREDIT, 10000.0, due=date(2026, 1, 1), file_id=1)
        b = _d("INV:B", CREDIT, 5000.0, due=date(2026, 2, 1), file_id=2)
        pay = _d("PAY:1", DEBIT, 12000.0, entry_date=date(2026, 3, 1), file_id=2)
        eur = _d("PAY:2", DEBIT, 1000.0, ccy="EUR", entry_date=date(2026, 3, 2))
        allocate_payments([a, b, pay, eur])
        assert (b.open_amount_fx, b.status) == (0.0, "SETTLED")  # own file first
        assert (a.open_amount_fx, a.status) == (3000.0, "PARTIAL")  # 10,000 - 7,000
        assert (pay.open_amount_fx, pay.status) == (0.0, "SETTLED")
        assert (eur.open_amount_fx, eur.status) == (1000.0, "UNAPPLIED")  # an advance: no EUR invoice yet

    def test_running_balance_per_currency_never_nets_currencies(self):
        drafts = [
            _d("INV:A", CREDIT, 10000.0, egp=500000.0, entry_date=date(2026, 1, 1)),
            _d("PAY:1", DEBIT, 4000.0, egp=204000.0, entry_date=date(2026, 2, 1)),
            _d("INV:E", CREDIT, 3000.0, ccy="EUR", egp=165000.0, entry_date=date(2026, 1, 15)),
        ]
        allocate_payments(drafts)
        st = build_statement(drafts)
        assert [(ln.balance_fx, ln.balance_egp) for ln in st["USD"]] == [(10000.0, 500000.0), (6000.0, 296000.0)]
        assert [ln.balance_fx for ln in st["EUR"]] == [3000.0]
        bal = summarize_balances(drafts, {"USD": 52.0, "EUR": None})
        assert (bal["USD"].balance_fx, bal["USD"].book_balance_egp, bal["USD"].current_balance_egp) == (6000.0, 296000.0, 312000.0)
        assert bal["EUR"].current_balance_egp is None  # no rate: never guessed

    def test_aging_uses_open_amount_and_days_past_due(self):
        drafts = [
            _d("INV:1", CREDIT, 1000.0, due=date(2026, 10, 1)),   # 30 days -> 1_30
            _d("INV:2", CREDIT, 2000.0, due=date(2026, 9, 30)),   # 31 days -> 31_60
            _d("INV:3", CREDIT, 3000.0, due=date(2026, 8, 1)),    # 91 days -> OVER_90
            _d("INV:4", CREDIT, 4000.0, due=date(2026, 11, 15)),  # not due -> CURRENT
        ]
        allocate_payments(drafts)
        aging = build_aging(drafts, date(2026, 10, 31), {"USD": 50.0})["USD"]
        assert aging.buckets == {BUCKET_CURRENT: 4000.0, BUCKET_1_30: 1000.0, BUCKET_31_60: 2000.0,
                                 BUCKET_61_90: 0.0, BUCKET_OVER_90: 3000.0}
        assert (aging.total_open_fx, aging.total_open_egp) == (10000.0, 500000.0)


class TestCreditPure:
    def test_utilization_converts_positive_balances_to_the_limit_currency(self):
        rates = {"USD": 50.0, "EUR": 55.0}
        # USD 30,000 owed; EUR -2,000 is an advance and never frees USD credit.
        assert credit_utilization({"USD": 30000.0, "EUR": -2000.0}, "EUR", rates.__getitem__) == 27272.73
        assert credit_utilization({"USD": 30000.0, "EGP": 50000.0}, "USD", rates.__getitem__) == 31000.0

    def test_limit_boundaries_and_policies(self):
        within = evaluate_credit_limit(50000.0, "USD", "BLOCK", 45000.0, 5000.0)
        assert (within.exceeded, within.allowed, within.decision) == (False, True, "WITHIN_LIMIT")  # exactly at limit
        breach = evaluate_credit_limit(50000.0, "USD", "BLOCK", 45000.0, 5000.01)
        assert (breach.exceeded, breach.allowed, breach.decision) == (True, False, "BLOCK")
        assert (breach.available_amount, breach.utilization_pct) == (5000.0, 90.0)
        warn = evaluate_credit_limit(50000.0, "USD", "WARN", 45000.0, 9000.0)
        assert (warn.exceeded, warn.allowed, warn.decision) == (True, True, "WARN")
        none = evaluate_credit_limit(0.0, "USD", "BLOCK", 999999.0, 1.0)
        assert (none.has_limit, none.allowed, none.decision) == (False, True, "NO_LIMIT")


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


def _supplier(db, code="SUP-LED-1", payment_terms=None, limit=0.0, limit_ccy=None, policy="BLOCK") -> Supplier:
    s = Supplier(supplier_code=code, company_name=f"Milano Industrial {code}", supplier_type="Manufacturer",
                 registration_type="Factory", foreign_exporter_id=f"EXP-{code}", foreign_exporter_country="Italy",
                 foreign_exporter_country_code="IT", address="Milan", currency="USD", payment_terms=payment_terms,
                 credit_limit=limit, credit_limit_currency=limit_ccy, credit_limit_policy=policy, is_active=True)
    db.add(s)
    db.commit()
    return s


def _file(db, supplier, invoices, code, payment_term=None) -> ImportFile:
    imp = ImportFile(import_file_code=code, company_name="Sorour Logistics", supplier_id=supplier.supplier_id,
                     supplier_name=supplier.company_name, invoices_data=invoices, payment_term=payment_term,
                     is_active=True)
    db.add(imp)
    db.commit()
    return imp


_PAY_SEQ = [0]


def _paid(db, supplier, amount, egp, ccy="USD", imp=None, day=date(2026, 3, 1), payment_type="Final Settlement",
          status="Paid"):
    _PAY_SEQ[0] += 1
    req = PaymentRequestSession(
        payment_code=f"PAY-T-{_PAY_SEQ[0]}", title="Supplier payment", supplier_id=supplier.supplier_id,
        supplier_name=supplier.company_name, import_file_id=imp.import_file_id if imp else None,
        payment_type=payment_type, requested_amount=amount, currency_code=ccy, exchange_rate=egp / amount,
        requested_amount_egp=egp, paid_amount_egp=egp, due_date=day, request_date=day, swift_receipt_date=day,
        status=status, is_active=True,
    )
    db.add(req)
    db.commit()
    return req


def _active_entries(db, supplier):
    return db.query(SupplierLedgerEntry).filter_by(supplier_id=supplier.supplier_id, is_active=True).all()


def test_multi_currency_balances_with_egp_equivalent_and_no_double_counting(db):
    s = _supplier(db)
    usd_file = _file(db, s, [{"invoice_no": "CI-1", "amount": 10000.0, "currency": "USD", "exchange_rate": 50.0,
                               "invoice_date": "2026-02-01", "financing_markup_amount": 1000.0}], "IMP-LED-01",
                     payment_term="ADVANCE_PAYMENT")
    _file(db, s, [{"invoice_no": "CI-E", "amount": 4000.0, "currency": "EUR", "exchange_rate": 55.0,
                   "invoice_date": "2026-02-10"}], "IMP-LED-02")
    _paid(db, s, 6000.0, 306000.0, imp=usd_file, payment_type="Advance Payment")  # bank debit at 51

    balances = ls.get_supplier_realtime_balance(db, s.supplier_id)
    usd, eur = balances["USD"], balances["EUR"]
    # Payable = net FOB 9,000 + markup 1,000; 6,000 anchored at 51 + 4,000 at the invoice rate 50.
    assert (usd.billed_fx, usd.paid_fx, usd.balance_fx) == (10000.0, 6000.0, 4000.0)
    assert usd.book_balance_egp == 506000.0 - 306000.0
    assert (usd.current_rate, usd.current_balance_egp) == (52.0, 208000.0)  # today's commercial rate
    assert (eur.balance_fx, eur.book_balance_egp, eur.current_balance_egp) == (4000.0, 220000.0, 220000.0)

    # Single source of truth: the billed EGP is exactly the FOB engine payable of the file.
    valuation = resolve_fob_valuation(db, usd_file.import_file_id)
    entries, _ = sync_supplier_ledger(db, s.supplier_id, "tester")
    billed = [e for e in entries if e.entry_type == INVOICE_BILLED and e.currency == "USD"]
    assert sum(e.amount_egp for e in billed) == valuation.payable_total_egp == 506000.0
    advance = [e for e in entries if e.entry_type == "ADVANCE_PAID"]
    assert [(a.amount_fx, a.amount_egp, a.status) for a in advance] == [(6000.0, 306000.0, "SETTLED")]

    # Idempotent: a second sync updates in place (same codes, no extra rows).
    codes = sorted(e.entry_code for e in entries)
    again, _ = sync_supplier_ledger(db, s.supplier_id, "tester")
    assert sorted(e.entry_code for e in again) == codes
    assert db.query(SupplierLedgerEntry).filter_by(supplier_id=s.supplier_id).count() == 3


def test_duplicated_invoice_is_billed_once(db):
    s = _supplier(db)
    inv = {"invoice_no": "PI-9", "amount": 10000.0, "currency": "USD", "exchange_rate": 50.0}
    _file(db, s, [inv, dict(inv)], "IMP-LED-DUP")
    entries, _ = sync_supplier_ledger(db, s.supplier_id)
    assert [(e.amount_fx, e.amount_egp) for e in entries] == [(10000.0, 500000.0)]


def test_estimate_only_file_bills_nothing(db):
    s = _supplier(db)
    imp = _file(db, s, None, "IMP-LED-EST")
    imp.estimated_cost, imp.estimated_cost_currency = 25000.0, "USD"
    db.commit()
    entries, _ = sync_supplier_ledger(db, s.supplier_id)
    assert entries == []


@pytest.mark.parametrize("as_of,bucket", [
    (date(2026, 9, 30), BUCKET_CURRENT),   # due today
    (date(2026, 10, 30), BUCKET_1_30),     # 30 days
    (date(2026, 10, 31), BUCKET_31_60),    # 31
    (date(2026, 11, 29), BUCKET_31_60),    # 60
    (date(2026, 11, 30), BUCKET_61_90),    # 61
    (date(2026, 12, 29), BUCKET_61_90),    # 90
    (date(2026, 12, 30), BUCKET_OVER_90),  # 91
])
def test_open_account_partial_payment_ages_from_net_60_due_date(db, as_of, bucket):
    s = _supplier(db, payment_terms="Net 60")
    imp = _file(db, s, [{"invoice_no": "OA-1", "amount": 10000.0, "currency": "USD", "exchange_rate": 50.0,
                          "invoice_date": "2026-08-01"}], "IMP-LED-OA", payment_term="OPEN_ACCOUNT")
    _paid(db, s, 4000.0, 208000.0, imp=imp, day=date(2026, 9, 1))
    aging = supplier_aging_service(db, s.supplier_id, "tester", as_of)
    usd = aging.currencies[0]
    item = usd.items[0]
    assert (item.due_date, item.amount_fx, item.open_amount_fx) == (date(2026, 9, 30), 10000.0, 6000.0)
    assert item.bucket == bucket
    buckets = {BUCKET_CURRENT: usd.current, BUCKET_1_30: usd.days_1_30, BUCKET_31_60: usd.days_31_60,
               BUCKET_61_90: usd.days_61_90, BUCKET_OVER_90: usd.over_90}
    assert buckets[bucket] == 6000.0 and sum(buckets.values()) == 6000.0


def test_lc_commitment_is_memo_and_bank_settlement_covers_only_the_unpaid_part(db):
    s = _supplier(db)
    imp = _file(db, s, [{"invoice_no": "CI-LC", "amount": 10000.0, "currency": "USD", "exchange_rate": 50.0,
                          "invoice_date": "2026-03-01"}], "IMP-LED-LC", payment_term="LC")
    inst = ImportFinanceInstrument(instrument_type="LC", instrument_number="LC-LED-1", import_file_id=imp.import_file_id,
                                   issuing_bank="NBE", currency="USD", amount=10000.0, status="ISSUED",
                                   issue_date=date(2026, 2, 1), expiry_date=date(2026, 5, 1),
                                   shipment_deadline=date(2026, 3, 20), presentation_period_days=21)
    db.add(inst)
    db.commit()

    st = supplier_statement_service(db, s.supplier_id, "tester")
    usd = st.statements[0]
    memo = [ln for ln in usd.lines if ln.entry_type == "LC_COMMITTED"]
    assert [(m.direction, m.amount_fx, m.status) for m in memo] == [("MEMO", 10000.0, "OPEN")]
    assert usd.closing_balance_fx == 10000.0  # the commitment never doubles the liability
    inv = next(ln for ln in usd.lines if ln.entry_type == INVOICE_BILLED)
    assert inv.due_date == date(2026, 4, 10)  # shipment deadline + 21 days presentation
    assert st.balances[0].open_commitments_fx == 10000.0

    # 2,000 paid by SWIFT, then the bank settles the LC: only the remaining 8,000 is debited.
    _paid(db, s, 2000.0, 100000.0, imp=imp, day=date(2026, 3, 5))
    inst.status = "SETTLED"
    db.add(FxHedgingAndVariance(finance_instrument_id=inst.id, foreign_currency="USD", original_amount=10000.0,
                                booking_date=date(2026, 2, 1), booking_rate=50.0, booking_total_egp=500000.0,
                                settlement_date=date(2026, 4, 12), settlement_rate=51.0,
                                settlement_total_egp=510000.0))
    db.commit()
    st = supplier_statement_service(db, s.supplier_id, "tester")
    usd = st.statements[0]
    bank = [ln for ln in usd.lines if ln.source_key.endswith(":SETTLED")]
    assert [(b.amount_fx, b.amount_egp, b.entry_date) for b in bank] == [(8000.0, 408000.0, date(2026, 4, 12))]
    assert usd.closing_balance_fx == 0.0
    assert st.balances[0].open_commitments_fx == 0.0


def test_cancelled_payment_is_soft_deleted_and_balance_restored(db):
    s = _supplier(db)
    imp = _file(db, s, [{"invoice_no": "CI-1", "amount": 5000.0, "currency": "USD", "exchange_rate": 50.0}],
                "IMP-LED-RJ")
    req = _paid(db, s, 5000.0, 250000.0, imp=imp)
    sync_supplier_ledger(db, s.supplier_id)
    assert ls.get_supplier_realtime_balance(db, s.supplier_id)["USD"].balance_fx == 0.0
    req.status = "Rejected"
    db.commit()
    sync_supplier_ledger(db, s.supplier_id, "tester")
    gone = db.query(SupplierLedgerEntry).filter_by(payment_id=req.payment_id).one()
    assert (gone.is_active, gone.deleted_by) == (False, "tester")
    assert [e.status for e in _active_entries(db, s)] == ["OPEN"]


def test_statement_opening_balance_before_date_from(db):
    s = _supplier(db)
    imp = _file(db, s, [{"invoice_no": "CI-1", "amount": 10000.0, "currency": "USD", "exchange_rate": 50.0,
                          "invoice_date": "2026-01-10"}], "IMP-LED-OB")
    _paid(db, s, 3000.0, 153000.0, imp=imp, day=date(2026, 2, 10))
    _paid(db, s, 2000.0, 104000.0, imp=imp, day=date(2026, 4, 10))
    st = supplier_statement_service(db, s.supplier_id, "tester", currency="usd", date_from=date(2026, 3, 1))
    usd = st.statements[0]
    assert usd.opening_balance_fx == 7000.0
    assert [(ln.amount_fx, ln.balance_fx) for ln in usd.lines] == [(2000.0, 5000.0)]
    assert usd.closing_balance_fx == 5000.0


def test_credit_limit_block_warn_and_admin_override(db):
    s = _supplier(db, limit=20000.0, limit_ccy="USD", policy="BLOCK")
    _file(db, s, [{"invoice_no": "CI-1", "amount": 15000.0, "currency": "USD", "exchange_rate": 50.0}], "IMP-LED-CL")

    ok = enforce_supplier_credit_limit(db, s.supplier_id, 5000.0, "USD", context="PURCHASE_ORDER", reference="PO-1",
                                       actor="clerk")
    assert (ok.utilization_amount, ok.projected_amount, ok.decision) == (15000.0, 20000.0, "WITHIN_LIMIT")

    with pytest.raises(HTTPException) as exc:
        enforce_supplier_credit_limit(db, s.supplier_id, 6000.0, "USD", context="PURCHASE_ORDER", reference="PO-2",
                                      actor="clerk")
    assert exc.value.status_code == 409 and exc.value.detail["code"] == SUPPLIER_CREDIT_LIMIT_EXCEEDED
    assert exc.value.detail["projected_amount"] == 21000.0

    with pytest.raises(HTTPException) as exc:
        enforce_supplier_credit_limit(db, s.supplier_id, 6000.0, "USD", context="PURCHASE_ORDER", reference="PO-2",
                                      actor="clerk", override_reason="urgent")
    assert exc.value.status_code == 403 and exc.value.detail["code"] == SUPPLIER_CREDIT_OVERRIDE_FORBIDDEN

    # 6,000 EUR at 55 = 6,346.15 USD at 52 (cross through EGP).
    res = enforce_supplier_credit_limit(db, s.supplier_id, 6000.0, "EUR", context="PURCHASE_ORDER", reference="PO-3",
                                        actor="admin", actor_is_admin=True, override_reason="Strategic order")
    db.commit()
    assert (res.decision, res.requested_amount) == ("OVERRIDDEN", 6346.15)
    ov = db.query(SupplierCreditOverride).one()
    assert (ov.reference, ov.created_by, ov.reason, ov.limit_amount, ov.utilization_amount) == (
        "PO-3", "admin", "Strategic order", 20000.0, 15000.0)
    status_view = supplier_credit_status_service(db, s.supplier_id)
    assert status_view.credit.utilization_pct == 75.0 and len(status_view.overrides) == 1

    update_supplier_credit_limit(db, s.supplier_id, 20000.0, "USD", "warn", "admin")
    warn = check_supplier_credit_limit(db, s.supplier_id, 9000.0, "USD")
    assert (warn.decision, warn.allowed, warn.exceeded) == ("WARN", True, True)


def test_credit_limit_settings_validation(db):
    s = _supplier(db)
    with pytest.raises(HTTPException) as exc:
        update_supplier_credit_limit(db, s.supplier_id, 1000.0, "XYZ", "BLOCK", "admin")
    assert exc.value.detail["code"] == SUPPLIER_CREDIT_LIMIT_INVALID
    with pytest.raises(HTTPException):
        update_supplier_credit_limit(db, s.supplier_id, 1000.0, "USD", "MAYBE", "admin")
    with pytest.raises(HTTPException):
        update_supplier_credit_limit(db, s.supplier_id, -1.0, "USD", "BLOCK", "admin")
    updated = update_supplier_credit_limit(db, s.supplier_id, 1000.0, "eur", "block", "admin")
    assert (updated.credit_limit, updated.credit_limit_currency, updated.credit_limit_policy) == (1000.0, "EUR", "BLOCK")


@pytest.fixture
def po_env(db):
    from modules.import_companies.model import ImportCompany
    from modules.incoterms.model import Incoterm
    from modules.projects.model import Project

    s = _supplier(db, limit=10000.0, limit_ccy="USD")
    company = ImportCompany(importer_name="Import Corp", address="Cairo", country="Egypt", importer_id="IMP-1",
                            importer_id_expiry=date.today() + timedelta(days=120), vat_id="VAT-1",
                            vat_id_expiry=date.today() + timedelta(days=90), registration_number="REG-1",
                            registration_expiry=date.today() + timedelta(days=60), is_active=True)
    inco = Incoterm(incoterm_code="FOB", incoterm_name="Free on Board", is_active=True)
    db.add_all([company, inco])
    db.flush()
    project = Project(project_name="Alpha", project_code="PRJ-LED", project_owner="Eng", company_id=company.company_id,
                      supplier_id=s.supplier_id, incoterm_id=inco.incoterm_id, is_active=True)
    db.add(project)
    db.commit()
    usd = db.query(Currency).filter_by(currency_code="USD").one()
    return {"supplier": s, "company": company, "incoterm": inco, "project": project, "usd": usd}


def _po_data(env, quantity, **extra):
    from modules.purchase_orders.schemas import POLineItemCreate, PurchaseOrderCreate

    item = POLineItemCreate(item_code="X-1", description_ar="بند", quantity=quantity, unit_price=200.0)
    return PurchaseOrderCreate(project_id=env["project"].project_id, company_id=env["company"].company_id,
                               supplier_id=env["supplier"].supplier_id, incoterm_id=env["incoterm"].incoterm_id,
                               currency_id=env["usd"].currency_id, exchange_rate=50.0, items=[item], **extra)


def test_purchase_order_creation_is_governed_by_the_credit_limit(db, po_env):
    from modules.purchase_orders.service import PurchaseOrderService

    with pytest.raises(HTTPException) as exc:  # 100 x 200 = 20,000 USD vs 10,000 limit
        PurchaseOrderService(db).create(_po_data(po_env, 100.0), current_user_name="clerk")
    assert exc.value.detail["code"] == SUPPLIER_CREDIT_LIMIT_EXCEEDED

    po = PurchaseOrderService(db).create(_po_data(po_env, 100.0, credit_limit_override_reason="Board approved"),
                                         current_user_name="admin", actor_is_admin=True)
    ov = db.query(SupplierCreditOverride).one()
    assert (ov.context, ov.reference, ov.requested_amount) == ("PURCHASE_ORDER", po.po_number, 20000.0)


def test_open_uninvoiced_purchase_orders_count_toward_the_limit(db, po_env):
    from modules.purchase_orders.service import PurchaseOrderService

    s = po_env["supplier"]
    first = PurchaseOrderService(db).create(_po_data(po_env, 45.0), current_user_name="clerk")  # 9,000 USD
    assert first.po_number
    with pytest.raises(HTTPException) as exc:  # 9,000 open PO + 9,000 new > 10,000
        PurchaseOrderService(db).create(_po_data(po_env, 45.0), current_user_name="clerk")
    assert exc.value.detail["code"] == SUPPLIER_CREDIT_LIMIT_EXCEEDED
    assert (exc.value.detail["utilization_amount"], exc.value.detail["projected_amount"]) == (9000.0, 18000.0)
    status_view = supplier_credit_status_service(db, s.supplier_id)
    assert (status_view.credit.utilization_amount, status_view.credit.open_po_amount) == (9000.0, 9000.0)

    # Once the PO is invoiced on its linked import file, the invoice replaces the PO (no double count).
    from modules.purchase_orders.model import PurchaseOrder
    imp = _file(db, s, [{"invoice_no": "CI-PO", "amount": 9000.0, "currency": "USD", "exchange_rate": 50.0}], "IMP-LED-PO")
    po_row = db.query(PurchaseOrder).filter_by(po_number=first.po_number).one()
    po_row.import_file_id = imp.import_file_id
    db.commit()
    check = check_supplier_credit_limit(db, s.supplier_id, 0.0)
    assert (check.utilization_amount, check.open_po_amount) == (9000.0, 0.0)


def test_open_po_exposure_nets_invoices_of_the_linked_file():
    pos = [(1, "USD", 9000.0), (1, "USD", 3000.0), (None, "USD", 2000.0), (2, "EUR", 1000.0)]
    invoiced = {(1, "USD"): 10000.0, (2, "EUR"): 1500.0}
    assert ls.open_po_exposure(pos, invoiced) == {"USD": 4000.0}  # (12,000 - 10,000) + 2,000 unlinked


def test_generic_supplier_update_cannot_change_the_credit_limit(db):
    from modules.suppliers.schemas import SupplierCreate, SupplierUpdate
    from modules.suppliers.service import create_supplier_service, update_supplier_service

    created = create_supplier_service(db, SupplierCreate(company_name="Brand New Exporter GmbH", credit_limit=5000.0))
    assert created.credit_limit == 0.0  # ignored on create
    s = _supplier(db, code="SUP-GOV", limit=1000.0, limit_ccy="USD")
    update_supplier_service(db, s.supplier_id, SupplierUpdate(credit_limit=999999.0, notes="edited"))
    db.refresh(s)
    assert (s.credit_limit, s.notes) == (1000.0, "edited")


def test_bank_settlement_without_invoices_still_subtracts_paid_requests(db):
    # Review blocker: LC file with no invoices, paid LC request 10,000 + LC 10,000 SETTLED -> paid 10,000, not 20,000.
    s = _supplier(db)
    imp = _file(db, s, None, "IMP-LED-NOINV", payment_term="LC")
    _paid(db, s, 10000.0, 500000.0, imp=imp, payment_type="Letter of Credit (L/C)")
    db.add(ImportFinanceInstrument(instrument_type="LC", instrument_number="LC-NOINV", import_file_id=imp.import_file_id,
                                   issuing_bank="NBE", currency="USD", amount=10000.0, status="SETTLED",
                                   issue_date=date(2026, 2, 1)))
    db.commit()
    usd = ls.get_supplier_realtime_balance(db, s.supplier_id)["USD"]
    assert (usd.billed_fx, usd.paid_fx, usd.balance_fx) == (0.0, 10000.0, -10000.0)
    entries, _ = sync_supplier_ledger(db, s.supplier_id)
    assert not [e for e in entries if e.source_key.endswith(":SETTLED")]


def test_lc_cover_paid_in_egp_reduces_the_usd_bank_settlement(db):
    s = _supplier(db)
    imp = _file(db, s, [{"invoice_no": "CI-EGP", "amount": 10000.0, "currency": "USD", "exchange_rate": 50.0}],
                "IMP-LED-EGP", payment_term="LC")
    _paid(db, s, 250000.0, 250000.0, ccy="EGP", imp=imp, payment_type="Letter of Credit (L/C)")  # 5,000 USD at 50
    inst = ImportFinanceInstrument(instrument_type="LC", instrument_number="LC-EGP", import_file_id=imp.import_file_id,
                                   issuing_bank="NBE", currency="USD", amount=10000.0, status="SETTLED",
                                   issue_date=date(2026, 2, 1))
    db.add(inst)
    db.flush()
    db.add(FxHedgingAndVariance(finance_instrument_id=inst.id, foreign_currency="USD", original_amount=10000.0,
                                booking_date=date(2026, 2, 1), booking_rate=50.0, booking_total_egp=500000.0,
                                settlement_date=date(2026, 3, 1), settlement_rate=50.0, settlement_total_egp=500000.0))
    db.commit()
    entries, _ = sync_supplier_ledger(db, s.supplier_id)
    bank = [e for e in entries if e.source_key.endswith(":SETTLED")]
    assert [(b.currency, b.amount_fx, b.amount_egp) for b in bank] == [("USD", 5000.0, 250000.0)]


def test_payment_currency_and_amount_come_from_the_same_source():
    class Req:
        def __init__(self, **kw):
            self.swift_transferred_amount = kw.get("swift_amount")
            self.swift_transferred_currency = kw.get("swift_ccy")
            self.currency_code = kw.get("ccy", "USD")
            self.requested_amount = kw.get("requested", 1000.0)

    assert ls.payment_currency_and_amount(Req(swift_ccy="EUR")) == ("USD", 1000.0)  # no SWIFT amount: request pair
    assert ls.payment_currency_and_amount(Req(swift_ccy="EUR", swift_amount=900.0)) == ("EUR", 900.0)
    assert ls.payment_currency_and_amount(Req(swift_amount=990.0)) == ("USD", 990.0)


# ── Review round 2: prepaid POs, netting of the new PO, cross-currency netting, EGP payments ────────────────

def _link_po(db, env, quantity, imp, **extra):
    from modules.purchase_orders.service import PurchaseOrderService

    return PurchaseOrderService(db).create(_po_data(env, quantity, import_file_id=imp.import_file_id, **extra),
                                           current_user_name="clerk")


def test_fully_prepaid_po_does_not_consume_credit(db, po_env):
    from modules.purchase_orders.service import PurchaseOrderService

    s = po_env["supplier"]
    s.credit_limit = 150000.0
    db.commit()
    imp = _file(db, s, None, "IMP-LED-ADV", payment_term="ADVANCE_PAYMENT")
    _link_po(db, po_env, 500.0, imp)  # 100,000 USD
    _paid(db, s, 100000.0, 5000000.0, imp=imp, payment_type="Advance Payment")
    check = check_supplier_credit_limit(db, s.supplier_id, 60000.0, "USD")
    assert (check.utilization_amount, check.open_po_amount, check.decision) == (0.0, 0.0, "WITHIN_LIMIT")
    PurchaseOrderService(db).create(_po_data(po_env, 300.0), current_user_name="clerk")  # 60,000: not blocked


def test_partially_prepaid_po_counts_only_the_unpaid_part(db, po_env):
    s = po_env["supplier"]
    s.credit_limit = 150000.0
    db.commit()
    imp = _file(db, s, None, "IMP-LED-ADV2", payment_term="ADVANCE_PAYMENT")
    _link_po(db, po_env, 500.0, imp)  # 100,000 USD
    _paid(db, s, 40000.0, 2000000.0, imp=imp, payment_type="Advance Payment")
    ok = check_supplier_credit_limit(db, s.supplier_id, 60000.0, "USD")
    assert (ok.utilization_amount, ok.open_po_amount, ok.projected_amount, ok.decision) == (
        60000.0, 60000.0, 120000.0, "WITHIN_LIMIT")
    blocked = check_supplier_credit_limit(db, s.supplier_id, 100000.0, "USD")
    assert (blocked.projected_amount, blocked.decision) == (160000.0, "BLOCK")


def test_advance_in_another_currency_never_frees_credit():
    rates = {"USD": 50.0, "EUR": 55.0}.__getitem__
    assert ls.credit_exposure({"EUR": -50000.0}, {"USD": 9000.0}, "USD", rates) == (9000.0, 9000.0)


def test_new_po_on_an_already_invoiced_file_is_netted(db, po_env):
    s = po_env["supplier"]  # limit 10,000 USD
    imp = _file(db, s, [{"invoice_no": "CI-N", "amount": 9000.0, "currency": "USD", "exchange_rate": 50.0}],
                "IMP-LED-NET")
    linked = check_supplier_credit_limit(db, s.supplier_id, 9000.0, "USD", import_file_id=imp.import_file_id)
    assert (linked.utilization_amount, linked.requested_amount, linked.decision) == (9000.0, 0.0, "WITHIN_LIMIT")
    unlinked = check_supplier_credit_limit(db, s.supplier_id, 9000.0, "USD")
    assert (unlinked.requested_amount, unlinked.decision) == (9000.0, "BLOCK")
    _link_po(db, po_env, 45.0, imp)  # 9,000 USD on the invoiced file: goes through


def test_po_netting_converts_an_invoice_in_another_currency():
    rates = {"USD": 50.0, "EUR": 55.0}.__getitem__
    # 5,000 EUR invoiced = 5,500 USD at today's rates -> a 10,000 USD PO keeps 4,500 open.
    assert ls.open_po_exposure([(1, "USD", 10000.0)], {(1, "EUR"): 5000.0}, rates) == {"USD": 4500.0}
    # Each invoice amount nets one PO only.
    assert ls.open_po_exposure([(1, "USD", 3000.0), (1, "EUR", 3000.0)], {(1, "USD"): 3000.0}, rates) == {"EUR": 3000.0}


def test_egp_payment_on_usd_file_is_booked_in_usd_at_the_file_rate(db):
    s = _supplier(db)
    imp = _file(db, s, [{"invoice_no": "CI-1", "amount": 10000.0, "currency": "USD", "exchange_rate": 50.0}],
                "IMP-LED-E1")
    _paid(db, s, 500000.0, 500000.0, ccy="EGP", imp=imp)
    entries, warnings = sync_supplier_ledger(db, s.supplier_id)
    pay = next(e for e in entries if e.payment_id is not None)
    assert (pay.currency, pay.amount_fx, pay.amount_egp, pay.exchange_rate, pay.status) == (
        "USD", 10000.0, 500000.0, 50.0, "SETTLED")
    assert "EGP 500,000.00 @ 50" in pay.description
    balances = ls.get_supplier_realtime_balance(db, s.supplier_id)
    assert list(balances) == ["USD"] and balances["USD"].balance_fx == 0.0 and warnings == []


def test_egp_payment_uses_the_instrument_fx_rate_first(db):
    s = _supplier(db)
    imp = _file(db, s, [{"invoice_no": "CI-1", "amount": 10000.0, "currency": "USD", "exchange_rate": 50.0}],
                "IMP-LED-E2", payment_term="CAD")
    inst = ImportFinanceInstrument(instrument_type="CAD", instrument_number="CAD-E2", import_file_id=imp.import_file_id,
                                   issuing_bank="NBE", currency="USD", amount=10000.0, status="ACCEPTED")
    db.add(inst)
    db.flush()
    db.add(FxHedgingAndVariance(finance_instrument_id=inst.id, foreign_currency="USD", original_amount=10000.0,
                                booking_date=date(2026, 2, 1), booking_rate=51.0, booking_total_egp=510000.0))
    db.commit()
    _paid(db, s, 255000.0, 255000.0, ccy="EGP", imp=imp)  # 5,000 USD at the CAD booking rate 51
    entries, _ = sync_supplier_ledger(db, s.supplier_id)
    pay = next(e for e in entries if e.payment_id is not None)
    assert (pay.currency, pay.amount_fx, pay.exchange_rate) == ("USD", 5000.0, 51.0)


def test_egp_payment_without_a_rate_stays_in_egp_with_a_warning(db):
    s = _supplier(db)
    imp = _file(db, s, None, "IMP-LED-E3")
    imp.estimated_cost, imp.estimated_cost_currency = 1000.0, "GBP"  # no GBP rate registered
    db.commit()
    _paid(db, s, 50000.0, 50000.0, ccy="EGP", imp=imp)
    entries, warnings = sync_supplier_ledger(db, s.supplier_id)
    assert [(e.currency, e.amount_fx) for e in entries] == [("EGP", 50000.0)]
    assert ls.WARNING_EGP_PAYMENT_NOT_CONVERTED in [w["code"] for w in warnings]
