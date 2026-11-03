import pytest
from fastapi.testclient import TestClient
from main import app
from modules.import_documentation.ai_document_parser import (
    extract_commercial_invoice_data,
    _heuristic_multi_carrier_extractor,
    match_invoice_with_bl,
)

client = TestClient(app)

SHAW_INVOICE_TEXT = """
Commercial Invoice
Shaw Europe Limited
Blackaddie Road, Sanquhar, United Kingdom, DG4 6DB
United Kingdom
VAT Number 428102677
Phone +44 1659 50497

Order Date 24-06-2026
Order Number 35220
Shipment Number 688990
Payment Terms PBS CHK/CR/DBT
Purchase Order RSA-ARCE-Found Ever
Currency USD
Incoterms EXW
Incoterms Location UK
Freight Terms COLLECT

Bill To
ARCHI BRANDS FOR CORPET AND FLOOR TRADING
44 Street 18, Maadi Sarayat, Cairo, C, 11431, Egypt
Tax ID 759552827

Ship To
ARCHI BRANDS FOR CORPET AND FLOOR TRADING
44 Street 18, Maadi Sarayat, Cairo, C, 11431, Egypt

ACID 7595528271019210013
Line Total $85,060.57
VAT Total $0.00
Shipping Total $0.00
Order Total $85,060.57

Line 1: 5T22926100 NOOK TASKWORX HTS Code 5703299100 Square Meter 335 Boxes 67 United Kingdom 13.93 4666.55
Line 2: 5T51904675 FORMATION HTS Code 5703299100 Square Meter 35 Boxes 7 United Kingdom 18.64 652.40
Container: BEAU5851356 Seal: 177345
960 boxes / 31 pallets @ 110cm x 110cm x 106Gross weight 20030kg
Net weight 19410kg
ACID 7595528271019210013
"""

MSC_BL_TEXT = """
MEDITERRANEAN SHIPPING COMPANY S.A.
BILL OF LADING No. MEDURE910647
DRAFT
SCAC Code: MEDU

SHIPPER:
SHAW EUROPE LTD
BUILDING E, BLACKADDIE RD SANQUHAR, DG4 6DB. UNITED KINGDOM

CONSIGNEE:
ARCHI Brands for Corpet and Floor Trading
St.81 with st.18 building 44, 3rd floor, SARAYAT EL MAADI, Cairo- Egypt
VAT No: 759-552-827

NOTIFY PARTIES:
ARCHI Brands for Corpet and Floor Trading
St.81 with st.18 building 44, 3rd floor, SARAYAT EL MAADI, Cairo- Egypt

VESSEL AND VOYAGE NO: MSC GISELLE - NL630A
BOOKING REF. (or) SHIPPER'S REF.
EBKG18064984

PORT OF LOADING: London Gateway Port
PORT OF DISCHARGE: Alexandria El Dekheila, EGYPT

Container Numbers, Seal Numbers and Marks:
BEAU5851356 / 40' HIGH CUBE
Seal Number: 177345
Tare Weight: 3,700 kgs.

Description of Packages and Goods:
31 Pallet(s) 1 X 40' HIGH CUBE CONTAINING 31 PALLETS OF FLOORING
ACID: 7595528271019210013
EGYPTIAN IMPORTER TAX ID: 759552827
SHIPPER REGISTRATION TYPE: VAT NUMBER
SHIPPER ID: GB428102677
SHIPPER COUNTRY: UNITED KINGDOM
SHIPPER COUNTRY CODE: GB

FREIGHT PREPAID
Gross Cargo Weight: 20,030.000 kgs.
Total Items: 31 Total: 20,030.000 kgs.
"""


def test_extract_commercial_invoice_data():
    inv = extract_commercial_invoice_data(SHAW_INVOICE_TEXT)
    assert inv["acid_number"] == "7595528271019210013"
    assert inv["importer_tax_id"] == "759552827"
    assert inv["invoice_number"] == "35220"
    assert inv["invoice_date"] == "24-06-2026"
    assert inv["currency"] == "USD"
    assert inv["total_amount"] == 85060.57
    assert inv["incoterm"] == "EXW"
    assert "Shaw Europe" in inv["shipper"]
    assert "ARCHI BRANDS" in inv["consignee"].upper()
    assert inv["containers"][0]["container_no"] == "BEAU5851356"
    assert inv["containers"][0]["seal_no"] == "177345"
    assert inv["total_gross_weight_kg"] == 20030.0
    assert inv["total_net_weight_kg"] == 19410.0
    assert inv["qty_pallets"] == 31


def test_extract_msc_draft_bl():
    bl = _heuristic_multi_carrier_extractor(MSC_BL_TEXT)
    assert bl["acid_number"] == "7595528271019210013"
    assert bl["importer_tax_id"] == "759552827"
    assert bl["draft_bl_number"] == "MEDURE910647"
    assert bl["booking_no"] == "EBKG18064984"
    assert "MSC GISELLE" in bl["vessel_name"]
    assert bl["voyage_number"] == "NL630A"
    assert "London Gateway" in bl["pol"]
    assert "Alexandria" in bl["pod"]
    assert "SHAW EUROPE" in bl["shipper"].upper()
    assert "ARCHI BRANDS" in bl["consignee"].upper()
    assert bl["containers"][0]["container_no"] == "BEAU5851356"
    assert bl["containers"][0]["seal_no"] == "177345"
    assert bl["total_gross_weight_kg"] == 20030.0
    assert bl["qty_pkg"] == 31


def test_match_invoice_with_bl_perfect():
    inv = extract_commercial_invoice_data(SHAW_INVOICE_TEXT)
    bl = _heuristic_multi_carrier_extractor(MSC_BL_TEXT)
    res = match_invoice_with_bl(inv, bl)

    assert res["overall_status"] in ["FULLY_MATCHED", "ACCEPTED_WITH_WARNINGS"]
    assert res["is_safe_for_certification"] is True
    assert res["critical_discrepancies_count"] == 0
    assert res["match_score_percentage"] >= 85.0
    assert len(res["comparison_matrix"]) == 14

    # Verify ACID Check
    acid_item = next(m for m in res["comparison_matrix"] if m["item_code"] == "CHK_ACID")
    assert acid_item["match_status"] == "MATCH"
    assert acid_item["severity"] == "NONE"

    # Verify Container Check
    cntr_item = next(m for m in res["comparison_matrix"] if m["item_code"] == "CHK_CONTAINERS")
    assert cntr_item["match_status"] == "MATCH"
    assert "BEAU5851356" in cntr_item["invoice_value"]


def test_match_invoice_with_bl_discrepancy_detection():
    inv = extract_commercial_invoice_data(SHAW_INVOICE_TEXT)
    bl = _heuristic_multi_carrier_extractor(MSC_BL_TEXT)

    # Introduce critical discrepancy
    bl["acid_number"] = "9999999999999999999"
    bl["containers"] = [{"container_no": "MEDU9999999", "seal_no": "9999"}]
    bl["total_gross_weight_kg"] = 28000.0

    res = match_invoice_with_bl(inv, bl)
    assert res["overall_status"] == "DISCREPANCY_DETECTED"
    assert res["is_safe_for_certification"] is False
    assert res["critical_discrepancies_count"] >= 2
    assert "Dear" in res["correction_letter"]
    assert "ACID" in res["correction_letter"]


def test_api_extract_and_match():
    response = client.post(
        "/api/v1/import-documentation/invoice-bl/extract-and-match",
        json={
            "invoice_raw_text": SHAW_INVOICE_TEXT,
            "bl_raw_text": MSC_BL_TEXT,
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert data["is_safe_for_certification"] is True
    assert data["match_score_percentage"] >= 85.0
    assert len(data["comparison_matrix"]) == 14


def test_api_extract_and_match_with_packing_list():
    sample_pl_text = """
    PACKING LIST
    Packing List No: PL-2026-8899
    Date: 24-06-2026
    ACID: 7595528271019210013
    Shipper: Shaw Europe Limited
    Consignee: ARCHI BRANDS FOR CORPET AND FLOOR TRADING
    Gross Weight: 20030.00 KGS
    Net Weight: 19410.00 KGS
    Total Packages: 31 Pallets
    Measurement: 45.50 CBM
    Container: BEAU5851356 / Seal: 177345
    """

    response = client.post(
        "/api/v1/import-documentation/invoice-bl/extract-and-match",
        json={
            "invoice_raw_text": SHAW_INVOICE_TEXT,
            "packing_list_raw_text": sample_pl_text,
            "bl_raw_text": MSC_BL_TEXT,
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert data["packing_list_data"] is not None
    assert data["invoice_data"]["total_gross_weight_kg"] == 20030.0
    assert data["invoice_data"]["qty_pkg"] == 31
    assert data["is_safe_for_certification"] is True


