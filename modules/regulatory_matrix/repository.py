"""
Repository for Regulatory Matrix
"""

from typing import List, Optional, Tuple
from sqlalchemy import or_
from sqlalchemy.orm import Session

from modules.regulatory_matrix.model import HsCodeRegulatoryRequirement


class RegulatoryMatrixRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, req_id: int) -> Optional[HsCodeRegulatoryRequirement]:
        return (
            self.db.query(HsCodeRegulatoryRequirement)
            .filter(
                HsCodeRegulatoryRequirement.id == req_id,
                HsCodeRegulatoryRequirement.is_active.is_(True),
            )
            .first()
        )

    def find_existing(
        self, hs_code: str, agency_code: str, stage_timing: str
    ) -> Optional[HsCodeRegulatoryRequirement]:
        return (
            self.db.query(HsCodeRegulatoryRequirement)
            .filter(
                HsCodeRegulatoryRequirement.hs_code == hs_code,
                HsCodeRegulatoryRequirement.agency_code == agency_code,
                HsCodeRegulatoryRequirement.stage_timing == stage_timing,
                HsCodeRegulatoryRequirement.is_active.is_(True),
            )
            .first()
        )

    def get_by_hs_code(self, hs_code: str) -> List[HsCodeRegulatoryRequirement]:
        # Exact match or prefix match (e.g., 8471 matching 8471.30.00)
        clean_code = hs_code.replace(".", "").strip()
        return (
            self.db.query(HsCodeRegulatoryRequirement)
            .filter(
                HsCodeRegulatoryRequirement.is_active.is_(True),
                or_(
                    HsCodeRegulatoryRequirement.hs_code == hs_code,
                    HsCodeRegulatoryRequirement.hs_code.like(f"{clean_code}%"),
                ),
            )
            .order_by(HsCodeRegulatoryRequirement.stage_timing.asc())
            .all()
        )

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
        query = self.db.query(HsCodeRegulatoryRequirement).filter(
            HsCodeRegulatoryRequirement.is_active.is_(True)
        )

        if hs_code:
            query = query.filter(HsCodeRegulatoryRequirement.hs_code.ilike(f"%{hs_code}%"))
        if agency_code:
            query = query.filter(HsCodeRegulatoryRequirement.agency_code == agency_code.upper())
        if stage_timing:
            query = query.filter(HsCodeRegulatoryRequirement.stage_timing == stage_timing.upper())
        if is_mandatory is not None:
            query = query.filter(HsCodeRegulatoryRequirement.is_mandatory.is_(is_mandatory))

        if search:
            pattern = f"%{search.strip()}%"
            query = query.filter(
                or_(
                    HsCodeRegulatoryRequirement.hs_code.ilike(pattern),
                    HsCodeRegulatoryRequirement.agency_name_ar.ilike(pattern),
                    HsCodeRegulatoryRequirement.agency_name_en.ilike(pattern),
                    HsCodeRegulatoryRequirement.required_documents.ilike(pattern),
                )
            )

        total = query.count()
        items = query.order_by(HsCodeRegulatoryRequirement.hs_code.asc()).offset(skip).limit(limit).all()
        return items, total

    def create(self, requirement: HsCodeRegulatoryRequirement) -> HsCodeRegulatoryRequirement:
        self.db.add(requirement)
        return requirement

    def soft_delete(self, requirement: HsCodeRegulatoryRequirement, current_user: str = "system") -> None:
        requirement.is_active = False
        requirement.updated_by = current_user
