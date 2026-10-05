"""
Customs Clearance Quotations & Price Lists Validators
"""

from __future__ import annotations

from datetime import date
from typing import Any, Optional

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.common.validators import require_active
from modules.customs_clearance_quotations.schemas import (
    CustomsClearanceRFQCreate,
    CustomsClearanceQuotationCreate,
    ClearancePriceListItemCreate,
)

RFQ_STATUS_AWARDED = "Awarded"
RFQ_STATUS_CANCELLED = "Cancelled"
# "RFQ Issued" is kept: it is a documented model status that older rows may carry.
RFQ_STATUSES = ("Draft", "RFQ Issued", "Quotations Received", RFQ_STATUS_AWARDED, RFQ_STATUS_CANCELLED)


def coded_error(status_code: int, code: str, message_ar: str, **params: Any) -> HTTPException:
    """``detail = {"code", "message" (Arabic), **params}`` (codes in docs/plans/review-shared-needs.md)."""
    return HTTPException(status_code=status_code, detail={"code": code, "message": message_ar, **params})


def validate_rfq_create(data: CustomsClearanceRFQCreate) -> None:
    if not data.title or len(data.title.strip()) < 3:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="عنوان طلب عرض أسعار التخليص مطلوب ويجب ألا يقل عن 3 أحرف.",
        )
    if not data.port_name or len(data.port_name.strip()) < 2:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="ميناء التخليص الجمركي مطلوب.",
        )
    if data.containers_count < 1:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="عدد الحاويات / الشحنات يجب أن يكون 1 على الأقل.",
        )


def validate_rfq_links(db: Session, *, import_file_id: Optional[int] = None, project_id: Optional[int] = None,
                       port_id: Optional[int] = None) -> None:
    """Active-FK checks for the optional RFQ links (400 on a missing / soft-deleted row)."""
    from modules.import_files.model import ImportFile
    from modules.projects.model import Project
    from modules.transport_locations.model import TransportLocation

    require_active(db, ImportFile, import_file_id, "ملف الشحنة")
    require_active(db, Project, project_id, "المشروع")
    require_active(db, TransportLocation, port_id, "الميناء")


def validate_rfq_status_change(current_status: str, new_status: Optional[str]) -> None:
    """RFQ PUT: the status must be a known value and cannot become "Awarded" (only the award route does that)."""
    if new_status is None:
        return
    if new_status not in RFQ_STATUSES or (new_status == RFQ_STATUS_AWARDED and current_status != RFQ_STATUS_AWARDED):
        raise coded_error(
            status.HTTP_400_BAD_REQUEST,
            "CCQ_RFQ_STATUS_INVALID",
            f"حالة طلب عرض الأسعار ({new_status}) غير مسموح بها. الترسية تتم من خلال إجراء الترسية فقط.",
            status=new_status,
        )


def validate_quotation_create(data: CustomsClearanceQuotationCreate) -> None:
    if not data.provider_name or len(data.provider_name.strip()) < 2:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="اسم المخلص الجمركي / المكتب مطلوب.",
        )
    if data.provider_id <= 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="معرف الشريك / المخلص الجمركي غير صالح.",
        )
    if (data.clearance_fee + data.inland_transport_fee + data.inspection_fee + data.port_expenses + data.miscellaneous_fee) <= 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="يجب إدخال قيمة موجبة لأحد بنود عرض أسعار التخليص على الأقل.",
        )


def validate_quotation_provider(db: Session, provider_id: int) -> None:
    from modules.external_service_providers.model import ExternalServiceProvider

    require_active(db, ExternalServiceProvider, provider_id, "المخلص الجمركي / الشريك")


def validate_award(rfq, quote, today: Optional[date] = None) -> None:
    """Award: the quote must be an active quote of this RFQ (400), the RFQ not cancelled (409), the quote valid (400)."""
    if quote is None or quote.rfq_id != rfq.rfq_id or not quote.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="عرض السعر المحدد لا ينتمي لهذا الطلب.")
    if rfq.status == RFQ_STATUS_CANCELLED:
        raise coded_error(
            status.HTTP_409_CONFLICT, "CCQ_RFQ_CANCELLED", "لا يمكن ترسية طلب عرض أسعار ملغى.", rfq_code=rfq.rfq_code
        )
    today = today or date.today()
    if quote.validity_date is not None and quote.validity_date < today:
        raise coded_error(
            status.HTTP_400_BAD_REQUEST,
            "CCQ_QUOTE_EXPIRED",
            "عرض السعر منتهي الصلاحية.",
            validity_date=quote.validity_date.isoformat(),
        )


def validate_quote_deletable(quote) -> None:
    if quote.is_awarded:
        raise coded_error(
            status.HTTP_409_CONFLICT,
            "CCQ_AWARDED_QUOTE_DELETE",
            "لا يمكن حذف العرض المُرسى عليه.",
            quotation_id=quote.quotation_id,
        )


def validate_price_item_create(data: ClearancePriceListItemCreate) -> None:
    if data.unit_price <= 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="سعر البند في قائمة الأسعار يجب أن يكون أكبر من الصفر.",
        )
    if not data.port_name or len(data.port_name.strip()) < 2:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="ميناء الخدمة مطلوب.",
        )
    validate_price_item_dates(data.effective_from, data.effective_to)


def validate_price_item_update(port_name: Optional[str], effective_from: Optional[date], effective_to: Optional[date]) -> None:
    if port_name is not None and len(port_name.strip()) < 2:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="ميناء الخدمة مطلوب.")
    validate_price_item_dates(effective_from, effective_to)


def validate_price_item_dates(effective_from: Optional[date], effective_to: Optional[date]) -> None:
    if effective_from and effective_to and effective_from > effective_to:
        raise coded_error(
            status.HTTP_400_BAD_REQUEST,
            "CCQ_PRICE_LIST_DATE_RANGE",
            "تاريخ بداية السريان بعد تاريخ نهايته.",
            effective_from=effective_from.isoformat(),
            effective_to=effective_to.isoformat(),
        )
