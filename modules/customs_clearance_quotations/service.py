"""
Customs Clearance Quotations & Price Lists Service
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import select, func
from fastapi import HTTPException, status

from modules.customs_clearance_quotations.model import (
    CustomsClearanceRFQ,
    CustomsClearanceQuotationItem,
    ClearanceServicePriceListItem,
)
from modules.customs_clearance_quotations.schemas import (
    CustomsClearanceRFQCreate,
    CustomsClearanceRFQUpdate,
    CustomsClearanceQuotationCreate,
    CustomsClearanceQuotationUpdate,
    ClearancePriceListItemCreate,
    ClearancePriceListItemUpdate,
)
import modules.customs_clearance_quotations.repository as repo
import modules.customs_clearance_quotations.validators as val
from modules.common import enum_codes


def _normalize_quote_fields(data: dict) -> dict:
    """Tier-3 fields: service_category -> CLEARANCE_QUOTE_SERVICE_CATEGORY code, currency -> ISO code."""
    if data.get("service_category") is not None:
        data["service_category"] = enum_codes.normalize(
            enum_codes.CLEARANCE_QUOTE_SERVICE_CATEGORY, data["service_category"]
        )
    if data.get("currency") is not None:
        data["currency"] = enum_codes.normalize_currency(data["currency"])
    return data


def generate_rfq_code(db: Session) -> str:
    count = db.execute(select(func.count(CustomsClearanceRFQ.rfq_id))).scalar() or 0
    return f"CRFQ-{count + 1:06d}"


def recalculate_rfq_metrics(db: Session, rfq_id: int) -> Optional[CustomsClearanceRFQ]:
    rfq = repo.get_rfq_by_id(db, rfq_id)
    if not rfq:
        return None

    active_quotes = [q for q in rfq.quotations if q.is_active]
    if active_quotes:
        rfq.lowest_clearance_cost = min(q.total_cost for q in active_quotes)
        rfq.fastest_turnaround_days = min(q.estimated_turnaround_days for q in active_quotes)
        if rfq.status == "Draft":
            rfq.status = "Quotations Received"
    else:
        rfq.lowest_clearance_cost = 0.0
        rfq.fastest_turnaround_days = 0

    db.commit()
    db.refresh(rfq)
    return rfq


def create_rfq_service(db: Session, data: CustomsClearanceRFQCreate) -> CustomsClearanceRFQ:
    val.validate_rfq_create(data)
    rfq_code = generate_rfq_code(db)
    rfq_data = data.model_dump()

    # Pre-calculate totals for initial quotations if provided
    if "quotations" in rfq_data and rfq_data["quotations"]:
        for q in rfq_data["quotations"]:
            if not q.get("total_cost"):
                q["total_cost"] = (
                    (q.get("clearance_fee") or 0.0)
                    + (q.get("inland_transport_fee") or 0.0)
                    + (q.get("inspection_fee") or 0.0)
                    + (q.get("port_expenses") or 0.0)
                    + (q.get("miscellaneous_fee") or 0.0)
                )

    rfq = repo.create_rfq(db, rfq_data, rfq_code)
    return recalculate_rfq_metrics(db, rfq.rfq_id) or rfq


def get_rfqs_service(
    db: Session,
    skip: int = 0,
    limit: int = 100,
    status_filter: Optional[str] = None,
    port_name: Optional[str] = None,
    import_file_id: Optional[int] = None,
    include_inactive: bool = False,
) -> List[CustomsClearanceRFQ]:
    return repo.get_rfqs(
        db,
        skip=skip,
        limit=limit,
        status=status_filter,
        port_name=port_name,
        import_file_id=import_file_id,
        include_inactive=include_inactive,
    )


def get_rfq_by_id_service(db: Session, rfq_id: int) -> CustomsClearanceRFQ:
    rfq = repo.get_rfq_by_id(db, rfq_id)
    if not rfq:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"طلب عرض أسعار التخليص رقم {rfq_id} غير موجود.",
        )
    return rfq


def update_rfq_service(db: Session, rfq_id: int, data: CustomsClearanceRFQUpdate) -> CustomsClearanceRFQ:
    rfq = repo.get_rfq_by_id(db, rfq_id)
    if not rfq:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="السجل غير موجود")

    update_dict = data.model_dump(exclude_unset=True)
    updated = repo.update_rfq(db, rfq_id, update_dict)
    return recalculate_rfq_metrics(db, rfq_id) or updated  # type: ignore


def delete_rfq_service(db: Session, rfq_id: int) -> bool:
    success = repo.delete_rfq(db, rfq_id, soft=True)
    if not success:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="السجل غير موجود")
    return True


def add_quotation_service(
    db: Session, rfq_id: int, data: CustomsClearanceQuotationCreate
) -> CustomsClearanceQuotationItem:
    rfq = repo.get_rfq_by_id(db, rfq_id)
    if not rfq:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"طلب عرض أسعار التخليص {rfq_id} غير موجود.",
        )

    val.validate_quotation_create(data)
    q_data = _normalize_quote_fields(data.model_dump())
    if not q_data.get("total_cost"):
        q_data["total_cost"] = (
            (q_data.get("clearance_fee") or 0.0)
            + (q_data.get("inland_transport_fee") or 0.0)
            + (q_data.get("inspection_fee") or 0.0)
            + (q_data.get("port_expenses") or 0.0)
            + (q_data.get("miscellaneous_fee") or 0.0)
        )

    quotation = repo.add_quotation_to_rfq(db, rfq_id, q_data)
    recalculate_rfq_metrics(db, rfq_id)
    return quotation


def update_quotation_service(
    db: Session, quotation_id: int, data: CustomsClearanceQuotationUpdate
) -> CustomsClearanceQuotationItem:
    q = repo.get_quotation_by_id(db, quotation_id)
    if not q:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="عرض السعر غير موجود")

    q_data = _normalize_quote_fields(data.model_dump(exclude_unset=True))
    updated = repo.update_quotation(db, quotation_id, q_data)

    # Recalculate total cost if cost elements changed
    if any(k in q_data for k in ["clearance_fee", "inland_transport_fee", "inspection_fee", "port_expenses", "miscellaneous_fee"]):
        updated.total_cost = (
            updated.clearance_fee
            + updated.inland_transport_fee
            + updated.inspection_fee
            + updated.port_expenses
            + updated.miscellaneous_fee
        )
        db.commit()
        db.refresh(updated)

    recalculate_rfq_metrics(db, updated.rfq_id)
    return updated


def delete_quotation_service(db: Session, quotation_id: int) -> bool:
    q = repo.get_quotation_by_id(db, quotation_id)
    if not q:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="عرض السعر غير موجود")
    rfq_id = q.rfq_id
    success = repo.delete_quotation(db, quotation_id)
    recalculate_rfq_metrics(db, rfq_id)
    return success


def award_quotation_service(
    db: Session, rfq_id: int, quotation_id: int, notes: Optional[str] = None
) -> CustomsClearanceRFQ:
    rfq = repo.get_rfq_by_id(db, rfq_id)
    if not rfq:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="طلب عرض الأسعار غير موجود")

    target_quote = repo.get_quotation_by_id(db, quotation_id)
    if not target_quote or target_quote.rfq_id != rfq_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="عرض السعر المحدد لا ينتمي لهذا الطلب.",
        )

    # Mark this quote as awarded and un-award others
    for q in rfq.quotations:
        q.is_awarded = (q.quotation_id == quotation_id)

    rfq.awarded_provider_id = target_quote.provider_id
    rfq.awarded_provider_name = target_quote.provider_name
    rfq.awarded_quotation_id = target_quote.quotation_id
    rfq.awarded_at = datetime.now(timezone.utc)
    rfq.status = "Awarded"

    db.commit()
    db.refresh(rfq)
    return rfq


# ─────────────────────────────────────────────────────────────────────────────
# Price List Services
# ─────────────────────────────────────────────────────────────────────────────

def get_price_list_service(
    db: Session,
    provider_id: Optional[int] = None,
    port_name: Optional[str] = None,
    service_category: Optional[str] = None,
    include_inactive: bool = False,
) -> List[ClearanceServicePriceListItem]:
    categories: Optional[List[str]] = None
    if service_category:
        code = enum_codes.normalize(enum_codes.CLEARANCE_QUOTE_SERVICE_CATEGORY, service_category)
        # A code also matches legacy rows stored with its Arabic/English label.
        categories = (
            enum_codes.legacy_values(enum_codes.CLEARANCE_QUOTE_SERVICE_CATEGORY, code)
            if enum_codes.is_code(enum_codes.CLEARANCE_QUOTE_SERVICE_CATEGORY, code)
            else [service_category]
        )
    return repo.get_price_list_items(
        db,
        provider_id=provider_id,
        port_name=port_name,
        service_categories=categories,
        include_inactive=include_inactive,
    )


def create_price_item_service(
    db: Session, data: ClearancePriceListItemCreate
) -> ClearanceServicePriceListItem:
    val.validate_price_item_create(data)
    return repo.create_price_item(db, _normalize_quote_fields(data.model_dump()))


def update_price_item_service(
    db: Session, item_id: int, data: ClearancePriceListItemUpdate
) -> ClearanceServicePriceListItem:
    updated = repo.update_price_item(db, item_id, _normalize_quote_fields(data.model_dump(exclude_unset=True)))
    if not updated:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="بند قائمة الأسعار غير موجود")
    return updated


def delete_price_item_service(db: Session, item_id: int) -> bool:
    success = repo.delete_price_item(db, item_id)
    if not success:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="بند قائمة الأسعار غير موجود")
    return True
