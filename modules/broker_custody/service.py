from datetime import datetime, timezone
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.broker_custody.model import (
    BrokerCustodyAdvance,
    BrokerExpenseItem,
    BrokerSettlementReceipt,
    CustomsBrokerAdvance,
)
from modules.broker_custody.repository import BrokerCustodyRepository
from modules.broker_custody.schemas import (
    BrokerCustodyAdvanceCreate,
    BrokerCustodyAdvanceUpdate,
    BrokerExpenseItemCreate,
    BrokerExpenseItemUpdate,
    BrokerSettlementReceiptCreate,
    BrokerSettlementReceiptUpdate,
    CustomsBrokerAdvanceCreate,
    CustomsBrokerAdvanceUpdate,
    CustomsSettlementVarianceResponse,
    ExpenseItemApprovalRequest,
    SettlementReconciliationResponse,
)
from modules.broker_custody.validators import (
    validate_approval_status,
    validate_broker_advance_create,
    validate_broker_advance_update,
    validate_broker_expense_create,
    validate_broker_expense_update,
    validate_customs_advance_create,
    validate_customs_advance_update,
    validate_settlement_receipt_create,
    validate_settlement_receipt_update,
)
from modules.common.validators import not_found
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile


class BrokerCustodyService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = BrokerCustodyRepository(db)

    # =======================================================================
    # Wave 1 Customs Broker Advances & Receipts Operations
    # =======================================================================
    def create_customs_advance(
        self, data: CustomsBrokerAdvanceCreate, current_user: str = "system"
    ) -> CustomsBrokerAdvance:
        validate_customs_advance_create(data)

        # 1. Verify Import File
        file = self.db.query(ImportFile).filter(ImportFile.import_file_id == data.import_file_id).first()
        if not file:
            raise not_found("ملف الشحنة", data.import_file_id)

        # 2. Verify Broker
        broker_name = data.broker_name
        if not broker_name:
            provider = (
                self.db.query(ExternalServiceProvider)
                .filter(ExternalServiceProvider.provider_id == data.broker_id)
                .first()
            )
            if not provider:
                raise not_found("المخلص الجمركي", data.broker_id)
            broker_name = provider.partner_name

        code = self.repo.generate_next_customs_advance_code()

        adv = CustomsBrokerAdvance(
            advance_code=code,
            import_file_id=data.import_file_id,
            broker_id=data.broker_id,
            broker_name=broker_name.strip(),
            advance_amount=data.advance_amount,
            disbursement_date=data.disbursement_date,
            payment_method=data.payment_method.strip().upper(),
            status="OPEN",
            settled_amount=0.0,
            remaining_balance=data.advance_amount,
            notes=data.notes.strip() if data.notes else None,
            created_by=current_user,
            updated_by=current_user,
        )

        self.repo.add_customs_advance(adv)
        self.db.commit()
        self.db.refresh(adv)
        return adv

    def get_customs_advance(self, adv_id: int) -> CustomsBrokerAdvance:
        adv = self.repo.get_customs_advance_by_id(adv_id)
        if not adv:
            raise not_found("عهدة المخلص الجمركي", adv_id)
        return adv

    def list_customs_advances(
        self,
        skip: int = 0,
        limit: int = 50,
        import_file_id: Optional[int] = None,
        broker_id: Optional[int] = None,
        status: Optional[str] = None,
        search: Optional[str] = None,
    ) -> Tuple[List[CustomsBrokerAdvance], int]:
        return self.repo.list_customs_advances(
            skip=skip,
            limit=limit,
            import_file_id=import_file_id,
            broker_id=broker_id,
            status=status,
            search=search,
        )

    def update_customs_advance(
        self, adv_id: int, data: CustomsBrokerAdvanceUpdate, current_user: str = "system"
    ) -> CustomsBrokerAdvance:
        adv = self.get_customs_advance(adv_id)
        updates = validate_customs_advance_update(data)

        for key, value in updates.items():
            setattr(adv, key, value)

        if "advance_amount" in updates:
            adv.remaining_balance = round(adv.advance_amount - adv.settled_amount, 2)

        adv.updated_by = current_user
        adv.updated_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(adv)
        return adv

    def delete_customs_advance(self, adv_id: int, current_user: str = "system") -> None:
        adv = self.get_customs_advance(adv_id)
        self.repo.soft_delete_customs_advance(adv, current_user=current_user)
        self.db.commit()

    def add_settlement_receipt(
        self, adv_id: int, data: BrokerSettlementReceiptCreate, current_user: str = "system"
    ) -> BrokerSettlementReceipt:
        adv = self.get_customs_advance(adv_id)
        validate_settlement_receipt_create(data)

        tax_withheld = round(data.amount * data.tax_withholding_rate, 2)
        net_amt = round(data.amount - tax_withheld, 2)

        receipt = BrokerSettlementReceipt(
            advance_id=adv.id,
            receipt_type=data.receipt_type.strip().upper(),
            receipt_number=data.receipt_number.strip(),
            receipt_date=data.receipt_date,
            issuing_entity=data.issuing_entity.strip(),
            amount=data.amount,
            tax_withholding_rate=data.tax_withholding_rate,
            tax_withheld_amount=tax_withheld,
            net_amount=net_amt,
            e_invoice_uuid=data.e_invoice_uuid.strip() if data.e_invoice_uuid else None,
            is_official_receipt=data.is_official_receipt,
            verification_status="PENDING",
            notes=data.notes.strip() if data.notes else None,
            created_by=current_user,
            updated_by=current_user,
        )

        self.repo.add_receipt(receipt)
        self.db.commit()
        self.db.refresh(receipt)

        self._recalculate_customs_advance_balance(adv)
        return receipt

    def update_settlement_receipt(
        self, receipt_id: int, data: BrokerSettlementReceiptUpdate, current_user: str = "system"
    ) -> BrokerSettlementReceipt:
        receipt = self.repo.get_receipt_by_id(receipt_id)
        if not receipt:
            raise not_found("إيصال تسوية العهدة", receipt_id)

        updates = validate_settlement_receipt_update(data)
        for key, value in updates.items():
            setattr(receipt, key, value)

        if "amount" in updates or "tax_withholding_rate" in updates:
            receipt.tax_withheld_amount = round(receipt.amount * receipt.tax_withholding_rate, 2)
            receipt.net_amount = round(receipt.amount - receipt.tax_withheld_amount, 2)

        receipt.updated_by = current_user
        receipt.updated_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(receipt)

        adv = self.get_customs_advance(receipt.advance_id)
        self._recalculate_customs_advance_balance(adv)
        return receipt

    def delete_settlement_receipt(self, receipt_id: int, current_user: str = "system") -> None:
        receipt = self.repo.get_receipt_by_id(receipt_id)
        if not receipt:
            raise not_found("إيصال التسوية", receipt_id)

        adv_id = receipt.advance_id
        self.repo.soft_delete_receipt(receipt, current_user=current_user)
        self.db.commit()

        adv = self.get_customs_advance(adv_id)
        self._recalculate_customs_advance_balance(adv)

    def reconcile_customs_settlement(self, adv_id: int) -> CustomsSettlementVarianceResponse:
        adv = self.get_customs_advance(adv_id)
        receipts = self.repo.list_receipts(adv.id)

        total_gross = sum(r.amount for r in receipts)
        total_tax_withheld = sum(r.tax_withheld_amount for r in receipts)
        total_net = sum(r.net_amount for r in receipts)
        variance = round(adv.advance_amount - total_net, 2)

        white_total = sum(r.net_amount for r in receipts if "WHITE" in r.receipt_type)
        red_total = sum(r.net_amount for r in receipts if "RED" in r.receipt_type)
        port_total = sum(r.net_amount for r in receipts if "PORT" in r.receipt_type)
        broker_total = sum(r.net_amount for r in receipts if "BROKER" in r.receipt_type)
        other_total = sum(r.net_amount for r in receipts if r.receipt_type not in {
            "WHITE_RECEIPT_CUSTOMS_DUTIES", "RED_RECEIPT_EXAMINATION_INSPECTION", "PORT_AUTHORITY_RECEIPT", "BROKER_SERVICE_FEE"
        })

        verified_cnt = sum(1 for r in receipts if r.verification_status == "VERIFIED")
        pending_cnt = sum(1 for r in receipts if r.verification_status == "PENDING")

        return CustomsSettlementVarianceResponse(
            advance_id=adv.id,
            advance_code=adv.advance_code,
            advance_amount=round(adv.advance_amount, 2),
            total_receipts_amount=round(total_gross, 2),
            total_tax_withheld=round(total_tax_withheld, 2),
            total_net_settled=round(total_net, 2),
            variance_amount=variance,
            status=adv.status,
            white_receipts_total=round(white_total, 2),
            red_receipts_total=round(red_total, 2),
            port_receipts_total=round(port_total, 2),
            broker_fees_total=round(broker_fees_total := broker_total, 2),
            other_receipts_total=round(other_total, 2),
            verified_receipts_count=verified_cnt,
            pending_receipts_count=pending_cnt,
        )

    def _recalculate_customs_advance_balance(self, adv: CustomsBrokerAdvance) -> None:
        receipts = self.repo.list_receipts(adv.id)
        total_net = sum(r.net_amount for r in receipts)

        adv.settled_amount = round(total_net, 2)
        adv.remaining_balance = round(adv.advance_amount - total_net, 2)

        if adv.settled_amount == 0.0:
            adv.status = "OPEN"
        elif adv.remaining_balance <= 0.0:
            adv.status = "SETTLED"
        else:
            adv.status = "PARTIALLY_SETTLED"

        adv.updated_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(adv)

    # =======================================================================
    # Legacy Operations (Preserved)
    # =======================================================================
    def create_advance(
        self, data: BrokerCustodyAdvanceCreate, current_user: str = "system"
    ) -> BrokerCustodyAdvance:
        validate_broker_advance_create(data)

        imp_file = self.db.query(ImportFile).filter(ImportFile.import_file_id == data.import_file_id).first()
        if not imp_file:
            raise not_found("ملف الشحنة", data.import_file_id)

        broker_name = data.broker_name
        if not broker_name:
            provider = (
                self.db.query(ExternalServiceProvider)
                .filter(ExternalServiceProvider.provider_id == data.broker_id)
                .first()
            )
            if not provider:
                raise not_found("المخلص الجمركي", data.broker_id)
            broker_name = provider.partner_name

        advance_code = self.repo.generate_next_advance_code()

        advance = BrokerCustodyAdvance(
            advance_code=advance_code,
            import_file_id=data.import_file_id,
            import_file_code=imp_file.import_file_code,
            broker_id=data.broker_id,
            broker_name=broker_name.strip(),
            advance_amount=data.advance_amount,
            disbursement_date=data.disbursement_date,
            payment_method=data.payment_method.strip().upper(),
            status="OPEN",
            settled_amount=0.0,
            remaining_balance=data.advance_amount,
            notes=data.notes,
            created_by=current_user,
            updated_by=current_user,
        )

        self.repo.add_advance(advance)
        self.db.commit()
        self.db.refresh(advance)
        return advance

    def get_advance(self, advance_id: int) -> BrokerCustodyAdvance:
        advance = self.repo.get_advance_by_id(advance_id)
        if not advance:
            raise not_found("عهدة المخلص الجمركي", advance_id)
        return advance

    def list_advances(
        self,
        skip: int = 0,
        limit: int = 50,
        import_file_id: Optional[int] = None,
        broker_id: Optional[int] = None,
        status: Optional[str] = None,
        search: Optional[str] = None,
    ) -> Tuple[List[BrokerCustodyAdvance], int]:
        return self.repo.list_advances(
            skip=skip,
            limit=limit,
            import_file_id=import_file_id,
            broker_id=broker_id,
            status=status,
            search=search,
        )

    def update_advance(
        self, advance_id: int, data: BrokerCustodyAdvanceUpdate, current_user: str = "system"
    ) -> BrokerCustodyAdvance:
        advance = self.get_advance(advance_id)
        updates = validate_broker_advance_update(data)

        for key, value in updates.items():
            setattr(advance, key, value)

        if "advance_amount" in updates:
            advance.remaining_balance = round(advance.advance_amount - advance.settled_amount, 2)

        advance.updated_by = current_user
        advance.updated_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(advance)
        return advance

    def delete_advance(self, advance_id: int, current_user: str = "system") -> None:
        advance = self.get_advance(advance_id)
        advance.updated_by = current_user
        self.repo.soft_delete_advance(advance)
        self.db.commit()

    def add_expense_item(
        self, advance_id: int, data: BrokerExpenseItemCreate, current_user: str = "system"
    ) -> BrokerExpenseItem:
        advance = self.get_advance(advance_id)
        validate_broker_expense_create(data)

        tax_withheld = round(data.amount * data.tax_withholding_rate, 2)
        net_settled = round(data.amount - tax_withheld, 2)

        item = BrokerExpenseItem(
            advance_id=advance.advance_id,
            expense_category=data.expense_category.strip().upper(),
            is_e_invoice_backed=data.is_e_invoice_backed,
            e_invoice_uuid=data.e_invoice_uuid.strip() if data.e_invoice_uuid else None,
            receipt_reference=data.receipt_reference.strip() if data.receipt_reference else None,
            amount=data.amount,
            tax_withholding_rate=data.tax_withholding_rate,
            tax_withheld_amount=tax_withheld,
            net_settled_amount=net_settled,
            approval_status=data.approval_status.strip().upper(),
            verified_by=None,
            notes=data.notes,
            created_by=current_user,
            updated_by=current_user,
        )

        self.repo.add_expense_item(item)
        self.db.commit()
        self.db.refresh(item)

        self._recalculate_advance_balance(advance)
        return item

    def update_expense_item(
        self, item_id: int, data: BrokerExpenseItemUpdate, current_user: str = "system"
    ) -> BrokerExpenseItem:
        item = self.repo.get_expense_item_by_id(item_id)
        if not item:
            raise not_found("بند مصروف العهدة", item_id)

        updates = validate_broker_expense_update(data)
        for key, value in updates.items():
            setattr(item, key, value)

        if "amount" in updates or "tax_withholding_rate" in updates:
            item.tax_withheld_amount = round(item.amount * item.tax_withholding_rate, 2)
            item.net_settled_amount = round(item.amount - item.tax_withheld_amount, 2)

        item.updated_by = current_user
        item.updated_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(item)

        advance = self.get_advance(item.advance_id)
        self._recalculate_advance_balance(advance)
        return item

    def approve_expense_item(
        self, item_id: int, payload: ExpenseItemApprovalRequest, current_user: str = "system"
    ) -> BrokerExpenseItem:
        item = self.repo.get_expense_item_by_id(item_id)
        if not item:
            raise not_found("بند مصروف العهدة", item_id)

        validate_approval_status(payload.approval_status)
        item.approval_status = payload.approval_status.strip().upper()
        item.verified_by = payload.verified_by or current_user
        if payload.notes:
            item.notes = payload.notes
        item.updated_by = current_user
        item.updated_at = datetime.now(timezone.utc)

        self.db.commit()
        self.db.refresh(item)

        advance = self.get_advance(item.advance_id)
        self._recalculate_advance_balance(advance)
        return item

    def delete_expense_item(self, item_id: int, current_user: str = "system") -> None:
        item = self.repo.get_expense_item_by_id(item_id)
        if not item:
            raise not_found("بند المصروف", item_id)

        advance_id = item.advance_id
        item.updated_by = current_user
        self.repo.soft_delete_expense_item(item)
        self.db.commit()

        advance = self.get_advance(advance_id)
        self._recalculate_advance_balance(advance)

    def reconcile_settlement(self, advance_id: int) -> SettlementReconciliationResponse:
        advance = self.get_advance(advance_id)
        items = self.repo.list_expense_items(advance.advance_id)

        approved_items = [i for i in items if i.approval_status == "APPROVED"]
        total_claimed = sum(i.amount for i in approved_items)
        total_wht = sum(i.tax_withheld_amount for i in approved_items)
        total_net = sum(i.net_settled_amount for i in approved_items)

        approved_count = len(approved_items)
        pending_count = sum(1 for i in items if i.approval_status == "PENDING")

        return SettlementReconciliationResponse(
            advance_id=advance.advance_id,
            advance_code=advance.advance_code,
            advance_amount=round(advance.advance_amount, 2),
            total_expenses_claimed=round(total_claimed, 2),
            total_tax_withheld_w41=round(total_wht, 2),
            total_net_settled=round(total_net, 2),
            balance_remaining=round(advance.remaining_balance, 2),
            status=advance.status,
            approved_items_count=approved_count,
            pending_items_count=pending_count,
            reconciliation_summary=f"العهدة: {advance.advance_amount:,.2f} ج.م | المسدد: {total_net:,.2f} ج.م | المتبقي: {advance.remaining_balance:,.2f} ج.م",
        )

    def approve_petty_cash(
        self, item_id: int, payload: ExpenseItemApprovalRequest, current_user: str = "system"
    ) -> BrokerExpenseItem:
        return self.approve_expense_item(item_id, payload, current_user=current_user)

    def reconcile_and_settle(
        self, advance_id: int, current_user: str = "system"
    ) -> SettlementReconciliationResponse:
        return self.reconcile_settlement(advance_id)

    def _recalculate_advance_balance(self, advance: BrokerCustodyAdvance) -> None:
        items = self.repo.list_expense_items(advance.advance_id)
        total_settled = sum(i.net_settled_amount for i in items if i.approval_status == "APPROVED")

        advance.settled_amount = round(total_settled, 2)
        advance.remaining_balance = round(advance.advance_amount - total_settled, 2)

        if advance.settled_amount == 0.0:
            advance.status = "OPEN"
        elif advance.remaining_balance <= 0.0:
            advance.status = "SETTLED"
        else:
            advance.status = "PARTIALLY_SETTLED"

        advance.updated_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(advance)
