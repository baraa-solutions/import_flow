"""
Validators for Import Files Master & Tracking Module
"""

from typing import List, Optional
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from modules.projects.model import Project
from modules.import_companies.model import ImportCompany


def validate_company_project_ownership(
    db: Session, company_id: Optional[int], project_ids: Optional[List[int]]
):
    """
    Validates that all specified project_ids belong strictly to the target company_id.
    Rule: الشحنة ممكن تكون لأكثر من مشروع بشرط أن تكون نفس الشركة المستوردة
    """
    if not project_ids or not company_id:
        return

    # Fetch projects
    projects = db.query(Project).filter(Project.project_id.in_(project_ids)).all()
    if len(projects) != len(project_ids):
        found_ids = {p.project_id for p in projects}
        missing_ids = set(project_ids) - found_ids
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"المشروعات ذات المعرفات التالية غير موجودة في النظام: {list(missing_ids)}",
        )

    # Verify company_id match if project has company_id
    for proj in projects:
        if proj.company_id and proj.company_id != company_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"المشروع '{proj.project_name}' (كود: {proj.project_code}) مرتبط بشركة مستوردة أخرى، لا يمكن ربطه بشحنة تابعة لشركة مختلفة.",
            )


def validate_custom_file_number_unique(
    db: Session, custom_file_number: Optional[str], current_file_id: Optional[int] = None
):
    """
    Ensures custom_file_number (e.g. 6701068100) is unique if provided.
    """
    if not custom_file_number or not custom_file_number.strip():
        return

    from modules.import_files.model import ImportFile

    query = db.query(ImportFile).filter(
        ImportFile.custom_file_number == custom_file_number.strip(),
        ImportFile.is_active == True,
    )
    if current_file_id:
        query = query.filter(ImportFile.import_file_id != current_file_id)

    if query.first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"رقم ملف الاستيراد '{custom_file_number}' مستخدم بالفعل لشحنة أخرى في النظام.",
        )


def validate_invoices_currency_consistency(invoices_data: Optional[List[dict]]):
    """
    Validates that all invoices linked to an import file share the exact same currency code.
    Rule: القيمة ليست ثابته بالدولار فقط وتكون بأكثر من عملة لكن يجب أن تكون كل الفواتير المربوطة على ملف شحنة بنفس العملة
    """
    if not invoices_data or len(invoices_data) <= 1:
        return

    currencies = set()
    for inv in invoices_data:
        if isinstance(inv, dict):
            curr = (inv.get("currency") or "USD").strip().upper()
            currencies.add(curr)

    if len(currencies) > 1:
        curr_list = ", ".join(sorted(currencies))
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"يجب أن تكون جميع الفواتير المربوطة بملف الشحنة بنفس العملة الموحدة. تم اكتشاف عملات متعددة: [{curr_list}]. يرجى توحيد العملة لجميع الفواتير المرتبطة بالملف.",
        )


ALLOWED_STATUS_TRANSITIONS = {
    "Open": {"In Progress", "On Hold", "Closed"},
    "Draft": {"In Progress", "On Hold", "Closed"},
    "In Progress": {"On Hold", "Closed"},
    "On Hold": {"In Progress", "Closed"},
    "Closed": {"In Progress"},
    "Archived": set(),
}

STATUS_CANONICAL = {
    "open": "Open",
    "draft": "Draft",
    "in progress": "In Progress",
    "on hold": "On Hold",
    "closed": "Closed",
    "archived": "Archived",
    "active": "In Progress",
}


def validate_status_transition(current_status: Optional[str], target_status: str) -> None:
    """
    Validates whether transitioning an import file from current_status to target_status is allowed.
    Allowed transitions:
      - Open / Draft -> In Progress, On Hold, Closed
      - In Progress -> On Hold, Closed
      - On Hold -> In Progress (resume), Closed
      - Closed -> In Progress (reopen)
      - Archived -> none
    Raises CodedHTTPException (409) with IF_STATUS_TRANSITION_INVALID if disallowed.
    """
    raw_current = (current_status or "").strip()
    raw_target = (target_status or "").strip()
    curr_norm = STATUS_CANONICAL.get(raw_current.lower(), raw_current)
    targ_norm = STATUS_CANONICAL.get(raw_target.lower(), raw_target)

    allowed = ALLOWED_STATUS_TRANSITIONS.get(curr_norm, set())
    if targ_norm not in allowed:
        from modules.common.errors import CodedHTTPException

        raise CodedHTTPException(
            status_code=status.HTTP_409_CONFLICT,
            code="IF_STATUS_TRANSITION_INVALID",
            message_ar=f"لا يمكن تغيير حالة ملف الشحنة من '{current_status}' إلى '{target_status}'.",
            **{"from": current_status or "", "to": target_status},
        )


def validate_payment_pathway_gate(
    import_file_code: Optional[str],
    payment_term: Optional[str],
    blocked: List[tuple],
    gate_labels: Optional[dict] = None,
    import_file_id: Optional[int] = None,
) -> None:
    """GP-002 stage gate of the exclusive payment pathway (modules/import_files/payment_milestones.py).

    ``blocked`` = ``[(gate, [missing milestone codes]), ...]`` from ``payment_milestones.blocking_milestones``.
    Raises 409 ``PAYMENT_MILESTONE_GATE_BLOCKED`` naming the first unsatisfied gate and every missing
    milestone (Arabic ``message`` + English ``message_en``)."""
    if not blocked:
        return
    from modules.import_files.payment_milestones import MILESTONES
    from modules.trade_finance.payment_pathway import pathway_error

    gate, missing = blocked[0]
    label_en, label_ar = (gate_labels or {}).get(gate, (gate, gate))
    missing_ar = "، ".join(MILESTONES[c].label_ar for c in missing)
    missing_en = "; ".join(MILESTONES[c].label_en for c in missing)
    raise pathway_error(
        status.HTTP_409_CONFLICT,
        "PAYMENT_MILESTONE_GATE_BLOCKED",
        f"لا يمكن نقل ملف الشحنة {import_file_code} إلى ({label_ar}) على مسار الدفع ({payment_term}) "
        f"قبل استيفاء البوابات المصرفية التالية: {missing_ar}.",
        message_en=(
            f"Import file {import_file_code} cannot move to ({label_en}) on payment pathway ({payment_term}) "
            f"until these banking milestones are met: {missing_en}."
        ),
        import_file_id=import_file_id,
        import_file_code=import_file_code,
        payment_term=payment_term,
        gate=gate,
        missing_milestones=list(missing),
        blocked_gates=[{"gate": g, "missing_milestones": list(m)} for g, m in blocked],
    )

