from datetime import date, timedelta
from typing import Any, Dict, List, Optional, Tuple

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.common.validators import get_or_404
from modules.financial_settlement.service import SettlementFx
from modules.import_files.repository import codes_by_ids
from modules.shipping_scenarios.model import ShippingEvaluationSession
from modules.shipping_scenarios.repository import ShippingScenarioRepository
from modules.shipping_scenarios.schemas import (
    SCENARIO_ITEM_FIELDS,
    CloneShippingEvaluationRequest,
    ShippingEvaluationCreate,
    ShippingEvaluationResponse,
    ShippingEvaluationUpdate,
    ShippingScenarioItemCalculated,
)
from modules.shipping_scenarios.validators import ShippingScenarioValidator


def scenario_item_totals(db: Session, item: Any, on_date: date) -> Tuple[float, float]:
    """
    Computes (total_quotation_amount, freight_total_amount) for a scenario item in quotation_currency
    using commercial FX rates on on_date (session created_at date or today).

    1. International Freight (freight_total_amount):
       - 40' container: container_40ft_price * container_40ft_qty (if container_40ft_applicable)
       - 20' container: container_20ft_price * container_20ft_qty (if container_20ft_applicable)
       - LCL: lcl_cbm_price * lcl_cbm_qty (if lcl_cbm_applicable)
       - Express courier: express_courier_price * 1 (if express_courier_applicable)

    2. Per-Container Charges (multiplied by container_40ft_qty + container_20ft_qty):
       - SOLAS VGM: solas_vgm_price * (c40_qty + c20_qty) (if solas_vgm_applicable)
       - VGM notification: vgm_notification_price * (c40_qty + c20_qty) (if vgm_notification_applicable)

    3. Flat Charges (x 1):
       - eur_atr, telex_release, insurance, booking_cancellation, ics2_filing_fee,
         others_fee, document_fees, waiver_letter_fee, dthc, storage_per_week,
         extra_day_storage, clearance_fee, inspection_fee, inland_transport_fee, port_expenses.

    Raises 409 SS_FX_RATE_MISSING when a commercial rate is missing.
    All components converted into quotation_currency, rounded to 2 decimals.
    """
    BREAKDOWN_APPLICABLE_FLAGS = [
        "container_40ft_applicable",
        "container_20ft_applicable",
        "lcl_cbm_applicable",
        "express_courier_applicable",
        "solas_vgm_applicable",
        "vgm_notification_applicable",
        "eur_atr_applicable",
        "telex_release_applicable",
        "insurance_applicable",
        "booking_cancellation_applicable",
        "ics2_filing_fee_applicable",
        "others_fee_applicable",
        "document_fees_applicable",
        "waiver_letter_fee_applicable",
        "dthc_applicable",
        "storage_per_week_applicable",
        "extra_day_storage_applicable",
        "clearance_fee_applicable",
        "inspection_fee_applicable",
        "inland_transport_fee_applicable",
        "port_expenses_applicable",
    ]
    if not any(getattr(item, f, False) for f in BREAKDOWN_APPLICABLE_FLAGS):
        if getattr(item, "item_id", None) is not None:
            legacy_amt = float(getattr(item, "total_quotation_amount", 0.0) or 0.0)
            return legacy_amt, legacy_amt
        return 0.0, 0.0

    target_currency = (getattr(item, "quotation_currency", None) or "USD").strip().upper()
    c40_qty = int(getattr(item, "container_40ft_qty", 0) or 0) if getattr(item, "container_40ft_applicable", False) else 0
    c20_qty = int(getattr(item, "container_20ft_qty", 0) or 0) if getattr(item, "container_20ft_applicable", False) else 0
    total_cntrs = c40_qty + c20_qty
    lcl_qty = float(getattr(item, "lcl_cbm_qty", 0.0) or 0.0) if getattr(item, "lcl_cbm_applicable", False) else 0.0

    eff_date = on_date or date.today()
    fx = SettlementFx(db, "commercial")

    def _convert(amount: float, source_currency: Optional[str]) -> float:
        if amount == 0.0:
            return 0.0
        c_from = (source_currency or target_currency).strip().upper()
        if c_from == target_currency:
            return round(amount, 2)
        try:
            rate_from = fx.rate(c_from, eff_date)
        except HTTPException:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "SS_FX_RATE_MISSING",
                    "message": f"لا يوجد سعر صرف تجاري مسجل للعملة {c_from} بتاريخ {eff_date.isoformat()}.",
                    "currency": c_from,
                    "on_date": eff_date.isoformat(),
                },
            )
        try:
            rate_to = fx.rate(target_currency, eff_date)
        except HTTPException:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "SS_FX_RATE_MISSING",
                    "message": f"لا يوجد سعر صرف تجاري مسجل للعملة {target_currency} بتاريخ {eff_date.isoformat()}.",
                    "currency": target_currency,
                    "on_date": eff_date.isoformat(),
                },
            )
        return round(amount * (rate_from / rate_to), 2)

    freight_total = 0.0
    total = 0.0

    # 1. International Freight
    if getattr(item, "container_40ft_applicable", False):
        amt = float(getattr(item, "container_40ft_price", 0.0) or 0.0) * c40_qty
        converted = _convert(amt, getattr(item, "container_40ft_currency", None))
        freight_total += converted
        total += converted

    if getattr(item, "container_20ft_applicable", False):
        amt = float(getattr(item, "container_20ft_price", 0.0) or 0.0) * c20_qty
        converted = _convert(amt, getattr(item, "container_20ft_currency", None))
        freight_total += converted
        total += converted

    if getattr(item, "lcl_cbm_applicable", False):
        amt = float(getattr(item, "lcl_cbm_price", 0.0) or 0.0) * lcl_qty
        converted = _convert(amt, getattr(item, "lcl_cbm_currency", None))
        freight_total += converted
        total += converted

    if getattr(item, "express_courier_applicable", False):
        amt = float(getattr(item, "express_courier_price", 0.0) or 0.0)
        converted = _convert(amt, getattr(item, "express_courier_currency", None))
        freight_total += converted
        total += converted

    # 2. Per-Container Surcharges
    if getattr(item, "solas_vgm_applicable", False):
        amt = float(getattr(item, "solas_vgm_price", 0.0) or 0.0) * total_cntrs
        converted = _convert(amt, getattr(item, "solas_vgm_currency", None))
        total += converted

    if getattr(item, "vgm_notification_applicable", False):
        amt = float(getattr(item, "vgm_notification_price", 0.0) or 0.0) * total_cntrs
        converted = _convert(amt, getattr(item, "vgm_notification_currency", None))
        total += converted

    # 3. Flat Charges
    flat_components = [
        ("eur_atr_applicable", "eur_atr_price", "eur_atr_currency"),
        ("telex_release_applicable", "telex_release_price", "telex_release_currency"),
        ("insurance_applicable", "insurance_price", "insurance_currency"),
        ("booking_cancellation_applicable", "booking_cancellation_price", "booking_cancellation_currency"),
        ("ics2_filing_fee_applicable", "ics2_filing_fee_price", "ics2_filing_fee_currency"),
        ("others_fee_applicable", "others_fee_price", "others_fee_currency"),
        ("document_fees_applicable", "document_fees_price", "document_fees_currency"),
        ("waiver_letter_fee_applicable", "waiver_letter_fee_price", "waiver_letter_fee_currency"),
        ("dthc_applicable", "dthc_price", "dthc_currency"),
        ("storage_per_week_applicable", "storage_per_week_price", "storage_per_week_currency"),
        ("extra_day_storage_applicable", "extra_day_storage_price", "extra_day_storage_currency"),
        ("clearance_fee_applicable", "clearance_fee_price", "clearance_fee_currency"),
        ("inspection_fee_applicable", "inspection_fee_price", "inspection_fee_currency"),
        ("inland_transport_fee_applicable", "inland_transport_fee_price", "inland_transport_fee_currency"),
        ("port_expenses_applicable", "port_expenses_price", "port_expenses_currency"),
    ]

    for app_field, price_field, curr_field in flat_components:
        if getattr(item, app_field, False):
            amt = float(getattr(item, price_field, 0.0) or 0.0)
            converted = _convert(amt, getattr(item, curr_field, None))
            total += converted

    return round(total, 2), round(freight_total, 2)


def _total_days(session_obj: ShippingEvaluationSession, item) -> int:
    """Days from cargo ready date to warehouse for one scenario."""
    return (
        (item.estimated_arrival_date - item.sailing_date).days
        + (item.sailing_date - session_obj.cargo_ready_date).days
        + session_obj.avg_form4_days
        + session_obj.avg_clearance_days
        + item.expected_line_delay_days
    )


def _recommended_provider(session_obj: ShippingEvaluationSession) -> Optional[str]:
    """The last scenario flagged is_recommended, else the earliest arrival among the averaged ones
    ("provider (vessel)")."""
    flagged = [i for i in session_obj.items if i.is_recommended]
    if flagged:
        return f"{flagged[-1].provider_name} ({flagged[-1].vessel_name})"
    earliest = None
    for item in session_obj.items:
        if item.is_excluded_from_average:
            continue
        if earliest is None or _total_days(session_obj, item) < _total_days(session_obj, earliest):
            earliest = item
    return f"{earliest.provider_name} ({earliest.vessel_name})" if earliest else None


def _build_response(
    db: Session,
    session_obj: ShippingEvaluationSession,
    import_file_code: Optional[str],
    po_number: Optional[str] = None,
    project_name: Optional[str] = None,
) -> ShippingEvaluationResponse:
    """Pure: per-scenario day arithmetic plus the average / earliest / latest / recommended summary."""
    crd = session_obj.cargo_ready_date
    on_date = session_obj.created_at.date() if getattr(session_obj, "created_at", None) else date.today()
    calculated_items: List[ShippingScenarioItemCalculated] = []
    valid_transit_days: List[int] = []
    earliest: Optional[ShippingScenarioItemCalculated] = None
    latest: Optional[ShippingScenarioItemCalculated] = None
    for item in session_obj.items:
        vessel_lead_time = (item.estimated_arrival_date - item.sailing_date).days
        ready_for_shipping = (item.sailing_date - crd).days
        expected_total_days = _total_days(session_obj, item)
        total, freight_total = scenario_item_totals(db, item, on_date)
        calc_dict = {f: getattr(item, f) for f in SCENARIO_ITEM_FIELDS}
        calc_dict.update({
            "item_id": item.item_id,
            "total_quotation_amount": total,
            "freight_total_amount": freight_total,
            "totals_rate_date": on_date,
            "vessel_lead_time_days": vessel_lead_time,
            "ready_for_shipping_days": ready_for_shipping,
            "expected_total_days_to_warehouse": expected_total_days,
            "expected_warehouse_arrival_date": crd + timedelta(days=expected_total_days),
        })
        calc_item = ShippingScenarioItemCalculated(**calc_dict)
        calculated_items.append(calc_item)

        if not item.is_excluded_from_average:
            valid_transit_days.append(expected_total_days)
            arrival = calc_item.expected_warehouse_arrival_date
            if earliest is None or arrival < earliest.expected_warehouse_arrival_date:
                earliest = calc_item
            if latest is None or arrival > latest.expected_warehouse_arrival_date:
                latest = calc_item

    avg_transit = sum(valid_transit_days) / len(valid_transit_days) if valid_transit_days else 0.0
    # round() is banker's rounding (pinned by the characterization tests).
    avg_wh_date = crd + timedelta(days=round(avg_transit)) if valid_transit_days else None

    return ShippingEvaluationResponse(
        session_id=session_obj.session_id,
        session_code=session_obj.session_code,
        title=session_obj.title,
        cargo_ready_date=session_obj.cargo_ready_date,
        pick_up_address=session_obj.pick_up_address,
        port_of_loading_id=session_obj.port_of_loading_id,
        port_of_discharge_id=session_obj.port_of_discharge_id,
        avg_form4_days=session_obj.avg_form4_days,
        avg_clearance_days=session_obj.avg_clearance_days,
        import_file_id=session_obj.import_file_id,
        import_file_code=import_file_code,
        po_id=session_obj.po_id,
        project_id=session_obj.project_id,
        notes=session_obj.notes,
        is_active=session_obj.is_active,
        created_at=session_obj.created_at,
        updated_at=session_obj.updated_at,
        created_by=session_obj.created_by,
        updated_by=session_obj.updated_by,
        po_number=po_number,
        project_name=project_name,
        items=calculated_items,
        avg_expected_transit_days=round(avg_transit, 1),
        avg_expected_warehouse_arrival_date=avg_wh_date,
        earliest_arrival_scenario_provider=earliest.provider_name if earliest else None,
        earliest_arrival_date=earliest.expected_warehouse_arrival_date if earliest else None,
        latest_arrival_scenario_provider=latest.provider_name if latest else None,
        latest_arrival_date=latest.expected_warehouse_arrival_date if latest else None,
        recommended_scenario_provider=_recommended_provider(session_obj),
    )


class ShippingScenarioService:
    """
    Business Logic & Calculation Engine for BP-007 Shipping Scenarios Evaluation
    """

    @staticmethod
    def _respond(
        db: Session,
        session_obj: ShippingEvaluationSession,
        codes: Optional[Dict[int, str]] = None,
        po_numbers: Optional[Dict[int, str]] = None,
        project_names: Optional[Dict[int, str]] = None,
    ) -> ShippingEvaluationResponse:
        """``codes`` / ``po_numbers`` / ``project_names``: preloaded maps for lists; None = look up this row."""
        if codes is None:
            codes = codes_by_ids(db, [session_obj.import_file_id])
        if po_numbers is None or project_names is None:
            po_numbers, project_names = ShippingScenarioRepository.po_and_project_names(db, [session_obj])
        return _build_response(
            db,
            session_obj,
            codes.get(session_obj.import_file_id),
            po_numbers.get(session_obj.po_id),
            project_names.get(session_obj.project_id),
        )

    @staticmethod
    def _check_one_per_file(db: Session, import_file_id: int, session_id: Optional[int] = None) -> None:
        ShippingScenarioValidator.validate_no_other_session_for_file(
            ShippingScenarioRepository.list_sessions(db, import_file_id=import_file_id), session_id=session_id
        )

    @staticmethod
    def _commit_with_file_selection(db: Session, session_obj: ShippingEvaluationSession) -> ShippingEvaluationResponse:
        """Write the recommended scenario onto the linked import file, then commit once."""
        recommended = _recommended_provider(session_obj)
        if session_obj.import_file_id and recommended:
            ShippingScenarioRepository.set_file_selected_scenario(db, session_obj.import_file_id, recommended)
        db.commit()
        db.refresh(session_obj)
        return ShippingScenarioService._respond(db, session_obj)

    @staticmethod
    def create_session_service(
        db: Session, payload: ShippingEvaluationCreate, user: Optional[str] = None
    ) -> ShippingEvaluationResponse:
        ShippingScenarioValidator.validate_evaluation_create(payload)
        ShippingScenarioValidator.validate_foreign_keys(db, payload, payload.items)
        if payload.import_file_id:
            ShippingScenarioService._check_one_per_file(db, payload.import_file_id)
        on_date = date.today()
        if payload.items:
            for item in payload.items:
                tot, _ = scenario_item_totals(db, item, on_date)
                item.total_quotation_amount = tot
        session_obj = ShippingScenarioRepository.create(db, payload)
        session_obj.created_by = session_obj.updated_by = user
        return ShippingScenarioService._commit_with_file_selection(db, session_obj)

    @staticmethod
    def get_session_service(db: Session, session_id: int) -> ShippingEvaluationResponse:
        return ShippingScenarioService._respond(db, get_or_404(db, ShippingEvaluationSession, session_id, "دراسة سيناريوهات الشحن"))

    @staticmethod
    def list_sessions_service(
        db: Session,
        include_inactive: bool = False,
        import_file_id: Optional[int] = None,
        project_id: Optional[int] = None,
        po_id: Optional[int] = None,
        search: Optional[str] = None,
    ) -> List[ShippingEvaluationResponse]:
        sessions = ShippingScenarioRepository.list_sessions(
            db,
            include_inactive=include_inactive,
            import_file_id=import_file_id,
            project_id=project_id,
            po_id=po_id,
            search=search,
        )
        codes: Dict[int, str] = codes_by_ids(db, [s.import_file_id for s in sessions])
        po_numbers, project_names = ShippingScenarioRepository.po_and_project_names(db, sessions)
        return [ShippingScenarioService._respond(db, s, codes, po_numbers, project_names) for s in sessions]

    @staticmethod
    def update_session_service(
        db: Session, session_id: int, payload: ShippingEvaluationUpdate, user: Optional[str] = None
    ) -> ShippingEvaluationResponse:
        session_obj = get_or_404(db, ShippingEvaluationSession, session_id, "دراسة سيناريوهات الشحن")

        ShippingScenarioValidator.validate_evaluation_update(payload, session_obj)
        on_date = session_obj.created_at.date() if session_obj.created_at else date.today()
        if payload.items is not None:
            stored_ids = {it.item_id for it in session_obj.items}
            sent_ids = [it.item_id for it in payload.items]
            ShippingScenarioValidator.validate_item_ids_belong(stored_ids, sent_ids)

            removed_ids = stored_ids - {i for i in sent_ids if i is not None}
            if removed_ids:
                booked = ShippingScenarioRepository.booked_item_ids(db, removed_ids)
                ShippingScenarioValidator.validate_removed_not_booked(booked)

            for item in payload.items:
                tot, _ = scenario_item_totals(db, item, on_date)
                item.total_quotation_amount = tot
        ShippingScenarioValidator.validate_foreign_keys(db, payload, payload.items, stored=session_obj)
        file_id = payload.import_file_id or session_obj.import_file_id
        reactivated = not session_obj.is_active and payload.is_active is not False  # an update reactivates
        if file_id and (file_id != session_obj.import_file_id or reactivated):
            ShippingScenarioService._check_one_per_file(db, file_id, session_id)

        updated_obj = ShippingScenarioRepository.update(db, session_obj, payload)
        updated_obj.updated_by = user
        return ShippingScenarioService._commit_with_file_selection(db, updated_obj)

    @staticmethod
    def soft_delete_service(db: Session, session_id: int, user: Optional[str] = None) -> dict:
        session_obj = get_or_404(db, ShippingEvaluationSession, session_id, "دراسة سيناريوهات الشحن")
        session_obj.updated_by = user
        ShippingScenarioRepository.soft_delete(db, session_obj)
        db.commit()
        return {"message": f"Shipping evaluation session {session_obj.session_code} deactivated successfully."}

    @staticmethod
    def restore_service(db: Session, session_id: int, user: Optional[str] = None) -> ShippingEvaluationResponse:
        session_obj = get_or_404(db, ShippingEvaluationSession, session_id, "دراسة سيناريوهات الشحن")
        if session_obj.import_file_id and not session_obj.is_active:
            ShippingScenarioService._check_one_per_file(db, session_obj.import_file_id, session_id)
        session_obj.updated_by = user
        ShippingScenarioRepository.restore(db, session_obj)
        db.commit()
        db.refresh(session_obj)
        return ShippingScenarioService._respond(db, session_obj)

    @staticmethod
    def clone_session_service(
        db: Session,
        session_id: int,
        payload: Optional[CloneShippingEvaluationRequest] = None,
        user: Optional[str] = None,
    ) -> ShippingEvaluationResponse:
        source = get_or_404(db, ShippingEvaluationSession, session_id, "دراسة سيناريوهات الشحن")
        req = payload or CloneShippingEvaluationRequest()

        new_title = req.new_title or f"{source.title or f'Study {source.session_code}'} (Copy)"
        notes = source.notes
        if req.remarks:
            notes = f"{notes}\n[Clone Note]: {req.remarks}" if notes else f"[Clone Note]: {req.remarks}"

        cloned_file_id = (
            req.target_import_file_id
            if getattr(req, "target_import_file_id", None) is not None
            else (None if req.unlink_import_file else source.import_file_id)
        )
        if cloned_file_id:
            ShippingScenarioService._check_one_per_file(db, cloned_file_id)

        cloned_session = ShippingEvaluationSession(
            session_code=ShippingScenarioRepository.generate_session_code(db),
            title=new_title,
            cargo_ready_date=req.cargo_ready_date or source.cargo_ready_date,
            pick_up_address=source.pick_up_address,
            port_of_loading_id=source.port_of_loading_id,
            port_of_discharge_id=source.port_of_discharge_id,
            avg_form4_days=source.avg_form4_days,
            avg_clearance_days=source.avg_clearance_days,
            import_file_id=cloned_file_id,
            po_id=None if req.unlink_po else source.po_id,
            project_id=source.project_id,
            notes=notes,
            is_active=True,
            created_by=user,
            updated_by=user,
        )

        items_to_validate = source.items if (req.copy_carrier_options and source.items) else []
        ShippingScenarioValidator.validate_foreign_keys(db, cloned_session, items_to_validate)

        db.add(cloned_session)
        db.flush()

        if req.copy_carrier_options and source.items:
            ShippingScenarioRepository.add_items_copy(db, cloned_session.session_id, source.items)

        db.commit()
        db.refresh(cloned_session)
        return ShippingScenarioService._respond(db, cloned_session)
