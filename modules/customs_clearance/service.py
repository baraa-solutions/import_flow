"""
Phases 6-7 customs preparation and clearance services (CS-01..CS-03, CL-01..CL-05, under-bond / lab).

Every mutating service follows one order (06-07 plan CL-12 / CL-13):
1. validate, 2. write the business rows (record + import file sync), 3. ONE ``db.commit()``,
4. run each side effect (tasks, notification, lifecycle board, audit log, settlement snapshot) through
   ``best_effort``: a failing side effect is logged and rolled back alone, it never undoes the saved business write.
"""
import logging
import random
import uuid
from datetime import date, datetime, timedelta, timezone
from typing import Any, Callable, Dict, Iterable, List, Optional, Sequence, TypeVar

from fastapi import HTTPException, status
from sqlalchemy import or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from modules.common import enum_codes
from modules.common.errors import best_effort
from modules.common.file_tracking import set_file_tracking
from modules.common.system_messages import SysMsg, msg, render_en
from modules.common.validators import not_null_columns
from modules.import_files.model import ImportFile

from . import repository as repo
from .model import ClearanceExpenseInvoice, CustomsClearanceRecord
from .schemas import (
    ClearanceExpenseInvoiceCreate,
    ClearanceExpenseInvoiceResponse,
    ClearanceInvoicesSummaryResponse,
    CompleteReleaseSubmit,
    CustomsBrokerAuthorizationSubmit,
    CustomsClearanceCreate,
    CustomsClearanceUpdate,
    CustomsDeclaration46Submit,
    CustomsDutyPaymentSubmit,
    CustomsFinalReleaseSubmit,
    CustomsInspectionSamplingSubmit,
    DeliveryOrderPaymentSubmit,
    DutyPaymentSubmit,
    FinalDutyAssessmentSubmit,
    LabTestResultSubmit,
    UnderBondReleaseSubmit,
)
from .validators import (
    DUTY_COMPONENT_FIELDS,
    FINAL_RELEASE_STATUS,
    LAB_CONFORMING,
    acid_expiry_date,
    coded_error,
    is_assessed,
    is_duty_fully_paid,
    validate_acid_not_expired_for_release,
    validate_bank_receipt_no,
    validate_duty_payment_amount,
    validate_lab_result_open,
    validate_release_not_quarantined,
    validate_release_payment,
    validate_release_permit_no,
    validate_settlement_open,
    validate_under_bond_allowed,
    SETTLEMENT_LOCKED_STATUSES,
)

logger = logging.getLogger(__name__)

T = TypeVar("T")

SYSTEM_USER = "System"
CODE_ATTEMPTS = 3
_CODE_COLUMNS = ("customs_clearance_records.clearance_code", "clearance_expense_invoices.invoice_code")
_FILE_NOT_FOUND = "ملف الشحنة الاستيرادية غير موجود أو محذوف."
_RECORD_NOT_FOUND = "سجل التخليص الجمركي والمعاينة غير موجود."

# CL-05 aggregates: explicit CLEARANCE_EXPENSE_CATEGORY code sets (legacy labels are normalized on read).
CLEARANCE_FEE_CATEGORIES = frozenset({"BROKER_FEES", "OTHER_CLEARANCE"})
PORT_DUES_CATEGORIES = frozenset({"PORT_DUES_WHARFAGE", "STORAGE_DEMURRAGE"})
HANDLING_CATEGORIES = frozenset({"STEVEDORING_HANDLING"})
# Free-text rows that match no category code keep the historical keyword split (same numbers as before).
_LEGACY_KEYWORDS = {
    "clearance": ("broker", "أتعاب", "تخليص", "clearance"),
    "port": ("port", "نولون", "wharfage", "storage", "أرضيات", "موانئ"),
    "handling": ("handling", "stevedoring", "عتالة", "تفريغ", "حمالة"),
}
_CODE_BUCKETS = (
    ("clearance", CLEARANCE_FEE_CATEGORIES),
    ("port", PORT_DUES_CATEGORIES),
    ("handling", HANDLING_CATEGORIES),
)

# CL-04: an explicit null may not clear these (NOT NULL columns and money amounts).
_MONEY_UPDATE_FIELDS = frozenset({
    "cif_base_amount", "customs_exchange_rate", "estimated_duty_total", "delivery_order_fees", *DUTY_COMPONENT_FIELDS,
})


# ── Single-language storage: system texts are message codes + English render ──
def _render(m: SysMsg, part: str, **english_overrides) -> str:
    """English render of ``m``; ``english_overrides`` replace params for the English text only (e.g. an
    enum label instead of its code), ``m.params`` keeps the language-independent values."""
    params = dict(m.params)
    params.update(english_overrides)
    return render_en(m.code, params, part)


def _task_fields(m: SysMsg, **english_overrides) -> dict:
    """SmartTask title/description (English) + message code."""
    return {
        "title": _render(m, "title", **english_overrides)[:255],
        "description": _render(m, "body", **english_overrides),
        "msg_code": m.code,
        "msg_params": m.params,
    }


def _notification_fields(m: SysMsg, **english_overrides) -> dict:
    """SystemNotification title/message (English) + message code."""
    return {
        "title": _render(m, "title", **english_overrides)[:200],
        "message": _render(m, "body", **english_overrides),
        "msg_code": m.code,
        "msg_params": m.params,
    }


def _money(value) -> float:
    return round(float(value or 0.0), 2)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def duty_components_total(source: Any) -> float:
    """CL-03: the ONE duty-total formula (create, PUT and CL-02): rounded sum of the seven components."""
    return round(sum(float(getattr(source, name, 0.0) or 0.0) for name in DUTY_COMPONENT_FIELDS), 2)


def _apply_unrounded_variance(record: CustomsClearanceRecord) -> None:
    """Variance of actual vs estimated duty: amount unrounded, percentage rounded to 2 (only when est > 0)."""
    est = float(record.estimated_duty_total or 0.0)
    if est > 0:
        record.duty_variance_amount = float(record.actual_duty_total or 0.0) - est
        record.duty_variance_percentage = round((record.duty_variance_amount / est) * 100, 2)


# ── Transaction helpers ──────────────────────────────────────────────────────

def _commit_write(db: Session, write: Callable[[], T]) -> T:
    """Run the business ``write`` and commit once. A concurrent clash on a generated reference code
    (clearance / invoice code) rolls back and rebuilds the write with a fresh code."""
    for attempt in range(1, CODE_ATTEMPTS + 1):
        result = write()
        try:
            db.commit()
            return result
        except IntegrityError as exc:
            db.rollback()
            if not any(column in str(exc.orig) for column in _CODE_COLUMNS):
                raise
            if attempt == CODE_ATTEMPTS:
                raise coded_error(
                    status.HTTP_409_CONFLICT,
                    "CC_REFERENCE_CODE_CONFLICT",
                    "تعذر توليد كود مرجعي فريد بسبب عمليات متزامنة، يرجى إعادة المحاولة.",
                )
            logger.info("Customs clearance reference code taken concurrently; retrying (%s/%s)", attempt, CODE_ATTEMPTS)
    raise AssertionError("unreachable")  # pragma: no cover


def _follow_up(db: Session, label: str, fn: Callable[..., Any], *args: Any, **kwargs: Any) -> None:
    """A side effect after the main commit: committed on success, rolled back and logged on failure."""
    def run() -> None:
        fn(*args, **kwargs)
        db.commit()

    best_effort(db, run, label)


def _require_import_file(db: Session, import_file_id: int, detail: str = _FILE_NOT_FOUND) -> ImportFile:
    imp_file = (
        db.query(ImportFile)
        .filter(ImportFile.import_file_id == import_file_id, ImportFile.is_active == True)  # noqa: E712
        .first()
    )
    if not imp_file:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=detail)
    return imp_file


def _file_label(imp_file: ImportFile) -> str:
    return imp_file.import_file_code or f"IMP-{imp_file.import_file_id}"


def _find_or_new_record(db: Session, imp_file: ImportFile, user: str, **new_fields: Any) -> CustomsClearanceRecord:
    """The file's active clearance record, or a new pending one built from ``new_fields``."""
    record = repo.get_active_clearance_for_file(db, imp_file.import_file_id)
    if record:
        return record
    record = CustomsClearanceRecord(
        clearance_code=repo.generate_customs_clearance_code(db),
        import_file_id=imp_file.import_file_id,
        owner=imp_file.owner or user,
        created_by=user,
        updated_by=user,
        **new_fields,
    )
    db.add(record)
    return record


def _touch(row: Any, user: str) -> None:
    row.updated_at = _now()
    row.updated_by = user


def _raise_progress(imp_file: ImportFile, floor: float) -> None:
    if (imp_file.progress_percent or 0.0) < floor:
        imp_file.progress_percent = floor


# ── Side effects (run through _follow_up) ────────────────────────────────────

def _complete_tasks(
    db: Session,
    import_file_id: int,
    task_types: Sequence[str],
    note_msg: SysMsg,
    user: str,
    *,
    note_part: str = "note",
    task_codes: Sequence[str] = (),
    open_statuses: Optional[Sequence[str]] = None,
) -> None:
    """Close the file's open SmartTasks of ``task_types`` (plus legacy ``task_codes``); the English note goes to
    ``SmartTask.notes``."""
    from modules.smart_tasks.model import SmartTask

    match = SmartTask.task_type.in_(list(task_types))
    if task_codes:
        match = or_(match, SmartTask.task_code.in_(list(task_codes)))
    query = db.query(SmartTask).filter(SmartTask.import_file_id == import_file_id, match)
    if open_statuses:
        query = query.filter(SmartTask.status.in_(list(open_statuses)))
    else:
        query = query.filter(SmartTask.status != "Completed")
    note = _render(note_msg, note_part)
    for task in query.all():
        task.status = "Completed"
        task.notes = note
        task.updated_at = _now()
        task.updated_by = user


def _dispatch_task(
    db: Session,
    imp_file_id: int,
    existing_types: Sequence[str],
    task_msg: SysMsg,
    task_type: str,
    priority: str,
    assigned_user: str,
    due_in_days: int,
    user: str,
) -> None:
    """Create the downstream SmartTask unless the file already has one of ``existing_types``."""
    from modules.smart_tasks.model import SmartTask

    exists = (
        db.query(SmartTask)
        .filter(SmartTask.import_file_id == imp_file_id, SmartTask.task_type.in_(list(existing_types)))
        .first()
    )
    if exists:
        return
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == imp_file_id).first()
    db.add(SmartTask(
        task_code=f"TASK-{uuid.uuid4().hex[:8].upper()}",
        import_file_id=imp_file_id,
        import_file_code=_file_label(imp_file) if imp_file else None,
        **_task_fields(task_msg),
        task_type=task_type,
        priority=priority,
        status="Pending",
        assigned_user=assigned_user,
        due_date=(_now() + timedelta(days=due_in_days)).strftime("%Y-%m-%d"),
        created_by=user,
    ))


def _notify(db: Session, import_file_id: int, m: SysMsg) -> None:
    from modules.notifications.model import SystemNotification

    db.add(SystemNotification(
        **_notification_fields(m),
        category="STAGE_PROGRESSION",
        severity="INFO",
        entity_type="ImportFile",
        entity_id=import_file_id,
        target_role="ALL",
        is_read=False,
    ))


def _advance(db: Session, import_file_id: int, **kwargs: Any) -> None:
    from modules.lifecycle_board.service import advance_lifecycle_step_service

    advance_lifecycle_step_service(db=db, import_file_id=import_file_id, **kwargs)


def _audit(db: Session, record_id: int, record_code: str, action: str, user: str,
           old_data: Optional[Dict[str, Any]] = None, new_data: Optional[Dict[str, Any]] = None) -> None:
    from modules.audit_logs.service import AuditLogService

    AuditLogService(db).log_activity(
        entity_type="CustomsClearanceRecord",
        entity_id=record_id,
        entity_code=record_code,
        action=action,
        old_data=old_data,
        new_data=new_data,
        performed_by=user,
    )


def _step_follow_ups(
    db: Session,
    step: str,
    import_file_id: int,
    *,
    user: str,
    complete_types: Sequence[str],
    note_msg: SysMsg,
    dispatch: Optional[Dict[str, Any]] = None,
    lifecycle: Optional[Dict[str, Any]] = None,
) -> None:
    """The standard side effects of a CS/CL step: close its tasks, open the next task, notify, advance the board."""
    _follow_up(db, f"{step} task completion", _complete_tasks, db, import_file_id, complete_types, note_msg, user)
    if dispatch:
        _follow_up(db, f"{step} downstream task", _dispatch_task, db, import_file_id, user=user, **dispatch)
    _follow_up(db, f"{step} notification", _notify, db, import_file_id, note_msg)
    if lifecycle:
        _follow_up(db, f"{step} lifecycle advance", _advance, db, import_file_id, **lifecycle)


# ── Generic record CRUD ──────────────────────────────────────────────────────

def create_customs_clearance_service(
    db: Session, schema: CustomsClearanceCreate, user: str = SYSTEM_USER
) -> CustomsClearanceRecord:
    imp_file = _require_import_file(db, schema.import_file_id, "ملف الشحنة الاستيرادية المرتكز عليه غير موجود أو محذوف.")

    # ACID Expiry Guard: no clearance with an expired ACID (an unparseable date is a 400, never skipped).
    expiry = acid_expiry_date(imp_file)
    if expiry and expiry < date.today():
        raise HTTPException(
            status_code=400,
            detail=f"لا يمكن فتح بيان تخليص جمركي — رقم ACID الخاص بهذا الملف منتهي الصلاحية في {expiry}. يجب تجديد ACID أولاً.",
        )

    existing = repo.get_active_clearance_for_file(db, schema.import_file_id)
    if existing:
        raise HTTPException(
            status_code=400,
            detail=f"يوجد بالفعل بيان تخليص جمركي مسجل لهذا الملف الاستيرادي (كود البيان: {existing.clearance_code}). يرجى مراجعة وتحديث البيان الحالي بدلاً من إنشاء بيان مكرر.",
        )

    def write() -> CustomsClearanceRecord:
        now = _now()
        record = CustomsClearanceRecord(
            clearance_code=repo.generate_customs_clearance_code(db),
            import_file_id=schema.import_file_id,
            declaration_46_no=schema.declaration_46_no,
            customs_office_name=schema.customs_office_name,
            channel_type=schema.channel_type,
            inspection_date=schema.inspection_date or now,
            regulatory_bodies=schema.regulatory_bodies,
            inspection_notes=schema.inspection_notes,
            import_duty_amount=schema.import_duty_amount,
            vat_amount=schema.vat_amount,
            schedule_tax_amount=schema.schedule_tax_amount,
            development_fee_amount=schema.development_fee_amount,
            customs_service_fees=schema.customs_service_fees,
            wht_amount=schema.wht_amount,
            lab_service_fees=schema.lab_service_fees,
            estimated_duty_total=schema.estimated_duty_total,
            duty_variance_amount=schema.duty_variance_amount,
            duty_variance_percentage=schema.duty_variance_percentage,
            duty_variance_reason=schema.duty_variance_reason,
            nafeza_assessment_json=schema.nafeza_assessment_json or {},
            port_arrival_date=schema.port_arrival_date,
            delivery_order_number=schema.delivery_order_number,
            delivery_order_expiry=schema.delivery_order_expiry,
            free_days_allowed=schema.free_days_allowed,
            port_gate_out_date=schema.port_gate_out_date,
            owner=schema.owner or user,
            notes=schema.notes,
            created_at=now,
            updated_at=now,
            created_by=user,
            updated_by=user,
        )
        record.total_duty_payable = duty_components_total(record)
        record.actual_duty_total = schema.actual_duty_total if schema.actual_duty_total > 0 else record.total_duty_payable
        _apply_unrounded_variance(record)
        if schema.declaration_46_no:
            _require_import_file(db, schema.import_file_id).form46_no = schema.declaration_46_no
        db.add(record)
        return record

    record = _commit_write(db, write)
    record_id, code = record.customs_clearance_id, record.clearance_code

    _follow_up(db, "CustomsClearanceRecord create audit", _audit, db, record_id, code, "CREATE", user,
               new_data=schema.model_dump(mode="json", exclude_unset=True))
    _follow_up(db, "Lifecycle advance STEP_12->STEP_13", _advance, db, schema.import_file_id,
               completed_step_code="STEP_12", target_step_codes=["STEP_13"],
               notes_msg=msg("CC_RECORD_OPENED", clearance_code=code), assigned_user="Customs Broker")
    db.refresh(record)
    return record


def get_customs_clearance_service(db: Session, record_id: int) -> CustomsClearanceRecord:
    record = repo.get_customs_clearance_by_id(db, record_id)
    if not record:
        raise HTTPException(status_code=404, detail=_RECORD_NOT_FOUND)
    return record


def list_customs_clearances_service(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
) -> List[CustomsClearanceRecord]:
    return repo.get_customs_clearance_list(db, include_inactive, import_file_id, status, search)


def _normalize_clearance_update(data: Dict[str, Any]) -> Dict[str, Any]:
    """Tier-3 fields of a generic update: legacy labels -> enum codes (unknown values unchanged)."""
    if data.get("release_type") is not None:
        data["release_type"] = enum_codes.normalize(enum_codes.RELEASE_TYPE, data["release_type"])
    for field_name in ("regulatory_bodies", "sampled_regulatory_bodies"):
        if data.get(field_name) is not None:
            data[field_name] = enum_codes.normalize_list(enum_codes.REGULATORY_BODY, data[field_name])
    return data


def update_customs_clearance_service(
    db: Session, record_id: int, schema: CustomsClearanceUpdate, user: str = SYSTEM_USER
) -> CustomsClearanceRecord:
    """Generic PUT (CL-04): workflow / payment / derived fields are not in the schema (ignored when sent);
    an explicit null on a NOT NULL or money field is a 400. On an assessed record (``validators.is_assessed``) a PUT
    never writes total_duty_payable / actual_duty_total and a duty-component change is a 409 (re-assess via CL-02);
    before assessment the total is the CL-03 component sum."""
    record = get_customs_clearance_service(db, record_id)
    data = _normalize_clearance_update(schema.model_dump(exclude_unset=True))
    protected = not_null_columns(CustomsClearanceRecord) | _MONEY_UPDATE_FIELDS
    nulls = sorted(name for name, value in data.items() if value is None and name in protected)
    if nulls:
        raise coded_error(
            status.HTTP_400_BAD_REQUEST,
            "CC_UPDATE_NULL_NOT_ALLOWED",
            "لا يمكن مسح قيمة حقل إلزامي أو مبلغ مالي: " + ", ".join(nulls),
            fields=",".join(nulls),
        )
    changed_components = sorted(name for name in data if name in DUTY_COMPONENT_FIELDS)
    if changed_components and is_assessed(record):
        raise coded_error(
            status.HTTP_409_CONFLICT,
            "CC_ASSESSED_COMPONENTS_LOCKED",
            "لا يمكن تعديل بنود الرسوم الجمركية بعد احتسابها. استخدم إعادة احتساب الرسوم النهائية (CL-02).",
            fields=",".join(changed_components),
        )
    old_data = {name: getattr(record, name, None) for name in data}

    def write() -> CustomsClearanceRecord:
        target = get_customs_clearance_service(db, record_id)
        for name, value in data.items():
            setattr(target, name, value)
        if not is_assessed(target):
            # Not assessed yet: the CL-03 component sum; the assessed totals are never written by a PUT.
            target.total_duty_payable = duty_components_total(target)
            if not target.actual_duty_total:
                target.actual_duty_total = target.total_duty_payable
        _apply_unrounded_variance(target)
        _touch(target, user)
        if data.get("declaration_46_no"):
            imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == target.import_file_id).first()
            if imp_file:
                imp_file.form46_no = data["declaration_46_no"]
        return target

    record = _commit_write(db, write)
    _follow_up(db, "CustomsClearanceRecord update audit", _audit, db, record.customs_clearance_id,
               record.clearance_code, "UPDATE", user,
               old_data={k: (v.isoformat() if isinstance(v, datetime) else v) for k, v in old_data.items()},
               new_data=schema.model_dump(mode="json", exclude_unset=True))
    db.refresh(record)
    return record


def delete_customs_clearance_service(db: Session, record_id: int, user: str = SYSTEM_USER) -> bool:
    record = get_customs_clearance_service(db, record_id)
    record.is_active = False
    _touch(record, user)
    db.commit()
    return True


soft_delete_customs_clearance_service = delete_customs_clearance_service


def restore_customs_clearance_service(db: Session, record_id: int, user: str = SYSTEM_USER) -> CustomsClearanceRecord:
    record = repo.get_customs_clearance_by_id(db, record_id, include_inactive=True)
    if not record:
        raise HTTPException(status_code=404, detail="السجل المطلوب استعادته غير موجود.")
    other = repo.get_active_clearance_for_file(db, record.import_file_id, exclude_record_id=record.customs_clearance_id)
    if other:
        raise coded_error(
            status.HTTP_409_CONFLICT,
            "CC_RESTORE_DUPLICATE_ACTIVE",
            f"يوجد بيان تخليص نشط آخر لنفس الملف ({other.clearance_code}).",
            clearance_code=other.clearance_code,
        )
    record.is_active = True
    _touch(record, user)
    db.commit()
    db.refresh(record)
    return record


# ── CS-01: customs broker authorization ──────────────────────────────────────

def _generate_mandate_letter(
    db: Session, record_id: int, payload: CustomsBrokerAuthorizationSubmit, broker_name: str,
    broker_license: Optional[str], user: str,
) -> None:
    from modules.formal_letters.schemas import FormalLetterGenerateRequest
    from modules.formal_letters.service import generate_formal_letter_service

    letter_req = FormalLetterGenerateRequest(
        import_file_id=payload.import_file_id,
        template_type="customs_broker_mandate",
        recipient_name=f"السيد مدير عام {payload.customs_office_name or 'جمارك الإسكندرية'}",
        broker_name=broker_name,
        broker_license=broker_license or "رخصة معتمدة",
        custom_notes=payload.authorization_notes,
    )
    created_letter = generate_formal_letter_service(db, letter_req, user=user)
    if created_letter and created_letter.letter_code:
        record = repo.get_customs_clearance_by_id(db, record_id, include_inactive=True)
        record.mandate_letter_code = created_letter.letter_code


def authorize_customs_broker_service(
    db: Session,
    payload: CustomsBrokerAuthorizationSubmit,
    user: str = SYSTEM_USER,
) -> CustomsClearanceRecord:
    """BP-027 / CS-01: broker delegation on the record + ImportFile sync (progress >= 80%), then the CS-01 tasks,
    the CS-02 task, a notification, the optional mandate letter and the STEP_12 -> STEP_13 board advance."""
    _require_import_file(db, payload.import_file_id, "ملف الشحنة الاستيرادية المطلوب غير موجود أو محذوف.")

    from modules.external_service_providers.model import ExternalServiceProvider
    broker = (
        db.query(ExternalServiceProvider)
        .filter(ExternalServiceProvider.provider_id == payload.broker_id, ExternalServiceProvider.is_active == True)  # noqa: E712
        .first()
    )
    if not broker:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="المخلص الجمركي المختار غير مسجل أو محذوف.")
    broker_id, broker_name, broker_license = broker.provider_id, broker.partner_name, broker.clearance_license_number

    delegation_no = payload.delegation_number.strip()
    if len(delegation_no) < 3:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="رقم التفويض الإلكتروني يجب ألا يقل عن 3 أحرف/أرقام.")
    delegation_dt = payload.delegation_date or _now()

    def write():
        imp_file = _require_import_file(db, payload.import_file_id)
        record = _find_or_new_record(
            db, imp_file, user,
            customs_office_name=payload.customs_office_name or "Alexandria Port Customs",
            status="Broker Authorized - Ready for 46",
        )
        record.broker_id = broker_id
        record.broker_name = broker_name
        record.delegation_number = delegation_no
        record.delegation_date = delegation_dt
        record.delegation_status = "Authorized"
        if payload.customs_office_name:
            record.customs_office_name = payload.customs_office_name
        if payload.authorization_notes:
            record.authorization_notes = payload.authorization_notes
        if record.status in ("Inspection In Progress", "Open", "Draft"):
            record.status = "Broker Authorized - Ready for 46"
        _touch(record, user)

        imp_file.broker_id = broker_id
        imp_file.broker_name = broker_name
        imp_file.customs_broker_delegation_no = delegation_no
        imp_file.customs_broker_delegated_at = delegation_dt
        imp_file.customs_broker_authorization_status = "Authorized"
        imp_file.current_module = "Phase 6 - Customs Preparation"
        set_file_tracking(imp_file, stage_code="CUSTOMS_BROKER_AUTHORIZED", next_action=msg("NA_CS_PAY_DELIVERY_ORDER"))
        _raise_progress(imp_file, 80.0)
        _touch(imp_file, user)
        return record, _file_label(imp_file)

    record, file_label = _commit_write(db, write)
    record_id = record.customs_clearance_id
    broker_msg = msg("CC_BROKER_AUTHORIZED", broker_name=broker_name, import_file_code=file_label, delegation_no=delegation_no)

    if payload.generate_mandate_letter:
        _follow_up(db, "CS-01 mandate letter", _generate_mandate_letter, db, record_id, payload, broker_name, broker_license, user)
    _step_follow_ups(
        db, "CS-01", payload.import_file_id, user=user,
        complete_types=("CUSTOMS_BROKER_ASSIGNMENT", "CS-01"), note_msg=broker_msg,
        dispatch=dict(
            existing_types=("DELIVERY_ORDER_PAYMENT", "CS-02"),
            task_msg=msg("CC_TASK_DELIVERY_ORDER_PAYMENT", import_file_code=file_label, broker_name=broker_name,
                         delegation_no=delegation_no),
            task_type="DELIVERY_ORDER_PAYMENT", priority="High", assigned_user="Logistics Operations", due_in_days=3,
        ),
        lifecycle=dict(
            completed_step_code="STEP_12", target_step_codes=["STEP_13"], notes_msg=broker_msg,
            assigned_user="Customs Broker", next_action_msg=msg("NA_CS_PAY_DELIVERY_ORDER"), min_progress_percent=80.0,
        ),
    )
    db.refresh(record)
    return record


# ── CS-02: delivery order payment ────────────────────────────────────────────

def record_delivery_order_payment_service(
    db: Session,
    payload: DeliveryOrderPaymentSubmit,
    user: str = SYSTEM_USER,
) -> CustomsClearanceRecord:
    """CS-02: shipping-line D/O payment + receipt on the record, ImportFile sync (progress >= 83%), then tasks,
    notification and the STEP_13 board step."""
    _require_import_file(db, payload.import_file_id)

    do_number = payload.delivery_order_number.strip()
    if len(do_number) < 3:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="رقم إذن التسليم الملاحي يجب ألا يقل عن 3 أحرف/أرقام.")
    payment_ref = payload.delivery_order_payment_ref.strip()
    if len(payment_ref) < 2:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="رقم إيصال أو مرجع سداد مصاريف التوكيل الملاحي مطلوب.")

    shipping_agent_name = payload.shipping_agent_name
    if payload.shipping_agent_id:
        from modules.external_service_providers.model import ExternalServiceProvider
        agent = (
            db.query(ExternalServiceProvider)
            .filter(ExternalServiceProvider.provider_id == payload.shipping_agent_id, ExternalServiceProvider.is_active == True)  # noqa: E712
            .first()
        )
        if not agent:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="التوكيل / الخط الملاحي المختار غير مسجل أو محذوف.")
        shipping_agent_name = agent.partner_name

    do_dt = payload.delivery_order_date or _now()
    paid_dt = payload.delivery_order_paid_at or _now()
    expiry_dt = payload.delivery_order_expiry

    def write():
        imp_file = _require_import_file(db, payload.import_file_id)
        record = _find_or_new_record(db, imp_file, user, status="D/O Received - Ready for 46")
        record.delivery_order_number = do_number
        record.delivery_order_date = do_dt
        record.delivery_order_expiry = expiry_dt
        record.free_days_allowed = payload.free_days_allowed
        if payload.shipping_agent_id:
            record.shipping_agent_id = payload.shipping_agent_id
        if shipping_agent_name:
            record.shipping_agent_name = shipping_agent_name
        record.delivery_order_fees = payload.delivery_order_fees
        record.delivery_order_currency = payload.delivery_order_currency
        record.delivery_order_payment_ref = payment_ref
        record.delivery_order_paid_at = paid_dt
        record.delivery_order_status = "Paid & Received"
        if payload.delivery_order_file_url:
            record.delivery_order_file_url = payload.delivery_order_file_url
        if payload.notes:
            record.delivery_order_notes = payload.notes
        if payload.delivery_order_requested_at:
            assess_json = dict(record.nafeza_assessment_json or {})
            assess_json["delivery_order_requested_at"] = payload.delivery_order_requested_at.isoformat()
            record.nafeza_assessment_json = assess_json
        if record.status in ("Inspection In Progress", "Open", "Draft", "Broker Authorized - Ready for 46"):
            record.status = "D/O Received - Ready for 46"
        _touch(record, user)

        imp_file.delivery_order_no = do_number
        imp_file.delivery_order_date = do_dt
        imp_file.delivery_order_expiry_date = expiry_dt
        imp_file.delivery_order_status = "PAID_AND_RECEIVED"
        imp_file.current_module = "Phase 6 - Customs Preparation"
        set_file_tracking(imp_file, stage_code="DELIVERY_ORDER_PAID", next_action=msg("NA_CS_REGISTER_DECLARATION_46"))
        _raise_progress(imp_file, 83.0)
        _touch(imp_file, user)
        return record, _file_label(imp_file)

    record, file_label = _commit_write(db, write)
    expiry_str = expiry_dt.strftime("%Y-%m-%d") if hasattr(expiry_dt, "strftime") else str(expiry_dt)
    do_msg = msg(
        "CC_DELIVERY_ORDER_PAID",
        import_file_code=file_label,
        shipping_agent_name=shipping_agent_name or "-",
        do_number=do_number,
        expiry_date=expiry_str,
    )
    _step_follow_ups(
        db, "CS-02", payload.import_file_id, user=user,
        complete_types=("DELIVERY_ORDER_PAYMENT", "CS-02"), note_msg=do_msg,
        dispatch=dict(
            existing_types=("CUSTOMS_DECLARATION_46", "CS-03"),
            task_msg=msg("CC_TASK_DECLARATION_46", import_file_code=file_label, do_number=do_number, expiry_date=expiry_str),
            task_type="CUSTOMS_DECLARATION_46", priority="High", assigned_user="Customs Broker", due_in_days=2,
        ),
        lifecycle=dict(
            completed_step_code="STEP_12", target_step_codes=["STEP_13"], notes_msg=do_msg, assigned_user="Customs Broker",
            next_action_msg=msg("NA_CS_REGISTER_DECLARATION_46"), min_progress_percent=83.0,
        ),
    )
    db.refresh(record)
    return record


# ── CS-03: customs declaration 46 ────────────────────────────────────────────

def register_customs_declaration_46_service(
    db: Session,
    payload: CustomsDeclaration46Submit,
    user: str = SYSTEM_USER,
) -> CustomsClearanceRecord:
    """CS-03: Form 46 on the record, ImportFile sync (form46_*, progress >= 86%), then tasks, notification and
    the STEP_13 -> STEP_14/15 board advance."""
    _require_import_file(db, payload.import_file_id)

    dec_no = payload.declaration_46_no.strip()
    if len(dec_no) < 3:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="رقم الإقرار الجمركي ونموذج 46 ك.م يجب ألا يقل عن 3 أحرف/أرقام.")

    dec_dt = payload.declaration_46_date or _now()
    channel = payload.channel_type or "Red Channel"
    office = (payload.customs_office_name or "").strip() or "Alexandria Port Customs"
    reg_bodies = enum_codes.normalize_list(enum_codes.REGULATORY_BODY, payload.regulatory_bodies) or []
    tariff_count = payload.customs_tariff_items_count if payload.customs_tariff_items_count and payload.customs_tariff_items_count > 0 else 1
    mts_cert = payload.mts_certificate_number.strip() if payload.mts_certificate_number else None

    def write():
        imp_file = _require_import_file(db, payload.import_file_id)
        record = _find_or_new_record(db, imp_file, user, status="Under Customs Clearance")
        record.declaration_46_no = dec_no
        record.declaration_46_date = dec_dt
        record.customs_office_name = office
        record.channel_type = channel
        record.regulatory_bodies = reg_bodies
        if mts_cert:
            record.mts_certificate_number = mts_cert
        record.customs_tariff_items_count = tariff_count
        if payload.inspection_notes:
            record.inspection_notes = payload.inspection_notes
        record.status = "Under Customs Clearance"
        _touch(record, user)

        imp_file.form46_no = dec_no
        imp_file.form46_date = dec_dt
        imp_file.form46_status = "REGISTERED"
        imp_file.current_module = "Phase 7 - Customs Clearance"
        set_file_tracking(imp_file, stage_code="UNDER_CUSTOMS_CLEARANCE", next_action=msg("NA_CL_RECORD_INSPECTION"))
        _raise_progress(imp_file, 86.0)
        _touch(imp_file, user)
        return record, _file_label(imp_file)

    record, file_label = _commit_write(db, write)
    channel_code = enum_codes.normalize(enum_codes.CUSTOMS_CHANNEL, channel)
    d46_msg = msg(
        "CC_DECLARATION_46_REGISTERED",
        import_file_code=file_label,
        declaration_no=dec_no,
        channel_enum_customs_channel=channel_code,
        customs_office=office,
    )
    _step_follow_ups(
        db, "CS-03", payload.import_file_id, user=user,
        complete_types=("CUSTOMS_DECLARATION_46", "CS-03"), note_msg=d46_msg,
        dispatch=dict(
            existing_types=("CUSTOMS_INSPECTION_SAMPLING", "CL-01"),
            task_msg=msg("CC_TASK_INSPECTION", import_file_code=file_label, declaration_no=dec_no,
                         channel_enum_customs_channel=channel_code, customs_office=office),
            task_type="CUSTOMS_INSPECTION_SAMPLING", priority="High", assigned_user="Customs Broker", due_in_days=2,
        ),
        lifecycle=dict(
            completed_step_code="STEP_13", target_step_codes=["STEP_14", "STEP_15"], notes_msg=d46_msg,
            assigned_user="Customs Broker", next_action_msg=msg("NA_CL_RECORD_INSPECTION"), min_progress_percent=86.0,
        ),
    )
    db.refresh(record)
    return record


# ── CL-01: inspection & sampling ─────────────────────────────────────────────

def record_customs_inspection_sampling_service(
    db: Session,
    payload: CustomsInspectionSamplingSubmit,
    user: str = SYSTEM_USER,
) -> CustomsClearanceRecord:
    """CL-01: inspection / sampling report on the record, ImportFile sync (progress >= 88%), then tasks,
    notification and the STEP_14 -> STEP_15/17 board advance."""
    _require_import_file(db, payload.import_file_id)

    sampling_rec = (payload.sampling_record_no or "").strip()
    if payload.is_sample_drawn:
        if sampling_rec and len(sampling_rec) < 3:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="رقم محضر سحب العينات يجب ألا يقل عن 3 أحرف/أرقام.")
        if not sampling_rec:
            sampling_rec = f"SMP-{datetime.now().year}-{payload.import_file_id:04d}-{random.randint(100, 999)}"

    insp_dt = payload.inspection_date or _now()
    sampling_dt = payload.sampling_date or (insp_dt if payload.is_sample_drawn else None)
    # INSPECTION_YARD code when picked from the list (legacy Arabic names mapped); free text stays as typed.
    insp_yard = enum_codes.normalize(enum_codes.INSPECTION_YARD, (payload.inspection_yard or "").strip()) or "Joint Inspection Yard"
    insp_type = (payload.inspection_type or "").strip() or "Physical & Sampling"
    insp_result = (payload.inspection_result or "").strip() or "Conforming"
    sample_status = payload.sample_test_status or ("Samples Under Testing" if payload.is_sample_drawn else "None")
    sampled_bodies = enum_codes.normalize_list(enum_codes.REGULATORY_BODY, payload.sampled_regulatory_bodies) or []
    goeic_cert = (payload.goeic_certificate_no or "").strip() if payload.goeic_certificate_no else None
    lab_fees = float(payload.lab_service_fees or 0.0)

    def write():
        imp_file = _require_import_file(db, payload.import_file_id)
        record = _find_or_new_record(
            db, imp_file, user,
            customs_office_name=insp_yard, channel_type="Red Channel", status="Inspection & Sampling Recorded",
        )
        record.inspection_date = insp_dt
        record.inspection_type = insp_type
        record.inspection_yard = insp_yard
        if payload.inspector_name:
            record.inspector_name = payload.inspector_name
        record.inspection_result = insp_result
        record.is_sample_drawn = payload.is_sample_drawn
        record.sampling_date = sampling_dt
        record.sampling_record_no = sampling_rec if payload.is_sample_drawn else None
        record.sample_test_status = sample_status
        record.sampled_regulatory_bodies = sampled_bodies
        if goeic_cert:
            record.goeic_certificate_no = goeic_cert
        if lab_fees > 0:
            record.lab_service_fees = lab_fees
        if payload.inspection_notes:
            record.inspection_notes = payload.inspection_notes
        record.status = "Inspection & Sampling Recorded"
        _touch(record, user)

        imp_file.current_module = "Phase 7 - Customs Clearance & Inspection"
        set_file_tracking(imp_file, stage_code="CUSTOMS_INSPECTION_COMPLETED", next_action=msg("NA_CL_ASSESS_FINAL_DUTIES"))
        _raise_progress(imp_file, 88.0)
        _touch(imp_file, user)
        return record, _file_label(imp_file)

    record, file_label = _commit_write(db, write)
    result_code = enum_codes.normalize(enum_codes.INSPECTION_RESULT, insp_result)
    # inspection_yard is an INSPECTION_YARD code when picked from the list (render_en uses its English label).
    insp_msg = msg(
        "CC_INSPECTION_RECORDED",
        import_file_code=file_label,
        inspection_result_enum_inspection_result=result_code,
        inspection_yard_enum_inspection_yard=enum_codes.normalize(enum_codes.INSPECTION_YARD, insp_yard),
        sampling_record_no=sampling_rec if payload.is_sample_drawn else "-",
    )
    _step_follow_ups(
        db, "CL-01", payload.import_file_id, user=user,
        complete_types=("CUSTOMS_INSPECTION_SAMPLING", "CL-01"), note_msg=insp_msg,
        dispatch=dict(
            existing_types=("FINAL_DUTY_ASSESSMENT", "CL-02"),
            task_msg=msg("CC_TASK_DUTY_ASSESSMENT", import_file_code=file_label,
                         inspection_result_enum_inspection_result=result_code),
            task_type="FINAL_DUTY_ASSESSMENT", priority="High", assigned_user="Customs Broker", due_in_days=2,
        ),
        lifecycle=dict(
            completed_step_code="STEP_14", target_step_codes=["STEP_15", "STEP_17"], notes_msg=insp_msg,
            assigned_user="Customs Broker", next_action_msg=msg("NA_CL_ASSESS_FINAL_DUTIES"), min_progress_percent=88.0,
        ),
    )
    db.refresh(record)
    return record


# ── CL-02: final duty assessment ─────────────────────────────────────────────

def assess_final_customs_duties_service(
    db: Session,
    payload: FinalDutyAssessmentSubmit,
    user: str = SYSTEM_USER,
) -> CustomsClearanceRecord:
    """CL-02: itemised duties, total (7 components, or the claim override), variance vs the estimate. Needs the
    file's clearance record with a registered declaration 46 (409). Then tasks, notification, STEP_15 advance."""
    _require_import_file(db, payload.import_file_id)

    claim_no = (payload.nafeza_claim_number or "").strip()
    if len(claim_no) < 3:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="رقم المطالبة الجمركية بنظام نافذة يجب ألا يقل عن 3 أحرف/أرقام.")

    existing = repo.get_active_clearance_for_file(db, payload.import_file_id)
    if existing is None or not (existing.declaration_46_no or "").strip():
        raise coded_error(
            status.HTTP_409_CONFLICT,
            "CC_ASSESS_REQUIRES_DECLARATION_46",
            "لا يمكن احتساب الرسوم الجمركية النهائية قبل قيد الإقرار الجمركي نموذج 46 (CS-03).",
            import_file_id=payload.import_file_id,
        )

    # A component the payload does not send keeps its stored value (exclude_unset semantics).
    sent = payload.model_fields_set
    components = {
        name: float((getattr(payload, name) if name in sent else getattr(existing, name)) or 0.0)
        for name in DUTY_COMPONENT_FIELDS
    }
    computed_total = round(sum(components[name] for name in DUTY_COMPONENT_FIELDS), 2)
    if payload.actual_duty_total is not None and payload.actual_duty_total > 0:
        actual_total = round(float(payload.actual_duty_total), 2)
    else:
        actual_total = computed_total
    claim_dt = payload.nafeza_claim_date or _now()

    def write():
        imp_file = _require_import_file(db, payload.import_file_id)
        record = repo.get_active_clearance_for_file(db, payload.import_file_id)
        est_total = float(record.estimated_duty_total or 0.0)
        var_amount = 0.0
        var_pct = 0.0
        if est_total > 0:
            var_amount = round(actual_total - est_total, 2)
            var_pct = round((var_amount / est_total) * 100, 2)

        record.cif_base_amount = float(payload.cif_base_amount or 0.0)
        if payload.customs_exchange_rate is not None:  # never default the customs rate to 1.0
            record.customs_exchange_rate = float(payload.customs_exchange_rate)
        for name, value in components.items():
            setattr(record, name, value)
        record.total_duty_payable = actual_total
        record.actual_duty_total = actual_total
        record.duty_variance_amount = var_amount
        record.duty_variance_percentage = var_pct
        if payload.duty_variance_reason:
            record.duty_variance_reason = payload.duty_variance_reason
        record.nafeza_claim_number = claim_no
        record.nafeza_claim_date = claim_dt
        record.assessment_status = "Assessed"
        if payload.nafeza_assessment_json:
            record.nafeza_assessment_json = payload.nafeza_assessment_json
        if payload.assessment_notes:
            record.notes = (record.notes or "") + f" | Nafeza assessment: {payload.assessment_notes}"
        record.status = "Customs Duties Assessed - Ready for Payment"
        record.payment_status = "Payment Requested" if record.payment_status in ("Unpaid", None) else record.payment_status
        _touch(record, user)

        imp_file.current_module = "Phase 7 - Customs Clearance & Duty Assessment"
        set_file_tracking(imp_file, stage_code="CUSTOMS_DUTY_ASSESSED", next_action=msg("NA_CL_RECORD_DUTY_PAYMENT"))
        _raise_progress(imp_file, 90.0)
        _touch(imp_file, user)
        return record, _file_label(imp_file)

    record, file_label = _commit_write(db, write)
    assess_msg = msg("CC_DUTIES_ASSESSED", import_file_code=file_label, claim_no=claim_no, total_amount=_money(actual_total))
    _step_follow_ups(
        db, "CL-02", payload.import_file_id, user=user,
        complete_types=("FINAL_DUTY_ASSESSMENT", "CL-02"), note_msg=assess_msg,
        dispatch=dict(
            existing_types=("CUSTOMS_DUTY_PAYMENT", "CL-03"),
            task_msg=msg("CC_TASK_DUTY_PAYMENT", import_file_code=file_label, claim_no=claim_no,
                         total_amount=_money(actual_total)),
            task_type="CUSTOMS_DUTY_PAYMENT", priority="Urgent", assigned_user="Customs Broker", due_in_days=2,
        ),
        lifecycle=dict(
            completed_step_code="STEP_15", target_step_codes=["STEP_16", "STEP_17"], notes_msg=assess_msg,
            assigned_user="Customs Broker", next_action_msg=msg("NA_CL_RECORD_DUTY_PAYMENT"), min_progress_percent=90.0,
        ),
    )
    db.refresh(record)
    return record


# ── CL-03: duty payment (main route + legacy /{id}/pay-duty adapter) ─────────

def _record_duty_payment(
    db: Session,
    import_file_id: int,
    record_id: int,
    *,
    receipt_no: str,
    sadad_no: Optional[str],
    bank_name: Optional[str],
    payment_date: Optional[datetime],
    payment_method: Optional[str],
    paid_amount: float,
    receipt_file_url: Optional[str],
    payment_notes: Optional[str],
    record_status: str,
    user: str,
    variance_reason: Optional[str] = None,
    nafeza_assessment_json: Optional[Dict[str, Any]] = None,
) -> CustomsClearanceRecord:
    """The single CL-03 write (both routes): the assessed total is never overwritten by the paid amount."""
    pay_dt = payment_date or _now()

    def write():
        imp_file = _require_import_file(db, import_file_id)
        record = get_customs_clearance_service(db, record_id)
        record.bank_receipt_no = receipt_no
        record.sadad_number = sadad_no
        record.paying_bank_name = enum_codes.normalize(enum_codes.DUTY_BANK, bank_name.strip()) if bank_name else bank_name
        record.payment_date = pay_dt
        record.payment_method = enum_codes.normalize(enum_codes.PAYMENT_METHOD, payment_method) or "SADAD_EFINANCE"
        record.duty_paid_amount = paid_amount
        if receipt_file_url:
            record.receipt_file_url = receipt_file_url
        if payment_notes:
            record.payment_notes = payment_notes
            record.notes = (record.notes or "") + f" | Customs payment: {payment_notes}"
        if variance_reason:
            record.duty_variance_reason = variance_reason
        if nafeza_assessment_json:
            record.nafeza_assessment_json = nafeza_assessment_json
        _apply_unrounded_variance(record)
        record.payment_status = "Paid & Verified"
        record.status = record_status
        _touch(record, user)

        imp_file.customs_duty_paid_amount = paid_amount
        imp_file.customs_duty_receipt_no = receipt_no
        imp_file.customs_duty_sadad_no = sadad_no
        imp_file.customs_duty_payment_date = pay_dt
        imp_file.customs_duty_payment_status = "PAID"
        imp_file.current_module = "Phase 7 - Customs Clearance & Duty Payment"
        set_file_tracking(imp_file, stage_code="DUTY_PAID", next_action=msg("NA_CL_ISSUE_GREEN_RELEASE"))
        _raise_progress(imp_file, 92.0)
        _touch(imp_file, user)
        return record, _file_label(imp_file)

    record, file_label = _commit_write(db, write)
    paid_msg = msg(
        "CC_DUTIES_PAID",
        import_file_code=file_label,
        paid_amount=_money(paid_amount),
        sadad_no=sadad_no or "-",
        receipt_no=receipt_no,
    )
    _step_follow_ups(
        db, "CL-03", import_file_id, user=user,
        complete_types=("CUSTOMS_DUTY_PAYMENT", "CL-03"), note_msg=paid_msg,
        dispatch=dict(
            existing_types=("CUSTOMS_FINAL_RELEASE", "CL-04"),
            task_msg=msg("CC_TASK_RELEASE", import_file_code=file_label, paid_amount=_money(paid_amount),
                         sadad_no=sadad_no or "-"),
            task_type="CUSTOMS_FINAL_RELEASE", priority="Urgent", assigned_user="Customs Broker", due_in_days=2,
        ),
        lifecycle=dict(
            completed_step_code="STEP_16", target_step_codes=["STEP_17"], notes_msg=paid_msg,
            assigned_user="Customs Broker", next_action_msg=msg("NA_CL_ISSUE_GREEN_RELEASE"), min_progress_percent=92.0,
        ),
    )
    db.refresh(record)
    return record


def record_customs_duty_payment_service(
    db: Session, payload: CustomsDutyPaymentSubmit, user: str = SYSTEM_USER
) -> CustomsClearanceRecord:
    """CL-03: needs the file's assessed record (409, never auto-created) and a payment covering the assessed
    total (400, partial payments are refused)."""
    _require_import_file(db, payload.import_file_id, "ملف الشحنة الاستيرادية المحدد غير موجود أو غير نشط.")
    receipt_no = payload.bank_receipt_no.strip()
    validate_bank_receipt_no(receipt_no)
    sadad_no = payload.sadad_number.strip()
    if len(sadad_no) < 3:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="رقم منظومة سداد / E-Finance يجب ألا يقل عن 3 أحرف.")
    if payload.duty_paid_amount <= 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="المبلغ المسدد للرسوم الجمركية يجب أن يكون أكبر من الصفر.")

    record = repo.get_active_clearance_for_file(db, payload.import_file_id)
    validate_duty_payment_amount(record, payload.duty_paid_amount)

    return _record_duty_payment(
        db, payload.import_file_id, record.customs_clearance_id,
        receipt_no=receipt_no, sadad_no=sadad_no, bank_name=payload.paying_bank_name,
        payment_date=payload.payment_date, payment_method=payload.payment_method,
        paid_amount=payload.duty_paid_amount, receipt_file_url=payload.receipt_file_url,
        payment_notes=payload.payment_notes, record_status="Duty Paid - Ready for Final Release", user=user,
    )


def submit_duty_payment_service(
    db: Session, record_id: int, payload: DutyPaymentSubmit, user: str = SYSTEM_USER
) -> CustomsClearanceRecord:
    """Legacy BP-031 ``/{id}/pay-duty``: a thin adapter over the CL-03 rules. The paid amount is
    ``duty_paid_amount`` (or, for old clients, ``actual_duty_total``); the client cannot change the assessed or
    estimated totals any more."""
    validate_bank_receipt_no(payload.bank_receipt_no)
    record = get_customs_clearance_service(db, record_id)
    paid_amount = payload.duty_paid_amount if payload.duty_paid_amount is not None else payload.actual_duty_total
    if paid_amount is None or paid_amount <= 0:
        raise coded_error(
            status.HTTP_400_BAD_REQUEST,
            "CC_DUTY_PAID_AMOUNT_REQUIRED",
            "المبلغ المسدد للرسوم الجمركية مطلوب ويجب أن يكون أكبر من الصفر.",
        )
    validate_duty_payment_amount(record, paid_amount)

    return _record_duty_payment(
        db, record.import_file_id, record.customs_clearance_id,
        receipt_no=payload.bank_receipt_no.strip(),
        sadad_no=(payload.sadad_number or "").strip() or None,
        bank_name=payload.paying_bank_name,
        payment_date=payload.payment_date, payment_method=payload.payment_method,
        paid_amount=float(paid_amount), receipt_file_url=payload.receipt_file_url,
        payment_notes=payload.payment_notes, record_status="Duty Paid", user=user,
        variance_reason=payload.duty_variance_reason, nafeza_assessment_json=payload.nafeza_assessment_json,
    )


# ── CL-04: final release (main route + legacy /{id}/complete-release adapter) ─

def _issue_release(
    db: Session, imp_file: ImportFile, record: Optional[CustomsClearanceRecord], payload: Any, user: str
) -> CustomsClearanceRecord:
    """Shared CL-04 guards + write. ``payload`` is a CustomsFinalReleaseSubmit or a CompleteReleaseSubmit."""
    validate_acid_not_expired_for_release(imp_file)
    validate_release_not_quarantined(record)
    validate_release_payment(record)
    permit_no = validate_release_permit_no(payload.release_permit_no)

    import_file_id, record_id = imp_file.import_file_id, record.customs_clearance_id
    rel_dt = payload.release_date or _now()
    release_type = enum_codes.normalize(enum_codes.RELEASE_TYPE, payload.release_type) or "FINAL_GREEN"

    def write():
        target_file = _require_import_file(db, import_file_id)
        target = get_customs_clearance_service(db, record_id)
        target.release_permit_no = permit_no
        target.release_date = rel_dt
        if payload.release_officer_name:
            target.release_officer_name = payload.release_officer_name
        target.release_type = release_type
        if payload.release_document_url:
            target.release_document_url = payload.release_document_url
        if payload.gate_pass_number:
            target.gate_pass_number = payload.gate_pass_number
        if payload.port_gate_out_date:
            target.port_gate_out_date = payload.port_gate_out_date
        target.demurrage_storage_fees = payload.demurrage_storage_fees or 0.0
        target.dispatch_authorized = payload.dispatch_authorized
        target.dispatch_date = _now() if payload.dispatch_authorized else None
        if payload.transport_instructions:
            target.transport_instructions = payload.transport_instructions
        target.status = FINAL_RELEASE_STATUS
        if payload.notes:
            target.notes = (target.notes or "") + f" | Customs release: {payload.notes}"
        _touch(target, user)

        target_file.is_customs_released = True
        target_file.customs_released_at = rel_dt
        target_file.customs_release_permit_no = permit_no
        target_file.customs_release_type = release_type
        if payload.release_officer_name:
            target_file.customs_release_officer = payload.release_officer_name
        if payload.gate_pass_number:
            target_file.customs_gate_pass_no = payload.gate_pass_number
        target_file.current_module = "Phase 7 - Customs Clearance & Release"
        set_file_tracking(
            target_file, stage_code="CUSTOMS_RELEASED", next_action=msg("NA_TR_BOOK_INLAND_TRANSPORT_MONITOR_FREE_TIME")
        )
        _raise_progress(target_file, 95.0)
        _touch(target_file, user)
        free_days = target.free_days_allowed or target_file.target_free_days or 14
        return target, _file_label(target_file), free_days

    released, file_label, free_days = _commit_write(db, write)
    release_msg = msg("CC_RELEASE_ISSUED", import_file_code=file_label, permit_no=permit_no)
    _follow_up(db, "CL-04 task completion", _complete_tasks, db, import_file_id,
               ("CUSTOMS_FINAL_RELEASE", "CL-04"), release_msg, user)
    _follow_up(db, "TR-01 task dispatch", _dispatch_task, db, import_file_id,
               existing_types=("INLAND_TRANSPORT", "TR-01"),
               task_msg=msg("CC_TASK_INLAND_TRANSPORT", import_file_code=file_label, permit_no=permit_no),
               task_type="INLAND_TRANSPORT", priority="High", assigned_user="Logistics Officer", due_in_days=2, user=user)
    _follow_up(db, "TR-02 task dispatch", _dispatch_task, db, import_file_id,
               existing_types=("DEMURRAGE_TRACKING", "TR-02"),
               task_msg=msg("CC_TASK_FREE_TIME_MONITOR", import_file_code=file_label, free_days=free_days),
               task_type="DEMURRAGE_TRACKING", priority="Medium", assigned_user="Operations Team", due_in_days=2, user=user)
    _follow_up(db, "CL-04 notification", _notify, db, import_file_id, release_msg)
    _follow_up(db, "Lifecycle advance STEP_17->STEP_18", _advance, db, import_file_id,
               completed_step_code="STEP_17", target_step_codes=["STEP_18"], notes_msg=release_msg,
               assigned_user="Customs Broker", stage_code="CUSTOMS_RELEASED",
               next_action_msg=msg("NA_TR_BOOK_INLAND_TRANSPORT"), min_progress_percent=95.0)
    db.refresh(released)
    return released


def issue_final_customs_release_service(
    db: Session,
    payload: CustomsFinalReleaseSubmit,
    user: str = SYSTEM_USER,
) -> CustomsClearanceRecord:
    """CL-04: ACID hard block (DC-02), the record must belong to ``import_file_id`` (400), duty fully paid (400,
    no auto-created record), then the green release, ImportFile sync (progress >= 95%) and the TR tasks."""
    imp_file = _require_import_file(db, payload.import_file_id, f"ملف الشحنة رقم ({payload.import_file_id}) غير مسجل أو محذوف.")

    record = None
    if payload.clearance_id:
        record = repo.get_customs_clearance_by_id(db, payload.clearance_id)
        if record is not None and record.import_file_id != payload.import_file_id:
            raise coded_error(
                status.HTTP_400_BAD_REQUEST,
                "CC_RELEASE_RECORD_FILE_MISMATCH",
                "سجل التخليص المحدد لا يخص ملف الشحنة.",
                clearance_id=payload.clearance_id,
                import_file_id=payload.import_file_id,
            )
    if record is None:
        record = repo.get_active_clearance_for_file(db, payload.import_file_id)
    return _issue_release(db, imp_file, record, payload, user)


def complete_customs_release_service(
    db: Session, record_id: int, payload: CompleteReleaseSubmit, user: str = SYSTEM_USER
) -> CustomsClearanceRecord:
    """Legacy BP-032 ``/{id}/complete-release``: a thin adapter over the CL-04 guards and write."""
    record = get_customs_clearance_service(db, record_id)
    imp_file = _require_import_file(db, record.import_file_id, f"ملف الشحنة رقم ({record.import_file_id}) غير مسجل أو محذوف.")
    return _issue_release(db, imp_file, record, payload, user)


# ── LOG-BOND-003: under-bond release and lab quarantine ──────────────────────

def issue_under_bond_release_service(
    db: Session, record_id: int, payload: UnderBondReleaseSubmit, user: str = SYSTEM_USER
) -> CustomsClearanceRecord:
    """Conditional under-bond release: goods move to the factory warehouse under a quarantine lock while the lab
    tests run. Refused (409) once the shipment is under bond or finally released."""
    record = get_customs_clearance_service(db, record_id)
    if not payload.bond_guarantee_ref or len(payload.bond_guarantee_ref.strip()) < 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="لا يمكن السحب على عهدة بدون إرفاق رقم التعهد أو خطاب الضمان البنكي/الجمركي المعتمد.",
        )
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == record.import_file_id).first()
    validate_under_bond_allowed(record, imp_file)

    bond_ref = payload.bond_guarantee_ref.strip()
    record.is_under_bond_release = True
    record.bond_guarantee_ref = bond_ref
    record.quarantine_lock = True
    record.dispatch_authorized = False
    record.lab_test_result = "Pending"
    record.status = "Under Bond Released"
    record.release_date = payload.temporary_release_date
    record.port_gate_out_date = payload.temporary_release_date
    record.notes = (record.notes or "") + f" | Under-bond withdrawal, undertaking #{bond_ref} to: {payload.customs_warehouse_location}"
    _touch(record, user)
    if imp_file:
        imp_file.current_module = "Phase 7 - Customs Clearance & Inspection"
        set_file_tracking(imp_file, stage_code="UNDER_BOND_QUARANTINE", next_action=msg("NA_CL_AWAIT_LAB_RESULTS"))
        _touch(imp_file, user)
    db.commit()
    db.refresh(record)
    return record


def record_lab_result_and_lift_quarantine_service(
    db: Session, record_id: int, payload: LabTestResultSubmit, user: str = SYSTEM_USER, can_release: bool = False
) -> CustomsClearanceRecord:
    """Store the LAB_TEST_RESULT code. CONFORMING + lift: the quarantine lock is lifted; the final release
    (status, dispatch, ``is_customs_released``) only follows when the duty is fully paid (Q3) AND the acting user
    holds ``customs_clearance.release`` (``can_release``, resolved by the router). Refused (409) once the lock is
    lifted or the record is finally released."""
    record = get_customs_clearance_service(db, record_id)
    if not record.is_under_bond_release:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="هذه الشحنة ليست مقيدة في مسار السحب على عهدة أو التحفظ الجمركي.",
        )
    validate_lab_result_open(record)
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == record.import_file_id).first()

    record.lab_test_result = payload.lab_test_result
    record.lab_certificate_number = payload.lab_certificate_number
    if payload.lab_test_result == LAB_CONFORMING:
        if payload.lift_quarantine_lock:
            record.quarantine_lock = False
            record.quarantine_lifted_date = payload.test_completion_date or _now()
            record.quarantine_lifted_by = "Customs Laboratory Authority"
            try:
                from modules.warehouse_receiving.service import release_quarantine_lock_for_file
                release_quarantine_lock_for_file(db, record.import_file_id, user=user)
            except Exception:
                pass
            if can_release and is_duty_fully_paid(record):
                record.dispatch_authorized = True
                record.status = FINAL_RELEASE_STATUS
                if imp_file:
                    set_file_tracking(
                        imp_file, stage_code="LAB_APPROVED_RELEASED", next_action=msg("NA_WAREHOUSE_READY_FOR_DISPATCH")
                    )
                    imp_file.is_customs_released = True
            elif imp_file and not is_duty_fully_paid(record):
                set_file_tracking(imp_file, next_action=msg("NA_CL_RECORD_DUTY_PAYMENT"))
            elif imp_file:
                set_file_tracking(imp_file, next_action=msg("NA_CL_ISSUE_GREEN_RELEASE"))
    else:
        record.quarantine_lock = True
        record.dispatch_authorized = False
        record.status = "Lab Non-Conforming - Rejected"
        if imp_file:
            set_file_tracking(imp_file, stage_code="LAB_REJECTED", next_action=msg("NA_CL_RE_EXPORT_OR_DISPOSAL"))
    _touch(record, user)
    if imp_file:
        _touch(imp_file, user)
    db.commit()
    db.refresh(record)
    return record


# ── CL-05: clearance fees & port invoices ────────────────────────────────────

def generate_clearance_invoice_code(db: Session) -> str:
    """Next ``CLI-YYYY-NNNN`` invoice code (per year, highest suffix + 1)."""
    return repo.generate_clearance_invoice_code(db)


def _invoice_bucket(expense_category: Optional[str]) -> str:
    """clearance / port / handling / other for one invoice category (codes; legacy free text by keyword)."""
    code = enum_codes.normalize(enum_codes.CLEARANCE_EXPENSE_CATEGORY, expense_category or "")
    if enum_codes.is_code(enum_codes.CLEARANCE_EXPENSE_CATEGORY, code):
        for bucket, codes in _CODE_BUCKETS:
            if code in codes:
                return bucket
        return "other"
    text = (expense_category or "").lower()
    for bucket in ("clearance", "port", "handling"):
        if any(keyword in text for keyword in _LEGACY_KEYWORDS[bucket]):
            return bucket
    return "other"


def _bucket_totals(invoices: Iterable[ClearanceExpenseInvoice]) -> Dict[str, float]:
    totals = {"clearance": 0.0, "port": 0.0, "handling": 0.0, "other": 0.0}
    for inv in invoices:
        totals[_invoice_bucket(inv.expense_category)] += inv.net_payable_egp
    return totals


def _recalculate_clearance_expenses_aggregates(db: Session, import_file_id: int, clearance_record_id: Optional[int] = None) -> None:
    """Business part of the CL-05 totals: clearance record + import file (same transaction as the invoice)."""
    db.flush()
    invoices = repo.get_active_invoices_for_file(db, import_file_id)
    total_net = sum(inv.net_payable_egp for inv in invoices)
    buckets = _bucket_totals(invoices)

    clearance = None
    if clearance_record_id:
        clearance = repo.get_customs_clearance_by_id(db, clearance_record_id, include_inactive=True)
    if not clearance:
        clearance = repo.get_latest_clearance_for_file(db, import_file_id)
    if clearance:
        clearance.clearance_invoices_count = len(invoices)
        clearance.total_clearance_expenses_egp = round(total_net, 2)
        clearance.total_port_expenses_egp = round(buckets["port"], 2)
        clearance.total_handling_expenses_egp = round(buckets["handling"], 2)
        clearance.updated_at = _now()

    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
    if imp_file:
        imp_file.total_clearance_expenses_egp = round(total_net, 2)
        imp_file.clearance_invoices_status = "Invoices Logged & Verified" if invoices else "Pending Invoices"
        _raise_progress(imp_file, 96.0)
        set_file_tracking(imp_file, next_action=msg("NA_TR_BOOK_INLAND_TRANSPORT_MONITOR_FREE_TIME"))
        imp_file.updated_at = _now()


def _sync_settlement_snapshot(db: Session, import_file_id: int, actor: str = SYSTEM_USER) -> None:
    """Landed-cost settlement snapshot: ``Clearance / <label_en>`` rows replace the earlier clearance rows."""
    from modules.financial_settlement.model import LandedCostSettlementRecord
    from modules.financial_settlement.service import recalculate_settlement_totals

    settlement = db.query(LandedCostSettlementRecord).filter(
        LandedCostSettlementRecord.import_file_id == import_file_id,
        LandedCostSettlementRecord.is_active == True,  # noqa: E712
    ).first()
    if not settlement:
        return
    if settlement.status in SETTLEMENT_LOCKED_STATUSES:
        logger.warning(
            "Skipping settlement snapshot sync for import_file_id=%s: settlement %s is locked (%s)",
            import_file_id,
            settlement.settlement_code,
            settlement.status,
        )
        return
    rows = [item for item in (settlement.expense_invoices or []) if not str(item.get("category", "")).startswith("Clearance / ")]
    for inv in repo.get_active_invoices_for_file(db, import_file_id):
        rows.append({
            "invoice_no": inv.invoice_number,
            "invoice_code": inv.invoice_code,
            "category": f"Clearance / {enum_codes.label_en(enum_codes.CLEARANCE_EXPENSE_CATEGORY, inv.expense_category)}",
            "provider_name": inv.provider_name,
            "currency": inv.currency,
            "amount_fx": inv.amount_fx,
            "exchange_rate": inv.exchange_rate,
            "amount_egp": inv.amount_egp,
            "vat_amount": inv.vat_amount,
            "wht_amount": inv.wht_amount,
            "net_payable_egp": inv.net_payable_egp,
            "allocation_rule": inv.allocation_rule or "Equal",
        })
    settlement.expense_invoices = rows
    recalculate_settlement_totals(settlement, actor=actor)
    settlement.updated_at = _now()


def record_clearance_invoice_service(
    db: Session,
    payload: ClearanceExpenseInvoiceCreate,
    current_user: str = SYSTEM_USER,
) -> ClearanceExpenseInvoice:
    """CL-05: record a broker / port / handling invoice (EGP amount from FX when needed), update the record and
    file totals, then sync the settlement snapshot, close CL-05 tasks and notify."""
    validate_settlement_open(db, payload.import_file_id)
    imp_file = _require_import_file(db, payload.import_file_id)
    file_label = _file_label(imp_file)

    clearance_id = payload.customs_clearance_id
    if clearance_id:
        linked = repo.get_customs_clearance_by_id(db, clearance_id, include_inactive=True)
        if linked is None or linked.import_file_id != payload.import_file_id:
            raise coded_error(
                status.HTTP_400_BAD_REQUEST,
                "CC_INVOICE_RECORD_FILE_MISMATCH",
                "سجل التخليص المحدد للفاتورة لا يخص ملف الشحنة.",
                customs_clearance_id=clearance_id,
                import_file_id=payload.import_file_id,
            )
    else:
        latest_active = repo.get_active_clearance_for_file(db, payload.import_file_id)
        clearance_id = latest_active.customs_clearance_id if latest_active else None

    currency = (payload.currency or "EGP").strip() or "EGP"
    amount_egp = payload.amount_egp
    if amount_egp is None or amount_egp <= 0.0:
        if currency.upper() != "EGP" and not payload.exchange_rate:
            raise coded_error(
                status.HTTP_400_BAD_REQUEST,
                "CC_INVOICE_FX_RATE_REQUIRED",
                "سعر الصرف مطلوب لفاتورة بعملة أجنبية.",
                currency=currency,
            )
        if payload.amount_fx > 0:
            amount_egp = round(payload.amount_fx * (payload.exchange_rate or 1.0), 2)
    # Stored rate: the given one; EGP = 1.0; a foreign invoice with only an EGP amount: implied rate or None.
    if payload.exchange_rate:
        stored_rate = payload.exchange_rate
    elif currency.upper() == "EGP":
        stored_rate = 1.0
    elif payload.amount_fx and payload.amount_fx > 0 and amount_egp:
        stored_rate = amount_egp / payload.amount_fx
    else:
        stored_rate = None
    # Q2 (CTO): vat_included keeps today's add-on math until the business rule is decided.
    net_payable = round(amount_egp + (payload.vat_amount or 0.0) - (payload.wht_amount or 0.0), 2)

    def write() -> ClearanceExpenseInvoice:
        invoice = ClearanceExpenseInvoice(
            invoice_code=repo.generate_clearance_invoice_code(db),
            import_file_id=payload.import_file_id,
            customs_clearance_id=clearance_id,
            invoice_number=payload.invoice_number.strip(),
            invoice_date=payload.invoice_date or _now(),
            provider_id=payload.provider_id,
            provider_name=payload.provider_name.strip(),
            expense_category=enum_codes.normalize(enum_codes.CLEARANCE_EXPENSE_CATEGORY, payload.expense_category.strip()),
            currency=currency,
            amount_fx=payload.amount_fx or 0.0,
            exchange_rate=stored_rate,
            amount_egp=amount_egp,
            vat_included=payload.vat_included,
            vat_amount=payload.vat_amount or 0.0,
            wht_deducted=payload.wht_deducted,
            wht_amount=payload.wht_amount or 0.0,
            net_payable_egp=net_payable,
            payment_status=payload.payment_status or "Unpaid",
            payment_ref=payload.payment_ref,
            document_url=payload.document_url,
            allocation_rule=payload.allocation_rule or "Equal",
            notes=payload.notes,
            is_verified=True,
            is_active=True,
            created_by=current_user,
            updated_by=current_user,
        )
        repo.add(db, invoice)
        if stored_rate is None:
            invoice.exchange_rate = None  # the column's 1.0 insert default replaced a None: clear it explicitly
        _recalculate_clearance_expenses_aggregates(db, payload.import_file_id, clearance_id)
        return invoice

    invoice = _commit_write(db, write)
    invoice_msg = msg(
        "CC_CLEARANCE_INVOICE_RECORDED",
        invoice_number=invoice.invoice_number,
        expense_category_enum_clearance_expense_category=invoice.expense_category,
        net_amount=_money(invoice.net_payable_egp),
        provider_name=invoice.provider_name or "-",
        import_file_code=file_label,
    )
    _follow_up(db, "CL-05 settlement snapshot", _sync_settlement_snapshot, db, payload.import_file_id, actor=current_user)
    _follow_up(db, "CL-05 task completion", _complete_tasks, db, payload.import_file_id,
               ("CLEARANCE_INVOICES", "CL-05"), invoice_msg, current_user,
               note_part="body", task_codes=("CL-05", "TSK-0205"), open_statuses=("Pending", "In Progress"))
    _follow_up(db, "CL-05 notification", _notify, db, payload.import_file_id, invoice_msg)
    db.refresh(invoice)
    return invoice


def get_clearance_invoices_by_file_service(
    db: Session,
    import_file_id: int
) -> ClearanceInvoicesSummaryResponse:
    """All active clearance invoices of a file with the category split."""
    invoices = repo.get_active_invoices_for_file(db, import_file_id, newest_first=True)
    total_amount = sum(inv.amount_egp for inv in invoices)
    total_vat = sum(inv.vat_amount for inv in invoices)
    total_wht = sum(inv.wht_amount for inv in invoices)
    net_payable = sum(inv.net_payable_egp for inv in invoices)
    buckets = _bucket_totals(invoices)
    total_other = round(net_payable - (buckets["clearance"] + buckets["port"] + buckets["handling"]), 2)
    if total_other < 0:
        total_other = 0.0

    return ClearanceInvoicesSummaryResponse(
        import_file_id=import_file_id,
        invoices_count=len(invoices),
        total_amount_egp=round(total_amount, 2),
        total_vat_egp=round(total_vat, 2),
        total_wht_egp=round(total_wht, 2),
        net_payable_egp=round(net_payable, 2),
        total_clearance_fees_egp=round(buckets["clearance"], 2),
        total_port_dues_egp=round(buckets["port"], 2),
        total_handling_stevedoring_egp=round(buckets["handling"], 2),
        total_other_expenses_egp=round(total_other, 2),
        invoices=[ClearanceExpenseInvoiceResponse.model_validate(inv) for inv in invoices],
    )


def delete_clearance_invoice_service(
    db: Session,
    invoice_id: int,
    current_user: str = SYSTEM_USER,
) -> bool:
    """Soft-delete a clearance invoice, recompute the totals, then resync the settlement snapshot."""
    inv = repo.get_invoice_by_id(db, invoice_id)
    if not inv:
        raise HTTPException(status_code=404, detail="فاتورة التخليص غير موجودة أو محذوفة.")
    import_file_id = inv.import_file_id
    clearance_id = inv.customs_clearance_id
    validate_settlement_open(db, import_file_id)

    inv.is_active = False
    _touch(inv, current_user)
    _recalculate_clearance_expenses_aggregates(db, import_file_id, clearance_id)
    db.commit()
    _follow_up(db, "CL-05 settlement snapshot", _sync_settlement_snapshot, db, import_file_id, actor=current_user)
    return True
