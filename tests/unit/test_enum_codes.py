"""
Tier-3 enum codes: legacy label -> code normalization (single-language storage, Phase A).
"""
import json
import re

import pytest

from modules.common import enum_codes as ec

ALL_LEGACY = [(t, label, code) for t, m in ec.legacy_labels().items() for label, code in m.items()]
ALL_CODES = [(t, code) for t in ec.ENUM_TYPES for code in ec.codes(t)]


@pytest.mark.parametrize("enum_type,label,code", ALL_LEGACY)
def test_every_legacy_label_maps_to_its_code(enum_type, label, code):
    assert ec.normalize(enum_type, label) == code
    assert ec.normalize(enum_type, f"  {label}  ") == code


@pytest.mark.parametrize("enum_type,code", ALL_CODES)
def test_codes_are_idempotent_and_have_english_labels(enum_type, code):
    assert re.fullmatch(r"[A-Z0-9_]+", code)
    assert ec.normalize(enum_type, code) == code
    assert ec.normalize(enum_type, code.lower()) == code
    label = ec.label_en(enum_type, code)
    assert label and not re.search(r"[؀-ۿ]", label)
    assert ec.normalize(enum_type, label) == code  # English label maps back


@pytest.mark.parametrize(
    "enum_type,value,expected",
    [
        (ec.RELEASE_TYPE, "نهائي وبات (Final Green Release)", "FINAL_GREEN"),
        (ec.PAYMENT_METHOD, "Sadad / E-Finance", "SADAD_EFINANCE"),
        (ec.PAYMENT_METHOD, "Bank Transfer / تحويل بنكي", "BANK_TRANSFER"),
        (ec.DUTY_BANK, "البنك الأهلي المصري (NBE)", "NBE"),
        (ec.DUTY_BANK, "cib", "CIB"),
        (ec.CLEARANCE_EXPENSE_CATEGORY, "Customs Broker Fees (أتعاب التخليص الجمركي)", "BROKER_FEES"),
        (ec.TRUCK_TYPE, "Flatbed Trailer (تريلا مسطح)", "FLATBED"),
        (ec.REGULATORY_BODY, "مصلحة الكيمياء المصرية (Chemistry Dept)", "CHEMISTRY_DEPT"),
        (ec.REGULATORY_BODY, "Food Safety Authority", "NFSA"),
        (ec.CLEARANCE_QUOTE_SERVICE_CATEGORY, "Clearance Fee", "CLEARANCE_FEE"),
        (ec.CLEARANCE_QUOTE_SERVICE_CATEGORY, "مصاريف الفحص والعرض", "INSPECTION_FEE"),
        (ec.BROKER_EXPENSE_CATEGORY, "Clearance Fees (أتعاب ومصاريف تخليص)", "CLEARANCE_FEES"),
        (ec.BROKER_EXPENSE_CATEGORY, "Port & Handling", "PORT_HANDLING"),
        (ec.PRICING_UNIT, "Per Invoice (لكل فاتورة)", "PER_INVOICE"),
        (ec.PRICING_UNIT, "Per Ton (لكل طن إضافي)", "PER_EXTRA_TON"),
        (ec.PRICING_UNIT, "per_truck", "PER_TRUCK"),
        (ec.PRICING_UNIT, "Per Container 40ft", "PER_CONTAINER_40FT"),
        (ec.EMPTY_CONTAINER_DEPOT, "Dekheila Yard (ساحة حاويات الدخيلة)", "DEKHEILA_YARD"),
        (ec.SKIP_REASON_CATEGORY, "Other / أخرى", "OTHER"),
        (ec.HOLD_REASON, "تعليق إداري مؤقت للشحنة", "ADMIN_HOLD"),
        (ec.HOLD_REASON, "Awaiting bank Form 4 issuance", "AWAITING_BANK_FORM4"),
        (ec.STAGE, "Customs Released (تم الإفراج الجمركي النهائي وبدء النقل)", "CUSTOMS_RELEASED"),
        (ec.INSPECTION_YARD, "ساحة الفحص المشترك - ميناء الإسكندرية (رصيف 42)", "ALEXANDRIA_BERTH_42"),
        (ec.INSPECTION_YARD, "قرية البضائع - مطار القاهرة الدولي", "CAIRO_AIRPORT_CARGO"),
        (ec.INSPECTION_YARD, "adabiya", "ADABIYA"),
    ],
)
def test_known_mappings(enum_type, value, expected):
    assert ec.normalize(enum_type, value) == expected


@pytest.mark.parametrize("value", ["Banque Misr - Corporate Branch", "SET", "مستودع خاص بالعميل", "Something new"])
def test_unknown_values_pass_through_unchanged(value):
    for enum_type in ec.ENUM_TYPES:
        assert ec.normalize(enum_type, value) == value, enum_type


def test_non_strings_and_blanks_pass_through():
    assert ec.normalize(ec.TRUCK_TYPE, None) is None
    assert ec.normalize(ec.TRUCK_TYPE, "") == ""
    assert ec.normalize(ec.TRUCK_TYPE, 5) == 5
    with pytest.raises(KeyError):
        ec.normalize("NOT_A_TYPE", "x")


def test_normalize_list_dedupes_and_keeps_unknowns():
    values = ["الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)", "GOEIC", "Custom body", "الحجر البيطري"]
    assert ec.normalize_list(ec.REGULATORY_BODY, values) == ["GOEIC", "Custom body", "VETERINARY_QUARANTINE"]
    assert ec.normalize_list(ec.REGULATORY_BODY, None) is None
    assert ec.normalize_list(ec.REGULATORY_BODY, []) == []


def test_legacy_values_cover_old_rows():
    values = ec.legacy_values(ec.CLEARANCE_QUOTE_SERVICE_CATEGORY, "CLEARANCE_FEE")
    assert values[0] == "CLEARANCE_FEE"
    assert {"Clearance Fee", "أتعاب التخليص الجمركي", "Clearance Agency Fee"} <= set(values)


@pytest.mark.parametrize(
    "value,expected",
    [("جنيه", "EGP"), ("ج.م", "EGP"), ("egp", "EGP"), ("usd", "USD"), ("EUR", "EUR"), ("Euro", "Euro"), (None, None), ("", "")],
)
def test_normalize_currency(value, expected):
    assert ec.normalize_currency(value) == expected


@pytest.mark.parametrize(
    "value,expected",
    [
        ("STEP_08_BL", (None, "STEP_08_BL")),
        ("STEP-08", (None, "STEP_08")),
        ("PHASE-4: STEP_11", (4, "STEP_11")),
        ("PHASE-1: STEP_02-TAX", (1, "STEP_02")),
        ("PHASE-3-INS", (3, None)),
        ("PHASE_5", (5, None)),
        ("مرحلة", (None, None)),
        (None, (None, None)),
    ],
)
def test_parse_stage_reference(value, expected):
    assert ec.parse_stage_reference(value) == expected


def _aggregate_bucket(category: str) -> tuple:
    """Same substring rules as customs_clearance get_clearance_invoices_by_file_service."""
    c = category.lower()
    return (
        any(k in c for k in ["broker", "أتعاب", "تخليص", "clearance"]),
        any(k in c for k in ["port", "نولون", "wharfage", "storage", "أرضيات", "موانئ"]),
        any(k in c for k in ["handling", "stevedoring", "عتالة", "تفريغ", "حمالة"]),
    )


@pytest.mark.parametrize("label,code", list(ec.legacy_labels()[ec.CLEARANCE_EXPENSE_CATEGORY].items()))
def test_expense_category_codes_keep_the_aggregate_buckets(label, code):
    assert _aggregate_bucket(code) == _aggregate_bucket(label)

# ─── docs/enum_codes.json (Flutter contract) ──────────────────────────────────

def test_enum_contract_file_matches_module():
    on_disk = json.loads(ec.CONTRACT_PATH.read_text(encoding="utf-8"))
    assert on_disk == ec.build_contract(), "run: python -m modules.common.enum_codes"
    assert set(on_disk) == set(ec.ENUM_TYPES)
    for enum_type, entry in on_disk.items():
        assert set(entry) == {"codes", "legacy"}
        assert set(entry["legacy"].values()) <= set(entry["codes"]), enum_type


@pytest.mark.parametrize(
    "label,code",
    [
        ("Per Shipment (لكل إقرار)", "PER_SHIPMENT"),
        ("Fixed Amount", "FIXED"),
        ("Fixed (مبلغ ثابت)", "FIXED"),
        ("Per Case (لكل عرض)", "PER_CASE"),
        ("Per Sample (لكل عينة)", "PER_SAMPLE"),
        ("Per Trailer (لكل تريلا)", "PER_TRAILER"),
        ("Per Container (لكل حاوية إضافية)", "PER_CONTAINER"),
    ],
)
def test_seed_and_extractor_unit_labels(label, code):
    assert ec.normalize(ec.PRICING_UNIT, label) == code
    assert ec.build_contract()[ec.PRICING_UNIT]["legacy"][label] == code


def test_every_seed_and_extractor_label_is_in_the_legacy_map():
    """Unit/category labels written by seeds and the broker quotation extractor are all in the legacy map."""
    from pathlib import Path
    root = Path(__file__).resolve().parents[2]
    sources = [root / "seed_clearance_expenses.py", root / "database" / "master_data_sync_service.py",
               root / "modules" / "smart_document_upload" / "extractors" / "customs_broker_quotation.py"]
    unit_re = re.compile(r"""["'](Per [A-Za-z/ 0-9]+ \([^"')]+\)|Fixed \([^"')]+\))["']""")
    cat_re = re.compile(
        r"""["']((?:Clearance Fees|Procedures & Approvals|Inland Transport|Port & Handling|Other Fees) \([^"')]+\))["']"""
    )
    contract = ec.build_contract()
    seen = 0
    for src in sources:
        text = src.read_text(encoding="utf-8-sig")
        for label in unit_re.findall(text):
            seen += 1
            assert label in contract[ec.PRICING_UNIT]["legacy"], label
        for label in cat_re.findall(text):
            seen += 1
            assert label in contract[ec.BROKER_EXPENSE_CATEGORY]["legacy"], label
    assert seen > 20


def test_label_ar_and_legacy_text():
    assert ec.label_ar(ec.CLEARANCE_EXPENSE_CATEGORY, "BROKER_FEES") == "أتعاب التخليص الجمركي"
    assert ec.label_ar(ec.DUTY_BANK, "NBE") == "البنك الأهلي المصري"
    assert ec.label_ar(ec.PAYMENT_METHOD, "BANK_TRANSFER") == "تحويل بنكي"
    assert ec.label_ar(ec.PAYMENT_METHOD, "SADAD_EFINANCE") == "E-Finance / Sadad"  # no Arabic legacy -> English
    assert ec.label_ar(ec.DUTY_BANK, "free text") == "free text" and ec.label_ar(ec.DUTY_BANK, None) is None
    legacy = "Port Dues & Wharfage (نولون ورسوم الميناء والرصيف)"
    for value in ("PORT_DUES_WHARFAGE", "Port Dues & Wharfage", legacy):
        assert ec.legacy_text(ec.CLEARANCE_EXPENSE_CATEGORY, value) == legacy
    assert ec.legacy_text(ec.CLEARANCE_EXPENSE_CATEGORY, "Freight invoice") == "Freight invoice"
    assert ec.legacy_text(ec.CLEARANCE_EXPENSE_CATEGORY, None) == ""
