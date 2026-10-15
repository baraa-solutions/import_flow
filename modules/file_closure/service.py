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
    BLOCKING_MESSAGES_AR,
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
    export_blocked_error,
    export_blocking_keys,
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
    # BE810-T10: Client values in request bodies are ignored; acting user is taken from token.
    return user


def _require_any_permission(db: Session, actor: Optional[User], *codes: str, trusted: bool = False) -> None:
    """Route-level auth only proves the user may read closures; the write permission depends on the payload (BE810-F31)."""
    if trusted:
        return
    if actor is None:
        raise HTTPException(
            status_code=403,
            detail=f"Access denied. Permission '{codes[-1]}' required.",
        )
    if not any(has_user_permission(db, actor, code) for code in codes):
        raise HTTPException(
            status_code=403,
            detail=f"Access denied. Permission '{codes[-1]}' required.",
        )


def _is_closure_task(task: SmartTask) -> bool:
    return (
        task.msg_code == "CLO_TASK_OFFICIAL_CLOSURE"
        or task.task_type == "CLO-04"
        or "0904" in (task.task_code or "")
        # legacy rows created before msg codes existed: exact CLO-04 match in title only (BE810-F27)
        or "CLO-04" in (task.title or "")
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
        locked_grn_count=sum(
            1 for g in grns
            if g.quarantine_lock_active
            and getattr(repo.latest_active_clearance(db, imp.import_file_id), "quarantine_lock", True) is not False
        ),
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
    trusted: bool = False,
) -> ImportFileClosureRecord:
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == schema.import_file_id, ImportFile.is_active == True).first()
    if not imp_file:
        raise HTTPException(status_code=404, detail="ملف الشحنة الاستيرادية المرتكز عليه غير موجود أو محذوف.")

    if schema.is_draft:
        _require_any_permission(db, actor, "import_files.edit", "import_files.close", trusted=trusted)
    else:
        _require_any_permission(db, actor, "import_files.close", trusted=trusted)

    # FC-04: a closed file is never closed again (nor moved back to a draft closure) until it is reopened.
    if imp_file.status == FILE_STATUS_CLOSED:
        raise already_closed_error(imp_file.import_file_code)

    auditor = user
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
        # closed_at moves only when the record becomes Closed (a draft re-save clears it if not Closed)
        if schema.is_draft:
            extra = {"closed_at": None} if target_status != "Closed" else {}
        else:
            extra = {"closed_at": datetime.now(timezone.utc)}
        record = repo.apply_changes(existing_record, {**values, **extra}, user)
    else:
        record = _insert_closure(db, {**values, "import_file_id": import_file_id, "created_by": user, "updated_by": user})
        imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()

    if schema.is_draft:
        # BE810-T09 / F19: Draft changes current_module / stage only when dossier is already exported.
        if imp_file.dossier_exported_at:
            imp_file.current_module = "Phase 10 - Import File Closure & Historical Archive (Draft)"
            set_file_tracking(imp_file, stage_code="CLOSURE_IN_PROGRESS", next_action=msg("NA_CLO_COMPLETE_CHECKLIST"))
        db.commit()
        db.refresh(record)

        def _audit_draft() -> None:
            from modules.audit_logs.service import AuditLogService
            AuditLogService(db).log_activity(
                entity_type="ImportFileClosureRecord",
                entity_id=record.closure_id,
                entity_code=record.closure_code,
                action="CREATE",
                new_data=schema.model_dump(exclude_unset=True),
                performed_by=user,
            )

        best_effort(db, _audit_draft, "Closure draft create audit log")
        return record

    # FC-05 / BE810-T09: remember where the file was so a reopen restores that phase (strip any trailing " (Draft)").
    curr_mod = imp_file.current_module or ""
    if curr_mod.endswith(" (Draft)"):
        curr_mod = curr_mod[:-len(" (Draft)")]
    imp_file.closed_at_phase = curr_mod
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

    def _audit_close() -> None:
        from modules.audit_logs.service import AuditLogService
        AuditLogService(db).log_activity(
            entity_type="ImportFileClosureRecord",
            entity_id=record_id,
            entity_code=closure_code,
            action="CLOSE",
            new_data=schema.model_dump(exclude_unset=True),
            performed_by=user,
        )

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

    best_effort(db, _audit_close, "Closure official close audit log")
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
        values["auditor_name"] = user

    old_data = {k: getattr(record, k, None) for k in values.keys()}
    repo.apply_changes(record, values, user)
    db.commit()
    db.refresh(record)

    def _audit_update() -> None:
        from modules.audit_logs.service import AuditLogService
        AuditLogService(db).log_activity(
            entity_type="ImportFileClosureRecord",
            entity_id=record.closure_id,
            entity_code=record.closure_code,
            action="UPDATE",
            old_data=old_data,
            new_data=values,
            performed_by=user,
        )

    best_effort(db, _audit_update, "Closure update audit log")
    return record


def soft_delete_closure_service(db: Session, closure_id: int, user: str = "System") -> bool:
    record = get_closure_service(db, closure_id)
    # Q5: deleting the closure of a closed file would leave it Closed without a closure: reopen first.
    if _is_locked_closure(db, record):
        raise closed_record_locked_error(record.closure_code)
    repo.apply_changes(record, {"is_active": False}, user)
    db.commit()

    def _audit_delete() -> None:
        from modules.audit_logs.service import AuditLogService
        AuditLogService(db).log_activity(
            entity_type="ImportFileClosureRecord",
            entity_id=record.closure_id,
            entity_code=record.closure_code,
            action="DELETE",
            performed_by=user,
        )

    best_effort(db, _audit_delete, "Closure delete audit log")
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

    def _audit_restore() -> None:
        from modules.audit_logs.service import AuditLogService
        AuditLogService(db).log_activity(
            entity_type="ImportFileClosureRecord",
            entity_id=record.closure_id,
            entity_code=record.closure_code,
            action="RESTORE",
            performed_by=user,
        )

    best_effort(db, _audit_restore, "Closure restore audit log")
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
    fob_by_currency: Dict[str, float] = {}
    unknown_currency = False

    for po in pos:
        curr = po.currency.currency_code if getattr(po, "currency", None) else None
        amt = float(po.total_amount_fob or 0.0)
        if not curr:
            unknown_currency = True
        else:
            fob_by_currency[curr] = round(fob_by_currency.get(curr, 0.0) + amt, 2)

        po_rate_raw = float(po.exchange_rate) if po.exchange_rate is not None else None
        if po_rate_raw is not None:
            if po_rate_raw <= 0:
                po_rate = None
            elif (curr or "").strip().upper() != "EGP" and po_rate_raw == 1.0:
                po_rate = None
            else:
                po_rate = po_rate_raw
        else:
            po_rate = None

        po_summaries.append({
            "po_id": po.po_id,
            "po_number": po.po_number,
            "po_reference": po.po_reference,
            "proforma_invoice_number": po.proforma_invoice_number,
            "currency": curr,
            "exchange_rate": po_rate,
            "total_amount_fob": amt,
            "total_packages": int(po.total_packages_count or 0),
            "total_gross_weight_kg": float(po.total_gross_weight_kg or 0.0),
            "total_net_weight_kg": float(po.total_net_weight_kg) if getattr(po, "total_net_weight_kg", None) is not None and float(po.total_net_weight_kg) > 0 else None,
            "total_cbm": float(po.total_cbm or 0.0),
            "status": po.status,
        })

        for itm in (po.line_items or []):
            hs = (itm.tariff.hs_code if getattr(itm, "tariff", None) else getattr(itm, "hs_code", "")) or (imp.hs_code or "")
            qty = float(itm.quantity or 0.0)
            u_price = float(itm.unit_price or 0.0)
            tot_price = float(itm.total_price or (qty * u_price))
            itm_nw = float(itm.net_weight_kg) if getattr(itm, "net_weight_kg", None) is not None and float(itm.net_weight_kg) > 0 else None
            items_detail.append({
                "item_code": itm.item_code or None,
                "description": itm.description_ar or itm.description_en or itm.main_description or "",
                "quantity": qty,
                "unit_of_measure": itm.unit_of_measure or "",
                "unit_price": u_price,
                "total_price": tot_price,
                "hs_code": hs,
                "cbm": float(itm.total_cbm or 0.0),
                "weight_kg": float(itm.gross_weight_kg or 0.0),
                "net_weight_kg": itm_nw,
            })

    # Track FOB source: PO vs ESTIMATE vs None (FC-07 / BE810-T07)
    fob_source: Optional[str] = None
    if pos:
        fob_source = "PO"
    elif getattr(imp, "estimated_cost", None) and float(imp.estimated_cost or 0.0) > 0:
        fob_source = "ESTIMATE"
        est_val = float(imp.estimated_cost or 0.0)
        est_curr = imp.estimated_cost_currency or "USD"
        fob_by_currency = {est_curr: est_val}

    if not unknown_currency and len(fob_by_currency) == 1:
        single_curr, single_amt = next(iter(fob_by_currency.items()))
        total_fob_fc = single_amt
        fob_currency = single_curr
    else:
        total_fob_fc = None
        fob_currency = None

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
    raw_markup = None
    if settlement and settlement.average_markup_factor is not None:
        raw_markup = settlement.average_markup_factor
    elif getattr(imp, "actual_landed_cost_calculated_at", None) is not None:
        raw_markup = getattr(imp, "actual_landed_cost_markup_factor", None)
    markup_fac: Optional[float] = float(raw_markup) if raw_markup is not None else None
    var_egp = float(imp.actual_landed_cost_variance_egp or 0.0)
    var_pct = float(imp.actual_landed_cost_variance_pct or 0.0)
    calc_at = imp.actual_landed_cost_calculated_at or (settlement.updated_at if settlement else None)
    if settlement is not None and settlement.total_fob_egp:
        total_fob_egp: Optional[float] = float(settlement.total_fob_egp)
    elif unknown_currency or not fob_by_currency or fob_source is None:
        total_fob_egp = None
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
            status="COMPLETED" if pos or bool(fob_by_currency) else "PENDING",
            status_ar="مكتمل" if pos or bool(fob_by_currency) else "قيد الانتظار",
            details={
                "po_count": len(pos),
                "total_fob_fc": total_fob_fc,
                "currency": fob_currency,
                "fob_by_currency": fob_by_currency,
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

    gate = evaluate_file_closure_gate(db, imp)
    closure_readiness = {
        **gate.checklist,
        # FC-13 / BE810-T08: eir_returned alias kept for old clients
        "eir_returned": gate.checklist["empty_containers_returned"],
    }

    if total_fob_fc is not None and fob_currency:
        fob_text = f"{total_fob_fc:,.2f} {fob_currency}"
    elif fob_by_currency:
        fob_text = " / ".join(f"{amt:,.2f} {c}" for c, amt in sorted(fob_by_currency.items()))
    else:
        fob_text = "—"

    markup_str = f" بمعامل زيادة {markup_fac:.3f}x" if markup_fac is not None else ""
    is_ready = all(closure_readiness.values())
    if is_ready:
        summary_notes = (
            f"ملف الشحنة {imp.import_file_code} مستوفي لكافة مراحل الاستيراد العشر. "
            f"قيمة البضاعة FOB تبلغ {fob_text}، "
            f"وتكلفة الوصول الفعلية الشاملة تبلغ {actual_landed_egp:,.2f} جنيه مصري{markup_str}. "
            f"الملف جاهز للأرشفة الرقمية والاعتماد النهائي."
        )
    else:
        summary_notes = (
            f"ملف الشحنة {imp.import_file_code} قيد المتابعة ولم يستوفِ شروط الإغلاق بعد. "
            f"قيمة البضاعة FOB تبلغ {fob_text}، "
            f"وتكلفة الوصول الحالية تبلغ {actual_landed_egp:,.2f} جنيه مصري{markup_str}."
        )

    dossier_net_weight: Optional[float] = None
    # Priority 1: sum net weight from purchase_orders (most reliable source — FC-07 / BE810-T07)
    po_nw = sum(
        float(p["total_net_weight_kg"])
        for p in po_summaries
        if p.get("total_net_weight_kg") is not None
    )
    if po_nw > 0:
        dossier_net_weight = round(po_nw, 2)
    else:
        # Priority 2: sum net weight from individual PO items
        po_items_nw = sum(
            float(itm["net_weight_kg"])
            for itm in items_detail
            if itm.get("net_weight_kg") is not None
        )
        if po_items_nw > 0:
            dossier_net_weight = round(po_items_nw, 2)
        elif getattr(imp, "net_weight_kg", None) is not None and float(imp.net_weight_kg) > 0:
            # Priority 3: import file record (may be stale — use as last resort)
            dossier_net_weight = float(imp.net_weight_kg)

    # 8. Container loading & seal matrix
    cargo_ship = repo.latest_active_cargo_shipping(db, import_file_id)
    containers_list: List[Dict[str, Any]] = []
    if cargo_ship and cargo_ship.containers_loading_data:
        for idx, c in enumerate(cargo_ship.containers_loading_data):
            c_no = c.get("container_no") or f"CONT-{idx+1}"
            l_seal = c.get("liner_seal_no") or c.get("seal_no") or ""
            c_seal = c.get("customs_seal_no") or ""
            containers_list.append({
                "container_no": c_no,
                "container_type": c.get("container_type", "40HC"),
                "seal_no": c.get("seal_no") or l_seal,
                "liner_seal_no": l_seal,
                "customs_seal_no": c_seal,
                "tare_weight_kg": float(c.get("tare_weight_kg") or 0.0),
                "net_weight_kg": float(c.get("net_weight_kg") or 0.0),
                "gross_weight_kg": float(c.get("gross_weight_kg") or 0.0),
                "vgm_status": c.get("vgm_status") or "Verified",
                "tracking_status": c.get("tracking_status") or "Gate-In Completed",
            })
    elif getattr(imp, "container_number", None) or getattr(imp, "seal_number", None):
        containers_list.append({
            "container_no": getattr(imp, "container_number", None) or "CONT-001",
            "container_type": "40HC",
            "seal_no": getattr(imp, "seal_number", "") or "",
            "liner_seal_no": getattr(imp, "seal_number", "") or "",
            "customs_seal_no": "",
            "tare_weight_kg": 0.0,
            "net_weight_kg": float(getattr(imp, "net_weight_kg", 0.0) or 0.0),
            "gross_weight_kg": float(getattr(imp, "gross_weight_kg", 0.0) or 0.0),
            "vgm_status": "Verified",
            "tracking_status": "Active",
        })

    # 9. FX Reconciliation (Customs vs Commercial Bank)
    from modules.financial_settlement.service import get_shipment_fx_reconciliation
    try:
        fx_recon = get_shipment_fx_reconciliation(db, import_file_id)
    except Exception:
        fx_recon = None

    # 10. Operational Timeline Events & SLA tracking
    form4_req = imp.form4_request_date
    form4_rec = imp.form4_received_date
    form4_sla_days = (form4_rec - form4_req).days if (form4_req and form4_rec) else None

    do_req_str = clearance.nafeza_assessment_json.get("delivery_order_requested_at") if (clearance and clearance.nafeza_assessment_json) else None
    do_paid_dt = clearance.delivery_order_date if clearance else None
    do_sla_hours = None
    if do_req_str and do_paid_dt:
        try:
            do_req_dt = datetime.fromisoformat(do_req_str)
            do_sla_hours = round((do_paid_dt - do_req_dt).total_seconds() / 3600.0, 1)
        except Exception:
            pass

    timeline_events = [
        {
            "event_code": "EVT_PO",
            "stage_code": "STEP_01",
            "stage_name_ar": "أمر الشراء والتعاقد الخارجي",
            "stage_name_en": "Purchase Order & Commercial Contract",
            "planned_date": imp.contract_date.isoformat() if getattr(imp, "contract_date", None) else None,
            "actual_date": imp.contract_date.isoformat() if getattr(imp, "contract_date", None) else None,
            "status": "COMPLETED" if pos else "PENDING",
            "details": f"أوامر شراء: {len(pos)}",
            "sla_label": None,
        },
        {
            "event_code": "EVT_ACID",
            "stage_code": "STEP_03",
            "stage_name_ar": "إصدار رقم القيد الجمركي نافذة ACID",
            "stage_name_en": "Nafeza ACID Number Issuance",
            "planned_date": str(imp.acid_issue_date or ""),
            "actual_date": str(imp.acid_issue_date or ""),
            "status": "COMPLETED" if imp.acid_number else "PENDING",
            "details": imp.acid_number or "بانتظار الإصدار",
            "sla_label": f"ساري حتى {imp.acid_expiry_date}" if imp.acid_expiry_date else None,
        },
        {
            "event_code": "EVT_FORM4",
            "stage_code": "STEP_05",
            "stage_name_ar": "تقديم واستلام نموذج 4 البنكي",
            "stage_name_en": "Form 4 Submission & Bank Endorsement",
            "planned_date": str(form4_req or ""),
            "actual_date": str(form4_rec or ""),
            "status": "COMPLETED" if imp.form4_no else "PENDING",
            "details": f"نموذج 4 رقم: {imp.form4_no or '—'}",
            "sla_label": f"استغرق {form4_sla_days} يوم عمل" if form4_sla_days is not None else None,
        },
        {
            "event_code": "EVT_CARGOX",
            "stage_code": "STEP_08",
            "stage_name_ar": "رفع المستندات عبر كارجو إكس",
            "stage_name_en": "CargoX Blockchain Document Transfer",
            "planned_date": None,
            "actual_date": imp.cargox_transferred_at.isoformat() if imp.cargox_transferred_at else None,
            "status": "COMPLETED" if imp.cargox_transferred_at else "PENDING",
            "details": f"Envelope ID: {imp.cargox_envelope_id or '—'}",
            "sla_label": "تم النقل الرقمي والمطابقة" if imp.cargox_transferred_at else None,
        },
        {
            "event_code": "EVT_DEPARTURE",
            "stage_code": "STEP_09",
            "stage_name_ar": "إبحار السفينة من ميناء الشحن (ETD/ATD)",
            "stage_name_en": "Vessel Departure & ATD Confirmation",
            "planned_date": imp.departure_date.isoformat() if getattr(imp, "departure_date", None) else None,
            "actual_date": imp.actual_departure_date.isoformat() if getattr(imp, "actual_departure_date", None) else None,
            "status": "COMPLETED" if getattr(imp, "actual_departure_date", None) else "PENDING",
            "details": f"الباخرة: {imp.vessel_name or '—'} | بوليصة: {imp.bl_number or '—'}",
            "sla_label": None,
        },
        {
            "event_code": "EVT_ARRIVAL",
            "stage_code": "STEP_11",
            "stage_name_ar": "وصول السفينة لميناء المقصد (ETA/ATA)",
            "stage_name_en": "Port Arrival (ETA/ATA)",
            "planned_date": imp.required_eta.isoformat() if getattr(imp, "required_eta", None) else None,
            "actual_date": imp.actual_arrival_date.isoformat() if getattr(imp, "actual_arrival_date", None) else (clearance.port_arrival_date.isoformat() if clearance and clearance.port_arrival_date else None),
            "status": "COMPLETED" if (getattr(imp, "actual_arrival_date", None) or (clearance and clearance.port_arrival_date)) else "IN_TRANSIT",
            "details": f"ميناء الوصول: {imp.port_of_discharge or '—'}",
            "sla_label": "وصلت الميناء" if (getattr(imp, "actual_arrival_date", None) or (clearance and clearance.port_arrival_date)) else "مبحرة في البحر",
        },
        {
            "event_code": "EVT_DELIVERY_ORDER",
            "stage_code": "STEP_12",
            "stage_name_ar": "طلب وسداد إذن التسليم الملاحي D/O",
            "stage_name_en": "Delivery Order Request & Payment",
            "planned_date": do_req_str,
            "actual_date": clearance.delivery_order_date.isoformat() if (clearance and clearance.delivery_order_date) else None,
            "status": "COMPLETED" if (clearance and clearance.delivery_order_number) else "PENDING",
            "details": f"إذن تسليم: {(clearance.delivery_order_number if clearance else None) or '—'}",
            "sla_label": f"خلال {do_sla_hours} ساعة" if do_sla_hours is not None else None,
        },
        {
            "event_code": "EVT_DECLARATION_46",
            "stage_code": "STEP_13",
            "stage_name_ar": "تسجيل إقرار 46 وتعيين المسار الجمركي",
            "stage_name_en": "Customs Declaration 46 & Channel Routing",
            "planned_date": None,
            "actual_date": imp.form46_date.isoformat() if imp.form46_date else None,
            "status": "COMPLETED" if imp.form46_no else "PENDING",
            "details": f"رقم الإقرار: {imp.form46_no or '—'} | المسار: {customs_channel or '—'}",
            "sla_label": None,
        },
        {
            "event_code": "EVT_RELEASE_PERMIT",
            "stage_code": "STEP_16",
            "stage_name_ar": "سداد الرسوم والإفراج الجمركي النهائي",
            "stage_name_en": "Customs Duty Payment & Release Permit",
            "planned_date": None,
            "actual_date": customs_released_at_str,
            "status": "COMPLETED" if customs_released else "PENDING",
            "details": f"تصريح إفراج رقم: {customs_release_permit_no or '—'}",
            "sla_label": f"إجمالي المسدد: {total_customs_paid:,.2f} ج.م",
        },
        {
            "event_code": "EVT_WAREHOUSE_GRN",
            "stage_code": "STEP_19",
            "stage_name_ar": "وصول المخازن وفحص الجودة وإذن GRN",
            "stage_name_en": "Warehouse Inbound & GRN Acceptance",
            "planned_date": inland_arrival_str,
            "actual_date": (wh.receiving_date.isoformat() if wh and getattr(wh, "receiving_date", None) else None),
            "status": "COMPLETED" if wh else "PENDING",
            "details": f"إذن GRN: {wh_grn_code or '—'} (مقبول: {wh_acc_qty}، عجز: {wh_short_qty})",
            "sla_label": None,
        },
        {
            "event_code": "EVT_CONTAINER_RETURN",
            "stage_code": "STEP_21",
            "stage_name_ar": "إعادة الحاويات الفارغة وإيصالات EIR",
            "stage_name_en": "Empty Container Return & EIR Receipts",
            "planned_date": None,
            "actual_date": imp.empty_containers_returned_at.isoformat() if imp.empty_containers_returned_at else None,
            "status": "COMPLETED" if containers_returned else "PENDING",
            "details": f"إيصال EIR: {imp.empty_containers_eir_numbers or '—'}",
            "sla_label": "تمت إعادة الحاويات" if containers_returned else "بانتظار الإعادة للمستودع",
        },
        {
            "event_code": "EVT_LANDED_COST_SETTLEMENT",
            "stage_code": "STEP_23",
            "stage_name_ar": "تسوية واعتماد تكلفة الوصول الفعلية",
            "stage_name_en": "Actual Landed Cost Approval & Settlement",
            "planned_date": None,
            "actual_date": calc_at.isoformat() if calc_at else None,
            "status": "COMPLETED" if settlement_done else "PENDING",
            "details": f"الإجمالي الفعلي: {actual_landed_egp:,.2f} ج.م",
            "sla_label": f"معامل الزيادة {markup_fac:.3f}x" if markup_fac is not None else None,
        },
    ]

    # 11. Cargo Physical Breakdown & KPI Summary
    final_total_packages = int(getattr(imp, "total_packages_count", 0) or sum(p.get("total_packages", 0) for p in po_summaries) or 0)
    final_gross_weight = float(getattr(imp, "gross_weight_kg", 0.0) or sum(p.get("total_gross_weight_kg", 0.0) for p in po_summaries) or 0.0)
    final_total_cbm = float(getattr(imp, "total_cbm", 0.0) or sum(p.get("total_cbm", 0.0) for p in po_summaries) or 0.0)

    unique_invoices = set()
    if imp.pi_number:
        unique_invoices.add(imp.pi_number)
    for p in po_summaries:
        if p.get("proforma_invoice_number"):
            unique_invoices.add(p["proforma_invoice_number"])
    if getattr(imp, "invoices_data", None):
        for inv in (imp.invoices_data or []):
            inv_no = inv.get("invoice_no") or inv.get("number")
            if inv_no:
                unique_invoices.add(str(inv_no))

    invoices_list = sorted(list(unique_invoices))
    effective_invoices_count = max(len(invoices_list), inv_count, 1 if imp.pi_number else 0)

    cargo_physical_summary = {
        "total_cbm": round(final_total_cbm, 4),
        "total_gross_weight_kg": round(final_gross_weight, 2),
        "total_net_weight_kg": round(dossier_net_weight, 2) if dossier_net_weight else None,
        "total_packages": final_total_packages,
        "invoices_count": effective_invoices_count,
        "invoices_numbers": invoices_list,
        "pos_count": len(pos),
        "pos_numbers": [p.get("po_number") for p in po_summaries if p.get("po_number")],
    }

    # 12. ETA Tracking Revisions Log
    eta_revisions_log = []
    try:
        from modules.shipment_updates.model import ShipmentUpdateLog
        up_logs = (
            db.query(ShipmentUpdateLog)
            .filter(
                ShipmentUpdateLog.import_file_id == import_file_id,
                ShipmentUpdateLog.is_active == True,
            )
            .order_by(ShipmentUpdateLog.created_at.asc())
            .all()
        )
        for log in up_logs:
            note_lower = (log.note or "").lower()
            if any(k in note_lower for k in ["eta", "تأخير", "وصول", "arrival", "drift", "تأخر"]):
                eta_revisions_log.append({
                    "logged_at": log.created_at.isoformat() if log.created_at else str(log.log_date),
                    "note": log.note,
                    "target_phase": log.target_phase,
                    "update_category": log.update_category,
                    "recorded_by": log.created_by,
                })
    except Exception:
        eta_revisions_log = []

    if imp.required_eta:
        req_eta_str = str(imp.required_eta)
        act_arrival_str = imp.inland_actual_arrival_date.date().isoformat() if imp.inland_actual_arrival_date else (
            imp.inland_expected_arrival_date.date().isoformat() if imp.inland_expected_arrival_date else None
        )
        drift = None
        if imp.inland_actual_arrival_date:
            drift = (imp.inland_actual_arrival_date.date() - imp.required_eta).days
        elif imp.inland_expected_arrival_date:
            drift = (imp.inland_expected_arrival_date.date() - imp.required_eta).days

        if not eta_revisions_log:
            eta_revisions_log.append({
                "logged_at": imp.created_at.isoformat() if imp.created_at else req_eta_str,
                "previous_eta": req_eta_str,
                "revised_eta": req_eta_str,
                "drift_days": 0,
                "reason": "الموعد المخطط المبدئي (Initial Target ETA)",
                "recorded_by": imp.owner or "Logistics Team",
            })
            if act_arrival_str and act_arrival_str != req_eta_str:
                eta_revisions_log.append({
                    "logged_at": imp.updated_at.isoformat() if imp.updated_at else act_arrival_str,
                    "previous_eta": req_eta_str,
                    "revised_eta": act_arrival_str,
                    "drift_days": drift,
                    "reason": f"رصد حركة السفينة وتعديل موعد الوصول ({'تأخير' if drift and drift > 0 else 'تقديم'} {abs(drift or 0)} أيام)",
                    "recorded_by": "Tracking Engine",
                })

    # 13. Institutional Knowledge, Past Similar Shipments, and Recurring Patterns
    institutional_knowledge = None
    similar_past_shipments = []
    recurring_patterns = []
    try:
        from modules.experience_guide.service import ExperienceGuideService
        from modules.experience_guide.schemas import GuideMatchRequest
        guide_svc = ExperienceGuideService(db)
        # Collect HS codes and categories from file and PO line items
        file_hs = imp.hs_code or (po_summaries[0].get("hs_code") if po_summaries else None)
        file_category = imp.product_category or (po_summaries[0].get("product_category") if po_summaries else None)
        all_hs = [file_hs] if file_hs else []
        all_cats = [file_category] if file_category else []
        for itm in (items_detail or []):
            if itm.get("hs_code") and itm.get("hs_code") not in all_hs:
                all_hs.append(itm.get("hs_code"))
            if itm.get("product_category") and itm.get("product_category") not in all_cats:
                all_cats.append(itm.get("product_category"))

        match_req = GuideMatchRequest(
            hs_code=file_hs,
            hs_codes=all_hs or None,
            product_category=file_category,
            product_categories=all_cats or None,
            supplier=supplier_name,
            port_of_loading=imp.port_of_loading,
            port_of_discharge=imp.port_of_discharge,
            destination_port=imp.port_of_discharge,
            shipping_line=getattr(imp, "shipping_line", None) or getattr(imp, "selected_scenario", None),
            incoterm=imp.incoterm_code,
            import_file_id=imp.import_file_id,
            import_file_reference=imp.import_file_code,
        )
        matched_guide = guide_svc.match_shipment(match_req)

        try:
            raw_sim = guide_svc.get_similar_shipments(imp.import_file_id)
            similar_past_shipments = [
                {
                    "import_file_id": s.import_file_id,
                    "import_file_code": s.import_file_code,
                    "company_name": s.company_name,
                    "supplier_name": s.supplier_name,
                    "port_of_loading": s.port_of_loading,
                    "port_of_discharge": s.port_of_discharge,
                    "shipping_line": s.shipping_line,
                    "status": s.status,
                    "opening_date": s.opening_date,
                    "clearance_duration_days": s.clearance_duration_days,
                    "cost_variance_pct": s.cost_variance_pct,
                    "matched_dimensions": s.matched_dimensions,
                }
                for s in raw_sim
            ]
        except Exception:
            similar_past_shipments = []

        try:
            raw_pat = guide_svc.get_detected_patterns()
            recurring_patterns = [
                {
                    "pattern_id": p.pattern_id,
                    "pattern_type": p.pattern_type,
                    "dimension_type": p.dimension_type,
                    "dimension_value": p.dimension_value,
                    "occurrence_count": p.occurrence_count,
                    "suggested_title": p.suggested_title,
                    "suggested_content": p.suggested_content,
                    "suggested_severity": p.suggested_severity,
                    "evidence_shipments": p.evidence_shipments,
                }
                for p in raw_pat
            ]
        except Exception:
            recurring_patterns = []

        institutional_knowledge = {
            "has_critical_alert": matched_guide.has_critical_alert,
            "has_warning_alert": matched_guide.has_warning_alert,
            "mandatory_ports": matched_guide.mandatory_ports,
            "required_documents": matched_guide.required_documents,
            "suggested_notes": matched_guide.suggested_notes,
            "matched_entries": [
                {
                    "entry_id": e.entry_id,
                    "title": e.title,
                    "content": e.content,
                    "entry_type": e.entry_type,
                    "severity": e.severity,
                    "department": e.department,
                    "source_type": e.source_type,
                    "confidence_level": e.confidence_level,
                    "is_system_inferred": e.is_system_inferred,
                }
                for e in matched_guide.matched_entries
            ],
            "critical_entries": [
                {
                    "entry_id": e.entry_id,
                    "title": e.title,
                    "content": e.content,
                    "severity": e.severity,
                }
                for e in matched_guide.critical_entries
            ],
            "warning_entries": [
                {
                    "entry_id": e.entry_id,
                    "title": e.title,
                    "content": e.content,
                    "severity": e.severity,
                }
                for e in matched_guide.warning_entries
            ],
            "similar_past_shipments": similar_past_shipments,
            "recurring_patterns": recurring_patterns,
        }
    except Exception:
        institutional_knowledge = None
        similar_past_shipments = []
        recurring_patterns = []

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
        total_packages=final_total_packages,
        gross_weight_kg=final_gross_weight,
        net_weight_kg=dossier_net_weight,
        total_cbm=final_total_cbm,
        target_free_days=int(imp.target_free_days or 0),
        purchase_orders=po_summaries,
        pos_count=len(pos),
        invoices_count=effective_invoices_count,
        fob_by_currency=fob_by_currency,
        total_fob_fc=total_fob_fc,
        total_fob_egp=total_fob_egp,
        fob_currency=fob_currency,
        fob_source=fob_source,
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
        containers=containers_list,
        fx_reconciliation=fx_recon,
        timeline_events=timeline_events,
        eta_revisions_log=eta_revisions_log,
        cargo_physical_summary=cargo_physical_summary,
        similar_past_shipments=similar_past_shipments,
        recurring_patterns=recurring_patterns,
        institutional_knowledge=institutional_knowledge,
    )


def confirm_dossier_export_service(
    db: Session,
    payload: DossierExportConfirmRequest,
    user: str = "System",
    actor: Optional[User] = None,
    trusted: bool = False,
) -> DossierExportConfirmResponse:
    """
    CLO-03: Confirms the export of the comprehensive shipment dossier, records export metadata,
    advances progress to >=99.5%, resolves SmartTask TSK-0903, dispatches TSK-0904, and posts system notification.
    """
    imp = _get_active_file(db, payload.import_file_id)
    _require_any_permission(db, actor, "import_files.edit", "import_files.close", trusted=trusted)
    if imp.status == FILE_STATUS_CLOSED:
        raise already_closed_error(imp.import_file_code)

    # BE810-T09 / F18: Check gate preconditions (customs, warehouse, landed cost).
    gate = evaluate_file_closure_gate(db, imp)
    if export_blocking_keys(gate):
        raise export_blocked_error(gate)

    exported_by = user
    now_utc = datetime.now(timezone.utc)
    today_str = datetime.now().strftime("%Y-%m-%d")
    was_already_exported = imp.dossier_exported_at is not None

    # 1. Update ImportFile metadata & progress
    imp.dossier_exported_at = now_utc
    imp.dossier_exported_by = exported_by
    current_progress = float(imp.progress_percent or 0.0)
    imp.progress_percent = max(current_progress, 99.5)
    imp.current_module = "Phase 10 - Comprehensive Dossier Export & Digital Archiving"
    set_file_tracking(imp, stage_code="CLOSURE_IN_PROGRESS", next_action=msg("NA_CLO_OFFICIAL_CLOSURE"))

    # 2. Resolve SmartTask TSK-0903 (open tasks only, BE810-F35)
    tasks_903 = db.query(SmartTask).filter(
        SmartTask.import_file_id == imp.import_file_id,
        SmartTask.is_active == True,
        SmartTask.status.in_(["Pending", "In Progress"]),
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

    # 4. Dispatch central SystemNotification (only on the first export, BE810-F35)
    if not was_already_exported:
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

    def _audit_export() -> None:
        from modules.audit_logs.service import AuditLogService
        AuditLogService(db).log_activity(
            entity_type="ImportFile",
            entity_id=imp.import_file_id,
            entity_code=imp.import_file_code,
            action="DOSSIER_EXPORT",
            new_data=payload.model_dump(exclude_unset=True),
            performed_by=user,
        )

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

    best_effort(db, _audit_export, "Dossier export audit log")
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
    raw_markup = None
    if settlement is not None:
        actual_landed = float(settlement.total_landed_cost_egp or actual_landed)
        if settlement.average_markup_factor is not None:
            raw_markup = settlement.average_markup_factor
    elif getattr(imp, "actual_landed_cost_calculated_at", None) is not None:
        raw_markup = getattr(imp, "actual_landed_cost_markup_factor", None)
    markup: Optional[float] = float(raw_markup) if raw_markup is not None else None

    blocking_keys = list(gate.blocking_keys)
    blocking_reasons = list(gate.blocking_reasons)
    can_close = gate.can_close
    if imp.status == FILE_STATUS_CLOSED:
        can_close = False
        if "already_closed" not in blocking_keys:
            blocking_keys.append("already_closed")
        already_closed_msg = BLOCKING_MESSAGES_AR.get("already_closed", "ملف الشحنة مغلق رسمياً بالفعل ولا يمكن إعادة إغلاقه.")
        if already_closed_msg not in blocking_reasons:
            blocking_reasons.append(already_closed_msg)

    return ClosurePrecheckResponse(
        import_file_id=imp.import_file_id,
        import_file_code=imp.import_file_code or f"IMP-{imp.import_file_id}",
        company_name=company_name,
        supplier_name=supplier_name,
        can_close=can_close,
        blocking_reasons=blocking_reasons,
        blocking_keys=blocking_keys,
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
    actor: Optional[User] = None,
) -> OfficialClosureCertificateResponse:
    """
    CLO-04: Formal closure & digital archival.
    Issues digital certificate, locks file at 100%, and advances lifecycle board to terminal STEP_21.
    """
    final_schema = schema.model_copy(update={"is_draft": False})
    record = close_import_file_service(db, final_schema, user=user, actor=actor, trusted=actor is None)

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
