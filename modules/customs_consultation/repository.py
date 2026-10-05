"""
Customs Consultation & Broker Price Lists Database Repository (BP-009)
"""

from datetime import datetime, date, timezone
from typing import List, Optional
from sqlalchemy.orm import Session
from modules.customs_consultation.model import (
    ClearanceExpenseType,
    BrokerPriceList,
    BrokerPriceListItem,
    CustomsConsultationSession,
    CustomsChecklistItem,
    CustomsBrokerQuoteItem,
)
from modules.customs_consultation.schemas import (
    ClearanceExpenseTypeCreate,
    ClearanceExpenseTypeUpdate,
    BrokerPriceListCreate,
    BrokerPriceListUpdate,
    CustomsConsultationCreate,
    CustomsConsultationUpdate,
)


# ==============================================================================
# Clearance Expense Types Repository
# ==============================================================================

class ClearanceExpenseTypeRepository:

    @staticmethod
    def generate_expense_code(db: Session) -> str:
        last_item = (
            db.query(ClearanceExpenseType)
            .order_by(ClearanceExpenseType.expense_id.desc())
            .first()
        )
        if last_item:
            try:
                num = int(last_item.expense_code.replace("EXP-", "")) + 1
            except ValueError:
                num = last_item.expense_id + 1
        else:
            num = 1
        return f"EXP-{num:03d}"

    @staticmethod
    def create(db: Session, schema: ClearanceExpenseTypeCreate) -> ClearanceExpenseType:
        code = schema.expense_code or ClearanceExpenseTypeRepository.generate_expense_code(db)
        db_obj = ClearanceExpenseType(
            expense_code=code,
            name_ar=schema.name_ar,
            name_en=schema.name_en,
            category=schema.category,
            default_unit=schema.default_unit,
            default_currency=schema.default_currency,
            display_order=schema.display_order,
            is_active=schema.is_active,
        )
        db.add(db_obj)
        db.commit()
        db.refresh(db_obj)
        return db_obj

    @staticmethod
    def get_by_id(db: Session, expense_id: int) -> Optional[ClearanceExpenseType]:
        return db.query(ClearanceExpenseType).filter(ClearanceExpenseType.expense_id == expense_id).first()

    @staticmethod
    def get_by_code(db: Session, code: str) -> Optional[ClearanceExpenseType]:
        return db.query(ClearanceExpenseType).filter(ClearanceExpenseType.expense_code == code).first()

    @staticmethod
    def get_all(
        db: Session,
        include_inactive: bool = False,
        categories: Optional[List[str]] = None,
        search: Optional[str] = None,
    ) -> List[ClearanceExpenseType]:
        query = db.query(ClearanceExpenseType)
        if not include_inactive:
            query = query.filter(ClearanceExpenseType.is_active == True)
        if categories:
            query = query.filter(ClearanceExpenseType.category.in_(categories))
        if search:
            pat = f"%{search}%"
            query = query.filter(
                (ClearanceExpenseType.expense_code.ilike(pat))
                | (ClearanceExpenseType.name_ar.ilike(pat))
                | (ClearanceExpenseType.name_en.ilike(pat))
            )
        return query.order_by(ClearanceExpenseType.display_order.asc(), ClearanceExpenseType.expense_id.asc()).all()

    @staticmethod
    def update(db: Session, db_obj: ClearanceExpenseType, schema: ClearanceExpenseTypeUpdate) -> ClearanceExpenseType:
        update_data = schema.model_dump(exclude_unset=True)
        for k, v in update_data.items():
            setattr(db_obj, k, v)
        db_obj.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(db_obj)
        return db_obj

    @staticmethod
    def delete(db: Session, db_obj: ClearanceExpenseType) -> ClearanceExpenseType:
        db_obj.is_active = False
        db_obj.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(db_obj)
        return db_obj


# ==============================================================================
# Broker Price Lists Repository
# ==============================================================================

class BrokerPriceListRepository:

    @staticmethod
    def generate_price_list_code(db: Session) -> str:
        current_year = datetime.now(timezone.utc).year
        prefix = f"PL-{current_year}-"
        last_pl = (
            db.query(BrokerPriceList)
            .filter(BrokerPriceList.price_list_code.like(f"{prefix}%"))
            .order_by(BrokerPriceList.price_list_id.desc())
            .first()
        )
        if last_pl:
            try:
                num = int(last_pl.price_list_code.split("-")[-1]) + 1
            except ValueError:
                num = 1
        else:
            num = 1
        return f"{prefix}{num:03d}"

    @staticmethod
    def create(db: Session, schema: BrokerPriceListCreate) -> BrokerPriceList:
        code = BrokerPriceListRepository.generate_price_list_code(db)
        db_pl = BrokerPriceList(
            price_list_code=code,
            title=schema.title,
            broker_id=schema.broker_id,
            broker_name=schema.broker_name,
            port_name=schema.port_name,
            effective_from=schema.effective_from,
            effective_to=schema.effective_to,
            version=schema.version,
            is_active=schema.is_active,
            notes=schema.notes,
        )
        db.add(db_pl)
        db.flush()

        for itm in schema.items:
            db_itm = BrokerPriceListItem(
                price_list_id=db_pl.price_list_id,
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
            db.add(db_itm)

        db.commit()
        db.refresh(db_pl)
        return db_pl

    @staticmethod
    def get_by_id(db: Session, price_list_id: int) -> Optional[BrokerPriceList]:
        return db.query(BrokerPriceList).filter(BrokerPriceList.price_list_id == price_list_id).first()

    @staticmethod
    def get_all(
        db: Session,
        include_inactive: bool = False,
        broker_id: Optional[int] = None,
        search: Optional[str] = None,
    ) -> List[BrokerPriceList]:
        query = db.query(BrokerPriceList)
        if not include_inactive:
            query = query.filter(BrokerPriceList.is_active == True)
        if broker_id:
            query = query.filter(BrokerPriceList.broker_id == broker_id)
        if search:
            pat = f"%{search}%"
            query = query.filter(
                (BrokerPriceList.price_list_code.ilike(pat))
                | (BrokerPriceList.title.ilike(pat))
                | (BrokerPriceList.broker_name.ilike(pat))
            )
        return query.order_by(BrokerPriceList.effective_from.desc(), BrokerPriceList.price_list_id.desc()).all()

    @staticmethod
    def get_active_by_broker(db: Session, broker_id: int, target_date: Optional[date] = None) -> Optional[BrokerPriceList]:
        """
        Gets the active price list for a broker valid on a specific target date (or today).
        """
        if not target_date:
            target_date = date.today()

        query = (
            db.query(BrokerPriceList)
            .filter(
                BrokerPriceList.broker_id == broker_id,
                BrokerPriceList.is_active == True,
                BrokerPriceList.effective_from <= target_date,
            )
            .filter(
                (BrokerPriceList.effective_to == None) | (BrokerPriceList.effective_to >= target_date)
            )
            .order_by(BrokerPriceList.effective_from.desc(), BrokerPriceList.price_list_id.desc())
        )
        return query.first()

    @staticmethod
    def update(db: Session, db_pl: BrokerPriceList, schema: BrokerPriceListUpdate) -> BrokerPriceList:
        update_data = schema.model_dump(exclude_unset=True, exclude={"items"})
        for k, v in update_data.items():
            setattr(db_pl, k, v)

        if schema.items is not None:
            # Replace items
            db.query(BrokerPriceListItem).filter(BrokerPriceListItem.price_list_id == db_pl.price_list_id).delete()
            for itm in schema.items:
                db_itm = BrokerPriceListItem(
                    price_list_id=db_pl.price_list_id,
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
                db.add(db_itm)

        db_pl.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(db_pl)
        return db_pl

    @staticmethod
    def soft_delete(db: Session, db_pl: BrokerPriceList) -> BrokerPriceList:
        db_pl.is_active = False
        db_pl.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(db_pl)
        return db_pl


# ==============================================================================
# Customs Consultation Session Repository
# ==============================================================================

class CustomsConsultationRepository:

    @staticmethod
    def generate_consultation_code(db: Session) -> str:
        """
        Generates auto-incremented consultation code in format CUS-YYYY-XXX (e.g. CUS-2026-001).
        """
        current_year = datetime.now(timezone.utc).year
        prefix = f"CUS-{current_year}-"
        
        last_session = (
            db.query(CustomsConsultationSession)
            .filter(CustomsConsultationSession.consultation_code.like(f"{prefix}%"))
            .order_by(CustomsConsultationSession.consultation_id.desc())
            .first()
        )
        
        if last_session:
            try:
                last_num = int(last_session.consultation_code.split("-")[-1])
                new_num = last_num + 1
            except ValueError:
                new_num = 1
        else:
            new_num = 1

        return f"{prefix}{new_num:03d}"

    @staticmethod
    def create(db: Session, session_in: CustomsConsultationCreate) -> CustomsConsultationSession:
        code = CustomsConsultationRepository.generate_consultation_code(db)
        
        # Calculate total applied broker fees
        total_broker_fees = sum(
            (itm.unit_price * itm.qty) for itm in session_in.broker_quote_items if itm.is_applicable
        )

        db_session = CustomsConsultationSession(
            consultation_code=code,
            title=session_in.title,
            broker_id=session_in.broker_id,
            broker_name=session_in.broker_name,
            broker_contact_person=session_in.broker_contact_person,
            broker_price_list_id=session_in.broker_price_list_id,
            import_file_id=session_in.import_file_id,
            po_id=session_in.po_id,
            project_id=session_in.project_id,
            overall_status=session_in.overall_status,
            estimated_duties_egp=session_in.estimated_duties_egp,
            total_broker_fees_egp=total_broker_fees or session_in.total_broker_fees_egp,
            notes=session_in.notes,
            is_active=True,
        )

        db.add(db_session)
        db.flush()  # get consultation_id

        # Add checklist items
        for item_in in session_in.checklist_items:
            db_item = CustomsChecklistItem(
                consultation_id=db_session.consultation_id,
                document_type=item_in.document_type,
                hs_code=item_in.hs_code,
                is_required=item_in.is_required,
                required_text=item_in.required_text,
                is_blocking_shipment=item_in.is_blocking_shipment,
                responsible_party=item_in.responsible_party,
                status=item_in.status,
                received_date=item_in.received_date,
                verified_date=item_in.verified_date,
                regulatory_agency=item_in.regulatory_agency,
                remarks=item_in.remarks,
                corrective_action_required=item_in.corrective_action_required,
            )
            db.add(db_item)

        # Add broker quote items (frozen snapshot)
        for quote_in in session_in.broker_quote_items:
            line_total = (quote_in.unit_price * quote_in.qty) if quote_in.is_applicable else 0.0
            db_quote = CustomsBrokerQuoteItem(
                consultation_id=db_session.consultation_id,
                expense_type_id=quote_in.expense_type_id,
                expense_name=quote_in.expense_name,
                category=quote_in.category,
                unit_type=quote_in.unit_type,
                unit_price=quote_in.unit_price,
                currency=quote_in.currency,
                qty=quote_in.qty,
                is_applicable=quote_in.is_applicable,
                total_amount=line_total,
                notes=quote_in.notes,
            )
            db.add(db_quote)

        db.flush()
        return db_session

    @staticmethod
    def get_by_id(db: Session, consultation_id: int) -> Optional[CustomsConsultationSession]:
        return (
            db.query(CustomsConsultationSession)
            .filter(CustomsConsultationSession.consultation_id == consultation_id)
            .first()
        )

    @staticmethod
    def get_all(
        db: Session,
        include_inactive: bool = False,
        search: Optional[str] = None,
        broker_id: Optional[int] = None,
        import_file_id: Optional[int] = None,
        po_id: Optional[int] = None,
        project_id: Optional[int] = None,
        status: Optional[str] = None,
    ) -> List[CustomsConsultationSession]:
        query = db.query(CustomsConsultationSession)

        if not include_inactive:
            query = query.filter(CustomsConsultationSession.is_active == True)

        if broker_id:
            query = query.filter(CustomsConsultationSession.broker_id == broker_id)

        if import_file_id:
            query = query.filter(CustomsConsultationSession.import_file_id == import_file_id)

        if po_id:
            query = query.filter(CustomsConsultationSession.po_id == po_id)

        if project_id:
            query = query.filter(CustomsConsultationSession.project_id == project_id)

        if status:
            query = query.filter(CustomsConsultationSession.overall_status == status)

        if search:
            search_pattern = f"%{search}%"
            query = query.filter(
                (CustomsConsultationSession.consultation_code.ilike(search_pattern))
                | (CustomsConsultationSession.title.ilike(search_pattern))
                | (CustomsConsultationSession.broker_name.ilike(search_pattern))
            )

        return query.order_by(CustomsConsultationSession.consultation_id.desc()).all()

    list_consultations = get_all

    @staticmethod
    def update(
        db: Session, db_session: CustomsConsultationSession, update_in: CustomsConsultationUpdate
    ) -> CustomsConsultationSession:
        update_data = update_in.model_dump(
            exclude_unset=True, exclude={"checklist_items", "broker_quote_items"}
        )

        for field, value in update_data.items():
            setattr(db_session, field, value)

        if update_in.checklist_items is not None:
            # Replace checklist items
            db.query(CustomsChecklistItem).filter(
                CustomsChecklistItem.consultation_id == db_session.consultation_id
            ).delete()

            for item_in in update_in.checklist_items:
                db_item = CustomsChecklistItem(
                    consultation_id=db_session.consultation_id,
                    document_type=item_in.document_type,
                    hs_code=item_in.hs_code,
                    is_required=item_in.is_required,
                    required_text=item_in.required_text,
                    is_blocking_shipment=item_in.is_blocking_shipment,
                    responsible_party=item_in.responsible_party,
                    status=item_in.status,
                    received_date=item_in.received_date,
                    verified_date=item_in.verified_date,
                    regulatory_agency=item_in.regulatory_agency,
                    remarks=item_in.remarks,
                    corrective_action_required=item_in.corrective_action_required,
                )
                db.add(db_item)

        if update_in.broker_quote_items is not None:
            # Replace quote items with updated frozen snapshot
            db.query(CustomsBrokerQuoteItem).filter(
                CustomsBrokerQuoteItem.consultation_id == db_session.consultation_id
            ).delete()

            total_broker_fees = 0.0
            for quote_in in update_in.broker_quote_items:
                line_total = (quote_in.unit_price * quote_in.qty) if quote_in.is_applicable else 0.0
                if quote_in.is_applicable:
                    total_broker_fees += line_total
                db_quote = CustomsBrokerQuoteItem(
                    consultation_id=db_session.consultation_id,
                    expense_type_id=quote_in.expense_type_id,
                    expense_name=quote_in.expense_name,
                    category=quote_in.category,
                    unit_type=quote_in.unit_type,
                    unit_price=quote_in.unit_price,
                    currency=quote_in.currency,
                    qty=quote_in.qty,
                    is_applicable=quote_in.is_applicable,
                    total_amount=line_total,
                    notes=quote_in.notes,
                )
                db.add(db_quote)
            db_session.total_broker_fees_egp = total_broker_fees

        db_session.updated_at = datetime.now(timezone.utc)
        db.flush()
        # Child rows were replaced through bulk deletes: reload the collections on next access.
        db.expire(db_session, ["checklist_items", "broker_quote_items"])
        return db_session

    @staticmethod
    def soft_delete(db: Session, db_session: CustomsConsultationSession) -> CustomsConsultationSession:
        db_session.is_active = False
        db_session.updated_at = datetime.now(timezone.utc)
        db.flush()
        return db_session

    @staticmethod
    def restore(db: Session, db_session: CustomsConsultationSession) -> CustomsConsultationSession:
        db_session.is_active = True
        db_session.updated_at = datetime.now(timezone.utc)
        db.flush()
        return db_session

    # ── Cross-module reads used by the consultation service ─────────────────────

    @staticmethod
    def latest_reconciliation(db: Session, import_file_id: int):
        """Latest active PO / packing reconciliation session (final invoice) of the import file."""
        from modules.import_documentation.model import POPackingReconciliationSession

        return (
            db.query(POPackingReconciliationSession)
            .filter(
                POPackingReconciliationSession.import_file_id == import_file_id,
                POPackingReconciliationSession.is_active == True,
            )
            .order_by(POPackingReconciliationSession.session_id.desc())
            .first()
        )

    @staticmethod
    def active_po_line_items(db: Session, import_file_id: int) -> list:
        """Line items of the active purchase orders linked to the import file, in PO / line order."""
        from modules.purchase_orders.model import POLineItem, PurchaseOrder

        from sqlalchemy.orm import joinedload

        return (
            db.query(POLineItem)
            .join(PurchaseOrder, POLineItem.po_id == PurchaseOrder.po_id)
            .options(
                joinedload(POLineItem.tariff),
                joinedload(POLineItem.purchase_order).joinedload(PurchaseOrder.currency),
            )
            .filter(PurchaseOrder.import_file_id == import_file_id, PurchaseOrder.is_active == True)
            .order_by(PurchaseOrder.po_id, POLineItem.item_id)
            .all()
        )
