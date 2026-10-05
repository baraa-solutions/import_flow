from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy.orm.attributes import flag_modified
from sqlalchemy import desc, or_

from modules.common.sequence_generator import next_yearly_code
from .model import OriginalDocumentsCollectionSession


class OriginalDocumentsCollectionRepository:
    """Queries only. Writes flush; the service owns the transaction and commits once (ODC-06)."""

    @staticmethod
    def get_next_collection_code(db: Session) -> str:
        """``DOC-COL-<year>-NNNN``: highest numeric suffix of the year + 1 (ODC-12). The unique constraint stays
        the guard: the service retries on IntegrityError."""
        return next_yearly_code(db, OriginalDocumentsCollectionSession.collection_code, "DOC-COL", pad=4)

    @staticmethod
    def create(db: Session, session: OriginalDocumentsCollectionSession) -> OriginalDocumentsCollectionSession:
        db.add(session)
        db.flush()
        return session

    @staticmethod
    def get_by_id(db: Session, collection_id: int) -> Optional[OriginalDocumentsCollectionSession]:
        return (
            db.query(OriginalDocumentsCollectionSession)
            .filter(
                OriginalDocumentsCollectionSession.collection_id == collection_id,
                OriginalDocumentsCollectionSession.is_active == True,
            )
            .first()
        )

    @staticmethod
    def get_by_import_file(db: Session, import_file_id: int) -> Optional[OriginalDocumentsCollectionSession]:
        return (
            db.query(OriginalDocumentsCollectionSession)
            .filter(
                OriginalDocumentsCollectionSession.import_file_id == import_file_id,
                OriginalDocumentsCollectionSession.is_active == True,
            )
            .first()
        )

    @staticmethod
    def get_all(
        db: Session,
        include_inactive: bool = False,
        status: Optional[str] = None,
        search: Optional[str] = None,
        limit: int = 100,
        offset: int = 0,
    ) -> List[OriginalDocumentsCollectionSession]:
        query = db.query(OriginalDocumentsCollectionSession)
        if not include_inactive:
            query = query.filter(OriginalDocumentsCollectionSession.is_active == True)

        if status and status != "All":
            query = query.filter(OriginalDocumentsCollectionSession.status == status)

        if search:
            search_pattern = f"%{search}%"
            query = query.filter(
                or_(
                    OriginalDocumentsCollectionSession.collection_code.ilike(search_pattern),
                    OriginalDocumentsCollectionSession.import_file_code.ilike(search_pattern),
                    OriginalDocumentsCollectionSession.acid_number.ilike(search_pattern),
                    OriginalDocumentsCollectionSession.importer_name.ilike(search_pattern),
                    OriginalDocumentsCollectionSession.supplier_name.ilike(search_pattern),
                )
            )

        return (
            query.order_by(desc(OriginalDocumentsCollectionSession.updated_at))
            .offset(offset)
            .limit(limit)
            .all()
        )

    @staticmethod
    def get_active_with_couriers(db: Session) -> List[OriginalDocumentsCollectionSession]:
        """Every active session that has at least one courier (courier alerts / registry: no row cap, ODC-11)."""
        sessions = (
            db.query(OriginalDocumentsCollectionSession)
            .filter(OriginalDocumentsCollectionSession.is_active == True)
            .order_by(desc(OriginalDocumentsCollectionSession.updated_at))
            .all()
        )
        return [s for s in sessions if s.couriers_list]

    @staticmethod
    def update(
        db: Session,
        session: OriginalDocumentsCollectionSession,
        updates: dict,
    ) -> OriginalDocumentsCollectionSession:
        for key, value in updates.items():
            if hasattr(session, key):
                setattr(session, key, value)
                if key in ["couriers_list", "documents_list"]:
                    flag_modified(session, key)

        session.updated_at = datetime.now(timezone.utc)
        db.flush()
        return session

    @staticmethod
    def soft_delete(db: Session, collection_id: int) -> bool:
        session = db.query(OriginalDocumentsCollectionSession).filter_by(collection_id=collection_id).first()
        if not session:
            return False
        session.is_active = False
        session.updated_at = datetime.now(timezone.utc)
        db.flush()
        return True
