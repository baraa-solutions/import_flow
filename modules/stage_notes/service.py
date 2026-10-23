"""
Stage & Screen Notes — Business Service Layer
Orchestrates file storage, note persistence, history compilation, and download retrieval.
"""

import os
import uuid
import logging
from typing import List, Optional, Tuple
from fastapi import UploadFile, HTTPException, status
from sqlalchemy.orm import Session

from utils.db_safety import app_base_dir
import modules.stage_notes.repository as repo
import modules.stage_notes.validators as validators
from modules.stage_notes.schemas import (
    StageNoteResponse,
    StageNoteAttachmentResponse,
    StageNotesSummaryResponse,
)

logger = logging.getLogger(__name__)

# Base storage path for uploaded stage attachments: next to backend.exe when frozen, repo root in dev.
# Never derived from the process working directory, which depends on how the app was launched.
STORAGE_DIR = str(app_base_dir() / "uploads" / "stage_notes")


def _ensure_storage_dir():
    """Ensure directory exists on disk."""
    if not os.path.exists(STORAGE_DIR):
        os.makedirs(STORAGE_DIR, exist_ok=True)


def _resolve_attachment_path(stored_path: str) -> str:
    """Stored paths are file names relative to STORAGE_DIR; absolute paths from older rows are used as-is."""
    if os.path.isabs(stored_path):
        return stored_path
    return os.path.join(STORAGE_DIR, stored_path)


def _read_validated_uploads(files: Optional[List[UploadFile]]) -> List[Tuple[UploadFile, str, bytes]]:
    """Validate every upload (extension and size) before anything is written to disk."""
    validated = []
    for file in files or []:
        if not file.filename:
            continue
        ext = validators.validate_attachment_file(file)
        content = file.file.read()
        if len(content) > validators.MAX_FILE_SIZE_BYTES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"File '{file.filename}' exceeds maximum allowed size of 50 MB",
            )
        validated.append((file, ext, content))
    return validated


def _remove_files(paths: List[str]) -> None:
    for path in paths:
        try:
            os.remove(path)
        except OSError:
            logger.warning(f"Could not remove orphaned stage note attachment: {path}")


def _format_attachment_response(att) -> StageNoteAttachmentResponse:
    return StageNoteAttachmentResponse(
        id=att.id,
        note_id=att.note_id,
        file_name=att.file_name,
        file_size_bytes=att.file_size_bytes,
        file_type=att.file_type,
        download_url=f"/api/v1/stage-notes/attachments/{att.id}/download",
        created_at=att.created_at,
    )


def _format_note_response(note) -> StageNoteResponse:
    active_attachments = [
        _format_attachment_response(att)
        for att in (note.attachments or [])
        if getattr(att, "is_active", True)
    ]
    return StageNoteResponse(
        id=note.id,
        screen_code=note.screen_code,
        record_id=note.record_id,
        stage_code=note.stage_code,
        note_text=note.note_text,
        created_by=note.created_by,
        created_at=note.created_at,
        attachments=active_attachments,
    )


def list_notes_service(
    db: Session,
    screen_code: str,
    record_id: Optional[int] = None,
    stage_code: Optional[str] = None,
    limit: int = 200,
    skip: int = 0,
) -> StageNotesSummaryResponse:
    """Fetch all notes for a screen or stage with summary statistics."""
    screen_code = validators.validate_screen_code(screen_code)
    notes = repo.get_stage_notes(
        db,
        screen_code=screen_code,
        record_id=record_id,
        stage_code=stage_code,
        limit=limit,
        skip=skip,
    )

    formatted_notes = [_format_note_response(n) for n in notes]
    total_attachments = sum(len(n.attachments) for n in formatted_notes)

    return StageNotesSummaryResponse(
        screen_code=screen_code,
        record_id=record_id,
        stage_code=stage_code,
        total_notes=len(formatted_notes),
        total_attachments=total_attachments,
        notes=formatted_notes,
    )


def create_note_with_attachments_service(
    db: Session,
    screen_code: str,
    note_text: str,
    created_by: str,
    record_id: Optional[int] = None,
    stage_code: Optional[str] = None,
    files: Optional[List[UploadFile]] = None,
) -> StageNoteResponse:
    """
    Create a new note and safely persist any uploaded file attachments.
    """
    screen_code = validators.validate_screen_code(screen_code)
    note_text = validators.validate_note_content(note_text)

    uploads = _read_validated_uploads(files)
    if uploads:
        _ensure_storage_dir()

    written_paths: List[str] = []
    try:
        # 1. Create the StageNote
        note = repo.create_note(
            db=db,
            screen_code=screen_code,
            record_id=record_id,
            stage_code=stage_code,
            note_text=note_text,
            created_by=created_by,
        )

        # 2. Save the already-validated attachments
        for file, ext, content in uploads:
            safe_filename = f"{uuid.uuid4().hex[:12]}_{os.path.basename(file.filename)}"
            destination_path = os.path.join(STORAGE_DIR, safe_filename)
            with open(destination_path, "wb") as f_out:
                f_out.write(content)
            written_paths.append(destination_path)

            repo.create_attachment(
                db=db,
                note_id=note.id,
                file_name=file.filename,
                file_path=safe_filename,
                file_size_bytes=len(content),
                file_type=validators.determine_file_type(ext),
            )

        db.commit()
    except Exception:
        db.rollback()
        _remove_files(written_paths)
        raise
    db.refresh(note)

    logger.info(
        f"StageNote created: id={note.id}, screen={screen_code}, "
        f"attachments={len(uploads)}, user={created_by}"
    )
    return _format_note_response(note)


def get_attachment_file_for_download_service(
    db: Session,
    attachment_id: int,
) -> Tuple[str, str, str]:
    """
    Fetch file path, original name, and media type for serving.
    Returns: (file_path, file_name, media_type)
    """
    att = repo.get_attachment_by_id(db, attachment_id)
    file_path = _resolve_attachment_path(att.file_path) if att else ""
    if not att or not os.path.exists(file_path):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Attachment file not found",
        )

    ext = os.path.splitext(att.file_name)[1].lower()
    media_type = "application/octet-stream"
    if ext == ".pdf":
        media_type = "application/pdf"
    elif ext in {".png", ".jpg", ".jpeg", ".webp"}:
        media_type = "image/jpeg" if ext in {".jpg", ".jpeg"} else f"image/{ext.lstrip('.')}"
    elif ext == ".xlsx":
        media_type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    elif ext == ".xls":
        media_type = "application/vnd.ms-excel"

    return file_path, att.file_name, media_type


def delete_note_service(
    db: Session,
    note_id: int,
    user_name: str,
    is_admin: bool = False,
) -> bool:
    """Soft-delete note and its attachments. Only the note's author or an admin may delete it."""
    note = repo.get_note_by_id(db, note_id)
    if not note:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Stage note with id {note_id} not found",
        )
    validators.validate_can_delete_note(note, user_name, is_admin)
    repo.soft_delete_note(db, note_id)
    db.commit()
    logger.info(f"StageNote deleted: id={note_id} by user={user_name}")
    return True
