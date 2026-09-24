"""Pydantic request/response models for /api/v1/app-update (plan §6)."""
from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, Field

VERSION_PATTERN = r"^\d+\.\d+\.\d+$"

CheckStatus = Literal["up_to_date", "update_available", "offline", "invalid_signature", "disabled"]
UpdateState = Literal["idle", "downloading", "verifying", "ready", "backing_up", "installing", "failed"]
LastResult = Literal["none", "success", "failed"]


class ReleaseNotes(BaseModel):
    ar: List[str] = Field(default_factory=list)
    en: List[str] = Field(default_factory=list)


class UpdateCheckResponse(BaseModel):
    current_version: str
    current_build: int
    latest_version: Optional[str] = None
    latest_build: Optional[int] = None
    update_available: bool = False
    mandatory: bool = False
    release_notes: ReleaseNotes = Field(default_factory=ReleaseNotes)
    released_at: Optional[datetime] = None
    installer_size_bytes: Optional[int] = None
    check_status: CheckStatus
    last_checked_at: Optional[datetime] = None
    apply_supported: bool = False


class UpdateStatusResponse(BaseModel):
    state: UpdateState = "idle"
    version: Optional[str] = None
    downloaded_bytes: int = 0
    total_bytes: int = 0
    error_code: Optional[str] = None
    error_detail: Optional[str] = None


class DownloadRequest(BaseModel):
    version: str = Field(..., pattern=VERSION_PATTERN)


class ApplyRequest(BaseModel):
    version: str = Field(..., pattern=VERSION_PATTERN)


class StageLocalRequest(BaseModel):
    manifest_path: str = Field(..., min_length=1)
    installer_path: str = Field(..., min_length=1)


class RollbackRequest(BaseModel):
    confirm: bool
    backup_file: str = Field(..., min_length=1)


class LastResultResponse(BaseModel):
    result: LastResult = "none"
    from_version: Optional[str] = None
    to_version: Optional[str] = None
    finished_at: Optional[datetime] = None
    detail: Optional[str] = None


class UpdateHistoryItem(BaseModel):
    ts: Optional[datetime] = None
    event: str
    version: Optional[str] = None
    detail: Optional[str] = None


class UpdateHistoryResponse(BaseModel):
    items: List[UpdateHistoryItem] = Field(default_factory=list)
