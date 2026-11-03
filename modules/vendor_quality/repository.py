"""
Database Repository for Pre-Shipment Inspection (PSI) and Vendor Quality Rating
"""

from typing import List, Optional, Tuple
from sqlalchemy import case, func, or_
from sqlalchemy.orm import Session

from modules.vendor_quality.model import VendorQualityAndPSI


class VendorQualityRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, record_id: int) -> Optional[VendorQualityAndPSI]:
        return (
            self.db.query(VendorQualityAndPSI)
            .filter(VendorQualityAndPSI.id == record_id, VendorQualityAndPSI.is_deleted == False)
            .first()
        )

    def get_by_code(self, code: str) -> Optional[VendorQualityAndPSI]:
        return (
            self.db.query(VendorQualityAndPSI)
            .filter(VendorQualityAndPSI.assessment_code == code, VendorQualityAndPSI.is_deleted == False)
            .first()
        )

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
        include_deleted: bool = False,
    ) -> Tuple[List[VendorQualityAndPSI], int]:
        query = self.db.query(VendorQualityAndPSI)
        if not include_deleted:
            query = query.filter(VendorQualityAndPSI.is_deleted == False)

        if vendor_id is not None:
            query = query.filter(VendorQualityAndPSI.vendor_id == vendor_id)

        if purchase_order_id is not None:
            query = query.filter(VendorQualityAndPSI.purchase_order_id == purchase_order_id)

        if import_file_id is not None:
            query = query.filter(VendorQualityAndPSI.import_file_id == import_file_id)

        if inspection_agency:
            query = query.filter(VendorQualityAndPSI.inspection_agency == inspection_agency)

        if psi_result:
            query = query.filter(VendorQualityAndPSI.psi_result == psi_result)

        if rating_grade:
            query = query.filter(VendorQualityAndPSI.rating_grade == rating_grade)

        if search:
            s = f"%{search.strip()}%"
            query = query.filter(
                or_(
                    VendorQualityAndPSI.assessment_code.ilike(s),
                    VendorQualityAndPSI.vendor_name.ilike(s),
                    VendorQualityAndPSI.psi_certificate_number.ilike(s),
                    VendorQualityAndPSI.inspector_notes.ilike(s),
                )
            )

        total = query.count()
        items = query.order_by(VendorQualityAndPSI.created_at.desc()).offset(skip).limit(limit).all()
        return items, total

    def create(self, record: VendorQualityAndPSI) -> VendorQualityAndPSI:
        self.db.add(record)
        self.db.flush()
        self.db.refresh(record)
        return record

    def update(self, record: VendorQualityAndPSI) -> VendorQualityAndPSI:
        self.db.flush()
        self.db.refresh(record)
        return record

    def soft_delete(self, record: VendorQualityAndPSI) -> None:
        record.is_deleted = True
        record.is_active = False
        self.db.flush()

    def get_next_sequence_number(self, year: int) -> int:
        prefix = f"PSI-{year}-"
        count = (
            self.db.query(func.count(VendorQualityAndPSI.id))
            .filter(VendorQualityAndPSI.assessment_code.like(f"{prefix}%"))
            .scalar()
            or 0
        )
        return count + 1

    def get_historical_rankings(self) -> List[dict]:
        rows = (
            self.db.query(
                VendorQualityAndPSI.vendor_id,
                VendorQualityAndPSI.vendor_name,
                func.count(VendorQualityAndPSI.id).label("inspections_count"),
                func.sum(case((VendorQualityAndPSI.psi_result == "PASSED", 1), else_=0)).label("passed_count"),
                func.sum(case((VendorQualityAndPSI.psi_result == "FAILED", 1), else_=0)).label("failed_count"),
                func.avg(VendorQualityAndPSI.quality_score).label("avg_quality"),
                func.avg(VendorQualityAndPSI.delivery_timeliness_score).label("avg_delivery"),
                func.avg(VendorQualityAndPSI.documentation_accuracy_score).label("avg_docs"),
                func.avg(VendorQualityAndPSI.compliance_score).label("avg_compliance"),
                func.avg(VendorQualityAndPSI.overall_vendor_rating).label("avg_rating"),
            )
            .filter(VendorQualityAndPSI.is_deleted == False)
            .group_by(VendorQualityAndPSI.vendor_id, VendorQualityAndPSI.vendor_name)
            .order_by(func.avg(VendorQualityAndPSI.overall_vendor_rating).desc())
            .all()
        )

        results = []
        for r in rows:
            avg_rating = round(float(r.avg_rating or 100.0), 1)
            if avg_rating >= 90:
                grade = "A"
            elif avg_rating >= 80:
                grade = "B"
            elif avg_rating >= 70:
                grade = "C"
            elif avg_rating >= 60:
                grade = "D"
            else:
                grade = "F"

            results.append(
                {
                    "vendor_id": r.vendor_id,
                    "vendor_name": r.vendor_name,
                    "inspections_count": int(r.inspections_count or 0),
                    "passed_count": int(r.passed_count or 0),
                    "failed_count": int(r.failed_count or 0),
                    "avg_quality_score": round(float(r.avg_quality or 100.0), 1),
                    "avg_delivery_timeliness": round(float(r.avg_delivery or 100.0), 1),
                    "avg_documentation_accuracy": round(float(r.avg_docs or 100.0), 1),
                    "avg_compliance": round(float(r.avg_compliance or 100.0), 1),
                    "avg_overall_rating": avg_rating,
                    "current_grade": grade,
                }
            )
        return results
