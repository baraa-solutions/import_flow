"""
Unit tests for Stage & Screen Notes Module (modules/stage_notes)
"""

import io
import os
import pytest
from fastapi import UploadFile, HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from database.database import Base
from modules.stage_notes.model import StageNote, StageNoteAttachment
import modules.stage_notes.service as service
import modules.stage_notes.validators as validators


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    SessionLocal = sessionmaker(bind=engine)
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


def test_create_stage_note_without_attachments(db_session):
    res = service.create_note_with_attachments_service(
        db=db_session,
        screen_code="import_files",
        note_text="Initial review completed for draft documents.",
        created_by="Ahmed Salah",
        record_id=101,
        stage_code="STEP-03",
    )
    assert res.id is not None
    assert res.screen_code == "import_files"
    assert res.record_id == 101
    assert res.stage_code == "STEP-03"
    assert res.note_text == "Initial review completed for draft documents."
    assert res.created_by == "Ahmed Salah"
    assert len(res.attachments) == 0


def test_create_stage_note_with_attachments(db_session, tmp_path, monkeypatch):
    # Route storage dir to tmp_path
    monkeypatch.setattr(service, "STORAGE_DIR", str(tmp_path))

    fake_pdf = UploadFile(
        filename="customs_declaration.pdf",
        file=io.BytesIO(b"%PDF-1.4 sample content for customs"),
    )
    fake_img = UploadFile(
        filename="container_seal.png",
        file=io.BytesIO(b"\x89PNG\r\n\x1a\nfake image content"),
    )

    res = service.create_note_with_attachments_service(
        db=db_session,
        screen_code="customs_clearance",
        note_text="Attached 46 declaration copy and container seal photograph.",
        created_by="Karim Broker",
        record_id=55,
        stage_code="PHASE-04",
        files=[fake_pdf, fake_img],
    )

    assert res.id is not None
    assert len(res.attachments) == 2

    pdf_att = next(a for a in res.attachments if a.file_name == "customs_declaration.pdf")
    img_att = next(a for a in res.attachments if a.file_name == "container_seal.png")

    assert pdf_att.file_type == "pdf"
    assert pdf_att.file_size_bytes > 0
    assert pdf_att.download_url == f"/api/v1/stage-notes/attachments/{pdf_att.id}/download"

    assert img_att.file_type == "image"
    assert img_att.file_size_bytes > 0


def test_list_stage_notes_and_summary(db_session, tmp_path, monkeypatch):
    monkeypatch.setattr(service, "STORAGE_DIR", str(tmp_path))

    service.create_note_with_attachments_service(
        db=db_session,
        screen_code="demurrage_detention",
        note_text="First note on demurrage",
        created_by="Operator A",
        record_id=12,
    )
    service.create_note_with_attachments_service(
        db=db_session,
        screen_code="demurrage_detention",
        note_text="Second note on demurrage with an Excel sheet",
        created_by="Operator B",
        record_id=12,
        files=[
            UploadFile(filename="rates.xlsx", file=io.BytesIO(b"fake excel content")),
        ],
    )

    summary = service.list_notes_service(
        db=db_session,
        screen_code="demurrage_detention",
        record_id=12,
    )

    assert summary.total_notes == 2
    assert summary.total_attachments == 1
    assert len(summary.notes) == 2
    # Newest first
    assert summary.notes[0].note_text == "Second note on demurrage with an Excel sheet"
    assert len(summary.notes[0].attachments) == 1
    assert summary.notes[0].attachments[0].file_type == "excel"


def test_download_attachment(db_session, tmp_path, monkeypatch):
    monkeypatch.setattr(service, "STORAGE_DIR", str(tmp_path))

    note = service.create_note_with_attachments_service(
        db=db_session,
        screen_code="warehouse_receiving",
        note_text="Discrepancy inspection report",
        created_by="Inspector",
        files=[UploadFile(filename="inspection.pdf", file=io.BytesIO(b"%PDF content"))],
    )
    att_id = note.attachments[0].id

    path, name, media_type = service.get_attachment_file_for_download_service(db_session, att_id)
    assert os.path.exists(path)
    assert name == "inspection.pdf"
    assert media_type == "application/pdf"


def test_validators_reject_invalid_inputs():
    with pytest.raises(HTTPException) as exc:
        validators.validate_note_content("")
    assert exc.value.status_code == 422

    with pytest.raises(HTTPException) as exc:
        validators.validate_screen_code("   ")
    assert exc.value.status_code == 422

    # Disallowed extension
    bad_file = UploadFile(filename="malware.exe", file=io.BytesIO(b"dangerous"))
    with pytest.raises(HTTPException) as exc:
        validators.validate_attachment_file(bad_file)
    assert exc.value.status_code == 400


def test_delete_stage_note(db_session):
    note = service.create_note_with_attachments_service(
        db=db_session,
        screen_code="purchase_orders",
        note_text="Temporary note to delete",
        created_by="Admin",
    )
    note_id = note.id

    service.delete_note_service(db_session, note_id, user_name="Admin")

    summary = service.list_notes_service(db_session, screen_code="purchase_orders")
    assert summary.total_notes == 0
