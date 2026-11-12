"""
Review wave shared needs (docs/plans/review-shared-needs.md): central registration of message codes, enum code
sets and system parameters.

- Every message code a module raises / returns as a plain dict (``detail={"code": ...}``, ``message_code=``,
  ``msg_code``, ``coded_error(...)``, ``fa_error(...)``, ...) is in ``system_messages.CATALOG`` (AST scan, like the
  permission catalog test), and the params it sends cover the template placeholders.
- The new enum sets map every legacy value the modules store today to a code.
- ``DEFAULT_PARAMETERS`` defaults equal the module constants their readers fall back to, so seeding changes nothing.
- ``get_float_parameter`` optional range.
"""
import ast
import json
import logging
import math
import re
from pathlib import Path
from typing import Dict, Iterator, List, Optional, Set, Tuple

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import database.models  # noqa: F401  (registers the model tables on Base.metadata)
from database.database import Base
from modules.common import enum_codes as ec
from modules.common import system_messages as sm
from modules.common import system_parameters as sp

ROOT = Path(__file__).resolve().parents[2]
MODULES = ROOT / "modules"
CODE_RE = re.compile(r"^[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+$")
_CODE_KEYS = {"code", "message_code", "msg_code", "banner_message_code", "settlement_warning_code"}
_PARAM_KEYS = {"message_code": ("message_params",), "msg_code": ("params", "msg_params"),
               "banner_message_code": ("banner_message_params",)}
_NON_PARAM_KEYS = {"code", "message", "message_ar", "status_code", "severity"}
# Code-raising helpers: the code is one of the first positional args, the params are the keyword args.
_RAISERS = re.compile(r"^(?:\w*_error|CodedHTTPException|_message|issue|to_item|msg)$")

# Plain-dict "codes" that are not system messages.
NOT_MESSAGE_CODES = {
    "PASSWORD_CHANGE_REQUIRED",  # auth protocol code (403), handled by the API client, never rendered
    "DYNAMIC_WH_ESTIMATE",  # milestone audit item code in file_closure
    "ACTUAL_WH_ARRIVAL",  # milestone audit item code in file_closure
    "EMPTY_CONTAINER_RETURN",  # milestone audit item code in file_closure
    "CHECKLIST_GATE_BLOCKED",  # gatekeeper 409 error code with custom dictionary payload
    "OPEN_TASKS_BYPASSED",  # lifecycle step skip warning payload code
    # Banking milestone identifiers (MilestoneDefinition(code=...) in import_files/payment_milestones.py):
    # data keys with their own label_ar / label_en, never raised as system messages.
    "ADV_SWIFT_MT103", "LC_MT700_ISSUED", "LC_SHIPMENT_DEADLINE", "LC_DOCS_HONOURED",
    "CAD_COLLECTION_NOTICE", "CAD_DOCS_RELEASED", "OA_GRN_RECEIVED", "OA_SUPPLIER_SETTLED",
}
NOT_MESSAGE_FILES = {"modules/auth/seed_rbac.py"}  # role definitions ({"code": "GENERAL_MANAGER", ...})

# Call sites that send fewer params than the registered template uses (rendered with the placeholder left in).
# The owning module switches to the variant code noted here; remove the entry when it does.
KNOWN_PARAM_GAPS = {
    # financial_settlement.validators.ensure_cost_not_approved -> SETTLEMENT_COST_ALREADY_APPROVED
    ("SETTLEMENT_NOT_EDITABLE", "modules/financial_settlement/validators.py"),
}

REVIEW_WAVE_CODES = (
    # 02
    "FA_FX_RATE_MISSING", "FA_CURRENCY_MISSING", "FA_SWIFT_CURRENCY_MISMATCH", "FA_SWIFT_REF_ALREADY_USED",
    "FA_SWIFT_BATCH_ALREADY_RECONCILED", "FA_SWIFT_BATCH_STATUS_INVALID", "FA_PAYMENT_STATUS_INVALID",
    "FA_PAYMENT_LOCKED", "FA_BUDGET_LOCKED", "FA_BUDGET_STATUS_INVALID", "FA_PAYMENT_DUPLICATE_TYPE",
    "FA_BUDGET_DUPLICATE_FILE", "FA_BUDGET_HARD_BLOCK", "FA_BUDGET_SOD_DENIED", "FA_BUDGET_SYNC_REVISION_CREATED",
    "FA_BUDGET_SYNC_DONE", "FA_SWIFT_BATCH_CONFIRMED", "FA_SWIFT_FILE_TOO_LARGE", "FA_SWIFT_FILE_INVALID_BASE64",
    "FA_CODE_GENERATION_CONFLICT", "FA_PAYMENT_RATE_REQUIRED",
    # 03a-D2
    "DOC_ACID_TRACKER_STATUS", "DOC_LEGAL_DOC_EXPIRED", "DOC_LEGAL_DOC_CRITICAL_BREACH", "DOC_LEGAL_DOC_EXPIRING_SOON",
    "DOC_LEGAL_DOC_VALID", "DOC_LEGAL_ACID_MISSING", "DOC_LEGAL_BANNER", "DOC_INVOICE_BL_SYNCED", "DOC_ACID_CONFLICT",
    # 03b
    "ODC_COURIER_NOT_FOUND", "ODC_SESSION_NOT_FOUND", "DCA_SESSION_FINAL_LOCKED", "DCA_SESSION_NOT_READY",
    "DCA_TICKET_CLOSED", "DCA_SAME_REVIEWER", "SDU_ACID_INVALID", "SDU_ACID_CONFLICT", "SDU_FILE_CLOSED",
    "SDU_INVOICE_APPLIED", "SDU_BL_APPLIED", "SDU_EXTRACTED_ONLY", "SDU_NO_SHIPPING_RECORD", "XCHK_ACID_MISMATCH", "XCHK_TAX_ID_MISMATCH",
    "XCHK_SHIPPER_MISMATCH", "XCHK_CONSIGNEE_MISMATCH", "XCHK_WEIGHT_OVER", "XCHK_WEIGHT_MINOR",
    "XCHK_PORTS_MISMATCH", "XCHK_INCOTERM_PREPAID_CONFLICT", "XCHK_INCOTERM_COLLECT_CONFLICT",
    "XCHK_PACKAGES_MISMATCH",
    # 04-05
    "DD_SETTLEMENT_STALE",
    # 06-07
    "CC_RELEASE_RECORD_FILE_MISMATCH", "CC_DUTY_NOT_ASSESSED", "CC_DUTY_UNDERPAID", "CC_DUTY_NOT_PAID",
    "CC_DUTY_PAID_AMOUNT_REQUIRED", "CC_ASSESS_REQUIRES_DECLARATION_46", "CC_UPDATE_NULL_NOT_ALLOWED",
    "CC_RESTORE_DUPLICATE_ACTIVE", "CC_UNDER_BOND_NOT_ALLOWED", "CC_INVOICE_FX_RATE_REQUIRED",
    "CC_INVOICE_RECORD_FILE_MISMATCH", "CC_ACID_EXPIRY_INVALID", "CC_REFERENCE_CODE_CONFLICT",
    "CC_RELEASE_QUARANTINE_LOCKED", "CC_LAB_RESULT_ALREADY_FINAL", "CC_ASSESSED_COMPONENTS_LOCKED",
    "CC_SETTLEMENT_LOCKED",
    "CCQ_RFQ_STATUS_INVALID", "CCQ_RFQ_CANCELLED", "CCQ_QUOTE_EXPIRED", "CCQ_AWARDED_QUOTE_DELETE", "CCQ_RFQ_AWARDED",
    "CCQ_PRICE_LIST_DATE_RANGE",
    # 08-10
    "WR_GRN_EXISTS", "WR_GRN_LINE_UNBALANCED", "WR_VERDICT_INVALID", "WR_VERDICT_INCONSISTENT",
    "WR_VERDICT_INCONSISTENT_EXPECTED", "WR_STATUS_INVALID", "WR_DISCREPANCY_TYPE_INVALID", "IT_BOOKING_EXISTS",
    "IT_STATUS_INVALID", "IT_TRANSITION_NOT_ALLOWED", "FC_ALREADY_CLOSED", "FC_CLOSURE_BLOCKED",
    "FC_CLOSED_RECORD_LOCKED", "FC_CLOSURE_EXISTS", "FC_STATUS_INVALID",
    # 09
    "SETTLEMENT_FX_RATE_MISSING", "SETTLEMENT_NOT_EDITABLE", "SETTLEMENT_COST_ALREADY_APPROVED",
    "SETTLEMENT_DUPLICATE_ACTIVE", "INVOICES_ALREADY_SETTLED", "JOURNAL_UNBALANCED", "SETTLEMENT_LINE_NO_HS",
    "SETTLEMENT_LINE_ZERO_VALUE", "PAYMENT_STATUS_UNKNOWN", "ESTIMATE_UNAVAILABLE", "SETTLEMENT_UNPAID_INVOICE",
    "WHT_RATE_MISSING_WARNING", "WHT_RATE_NOT_CONFIGURED", "RECALC_NO_VARIANCE", "RECALC_SOFT_VARIANCE",
    "RECALC_HARD_BLOCK", "RECALC_APPLIED", "RECALC_RATE_MISSING",
)


# ── AST scan of the modules ──────────────────────────────────────────────────────────────────────────────────

def _module_path(module: str) -> Optional[Path]:
    base = ROOT.joinpath(*module.split("."))
    for candidate in (base.with_suffix(".py"), base / "__init__.py"):
        if candidate.exists():
            return candidate
    return None


def _string_constants(tree: ast.Module) -> Dict[str, str]:
    consts: Dict[str, str] = {}
    for node in tree.body:
        if isinstance(node, ast.Assign) and isinstance(node.value, ast.Constant) and isinstance(node.value.value, str):
            for target in node.targets:
                if isinstance(target, ast.Name):
                    consts[target.id] = node.value.value
    return consts


_TREES: Dict[Path, ast.Module] = {}


def _tree(path: Path) -> ast.Module:
    if path not in _TREES:
        _TREES[path] = ast.parse(path.read_text(encoding="utf-8-sig"))
    return _TREES[path]


def _resolver(path: Path, tree: ast.Module) -> Dict[str, str]:
    """Module-level string constants of the file plus the names it imports from other module files."""
    names = dict(_string_constants(tree))
    package = ".".join(path.relative_to(ROOT).with_suffix("").parts[:-1])
    for node in ast.walk(tree):
        if not isinstance(node, ast.ImportFrom):
            continue
        module = node.module or ""
        if node.level:
            parts = package.split(".")
            module = ".".join(parts[: len(parts) - node.level + 1] + ([module] if module else []))
        source = _module_path(module) if module else None
        if source is None:
            continue
        consts = _string_constants(_tree(source))
        for alias in node.names:
            if alias.name in consts:
                names[alias.asname or alias.name] = consts[alias.name]
    return names


def _values(node: ast.AST, names: Dict[str, str]) -> List[str]:
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return [node.value]
    if isinstance(node, ast.Name) and node.id in names:
        return [names[node.id]]
    if isinstance(node, ast.IfExp):
        return _values(node.body, names) + _values(node.orelse, names)
    return []


def _dict_keys(node: ast.AST) -> Optional[Set[str]]:
    """Literal keys of a dict expression (None when it is not a literal dict or spreads ``**``)."""
    if isinstance(node, ast.IfExp):
        node = node.body
    if not isinstance(node, ast.Dict) or any(k is None for k in node.keys):
        return None
    return {k.value for k in node.keys if isinstance(k, ast.Constant) and isinstance(k.value, str)}


Site = Tuple[str, str, int, Optional[Set[str]]]  # code, file, line, params sent (None = unknown)


def _coded_sites() -> Iterator[Site]:
    for path in sorted(MODULES.rglob("*.py")):
        rel = path.relative_to(ROOT).as_posix()
        if rel in NOT_MESSAGE_FILES:
            continue
        tree = _tree(path)
        names = _resolver(path, tree)
        for node in ast.walk(tree):
            if isinstance(node, ast.Dict):
                pairs = {k.value: v for k, v in zip(node.keys, node.values) if isinstance(k, ast.Constant)}
                spread = any(k is None for k in node.keys)
                for key in _CODE_KEYS & set(pairs):
                    for code in _values(pairs[key], names):
                        if key == "code" and "params" in pairs:  # {"code", "params": {...}, "severity"} item
                            params = _dict_keys(pairs["params"])
                        elif key == "code":
                            params = None if spread else set(pairs) - _NON_PARAM_KEYS
                        else:
                            params = next((_dict_keys(pairs[p]) for p in _PARAM_KEYS.get(key, ()) if p in pairs), None)
                        yield code, rel, node.lineno, params
            elif isinstance(node, ast.Call):
                func = node.func
                name = func.id if isinstance(func, ast.Name) else func.attr if isinstance(func, ast.Attribute) else ""
                kwargs = {kw.arg: kw.value for kw in node.keywords if kw.arg}
                for key in _CODE_KEYS & set(kwargs):
                    for code in _values(kwargs[key], names):
                        params = next((_dict_keys(kwargs[p]) for p in _PARAM_KEYS.get(key, ()) if p in kwargs), None)
                        yield code, rel, node.lineno, params
                if _RAISERS.match(name):
                    spread = any(kw.arg is None for kw in node.keywords)
                    for arg in node.args[:3]:
                        for code in _values(arg, names):
                            yield code, rel, node.lineno, None if spread else set(kwargs) - _NON_PARAM_KEYS


def _message_sites() -> List[Site]:
    return [s for s in _coded_sites() if CODE_RE.match(s[0]) and s[0] not in NOT_MESSAGE_CODES]


def test_scan_finds_the_review_wave_call_sites():
    found = {code for code, *_ in _message_sites()}
    assert len(found) >= 150, len(found)
    # one call site per plan section, through each detection path (dict, *_error, message_code=, Name, IfExp)
    for code in ("DCA_SESSION_NOT_READY", "FA_FX_RATE_MISSING", "CC_DUTY_UNDERPAID", "WR_GRN_EXISTS",
                 "SETTLEMENT_DUPLICATE_ACTIVE", "SETTLEMENT_LINE_NO_HS", "RECALC_RATE_MISSING", "RECALC_NO_VARIANCE",
                 "DOC_LEGAL_ACID_MISSING", "SDU_BL_APPLIED", "XCHK_WEIGHT_OVER", "WHT_RATE_NOT_CONFIGURED",
                 "LC_STEP_ON_HOLD"):
        assert code in found, code


def test_every_coded_message_raised_by_a_module_is_registered():
    missing = sorted({(code, f"{rel}:{line}") for code, rel, line, _ in _message_sites() if code not in sm.CATALOG})
    assert missing == [], "register these codes in modules/common/system_messages.py: %s" % missing


def test_call_sites_send_every_template_param():
    """Review-wave codes only: older multi-part codes (notes / tasks) build their params in several steps."""
    gaps = set()
    for code, rel, line, params in _message_sites():
        if params is None or code not in REVIEW_WAVE_CODES:
            continue
        lacking = set(sm.params_of(code)) - params
        if lacking:
            gaps.add((code, rel, line, tuple(sorted(lacking))))
    unexpected = sorted(g for g in gaps if (g[0], g[1]) not in KNOWN_PARAM_GAPS)
    assert unexpected == []
    assert {(g[0], g[1]) for g in gaps} == KNOWN_PARAM_GAPS, "a known gap was fixed: drop it from KNOWN_PARAM_GAPS"


@pytest.mark.parametrize("code", REVIEW_WAVE_CODES)
def test_review_wave_code_is_registered_with_an_english_note(code):
    assert set(sm.CATALOG[code]) == {"note"}
    rendered = sm.render_en(code, {p: "x" for p in sm.params_of(code)}, "note")
    assert "{" not in rendered and rendered.strip()


def test_review_wave_codes_have_their_documented_params():
    expected = {
        "FA_PAYMENT_STATUS_INVALID": ["action", "payment_code", "status"],
        "FA_BUDGET_HARD_BLOCK": ["field_name", "variance_percentage"],
        "DOC_LEGAL_DOC_CRITICAL_BREACH": ["doc_kind", "doc_number", "eta_date", "expiry_date"],
        "DOC_LEGAL_ACID_MISSING": [],
        "DCA_SESSION_NOT_READY": ["missing_statuses", "open_tickets_count"],
        "XCHK_WEIGHT_OVER": ["diff_kg", "tolerance_pct", "variance_pct"],
        "CC_DUTY_UNDERPAID": ["assessed_amount", "paid_amount"],
        "WR_GRN_LINE_UNBALANCED": ["accepted_qty", "damaged_qty", "invoiced_qty", "item_code", "shortage_qty"],
        "WR_VERDICT_INCONSISTENT_EXPECTED": ["expected_verdict", "verdict"],
        "IT_TRANSITION_NOT_ALLOWED": ["action", "current_status"],
        "SETTLEMENT_UNPAID_INVOICE": ["amount", "invoice_no", "party_name"],
        "WHT_RATE_NOT_CONFIGURED": ["invoice_code", "on_date", "tax_code"],
        "RECALC_APPLIED": ["action_taken"],
        "DD_SETTLEMENT_STALE": ["tracking_code"],
    }
    for code, params in expected.items():
        assert sm.params_of(code) == params, code


def test_cross_check_templates_match_the_catalog():
    from modules.smart_document_upload.cross_checker import XCHK_TEMPLATES_EN

    for code, template in XCHK_TEMPLATES_EN.items():
        assert sm.CATALOG[code] == {"note": template}, code


def test_catalog_has_no_duplicate_keys():
    """A repeated key in the CATALOG literal would silently drop the first template."""
    tree = ast.parse((MODULES / "common" / "system_messages.py").read_text(encoding="utf-8"))
    catalog = next(n.value for n in tree.body if isinstance(n, ast.AnnAssign) and getattr(n.target, "id", "") == "CATALOG")
    keys = [k.value for k in catalog.keys]
    assert len(keys) == len(set(keys))


def test_contract_json_carries_the_new_codes():
    contract = json.loads(sm.CONTRACT_PATH.read_text(encoding="utf-8"))
    for code in REVIEW_WAVE_CODES:
        assert contract[code] == {"parts": ["note"], "params": sm.params_of(code)}, code


# ── Enum code sets ───────────────────────────────────────────────────────────────────────────────────────────

NEW_ENUM_TYPES = (
    ec.PAYMENT_TYPE, ec.LEGAL_DOC_KIND, ec.LAB_TEST_RESULT, ec.ODC_STATUS, ec.ORIGINAL_DOC_STATUS,
    ec.ORIGINAL_DOC_REQUIRED, ec.COURIER_STATUS, ec.DOC_REVIEW_STATUS, ec.DOC_APPROVAL_STATUS, ec.TICKET_STATUS,
    ec.TICKET_SEVERITY, ec.ALLOCATION_RULE, ec.SETTLEMENT_STATUS, ec.ACTUAL_COST_BUCKET, ec.DUTY_COMPONENT,
    ec.WAREHOUSE_RECEIVING_STATUS, ec.GRN_DISCREPANCY_TYPE, ec.INLAND_TRANSPORT_STATUS, ec.FILE_CLOSURE_STATUS,
)


def test_new_enum_types_are_in_the_contract():
    contract = json.loads(ec.CONTRACT_PATH.read_text(encoding="utf-8"))
    for enum_type in NEW_ENUM_TYPES:
        assert contract[enum_type] == ec.build_contract()[enum_type]
    assert contract[ec.PAYMENT_TYPE]["codes"] == {
        "ADVANCE_PAYMENT": "Advance Payment", "AGAINST_BL": "Against B/L", "LETTER_OF_CREDIT": "Letter of Credit (L/C)",
        "DOCUMENTARY_COLLECTION": "Documentary Collection (CAD)", "FINAL_SETTLEMENT": "Final Settlement",
    }
    assert ec.codes(ec.LEGAL_DOC_KIND) == ["ACID", "IMPORT_CARD", "COMMERCIAL_REGISTRY", "TAX_CARD"]
    assert ec.codes(ec.LAB_TEST_RESULT) == ["CONFORMING", "NON_CONFORMING", "PENDING", "NONE"]


def test_payment_type_matches_the_financial_approval_local_set():
    from modules.financial_approval import validators as fa

    assert fa.PAYMENT_TYPE == ec.PAYMENT_TYPE
    assert ec.LABELS_EN[ec.PAYMENT_TYPE] == fa.PAYMENT_TYPE_LABELS_EN
    for alias, code in fa._PAYMENT_TYPE_ALIASES.items():
        assert ec.normalize(ec.PAYMENT_TYPE, alias) == code, alias
        assert fa.normalize_payment_type(alias.upper()) == code, alias  # now delegates to enum_codes
    assert fa.normalize_payment_type("Wire") == "Wire"
    assert fa.require_payment_type("Advance") == "ADVANCE_PAYMENT"


def test_lab_test_result_matches_the_customs_clearance_map():
    from modules.customs_clearance import validators as cc

    for legacy, code in cc._LAB_RESULT_LEGACY.items():
        assert ec.normalize(ec.LAB_TEST_RESULT, legacy) == code, legacy
        assert cc.normalize_lab_test_result(legacy) == code
    assert ec.normalize(ec.LAB_TEST_RESULT, "Pending") == "PENDING"


def test_legal_doc_kind_covers_the_documentation_alert_titles():
    assert ec.normalize(ec.LEGAL_DOC_KIND, "البطاقة الضريبية / ملف القيمة المضافة (Tax Card)") == "TAX_CARD"
    assert ec.normalize(ec.LEGAL_DOC_KIND, "Import Card") == "IMPORT_CARD"
    assert ec.label_ar(ec.LEGAL_DOC_KIND, "COMMERCIAL_REGISTRY") == "السجل التجاري"


def _assert_all_map(enum_type: str, values, expected: Optional[Dict[str, str]] = None):
    for value in values:
        code = ec.normalize(enum_type, value)
        assert ec.is_code(enum_type, code), (enum_type, value, code)
        if expected is not None:
            assert code == expected[value], (enum_type, value)


def test_module_local_status_sets_map_to_codes():
    from modules.docs_customs_approval import validators as dca
    from modules.file_closure import validators as fc
    from modules.inland_transport import validators as it
    from modules.original_documents_collection import validators as odc
    from modules.warehouse_receiving import validators as wr

    _assert_all_map(ec.ODC_STATUS, odc.SESSION_STATUSES)
    _assert_all_map(ec.ORIGINAL_DOC_STATUS, odc.DOCUMENT_STATUSES)
    _assert_all_map(ec.ORIGINAL_DOC_REQUIRED, odc.REQUIRED_FLAGS)
    _assert_all_map(ec.COURIER_STATUS, odc.COURIER_STATUSES)
    _assert_all_map(ec.DOC_APPROVAL_STATUS, dca.DOC_APPROVAL_STATUS, dca.DOC_APPROVAL_STATUS)
    _assert_all_map(ec.DOC_REVIEW_STATUS, dca.DOC_REVIEW_STATUS, dca.DOC_REVIEW_STATUS)
    _assert_all_map(ec.TICKET_STATUS, dca.TICKET_STATUS, dca.TICKET_STATUS)
    _assert_all_map(ec.TICKET_SEVERITY, dca.TICKET_SEVERITY, dca.TICKET_SEVERITY)
    _assert_all_map(ec.WAREHOUSE_RECEIVING_STATUS, wr.WR_STATUS_LABELS)
    _assert_all_map(ec.GRN_DISCREPANCY_TYPE, wr.WR_DISCREPANCY_TYPES)
    _assert_all_map(ec.INLAND_TRANSPORT_STATUS, it.IT_STATUS_LABELS)
    _assert_all_map(ec.FILE_CLOSURE_STATUS, (fc.CLOSURE_STATUS_DRAFT, fc.CLOSURE_STATUS_CLOSED, "Archived", "Reopened"))
    assert ec.normalize(ec.GRN_DISCREPANCY_TYPE, "Damage & Shortage") == "SHORTAGE_AND_DAMAGE"
    assert ec.normalize(ec.WAREHOUSE_RECEIVING_STATUS, "Draft / Pending Warehouse Count") == "PENDING_COUNT"


def test_settlement_enum_sets_map_the_module_values():
    from typing import get_args

    from modules.customs_clearance.validators import DUTY_COMPONENT_FIELDS
    from modules.financial_settlement import schemas as fss
    from modules.financial_settlement.service import ACTUAL_BUCKETS
    from modules.financial_settlement.validators import LOCKED_SETTLEMENT_STATUSES

    _assert_all_map(ec.ALLOCATION_RULE, get_args(fss.AllocationRule))
    assert [ec.normalize(ec.ALLOCATION_RULE, v) for v in ("Value-Based", "Weight-Based", "Volume-Based", "Equal")] == [
        "VALUE", "WEIGHT", "VOLUME", "EQUAL"]
    assert list(ec.LABELS_EN[ec.ACTUAL_COST_BUCKET].values()) == list(ACTUAL_BUCKETS)
    _assert_all_map(ec.SETTLEMENT_STATUS, ("Draft", "Calculated") + tuple(LOCKED_SETTLEMENT_STATUSES))
    _assert_all_map(ec.DUTY_COMPONENT, DUTY_COMPONENT_FIELDS + ("actual_duty_total",))


# ── System parameters ────────────────────────────────────────────────────────────────────────────────────────

@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(bind=engine, autoflush=False)()
    yield session
    session.close()
    engine.dispose()


def _default(key: str) -> str:
    return sp.DEFAULT_PARAMETERS[key][0]


def test_parameter_rows_fit_the_columns():
    for key, (value, description) in sp.DEFAULT_PARAMETERS.items():
        assert len(key) <= 100 and len(value) <= 255 and description and len(description) <= 255, key


def test_insurance_defaults_equal_the_module_constants():
    from modules.cargo_insurance import service as ins

    for clause, key in ins.INSURANCE_RATE_KEYS.items():
        assert float(_default(key)) == ins.DEFAULT_RATE_TABLE[clause], key
    assert float(_default(ins.INSURANCE_WAR_STRIKES_RATE)) == ins.DEFAULT_WAR_STRIKES_RATE
    assert float(_default(ins.INSURANCE_TAX_RATE)) == ins.DEFAULT_TAX_RATE
    assert float(_default(ins.INSURANCE_ISSUANCE_FEE)) == ins.DEFAULT_ISSUANCE_FEE
    assert float(_default(ins.INSURANCE_MIN_PREMIUM)) == ins.DEFAULT_MIN_PREMIUM
    assert float(_default(ins.INSURANCE_MARKUP)) == ins.DEFAULT_MARKUP


def test_demurrage_defaults_equal_the_module_constants():
    from modules.demurrage_detention import service as dd

    assert json.loads(_default(dd.DD_DEFAULT_DEMURRAGE_TIERS)) == dd.DEFAULT_DEMURRAGE_TIERS
    assert json.loads(_default(dd.DD_DEFAULT_DETENTION_TIERS)) == dd.DEFAULT_DETENTION_TIERS
    pairs = {
        dd.DD_DEFAULT_FREE_DAYS_DEMURRAGE: dd.DEFAULT_FREE_DAYS_DEMURRAGE,
        dd.DD_DEFAULT_FREE_DAYS_DETENTION: dd.DEFAULT_FREE_DAYS_DETENTION,
        dd.DD_DEFAULT_STORAGE_FREE_DAYS: dd.DEFAULT_STORAGE_FREE_DAYS,
        dd.DD_DEFAULT_STORAGE_RATE_EGP: dd.DEFAULT_STORAGE_RATE_EGP,
        dd.DD_STANDARD_FREE_DAYS: dd.DEFAULT_STANDARD_FREE_DAYS,
        dd.DD_DEFAULT_NEGOTIATED_FREE_DAYS: dd.DEFAULT_NEGOTIATED_DEMURRAGE_DAYS,
        dd.DD_AVOIDANCE_RATE_USD: dd.DEFAULT_AVOIDANCE_RATE_USD,
    }
    for key, constant in pairs.items():
        assert float(_default(key)) == float(constant), key


def test_settlement_defaults_equal_the_module_constants():
    from modules.financial_settlement.service import ESTIMATE_PARAMETER_DEFAULTS

    assert len(ESTIMATE_PARAMETER_DEFAULTS) == 7
    for key, constant in ESTIMATE_PARAMETER_DEFAULTS.items():
        assert float(_default(key)) == constant, key


def test_every_reader_key_is_seeded():
    from modules.cargo_insurance import service as ins
    from modules.demurrage_detention import service as dd
    from modules.financial_settlement.service import ESTIMATE_PARAMETER_DEFAULTS

    keys = set(ins.INSURANCE_RATE_KEYS.values()) | {
        ins.INSURANCE_WAR_STRIKES_RATE, ins.INSURANCE_TAX_RATE, ins.INSURANCE_ISSUANCE_FEE, ins.INSURANCE_MIN_PREMIUM,
        ins.INSURANCE_MARKUP,
    } | {getattr(dd, name) for name in dir(dd) if name.startswith("DD_") and isinstance(getattr(dd, name), str)
         and getattr(dd, name) == name} | set(ESTIMATE_PARAMETER_DEFAULTS)
    assert keys <= set(sp.DEFAULT_PARAMETERS), keys - set(sp.DEFAULT_PARAMETERS)
    assert len(keys) == 26  # Added DD_DEFAULT_NEGOTIATED_FREE_DAYS


def test_seeded_database_gives_the_same_numbers_as_an_empty_one(db):
    from modules.cargo_insurance.service import DEFAULT_INSURANCE_RATES, load_insurance_rates
    from modules.demurrage_detention import service as dd
    from modules.financial_settlement.service import ESTIMATE_PARAMETER_DEFAULTS, _estimate_parameter

    empty_tariff = dd.default_tariff(db)
    assert load_insurance_rates(db) == DEFAULT_INSURANCE_RATES
    assert sp.seed_default_parameters(db) == len(sp.DEFAULT_PARAMETERS)
    assert sp.seed_default_parameters(db) == 0
    assert load_insurance_rates(db) == DEFAULT_INSURANCE_RATES
    assert dd.default_tariff(db) == empty_tariff
    for key, constant in ESTIMATE_PARAMETER_DEFAULTS.items():
        assert _estimate_parameter(db, key) == constant
    assert sp.air_volumetric_kg_per_cbm(db) == sp.DEFAULT_AIR_VOLUMETRIC_KG_PER_CBM


def test_seeding_keeps_a_configured_value(db):
    db.add(sp.SystemParameter(param_key="INSURANCE_TAX_RATE", param_value="0.07"))
    db.commit()
    assert sp.seed_default_parameters(db) == len(sp.DEFAULT_PARAMETERS) - 1
    assert sp.get_parameter(db, "INSURANCE_TAX_RATE") == "0.07"


# ── get_float_parameter range ────────────────────────────────────────────────────────────────────────────────

@pytest.mark.parametrize(
    "stored, expected",
    [("0.5", 0.5), ("0", 0.0), ("1", 1.0), ("-0.1", 0.2), ("1.5", 0.2), ("nan", 0.2), ("inf", 0.2), ("x", 0.2)],
)
def test_float_parameter_range_falls_back_to_the_default(db, stored, expected, caplog):
    db.add(sp.SystemParameter(param_key="RATE", param_value=stored))
    db.commit()
    with caplog.at_level(logging.WARNING, logger=sp.logger.name):
        assert sp.get_float_parameter(db, "RATE", 0.2, min_value=0, max_value=1) == expected
    assert bool(caplog.records) == (expected == 0.2 and stored != "0.2")


def test_float_parameter_without_range_keeps_the_old_behaviour(db):
    db.add(sp.SystemParameter(param_key="BIG", param_value="-1e6"))
    db.commit()
    assert sp.get_float_parameter(db, "BIG", 3.0) == -1e6  # positional call, no bounds
    assert sp.get_float_parameter(db, "MISSING", 3.0, min_value=10) == 3.0  # missing: default even if out of range
    assert sp.get_float_parameter(db, "BIG", 3.0, min_value=-1e6) == -1e6  # bounds are inclusive
    assert sp.get_float_parameter(db, "BIG", 3.0, max_value=-2e6) == 3.0
    assert math.isfinite(sp.get_float_parameter(db, "BIG", 3.0))
