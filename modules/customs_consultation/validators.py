"""
Customs Consultation & Broker Price Lists Business Validators (BP-009)
"""

from typing import Iterable, Optional, Type
from fastapi import HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from modules.common.validators import not_null_columns, require_active
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile
from modules.projects.model import Project
from modules.purchase_orders.model import PurchaseOrder
from modules.customs_consultation.model import (
    BrokerPriceList,
    ClearanceExpenseType,
)


def validate_broker_exists(db: Session, broker_id: int) -> ExternalServiceProvider:
    """
    Validates that the given broker ID exists in external_service_providers table and is active.
    """
    return require_active(db, ExternalServiceProvider, broker_id, "المخلص الجمركي")


def validate_references(
    db: Session,
    import_file_id: Optional[int] = None,
    po_id: Optional[int] = None,
    project_id: Optional[int] = None,
    broker_price_list_id: Optional[int] = None,
    expense_type_ids: Optional[Iterable[Optional[int]]] = None,
) -> None:
    """
    Validates that optional master/transaction references exist and are active.
    """
    if import_file_id is not None:
        require_active(db, ImportFile, import_file_id, "ملف الاستيراد")
    if po_id is not None:
        require_active(db, PurchaseOrder, po_id, "أمر الشراء")
    if project_id is not None:
        require_active(db, Project, project_id, "المشروع")
    if broker_price_list_id is not None:
        require_active(db, BrokerPriceList, broker_price_list_id, "قائمة أسعار المخلص")
    if expense_type_ids:
        for eid in expense_type_ids:
            if eid is not None:
                require_active(db, ClearanceExpenseType, eid, "نوع المصروف")


def reject_cleared_not_null_fields(model: Type, update_schema: BaseModel, label_ar: str = "السجل") -> None:
    """
    Rejects explicit null values sent on NOT NULL columns during update.
    """
    sent = update_schema.model_dump(exclude_unset=True)
    for field in not_null_columns(model):
        if field in sent and sent[field] is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"لا يمكن مسح الحقل الإلزامي '{field}' في {label_ar}.",
            )


def validate_expense_code_unique(db: Session, code: str, current_id: int | None = None) -> None:
    query = db.query(ClearanceExpenseType).filter(ClearanceExpenseType.expense_code == code)
    if current_id:
        query = query.filter(ClearanceExpenseType.expense_id != current_id)
    if query.first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Expense code '{code}' already exists.",
        )


def validate_checklist_items(items: list) -> None:
    """
    Validates checklist items consistency.
    """
    valid_statuses = {"Pending", "Received", "Verified", "Approved", "Rejected"}
    for item in items:
        status_val = getattr(item, "status", None) or item.get("status") if isinstance(item, dict) else getattr(item, "status", "Pending")
        if status_val not in valid_statuses:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid document status '{status_val}'. Valid statuses: {valid_statuses}",
            )
