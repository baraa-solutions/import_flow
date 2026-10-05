from typing import Optional

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.cbm_calculator.model import CBMCalculation
from modules.cbm_calculator.schemas import CBMItemCreate
from modules.common.validators import require_active
from modules.import_files.model import ImportFile
from modules.projects.model import Project
from modules.purchase_orders.model import PurchaseOrder


class CBMValidator:

    @staticmethod
    def validate_items(items: list[CBMItemCreate]):
        if not items or len(items) == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="At least one package item is required for CBM calculation.",
            )
        for idx, item in enumerate(items):
            if item.quantity <= 0:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Item #{idx+1}: Quantity must be greater than zero.",
                )
            if item.length_cm <= 0 or item.width_cm <= 0 or item.height_cm <= 0:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Item #{idx+1}: Length, width, and height dimensions must be greater than zero cm.",
                )
            if item.gross_weight_per_unit_kg < 0:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Item #{idx+1}: Gross weight cannot be negative.",
                )

    @staticmethod
    def validate_fk_references(
        db: Session,
        project_id: Optional[int] = None,
        po_id: Optional[int] = None,
        import_file_id: Optional[int] = None,
        stored: Optional[CBMCalculation] = None,
    ) -> None:
        """Referenced project / PO / import file must exist and be active (400 otherwise). On update
        (``stored``) a reference that is already saved only has to exist: a resent full payload whose file
        or PO was deactivated since stays editable."""
        for model, value, field, label in (
            (Project, project_id, "project_id", "المشروع"),
            (PurchaseOrder, po_id, "po_id", "أمر الشراء"),
            (ImportFile, import_file_id, "import_file_id", "ملف الاستيراد"),
        ):
            if value is None:
                continue
            if stored is not None and getattr(stored, field) == value:
                if db.get(model, value) is None:
                    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"{label} رقم {value} غير موجود أو غير نشط.")
                continue
            require_active(db, model, value, label)
