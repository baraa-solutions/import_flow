"""
Business Logic & Service Layer for Pre-Shipment Inspection (PSI) and Vendor Quality
"""

from datetime import datetime, timezone
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.vendor_quality.model import VendorQualityAndPSI
from modules.vendor_quality.repository import VendorQualityRepository
from modules.vendor_quality.schemas import (
    PsiCertificateUploadRequest,
    VendorHistoricalRankingItem,
    VendorHistoricalRankingOut,
    VendorQualityCreate,
    VendorQualityUpdate,
)
from modules.vendor_quality.validators import (
    validate_assessment_code_unique,
    validate_defects_count,
    validate_scores,
)


class VendorQualityService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = VendorQualityRepository(db)

    def generate_code(self) -> str:
        current_year = datetime.now(timezone.utc).year
        seq = self.repo.get_next_sequence_number(current_year)
        return f"PSI-{current_year}-{seq:04d}"

    @staticmethod
    def calculate_overall_rating(
        quality: float,
        timeliness: float,
        docs: float,
        compliance: float,
        critical_defects: int = 0,
    ) -> Tuple[float, str, bool]:
        """
        Calculates weighted scorecard rating:
        - Quality: 40%
        - Delivery Timeliness: 25%
        - Documentation Accuracy: 20%
        - Regulatory & Contractual Compliance: 15%
        - Penalty: -5.0 per critical defect
        """
        raw = (0.40 * quality) + (0.25 * timeliness) + (0.20 * docs) + (0.15 * compliance)
        penalty = critical_defects * 5.0
        final_rating = max(0.0, min(100.0, round(raw - penalty, 1)))

        if final_rating >= 90.0:
            grade = "A"
        elif final_rating >= 80.0:
            grade = "B"
        elif final_rating >= 70.0:
            grade = "C"
        elif final_rating >= 60.0:
            grade = "D"
        else:
            grade = "F"

        corrective_action = critical_defects > 0 or grade in ["D", "F"]
        return final_rating, grade, corrective_action

    def list_assessments(
        self,
        skip: int = 0,
        limit: int = 50,
        vendor_id: Optional[int] = None,
        purchase_order_id: Optional[int] = None,
        import_file_id: Optional[int] = None,
        inspection_agency: Optional[str] = None,
        psi_result: Optional[str] = None,
        rating_grade: Optional[str] = None,
        search: Optional[str] = None,
    ) -> Tuple[List[VendorQualityAndPSI], int]:
        return self.repo.list_assessments(
            skip=skip,
            limit=limit,
            vendor_id=vendor_id,
            purchase_order_id=purchase_order_id,
            import_file_id=import_file_id,
            inspection_agency=inspection_agency,
            psi_result=psi_result,
            rating_grade=rating_grade,
            search=search,
        )

    def get_by_id(self, record_id: int) -> VendorQualityAndPSI:
        item = self.repo.get_by_id(record_id)
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Vendor quality record #{record_id} not found.",
            )
        return item

    def create_assessment(
        self,
        data: VendorQualityCreate,
        current_user_id: Optional[int] = None,
    ) -> VendorQualityAndPSI:
        code = data.assessment_code or self.generate_code()
        validate_assessment_code_unique(self.repo, code)
        validate_scores(
            data.quality_score,
            data.delivery_timeliness_score,
            data.documentation_accuracy_score,
            data.compliance_score,
        )
        validate_defects_count(data.defects_count, data.critical_defects_count)

        rating, grade, action_req = self.calculate_overall_rating(
            data.quality_score,
            data.delivery_timeliness_score,
            data.documentation_accuracy_score,
            data.compliance_score,
            data.critical_defects_count,
        )

        record = VendorQualityAndPSI(
            assessment_code=code,
            vendor_id=data.vendor_id,
            vendor_name=data.vendor_name,
            purchase_order_id=data.purchase_order_id,
            import_file_id=data.import_file_id,
            inspection_agency=data.inspection_agency,
            psi_certificate_number=data.psi_certificate_number,
            inspection_date=data.inspection_date,
            psi_result=data.psi_result,
            defects_count=data.defects_count,
            critical_defects_count=data.critical_defects_count,
            inspection_certificate_file=data.inspection_certificate_file,
            quality_score=data.quality_score,
            delivery_timeliness_score=data.delivery_timeliness_score,
            documentation_accuracy_score=data.documentation_accuracy_score,
            compliance_score=data.compliance_score,
            overall_vendor_rating=rating,
            rating_grade=grade,
            corrective_action_required=data.corrective_action_required or action_req,
            corrective_action_plan=data.corrective_action_plan,
            inspector_notes=data.inspector_notes,
            created_by_user_id=current_user_id,
        )

        saved = self.repo.create(record)
        self.db.commit()
        return saved

    def update_assessment(
        self,
        record_id: int,
        data: VendorQualityUpdate,
        current_user_id: Optional[int] = None,
    ) -> VendorQualityAndPSI:
        item = self.get_by_id(record_id)
        update_dict = data.model_dump(exclude_unset=True)

        for field, value in update_dict.items():
            setattr(item, field, value)

        validate_scores(
            item.quality_score,
            item.delivery_timeliness_score,
            item.documentation_accuracy_score,
            item.compliance_score,
        )
        validate_defects_count(item.defects_count, item.critical_defects_count)

        rating, grade, action_req = self.calculate_overall_rating(
            item.quality_score,
            item.delivery_timeliness_score,
            item.documentation_accuracy_score,
            item.compliance_score,
            item.critical_defects_count,
        )
        item.overall_vendor_rating = rating
        item.rating_grade = grade
        if action_req:
            item.corrective_action_required = True

        item.updated_at = datetime.now(timezone.utc)
        updated = self.repo.update(item)
        self.db.commit()
        return updated

    def upload_psi_certificate(
        self,
        record_id: int,
        req: PsiCertificateUploadRequest,
        current_user_id: Optional[int] = None,
    ) -> VendorQualityAndPSI:
        item = self.get_by_id(record_id)
        validate_defects_count(req.defects_count, req.critical_defects_count)

        item.psi_certificate_number = req.psi_certificate_number
        item.inspection_date = req.inspection_date
        item.psi_result = req.psi_result
        item.inspection_certificate_file = req.inspection_certificate_file
        item.defects_count = req.defects_count
        item.critical_defects_count = req.critical_defects_count
        if req.inspector_notes:
            prev = item.inspector_notes or ""
            item.inspector_notes = f"{prev}\n[PSI Upload]: {req.inspector_notes}".strip()

        # Recalculate rating with updated critical defects
        rating, grade, action_req = self.calculate_overall_rating(
            item.quality_score,
            item.delivery_timeliness_score,
            item.documentation_accuracy_score,
            item.compliance_score,
            req.critical_defects_count,
        )
        item.overall_vendor_rating = rating
        item.rating_grade = grade
        if action_req:
            item.corrective_action_required = True

        item.updated_at = datetime.now(timezone.utc)
        updated = self.repo.update(item)
        self.db.commit()
        return updated

    def delete_assessment(self, record_id: int) -> None:
        item = self.get_by_id(record_id)
        self.repo.soft_delete(item)
        self.db.commit()

    def get_rankings(self) -> VendorHistoricalRankingOut:
        rankings_data = self.repo.get_historical_rankings()
        items = [VendorHistoricalRankingItem(**r) for r in rankings_data]
        return VendorHistoricalRankingOut(rankings=items, total_vendors=len(items))
