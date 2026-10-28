"""
Master Items Validators (MD-ITEM-001)
Business logic validators for Item Master Data, Supplier Linkages, and Prices.
"""

from __future__ import annotations

from typing import Optional
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.customs_tariff.model import CustomsTariff
from modules.suppliers.model import Supplier
from modules.master_items.model import MasterItem, ItemSupplierCatalog


class MasterItemValidator:

    @staticmethod
    def validate_item_code_unique(
        db: Session,
        item_code: str,
        exclude_item_id: Optional[int] = None,
    ) -> None:
        query = db.query(MasterItem).filter(
            MasterItem.item_code == item_code.strip(),
            MasterItem.is_active == True,
        )
        if exclude_item_id:
            query = query.filter(MasterItem.item_id != exclude_item_id)
        
        if query.first():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "code": "ITEM_CODE_ALREADY_EXISTS",
                    "message": f"كود الصنف '{item_code}' مسجل بالفعل في دليل الأصناف.",
                },
            )

    @staticmethod
    def validate_tariff_exists(db: Session, tariff_id: Optional[int]) -> Optional[CustomsTariff]:
        if not tariff_id:
            return None
        tariff = db.query(CustomsTariff).filter(
            CustomsTariff.tariff_id == tariff_id,
            CustomsTariff.is_active == True,
        ).first()
        if not tariff:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "code": "TARIFF_NOT_FOUND",
                    "message": f"بند التعريفة الجمركية رقم {tariff_id} غير موجود أو غير مفعل.",
                },
            )
        return tariff

    @staticmethod
    def validate_supplier_exists(db: Session, supplier_id: int) -> Supplier:
        supplier = db.query(Supplier).filter(
            Supplier.supplier_id == supplier_id,
            Supplier.is_active == True,
        ).first()
        if not supplier:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "code": "SUPPLIER_NOT_FOUND",
                    "message": f"المورد الأجنبي رقم {supplier_id} غير موجود في الدليل.",
                },
            )
        return supplier

    @staticmethod
    def validate_supplier_link_unique(
        db: Session,
        item_id: int,
        supplier_id: int,
        exclude_catalog_id: Optional[int] = None,
    ) -> None:
        query = db.query(ItemSupplierCatalog).filter(
            ItemSupplierCatalog.item_id == item_id,
            ItemSupplierCatalog.supplier_id == supplier_id,
            ItemSupplierCatalog.is_active == True,
        )
        if exclude_catalog_id:
            query = query.filter(ItemSupplierCatalog.catalog_id != exclude_catalog_id)

        if query.first():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "code": "ITEM_SUPPLIER_LINK_EXISTS",
                    "message": "هذا الصنف مرتبط بالفعل بهذا المورد في كتالوج الأسعار.",
                },
            )
