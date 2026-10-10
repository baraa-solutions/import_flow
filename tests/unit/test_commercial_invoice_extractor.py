import pytest
from modules.smart_document_upload.extractors.commercial_invoice import CommercialInvoiceExtractor
from modules.smart_document_upload.service import (
    extract_commercial_invoice_service,
    apply_extracted_invoice_service,
)
from database.database import get_db, SessionLocal
from modules.import_files.model import ImportFile
from modules.incoterms.model import Incoterm
from modules.smart_document_upload.schemas import ApplyInvoiceRequest


SAMPLE_INVOICE_TEXT = """
COMMERCIAL INVOICE
Invoice No: INV-2026-99881
Invoice Date: 2026-08-15
ACID Number: 1987654321098765432
Importer Tax ID: 200345678
Exporter Registration No: CN91310000778899
Supplier / Exporter: Shanghai Machinery Co., Ltd.
Importer / Buyer: Egyptian National Industrial Supply LLC
Country of Origin: China
Port of Loading: Shanghai Port
Port of Discharge: Alexandria Port
Incoterms: FOB
Currency: USD

Item Description                  Qty    UOM    Unit Price   Total Price
Industrial Milling Tool A10      100    PCS    250.00       25000.00
Hydraulic Valve 2-inch            50    PCS    180.00        9000.00
Control Unit Replacement         200    PCS     80.00       16000.00

Total Amount: 50,000.00 USD
Total Gross Weight: 4,500.00 KG
Total Net Weight: 4,100.00 KG
Payment Terms: 30% Advance, 70% against Draft BL copy
"""


class TestCommercialInvoiceExtractor:
    def test_extract_invoice_fields(self):
        extractor = CommercialInvoiceExtractor()
        data = extractor.extract(SAMPLE_INVOICE_TEXT, {})

        assert data["invoice_number"] == "INV-2026-99881"
        assert data["acid_number"] == "1987654321098765432"
        assert data["importer_tax_id"] == "200345678"
        assert data["exporter_registration_no"] == "CN91310000778899"
        assert "Shanghai" in data["supplier_name"]
        assert "Egyptian" in data["importer_name"]
        assert data["origin_country"] == "China"
        assert data["incoterms"] == "FOB"
        assert data["currency"] == "USD"
        assert data["invoice_value"] == 50000.0
        assert data["total_gross_weight_kg"] == 4500.0
        assert data["total_net_weight_kg"] == 4100.0
        assert data["items_count"] == 3

    def test_extract_service_wrapper(self):
        res = extract_commercial_invoice_service(
            filename="invoice.txt",
            raw_text=SAMPLE_INVOICE_TEXT,
        )

        assert res["document_type"] == "Commercial Invoice"
        assert res["extracted_fields"]["invoice_number"] == "INV-2026-99881"
        assert res["items_count"] == 3
        assert len(res["items"]) == 3
        assert res["items"][0]["quantity"] == 100.0

    def test_apply_extracted_invoice_to_import_file(self):
        db = SessionLocal()
        try:
            # Create a test import file
            import_file = ImportFile(
                import_file_code="IMP-INV-TEST-001",
                company_name="Egyptian National Industrial Supply LLC",
                supplier_name="Shanghai Machinery Co., Ltd.",
                shipment_mode="Sea FCL",
                incoterm_code="EXW",
            )
            db.add(import_file)
            db.commit()
            db.refresh(import_file)

            # SDU-01: the Incoterm is validated against the incoterms master table.
            if db.query(Incoterm).filter(Incoterm.incoterm_code == "FOB").first() is None:
                db.add(Incoterm(incoterm_code="FOB", incoterm_name="Free On Board"))
                db.commit()

            extractor = CommercialInvoiceExtractor()
            data = extractor.extract(SAMPLE_INVOICE_TEXT, {})

            # SDU-01: typed request body (same keys as the extractor output).
            apply_res = apply_extracted_invoice_service(
                db=db,
                payload=ApplyInvoiceRequest(import_file_id=import_file.import_file_id, invoice_data=data),
                user="tester",
            )

            assert apply_res["applied"] is True
            assert apply_res["import_file_id"] == import_file.import_file_id

            # Verify db update
            db.refresh(import_file)
            assert import_file.acid_number == "1987654321098765432"
            assert import_file.incoterm_code == "FOB"
            assert import_file.port_of_loading == "Shanghai Port"
            assert import_file.port_of_discharge == "Alexandria Port"
            assert import_file.estimated_cost == 50000.0
            assert import_file.invoices_count == 1
        finally:
            db.close()

    def test_extract_arabic_commercial_invoice_fields(self):
        arabic_text = """تحليل شامل لبيانات الفاتورة التجارية المرفقة:
1. الأطراف والبيانات الأساسية
المُصدِّر (البائع): شركة G.I. INDUSTRIAL HOLDING SPA (إيطاليا - Via G. Agnelli, 7, 33053 Latisana).
المستورد (المشتري): شركة ECO ASSOCIATES (مصر - 7 شارع حسني عثمان، حي السفارات، مدينة نصر، القاهرة).
رقم الفاتورة: V1/ 2539.
تاريخ الفاتورة: 30/06/2026.
أرقام المراجع:أمر شراء العميل (PO): ECO/53/26REV00.
تأكيد أمر التوريد: 768 date 14/04/26.
إذن التسليم/البوليصة: Bolla RO/0/ 441 Del 30/06/2026.
كود العميل: 801765.
الرقم الضريبي للمستورد (V.A.T. ID): 200183044.
2. الشروط التجارية والمالية
شرط التسليم (Incoterms 2020): EXW EXTRA UE (تسليم أرض المصنع خارج الاتحاد الأوروبي).
شروط الدفع: 100% ADVANCED PAYMENT (دفع مقدم 100%).
العملة: يورو (EUR).
القيمة الإجمالية للفاتورة: 15,100.00 يورو.
3. تفاصيل البنود والأصناف (Line Items)
كود الصنف: WOPB3D0048S0009.
الوصف: وحدة تكييف هواء / مبرد مياه بنظام السوائل (مبرد مياه وشيلر) - TWS 340 S.
البند الجمركي (HS Code): 84158200.
الكمية: 2 (قطعتين / No).
سعر الوحدة: 7,550.00 يورو.
الإجمالي للبند: 15,100.00 يورو.
الوزن الصافي (Net Weight): 820.60 كجم.
الوزن الإجمالي/القائم (Gross Weight): 848.60 كجم.
بلد المنشأ: إيطاليا (Italy)."""
        extractor = CommercialInvoiceExtractor()
        data = extractor.extract(arabic_text, {})

        assert data["invoice_number"] == "V1/ 2539"
        assert data["invoice_date"] == "30/06/2026"
        assert data["supplier_name"] == "G.I. INDUSTRIAL HOLDING SPA"
        assert data["importer_name"] == "ECO ASSOCIATES"
        assert data["importer_tax_id"] == "200183044"
        assert data["incoterms"] == "EXW"
        assert data["currency"] == "EUR"
        assert data["invoice_value"] == 15100.0
        assert data["origin_country"] == "إيطاليا"
        assert data["payment_terms"] == "100% ADVANCED PAYMENT"
        assert data["total_gross_weight_kg"] == 848.6
        assert data["total_net_weight_kg"] == 820.6
        assert len(data["items"]) == 1
        assert data["items"][0]["item_code"] == "WOPB3D0048S0009"
        assert data["items"][0]["hs_code"] == "84158200"
        assert data["items"][0]["quantity"] == 2.0
        assert data["items"][0]["unit_price"] == 7550.0
        assert data["items"][0]["total_price"] == 15100.0

