"""
Stage & Screen Notes — Validators
"""

import os
from typing import List
from fastapi import HTTPException, UploadFile, status

# Allowed file extensions for attachments
ALLOWED_EXTENSIONS = {
    ".pdf", ".png", ".jpg", ".jpeg", ".webp",
    ".xlsx", ".xls", ".csv",
    ".docx", ".doc", ".txt",
}

# Max file size: 50 MB
MAX_FILE_SIZE_BYTES = 50 * 1024 * 1024


def validate_note_content(note_text: str) -> str:
    """Ensure note content is non-empty and within bounds."""
    cleaned = (note_text or "").strip()
    if not cleaned:
        raise HTTPException(
            status_code=422,
            detail="Note text cannot be empty",
        )
    if len(cleaned) > 10000:
        raise HTTPException(
            status_code=422,
            detail="Note text exceeds maximum length of 10,000 characters",
        )
    return cleaned


def validate_screen_code(screen_code: str) -> str:
    """Validate screen code identifier."""
    cleaned = (screen_code or "").strip()
    if not cleaned:
        raise HTTPException(
            status_code=422,
            detail="screen_code cannot be empty",
        )
    return cleaned


def validate_attachment_file(file: UploadFile) -> str:
    """
    Validate uploaded attachment filename and extension.
    Returns normalized file extension.
    """
    if not file.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file must have a filename",
        )

    _, ext = os.path.splitext(file.filename.lower())
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File extension '{ext}' is not permitted. Allowed: {', '.join(sorted(ALLOWED_EXTENSIONS))}",
        )
    return ext


def validate_can_delete_note(note, user_name: str, is_admin: bool) -> None:
    """Only the user who wrote the note, or an admin, may delete it."""
    if is_admin or (note.created_by or "") == (user_name or ""):
        return
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Only the note author or an administrator can delete this note",
    )


def determine_file_type(ext: str) -> str:
    """Classify file extension into logical type for UI display."""
    ext = ext.lower().lstrip(".")
    if ext in {"pdf"}:
        return "pdf"
    if ext in {"png", "jpg", "jpeg", "webp"}:
        return "image"
    if ext in {"xlsx", "xls", "csv"}:
        return "excel"
    if ext in {"docx", "doc"}:
        return "word"
    return "document"
