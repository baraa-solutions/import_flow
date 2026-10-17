"""
Characterization (golden-master) tests for modules/import_documentation.

These tests lock the CURRENT observable output of the document parser and the
reconciliation / comparison services so that behaviour-preserving refactors can
be verified byte-for-byte. They intentionally also lock known-buggy behaviour
(e.g. inconsistent flags, fabricated defaults); when a bug is fixed on purpose,
regenerate the golden file and review the diff:

    REGEN_IMPORT_DOC_GOLDEN=1 python -m pytest tests/unit/test_import_documentation_characterization.py -q

Inputs avoid multiple HS codes / containers per document because those outputs
are derived from set() iteration and depend on PYTHONHASHSEED.
"""

import json
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Callable, Dict

import pytest
from fastapi import HTTPException

from database.database import SessionLocal
from modules.currencies.model import Currency
from modules.customs_tariff.model import CustomsTariff
from modules.import_companies.model import ImportCompany
from modules.import_documentation.ai_document_parser import (
    extract_agadir_gafta_form_a_coo_text,
    extract_coa_certificate_text,
    extract_commercial_invoice_data,
    extract_packing_list_data,
    extract_psi_certificate_text,
    extract_standard_coo_text,
    match_invoice_with_bl,
    reconcile_po_documents_with_system,
)
from modules.import_documentation.schemas import (
    COOComparisonRequest,
    InspectionComparisonRequest,
    POExtractAndCompareRequest,
)
from modules.import_documentation.service import (
    compare_coo_service,
    compare_inspection_cert_service,
    extract_and_compare_po_documents_service,
)
from modules.import_files.model import ImportFile
from modules.incoterms.model import Incoterm
from modules.projects.model import Project
from modules.purchase_orders.model import PackingListItem, POLineItem, PurchaseOrder
from modules.suppliers.model import Supplier

GOLDEN_PATH = Path(__file__).with_name("import_documentation_characterization_golden.json")
REGEN = os.environ.get("REGEN_IMPORT_DOC_GOLDEN") == "1"

ACID_A = "2001830441013710010"
ACID_B = "7595528271019210013"
ACID_C = "1111111111111111111"


def _jsonable(value: Any) -> Any:
    return json.loads(json.dumps(value, ensure_ascii=False, default=str))


def _load_golden() -> Dict[str, Any]:
    if GOLDEN_PATH.exists():
        return json.loads(GOLDEN_PATH.read_text(encoding="utf-8"))
    return {}


_GOLDEN = _load_golden()


def _check(name: str, actual: Any) -> None:
    actual = _jsonable(actual)
    if REGEN:
        _GOLDEN[name] = actual
        GOLDEN_PATH.write_text(json.dumps(_GOLDEN, ensure_ascii=False, indent=1, sort_keys=False), encoding="utf-8")
        return
    assert name in _GOLDEN, f"missing golden entry {name}; run with REGEN_IMPORT_DOC_GOLDEN=1"
    expected = _GOLDEN[name]
    # Compare serialized form so key ORDER is locked too.
    assert json.dumps(actual, ensure_ascii=False) == json.dumps(expected, ensure_ascii=False), name


# ==============================================================================
# match_invoice_with_bl
# ==============================================================================

INV_FULL = {
    "acid_number": ACID_A,
    "importer_tax_id": "200183044",
    "shipper": "Shaw Europe Limited",
    "consignee": "ARCHI BRANDS FOR CORPET AND FLOOR TRADING",
    "containers": [{"container_no": "BEAU5851356", "seal_no": "177345"}],
    "qty_pkg": 31,
    "total_gross_weight_kg": 20030.0,
    "total_net_weight_kg": 19410.0,
    "incoterm": "EXW",
}
BL_FULL = {
    "acid_number": ACID_A,
    "importer_tax_id": "200183044",
    "shipper": "SHAW EUROPE LIMITED",
    "consignee": "ARCHI BRANDS FOR CORPET AND FLOOR TRADING",
    "containers": [{"container_no": "BEAU5851356", "seal_no": "177345"}],
    "qty_pkg": 31,
    "total_gross_weight_kg": 20030.0,
    "total_net_weight_kg": 19410.0,
    "shipping_line": "MSC",
    "draft_bl_number": "MEDURE910647",
    "booking_no": "BK-1",
}
SYS_FULL = {
    "acid_number": ACID_A,
    "importer_tax_id": "200183044",
    "supplier_name": "Shaw Europe Limited",
    "importer_name": "Archi Brands",
    "containers": [{"container_no": "BEAU5851356", "seal_no": "177345"}],
    "total_packages": 31,
    "total_gross_weight_kg": 20030.0,
    "total_net_weight_kg": 19410.0,
    "incoterms": "EXW",
}
PL_FULL = {
    "acid_number": ACID_A,
    "importer_tax_id": "200183044",
    "supplier_name": "Shaw Europe PL",
    "importer_name": "Archi PL",
    "total_packages": 31,
    "total_gross_weight_kg": 20031.0,
}

MATCH_CASES: Dict[str, Callable[[], Any]] = {
    "all_match_with_pl": lambda: match_invoice_with_bl(INV_FULL, BL_FULL, SYS_FULL, PL_FULL),
    "all_match_no_sys_no_pl": lambda: match_invoice_with_bl(INV_FULL, BL_FULL),
    "identity_mismatch": lambda: match_invoice_with_bl(
        {**INV_FULL, "acid_number": ACID_A, "importer_tax_id": "200183044",
         "shipper": "Totally Different Exporter GmbH", "consignee": "Nile Trading Company"},
        {**BL_FULL, "acid_number": ACID_B, "importer_tax_id": "999888777",
         "shipper": "Shaw Europe Limited", "consignee": "ARCHI BRANDS FOR CORPET AND FLOOR TRADING"},
        SYS_FULL,
        PL_FULL,
    ),
    "identity_extraction_failed": lambda: match_invoice_with_bl({}, {}, SYS_FULL, PL_FULL),
    "identity_extraction_failed_all_empty": lambda: match_invoice_with_bl({}, {}),
    "acid_system_override": lambda: match_invoice_with_bl(INV_FULL, BL_FULL, {**SYS_FULL, "acid_number": ACID_C}),
    "acid_system_equal_but_bl_differs": lambda: match_invoice_with_bl(
        INV_FULL, {**BL_FULL, "acid_number": ACID_B}, SYS_FULL
    ),
    "one_sided_invoice_only": lambda: match_invoice_with_bl(
        {"acid_number": ACID_A, "importer_tax_id": "200183044", "shipper": "Shaw", "consignee": "Archi"},
        {"acid_number": None, "shipper": ""},
        {"acid_number": ACID_A},
        {"shipper": "PL Shipper", "consignee": "PL Consignee"},
    ),
    "one_sided_bl_only_sys_acid": lambda: match_invoice_with_bl(
        {},
        {"acid_number": ACID_A, "importer_tax_id": "200183044", "shipper": "Shaw", "consignee": "Archi"},
        {"acid_number": ACID_C, "shipper": "Sys Shipper", "consignee": "Sys Consignee"},
    ),
    "fallback_keys_supplier_importer": lambda: match_invoice_with_bl(
        {"supplier_name": "Shaw Europe Limited", "importer_name": "Archi Brands Trading"},
        {"shipper": "Shaw Europe Ltd", "consignee": "Archi Brands Trading Co"},
        {"shipper": "Sys Shaw", "consignee": "Sys Archi"},
        {"supplier_name": "PL Shaw", "importer_name": "PL Archi"},
    ),
}


@pytest.mark.parametrize("case", list(MATCH_CASES))
def test_match_invoice_with_bl_golden(case):
    _check(f"match_invoice_with_bl::{case}", MATCH_CASES[case]())


def test_match_invoice_with_bl_identity_states_explicit():
    rows = {r["item_code"]: r for r in match_invoice_with_bl(INV_FULL, BL_FULL, SYS_FULL, PL_FULL)["comparison_matrix"]}
    for code in ("CHK_ACID", "CHK_TAX_ID", "CHK_SHIPPER", "CHK_CONSIGNEE"):
        assert rows[code]["match_status"] == "MATCH"
        assert rows[code]["severity"] == "NONE"
        assert rows[code]["disagreeing_sources"] is None

    failed = {r["item_code"]: r for r in match_invoice_with_bl({}, {})["comparison_matrix"]}
    for code in ("CHK_ACID", "CHK_TAX_ID", "CHK_SHIPPER", "CHK_CONSIGNEE"):
        assert failed[code]["match_status"] == "EXTRACTION_FAILED"
        assert failed[code]["severity"] == "WARNING"
    assert failed["CHK_SHIPPER"]["tolerance"] == "Similarity: 0.0%"

    override = match_invoice_with_bl(INV_FULL, BL_FULL, {"acid_number": ACID_C})
    acid_row = override["comparison_matrix"][0]
    assert acid_row["match_status"] == "MISMATCH_CRITICAL"
    assert acid_row["severity"] == "BLOCKING"
    # Known bug locked on purpose: the system is the disagreeing source, not Invoice/B/L.
    assert acid_row["disagreeing_sources"] == ["Invoice", "B/L"]
    assert override["is_safe_for_certification"] is False


# ==============================================================================
# reconcile_po_documents_with_system
# ==============================================================================

RECON_INV = {
    "invoice_number": "V1/2562",
    "acid_number": ACID_A,
    "importer_tax_id": "200183044",
    "supplier_name": "G.I. INDUSTRIAL HOLDING SPA",
    "importer_name": "ECO ASSOCIATES",
    "hs_code": "84158200",
    "total_amount": 37741.0,
    "currency": "EUR",
    "qty_pkg": 4,
    "total_gross_weight_kg": 2274.0,
    "total_net_weight_kg": 2254.0,
    "items": [
        {"item_code": "CYK4R6018210001", "description": "ROOF TOP", "hs_code": "84158200",
         "quantity": 2.0, "unit_price": 18602.375},
        {"item_code": "QCR12026802R", "description": "RUBBER SHOCK ABSORBERS", "hs_code": "",
         "quantity": 2.0, "unit_price": 268.125},
    ],
}
RECON_PL = {
    "acid_number": ACID_A,
    "order_number": "M26 413",
    "supplier_name": "G.I. INDUSTRIAL",
    "importer_name": "ECO ASSOCIATES",
    "total_packages": 4,
    "total_gross_weight_kg": 2274.0,
    "total_net_weight_kg": 2254.0,
    "total_cbm": 40.3,
    "items": [
        {"item_code": "CYK4R-6018210001", "description": "ROOF TOP", "quantity": 2.0, "packages_count": 2.0,
         "net_weight_kg": 2250.0, "gross_weight_kg": 2270.0, "calculated_cbm": 40.0, "package_type": "Package"},
        {"item_code": "QCR12026802R", "description": "ABSORBERS", "quantity": 1.0, "packages_count": 2.0,
         "net_weight_kg": 4.0, "gross_weight_kg": 4.0, "calculated_cbm": 0.3, "package_type": "Box"},
    ],
}
RECON_SYS_ITEMS = [
    {"po_item_id": 11, "item_code": "CYK4R6018210001", "description": "ROOF TOP", "hs_code": "84158200",
     "initial_quantity": 2.0, "initial_unit_price": 18000.0, "initial_packages_count": 2.0,
     "initial_net_weight_kg": 2250.0, "initial_gross_weight_kg": 2270.0, "initial_cbm": 40.0},
    {"po_item_id": 12, "item_code": "QCR12026802R", "description": "RUBBER SHOCK ABSORBERS",
     "initial_quantity": 2.0, "initial_unit_price": 268.125, "initial_packages_count": 0,
     "initial_net_weight_kg": 4.0, "initial_gross_weight_kg": 4.0, "initial_cbm": 0.3},
]
RECON_SYS_PACKING = [
    {"po_item_id": 21, "item_code": "CYK4R6018210001", "description": "Roof top crate", "hs_code": "84158200",
     "package_type": "Crate", "initial_quantity": 2.0, "initial_packages_count": 2.0,
     "initial_net_weight_kg": 2250.0, "initial_gross_weight_kg": 2270.0, "initial_cbm": 40.0},
    {"packing_item_id": 22, "item_code": "QCR", "qty_pkg": 2, "total_net_weight_kg": 4.0,
     "total_gross_weight_kg": 5.0, "total_cbm": 0.2},
    {"item_code": "EXTRA-ITEM", "initial_packages_count": 1, "initial_gross_weight_kg": 10.0},
]
RECON_META = {
    "final_invoice_number": "V1-2562",
    "packing_list_number": "PL-2562",
    "acid_number": ACID_A,
    "importer_tax_id": "200183044",
    "supplier_name": "G.I. Industrial Holding S.p.A",
    "importer_name": "Eco Associates",
    "hs_code": "8415.82.00",
    "total_amount": 37741.0,
    "currency": "EUR",
    "total_packages": 4,
    "total_gross_weight_kg": 2274.0,
    "total_net_weight_kg": 2254.0,
    "total_cbm": 40.3,
}

RECON_CASES: Dict[str, Callable[[], Any]] = {
    "full_with_packing_items": lambda: reconcile_po_documents_with_system(
        RECON_INV, RECON_PL, RECON_SYS_ITEMS, RECON_META, system_packing_items=RECON_SYS_PACKING
    ),
    "full_without_packing_items": lambda: reconcile_po_documents_with_system(
        RECON_INV, RECON_PL, RECON_SYS_ITEMS, RECON_META
    ),
    "full_empty_packing_list": lambda: reconcile_po_documents_with_system(
        RECON_INV, RECON_PL, RECON_SYS_ITEMS, RECON_META, system_packing_items=[]
    ),
    "header_mismatches": lambda: reconcile_po_documents_with_system(
        {**RECON_INV, "invoice_number": "X-999", "importer_tax_id": "111222333",
         "supplier_name": "Another Supplier LLC", "importer_name": "Nile Company",
         "hs_code": "94013000", "currency": "USD", "total_amount": 50000.0, "acid_number": ACID_B},
        {**RECON_PL, "total_packages": 9, "total_gross_weight_kg": 3000.0, "total_net_weight_kg": 2900.0,
         "total_cbm": 55.0},
        RECON_SYS_ITEMS,
        RECON_META,
        system_packing_items=RECON_SYS_PACKING,
    ),
    "one_sided_system_only": lambda: reconcile_po_documents_with_system({}, {}, RECON_SYS_ITEMS, RECON_META),
    "one_sided_document_only": lambda: reconcile_po_documents_with_system(RECON_INV, RECON_PL, [], {}),
    "nothing": lambda: reconcile_po_documents_with_system({}, {}, [], None),
    "fallback_keys_and_substrings": lambda: reconcile_po_documents_with_system(
        {"shipper_name": "  G.I. Industrial  ", "consignee_name": "ECO", "shipper": "Alt Shipper",
         "buyer": "Buyer Co", "items": [{"item_code": "ZZ-1", "description": "Only item", "hs_code": "8415",
                                          "quantity": 5, "unit_price": 1.0}],
         "invoice_number": "2562"},
        {"shipper": "PL Shipper", "customer_name": "PL Customer", "packing_list_number": "PL-77",
         "items": [{"item_code": "ZZ/1", "hs_code": "8415"}]},
        RECON_SYS_ITEMS,
        {"po_number": "V1/2562", "supplier_name": "GI INDUSTRIAL HOLDING", "importer_name": "Eco Associates",
         "hs_code": "84158200"},
    ),
    "supplier_names_normalize_to_empty": lambda: reconcile_po_documents_with_system(
        {"supplier_name": "---", "importer_name": "...", "hs_code": "12", "invoice_number": "//"},
        {},
        [],
        {"supplier_name": "ACME", "importer_name": "Buyer", "hs_code": "34", "final_invoice_number": "INV-1"},
    ),
}


@pytest.mark.parametrize("case", list(RECON_CASES))
def test_reconcile_po_documents_golden(case):
    _check(f"reconcile_po_documents_with_system::{case}", RECON_CASES[case]())


def test_reconcile_header_rows_explicit():
    res = reconcile_po_documents_with_system({}, {}, [], {"importer_tax_id": None})
    rows = {r["check_code"]: r for r in res["header_discrepancies"]}
    assert [r["check_code"] for r in res["header_discrepancies"]] == [
        "CHK_INVOICE_NO", "CHK_ACID", "CHK_TAX_ID", "CHK_SUPPLIER_NAME", "CHK_IMPORTER_NAME",
        "CHK_HS_CODE", "CHK_TOTAL_AMOUNT", "CHK_PACKAGES", "CHK_GROSS_WEIGHT", "CHK_NET_WEIGHT", "CHK_TOTAL_CBM",
    ]
    # Placeholders are English since single-language storage (company/main 96657fbd).
    assert rows["CHK_TAX_ID"]["system_value"] == "Not set in the system"
    assert rows["CHK_TAX_ID"]["extracted_value"] == "Not found in the document"
    assert rows["CHK_TAX_ID"]["system_invoice_value"] == "Not set in the system"
    assert rows["CHK_SUPPLIER_NAME"]["status"] == "MATCH"
    assert rows["CHK_HS_CODE"]["status"] == "MATCH"

    mism = reconcile_po_documents_with_system(
        {"supplier_name": "Alpha"}, {}, [], {"supplier_name": "Omega"}
    )
    sup = [r for r in mism["header_discrepancies"] if r["check_code"] == "CHK_SUPPLIER_NAME"][0]
    assert sup["status"] == "MINOR_VARIANCE"
    assert mism["overall_status"] == "ACCEPTED_WITH_WARNINGS"


# ==============================================================================
# Commercial invoice / packing list extractors
# ==============================================================================

INVOICE_SOLD_TO = """
Acme Machinery Co., Ltd.
COMMERCIAL INVOICE
Invoice No: INV-7788
SOLD TO: Nile Star Trading Company, Cairo, Egypt
HS CODE: 84158200
ACID 2001830441013710010
TAX ID: 200-183-044
"""

INVOICE_BILL_TO = """
Commercial Invoice
Shaw Europe Limited
Blackaddie Road, Sanquhar, United Kingdom
Bill To
ARCHI BRANDS FOR CORPET AND FLOOR TRADING
44 Street 18, Maadi Sarayat, Cairo, Egypt
Tax ID 759552827
ACID 7595528271019210013
"""

INVOICE_FIRST_LINES_FALLBACK = """
--- PAGE 1 ---
COMMERCIAL INVOICE
Nordic Timber Works
Date 01/02/2026
Messrs
EGYPTIAN WOOD TRADERS
Maadi Cairo
7595528271019210013
"""

INVOICE_COMMERCIAL_EXCLUDED = """
Nordic Timber Works
CUSTOMER COMMERCIAL DEPARTMENT
Messrs: DELTA BUYERS
"""

INVOICE_NO_PARTY = """
123
COMMERCIAL INVOICE
ACID NO 20018304410137100XX
"""

PL_SOLD_TO = """
PACKING LIST
Acme Machinery Co., Ltd.
SOLD TO: Nile Star Trading Company
ACID NUMBER 2001830441013710010
TOTAL GROSS WEIGHT: 1,500.5
NET WEIGHT: 1,400
TOTAL PACKAGES: 12
CBM: 8.5
"""

PL_SHIPPER_LABEL = """
SHIPPER: Baltic Furniture UAB
CONSIGNEE: Delta Import LLC
TAX ID: 200183044
GROSS 250
NET 200
"""

PL_FIRST_LINES_FALLBACK = """
--- PACKING PAGE 1 ---
PACKING LIST
Nordic Timber
Date 01/02/2026
IMPORTER Packing Dept Records
ECO ASSOCIATES TRADING
"""

PL_PACKING_EXCLUDED = """
Nordic Timber
SOLD TO: PACKING DEPARTMENT
"""

EXTRACT_CASES: Dict[str, Callable[[], Any]] = {
    "invoice_sold_to": lambda: extract_commercial_invoice_data(INVOICE_SOLD_TO),
    "invoice_bill_to": lambda: extract_commercial_invoice_data(INVOICE_BILL_TO),
    "invoice_first_lines_fallback": lambda: extract_commercial_invoice_data(INVOICE_FIRST_LINES_FALLBACK),
    "invoice_commercial_excluded": lambda: extract_commercial_invoice_data(INVOICE_COMMERCIAL_EXCLUDED),
    "invoice_no_party": lambda: extract_commercial_invoice_data(INVOICE_NO_PARTY),
    "invoice_empty": lambda: extract_commercial_invoice_data("   "),
    "pl_sold_to": lambda: extract_packing_list_data(PL_SOLD_TO),
    "pl_shipper_label": lambda: extract_packing_list_data(PL_SHIPPER_LABEL),
    "pl_first_lines_fallback": lambda: extract_packing_list_data(PL_FIRST_LINES_FALLBACK),
    "pl_packing_excluded": lambda: extract_packing_list_data(PL_PACKING_EXCLUDED),
    "pl_empty": lambda: extract_packing_list_data(""),
}


@pytest.mark.parametrize("case", list(EXTRACT_CASES))
def test_invoice_and_packing_extractors_golden(case):
    _check(f"extract::{case}", EXTRACT_CASES[case]())


def test_invoice_party_extraction_explicit():
    sold = extract_commercial_invoice_data(INVOICE_SOLD_TO)
    assert sold["consignee"] == "Nile Star Trading Company"
    assert sold["hs_code"] == "84158200"
    bill = extract_commercial_invoice_data(INVOICE_BILL_TO)
    assert bill["importer_name"] == "ARCHI BRANDS FOR CORPET AND FLOOR TRADING"


# ==============================================================================
# Preferential COO / PSI / COA / standard COO extractors
# ==============================================================================

AGADIR_LABELLED = """
AGADIR AGREEMENT CERTIFICATE OF ORIGIN
Certificate No: AGD/2026/0042
Exporter: Casablanca Ceramics SARL
Consignee: Nile Tiles Company
ACID: 2001830441013710010
HS Code: 690721
Invoice No. INV-AG-77
Origin: TUNISIA
Gross weight 12,500.5 KGS
"""

GAFTA_BARE_ACID = """
منطقة التجارة الحرة العربية الكبرى
Cert. No. GFT-9
Exporter: Amman Foods Co.
7595528271019210013 shipment
البند الجمركي 190590
رقم الفاتورة: JO-123
الأردن
"""

FORM_A_NO_ACID = """
FORM A GSP
Exporter: Dhaka Textiles Ltd
Tariff No. 6109
UAE transit
weight 55 KG
"""

PREF_DEFAULTS = """
Some unrelated preferential document
"""

PSI_LABELLED = """
BUREAU VERITAS PSI Report No: BV-PSI-889
Importer: Delta Import LLC
Exporter: Baltic Furniture UAB
ACI CODE: 2001830441013710010
Commercial Invoice No. CI-4455
Date of Inspection: 12/03/2026
Place of Inspection: Klaipeda Warehouse
Inspector Name: J. Smith
Quantity Inspected: 44
Result: PASSED
Seal No: SL-001
Seal: SL-002
"""

PSI_FAILED_BARE_ACID = """
COTECNA Inspection Report No. CT-1
DRAFT
Shipment 7595528271019210013
Result: REJECTED
"""

PSI_DEFAULTS = """
TUV inspection memo
"""

COA_LABELLED = """
Laboratory: Eurofins Lab Milano
COA No. COA-2026-15
Product Name: Acoustic Panel Resin
Batch No: B-778
Date of Analysis: 05/04/2026
ACID: 2001830441013710010
Invoice No: INV-COA-1
Result: within spec
"""

COA_OUT_OF_SPEC_BARE = """
Test Report # TR-9
7595528271019210013
OUT OF SPEC viscosity
"""

STD_COO_LABELLED = """
CERTIFICATE OF ORIGIN
Certificate No: CO 2026 5566
Exporter: Baltic Furniture UAB
Consignee: Delta Import LLC
ACID - 2001830441013710010
H.S. Code: 940360
Invoice No. BF-2026-01
"""

STD_COO_BARE = """
Certificate of origin
Exporter: Some Exporter Ltd
ref 7595528271019210013
"""

CERT_CASES: Dict[str, Callable[[], Any]] = {
    "agadir_labelled": lambda: extract_agadir_gafta_form_a_coo_text(AGADIR_LABELLED),
    "gafta_bare_acid": lambda: extract_agadir_gafta_form_a_coo_text(GAFTA_BARE_ACID),
    "form_a_no_acid": lambda: extract_agadir_gafta_form_a_coo_text(FORM_A_NO_ACID),
    "pref_defaults": lambda: extract_agadir_gafta_form_a_coo_text(PREF_DEFAULTS, agreement_type="CUSTOM"),
    "pref_empty": lambda: extract_agadir_gafta_form_a_coo_text(""),
    "psi_labelled": lambda: extract_psi_certificate_text(PSI_LABELLED),
    "psi_failed_bare_acid": lambda: extract_psi_certificate_text(PSI_FAILED_BARE_ACID),
    "psi_defaults": lambda: extract_psi_certificate_text(PSI_DEFAULTS),
    "psi_empty": lambda: extract_psi_certificate_text(""),
    "coa_labelled": lambda: extract_coa_certificate_text(COA_LABELLED),
    "coa_out_of_spec_bare": lambda: extract_coa_certificate_text(COA_OUT_OF_SPEC_BARE),
    "coa_empty": lambda: extract_coa_certificate_text(""),
    "std_coo_labelled": lambda: extract_standard_coo_text(STD_COO_LABELLED),
    "std_coo_bare": lambda: extract_standard_coo_text(STD_COO_BARE),
    "std_coo_empty": lambda: extract_standard_coo_text(""),
}


@pytest.mark.parametrize("case", list(CERT_CASES))
def test_certificate_extractors_golden(case):
    _check(f"cert::{case}", CERT_CASES[case]())


def test_certificate_acid_extraction_explicit():
    assert extract_agadir_gafta_form_a_coo_text(AGADIR_LABELLED)["acid_number"] == ACID_A
    assert extract_agadir_gafta_form_a_coo_text(GAFTA_BARE_ACID)["acid_number"] == ACID_B
    assert extract_agadir_gafta_form_a_coo_text(FORM_A_NO_ACID)["acid_number"] == ""
    assert extract_psi_certificate_text(PSI_LABELLED)["acid_number"] == ACID_A
    assert extract_psi_certificate_text(PSI_FAILED_BARE_ACID)["acid_number"] == ACID_B
    assert extract_coa_certificate_text(COA_LABELLED)["acid_number"] == ACID_A
    assert extract_coa_certificate_text(COA_OUT_OF_SPEC_BARE)["acid_number"] == ACID_B
    assert extract_standard_coo_text(STD_COO_LABELLED)["acid_number"] == ACID_A
    assert extract_standard_coo_text(STD_COO_BARE)["acid_number"] == ACID_B


# ==============================================================================
# DB-backed services (COO / inspection comparison, PO extract & compare)
# ==============================================================================

TAG = "CHARIDOC"


@pytest.fixture
def db_session():
    session = SessionLocal()
    yield session
    session.close()


def _get_or_create(db, model, lookup: Dict[str, Any], **extra):
    obj = db.query(model).filter_by(**lookup).first()
    if not obj:
        obj = model(**lookup, **extra)
        db.add(obj)
        db.commit()
        db.refresh(obj)
    return obj


@pytest.fixture
def char_world(db_session):
    """Creates deterministic master data + import files owned by this test module."""
    db = db_session
    now = datetime.now(timezone.utc)
    company = _get_or_create(
        db, ImportCompany, {"importer_id": f"{TAG}-IMP-1"},
        importer_name="ECO ASSOCIATES", importer_id_expiry=now + timedelta(days=365),
        vat_id=f"{TAG}-VAT-200183044", vat_id_expiry=now + timedelta(days=365),
        registration_number=f"{TAG}-REG-1", registration_expiry=now + timedelta(days=365),
        address="7 Hosni Osman St, Cairo", country="Egypt", is_active=True,
    )
    supplier = _get_or_create(
        db, Supplier, {"supplier_code": f"{TAG}-SUP-1"},
        company_name="G.I. INDUSTRIAL HOLDING SPA", supplier_type="Manufacturer", registration_type="Factory",
        foreign_exporter_id=f"{TAG}-EXP-1", foreign_exporter_country="Italy", foreign_exporter_country_code="IT",
        address="Via G. Agnelli 7, Latisana", is_active=True,
    )
    incoterm = db.query(Incoterm).first() or _get_or_create(
        db, Incoterm, {"incoterm_code": "EXW"}, incoterm_name="Ex Works", is_active=True
    )
    project = _get_or_create(
        db, Project, {"project_code": f"{TAG}-PRJ-1"},
        project_name="Characterization", project_owner="QA", company_id=company.company_id,
        supplier_id=supplier.supplier_id, incoterm_id=incoterm.incoterm_id, is_active=True,
    )
    currency = db.query(Currency).filter(Currency.currency_code == "EUR").first()
    if not currency:
        currency = Currency(currency_code="EUR", currency_name="Euro", currency_symbol="€", is_active=True)
        db.add(currency)
        db.commit()
    tariff = _get_or_create(db, CustomsTariff, {"hs_code": "84158200"}, hs_description="Air conditioning", is_active=True)

    def make_file(code: str, **kw) -> ImportFile:
        f = db.query(ImportFile).filter(ImportFile.import_file_code == code).first()
        if f:
            return f
        f = ImportFile(
            import_file_code=code, company_id=company.company_id, company_name="ECO ASSOCIATES (file)",
            supplier_id=supplier.supplier_id, supplier_name="GI file supplier", is_active=True, **kw,
        )
        db.add(f)
        db.commit()
        db.refresh(f)
        return f

    # File 1: PO linked by import_file_id, first line item has a tariff.
    f1 = make_file(f"{TAG}-F1", acid_number=ACID_A, po_number=f"{TAG}-PO-1", pi_number="PI-889")
    po1 = db.query(PurchaseOrder).filter(PurchaseOrder.po_number == f"{TAG}-PO-1").first()
    if not po1:
        po1 = PurchaseOrder(
            po_number=f"{TAG}-PO-1", proforma_invoice_number="V1/2562", import_file_id=f1.import_file_id,
            project_id=project.project_id, company_id=company.company_id, supplier_id=supplier.supplier_id,
            incoterm_id=incoterm.incoterm_id, currency_id=currency.currency_id, total_amount_fob=37741.0,
            total_packages_count=4, total_gross_weight_kg=2274.0, total_net_weight_kg=2254.0, total_cbm=40.3,
        )
        db.add(po1)
        db.commit()
        db.add_all([
            POLineItem(po_id=po1.po_id, item_code="CYK4R6018210001", description_ar="وحدة تكييف",
                       tariff_id=tariff.tariff_id, quantity=2, unit_price=18000.0, total_price=36000.0,
                       net_weight_kg=1.0, gross_weight_kg=1.0, total_cbm=0.1),
            POLineItem(po_id=po1.po_id, item_code="QCR12026802R", description_ar="ممتص صدمات",
                       description_en="Rubber absorbers", quantity=2, unit_price=268.125, total_price=536.25,
                       net_weight_kg=3.5, gross_weight_kg=4.5, total_cbm=0.25),
            PackingListItem(po_id=po1.po_id, hs_code="84158200", item_code="cyk4r6018210001 ",
                            description="Roof top package", qty_pcs=2, qty_pkg=2, package_type="Package",
                            total_net_weight_kg=2250.0, total_gross_weight_kg=2270.0, total_cbm=40.0),
            PackingListItem(po_id=po1.po_id, hs_code="40169300", item_code="QCR-PL", description=None,
                            qty_pcs=1, qty_pkg=2, package_type=None,
                            total_net_weight_kg=4.0, total_gross_weight_kg=4.0, total_cbm=0.3),
        ])
        db.commit()

    # File 2: PO found only through ImportFile.po_number; first line item has no tariff.
    f2 = make_file(f"{TAG}-F2", acid_number=ACID_B, po_number=f"{TAG}-PO-2")
    po2 = db.query(PurchaseOrder).filter(PurchaseOrder.po_number == f"{TAG}-PO-2").first()
    if not po2:
        po2 = PurchaseOrder(
            po_number=f"{TAG}-PO-2", import_file_id=None,
            project_id=project.project_id, company_id=company.company_id, supplier_id=supplier.supplier_id,
            incoterm_id=incoterm.incoterm_id, currency_id=currency.currency_id, total_amount_fob=0,
            total_packages_count=0, total_gross_weight_kg=0, total_net_weight_kg=0, total_cbm=0,
        )
        db.add(po2)
        db.commit()
        db.add_all([
            POLineItem(po_id=po2.po_id, item_code="ZX-1", description_ar="صنف", quantity=3, unit_price=10.0,
                       total_price=30.0),
            PackingListItem(po_id=po2.po_id, hs_code="94036000", item_code="ZX-1", description="Desk",
                            qty_pcs=3, qty_pkg=1, package_type="Pallet",
                            total_net_weight_kg=90.0, total_gross_weight_kg=100.0, total_cbm=1.2),
        ])
        db.commit()

    # File 3: no PO at all.
    f3 = make_file(f"{TAG}-F3", estimated_cost=1234.5, estimated_cost_currency="GBP")

    ids = {"files": {f1.import_file_id: "<F1>", f2.import_file_id: "<F2>", f3.import_file_id: "<F3>"}}
    ids["lines"] = {li.item_id: f"<LINE:{li.item_code}>" for po in (po1, po2) for li in po.line_items}
    ids["packs"] = {pi.packing_item_id: f"<PACK:{pi.item_code}>" for po in (po1, po2) for pi in po.packing_list_items}
    return {"db": db, "f1": f1, "f2": f2, "f3": f3, "ids": ids}


def _normalize_po_response(resp, ids) -> Dict[str, Any]:
    data = _jsonable(resp.model_dump())
    if data.get("import_file_id") in ids["files"]:
        data["import_file_id"] = ids["files"][data["import_file_id"]]
    for row in data["reconciled_invoice_items"]:
        row["po_item_id"] = ids["lines"].get(row["po_item_id"], row["po_item_id"])
    for row in data["reconciled_packing_items"]:
        row["po_item_id"] = ids["packs"].get(row["po_item_id"], row["po_item_id"])
    return data


INV_RAW = """
G.I. INDUSTRIAL HOLDING SPA
COMMERCIAL INVOICE Date 30/06/2026 Page 1
V1/ 2562
Messrs
ECO ASSOCIATES
CYK4R6018210001 ROOF TOP 84158200 2,000 NR 18.602,37500 37.204,75 NI
ACID NR. 2001830441013710010
IMPORTER TAX ID: 200183044
TOTAL INVOICE AMOUNT 37.741,00 EUR
Net weight kg 2.254,000
Gross weight kg 2.274,000
Packages 4
"""

PL_RAW = """
PACKING AND WEIGHT LIST
ECO ASSOCIATES
ACID NUMBER 2001830441013710010
RTAXT/K/EC/MS 182 IM/RFM/RFL/PF/NS 2 3950 2250 2250 2250 2270 2 PACKAGE
KG / COLLI 2254,0 2274,0 4,0 TOTAL
"""


def _po_cases(w) -> Dict[str, Callable[[], Any]]:
    db = w["db"]
    return {
        "file_po_by_file_id": lambda: extract_and_compare_po_documents_service(db, POExtractAndCompareRequest(
            import_file_id=w["f1"].import_file_id, invoice_raw_text=INV_RAW, packing_list_raw_text=PL_RAW,
        )),
        "file_po_by_file_id_with_request_system_items": lambda: extract_and_compare_po_documents_service(
            db, POExtractAndCompareRequest(
                import_file_id=w["f1"].import_file_id, invoice_raw_text=INV_RAW,
                invoice_data={"invoice_number": "OVERRIDE-1", "items": []},
                system_items=[{"po_item_id": 9001, "item_code": "CYK4R6018210001", "initial_quantity": 2,
                               "initial_unit_price": 18000.0}],
                system_packing_items=[{"po_item_id": "IGNORED", "item_code": "IGNORED"}],
            )),
        "file_po_by_po_number": lambda: extract_and_compare_po_documents_service(db, POExtractAndCompareRequest(
            import_file_id=w["f2"].import_file_id, invoice_data={"supplier_name": "GI", "items": []},
        )),
        "file_without_po": lambda: extract_and_compare_po_documents_service(db, POExtractAndCompareRequest(
            import_file_id=w["f3"].import_file_id, invoice_raw_text=INV_RAW,
        )),
        "unknown_file": lambda: extract_and_compare_po_documents_service(db, POExtractAndCompareRequest(
            import_file_id=987654321, invoice_raw_text=INV_RAW, packing_list_raw_text=PL_RAW,
        )),
        "no_file": lambda: extract_and_compare_po_documents_service(db, POExtractAndCompareRequest(
            invoice_raw_text=INV_RAW, packing_list_raw_text=PL_RAW,
        )),
    }


PO_CASE_NAMES = [
    "file_po_by_file_id",
    "file_po_by_file_id_with_request_system_items",
    "file_po_by_po_number",
    "file_without_po",
    "unknown_file",
    "no_file",
]


@pytest.mark.parametrize("case", PO_CASE_NAMES)
def test_extract_and_compare_po_documents_golden(char_world, case):
    resp = _po_cases(char_world)[case]()
    _check(f"extract_and_compare_po::{case}", _normalize_po_response(resp, char_world["ids"]))


def test_extract_and_compare_po_documents_db_resolution_explicit(char_world):
    resp = extract_and_compare_po_documents_service(char_world["db"], POExtractAndCompareRequest(
        import_file_id=char_world["f1"].import_file_id, invoice_raw_text=INV_RAW, packing_list_raw_text=PL_RAW,
    ))
    rows = {r.check_code: r.model_dump() for r in resp.header_discrepancies}
    assert rows["CHK_SUPPLIER_NAME"]["system_value"] == "G.I. INDUSTRIAL HOLDING SPA"
    assert rows["CHK_IMPORTER_NAME"]["system_value"] == "ECO ASSOCIATES"
    assert rows["CHK_HS_CODE"]["system_value"] == "84158200"
    assert rows["CHK_TAX_ID"]["system_value"] == f"{TAG}-VAT-200183044"
    assert [p.item_code for p in resp.reconciled_packing_items] == ["cyk4r6018210001 ", "QCR-PL"]
    # A PO line with no packing-list row has no package type (null, never invented; PR #151).
    assert [i.package_type for i in resp.reconciled_invoice_items] == ["Package", None]


def _normalize_cmp(result: Dict[str, Any], ids) -> Dict[str, Any]:
    data = _jsonable(result)
    data["import_file_id"] = ids["files"].get(data["import_file_id"], data["import_file_id"])
    data["system_snapshot_data"].pop("invoice_date", None)
    return data


COO_DRAFTS = {
    "empty": {},
    "partial": {"exporter_name": "G.I. Industrial Holding SpA", "country_of_origin": "European Union",
                "importer_name": "   "},
    "full_mismatch": {"exporter_reg_id": "IT999", "exporter_name": "Other Exporter", "country_of_origin": "China",
                      "importer_name": "Other Importer", "destination_country": "Egypt",
                      "invoice_number": "PI-889", "certificate_type": "Form A"},
}


@pytest.mark.parametrize("draft", list(COO_DRAFTS))
def test_compare_coo_service_golden(char_world, draft):
    res = compare_coo_service(char_world["db"], COOComparisonRequest(
        import_file_id=char_world["f1"].import_file_id, certificate_type="EUR.1", draft_fields=COO_DRAFTS[draft],
    ))
    _check(f"compare_coo::{draft}", _normalize_cmp(res, char_world["ids"]))


def test_compare_coo_service_extraction_failed_rows_explicit(char_world):
    res = compare_coo_service(char_world["db"], COOComparisonRequest(
        import_file_id=char_world["f1"].import_file_id, draft_fields={},
    ))
    rows = {r["field_key"]: r for r in res["comparison_matrix"]}
    assert rows["exporter_name"]["match_status"] == "EXTRACTION_FAILED"
    assert rows["exporter_name"]["severity"] == "BLOCKING"
    assert rows["exporter_name"]["draft_value"] == "Not extracted"
    assert rows["certificate_type"]["severity"] == "WARNING"
    assert rows["exporter_reg_id"]["match_status"] == "MATCH"
    assert res["status"] == "Correction Requested"


INSP_DRAFTS = {
    "empty": {},
    "partial": {"inspection_agency": "SGS", "importer_name": "ECO ASSOCIATES", "acid_number": ACID_A,
                "invoice_number": "PI-889", "standard_specification": "ES 7321"},
}


@pytest.mark.parametrize("draft", list(INSP_DRAFTS))
def test_compare_inspection_cert_service_golden(char_world, draft):
    res = compare_inspection_cert_service(char_world["db"], InspectionComparisonRequest(
        import_file_id=char_world["f1"].import_file_id, draft_fields=INSP_DRAFTS[draft],
    ))
    _check(f"compare_inspection::{draft}", _normalize_cmp(res, char_world["ids"]))


def test_compare_services_missing_file_raises(db_session):
    with pytest.raises(HTTPException) as e1:
        compare_coo_service(db_session, COOComparisonRequest(import_file_id=987654321))
    assert e1.value.status_code == 404
    with pytest.raises(HTTPException) as e2:
        compare_inspection_cert_service(db_session, InspectionComparisonRequest(import_file_id=987654321))
    assert e2.value.status_code == 404
