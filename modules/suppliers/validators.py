from fastapi import HTTPException
from sqlalchemy.orm import Session

from modules.common.name_normalizer import check_duplicate_name
from .model import Supplier
from .schemas import SupplierCreate


def validate_supplier(
    db: Session,
    supplier: SupplierCreate
) -> None:
    # 1. Company Name Required
    if not supplier.company_name or not supplier.company_name.strip():
        raise HTTPException(
            status_code=400,
            detail="اسم الشركة / المورد الأجنبي مطلوب."
        )

    # 2. Strict Duplicate Name Detection (Active & Inactive Suppliers)
    all_suppliers = db.query(Supplier).all()
    existing_names = [s.company_name for s in all_suppliers if s.company_name]
    matched_name = check_duplicate_name(supplier.company_name, existing_names)

    if matched_name:
        existing_obj = next((s for s in all_suppliers if s.company_name == matched_name), None)
        code_info = f" (كود المورد: {existing_obj.supplier_code})" if existing_obj else ""
        raise HTTPException(
            status_code=400,
            detail=f"عفواً! المورد الأجنبي '{supplier.company_name.strip()}' مسجل بالفعل بالنظام من قبل باسم متطابق أو تشابه كبير: '{matched_name}'{code_info}. لا يمكن تكرار تسجيل الموردين."
        )

    # 3. Duplicate Exporter ID check
    exp_id = (supplier.foreign_exporter_id or "").strip()
    if exp_id and not exp_id.startswith("EXP-SUP-"):
        duplicate_exporter = next((s for s in all_suppliers if s.foreign_exporter_id == exp_id), None)
        if duplicate_exporter:
            raise HTTPException(
                status_code=400,
                detail=f"عفواً! رقم السجل / المعرف الضريبي للمورد الأجنبي '{exp_id}' مسجل بالفعل للنظام من قبل باسم: '{duplicate_exporter.company_name}'."
            )


# ==================================================
# Sub-Ledger & Credit Limit Governance (Trello GzFff0Pc)
# ==================================================

SUPPLIER_CREDIT_LIMIT_EXCEEDED = "SUPPLIER_CREDIT_LIMIT_EXCEEDED"
SUPPLIER_CREDIT_OVERRIDE_FORBIDDEN = "SUPPLIER_CREDIT_OVERRIDE_FORBIDDEN"
SUPPLIER_CREDIT_LIMIT_INVALID = "SUPPLIER_CREDIT_LIMIT_INVALID"
CREDIT_LIMIT_POLICIES = ("WARN", "BLOCK")


def supplier_coded_error(status_code: int, code: str, message_ar: str, **params) -> HTTPException:
    """HTTP error with a machine code + params next to the Arabic message (same shape as the FOB engine)."""
    return HTTPException(status_code=status_code, detail={"code": code, "message": message_ar, **params})


def validate_credit_limit_settings(db: Session, credit_limit: float, currency, policy) -> tuple:
    """Returns (currency_code or None, policy_code). Limit >= 0 (0 = no limit), registered active currency,
    policy WARN or BLOCK."""
    from modules.currencies.model import Currency

    if credit_limit is None or float(credit_limit) < 0:
        raise supplier_coded_error(422, SUPPLIER_CREDIT_LIMIT_INVALID, "الحد الائتماني لا يجوز أن يكون سالباً.",
                                   field="credit_limit")
    policy_code = (policy or "BLOCK").strip().upper()
    if policy_code not in CREDIT_LIMIT_POLICIES:
        raise supplier_coded_error(422, SUPPLIER_CREDIT_LIMIT_INVALID,
                                   "سياسة الحد الائتماني يجب أن تكون WARN أو BLOCK.", field="credit_limit_policy")
    currency_code = (currency or "").strip().upper() or None
    if currency_code and currency_code != "EGP":
        exists = (
            db.query(Currency)
            .filter(Currency.currency_code == currency_code, Currency.is_active == True)  # noqa: E712
            .first()
        )
        if exists is None:
            raise supplier_coded_error(422, SUPPLIER_CREDIT_LIMIT_INVALID,
                                       f"عملة الحد الائتماني '{currency_code}' غير مسجلة أو غير نشطة.",
                                       field="credit_limit_currency")
    return currency_code, policy_code