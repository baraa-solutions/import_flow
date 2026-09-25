"""
Customs Consultation & Broker Price Lists Service Engine (BP-009)
"""

from datetime import datetime, date, timezone
from typing import Dict, List, Optional
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from modules.customs_consultation.model import (
    ClearanceExpenseType,
    BrokerPriceList,
    CustomsConsultationSession,
)
from modules.customs_consultation.schemas import (
    ClearanceExpenseTypeCreate,
    ClearanceExpenseTypeUpdate,
    ClearanceExpenseTypeResponse,
    BrokerPriceListCreate,
    BrokerPriceListUpdate,
    BrokerPriceListResponse,
    CustomsConsultationCreate,
    CustomsConsultationUpdate,
    CustomsConsultationResponse,
    CloneBrokerPriceListRequest,
    CloneConsultationRequest,
)
from modules.customs_consultation.repository import (
    ClearanceExpenseTypeRepository,
    BrokerPriceListRepository,
    CustomsConsultationRepository,
)
from modules.customs_consultation.validators import (
    validate_broker_exists,
    validate_checklist_items,
    validate_expense_code_unique,
)


# ==============================================================================
# Clearance Expense Types Service
# ==============================================================================

class ClearanceExpenseTypeService:

    @staticmethod
    def create_expense_type(db: Session, schema: ClearanceExpenseTypeCreate) -> ClearanceExpenseTypeResponse:
        validate_expense_code_unique(db, schema.expense_code)
        obj = ClearanceExpenseTypeRepository.create(db, schema)
        return ClearanceExpenseTypeResponse.model_validate(obj)

    @staticmethod
    def get_expense_type(db: Session, expense_id: int) -> ClearanceExpenseTypeResponse:
        obj = ClearanceExpenseTypeRepository.get_by_id(db, expense_id)
        if not obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Expense Type with ID '{expense_id}' not found.",
            )
        return ClearanceExpenseTypeResponse.model_validate(obj)

    @staticmethod
    def list_expense_types(
        db: Session,
        include_inactive: bool = False,
        category: Optional[str] = None,
        search: Optional[str] = None,
    ) -> List[ClearanceExpenseTypeResponse]:
        items = ClearanceExpenseTypeRepository.get_all(
            db, include_inactive=include_inactive, category=category, search=search
        )
        return [ClearanceExpenseTypeResponse.model_validate(i) for i in items]

    @staticmethod
    def update_expense_type(
        db: Session, expense_id: int, schema: ClearanceExpenseTypeUpdate
    ) -> ClearanceExpenseTypeResponse:
        obj = ClearanceExpenseTypeRepository.get_by_id(db, expense_id)
        if not obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Expense Type with ID '{expense_id}' not found.",
            )
        if schema.expense_code and schema.expense_code != obj.expense_code:
            validate_expense_code_unique(db, schema.expense_code, current_id=expense_id)
        updated = ClearanceExpenseTypeRepository.update(db, obj, schema)
        return ClearanceExpenseTypeResponse.model_validate(updated)

    @staticmethod
    def delete_expense_type(db: Session, expense_id: int) -> ClearanceExpenseTypeResponse:
        obj = ClearanceExpenseTypeRepository.get_by_id(db, expense_id)
        if not obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Expense Type with ID '{expense_id}' not found.",
            )
        deleted = ClearanceExpenseTypeRepository.delete(db, obj)
        return ClearanceExpenseTypeResponse.model_validate(deleted)


# ==============================================================================
# Broker Price Lists Service
# ==============================================================================

class BrokerPriceListService:

    @staticmethod
    def create_price_list(db: Session, schema: BrokerPriceListCreate) -> BrokerPriceListResponse:
        validate_broker_exists(db, schema.broker_id)
        pl = BrokerPriceListRepository.create(db, schema)
        return BrokerPriceListResponse.model_validate(pl)

    @staticmethod
    def get_price_list(db: Session, price_list_id: int) -> BrokerPriceListResponse:
        pl = BrokerPriceListRepository.get_by_id(db, price_list_id)
        if not pl:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Broker Price List with ID '{price_list_id}' not found.",
            )
        return BrokerPriceListResponse.model_validate(pl)

    @staticmethod
    def list_price_lists(
        db: Session,
        include_inactive: bool = False,
        broker_id: Optional[int] = None,
        search: Optional[str] = None,
    ) -> List[BrokerPriceListResponse]:
        lists = BrokerPriceListRepository.get_all(
            db, include_inactive=include_inactive, broker_id=broker_id, search=search
        )
        return [BrokerPriceListResponse.model_validate(l) for l in lists]

    @staticmethod
    def get_active_price_list_for_broker(
        db: Session, broker_id: int, target_date: Optional[date] = None
    ) -> Optional[BrokerPriceListResponse]:
        validate_broker_exists(db, broker_id)
        pl = BrokerPriceListRepository.get_active_by_broker(db, broker_id, target_date)
        if not pl:
            return None
        return BrokerPriceListResponse.model_validate(pl)

    @staticmethod
    def update_price_list(
        db: Session, price_list_id: int, schema: BrokerPriceListUpdate
    ) -> BrokerPriceListResponse:
        pl = BrokerPriceListRepository.get_by_id(db, price_list_id)
        if not pl:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Broker Price List with ID '{price_list_id}' not found.",
            )
        if schema.broker_id:
            validate_broker_exists(db, schema.broker_id)
        updated = BrokerPriceListRepository.update(db, pl, schema)
        return BrokerPriceListResponse.model_validate(updated)

    @staticmethod
    def soft_delete_price_list(db: Session, price_list_id: int) -> BrokerPriceListResponse:
        pl = BrokerPriceListRepository.get_by_id(db, price_list_id)
        if not pl:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Broker Price List with ID '{price_list_id}' not found.",
            )
        deleted = BrokerPriceListRepository.soft_delete(db, pl)
        return BrokerPriceListResponse.model_validate(deleted)

    @staticmethod
    def clone_price_list(
        db: Session, price_list_id: int, schema: CloneBrokerPriceListRequest
    ) -> BrokerPriceListResponse:
        original = BrokerPriceListRepository.get_by_id(db, price_list_id)
        if not original:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Broker Price List with ID '{price_list_id}' not found.",
            )

        target_code = schema.new_price_list_code
        if not target_code:
            target_code = f"{original.price_list_code}-CLONE"
            idx = 1
            while db.query(BrokerPriceList).filter(BrokerPriceList.price_list_code == target_code).first():
                target_code = f"{original.price_list_code}-CLONE{idx}"
                idx += 1
        else:
            existing = db.query(BrokerPriceList).filter(BrokerPriceList.price_list_code == target_code).first()
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"كود قائمة الأسعار '{target_code}' مستخدم بالفعل.",
                )

        new_pl = BrokerPriceList(
            price_list_code=target_code,
            title=schema.new_title,
            broker_id=original.broker_id,
            broker_name=original.broker_name,
            port_name=original.port_name,
            effective_from=schema.effective_from or date.today(),
            effective_to=schema.effective_to,
            version=original.version + 1,
            is_active=True,
            notes=schema.notes or f"مستنسخة من: {original.price_list_code}",
            cloned_from_id=original.price_list_id,
            cloned_from_code=original.price_list_code,
        )
        db.add(new_pl)
        db.flush()

        from modules.customs_consultation.model import BrokerPriceListItem
        for itm in original.items:
            cloned_item = BrokerPriceListItem(
                price_list_id=new_pl.price_list_id,
                expense_type_id=itm.expense_type_id,
                expense_name=itm.expense_name,
                category=itm.category,
                unit_type=itm.unit_type,
                standard_price=itm.standard_price,
                currency=itm.currency,
                min_price=itm.min_price,
                max_price=itm.max_price,
                notes=itm.notes,
                is_active=itm.is_active,
            )
            db.add(cloned_item)

        db.commit()
        db.refresh(new_pl)
        return BrokerPriceListResponse.model_validate(new_pl)



# ==============================================================================
# Customs Consultation Session Service
# ==============================================================================

class CustomsConsultationService:

    @staticmethod
    def _compute_session_metrics(
        db: Session,
        db_session: CustomsConsultationSession,
        import_file_codes_map: Optional[Dict[int, str]] = None,
    ) -> CustomsConsultationResponse:
        """
        Calculates total documents, approved count, blocking issues count, readiness %,
        total broker fees, applied broker items count, and overall status.
        """
        items = db_session.checklist_items or []
        total_count = len(items)
        approved_count = sum(1 for item in items if item.status == "Approved")
        rejected_count = sum(1 for item in items if item.status == "Rejected")
        blocking_count = sum(
            1 for item in items if item.is_blocking_shipment and item.status == "Rejected"
        )
        
        readiness_pct = (approved_count / total_count * 100.0) if total_count > 0 else 0.0
        readiness_pct = round(readiness_pct, 1)

        has_blocking = blocking_count > 0

        # Auto evaluate status if not explicitly locked or override
        overall_status = db_session.overall_status
        if has_blocking:
            overall_status = "Blocked"
        elif readiness_pct == 100.0 and total_count > 0:
            overall_status = "Clearance Ready"
        elif rejected_count > 0:
            overall_status = "Action Required"
        elif approved_count > 0 or any(i.status == "Verified" for i in items):
            overall_status = "In Progress"

        db_session.readiness_percentage = readiness_pct
        db_session.has_blocking_issues = has_blocking
        db_session.overall_status = overall_status

        # Broker quote items metrics
        quote_items = db_session.broker_quote_items or []
        applied_broker_count = sum(1 for q in quote_items if q.is_applicable)
        total_broker_fees = sum(q.total_amount for q in quote_items if q.is_applicable)
        db_session.total_broker_fees_egp = total_broker_fees

        import_file_code = None
        if db_session.import_file_id:
            if import_file_codes_map is not None and db_session.import_file_id in import_file_codes_map:
                import_file_code = import_file_codes_map[db_session.import_file_id]
            else:
                from modules.import_files.model import ImportFile
                imp = db.query(ImportFile).filter(ImportFile.import_file_id == db_session.import_file_id).first()
                if imp:
                    import_file_code = imp.import_file_code or imp.custom_file_number

        res = CustomsConsultationResponse.model_validate(db_session)
        res.total_documents_count = total_count
        res.approved_documents_count = approved_count
        res.blocking_issues_count = blocking_count
        res.applied_broker_items_count = applied_broker_count
        res.readiness_percentage = readiness_pct
        res.has_blocking_issues = has_blocking
        res.overall_status = overall_status
        res.import_file_code = import_file_code
        res.total_broker_fees_egp = total_broker_fees
        return res

    @staticmethod
    def create_consultation(
        db: Session, session_in: CustomsConsultationCreate, modified_by: Optional[str] = "Customs Specialist"
    ) -> CustomsConsultationResponse:
        validate_broker_exists(db, session_in.broker_id)
        validate_checklist_items(session_in.checklist_items)

        # Prevent duplicate consultation creation for the same import file
        if session_in.import_file_id:
            existing = CustomsConsultationRepository.get_all(db, import_file_id=session_in.import_file_id)
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"يوجد بالفعل دراسة استشارة جمركية محفوظة لهذا الملف. يرجى الذهاب لتعديل الدراسة الحالية بدلاً من إنشاء دراسة جديدة.",
                )

        db_session = CustomsConsultationRepository.create(db, session_in)
        
        # Auto-sync lifecycle stage to STEP_02 (Customs Studies) and set STEP_03 as next action
        if db_session.import_file_id:
            from modules.lifecycle_board.service import sync_consultation_lifecycle_stage
            try:
                sync_consultation_lifecycle_stage(db, db_session.import_file_id)
            except Exception as e:
                print(f"[Warning] Could not sync lifecycle stage: {e}")

            # Event-Driven Scoped Budget Variance Check
            try:
                from modules.financial_approval.service import evaluate_and_record_budget_variance_service
                evaluate_and_record_budget_variance_service(
                    db, db_session.import_file_id, modified_by=modified_by or "Customs Specialist"
                )
            except Exception as e:
                print(f"[Warning] Could not evaluate budget variance: {e}")

        return CustomsConsultationService._compute_session_metrics(db, db_session)

    @staticmethod
    def get_consultation(db: Session, consultation_id: int) -> CustomsConsultationResponse:
        db_session = CustomsConsultationRepository.get_by_id(db, consultation_id)
        if not db_session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Customs Consultation study with ID '{consultation_id}' not found.",
            )
        return CustomsConsultationService._compute_session_metrics(db, db_session)

    @staticmethod
    def list_consultations(
        db: Session,
        include_inactive: bool = False,
        search: Optional[str] = None,
        broker_id: Optional[int] = None,
        import_file_id: Optional[int] = None,
        po_id: Optional[int] = None,
        project_id: Optional[int] = None,
        status: Optional[str] = None,
    ) -> List[CustomsConsultationResponse]:
        sessions = CustomsConsultationRepository.get_all(
            db,
            include_inactive=include_inactive,
            search=search,
            broker_id=broker_id,
            import_file_id=import_file_id,
            po_id=po_id,
            project_id=project_id,
            status=status,
        )

        # Batch preload ImportFile codes to eliminate N+1 queries
        imp_file_ids = {s.import_file_id for s in sessions if s.import_file_id}
        imp_codes_map = {}
        if imp_file_ids:
            from modules.import_files.model import ImportFile
            imp_records = db.query(ImportFile).filter(ImportFile.import_file_id.in_(imp_file_ids)).all()
            imp_codes_map = {
                f.import_file_id: (f.import_file_code or f.custom_file_number) for f in imp_records
            }

        return [
            CustomsConsultationService._compute_session_metrics(db, s, imp_codes_map)
            for s in sessions
        ]

    @staticmethod
    def update_consultation(
        db: Session,
        consultation_id: int,
        update_in: CustomsConsultationUpdate,
        modified_by: Optional[str] = "Customs Specialist",
    ) -> CustomsConsultationResponse:
        db_session = CustomsConsultationRepository.get_by_id(db, consultation_id)
        if not db_session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Customs Consultation study with ID '{consultation_id}' not found.",
            )

        if update_in.broker_id is not None:
            validate_broker_exists(db, update_in.broker_id)

        if update_in.checklist_items is not None:
            validate_checklist_items(update_in.checklist_items)

        updated_session = CustomsConsultationRepository.update(db, db_session, update_in)
        
        # Auto-sync lifecycle stage to STEP_02 (Customs Studies) and set STEP_03 as next action
        if updated_session.import_file_id:
            from modules.lifecycle_board.service import sync_consultation_lifecycle_stage
            try:
                sync_consultation_lifecycle_stage(db, updated_session.import_file_id)
            except Exception as e:
                print(f"[Warning] Could not sync lifecycle stage: {e}")

            # Event-Driven Scoped Budget Variance Check
            try:
                from modules.financial_approval.service import evaluate_and_record_budget_variance_service
                evaluate_and_record_budget_variance_service(
                    db, updated_session.import_file_id, modified_by=modified_by or "Customs Specialist"
                )
            except Exception as e:
                print(f"[Warning] Could not evaluate budget variance: {e}")

        return CustomsConsultationService._compute_session_metrics(db, updated_session)

    @staticmethod
    def soft_delete_consultation(db: Session, consultation_id: int) -> CustomsConsultationResponse:
        db_session = CustomsConsultationRepository.get_by_id(db, consultation_id)
        if not db_session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Customs Consultation study with ID '{consultation_id}' not found.",
            )
        deleted_session = CustomsConsultationRepository.soft_delete(db, db_session)
        return CustomsConsultationService._compute_session_metrics(db, deleted_session)

    @staticmethod
    def restore_consultation(db: Session, consultation_id: int) -> CustomsConsultationResponse:
        db_session = CustomsConsultationRepository.get_by_id(db, consultation_id)
        if not db_session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Customs Consultation study with ID '{consultation_id}' not found.",
            )
        restored_session = CustomsConsultationRepository.restore(db, db_session)
        return CustomsConsultationService._compute_session_metrics(db, restored_session)

    @staticmethod
    def clone_consultation(
        db: Session, consultation_id: int, schema: CloneConsultationRequest
    ) -> CustomsConsultationResponse:
        original = CustomsConsultationRepository.get_by_id(db, consultation_id)
        if not original:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Customs Consultation with ID '{consultation_id}' not found.",
            )

        target_code = schema.new_consultation_code
        if not target_code:
            target_code = f"{original.consultation_code}-CLONE"
            idx = 1
            while db.query(CustomsConsultationSession).filter(CustomsConsultationSession.consultation_code == target_code).first():
                target_code = f"{original.consultation_code}-CLONE{idx}"
                idx += 1
        else:
            existing = db.query(CustomsConsultationSession).filter(CustomsConsultationSession.consultation_code == target_code).first()
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"كود الاستشارة الجمركية '{target_code}' مستخدم بالفعل.",
                )

        new_sess = CustomsConsultationSession(
            consultation_code=target_code,
            title=schema.new_title,
            broker_id=original.broker_id,
            broker_name=original.broker_name,
            broker_contact_person=original.broker_contact_person,
            broker_price_list_id=original.broker_price_list_id,
            import_file_id=schema.target_import_file_id or original.import_file_id,
            po_id=None,
            project_id=original.project_id,
            overall_status="Draft",
            has_blocking_issues=False,
            readiness_percentage=0.0,
            estimated_duties_egp=original.estimated_duties_egp,
            total_broker_fees_egp=original.total_broker_fees_egp,
            notes=schema.notes or f"مستنسخة من: {original.consultation_code}",
            is_active=True,
            cloned_from_id=original.consultation_id,
            cloned_from_code=original.consultation_code,
        )
        db.add(new_sess)
        db.flush()

        from modules.customs_consultation.model import CustomsChecklistItem, CustomsBrokerQuoteItem
        if schema.copy_checklist_items:
            for chk in original.checklist_items:
                cloned_chk = CustomsChecklistItem(
                    consultation_id=new_sess.consultation_id,
                    document_type=chk.document_type,
                    hs_code=chk.hs_code,
                    is_required=chk.is_required,
                    required_text=chk.required_text,
                    responsible_party=chk.responsible_party,
                    is_blocking_shipment=chk.is_blocking_shipment,
                    status="Pending",
                    remarks=chk.remarks,
                    regulatory_agency=chk.regulatory_agency,
                    corrective_action_required=chk.corrective_action_required,
                )
                db.add(cloned_chk)

        if schema.copy_broker_quote_items:
            for quote_item in original.broker_quote_items:
                cloned_q = CustomsBrokerQuoteItem(
                    consultation_id=new_sess.consultation_id,
                    expense_type_id=quote_item.expense_type_id,
                    expense_name=quote_item.expense_name,
                    category=quote_item.category,
                    unit_type=quote_item.unit_type,
                    unit_price=quote_item.unit_price,
                    currency=quote_item.currency,
                    qty=quote_item.qty,
                    is_applicable=quote_item.is_applicable,
                    total_amount=quote_item.total_amount,
                    notes=quote_item.notes,
                )
                db.add(cloned_q)

        db.commit()
        db.refresh(new_sess)
        return CustomsConsultationService._compute_session_metrics(db, new_sess)


    @staticmethod
    def recalculate_from_reconciliation_service(
        db: Session,
        import_file_id: int,
        exchange_rate: Optional[float] = None,
        freight_egp: Optional[float] = 0.0,
        insurance_egp: Optional[float] = 0.0,
        estimate_date: Optional[date] = None,
    ):
        """
        Recalculates Egyptian Customs duties, taxes, and fees for an import file based on
        the final reconciled commercial invoice and packing list (POPackingReconciliationSession),
        and compares with baseline preliminary PO values to compute liquidity variance forecast.
        """
        from modules.import_files.model import ImportFile
        from modules.import_documentation.model import POPackingReconciliationSession
        from modules.purchase_orders.model import PurchaseOrder, POLineItem
        from modules.customs_tariff.model import CustomsTariff, PreferentialAgreement
        from modules.customs_consultation.schemas import (
            CustomsRecalculationResponse,
            LineVarianceComparison,
        )

        imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
        if not imp_file:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"ملف الشحنة رقم {import_file_id} غير موجود.",
            )

        calc_date = estimate_date or date.today()
        fx_rate = exchange_rate if (exchange_rate and exchange_rate > 0) else float(getattr(imp_file, "exchange_rate", 50.0) or 50.0)
        freight_val = float(freight_egp or 0.0)
        ins_val = float(insurance_egp or 0.0)

        # 1. Fetch Reconciliation Session (Final Approved Commercial Invoice & Packing List)
        reconcil_session = (
            db.query(POPackingReconciliationSession)
            .filter(
                POPackingReconciliationSession.import_file_id == import_file_id,
                POPackingReconciliationSession.is_active == True,
            )
            .order_by(POPackingReconciliationSession.session_id.desc())
            .first()
        )

        final_items = []
        final_inv_no = None
        is_reconciled = False
        reconcil_id = None

        if reconcil_session and reconcil_session.reconciled_invoice_items:
            final_items = reconcil_session.reconciled_invoice_items
            final_inv_no = reconcil_session.final_invoice_number
            is_reconciled = bool(reconcil_session.is_safe_for_certification or reconcil_session.overall_status in ("FULLY_MATCHED", "RECONCILED", "APPROVED"))
            reconcil_id = reconcil_session.session_id

        # 2. Fetch Preliminary PO Line Items (Baseline)
        prelim_items = []
        pos = (
            db.query(PurchaseOrder)
            .filter(
                PurchaseOrder.import_file_id == import_file_id,
                PurchaseOrder.is_active == True,
            )
            .all()
        )
        for po in pos:
            for item in (getattr(po, "line_items", []) or []):
                prelim_items.append(item)

        # Build Tariff Lookups
        tariffs = db.query(CustomsTariff).filter(CustomsTariff.is_active == True).all()
        tariff_map = {t.hs_code.replace(".", "").strip(): t for t in tariffs}

        def get_tariff(hs: str) -> Optional[CustomsTariff]:
            clean_hs = (hs or "").replace(".", "").strip()
            return tariff_map.get(clean_hs)

        # If no reconciled items exist yet, use preliminary items as current final base
        lines_comparison: List[LineVarianceComparison] = []

        total_prelim_fob_egp = 0.0
        total_final_fob_egp = 0.0
        total_prelim_duty_egp = 0.0
        total_final_duty_egp = 0.0
        total_prelim_vat_egp = 0.0
        total_final_vat_egp = 0.0
        total_prelim_taxes_egp = 0.0
        total_final_taxes_egp = 0.0

        if final_items:
            # Reconciled final items available
            for idx, f_item in enumerate(final_items):
                item_name = f_item.get("item_name") or f"Item #{idx + 1}"
                hs_code = str(f_item.get("hs_code") or "6802.99")
                origin = f_item.get("country_of_origin") or "CN"
                final_q = float(f_item.get("quantity") or 0.0)
                final_u_price = float(f_item.get("unit_price") or 0.0)
                final_fob_foreign = float(f_item.get("total_price") or (final_q * final_u_price))
                final_fob_egp_item = final_fob_foreign * fx_rate

                # Match with corresponding preliminary item if exists
                matched_p = None
                if idx < len(prelim_items):
                    matched_p = prelim_items[idx]
                elif prelim_items:
                    matched_p = next(
                        (
                            p for p in prelim_items
                            if ((p.tariff.hs_code if p.tariff else getattr(p, 'hs_code', '')) or '').replace('.', '') == hs_code.replace('.', '')
                        ),
                        None,
                    )

                prelim_q = float(matched_p.quantity) if matched_p else final_q
                prelim_u_price = float(matched_p.unit_price) if matched_p else final_u_price
                prelim_fob_foreign = float(matched_p.total_price) if matched_p else final_fob_foreign
                prelim_fob_egp_item = prelim_fob_foreign * fx_rate

                t = get_tariff(hs_code)
                duty_rate = float(t.customs_duty_rate) if t else 10.0
                vat_rate = float(t.vat_rate) if t else 14.0
                sch_rate = float(t.schedule_tax_rate) if t else 0.0
                dev_rate = float(t.development_fee_rate) if t else 0.0
                svc_rate = float(t.customs_service_fee_rate) if (t and t.customs_service_fee_rate is not None) else 1.0

                # Allocating proportional freight & insurance
                prop_freight_final = freight_val / len(final_items) if len(final_items) > 0 else 0.0
                prop_ins_final = ins_val / len(final_items) if len(final_items) > 0 else 0.0
                final_cif_item = final_fob_egp_item + prop_freight_final + prop_ins_final

                prop_freight_prelim = freight_val / (len(prelim_items) or 1)
                prop_ins_prelim = ins_val / (len(prelim_items) or 1)
                prelim_cif_item = prelim_fob_egp_item + prop_freight_prelim + prop_ins_prelim

                # Preliminary tax calculation
                p_duty = round(prelim_cif_item * (duty_rate / 100.0), 2)
                p_vat_base = prelim_cif_item + p_duty
                p_vat = round(p_vat_base * (vat_rate / 100.0), 2)
                p_sch = round(prelim_cif_item * (sch_rate / 100.0), 2)
                p_dev = round(prelim_cif_item * (dev_rate / 100.0), 2)
                p_svc = round(prelim_cif_item * (svc_rate / 100.0), 2)
                p_total = round(p_duty + p_vat + p_sch + p_dev + p_svc, 2)

                # Final tax calculation
                f_duty = round(final_cif_item * (duty_rate / 100.0), 2)
                f_vat_base = final_cif_item + f_duty
                f_vat = round(f_vat_base * (vat_rate / 100.0), 2)
                f_sch = round(final_cif_item * (sch_rate / 100.0), 2)
                f_dev = round(final_cif_item * (dev_rate / 100.0), 2)
                f_svc = round(final_cif_item * (svc_rate / 100.0), 2)
                f_total = round(f_duty + f_vat + f_sch + f_dev + f_svc, 2)

                line = LineVarianceComparison(
                    item_name=item_name,
                    hs_code=hs_code,
                    country_of_origin=origin,
                    preliminary_qty=prelim_q,
                    final_qty=final_q,
                    qty_variance=round(final_q - prelim_q, 2),
                    preliminary_unit_price=prelim_u_price,
                    final_unit_price=final_u_price,
                    unit_price_variance=round(final_u_price - prelim_u_price, 2),
                    preliminary_fob_egp=round(prelim_fob_egp_item, 2),
                    final_fob_egp=round(final_fob_egp_item, 2),
                    fob_variance_egp=round(final_fob_egp_item - prelim_fob_egp_item, 2),
                    preliminary_cif_egp=round(prelim_cif_item, 2),
                    final_cif_egp=round(final_cif_item, 2),
                    cif_variance_egp=round(final_cif_item - prelim_cif_item, 2),
                    duty_rate_pct=duty_rate,
                    preliminary_duty_egp=p_duty,
                    final_duty_egp=f_duty,
                    duty_variance_egp=round(f_duty - p_duty, 2),
                    vat_rate_pct=vat_rate,
                    preliminary_vat_egp=p_vat,
                    final_vat_egp=f_vat,
                    vat_variance_egp=round(f_vat - p_vat, 2),
                    preliminary_total_taxes_egp=p_total,
                    final_total_taxes_egp=f_total,
                    total_taxes_variance_egp=round(f_total - p_total, 2),
                )
                lines_comparison.append(line)

                total_prelim_fob_egp += prelim_fob_egp_item
                total_final_fob_egp += final_fob_egp_item
                total_prelim_duty_egp += p_duty
                total_final_duty_egp += f_duty
                total_prelim_vat_egp += p_vat
                total_final_vat_egp += f_vat
                total_prelim_taxes_egp += p_total
                total_final_taxes_egp += f_total
        else:
            # Fallback to preliminary PO line items
            for p in prelim_items:
                item_name = getattr(p, "description_ar", "") or getattr(p, "item_name", "Item")
                hs_code = (p.tariff.hs_code if getattr(p, 'tariff', None) else getattr(p, "hs_code", "")) or "6802.99"
                origin = getattr(p, "country_of_origin", "CN") or "CN"
                q = float(p.quantity or 0.0)
                u_price = float(p.unit_price or 0.0)
                fob_foreign = float(p.total_price or (q * u_price))
                fob_egp_item = fob_foreign * fx_rate

                t = get_tariff(hs_code)
                duty_rate = float(t.customs_duty_rate) if t else 10.0
                vat_rate = float(t.vat_rate) if t else 14.0
                sch_rate = float(t.schedule_tax_rate) if t else 0.0
                dev_rate = float(t.development_fee_rate) if t else 0.0
                svc_rate = float(t.customs_service_fee_rate) if (t and t.customs_service_fee_rate is not None) else 1.0

                prop_freight = freight_val / (len(prelim_items) or 1)
                prop_ins = ins_val / (len(prelim_items) or 1)
                cif_item = fob_egp_item + prop_freight + prop_ins

                duty = round(cif_item * (duty_rate / 100.0), 2)
                vat_base = cif_item + duty
                vat = round(vat_base * (vat_rate / 100.0), 2)
                sch = round(cif_item * (sch_rate / 100.0), 2)
                dev = round(cif_item * (dev_rate / 100.0), 2)
                svc = round(cif_item * (svc_rate / 100.0), 2)
                total = round(duty + vat + sch + dev + svc, 2)

                line = LineVarianceComparison(
                    item_name=item_name,
                    hs_code=hs_code,
                    country_of_origin=origin,
                    preliminary_qty=q,
                    final_qty=q,
                    qty_variance=0.0,
                    preliminary_unit_price=u_price,
                    final_unit_price=u_price,
                    unit_price_variance=0.0,
                    preliminary_fob_egp=round(fob_egp_item, 2),
                    final_fob_egp=round(fob_egp_item, 2),
                    fob_variance_egp=0.0,
                    preliminary_cif_egp=round(cif_item, 2),
                    final_cif_egp=round(cif_item, 2),
                    cif_variance_egp=0.0,
                    duty_rate_pct=duty_rate,
                    preliminary_duty_egp=duty,
                    final_duty_egp=duty,
                    duty_variance_egp=0.0,
                    vat_rate_pct=vat_rate,
                    preliminary_vat_egp=vat,
                    final_vat_egp=vat,
                    vat_variance_egp=0.0,
                    preliminary_total_taxes_egp=total,
                    final_total_taxes_egp=total,
                    total_taxes_variance_egp=0.0,
                )
                lines_comparison.append(line)

                total_prelim_fob_egp += fob_egp_item
                total_final_fob_egp += fob_egp_item
                total_prelim_duty_egp += duty
                total_final_duty_egp += duty
                total_prelim_vat_egp += vat
                total_final_vat_egp += vat
                total_prelim_taxes_egp += total
                total_final_taxes_egp += total

        total_prelim_cif_egp = total_prelim_fob_egp + freight_val + ins_val
        total_final_cif_egp = total_final_fob_egp + freight_val + ins_val

        taxes_variance = round(total_final_taxes_egp - total_prelim_taxes_egp, 2)
        pct_change = round((taxes_variance / total_prelim_taxes_egp * 100.0), 2) if total_prelim_taxes_egp > 0 else 0.0

        forecast_status = "Exact Match"
        if taxes_variance > 0:
            forecast_status = "Increased Cost"
        elif taxes_variance < 0:
            forecast_status = "Reduced Cost"

        return CustomsRecalculationResponse(
            import_file_id=import_file_id,
            import_file_code=imp_file.import_file_code or f"IMP-{import_file_id:04d}",
            final_invoice_number=final_inv_no or imp_file.pi_number,
            reconciliation_session_id=reconcil_id,
            is_reconciled=is_reconciled,
            source_description="الفاتورة وقائمة التعبئة النهائية المعتمدة" if is_reconciled else "أمر الشراء التقديري (مبدئي)",
            exchange_rate=round(fx_rate, 4),
            estimate_date=calc_date,
            preliminary_fob_egp=round(total_prelim_fob_egp, 2),
            final_fob_egp=round(total_final_fob_egp, 2),
            fob_variance_egp=round(total_final_fob_egp - total_prelim_fob_egp, 2),
            preliminary_cif_egp=round(total_prelim_cif_egp, 2),
            final_cif_egp=round(total_final_cif_egp, 2),
            cif_variance_egp=round(total_final_cif_egp - total_prelim_cif_egp, 2),
            preliminary_duty_egp=round(total_prelim_duty_egp, 2),
            final_duty_egp=round(total_final_duty_egp, 2),
            duty_variance_egp=round(total_final_duty_egp - total_prelim_duty_egp, 2),
            preliminary_vat_egp=round(total_prelim_vat_egp, 2),
            final_vat_egp=round(total_final_vat_egp, 2),
            vat_variance_egp=round(total_final_vat_egp - total_prelim_vat_egp, 2),
            preliminary_total_taxes_egp=round(total_prelim_taxes_egp, 2),
            final_total_taxes_egp=round(total_final_taxes_egp, 2),
            total_taxes_variance_egp=taxes_variance,
            variance_percentage=pct_change,
            forecast_status=forecast_status,
            comparison_lines=lines_comparison,
        )

