"""
Business Service for Docs Customs Approval Hub (DCA-001)
Cross-Document Matrix Engine, Dual-Tiered Approvals & Rectification Ticketing.

Transactions: the repository only flushes; every public write commits once here (DCA-06). The reviewer /
resolver / session author is the logged-in user passed by the router (DCA-03). ``current_user_name=None`` is
only for internal callers (tests, other services): they keep the legacy payload value.
"""

import logging
import re
from typing import Callable, Iterable, List, Optional, Dict, Any, Tuple
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from modules.docs_customs_approval.model import (
    CustomsDocumentApproval,
    DiscrepancyRectificationTicket,
    DocsCustomsApprovalSession,
)
from modules.docs_customs_approval.schemas import (
    CustomsDocumentApprovalCreate,
    CustomsDocumentApprovalUpdate,
    CommercialReviewPayload,
    CustomsBrokerReviewPayload,
    CrossDocumentMatrixCheckResponse,
    MatrixCheckItem,
    DiscrepancyTicketCreate,
    DiscrepancyTicketUpdate,
    DiscrepancyTicketResolve,
    DocsCustomsApprovalSessionCreate,
)
import modules.docs_customs_approval.repository as repo
import modules.docs_customs_approval.validators as validators
from modules.common.clock import cairo_today
from modules.common.regex_patterns import ACID_PATTERN
from modules.common.system_messages import msg, render_en
from modules.common.file_tracking import set_file_tracking
from modules.import_files.model import ImportFile
from modules.purchase_orders.model import PurchaseOrder
from modules.users.model import User
from modules.import_documentation.model import (
    AcidRegistrationSession,
    ShipmentDocumentItem,
)

logger = logging.getLogger(__name__)

CODE_ATTEMPTS = 2
# Weight / CBM agreement between the PO and the recorded packing lists (same default as the smart-upload
# invoice-vs-B/L cross-check). Value totals must agree to the cent.
MEASURE_TOLERANCE_PCT = 3.0
VALUE_TOLERANCE = 0.01

MATCH, MISMATCH, WARNING, MISSING, NOT_CHECKED = "Match", "Mismatch", "Warning", "Missing", "Not Checked"
FAILED_STATUSES = (MISMATCH, WARNING, MISSING)


def _actor(current_user_name: Optional[str], legacy: Optional[str], default: str = "SYSTEM") -> str:
    return current_user_name or legacy or default


def _insert_with_code(
    db: Session, build: Callable[[str], Any], next_code: Callable[[Session], str], create: Callable, retry: bool = True
):
    """Insert a row whose business code comes from ``next_code`` (``<PREFIX>-<year>-NNNN``, DCA-05). The unique
    constraint is the guard: on a collision the (single-row) transaction is rolled back and retried once. Callers
    that already wrote other rows in the transaction pass ``retry=False`` (a rollback would discard them)."""
    attempts = CODE_ATTEMPTS if retry else 1
    for attempt in range(1, attempts + 1):
        obj = build(next_code(db))
        try:
            return create(db, obj)
        except IntegrityError:
            db.rollback()
            if attempt == attempts:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="تعذر توليد رقم مرجعي فريد بسبب تعارض متزامن، يرجى إعادة المحاولة.",
                )


def _check_version(db: Session, record, submitted_version: Optional[int], entity: str, record_id: int,
                   attempted_by: Optional[str], details: str, updated_by: Optional[str] = None) -> None:
    current_version = getattr(record, "version", 1) or 1
    if submitted_version is None or submitted_version == current_version:
        return
    from modules.common.concurrency import ConcurrencyConflictException, log_concurrency_conflict

    log_concurrency_conflict(
        db=db,
        entity_name=entity,
        record_id=record_id,
        current_version=current_version,
        submitted_version=submitted_version,
        attempted_by=attempted_by,
        details=details,
    )
    kwargs = {"updated_by": updated_by} if updated_by is not None else {}
    raise ConcurrencyConflictException(
        entity=entity,
        record_id=record_id,
        current_version=current_version,
        submitted_version=submitted_version,
        updated_at=record.updated_at,
        **kwargs,
    )


def _po_for_file(db: Session, import_file: ImportFile) -> Optional[PurchaseOrder]:
    query = db.query(PurchaseOrder).filter(
        PurchaseOrder.import_file_id == import_file.import_file_id,
        PurchaseOrder.is_active == True,
    )
    if import_file.po_number:
        query = query.filter(PurchaseOrder.po_number == import_file.po_number)
    pos = query.all()
    if len(pos) == 1:
        return pos[0]
    return None


def _file_label(import_file: ImportFile) -> str:
    return import_file.custom_file_number or import_file.import_file_code


def _overall_after_commercial(approval: CustomsDocumentApproval) -> str:
    if approval.commercial_status == "Approved" and approval.customs_status == "Approved":
        return "Approved for Clearance"
    if approval.commercial_status == "Rejected":
        return "Rectification Required"
    return "Under Review"


def _overall_after_customs(approval: CustomsDocumentApproval) -> str:
    if approval.commercial_status == "Approved" and approval.customs_status == "Approved":
        return "Approved for Clearance"
    if approval.customs_status == "Rejected":
        return "Rectification Required"
    if approval.customs_status == "Conditionally Approved":
        return "Conditionally Approved"
    return "Under Review"


def create_approval_service(db: Session, payload: CustomsDocumentApprovalCreate) -> CustomsDocumentApproval:
    import_file = validators.validate_import_file_exists(db, payload.import_file_id)
    validators.validate_document_type(payload.document_type)

    po = _po_for_file(db, import_file)
    po_id = payload.po_id or (po.po_id if po else None)

    approval = _insert_with_code(
        db,
        lambda code: CustomsDocumentApproval(
            approval_code=code,
            import_file_id=payload.import_file_id,
            import_file_code=_file_label(import_file),
            po_id=po_id,
            document_type=payload.document_type,
            document_reference_no=payload.document_reference_no,
            document_date=payload.document_date,
            overall_status="Draft",
        ),
        repo.generate_approval_code,
        repo.create_approval,
    )
    db.commit()
    db.refresh(approval)
    return approval


def update_approval_service(
    db: Session, approval_id: int, payload: CustomsDocumentApprovalUpdate, current_user_name: Optional[str] = None
) -> Optional[CustomsDocumentApproval]:
    """Reference, date, notes and broker name only. ``commercial_status`` / ``customs_status`` /
    ``overall_status`` in the payload are ignored (DCA-03): the two review endpoints are the only way to a
    reviewed or "Approved for Clearance" state."""
    approval = repo.get_approval_by_id(db, approval_id)
    if not approval:
        return None

    _check_version(
        db, approval, getattr(payload, "version", None), "CustomsDocumentApproval", approval_id,
        current_user_name, f"Conflict detected while updating Approval #{approval.approval_code}",
    )

    if payload.document_reference_no is not None:
        approval.document_reference_no = payload.document_reference_no
    if payload.document_date is not None:
        approval.document_date = payload.document_date
    if payload.commercial_notes is not None:
        approval.commercial_notes = payload.commercial_notes
    if payload.customs_broker_name is not None:
        approval.customs_broker_name = payload.customs_broker_name
    if payload.customs_notes is not None:
        approval.customs_notes = payload.customs_notes

    repo.update_approval(db, approval)
    db.commit()
    db.refresh(approval)
    return approval


def get_approval_service(db: Session, approval_id: int) -> Optional[CustomsDocumentApproval]:
    return repo.get_approval_by_id(db, approval_id)


def list_approvals_service(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    document_type: Optional[str] = None,
    overall_status: Optional[str] = None,
    search: Optional[str] = None,
) -> List[CustomsDocumentApproval]:
    return repo.list_approvals(db, include_inactive, import_file_id, document_type, overall_status, search)


def soft_delete_approval_service(db: Session, approval_id: int) -> bool:
    deleted = repo.soft_delete_approval(db, approval_id)
    if deleted:
        db.commit()
    return deleted


def auto_generate_approvals_for_import_file_service(
    db: Session, import_file_id: int
) -> List[CustomsDocumentApproval]:
    """
    Ensures standard pre-clearance documents checklist exists for the import file (one commit).
    """
    import_file = validators.validate_import_file_exists(db, import_file_id)

    standard_docs = [
        "Commercial Invoice",
        "Packing List",
        "Bill of Lading",
        "Certificate of Origin",
        "EUR.1",
        "Inspection Certificate",
        "Fumigation Certificate",
        "Bank Form 4",
    ]

    existing = repo.list_approvals(db, import_file_id=import_file_id)
    existing_types = {item.document_type for item in existing}

    po = _po_for_file(db, import_file)
    po_id = po.po_id if po else None

    for doc_type in standard_docs:
        if doc_type not in existing_types:
            _insert_with_code(
                db,
                lambda code, doc_type=doc_type: CustomsDocumentApproval(
                    approval_code=code,
                    import_file_id=import_file_id,
                    import_file_code=_file_label(import_file),
                    po_id=po_id,
                    document_type=doc_type,
                    overall_status="Pending Review",
                ),
                repo.generate_approval_code,
                repo.create_approval,
                retry=False,
            )
    db.commit()
    return repo.list_approvals(db, import_file_id=import_file_id)


def upsert_original_documents_approval(
    db: Session,
    import_file_id: int,
    reference_no: str,
    user: str,
    commit: bool = False,
) -> CustomsDocumentApproval:
    """
    SH-04 hook (ODC-02, Q1): the originals were physically received AND verified, which is the commercial tier
    of the file's ORIGINAL_DOCUMENTS approval. Only that tier is approved; the customs tier stays with the broker
    (Pending on a new row, unchanged on an existing one). The code and the overall status follow the DCA rules.
    ``commit=False`` flushes only, so the caller's transaction stays atomic.
    """
    import_file = validators.validate_import_file_exists(db, import_file_id)
    now = datetime.now(timezone.utc)
    note = f"Original documents physically received and verified under collection no. {reference_no}"

    approval = repo.get_approval_by_type(db, import_file_id, validators.ORIGINAL_DOCUMENTS_LEGACY_TYPES)
    if approval is None:
        approval = _insert_with_code(
            db,
            lambda code: CustomsDocumentApproval(
                approval_code=code,
                import_file_id=import_file_id,
                import_file_code=_file_label(import_file),
                document_type=validators.ORIGINAL_DOCUMENTS_TYPE,
                document_reference_no=reference_no,
                commercial_status="Approved",
                commercial_reviewed_by=user,
                commercial_reviewed_at=now,
                commercial_notes=note,
                customs_status="Pending",
                overall_status="Under Review",
            ),
            repo.generate_approval_code,
            repo.create_approval,
            retry=False,
        )
    else:
        approval.document_reference_no = reference_no
        try:
            validators.validate_distinct_reviewers(approval, user, other_reviewer=approval.customs_reviewed_by)
        except HTTPException:
            # Four-eyes rule: the broker who signed the customs tier cannot also stamp the commercial tier through
            # SH-04. The receipt itself is still saved; the commercial review is left for another user.
            logger.warning(
                "SH-04: commercial stamp of %s skipped, %s already signed the customs tier",
                approval.approval_code, user,
            )
            repo.update_approval(db, approval)
            if commit:
                db.commit()
                db.refresh(approval)
            return approval
        approval.commercial_status = "Approved"
        approval.commercial_reviewed_by = user
        approval.commercial_reviewed_at = now
        approval.commercial_notes = note
        approval.overall_status = _overall_after_commercial(approval)
        repo.update_approval(db, approval)

    if commit:
        db.commit()
        db.refresh(approval)
    return approval


def submit_commercial_review_service(
    db: Session, approval_id: int, payload: CommercialReviewPayload, current_user_name: Optional[str] = None
) -> Optional[CustomsDocumentApproval]:
    approval = repo.get_approval_by_id(db, approval_id)
    if not approval:
        return None
    actor = _actor(current_user_name, payload.reviewer_name)

    _check_version(
        db, approval, getattr(payload, "version", None), "CustomsDocumentApproval", approval_id, actor,
        f"Conflict detected during commercial review of Approval #{approval.approval_code}",
        updated_by=approval.commercial_reviewed_by or approval.customs_reviewed_by,
    )

    validators.validate_distinct_reviewers(approval, actor, other_reviewer=approval.customs_reviewed_by)
    approval.commercial_status = validators.normalize_commercial_status(payload.status)
    approval.commercial_reviewed_by = actor
    approval.commercial_reviewed_at = datetime.now(timezone.utc)
    approval.commercial_notes = payload.notes
    approval.overall_status = _overall_after_commercial(approval)

    repo.update_approval(db, approval)
    db.commit()
    db.refresh(approval)
    return approval


def submit_customs_broker_review_service(
    db: Session, approval_id: int, payload: CustomsBrokerReviewPayload, current_user_name: Optional[str] = None
) -> Optional[CustomsDocumentApproval]:
    approval = repo.get_approval_by_id(db, approval_id)
    if not approval:
        return None
    actor = _actor(current_user_name, payload.reviewer_name)

    _check_version(
        db, approval, getattr(payload, "version", None), "CustomsDocumentApproval", approval_id, actor,
        f"Conflict detected during customs broker review of Approval #{approval.approval_code}",
        updated_by=approval.customs_reviewed_by or approval.commercial_reviewed_by,
    )

    validators.validate_distinct_reviewers(approval, actor, other_reviewer=approval.commercial_reviewed_by)
    approval.customs_status = validators.normalize_customs_status(payload.status)
    approval.customs_broker_name = payload.broker_name
    approval.customs_reviewed_by = actor
    approval.customs_reviewed_at = datetime.now(timezone.utc)
    approval.customs_notes = payload.notes
    approval.overall_status = _overall_after_customs(approval)

    repo.update_approval(db, approval)
    db.commit()
    db.refresh(approval)
    return approval


# --- Cross-Document Matrix Audit Engine ---

def _num(value: Any) -> Optional[float]:
    """Positive number or None (0 / empty / unparsable = not recorded)."""
    if value is None:
        return None
    try:
        number = float(str(value).replace(",", "").strip())
    except ValueError:
        return None
    return number if number > 0 else None


def _sum_entries(entries: Any, key: str) -> Optional[float]:
    if not isinstance(entries, list):
        return None
    values = [_num(e.get(key)) for e in entries if isinstance(e, dict)]
    values = [v for v in values if v is not None]
    return round(sum(values), 4) if values else None


def _hs_digits(value: Any) -> str:
    return re.sub(r"[^0-9]", "", str(value or ""))


def _tokens(value: Optional[str]) -> set:
    return set(re.sub(r"[^a-z0-9]", " ", (value or "").lower()).split()) - {"port", "of", "the"}


def _places_agree(a: Optional[str], b: Optional[str]) -> bool:
    return bool(_tokens(a) & _tokens(b))


def _within(a: float, b: float, tolerance_pct: float) -> bool:
    return abs(a - b) <= abs(a) * tolerance_pct / 100.0


def _acid_check(acid: Optional[AcidRegistrationSession], import_file: ImportFile, recommendations: List[str]) -> MatrixCheckItem:
    """ACID registered, valid (``ACID_PATTERN``: 19 digits) and identical in the Nafeza ACID session and the file."""
    sources = {
        "acid_session": (acid.acid_number or "").strip() if acid else "",
        "import_file": (import_file.acid_number or "").strip(),
    }
    values = {k: v for k, v in sources.items() if v}
    shown = values.get("acid_session") or values.get("import_file")
    if not values:
        recommendations.append("يجب تسجيل رقم الـ ACID المكون من 19 رقم على الملف وإدراجه في الفاتورة وبوليصة الشحن.")
        return MatrixCheckItem(
            parameter="ACID Number (19 Digits)", status=MISMATCH, acid_val="Missing",
            notes="تنبيه حرج: رقم الـ ACID غير مسجل على الملف أو في جلسة تسجيل الـ ACID.",
        )
    invalid = [v for v in values.values() if not ACID_PATTERN.fullmatch(v)]
    if invalid:
        recommendations.append("يجب تصحيح رقم الـ ACID ليكون 19 رقماً بالضبط.")
        return MatrixCheckItem(
            parameter="ACID Number (19 Digits)", status=MISMATCH, acid_val=shown,
            notes="تنبيه حرج: رقم الـ ACID المسجل غير صالح (يجب أن يكون 19 رقماً).",
        )
    if len(set(values.values())) > 1:
        recommendations.append("توحيد رقم الـ ACID بين ملف الاستيراد وجلسة تسجيل الـ ACID في نافذة.")
        return MatrixCheckItem(
            parameter="ACID Number (19 Digits)", status=MISMATCH, acid_val=values.get("acid_session"),
            notes=f"تنبيه حرج: رقم الـ ACID في جلسة نافذة ({values.get('acid_session')}) يختلف عن ملف الاستيراد ({values.get('import_file')}).",
        )
    return MatrixCheckItem(
        parameter="ACID Number (19 Digits)", status=MATCH, acid_val=shown,
        notes="رقم الـ ACID مسجل وصالح (19 رقم) ومتطابق بين ملف الاستيراد وجلسة نافذة.",
    )


def _hs_check(po: Optional[PurchaseOrder], acid: Optional[AcidRegistrationSession], recommendations: List[str]) -> MatrixCheckItem:
    po_codes = []
    for line in (po.line_items if po else []) or []:
        tariff = getattr(line, "tariff", None)
        if tariff is not None and _hs_digits(tariff.hs_code):
            po_codes.append(tariff.hs_code)
    acid_hs = None
    if acid is not None and isinstance(acid.generated_data, dict):
        acid_hs = acid.generated_data.get("hs_code") or None
    if not po_codes or not acid_hs:
        return MatrixCheckItem(
            parameter="HS Code Classification", status=NOT_CHECKED,
            invoice_val=", ".join(po_codes) or None, acid_val=acid_hs,
            notes="لم يتم التحقق: بند التعريفة غير مسجل في أصناف أمر الشراء أو في بيانات الـ ACID المولدة.",
        )
    po_digits = {_hs_digits(c) for c in po_codes}
    if _hs_digits(acid_hs) in po_digits:
        return MatrixCheckItem(
            parameter="HS Code Classification", status=MATCH, invoice_val=", ".join(po_codes), acid_val=acid_hs,
            notes=f"بند التعريفة {acid_hs} متطابق بين أصناف أمر الشراء وبيانات الـ ACID.",
        )
    recommendations.append(f"مراجعة بند التعريفة: الـ ACID ({acid_hs}) لا يطابق أصناف أمر الشراء ({', '.join(po_codes)}).")
    return MatrixCheckItem(
        parameter="HS Code Classification", status=WARNING, invoice_val=", ".join(po_codes), acid_val=acid_hs,
        notes=f"اختلاف في بند التعريفة: أمر الشراء ({', '.join(po_codes)}) مقابل الـ ACID ({acid_hs}).",
    )


def _value_check(po: Optional[PurchaseOrder], import_file: ImportFile, recommendations: List[str]) -> MatrixCheckItem:
    po_total = _num(po.total_amount_fob) if po else None
    po_curr = getattr(getattr(po, "currency", None), "currency_code", None) if po else None
    invoices = import_file.invoices_data if isinstance(import_file.invoices_data, list) else []
    inv_total = _sum_entries(invoices, "amount")
    inv_currencies = {str(i.get("currency")).upper() for i in invoices if isinstance(i, dict) and i.get("currency")}
    po_val = f"{po_total:,.2f} {po_curr or ''}".strip() if po_total else None
    inv_val = f"{inv_total:,.2f} {'/'.join(sorted(inv_currencies))}".strip() if inv_total else None
    if po_total is None or inv_total is None:
        return MatrixCheckItem(
            parameter="Total Value & Currency", status=NOT_CHECKED, invoice_val=inv_val, acid_val=po_val,
            notes="لم يتم التحقق: إجمالي أمر الشراء أو الفواتير المسجلة على الملف غير متوفر.",
        )
    if po_curr and inv_currencies and inv_currencies != {po_curr.upper()}:
        recommendations.append("توحيد عملة الفواتير المسجلة مع عملة أمر الشراء.")
        return MatrixCheckItem(
            parameter="Total Value & Currency", status=WARNING, invoice_val=inv_val, acid_val=po_val,
            notes=f"عملة الفواتير ({'/'.join(sorted(inv_currencies))}) تختلف عن عملة أمر الشراء ({po_curr}).",
        )
    if abs(po_total - inv_total) <= VALUE_TOLERANCE:
        return MatrixCheckItem(
            parameter="Total Value & Currency", status=MATCH, invoice_val=inv_val, acid_val=po_val,
            notes=f"إجمالي الفواتير المسجلة ({inv_val}) مطابق لإجمالي أمر الشراء.",
        )
    recommendations.append(f"مراجعة قيمة الفواتير ({inv_val}) مقابل إجمالي أمر الشراء ({po_val}).")
    return MatrixCheckItem(
        parameter="Total Value & Currency", status=WARNING, invoice_val=inv_val, acid_val=po_val,
        notes=f"إجمالي الفواتير ({inv_val}) لا يطابق إجمالي أمر الشراء ({po_val}).",
    )


def _measure_check(parameter: str, unit: str, po_value: Optional[float], pl_value: Optional[float],
                   label_ar: str, recommendations: List[str]) -> MatrixCheckItem:
    po_txt = f"{po_value:,.2f} {unit}" if po_value else None
    pl_txt = f"{pl_value:,.2f} {unit}" if pl_value else None
    if po_value is None or pl_value is None:
        return MatrixCheckItem(
            parameter=parameter, status=NOT_CHECKED, packing_val=pl_txt, invoice_val=po_txt,
            notes=f"لم يتم التحقق: {label_ar} غير مسجل في أمر الشراء أو في قوائم التعبئة على الملف.",
        )
    if _within(po_value, pl_value, MEASURE_TOLERANCE_PCT):
        return MatrixCheckItem(
            parameter=parameter, status=MATCH, packing_val=pl_txt, invoice_val=po_txt,
            notes=f"{label_ar} في قوائم التعبئة ({pl_txt}) مطابق لأمر الشراء ({po_txt}).",
        )
    recommendations.append(f"مراجعة {label_ar}: قوائم التعبئة ({pl_txt}) مقابل أمر الشراء ({po_txt}).")
    return MatrixCheckItem(
        parameter=parameter, status=WARNING, packing_val=pl_txt, invoice_val=po_txt,
        notes=f"اختلاف في {label_ar} يتجاوز {MEASURE_TOLERANCE_PCT:g}%: قوائم التعبئة ({pl_txt}) مقابل أمر الشراء ({po_txt}).",
    )


def _incoterm_ports_check(po: Optional[PurchaseOrder], acid: Optional[AcidRegistrationSession],
                          import_file: ImportFile, recommendations: List[str]) -> MatrixCheckItem:
    po_inco = getattr(getattr(po, "incoterm", None), "incoterm_code", None) if po else None
    file_inco = import_file.incoterm_code
    pairs: List[Tuple[str, Optional[str], Optional[str], bool]] = []
    if po_inco and file_inco:
        pairs.append(("Incoterm", po_inco, file_inco, po_inco.strip().upper() == file_inco.strip().upper()))
    if acid is not None and acid.pol_name and import_file.port_of_loading:
        pairs.append(("POL", acid.pol_name, import_file.port_of_loading, _places_agree(acid.pol_name, import_file.port_of_loading)))
    if acid is not None and acid.pod_name and import_file.port_of_discharge:
        pairs.append(("POD", acid.pod_name, import_file.port_of_discharge, _places_agree(acid.pod_name, import_file.port_of_discharge)))
    invoice_val = " | ".join(f"{name}: {a}" for name, a, _, _ in pairs) or None
    bl_val = " | ".join(f"{name}: {b}" for name, _, b, _ in pairs) or None
    if not pairs:
        return MatrixCheckItem(
            parameter="Incoterms & Ports", status=NOT_CHECKED,
            notes="لم يتم التحقق: شروط التسليم أو موانئ الشحن والتفريغ غير مسجلة في المصادر المطلوبة.",
        )
    mismatched = [name for name, _, _, ok in pairs if not ok]
    if mismatched:
        recommendations.append(f"مراجعة {', '.join(mismatched)} بين أمر الشراء / الـ ACID وملف الاستيراد.")
        return MatrixCheckItem(
            parameter="Incoterms & Ports", status=WARNING, invoice_val=invoice_val, bl_val=bl_val,
            notes=f"عدم تطابق في: {', '.join(mismatched)}.",
        )
    return MatrixCheckItem(
        parameter="Incoterms & Ports", status=MATCH, invoice_val=invoice_val, bl_val=bl_val,
        notes=f"متطابق ({', '.join(name for name, _, _, _ in pairs)}) بين أمر الشراء / الـ ACID وملف الاستيراد.",
    )


MANDATORY_DOCS_SPEC = [
    {
        "parameter": "Commercial Invoice Verification",
        "name_ar": "الفاتورة التجارية المعتمدة",
        "keys": ["Commercial Invoice", "Invoice", "Final Invoice", "Proforma Invoice"],
        "critical": True,
    },
    {
        "parameter": "Packing List Verification",
        "name_ar": "بيان العبوة ومطابقة الأوزان (Packing List)",
        "keys": ["Packing List", "PL", "Final Packing List"],
        "critical": True,
    },
    {
        "parameter": "Bill of Lading Verification",
        "name_ar": "بوليصة الشحن البحرية / الجوية (B/L)",
        "keys": ["Bill of Lading", "B/L", "Draft B/L", "Ocean Bill of Lading", "Air Waybill"],
        "critical": True,
    },
    {
        "parameter": "Certificate of Origin (COO / EUR.1)",
        "name_ar": "شهادة المنشأ والاتفاقيات التفضيلية (COO / EUR.1)",
        "keys": ["Certificate of Origin", "COO", "EUR.1", "Draft COO"],
        "critical": True,
    },
    {
        "parameter": "Inspection Certificate (Pre-Shipment / GOIEC)",
        "name_ar": "شهادة الفحص والتفتيش والمطابقة (Inspection Cert)",
        "keys": ["Inspection Certificate", "COC", "Pre-Shipment Inspection", "Certificate of Conformity"],
        "critical": False,
    },
    {
        "parameter": "Fumigation Certificate (ISPM 15)",
        "name_ar": "شهادة التبخير والصحة النباتية (Fumigation Cert)",
        "keys": ["Fumigation Certificate", "Phytosanitary Certificate", "Fumigation"],
        "critical": False,
    },
    {
        "parameter": "Bank Form 4 / LC Verification",
        "name_ar": "نموذج 4 البنكي أو الاعتماد المستندي (Bank Form 4 / LC)",
        "keys": ["Bank Form 4", "Form 4", "Letter of Credit", "L/C", "Form 9"],
        "critical": True,
    },
]


def _document_rows(approvals, docs, import_file: ImportFile, file_code: str,
                   recommendations: List[str]) -> Tuple[List[MatrixCheckItem], List[str], int]:
    """DC-04 shipping documents matrix and deficiency radar (unchanged rules, plan section 2)."""
    rows: List[MatrixCheckItem] = []
    missing_documents: List[str] = []
    approved_docs_count = 0

    for doc_spec in MANDATORY_DOCS_SPEC:
        matching_approval = next(
            (a for a in approvals if any(k.lower() == (a.document_type or "").lower() for k in doc_spec["keys"])),
            None,
        )
        matching_doc_item = next(
            (d for d in docs if any(k.lower() in (d.doc_name or "").lower() for k in doc_spec["keys"])),
            None,
        )

        inv_val = None
        bl_val = None

        if matching_approval:
            inv_val = matching_approval.document_reference_no or matching_approval.approval_code
            if matching_approval.overall_status == "Approved for Clearance" or (
                matching_approval.commercial_status == "Approved" and matching_approval.customs_status == "Approved"
            ):
                doc_status = MATCH
                doc_note = f"مستند {doc_spec['name_ar']} معتمد رسمياً ({matching_approval.approval_code})."
                approved_docs_count += 1
            elif matching_approval.overall_status in ("Rectification Required", "Rejected") or (
                matching_approval.commercial_status == "Rejected" or matching_approval.customs_status == "Rejected"
            ):
                doc_status = MISMATCH
                doc_note = f"تنبيه استدراك: مستند {doc_spec['name_ar']} به ملاحظات رفض أو استدراك ({matching_approval.approval_code})."
                recommendations.append(f"استدراك مستندي: مراجعة ملاحظات الرفض لمستند {doc_spec['name_ar']} وتعديلها مع المورد.")
            else:
                doc_status = WARNING
                doc_note = f"مستند {doc_spec['name_ar']} قيد المراجعة والتدقيق ({matching_approval.overall_status})."
        elif matching_doc_item:
            inv_val = matching_doc_item.doc_number or matching_doc_item.document_code
            if matching_doc_item.status in ("Approved", "Endorsed"):
                doc_status = MATCH
                doc_note = f"مستند {doc_spec['name_ar']} مستلم ومعتمد برقم ({matching_doc_item.doc_number})."
                approved_docs_count += 1
            elif matching_doc_item.status == "Rejected":
                doc_status = MISMATCH
                doc_note = f"مستند {doc_spec['name_ar']} مرفوض ويجب استبداله."
                recommendations.append(f"استدراك مستندي: تم رفض مستند {doc_spec['name_ar']} ويجب طلب مسودة معدلة.")
            else:
                doc_status = WARNING
                doc_note = f"مستند {doc_spec['name_ar']} مسجل برقم ({matching_doc_item.doc_number}) وقيد التدقيق."
        elif doc_spec["parameter"] == "Bank Form 4 / LC Verification" and import_file.form4_no and import_file.form4_no != "PENDING":
            doc_status = MATCH
            inv_val = import_file.form4_no
            doc_note = f"تم توثيق نموذج 4 / الاعتماد برقم مرجعي ({inv_val})."
            approved_docs_count += 1
        elif doc_spec["parameter"] == "Bill of Lading Verification" and import_file.bl_number and import_file.bl_number != "PENDING":
            doc_status = MATCH
            bl_val = import_file.bl_number
            doc_note = f"تم تسجيل رقم بوليصة الشحن ({bl_val})."
            approved_docs_count += 1
        else:
            doc_status = MISSING
            doc_note = f"تنبيه نقص مستندي (DC-04): مستند {doc_spec['name_ar']} غير مستوفى للشحنة."
            missing_documents.append(doc_spec["name_ar"])
            recommendations.append(f"تنبيه استكمال مستندي (DC-04): يجب استيفاء مستند {doc_spec['name_ar']} ورفعه على المنظومة للملف ({file_code}).")

        rows.append(
            MatrixCheckItem(
                parameter=doc_spec["parameter"],
                status=doc_status,
                invoice_val=inv_val or "N/A",
                bl_val=bl_val,
                notes=doc_note,
            )
        )
    return rows, missing_documents, approved_docs_count


def run_cross_document_matrix_check_service(
    db: Session, import_file_id: int
) -> CrossDocumentMatrixCheckResponse:
    """
    Cross-document audit (DCA-01). Every data check compares real sources only: PO lines / totals, the Nafeza
    ACID session, the invoices and packing lists recorded on the import file. A check whose source is missing is
    ``Not Checked``: it counts as neither passed nor failed and prevents "Fully Compliant".
    """
    import_file = validators.validate_import_file_exists(db, import_file_id)
    file_code = import_file.custom_file_number or import_file.import_file_code or f"IMP-{import_file_id}"

    po = _po_for_file(db, import_file)
    acid = (
        db.query(AcidRegistrationSession)
        .filter(AcidRegistrationSession.import_file_id == import_file_id, AcidRegistrationSession.is_active == True)
        .first()
    )
    docs = (
        db.query(ShipmentDocumentItem)
        .filter(ShipmentDocumentItem.import_file_id == import_file_id, ShipmentDocumentItem.is_active == True)
        .all()
    )
    open_tickets_count = repo.count_tickets_with_status(db, import_file_id, validators.OPEN_TICKET_STATUSES)

    recommendations: List[str] = []
    packing_lists = import_file.packing_lists_data if isinstance(import_file.packing_lists_data, list) else []
    checks: List[MatrixCheckItem] = [
        _acid_check(acid, import_file, recommendations),
        _hs_check(po, acid, recommendations),
        _value_check(po, import_file, recommendations),
        _measure_check(
            "Gross Weight (KG)", "KG", _num(po.total_gross_weight_kg) if po else None,
            _sum_entries(packing_lists, "gross_weight_kg"), "الوزن القائم", recommendations,
        ),
        _measure_check(
            "Total Volume (CBM)", "CBM", _num(po.total_cbm) if po else None,
            _sum_entries(packing_lists, "cbm"), "الحجم التكعيبي", recommendations,
        ),
        _incoterm_ports_check(po, acid, import_file, recommendations),
    ]

    approvals = repo.list_approvals(db, import_file_id=import_file_id)
    doc_rows, missing_documents, approved_docs_count = _document_rows(
        approvals, docs, import_file, file_code, recommendations
    )
    checks.extend(doc_rows)

    completeness_percent = round((approved_docs_count / len(MANDATORY_DOCS_SPEC)) * 100.0, 1)

    total_passed = sum(1 for c in checks if c.status == MATCH)
    total_failed = sum(1 for c in checks if c.status in FAILED_STATUSES)
    not_checked = sum(1 for c in checks if c.status == NOT_CHECKED)

    if any(c.status == MISMATCH for c in checks) or open_tickets_count > 0:
        overall = "Critical Blocker"
    elif total_failed > 0 or not_checked > 0:
        overall = "Discrepancies Found"
    else:
        overall = "Fully Compliant"
    if not_checked:
        recommendations.append(
            f"لم يتم التحقق من {not_checked} بند/بنود لعدم توفر البيانات المصدرية؛ يجب استكمالها قبل اعتبار الملف مطابقاً بالكامل."
        )

    if overall == "Fully Compliant" and completeness_percent >= 100.0:
        current_na = import_file.next_action or ""
        # Legacy Arabic text or the English render of a documents-related next action.
        if "المستندات" in current_na or "documents" in current_na.lower():
            set_file_tracking(import_file, next_action=msg("NA_STEP10_UPLOAD_APPROVED_TO_CARGOX"))
            db.commit()

    return CrossDocumentMatrixCheckResponse(
        import_file_id=import_file_id,
        import_file_code=file_code,
        overall_compliance=overall,
        total_checks=len(checks),
        passed_checks=total_passed,
        failed_checks=total_failed,
        not_checked_checks=not_checked,
        checks=checks,
        recommendations=recommendations,
        open_tickets_count=open_tickets_count,
        missing_documents=missing_documents,
        completeness_percent=completeness_percent,
    )


# --- Discrepancy Rectification Tickets Service ---

def create_rectification_ticket_service(
    db: Session, payload: DiscrepancyTicketCreate
) -> DiscrepancyRectificationTicket:
    import_file = validators.validate_import_file_exists(db, payload.import_file_id)
    validators.validate_ticket_creation(payload.description, payload.issue_category)
    validators.validate_ticket_approval(db, payload.approval_id, payload.import_file_id)
    severity = validators.normalize_ticket_severity(payload.severity)

    ticket = _insert_with_code(
        db,
        lambda code: DiscrepancyRectificationTicket(
            ticket_code=code,
            approval_id=payload.approval_id,
            import_file_id=payload.import_file_id,
            import_file_code=_file_label(import_file),
            issue_category=payload.issue_category,
            severity=severity,
            description=payload.description,
            expected_value=payload.expected_value,
            found_value=payload.found_value,
            supplier_action_required=payload.supplier_action_required,
            status="Open",
        ),
        repo.generate_ticket_code,
        repo.create_ticket,
    )
    db.commit()
    db.refresh(ticket)
    return ticket


def update_rectification_ticket_service(
    db: Session, ticket_id: int, payload: DiscrepancyTicketUpdate
) -> Optional[DiscrepancyRectificationTicket]:
    ticket = repo.get_ticket_by_id(db, ticket_id)
    if not ticket:
        return None

    if payload.issue_category is not None:
        ticket.issue_category = payload.issue_category
    if payload.severity is not None:
        ticket.severity = validators.normalize_ticket_severity(payload.severity)
    if payload.description is not None:
        ticket.description = payload.description
    if payload.expected_value is not None:
        ticket.expected_value = payload.expected_value
    if payload.found_value is not None:
        ticket.found_value = payload.found_value
    if payload.supplier_action_required is not None:
        ticket.supplier_action_required = payload.supplier_action_required
    if payload.supplier_response is not None:
        ticket.supplier_response = payload.supplier_response
    if payload.status is not None:
        ticket.status = validators.normalize_ticket_status(payload.status)

    repo.update_ticket(db, ticket)
    db.commit()
    db.refresh(ticket)
    return ticket


def resolve_rectification_ticket_service(
    db: Session, ticket_id: int, payload: DiscrepancyTicketResolve, current_user_name: Optional[str] = None
) -> Optional[DiscrepancyRectificationTicket]:
    ticket = repo.get_ticket_by_id(db, ticket_id)
    if not ticket:
        return None
    validators.validate_ticket_open(ticket)

    ticket.supplier_response = payload.supplier_response
    ticket.resolved_by = _actor(current_user_name, payload.resolved_by)
    ticket.status = validators.normalize_resolution_status(payload.new_status)
    ticket.resolved_at = datetime.now(timezone.utc)

    repo.update_ticket(db, ticket)
    db.commit()
    db.refresh(ticket)
    return ticket


def list_rectification_tickets_service(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    approval_id: Optional[int] = None,
    status: Optional[str] = None,
    severity: Optional[str] = None,
    search: Optional[str] = None,
) -> List[DiscrepancyRectificationTicket]:
    return repo.list_tickets(db, include_inactive, import_file_id, approval_id, status, severity, search)


# --- Docs Customs Approval Sessions Services (STEP-09) ---

def _session_not_ready(missing_statuses: List[str], open_tickets: int) -> HTTPException:
    parts = []
    if missing_statuses:
        parts.append(f"حالات المستندات غير محددة: {', '.join(missing_statuses)}")
    if open_tickets:
        parts.append(f"توجد {open_tickets} تذكرة استدراك مفتوحة")
    return HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail={
            "code": "DCA_SESSION_NOT_READY",
            "message": "لا يمكن اعتماد جلسة الموافقة الجمركية نهائياً: " + "؛ ".join(parts) + ".",
            "missing_statuses": missing_statuses,
            "open_tickets_count": open_tickets,
        },
    )


def create_customs_approval_session_service(
    db: Session, payload: DocsCustomsApprovalSessionCreate, current_user: Optional[User] = None
) -> DocsCustomsApprovalSession:
    """
    Save the file's customs-approval session as draft, or certify it (``is_draft=False``, DCA-04 / Q3):
    - a certified (final) session is locked: any further save -> 409 ``DCA_SESSION_FINAL_LOCKED``;
    - certification needs ``customs_clearance.update`` (router passes the user), the five document statuses sent
      explicitly (schema defaults are not accepted on a final save) and no open rectification ticket on the
      file -> otherwise 400 ``DCA_SESSION_NOT_READY``;
    - the author and the sign-offs come from the logged-in user, never from the payload (DCA-03);
    - STEP_09 -> STEP_10: a lifecycle failure propagates (the request fails, nothing is reported as certified).
    """
    import_file = validators.validate_import_file_exists(db, payload.import_file_id)
    file_code = import_file.custom_file_number or import_file.import_file_code or f"IMP-{payload.import_file_id}"
    actor = current_user.username if current_user is not None else (payload.created_by or "SYSTEM")
    final = not payload.is_draft

    if final and current_user is not None:
        from modules.auth.permissions import has_user_permission

        if not has_user_permission(db, current_user, "customs_clearance.update"):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. Permission 'customs_clearance.update' required.",
            )

    existing = repo.get_session_by_file_id(db, payload.import_file_id, include_drafts=True)
    if existing is not None and not existing.is_draft:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "DCA_SESSION_FINAL_LOCKED",
                "message": f"جلسة الموافقة الجمركية {existing.session_code} معتمدة نهائياً ولا يمكن تعديلها.",
                "session_code": existing.session_code,
            },
        )

    open_tickets = repo.count_tickets_with_status(db, payload.import_file_id, validators.OPEN_TICKET_STATUSES)
    if final:
        missing = [f for f in validators.SESSION_DOCUMENT_STATUS_FIELDS if f not in payload.model_fields_set]
        if missing or open_tickets:
            raise _session_not_ready(missing, open_tickets)

    data = payload.model_dump(exclude_unset=True)
    for ignored in ("version", "created_by", "commercial_signoff_by", "customs_signoff_by", "open_tickets_count"):
        data.pop(ignored, None)
    data["open_tickets_count"] = open_tickets
    today = cairo_today()
    if "commercial_signoff_date" in payload.model_fields_set or "commercial_signoff_by" in payload.model_fields_set:
        data["commercial_signoff_by"] = actor
        data["commercial_signoff_date"] = payload.commercial_signoff_date or today
    data.pop("customs_signoff_date", None)
    if final:
        # The customs sign-off is stamped only on a certified save (customs_clearance.update checked above).
        data["customs_signoff_by"] = actor
        data["customs_signoff_date"] = payload.customs_signoff_date or today

    if existing is not None:
        _check_version(
            db, existing, getattr(payload, "version", None), "DocsCustomsApprovalSession", existing.session_id,
            actor, f"Conflict detected while updating Customs Approval Session #{existing.session_code}",
            updated_by=existing.updated_by,
        )
        for k, v in data.items():
            setattr(existing, k, v)
        existing.import_file_code = file_code
        existing.updated_by = actor
        session_res = repo.update_session(db, existing)
    else:
        session_res = _insert_with_code(
            db,
            lambda code: DocsCustomsApprovalSession(
                session_code=code,
                import_file_code=file_code,
                created_by=actor,
                updated_by=actor,
                **data,
            ),
            repo.generate_session_code,
            repo.create_session,
        )

    if final:
        set_file_tracking(import_file, step_code="STEP_10", next_action=msg("NA_STEP10_UPLOAD_APPROVED_TO_CARGOX"))
        if (import_file.progress_percent or 0.0) < 60.0:
            import_file.progress_percent = 60.0

        from modules.lifecycle_board.service import transition_stage_activity_service

        transition_stage_activity_service(
            db=db,
            import_file_id=payload.import_file_id,
            completed_step_code="STEP_09",
            target_step_codes=["STEP_10"],
            notes=render_en("DOC_CUSTOMS_APPROVAL_GRANTED", {"session_code": session_res.session_code}, "note"),
            performed_by=actor,
        )

    db.commit()
    db.refresh(session_res)
    return session_res


def list_customs_approval_sessions_service(
    db: Session,
    import_file_id: Optional[int] = None,
    is_draft: Optional[bool] = None,
    search: Optional[str] = None,
) -> List[DocsCustomsApprovalSession]:
    return repo.list_sessions(db, import_file_id, is_draft, search)


def get_customs_approval_session_service(
    db: Session, session_id: int
) -> Optional[DocsCustomsApprovalSession]:
    return repo.get_session_by_id(db, session_id)
