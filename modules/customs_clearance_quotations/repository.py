"""
Customs Clearance Quotations & Price Lists Repository
"""

from __future__ import annotations

from typing import List, Optional
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import select, desc

from modules.customs_clearance_quotations.model import (
    CustomsClearanceRFQ,
    CustomsClearanceQuotationItem,
    ClearanceServicePriceListItem,
)


def get_rfqs(
    db: Session,
    skip: int = 0,
    limit: int = 100,
    status: Optional[str] = None,
    port_name: Optional[str] = None,
    import_file_id: Optional[int] = None,
    include_inactive: bool = False,
) -> List[CustomsClearanceRFQ]:
    stmt = (
        select(CustomsClearanceRFQ)
        .options(joinedload(CustomsClearanceRFQ.quotations))
        .order_by(desc(CustomsClearanceRFQ.created_at))
    )
    if not include_inactive:
        stmt = stmt.where(CustomsClearanceRFQ.is_active == True)  # noqa: E712
    if status:
        stmt = stmt.where(CustomsClearanceRFQ.status == status)
    if port_name:
        stmt = stmt.where(CustomsClearanceRFQ.port_name.ilike(f"%{port_name}%"))
    if import_file_id:
        stmt = stmt.where(CustomsClearanceRFQ.import_file_id == import_file_id)

    return list(db.execute(stmt.offset(skip).limit(limit)).unique().scalars().all())


def get_rfq_by_id(db: Session, rfq_id: int) -> Optional[CustomsClearanceRFQ]:
    stmt = (
        select(CustomsClearanceRFQ)
        .options(joinedload(CustomsClearanceRFQ.quotations))
        .where(CustomsClearanceRFQ.rfq_id == rfq_id)
    )
    return db.execute(stmt).unique().scalar_one_or_none()


def get_rfq_by_code(db: Session, rfq_code: str) -> Optional[CustomsClearanceRFQ]:
    stmt = (
        select(CustomsClearanceRFQ)
        .options(joinedload(CustomsClearanceRFQ.quotations))
        .where(CustomsClearanceRFQ.rfq_code == rfq_code)
    )
    return db.execute(stmt).unique().scalar_one_or_none()


def create_rfq(db: Session, rfq_data: dict, rfq_code: str) -> CustomsClearanceRFQ:
    quotations_data = rfq_data.pop("quotations", []) or []
    rfq = CustomsClearanceRFQ(**rfq_data, rfq_code=rfq_code)
    db.add(rfq)
    db.flush()

    for q in quotations_data:
        q_dict = q if isinstance(q, dict) else q.model_dump()
        quotation = CustomsClearanceQuotationItem(rfq_id=rfq.rfq_id, **q_dict)
        db.add(quotation)

    db.commit()
    db.refresh(rfq)
    return rfq


def update_rfq(db: Session, rfq_id: int, update_data: dict) -> Optional[CustomsClearanceRFQ]:
    rfq = get_rfq_by_id(db, rfq_id)
    if not rfq:
        return None
    for k, v in update_data.items():
        if v is not None and hasattr(rfq, k):
            setattr(rfq, k, v)
    db.commit()
    db.refresh(rfq)
    return rfq


def delete_rfq(db: Session, rfq_id: int, soft: bool = True) -> bool:
    rfq = get_rfq_by_id(db, rfq_id)
    if not rfq:
        return False
    if soft:
        rfq.is_active = False
        for q in rfq.quotations:
            q.is_active = False
    else:
        db.delete(rfq)
    db.commit()
    return True


def get_quotation_by_id(db: Session, quotation_id: int) -> Optional[CustomsClearanceQuotationItem]:
    stmt = select(CustomsClearanceQuotationItem).where(CustomsClearanceQuotationItem.quotation_id == quotation_id)
    return db.execute(stmt).scalar_one_or_none()


def add_quotation_to_rfq(db: Session, rfq_id: int, quotation_data: dict) -> CustomsClearanceQuotationItem:
    quotation = CustomsClearanceQuotationItem(rfq_id=rfq_id, **quotation_data)
    db.add(quotation)
    db.commit()
    db.refresh(quotation)
    return quotation


def update_quotation(db: Session, quotation_id: int, update_data: dict) -> Optional[CustomsClearanceQuotationItem]:
    quotation = get_quotation_by_id(db, quotation_id)
    if not quotation:
        return None
    for k, v in update_data.items():
        if v is not None and hasattr(quotation, k):
            setattr(quotation, k, v)
    db.commit()
    db.refresh(quotation)
    return quotation


def delete_quotation(db: Session, quotation_id: int) -> bool:
    quotation = get_quotation_by_id(db, quotation_id)
    if not quotation:
        return False
    db.delete(quotation)
    db.commit()
    return True


# ─────────────────────────────────────────────────────────────────────────────
# Price List Repository
# ─────────────────────────────────────────────────────────────────────────────

def get_price_list_items(
    db: Session,
    provider_id: Optional[int] = None,
    port_name: Optional[str] = None,
    service_categories: Optional[List[str]] = None,
    include_inactive: bool = False,
) -> List[ClearanceServicePriceListItem]:
    stmt = select(ClearanceServicePriceListItem).order_by(ClearanceServicePriceListItem.provider_name.asc())
    if not include_inactive:
        stmt = stmt.where(ClearanceServicePriceListItem.is_active == True)  # noqa: E712
    if provider_id:
        stmt = stmt.where(ClearanceServicePriceListItem.provider_id == provider_id)
    if port_name:
        stmt = stmt.where(ClearanceServicePriceListItem.port_name.ilike(f"%{port_name}%"))
    if service_categories:
        stmt = stmt.where(ClearanceServicePriceListItem.service_category.in_(service_categories))

    return list(db.execute(stmt).scalars().all())


def get_price_item_by_id(db: Session, price_item_id: int) -> Optional[ClearanceServicePriceListItem]:
    stmt = select(ClearanceServicePriceListItem).where(ClearanceServicePriceListItem.price_item_id == price_item_id)
    return db.execute(stmt).scalar_one_or_none()


def create_price_item(db: Session, price_data: dict) -> ClearanceServicePriceListItem:
    item = ClearanceServicePriceListItem(**price_data)
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


def update_price_item(db: Session, price_item_id: int, update_data: dict) -> Optional[ClearanceServicePriceListItem]:
    item = get_price_item_by_id(db, price_item_id)
    if not item:
        return None
    for k, v in update_data.items():
        if v is not None and hasattr(item, k):
            setattr(item, k, v)
    db.commit()
    db.refresh(item)
    return item


def delete_price_item(db: Session, price_item_id: int) -> bool:
    item = get_price_item_by_id(db, price_item_id)
    if not item:
        return False
    item.is_active = False
    db.commit()
    return True
