"""
Unit Tests — Smart Document Upload Module
Tests parsers, extractors, validators, and service logic.
"""

import pytest
from unittest.mock import MagicMock, patch
from modules.smart_document_upload.extractors.purchase_order import PurchaseOrderExtractor
from modules.smart_document_upload.extractors.cargo_shipping import CargoShippingExtractor
from modules.smart_document_upload.extractors.customs_clearance import CustomsClearanceExtractor
from modules.smart_document_upload.extractors.import_file import ImportFileExtractor
from modules.smart_document_upload.extractors.freight_quotation import FreightQuotationExtractor
from modules.smart_document_upload.extractors.freight_booking import FreightBookingExtractor
from modules.smart_document_upload.validators import (
    validate_module_name,
    validate_file_size,
    SUPPORTED_MODULES,
)
from fastapi import HTTPException

from database.database import SessionLocal
from modules.import_files.model import ImportFile
from modules.smart_document_upload.schemas import ApplyInvoiceRequest, InvoiceApplyData
from modules.smart_document_upload.service import apply_extracted_invoice_service


# ─────────────────────────────────────────────────────────────────────────────
# Purchase Order Extractor Tests
# ─────────────────────────────────────────────────────────────────────────────

class TestPurchaseOrderExtractor:
    extractor = PurchaseOrderExtractor()

    SAMPLE_PO_TEXT = """
    Purchase Order No: PO-2024-00123
    Date: 15/01/2024
    Supplier: ABC Trading Co. Ltd
    Payment Terms: T/T 30 days after BL date
    Incoterms: FOB Shanghai
    Port of Loading: Shanghai
    Currency: USD

    Description                     | Qty  | Unit | Unit Price | Total
    Steel Pipes 2 inch               | 500  | PCS  | 45.00      | 22,500.00
    Steel Fittings                   | 200  | PCS  | 12.50      | 2,500.00

    Grand Total: USD 25,000.00
    """

    def test_po_number_extraction(self):
        result = self.extractor.extract(self.SAMPLE_PO_TEXT, {})
        assert result["po_number"] == "PO-2024-00123"

    def test_supplier_extraction(self):
        result = self.extractor.extract(self.SAMPLE_PO_TEXT, {})
        assert result["supplier_name"] is not None
        assert "ABC" in result["supplier_name"]

    def test_currency_extraction(self):
        result = self.extractor.extract(self.SAMPLE_PO_TEXT, {})
        assert result["currency"] == "USD"

    def test_incoterms_extraction(self):
        result = self.extractor.extract(self.SAMPLE_PO_TEXT, {})
        assert result["incoterms"] == "FOB"

    def test_total_amount_extraction(self):
        result = self.extractor.extract(self.SAMPLE_PO_TEXT, {})
        assert result["total_amount"] == 25000.0

    def test_line_items_extraction(self):
        result = self.extractor.extract(self.SAMPLE_PO_TEXT, {})
        items = result.get("items", [])
        assert len(items) >= 1

    def test_confidence_score(self):
        result = self.extractor.extract(self.SAMPLE_PO_TEXT, {})
        confidence = self.extractor.compute_confidence(result)
        assert 0.0 <= confidence <= 1.0
        assert confidence > 0.5  # should find most required fields

    def test_empty_text_returns_dict(self):
        result = self.extractor.extract("", {})
        assert isinstance(result, dict)

    def test_required_fields_defined(self):
        assert len(self.extractor.required_fields()) > 0

    def test_missing_fields_for_empty_doc(self):
        result = self.extractor.extract("", {})
        missing = self.extractor.missing_required(result)
        assert len(missing) > 0

    def test_gi_industrial_packing_list_extraction(self):
        sample_gi_pl_ocr = """
        Latisana, 30/06/2026
        ECO ASSOCIATES
        7 HOSNI OSMAN ST. SEFARAT DISTRICT
        NOSTRO ORDINE / OUR ORDER M26 413
        COMMESSA 27/360012
        VOSTRO ORDINE / YOUR ORDER ECO/049/2026/REV00
        ACID NUMBER 2001830441013710010
        Q.TA' / Q.TY (NO) LENGTH (mm.) WIDTH (mm.) HEIGHT (mm.) NET (KG) GROSS (KG) (NO) (TYPE)
        RTAXT/K/EC/MS 182 IM/RFM/RFL/PF/NS 2 3950 2250 2250 2250 2270 2 PACKAGE
        QCR12026802R 1 275 265 160 4 4 2 BOX
        KG / COLLI 2254,0 2274,0 4,0 TOTAL
        11471 NASR CITY, CAIRO
        DESCRIZIONE / DESCRIPTION PESO / WEIGHT IMBALLO / PACKING PACKING AND WEIGHT LIST EGYPT
        """
        result = self.extractor.extract(sample_gi_pl_ocr, {})
        packing = result.get("packing_list_items", [])
        assert len(packing) == 2
        
        row1 = packing[0]
        assert "RTAXT" in row1["item_code"]
        assert row1["package_type"] == "Package"
        assert row1["qty_pkg"] == 2.0
        assert row1["length_cm"] == 395.0
        assert row1["width_cm"] == 225.0
        assert row1["height_cm"] == 225.0
        assert row1["total_gross_weight_kg"] == 2270.0
        assert row1["total_net_weight_kg"] == 2250.0

        row2 = packing[1]
        assert row2["item_code"] == "QCR12026802R"
        assert row2["package_type"] == "Box"
        assert row2["qty_pkg"] == 2.0
        assert row2["length_cm"] == 27.5
        assert row2["width_cm"] == 26.5
        assert row2["height_cm"] == 16.0
        assert row2["total_gross_weight_kg"] == 4.0
        assert row2["total_net_weight_kg"] == 4.0

    def test_steelcase_invoice_and_packing_list_extraction(self):
        sample_steelcase_invoice = """
        Steelcase - Steelcase S.A.S. - Société par Actions Simplifiée
        Page 1 / 7
        Invoice No 2316135 of 19.08.2026
        Client/Dealer 79064
        Archi Brands For Corpet and Floor Trading
        Payment and invoicing currency EUR
        Shipment number 1737751 / CUSTOMER PICK UP
        Delivery terms : FCA Free Carrier
        ACID: 7595528271019310011

        Page 2 / 7
        1 466160MTC 5E S7 01 B7 00 05 01 00 73 91 01
        Reply Task Chair Reply Air Color (Mesh version)
        Gross weight=1262,569 KG Net weight=1043,754 KG Unit net weight=14,298 KG
        V=18,980 M3
        HTS 94013900 Country of Origin France
        Item N°: 000100
         73 203,10 14.826,30 15.078,35

        Page 3 / 7
        1 LARSPINE80 01
        Lares Desk Cable Management Vertical Cable Spine H800
        Gross weight=79,253 KG Net weight=76,923 KG
        HTS 39263000 Country of Origin Germany
        Item N°: 000100
         77 26,20 2.017,40 2.051,70

        Page 7 / 7
        Delivery terms : FCA Free Carrier 
        Total net 41.762,39 42.472,35
        Total net incl. surcharge excl. VAT 42.472,35 42.472,35
        Net to pay EUR 42.472,35 42.472,35
        Nb of parcel : 250 Gross weight : 4.036,500 KG Gross volume : 62,026 M3
        N°of container : CSNU 5954505 / R114238
        """

        sample_steelcase_pl = """
        Packing List 1737751-1
        Container ID: CSNU 5954505
        Identification: R114238
        Parcel-No. Parcel Volume: m3 Gross weight: kg Your PO no.: Our Order:
        Qty: Material Code: Description Your Pos. Our Pos. Code:
        1733676639 0,400 41,170 0000060 1704611
        40 TN97800069 Cable spine H800 1 200 LARSPINE80
        2019765652 0,226 17,295 0000059 1704609
        1 P466_WORK_1 REPLY PARCEL 1 200 466160MTC
        """

        combined = sample_steelcase_invoice + "\n\n" + sample_steelcase_pl
        result = self.extractor.extract(combined, {})

        assert result["supplier_name"] == "Steelcase S.A.S."
        assert "Archi Brands" in result["importer_name"]
        assert result["po_number"] == "2316135"
        assert result["currency"] == "EUR"
        assert result["incoterms"] == "FCA"
        assert result["total_amount"] == 42472.35
        assert result["acid_number"] == "7595528271019310011"
        assert "CSNU" in result["container_number"]
        assert result["seal_number"] == "R114238"

        # Check line items
        items = result.get("items", [])
        assert len(items) == 2
        assert items[0]["item_code"] == "466160MTC"
        assert items[0]["quantity"] == 73.0
        assert items[0]["unit_price"] == 203.10
        assert items[0]["total_price"] == 14826.30
        assert items[0]["hs_code"] == "94013900"
        assert items[0]["country_of_origin"] == "France"

        assert items[1]["item_code"] == "LARSPINE80"
        assert items[1]["quantity"] == 77.0
        assert items[1]["unit_price"] == 26.20
        assert items[1]["total_price"] == 2017.40
        assert items[1]["hs_code"] == "39263000"
        assert items[1]["country_of_origin"] == "Germany"

        # Check packing items
        packing = result.get("packing_list_items", [])
        assert len(packing) == 2
        assert packing[0]["item_code"] == "LARSPINE80"
        assert packing[0]["qty_pcs"] == 40.0
        assert packing[0]["total_gross_weight_kg"] == 41.17
        assert packing[0]["total_cbm"] == 0.4
        assert packing[0]["hs_code"] == "39263000"

        assert packing[1]["item_code"] == "466160MTC"
        assert packing[1]["qty_pcs"] == 1.0
        assert packing[1]["total_gross_weight_kg"] == 17.295
        assert packing[1]["total_cbm"] == 0.226
        assert packing[1]["hs_code"] == "94013900"


# ─────────────────────────────────────────────────────────────────────────────
# Cargo Shipping Extractor Tests
# ─────────────────────────────────────────────────────────────────────────────

class TestCargoShippingExtractor:
    extractor = CargoShippingExtractor()

    SAMPLE_BL_TEXT = """
    Bill of Lading No: MSC1234567
    Vessel: MSC MAGNIFICA
    Voyage: 001W
    Port of Loading: Shanghai, China
    Port of Discharge: Alexandria, Egypt
    ETD: 20/01/2024
    ETA: 15/02/2024
    Shipper: ABC Factory Ltd
    Consignee: Egyptian Import Co.
    Gross Weight: 25,000 KG
    Measurement: 45.5 CBM
    Container: MSCU1234567 / Seal: EG123456 / 40HC
    """

    def test_fallback_extraction_bl_number(self):
        # Test the fallback extraction when ai_document_parser is not available
        result = self.extractor._fallback_extract(self.SAMPLE_BL_TEXT)
        assert result.get("bl_number") is not None

    def test_required_fields_defined(self):
        assert "bl_number" in self.extractor.required_fields()
        assert "vessel_name" in self.extractor.required_fields()

    def test_parse_float_helper(self):
        assert self.extractor._parse_float("25,000") == 25000.0
        assert self.extractor._parse_float(None) is None
        assert self.extractor._parse_float("N/A") is None

    def test_containers_extraction_from_dict(self):
        bl_fields = {
            "containers": [
                {"container_no": "MSCU1234567", "seal_no": "EG123456", "type": "40HC", "gross_weight": "10000"}
            ]
        }
        containers = self.extractor._extract_containers(bl_fields)
        assert len(containers) == 1
        assert containers[0]["container_no"] == "MSCU1234567"
        assert containers[0]["gross_weight_kg"] == 10000.0


# ─────────────────────────────────────────────────────────────────────────────
# Customs Clearance Extractor Tests
# ─────────────────────────────────────────────────────────────────────────────

class TestCustomsClearanceExtractor:
    extractor = CustomsClearanceExtractor()

    SAMPLE_CUSTOMS_TEXT = """
    بيان رقم: 2024001234
    تاريخ الإقرار: 20/02/2024
    HS Code: 7304.19.00
    بلد المنشأ: China
    القيمة الجمركية: 623,000
    سعر الصرف: 30.95
    ضريبة الوارد: 62,300
    ضريبة القيمة المضافة: 95,942
    إجمالي: 165,801.50
    """

    def test_declaration_no_extraction(self):
        result = self.extractor.extract(self.SAMPLE_CUSTOMS_TEXT, {})
        assert result["declaration_no"] == "2024001234"

    def test_hs_code_extraction(self):
        result = self.extractor.extract(self.SAMPLE_CUSTOMS_TEXT, {})
        assert result["hs_code"] is not None
        assert "7304" in result["hs_code"]

    def test_customs_value_extraction(self):
        result = self.extractor.extract(self.SAMPLE_CUSTOMS_TEXT, {})
        assert result["customs_value_egp"] == 623000.0

    def test_vat_extraction(self):
        result = self.extractor.extract(self.SAMPLE_CUSTOMS_TEXT, {})
        assert result["vat_amount"] == 95942.0

    def test_total_taxes_extraction(self):
        result = self.extractor.extract(self.SAMPLE_CUSTOMS_TEXT, {})
        assert result["total_taxes"] == 165801.50

    def test_required_fields(self):
        assert "declaration_no" in self.extractor.required_fields()
        assert "total_taxes" in self.extractor.required_fields()


# ─────────────────────────────────────────────────────────────────────────────
# Import File Extractor Tests
# ─────────────────────────────────────────────────────────────────────────────

class TestImportFileExtractor:
    extractor = ImportFileExtractor()

    SAMPLE_INVOICE_TEXT = """
    Commercial Invoice No: INV-2024-0099
    Invoice Date: 10/01/2024
    Seller: Shanghai Steel Corp Ltd
    Country of Origin: China
    Port of Loading: Shanghai
    Port of Discharge: Alexandria
    Incoterms: FOB
    Currency: USD
    Description of Goods: Steel Pipes and Fittings
    HS Code: 7304.19
    Total Amount: 25,000.00
    """

    def test_invoice_number(self):
        result = self.extractor.extract(self.SAMPLE_INVOICE_TEXT, {})
        assert result["invoice_number"] == "INV-2024-0099"

    def test_origin_country(self):
        result = self.extractor.extract(self.SAMPLE_INVOICE_TEXT, {})
        assert result["origin_country"] is not None

    def test_hs_code(self):
        result = self.extractor.extract(self.SAMPLE_INVOICE_TEXT, {})
        assert result["hs_code"] is not None
        assert "7304" in result["hs_code"]

    def test_invoice_value(self):
        result = self.extractor.extract(self.SAMPLE_INVOICE_TEXT, {})
        assert result["invoice_value"] == 25000.0

    def test_incoterms(self):
        result = self.extractor.extract(self.SAMPLE_INVOICE_TEXT, {})
        assert result["incoterms"] == "FOB"


# ─────────────────────────────────────────────────────────────────────────────
# Freight Quotation Extractor Tests
# ─────────────────────────────────────────────────────────────────────────────

class TestFreightQuotationExtractor:
    extractor = FreightQuotationExtractor()

    SAMPLE_QUOTE_TEXT = """
    Freight Rate Quote
    Carrier: MSC Mediterranean Shipping
    Origin: Shanghai
    Destination: Alexandria
    Container: 40HC
    Freight Rate: USD 2,500
    Transit Time: 28 days
    Valid Until: 28/02/2024
    Free Days Demurrage: 14
    Free Days Detention: 7
    """

    def test_carrier_extraction(self):
        result = self.extractor.extract(self.SAMPLE_QUOTE_TEXT, {})
        assert result["carrier_name"] is not None

    def test_freight_rate_extraction(self):
        result = self.extractor.extract(self.SAMPLE_QUOTE_TEXT, {})
        assert result["freight_rate"] == 2500.0

    def test_transit_days_extraction(self):
        result = self.extractor.extract(self.SAMPLE_QUOTE_TEXT, {})
        assert result["transit_days"] == 28

    def test_free_days_demurrage(self):
        result = self.extractor.extract(self.SAMPLE_QUOTE_TEXT, {})
        assert result["free_days_demurrage"] == 14

    def test_container_type(self):
        result = self.extractor.extract(self.SAMPLE_QUOTE_TEXT, {})
        assert result["container_type"] == "40HC"

    def test_real_world_example_1_whl_multi_container(self):
        example_1_text = """
        Dear  Ahmed ,
        Please kindly find the estimated cost as below:
        Local charges: Approx. USD 820/20GP
        Ocean freight:
        •	WHL: USD 5800/20GP  ETD:8.28 
        o	Route: Shanghai – El Dekheila 
        o	Service: Direct 
        o	Transit time: 29 days 
        o	Free time: 21 days
        Local charges: Approx. USD 880/40HQ
        Ocean freight:
        •	WHL: USD 6,700/40HQ  ETD:8.28 
        o	Route: Shanghai – El Dekheila 
        o	Service: Direct 
        o	Transit time: 29 days 
        o	Free time: 21 days
        """
        result = self.extractor.extract(example_1_text, {})
        assert "Wan Hai" in result["carrier_name"] or "WHL" in result["carrier_name"]
        assert "Shanghai" in result["origin_port"]
        assert "Dekheila" in result["destination_port"]
        assert result["free_days_demurrage"] == 21
        assert result["transit_days"] == 29
        assert result["is_direct"] is True
        assert len(result["rate_options"]) >= 2

        # Check 20GP option
        opt20 = next(o for o in result["rate_options"] if o["container_type"] == "20GP")
        assert opt20["ocean_freight"] == 5800.0
        assert opt20["local_charges"] == 820.0
        assert opt20["total_estimated_cost"] == 6620.0
        assert opt20["free_time_days"] == 21

        # Check 40HQ option
        opt40 = next(o for o in result["rate_options"] if o["container_type"] == "40HQ")
        assert opt40["ocean_freight"] == 6700.0
        assert opt40["local_charges"] == 880.0
        assert opt40["total_estimated_cost"] == 7580.0
        assert opt40["free_time_days"] == 21

    def test_vertexexpress_user_quote_extraction(self):
        user_text = """vertexexpress
POL ：NINGBO
POD：DEKHEILA
OF：USD6760/20GP
OF：USD7735/40HQ
ETD：30-Aug
CARRIER：WHL
TT : 35 DAYS direct
FREE TIME：14 days
Other (21days+USD200/ctnr)"""
        result = self.extractor.extract(user_text, {})
        assert result["carrier_name"] == "Wan Hai Lines (WHL)"
        assert result["forwarder_name"] == "Vertex Express"
        assert "Ningbo" in result["origin_port"]
        assert "Dekheila" in result["destination_port"]
        assert result["free_days_demurrage"] == 14
        assert result["transit_days"] == 35
        assert result["is_direct"] is True
        assert result["etd_date"] == "2026-08-30"
        assert len(result["rate_options"]) == 2

        opt20 = next(o for o in result["rate_options"] if o["container_type"] == "20GP")
        assert opt20["ocean_freight"] == 6760.0
        assert opt20["carrier_name"] == "Wan Hai Lines (WHL)"
        assert opt20["forwarder_name"] == "Vertex Express"

        opt40 = next(o for o in result["rate_options"] if o["container_type"] == "40HQ")
        assert opt40["ocean_freight"] == 7735.0
        assert opt40["carrier_name"] == "Wan Hai Lines (WHL)"

    def test_real_world_example_2_surcharges_and_exw(self):
        example_2_text = """
        Dear Ahmed, 

        Please find below our best rate based on your below request : 

        O/F rate: USD 6195/20’DC (INCL OWS ) 
                          USD 7560/40’HQ
        21 days FT
        1st vessel : 1-SEP
        TT: direct, about 28 days
        cancel fee: $100/cntr

        Ex-work charges : USD 630\\20’DC
                                         USD 770\\40’DC

        Thanks with my best regards.
        """
        result = self.extractor.extract(example_2_text, {})
        assert result["free_days_demurrage"] == 21
        assert result["transit_days"] == 28
        assert result["is_direct"] is True
        assert result["cancel_fee"] == 100.0
        assert len(result["rate_options"]) >= 2

        opt20 = next(o for o in result["rate_options"] if o["container_type"] == "20GP")
        assert opt20["ocean_freight"] == 6195.0
        assert opt20["local_charges"] == 630.0
        assert opt20["total_estimated_cost"] == 6825.0
        assert "OWS" in (opt20["notes"] or "")

        opt40 = next(o for o in result["rate_options"] if o["container_type"] == "40HQ")
        assert opt40["ocean_freight"] == 7560.0
        assert opt40["local_charges"] == 770.0
        assert opt40["total_estimated_cost"] == 8330.0

    def test_real_world_example_3_multi_carrier_whl_and_yml(self):
        example_3_text = """
        Dear Ahmed,
        Good day,

        Kindly check the rates below :

        EXW SHANGHAI-DEK
        O/F: USD8280/40HQ BY WHL
        Included EXW FEE
        Included TRUCK: USD440/40HQ+LOCAL: USD390/40HQ+CUSTOMS:USD 50/BILL(BASE EXPORT LICENSE
        Free time has 21days
        ETD:28/AUG
        T/T: About 27 day, DIRECT
         


        EXW SHANGHAI-DEK
        O/F: USD6180/40HQ BY YML
        EXW FEE:(
        TRUCK: USD440/40HQ+LOCAL: USD390/40HQ+CUSTOMS:USD 50/BILL(BASE EXPORT LICENSE
        Free time has 21days
        ETD:27/AUG
        T/T: About 48 day, INDIRECT
        """
        result = self.extractor.extract(example_3_text, {})
        assert result["incoterm"] == "EXW"
        assert len(result["rate_options"]) >= 2

        whl_opt = next(o for o in result["rate_options"] if "WHL" in o["carrier_name"])
        assert whl_opt["ocean_freight"] == 8280.0
        assert whl_opt["transit_days"] == 27
        assert whl_opt["is_direct"] is True
        assert whl_opt["free_time_days"] == 21

        yml_opt = next(o for o in result["rate_options"] if "YML" in o["carrier_name"])
        assert yml_opt["ocean_freight"] == 6180.0
        assert yml_opt["transit_days"] == 48
        assert yml_opt["is_direct"] is False
        assert yml_opt["free_time_days"] == 21

    def test_ocr_noisy_text_extraction(self):
        ocr_noisy_text = """
        QUOTATION FROM COSCO SHIPPING
        Quote Ref: COSCO-EGY-2026-88
        Valid To: 15/09/2026
        POL: NINGBO
        POD: EL DEKHEILA
        
        RATES:
        • COSCO: USD 3, 400 / 40 ' HQ BY COSCO
        • CMA: USD 3, 250 / 40HC BY CMA CGM
        
        Local charges: USD 420 / 40HQ
        Free time: 14 days FT
        Transit time: about 30 days
        """
        result = self.extractor.extract(ocr_noisy_text, {})
        assert result["quotation_ref"] == "COSCO-EGY-2026-88"
        assert result["validity_date"] == "15/09/2026"
        assert "Dekheila" in (result["destination_port"] or "")
        assert len(result["rate_options"]) >= 2

        cosco_opt = next(o for o in result["rate_options"] if "COSCO" in o["carrier_name"])
        assert cosco_opt["ocean_freight"] == 3400.0
        assert cosco_opt["local_charges"] == 420.0

        cma_opt = next(o for o in result["rate_options"] if "CMA" in o["carrier_name"])
        assert cma_opt["ocean_freight"] == 3250.0

    def test_arabic_shipping_quotation_text(self):
        arabic_text = """
        عرض سعر شحن بحري
        الخط الملاحي: إيفرجرين (EVERGREEN)
        شركة الشحن: الأهرام لخدمات الشحن واللوجستيات
        رقم العرض: RFQ-EGY-9912
        صالح حتى: 30/09/2026
        ميناء الشحن: شنغهاي
        ميناء الوصول: ميناء الإسكندرية
        
        الأسعار:
        نولون بحري: USD 3100/40HQ BY EMC
        مصاريف محلية: USD 350/40HQ
        فترة السماح: 21 يوم
        مدة الإبحار: 26 يوم مباشر
        رسوم الإلغاء: $150
        """
        result = self.extractor.extract(arabic_text, {})
        assert "Evergreen" in (result["carrier_name"] or "") or "EMC" in (result["carrier_name"] or "")
        assert "Shanghai" in (result["origin_port"] or "") or "شنغهاي" in (result["origin_port"] or "")
        assert "Alexandria" in (result["destination_port"] or "") or "الإسكندرية" in (result["destination_port"] or "")
        assert result["free_days_demurrage"] == 21
        assert result["transit_days"] == 26
        assert result["is_direct"] is True
        assert result["cancel_fee"] == 150.0

    def test_lcl_and_air_freight_rates(self):
        lcl_air_text = """
        LCL Consolidation Quote
        POL: SHANGHAI
        POD: ALEXANDRIA
        Rate: USD 45/CBM BY MSK
        Local charges: USD 15/CBM
        Free time: 10 days
        Transit time: 32 days
        """
        result = self.extractor.extract(lcl_air_text, {})
        assert len(result["rate_options"]) >= 1
        opt = result["rate_options"][0]
        assert opt["ocean_freight"] == 45.0
        assert opt["container_type"] == "LCL (CBM)"
        assert opt["local_charges"] == 15.0

    def test_unmapped_expenses_and_free_time_extend(self):
        user_quote_text = """
        vertexexpress
        POL ：NINGBO
        POD：DEKHEILA
        OF：USD6760/20GP
        FREE TIME EXTEND : USD200/ctnr
        OF：USD7735/40HQ
        FREE TIME EXTEND : USD200/ctnr)
        ETD：30-Aug
        CARRIER：WHL
        TT : 35 DAYS direct
        FREE TIME：14 days
        Other (21days+USD200/ctnr)
        """
        result = self.extractor.extract(user_quote_text, {})
        assert len(result["rate_options"]) >= 2
        assert "Dekheila" in (result["destination_port"] or "")
        assert "Ningbo" in (result["origin_port"] or "")
        assert result["additional_expenses"] is not None
        assert len(result["additional_expenses"]) >= 1
        assert result["unmapped_expenses_warning"] is not None
        assert "تنبيه" in result["unmapped_expenses_warning"]

        # Check options contain additional charges in notes
        for opt in result["rate_options"]:
            assert opt["notes"] is not None
            assert "USD 200" in opt["notes"]

    def test_genoa_alexandria_lcl_quotation_single_option(self):
        user_email = """
        Dear Mr.Ahmed,
                     Good Day,

        Please find below our rate  :

        POL : Genoa

        POD : Alexandria Old Port – Our Warehouse

        Term : EXW

        Volume : 9 CBM
        Cargo : Non-IMO / Non-Stackable
        •	Ocean Freight : EUR 25 / W/M
        •	D-THC : EGP 650 / W/M + VAT 
        •	Storage (1st week) : EGP 650 / W/M + VAT
        •	Extra Storage Day : EGP 50 / W/M + VAT
        •	Transit Time : About 7 days – Direct Service
                Notes  :
        •	Ocean freight rates are subject to War Risk Surcharges (WRS) and General Rate Increase (GRI).
        •	All vessels are subject to possible delays in arrival, berthing, sailing, or changes in schedule/port calls, which are beyond our control.
        •	Storage charges apply in case the cargo is stored in UGL bonded warehouse. In case of storage in governmental warehouses, the applicable governmental warehouse tariff will apply.
        •	21 days is the maximum valid time for using the offered tariff. After 21 days, the regular governmental warehouse tariff will be applied.
        """
        result = self.extractor.extract(user_email, {})
        assert result["options_count"] == 1
        assert len(result["rate_options"]) == 1

        opt = result["rate_options"][0]
        assert opt["ocean_freight"] == 25.0
        assert opt["currency"] == "EUR"
        assert opt["container_type"] == "LCL (CBM)"
        assert "Genoa" in (opt["origin_port"] or "")
        assert "Alexandria" in (opt["destination_port"] or "")
        assert opt["transit_days"] == 7
        assert opt["is_direct"] is True
        assert opt["incoterm"] == "EXW"
        assert "D-THC" in (opt["notes"] or "")
        assert "Storage" in (opt["notes"] or "")
# ─────────────────────────────────────────────────────────────────────────────
# Freight Booking Extractor Tests
# ─────────────────────────────────────────────────────────────────────────────

class TestFreightBookingExtractor:
    extractor = FreightBookingExtractor()

    SAMPLE_BOOKING_TEXT = """
    Booking Confirmation
    Booking No: MSC123456789
    Carrier: MSC
    Vessel: MSC MAGNIFICA
    Voyage: 001W
    Port of Loading: Shanghai
    Port of Discharge: Alexandria
    ETD: 20/01/2024
    ETA: 15/02/2024
    SI Cut-Off: 15/01/2024
    VGM Cut-Off: 14/01/2024
    Container: 1 x 40HC
    """

    def test_booking_number(self):
        result = self.extractor.extract(self.SAMPLE_BOOKING_TEXT, {})
        assert result["booking_number"] == "MSC123456789"

    def test_vessel_name(self):
        result = self.extractor.extract(self.SAMPLE_BOOKING_TEXT, {})
        assert result["vessel_name"] is not None

    def test_etd(self):
        result = self.extractor.extract(self.SAMPLE_BOOKING_TEXT, {})
        assert result["etd"] is not None

    def test_containers_count(self):
        result = self.extractor.extract(self.SAMPLE_BOOKING_TEXT, {})
        assert result["containers_count"] == 1


# ─────────────────────────────────────────────────────────────────────────────
# Validators Tests
# ─────────────────────────────────────────────────────────────────────────────

class TestValidators:

    def test_valid_module_passes(self):
        for module in SUPPORTED_MODULES:
            validate_module_name(module)  # should not raise

    def test_invalid_module_raises(self):
        with pytest.raises(HTTPException) as exc_info:
            validate_module_name("nonexistent-module")
        assert exc_info.value.status_code == 422

    def test_file_size_within_limit(self):
        content = b"%PDF-1.4\n" + b"x" * (5 * 1024 * 1024)  # 5 MB valid PDF header
        validate_file_size(content, "test.pdf")  # should not raise

    def test_file_size_exceeds_limit(self):
        content = b"x" * (21 * 1024 * 1024)  # 21 MB
        with pytest.raises(HTTPException) as exc_info:
            validate_file_size(content, "large_file.pdf")
        assert exc_info.value.status_code == 413


# ─────────────────────────────────────────────────────────────────────────────
# Base Extractor Helper Tests
# ─────────────────────────────────────────────────────────────────────────────

class TestBaseExtractorHelpers:
    extractor = ImportFileExtractor()  # concrete instance for testing base methods

    def test_find_first_returns_match(self):
        text = "Invoice No: INV-123"
        result = self.extractor.find_first([r"Invoice\s+No[:\s]+([A-Z0-9\-]+)"], text)
        assert result == "INV-123"

    def test_find_first_returns_none_on_no_match(self):
        result = self.extractor.find_first([r"NOPATTERN(\d+)"], "nothing here")
        assert result is None

    def test_find_float_with_comma(self):
        result = self.extractor.find_float([r"Total[:\s]+([0-9,]+\.?\d*)"], "Total: 25,000.50")
        assert result == 25000.50

    def test_normalize_currency(self):
        assert self.extractor.normalize_currency("Amount: USD 5000") == "USD"
        assert self.extractor.normalize_currency("العملة: EGP") == "EGP"
        assert self.extractor.normalize_currency("no currency here") is None

    def test_normalize_incoterms(self):
        assert self.extractor.normalize_incoterms("Terms: FOB Shanghai") == "FOB"
        assert self.extractor.normalize_incoterms("CIF Alexandria") == "CIF"
        assert self.extractor.normalize_incoterms("no terms") is None

    def test_normalize_container_type_40hc(self):
        assert self.extractor.normalize_container_type("40HC container") == "40HC"
        assert self.extractor.normalize_container_type("40'HQ") == "40HC"

    def test_normalize_container_type_20gp(self):
        assert self.extractor.normalize_container_type("20ft container") == "20GP"


# ─────────────────────────────────────────────────────────────────────────────
# BE03-T03: Apply Extracted Invoice Idempotency & Validation Tests
# ─────────────────────────────────────────────────────────────────────────────

class TestApplyExtractedInvoiceIdempotent:
    """Tests for BE03-T03: apply_extracted_invoice_service idempotency and required invoice_number."""

    def test_apply_invoice_requires_invoice_number_when_file_set(self):
        db = SessionLocal()
        try:
            import_file = ImportFile(
                import_file_code="IMP-BE03-T03-REQ",
                company_name="Test Importer",
                supplier_name="Test Supplier",
                shipment_mode="Sea FCL",
            )
            db.add(import_file)
            db.commit()
            db.refresh(import_file)

            # Missing invoice number
            payload_none = ApplyInvoiceRequest(
                import_file_id=import_file.import_file_id,
                invoice_data=InvoiceApplyData(invoice_number=None, invoice_value=5000.0),
            )
            with pytest.raises(HTTPException) as exc_none:
                apply_extracted_invoice_service(db=db, payload=payload_none)
            assert exc_none.value.status_code == 400
            assert exc_none.value.detail["code"] == "SDU_INVOICE_NUMBER_REQUIRED"

            # Blank invoice number
            payload_blank = ApplyInvoiceRequest(
                import_file_id=import_file.import_file_id,
                invoice_data=InvoiceApplyData(invoice_number="   ", invoice_value=5000.0),
            )
            with pytest.raises(HTTPException) as exc_blank:
                apply_extracted_invoice_service(db=db, payload=payload_blank)
            assert exc_blank.value.status_code == 400
            assert exc_blank.value.detail["code"] == "SDU_INVOICE_NUMBER_REQUIRED"
        finally:
            db.close()

    def test_apply_invoice_idempotent_and_does_not_overwrite_estimate(self):
        db = SessionLocal()
        try:
            import_file = ImportFile(
                import_file_code="IMP-BE03-T03-IDEMP",
                company_name="Test Importer",
                supplier_name="Test Supplier",
                shipment_mode="Sea FCL",
                estimated_cost=75000.0,
                estimated_cost_currency="EUR",
                invoices_data=[],
                invoices_count=0,
            )
            db.add(import_file)
            db.commit()
            db.refresh(import_file)

            # Apply invoice "inv-77" with 10000 USD
            payload = ApplyInvoiceRequest(
                import_file_id=import_file.import_file_id,
                invoice_data=InvoiceApplyData(
                    invoice_number="inv-77",
                    invoice_date="2026-10-01",
                    invoice_value=10000.0,
                    currency="USD",
                ),
            )
            res1 = apply_extracted_invoice_service(db=db, payload=payload, user="tester")
            assert res1["applied"] is True
            assert res1["params"]["replaced"] is False
            assert res1["params"]["invoice_no"] == "inv-77"

            db.refresh(import_file)
            assert len(import_file.invoices_data) == 1
            assert import_file.invoices_count == 1
            assert sum(inv["amount"] for inv in import_file.invoices_data) == 10000.0
            assert import_file.estimated_cost == 75000.0  # untouched
            assert import_file.estimated_cost_currency == "EUR"  # untouched

            # Apply the same invoice number (case-insensitive "INV-77") a second time
            payload2 = ApplyInvoiceRequest(
                import_file_id=import_file.import_file_id,
                invoice_data=InvoiceApplyData(
                    invoice_number="INV-77",
                    invoice_date="2026-10-02",
                    invoice_value=10000.0,
                    currency="USD",
                ),
            )
            res2 = apply_extracted_invoice_service(db=db, payload=payload2, user="tester")
            assert res2["applied"] is True
            assert res2["params"]["replaced"] is True
            assert res2["params"]["invoice_no"] == "INV-77"

            db.refresh(import_file)
            assert len(import_file.invoices_data) == 1
            assert import_file.invoices_count == 1
            assert sum(inv["amount"] for inv in import_file.invoices_data) == 10000.0
            assert import_file.estimated_cost == 75000.0
            assert import_file.estimated_cost_currency == "EUR"
            assert import_file.invoices_data[0]["date"] == "2026-10-02"

            # Apply third time with different amount replaces in-place
            payload3 = ApplyInvoiceRequest(
                import_file_id=import_file.import_file_id,
                invoice_data=InvoiceApplyData(
                    invoice_number="inv-77 ",
                    invoice_date="2026-10-03",
                    invoice_value=12000.0,
                    currency="USD",
                ),
            )
            res3 = apply_extracted_invoice_service(db=db, payload=payload3, user="tester")
            assert res3["applied"] is True
            assert res3["params"]["replaced"] is True

            db.refresh(import_file)
            assert len(import_file.invoices_data) == 1
            assert import_file.invoices_count == 1
            assert sum(inv["amount"] for inv in import_file.invoices_data) == 12000.0
            assert import_file.estimated_cost == 75000.0
        finally:
            db.close()

