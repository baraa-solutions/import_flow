"""
Input validation for Trade Finance
"""

from typing import Any, Dict
from fastapi import HTTPException, status
from modules.trade_finance.schemas import (
    FxHedgingAndVarianceCreate,
    FxHedgingAndVarianceUpdate,
    ImportFinanceInstrumentCreate,
    ImportFinanceInstrumentUpdate,
    LcBankChargeCreate,
    LcBankChargeUpdate,
)

VALID_INSTRUMENT_TYPES = {"LC", "CAD", "ADVANCE_PAYMENT", "OPEN_ACCOUNT"}
VALID_INSTRUMENT_STATUSES = {"DRAFT", "ISSUED", "ACCEPTED", "SETTLED", "CANCELLED"}
VALID_CHARGE_TYPES = {
    "ISSUANCE_COMMISSION",
    "AMENDMENT_FEE",
    "SWIFT_CHARGE",
    "PAYMENT_COMMISSION",
    "CONFIRMATION_FEE",
    "DISCREPANCY_FEE",
    "OTHER",
}


def validate_instrument_create(data: ImportFinanceInstrumentCreate) -> None:
    if data.instrument_type.upper() not in VALID_INSTRUMENT_TYPES:
        raise HTTPException(
            status_code=422,
            detail=f"نوع أداة التمويل غير صالح. الخيارات المتاحة: {', '.join(sorted(VALID_INSTRUMENT_TYPES))}",
        )

    if not data.instrument_number or not data.instrument_number.strip():
        raise HTTPException(
            status_code=422,
            detail="رقم الأداة التمويلية / الاعتماد المستندي إلزامي.",
        )

    if data.amount <= 0.0:
        raise HTTPException(
            status_code=422,
            detail="قيمة الاعتماد / أداة التمويل يجب أن تكون أكبر من الصفر.",
        )

    if data.issue_date and data.expiry_date and data.expiry_date < data.issue_date:
        raise HTTPException(
            status_code=422,
            detail="تاريخ انتهاء صلاحية الاعتماد لا يمكن أن يكون قبل تاريخ الإصدار.",
        )

    if data.shipment_deadline and data.expiry_date and data.shipment_deadline > data.expiry_date:
        raise HTTPException(
            status_code=422,
            detail="آخر ميعاد للشحن لا يمكن أن يتجاوز تاريخ انتهاء صلاحية الاعتماد.",
        )


def validate_instrument_update(data: ImportFinanceInstrumentUpdate) -> Dict[str, Any]:
    updates: Dict[str, Any] = {}

    if data.status is not None:
        if data.status.upper() not in VALID_INSTRUMENT_STATUSES:
            raise HTTPException(
                status_code=422,
                detail=f"حالة الاعتماد غير صالحة ({data.status}).",
            )
        updates["status"] = data.status.upper()

    if data.amount is not None:
        if data.amount <= 0.0:
            raise HTTPException(
                status_code=422,
                detail="قيمة الاعتماد يجب أن تكون موجبة.",
            )
        updates["amount"] = data.amount

    for field in [
        "issuing_bank",
        "advising_bank",
        "currency",
        "issue_date",
        "expiry_date",
        "shipment_deadline",
        "presentation_period_days",
        "payment_terms",
        "tolerance_percentage",
        "notes",
    ]:
        val = getattr(data, field)
        if val is not None:
            updates[field] = val

    return updates


def validate_bank_charge_create(data: LcBankChargeCreate) -> None:
    if data.charge_type.upper() not in VALID_CHARGE_TYPES:
        raise HTTPException(
            status_code=422,
            detail=f"نوع المصروف البنكي غير صالح. الخيارات المتاحة: {', '.join(sorted(VALID_CHARGE_TYPES))}",
        )
    if data.amount <= 0.0 or data.amount_egp <= 0.0:
        raise HTTPException(
            status_code=422,
            detail="مبلغ المصروف البنكي يجب أن يكون أكبر من الصفر.",
        )


def validate_bank_charge_update(data: LcBankChargeUpdate) -> Dict[str, Any]:
    updates: Dict[str, Any] = {}
    for field in [
        "charge_type",
        "currency",
        "amount",
        "amount_egp",
        "debit_date",
        "debit_account",
        "swift_reference",
        "notes",
    ]:
        val = getattr(data, field)
        if val is not None:
            updates[field] = val
    return updates


def validate_fx_create(data: FxHedgingAndVarianceCreate) -> None:
    if data.original_amount <= 0.0:
        raise HTTPException(
            status_code=422,
            detail="المبلغ بالعملة الأجنبية يجب أن يكون أكبر من الصفر.",
        )
    if data.booking_rate <= 0.0:
        raise HTTPException(
            status_code=422,
            detail="سعر الصرف عند الحجز يجب أن يكون أكبر من الصفر.",
        )
    if data.settlement_rate is not None and data.settlement_rate <= 0.0:
        raise HTTPException(
            status_code=422,
            detail="سعر الصرف الفعلي عند السداد يجب أن يكون أكبر من الصفر.",
        )


def validate_fx_update(data: FxHedgingAndVarianceUpdate) -> Dict[str, Any]:
    updates: Dict[str, Any] = {}
    if data.settlement_rate is not None:
        if data.settlement_rate <= 0.0:
            raise HTTPException(
                status_code=422,
                detail="سعر الصرف عند السداد يجب أن يكون أكبر من الصفر.",
            )
        updates["settlement_rate"] = data.settlement_rate
    for field in ["settlement_date", "hedging_contract_ref", "notes"]:
        val = getattr(data, field)
        if val is not None:
            updates[field] = val
    return updates
