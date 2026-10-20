import re
from typing import Any, Dict, Optional
from fastapi import HTTPException, status
from modules.bank_form4.schemas import BankForm4Create, BankForm4Update

VALID_CURRENCIES = {"USD", "EUR", "EGP"}
VALID_FINANCING_MODES = {"CAD", "LC", "ADVANCE", "OPEN_ACCOUNT"}
VALID_FX_ALLOTMENT_STATUSES = {"PENDING", "ALLOTTED", "TRANSFERRED"}
VALID_NAFEZA_STATUSES = {"AWAITING_BANK", "TRANSMITTED", "VALUE_MISMATCH", "ACCEPTED"}

# Standard SWIFT Reference / BIC regex (alphanumeric, slash, hyphen, underscore, 4 to 35 chars)
SWIFT_REGEX = re.compile(r"^[A-Za-z0-9/\-_]{4,35}$")


def _bad_request(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=detail)


def validate_currency(currency: str) -> str:
    cleaned = (currency or "").strip().upper()
    if cleaned not in VALID_CURRENCIES:
        raise _bad_request(f"عملة غير صالحة: {currency}. العملات المدعومة: {', '.join(sorted(VALID_CURRENCIES))}")
    return cleaned


def validate_swift_reference(swift_ref: Optional[str]) -> Optional[str]:
    if swift_ref is None:
        return None
    cleaned = swift_ref.strip()
    if not cleaned:
        return None
    if not SWIFT_REGEX.match(cleaned):
        raise _bad_request(f"صيغة مرجع السويفت (SWIFT Reference) غير صالحة: {swift_ref}. يجب أن تتكون من 4 إلى 35 رمزًا (حروف، أرقام، شرطة، مائل).")
    return cleaned


def validate_positive_amount(amount: float, field_name: str = "fx_amount") -> float:
    if amount is None or amount <= 0:
        raise _bad_request(f"قيمة المبلغ ({field_name}) يجب أن تكون رقمًا موجبًا أكبر من الصفر.")
    return amount


def validate_financing_mode(mode: str) -> str:
    cleaned = (mode or "").strip().upper()
    if cleaned not in VALID_FINANCING_MODES:
        raise _bad_request(f"طريقة التمويل غير معروفة: {mode}. الطرق المتاحة: {', '.join(sorted(VALID_FINANCING_MODES))}")
    return cleaned


def validate_fx_allotment_status(status_val: str) -> str:
    cleaned = (status_val or "").strip().upper()
    if cleaned not in VALID_FX_ALLOTMENT_STATUSES:
        raise _bad_request(f"حالة تدبير العملة غير صالحة: {status_val}. الحالات المتاحة: {', '.join(sorted(VALID_FX_ALLOTMENT_STATUSES))}")
    return cleaned


def validate_nafeza_transmission_status(status_val: str) -> str:
    cleaned = (status_val or "").strip().upper()
    if cleaned not in VALID_NAFEZA_STATUSES:
        raise _bad_request(f"حالة الإرسال إلى نافذة غير صالحة: {status_val}. الحالات المتاحة: {', '.join(sorted(VALID_NAFEZA_STATUSES))}")
    return cleaned


def validate_bank_form4_create(data: BankForm4Create) -> None:
    validate_currency(data.currency)
    validate_positive_amount(data.fx_amount, "fx_amount")
    validate_financing_mode(data.financing_mode)
    validate_fx_allotment_status(data.fx_allotment_status)
    validate_nafeza_transmission_status(data.nafeza_transmission_status)
    if data.swift_reference:
        validate_swift_reference(data.swift_reference)
    if data.bank_delay_days < 0:
        raise _bad_request("أيام تأخير البنك لا يمكن أن تكون سالبة.")
    if data.daily_financing_cost < 0:
        raise _bad_request("تكلفة التمويل اليومية لا يمكن أن تكون سالبة.")


def validate_bank_form4_update(data: BankForm4Update) -> Dict[str, Any]:
    update_dict = data.model_dump(exclude_unset=True)
    if "currency" in update_dict and update_dict["currency"] is not None:
        update_dict["currency"] = validate_currency(update_dict["currency"])
    if "fx_amount" in update_dict and update_dict["fx_amount"] is not None:
        validate_positive_amount(update_dict["fx_amount"], "fx_amount")
    if "financing_mode" in update_dict and update_dict["financing_mode"] is not None:
        update_dict["financing_mode"] = validate_financing_mode(update_dict["financing_mode"])
    if "fx_allotment_status" in update_dict and update_dict["fx_allotment_status"] is not None:
        update_dict["fx_allotment_status"] = validate_fx_allotment_status(update_dict["fx_allotment_status"])
    if "nafeza_transmission_status" in update_dict and update_dict["nafeza_transmission_status"] is not None:
        update_dict["nafeza_transmission_status"] = validate_nafeza_transmission_status(update_dict["nafeza_transmission_status"])
    if "swift_reference" in update_dict and update_dict["swift_reference"] is not None:
        update_dict["swift_reference"] = validate_swift_reference(update_dict["swift_reference"])
    if "bank_delay_days" in update_dict and update_dict["bank_delay_days"] is not None and update_dict["bank_delay_days"] < 0:
        raise _bad_request("أيام تأخير البنك لا يمكن أن تكون سالبة.")
    if "daily_financing_cost" in update_dict and update_dict["daily_financing_cost"] is not None and update_dict["daily_financing_cost"] < 0:
        raise _bad_request("تكلفة التمويل اليومية لا يمكن أن تكون سالبة.")
    return update_dict
