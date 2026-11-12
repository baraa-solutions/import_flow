"""
Exclusive Payment Pathway policy (مسار الدفع الحصري للشحنة).

Each import file is financed through exactly ONE primary payment pathway, stored in
``import_files.payment_term``:

    ADVANCE_PAYMENT  Cash in Advance / SWIFT (MT103)
    LC               Letter of Credit (MT700)
    CAD              Cash Against Documents / documentary collection (D/P, D/A)
    OPEN_ACCOUNT     Open Account / deferred payment

The pathway decides which trade-finance instruments and which payment-request types may be opened
for the file, so the SWIFT hub (financial_approval) and the trade-finance hub (LC / CAD) can never run
two conflicting financing instruments for the same goods.

Progressive entry (GP-001): ``payment_term`` may stay empty. The first instrument or payment request
whose type identifies a pathway fixes it; from then on the pathway is locked while that financing exists.
"""

import re
from typing import Iterable, List, Optional, Tuple

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.common import enum_codes

PAYMENT_TERM_ADVANCE = "ADVANCE_PAYMENT"
PAYMENT_TERM_LC = "LC"
PAYMENT_TERM_CAD = "CAD"
PAYMENT_TERM_OPEN_ACCOUNT = "OPEN_ACCOUNT"
PAYMENT_TERMS: Tuple[str, ...] = (
    PAYMENT_TERM_ADVANCE,
    PAYMENT_TERM_LC,
    PAYMENT_TERM_CAD,
    PAYMENT_TERM_OPEN_ACCOUNT,
)

# Payment-request types (financial_approval PAYMENT_TYPE codes) each pathway may use.
# FINAL_SETTLEMENT (balance / maturity payment) belongs to every pathway.
ALLOWED_PAYMENT_TYPES = {
    PAYMENT_TERM_ADVANCE: frozenset({"ADVANCE_PAYMENT", "AGAINST_BL", "FINAL_SETTLEMENT"}),
    PAYMENT_TERM_LC: frozenset({"LETTER_OF_CREDIT", "FINAL_SETTLEMENT"}),
    PAYMENT_TERM_CAD: frozenset({"DOCUMENTARY_COLLECTION", "FINAL_SETTLEMENT"}),
    PAYMENT_TERM_OPEN_ACCOUNT: frozenset({"FINAL_SETTLEMENT"}),
}

# Payment-request type -> the pathway it identifies (None: valid on several pathways).
PATHWAY_OF_PAYMENT_TYPE = {
    "ADVANCE_PAYMENT": PAYMENT_TERM_ADVANCE,
    "AGAINST_BL": PAYMENT_TERM_ADVANCE,
    "LETTER_OF_CREDIT": PAYMENT_TERM_LC,
    "DOCUMENTARY_COLLECTION": PAYMENT_TERM_CAD,
    "FINAL_SETTLEMENT": None,
}

# Trade-finance instrument types share the payment-term codes one to one.
INSTRUMENT_CANCELLED = "CANCELLED"

# Free-text PO payment terms -> pathway. Same rules and order as the Flutter
# ``PoPaymentTerms.fromText`` (collection before LC, LC before open account, advance last).
_TEXT_RULES: List[Tuple[str, "re.Pattern[str]"]] = [
    (
        PAYMENT_TERM_CAD,
        re.compile(
            r"\bCAD\b|CASH\s*AGAINST\s*DOC|DOCUMENTARY\s*COLLECTION|\bCOLLECTION\b|\bD\s*/\s*[PA]\b"
            r"|DOCUMENTS?\s*AGAINST|تحصيل\s*مستندي|مستندات",
            re.IGNORECASE,
        ),
    ),
    (
        PAYMENT_TERM_LC,
        re.compile(r"\bL\s*/\s*C\b|\bLC\b|LETTER\s*OF\s*CREDIT|DOCUMENTARY\s*CREDIT|اعتماد", re.IGNORECASE),
    ),
    (
        PAYMENT_TERM_OPEN_ACCOUNT,
        re.compile(
            r"OPEN\s*ACCOUNT|\bO\s*/\s*A\b|DEFERRED|\bNET\s*\d+|DAYS\s*(AFTER|FROM)|حساب\s*مفتوح|آجل",
            re.IGNORECASE,
        ),
    ),
    (
        PAYMENT_TERM_ADVANCE,
        re.compile(
            r"\bT\s*/\s*T\b|\bTT\b|TELEGRAPHIC|WIRE\s*TRANSFER|BANK\s*TRANSFER|\bSWIFT\b|ADVANCE"
            r"|PRE-?\s*PAYMENT|PREPAID|\bCASH\b|سويفت|مقدم|تحويل",
            re.IGNORECASE,
        ),
    ),
]


def pathway_error(status_code: int, code: str, message_ar: str, **params) -> HTTPException:
    """Coded error (same ``{"code", "message", **params}`` shape as the finance hubs)."""
    return HTTPException(status_code=status_code, detail={"code": code, "message": message_ar, **params})


# ── Normalization ───────────────────────────────────────────────────────────────

def normalize_payment_term(value: Optional[str]) -> Optional[str]:
    """Pathway code for a code, label or legacy label; ``None`` for empty. Unknown text raises ``ValueError``
    (pydantic turns it into a 422)."""
    if value is None or not str(value).strip():
        return None
    code = enum_codes.normalize(enum_codes.PAYMENT_TERM, str(value).strip())
    if code not in PAYMENT_TERMS:
        raise ValueError(f"Unknown payment_term '{value}'. Allowed: {', '.join(PAYMENT_TERMS)}")
    return code


def payment_term_from_text(text: Optional[str]) -> Optional[str]:
    """Best-effort pathway of a free-text PO payment term ("LC at Sight", "30% T/T advance", ...)."""
    if not text or not text.strip():
        return None
    try:
        return normalize_payment_term(text)
    except ValueError:
        pass
    for code, pattern in _TEXT_RULES:
        if pattern.search(text):
            return code
    return None


def payment_term_from_purchase_orders(db: Session, po_ids: Optional[Iterable[int]]) -> Optional[str]:
    """The single pathway shared by the linked POs, or ``None`` when absent or ambiguous."""
    ids = [int(i) for i in (po_ids or []) if i is not None]
    if not ids:
        return None
    from modules.purchase_orders.model import PurchaseOrder

    terms = {
        payment_term_from_text(row.payment_terms)
        for row in db.query(PurchaseOrder.payment_terms).filter(PurchaseOrder.po_id.in_(ids)).all()
    }
    terms.discard(None)
    return terms.pop() if len(terms) == 1 else None


# ── Active financing of a file ──────────────────────────────────────────────────

def _active_instruments(db: Session, import_file_id: int, exclude_id: Optional[int] = None):
    from modules.trade_finance.model import ImportFinanceInstrument

    query = db.query(ImportFinanceInstrument).filter(
        ImportFinanceInstrument.import_file_id == import_file_id,
        ImportFinanceInstrument.is_active == True,  # noqa: E712
        ImportFinanceInstrument.status != INSTRUMENT_CANCELLED,
    )
    if exclude_id is not None:
        query = query.filter(ImportFinanceInstrument.id != exclude_id)
    return query.all()


def _active_payment_requests(db: Session, import_file_id: int, exclude_id: Optional[int] = None):
    from modules.financial_approval.model import PaymentRequestSession

    query = db.query(PaymentRequestSession).filter(
        PaymentRequestSession.import_file_id == import_file_id,
        PaymentRequestSession.is_active == True,  # noqa: E712
        PaymentRequestSession.status != "Rejected",
    )
    if exclude_id is not None:
        query = query.filter(PaymentRequestSession.payment_id != exclude_id)
    return query.all()


def _normalized_payment_type(payment_type: Optional[str]) -> Optional[str]:
    from modules.financial_approval.validators import normalize_payment_type

    return normalize_payment_type(payment_type)


def conflicting_financing(db: Session, import_file_id: int, payment_term: str) -> List[str]:
    """References of the file's active instruments / payment requests that do not belong to ``payment_term``."""
    conflicts = [
        inst.instrument_number
        for inst in _active_instruments(db, import_file_id)
        if (inst.instrument_type or "").upper() != payment_term
    ]
    allowed = ALLOWED_PAYMENT_TYPES[payment_term]
    conflicts += [
        req.payment_code
        for req in _active_payment_requests(db, import_file_id)
        if _normalized_payment_type(req.payment_type) not in allowed
    ]
    return conflicts


# ── Guards ──────────────────────────────────────────────────────────────────────

def _load_file(db: Session, import_file_id: int):
    from modules.import_files.model import ImportFile

    return db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()


def _lock_pathway(import_file, payment_term: str, actor: str) -> None:
    import_file.payment_term = payment_term
    import_file.updated_by = actor


def ensure_payment_term_change_allowed(db: Session, import_file, new_term: Optional[str]) -> None:
    """409 when the file already holds financing of another pathway (the pathway is locked)."""
    current = getattr(import_file, "payment_term", None)
    if new_term == current:
        return
    if new_term is None:
        blockers = [i.instrument_number for i in _active_instruments(db, import_file.import_file_id)]
        blockers += [r.payment_code for r in _active_payment_requests(db, import_file.import_file_id)]
    else:
        blockers = conflicting_financing(db, import_file.import_file_id, new_term)
    if blockers:
        raise pathway_error(
            status.HTTP_409_CONFLICT,
            "PAYMENT_PATHWAY_LOCKED",
            f"لا يمكن تغيير مسار الدفع للملف {import_file.import_file_code} لوجود أدوات تمويل أو طلبات صرف "
            f"قائمة على المسار الحالي ({', '.join(blockers)}). يجب إلغاؤها أولاً.",
            import_file_code=import_file.import_file_code,
            payment_term=current,
            requested_payment_term=new_term,
            blocking_references=blockers,
        )


def ensure_instrument_allowed(
    db: Session, import_file_id: int, instrument_type: str, actor: str = "system", exclude_id: Optional[int] = None
) -> None:
    """One active primary instrument per file, of the file's pathway. Fixes the pathway when still empty."""
    import_file = _load_file(db, import_file_id)
    if import_file is None:
        return
    inst_type = (instrument_type or "").upper()
    term = import_file.payment_term

    if term is not None and inst_type != term:
        raise pathway_error(
            status.HTTP_409_CONFLICT,
            "PAYMENT_PATHWAY_CONFLICT",
            f"مسار الدفع المعتمد للملف {import_file.import_file_code} هو ({term})، "
            f"ولا يمكن فتح أداة تمويل من نوع ({inst_type}) لنفس الشحنة.",
            import_file_code=import_file.import_file_code,
            payment_term=term,
            requested_type=inst_type,
        )

    existing = _active_instruments(db, import_file_id, exclude_id=exclude_id)
    if existing:
        raise pathway_error(
            status.HTTP_409_CONFLICT,
            "PAYMENT_INSTRUMENT_ALREADY_OPEN",
            f"يوجد بالفعل أداة تمويل رئيسية قائمة للملف {import_file.import_file_code} "
            f"({existing[0].instrument_number}). يجب إلغاؤها قبل فتح أداة جديدة.",
            import_file_code=import_file.import_file_code,
            instrument_number=existing[0].instrument_number,
        )

    if term is None:
        conflicts = conflicting_financing(db, import_file_id, inst_type)
        if conflicts:
            raise pathway_error(
                status.HTTP_409_CONFLICT,
                "PAYMENT_PATHWAY_CONFLICT",
                f"لا يمكن فتح أداة تمويل من نوع ({inst_type}) للملف {import_file.import_file_code} "
                f"لوجود طلبات صرف على مسار دفع آخر ({', '.join(conflicts)}).",
                import_file_code=import_file.import_file_code,
                requested_type=inst_type,
                blocking_references=conflicts,
            )
        _lock_pathway(import_file, inst_type, actor)


def ensure_payment_type_allowed(
    db: Session, import_file_id: Optional[int], payment_type: Optional[str], actor: str = "system",
    exclude_id: Optional[int] = None,
) -> None:
    """A payment request must use a type of the file's pathway. Fixes the pathway when still empty and the
    type identifies one (FINAL_SETTLEMENT alone does not)."""
    if not import_file_id:
        return
    import_file = _load_file(db, import_file_id)
    if import_file is None:
        return
    code = _normalized_payment_type(payment_type)
    term = import_file.payment_term

    if term is not None:
        if code not in ALLOWED_PAYMENT_TYPES[term]:
            raise pathway_error(
                status.HTTP_409_CONFLICT,
                "PAYMENT_PATHWAY_CONFLICT",
                f"مسار الدفع المعتمد للملف {import_file.import_file_code} هو ({term})، "
                f"ولا يسمح بطلب صرف من نوع ({code}).",
                import_file_code=import_file.import_file_code,
                payment_term=term,
                requested_type=code,
                allowed_types=sorted(ALLOWED_PAYMENT_TYPES[term]),
            )
        return

    implied = PATHWAY_OF_PAYMENT_TYPE.get(code)
    if implied is None:
        return
    conflicts = [
        inst.instrument_number
        for inst in _active_instruments(db, import_file_id)
        if (inst.instrument_type or "").upper() != implied
    ]
    conflicts += [
        req.payment_code
        for req in _active_payment_requests(db, import_file_id, exclude_id=exclude_id)
        if _normalized_payment_type(req.payment_type) not in ALLOWED_PAYMENT_TYPES[implied]
    ]
    if conflicts:
        raise pathway_error(
            status.HTTP_409_CONFLICT,
            "PAYMENT_PATHWAY_CONFLICT",
            f"لا يمكن إنشاء طلب صرف من نوع ({code}) للملف {import_file.import_file_code} "
            f"لوجود تمويل قائم على مسار دفع آخر ({', '.join(conflicts)}).",
            import_file_code=import_file.import_file_code,
            requested_type=code,
            blocking_references=conflicts,
        )
    _lock_pathway(import_file, implied, actor)
