"""Single-language storage, Phase B (group 3 modules): stored system text is coded + English.

Covers import_documentation, financial_approval, financial_settlement, freight_booking, cargox,
original_documents_collection, docs_customs_approval, import_requirements, inland_transport,
warehouse_receiving, demurrage_detention and file_closure.
"""

import ast
import re
from pathlib import Path

import pytest

from modules.common.system_messages import CATALOG, render_en

ROOT = Path(__file__).resolve().parents[2]
GROUP3_MODULES = [
    "import_documentation",
    "financial_approval",
    "financial_settlement",
    "freight_booking",
    "cargox",
    "original_documents_collection",
    "docs_customs_approval",
    "import_requirements",
    "inland_transport",
    "warehouse_receiving",
    "demurrage_detention",
    "file_closure",
]
ARABIC = re.compile("[؀-ۿ]")
TRACKING_ATTRS = {"next_action", "current_module", "current_stage", "commercial_notes", "savings_notes"}
MSG_KWARGS = {"notes", "title", "description", "message", "notes_msg", "next_action_msg"}


def _service_tree(module: str) -> ast.AST:
    return ast.parse((ROOT / "modules" / module / "service.py").read_text(encoding="utf-8"))


def _has_arabic(node: ast.AST) -> bool:
    return any(isinstance(n, ast.Constant) and isinstance(n.value, str) and ARABIC.search(n.value) for n in ast.walk(node))


@pytest.mark.parametrize("module", GROUP3_MODULES)
def test_msg_and_render_calls_use_known_codes(module):
    for node in ast.walk(_service_tree(module)):
        if isinstance(node, ast.Call) and getattr(node.func, "id", None) in {"msg", "render_en"} and node.args:
            first = node.args[0]
            if isinstance(first, ast.Constant) and isinstance(first.value, str):
                assert first.value in CATALOG, f"{module}: unknown message code {first.value}"


@pytest.mark.parametrize("module", GROUP3_MODULES)
def test_no_arabic_in_tracking_attribute_writes(module):
    offenders = []
    for node in ast.walk(_service_tree(module)):
        if isinstance(node, (ast.Assign, ast.AugAssign)):
            targets = node.targets if isinstance(node, ast.Assign) else [node.target]
            for target in targets:
                if isinstance(target, ast.Attribute) and target.attr in TRACKING_ATTRS and _has_arabic(node.value):
                    offenders.append(node.lineno)
    assert offenders == [], f"{module}: Arabic stored text at lines {offenders}"


@pytest.mark.parametrize("module", GROUP3_MODULES)
def test_no_arabic_in_system_notification_or_task_text(module):
    offenders = []
    for node in ast.walk(_service_tree(module)):
        if isinstance(node, ast.Call) and getattr(node.func, "id", None) in {"SystemNotification", "SmartTask", "SmartTaskCreate"}:
            for kw in node.keywords:
                if kw.arg in {"title", "message", "description", "phase_name"} and _has_arabic(kw.value):
                    offenders.append(node.lineno)
        if isinstance(node, ast.Call) and getattr(node.func, "id", None) == "advance_lifecycle_step_service":
            for kw in node.keywords:
                if kw.arg in {"notes", "custom_next_action", "custom_stage_title", "custom_module_name"} and _has_arabic(kw.value):
                    offenders.append(node.lineno)
    assert offenders == [], f"{module}: Arabic system text at lines {offenders}"


def test_requirement_item_is_coded_and_english():
    from modules.import_requirements.service import ACID_PENDING_PLACEHOLDER, _requirement_item

    item = _requirement_item(
        "Permit_8415", "Critical", "REQ_TASK_PERMIT_HS",
        import_file_code="IMP-1", hs_code="8415", acid_number=ACID_PENDING_PLACEHOLDER, authority_enum_regulatory_body="EEAA",
    )
    assert item["type"] == "Permit_8415"
    assert item["priority"] == "Critical"
    assert item["msg"].code == "REQ_TASK_PERMIT_HS"
    assert item["title"] == render_en("REQ_TASK_PERMIT_HS", item["msg"].params, "title")
    assert "[ACID: PENDING]" in item["title"] and "EEAA" in item["title"]
    assert not ARABIC.search(item["title"] + item["desc"])


def test_requirement_item_rejects_unknown_code():
    from modules.import_requirements.service import _requirement_item

    with pytest.raises(KeyError):
        _requirement_item("X", "Low", "REQ_TASK_DOES_NOT_EXIST")


def test_free_days_note_prefixes_cover_english_and_legacy():
    from modules.demurrage_detention import service

    assert service.FREE_DAYS_NOTE_PREFIX == "Free days agreement: "
    assert ARABIC.search(service.LEGACY_FREE_DAYS_NOTE_PREFIX)
