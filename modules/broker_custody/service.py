from datetime import datetime, timezone
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.broker_custody.model import BrokerCustodyAdvance, BrokerExpenseItem
from modules.broker_custody.repository import BrokerCustodyRepository
from modules.broker_custody.schemas import (
    BrokerCustodyAdvanceCreate,
    BrokerCustodyAdvanceUpdate,
    BrokerExpenseItemCreate,
    BrokerExpenseItemUpdate,
    ExpenseItemApprovalRequest,
    SettlementReconciliationResponse,
)
from modules.broker_custody.validators import (
    validate_approval_status,
    validate_broker_advance_create,
    validate_broker_advance_update,
    validate_broker_expense_create,
    validate_broker_expense_update,
)
from modules.common.validators import not_found
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile


class BrokerCustodyService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = BrokerCustodyRepository(db)

    # -------------------------------------------------------------
    # Advance Operations
    # -------------------------------------------------------------
    def create_advance(
        self, data: BrokerCustodyAdvanceCreate, current_user: str = "system"
    ) -> BrokerCustodyAdvance:
        validate_broker_advance_create(data)

        # 1. Verify Import File
        imp_file = self.db.query(ImportFile).filter(ImportFile.import_file_id == data.import_file_id).first()
        if not imp_file:
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

    # -------------------------------------------------------------
    # Expense Item Operations
    # -------------------------------------------------------------
    def add_expense_item(
        self, advance_id: int, data: BrokerExpenseItemCreate, current_user: str = "system"
    ) -> BrokerExpenseItem:
        advance = self.get_advance(advance_id)
        validate_broker_expense_create(data)

        # Calculate 1% WHT (Form 41) and Net Settled Amount
        tax_withheld = round(data.amount * data.tax_withholding_rate, 2)
        net_settled = round(data.amount - tax_withheld, 2)

        approval_status = data.approval_status.strip().upper()
        # For sundry petty cash without approval, default to PENDING
        if data.expense_category == "SUNDRY_PETTY_CASH" and approval_status != "APPROVED":
            approval_status = "PENDING"

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
            approval_status=approval_status,
            verified_by=current_user if approval_status == "APPROVED" else None,
            notes=data.notes,
            created_by=current_user,
            updated_by=current_user,
        )

        self.repo.add_expense_item(item)
        self.db.commit()
        self.db.refresh(item)
        return item

    def get_expense_item(self, item_id: int) -> BrokerExpenseItem:
        item = self.repo.get_expense_item_by_id(item_id)
        if not item:
            raise not_found("بند مصروف العهدة", item_id)
        return item

    def list_expense_items(self, advance_id: int) -> List[BrokerExpenseItem]:
        self.get_advance(advance_id)  # Validate advance exists
        return self.repo.list_expense_items(advance_id)

    def update_expense_item(
        self, item_id: int, data: BrokerExpenseItemUpdate, current_user: str = "system"
    ) -> BrokerExpenseItem:
        item = self.get_expense_item(item_id)
        updates = validate_broker_expense_update(data)

        for key, value in updates.items():
            setattr(item, key, value)

        # Recalculate WHT and net settled amount if amount or rate changed
        if "amount" in updates or "tax_withholding_rate" in updates:
            tax_withheld = round(item.amount * item.tax_withholding_rate, 2)
            net_settled = round(item.amount - tax_withheld, 2)
            item.tax_withheld_amount = tax_withheld
            item.net_settled_amount = net_settled

        item.updated_by = current_user
        item.updated_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(item)
        return item

    def approve_petty_cash(
        self, item_id: int, approval_data: ExpenseItemApprovalRequest, current_user: str = "system"
    ) -> BrokerExpenseItem:
        """
        Approve or reject petty cash / sundry expense items with verifier tracking.
        """
        item = self.get_expense_item(item_id)
        new_status = validate_approval_status(approval_data.approval_status)

        item.approval_status = new_status
        item.verified_by = approval_data.verified_by or current_user
        if approval_data.notes:
            if item.notes:
                item.notes = f"{item.notes}\n[{new_status}]: {approval_data.notes}"
            else:
                item.notes = f"[{new_status}]: {approval_data.notes}"

        item.updated_by = current_user
        item.updated_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(item)
        return item

    def delete_expense_item(self, item_id: int, current_user: str = "system") -> None:
        item = self.get_expense_item(item_id)
        item.updated_by = current_user
        self.repo.soft_delete_expense_item(item)
        self.db.commit()

    # -------------------------------------------------------------
    # Settlement Reconciliation (/settle)
    # -------------------------------------------------------------
    def reconcile_and_settle(
        self, advance_id: int, current_user: str = "system"
    ) -> SettlementReconciliationResponse:
        """
        Reconciles the custody advance against approved expense items.
        Applies 1% WHT deductions and updates the advance status:
        - balance_remaining == 0.0 -> SETTLED
        - balance_remaining > 0.0  -> PARTIALLY_SETTLED (refund due to company)
        - balance_remaining < 0.0  -> SETTLED (company owes reimbursement to broker)
        """
        advance = self.get_advance(advance_id)
        all_items = self.repo.list_expense_items(advance_id)

        approved_items = [i for i in all_items if i.approval_status == "APPROVED"]
        pending_items = [i for i in all_items if i.approval_status == "PENDING"]

        total_expenses = round(sum(i.amount for i in approved_items), 2)
        total_wht = round(sum(i.tax_withheld_amount for i in approved_items), 2)
        total_net_settled = round(sum(i.net_settled_amount for i in approved_items), 2)
        balance_remaining = round(advance.advance_amount - total_net_settled, 2)

        if balance_remaining == 0.0:
            status_val = "SETTLED"
            summary = f"تمت تسوية العهدة {advance.advance_code} بالكامل (الرصيد المتبقي صفر)."
        elif balance_remaining > 0.0:
            status_val = "PARTIALLY_SETTLED"
            summary = (
                f"تمت تسوية العهدة {advance.advance_code} جزئيًا بمبلغ صافي {total_net_settled:,.2f} ج.م. "
                f"متبقي طرف المخلص: {balance_remaining:,.2f} ج.م واجبة الرد للشركة."
            )
        else:
            status_val = "SETTLED"
            summary = (
                f"تمت تسوية العهدة {advance.advance_code}. المصروفات الصافية ({total_net_settled:,.2f} ج.م) "
                f"تجاوزت العهدة. مستحق للمخلص طرف الشركة: {abs(balance_remaining):,.2f} ج.م."
            )

        advance.settled_amount = total_net_settled
        advance.remaining_balance = balance_remaining
        advance.status = status_val
        advance.updated_by = current_user
        advance.updated_at = datetime.now(timezone.utc)

        self.db.commit()
        self.db.refresh(advance)

        return SettlementReconciliationResponse(
            advance_id=advance.advance_id,
            advance_code=advance.advance_code,
            advance_amount=advance.advance_amount,
            total_expenses_claimed=total_expenses,
            total_tax_withheld_w41=total_wht,
            total_net_settled=total_net_settled,
            balance_remaining=balance_remaining,
            status=status_val,
            approved_items_count=len(approved_items),
            pending_items_count=len(pending_items),
            reconciliation_summary=summary,
        )
