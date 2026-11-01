"""
CS-03 Customs Declaration 46 and CL-01 Customs Inspection & Sampling services.

Handles:
- Registration and validation of Customs Declaration Form 46 (نموذج 46 ك.م)
- Commercial vs Assessed CIF valuation capture on Form 46
- Registration of Joint Customs Inspection, Sampling (محضر سحب عينات), and Regulatory Bodies (GOEIC, etc.)
- Downstream task creation and lifecycle step progression (STEP_13 -> STEP_14 -> STEP_15)
"""
from datetime import datetime
from typing import Optional, Any

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.common import enum_codes
from modules.common.file_tracking import set_file_tracking
from modules.common.system_messages import msg
from modules.import_files.model import ImportFile

from . import repository as repo
from .model import CustomsClearanceRecord
from .schemas import (
    CustomsDeclaration46Submit,
    CustomsInspectionSamplingSubmit,
    RevisedEstimateSubmit,
)

SYSTEM_USER = "System"


def _svc():
    """Lazy resolver for shared customs clearance service utilities to prevent circular imports."""
    from . import service
    return service


def validate_declaration_46_payload(payload: CustomsDeclaration46Submit) -> None:
    """Validate declaration 46 submission payload."""
    dec_no = (payload.declaration_46_no or "").strip()
    if len(dec_no) < 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="رقم الإقرار الجمركي ونموذج 46 ك.م يجب ألا يقل عن 3 أحرف/أرقام.",
        )


def validate_customs_inspection_payload(payload: CustomsInspectionSamplingSubmit) -> None:
    """Validate customs inspection & sampling submission payload."""
    sampling_rec = (payload.sampling_record_no or "").strip()
    if payload.is_sample_drawn:
        if not sampling_rec:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="رقم محضر سحب العينات مطلوب عند سحب عينات.",
            )
        if len(sampling_rec) < 3:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="رقم محضر سحب العينات يجب ألا يقل عن 3 أحرف/أرقام.",
            )


def apply_declaration_46_valuation_fields(
    record: CustomsClearanceRecord,
    payload: CustomsDeclaration46Submit,
) -> None:
    """EPIC-CUST-VAL: Customs Valuation Uplift & Commercial vs Assessed CIF for Form 46."""
    if payload.commercial_cif_base_amount is not None:
        record.commercial_cif_base_amount = float(payload.commercial_cif_base_amount)
    if payload.customs_assessed_cif_egp is not None:
        record.customs_assessed_cif_egp = float(payload.customs_assessed_cif_egp)
        record.cif_base_amount = float(payload.customs_assessed_cif_egp)
    if payload.customs_assessed_cif_usd is not None:
        record.customs_assessed_cif_usd = float(payload.customs_assessed_cif_usd)
    if payload.is_valuation_uplifted is not None:
        record.is_valuation_uplifted = bool(payload.is_valuation_uplifted)
    if payload.valuation_uplift_amount_egp is not None:
        record.valuation_uplift_amount_egp = float(payload.valuation_uplift_amount_egp)
    elif (record.customs_assessed_cif_egp or 0.0) > (record.commercial_cif_base_amount or 0.0) > 0.0:
        record.valuation_uplift_amount_egp = round(
            (record.customs_assessed_cif_egp or 0.0) - (record.commercial_cif_base_amount or 0.0), 2
        )
        record.is_valuation_uplifted = True
    if payload.valuation_uplift_reason is not None:
        record.valuation_uplift_reason = payload.valuation_uplift_reason


REVISED_ESTIMATE_FIELDS = (
    "revised_exchange_rate",
    "revised_freight_egp",
    "revised_insurance_egp",
    "revised_unloading_egp",
    "revised_duty_rate",
    "revised_extra_fees_egp",
    "revised_cif_egp",
    "revised_import_duty_egp",
    "revised_vat_egp",
    "revised_total_duties_egp",
    "revised_has_exemption",
    "revised_estimate_date",
    "revised_estimate_by",
    "revised_estimate_notes",
)


def apply_revised_estimate_fields(
    record: CustomsClearanceRecord,
    payload: Any,
    db: Optional[Session] = None,
) -> None:
    """
    Applies revised estimate fields (التقدير المحدّث للرسوم) from payload to record.
    Calculates variance and records duty_variance_reason when variance is present.
    """
    has_any_revised = False
    for field in REVISED_ESTIMATE_FIELDS:
        val = getattr(payload, field, None)
        if val is not None:
            has_any_revised = True
            if field in ("revised_has_exemption",):
                setattr(record, field, bool(val))
            elif field in ("revised_estimate_by", "revised_estimate_notes"):
                setattr(record, field, str(val))
            elif field in ("revised_estimate_date",):
                setattr(record, field, val)
            else:
                setattr(record, field, float(val))

    if has_any_revised and not record.revised_estimate_date:
        svc = _svc()
        record.revised_estimate_date = getattr(payload, "revised_estimate_date", None) or svc._now()

    # If revised_total_duties_egp is set, calculate variance vs preliminary estimate or actuals
    revised_total = getattr(record, "revised_total_duties_egp", None)
    if revised_total is not None and float(revised_total) > 0:
        est_total = float(record.estimated_duty_total or 0.0)
        if est_total > 0:
            var_amt = round(float(revised_total) - est_total, 2)
            var_pct = round((var_amt / est_total) * 100, 2)
            record.duty_variance_amount = var_amt
            record.duty_variance_percentage = var_pct
        elif float(record.actual_duty_total or 0.0) > 0:
            act_total = float(record.actual_duty_total)
            var_amt = round(act_total - float(revised_total), 2)
            var_pct = round((var_amt / float(revised_total)) * 100, 2)
            record.duty_variance_amount = var_amt
            record.duty_variance_percentage = var_pct

    # Save or update duty_variance_reason if provided
    variance_reason = getattr(payload, "duty_variance_reason", None)
    if variance_reason is not None and str(variance_reason).strip():
        record.duty_variance_reason = str(variance_reason).strip()


def register_customs_declaration_46_service(
    db: Session,
    payload: CustomsDeclaration46Submit,
    user: str = SYSTEM_USER,
) -> CustomsClearanceRecord:
    """CS-03: Form 46 on the record, ImportFile sync (form46_*, progress >= 86%), then tasks, notification and
    the STEP_13 -> STEP_14/15 board advance."""
    svc = _svc()
    svc._require_import_file(db, payload.import_file_id)
    validate_declaration_46_payload(payload)

    dec_no = payload.declaration_46_no.strip()
    dec_dt = payload.declaration_46_date or svc._now()
    channel = payload.channel_type.strip()
    office = payload.customs_office_name.strip()
    reg_bodies = enum_codes.normalize_list(enum_codes.REGULATORY_BODY, payload.regulatory_bodies) or []
    tariff_count = payload.customs_tariff_items_count if payload.customs_tariff_items_count and payload.customs_tariff_items_count > 0 else 1
    mts_cert = payload.mts_certificate_number.strip() if payload.mts_certificate_number else None

    def write():
        imp_file = svc._require_import_file(db, payload.import_file_id)
        record = svc._find_or_new_record(db, imp_file, user, status="Under Customs Clearance")
        record.declaration_46_no = dec_no
        record.declaration_46_date = dec_dt
        record.customs_office_name = office
        record.channel_type = channel
        record.regulatory_bodies = reg_bodies
        if mts_cert:
            record.mts_certificate_number = mts_cert
        record.customs_tariff_items_count = tariff_count

        apply_declaration_46_valuation_fields(record, payload)
        apply_revised_estimate_fields(record, payload, db=db)

        if payload.inspection_notes:
            record.inspection_notes = payload.inspection_notes
        record.status = "Under Customs Clearance"
        svc._touch(record, user)

        imp_file.form46_no = dec_no
        imp_file.form46_date = dec_dt
        imp_file.form46_status = "REGISTERED"
        imp_file.current_module = "Phase 7 - Customs Clearance"
        set_file_tracking(imp_file, stage_code="UNDER_CUSTOMS_CLEARANCE", next_action=msg("NA_CL_RECORD_INSPECTION"))
        svc._raise_progress(imp_file, 86.0)
        svc._touch(imp_file, user)
        return record, svc._file_label(imp_file)

    record, file_label = svc._commit_write(db, write)
    channel_code = enum_codes.normalize(enum_codes.CUSTOMS_CHANNEL, channel)
    d46_msg = msg(
        "CC_DECLARATION_46_REGISTERED",
        import_file_code=file_label,
        declaration_no=dec_no,
        channel_enum_customs_channel=channel_code,
        customs_office=office,
    )
    svc._step_follow_ups(
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



def save_revised_estimate_service(
    db: Session,
    payload: RevisedEstimateSubmit,
    user: str = SYSTEM_USER,
) -> CustomsClearanceRecord:
    """
    Saves or updates the revised customs duty estimate (التقدير المحدّث للرسوم الجمركية)
    prior to or alongside Customs Declaration Form 46 registration.
    """
    svc = _svc()
    imp_file = svc._require_import_file(db, payload.import_file_id)

    def write():
        record = repo.get_active_clearance_for_file(db, payload.import_file_id)
        if not record:
            record = svc._find_or_new_record(db, imp_file, user, status="Under Customs Clearance")
        apply_revised_estimate_fields(record, payload, db=db)
        if not record.revised_estimate_by:
            record.revised_estimate_by = user
        svc._touch(record, user)
        return record, svc._file_label(imp_file)

    record, _ = svc._commit_write(db, write)
    db.refresh(record)
    return record


def get_approved_booking_freight_service(db: Session, import_file_id: int) -> dict:
    """
    Reads approved booking freight (نولون البوكينج المعتمد) from the shipment booking
    or shipping scenario linked to the import file if available.
    """
    svc = _svc()
    svc._require_import_file(db, import_file_id)

    # 1. Look for linked ShipmentBooking
    try:
        from modules.freight_booking.model import ShipmentBooking
        from sqlalchemy import case
        booking = (
            db.query(ShipmentBooking)
            .filter(
                ShipmentBooking.import_file_id == import_file_id,
                ShipmentBooking.is_active == True,
            )
            .order_by(
                case(
                    (ShipmentBooking.status.in_(["Confirmed", "Sailed", "Amended"]), 1),
                    (ShipmentBooking.status == "Booking Requested", 2),
                    else_=3,
                ),
                ShipmentBooking.booking_id.desc(),
            )
            .first()
        )
    except Exception:
        booking = None

    if booking:
        freight_usd = float(booking.total_freight_cost_usd or 0.0)
        # Attempt to determine exchange rate to EGP
        rate_used = None
        record = repo.get_active_clearance_for_file(db, import_file_id)
        if record:
            rate_used = record.revised_exchange_rate or record.customs_exchange_rate
        if not rate_used:
            try:
                from modules.currencies.service import CurrencyService
                curr_svc = CurrencyService(db)
                rate_used = curr_svc._get_rate_to_egp("USD", rate_type="CUSTOMS")
            except Exception:
                rate_used = None

        freight_egp = round(freight_usd * float(rate_used), 2) if rate_used and freight_usd > 0 else None

        return {
            "has_booking": True,
            "import_file_id": import_file_id,
            "booking_id": booking.booking_id,
            "booking_code": booking.booking_code,
            "booking_status": booking.status,
            "shipping_line_name": booking.shipping_line_name,
            "freight_forwarder_name": booking.freight_forwarder_name,
            "bill_of_lading_no": booking.bill_of_lading_no,
            "freight_terms": booking.freight_terms,
            "total_freight_cost_usd": freight_usd,
            "freight_cost_egp": freight_egp,
            "exchange_rate_used": rate_used,
            "source": "ShipmentBooking",
            "notes": booking.notes,
        }

    # 2. Fallback to ShippingScenarioItem if no booking yet
    try:
        from modules.shipping_scenarios.model import ShippingEvaluationSession, ShippingScenarioItem
        item = (
            db.query(ShippingScenarioItem)
            .join(ShippingEvaluationSession, ShippingScenarioItem.session_id == ShippingEvaluationSession.session_id)
            .filter(
                ShippingEvaluationSession.import_file_id == import_file_id,
                ShippingScenarioItem.is_selected == True,
            )
            .order_by(ShippingScenarioItem.item_id.desc())
            .first()
        )
        if item:
            amount = float(item.total_quotation_amount or 0.0)
            curr = item.quotation_currency or "USD"
            return {
                "has_booking": True,
                "import_file_id": import_file_id,
                "booking_id": None,
                "booking_code": None,
                "booking_status": "Scenario Selected",
                "shipping_line_name": None,
                "freight_forwarder_name": item.provider_name,
                "bill_of_lading_no": None,
                "freight_terms": None,
                "total_freight_cost_usd": amount if curr == "USD" else 0.0,
                "freight_cost_egp": amount if curr == "EGP" else None,
                "exchange_rate_used": None,
                "source": "ShippingScenarioItem",
                "notes": item.notes,
            }
    except Exception:
        pass

    return {
        "has_booking": False,
        "import_file_id": import_file_id,
        "booking_id": None,
        "booking_code": None,
        "booking_status": None,
        "shipping_line_name": None,
        "freight_forwarder_name": None,
        "bill_of_lading_no": None,
        "freight_terms": None,
        "total_freight_cost_usd": 0.0,
        "freight_cost_egp": None,
        "exchange_rate_used": None,
        "source": None,
        "notes": None,
    }


def record_customs_inspection_sampling_service(
    db: Session,
    payload: CustomsInspectionSamplingSubmit,
    user: str = SYSTEM_USER,
) -> CustomsClearanceRecord:
    """CL-01: inspection / sampling report on the record, ImportFile sync (progress >= 88%), then tasks,
    notification and the STEP_14 -> STEP_15/17 board advance."""
    svc = _svc()
    svc._require_import_file(db, payload.import_file_id)
    validate_customs_inspection_payload(payload)

    sampling_rec = (payload.sampling_record_no or "").strip()
    insp_dt = payload.inspection_date or svc._now()
    sampling_dt = payload.sampling_date or (insp_dt if payload.is_sample_drawn else None)
    # INSPECTION_YARD code when picked from the list (legacy Arabic names mapped); free text stays as typed.
    insp_yard = enum_codes.normalize(enum_codes.INSPECTION_YARD, (payload.inspection_yard or "").strip()) or "Joint Inspection Yard"
    insp_type = (payload.inspection_type or "").strip() or None
    insp_result = payload.inspection_result.strip()
    sample_status = payload.sample_test_status or ("Samples Under Testing" if payload.is_sample_drawn else "None")
    sampled_bodies = enum_codes.normalize_list(enum_codes.REGULATORY_BODY, payload.sampled_regulatory_bodies) or []
    goeic_cert = (payload.goeic_certificate_no or "").strip() if payload.goeic_certificate_no else None
    lab_fees = float(payload.lab_service_fees or 0.0)

    def write():
        imp_file = svc._require_import_file(db, payload.import_file_id)
        record = svc._find_or_new_record(
            db, imp_file, user,
            status="Inspection & Sampling Recorded",
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
        svc._touch(record, user)

        imp_file.current_module = "Phase 7 - Customs Clearance & Inspection"
        set_file_tracking(imp_file, stage_code="CUSTOMS_INSPECTION_COMPLETED", next_action=msg("NA_CL_ASSESS_FINAL_DUTIES"))
        svc._raise_progress(imp_file, 88.0)
        svc._touch(imp_file, user)
        return record, svc._file_label(imp_file)

    record, file_label = svc._commit_write(db, write)
    result_code = enum_codes.normalize(enum_codes.INSPECTION_RESULT, insp_result)
    # inspection_yard is an INSPECTION_YARD code when picked from the list (render_en uses its English label).
    insp_msg = msg(
        "CC_INSPECTION_RECORDED",
        import_file_code=file_label,
        inspection_result_enum_inspection_result=result_code,
        inspection_yard_enum_inspection_yard=enum_codes.normalize(enum_codes.INSPECTION_YARD, insp_yard),
        sampling_record_no=sampling_rec if payload.is_sample_drawn else "-",
    )
    svc._step_follow_ups(
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

