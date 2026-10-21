"""
Stage & Screen Notes — Database Repository
Pure database queries and persistence operations.
"""

from typing import List, Optional
from sqlalchemy.orm import Session, joinedload
from modules.stage_notes.model import StageNote, StageNoteAttachment


def get_stage_notes(
    db: Session,
    screen_code: str,
    record_id: Optional[int] = None,
    stage_code: Optional[str] = None,
    limit: int = 200,
    skip: int = 0,
) -> List[StageNote]:
    """
    Fetch active notes with preloaded attachments ordered newest first.
    """
    q = (
        db.query(StageNote)
        .options(joinedload(StageNote.attachments))
        .filter(StageNote.screen_code == screen_code, StageNote.is_active == True)
    )
    if record_id is not None:
        q = q.filter(StageNote.record_id == record_id)
    if stage_code:
        q = q.filter(StageNote.stage_code == stage_code)

    return q.order_by(StageNote.created_at.desc(), StageNote.id.desc()).offset(skip).limit(limit).all()


def get_note_by_id(db: Session, note_id: int) -> Optional[StageNote]:
    """Retrieve single note by primary key."""
    return (
        db.query(StageNote)
        .options(joinedload(StageNote.attachments))
        .filter(StageNote.id == note_id, StageNote.is_active == True)
        .first()
    )


def create_note(
    db: Session,
    screen_code: str,
    note_text: str,
    created_by: str,
    record_id: Optional[int] = None,
    stage_code: Optional[str] = None,
) -> StageNote:
    """Create a new StageNote row."""
    note = StageNote(
        screen_code=screen_code,
        record_id=record_id,
        stage_code=stage_code,
        note_text=note_text,
        created_by=created_by,
        is_active=True,
    )
    db.add(note)
    db.flush()
    return note


def soft_delete_note(db: Session, note_id: int) -> bool:
    """Soft delete note and cascade to active attachments."""
    note = get_note_by_id(db, note_id)
    if not note:
        return False
    note.is_active = False
    for att in note.attachments:
        att.is_active = False
    db.flush()
    return True


def create_attachment(
    db: Session,
    note_id: int,
    file_name: str,
    file_path: str,
    file_size_bytes: int,
    file_type: str,
) -> StageNoteAttachment:
    """Create a StageNoteAttachment row."""
    att = StageNoteAttachment(
        note_id=note_id,
        file_name=file_name,
        file_path=file_path,
        file_size_bytes=file_size_bytes,
        file_type=file_type,
        is_active=True,
    )
    db.add(att)
    db.flush()
    return att


def get_attachment_by_id(db: Session, attachment_id: int) -> Optional[StageNoteAttachment]:
    """Retrieve single attachment by primary key."""
    return (
        db.query(StageNoteAttachment)
        .filter(StageNoteAttachment.id == attachment_id, StageNoteAttachment.is_active == True)
        .first()
    )
