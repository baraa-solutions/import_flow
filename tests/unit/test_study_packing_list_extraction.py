"""
Unit Tests for Empirical Study Packing Lists Extraction:
1. Viccarbe (Spain) - Dual-Tier Spanish Table (Boxes + Palletized Cargo, HS codes, Dimensions)
2. Narbutas (Lithuania) - Multi-Page Hierarchical BOM Table (Assemblies vs Components, Catalog/Samples, ACID/Tax ID)
3. Impact Acoustic (Italy) - Inline Dimensions & Pallets Manifest (ACID, hyphenated VAT, Surcharges)
4. G.I. Industrial (Italy) - Bilingual Mechanical / Dimensional Block mm (Dynamic CBM, No hardcoding)
"""

import pytest
from modules.smart_document_upload.extractors.packing_list import PackingListExtractor
from modules.import_documentation.ai_document_parser import extract_packing_list_data


VICCARBE_SPAIN_TEXT = """
Delivery Address
PACKING Nº 2.026 - E - 2.475 2624
008287
SCAS 
44, Road 81
MAADI SARAYAT
CAIRO - EGYPT
Units Code Description HS. Code Boxes Total Gross Weight Total Net Weight Total Volume Length Width Height
2 RECTRM SET OF TRESTLE OUTDOOR LEGS Finish Black H105 940360 6 87,00 80,00 1,77 107,00 95,00 29,00
Total Boxes Total Gross Weight (kg) Total Net Weight (kg) Total Volume (m3)
August, 28th. 2026 13:39:37 Página : 1
 6 87,00 80,00 1,77 

PALLETIZED CARGO
PO 2475
UNITS LENGHT WIDTH HEIGHT TOTAL VOLUMEN TOTAL WEIGHT
1 124 116 149 2,14 110
TOTAL 1 2,14 110
"""

NARBUTAS_LITHUANIA_TEXT = """
UAB Narbutas 
International
Eitminų g. 3
Vilnius, 12113
LTU
Telephone +370 5 243 1407
Enterprise code 300591314
VAT LT100002632414
Packing slip
Nr. SPS0034141
Load ID LOAD072811
Date 2026-08-07
Sales responsible Vitalij Karpov
Sales agreement ID PRJ-2858
Terms of delivery EXW
Terms of payment Prepayment
Customer Delivery address
Archi Brands for Corpet and Floor 
Trading
Maadi, Street 18, Building 44, Third 
Floor
Cairo 11728
EGY
Enterprise code – ND
VAT - ND
Archibrands
Maadi
Cairo 0000
EGY
9-5
Contact Contact information
Hana Bayoumi +201009688553
Hana Bayoumi h.bayoumi@archi-brands.com
Item number Configuration Item name Delivered Unit Weight netto Weight brutto Volume
Sales order SO6094737 / Quotation SQC082278
Customer requisition Informa REV.8
PSHD041 .PA01.MA03 Mobile table with metal base, W=400, D=500, H=620 MOBI 4.00 Pcs 46.000 51.950 0.086
G2A0913 .PA01.0 Desktop, 500x400x16 4.00 vnt 8.800 10.279 0.031
G3B0079 .MA03.0 Metal base, 450x300, H=604 4.00 vnt 37.200 41.671 0.056
PSHD041 .PA01.MA03 Mobile table with metal base, W=400, D=500, H=620 MOBI 2.00 Pcs 23.000 25.975 0.043
G2A0913 .PA01.0 Desktop, 500x400x16 2.00 vnt 4.400 5.140 0.015
Product Catalogs & Samples 1 Box 8.264 14.996 0.398
Volume 26.059
Weight netto 1,362.314
Weight brutto 1,789.511
Number of packages 142
Number of pallets 13
Acid Number: 7595528271020210010
Products issued by: Lukas Sokolovskis Products received by: 
"""

IMPACT_ACOUSTIC_ITALY_TEXT = """
IMPACT ACOUSTIC S.R.L. - c/o F2A, Via Caldera 21 - 20153 Milan 
Reference No. : ARCE - Acoustic
EXPORTER ID : IT04462890981 Your Customer No. : 6723
ARCHI Brands for Corpet and Floor Trading 
St.81 with st.18 building 44, 3rd floor 
SARAYAT EL MAADI, Cairo- Egypt 
Document No. : IT-DN26-005657
Document Date : 26.08.2026
Contact person: M.SAMY (+2) 01026261319 Delivery date : 10.08.2026
Payment Method : Invoice
Due Date : August 26, 2026 
Person in charge : maivelyn.dimalanta@impactacoustic.com 
VAT No: 759-552-827
ACID Number: 7595528271024210016 
UID-VAT IT : 04462890981

Nr. Item Number Description Qty Net Weight Total Net Weight
1 812.10.24.239.01 Acoustic Panel L: 1820mm W: 2420mm H : 24mm 9 10.50 kg 94.50 kg
2 828.20.00.600.00 Strut Channel, galvanized 2400 x 20 mm galvanized 24 1.00 kg 24.00 kg
3 828.20.10.600.00 Baffle connector galvanized 200 x 28 mm galvanized 16 0.10 kg 1.60 kg
Packing List IT-DN26-005657 Milan, August 27, 2026 
16 831.11.00.000.00 Surcharge for custom size and design 5 - -

2 x PALLET 
250cm x190cm xh 88cm 
Net Weight: 310.0 kg 
Gross Weight: 266.0 kg 
160cm x 120cm x h 25cm - 32kg 
Net Weight: 22.0 kg 
Gross Weight: 32.0 kg 
Total Net Weight: 300.0 kg. 
Total Gross Weight: 342.0 kg.
"""

GI_INDUSTRIAL_ITALY_TEXT = """
NOSTRO ORDINE / OUR ORDER R26 1248
COMMESSA 24/166635
VOSTRO ORDINE / YOUR ORDER ECO/57/26
(TYPE) (NO)
TOTAL GROSS (KG) TOTAL NET (KG)
Pallet nr 1 37 25
TOTAL 1 37,0 25,0
(*) LATO DI CARICO MULETTO / FORKLIFT LOADING SIDE
(**) IMBALLO GABBIA LEGNO / WOODEN CAGE PACKAGE
LISTA DEI COLLI E DEI PESI
ECO ASSOCIATES
STREET 17, SARAYAT AL GHARBEYAH
 CAIRO 
EG Egitto
PACKING AND WEIGHT LIST
DESCRIZIONE DESCRIPTION
IMBALLO / PACKING
DIMENSIONI / DIMENSIONS (mm)
800x800x460
"""


def test_viccarbe_spanish_packing_list_extraction():
    extractor = PackingListExtractor()
    data = extractor.extract(VICCARBE_SPAIN_TEXT, {})

    assert data["packing_list_number"] == "2.026 - E - 2.475 2624"
    assert data["supplier_name"] == "Viccarbe"
    assert data["consignee_name"] == "SCAS"
    assert data["po_number"] == "2475"
    assert data["date"] == "28/08/2026"
    assert data["total_packages"] == 6
    assert data["pallets_count"] == 1
    assert data["total_gross_weight_kg"] == 87.0
    assert data["pallet_gross_weight_kg"] == 110.0
    assert data["total_net_weight_kg"] == 80.0
    assert data["total_cbm"] == 1.77
    assert data["pallet_cbm"] == 2.14

    assert len(data["items"]) == 1
    item = data["items"][0]
    assert item["item_code"] == "RECTRM"
    assert "TRESTLE OUTDOOR LEGS" in item["description"]
    assert item["hs_code"] == "940360"
    assert item["quantity"] == 2.0
    assert item["packages_count"] == 6.0
    assert item["gross_weight_kg"] == 87.0
    assert item["net_weight_kg"] == 80.0
    assert item["calculated_cbm"] == 1.77
    assert item["length_cm"] == 107.0
    assert item["width_cm"] == 95.0
    assert item["height_cm"] == 29.0

    assert len(data["pallets"]) == 1
    pallet = data["pallets"][0]
    assert pallet["units"] == 1.0
    assert pallet["length_cm"] == 124.0
    assert pallet["width_cm"] == 116.0
    assert pallet["height_cm"] == 149.0
    assert pallet["calculated_cbm"] == 2.14
    assert pallet["gross_weight_kg"] == 110.0


def test_narbutas_lithuanian_packing_list_extraction():
    extractor = PackingListExtractor()
    data = extractor.extract(NARBUTAS_LITHUANIA_TEXT, {})

    assert data["packing_list_number"] == "SPS0034141"
    assert data["supplier_name"] == "UAB Narbutas International"
    assert "Archi Brands" in data["consignee_name"]
    assert data["acid_number"] == "7595528271020210010"
    assert data["importer_tax_id"] == "759552827"
    assert data["load_id"] == "LOAD072811"
    assert data["sales_order"] == "SO6094737"
    assert data["terms_of_delivery"] == "EXW"
    assert data["total_packages"] == 142
    assert data["pallets_count"] == 13
    assert data["total_net_weight_kg"] == 1362.314
    assert data["total_gross_weight_kg"] == 1789.511
    assert data["total_cbm"] == 26.059

    # Verify item-level BOM hierarchy
    assert len(data["items"]) == 6
    parent_table = [it for it in data["items"] if it["item_code"] == "PSHD041" and it["quantity"] == 4.0][0]
    assert parent_table["is_parent_assembly"] is True
    assert parent_table["unit"] == "Pcs"
    assert parent_table["net_weight_kg"] == 46.0

    comp_desktop = [it for it in data["items"] if it["item_code"] == "G2A0913" and it["quantity"] == 4.0][0]
    assert comp_desktop["is_parent_assembly"] is False
    assert comp_desktop["unit"] == "vnt"
    assert comp_desktop["net_weight_kg"] == 8.8

    samples = [it for it in data["items"] if it["item_code"] == "SAMPLES"][0]
    assert samples["quantity"] == 1.0
    assert samples["unit"] == "Box"
    assert samples["gross_weight_kg"] == 14.996


def test_impact_acoustic_packing_list_extraction():
    extractor = PackingListExtractor()
    data = extractor.extract(IMPACT_ACOUSTIC_ITALY_TEXT, {})

    assert data["packing_list_number"] == "IT-DN26-005657"
    assert data["supplier_name"] == "IMPACT ACOUSTIC S.R.L."
    assert "Archi Brands" in data["consignee_name"]
    assert data["acid_number"] == "7595528271024210016"
    assert data["importer_tax_id"] == "759552827"
    assert data["date"] == "26/08/2026"
    assert data["total_net_weight_kg"] == 300.0
    assert data["total_gross_weight_kg"] == 342.0
    assert data["pallets_count"] == 2

    assert len(data["items"]) == 4
    panel = data["items"][0]
    assert panel["item_code"] == "812.10.24.239.01"
    assert panel["length_mm"] == 1820.0
    assert panel["width_mm"] == 2420.0
    assert panel["height_mm"] == 24.0
    assert panel["net_weight_kg"] == 94.5

    surcharge = data["items"][3]
    assert surcharge["item_code"] == "831.11.00.000.00"
    assert surcharge["net_weight_kg"] == 0.0

    # Verify Pallet Manifest
    assert len(data["pallets"]) == 2
    p1 = data["pallets"][0]
    assert p1["length_cm"] == 250.0
    assert p1["width_cm"] == 190.0
    assert p1["height_cm"] == 88.0
    assert p1["gross_weight_kg"] == 266.0
    assert p1["net_weight_kg"] == 310.0


def test_gi_industrial_packing_list_extraction():
    extractor = PackingListExtractor()
    data = extractor.extract(GI_INDUSTRIAL_ITALY_TEXT, {})

    assert data["supplier_name"] == "G.I. INDUSTRIAL HOLDING SPA"
    assert data["consignee_name"] == "ECO ASSOCIATES"
    assert "ECO/57/26" in data["order_number"]
    assert data["load_id"] == "24/166635"
    assert data["total_packages"] == 1
    assert data["pallets_count"] == 1
    assert data["total_gross_weight_kg"] == 37.0
    assert data["total_net_weight_kg"] == 25.0
    assert round(data["total_cbm"], 3) == 0.294

    assert len(data["items"]) == 1
    it = data["items"][0]
    assert it["length_mm"] == 800.0
    assert it["width_mm"] == 800.0
    assert it["height_mm"] == 460.0
    assert it["gross_weight_kg"] == 37.0
    assert it["net_weight_kg"] == 25.0
    assert it["package_type"] == "Crate"
    # Verify no legacy hardcoding remains
    assert it["item_code"] != "334441"
    assert "Condenser Unit" not in it["description"]
