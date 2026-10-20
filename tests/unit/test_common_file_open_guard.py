"""Unit tests for BEW0-03: Closed-file guard ensure_file_open + IMPORT_FILE_CLOSED."""
from types import SimpleNamespace
from typing import Any, Dict

import pytest
from fastapi import HTTPException, status

from modules.common.errors import CodedHTTPException
from modules.common import system_messages as sm
from modules.common.validators import CLOSED_FILE_STATUSES, ensure_file_open
from modules.import_files.model import ImportFile


def test_closed_file_statuses_constant():
    assert "Closed" in CLOSED_FILE_STATUSES
    assert "Archived" in CLOSED_FILE_STATUSES


def test_system_message_code_registered_in_catalog():
    assert "IMPORT_FILE_CLOSED" in sm.CATALOG
    assert "note" in sm.CATALOG["IMPORT_FILE_CLOSED"]
    template = sm.CATALOG["IMPORT_FILE_CLOSED"]["note"]
    assert "{import_file_code}" in template
    rendered = sm.render_en("IMPORT_FILE_CLOSED", {"import_file_code": "IF-2026-001"}, "note")
    assert "IF-2026-001" in rendered
    assert "permanently closed" in rendered


@pytest.mark.parametrize("status_val", ["Open", "In Progress", "On Hold", "Draft", "Customs Clearance", ""])
def test_open_file_statuses_pass(status_val):
    file_obj = SimpleNamespace(status=status_val, import_file_code="IF-OPEN-001")
    ensure_file_open(file_obj)  # Must not raise


def test_none_input_passes():
    ensure_file_open(None)  # Must not raise


def test_object_without_status_passes():
    obj = SimpleNamespace(import_file_code="IF-NO-STATUS")
    ensure_file_open(obj)  # Must not raise


@pytest.mark.parametrize("status_val", ["Closed", "Archived", "closed", "archived", "CLOSED", "ARCHIVED"])
def test_closed_and_archived_file_raises_409_coded_exception(status_val):
    file_obj = SimpleNamespace(status=status_val, import_file_code="IF-2026-007")

    with pytest.raises(HTTPException) as exc_info:
        ensure_file_open(file_obj)

    exc = exc_info.value
    assert exc.status_code == status.HTTP_409_CONFLICT
    assert isinstance(exc, CodedHTTPException)
    assert exc.code == "IMPORT_FILE_CLOSED"
    assert exc.params == {"import_file_code": "IF-2026-007"}

    detail = exc.detail
    assert isinstance(detail, dict)
    assert detail["code"] == "IMPORT_FILE_CLOSED"
    assert detail["import_file_code"] == "IF-2026-007"
    assert "ملف الشحنة IF-2026-007 مغلق نهائياً ولا يمكن تعديل بياناته. يلزم إعادة فتحه أولاً." == detail["message"]


def test_import_file_model_instance():
    imp = ImportFile(
        import_file_id=101,
        import_file_code="IF-MODEL-101",
        company_name="Al-Amal Import",
        supplier_name="Global Trading",
        status="Closed",
    )

    with pytest.raises(HTTPException) as exc_info:
        ensure_file_open(imp)

    exc = exc_info.value
    assert exc.status_code == 409
    assert exc.detail["code"] == "IMPORT_FILE_CLOSED"
    assert exc.detail["import_file_code"] == "IF-MODEL-101"


def test_dict_input():
    closed_dict: Dict[str, Any] = {"status": "Closed", "import_file_code": "IF-DICT-001"}
    with pytest.raises(HTTPException) as exc_info:
        ensure_file_open(closed_dict)

    exc = exc_info.value
    assert exc.status_code == 409
    assert exc.detail["code"] == "IMPORT_FILE_CLOSED"
    assert exc.detail["import_file_code"] == "IF-DICT-001"

    open_dict: Dict[str, Any] = {"status": "In Progress", "import_file_code": "IF-DICT-002"}
    ensure_file_open(open_dict)  # Must not raise


def test_fallback_to_import_file_id_when_code_missing():
    obj = SimpleNamespace(status="Closed", import_file_id=55)
    with pytest.raises(HTTPException) as exc_info:
        ensure_file_open(obj)

    exc = exc_info.value
    assert exc.status_code == 409
    assert exc.detail["code"] == "IMPORT_FILE_CLOSED"
    assert exc.detail["import_file_code"] == "#55"
    assert "#55" in exc.detail["message"]


def test_empty_code_and_id_message():
    obj = SimpleNamespace(status="Closed")
    with pytest.raises(HTTPException) as exc_info:
        ensure_file_open(obj)

    exc = exc_info.value
    assert exc.status_code == 409
    assert exc.detail["code"] == "IMPORT_FILE_CLOSED"
    assert exc.detail["import_file_code"] == ""
    assert "ملف الشحنة مغلق نهائياً ولا يمكن تعديل بياناته. يلزم إعادة فتحه أولاً." == detail_msg(exc)


def detail_msg(exc: HTTPException) -> str:
    return exc.detail["message"] if isinstance(exc.detail, dict) else str(exc.detail)


def test_ensure_file_open_with_db_session():
    """Test ensure_file_open(db, import_file_id) with in-memory database."""
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker
    from database.database import Base

    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    db = Session()
    try:
        open_file = ImportFile(
            import_file_id=1,
            import_file_code="IF-OPEN-1",
            company_name="Al-Amal Import",
            supplier_name="Global Trading",
            status="In Progress",
        )
        closed_file = ImportFile(
            import_file_id=2,
            import_file_code="IF-CLOSED-2",
            company_name="Al-Amal Import",
            supplier_name="Global Trading",
            status="Closed",
        )
        archived_file = ImportFile(
            import_file_id=3,
            import_file_code="IF-ARCHIVED-3",
            company_name="Al-Amal Import",
            supplier_name="Global Trading",
            status="Archived",
        )
        db.add_all([open_file, closed_file, archived_file])
        db.commit()

        # Open file should not raise
        ensure_file_open(db, 1)

        # Closed file should raise 409
        with pytest.raises(HTTPException) as exc_info:
            ensure_file_open(db, 2)
        assert exc_info.value.status_code == 409
        assert exc_info.value.detail["code"] == "IMPORT_FILE_CLOSED"
        assert exc_info.value.detail["import_file_code"] == "IF-CLOSED-2"

        # Archived file should raise 409
        with pytest.raises(HTTPException) as exc_info:
            ensure_file_open(db, 3)
        assert exc_info.value.status_code == 409
        assert exc_info.value.detail["code"] == "IMPORT_FILE_CLOSED"

        # Non-existent file id should not raise closed error
        ensure_file_open(db, 9999)

        # None id should not raise
        ensure_file_open(db, None)
    finally:
        db.close()

