import logging
import math
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from typing import List, Optional, Dict, Any, Tuple
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from .model import LandedCostSettlementRecord
from .schemas import (
    FinancialSettlementCreate,
    FinancialSettlementUpdate,
    ExpenseInvoiceSchema,
    ItemLandedCostSchema,
    AggregatedInvoiceItemSchema,
    InvoicesPartySummary,
    InvoicesAggregationResponse,
    ConfirmInvoicesSettlementRequest,
    ConfirmInvoicesSettlementResponse,
    ActualLandedCostCategoryBreakdown,
    ActualLandedCostItemLine,
    ActualLandedCostCalculationRequest,
    ActualLandedCostCalculationResponse,
    ApproveActualLandedCostRequest,
    ApproveActualLandedCostResponse,
    EstimatedLandedCostSimulationRequest,
    EstimatedLandedCostSimulationResponse,
    EstimatedLandedCostItemBreakdown,
    EstimatedLandedCostExpenseItem,
    SettlementMessage,
    RECALC_ADJUSTMENT_PREFIX,
    CustomsDutyComponentSchema,
)
from .repository import (
    add_with_new_code,
    apply_settlement_update,
    build_settlement,
    get_settlement_by_id,
    get_settlement_by_import_file_id,
    list_settlements,
    soft_delete_settlement,
    restore_settlement,
    get_effective_tax_rate,
)
from .model import (
    WHT_CLEARANCE_SERVICES,
    WHT_TRANSPORT_SERVICES,
    CLEARANCE_CATEGORY_BUCKET,
)
from .validators import (
    SETTLEMENT_ACTUAL_FOB_MISSING,
    SETTLEMENT_DUPLICATE_ACTIVE,
    SETTLEMENT_FX_RATE_MISSING,
    coded_error,
    ensure_cost_not_approved,
    ensure_file_open,
    ensure_invoices_not_settled,
    ensure_invoices_settlement_ready,
    ensure_invoices_settled,
    ensure_no_manual_rows,
    ensure_no_other_active_settlement,
    ensure_no_client_adjustment_rows,
    ensure_settlement_editable,
    fx_rate_missing_error,
    currency_missing_error,
    validate_expense_invoice,
    validate_items_allocation_readiness,
)
from modules.import_files.model import ImportFile
from modules.common import enum_codes
from modules.common.errors import best_effort
from modules.common.system_messages import msg, render_en
from modules.common.system_parameters import get_float_parameter
from modules.common.validators import require_active
from modules.common.file_tracking import set_file_tracking

logger = logging.getLogger(__name__)

IMPORT_FILE_LABEL_AR = "ملف الشحنة"

# Message codes emitted in ``messages[]`` (plain {code, params} until registered in the shared catalog).
SETTLEMENT_LINE_NO_HS = "SETTLEMENT_LINE_NO_HS"
SETTLEMENT_LINE_ZERO_VALUE = "SETTLEMENT_LINE_ZERO_VALUE"
PAYMENT_STATUS_UNKNOWN = "PAYMENT_STATUS_UNKNOWN"
ESTIMATE_UNAVAILABLE = "ESTIMATE_UNAVAILABLE"
SETTLEMENT_UNPAID_INVOICE = "SETTLEMENT_UNPAID_INVOICE"
WHT_RATE_MISSING_WARNING = "WHT_RATE_MISSING_WARNING"
ALLOCATION_BASIS_INCOMPLETE = "ALLOCATION_BASIS_INCOMPLETE"
ACTUAL_SOURCE_MISSING = "ACTUAL_SOURCE_MISSING"

# PL-08 estimate constants, configurable through system_parameters (FS-07). The defaults are the former literals,
# so the estimate is unchanged while no parameter row exists.
PARAM_DEEMED_FREIGHT_PCT = "settlement.deemed_freight_pct"
PARAM_DEEMED_INSURANCE_PCT = "settlement.deemed_insurance_pct"
PARAM_DEFAULT_CLEARANCE_EGP = "settlement.default_clearance_egp"
PARAM_DEFAULT_PORT_HANDLING_EGP = "settlement.default_port_handling_egp"
PARAM_DEFAULT_INLAND_TRANSPORT_EGP = "settlement.default_inland_transport_egp"
PARAM_DEFAULT_BANK_FEES_EGP = "settlement.default_bank_fees_egp"
PARAM_DEFAULT_OTHER_EXPENSES_EGP = "settlement.default_other_expenses_egp"
PARAM_VARIANCE_UNIT_TOLERANCE_EGP = "settlement.variance_unit_tolerance_egp"
PARAM_VARIANCE_FILE_TOLERANCE_EGP = "settlement.variance_file_tolerance_egp"
DEFAULT_VARIANCE_UNIT_TOLERANCE_EGP: float = 0.05
DEFAULT_VARIANCE_FILE_TOLERANCE_EGP: float = 100.0

ESTIMATE_PARAMETER_DEFAULTS: Dict[str, float] = {
    PARAM_DEEMED_FREIGHT_PCT: 2.0,
    PARAM_DEEMED_INSURANCE_PCT: 2.5,
    PARAM_DEFAULT_CLEARANCE_EGP: 4500.0,
    PARAM_DEFAULT_PORT_HANDLING_EGP: 5000.0,
    PARAM_DEFAULT_INLAND_TRANSPORT_EGP: 7500.0,
    PARAM_DEFAULT_BANK_FEES_EGP: 2500.0,
    PARAM_DEFAULT_OTHER_EXPENSES_EGP: 2000.0,
}



from .landed_cost_engine_service import (
    _message, actual_expense_bucket, settlement_expense_field, recalc_adjustment_invoice_no,
    _counts_for_field, settlement_field_total, apply_settlement_field_total, allocation_ratios,
    row_amount_egp, calculate_landed_cost_engine, _unit_qty, is_seller_paid_expense,
    SettlementFx, _as_date, purchase_order_rate_to_egp, _purchase_orders_of_file,
    _line_item_name, file_po_line_shares, _items_from_purchase_orders,
    _resolve_client_expense_rates, _derive_expense_egp, _validate_client_expenses,
    _duty_row, _customs_duty_rows, _recalculate_in_place, recalculate_settlement_totals,
    _audit, _audit_import_file, _settlement_snapshot_dict, build_initial_settlement
)

def create_settlement_service(
    db: Session, schema: FinancialSettlementCreate, actor: str = "System"
) -> LandedCostSettlementRecord:
    imp_file = require_active(db, ImportFile, schema.import_file_id, IMPORT_FILE_LABEL_AR, status_code=404)
    ensure_file_open(imp_file)

    existing = get_settlement_by_import_file_id(db, schema.import_file_id)
    if existing:
        raise coded_error(
            status.HTTP_409_CONFLICT,
            SETTLEMENT_DUPLICATE_ACTIVE,
            f"يوجد بالفعل تسوية مالية وتكلفة وصول (Landed Cost) مسجلة لهذا الملف الاستيرادي (كود التسوية: {existing.settlement_code}). يرجى مراجعة وتحديث التسوية الحالية بدلاً من إنشاء تسوية مكررة.",
            settlement_code=existing.settlement_code,
        )

    expenses_in = [e if isinstance(e, dict) else e.model_dump() for e in (schema.expense_invoices or [])]
    items_in = [i if isinstance(i, dict) else i.model_dump() for i in (schema.item_landed_costs or [])]

    record = build_initial_settlement(
        db,
        imp_file,
        actor=actor,
        expenses_in=expenses_in,
        items_in=items_in,
        incoterm=schema.incoterm_code,
        notes=schema.notes,
    )
    add_with_new_code(db, record)

    # Update Import File progress
    imp_file.current_module = "Phase 9 - Financial Settlement & Landed Cost Engine"
    if (imp_file.progress_percent or 0.0) < 95.0:
        imp_file.progress_percent = 95.0
    set_file_tracking(
        imp_file,
        stage_code="LANDED_COST_CALCULATED",
        next_action=msg("NA_REVIEW_SETTLEMENT_AND_CLOSE"),
    )
    saved_messages = list(getattr(record, "messages", []) or [])
    incoterm = record.incoterm_code
    db.commit()
    db.refresh(record)
    record.messages = saved_messages
    code = record.settlement_code
    audit_data = {
        "import_file_id": schema.import_file_id,
        "incoterm_code": incoterm,
        "expense_invoices": expenses_in,
        "item_landed_costs": items_in,
        "notes": schema.notes,
    }

    # Follow-up steps never undo the saved settlement (FS-13).
    from modules.lifecycle_board.service import advance_lifecycle_step_service
    best_effort(
        db,
        lambda: advance_lifecycle_step_service(
            db=db,
            import_file_id=schema.import_file_id,
            completed_step_code="STEP_19",
            target_step_codes=["STEP_20"],
            notes_msg=msg("FS_SETTLEMENT_CREATED", settlement_code=code),
            next_action_msg=msg("NA_REVIEW_SETTLEMENT_AND_CLOSE"),
            stage_code="LANDED_COST_CALCULATED",
            assigned_user="Finance Manager",
        ),
        "Lifecycle advance STEP_19->STEP_20",
    )
    best_effort(db, _audit, "AuditLog for LandedCostSettlementRecord create", db, record, "CREATE", actor, new_data=audit_data)
    db.refresh(record)
    return record


def recalculate_settlement_service(db: Session, settlement_id: int, actor: str = "System") -> LandedCostSettlementRecord:
    record = get_settlement_by_id(db, settlement_id)
    if not record:
        raise HTTPException(status_code=404, detail="سجل التسوية المالية غير موجود.")
    ensure_file_open(record.import_file or db.query(ImportFile).filter(ImportFile.import_file_id == record.import_file_id).first())
    ensure_settlement_editable(record)
    old_data = _settlement_snapshot_dict(record)
    _recalculate_in_place(record, actor)
    db.commit()
    db.refresh(record)
    new_data = _settlement_snapshot_dict(record)
    best_effort(
        db, _audit, "AuditLog for LandedCostSettlementRecord recalculate", db, record, "RECALCULATE", actor,
        new_data=new_data, old_data=old_data,
    )
    return record


# Columns that may not be set to NULL through PUT.
_NON_NULL_UPDATE_FIELDS = ("incoterm_code", "status", "expense_invoices", "item_landed_costs")


def update_settlement_service(
    db: Session, settlement_id: int, schema: FinancialSettlementUpdate, actor: str = "System"
) -> LandedCostSettlementRecord:
    existing = get_settlement_by_id(db, settlement_id)
    if not existing:
        raise HTTPException(status_code=404, detail="سجل التسوية المالية غير موجود.")
    ensure_file_open(existing.import_file or db.query(ImportFile).filter(ImportFile.import_file_id == existing.import_file_id).first())
    ensure_settlement_editable(existing)

    update_data = schema.model_dump(exclude_unset=True)
    update_data.pop("accountant_name", None)  # ignored: the acting user is recorded in updated_by
    for key in _NON_NULL_UPDATE_FIELDS:
        if key in update_data and update_data[key] is None:
            del update_data[key]
    if update_data.get("expense_invoices") is not None:
        ensure_no_client_adjustment_rows(update_data["expense_invoices"], stored_rows=existing.expense_invoices or [])
        _resolve_client_expense_rates(update_data["expense_invoices"], SettlementFx(db, "commercial"))
        _derive_expense_egp(update_data["expense_invoices"])
        _validate_client_expenses(update_data["expense_invoices"])
    old_data = {k: getattr(existing, k, None) for k in update_data.keys()}

    apply_settlement_update(db, existing, update_data, actor)
    _recalculate_in_place(existing, actor)
    db.commit()
    db.refresh(existing)

    best_effort(
        db, _audit, "AuditLog for LandedCostSettlementRecord update", db, existing, "UPDATE", actor,
        new_data=update_data, old_data=old_data,
    )
    db.refresh(existing)
    return existing

def get_settlement_service(db: Session, settlement_id: int) -> LandedCostSettlementRecord:
    record = get_settlement_by_id(db, settlement_id)
    if not record:
        raise HTTPException(status_code=404, detail="سجل التسوية المالية غير موجود.")
    return record

def list_settlements_service(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
    skip: int = 0,
    limit: Optional[int] = None,
) -> List[LandedCostSettlementRecord]:
    return list_settlements(
        db,
        include_inactive=include_inactive,
        import_file_id=import_file_id,
        status=status,
        search=search,
        skip=skip,
        limit=limit,
    )

def soft_delete_settlement_service(db: Session, settlement_id: int, actor: str = "System") -> bool:
    record = get_settlement_service(db, settlement_id)
    ensure_file_open(record.import_file or db.query(ImportFile).filter(ImportFile.import_file_id == record.import_file_id).first())
    ensure_settlement_editable(record)
    old_data = _settlement_snapshot_dict(record)
    soft_delete_settlement(db, record, actor)
    db.commit()
    new_data = _settlement_snapshot_dict(record)
    best_effort(
        db, _audit, "AuditLog for LandedCostSettlementRecord delete", db, record, "SOFT_DELETE", actor,
        new_data=new_data, old_data=old_data,
    )
    return True

def restore_settlement_service(db: Session, settlement_id: int, actor: str = "System") -> LandedCostSettlementRecord:
    record = get_settlement_by_id(db, settlement_id, include_inactive=True)
    if not record:
        raise HTTPException(status_code=404, detail=f"سجل التسوية التكليفية رقم {settlement_id} غير موجود.")
    ensure_file_open(record.import_file or db.query(ImportFile).filter(ImportFile.import_file_id == record.import_file_id).first())
    if not record.is_active:
        ensure_no_other_active_settlement(get_settlement_by_import_file_id(db, record.import_file_id), settlement_id)
    old_data = _settlement_snapshot_dict(record)
    restore_settlement(db, record, actor)
    db.commit()
    db.refresh(record)
    new_data = _settlement_snapshot_dict(record)
    best_effort(
        db, _audit, "AuditLog for LandedCostSettlementRecord restore", db, record, "RESTORE", actor,
        new_data=new_data, old_data=old_data,
    )
    return record


# ==============================================================================
# PL-08: Estimated Landed Cost Simulation Service
# ==============================================================================

