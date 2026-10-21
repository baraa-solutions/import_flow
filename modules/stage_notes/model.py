"""
Stage & Screen Notes — SQLAlchemy Models
Tables:
  - stage_notes: stores notes associated with any screen, record, or stage.
  - stage_note_attachments: stores uploaded files associated with notes.
"""

from datetime import datetime
from typing import Optional, List
from sqlalchemy import Column, Integer, String, Text, DateTime, Boolean, ForeignKey, func
from sqlalchemy.orm import relationship, Mapped, mapped_column
from database.database import Base


class StageNote(Base):
    """
    Unified note entry for any system screen, shipment record, or workflow stage.
    """
    __tablename__ = "stage_notes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    screen_code: Mapped[str] = mapped_column(String(100), index=True, nullable=False)
    record_id: Mapped[Optional[int]] = mapped_column(Integer, index=True, nullable=True)
    stage_code: Mapped[Optional[str]] = mapped_column(String(50), index=True, nullable=True)
    note_text: Mapped[str] = mapped_column(Text, nullable=False)
    created_by: Mapped[str] = mapped_column(String(100), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=func.now(), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    attachments: Mapped[List["StageNoteAttachment"]] = relationship(
        "StageNoteAttachment",
        back_populates="note",
        cascade="all, delete-orphan",
        order_by="StageNoteAttachment.id.asc()",
    )


class StageNoteAttachment(Base):
    """
    Files uploaded and attached to a stage note.
    """
    __tablename__ = "stage_note_attachments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    note_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("stage_notes.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    file_name: Mapped[str] = mapped_column(String(255), nullable=False)
    file_path: Mapped[str] = mapped_column(String(500), nullable=False)
    file_size_bytes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    file_type: Mapped[str] = mapped_column(String(50), default="generic", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=func.now(), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    note: Mapped["StageNote"] = relationship("StageNote", back_populates="attachments")
