from typing import Any, Dict, Optional
from fastapi import HTTPException, status
from modules.broker_custody.schemas import (
    BrokerCustodyAdvanceCreate,
    BrokerCustodyAdvanceUpdate,
    BrokerExpenseItemCreate,
    BrokerExpenseItemUpdate,
    BrokerSettlementReceiptCreate,
    BrokerSettlementReceiptUpdate,
    CustomsBrokerAdvanceCreate,
    CustomsBrokerAdvanceUpdate,
)

VALID_EXPENSE_CATEGORIES = {
    "OFFICIAL_DUTIES_TAXES",
    "PORT_AUTHORITY_FEES",
    "LAB_TESTING_FEES",
    "HANDLING_AND_PORTERAGE",
    "INSPECTION_TRANSPORT",
    "SUNDRY_PETTY_CASH",
}

VALID_RECEIPT_TYPES = {
    "WHITE_RECEIPT_CUSTOMS_DUTIES",
    "RED_RECEIPT_EXAMINATION_INSPECTION",
    "PORT_AUTHORITY_RECEIPT",
    "BROKER_SERVICE_FEE",
    "STORAGE_RECEIPT",
    "OTHER_OFFICIAL_RECEIPT",
}

VALID_PAYMENT_METHODS = {"CASH", "BANK_TRANSFER", "CHECK"}
VALID_ADVANCE_STATUSES = {"OPEN", "PARTIALLY_SETTLED", "SETTLED"}
VALID_APPROVAL_STATUSES = {"PENDING", "APPROVED", "REJECTED"}
VALID_RECEIPT_VERIFICATION_STATUSES = {"PENDING", "VERIFIED", "REJECTED"}


def _bad_request(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=detail)


def validate_expense_category(category: str) -> str:
    cleaned = (category or "").strip().upper()
    if cleaned not in VALID_EXPENSE_CATEGORIES:
        raise _bad_request(
            f"تصنيف المصروف غير صالح: {category}. التصنيفات المعتمدة: {', '.join(sorted(VALID_EXPENSE_CATEGORIES))}"
        )
    return cleaned


def validate_receipt_type(receipt_type: str) -> str:
    cleaned = (receipt_type or "").strip().upper()
    if cleaned not in VALID_RECEIPT_TYPES:
        raise _bad_request(
            f"نوع الإيصال غير صالح: {receipt_type}. الأنواع المعتمدة: {', '.join(sorted(VALID_RECEIPT_TYPES))}"
        )
    return cleaned


def validate_payment_method(method: str) -> str:
    cleaned = (method or "").strip().upper()
    if cleaned not in VALID_PAYMENT_METHODS:
        raise _bad_request(
            f"طريقة الدفع غير صالحة: {method}. الطرق المتاحة: {', '.join(sorted(VALID_PAYMENT_METHODS))}"
        )
    return cleaned


def validate_advance_status(status_val: str) -> str:
    cleaned = (status_val or "").strip().upper()
    if cleaned not in VALID_ADVANCE_STATUSES:
        raise _bad_request(
            f"حالة العهدة غير صالحة: {status_val}. الحالات المتاحة: {', '.join(sorted(VALID_ADVANCE_STATUSES))}"
        )
    return cleaned


def validate_approval_status(status_val: str) -> str:
    cleaned = (status_val or "").strip().upper()
    if cleaned not in VALID_APPROVAL_STATUSES:
        raise _bad_request(
            f"حالة الاعتماد غير صالحة: {status_val}. الحالات المتاحة: {', '.join(sorted(VALID_APPROVAL_STATUSES))}"
        )
    return cleaned


def validate_receipt_verification_status(status_val: str) -> str:
    cleaned = (status_val or "").strip().upper()
    if cleaned not in VALID_RECEIPT_VERIFICATION_STATUSES:
        raise _bad_request(
            f"حالة تدقيق الإيصال غير صالحة: {status_val}."
        )
    return cleaned


def validate_wht_rate(rate: float) -> float:
    if rate is None or not (0.0 <= rate <= 1.0):
        raise _bad_request(f"نسبة الخصم من المنبع (WHT) غير صالحة: {rate}. يجب أن تكون نسبة عشرية بين 0.0 و 1.0.")
    return rate


def validate_e_invoice_backed(is_e_invoice_backed: bool, e_invoice_uuid: Optional[str]) -> None:
    if is_e_invoice_backed:
        if not e_invoice_uuid or not e_invoice_uuid.strip():
            raise _bad_request("المصروف محدد كفاتورة إلكترونية معتمدة، لذلك يجب إدخال الـ UUID الخاص بالفاتورة الإلكترونية.")


def validate_positive_amount(amount: float, field_name: str) -> float:
    if amount is None or amount <= 0:
        raise _bad_request(f"مبلغ {field_name} يجب أن يكون رقمًا موجبًا أكبر من الصفر.")
    return amount


# -------------------------------------------------------------
# Wave 1 Customs Broker Advance Validators
# -------------------------------------------------------------
def validate_customs_advance_create(data: CustomsBrokerAdvanceCreate) -> None:
    validate_positive_amount(data.advance_amount, "العهدة")
    validate_payment_method(data.payment_method)


def validate_customs_advance_update(data: CustomsBrokerAdvanceUpdate) -> Dict[str, Any]:
    updates = data.model_dump(exclude_unset=True)
    if "advance_amount" in updates and updates["advance_amount"] is not None:
        validate_positive_amount(updates["advance_amount"], "العهدة")
    if "payment_method" in updates and updates["payment_method"] is not None:
        updates["payment_method"] = validate_payment_method(updates["payment_method"])
    if "status" in updates and updates["status"] is not None:
        updates["status"] = validate_advance_status(updates["status"])
    return updates


# -------------------------------------------------------------
# Wave 1 Settlement Receipts Validators
# -------------------------------------------------------------
def validate_settlement_receipt_create(data: BrokerSettlementReceiptCreate) -> None:
    validate_receipt_type(data.receipt_type)
    if not data.receipt_number or not data.receipt_number.strip():
        raise _bad_request("رقم الإيصال أو الفاتورة إلزامي.")
    if not data.issuing_entity or not data.issuing_entity.strip():
        raise _bad_request("الجهة المصدرة للإيصال إلزامية.")
    validate_positive_amount(data.amount, "الإيصال")
    validate_wht_rate(data.tax_withholding_rate)


def validate_settlement_receipt_update(data: BrokerSettlementReceiptUpdate) -> Dict[str, Any]:
    updates = data.model_dump(exclude_unset=True)
    if "receipt_type" in updates and updates["receipt_type"] is not None:
        updates["receipt_type"] = validate_receipt_type(updates["receipt_type"])
    if "amount" in updates and updates["amount"] is not None:
        validate_positive_amount(updates["amount"], "الإيصال")
    if "tax_withholding_rate" in updates and updates["tax_withholding_rate"] is not None:
        updates["tax_withholding_rate"] = validate_wht_rate(updates["tax_withholding_rate"])
    if "verification_status" in updates and updates["verification_status"] is not None:
        updates["verification_status"] = validate_receipt_verification_status(updates["verification_status"])
    return updates


# -------------------------------------------------------------
# Legacy Validators (Preserved)
# -------------------------------------------------------------
def validate_broker_advance_create(data: BrokerCustodyAdvanceCreate) -> None:
    validate_positive_amount(data.advance_amount, "العهدة")
    validate_payment_method(data.payment_method)


def validate_broker_advance_update(data: BrokerCustodyAdvanceUpdate) -> Dict[str, Any]:
    updates = data.model_dump(exclude_unset=True)
    if "advance_amount" in updates and updates["advance_amount"] is not None:
        validate_positive_amount(updates["advance_amount"], "العهدة")
    if "payment_method" in updates and updates["payment_method"] is not None:
        updates["payment_method"] = validate_payment_method(updates["payment_method"])
    if "status" in updates and updates["status"] is not None:
        updates["status"] = validate_advance_status(updates["status"])
    return updates


def validate_broker_expense_create(data: BrokerExpenseItemCreate) -> None:
    validate_expense_category(data.expense_category)
    validate_positive_amount(data.amount, "المصروف")
    validate_wht_rate(data.tax_withholding_rate)
    validate_e_invoice_backed(data.is_e_invoice_backed, data.e_invoice_uuid)
    validate_approval_status(data.approval_status)


def validate_broker_expense_update(data: BrokerExpenseItemUpdate) -> Dict[str, Any]:
    updates = data.model_dump(exclude_unset=True)
    if "expense_category" in updates and updates["expense_category"] is not None:
        updates["expense_category"] = validate_expense_category(updates["expense_category"])
    if "amount" in updates and updates["amount"] is not None:
        validate_positive_amount(updates["amount"], "المصروف")
    if "tax_withholding_rate" in updates and updates["tax_withholding_rate"] is not None:
        updates["tax_withholding_rate"] = validate_wht_rate(updates["tax_withholding_rate"])
    if "approval_status" in updates and updates["approval_status"] is not None:
        updates["approval_status"] = validate_approval_status(updates["approval_status"])
    if "is_e_invoice_backed" in updates:
        uuid = updates.get("e_invoice_uuid")
        validate_e_invoice_backed(updates["is_e_invoice_backed"], uuid)
    return updates
