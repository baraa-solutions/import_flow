"""
Stage & Screen Notes — FastAPI Router
Endpoints for notes and attachment management across all screens and workflow stages.
"""

from typing import List, Optional
from fastapi import APIRouter, Depends, Form, File, UploadFile, Query, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.router import get_current_user
from modules.auth.permissions import require_permission
from modules.users.model import User
import modules.stage_notes.service as service
from modules.stage_notes.schemas import (
    StageNoteResponse,
    StageNotesSummaryResponse,
)

router = APIRouter(
    prefix="/api/v1/stage-notes",
    tags=["Stage & Screen Notes with Attachments"],
    dependencies=[Depends(get_current_user)],
)


@router.get(
    "",
    response_model=StageNotesSummaryResponse,
    summary="List notes and attachments for a screen or stage",
)
def list_stage_notes(
    screen_code: str = Query(..., description="Screen or module identifier, e.g. 'import_files', 'customs_clearance'"),
    record_id: Optional[int] = Query(None, description="Optional entity record PK"),
    stage_code: Optional[str] = Query(None, description="Optional workflow stage, e.g. 'STEP-01', 'PHASE-02'"),
    skip: int = Query(0, ge=0),
    limit: int = Query(200, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.view")),
):
    """
    Retrieve chronological history of notes and file attachments for the specified screen/stage.
    """
    return service.list_notes_service(
        db=db,
        screen_code=screen_code,
        record_id=record_id,
        stage_code=stage_code,
        limit=limit,
        skip=skip,
    )


@router.post(
    "",
    response_model=StageNoteResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Add a new note with optional file attachments (+ button)",
)
def create_stage_note(
    screen_code: str = Form(..., description="Screen code identifier"),
    note_text: str = Form(..., description="Note content text"),
    record_id: Optional[int] = Form(None, description="Optional entity record PK"),
    stage_code: Optional[str] = Form(None, description="Optional workflow stage"),
    files: Optional[List[UploadFile]] = File(None, description="Optional attachment files"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.view")),
):
    """
    Record a new note entry with optional file attachments (images, PDFs, documents, spreadsheets).
    """
    user_name = current_user.full_name or current_user.username
    return service.create_note_with_attachments_service(
        db=db,
        screen_code=screen_code,
        record_id=record_id,
        stage_code=stage_code,
        note_text=note_text,
        created_by=user_name,
        files=files,
    )


@router.get(
    "/attachments/{attachment_id}/download",
    summary="Download or view an attachment file",
)
def download_attachment(
    attachment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.view")),
):
    """
    Download or stream the requested stage note attachment.
    """
    file_path, file_name, media_type = service.get_attachment_file_for_download_service(
        db=db,
        attachment_id=attachment_id,
    )
    return FileResponse(
        path=file_path,
        filename=file_name,
        media_type=media_type,
        headers={"Content-Disposition": f'attachment; filename="{file_name}"'},
    )


@router.delete(
    "/{note_id}",
    status_code=status.HTTP_200_OK,
    summary="Delete a stage note",
)
def delete_stage_note(
    note_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.view")),
):
    """
    Soft-delete a stage note and its associated attachments.
    """
    user_name = current_user.full_name or current_user.username
    service.delete_note_service(db=db, note_id=note_id, user_name=user_name)
    return {"message": "Stage note deleted successfully", "note_id": note_id}
