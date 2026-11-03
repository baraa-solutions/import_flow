"""
Service for Regulatory Matrix
"""

from datetime import datetime, timezone
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.common.validators import not_found
from modules.regulatory_matrix.model import HsCodeRegulatoryRequirement
from modules.regulatory_matrix.repository import RegulatoryMatrixRepository
from modules.regulatory_matrix.schemas import HsCodeRegulatoryCreate, HsCodeRegulatoryUpdate
from modules.regulatory_matrix.validators import (
    validate_requirement_create,
    validate_requirement_update,
)


class RegulatoryMatrixService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = RegulatoryMatrixRepository(db)

    def create_requirement(
        self, data: HsCodeRegulatoryCreate, current_user: str = "system"
    ) -> HsCodeRegulatoryRequirement:
        validate_requirement_create(data)

        # Duplicate check: same HS code + agency + stage timing
        existing = self.repo.find_existing(
            data.hs_code.strip(), data.agency_code.strip().upper(), data.stage_timing.strip().upper()
        )
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"الجهة الرقابية ({data.agency_code}) مسجلة بالفعل لنفس البند ({data.hs_code}) في مرحلة ({data.stage_timing}).",
            )

        req = HsCodeRegulatoryRequirement(
            hs_code=data.hs_code.strip(),
            agency_code=data.agency_code.strip().upper(),
            agency_name_ar=data.agency_name_ar.strip(),
            agency_name_en=data.agency_name_en.strip(),
            stage_timing=data.stage_timing.strip().upper(),
            required_documents=data.required_documents.strip() if data.required_documents else None,
            inspection_type=data.inspection_type.strip().upper() if data.inspection_type else None,
            regulatory_notes=data.regulatory_notes.strip() if data.regulatory_notes else None,
            is_mandatory=data.is_mandatory,
            created_by=current_user,
            updated_by=current_user,
        )

        self.repo.create(req)
        self.db.commit()
        self.db.refresh(req)
        return req

    def get_requirement(self, req_id: int) -> HsCodeRegulatoryRequirement:
        req = self.repo.get_by_id(req_id)
        if not req:
            raise not_found("المتطلب الرقابي للبند الجمركي", req_id)
        return req

    def get_requirements_for_hs_code(self, hs_code: str) -> List[HsCodeRegulatoryRequirement]:
        return self.repo.get_by_hs_code(hs_code)

    def list_requirements(
        self,
        skip: int = 0,
        limit: int = 50,
        hs_code: Optional[str] = None,
        agency_code: Optional[str] = None,
        stage_timing: Optional[str] = None,
        is_mandatory: Optional[bool] = None,
        search: Optional[str] = None,
    ) -> Tuple[List[HsCodeRegulatoryRequirement], int]:
        return self.repo.list_requirements(
            skip=skip,
            limit=limit,
            hs_code=hs_code,
            agency_code=agency_code,
            stage_timing=stage_timing,
            is_mandatory=is_mandatory,
            search=search,
        )

    def update_requirement(
        self, req_id: int, data: HsCodeRegulatoryUpdate, current_user: str = "system"
    ) -> HsCodeRegulatoryRequirement:
        req = self.get_requirement(req_id)
        updates = validate_requirement_update(data)

        for key, value in updates.items():
            setattr(req, key, value)

        req.updated_by = current_user
        req.updated_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(req)
        return req

    def delete_requirement(self, req_id: int, current_user: str = "system") -> None:
        req = self.get_requirement(req_id)
        self.repo.soft_delete(req, current_user=current_user)
        self.db.commit()
