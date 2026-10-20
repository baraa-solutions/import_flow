from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from sqlalchemy import or_, desc
from .model import ReexportDossier


class ReexportProtocolRepository:
    @staticmethod
    def create(db: Session, dossier: ReexportDossier) -> ReexportDossier:
        db.add(dossier)
        db.commit()
        db.refresh(dossier)
        return dossier

    @staticmethod
    def get_by_id(db: Session, reexport_id: int) -> Optional[ReexportDossier]:
        return db.query(ReexportDossier).filter(ReexportDossier.reexport_id == reexport_id).first()

    @staticmethod
    def get_by_decree(db: Session, decree_number: str) -> Optional[ReexportDossier]:
        return db.query(ReexportDossier).filter(
            ReexportDossier.rejection_decree_number == decree_number,
            ReexportDossier.is_active == True,
        ).first()

    @staticmethod
    def get_by_import_file_id(db: Session, import_file_id: int) -> List[ReexportDossier]:
        return db.query(ReexportDossier).filter(
            ReexportDossier.import_file_id == import_file_id,
            ReexportDossier.is_active == True,
        ).all()

    @staticmethod
    def list(
        db: Session,
        include_inactive: bool = False,
        import_file_id: Optional[int] = None,
        status: Optional[str] = None,
        search: Optional[str] = None,
        skip: int = 0,
        limit: int = 100,
    ) -> Tuple[List[ReexportDossier], int]:
        query = db.query(ReexportDossier)
        if not include_inactive:
            query = query.filter(ReexportDossier.is_active == True)

        if import_file_id is not None:
            query = query.filter(ReexportDossier.import_file_id == import_file_id)

        if status:
            query = query.filter(ReexportDossier.status == status)

        if search:
            search_pattern = f"%{search}%"
            query = query.filter(
                or_(
                    ReexportDossier.import_file_code.ilike(search_pattern),
                    ReexportDossier.rejection_decree_number.ilike(search_pattern),
                    ReexportDossier.rejection_authority.ilike(search_pattern),
                    ReexportDossier.customs_outbound_declaration_no.ilike(search_pattern),
                    ReexportDossier.outbound_bl_number.ilike(search_pattern),
                    ReexportDossier.return_booking_number.ilike(search_pattern),
                )
            )

        total = query.count()
        items = query.order_by(desc(ReexportDossier.created_at)).offset(skip).limit(limit).all()
        return items, total

    @staticmethod
    def update(db: Session, dossier: ReexportDossier) -> ReexportDossier:
        db.commit()
        db.refresh(dossier)
        return dossier

    @staticmethod
    def soft_delete(db: Session, reexport_id: int, user: str) -> Optional[ReexportDossier]:
        dossier = ReexportProtocolRepository.get_by_id(db, reexport_id)
        if dossier:
            dossier.is_active = False
            dossier.updated_by = user
            db.commit()
            db.refresh(dossier)
        return dossier

    @staticmethod
    def get_active_dossiers(db: Session) -> List[ReexportDossier]:
        return (
            db.query(ReexportDossier)
            .filter(
                ReexportDossier.is_active == True,
                ReexportDossier.status != "COMPLETED_CLOSED",
            )
            .order_by(ReexportDossier.legal_reexport_deadline.asc())
            .all()
        )
