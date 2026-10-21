"""
Stage & Screen Notes — Pydantic Schemas (Pydantic v2)
"""

from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class StageNoteAttachmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    note_id: int
    file_name: str
    file_size_bytes: int
    file_type: str
    download_url: str
    created_at: datetime


class StageNoteResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    screen_code: str
    record_id: Optional[int] = None
    stage_code: Optional[str] = None
    note_text: str
    created_by: str
    created_at: datetime
    attachments: List[StageNoteAttachmentResponse] = Field(default_factory=list)


class StageNoteCreate(BaseModel):
    screen_code: str = Field(..., min_length=1, max_length=100)
    record_id: Optional[int] = None
    stage_code: Optional[str] = Field(None, max_length=50)
    note_text: str = Field(..., min_length=1, max_length=10000)


class StageNotesSummaryResponse(BaseModel):
    screen_code: str
    record_id: Optional[int] = None
    stage_code: Optional[str] = None
    total_notes: int
    total_attachments: int
    notes: List[StageNoteResponse]
