"""
Smart Extract (PI / PL) two-pass extraction and item de-duplication (Trello 78jf8Co7).

A document carrying both the commercial invoice and the packing list repeats every colour code
(YH-652 ...). Line items must come from the invoice only (7, not 7 + 7), enriched with the packing
list's cartons / weights / volume, and the packing list must hold one row per code.
"""
import pytest

from modules.smart_document_upload.extractors.purchase_order import PurchaseOrderExtractor

CODES = ["YH-652", "YH-644", "YH-610", "YH-612", "YH-646", "YH-656", "YH-658"]
QTY = [100, 100, 100, 100, 100, 100, 120]
CTNS = [20, 20, 20, 20, 20, 20, 24]
GW = [1460, 1460, 1460, 1460, 1460, 1460, 1750]
NW = [1400, 1400, 1400, 1400, 1400, 1400, 1680]
CBM = [9.2, 9.2, 9.2, 9.2, 9.2, 9.2, 10.8]

INVOICE_ROWS = "\n".join(f"{c} {k} {q}" for c, k, q in zip(CODES, CTNS, QTY))
PACKING_ROWS = "\n".join(
    f"{c} {k} {q} {g} {n} {v}" for c, k, q, g, n, v in zip(CODES, CTNS, QTY, GW, NW, CBM)
)

YUHENG_PI_PL = f"""SUZHOU YUHENG TEXTILE CO.,LTD
COMMERCIAL INVOICE
INV. NO.: YH20260730-6
Description: PET Acoustic Panels
Unit price 60.70
{INVOICE_ROWS}
TOTAL AMOUNT: USD 43,704.00

PACKING LIST
INV. NO.: YH20260730-6
{PACKING_ROWS}
TOTAL: 144 CTNS 720 PCS 10510 KGS 10080 KGS 66 CBM
"""


@pytest.fixture(scope="module")
def result():
    return PurchaseOrderExtractor().extract(YUHENG_PI_PL, {})


def test_line_items_come_from_the_invoice_only(result):
    items = result["items"]
    assert [i["item_code"] for i in items] == CODES
    assert sum(i["quantity"] for i in items) == 720
    assert round(sum(i["total_price"] for i in items), 2) == 43704.00


def test_line_items_are_enriched_from_the_packing_list(result):
    last = result["items"][-1]
    assert last["item_code"] == "YH-658"
    assert last["qty_pkg"] == 24
    assert last["gross_weight_kg"] == 1750
    assert last["net_weight_kg"] == 1680
    assert last["total_cbm"] == 10.8


def test_packing_list_has_one_row_per_code(result):
    packing = result["packing_list_items"]
    assert [p["item_code"] for p in packing] == CODES
    assert sum(p["qty_pkg"] for p in packing) == 144
    assert sum(p["qty_pcs"] for p in packing) == 720
    assert round(sum(p["total_gross_weight_kg"] for p in packing), 2) == 10510
    assert round(sum(p["total_net_weight_kg"] for p in packing), 2) == 10080
    assert round(sum(p["total_cbm"] for p in packing), 2) == 66


def test_repeated_codes_without_a_packing_heading_are_merged():
    text = f"COMMERCIAL INVOICE\nUnit price 60.70\n{INVOICE_ROWS}\n\n{PACKING_ROWS}\n"
    items = PurchaseOrderExtractor().extract(text, {})["items"]
    assert [i["item_code"] for i in items] == CODES


def test_same_code_with_another_price_or_quantity_is_kept():
    extractor = PurchaseOrderExtractor()
    merged = extractor._reconcile_line_items([
        {"item_code": "A-1", "quantity": 1, "unit_price": 10.0, "total_price": 10.0},
        {"item_code": "A-1", "quantity": 2, "unit_price": 12.0, "total_price": 24.0},
        {"item_code": "B-2", "quantity": 4, "unit_price": 124.0, "total_price": 496.0},
        {"item_code": "B-2", "quantity": 2, "unit_price": 124.0, "total_price": 248.0},
        {"item_code": "ITEM-001", "quantity": 1, "unit_price": 5.0},
        {"item_code": "ITEM-001", "quantity": 1, "unit_price": 5.0},
    ])
    assert len(merged) == 6
