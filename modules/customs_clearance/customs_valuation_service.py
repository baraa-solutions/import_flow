"""
Customs Valuation and Final Duty Assessment Service (CL-02 & EPIC-CUST-VAL).

Handles:
- Commercial vs Assessed CIF valuation comparison
- Customs valuation uplift calculation & indicative pricing rationale
- Duty components itemization (7 components) and actual claim override
- Duty variance calculation vs preliminary estimate
- Final duty assessment registration and stage progression
"""
from datetime import datetime
from typing import Any, Dict, Optional, Tuple

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.common.file_tracking import set_file_tracking
from modules.common.system_messages import msg
from modules.import_files.model import ImportFile

from . import repository as repo
from .model import CustomsClearanceRecord
from .schemas import FinalDutyAssessmentSubmit
from .validators import DUTY_COMPONENT_FIELDS, coded_error, validate_settlement_open

SYSTEM_USER = "System"


def _svc():
    """Lazy resolver for shared customs clearance service utilities to prevent circular imports."""
    from . import service
    return service


def calculate_valuation_uplift(
    assessed_cif: float,
    commercial_cif: float,
    requested_uplift: Optional[float] = None,
    is_uplift_flag: Optional[bool] = None,
) -> Tuple[bool, float]:
    """
    EPIC-CUST-VAL: Calculate whether customs valuation is uplifted and the uplift amount in EGP.

    When customs assessed CIF exceeds commercial invoice CIF (or is_valuation_uplifted is explicitly
    requested), the valuation is marked as uplifted and the difference (or specified amount) is recorded.
    """
    is_uplifted = bool(
        is_uplift_flag
        or (assessed_cif > commercial_cif and commercial_cif > 0.0)
    )
    if is_uplifted:
        diff = assessed_cif - commercial_cif
        uplift_amount = float(
            requested_uplift
            if requested_uplift is not None and requested_uplift > 0
            else max(0.0, round(diff, 2))
        )
    else:
        uplift_amount = 0.0
    return is_uplifted, uplift_amount


def calculate_duty_variance(actual_total: float, estimated_total: float) -> Tuple[float, float]:
    """Calculate duty variance amount and percentage (actual vs estimated)."""
    if estimated_total > 0:
        var_amount = round(actual_total - estimated_total, 2)
        var_pct = round((var_amount / estimated_total) * 100, 2)
        return var_amount, var_pct
    return 0.0, 0.0


def compute_duty_components(
    payload: FinalDutyAssessmentSubmit,
    existing_record: CustomsClearanceRecord,
) -> Tuple[Dict[str, float], float, float]:
    """
    Compute the 7 itemized duty components, the computed sum, and the actual total.

    A component the payload does not send keeps its stored value (exclude_unset semantics).
    If actual_duty_total is specified and > 0, it is used as the claim override total.
    """
    sent = payload.model_fields_set
    components = {
        name: float((getattr(payload, name) if name in sent else getattr(existing_record, name)) or 0.0)
        for name in DUTY_COMPONENT_FIELDS
    }
    computed_total = round(sum(components[name] for name in DUTY_COMPONENT_FIELDS), 2)
    if payload.actual_duty_total is not None and payload.actual_duty_total > 0:
        actual_total = round(float(payload.actual_duty_total), 2)
    else:
        actual_total = computed_total
    return components, computed_total, actual_total


def assess_final_customs_duties_service(
    db: Session,
    payload: FinalDutyAssessmentSubmit,
    user: str = SYSTEM_USER,
) -> CustomsClearanceRecord:
    """CL-02: itemised duties, total (7 components, or the claim override), variance vs the estimate. Needs the
    file's clearance record with a registered declaration 46 (409). Then tasks, notification, STEP_15 advance."""
    svc = _svc()
    svc._require_import_file(db, payload.import_file_id)
    validate_settlement_open(db, payload.import_file_id, "الرسوم الجمركية النهائية")

    claim_no = (payload.nafeza_claim_number or "").strip()
    if len(claim_no) < 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="رقم المطالبة الجمركية بنظام نافذة يجب ألا يقل عن 3 أحرف/أرقام.",
        )

    existing = repo.get_active_clearance_for_file(db, payload.import_file_id)
    if existing is None or not (existing.declaration_46_no or "").strip():
        raise coded_error(
            status.HTTP_409_CONFLICT,
            "CC_ASSESS_REQUIRES_DECLARATION_46",
            "لا يمكن احتساب الرسوم الجمركية النهائية قبل قيد الإقرار الجمركي نموذج 46 (CS-03).",
            import_file_id=payload.import_file_id,
        )

    components, computed_total, actual_total = compute_duty_components(payload, existing)
    claim_dt = payload.nafeza_claim_date or svc._now()

    def write():
        imp_file = svc._require_import_file(db, payload.import_file_id)
        record = repo.get_active_clearance_for_file(db, payload.import_file_id)
        est_total = float(record.revised_total_duties_egp or record.estimated_duty_total or 0.0)
        var_amount, var_pct = calculate_duty_variance(actual_total, est_total)

        # EPIC-CUST-VAL: Commercial CIF vs Customs Assessed CIF calculation
        assessed_cif = float(
            payload.customs_assessed_cif_egp
            if payload.customs_assessed_cif_egp is not None
            else (payload.cif_base_amount or record.customs_assessed_cif_egp or record.cif_base_amount or 0.0)
        )
        commercial_cif = float(
            payload.commercial_cif_base_amount
            if payload.commercial_cif_base_amount is not None
            else (record.commercial_cif_base_amount or assessed_cif)
        )
        record.commercial_cif_base_amount = commercial_cif
        record.customs_assessed_cif_egp = assessed_cif
        if payload.customs_assessed_cif_usd is not None:
            record.customs_assessed_cif_usd = float(payload.customs_assessed_cif_usd)
        elif payload.customs_exchange_rate and float(payload.customs_exchange_rate) > 0:
            record.customs_assessed_cif_usd = round(assessed_cif / float(payload.customs_exchange_rate), 2)

        # Customs duties & taxes are calculated on the Assessed CIF
        record.cif_base_amount = assessed_cif

        is_uplifted, uplift_amount = calculate_valuation_uplift(
            assessed_cif=assessed_cif,
            commercial_cif=commercial_cif,
            requested_uplift=payload.valuation_uplift_amount_egp,
            is_uplift_flag=payload.is_valuation_uplifted,
        )
        record.is_valuation_uplifted = is_uplifted
        record.valuation_uplift_amount_egp = uplift_amount

        if payload.valuation_uplift_reason:
            record.valuation_uplift_reason = payload.valuation_uplift_reason
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
        svc._touch(record, user)

        imp_file.current_module = "Phase 7 - Customs Clearance & Duty Assessment"
        set_file_tracking(imp_file, stage_code="CUSTOMS_DUTY_ASSESSED", next_action=msg("NA_CL_RECORD_DUTY_PAYMENT"))
        svc._raise_progress(imp_file, 90.0)
        svc._touch(imp_file, user)
        return record, svc._file_label(imp_file)

    record, file_label = svc._commit_write(db, write)
    assess_msg = msg("CC_DUTIES_ASSESSED", import_file_code=file_label, claim_no=claim_no, total_amount=svc._money(actual_total))
    svc._step_follow_ups(
        db, "CL-02", payload.import_file_id, user=user,
        complete_types=("FINAL_DUTY_ASSESSMENT", "CL-02"), note_msg=assess_msg,
        dispatch=dict(
            existing_types=("CUSTOMS_DUTY_PAYMENT", "CL-03"),
            task_msg=msg("CC_TASK_DUTY_PAYMENT", import_file_code=file_label, claim_no=claim_no,
                         total_amount=svc._money(actual_total)),
            task_type="CUSTOMS_DUTY_PAYMENT", priority="Urgent", assigned_user="Customs Broker", due_in_days=2,
        ),
        lifecycle=dict(
            completed_step_code="STEP_15", target_step_codes=["STEP_16", "STEP_17"], notes_msg=assess_msg,
            assigned_user="Customs Broker", next_action_msg=msg("NA_CL_RECORD_DUTY_PAYMENT"), min_progress_percent=90.0,
        ),
    )
    db.refresh(record)
    return record
