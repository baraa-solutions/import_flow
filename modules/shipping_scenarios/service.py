from datetime import timedelta, date
from typing import List, Optional
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.shipping_scenarios.model import (
    ShippingEvaluationSession,
    ShippingScenarioItem,
)
from modules.shipping_scenarios.repository import ShippingScenarioRepository
from modules.shipping_scenarios.schemas import (
    ShippingEvaluationCreate,
    ShippingEvaluationUpdate,
    ShippingEvaluationResponse,
    ShippingScenarioItemCalculated,
    CloneShippingEvaluationRequest,
)
from modules.shipping_scenarios.validators import ShippingScenarioValidator


class ShippingScenarioService:
    """
    Business Logic & Calculation Engine for BP-007 Shipping Scenarios Evaluation
    """

    @staticmethod
    def _enrich_session_response(
        db: Session,
        session_obj: ShippingEvaluationSession,
        import_file_code: Optional[str] = None,
    ) -> ShippingEvaluationResponse:
        crd = session_obj.cargo_ready_date
        form4_days = session_obj.avg_form4_days
        clearance_days = session_obj.avg_clearance_days

        calculated_items: List[ShippingScenarioItemCalculated] = []
        valid_transit_days: List[int] = []
        valid_arrival_dates: List[date] = []

        earliest_item: Optional[ShippingScenarioItemCalculated] = None
        latest_item: Optional[ShippingScenarioItemCalculated] = None
        recommended_provider: Optional[str] = None
        min_days = 999999

        for item in session_obj.items:
            vessel_lead_time = (item.estimated_arrival_date - item.sailing_date).days
            ready_for_shipping = (item.sailing_date - crd).days
            expected_total_days = (
                vessel_lead_time
                + ready_for_shipping
                + form4_days
                + clearance_days
                + item.expected_line_delay_days
            )
            expected_wh_date = crd + timedelta(days=expected_total_days)

            calc_item = ShippingScenarioItemCalculated(
                item_id=item.item_id,
                provider_id=item.provider_id,
                provider_name=item.provider_name,
                customs_broker_id=item.customs_broker_id,
                customs_broker_name=item.customs_broker_name,
                vessel_name=item.vessel_name,
                voyage_number=item.voyage_number,
                port_of_loading_id=item.port_of_loading_id,
                port_of_discharge_id=item.port_of_discharge_id,
                pol_name=item.pol_name,
                pod_name=item.pod_name,
                sailing_date=item.sailing_date,
                estimated_arrival_date=item.estimated_arrival_date,
                expected_line_delay_days=item.expected_line_delay_days,
                is_excluded_from_average=item.is_excluded_from_average,
                is_recommended=item.is_recommended,
                is_selected=item.is_selected,
                risk_level=item.risk_level,
                notes=item.notes,
                vessel_lead_time_days=vessel_lead_time,
                ready_for_shipping_days=ready_for_shipping,
                expected_total_days_to_warehouse=expected_total_days,
                expected_warehouse_arrival_date=expected_wh_date,
                # Quotation properties
                free_time_days=item.free_time_days,
                quotation_currency=item.quotation_currency,
                total_quotation_amount=item.total_quotation_amount,
                container_40ft_applicable=item.container_40ft_applicable,
                container_40ft_price=item.container_40ft_price,
                container_40ft_currency=item.container_40ft_currency,
                container_40ft_qty=item.container_40ft_qty,
                container_20ft_applicable=item.container_20ft_applicable,
                container_20ft_price=item.container_20ft_price,
                container_20ft_currency=item.container_20ft_currency,
                container_20ft_qty=item.container_20ft_qty,
                lcl_cbm_applicable=item.lcl_cbm_applicable,
                lcl_cbm_price=item.lcl_cbm_price,
                lcl_cbm_currency=item.lcl_cbm_currency,
                lcl_cbm_qty=item.lcl_cbm_qty,
                express_courier_applicable=item.express_courier_applicable,
                express_courier_price=item.express_courier_price,
                express_courier_currency=item.express_courier_currency,
                eur_atr_applicable=item.eur_atr_applicable,
                eur_atr_price=item.eur_atr_price,
                eur_atr_currency=item.eur_atr_currency,
                solas_vgm_applicable=item.solas_vgm_applicable,
                solas_vgm_price=item.solas_vgm_price,
                solas_vgm_currency=item.solas_vgm_currency,
                vgm_notification_applicable=item.vgm_notification_applicable,
                vgm_notification_price=item.vgm_notification_price,
                vgm_notification_currency=item.vgm_notification_currency,
                telex_release_applicable=item.telex_release_applicable,
                telex_release_price=item.telex_release_price,
                telex_release_currency=item.telex_release_currency,
                insurance_applicable=item.insurance_applicable,
                insurance_price=item.insurance_price,
                insurance_currency=item.insurance_currency,
                booking_cancellation_applicable=item.booking_cancellation_applicable,
                booking_cancellation_price=item.booking_cancellation_price,
                booking_cancellation_currency=item.booking_cancellation_currency,
                ics2_filing_fee_applicable=item.ics2_filing_fee_applicable,
                ics2_filing_fee_price=item.ics2_filing_fee_price,
                ics2_filing_fee_currency=item.ics2_filing_fee_currency,
                others_fee_applicable=item.others_fee_applicable,
                others_fee_price=item.others_fee_price,
                others_fee_currency=item.others_fee_currency,
                document_fees_applicable=item.document_fees_applicable,
                document_fees_price=item.document_fees_price,
                document_fees_currency=item.document_fees_currency,
                waiver_letter_fee_applicable=item.waiver_letter_fee_applicable,
                waiver_letter_fee_price=item.waiver_letter_fee_price,
                waiver_letter_fee_currency=item.waiver_letter_fee_currency,
                dthc_applicable=item.dthc_applicable,
                dthc_price=item.dthc_price,
                dthc_currency=item.dthc_currency,
                storage_per_week_applicable=item.storage_per_week_applicable,
                storage_per_week_price=item.storage_per_week_price,
                storage_per_week_currency=item.storage_per_week_currency,
                extra_day_storage_applicable=item.extra_day_storage_applicable,
                extra_day_storage_price=item.extra_day_storage_price,
                extra_day_storage_currency=item.extra_day_storage_currency,
                clearance_fee_applicable=item.clearance_fee_applicable,
                clearance_fee_price=item.clearance_fee_price,
                clearance_fee_currency=item.clearance_fee_currency,
                inspection_fee_applicable=item.inspection_fee_applicable,
                inspection_fee_price=item.inspection_fee_price,
                inspection_fee_currency=item.inspection_fee_currency,
                inland_transport_fee_applicable=item.inland_transport_fee_applicable,
                inland_transport_fee_price=item.inland_transport_fee_price,
                inland_transport_fee_currency=item.inland_transport_fee_currency,
                port_expenses_applicable=item.port_expenses_applicable,
                port_expenses_price=item.port_expenses_price,
                port_expenses_currency=item.port_expenses_currency,
            )
            calculated_items.append(calc_item)

            if item.is_recommended:
                recommended_provider = f"{item.provider_name} ({item.vessel_name})"

            if not item.is_excluded_from_average:
                valid_transit_days.append(expected_total_days)
                valid_arrival_dates.append(expected_wh_date)

                if earliest_item is None or expected_wh_date < earliest_item.expected_warehouse_arrival_date:
                    earliest_item = calc_item
                if latest_item is None or expected_wh_date > latest_item.expected_warehouse_arrival_date:
                    latest_item = calc_item

                if expected_total_days < min_days and recommended_provider is None:
                    min_days = expected_total_days

        avg_transit = (
            sum(valid_transit_days) / len(valid_transit_days)
            if valid_transit_days
            else 0.0
        )
        avg_wh_date = (
            crd + timedelta(days=round(avg_transit))
            if valid_transit_days
            else None
        )

        if not recommended_provider and earliest_item:
            recommended_provider = f"{earliest_item.provider_name} ({earliest_item.vessel_name})"

        # Fetch names for linked entities if present
        po_num = session_obj.po.po_number if getattr(session_obj, "po", None) else None
        prj_name = session_obj.project.project_name if getattr(session_obj, "project", None) else None
        if session_obj.import_file_id and import_file_code is None:
            from modules.import_files.model import ImportFile
            imp = db.query(ImportFile).filter(ImportFile.import_file_id == session_obj.import_file_id).first()
            if imp:
                import_file_code = imp.import_file_code or imp.custom_file_number

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
            po_number=po_num,
            project_name=prj_name,
            items=calculated_items,
            avg_expected_transit_days=round(avg_transit, 1),
            avg_expected_warehouse_arrival_date=avg_wh_date,
            earliest_arrival_scenario_provider=earliest_item.provider_name if earliest_item else None,
            earliest_arrival_date=earliest_item.expected_warehouse_arrival_date if earliest_item else None,
            latest_arrival_scenario_provider=latest_item.provider_name if latest_item else None,
            latest_arrival_date=latest_item.expected_warehouse_arrival_date if latest_item else None,
            recommended_scenario_provider=recommended_provider,
        )

    @staticmethod
    def create_session_service(
        db: Session, payload: ShippingEvaluationCreate
    ) -> ShippingEvaluationResponse:
        ShippingScenarioValidator.validate_evaluation_create(payload)

        # Prevent duplicate scenario creation for the same import file
        if payload.import_file_id:
            existing = ShippingScenarioRepository.list_sessions(db, import_file_id=payload.import_file_id)
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"يوجد بالفعل دراسة سيناريوهات شحن محفوظة لهذا الملف. يرجى الذهاب لتعديل الدراسة الحالية بدلاً من إنشاء دراسة جديدة.",
                )

        session_obj = ShippingScenarioRepository.create(db, payload)
        res = ShippingScenarioService._enrich_session_response(db, session_obj)
        if res.import_file_id and res.recommended_scenario_provider:
            from modules.import_files.model import ImportFile
            imp = db.query(ImportFile).filter(ImportFile.import_file_id == res.import_file_id).first()
            if imp:
                imp.selected_scenario = res.recommended_scenario_provider
                db.commit()
        return res

    @staticmethod
    def get_session_service(
        db: Session, session_id: int
    ) -> ShippingEvaluationResponse:
        session_obj = ShippingScenarioRepository.get_by_id(db, session_id)
        if not session_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Shipping evaluation session with ID {session_id} not found.",
            )
        return ShippingScenarioService._enrich_session_response(db, session_obj)

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
        if not sessions:
            return []

        # Batch preload ImportFile codes to eliminate N+1 queries
        import_file_ids = {s.import_file_id for s in sessions if s.import_file_id}
        import_files_map = {}
        if import_file_ids:
            from modules.import_files.model import ImportFile
            imps = db.query(ImportFile).filter(ImportFile.import_file_id.in_(import_file_ids)).all()
            import_files_map = {
                i.import_file_id: (i.import_file_code or i.custom_file_number) for i in imps
            }

        return [
            ShippingScenarioService._enrich_session_response(
                db, s, import_file_code=import_files_map.get(s.import_file_id)
            )
            for s in sessions
        ]

    @staticmethod
    def update_session_service(
        db: Session, session_id: int, payload: ShippingEvaluationUpdate
    ) -> ShippingEvaluationResponse:
        session_obj = ShippingScenarioRepository.get_by_id(db, session_id)
        if not session_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Shipping evaluation session with ID {session_id} not found.",
            )

        effective_crd = payload.cargo_ready_date or session_obj.cargo_ready_date
        if payload.items:
            ShippingScenarioValidator.validate_scenario_items(
                effective_crd, payload.items
            )

        updated_obj = ShippingScenarioRepository.update(db, session_obj, payload)
        res = ShippingScenarioService._enrich_session_response(db, updated_obj)
        if res.import_file_id and res.recommended_scenario_provider:
            from modules.import_files.model import ImportFile
            imp = db.query(ImportFile).filter(ImportFile.import_file_id == res.import_file_id).first()
            if imp:
                imp.selected_scenario = res.recommended_scenario_provider
                db.commit()
        return res

    @staticmethod
    def soft_delete_service(db: Session, session_id: int) -> dict:
        session_obj = ShippingScenarioRepository.get_by_id(db, session_id)
        if not session_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Shipping evaluation session with ID {session_id} not found.",
            )
        ShippingScenarioRepository.soft_delete(db, session_obj)
        return {
            "message": f"Shipping evaluation session {session_obj.session_code} deactivated successfully."
        }

    @staticmethod
    def restore_service(db: Session, session_id: int) -> ShippingEvaluationResponse:
        session_obj = ShippingScenarioRepository.get_by_id(db, session_id)
        if not session_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Shipping evaluation session with ID {session_id} not found.",
            )
        restored_obj = ShippingScenarioRepository.restore(db, session_obj)
        return ShippingScenarioService._enrich_session_response(db, restored_obj)

    @staticmethod
    def clone_session_service(
        db: Session,
        session_id: int,
        payload: Optional[CloneShippingEvaluationRequest] = None,
    ) -> ShippingEvaluationResponse:
        source = ShippingScenarioRepository.get_by_id(db, session_id)
        if not source:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Shipping evaluation session with ID {session_id} not found.",
            )

        req = payload or CloneShippingEvaluationRequest()
        new_code = ShippingScenarioRepository.generate_session_code(db)

        new_title = req.new_title
        if not new_title:
            base_title = source.title or f"Study {source.session_code}"
            new_title = f"{base_title} (Copy)"

        new_crd = req.cargo_ready_date or source.cargo_ready_date
        new_import_file_id = None if req.unlink_import_file else source.import_file_id
        new_po_id = None if req.unlink_po else source.po_id

        notes = source.notes
        if req.remarks:
            notes = f"{notes}\n[Clone Note]: {req.remarks}" if notes else f"[Clone Note]: {req.remarks}"

        cloned_session = ShippingEvaluationSession(
            session_code=new_code,
            title=new_title,
            cargo_ready_date=new_crd,
            pick_up_address=source.pick_up_address,
            port_of_loading_id=source.port_of_loading_id,
            port_of_discharge_id=source.port_of_discharge_id,
            avg_form4_days=source.avg_form4_days,
            avg_clearance_days=source.avg_clearance_days,
            import_file_id=new_import_file_id,
            po_id=new_po_id,
            project_id=source.project_id,
            notes=notes,
            is_active=True,
        )
        db.add(cloned_session)
        db.flush()

        if req.copy_carrier_options and source.items:
            for item in source.items:
                cloned_item = ShippingScenarioItem(
                    session_id=cloned_session.session_id,
                    provider_id=item.provider_id,
                    provider_name=item.provider_name,
                    customs_broker_id=item.customs_broker_id,
                    customs_broker_name=item.customs_broker_name,
                    vessel_name=item.vessel_name,
                    voyage_number=item.voyage_number,
                    port_of_loading_id=item.port_of_loading_id,
                    port_of_discharge_id=item.port_of_discharge_id,
                    pol_name=item.pol_name,
                    pod_name=item.pod_name,
                    sailing_date=item.sailing_date,
                    estimated_arrival_date=item.estimated_arrival_date,
                    expected_line_delay_days=item.expected_line_delay_days,
                    is_excluded_from_average=item.is_excluded_from_average,
                    is_recommended=False,
                    is_selected=False,
                    risk_level=item.risk_level,
                    notes=item.notes,
                    free_time_days=item.free_time_days,
                    quotation_currency=item.quotation_currency,
                    total_quotation_amount=item.total_quotation_amount,
                    container_40ft_applicable=item.container_40ft_applicable,
                    container_40ft_price=item.container_40ft_price,
                    container_40ft_currency=item.container_40ft_currency,
                    container_40ft_qty=item.container_40ft_qty,
                    container_20ft_applicable=item.container_20ft_applicable,
                    container_20ft_price=item.container_20ft_price,
                    container_20ft_currency=item.container_20ft_currency,
                    container_20ft_qty=item.container_20ft_qty,
                    lcl_cbm_applicable=item.lcl_cbm_applicable,
                    lcl_cbm_price=item.lcl_cbm_price,
                    lcl_cbm_currency=item.lcl_cbm_currency,
                    lcl_cbm_qty=item.lcl_cbm_qty,
                    express_courier_applicable=item.express_courier_applicable,
                    express_courier_price=item.express_courier_price,
                    express_courier_currency=item.express_courier_currency,
                    eur_atr_applicable=item.eur_atr_applicable,
                    eur_atr_price=item.eur_atr_price,
                    eur_atr_currency=item.eur_atr_currency,
                    solas_vgm_applicable=item.solas_vgm_applicable,
                    solas_vgm_price=item.solas_vgm_price,
                    solas_vgm_currency=item.solas_vgm_currency,
                    vgm_notification_applicable=item.vgm_notification_applicable,
                    vgm_notification_price=item.vgm_notification_price,
                    vgm_notification_currency=item.vgm_notification_currency,
                    telex_release_applicable=item.telex_release_applicable,
                    telex_release_price=item.telex_release_price,
                    telex_release_currency=item.telex_release_currency,
                    insurance_applicable=item.insurance_applicable,
                    insurance_price=item.insurance_price,
                    insurance_currency=item.insurance_currency,
                    booking_cancellation_applicable=item.booking_cancellation_applicable,
                    booking_cancellation_price=item.booking_cancellation_price,
                    booking_cancellation_currency=item.booking_cancellation_currency,
                    ics2_filing_fee_applicable=item.ics2_filing_fee_applicable,
                    ics2_filing_fee_price=item.ics2_filing_fee_price,
                    ics2_filing_fee_currency=item.ics2_filing_fee_currency,
                    others_fee_applicable=item.others_fee_applicable,
                    others_fee_price=item.others_fee_price,
                    others_fee_currency=item.others_fee_currency,
                    document_fees_applicable=item.document_fees_applicable,
                    document_fees_price=item.document_fees_price,
                    document_fees_currency=item.document_fees_currency,
                    waiver_letter_fee_applicable=item.waiver_letter_fee_applicable,
                    waiver_letter_fee_price=item.waiver_letter_fee_price,
                    waiver_letter_fee_currency=item.waiver_letter_fee_currency,
                    dthc_applicable=item.dthc_applicable,
                    dthc_price=item.dthc_price,
                    dthc_currency=item.dthc_currency,
                    storage_per_week_applicable=item.storage_per_week_applicable,
                    storage_per_week_price=item.storage_per_week_price,
                    storage_per_week_currency=item.storage_per_week_currency,
                    extra_day_storage_applicable=item.extra_day_storage_applicable,
                    extra_day_storage_price=item.extra_day_storage_price,
                    extra_day_storage_currency=item.extra_day_storage_currency,
                    clearance_fee_applicable=item.clearance_fee_applicable,
                    clearance_fee_price=item.clearance_fee_price,
                    clearance_fee_currency=item.clearance_fee_currency,
                    inspection_fee_applicable=item.inspection_fee_applicable,
                    inspection_fee_price=item.inspection_fee_price,
                    inspection_fee_currency=item.inspection_fee_currency,
                    inland_transport_fee_applicable=item.inland_transport_fee_applicable,
                    inland_transport_fee_price=item.inland_transport_fee_price,
                    inland_transport_fee_currency=item.inland_transport_fee_currency,
                    port_expenses_applicable=item.port_expenses_applicable,
                    port_expenses_price=item.port_expenses_price,
                    port_expenses_currency=item.port_expenses_currency,
                )
                db.add(cloned_item)

        db.commit()
        db.refresh(cloned_session)
        return ShippingScenarioService._enrich_session_response(db, cloned_session)

