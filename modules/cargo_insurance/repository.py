from typing import List, Optional, Tuple
from sqlalchemy.orm import Session

from modules.cargo_insurance.model import CargoInsuranceCertificate
from modules.common.sequence_generator import next_yearly_code


class CargoInsuranceRepository:
    def __init__(self, db: Session):
        self.db = db

    def generate_next_certificate_code(self) -> str:
        """Next ``INS-YYYY-NNNNN`` of the current year (the unique constraint stays the final guard)."""
        return next_yearly_code(self.db, CargoInsuranceCertificate.certificate_code, "INS", pad=5)

    def add(self, certificate: CargoInsuranceCertificate) -> CargoInsuranceCertificate:
        """Adds and flushes (the service commits)."""
        self.db.add(certificate)
        self.db.flush()
        return certificate

    def get_by_id(self, certificate_id: int) -> Optional[CargoInsuranceCertificate]:
        return (
            self.db.query(CargoInsuranceCertificate)
            .filter(
                CargoInsuranceCertificate.certificate_id == certificate_id,
                CargoInsuranceCertificate.is_active == True,
            )
            .first()
        )

    def get_by_code(self, certificate_code: str) -> Optional[CargoInsuranceCertificate]:
        return (
            self.db.query(CargoInsuranceCertificate)
            .filter(
                CargoInsuranceCertificate.certificate_code == certificate_code,
                CargoInsuranceCertificate.is_active == True,
            )
            .first()
        )

    def list_certificates(
        self,
        skip: int = 0,
        limit: int = 50,
        import_file_id: Optional[int] = None,
        status: Optional[str] = None,
        search: Optional[str] = None,
    ) -> Tuple[List[CargoInsuranceCertificate], int]:
        query = self.db.query(CargoInsuranceCertificate).filter(CargoInsuranceCertificate.is_active == True)

        if import_file_id is not None:
            query = query.filter(CargoInsuranceCertificate.import_file_id == import_file_id)

        if status and status != "All":
            query = query.filter(CargoInsuranceCertificate.status == status)

        if search and search.strip():
            term = f"%{search.strip()}%"
            query = query.filter(
                (CargoInsuranceCertificate.certificate_code.ilike(term))
                | (CargoInsuranceCertificate.policy_number.ilike(term))
                | (CargoInsuranceCertificate.insured_entity_name.ilike(term))
                | (CargoInsuranceCertificate.carrier_name.ilike(term))
                | (CargoInsuranceCertificate.tracking_reference.ilike(term))
            )

        total = query.count()
        items = (
            query.order_by(CargoInsuranceCertificate.created_at.desc())
            .offset(skip)
            .limit(limit)
            .all()
        )
        return items, total

    def soft_delete(self, certificate: CargoInsuranceCertificate) -> None:
        """Marks the certificate inactive (the service commits)."""
        certificate.is_active = False
