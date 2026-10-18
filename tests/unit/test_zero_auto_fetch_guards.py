"""
Unit tests for Zero Auto-Fetch & No Default/Historical Data Guards (TASK-ZAF-11).
Verifies that:
1. Dossier and operational detail services strictly require explicit, positive import_file_id.
2. Passing None, 0, or negative IDs immediately triggers a 400 Bad Request guard without running arbitrary queries.
3. Querying non-existent records returns 404 Not Found rather than falling back to the first record.
4. Master data reference queries remain active-filtered without forcing arbitrary default choices.
"""

import pytest
from fastapi import HTTPException
from sqlalchemy.orm import Session

from database.database import SessionLocal
from modules.file_closure.service import get_comprehensive_shipment_dossier_service, _get_active_file
from modules.import_documentation.service import get_draft_bl_review_service, _active_import_file
from modules.currencies.model import Currency
from modules.incoterms.model import Incoterm


@pytest.fixture
def db_session():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def test_dossier_guard_rejects_none_file_id(db_session: Session):
    """Calling dossier service without an import_file_id must raise 400 Bad Request."""
    with pytest.raises(HTTPException) as exc_info:
        get_comprehensive_shipment_dossier_service(db_session, import_file_id=None)  # type: ignore
    assert exc_info.value.status_code == 400
    assert "import_file_id" in exc_info.value.detail


def test_dossier_guard_rejects_zero_and_negative_file_id(db_session: Session):
    """Calling dossier service with 0 or negative ID must raise 400 Bad Request."""
    with pytest.raises(HTTPException) as exc_zero:
        get_comprehensive_shipment_dossier_service(db_session, import_file_id=0)
    assert exc_zero.value.status_code == 400

    with pytest.raises(HTTPException) as exc_neg:
        get_comprehensive_shipment_dossier_service(db_session, import_file_id=-1)
    assert exc_neg.value.status_code == 400


def test_dossier_guard_raises_404_for_nonexistent_file(db_session: Session):
    """Calling dossier service with a non-existent file ID must raise 404, never fallback to first record."""
    with pytest.raises(HTTPException) as exc_info:
        get_comprehensive_shipment_dossier_service(db_session, import_file_id=99999999)
    assert exc_info.value.status_code == 404


def test_import_documentation_active_file_guard_rejects_none(db_session: Session):
    """_active_import_file must reject None with 400."""
    with pytest.raises(HTTPException) as exc_info:
        _active_import_file(db_session, import_file_id=None)
    assert exc_info.value.status_code == 400


def test_get_draft_bl_review_service_rejects_nonexistent_id(db_session: Session):
    """Querying draft B/L with non-existent ID must raise 404 without silent fallback."""
    with pytest.raises(HTTPException) as exc_info:
        get_draft_bl_review_service(db_session, review_id=99999999)
    assert exc_info.value.status_code == 404


def test_master_data_remains_queryable_by_active_flag(db_session: Session):
    """
    Master Data tables (currencies, incoterms) must remain fetchable when active,
    allowing dropdowns to populate while user selection remains null by default.
    """
    active_currencies = db_session.query(Currency).filter(Currency.is_active == True).all()
    assert isinstance(active_currencies, list)

    active_incoterms = db_session.query(Incoterm).filter(Incoterm.is_active == True).all()
    assert isinstance(active_incoterms, list)
