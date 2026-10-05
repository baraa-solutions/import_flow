"""
Smart Document Upload — Repository
CRUD operations for upload_sessions table.
"""

from __future__ import annotations

from typing import List, Optional

from sqlalchemy.orm import Session

from modules.common.sequence_generator import next_yearly_code
from modules.smart_document_upload.model import UploadSession


def _generate_session_ref(db: Session) -> str:
    """Next ``UPLOAD-<year>-NNNNN`` (highest suffix + 1, SDU-05). The unique constraint stays the guard."""
    return next_yearly_code(db, UploadSession.session_ref, "UPLOAD", pad=5)


def create_upload_session(
    db: Session,
    module_name: str,
    filename: str,
    file_type: str,
    file_size_bytes: int,
    extraction_status: str,
    confidence_score: float,
    extracted_fields: dict,
    missing_fields: list,
    extraction_notes: Optional[str] = None,
    linked_record_id: Optional[int] = None,
    linked_module: Optional[str] = None,
    created_by: Optional[int] = None,
) -> UploadSession:
    session_ref = _generate_session_ref(db)
    record = UploadSession(
        session_ref=session_ref,
        module_name=module_name,
        filename=filename,
        file_type=file_type,
        file_size_bytes=file_size_bytes,
        extraction_status=extraction_status,
        confidence_score=confidence_score,
        extraction_notes=extraction_notes,
        linked_record_id=linked_record_id,
        linked_module=linked_module,
        created_by=created_by,
    )
    record.set_extracted_fields(extracted_fields)
    record.set_missing_fields(missing_fields)
    db.add(record)
    db.flush()
    return record


def get_upload_sessions(
    db: Session,
    module_name: Optional[str] = None,
    skip: int = 0,
    limit: int = 50,
) -> List[UploadSession]:
    q = db.query(UploadSession).filter(UploadSession.is_active == 1)
    if module_name:
        q = q.filter(UploadSession.module_name == module_name)
    return q.order_by(UploadSession.created_at.desc()).offset(skip).limit(limit).all()


def get_upload_session_by_id(db: Session, session_id: int) -> Optional[UploadSession]:
    return (
        db.query(UploadSession)
        .filter(UploadSession.id == session_id, UploadSession.is_active == 1)
        .first()
    )


def soft_delete_upload_session(db: Session, session_id: int) -> bool:
    record = get_upload_session_by_id(db, session_id)
    if not record:
        return False
    record.is_active = 0
    db.flush()
    return True
