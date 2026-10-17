from datetime import datetime, timezone, timedelta, date
import logging
import re
from typing import Callable, List, Optional
from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from modules.freight_booking.model import ShipmentBooking
from modules.import_files.model import ImportFile
from modules.freight_booking.schemas import (
    ShipmentBookingCreate,
    ShipmentBookingUpdate,
    ShipmentBookingConfirm,
    ShipmentDepartureConfirm,
)
import modules.freight_booking.repository as repo
import modules.freight_booking.validators as validators
from modules.common.errors import best_effort
from modules.common.system_messages import msg, render_en
from modules.common.file_tracking import set_file_tracking
from modules.common.clock import cairo_today
from modules.common.validators import not_found

logger = logging.getLogger(__name__)

# Pending system tasks auto-closed by BK-01 confirmation / SH-01 departure: message codes first, title keywords
# only for tasks created before message codes existed.
BOOKING_TASK_MSG_CODES = frozenset({"DOC_TASK_FREIGHT_BOOKING"})
BOOKING_TASK_TITLE_KEYS = ("bk-01", "حجز", "freight booking")
DEPARTURE_TASK_MSG_CODES = frozenset()  # no coded SH-01 task exists yet
DEPARTURE_TASK_TITLE_KEYS = ("sh-01", "إبحار", "sailing", "departure", "بوليصة")


def calculate_transit_time_and_costs(booking: ShipmentBooking, db: Optional[Session] = None):
    # Calculate transit time in days
    if booking.etd and booking.eta:
        validators.validate_booking_dates(booking.etd, booking.eta)
        etd_comp = booking.etd.replace(tzinfo=None) if hasattr(booking.etd, "tzinfo") and booking.etd.tzinfo else booking.etd
        eta_comp = booking.eta.replace(tzinfo=None) if hasattr(booking.eta, "tzinfo") and booking.eta.tzinfo else booking.eta
        delta = eta_comp - etd_comp
        booking.transit_time_days = max(0, delta.days)
    else:
        booking.transit_time_days = 0

    # Calculate departure delay days if actual departure (ATD) is recorded
    if booking.atd and booking.etd:
        delay = (booking.atd.date() - booking.etd.date()).days
        booking.departure_delay_days = max(0, delay)
    else:
        booking.departure_delay_days = 0

    # Calculate expected warehouse arrival date based on ETA + warehouse lead days
    wh_days = booking.expected_warehouse_days if booking.expected_warehouse_days is not None else 7
    if booking.eta:
        # If there was an actual departure delay, adjust ETA if ETA was not already updated
        adjusted_eta = booking.eta + timedelta(days=booking.departure_delay_days or 0)
        booking.expected_warehouse_arrival_date = adjusted_eta + timedelta(days=wh_days)
    elif booking.expected_warehouse_arrival_date is None and booking.etd:
        booking.expected_warehouse_arrival_date = booking.etd + timedelta(days=booking.transit_time_days + wh_days)

    # Calculate container counts by type and total count
    counts_by_type: dict[str, float] = {}
    total_containers: float = 0.0
    if booking.containers_data:
        for item in booking.containers_data:
            qty = float(item.get("quantity", 1) if isinstance(item, dict) else getattr(item, "quantity", 1))
            c_type = item.get("container_type", "") if isinstance(item, dict) else getattr(item, "container_type", "")
            if c_type:
                c_key = str(c_type).strip().upper()
                counts_by_type[c_key] = counts_by_type.get(c_key, 0.0) + qty
            total_containers += qty

    # Calculate preliminary costs
    total_cost = 0.0
    if booking.cost_charges_data:
        updated_charges = []
        for charge in booking.cost_charges_data:
            c_dict = dict(charge if isinstance(charge, dict) else charge.model_dump())
            unit = c_dict.get("unit", "Per Container")
            rate = float(c_dict.get("rate", 0.0))
            qty = float(c_dict.get("quantity", 1.0))
            container_type = c_dict.get("container_type")

            if unit == "Per Container":
                if container_type:
                    c_type_key = str(container_type).strip().upper()
                    if c_type_key in counts_by_type:
                        calc_qty = counts_by_type[c_type_key]
                    else:
                        raise HTTPException(
                            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                            detail=f"نوع الحاوية {container_type} في بند {c_dict.get('charge_type', '')} غير موجود في توزيع الحاويات.",
                        )
                elif total_containers > 0:
                    calc_qty = total_containers
                else:
                    calc_qty = qty
            else:
                calc_qty = qty

            item_total = round(rate * calc_qty, 2)
            c_dict["quantity"] = calc_qty
            c_dict["total"] = item_total

            # Currency conversion to USD
            raw_currency = c_dict.get("currency") or "USD"
            ccy = str(raw_currency).strip().upper()
            c_dict["currency"] = ccy

            if ccy == "USD":
                fx_rate_to_usd = 1.0
                amount_usd = item_total
            else:
                conf_date = getattr(booking, "booking_confirmation_date", None)
                if conf_date:
                    ref_date = conf_date.date() if hasattr(conf_date, "date") else conf_date
                else:
                    ref_date = date.today()

                if db is not None:
                    from modules.currencies.repository import CurrencyRepository
                    from modules.currencies.service import CurrencyService

                    repo_c = CurrencyRepository(db)
                    curr_obj = repo_c.get_currency_by_code(ccy)
                    if not curr_obj or not getattr(curr_obj, "is_active", True):
                        raise HTTPException(
                            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                            detail=f"عملة البند غير معروفة: {ccy}",
                        )

                    curr_svc = CurrencyService(db)
                    rate_to_egp, _, _ = curr_svc._get_rate_to_egp(ccy, rate_type="commercial", as_of_date=ref_date)
                    usd_rate_to_egp, _, _ = curr_svc._get_rate_to_egp("USD", rate_type="commercial", as_of_date=ref_date)
                    if usd_rate_to_egp <= 0:
                        raise HTTPException(
                            status_code=status.HTTP_409_CONFLICT,
                            detail={
                                "code": "CURRENCY_RATE_MISSING",
                                "message": f"لا يوجد سعر صرف مسجل للعملة 'USD' بتاريخ {ref_date}.",
                                "currency": "USD",
                            },
                        )
                    fx_rate_to_usd = rate_to_egp / usd_rate_to_egp
                else:
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                        detail=f"يتطلب تحويل عملة البند {ccy} جلسة قاعدة بيانات صالحة.",
                    )

                amount_usd = round(item_total * fx_rate_to_usd, 2)

            # Charge category
            raw_cat = c_dict.get("charge_category")
            if raw_cat:
                cat_upper = str(raw_cat).strip().upper()
                c_dict["charge_category"] = (
                    cat_upper if cat_upper in validators.CHARGE_CATEGORIES
                    else validators.infer_charge_category(c_dict.get("charge_type", ""))
                )
            else:
                c_dict["charge_category"] = validators.infer_charge_category(c_dict.get("charge_type", ""))

            c_dict["fx_rate_to_usd"] = round(fx_rate_to_usd, 6)
            c_dict["amount_usd"] = amount_usd
            total_cost += amount_usd
            updated_charges.append(c_dict)

        booking.cost_charges_data = updated_charges

    booking.total_freight_cost_usd = round(total_cost, 2)

    # --- Cost Savings & Rate Variance Calculation Engine ---
    quot_data = dict(booking.quotation_details_data or {})
    scenario_item = None

    # Retrieve scenario item if linked and needed
    if db and booking.scenario_item_id:
        from modules.shipping_scenarios.model import ShippingScenarioItem
        scenario_item = db.query(ShippingScenarioItem).filter(ShippingScenarioItem.item_id == booking.scenario_item_id).first()

    # Determine original quote amount
    orig_quote_total = float(quot_data.get("original_quote_total_usd") or 0.0)
    if orig_quote_total <= 0.0:
        if scenario_item and scenario_item.total_quotation_amount:
            orig_quote_total = float(scenario_item.total_quotation_amount)
        elif booking.original_freight_cost_usd and booking.original_freight_cost_usd > 0:
            orig_quote_total = float(booking.original_freight_cost_usd)

    booking.original_freight_cost_usd = round(orig_quote_total, 2)

    # Rates before modification
    orig_40ft_rate = float(quot_data.get("original_container_40ft_price") or (scenario_item.container_40ft_price if scenario_item else 0.0))
    orig_20ft_rate = float(quot_data.get("original_container_20ft_price") or (scenario_item.container_20ft_price if scenario_item else 0.0))
    orig_lcl_rate = float(quot_data.get("original_lcl_cbm_price") or (scenario_item.lcl_cbm_price if scenario_item else 0.0))
    orig_air_rate = float(quot_data.get("original_express_courier_price") or (scenario_item.express_courier_price if scenario_item else 0.0))

    # Calculate item-level savings breakdown
    savings_breakdown = []
    item_savings_sum = 0.0

    if booking.cost_charges_data:
        for ch in booking.cost_charges_data:
            c_dict = ch if isinstance(ch, dict) else ch.model_dump()
            c_type = c_dict.get("charge_type", "")
            exec_rate = float(c_dict.get("rate", 0.0))
            exec_qty = float(c_dict.get("quantity", 1))

            orig_rate = 0.0
            unit_label = "Container"

            if "40ft" in c_type or "40HC" in c_type or "40" in c_type:
                orig_rate = orig_40ft_rate
                unit_label = "40ft Container"
            elif "20ft" in c_type or "20GP" in c_type or "20" in c_type:
                orig_rate = orig_20ft_rate
                unit_label = "20ft Container"
            elif "LCL" in c_type or "CBM" in c_type:
                orig_rate = orig_lcl_rate
                unit_label = "CBM"
            elif "Air" in c_type or "Courier" in c_type:
                orig_rate = orig_air_rate
                unit_label = "Air shipment / kg"

            if orig_rate > 0.0:
                diff = round(orig_rate - exec_rate, 2)
                sub_savings = round(diff * exec_qty, 2)
                item_savings_sum += sub_savings
                savings_breakdown.append({
                    "charge_type": c_type,
                    "unit_label": unit_label,
                    "unit_type": unit_label,
                    "original_rate": orig_rate,
                    "original_unit_rate": orig_rate,
                    "executed_rate": exec_rate,
                    "executed_unit_rate": exec_rate,
                    "difference": diff,
                    "unit_diff": diff,
                    "quantity": exec_qty,
                    "subtotal_savings": sub_savings,
                    "item_savings": sub_savings,
                    "currency": c_dict.get("currency", "USD"),
                    "is_saving": diff > 0,
                })

    # If item-level breakdown didn't capture or there are other charges, use overall total difference
    if orig_quote_total > 0.0:
        cost_variance = round(orig_quote_total - booking.total_freight_cost_usd, 2)
        booking.cost_variance_usd = cost_variance
        booking.cost_savings_usd = max(0.0, cost_variance)
    else:
        booking.cost_variance_usd = round(item_savings_sum, 2)
        booking.cost_savings_usd = max(0.0, item_savings_sum)

    # Format savings notes
    if booking.cost_savings_usd > 0:
        pct = round((booking.cost_savings_usd / booking.original_freight_cost_usd) * 100.0, 1) if booking.original_freight_cost_usd > 0 else 0.0
        breakdown_text = ""
        if savings_breakdown:
            parts = [f"{b['charge_type']}: (${b['original_rate']:,.2f} - ${b['executed_rate']:,.2f}) × {int(b['quantity']) if b['quantity'].is_integer() else b['quantity']} = ${b['subtotal_savings']:,.2f} USD" for b in savings_breakdown if b.get('is_saving')]
            if parts:
                breakdown_text = " [" + " | ".join(parts) + "]"
        booking.savings_notes = f"Freight savings achieved: ${booking.cost_savings_usd:,.2f} USD ({pct}% saving on freight cost){breakdown_text}"
    elif booking.cost_variance_usd < 0:
        booking.savings_notes = f"Freight cost increase: +${abs(booking.cost_variance_usd):,.2f} USD over the initial quotation"
    else:
        booking.savings_notes = "Executed rate matches the approved quotation exactly"

    # Persist updated breakdown into quotation_details_data
    quot_data["original_quote_total_usd"] = booking.original_freight_cost_usd
    quot_data["executed_freight_cost_usd"] = booking.total_freight_cost_usd
    quot_data["cost_savings_usd"] = booking.cost_savings_usd
    quot_data["cost_variance_usd"] = booking.cost_variance_usd
    quot_data["savings_breakdown"] = savings_breakdown
    booking.quotation_details_data = quot_data


def _file_code(file_rec: ImportFile) -> str:
    return file_rec.custom_file_number or file_rec.import_file_code or f"IMP-{file_rec.import_file_id}"


def _active_import_file(db: Session, import_file_id: Optional[int]) -> Optional[ImportFile]:
    if not import_file_id:
        return None
    return db.query(ImportFile).filter(
        ImportFile.import_file_id == import_file_id,
        ImportFile.is_active == True,
    ).first()


_STEP_NUMBER_RE = re.compile(r"^STEP_(\d+)")


def _file_past_step(file_rec: Optional[ImportFile], step_code: str) -> bool:
    """True when the file's GP-002 step is beyond ``step_code`` (STEP_08_BL is past STEP_07): booking saves
    never move a file backwards on the board."""
    if file_rec is None or not file_rec.current_step_code:
        return False
    current = _STEP_NUMBER_RE.match(file_rec.current_step_code)
    target = _STEP_NUMBER_RE.match(step_code)
    if not current or not target:
        return False
    return int(current.group(1)) > int(target.group(1))


def _sync_import_file_with_booking(db: Session, booking: ShipmentBooking, tracking_step: Optional[str]) -> Optional[ImportFile]:
    """Two-way sync of the booking into its import file (no commit; part of the caller's transaction).
    ``tracking_step``: "STEP_07" (booking confirmed), "STEP_06" (booking still pending) or None (attributes only)."""
    file_rec = _active_import_file(db, booking.import_file_id)
    if not file_rec:
        return None

    if booking.free_demurrage_days:
        file_rec.target_free_days = booking.free_demurrage_days

    if booking.eta:
        file_rec.required_eta = booking.eta.date() if isinstance(booking.eta, datetime) else booking.eta

    if tracking_step == "STEP_07" and booking.shipping_line_name:
        carrier_label = booking.shipping_line_name
        if booking.vessel_name:
            carrier_label += f" ({booking.vessel_name})"
        file_rec.selected_scenario = f"Confirmed booking: {carrier_label}"

    if tracking_step and _file_past_step(file_rec, tracking_step):
        tracking_step = None  # the file is already further on the board: attributes only
    if tracking_step == "STEP_07":
        set_file_tracking(
            file_rec,
            step_code="STEP_07",
            next_action=msg(
                "NA_STEP07_FOLLOW_LOADING_PLAN",
                booking_no=booking.booking_confirmation_no or booking.booking_code,
            ),
        )
        if (file_rec.progress_percent or 0.0) < 50.0:
            file_rec.progress_percent = 50.0
    elif tracking_step == "STEP_06":
        set_file_tracking(
            file_rec,
            step_code="STEP_06",
            next_action=msg("NA_STEP06_FOLLOW_BOOKING_CONFIRMATION_REF", booking_no=booking.booking_code),
        )
        if (file_rec.progress_percent or 0.0) < 45.0:
            file_rec.progress_percent = 45.0
    return file_rec


def _tracking_step_for(booking: ShipmentBooking) -> Optional[str]:
    """Create / PUT only move a pending booking's file to STEP_06; STEP_07 comes from /confirm."""
    if booking.status in (validators.STATUS_DRAFT, validators.STATUS_REQUESTED):
        return "STEP_06"
    return None


def _sync_booking_lifecycle(db: Session, booking: ShipmentBooking, is_confirmed: bool) -> None:
    from modules.lifecycle_board.service import sync_booking_lifecycle_stage
    sync_booking_lifecycle_stage(
        db=db,
        import_file_id=booking.import_file_id,
        booking_code=booking.booking_code,
        booking_confirmation_no=booking.booking_confirmation_no,
        is_confirmed=is_confirmed,
        vessel_name=booking.vessel_name,
    )
    db.commit()


def _close_prior_tasks(db: Session, import_file_id: int, msg_codes: frozenset, title_keys: tuple) -> None:
    """Auto-close pending system tasks of the file: by ``msg_code`` first, by title keywords as a fallback
    (tasks created before message codes existed, generic lifecycle tasks)."""
    from modules.smart_tasks.model import SmartTask
    prior_tasks = db.query(SmartTask).filter(
        SmartTask.import_file_id == import_file_id,
        SmartTask.task_type == "System Generated",
        SmartTask.status.in_(["Pending", "In Progress"]),
        SmartTask.is_active == True,
    ).all()
    for pt in prior_tasks:
        title_lower = (pt.title or "").lower()
        if pt.msg_code in msg_codes or any(key in title_lower for key in title_keys):
            pt.status = "Completed"
            pt.is_auto_closed = True
    db.commit()


def _dispatch_free_days_task(db: Session, booking: ShipmentBooking, file_id: int, file_code: str) -> None:
    from modules.smart_tasks.service import create_task_service
    from modules.smart_tasks.schemas import SmartTaskCreate
    free_days_msg = msg(
        "FB_TASK_FREE_DAYS",
        import_file_code=file_code,
        booking_no=booking.booking_confirmation_no or booking.booking_code,
        shipping_line_name=booking.shipping_line_name or "N/A",
        vessel_name=booking.vessel_name or "TBA",
        demurrage_free_days=booking.free_demurrage_days or 14,
    )
    task_schema = SmartTaskCreate(
        title=render_en(free_days_msg.code, free_days_msg.params, "title"),
        description=render_en(free_days_msg.code, free_days_msg.params, "body"),
        task_type="System Generated",
        import_file_id=file_id,
        import_file_code=file_code,
        phase_name="Phase 3: Booking & Doc Prep",
        assigned_user="Logistics Officer",
        priority="High",
        reminder_type="Free Days Confirmation",
        due_date=str(date.today() + timedelta(days=2)),
        status="Pending",
        notes=f"ACTION:FREE_DAYS_CONFIRMATION | File: {file_code} | Booking: {booking.booking_confirmation_no or booking.booking_code}",
    )
    create_task_service(
        db, task_schema, user_name="Freight Booking Confirmation Engine",
        msg_code=free_days_msg.code, msg_params=free_days_msg.params,
    )


def _dispatch_booking_confirmed_notification(db: Session, booking: ShipmentBooking, file_code: str) -> None:
    from modules.notifications.model import SystemNotification
    notif_msg = msg(
        "FB_BOOKING_CONFIRMED",
        booking_no=booking.booking_confirmation_no or booking.booking_code,
        import_file_code=file_code,
        shipping_line_name=booking.shipping_line_name or "N/A",
        vessel_name=booking.vessel_name or "TBA",
        etd_date=booking.etd.strftime("%Y-%m-%d") if booking.etd else "TBA",
        eta_date=booking.eta.strftime("%Y-%m-%d") if booking.eta else "TBA",
        demurrage_free_days=booking.free_demurrage_days or 14,
    )
    db.add(SystemNotification(
        title=render_en(notif_msg.code, notif_msg.params, "title"),
        message=render_en(notif_msg.code, notif_msg.params, "body"),
        msg_code=notif_msg.code,
        msg_params=notif_msg.params,
        severity="INFO",
        category="FREIGHT_BOOKING_CONFIRMED",
        entity_type="ShipmentBooking",
        entity_id=booking.booking_id,
        target_role="LOGISTICS_OFFICER",
    ))
    db.commit()


def _log_audit(db: Session, booking: ShipmentBooking, action: str, user: str, new_data: dict, old_data: Optional[dict] = None) -> None:
    from modules.audit_logs.service import AuditLogService
    AuditLogService(db).log_activity(
        entity_type="ShipmentBooking",
        entity_id=booking.booking_id,
        entity_code=booking.booking_code,
        action=action,
        old_data=old_data,
        new_data=new_data,
        performed_by=user,
    )


def _run_pending_followups(db: Session, booking: ShipmentBooking) -> None:
    """Follow-ups after the commit of a create / PUT (never undo the saved booking)."""
    file_rec = _active_import_file(db, booking.import_file_id) if booking.import_file_id else None
    if file_rec and _tracking_step_for(booking) == "STEP_06" and not _file_past_step(file_rec, "STEP_06"):
        best_effort(db, _sync_booking_lifecycle, "Booking lifecycle sync (STEP_06)", db, booking, False)


def _commit_with_code_retry(db: Session, build: Callable[[], ShipmentBooking]) -> ShipmentBooking:
    """Runs ``build`` (adds + flushes a booking with a fresh code) and commits; one retry when a concurrent
    create took the same ``BKG`` code (unique constraint)."""
    try:
        booking = build()
        db.commit()
        return booking
    except IntegrityError:
        db.rollback()
        logger.warning("Booking code collision; retrying once with a new code")
        booking = build()
        db.commit()
        return booking


def create_booking_service(db: Session, payload: ShipmentBookingCreate, user: str = "system") -> ShipmentBooking:
    validators.validate_container_allocation(payload.shipment_type, payload.containers_data)
    validators.validate_manual_status(payload.status)
    validators.validate_no_duplicate_booking_for_file(db, payload.import_file_id)
    validators.validate_charges(payload.cost_charges_data)
    validators.validate_charge_currencies(db, payload.cost_charges_data)
    owner = payload.owner if "owner" in payload.model_fields_set and payload.owner else user

    def build() -> ShipmentBooking:
        new_booking = repo.create_booking(db, payload, owner=owner)
        calculate_transit_time_and_costs(new_booking, db=db)
        _sync_import_file_with_booking(db, new_booking, _tracking_step_for(new_booking))
        return new_booking

    booking = _commit_with_code_retry(db, build)
    db.refresh(booking)

    _run_pending_followups(db, booking)
    best_effort(db, _log_audit, "AuditLog for ShipmentBooking create", db, booking, "CREATE", user,
                payload.model_dump(mode="json", exclude_unset=True))
    db.refresh(booking)
    return booking


def get_booking_service(db: Session, booking_id: int) -> ShipmentBooking:
    booking = repo.get_booking_by_id(db, booking_id)
    if not booking:
        raise not_found(validators.BOOKING_LABEL_AR, booking_id)
    return booking


def list_bookings_service(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None
) -> List[ShipmentBooking]:
    return repo.list_bookings(db, include_inactive, import_file_id, status, search)


def update_booking_service(db: Session, booking_id: int, payload: ShipmentBookingUpdate, user: str = "system") -> ShipmentBooking:
    booking = get_booking_service(db, booking_id)

    validators.validate_editable_fields(booking, payload.model_fields_set, payload=payload)

    if "shipment_type" in payload.model_fields_set or "containers_data" in payload.model_fields_set:
        eff_type = payload.shipment_type if ("shipment_type" in payload.model_fields_set and payload.shipment_type is not None) else booking.shipment_type
        eff_containers = payload.containers_data if ("containers_data" in payload.model_fields_set and payload.containers_data is not None) else booking.containers_data
        validators.validate_container_allocation(eff_type, eff_containers)

    if "status" in payload.model_fields_set:
        validators.validate_manual_status(payload.status, booking.status)
    if payload.import_file_id is not None:
        validators.validate_no_duplicate_booking_for_file(db, payload.import_file_id, current_booking_id=booking_id)
    if payload.cost_charges_data is not None:
        validators.validate_charges(payload.cost_charges_data)
        validators.validate_charge_currencies(db, payload.cost_charges_data)

    update_data = payload.model_dump(mode="json", exclude_unset=True, exclude_none=True)
    old_data = {k: getattr(booking, k, None) for k in update_data.keys()}

    repo.apply_booking_update(booking, payload)
    calculate_transit_time_and_costs(booking, db=db)
    _sync_import_file_with_booking(db, booking, _tracking_step_for(booking))
    db.commit()
    db.refresh(booking)

    _run_pending_followups(db, booking)
    best_effort(db, _log_audit, "AuditLog for ShipmentBooking update", db, booking, "UPDATE", user, update_data, old_data)
    db.refresh(booking)
    return booking


def confirm_booking_service(db: Session, booking_id: int, payload: ShipmentBookingConfirm, user: str = "system") -> ShipmentBooking:
    booking = get_booking_service(db, booking_id)
    validators.validate_can_confirm(booking)

    booking.status = validators.STATUS_CONFIRMED
    booking.booking_confirmation_no = payload.booking_confirmation_no
    booking.booking_confirmation_date = datetime.now(timezone.utc)
    if payload.vessel_name:
        booking.vessel_name = payload.vessel_name
    if payload.voyage_number:
        booking.voyage_number = payload.voyage_number
    if payload.etd:
        booking.etd = payload.etd
    if payload.eta:
        booking.eta = payload.eta
    if payload.free_demurrage_days:
        booking.free_demurrage_days = payload.free_demurrage_days
    if payload.notes:
        booking.notes = payload.notes

    calculate_transit_time_and_costs(booking, db=db)
    past_step_07 = _file_past_step(_active_import_file(db, booking.import_file_id), "STEP_07")
    file_rec = _sync_import_file_with_booking(db, booking, "STEP_07")
    file_id = file_rec.import_file_id if file_rec else None
    file_code = _file_code(file_rec) if file_rec else None
    db.commit()
    db.refresh(booking)

    # Follow-ups (BK-01): lifecycle STEP_07, close prior BK-01 tasks, BK-02 task, notification
    if file_id:
        if not past_step_07:
            best_effort(db, _sync_booking_lifecycle, "Booking lifecycle sync (STEP_07)", db, booking, True)
        best_effort(db, _close_prior_tasks, "Auto-close prior booking smart tasks", db, file_id,
                    BOOKING_TASK_MSG_CODES, BOOKING_TASK_TITLE_KEYS)
        best_effort(db, _dispatch_free_days_task, "Dispatch BK-02 smart task", db, booking, file_id, file_code)
        best_effort(db, _dispatch_booking_confirmed_notification, "Booking confirmation notification", db, booking, file_code)
    best_effort(db, _log_audit, "AuditLog for ShipmentBooking confirm", db, booking, "CONFIRM", user,
                payload.model_dump(mode="json", exclude_unset=True))
    db.refresh(booking)
    return booking


def soft_delete_booking_service(db: Session, booking_id: int, user: str = "system") -> bool:
    booking = get_booking_service(db, booking_id)
    validators.validate_deletable(booking)
    repo.set_booking_active(booking, False)
    db.commit()
    best_effort(db, _log_audit, "AuditLog for ShipmentBooking delete", db, booking, "DELETE", user, {"is_active": False})
    return True


def restore_booking_service(db: Session, booking_id: int, user: str = "system") -> ShipmentBooking:
    booking = repo.get_booking_by_id(db, booking_id, include_inactive=True)
    if not booking:
        raise not_found(validators.BOOKING_LABEL_AR, booking_id)
    validators.validate_no_duplicate_booking_for_file(db, booking.import_file_id, current_booking_id=booking_id)
    repo.set_booking_active(booking, True)
    calculate_transit_time_and_costs(booking, db=db)
    db.commit()
    db.refresh(booking)
    best_effort(db, _log_audit, "AuditLog for ShipmentBooking restore", db, booking, "RESTORE", user, {"is_active": True})
    db.refresh(booking)
    return booking


def confirm_departure_and_bol_service(
    db: Session,
    booking_id: int,
    payload: ShipmentDepartureConfirm,
    user: str = "system",
) -> ShipmentBooking:
    booking = get_booking_service(db, booking_id)
    validators.validate_can_depart(booking)

    today = cairo_today()
    atd_date = (
        payload.actual_departure_date.date()
        if isinstance(payload.actual_departure_date, datetime)
        else payload.actual_departure_date
    )
    if atd_date > today:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="تاريخ الإبحار الفعلي (ATD) لا يمكن أن يكون في المستقبل.",
        )
    if booking.booking_request_date:
        req_date = (
            booking.booking_request_date.date()
            if isinstance(booking.booking_request_date, datetime)
            else booking.booking_request_date
        )
        if atd_date < req_date:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="تاريخ الإبحار الفعلي (ATD) لا يمكن أن يكون قبل تاريخ طلب الحجز.",
            )

    # 1. Update Booking state
    booking.atd = payload.actual_departure_date
    booking.shipped_on_board_date = payload.shipped_on_board_date
    booking.bill_of_lading_no = payload.bill_of_lading_no.strip()
    booking.status = validators.STATUS_SAILED

    if payload.revised_eta:
        booking.eta = payload.revised_eta
    if payload.vessel_name:
        booking.vessel_name = payload.vessel_name.strip()
    if payload.voyage_number:
        booking.voyage_number = payload.voyage_number.strip()
    if payload.notes:
        if booking.notes:
            booking.notes += f"\n[Sailing confirmation]: {payload.notes.strip()}"
        else:
            booking.notes = f"[Sailing confirmation]: {payload.notes.strip()}"

    # Recalculate transit times, delay days, and warehouse arrival date
    calculate_transit_time_and_costs(booking, db=db)

    # 2. Same transaction: import file and demurrage trackings of the file
    file_rec = _sync_import_file_on_departure(db, booking)
    file_id = file_rec.import_file_id if file_rec else None
    file_code = file_rec.import_file_code if file_rec else None
    db.commit()
    db.refresh(booking)

    # 3. Follow-ups: lifecycle STEP_08_BL, prior SH-01 tasks, SH-02 task, notification
    if file_id:
        if not _file_past_step(file_rec, "STEP_08_BL"):
            best_effort(db, _advance_departure_lifecycle, "Lifecycle advance for departure", db, booking)
        best_effort(db, _close_prior_tasks, "Auto-close prior departure smart tasks", db, file_id,
                    DEPARTURE_TASK_MSG_CODES, DEPARTURE_TASK_TITLE_KEYS)
        if not _file_past_step(file_rec, "STEP_08_BL"):
            best_effort(db, _dispatch_draft_bl_task, "Dispatch SH-02 smart task", db, booking, file_id, file_code)
        best_effort(db, _dispatch_departure_notification, "Departure notification", db, booking, file_code)
    best_effort(db, _log_audit, "AuditLog for ShipmentBooking departure", db, booking, "DEPART", user,
                payload.model_dump(mode="json", exclude_unset=True))
    db.refresh(booking)
    return booking


def _sync_import_file_on_departure(db: Session, booking: ShipmentBooking) -> Optional[ImportFile]:
    """No commit: updates the import file and the file's active demurrage trackings with the B/L."""
    if not booking.import_file_id:
        return None
    file_rec = db.query(ImportFile).filter(
        ImportFile.import_file_id == booking.import_file_id,
        ImportFile.is_active == True,
    ).first()
    if not file_rec:
        return None

    if booking.eta:
        file_rec.required_eta = booking.eta.date() if isinstance(booking.eta, datetime) else booking.eta

    if not _file_past_step(file_rec, "STEP_08_BL"):
        file_rec.current_module = "STEP_08 In-Transit On Water"
        set_file_tracking(file_rec, next_action=msg("NA_STEP08BL_REVIEW_DRAFT_BL"))
        if (file_rec.progress_percent or 0.0) < 60.0:
            file_rec.progress_percent = 60.0

    from modules.demurrage_detention.model import DemurrageTracking
    dem_records = db.query(DemurrageTracking).filter(
        DemurrageTracking.import_file_id == booking.import_file_id,
        DemurrageTracking.is_active == True,
    ).all()
    for dem in dem_records:
        dem.bill_of_lading_no = booking.bill_of_lading_no
        if booking.shipping_line_name and not dem.carrier_name:
            dem.carrier_name = booking.shipping_line_name
    return file_rec


def _advance_departure_lifecycle(db: Session, booking: ShipmentBooking) -> None:
    from modules.lifecycle_board.service import advance_lifecycle_step_service
    file_rec = db.query(ImportFile).filter(
        ImportFile.import_file_id == booking.import_file_id,
        ImportFile.is_active == True,
    ).first()
    if file_rec and _file_past_step(file_rec, "STEP_08_BL"):
        return
    atd_str = booking.atd.strftime("%Y-%m-%d") if booking.atd else "N/A"
    advance_lifecycle_step_service(
        db=db,
        completed_step_code="STEP_07",
        import_file_id=booking.import_file_id,
        target_step_codes=["STEP_08_BL"],
        auto_complete_prior=True,
        notes_msg=msg("FB_SAILING_CONFIRMED", atd_date=atd_str, bl_number=booking.bill_of_lading_no),
        next_action_msg=msg("NA_STEP08BL_MATCH_BL_PO_INVOICE"),
        source_module="Freight Booking Departure Engine",
        min_progress_percent=60.0,
    )
    db.commit()


def _dispatch_draft_bl_task(db: Session, booking: ShipmentBooking, file_id: int, file_code: str) -> None:
    from modules.smart_tasks.service import create_task_service
    from modules.smart_tasks.schemas import SmartTaskCreate
    bl_task_msg = msg(
        "FB_TASK_DRAFT_BL_REVIEW",
        import_file_code=file_code,
        bl_number=booking.bill_of_lading_no,
        vessel_name=booking.vessel_name or "TBA",
        voyage_number=booking.voyage_number or "TBA",
    )
    task_schema = SmartTaskCreate(
        title=render_en(bl_task_msg.code, bl_task_msg.params, "title"),
        description=render_en(bl_task_msg.code, bl_task_msg.params, "body"),
        task_type="System Generated",
        import_file_id=file_id,
        import_file_code=file_code,
        phase_name="Phase 3: Booking & Doc Prep",
        assigned_user="Logistics Officer",
        priority="High",
        reminder_type="Draft B/L Dual Review",
        due_date=str(date.today() + timedelta(days=2)),
        status="Pending",
        notes=f"ACTION:DRAFT_BL_DUAL_REVIEW | File: {file_code} | BL: {booking.bill_of_lading_no}",
    )
    create_task_service(
        db, task_schema, user_name="Departure & B/L Confirmation Engine",
        msg_code=bl_task_msg.code, msg_params=bl_task_msg.params,
    )


def _dispatch_departure_notification(db: Session, booking: ShipmentBooking, file_code: str) -> None:
    from modules.notifications.model import SystemNotification
    notif_msg = msg(
        "FB_SAILING_CONFIRMED",
        bl_number=booking.bill_of_lading_no,
        import_file_code=file_code,
        atd_date=booking.atd.strftime("%Y-%m-%d") if booking.atd else "TBA",
        vessel_name=booking.vessel_name or "TBA",
        voyage_number=booking.voyage_number or "TBA",
        eta_date=booking.eta.strftime("%Y-%m-%d") if booking.eta else "TBA",
    )
    db.add(SystemNotification(
        title=render_en(notif_msg.code, notif_msg.params, "title"),
        message=render_en(notif_msg.code, notif_msg.params, "body"),
        msg_code=notif_msg.code,
        msg_params=notif_msg.params,
        severity="INFO",
        category="SHIPMENT_DEPARTED",
        entity_type="ShipmentBooking",
        entity_id=booking.booking_id,
        target_role="LOGISTICS_OFFICER",
    ))
    db.commit()
