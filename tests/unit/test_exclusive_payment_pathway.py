"""
Exclusive payment pathway per shipment (Trello UQdbFB3O): one primary financing pathway per import file
(ADVANCE_PAYMENT / LC / CAD / OPEN_ACCOUNT) enforced across the trade-finance hub, the SWIFT payment-request hub
and the import file itself, at application level and in the database.
"""
from datetime import date

import pytest
from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy.exc import IntegrityError

import modules.financial_approval.service as payment_service
from modules.financial_approval.schemas import PaymentRequestCreate, PaymentRequestUpdate
from modules.import_files.import_file_lifecycle_service import update_import_file_service
from modules.import_files.schemas import ImportFileUpdate
from modules.purchase_orders.model import PurchaseOrder
from modules.trade_finance.model import ImportFinanceInstrument
from modules.trade_finance.payment_pathway import (
    normalize_payment_term,
    payment_term_from_purchase_orders,
    payment_term_from_text,
)
from modules.trade_finance.schemas import ImportFinanceInstrumentCreate, ImportFinanceInstrumentUpdate
from modules.trade_finance.service import TradeFinanceService

from test_phase02_support import make_session, seed_file, seed_rate


@pytest.fixture
def db():
    session = make_session()
    seed_rate(session, "EGP", 1.0, base=True)
    seed_rate(session, "USD", 50.0)
    yield session
    session.close()


def _code(exc) -> str:
    return exc.value.detail["code"]


def _instrument(db, import_file_id, instrument_type="LC", number=None):
    return TradeFinanceService(db).create_instrument(ImportFinanceInstrumentCreate(
        instrument_type=instrument_type,
        instrument_number=number or f"{instrument_type}-{import_file_id}-{date.today().isoformat()}",
        import_file_id=import_file_id,
        issuing_bank="National Bank of Egypt",
        amount=50000.0,
    ))


def _payment(db, import_file_id, payment_type):
    return payment_service.create_payment_request_service(db, PaymentRequestCreate(
        title="Supplier payment",
        supplier_name="Supplier Co",
        payment_type=payment_type,
        requested_amount=10000.0,
        currency_code="USD",
        exchange_rate=50.0,
        due_date=date(2026, 12, 1),
        import_file_id=import_file_id,
    ))


def _seed_po(db, po_number, payment_terms):
    po = PurchaseOrder(
        po_number=po_number, project_id=1, company_id=1, supplier_id=1, incoterm_id=1, currency_id=1,
        total_amount_fob=1000.0, payment_terms=payment_terms, status="DRAFT",
    )
    db.add(po)
    db.commit()
    return po


# ── Normalization ───────────────────────────────────────────────────────────────

@pytest.mark.parametrize("value,expected", [
    ("LC", "LC"),
    ("lc", "LC"),
    ("ADVANCE_PAYMENT", "ADVANCE_PAYMENT"),
    ("SWIFT", "ADVANCE_PAYMENT"),
    ("Letter of Credit / LC", "LC"),
    ("CAD / Cash Against Documents", "CAD"),
    ("Open Account / Deferred Payment", "OPEN_ACCOUNT"),
    (None, None),
    ("  ", None),
])
def test_normalize_payment_term(value, expected):
    assert normalize_payment_term(value) == expected


def test_normalize_payment_term_rejects_unknown_text():
    with pytest.raises(ValueError):
        normalize_payment_term("Barter")
    with pytest.raises(ValidationError):
        ImportFileUpdate(payment_term="Barter")


@pytest.mark.parametrize("text,expected", [
    ("LC at Sight / اعتماد مستندي", "LC"),
    ("Cash in Advance / SWIFT", "ADVANCE_PAYMENT"),
    ("30% T/T advance, 70% before shipment", "ADVANCE_PAYMENT"),
    ("D/P at sight", "CAD"),
    ("Cash Against Documents", "CAD"),
    ("Net 60 days after B/L", "OPEN_ACCOUNT"),
    ("حساب مفتوح", "OPEN_ACCOUNT"),
    ("to be agreed", None),
    ("", None),
])
def test_payment_term_from_po_text(text, expected):
    assert payment_term_from_text(text) == expected


# ── Inheritance from the purchase order ─────────────────────────────────────────

def test_pathway_inherited_from_linked_pos(db):
    po1 = _seed_po(db, "PO-PT-1", "LC at Sight / اعتماد مستندي")
    po2 = _seed_po(db, "PO-PT-2", "Letter of Credit / LC")
    assert payment_term_from_purchase_orders(db, [po1.po_id, po2.po_id]) == "LC"


def test_ambiguous_or_missing_po_terms_are_not_inherited(db):
    po1 = _seed_po(db, "PO-PT-3", "LC at Sight")
    po2 = _seed_po(db, "PO-PT-4", "Cash in Advance / SWIFT")
    assert payment_term_from_purchase_orders(db, [po1.po_id, po2.po_id]) is None
    assert payment_term_from_purchase_orders(db, []) is None


def test_linking_a_po_fills_an_empty_pathway(db):
    po = _seed_po(db, "PO-PT-5", "CAD / Cash Against Documents")
    imp = seed_file(db)
    updated = update_import_file_service(db, imp.import_file_id, ImportFileUpdate(po_ids=[po.po_id]))
    assert updated.payment_term == "CAD"


# ── Trade-finance instruments ───────────────────────────────────────────────────

def test_first_instrument_locks_an_empty_pathway(db):
    imp = seed_file(db)
    _instrument(db, imp.import_file_id, "LC")
    db.refresh(imp)
    assert imp.payment_term == "LC"


def test_instrument_of_another_pathway_is_rejected(db):
    imp = seed_file(db, payment_term="ADVANCE_PAYMENT")
    with pytest.raises(HTTPException) as exc:
        _instrument(db, imp.import_file_id, "LC")
    assert exc.value.status_code == 409 and _code(exc) == "PAYMENT_PATHWAY_CONFLICT"


def test_only_one_active_instrument_per_file(db):
    imp = seed_file(db, payment_term="LC")
    first = _instrument(db, imp.import_file_id, "LC", number="LC-001")
    with pytest.raises(HTTPException) as exc:
        _instrument(db, imp.import_file_id, "LC", number="LC-002")
    assert _code(exc) == "PAYMENT_INSTRUMENT_ALREADY_OPEN"

    TradeFinanceService(db).update_instrument(first.id, ImportFinanceInstrumentUpdate(status="CANCELLED"))
    replacement = _instrument(db, imp.import_file_id, "LC", number="LC-002")
    assert replacement.id != first.id

    with pytest.raises(HTTPException) as exc:
        TradeFinanceService(db).update_instrument(first.id, ImportFinanceInstrumentUpdate(status="ISSUED"))
    assert _code(exc) == "PAYMENT_INSTRUMENT_ALREADY_OPEN"


def test_instrument_blocked_by_payment_request_of_another_pathway(db):
    imp = seed_file(db)
    _payment(db, imp.import_file_id, "ADVANCE_PAYMENT")
    with pytest.raises(HTTPException) as exc:
        _instrument(db, imp.import_file_id, "LC")
    assert _code(exc) == "PAYMENT_PATHWAY_CONFLICT"


# ── SWIFT payment requests ──────────────────────────────────────────────────────

def test_advance_payment_blocked_on_lc_file(db):
    imp = seed_file(db, payment_term="LC")
    with pytest.raises(HTTPException) as exc:
        _payment(db, imp.import_file_id, "ADVANCE_PAYMENT")
    assert exc.value.status_code == 409 and _code(exc) == "PAYMENT_PATHWAY_CONFLICT"
    assert "LETTER_OF_CREDIT" in exc.value.detail["allowed_types"]


@pytest.mark.parametrize("term,payment_type", [
    ("LC", "LETTER_OF_CREDIT"),
    ("LC", "FINAL_SETTLEMENT"),
    ("ADVANCE_PAYMENT", "AGAINST_BL"),
    ("CAD", "DOCUMENTARY_COLLECTION"),
    ("OPEN_ACCOUNT", "FINAL_SETTLEMENT"),
])
def test_payment_types_of_the_pathway_are_allowed(db, term, payment_type):
    imp = seed_file(db, payment_term=term)
    assert _payment(db, imp.import_file_id, payment_type).payment_id


def test_first_payment_request_locks_the_pathway(db):
    imp = seed_file(db)
    _payment(db, imp.import_file_id, "ADVANCE_PAYMENT")
    db.refresh(imp)
    assert imp.payment_term == "ADVANCE_PAYMENT"


def test_final_settlement_does_not_lock_the_pathway(db):
    imp = seed_file(db)
    _payment(db, imp.import_file_id, "FINAL_SETTLEMENT")
    db.refresh(imp)
    assert imp.payment_term is None


def test_changing_request_type_to_another_pathway_is_rejected(db):
    imp = seed_file(db)
    req = _payment(db, imp.import_file_id, "ADVANCE_PAYMENT")
    with pytest.raises(HTTPException) as exc:
        payment_service.update_payment_request_service(
            db, req.payment_id, PaymentRequestUpdate(payment_type="LETTER_OF_CREDIT", version=req.version)
        )
    assert _code(exc) == "PAYMENT_PATHWAY_CONFLICT"


def test_payment_without_import_file_is_not_restricted(db):
    assert _payment(db, None, "LETTER_OF_CREDIT").payment_id


# ── Changing the file's pathway ─────────────────────────────────────────────────

def test_pathway_change_blocked_while_financing_exists(db):
    imp = seed_file(db)
    _instrument(db, imp.import_file_id, "LC")
    with pytest.raises(HTTPException) as exc:
        update_import_file_service(db, imp.import_file_id, ImportFileUpdate(payment_term="ADVANCE_PAYMENT"))
    assert exc.value.status_code == 409 and _code(exc) == "PAYMENT_PATHWAY_LOCKED"
    with pytest.raises(HTTPException):
        update_import_file_service(db, imp.import_file_id, ImportFileUpdate(payment_term=None))


def test_pathway_change_allowed_without_financing(db):
    imp = seed_file(db, payment_term="LC")
    updated = update_import_file_service(db, imp.import_file_id, ImportFileUpdate(payment_term="CAD"))
    assert updated.payment_term == "CAD"


# ── Database constraints ────────────────────────────────────────────────────────

def test_database_rejects_unknown_payment_term(db):
    with pytest.raises(IntegrityError):
        seed_file(db, payment_term="BARTER")
    db.rollback()


def test_database_rejects_second_active_instrument(db):
    imp = seed_file(db, payment_term="LC")
    for number in ("LC-DB-1", "LC-DB-2"):
        db.add(ImportFinanceInstrument(
            instrument_type="LC", instrument_number=number, import_file_id=imp.import_file_id,
            issuing_bank="Bank", amount=1.0,
        ))
    with pytest.raises(IntegrityError):
        db.commit()
    db.rollback()

    db.add_all([
        ImportFinanceInstrument(instrument_type="LC", instrument_number="LC-DB-3", import_file_id=imp.import_file_id,
                                issuing_bank="Bank", amount=1.0, status="CANCELLED"),
        ImportFinanceInstrument(instrument_type="LC", instrument_number="LC-DB-4", import_file_id=imp.import_file_id,
                                issuing_bank="Bank", amount=1.0),
    ])
    db.commit()
