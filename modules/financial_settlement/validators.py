from datetime import date
from typing import List, Dict, Any, Optional

from fastapi import HTTPException, status

# Language-neutral error codes of this module (detail = {"code", "message" (Arabic), **params}). Registered in
# docs/plans/review-shared-needs.md "## 09 shared needs"; plain dicts until the shared catalog has them.
SETTLEMENT_NOT_EDITABLE = "SETTLEMENT_NOT_EDITABLE"
SETTLEMENT_FX_RATE_MISSING = "SETTLEMENT_FX_RATE_MISSING"
INVOICES_ALREADY_SETTLED = "INVOICES_ALREADY_SETTLED"
JOURNAL_UNBALANCED = "JOURNAL_UNBALANCED"
SETTLEMENT_DUPLICATE_ACTIVE = "SETTLEMENT_DUPLICATE_ACTIVE"
IMPORT_FILE_CLOSED = "IMPORT_FILE_CLOSED"

from modules.common.validators import ensure_file_open

LOCKED_SETTLEMENT_STATUSES = ("Approved", "Closed")
# ImportFile.financial_settlement_status values at or after the CLO-01 invoices settlement.
SETTLED_FILE_STATUSES = ("INVOICES_SETTLED", "COST_ALLOCATED", "CLOSED")

# Odoo journal balance tolerance (Q10).
JOURNAL_BALANCE_TOLERANCE_EGP = 0.01


def coded_error(status_code: int, code: str, message_ar: str, **params: Any) -> HTTPException:
    return HTTPException(status_code=status_code, detail={"code": code, "message": message_ar, **params})


def validate_expense_invoice(invoice_no: str, amount_fx: float, exchange_rate: float) -> None:
    if not invoice_no or not invoice_no.strip():
        raise HTTPException(status_code=400, detail="يلزم إدخال رقم الفاتورة أو الإيصال المالي للمصروف.")
    if amount_fx <= 0:
        raise HTTPException(status_code=400, detail="مبلغ الفاتورة يجب أن يكون أكبر من الصفر.")
    if exchange_rate <= 0:
        raise HTTPException(status_code=400, detail="سعر الصرف يجب أن يكون أكبر من الصفر.")


def validate_items_allocation_readiness(items: List[Dict[str, Any]]) -> None:
    if not items or len(items) == 0:
        raise HTTPException(
            status_code=400,
            detail="لا توجد بنود أصناف بالشحنة لإجراء توزيع التكاليف وحساب الـ Landed Cost.",
        )


def ensure_settlement_editable(record: Any) -> None:
    """Approved / Closed settlements are frozen: PUT and /recalculate are refused (FS-03). Approval goes only
    through approve-actual-landed-cost; the recalculation engine keeps its justified path (Q1)."""
    current = record.status or ""
    if current in LOCKED_SETTLEMENT_STATUSES:
        raise coded_error(
            status.HTTP_409_CONFLICT,
            SETTLEMENT_NOT_EDITABLE,
            f"لا يمكن تعديل أو إعادة احتساب التسوية {record.settlement_code} لأنها في حالة ({current}).",
            status=current,
            settlement_code=record.settlement_code,
        )


def ensure_no_other_active_settlement(existing: Optional[Any], settlement_id: int) -> None:
    """Restore must not create a second active settlement on the same import file (FS-11)."""
    if existing is not None and existing.settlement_id != settlement_id:
        raise coded_error(
            status.HTTP_409_CONFLICT,
            SETTLEMENT_DUPLICATE_ACTIVE,
            f"لا يمكن استرجاع التسوية: توجد تسوية نشطة أخرى ({existing.settlement_code}) لنفس ملف الشحنة.",
            settlement_code=existing.settlement_code,
        )


COST_APPROVED_FILE_STATUSES = ("COST_ALLOCATED", "CLOSED")


def ensure_cost_not_approved(imp: Any, settlement: Optional[Any]) -> None:
    """Approve once: an Approved / Closed settlement, or a file already at COST_ALLOCATED / CLOSED, is frozen
    (review 2 #2). Later corrections go through the justified recalculation path (Q1)."""
    if settlement is not None:
        ensure_settlement_editable(settlement)
    current = imp.financial_settlement_status or ""
    if current in COST_APPROVED_FILE_STATUSES:
        raise coded_error(
            status.HTTP_409_CONFLICT,
            SETTLEMENT_NOT_EDITABLE,
            f"تم اعتماد تكلفة الوصول الفعلية للملف {imp.import_file_code} من قبل (الحالة: {current}).",
            status=current,
            import_file_code=imp.import_file_code,
        )


def ensure_invoices_not_settled(imp: Any) -> None:
    """CLO-01 confirmation runs once per file (FS-12)."""
    current = imp.financial_settlement_status or ""
    if current in SETTLED_FILE_STATUSES:
        raise coded_error(
            status.HTTP_409_CONFLICT,
            INVOICES_ALREADY_SETTLED,
            f"تم اعتماد تسوية فواتير الملف {imp.import_file_code} من قبل (الحالة: {current}).",
            import_file_code=imp.import_file_code,
            status=current,
        )


def fx_rate_missing_error(currency: Optional[str], on_date: date) -> HTTPException:
    return coded_error(
        status.HTTP_409_CONFLICT,
        SETTLEMENT_FX_RATE_MISSING,
        (
            f"لا يوجد سعر صرف مسجل للعملة {currency or '-'} بتاريخ {on_date.isoformat()}. "
            "يرجى تسجيل سعر الصرف قبل احتساب التسوية."
        ),
        currency=currency,
        on_date=on_date.isoformat(),
    )


def ensure_journal_balanced(entry: Any) -> None:
    """An unbalanced journal is never exported (FS-14)."""
    if entry.difference > JOURNAL_BALANCE_TOLERANCE_EGP:
        raise coded_error(
            status.HTTP_409_CONFLICT,
            JOURNAL_UNBALANCED,
            f"قيد اليومية غير متوازن (فرق {entry.difference:,.2f} جنيه). لا يمكن تصديره.",
            difference=entry.difference,
            settlement_code=entry.settlement_code,
        )
