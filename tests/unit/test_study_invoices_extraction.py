import pytest
from modules.smart_document_upload.extractors.commercial_invoice import CommercialInvoiceExtractor
from modules.import_documentation.ai_document_parser import extract_commercial_invoice_data

GI_COMMERCIAL_INVOICE_TEXT = """
G.I. INDUSTRIAL HOLDING SPA Vis G. Agnelli, 7 - 33053 Latisana (UD) - Italy
Tel. +39 0432 823011 - Fax +39 0432 773855 - www.gind.it - e-mail: info@gind.it
C.F. 02410240242 - P.IVA IT01982510305 - R.I. 148459/97 (UD)
AEE IT18080000010638 - REA 201884 CCIAA (UD) - MECC. UD 023904

COMMERCIAL INVOICE Date Page
V1/ 3083 31/07/2026 1

Client id. no. V.A.T. ID Number
801765 200183044
Phone Fax
0020 22 6779167 0020 22 6779074
Agent
DIRECT SALE
Area manager

Payment condition
100% AVV.MERCE PRONTA-PICK UP CONF.
Bank IT86J0310402002000000820442
SWIFT : DEUTITM1793
Shipping - Delivery terms - As per INCOTERMS 2020
EX WORKS EXTRA UE

Delivery address
ECO ASSOCIATES
STREET 17, SARAYAT AL GHARBEYAH
CAIRO
Egitto

Messers
ECO ASSOCIATES
7 HOSNI OSMAN ST., SEFARAT DISTRICT
11471 NASR CITY, CAIRO
Egitto

Mail
m.scarello@ecoasso.com

Code Description Commodity code Q.ty U.M. Unit price Total price V.A.T
Your order ECO/57/26
Our order confirmation R26 1248 date 10/06/26
Bolla RI/0/ 1837 Del 31/07/2026
324080 AXIAL FAN FN080-SDA.6N.V7P5 84145925 1,000 NR 400,00000 400,00 NI
Commessa 24/166635
COUNTRY OF ORIGIN:GERMANY

333660 DOUBLE-LEVEL TERMINAL BLOCK PTTBS 2,5 85369010 20,000 NR 1,00000 20,00 NI
Commessa 24/166635
COUNTRY OF ORIGIN:CHINA

RIVIGNANO TEOR, 31/07/2026
CRISTIANO RUMIEL
ADMINISTRATION MANAGER

V.A.T. exemption code Amount V.A.T. amount
NI 420,00 N.I.ART.8 1 A/B DPR 633
OPERAZIONE NON SOGGETTA

Total goods 420,00
Advanced payments
Total 420,00
Complementary services
Total V.A.T.
Payment discount
Total INVOICE AMOUNT 420,00 EUR

Due date Amounts Due date Amounts
31/07/26 420,00

Net weight kg Gross weight kg Volume mc Packages
25,000 37,000 1
"""

GI_PROFORMA_INVOICE_TEXT = """
G.I. INDUSTRIAL HOLDING SPA Vis G. Agnelli, 7 - 33053 Latisana (UD) - Italy
Tel. +39 0432 823011 - Fax +39 0432 773855 - www.gind.it - e-mail: info@gind.it
C.F. 02410240242 - P.IVA IT01982510305 - R.I. 148459/97 (UD)
AEE IT18080000010638 - REA 201884 CCIAA (UD) - MECC. UD 023904

PROFORMA INVOICE Date Page
P / 19730 08/04/2026 1

Client id. no. V.A.T. ID Number
801765 200183044
Phone Fax
0020 22 6779167 0020 22 6779074
Agent
DIRECT SALE
Area manager

Payment condition
100% AT ORDER
Bank IT86J0310402002000000820442
SWIFT : DEUTITM1793
Shipping - Delivery terms - As per INCOTERMS 2020
EX WORKS EXTRA UE

Delivery address
ECO ASSOCIATES
STREET 17, SARAYAT AL GHARBEYAH
CAIRO
Egitto

Messers
ECO ASSOCIATES
7 HOSNI OSMAN ST., SEFARAT DISTRICT
11471 NASR CITY, CAIRO
Egitto

Mail
m.scarello@ecoasso.com

Code Description Commodity code Q.ty U.M. Unit price Total price V.A.T
Your order EFS/16/2026/REV0
Our order confirmation R26 717 date 8/04/26
334441 BATT COND 3/8" 4200X1770X3R PA2.1 44A DX T.RIG. 84195080 1,000 NR 4.609,00000 4.609,00 NI
DIS.221220/01 REV.00
Commessa 24/166332
BANK DETAILS EURO ACCOUNT
BANCO BPM S.p.A.
IBAN: IT30Z050341230100000005586
SWIFT: BAPPIT22
Country of Origin: ITALY

Total goods 4.609,00
Total 4.609,00
Total INVOICE AMOUNT 4.609,00 EUR

Due date Amounts
8/04/26 4.609,00
"""

VICCARBE_INVOICE_TEXT = """
viccarbe
Code EORI ESB96783907
invoice: 2.026 / AE / 4.537 2635

SCAS
44, Road 81
- MAADI SARAYAT CAIRO -
EGYPT
TEL.(+202) 27 50 9416

customer NUMBER.: 008287
SCAS
VAT N.: EG430008287
44, Road 81
- MAADI SARAYAT CAIRO -
EGYPT
TEL.(+202) 27 50 9416

The responsible for the delivery of waste packaging or container used for proper environmental management, will be the final holder.
'THE EXPORTER OF THE PRODUCTS COVERED BY THIS DOCUMENT DECLARES THAT, EXCEPT WHERE OTHERWISE CLEARLY INDICATED, THESE PRODUCTS ARE OF SPAIN/CEE PREFERENTIAL ORIGIN'

customer reference:
Showroom-PF 2025

date
28- 08- 2026

transport company
SUS MEDIOS / EXW VALENCIA

incoterm
EXWORK

total weight
110,000 Kg.

volume
2,14

total boxes (1 pallet)
6

reference description units public pricet discount % total
RECTRM SET OF TRESTLE OUTDOOR LEGS 2,00 25,00 100,00
Finish Black Black
H105Finish
H105
HS CODE 940390

WITHOUT COMMERCIAL VALUE
ONLY STATISTICAL VALUE FOR CUSTOM PURPOSES: 100,00

total net 1 total net 2 total net 3 total amount
total eur.
100,00
iva 0% 0,00
re

terms of payment: Sin Cargo
agent: VICCARBE
bank details:
IBAN: , SWIFT:
Tipo Pedido: Recla. Serie
CALLE RACON 23 POL. IND. NORTE BENIPARRELL 46460 VALENCIA (ESPANA)
Viccarbe Habitat, S.L.
CIF: B96783907
"""

NARBUTAS_INVOICE_TEXT = """
OUR BANK INFORMATION
Bank account number
LT957044060008321570
AB SEB Bankas EUR
CBVILT2XXXX
Bank address:
Konstitucijos pr. 24 Vilnius 08105 LTU

BANK DETAILS FOR USD PAYMENTS
Bank account number
8960563579
Routing No.: 231372691
Santander Bank, N.A. USD
SVRNUS33
Bank address:
601 Penn Street Reading PA 19601 USA

INVOICE
Nr. IN053328
Packing slip SPS0034141
Load ID LOAD072811
Date 2026-08-07
Sales responsible Vitalij Karpov
Delivery terms EXW
Terms of payment Prepayment
Country of origin Lithuania

Customer
Archi Brands for Corpet and Floor Trading
Maadi, Street 18, Building 44, Third Floor Cairo 11728 EGY
Enterprise code - ND
VAT - ND

Delivery address
Archibrands
Maadi Cairo 0000 EGY
9-5

Contact information
Hana Bayoumi +201009688553
Hana Bayoumi h.bayoumi@archi-brands.com

Item number Configuration Item name Quantity Unit Sales price Amount VAT
Sales order SO6094737 / Quotation Q086860
Customer requisition Informa REV.8
PSHD041 .PA01.MA03 Mobile table with metal base, W=400, D=500, H=620 MOBI 4.00 Pcs 124.00 496.00 0.00 %
PSHD041 .PA01.MA03 Mobile table with metal base, W=400, D=500, H=620 MOBI 2.00 Pcs 124.00 248.00 0.00 %
PCOM080 .PA01.MA03 Meeting table (3 seats), Ø 800, H=740 FSC Mix 70% * FORUM 2.00 Pcs 235.50 471.00 0.00 %
PDNA124-U .PA01.MA03 Desk, 1200x600, H=740 FSC Mix 70% * NOVA U 1.00 Pcs 86.50 86.50 0.00 %
G6F0443 .MA03.F.EU.0 Telescopic frame with adjustable electric legs for 1200-1600 mm desktops , W=1002-1402, D=600/630*, H=680-1150 B-ACTIVE 1.00 Pcs 187.00 187.00 0.00 %
G2A0B30 .PA01.0 Desktop, 1600x700, H=25 FSC Mix 70% * ACTIVE, B-ACTIVE, Q-ACTIVE desktops 1.00 Pcs 35.00 35.00 0.00 %
PN2607380 .PA01.MA03 Table FORUM COM080, Ø800, H=740 mm, with an 80 mm diameter cutout only in the center; a hole in the base for cable management FORUM 2.00 Pcs 279.00 558.00 0.00 %
PN2607381 .PA01.MA03 Table OPTIMA CZM200, only 2000x1000, H=720 mm (with casters) OPTIMA 1.00 Pcs 140.00 140.00 0.00 %
G5A0342 .GA02.MA01.0.0 Conference chair. Powder coated wire steel frame. Stackable (up to 5 chairs)., W=515, D=575, H=865, SH=480 MOON 6.00 Pcs 80.50 483.00 0.00 %
G5A0324 .GA02.GA02.TA09.1.0 Armchair. Steel framework. Entirely moulded in cold-cure polyurethane. Base: swivelling, height adjustable, 5-star black plastic with 65 mm castors., W=735, D=735, H=700 - 830, SH=370 - 500 TWIST&SIT 22.00 Pcs 189.00 4,158.00 0.00 %
G5A0324 .GA02.GA02.TA09.1.0 Armchair. Steel framework. Entirely moulded in cold-cure polyurethane. Base: swivelling, height adjustable, 5-star black plastic with 65 mm castors., W=735, D=735, H=700 - 830, SH=370 - 500 TWIST&SIT 10.00 Pcs 189.00 1,890.00 0.00 %
G5A0297 .GA02.GA02.MA01.NB01.0.0 High chair. For 1050 mm height desks. Steel framework. Entirely moulded in cold-cure polyurethane. Base: solid ash wood with painted metal footring and glides., W=510, D=505, H=945, SH=735 TWIST&SIT 6.00 Pcs 213.50 1,281.00 0.00 %
G5A0114 .GA01.TC02.MA03.0.0 Conference chair. Plastic shell can be with or without upholstered seat cushion. Powder-coated steel 4-leg frame on glides. , W=560, D=550, H=785, SH=440 POLYTONE 4.00 Pcs 73.50 294.00 0.00 %
G5A0114 .GA02.TC00.MA03.0.0 Conference chair. Plastic shell can be with or without upholstered seat cushion. Powder-coated steel 4-leg frame on glides. , W=560, D=550, H=785, SH=440 POLYTONE 8.00 Pcs 73.50 588.00 0.00 %
PSDM003 .GQ10.MA01.0 Three-seater sofa. Base: powder-coated metal legs with glides. , W=2250, D=850, H=790, SH=430 MYAMI 1.00 Pcs 956.00 956.00 0.00 %
G4A0326 .GA09.GA09.0 Screen without desktop fittings, 824x36, H=1320 MY SPACE 8.00 Pcs 70.50 564.00 0.00 %
G3P0024 .MA03.0 Metal leg "O", 30x30, H=69 MY SPACE 4.00 Pcs 6.50 26.00 0.00 %
G3P0025 .MA03.0 Metal leg "L" (90°) and top joint, 98x98, H=70 MY SPACE 8.00 Pcs 13.00 104.00 0.00 %
G4A0330 .GA09.GA09.0 Screen without desktop fittings, 1624x36, H=1320 MY SPACE 4.00 Pcs 136.50 546.00 0.00 %
PSGA103 .GA06.GA06 Pouf with backrest (800x200, H=250). Base - black painted rectangular metal tube/frame., 800x600, H=650 JAZZ CHILL OUT 8.00 Pcs 241.00 1,928.00 0.00 %
G3P0028 .MA03.0 Metal leg "I" and top joint, 150x30, H=70 MY SPACE 4.00 Pcs 13.00 52.00 0.00 %
G4A0331 .GA09.GA09.MA02.0 Screen with desktop fittings for one side, 824x36, H=1320 MY SPACE 2.00 Pcs 76.00 152.00 0.00 %
PAST120 .PA18.MA03 Table with one leg and metal frame., 1200x700, H=720 MY SPACE 2.00 Pcs 66.00 132.00 0.00 %
Product Catalogs & Samples 1 Box 0 0 0.00 %

Total of sales order SO6094737 / Quotation Q086860 15,375.50 EUR
Amount excl. sales tax 15,375.50 EUR
Discount 0.00 EUR
Taxable amount 0.00 % VAT 15,375.50 EUR
0.00 % VAT (Article 146 of Directive 2006/112/EC) 0.00 EUR
Invoice amount 15,375.50 EUR
Payment amount 15,375.50 EUR
Amount in words: Fifteen thousand three hundred and seventy and five euro and 50 cents
Payment schedule: Pay up to 2026-08-07, Payment amount 15,375.50 EUR
Logistics manager Karolis Zajančkauskas
Volume 26.059
Weight netto 1,362.314
Weight brutto 1,789.511
Number of packages 142
Number of pallets 13
Acid Number: 7595528271020210010

Products marked with * are certified as FSC Mix 70%. NARBUTAS INTERNATIONAL chain of custody code is PBN-COC-065291.
"""


def test_gi_commercial_invoice_extraction():
    extractor = CommercialInvoiceExtractor()
    data = extractor.extract(GI_COMMERCIAL_INVOICE_TEXT, {})

    assert data["invoice_number"] in ["V1/ 3083", "V1/3083"]
    assert data["invoice_date"] == "31/07/2026"
    assert data["importer_tax_id"] == "200183044"
    assert "IT01982510305" in (data["exporter_registration_no"] or "")
    assert "G.I. INDUSTRIAL" in data["supplier_name"].upper()
    assert "ECO ASSOCIATES" in data["importer_name"].upper()
    assert data["incoterms"] == "EXW"
    assert data["currency"] == "EUR"
    assert data["invoice_value"] == 420.0
    assert data["total_net_weight_kg"] == 25.0
    assert data["total_gross_weight_kg"] == 37.0
    assert data["items_count"] == 2

    it1, it2 = data["items"][0], data["items"][1]
    assert it1["item_code"] == "324080"
    assert "AXIAL FAN" in it1["description"].upper()
    assert it1["hs_code"] == "84145925"
    assert it1["quantity"] == 1.0
    assert it1["unit_price"] == 400.0
    assert it1["total_price"] == 400.0
    assert it1.get("country_of_origin") == "GERMANY"

    assert it2["item_code"] == "333660"
    assert "TERMINAL BLOCK" in it2["description"].upper()
    assert it2["hs_code"] == "85369010"
    assert it2["quantity"] == 20.0
    assert it2["unit_price"] == 1.0
    assert it2["total_price"] == 20.0
    assert it2.get("country_of_origin") == "CHINA"


def test_gi_proforma_invoice_extraction():
    extractor = CommercialInvoiceExtractor()
    data = extractor.extract(GI_PROFORMA_INVOICE_TEXT, {})

    assert data["invoice_number"] in ["P / 19730", "P/19730"]
    assert data["invoice_date"] == "08/04/2026"
    assert data["importer_tax_id"] == "200183044"
    assert "G.I. INDUSTRIAL" in data["supplier_name"].upper()
    assert "ECO ASSOCIATES" in data["importer_name"].upper()
    assert data["incoterms"] == "EXW"
    assert data["currency"] == "EUR"
    assert data["invoice_value"] == 4609.0
    assert data["items_count"] == 1

    it = data["items"][0]
    assert it["item_code"] == "334441"
    assert "BATT COND" in it["description"].upper()
    assert it["hs_code"] == "84195080"
    assert it["quantity"] == 1.0
    assert it["unit_price"] == 4609.0
    assert it["total_price"] == 4609.0
    assert it.get("country_of_origin") == "ITALY"


def test_viccarbe_invoice_extraction():
    extractor = CommercialInvoiceExtractor()
    data = extractor.extract(VICCARBE_INVOICE_TEXT, {})

    assert "2.026" in data["invoice_number"]
    assert "4.537" in data["invoice_number"]
    assert data["invoice_date"] in ["28-08-2026", "28- 08- 2026", "28/08/2026"]
    assert "VICCARBE" in data["supplier_name"].upper()
    assert "SCAS" in data["importer_name"].upper()
    assert data["importer_tax_id"] == "430008287"
    assert "ESB96783907" in (data["exporter_registration_no"] or "") or "B96783907" in (data["exporter_registration_no"] or "")
    assert data["incoterms"] == "EXW"
    assert data["currency"] == "EUR"
    assert data["invoice_value"] == 100.0
    assert data["total_gross_weight_kg"] == 110.0
    assert data.get("volume_cbm") == 2.14
    assert data.get("packages_count") == 6
    assert data.get("is_preferential_origin") is True
    assert data.get("is_free_of_charge") is True
    assert data["items_count"] == 1

    it = data["items"][0]
    assert it["item_code"] == "RECTRM"
    assert "TRESTLE OUTDOOR LEGS" in it["description"].upper()
    assert it["hs_code"] == "940390"
    assert it["quantity"] == 2.0
    assert it["total_price"] == 100.0


def test_narbutas_commercial_invoice_extraction():
    extractor = CommercialInvoiceExtractor()
    data = extractor.extract(NARBUTAS_INVOICE_TEXT, {})

    assert data["invoice_number"] == "IN053328"
    assert data["invoice_date"] == "2026-08-07"
    assert data["acid_number"] == "7595528271020210010"
    assert "NARBUTAS" in data["supplier_name"].upper()
    assert "ARCHI BRANDS" in data["importer_name"].upper()
    assert data["incoterms"] == "EXW"
    assert data["currency"] == "EUR"
    assert data["invoice_value"] == 15375.50
    assert data["total_net_weight_kg"] == 1362.314
    assert data["total_gross_weight_kg"] == 1789.511
    assert data.get("volume_cbm") == 26.059
    assert data.get("packages_count") == 142
    assert data.get("pallets_count") == 13
    assert data["items_count"] >= 23

    first_item = data["items"][0]
    assert first_item["item_code"] == "PSHD041"
    assert first_item["quantity"] == 4.0
    assert first_item["unit_price"] == 124.0
    assert first_item["total_price"] == 496.0


SHAW_PROFORMA_INVOICE_TEXT = """
'Shaw Contract is a trading name of Shaw Europe Ltd Company reg No SC009331' "This transaction is subject to our standard Terms & Conditions for the Sale of Goods, a copy of which is available at www.shawinc.com"
"Compliance With Laws. Buyer shall comply with all U.S. and applicable foreign laws and regulations, including, but not limited to, U.S. Sanctions, Anti Boycott, Anti-Bribery/Foreign Corrupt Practices Act, Export Controls 
and Anti Money Laundering laws and regulations, and all foreign equivalents. Buyer shall not export or reexport a Product in violation of any such applicable laws and regulations." "The exporter of the products covered by 
this document (GB428102677000) declares that, except where otherwise clearly indicated, these products are of UK preferential origin***. EXPORTER: SHAW EUROPE LIMITED PLACE : SANQUHAR DATE: 1/3/2024"
Shaw Europe Limited
Blackaddie Road
Sanquhar, United Kingdom, DG4 6DB
United Kingdom
VAT Number 428102677
Phone +44 1659 50497
Proforma Invoice
Order Date 21-08-2026
Invoice Number 43877
Payment Terms PBS CHK/CR/DBT
Purchase Order Mashreq Bank HQ + 
McDonald's project
Currency USD
Incoterms EXW
Incoterms Location UK
Freight Terms COLLECT
              
Bill To
ARCHI BRANDS FOR CORPET AND FLOOR 
TRADING
ARCHI BRANDS FOR CORPET AND FLOOR TRADING
44 Street 18
Maadi Sarayat
Cairo, C, 11431
Egypt
DUNS Number  
Tax ID  759552827
 
Ship To
ARCHI BRANDS FOR CORPET AND FLOOR 
TRADING
ARCHI BRANDS FOR CORPET AND FLOOR 
TRADING
44 Street 18
Maadi Sarayat
Cairo, C, 11431
Egypt
Remit To
Bank Name Bank of America, N.A.
Sort Code 165050
BIC Code BOFAGB22
Account Number 82720022
IBAN GB97BOFA16505082720022
Line Total $75,982.46
VAT Total $0.00
Shipping Total $87.74
Invoice Total $76,070.20
Line Item Item Description Primary UOM Primary Quantity Secondary UOM Secondary Quantity Unit Price VAT Rate VAT Amount Amount
1 C000W26100 GRAPH TW 
CUSH50X50COTSWOLD
Square Meter 3308 Boxes 827 19.45 0% 0.00 64,340.60
2 C039W04210 FRAGME CLR CW50BRUSHED 
GOLD                  
Square Meter 96 Boxes 24 26.33 0% 0.00 2,527.68
3 C019W53535 FRAGMENT 
COMF50X50LIMESTONE
Square Meter 96 Boxes 24 26.33 0% 0.00 2,527.68
4 C037W04111 FORMATI CL CW50OATMEAL Square Meter 244 Boxes 61 26.33 0% 0.00 6,424.52
7 EUR1 EUR1 Each 1 80.99 0% 0.00 80.99
8 COO COO Each 1 80.99 0% 0.00 80.99
9 Freight Freight - Finished Goods Each 1 87.74 0% 0.00 87.74
"""


def test_shawcontract_proforma_invoice_extraction():
    extractor = CommercialInvoiceExtractor()
    data = extractor.extract(SHAW_PROFORMA_INVOICE_TEXT, {})

    assert data["invoice_number"] == "43877"
    assert data["invoice_date"] == "21-08-2026"
    assert data["importer_tax_id"] == "759552827"
    assert "GB428102677000" in (data["exporter_registration_no"] or "") or "428102677" in (data["exporter_registration_no"] or "")
    assert "SHAW EUROPE" in data["supplier_name"].upper()
    assert "ARCHI BRANDS" in data["importer_name"].upper()
    assert data["incoterms"] == "EXW"
    assert data["currency"] == "USD"
    assert data["invoice_value"] == 76070.20
    assert data["subtotal"] == 75982.46
    assert data["freight_amount"] == 87.74
    assert data["packages_count"] == 936
    assert data.get("is_preferential_origin") is True
    assert data.get("preferential_origin_agreement") == "UK-Egypt Trade Agreement"
    assert data["items_count"] == 7

    # Check tile items
    it1 = data["items"][0]
    assert it1["item_code"] == "C000W26100"
    assert "GRAPH TW" in it1["description"]
    assert it1["quantity"] == 3308.0
    assert it1["unit"] == "Square Meter"
    assert it1["secondary_quantity"] == 827.0
    assert it1["secondary_unit"] == "Boxes"
    assert it1["unit_price"] == 19.45
    assert it1["total_price"] == 64340.60

    # Check ancillary line items
    it5 = data["items"][4]
    assert it5["item_code"] == "EUR1"
    assert it5["quantity"] == 1.0
    assert it5["unit_price"] == 80.99
    assert it5["total_price"] == 80.99

    it7 = data["items"][6]
    assert it7["item_code"] == "Freight"
    assert "Freight" in it7["description"]
    assert it7["quantity"] == 1.0
    assert it7["unit_price"] == 87.74
    assert it7["total_price"] == 87.74


SHAW_COMMERCIAL_INVOICE_TEXT = """
1/2
"'Shaw Contract is a trading name of Shaw Europe Ltd Company reg No SC009331' "This transaction is subject to our standard Terms & Conditions for the Sale of Goods, a copy of which is available at www.shawinc.
com" "Compliance With Laws. Buyer shall comply with all U.S. and applicable foreign laws and regulations, including, but not limited to, U.S. Sanctions, Anti Boycott, Anti-Bribery/Foreign Corrupt Practices Act, Export 
Controls and Anti Money Laundering laws and regulations, and all foreign equivalents. Buyer shall not export or reexport a Product in violation of any such applicable laws and regulations." "The exporter of the products 
covered by this document (GB428102677000) declares that, except where otherwise clearly indicated, these products are of UK preferential origin***. EXPORTER: SHAW EUROPE LIMITED PLACE : SANQUHAR 
DATE: 1/3/2024""
Commercial Invoice
 
Shaw Europe Limited
Blackaddie Road
Sanquhar, United Kingdom, DG4 6DB
United Kingdom
VAT Number 428102677
Phone +44 1659 50497
Order Date 21-08-2026
Order Number 43877
Shipment Number 877998
Payment Terms PBS CHK/CR/DBT
Purchase Order Mashreq Bank HQ
Currency USD
Incoterms EXW
Incoterms Location UK
Freight Terms COLLECT
Bill To
ARCHI BRANDS FOR CORPET AND FLOOR 
TRADING
44 Street 18
Maadi Sarayat
Cairo, C, 11431
Egypt
DUNS Number 
Tax ID 759552827
Ship To
ARCHI BRANDS FOR CORPET AND 
FLOOR TRADING
44 Street 18
Maadi Sarayat
Cairo, C, 11431
Egypt
Remit To
Bank Name Bank of America, N.A.
Sort Code 165050
BIC Code BOFAGB22
Account 
Number
82720022
IBAN GB97BOFA16505082720022
Line Total $76,070.20
VAT Total $0.00
Shipping Total $0.00
Order Total $76,070.20
ACID : 7595528271023610018

2/2
Line Item Item Description HTS Code Primary 
UOM
Primary 
Quantity
Secondary 
UOM
Secondary 
Quantity
Country Of 
Origin
Unit 
Price
VAT 
Rate
VAT 
Amount
Amount
3 C019W53535 FRAGMENT COMF 50X50
LIMESTONE
2 C039W04210 FRAGME CLR CW 50
BRUSHED GOLD 
5703299100
5703299100
5703299100
5703299100
1 C000W26100 GRAPH TW CUSH 50X50 Square Meter 3308 Boxes 827 19.45 0% 0.00 64,340.60
COTSWOLD
Square Meter 96 Boxes 24 26.33 0% 0.00 2,527.68
Square Meter 96 Boxes 24 26.33 0% 0.00 2,527.68
United
Kingdom
United
Kingdom
United
Kingdom
United
Kingdom
Container N - MSNU7490569
Seal N - 107539
GW - 17,649kg
NW - 16,889kg
936 + 4 boxes of samples (free of Charge)
38 pallets
21 pallets @ 110 x 107 x 132 cm
11 pallets @ 110 x 107 x 74 cm
5 pallets @ 110 x 107 x 59 cm
1 pallet @ 110 x 107 x 160 cm
4 C037W04111 FORMATI CL CW50 Square Meter 244 Boxes 61 26.33 0% 0.00 6,424.52
 OATMEAL
5 Sample Folders sku: SMP
3 panels and 4 panels
folder combo
type: Free sample carpet tile
catalogs for non commercial use
6 EUR1 EUR1 Each 1 80.99 0% 0.00 80.99
7 COO COO Each 1 80.99 0% 0.00 80.99
8 Freight Freight - Finished Goods Each 1 87.74 0% 0.00 87.74
Each 17 Boxes 4 United 0.00 0% 0.00 0.00 
Kingdom
ACID : 7595528271023610018
"""


def test_shawcontract_final_commercial_invoice_extraction():
    extractor = CommercialInvoiceExtractor()
    data = extractor.extract(SHAW_COMMERCIAL_INVOICE_TEXT, {})

    assert data["invoice_number"] == "43877"
    assert data["invoice_date"] == "21-08-2026"
    assert data["acid_number"] == "7595528271023610018"
    assert data["importer_tax_id"] == "759552827"
    assert "GB428102677000" in (data["exporter_registration_no"] or "") or "428102677" in (data["exporter_registration_no"] or "")
    assert "SHAW EUROPE" in data["supplier_name"].upper()
    assert "ARCHI BRANDS" in data["importer_name"].upper()
    assert data["origin_country"] == "United Kingdom"
    assert data["incoterms"] == "EXW"
    assert data["currency"] == "USD"
    assert data["invoice_value"] == 76070.20
    assert data["total_gross_weight_kg"] == 17649.0
    assert data["total_net_weight_kg"] == 16889.0
    assert data["packages_count"] == 940
    assert data["pallets_count"] == 38
    assert data["container_number"] == "MSNU7490569"
    assert data["seal_number"] == "107539"
    assert data["shipment_number"] == "877998"
    assert data["purchase_order"] == "Mashreq Bank HQ"
    assert data["hs_code"] == "5703299100"
    assert data.get("is_preferential_origin") is True
    assert data.get("preferential_origin_agreement") == "UK-Egypt Trade Agreement"
    assert data.get("is_free_of_charge") is True
    assert data["items_count"] == 8

    # Check tile items
    it1 = data["items"][0]
    assert it1["item_code"] == "C000W26100"
    assert "GRAPH TW" in it1["description"]
    assert it1["hs_code"] == "5703299100"
    assert it1["quantity"] == 3308.0
    assert it1["unit"] == "Square Meter"
    assert it1["secondary_quantity"] == 827.0
    assert it1["secondary_unit"] == "Boxes"
    assert it1["unit_price"] == 19.45
    assert it1["total_price"] == 64340.60
    assert it1.get("country_of_origin") == "United Kingdom"

    # Check free sample folders
    it5 = data["items"][4]
    assert it5["item_code"] == "Sample Folders"
    assert "Free sample" in it5["description"]
    assert it5["quantity"] == 17.0
    assert it5["unit"] == "Each"
    assert it5["secondary_quantity"] == 4.0
    assert it5["secondary_unit"] == "Boxes"
    assert it5["unit_price"] == 0.0
    assert it5["total_price"] == 0.0

    # Check EUR1, COO, Freight
    it6 = data["items"][5]
    assert it6["item_code"] == "EUR1"
    assert it6["quantity"] == 1.0
    assert it6["unit_price"] == 80.99
    assert it6["total_price"] == 80.99

    it7 = data["items"][6]
    assert it7["item_code"] == "COO"
    assert it7["quantity"] == 1.0
    assert it7["unit_price"] == 80.99
    assert it7["total_price"] == 80.99

    it8 = data["items"][7]
    assert it8["item_code"] == "Freight"
    assert "Freight" in it8["description"]
    assert it8["quantity"] == 1.0
    assert it8["unit_price"] == 87.74
    assert it8["total_price"] == 87.74


IMPACT_ACOUSTIC_INVOICE_TEXT = """
https://www.impactacoustic.com Page 1 / 2 
IMPACT ACOUSTIC S.R.L. - c/o F2A, Via Caldera 21 - 20153 Milan 
Reference No. : Bi-technologies-lighting
EXPORTER ID : IT04462890981 Your Customer No. : 6723
ARCHI Brands for Corpet and Floor Trading 
St.81 with st.18 building 44, 3rd floor 
SARAYAT EL MAADI, Cairo- Egypt 
Document No. : IT-DN26-005712
Document Date : 27.08.2026
Contact person: M.SAMY (+2) 01026261319 Delivery date : 24.08.2026
Email : m.samy@archi-brands.com Payment Method : Invoice
 Due Date : August 27, 2026 
 Person in charge : maivelyn.dimalanta@impactacoustic.com 
 Phone : 
VAT No: 759-552-827
ACID Number: 7595528271024210024 
UID-VAT IT : 04462890981
 
Nr. Item Number Description Custom tariff No. Qty Net price Amount USD
 
1 722.12.16.444.00 Acoustic Luminaire Spark 400 94051140 2 612.40 1,224.80
 D400mm H270mm, Slate (28.0 kg) 
 1580lm, 4000 Kelvin 
 
 Shipment 
2 841.10.10.000.00 EXW (EX Works) 1 100.00 100.00
 1x Pallet 
120cm x80cm xh 81cm 
Net Weight: 28.0 kg 
Gross Weight: 38.0 kg 
 Total USD 1,324.80
 Total VAT 0% of 1,324.8 0.00
 Total Incl. VAT USD 1,324.80
COUNTRY OF ORIGIN : ITALY 
Delivery address: 
ARCHI Brands for Corpet and Floor Trading
St.81 with st.18 building 44, 3rd floor 
SARAYAT EL MAADI, Cairo- Egypt 
Contact person: M.SAMY (+2) 01026261319 
Email : m.samy@archi-brands.com
Invoice IT-DN26-005712 Milan, August 31, 2026 
Thank you for your order. Please find here with our invoice for the following items:  

https://www.impactacoustic.com Page 2 / 2 
Bank details Intesa San Paolo USD
BIC/SWIFT BCITITMMXXX 
IBAN IT65F0306911237161009307835 
Payment reference IT-DN26-005712 
 
The exporter of the products covered by this document declares that, 
except where otherwise clearly indicated, these products are of Italian preferential origin.
"""


def test_impact_acoustic_invoice_extraction():
    extractor = CommercialInvoiceExtractor()
    data = extractor.extract(IMPACT_ACOUSTIC_INVOICE_TEXT, {})

    assert data["invoice_number"] == "IT-DN26-005712"
    assert data["invoice_date"] in ["27.08.2026", "27/08/2026", "31.08.2026", "31/08/2026", "August 31, 2026"]
    assert data["acid_number"] == "7595528271024210024"
    assert data["importer_tax_id"] == "759552827"
    assert "IT04462890981" in (data["exporter_registration_no"] or "") or "04462890981" in (data["exporter_registration_no"] or "")
    assert "IMPACT ACOUSTIC" in data["supplier_name"].upper()
    assert "ARCHI BRANDS" in data["importer_name"].upper()
    assert data["origin_country"] == "ITALY"
    assert data["incoterms"] == "EXW"
    assert data["currency"] == "USD"
    assert data["invoice_value"] == 1324.80
    assert data["total_gross_weight_kg"] == 38.0
    assert data["total_net_weight_kg"] == 28.0
    assert data["pallets_count"] == 1
    assert data["packages_count"] == 1
    assert "Bi-technologies-lighting" in (data["purchase_order"] or "")
    assert data["hs_code"] == "94051140"
    assert data.get("is_preferential_origin") is True
    assert data.get("preferential_origin_agreement") == "EU-Egypt Association Agreement (EUR.1)"
    assert data["items_count"] == 2

    it1 = data["items"][0]
    assert it1["item_code"] == "722.12.16.444.00"
    assert "Acoustic Luminaire Spark" in it1["description"]
    assert it1["hs_code"] == "94051140"
    assert it1["quantity"] == 2.0
    assert it1["unit_price"] == 612.40
    assert it1["total_price"] == 1224.80

    it2 = data["items"][1]
    assert it2["item_code"] == "841.10.10.000.00"
    assert "EXW" in it2["description"]
    assert it2["quantity"] == 1.0
    assert it2["unit_price"] == 100.00
    assert it2["total_price"] == 100.00


SUZHOU_YUHENG_INVOICE_TEXT = """
Marks&Nos. Description Quantity(PCS) Unit price（USD） Amount(USD)
Acoustic Panels
Thickness:9mm
Size:1220*2440mm
Density:2000g/m2
400 17.3 6920
Acoustic Panels
Thickness:12mm
Size:1220*2440mm
Density:2400g/m2
1400 23.5 32900
TOTAL 1800 39820
Suzhou Yuheng Textile Co., Ltd.
No.16 Kangsheng Road, Zhitang Town, Changshu City, Suzhou City China
Postcode 215500,Tel:+86 15162573310 Fax:+86 512 52558515
COMMERCIAL INVOICE
ACID: 5281534391025810014
TERMS:EXW
SAY TOTAL USD THIRTY-NINE THOUSAND EIGHT HUNDRED AND TWENTY ONLY.
Acoustic Panels
HS CODE:5602290000
INV.NO.:YH20260901-3
INV.DATE:September 1st,2026
SOLD TO:
To:SCAS FOR CONSTRUCTION AND FINISHING
Address:44,RD 18 ,MAADI SARAYAT CAIRO,11431，EGYPT
FROM SHANGHAI TO EGYPT
"""


def test_suzhou_yuheng_chinese_invoice_extraction():
    extractor = CommercialInvoiceExtractor()
    data = extractor.extract(SUZHOU_YUHENG_INVOICE_TEXT, {})

    assert data["invoice_number"] == "YH20260901-3"
    assert data["invoice_date"] in ["01/09/2026", "September 1st, 2026", "September 1st,2026"]
    assert data["acid_number"] == "5281534391025810014"
    assert data["importer_tax_id"] == "528153439"
    assert "SUZHOU YUHENG" in data["supplier_name"].upper()
    assert "SCAS FOR CONSTRUCTION" in data["importer_name"].upper()
    assert data["origin_country"] == "China"
    assert data["loading_port"] == "SHANGHAI"
    assert data["discharge_port"] == "EGYPT"
    assert data["incoterms"] == "EXW"
    assert data["currency"] == "USD"
    assert data["invoice_value"] == 39820.0
    assert data["subtotal"] == 39820.0
    assert data["hs_code"] == "5602290000"
    assert data["items_count"] == 2

    it1 = data["items"][0]
    assert "Acoustic Panels" in it1["description"]
    assert "Thickness:9mm" in it1["description"]
    assert it1["hs_code"] == "5602290000"
    assert it1["quantity"] == 400.0
    assert it1["unit_price"] == 17.3
    assert it1["total_price"] == 6920.0
    assert it1["country_of_origin"] == "China"

    it2 = data["items"][1]
    assert "Acoustic Panels" in it2["description"]
    assert "Thickness:12mm" in it2["description"]
    assert it2["hs_code"] == "5602290000"
    assert it2["quantity"] == 1400.0
    assert it2["unit_price"] == 23.5
    assert it2["total_price"] == 32900.0
    assert it2["country_of_origin"] == "China"




