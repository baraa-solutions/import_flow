from datetime import timedelta
from typing import Dict, List, Optional

from sqlalchemy.orm import Session

from modules.common.validators import get_or_404
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
    session_obj: ShippingEvaluationSession,
    import_file_code: Optional[str],
    po_number: Optional[str] = None,
    project_name: Optional[str] = None,
) -> ShippingEvaluationResponse:
    """Pure: per-scenario day arithmetic plus the average / earliest / latest / recommended summary."""
    crd = session_obj.cargo_ready_date
    calculated_items: List[ShippingScenarioItemCalculated] = []
    valid_transit_days: List[int] = []
    earliest: Optional[ShippingScenarioItemCalculated] = None
    latest: Optional[ShippingScenarioItemCalculated] = None
    for item in session_obj.items:
        vessel_lead_time = (item.estimated_arrival_date - item.sailing_date).days
        ready_for_shipping = (item.sailing_date - crd).days
        expected_total_days = _total_days(session_obj, item)
        calc_item = ShippingScenarioItemCalculated(
            **{f: getattr(item, f) for f in SCENARIO_ITEM_FIELDS},
            item_id=item.item_id,
            vessel_lead_time_days=vessel_lead_time,
            ready_for_shipping_days=ready_for_shipping,
            expected_total_days_to_warehouse=expected_total_days,
            expected_warehouse_arrival_date=crd + timedelta(days=expected_total_days),
        )
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

        if payload.items is not None:
            ShippingScenarioValidator.validate_scenario_items(
                payload.cargo_ready_date or session_obj.cargo_ready_date, payload.items
            )
            stored_ids = {it.item_id for it in session_obj.items}
            sent_ids = [it.item_id for it in payload.items]
            ShippingScenarioValidator.validate_item_ids_belong(stored_ids, sent_ids)
            sent_set = {i for i in sent_ids if i is not None}
            removed_ids = stored_ids - sent_set
            if removed_ids:
                booked = ShippingScenarioRepository.booked_item_ids(db, removed_ids)
                ShippingScenarioValidator.validate_removed_not_booked(booked)
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

        cloned_session = ShippingEvaluationSession(
            session_code=ShippingScenarioRepository.generate_session_code(db),
            title=new_title,
            cargo_ready_date=req.cargo_ready_date or source.cargo_ready_date,
            pick_up_address=source.pick_up_address,
            port_of_loading_id=source.port_of_loading_id,
            port_of_discharge_id=source.port_of_discharge_id,
            avg_form4_days=source.avg_form4_days,
            avg_clearance_days=source.avg_clearance_days,
            import_file_id=None if req.unlink_import_file else source.import_file_id,
            po_id=None if req.unlink_po else source.po_id,
            project_id=source.project_id,
            notes=notes,
            is_active=True,
            created_by=user,
            updated_by=user,
        )
        db.add(cloned_session)
        db.flush()

        if req.copy_carrier_options and source.items:
            ShippingScenarioRepository.add_items_copy(db, cloned_session.session_id, source.items)

        db.commit()
        db.refresh(cloned_session)
        return ShippingScenarioService._respond(db, cloned_session)
