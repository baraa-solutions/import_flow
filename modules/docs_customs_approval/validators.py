"""
Validators for Docs Customs Approval Hub (DCA-001)

Status values (DCA-07, Q6 safe default): requests are validated against the code sets below and the API keeps
storing and returning today's labels this wave. A request may send the label ("Under Review") or the code
("UNDER_REVIEW"); both map to the label. The T3 enum types DOC_REVIEW_STATUS / DOC_APPROVAL_STATUS /
TICKET_STATUS / TICKET_SEVERITY are a shared need (docs/plans/review-shared-needs.md, "03b shared needs").
"""

import re
from typing import Any, Dict, Optional, Sequence

from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from modules.common.validators import require_active
from modules.import_files.model import ImportFile


ORIGINAL_DOCUMENTS_TYPE = "ORIGINAL_DOCUMENTS"  # system row maintained by SH-04 (original documents collection)
ORIGINAL_DOCUMENTS_LEGACY_TYPES = (ORIGINAL_DOCUMENTS_TYPE, "ORIGINAL_BANK_DOCS", "Original Documents")

VALID_DOCUMENT_TYPES = [
    "Commercial Invoice",
    "Packing List",
    "Bill of Lading",
    "Certificate of Origin",
    "EUR.1",
    "Inspection Certificate",
    "Fumigation Certificate",
    "Bank Form 4",
    "Insurance Certificate",
    ORIGINAL_DOCUMENTS_TYPE,
]

# Overall approval status (DOC_APPROVAL_STATUS): label stored -> code.
DOC_APPROVAL_STATUS: Dict[str, str] = {
    "Draft": "DRAFT",
    "Pending Review": "PENDING_REVIEW",
    "Under Review": "UNDER_REVIEW",
    "Conditionally Approved": "CONDITIONALLY_APPROVED",
    "Approved for Clearance": "APPROVED_FOR_CLEARANCE",
    "Rectification Required": "RECTIFICATION_REQUIRED",
    "Rejected": "REJECTED",
}
VALID_APPROVAL_STATUSES = list(DOC_APPROVAL_STATUS)

# Review tier status (DOC_REVIEW_STATUS).
DOC_REVIEW_STATUS: Dict[str, str] = {
    "Pending": "PENDING",
    "Under Review": "UNDER_REVIEW",
    "Approved": "APPROVED",
    "Conditionally Approved": "CONDITIONALLY_APPROVED",
    "Rejected": "REJECTED",
}
COMMERCIAL_REVIEW_STATUSES = ("Pending", "Under Review", "Approved", "Rejected")
CUSTOMS_REVIEW_STATUSES = ("Pending", "Under Review", "Approved", "Conditionally Approved", "Rejected")

TICKET_STATUS: Dict[str, str] = {
    "Open": "OPEN",
    "Sent to Supplier": "SENT_TO_SUPPLIER",
    "Resolved": "RESOLVED",
    "Waived": "WAIVED",
    "Closed": "CLOSED",
}
OPEN_TICKET_STATUSES = ("Open", "Sent to Supplier")
RESOLUTION_STATUSES = ("Resolved", "Waived", "Closed")

TICKET_SEVERITY: Dict[str, str] = {"Critical": "CRITICAL", "Major": "MAJOR", "Minor": "MINOR"}

# The five documents of a certified customs-approval session (DCA-04).
SESSION_DOCUMENT_STATUS_FIELDS = (
    "final_invoice_status",
    "final_pl_status",
    "draft_bl_status",
    "coo_status",
    "coc_status",
)


def _key(value: str) -> str:
    return re.sub(r"[\s_\-/]+", "", value).lower()


def normalize_label(value: Any, labels: Dict[str, str], allowed: Sequence[str], field_label_ar: str) -> str:
    """Label of ``value`` (label or code, any case) within ``allowed``; 422 otherwise."""
    text = str(value).strip() if value is not None else ""
    lookup = {}
    for label in allowed:
        lookup[_key(label)] = label
        if label in labels:
            lookup[_key(labels[label])] = label
    found = lookup.get(_key(text)) if text else None
    if found is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"قيمة غير صالحة لـ {field_label_ar}: '{value}'. القيم المسموح بها: {', '.join(allowed)}.",
        )
    return found


def normalize_commercial_status(value: Any) -> str:
    return normalize_label(value, DOC_REVIEW_STATUS, COMMERCIAL_REVIEW_STATUSES, "حالة المراجعة التجارية")


def normalize_customs_status(value: Any) -> str:
    return normalize_label(value, DOC_REVIEW_STATUS, CUSTOMS_REVIEW_STATUSES, "حالة مراجعة المخلص الجمركي")


def normalize_ticket_status(value: Any) -> str:
    return normalize_label(value, TICKET_STATUS, list(TICKET_STATUS), "حالة تذكرة الاستدراك")


def normalize_resolution_status(value: Any) -> str:
    return normalize_label(value, TICKET_STATUS, RESOLUTION_STATUSES, "حالة إغلاق تذكرة الاستدراك")


def normalize_ticket_severity(value: Any) -> str:
    return normalize_label(value, TICKET_SEVERITY, list(TICKET_SEVERITY), "درجة خطورة التذكرة")


def validate_import_file_exists(db: Session, import_file_id: int) -> ImportFile:
    return require_active(db, ImportFile, import_file_id, "ملف الاستيراد", status_code=status.HTTP_404_NOT_FOUND)


def validate_document_type(doc_type: str) -> None:
    if doc_type not in VALID_DOCUMENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"نوع المستند '{doc_type}' غير صالح. الأنواع المسموح بها: {', '.join(VALID_DOCUMENT_TYPES)}",
        )


def validate_ticket_creation(description: str, issue_category: str) -> None:
    if not description or len(description.strip()) < 5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="وصف تذكرة الاستدراك يجب ألا يقل عن 5 أحرف.",
        )
    if not issue_category:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="تصنيف المشكلة مطلوب.",
        )


def validate_ticket_approval(db: Session, approval_id: Optional[int], import_file_id: int) -> None:
    """The linked approval must exist, be active and belong to the ticket's import file (DCA-07)."""
    if approval_id is None:
        return
    from modules.docs_customs_approval.model import CustomsDocumentApproval

    approval = require_active(db, CustomsDocumentApproval, approval_id, "اعتماد المستند")
    if approval.import_file_id != import_file_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"اعتماد المستند رقم {approval_id} لا يخص ملف الاستيراد رقم {import_file_id}.",
        )


def validate_distinct_reviewers(approval, actor: Optional[str], other_reviewer: Optional[str]) -> None:
    """Four-eyes rule: the commercial tier and the customs-broker tier of one approval are signed by two different
    users. 409 DCA_SAME_REVIEWER when ``actor`` already signed the other tier."""
    if not actor or not other_reviewer:
        return
    if actor.strip().lower() == other_reviewer.strip().lower():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "DCA_SAME_REVIEWER",
                "message": f"لا يمكن لنفس المستخدم ({actor}) اعتماد المراجعتين التجارية والجمركية لنفس المستند "
                f"({approval.approval_code}).",
                "approval_code": approval.approval_code,
                "reviewer": actor,
            },
        )


def validate_ticket_open(ticket) -> None:
    if ticket.status not in OPEN_TICKET_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "DCA_TICKET_CLOSED",
                "message": f"تذكرة الاستدراك {ticket.ticket_code} مغلقة بالفعل (الحالة: {ticket.status}).",
                "ticket_code": ticket.ticket_code,
                "status": ticket.status,
            },
        )
