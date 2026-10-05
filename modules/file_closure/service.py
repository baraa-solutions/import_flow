from datetime import date, datetime, timezone
from typing import Dict, List, Optional, Tuple

from fastapi import HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .model import ImportFileClosureRecord
from .schemas import (
    FileClosureCreate,
    FileClosureUpdate,
    DossierSectionSummary,
    ComprehensiveShipmentDossierResponse,
    DossierExportConfirmRequest,
    DossierExportConfirmResponse,
    ClosurePrecheckResponse,
    OfficialClosureCertificateResponse,
)
from . import repository as repo
from .validators import (
    CLOSURE_STATUS_CLOSED,
    CLOSURE_STATUS_DRAFT,
    FILE_STATUS_CLOSED,
    SETTLED_SETTLEMENT_STATUSES,
    ClosureFacts,
    ClosureGate,
    already_closed_error,
    closed_record_locked_error,
    closure_blocked_error,
    closure_exists_error,
    evaluate_closure_gate,
    validate_update_status,
)
from modules.auth.permissions import has_user_permission
from modules.common.errors import best_effort
from modules.common.file_tracking import set_file_tracking
from modules.common.system_messages import msg, render_en
from modules.import_files.model import ImportFile
from modules.notifications.model import SystemNotification
from modules.smart_tasks.model import SmartTask
from modules.users.model import User

OPEN_TASK_STATUSES = ("Pending", "In Progress", "In-Progress", "Under Review")
CLOSURE_MODULE = "Phase 10 - Import File Closure & Historical Archive"
# Defaults older clients send verbatim: treated as "not given" so the signed-in user is recorded instead (FC-10).
LEGACY_AUDITOR_DEFAULTS = frozenset({"Internal Auditor", "Finance & Audit Controller", "Finance Manager"})
LEGACY_EXPORTER_DEFAULTS = frozenset({"Finance & Logistics Controller"})


# ==============================================================================
# Shared helpers
# ==============================================================================

def _get_active_file(db: Session, import_file_id: int) -> ImportFile:
    imp = db.query(ImportFile).filter(
        ImportFile.import_file_id == import_file_id,
        ImportFile.is_active == True,
    ).first()
    if not imp:
        raise HTTPException(
            status_code=404,
            detail=f"ملف الشحنة الاستيرادية رقم {import_file_id} غير موجود أو محذوف.",
        )
    return imp


def _party_names(imp: ImportFile) -> Tuple[str, str]:
    """Company and supplier names from master data, else the file's stored names, else "" (never invented)."""
    company = getattr(imp, "company", None)
    supplier = getattr(imp, "supplier", None)
    company_name = (
        getattr(company, "importer_name", None)
        or getattr(company, "company_name", None)
        or imp.company_name
        or ""
    )
    supplier_name = (
        getattr(supplier, "company_name", None)
        or getattr(supplier, "supplier_name", None)
        or imp.supplier_name
        or ""
    )
    return company_name, supplier_name


def _resolve_user_name(value: Optional[str], legacy_defaults: frozenset, user: str) -> str:
    text = (value or "").strip()
    return user if not text or text in legacy_defaults else text


def _require_any_permission(db: Session, actor: Optional[User], *codes: str) -> None:
    """Route-level auth only proves the user may read closures; the write permission depends on the payload."""
    if actor is None:
        return
    if not any(has_user_permission(db, actor, code) for code in codes):
        raise HTTPException(
            status_code=403,
            detail=f"Access denied. Permission '{codes[-1]}' required.",
        )


def _is_closure_task(task: SmartTask) -> bool:
    return (
        task.msg_code == "CLO_TASK_OFFICIAL_CLOSURE"
        or "0904" in (task.task_code or "")
        # legacy rows created before msg codes existed
        or "CLO-04" in (task.title or "")
        or "إغلاق" in (task.title or "")
        or "أرشفة" in (task.title or "")
    )


def _closure_facts(db: Session, imp: ImportFile) -> Tuple[ClosureFacts, Optional[object]]:
    """Load the gate facts. No exception is swallowed: a failing query fails the precheck / close (FC-01)."""
    grns = repo.active_grns(db, imp.import_file_id)
    settlement = repo.latest_active_settlement(db, imp.import_file_id, SETTLED_SETTLEMENT_STATUSES)
    tasks = repo.open_tasks(db, imp.import_file_id, OPEN_TASK_STATUSES)
    facts = ClosureFacts(
        skipped_stages=list(imp.skipped_stages or []),
        has_final_release_clearance=repo.has_final_release_clearance(db, imp.import_file_id),
        is_customs_released=bool(imp.is_customs_released),
        customs_release_permit_no=imp.customs_release_permit_no,
        customs_released_at=imp.customs_released_at,
        active_grn_count=len(grns),
        locked_grn_count=sum(1 for g in grns if g.quarantine_lock_active),
        has_settled_settlement=settlement is not None,
        actual_landed_cost_egp=float(imp.actual_landed_cost_total_egp or 0.0),
        financial_settlement_status=imp.financial_settlement_status,
        dossier_exported_at=imp.dossier_exported_at,
        shipment_mode=imp.shipment_mode,
        empty_containers_return_status=imp.empty_containers_return_status,
        empty_containers_returned_at=imp.empty_containers_returned_at,
        empty_containers_eir_numbers=imp.empty_containers_eir_numbers,
        acid_number=imp.acid_number,
        form46_no=imp.form46_no,
        form4_no=imp.form4_no,
        cargox_envelope_id=imp.cargox_envelope_id,
        open_operational_task_count=sum(1 for t in tasks if not _is_closure_task(t)),
    )
    return facts, settlement


def evaluate_file_closure_gate(db: Session, imp: ImportFile) -> ClosureGate:
    """The single closure rule shared by the precheck and the final close (FC-03)."""
    facts, _ = _closure_facts(db, imp)
    return evaluate_closure_gate(facts)


def _insert_closure(db: Session, values: dict) -> ImportFileClosureRecord:
    """Insert with a fresh CLR code; one retry when a concurrent insert took the same code (unique constraint).
    The closure row is the first write of the request, so the rollback before the retry loses nothing."""
    try:
        return repo.add_closure(db, {**values, "closure_code": repo.generate_closure_code(db)})
    except IntegrityError:
        db.rollback()
        return repo.add_closure(db, {**values, "closure_code": repo.generate_closure_code(db)})


# ==============================================================================
# BP-040: Closure records
# ==============================================================================

def close_import_file_service(
    db: Session,
    schema: FileClosureCreate,
    user: str = "System",
    actor: Optional[User] = None,
) -> ImportFileClosureRecord:
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == schema.import_file_id, ImportFile.is_active == True).first()
    if not imp_file:
        raise HTTPException(status_code=404, detail="ملف الشحنة الاستيرادية المرتكز عليه غير موجود أو محذوف.")

    if schema.is_draft:
        _require_any_permission(db, actor, "import_files.edit", "import_files.close")
    else:
        _require_any_permission(db, actor, "import_files.close")

    # FC-04: a closed file is never closed again (nor moved back to a draft closure) until it is reopened.
    if imp_file.status == FILE_STATUS_CLOSED:
        raise already_closed_error(imp_file.import_file_code)

    auditor = _resolve_user_name(schema.auditor_name, LEGACY_AUDITOR_DEFAULTS, user)
    target_status = CLOSURE_STATUS_DRAFT if schema.is_draft else CLOSURE_STATUS_CLOSED

    if schema.is_draft:
        # Draft: the client checklist is stored for the record only.
        checklist = {k: v for k, v in schema.closure_checklist.model_dump().items() if v is not None}
    else:
        # FC-01: the server gate decides; the stored checklist is the server's view at closure time.
        gate = evaluate_file_closure_gate(db, imp_file)
        if not gate.can_close:
            raise closure_blocked_error(gate)
        checklist = gate.checklist

    import_file_id = imp_file.import_file_id
    existing_record = repo.get_closure_by_import_file_id(db, import_file_id)
    values = {
        "closure_checklist": checklist,
        "auditor_name": auditor,
        "archive_location": schema.archive_location,
        "archival_notes": schema.archival_notes,
        "status": target_status,
    }
    if existing_record:
        # closed_at moves only when the record becomes Closed (a draft re-save keeps it)
        extra = {} if schema.is_draft else {"closed_at": datetime.now(timezone.utc)}
        record = repo.apply_changes(existing_record, {**values, **extra}, user)
    else:
        record = _insert_closure(db, {**values, "import_file_id": import_file_id, "created_by": user, "updated_by": user})
        imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()

    if schema.is_draft:
        imp_file.current_module = "Phase 10 - Import File Closure & Historical Archive (Draft)"
        set_file_tracking(imp_file, stage_code="CLOSURE_IN_PROGRESS", next_action=msg("NA_CLO_COMPLETE_CHECKLIST"))
        db.commit()
        db.refresh(record)
        return record

    # FC-05: remember where the file was so a reopen restores that phase.
    imp_file.closed_at_phase = imp_file.current_module
    imp_file.status = FILE_STATUS_CLOSED
    imp_file.current_module = CLOSURE_MODULE
    imp_file.progress_percent = 100.0
    set_file_tracking(imp_file, stage_code="ARCHIVED_CLOSED", next_action=msg("NA_FILE_ARCHIVED_READ_ONLY"))

    # Auto-complete pending closure SmartTasks (only the closure tasks: see the precheck warning, FC-11)
    for t in repo.open_tasks(db, import_file_id, OPEN_TASK_STATUSES):
        if _is_closure_task(t):
            t.status = "Completed"
            t.is_auto_closed = True
            t.updated_by = user

    notif_msg = msg(
        "CLO_FILE_CLOSED",
        import_file_code=imp_file.import_file_code,
        closure_code=record.closure_code,
        archive_location=schema.archive_location,
    )
    db.add(SystemNotification(
        title=render_en(notif_msg.code, notif_msg.params, "title"),
        message=render_en(notif_msg.code, notif_msg.params, "body"),
        msg_code=notif_msg.code,
        msg_params=notif_msg.params,
        severity="INFO",
        category="FILE_CLOSURE",
        entity_type="ImportFile",
        entity_id=import_file_id,
        target_role="ALL",
    ))
    db.commit()
    db.refresh(record)

    # Follow-ups after the closure is saved: a failure is logged and never reopens the file.
    closure_code = record.closure_code
    record_id = record.closure_id

    def _lifecycle() -> None:
        from modules.lifecycle_board.service import advance_lifecycle_step_service
        advance_lifecycle_step_service(
            db=db,
            import_file_id=import_file_id,
            completed_step_code="STEP_21",
            target_step_codes=[],
            notes_msg=msg("CLO_FILE_CLOSED", closure_code=closure_code, auditor_name=auditor),
            next_action_msg=msg("NA_FILE_ARCHIVED_READ_ONLY"),
            stage_code="ARCHIVED_CLOSED",
            assigned_user=auditor,
        )

    def _enforce_terminal_state() -> None:
        imp = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
        set_file_tracking(imp, stage_code="ARCHIVED_CLOSED", next_action=msg("NA_FILE_ARCHIVED_READ_ONLY"))
        imp.current_module = CLOSURE_MODULE
        imp.status = FILE_STATUS_CLOSED
        imp.progress_percent = 100.0
        db.commit()

    def _learning() -> None:
        # KB-GUIDE-012 Section 5A: Autonomous Reference Engine Continuous Learning Trigger
        from modules.experience_guide.service import ExperienceGuideService
        ExperienceGuideService.run_autonomous_learning(db=db, trigger_import_file_id=import_file_id)

    best_effort(db, _lifecycle, "Closure lifecycle advance STEP_21")
    best_effort(db, _enforce_terminal_state, "Closure terminal state after lifecycle advance")
    best_effort(db, _learning, "Closure autonomous learning trigger")

    return repo.get_closure_by_id(db, record_id, include_inactive=True)


def get_closure_service(db: Session, closure_id: int) -> ImportFileClosureRecord:
    record = repo.get_closure_by_id(db, closure_id)
    if not record:
        raise HTTPException(status_code=404, detail="سجل إغلاق وأرشفة الملف غير موجود.")
    return record


def list_closures_service(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    search: Optional[str] = None,
) -> List[ImportFileClosureRecord]:
    return repo.list_closures(db, include_inactive, import_file_id, search)


def _is_locked_closure(db: Session, record: ImportFileClosureRecord) -> bool:
    """A Closed record of a file that is still Closed (FC-09): same rule for PUT and DELETE."""
    if record.status != CLOSURE_STATUS_CLOSED:
        return False
    imp = db.query(ImportFile).filter(ImportFile.import_file_id == record.import_file_id).first()
    return imp is not None and imp.status == FILE_STATUS_CLOSED


# Fields a Closed record still accepts (FC-09): archival metadata only.
CLOSED_RECORD_EDITABLE = frozenset({"archival_notes", "archive_location"})


def update_closure_service(
    db: Session,
    closure_id: int,
    schema: FileClosureUpdate,
    user: str = "System",
) -> ImportFileClosureRecord:
    record = get_closure_service(db, closure_id)
    data = schema.model_dump(exclude_unset=True)
    validate_update_status(data.get("status"))

    if _is_locked_closure(db, record) and set(data) - CLOSED_RECORD_EDITABLE:
        raise closed_record_locked_error(record.closure_code)

    values: Dict[str, object] = {}
    for key, value in data.items():
        if key == "closure_checklist":
            if value is not None:
                values[key] = {k: v for k, v in schema.closure_checklist.model_dump().items() if v is not None}
        elif value is not None:
            values[key] = value
    if "auditor_name" in values:
        values["auditor_name"] = _resolve_user_name(values["auditor_name"], LEGACY_AUDITOR_DEFAULTS, user)

    repo.apply_changes(record, values, user)
    db.commit()
    db.refresh(record)
    return record


def soft_delete_closure_service(db: Session, closure_id: int, user: str = "System") -> bool:
    record = get_closure_service(db, closure_id)
    # Q5: deleting the closure of a closed file would leave it Closed without a closure: reopen first.
    if _is_locked_closure(db, record):
        raise closed_record_locked_error(record.closure_code)
    repo.apply_changes(record, {"is_active": False}, user)
    db.commit()
    return True


def restore_closure_service(db: Session, closure_id: int, user: str = "System") -> ImportFileClosureRecord:
    record = repo.get_closure_by_id(db, closure_id, include_inactive=True)
    if not record:
        raise HTTPException(status_code=404, detail=f"سجل أرشفة وإغلاق الملف رقم {closure_id} غير موجود.")
    if not record.is_active:
        other = repo.get_closure_by_import_file_id(db, record.import_file_id, exclude_id=record.closure_id)
        if other is not None:
            raise closure_exists_error(other.closure_code)
    repo.apply_changes(record, {"is_active": True}, user)
    db.commit()
    db.refresh(record)
    return record


# ==============================================================================
# CLO-03: Comprehensive Shipment Dossier Aggregation & Export Confirmation
# ==============================================================================

def _to_date(value) -> Optional[date]:
    if value is None:
        return None
    return value.date() if isinstance(value, datetime) else value


def _fob_egp(db: Session, amounts_by_currency: Dict[str, float], on_date: date) -> Optional[float]:
    """FOB in EGP at the customs rate valid on ``on_date``. None when any currency has no configured rate
    (FC-02: never a hard-coded factor)."""
    total = 0.0
    for currency, amount in amounts_by_currency.items():
        if not amount:
            continue
        rate = repo.customs_rate_to_egp(db, currency, on_date)
        if rate is None:
            return None
        total += amount * rate
    return round(total, 2)


def _stored_clearance_fob_egp(clearance, amounts_by_currency: Dict[str, float]) -> Optional[float]:
    """FOB in EGP at the customs rate stored on the clearance (the rate Nafeza actually applied).

    The clearance keeps the rate without its currency, so it is used only when the FOB is in exactly one foreign
    currency (the one the declaration was valued in). 1.0 is the column default (rate never entered) and is ignored."""
    if clearance is None:
        return None
    rate = float(clearance.customs_exchange_rate or 0.0)
    currencies = [c for c, amount in amounts_by_currency.items() if amount]
    if rate <= 0 or rate == 1.0 or len(currencies) != 1 or currencies[0].strip().upper() == "EGP":
        return None
    return round(amounts_by_currency[currencies[0]] * rate, 2)


def get_comprehensive_shipment_dossier_service(
    db: Session,
    import_file_id: int,
) -> ComprehensiveShipmentDossierResponse:
    """
    CLO-03: Aggregates all operational, documentation, logistics, customs, warehouse,
    and financial settlement records across all 10 phases into a single comprehensive dossier.
    Missing data stays empty ("" / None / 0): nothing is invented (FC-07).
    """
    imp = _get_active_file(db, import_file_id)

    # 1. Party details
    company_name, supplier_name = _party_names(imp)

    # 2. Purchase Orders & Line Items
    pos = repo.active_purchase_orders(db, import_file_id)

    po_summaries = []
    items_detail = []
    total_fob_fc = 0.0
    fob_currency = "USD"
    fob_by_currency: Dict[str, float] = {}

    for po in pos:
        curr = po.currency.currency_code if getattr(po, "currency", None) else "USD"
        fob_currency = curr
        amt = float(po.total_amount_fob or 0.0)
        total_fob_fc += amt
        fob_by_currency[curr] = fob_by_currency.get(curr, 0.0) + amt
        po_summaries.append({
            "po_id": po.po_id,
            "po_number": po.po_number,
            "po_reference": po.po_reference,
            "proforma_invoice_number": po.proforma_invoice_number,
            "currency": curr,
            "exchange_rate": float(po.exchange_rate or 1.0),
            "total_amount_fob": amt,
            "total_packages": int(po.total_packages_count or 0),
            "total_gross_weight_kg": float(po.total_gross_weight_kg or 0.0),
            "total_cbm": float(po.total_cbm or 0.0),
            "status": po.status,
        })

        for itm in (po.line_items or []):
            hs = (itm.tariff.hs_code if getattr(itm, "tariff", None) else getattr(itm, "hs_code", "")) or (imp.hs_code or "")
            qty = float(itm.quantity or 0.0)
            u_price = float(itm.unit_price or 0.0)
            tot_price = float(itm.total_price or (qty * u_price))
            items_detail.append({
                "item_code": itm.item_code or f"ITM-{len(items_detail)+1:03d}",
                "description": itm.description_ar or itm.description_en or itm.main_description or "",
                "quantity": qty,
                "unit_of_measure": itm.unit_of_measure or "",
                "unit_price": u_price,
                "total_price": tot_price,
                "hs_code": hs,
                "cbm": float(itm.total_cbm or 0.0),
                "weight_kg": float(itm.gross_weight_kg or 0.0),
            })

    # Fallback to estimated cost if no PO items found
    if total_fob_fc == 0.0 and getattr(imp, "estimated_cost", 0.0):
        total_fob_fc = float(imp.estimated_cost or 0.0)
        fob_currency = imp.estimated_cost_currency or "USD"
        fob_by_currency = {fob_currency: total_fob_fc}

    # 3. Customs Clearance Record
    clearance = repo.latest_active_clearance(db, import_file_id)

    broker_name = (clearance.broker_name if clearance and clearance.broker_name else None) or imp.broker_name or None

    customs_declaration_no = (clearance.declaration_46_no if clearance else None) or imp.form46_no
    customs_channel = clearance.channel_type if clearance else None
    customs_office = (clearance.customs_office_name if clearance else None) or None
    customs_duty_amount = float(clearance.import_duty_amount or 0.0) if clearance else 0.0
    vat_amount = float(clearance.vat_amount or 0.0) if clearance else 0.0
    schedule_tax_amount = float(clearance.schedule_tax_amount or 0.0) if clearance else 0.0
    total_customs_paid = float(
        ((clearance.duty_paid_amount or clearance.total_duty_payable) or 0.0)
        if clearance
        else (imp.customs_duty_paid_amount or 0.0)
    )
    customs_release_permit_no = (clearance.release_permit_no if clearance else None) or imp.customs_release_permit_no
    customs_released_at_str = (
        clearance.release_date.isoformat()
        if clearance and clearance.release_date
        else (imp.customs_released_at.isoformat() if imp.customs_released_at else None)
    )

    # 4. Inland Transport Booking
    inland = repo.latest_active_inland_booking(db, import_file_id)

    inland_carrier = (inland.carrier_name if inland else None) or imp.inland_carrier_name
    inland_truck = (inland.truck_plate_number if inland else None) or imp.inland_truck_plate_no
    inland_driver = (inland.driver_name if inland else None) or imp.inland_driver_name
    inland_arrival_str = (
        inland.actual_arrival_at.isoformat()
        if inland and inland.actual_arrival_at
        else (imp.inland_actual_arrival_date.isoformat() if imp.inland_actual_arrival_date else None)
    )

    # 5. Warehouse Receiving Record (active GRNs only, FC-08)
    grns = repo.active_grns(db, import_file_id)
    wh = grns[0] if grns else None
    wh_grn_code = wh.grn_code if wh else None
    wh_name = wh.warehouse_name if wh else None
    wh_acc_qty = int(wh.total_accepted_qty or 0) if wh else 0
    wh_short_qty = int(wh.total_shortage_qty or 0) if wh else 0
    wh_dam_qty = int(wh.total_damaged_qty or 0) if wh else 0

    # 6. Landed Cost Settlement Record
    settlement = repo.latest_active_settlement(db, import_file_id)

    fin_status = (settlement.status if settlement else None) or imp.financial_settlement_status
    inv_count = len(settlement.expense_invoices or []) if settlement else 0
    fin_expenses_egp = float(settlement.total_expenses_egp or 0.0) if settlement else 0.0
    actual_landed_egp = float(
        (settlement.total_landed_cost_egp if settlement else None)
        or imp.actual_landed_cost_total_egp
        or 0.0
    )
    markup_fac = float(
        (settlement.average_markup_factor if settlement else None)
        or imp.actual_landed_cost_markup_factor
        or 1.0
    )
    var_egp = float(imp.actual_landed_cost_variance_egp or 0.0)
    var_pct = float(imp.actual_landed_cost_variance_pct or 0.0)
    calc_at = imp.actual_landed_cost_calculated_at or (settlement.updated_at if settlement else None)
    if settlement is not None and settlement.total_fob_egp:
        total_fob_egp: Optional[float] = float(settlement.total_fob_egp)
    else:
        total_fob_egp = _stored_clearance_fob_egp(clearance, fob_by_currency)
        if total_fob_egp is None:
            # Customs valuation date: declaration (Form 46) date, then the release date, then today.
            rate_date = _to_date(imp.form46_date) or _to_date(imp.customs_released_at) or date.today()
            total_fob_egp = _fob_egp(db, fob_by_currency, rate_date)

    settlement_done = bool(settlement and settlement.status in SETTLED_SETTLEMENT_STATUSES)
    customs_released = bool(
        (clearance and clearance.release_permit_no) or imp.customs_release_permit_no or imp.is_customs_released
    )
    containers_returned = bool(
        imp.empty_containers_returned_at is not None or imp.empty_containers_return_status == "ALL_RETURNED"
    )

    # 7. 10-Phase Sections Dossier
    sections = [
        DossierSectionSummary(
            section_code="SEC-01",
            section_name_en="Phase 1 & 2: Commercial Contract & PO",
            section_name_ar="أمر الشراء والتوريد والتعاقد الخارجي",
            status="COMPLETED" if pos or total_fob_fc > 0 else "PENDING",
            status_ar="مكتمل" if pos or total_fob_fc > 0 else "قيد الانتظار",
            details={
                "po_count": len(pos),
                "total_fob_fc": total_fob_fc,
                "currency": fob_currency,
                "items_count": len(items_detail),
                "incoterm": imp.incoterm_code or "",
            },
        ),
        DossierSectionSummary(
            section_code="SEC-02",
            section_name_en="Phase 3: Advance Cargo Information (ACID)",
            section_name_ar="التسجيل المسبق للشحنات نافذة ACID",
            status="COMPLETED" if imp.acid_number else "PENDING",
            status_ar="مكتمل ومسجل" if imp.acid_number else "معلق",
            details={
                "acid_number": imp.acid_number,
                "issue_date": str(imp.acid_issue_date or ""),
                "expiry_date": str(imp.acid_expiry_date or ""),
            },
        ),
        DossierSectionSummary(
            section_code="SEC-03",
            section_name_en="Phase 4: Banking Form 4 & Financing",
            section_name_ar="التمويل المصرفي ونموذج 4 وسويفت",
            status="COMPLETED" if imp.form4_no or imp.form4_received_date or imp.swift_no else "PENDING",
            status_ar="معتمد بنكياً" if imp.form4_no or imp.form4_received_date or imp.swift_no else "غير مكتمل",
            details={
                "form4_no": imp.form4_no,
                "form4_date": str(imp.form4_received_date or imp.form4_request_date or ""),
                "swift_no": imp.swift_no,
            },
        ),
        DossierSectionSummary(
            section_code="SEC-04",
            section_name_en="Phase 5: International Freight & Ocean Shipping",
            section_name_ar="الشحن الدولي والخط الملاحي وبوليصة الشحن",
            status="COMPLETED" if imp.bl_number or imp.booking_no or imp.vessel_name else "PENDING",
            status_ar="مشحون ومؤكد" if imp.bl_number or imp.booking_no or imp.vessel_name else "قيد الانتظار",
            details={
                "bl_number": imp.bl_number,
                "booking_no": imp.booking_no,
                "vessel_name": imp.vessel_name,
                "port_of_loading": imp.port_of_loading,
                "port_of_discharge": imp.port_of_discharge,
            },
        ),
        DossierSectionSummary(
            section_code="SEC-05",
            section_name_en="Phase 6: Customs Clearance & Form 46",
            section_name_ar="التخليص الجمركي ونموذج 46 والإفراج النهائي",
            status="COMPLETED" if customs_released else ("IN_PROGRESS" if clearance or imp.form46_no else "PENDING"),
            status_ar="مفرج عنه نهائياً" if customs_released else ("جاري التخليص" if clearance or imp.form46_no else "معلق"),
            details={
                "declaration_46_no": customs_declaration_no,
                "channel": customs_channel,
                "customs_office": customs_office,
                "release_permit_no": customs_release_permit_no,
                "total_customs_paid": total_customs_paid,
            },
        ),
        DossierSectionSummary(
            section_code="SEC-06",
            section_name_en="Phase 7: Inland Trucking & Delivery",
            section_name_ar="النقل الداخلي وتوصيل الشاحنات للمخزن",
            status="COMPLETED" if inland_arrival_str or imp.inland_transport_status in ["ARRIVED", "COMPLETED"] else ("IN_PROGRESS" if inland or imp.inland_transport_status == "IN_TRANSIT" else "PENDING"),
            status_ar="تم الوصول والتسليم" if inland_arrival_str or imp.inland_transport_status in ["ARRIVED", "COMPLETED"] else ("جاري النقل" if inland or imp.inland_transport_status == "IN_TRANSIT" else "معلق"),
            details={
                "carrier_name": inland_carrier,
                "truck_plate": inland_truck,
                "driver_name": inland_driver,
                "arrival_date": inland_arrival_str,
            },
        ),
        DossierSectionSummary(
            section_code="SEC-07",
            section_name_en="Phase 8: Warehouse Receiving & GRN",
            section_name_ar="فحص واستلام المستودع وإذن الإضافة GRN",
            status="COMPLETED" if wh else "PENDING",
            status_ar="مستلم بالكامل (GRN)" if wh else "معلق",
            details={
                "grn_code": wh_grn_code,
                "warehouse_name": wh_name,
                "accepted_qty": wh_acc_qty,
                "shortage_qty": wh_short_qty,
                "damaged_qty": wh_dam_qty,
            },
        ),
        DossierSectionSummary(
            section_code="SEC-08",
            section_name_en="Phase 8/9: Empty Container Return & EIR",
            section_name_ar="إعادة الحاويات الفارغة وإيصالات EIR",
            status="COMPLETED" if containers_returned else "PENDING",
            status_ar="تمت الإعادة واستلام EIR" if containers_returned else "معلق",
            details={
                "returned_at": imp.empty_containers_returned_at.isoformat() if imp.empty_containers_returned_at else None,
                "eir_numbers": imp.empty_containers_eir_numbers,
                "depot_name": imp.empty_containers_depot_name,
            },
        ),
        DossierSectionSummary(
            section_code="SEC-09",
            section_name_en="Phase 9: Multi-Party Invoices & Actual Landed Cost",
            section_name_ar="الفواتير متعددة الأطراف وتكلفة الوصول الفعلية",
            status="COMPLETED" if settlement_done or imp.financial_settlement_status == "COST_ALLOCATED" else "IN_PROGRESS",
            status_ar="معتمد وموزع" if settlement_done or imp.financial_settlement_status == "COST_ALLOCATED" else "قيد الاحتساب",
            details={
                "settlement_status": fin_status,
                "invoices_count": inv_count,
                "actual_landed_cost_total_egp": actual_landed_egp,
                "markup_factor": markup_fac,
                "variance_pct": var_pct,
            },
        ),
        DossierSectionSummary(
            section_code="SEC-10",
            section_name_en="Phase 10: Shipment Dossier & Final Archive",
            section_name_ar="الملف الشامل والأرشفة الرقمية والإغلاق الرسمي",
            status="COMPLETED" if imp.dossier_exported_at else "IN_PROGRESS",
            status_ar="مصدّر وجاهز للأرشفة" if imp.dossier_exported_at else "جاهز للتصدير والمراجعة",
            details={
                "exported_at": imp.dossier_exported_at.isoformat() if imp.dossier_exported_at else None,
                "exported_by": imp.dossier_exported_by,
            },
        ),
    ]

    closure_readiness = {
        "docs_verified": bool(imp.acid_number and (imp.form4_no or imp.swift_no)),
        "customs_cleared": customs_released,
        "warehouse_received": bool(wh is not None),
        "eir_returned": containers_returned,
        # FC-13: same key as the precheck checklist (eir_returned kept for old clients)
        "empty_containers_returned": containers_returned,
        "landed_cost_settled": bool(actual_landed_egp > 0 and (imp.financial_settlement_status == "COST_ALLOCATED" or settlement_done)),
        "tasks_closed": True,
    }

    summary_notes = (
        f"ملف الشحنة {imp.import_file_code} مستوفي لكافة مراحل الاستيراد العشر. "
        f"قيمة البضاعة FOB تبلغ {total_fob_fc:,.2f} {fob_currency}، "
        f"وتكلفة الوصول الفعلية الشاملة تبلغ {actual_landed_egp:,.2f} جنيه مصري بمعامل زيادة {markup_fac:.3f}x. "
        f"الملف جاهز للأرشفة الرقمية والاعتماد النهائي."
    )

    return ComprehensiveShipmentDossierResponse(
        import_file_id=imp.import_file_id,
        import_file_code=imp.import_file_code or f"IMP-{imp.import_file_id}",
        custom_file_number=imp.custom_file_number,
        status=imp.status,
        current_stage=imp.current_stage,
        current_module=imp.current_module,
        progress_percent=float(imp.progress_percent or 0.0),
        next_action=imp.next_action or render_en("NA_CLO_EXPORT_DOSSIER", {}, "action"),
        owner=imp.owner,
        created_at=imp.created_at,
        updated_at=imp.updated_at,
        dossier_exported_at=imp.dossier_exported_at,
        dossier_exported_by=imp.dossier_exported_by,
        company_id=imp.company_id,
        company_name=company_name,
        supplier_id=imp.supplier_id,
        supplier_name=supplier_name,
        broker_id=imp.broker_id,
        broker_name=broker_name,
        shipment_mode=imp.shipment_mode or "",
        incoterm_code=imp.incoterm_code or "",
        shipment_category=imp.shipment_category or "",
        priority=imp.priority or "",
        commodity=imp.product_category or imp.notes,
        port_of_loading=imp.port_of_loading,
        port_of_discharge=imp.port_of_discharge,
        total_packages=int(getattr(imp, "total_packages_count", 0) or sum(p.get("total_packages", 0) for p in po_summaries) or 0),
        gross_weight_kg=float(getattr(imp, "gross_weight_kg", 0.0) or sum(p.get("total_gross_weight_kg", 0.0) for p in po_summaries) or 0.0),
        net_weight_kg=float(getattr(imp, "net_weight_kg", 0.0) or sum(float(itm.get("weight_kg", 0.0) or 0.0) for itm in items_detail) or 0.0),
        total_cbm=float(getattr(imp, "total_cbm", 0.0) or sum(p.get("total_cbm", 0.0) for p in po_summaries) or 0.0),
        target_free_days=int(imp.target_free_days or 0),
        purchase_orders=po_summaries,
        total_fob_fc=total_fob_fc,
        total_fob_egp=total_fob_egp,
        fob_currency=fob_currency,
        items_count=len(items_detail),
        items_detail=items_detail,
        acid_number=imp.acid_number,
        acid_issue_date=str(imp.acid_issue_date) if imp.acid_issue_date else None,
        acid_expiry_date=str(imp.acid_expiry_date) if imp.acid_expiry_date else None,
        form4_no=imp.form4_no,
        form4_date=str(imp.form4_received_date or imp.form4_request_date) if (imp.form4_received_date or imp.form4_request_date) else None,
        swift_no=imp.swift_no,
        form46_no=imp.form46_no,
        form46_date=imp.form46_date.isoformat() if imp.form46_date else None,
        form46_status=imp.form46_status,
        cargox_envelope_id=str(imp.cargox_envelope_id) if imp.cargox_envelope_id else None,
        cargox_transferred_at=imp.cargox_transferred_at.isoformat() if imp.cargox_transferred_at else None,
        customs_declaration_no=customs_declaration_no,
        customs_channel=customs_channel,
        customs_office=customs_office,
        customs_duty_amount=customs_duty_amount,
        vat_amount=vat_amount,
        schedule_tax_amount=schedule_tax_amount,
        total_customs_paid=total_customs_paid,
        customs_release_permit_no=customs_release_permit_no,
        customs_released_at=customs_released_at_str,
        inland_carrier_name=inland_carrier,
        inland_truck_plate_no=inland_truck,
        inland_driver_name=inland_driver,
        inland_actual_arrival_date=inland_arrival_str,
        warehouse_grn_code=wh_grn_code,
        warehouse_name=wh_name,
        warehouse_accepted_qty=wh_acc_qty,
        warehouse_shortage_qty=wh_short_qty,
        warehouse_damaged_qty=wh_dam_qty,
        empty_containers_returned_at=imp.empty_containers_returned_at.isoformat() if imp.empty_containers_returned_at else None,
        empty_containers_eir_numbers=imp.empty_containers_eir_numbers,
        financial_settlement_status=fin_status,
        financial_settlement_invoices_count=inv_count,
        financial_settlement_total_egp=fin_expenses_egp,
        actual_landed_cost_total_egp=actual_landed_egp,
        actual_landed_cost_markup_factor=markup_fac,
        actual_landed_cost_variance_egp=var_egp,
        actual_landed_cost_variance_pct=var_pct,
        actual_landed_cost_calculated_at=calc_at,
        sections=sections,
        closure_readiness=closure_readiness,
        summary_notes=summary_notes,
    )


def confirm_dossier_export_service(
    db: Session,
    payload: DossierExportConfirmRequest,
    user: str = "System",
    actor: Optional[User] = None,
) -> DossierExportConfirmResponse:
    """
    CLO-03: Confirms the export of the comprehensive shipment dossier, records export metadata,
    advances progress to >=99.5%, resolves SmartTask TSK-0903, dispatches TSK-0904, and posts system notification.
    """
    imp = _get_active_file(db, payload.import_file_id)
    _require_any_permission(db, actor, "import_files.edit", "import_files.close")
    if imp.status == FILE_STATUS_CLOSED:
        raise already_closed_error(imp.import_file_code)

    exported_by = _resolve_user_name(payload.exported_by, LEGACY_EXPORTER_DEFAULTS, user)
    now_utc = datetime.now(timezone.utc)
    today_str = datetime.now().strftime("%Y-%m-%d")

    # 1. Update ImportFile metadata & progress
    imp.dossier_exported_at = now_utc
    imp.dossier_exported_by = exported_by
    current_progress = float(imp.progress_percent or 0.0)
    imp.progress_percent = max(current_progress, 99.5)
    imp.current_module = "Phase 10 - Comprehensive Dossier Export & Digital Archiving"
    set_file_tracking(imp, stage_code="CLOSURE_IN_PROGRESS", next_action=msg("NA_CLO_OFFICIAL_CLOSURE"))

    # 2. Resolve SmartTask TSK-0903
    tasks_903 = db.query(SmartTask).filter(
        SmartTask.import_file_id == imp.import_file_id,
        SmartTask.is_active == True,
        (SmartTask.task_code.ilike("%0903%") | SmartTask.title.ilike("%الملف الشامل%") | SmartTask.title.ilike("%CLO-03%"))
    ).all()
    for t in tasks_903:
        t.status = "Completed"
        t.is_auto_closed = True
        t.notes = f"Full dossier exported and approved as {payload.export_format} by {exported_by} on {today_str}"

    # 3. Dispatch downstream SmartTask TSK-0904
    task_code_904 = f"TSK-0904-{imp.import_file_id}"
    existing_904 = db.query(SmartTask).filter(SmartTask.task_code == task_code_904).first()
    if not existing_904:
        task_msg = msg(
            "CLO_TASK_OFFICIAL_CLOSURE",
            import_file_code=imp.import_file_code,
            export_format=payload.export_format,
        )
        db.add(SmartTask(
            task_code=task_code_904,
            title=render_en(task_msg.code, task_msg.params, "title"),
            description=render_en(task_msg.code, task_msg.params, "body"),
            msg_code=task_msg.code,
            msg_params=task_msg.params,
            step_code="STEP_21",
            task_type="System Generated",
            import_file_id=imp.import_file_id,
            import_file_code=imp.import_file_code,
            phase_name="Stage 10: Import File Closure & Archival",
            assigned_user=exported_by,
            priority="High",
            reminder_type="Final Closure",
            due_date=today_str,
            status="Pending",
            created_by=user,
            updated_by=user,
        ))

    # 4. Dispatch central SystemNotification
    notif_msg = msg(
        "CLO_DOSSIER_EXPORTED",
        import_file_code=imp.import_file_code,
        exported_by=exported_by,
        export_format=payload.export_format,
    )
    db.add(SystemNotification(
        title=render_en(notif_msg.code, notif_msg.params, "title"),
        message=render_en(notif_msg.code, notif_msg.params, "body"),
        msg_code=notif_msg.code,
        msg_params=notif_msg.params,
        severity="INFO",
        category="FILE_CLOSURE",
        entity_type="ImportFile",
        entity_id=imp.import_file_id,
        target_role="ALL",
    ))
    db.commit()

    # 5. Lifecycle advance STEP_20 -> STEP_21 (follow-up: never undoes the saved export)
    import_file_id = imp.import_file_id

    def _lifecycle() -> None:
        from modules.lifecycle_board.service import advance_lifecycle_step_service
        advance_lifecycle_step_service(
            db=db,
            import_file_id=import_file_id,
            completed_step_code="STEP_20",
            target_step_codes=["STEP_21"],
            notes_msg=msg("CLO_DOSSIER_EXPORTED", export_format=payload.export_format, exported_by=exported_by),
            next_action_msg=msg("NA_CLO_OFFICIAL_CLOSURE"),
            assigned_user=exported_by,
        )

    def _enforce_next_action() -> None:
        target = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
        set_file_tracking(target, next_action=msg("NA_CLO_OFFICIAL_CLOSURE"))
        db.commit()

    best_effort(db, _lifecycle, "Dossier export lifecycle advance STEP_20 -> STEP_21")
    best_effort(db, _enforce_next_action, "Dossier export next action")

    imp = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
    return DossierExportConfirmResponse(
        success=True,
        import_file_id=imp.import_file_id,
        import_file_code=imp.import_file_code or f"IMP-{imp.import_file_id}",
        dossier_exported_at=imp.dossier_exported_at,
        dossier_exported_by=imp.dossier_exported_by,
        progress_percent=imp.progress_percent,
        current_stage=imp.current_stage,
        current_module=imp.current_module,
        next_task_code=task_code_904,
        next_task_title=render_en("CLO_TASK_OFFICIAL_CLOSURE", {}, "title"),
        message=f"تم تصدير واعتماد الملف الشامل للشحنة {imp.import_file_code} بنجاح وإطلاق مهمة الإغلاق النهائي والأرشفة (CLO-04).",
    )


# ==============================================================================
# CLO-04: Official File Closure & Digital Archive Services
# ==============================================================================

def get_closure_precheck_service(db: Session, import_file_id: int) -> ClosurePrecheckResponse:
    """
    CLO-04: Live audit gate before official file closure. Same rule as the close itself (FC-03).
    """
    imp = _get_active_file(db, import_file_id)
    company_name, supplier_name = _party_names(imp)

    facts, settlement = _closure_facts(db, imp)
    gate = evaluate_closure_gate(facts)
    # The close re-uses the active (draft) record and its code; otherwise it issues the next yearly code.
    existing = repo.get_closure_by_import_file_id(db, import_file_id)

    actual_landed = float(imp.actual_landed_cost_total_egp or 0.0)
    markup = float(imp.actual_landed_cost_markup_factor or 1.0)
    if settlement is not None:
        actual_landed = float(settlement.total_landed_cost_egp or actual_landed)
        markup = float(settlement.average_markup_factor or markup)

    return ClosurePrecheckResponse(
        import_file_id=imp.import_file_id,
        import_file_code=imp.import_file_code or f"IMP-{imp.import_file_id}",
        company_name=company_name,
        supplier_name=supplier_name,
        can_close=gate.can_close and imp.status != FILE_STATUS_CLOSED,
        blocking_reasons=gate.blocking_reasons,
        warnings=gate.warnings,
        checklist_status=gate.checklist,
        actual_landed_cost_egp=actual_landed,
        actual_markup_factor=markup,
        dossier_exported_at=imp.dossier_exported_at,
        dossier_exported_by=imp.dossier_exported_by,
        empty_containers_returned_at=imp.empty_containers_returned_at,
        certificate_code_preview=(
            existing.closure_code if existing is not None else repo.generate_closure_code(db)
        ),
    )


def official_close_import_file_service(
    db: Session,
    schema: FileClosureCreate,
    user: str = "System",
) -> OfficialClosureCertificateResponse:
    """
    CLO-04: Formal closure & digital archival.
    Issues digital certificate, locks file at 100%, and advances lifecycle board to terminal STEP_21.
    """
    final_schema = schema.model_copy(update={"is_draft": False})
    record = close_import_file_service(db, final_schema, user=user)

    imp = db.query(ImportFile).filter(ImportFile.import_file_id == schema.import_file_id).first()
    company_name, supplier_name = _party_names(imp)

    return OfficialClosureCertificateResponse(
        success=True,
        closure_id=record.closure_id,
        closure_code=record.closure_code,
        import_file_id=imp.import_file_id,
        import_file_code=imp.import_file_code or f"IMP-{imp.import_file_id}",
        company_name=company_name,
        supplier_name=supplier_name,
        auditor_name=record.auditor_name,
        archive_location=record.archive_location,
        archival_notes=record.archival_notes,
        closed_at=record.closed_at,
        status=imp.status,
        progress_percent=float(imp.progress_percent or 100.0),
        current_stage=imp.current_stage or "",
        current_module=imp.current_module or CLOSURE_MODULE,
        next_action=imp.next_action or render_en("NA_FILE_ARCHIVED_READ_ONLY", {}, "action"),
        message=f"تم إغلاق ملف الشحنة {imp.import_file_code} رسمياً بنجاح بنسبة إنجاز 100%، وتم إصدار شهادة الإغلاق والأرشفة الرقمية {record.closure_code}.",
    )
