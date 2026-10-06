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
