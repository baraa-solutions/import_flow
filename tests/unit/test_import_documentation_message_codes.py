"""
Single-language storage, Phase C follow-up: document comparison items are stored with message codes
(details_code / details_params, tolerance_code / tolerance_params, checklist reason_code / reason_params)
and structured values (VALUE_PLACEHOLDER / MEASURE_UNIT codes) next to English text; customs_category is
the CUSTOMS_CATEGORY enum.
"""
import importlib
import re
from pathlib import Path

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.common import enum_codes
from modules.common.enum_codes import Measure, Placeholder, finalize_structured_values
from modules.common.system_messages import CATALOG, coded_text, render_en

ARABIC = re.compile("[؀-ۿ]")
ROOT = Path(__file__).resolve().parents[2]
VALUE_KEYS_ALLOWED_ARABIC = {"field_label_ar", "field_name_ar"}


def _assert_coded_item(item, value_keys=()):
    assert item["details_code"] in CATALOG, item
    assert item["details"] == render_en(item["details_code"], item["details_params"], "note")
    assert not ARABIC.search(item["details"])
    for key in value_keys:
        value = item.get(key)
        assert not (isinstance(value, str) and ARABIC.search(value)), (key, value)
    for key, spec in (item.get("structured_values") or {}).items():
        if "placeholder" in spec:
            assert enum_codes.is_code(enum_codes.VALUE_PLACEHOLDER, spec["placeholder"])
            assert item[key] == enum_codes.label_en(enum_codes.VALUE_PLACEHOLDER, spec["placeholder"])
        else:
            assert enum_codes.is_code(enum_codes.MEASURE_UNIT, spec["unit"])


# --- helpers --------------------------------------------------------------------------------------------
def test_coded_text_renders_english_and_keeps_code_and_params():
    fields = coded_text("details", "DOC_DRAFT_FUZZY_MATCH", match_pct=91.5)
    assert fields == {
        "details": "Smart match at 91.5%.",
        "details_code": "DOC_DRAFT_FUZZY_MATCH",
        "details_params": {"match_pct": 91.5},
    }
    # non-primitive values are stringified instead of failing the write
    assert coded_text("details", "DOC_DRAFT_VALUE_FROM_DRAFT", draft_value=["A", "B"])["details_params"] == {
        "draft_value": "['A', 'B']"
    }
    with pytest.raises(KeyError):
        coded_text("details", "DOC_NOT_A_CODE")


def test_finalize_structured_values():
    item = finalize_structured_values({
        "a": Placeholder("NOT_SET"),
        "b": Measure(1234.5, "KG"),
        "c": Measure(12, "PACKAGES", decimals=None),
        "d": Measure(None, "CBM"),
        "e": "plain",
    })
    assert item["a"] == "Not set in the system"
    assert item["b"] == "1,234.50 kg"
    assert item["c"] == "12 packages"
    assert item["d"] == "None CBM"
    assert item["e"] == "plain"
    assert item["structured_values"] == {
        "a": {"placeholder": "NOT_SET"},
        "b": {"number": 1234.5, "unit": "KG"},
        "c": {"number": 12, "unit": "PACKAGES"},
        "d": {"number": None, "raw": "None", "unit": "CBM"},
    }
    assert "structured_values" not in finalize_structured_values({"x": 1})
    with pytest.raises(KeyError):
        finalize_structured_values({"x": Placeholder("NOPE")})
    with pytest.raises(KeyError):
        finalize_structured_values({"x": Measure(1, "LITRE")})


@pytest.mark.parametrize("legacy,code", [
    ("غير مسجل بالسستم", "NOT_SET"), ("غير محدد بالسستم", "NOT_SET"), ("غير متوفر بالمستند", "NOT_IN_DOCUMENT"),
    ("لم يتم الاستخراج", "NOT_EXTRACTED"), ("اختياري / غير مدرج", "OPTIONAL_NOT_INCLUDED"),
    ("غير موجود بالبوليصة", "NOT_IN_BL"), ("غير محدد", "NOT_SPECIFIED"),
])
def test_placeholder_legacy_texts_map_to_codes(legacy, code):
    assert enum_codes.normalize(enum_codes.VALUE_PLACEHOLDER, legacy) == code


# --- PO reconciliation header checks (pure function) ------------------------------------------------------
def _reconcile(invoice, packing, meta):
    from modules.import_documentation.ai_document_parser import reconcile_po_documents_with_system

    return reconcile_po_documents_with_system(invoice, packing, [], meta)["header_discrepancies"]


def test_header_discrepancies_are_coded_with_structured_values():
    headers = _reconcile(
        {"invoice_number": "INV-9", "total_amount": 1000, "currency": "EUR", "qty_pkg": 10},
        {"total_packages": 12, "total_gross_weight_kg": 1500.0, "total_net_weight_kg": 1400.0, "total_cbm": 20.0},
        {"final_invoice_number": "INV-1", "total_amount": 900, "currency": "USD", "total_packages": 10,
         "total_gross_weight_kg": 1000.0, "total_net_weight_kg": 1400.0, "total_cbm": 20.0},
    )
    by_code = {h["check_code"]: h for h in headers}
    value_keys = ("system_value", "extracted_value", "system_invoice_value", "system_packing_value",
                  "uploaded_invoice_value", "uploaded_packing_value")
    for item in headers:
        _assert_coded_item(item, value_keys)

    assert by_code["CHK_INVOICE_NO"]["details_code"] == "DOC_CHK_INVOICE_NO_MISMATCH"
    assert by_code["CHK_INVOICE_NO"]["details_params"] == {"document_value": "INV-9", "system_value": "INV-1"}
    assert by_code["CHK_ACID"]["structured_values"]["system_value"] == {"placeholder": "NOT_SET"}
    assert by_code["CHK_ACID"]["structured_values"]["extracted_value"] == {"placeholder": "NOT_IN_DOCUMENT"}
    assert by_code["CHK_TOTAL_AMOUNT"]["details_code"] == "DOC_CHK_CURRENCY_MISMATCH"
    assert by_code["CHK_TOTAL_AMOUNT"]["structured_values"] == {
        "system_packing_value": {"placeholder": "NOT_IN_PACKING_LIST"}
    }
    pkgs = by_code["CHK_PACKAGES"]
    assert pkgs["details_code"] == "DOC_CHK_PACKAGES_VARIANCE" and pkgs["details_params"] == {"difference_count": 2}
    assert pkgs["extracted_value"] == "12 packages"
    assert pkgs["structured_values"]["extracted_value"] == {"number": 12, "unit": "PACKAGES"}
    gross = by_code["CHK_GROSS_WEIGHT"]
    assert gross["details_code"] == "DOC_CHK_GROSS_WEIGHT_VARIANCE"
    assert gross["structured_values"]["system_value"] == {"number": 1000.0, "unit": "KG"}
    assert gross["system_value"] == "1,000.00 kg"
    assert by_code["CHK_NET_WEIGHT"]["details_code"] == "DOC_CHK_NET_WEIGHT_MATCH"
    assert by_code["CHK_TOTAL_CBM"]["structured_values"]["uploaded_invoice_value"] == {"placeholder": "NOT_IN_INVOICE"}
    assert by_code["CHK_TOTAL_CBM"]["system_value"] == "20.00 CBM"


def test_header_amount_variance_params_are_numbers():
    headers = _reconcile({"total_amount": 1100, "currency": "USD"}, {},
                         {"total_amount": 1000, "currency": "USD"})
    amount = next(h for h in headers if h["check_code"] == "CHK_TOTAL_AMOUNT")
    assert amount["details_code"] == "DOC_CHK_AMOUNT_VARIANCE"
    assert amount["details_params"]["currency"] == "USD"
    assert isinstance(amount["details_params"]["variance_amount"], float)


# --- invoice vs B/L matcher (pure function) ---------------------------------------------------------------
def test_invoice_bl_matrix_is_coded():
    from modules.import_documentation.ai_document_parser import match_invoice_with_bl

    result = match_invoice_with_bl(
        {"acid_number": "1" * 19, "shipper": "ACME", "total_gross_weight_kg": 1000.0, "qty_pkg": 5},
        {"acid_number": "2" * 19, "shipper": "ACME", "total_gross_weight_kg": 1000.0, "qty_pkg": 5},
        {"acid_number": "1" * 19},
    )
    matrix = result["comparison_matrix"]
    for item in matrix:
        _assert_coded_item(item, ("system_value", "packing_list_value", "invoice_value", "bl_value"))
        assert item["tolerance_code"] in CATALOG
        assert item["tolerance"] == render_en(item["tolerance_code"], item["tolerance_params"], "note")
    by_code = {m["item_code"]: m for m in matrix}
    assert by_code["CHK_ACID"]["details_code"] == "DOC_IBL_ACID_MISMATCH"
    assert by_code["CHK_TAX_ID"]["details_code"] == "DOC_IBL_TAX_ID_NOT_EXTRACTED"
    assert by_code["CHK_TAX_ID"]["structured_values"]["bl_value"] == {"placeholder": "NOT_IN_BL"}
    assert by_code["CHK_PACKAGES"]["structured_values"]["invoice_value"] == {"number": 5, "unit": "PACKAGES_PALLETS"}
    assert by_code["CHK_GROSS_WEIGHT"]["details_code"] == "DOC_IBL_GROSS_WEIGHT_MATCH"
    assert by_code["CHK_INCOTERMS"]["details_params"] == {"incoterm": "EXW", "freight_terms": "Freight Prepaid"}
    assert "Reason: ACID number mismatch" in result["correction_letter"]


# --- draft B/L / COO / inspection services (DB) -----------------------------------------------------------
def _register_all_models() -> None:
    for model_file in sorted((ROOT / "modules").glob("*/model.py")):
        importlib.import_module(f"modules.{model_file.parent.name}.model")


@pytest.fixture()
def db():
    _register_all_models()
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(bind=engine)()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


@pytest.fixture()
def import_file(db):
    from modules.import_files.model import ImportFile

    rec = ImportFile(import_file_code="IMP-CODES-1", supplier_name="ACME GmbH", company_name="ECO EGYPT", is_active=True)
    db.add(rec)
    db.commit()
    return rec


def test_draft_bl_comparison_matrix_and_checklist_are_coded(db, import_file, monkeypatch):
    from modules.import_documentation import service
    from modules.import_documentation.schemas import DraftBLComparisonRequest

    monkeypatch.setattr(service, "_build_system_bl_snapshot", lambda _db, _id: {
        "vessel_name": "MSC ONE", "booking_no": "BKG-1", "total_gross_weight_kg": 1000.0, "consignee": "ECO EGYPT",
    })
    res = service.compare_draft_bl_service(db, DraftBLComparisonRequest(
        import_file_id=import_file.import_file_id,
        draft_fields={"vessel_name": "MSC TWO", "booking_no": "BKG-1", "total_gross_weight_kg": 1100.0, "pol": "SHANGHAI"},
    ))
    by_key = {m["field_key"]: m for m in res["comparison_matrix"]}
    for item in res["comparison_matrix"]:
        _assert_coded_item(item)
    assert by_key["vessel_name"]["details_code"] == "DOC_DRAFT_APPROVED_VALUE_MISMATCH"
    assert by_key["vessel_name"]["details_params"] == {"system_value": "MSC ONE", "draft_value": "MSC TWO"}
    assert by_key["booking_no"]["details_code"] == "DOC_DRAFT_TEXT_MATCH"
    assert by_key["total_gross_weight_kg"]["details_code"] == "DOC_DRAFT_NUMERIC_VARIANCE"
    assert by_key["pol"]["details_code"] == "DOC_DRAFT_VALUE_FROM_DRAFT"
    assert by_key["shipper"]["details_code"] == "DOC_DRAFT_FIELD_MISSING"

    checklist = {c["field_key"]: c for c in res["checklist_data"]}
    vessel = checklist["vessel_name"]
    assert vessel["reason_code"] == "DOC_DRAFT_APPROVED_VALUE_MISMATCH"
    assert vessel["reason"] == by_key["vessel_name"]["details"]
    assert checklist["booking_no"]["reason_code"] is None and checklist["booking_no"]["reason"] is None
    assert not ARABIC.search(res["correction_request_letter"].split("Reason / Details:")[1].split("\n")[0])


def test_edited_checklist_reason_drops_its_code():
    from modules.import_documentation.service import _drop_stale_reason_code

    fields = coded_text("reason", "DOC_DRAFT_TEXT_MATCH")
    kept = _drop_stale_reason_code(dict(fields))
    assert kept["reason_code"] == "DOC_DRAFT_TEXT_MATCH"
    edited = _drop_stale_reason_code({**fields, "reason": "User wrote this"})
    assert edited == {"reason": "User wrote this", "reason_code": None, "reason_params": None}


def test_coo_and_inspection_matrices_are_coded(db, import_file):
    from modules.import_documentation import service
    from modules.import_documentation.schemas import COOComparisonRequest, InspectionComparisonRequest

    coo = service.compare_coo_service(db, COOComparisonRequest(
        import_file_id=import_file.import_file_id, certificate_type="EUR.1",
        draft_fields={"exporter_name": "ACME GmbH"},
    ))
    for item in coo["comparison_matrix"]:
        _assert_coded_item(item, ("draft_value",))
    codes = {m["details_code"] for m in coo["comparison_matrix"]}
    assert {"DOC_COO_VALUE_NOT_FOUND", "DOC_COO_SIMILARITY"} <= codes
    missing = next(m for m in coo["comparison_matrix"] if m["details_code"] == "DOC_COO_VALUE_NOT_FOUND")
    assert missing["structured_values"] == {"draft_value": {"placeholder": "NOT_EXTRACTED"}}
    assert missing["draft_value"] == "Not extracted"

    insp = service.compare_inspection_cert_service(db, InspectionComparisonRequest(
        import_file_id=import_file.import_file_id, inspection_type="COC", inspection_agency="SGS",
        draft_fields={"inspection_agency": "SGS"},
    ))
    for item in insp["comparison_matrix"]:
        _assert_coded_item(item, ("draft_value",))
    codes = {m["details_code"] for m in insp["comparison_matrix"]}
    assert {"DOC_INSPECTION_OPTIONAL_NOT_INCLUDED", "DOC_INSPECTION_VALUE_NOT_FOUND", "DOC_INSPECTION_MATCH_RATE"} <= codes
    optional = next(m for m in insp["comparison_matrix"] if m["details_code"] == "DOC_INSPECTION_OPTIONAL_NOT_INCLUDED")
    assert optional["structured_values"] == {"draft_value": {"placeholder": "OPTIONAL_NOT_INCLUDED"}}


def test_response_schemas_keep_the_new_keys():
    from modules.import_documentation.schemas import (
        DraftBLChecklistItem, DraftBLDiscrepancyItem, InvoiceBLDiscrepancyMatrixItem, POHeaderDiscrepancyItem,
    )

    for schema, extra in (
        (DraftBLDiscrepancyItem, {"details_code", "details_params", "structured_values"}),
        (POHeaderDiscrepancyItem, {"details_code", "details_params", "structured_values"}),
        (InvoiceBLDiscrepancyMatrixItem, {"details_code", "details_params", "tolerance_code", "tolerance_params",
                                          "structured_values"}),
        (DraftBLChecklistItem, {"reason_code", "reason_params"}),
    ):
        assert extra <= set(schema.model_fields), schema.__name__


# --- customs_category enum ------------------------------------------------------------------------------
@pytest.mark.parametrize("value,expected", [
    ("آلات وأجهزة وتجهيزات", "MACHINERY_EQUIPMENT"),
    ("أصناف عامة", "GENERAL_GOODS"),
    ("General", "GENERAL_GOODS"),
    ("  Electronics ", "ELECTRONICS"),
    ("Raw Materials & Metals", "RAW_MATERIALS_METALS"),
    ("أصناف وتجهيزات البناء من لدائن", "أصناف وتجهيزات البناء من لدائن"),  # unknown free text passes through
    (None, None),
])
def test_customs_category_is_normalized_on_write(value, expected):
    from modules.customs_tariff.schemas import CustomsTariffCreate, CustomsTariffUpdate

    created = CustomsTariffCreate(hs_code="8415.10", hs_description="Air conditioning machines",
                                  customs_category=value, customs_duty_rate=5, vat_rate=14)
    assert created.customs_category == expected
    assert CustomsTariffUpdate(customs_category=value).customs_category == expected


def test_nafeza_parser_emits_customs_category_codes():
    from modules.customs_tariff.nafeza_text_parser import parse_nafeza_tariff_text
    from tests.unit.test_customs_tariff_agreements import RAW_NAFEZA_TEXT_EXAMPLE

    tariff, _ = parse_nafeza_tariff_text(RAW_NAFEZA_TEXT_EXAMPLE)
    assert tariff.customs_category in ("MACHINERY_EQUIPMENT", "GENERAL_GOODS")
    assert enum_codes.label_en(enum_codes.CUSTOMS_CATEGORY, "MACHINERY_EQUIPMENT") == "Machinery, appliances & equipment"
