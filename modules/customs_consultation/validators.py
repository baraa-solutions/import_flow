"""
Customs Consultation & Broker Price Lists Business Validators (BP-009)
"""

from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from modules.external_service_providers.model import ExternalServiceProvider
from modules.customs_consultation.model import ClearanceExpenseType


def validate_broker_exists(db: Session, broker_id: int) -> ExternalServiceProvider:
    """
    Validates that the given broker ID exists in external_service_providers table.
    """
    broker = (
        db.query(ExternalServiceProvider)
        .filter(ExternalServiceProvider.provider_id == broker_id)
        .first()
    )
    if not broker:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Customs Broker with ID '{broker_id}' not found.",
        )
    return broker


def validate_expense_code_unique(db: Session, code: str | None, current_id: int | None = None) -> None:
    if not code:
        return
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
