"""
Master Items Service (MD-ITEM-001)
Business logic for managing master items, supplier price catalogs, and landed cost histories.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.master_items.model import (
    MasterItem,
    ItemSupplierCatalog,
    ItemPriceHistory,
)
from modules.master_items.schemas import (
    MasterItemCreate,
    MasterItemUpdate,
    MasterItemResponse,
    MasterItemListResponse,
    ItemSupplierCatalogCreate,
    ItemSupplierCatalogUpdate,
    ItemSupplierCatalogResponse,
    ItemPriceHistoryCreate,
    ItemPriceHistoryResponse,
    ItemPriceTrendResponse,
)
from modules.master_items.repository import (
    MasterItemRepository,
    ItemSupplierCatalogRepository,
    ItemPriceHistoryRepository,
)
from modules.master_items.validators import MasterItemValidator


class MasterItemService:

    @classmethod
    def create_item(
        cls,
        db: Session,
        payload: MasterItemCreate,
        current_username: Optional[str] = None,
    ) -> MasterItemResponse:
        MasterItemValidator.validate_item_code_unique(db, payload.item_code)
        tariff = MasterItemValidator.validate_tariff_exists(db, payload.tariff_id)

        item = MasterItem(
            item_code=payload.item_code.strip(),
            description_ar=payload.description_ar.strip(),
            description_en=payload.description_en.strip() if payload.description_en else None,
            tariff_id=payload.tariff_id,
            default_uom=payload.default_uom or "PCS",
            default_pkg_type=payload.default_pkg_type or "Carton",
            cbm_per_unit=payload.cbm_per_unit or 0.0,
            gross_weight_kg=payload.gross_weight_kg or 0.0,
            net_weight_kg=payload.net_weight_kg or 0.0,
            product_category=payload.product_category,
            product_subcategory=payload.product_subcategory,
            notes=payload.notes,
            created_by=current_username,
        )

        if tariff:
            item.last_customs_duty_pct = float(tariff.customs_duty_rate or 0.0)
            item.last_vat_pct = float(tariff.vat_rate or 0.0)
            item.last_schedule_tax_pct = float(tariff.schedule_tax_rate or 0.0)

        created = MasterItemRepository.create(db, item)
        db.commit()
        db.refresh(created)
        return cls._to_item_response(created)

    @classmethod
    def get_item(cls, db: Session, item_id: int) -> MasterItemResponse:
        item = MasterItemRepository.get_by_id(db, item_id)
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"code": "ITEM_NOT_FOUND", "message": f"الصنف رقم {item_id} غير مسجل أو محذوف."},
            )
        return cls._to_item_response(item)

    @classmethod
    def list_items(
        cls,
        db: Session,
        search: Optional[str] = None,
        category: Optional[str] = None,
        skip: int = 0,
        limit: int = 100,
    ) -> MasterItemListResponse:
        items, total = MasterItemRepository.list_items(
            db, search=search, category=category, skip=skip, limit=limit
        )
        return MasterItemListResponse(
            total=total,
            items=[cls._to_item_response(i) for i in items],
        )

    @classmethod
    def update_item(
        cls,
        db: Session,
        item_id: int,
        payload: MasterItemUpdate,
        current_username: Optional[str] = None,
    ) -> MasterItemResponse:
        item = MasterItemRepository.get_by_id(db, item_id)
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"code": "ITEM_NOT_FOUND", "message": f"الصنف رقم {item_id} غير موجود."},
            )

        if payload.item_code and payload.item_code != item.item_code:
            MasterItemValidator.validate_item_code_unique(db, payload.item_code, exclude_item_id=item_id)
            item.item_code = payload.item_code.strip()

        if payload.tariff_id is not None:
            tariff = MasterItemValidator.validate_tariff_exists(db, payload.tariff_id)
            item.tariff_id = payload.tariff_id
            if tariff:
                item.last_customs_duty_pct = float(tariff.customs_duty_rate or 0.0)
                item.last_vat_pct = float(tariff.vat_rate or 0.0)
                item.last_schedule_tax_pct = float(tariff.schedule_tax_rate or 0.0)

        for field in [
            "description_ar",
            "description_en",
            "default_uom",
            "default_pkg_type",
            "cbm_per_unit",
            "gross_weight_kg",
            "net_weight_kg",
            "product_category",
            "product_subcategory",
            "notes",
            "is_active",
        ]:
            val = getattr(payload, field)
            if val is not None:
                setattr(item, field, val)

        item.updated_at = datetime.now(timezone.utc)
        item.updated_by = current_username

        updated = MasterItemRepository.update(db, item)
        db.commit()
        db.refresh(updated)
        return cls._to_item_response(updated)

    @classmethod
    def delete_item(
        cls,
        db: Session,
        item_id: int,
        current_username: Optional[str] = None,
    ) -> dict:
        item = MasterItemRepository.get_by_id(db, item_id)
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"code": "ITEM_NOT_FOUND", "message": f"الصنف رقم {item_id} غير موجود."},
            )
        MasterItemRepository.soft_delete(db, item, deleted_by=current_username)
        db.commit()
        return {"success": True, "message": f"تم تعطيل الصنف '{item.item_code}' بنجاح."}

    # ==================================================
    # Supplier Catalog Operations
    # ==================================================

    @classmethod
    def link_supplier(
        cls,
        db: Session,
        payload: ItemSupplierCatalogCreate,
    ) -> ItemSupplierCatalogResponse:
        item = MasterItemRepository.get_by_id(db, payload.item_id)
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"code": "ITEM_NOT_FOUND", "message": f"الصنف رقم {payload.item_id} غير موجود."},
            )

        MasterItemValidator.validate_supplier_exists(db, payload.supplier_id)
        MasterItemValidator.validate_supplier_link_unique(db, payload.item_id, payload.supplier_id)

        catalog = ItemSupplierCatalog(
            item_id=payload.item_id,
            supplier_id=payload.supplier_id,
            supplier_item_code=payload.supplier_item_code,
            supplier_description=payload.supplier_description,
            last_confirmed_price=payload.last_confirmed_price,
            last_confirmed_currency=payload.last_confirmed_currency or "USD",
            last_confirmed_date=payload.last_confirmed_date,
            last_po_id=payload.last_po_id,
            min_order_qty=payload.min_order_qty,
            lead_time_days=payload.lead_time_days,
            preferred_incoterm=payload.preferred_incoterm,
            is_preferred_supplier=payload.is_preferred_supplier,
            notes=payload.notes,
        )

        created = ItemSupplierCatalogRepository.create(db, catalog)
        db.commit()
        db.refresh(created)
        return cls._to_catalog_response(created)

    @classmethod
    def list_suppliers_for_item(
        cls,
        db: Session,
        item_id: int,
    ) -> List[ItemSupplierCatalogResponse]:
        item = MasterItemRepository.get_by_id(db, item_id)
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"code": "ITEM_NOT_FOUND", "message": f"الصنف رقم {item_id} غير موجود."},
            )
        catalogs = ItemSupplierCatalogRepository.list_by_item(db, item_id)
        return [cls._to_catalog_response(c) for c in catalogs]

    # ==================================================
    # Price History & Analysis
    # ==================================================

    @classmethod
    def record_price_history(
        cls,
        db: Session,
        payload: ItemPriceHistoryCreate,
    ) -> ItemPriceHistoryResponse:
        rate = payload.exchange_rate or 1.0
        unit_egp = payload.unit_price_egp
        if unit_egp is None:
            unit_egp = payload.unit_price_fx * rate

        record = ItemPriceHistory(
            item_id=payload.item_id,
            supplier_id=payload.supplier_id,
            po_id=payload.po_id,
            import_file_id=payload.import_file_id,
            unit_price_fx=payload.unit_price_fx,
            currency=payload.currency,
            exchange_rate=rate,
            unit_price_egp=unit_egp,
            landed_cost_egp=payload.landed_cost_egp,
            landed_cost_markup=payload.landed_cost_markup,
            quantity=payload.quantity,
            po_date=payload.po_date,
        )
        saved = ItemPriceHistoryRepository.record(db, record)
        db.commit()
        db.refresh(saved)
        return cls._to_history_response(saved)

    @classmethod
    def get_price_trends(
        cls,
        db: Session,
        item_id: int,
    ) -> ItemPriceTrendResponse:
        item = MasterItemRepository.get_by_id(db, item_id)
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"code": "ITEM_NOT_FOUND", "message": f"الصنف رقم {item_id} غير موجود."},
            )

        history = ItemPriceHistoryRepository.list_by_item(db, item_id, limit=50)
        history_responses = [cls._to_history_response(h) for h in history]

        prices = [h.unit_price_fx for h in history if h.unit_price_fx is not None]
        landed_costs = [h.landed_cost_egp for h in history if h.landed_cost_egp is not None]
        markups = [h.landed_cost_markup for h in history if h.landed_cost_markup is not None]

        count = len(prices)
        avg_price = sum(prices) / count if count > 0 else 0.0
        min_price = min(prices) if count > 0 else 0.0
        max_price = max(prices) if count > 0 else 0.0

        avg_landed = sum(landed_costs) / len(landed_costs) if landed_costs else None
        avg_markup = sum(markups) / len(markups) if markups else None

        return ItemPriceTrendResponse(
            item_id=item.item_id,
            item_code=item.item_code,
            description_ar=item.description_ar,
            total_purchases_count=count,
            average_unit_price_fx=round(avg_price, 4),
            min_unit_price_fx=round(min_price, 4),
            max_unit_price_fx=round(max_price, 4),
            average_landed_cost_egp=round(avg_landed, 2) if avg_landed else None,
            average_markup_percent=round(avg_markup, 2) if avg_markup else None,
            history=history_responses,
        )

    # ==================================================
    # Private Helpers
    # ==================================================

    @staticmethod
    def _to_item_response(item: MasterItem) -> MasterItemResponse:
        resp = MasterItemResponse.model_validate(item)
        if item.tariff:
            resp.hs_code = item.tariff.hs_code
        return resp

    @staticmethod
    def _to_catalog_response(c: ItemSupplierCatalog) -> ItemSupplierCatalogResponse:
        resp = ItemSupplierCatalogResponse.model_validate(c)
        if c.supplier:
            resp.supplier_name = c.supplier.company_name
        if c.item:
            resp.item_code = c.item.item_code
        return resp

    @staticmethod
    def _to_history_response(h: ItemPriceHistory) -> ItemPriceHistoryResponse:
        resp = ItemPriceHistoryResponse.model_validate(h)
        if h.supplier:
            resp.supplier_name = h.supplier.company_name
        if h.purchase_order:
            resp.po_number = h.purchase_order.po_number
        if h.import_file:
            resp.import_file_code = h.import_file.import_file_code
        return resp
