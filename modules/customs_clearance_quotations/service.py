"""
Customs Clearance Quotations & Price Lists Service (one commit per request; repositories only flush).
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

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

logger = logging.getLogger(__name__)

RFQ_CODE_ATTEMPTS = 3
COST_COMPONENTS = ("clearance_fee", "inland_transport_fee", "inspection_fee", "port_expenses", "miscellaneous_fee")
BASE_CURRENCY = "EGP"


def _normalize_quote_fields(data: dict) -> dict:
    """Tier-3 fields: service_category -> CLEARANCE_QUOTE_SERVICE_CATEGORY code, currency -> ISO code."""
    if data.get("service_category") is not None:
        data["service_category"] = enum_codes.normalize(
            enum_codes.CLEARANCE_QUOTE_SERVICE_CATEGORY, data["service_category"]
        )
    if data.get("currency") is not None:
        data["currency"] = enum_codes.normalize_currency(data["currency"])
    return data


def quote_total(source) -> float:
    """CCQ-05: a quote total is always the sum of its five cost components (a client total is ignored)."""
    get = source.get if isinstance(source, dict) else (lambda name: getattr(source, name, 0.0))
    return sum(float(get(name) or 0.0) for name in COST_COMPONENTS)


def generate_rfq_code(db: Session) -> str:
    return repo.next_rfq_code(db)


def _rfq_or_404(db: Session, rfq_id: int) -> CustomsClearanceRFQ:
    rfq = repo.get_rfq_by_id(db, rfq_id, active_only=True)
    if not rfq:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"طلب عرض أسعار التخليص رقم {rfq_id} غير موجود.",
        )
    return rfq


def _quote_or_404(db: Session, quotation_id: int) -> CustomsClearanceQuotationItem:
    quote = repo.get_quotation_by_id(db, quotation_id, active_only=True)
    if not quote or not repo.get_rfq_by_id(db, quote.rfq_id, active_only=True):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="عرض السعر غير موجود")
    return quote


def recalculate_rfq_metrics(db: Session, rfq: CustomsClearanceRFQ) -> CustomsClearanceRFQ:
    """Lowest cost / fastest days over the active quotes; Draft -> "Quotations Received" on the first quote.
    Mixed currencies: the lowest cost is taken over the EGP quotes only (Q8). No commit."""
    active_quotes = repo.get_active_quotations(db, rfq.rfq_id)
    if active_quotes:
        def ccy(q) -> str:
            return (q.currency or BASE_CURRENCY).strip().upper()

        currencies = {ccy(q) for q in active_quotes}
        # lowest_clearance_cost is NOT NULL (no migration in this wave): mixed currencies without an EGP quote -> 0.0.
        priced = active_quotes if len(currencies) == 1 else [q for q in active_quotes if ccy(q) == BASE_CURRENCY]
        rfq.lowest_clearance_cost = min((q.total_cost for q in priced), default=0.0)
        rfq.fastest_turnaround_days = min(q.estimated_turnaround_days for q in active_quotes)
        if rfq.status == "Draft":
            rfq.status = "Quotations Received"
    else:
        rfq.lowest_clearance_cost = 0.0
        rfq.fastest_turnaround_days = 0
    return rfq


def _prepare_quote(db: Session, data: CustomsClearanceQuotationCreate) -> dict:
    """CCQ-06: the same validation + normalization for standalone and nested quotes."""
    val.validate_quotation_create(data)
    provider = val.validate_quotation_provider(db, data.provider_id)
    q_data = _normalize_quote_fields(data.model_dump())
    q_data["provider_name"] = provider.partner_name
    q_data["total_cost"] = quote_total(q_data)
    return q_data


def create_rfq_service(db: Session, data: CustomsClearanceRFQCreate, user: str = "System") -> CustomsClearanceRFQ:
    val.validate_rfq_create(data)
    val.validate_rfq_links(db, import_file_id=data.import_file_id, project_id=data.project_id, port_id=data.port_id)
    quotes = [_prepare_quote(db, q) for q in (data.quotations or [])]
    rfq_data = data.model_dump(exclude={"quotations"})

    for attempt in range(1, RFQ_CODE_ATTEMPTS + 1):
        rfq_code = generate_rfq_code(db)
        try:
            rfq = repo.create_rfq(db, {**rfq_data, "quotations": [dict(q) for q in quotes]}, rfq_code, user=user)
            recalculate_rfq_metrics(db, rfq)
            db.commit()
        except IntegrityError:
            db.rollback()
            if not repo.rfq_code_exists(db, rfq_code) or attempt == RFQ_CODE_ATTEMPTS:
                raise
            logger.info("RFQ code %s taken concurrently; retrying (%s/%s)", rfq_code, attempt, RFQ_CODE_ATTEMPTS)
            continue
        db.refresh(rfq)
        return rfq
    raise AssertionError("unreachable")  # pragma: no cover


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


def update_rfq_service(db: Session, rfq_id: int, data: CustomsClearanceRFQUpdate, user: str = "System") -> CustomsClearanceRFQ:
    rfq = _rfq_or_404(db, rfq_id)
    update_dict = data.model_dump(exclude_unset=True)
    val.validate_rfq_status_change(rfq.status, update_dict.get("status"))
    val.validate_rfq_links(
        db,
        import_file_id=update_dict.get("import_file_id"),
        project_id=update_dict.get("project_id"),
        port_id=update_dict.get("port_id"),
    )
    repo.update_rfq(db, rfq_id, update_dict, user=user)
    recalculate_rfq_metrics(db, rfq)
    db.commit()
    db.refresh(rfq)
    return rfq


def delete_rfq_service(db: Session, rfq_id: int, user: str = "System") -> bool:
    rfq = _rfq_or_404(db, rfq_id)
    if rfq.status == val.RFQ_STATUS_AWARDED:
        raise val.coded_error(
            status.HTTP_409_CONFLICT,
            "CCQ_RFQ_AWARDED",
            "لا يمكن حذف طلب عرض أسعار تمت ترسيته بالفعل.",
            rfq_code=rfq.rfq_code,
        )
    success = repo.delete_rfq(db, rfq_id, soft=True, user=user)
    if not success:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="السجل غير موجود")
    db.commit()
    return True


def add_quotation_service(
    db: Session, rfq_id: int, data: CustomsClearanceQuotationCreate, user: str = "System"
) -> CustomsClearanceQuotationItem:
    rfq = _rfq_or_404(db, rfq_id)
    val.validate_rfq_open(rfq)
    quotation = repo.add_quotation_to_rfq(db, rfq, _prepare_quote(db, data), user=user)
    recalculate_rfq_metrics(db, rfq)
    db.commit()
    db.refresh(quotation)
    return quotation


def update_quotation_service(
    db: Session, quotation_id: int, data: CustomsClearanceQuotationUpdate, user: str = "System"
) -> CustomsClearanceQuotationItem:
    quote = _quote_or_404(db, quotation_id)
    rfq = _rfq_or_404(db, quote.rfq_id)
    val.validate_rfq_open(rfq)
    q_data = _normalize_quote_fields(data.model_dump(exclude_unset=True))
    q_data.pop("total_cost", None)  # always server-computed
    updated = repo.update_quotation(db, quotation_id, q_data, user=user)
    updated.total_cost = quote_total(updated)
    recalculate_rfq_metrics(db, rfq)
    db.commit()
    db.refresh(updated)
    return updated


def delete_quotation_service(db: Session, quotation_id: int, user: str = "System") -> bool:
    """Soft delete (CCQ-02); the awarded quote cannot be deleted (409)."""
    quote = _quote_or_404(db, quotation_id)
    rfq = _rfq_or_404(db, quote.rfq_id)
    val.validate_rfq_open(rfq)
    val.validate_quote_deletable(quote)
    repo.soft_delete_quotation(db, quote, user=user)
    recalculate_rfq_metrics(db, rfq)
    db.commit()
    return True


def award_quotation_service(
    db: Session, rfq_id: int, quotation_id: int, notes: Optional[str] = None, user: str = "System"
) -> CustomsClearanceRFQ:
    rfq = _rfq_or_404(db, rfq_id)
    target_quote = repo.get_quotation_by_id(db, quotation_id)
    val.validate_award(rfq, target_quote)

    for q in rfq.quotations:
        q.is_awarded = (q.quotation_id == quotation_id)
        if q.is_awarded:
            q.updated_by = user
    rfq.awarded_provider_id = target_quote.provider_id
    rfq.awarded_provider_name = target_quote.provider_name
    rfq.awarded_quotation_id = target_quote.quotation_id
    rfq.awarded_at = datetime.now(timezone.utc)
    rfq.status = val.RFQ_STATUS_AWARDED
    rfq.updated_by = user

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
    db: Session, data: ClearancePriceListItemCreate, user: str = "System"
) -> ClearanceServicePriceListItem:
    val.validate_price_item_create(data)
    provider = val.validate_quotation_provider(db, data.provider_id)
    p_data = _normalize_quote_fields(data.model_dump())
    p_data["provider_name"] = provider.partner_name
    item = repo.create_price_item(db, p_data, user=user)
    db.commit()
    db.refresh(item)
    return item


def update_price_item_service(
    db: Session, item_id: int, data: ClearancePriceListItemUpdate, user: str = "System"
) -> ClearanceServicePriceListItem:
    item = repo.get_price_item_by_id(db, item_id)
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="بند قائمة الأسعار غير موجود")
    changes = data.model_dump(exclude_unset=True)
    provider_id = changes.get("provider_id", item.provider_id)
    provider = val.validate_quotation_provider(db, provider_id)
    if "provider_id" in changes:
        changes["provider_name"] = provider.partner_name
    val.validate_price_item_update(
        changes.get("port_name"),
        changes.get("effective_from") or item.effective_from,
        changes.get("effective_to") or item.effective_to,
    )
    updated = repo.update_price_item(db, item_id, _normalize_quote_fields(changes), user=user)
    db.commit()
    db.refresh(updated)
    return updated


def delete_price_item_service(db: Session, item_id: int, user: str = "System") -> bool:
    success = repo.delete_price_item(db, item_id, user=user)
    if not success:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="بند قائمة الأسعار غير موجود")
    db.commit()
    return True

