"""
Regression: PO "Smart Extract (PI / PL)" on a G.I. Industrial commercial invoice billed in USD (V1/2539).

Field report: the heuristic PurchaseOrderExtractor returned currency EUR (a EUR amount in the company's legal
header won over the USD total), polluted the item description with the footer header "weight kg Gross weight kg
Volume mc Packages", read "Packages" + the next line's HS code as the package count and parsed the 3-decimal
European weights "820,600" / "848,600" as 820600 / 848600 kg.
"""

import pytest

from modules.smart_document_upload.extractors.purchase_order import PurchaseOrderExtractor

# Text as produced by the spatial PDF extraction of a G.I. invoice (stacked columns, see the V1/3083 fixture in
# test_multi_country_invoice_extraction.py); "Net" of the footer header is wrapped onto its own line.
GI_USD_INVOICE_STACKED = """G.I. INDUSTRIAL HOLDING SPA
Via G. Agnelli, 7 - 33053 Latisana (UD) - Italy
Tel. +39 0431 516111 - www.gind.it - e-mail: info@gind.it
Share capital 5.000.000,00 EUR fully paid - P.IVA IT01982510305
COMMERCIAL INVOICE Date Page Delivery address
V1/ 2539 30/06/2026 1
Client id. no.
801765
V.A.T. ID Number
200183044
Agent
DIRECT SALE
Messers
ECO ASSOCIATES
7 Hosny Osman St, Embassies district
Nasr City, Cairo
Egitto
Payment condition
100% AVV.MERCE PRONTA-PICK UP CONF.
Bank IT80Q0503412301USD100004026
 SWIFT : BAPPIT21682
Shipping - Delivery terms - As per INCOTERMS® 2020
EX WORKS EXTRA UE
Code Description Commodity code Q.ty U.M. Unit price Total price V.A.T
WOPB3D0048S0009
Your order
ECO/53/26REV00
Our order confirmation
768 date 14/04/26
Bolla RO/0/441 del 30/06/2026
WOPB/D 0048 PF/NS
Chilled Water Units with EC Inverter Plug-Fans
COUNTRY OF ORIGIN:ITALY
Net
weight kg Gross weight kg Volume mc Packages
84158200 2,000 NR 7.550,00000 15.100,00 NI
Total goods
15.100,00
Total INVOICE AMOUNT
15.100,00 USD
Net weight kg
820,600
Gross weight kg
848,600
Volume mc Packages
2
"""

# Same invoice laid out as an Italian table (Codice / Descrizione / Q.tà / Prezzo / Importo), EUR only in legal text.
GI_USD_INVOICE_ITALIAN_TABLE = """G.I. INDUSTRIAL HOLDING SPA - Via G. Agnelli 7 - 33053 Latisana (UD) - Italia
Capitale sociale EUR 5.000.000,00 i.v. - Bollo virtuale 2,00 EUR
FATTURA / COMMERCIAL INVOICE N. V1/2539 del 30/06/2026
Cliente / Customer: ECO ASSOCIATES - 7 Hosny Osman St, Embassies district, Nasr City, Cairo, Egypt
VAT ID Number 200183044
Codice cliente 801765
Vs. ordine ECO/53/26REV00 - Ns. conferma 768 del 14/04/26 - Bolla RO/0/441 del 30/06/2026
Resa / Incoterms: EXW EXTRA UE
Pagamento: 100% AVV.MERCE PRONTA-PICK UP CONF.
Codice | Descrizione | Voce doganale | Q.tà | U.M. | Prezzo | Importo
WOPB3D0048S0009 | WOPB/D 0048 PF/NS Chilled Water Units with EC Inverter Plug-Fans | 84158200 | 2,000 | NR | 7.550,00 | 15.100,00
Peso netto kg | Peso lordo kg | Volume mc | Colli
820,600 | 848,600 | | 2
Totale merce 15.100,00
Totale fattura USD 15.100,00
IBAN IT80Q0503412301USD100004026 - SWIFT BAPPIT21682
"""


@pytest.fixture(params=["stacked", "italian_table"])
def extracted(request):
    text = GI_USD_INVOICE_STACKED if request.param == "stacked" else GI_USD_INVOICE_ITALIAN_TABLE
    return PurchaseOrderExtractor().extract(text, {})


def test_header_fields(extracted):
    assert extracted["po_number"] == "V1/2539"
    assert extracted["order_date"] == "2026-06-30"
    assert extracted["supplier_name"] == "G.I. INDUSTRIAL HOLDING SPA"
    assert extracted["importer_name"] == "ECO ASSOCIATES"
    assert extracted["importer_tax_id"] == "200183044"
    assert "7 Hosny Osman St" in extracted["importer_address"]
    assert extracted["incoterms"] == "EXW"
    assert extracted["payment_terms"].startswith("100% AVV.MERCE PRONTA-PICK UP CONF")
    assert extracted["total_amount"] == 15100.0


def test_currency_is_the_currency_of_the_total_not_legal_text_or_extra_ue(extracted):
    assert extracted["currency"] == "USD"


def test_line_item_keeps_printed_hs_and_clean_description(extracted):
    assert len(extracted["items"]) == 1
    item = extracted["items"][0]
    assert item["item_code"] == "WOPB3D0048S0009"
    assert item["hs_code"] == "84158200"  # 8 digits as printed, never padded to a national 10-digit line
    assert extracted["hs_code"] == "84158200"
    assert item["quantity"] == 2.0
    assert item["unit"] == "PCS"
    assert item["unit_price"] == 7550.0
    assert item["total_price"] == 15100.0
    assert item["description"] == "WOPB/D 0048 PF/NS Chilled Water Units with EC Inverter Plug-Fans"
    for noise in ("weight kg", "Gross", "Volume", "Packages", "ECO/53", "Bolla", "768 date"):
        assert noise not in item["description"]


def test_packing_totals_keep_decimals(extracted):
    assert len(extracted["packing_list_items"]) == 1
    pack = extracted["packing_list_items"][0]
    assert pack["qty_pkg"] == 2.0
    assert pack["total_net_weight_kg"] == pytest.approx(820.6)
    assert pack["total_gross_weight_kg"] == pytest.approx(848.6)
    # The dialog shows per-package weights: total / packages, decimals kept (410.30 / 424.30, not 410 / 424).
    assert pack["net_weight_unit_kg"] == pytest.approx(410.3)
    assert pack["gross_weight_unit_kg"] == pytest.approx(424.3)
    assert extracted["total_gross_weight_kg"] == pytest.approx(848.6)
    # Nothing invented when the invoice prints no volume or dimensions.
    assert "total_cbm" not in pack
    assert "length_cm" not in pack


@pytest.mark.parametrize(
    "text, expected",
    [
        ("EX WORKS EXTRA UE\nTotal INVOICE AMOUNT\n15.100,00 USD", "USD"),
        ("Incoterms: EXW EXTRA UE\nTotale fattura USD 15.100,00", "USD"),
        ("Capitale sociale 5.000.000,00 EUR\nTotal goods 15.100,00\n15.100,00 USD", "USD"),
        ("Bank IT80Q0503412301USD100004026\nTotal goods 37.741,00\n37.741,00 EUR", "EUR"),
        ("Unit price (USD) Amount (USD)\nSAY TOTAL USD FORTY-THREE THOUSAND ONLY.", "USD"),
    ],
)
def test_currency_prefers_amount_attached_code(text, expected):
    assert PurchaseOrderExtractor().extract(text, {})["currency"] == expected


def test_three_decimal_european_weights_are_not_thousands():
    text = (
        "Total goods\n420,00\n420,00 EUR\n"
        "Net weight kg\n25,000\nGross weight kg\n37,000\nVolume mc Packages\n1"
    )
    pack = PurchaseOrderExtractor().extract(text, {})["packing_list_items"][0]
    assert pack["total_net_weight_kg"] == pytest.approx(25.0)
    assert pack["total_gross_weight_kg"] == pytest.approx(37.0)
    assert pack["qty_pkg"] == 1.0
