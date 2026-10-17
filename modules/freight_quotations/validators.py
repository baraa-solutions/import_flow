"""
Freight Quotations Business Validators (BP-008)
"""

from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from modules.external_service_providers.model import ExternalServiceProvider
from modules.common.validators import require_active


def validate_carrier_exists(db: Session, provider_id: int) -> ExternalServiceProvider:
    """
    Validates that carrier / freight provider ID exists and is active in external_service_providers table.
    """
    return require_active(
        db,
        ExternalServiceProvider,
        provider_id,
        "مقدم خدمة الشحن",
        status_code=status.HTTP_400_BAD_REQUEST,
    )


def validate_quotation_dates(crd_date, sailing_date, arrival_date) -> None:
    """
    Validates date sequence: sailing_date >= crd_date, arrival_date > sailing_date.
    """
    if sailing_date < crd_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Sailing date ({sailing_date}) cannot be before Cargo Ready Date ({crd_date}).",
        )

    if arrival_date <= sailing_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Estimated arrival date ({arrival_date}) must be after sailing date ({sailing_date}).",
        )


def validate_import_file_exists(db: Session, import_file_id: int):
    """
    Validates that the linked import file exists and is active.
    """
    from modules.import_files.model import ImportFile
    file_obj = db.query(ImportFile).filter(
        ImportFile.import_file_id == import_file_id,
        ImportFile.is_active == True,
    ).first()
    if not file_obj:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Active Import File with ID '{import_file_id}' not found.",
        )
    return file_obj


def validate_po_exists(db: Session, po_id: int):
    """
    Validates that the linked purchase order exists and is active.
    """
    from modules.purchase_orders.model import PurchaseOrder
    po_obj = db.query(PurchaseOrder).filter(
        PurchaseOrder.po_id == po_id,
        PurchaseOrder.is_active == True,
    ).first()
    if not po_obj:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Active Purchase Order with ID '{po_id}' not found.",
        )
    return po_obj


def validate_project_exists(db: Session, project_id: int):
    """
    Validates that the linked project exists and is active.
    """
    from modules.projects.model import Project
    project_obj = db.query(Project).filter(
        Project.project_id == project_id,
        Project.is_active == True,
    ).first()
    if not project_obj:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Active Project with ID '{project_id}' not found.",
        )
    return project_obj


def validate_quotation_currencies(db: Session, quotations: list) -> None:
    """Validate currency codes for all freight quotations: required when costs > 0, normalized to uppercase."""
    from modules.common.validators import validate_price_currency
    for q in quotations:
        ocean = getattr(q, "ocean_freight_cost", 0.0) if hasattr(q, "ocean_freight_cost") else (q.get("ocean_freight_cost", 0.0) if isinstance(q, dict) else 0.0)
        local = getattr(q, "local_charges_cost", 0.0) if hasattr(q, "local_charges_cost") else (q.get("local_charges_cost", 0.0) if isinstance(q, dict) else 0.0)
        inland = getattr(q, "inland_cost", 0.0) if hasattr(q, "inland_cost") else (q.get("inland_cost", 0.0) if isinstance(q, dict) else 0.0)
        total = getattr(q, "total_cost", 0.0) if hasattr(q, "total_cost") else (q.get("total_cost", 0.0) if isinstance(q, dict) else 0.0)
        price = max(float(ocean or 0.0), float(local or 0.0), float(inland or 0.0), float(total or 0.0))
        curr = getattr(q, "currency_code", None) if hasattr(q, "currency_code") else (q.get("currency_code") if isinstance(q, dict) else None)
        normalized = validate_price_currency(db, price, curr, label_ar="عملة عرض الشحن")
        if hasattr(q, "currency_code"):
            setattr(q, "currency_code", normalized)
        elif isinstance(q, dict):
            q["currency_code"] = normalized

