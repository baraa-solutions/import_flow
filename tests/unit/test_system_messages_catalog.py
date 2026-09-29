"""
System message catalog (single-language storage, Phase A).

- ``docs/system_message_codes.json`` (the Flutter contract) equals ``build_contract()``.
  Regenerate after a catalog change:  python -m modules.common.system_messages
- ``render_en`` renders every code/part and never raises.
- every ``msg("CODE", ...)`` call in modules/ uses a known code (AST scan).
"""
import ast
import json
import re
from pathlib import Path

import pytest

from modules.common import enum_codes
from modules.common import system_messages as sm

ROOT = Path(__file__).resolve().parents[2]
_ARABIC = re.compile(r"[؀-ۿ]")


def test_contract_file_matches_catalog():
    on_disk = json.loads(sm.CONTRACT_PATH.read_text(encoding="utf-8"))
    assert on_disk == sm.build_contract(), "run: python -m modules.common.system_messages"
    assert sm.CONTRACT_PATH == ROOT / "docs" / "system_message_codes.json"


def test_contract_shape():
    contract = sm.build_contract()
    assert len(contract) >= 200
    for code, entry in contract.items():
        assert re.fullmatch(r"[A-Z][A-Z0-9_]+", code), code
        assert set(entry) == {"parts", "params"}
        assert entry["parts"] and all(p in sm.PARTS for p in entry["parts"])
        assert entry["params"] == sorted(set(entry["params"]))


@pytest.mark.parametrize("code", sorted(sm.CATALOG))
def test_every_template_is_english_and_renders_with_all_params(code):
    params = {name: f"<{name}>" for name in sm.params_of(code)}
    for part, template in sm.CATALOG[code].items():
        assert part in sm.PARTS
        assert not _ARABIC.search(template), f"{code}.{part} contains Arabic"
        rendered = sm.render_en(code, params, part)
        assert "{" not in rendered and "}" not in rendered, rendered
        assert rendered.strip()


@pytest.mark.parametrize("code", sorted(sm.CATALOG))
def test_render_en_never_raises_with_missing_or_bad_params(code):
    for part in sm.PARTS:
        for params in (None, {}, "garbage", {"x": object()}):
            out = sm.render_en(code, params, part)
            assert isinstance(out, str) and out


def test_render_en_edge_cases():
    assert sm.render_en(None, {}, "note") == ""
    assert sm.render_en("NOPE_UNKNOWN", {}, "note") == "NOPE_UNKNOWN"
    assert sm.render_en("LC_STEP_COMPLETED", {}, "title") == "LC_STEP_COMPLETED"  # part missing -> code
    assert sm.render_en("LC_STEP_COMPLETED", {}, "note") == "{step_code} completed"  # placeholder kept
    assert sm.render_en("LC_STEP_COMPLETED", {"step_code": None}, "note") == " completed"
    assert sm.render_en("LC_STEP_COMPLETED", {"step_code": "STEP_05"}, "note") == "STEP_05 completed"


def test_render_en_uses_english_labels_for_enum_params():
    rendered = sm.render_en("LC_STEP_ON_HOLD_CODED", {"reason_enum_hold_reason": "ADMIN_HOLD"}, "note")
    assert rendered == "On hold: Temporary administrative hold"
    # a non-code value passes through
    assert sm.render_en("LC_STEP_ON_HOLD_CODED", {"reason_enum_hold_reason": "free"}, "note") == "On hold: free"


def test_every_enum_param_names_a_known_enum_type():
    for code in sm.CATALOG:
        for name in sm.params_of(code):
            if "_enum_" in name:
                assert name.split("_enum_", 1)[1].upper() in enum_codes.LABELS_EN, (code, name)


def test_msg_validates_code_and_params():
    m = sm.msg("LC_STEP_ACTIVATED", completed_step_code="STEP_02")
    assert m == sm.SysMsg("LC_STEP_ACTIVATED", {"completed_step_code": "STEP_02"})
    with pytest.raises(KeyError):
        sm.msg("NOT_A_CODE")
    with pytest.raises(TypeError):
        sm.msg("LC_STEP_ACTIVATED", completed_step_code={"nested": 1})
    assert sm.is_known_code("NA_FILE_CLOSED") and not sm.is_known_code(None) and not sm.is_known_code("X")


def test_plan_example_codes_exist():
    for code in ("LC_STEP_AUTO_COMPLETED", "LC_TASK_NEXT_STEP", "NA_FOLLOW_UP_STEP", "NA_CL_RECORD_INSPECTION",
                 "NOTIF_COMPANY_IMPORTER_ID_EXPIRY", "ALERT_BACKUP_OVERDUE", "GUIDE_SUPPLIER_DELAY"):
        assert code in sm.CATALOG


def _msg_call_codes():
    for path in (ROOT / "modules").rglob("*.py"):
        tree = ast.parse(path.read_text(encoding="utf-8-sig"))
        for node in ast.walk(tree):
            if not isinstance(node, ast.Call):
                continue
            func = node.func
            name = func.id if isinstance(func, ast.Name) else func.attr if isinstance(func, ast.Attribute) else None
            if name == "msg" and node.args and isinstance(node.args[0], ast.Constant) and isinstance(node.args[0].value, str):
                yield path.relative_to(ROOT).as_posix(), node.args[0].value


def test_every_msg_call_site_uses_a_known_code():
    calls = list(_msg_call_codes())
    assert calls, "expected msg() call sites (lifecycle hold/resume, import_files hold/resume)"
    unknown = [(p, c) for p, c in calls if c not in sm.CATALOG]
    assert unknown == []
