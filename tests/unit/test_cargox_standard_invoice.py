"""
Unit tests for CargoX Standard Excel Commercial Invoice Generator, Parser, Comparison, and Session Upsert (BP-025 / CGX-002).
"""

import io
import openpyxl
import pytest
from datetime import datetime, timezone
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

from database.database import Base, get_db
from main import app
from modules.import_files.model import ImportFile
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.purchase_orders.model import PurchaseOrder, POLineItem
from modules.cargox.schemas import (
    StandardInvoicePayload,
    StandardInvoiceLineItem,
    StandardInvoiceSessionCreate,
    StandardInvoiceStatusUpdateRequest,
)
from modules.cargox.service import CargoXStandardInvoiceService
from modules.cargox.excel_invoice_service import (
    generate_standard_invoice_excel_bytes,
    parse_standard_invoice_excel_bytes,
    compare_standard_invoice_data,
)
from modules.cargox.city_port_resolver import (
    resolve_city_code,
    resolve_port_display_name,
)


@pytest.fixture
def test_db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()

    # Seed Company
    company = ImportCompany(
        company_id=1,
        importer_name="الشركة المصرية للاستيراد والتوريدات",
        address="10 El-Bostan St, Cairo",
        country="Egypt",
        importer_id="IMP-001-REG",
        importer_id_expiry=datetime(2030, 1, 1).date(),
        vat_id="123456789",
        vat_id_expiry=datetime(2030, 1, 1).date(),
        registration_number="CR-987654",
        registration_expiry=datetime(2030, 1, 1).date(),
    )
    db.add(company)

    # Seed Supplier
    supplier = Supplier(
        supplier_id=1,
        supplier_code="SUP-001",
        company_name="Narbutas International UAB",
        supplier_type="Manufacturer",
        registration_type="Commercial Registration",
        foreign_exporter_id="LT300591314",
        foreign_exporter_country="Lithuania",
        foreign_exporter_country_code="LT",
        address="Ukmerges g. 308, Vilnius",
        phone="+37052100000",
        email="sales@narbutas.lt",
        website="www.narbutas.com",
    )
    db.add(supplier)

    # Seed Import File
    file = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-009",
        company_id=1,
        company_name="Egyptian Import & Supply Co.",
        supplier_id=1,
        supplier_name="Narbutas International UAB",
        acid_number="7595528271020210010",
        estimated_cost_currency="EUR",
        incoterm_code="EXW",
        port_of_loading="Klaipeda Port",
        port_of_discharge="Alexandria Port",
        estimated_cost=5000.0,
    )
    db.add(file)

    # Seed PO & Items
    po = PurchaseOrder(
        po_id=1,
        po_number="PO-2026-001",
        import_file_id=1,
        project_id=1,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        currency_id=1,
        total_amount_fob=5000.0,
    )
    db.add(po)
    db.flush()

    item1 = POLineItem(
        po_id=1,
        item_code="DSK-001",
        description_ar="مكتب تنفيذي",
        description_en="Executive Office Desk",
        quantity=10.0,
        unit_price=300.0,
        total_price=3000.0,
        unit_of_measure="SET",
        gross_weight_kg=250.0,
        net_weight_kg=220.0,
        country_of_origin="LT",
    )
    item2 = POLineItem(
        po_id=1,
        item_code="CHR-002",
        description_ar="كرسي مريح",
        description_en="Ergonomic Mesh Chair",
        quantity=20.0,
        unit_price=100.0,
        total_price=2000.0,
        unit_of_measure="PCE",
        gross_weight_kg=200.0,
        net_weight_kg=180.0,
        country_of_origin="LT",
    )
    db.add(item1)
    db.add(item2)
    db.commit()

    yield db
    db.close()



def test_standard_invoice_excel_generation_and_parsing(test_db):
    """Test generating .xlsx with openpyxl Named Ranges & Table and parsing it back cleanly."""
    snapshot = CargoXStandardInvoiceService.build_system_snapshot(test_db, 1)
    assert snapshot.acid_number == "7595528271020210010"
    assert snapshot.seller_tax_id == "LT300591314"
    assert snapshot.buyer_tax_id == "123456789"
    assert len(snapshot.items) == 2, "Distinct price items must remain on separate lines (Customs compliance)"
    assert snapshot.subtotal == 5000.0
    assert snapshot.total_amount == 5000.0

    # Generate Excel Bytes
    excel_bytes = generate_standard_invoice_excel_bytes(snapshot)
    assert len(excel_bytes) > 1000

    # Parse Excel Bytes back
    parsed = parse_standard_invoice_excel_bytes(excel_bytes)
    assert parsed.acid_number == "7595528271020210010"
    assert parsed.seller_name == "Narbutas International UAB"
    assert parsed.buyer_tax_id == "123456789"
    assert parsed.currency_code == "EUR"
    assert parsed.incoterm == "EXW"
    assert len(parsed.items) == 2
    assert parsed.items[0].hs_code == "940310"
    assert parsed.items[0].quantity == 10.0
    assert parsed.items[0].unit_price == 300.0
    assert parsed.items[1].hs_code == "940310"
    assert parsed.items[1].quantity == 20.0
    assert parsed.items[1].unit_price == 100.0
    assert parsed.subtotal == 5000.0


def test_standard_invoice_comparison_perfect_and_discrepancy(test_db):
    """Test comparison matrix for matching vs modified supplier data."""
    snapshot = CargoXStandardInvoiceService.build_system_snapshot(test_db, 1)
    
    # 1. Perfect Match
    comp_res = CargoXStandardInvoiceService.compare_invoices(test_db, 1, snapshot)
    assert comp_res.has_discrepancies is False
    assert comp_res.has_critical_mismatch is False
    assert comp_res.total_discrepancies_count == 0

    # 2. Supplier Data with Discrepancies
    modified_sup = snapshot.model_copy(deep=True)
    modified_sup.acid_number = "9999999999999999999"  # Mismatch
    modified_sup.items[0].unit_price = 350.0  # Price difference
    modified_sup.items[0].total_amount = 3500.0
    modified_sup.subtotal = 5500.0
    modified_sup.total_amount = 5850.0

    comp_diff = CargoXStandardInvoiceService.compare_invoices(test_db, 1, modified_sup)
    assert comp_diff.has_discrepancies is True
    assert comp_diff.has_critical_mismatch is True
    assert comp_diff.critical_mismatches_count >= 1
    assert comp_diff.rectification_notice_en is not None
    assert "ACID Number" in comp_diff.rectification_notice_en


def test_standard_invoice_session_upsert_and_override_justification(test_db):
    """Test Anti-duplicate upsert logic and mandatory discrepancy override justification."""
    snapshot = CargoXStandardInvoiceService.build_system_snapshot(test_db, 1)

    # 1. Create Initial Session as DRAFT
    create_schema = StandardInvoiceSessionCreate(
        import_file_id=1,
        import_file_code="IMP-2026-009",
        acid_number="7595528271020210010",
        invoice_number="INV-2026-009",
        subtotal_amount=5000.0,
        total_amount=5350.0,
        line_items_count=2,
        has_discrepancies=True,
        has_critical_mismatch=False,
        status="DRAFT",
    )
    session1 = CargoXStandardInvoiceService.save_or_upsert_session(test_db, create_schema)
    assert session1.session_id is not None
    assert session1.session_code.startswith("CX-INV-")
    assert session1.status == "DRAFT"

    # 2. Try Approving with Discrepancies without Override Reason -> Should Raise 400
    create_schema.status = "APPROVED"
    create_schema.discrepancy_override_reason = ""
    with pytest.raises(Exception) as exc_info:
        CargoXStandardInvoiceService.save_or_upsert_session(test_db, create_schema)
    assert "يجب كتابة مبرر" in str(exc_info.value)

    # 3. Approve with Valid Justification -> Should Update Same Record (Anti-Duplicate)
    create_schema.discrepancy_override_reason = "تم اعتماد الفرق البسيط في السعر بموافقة الإدارة المالية."
    session2 = CargoXStandardInvoiceService.save_or_upsert_session(test_db, create_schema)
    assert session2.session_id == session1.session_id  # Same session updated!
    assert session2.session_code == session1.session_code
    assert session2.status == "APPROVED"
    assert session2.discrepancy_override_reason == "تم اعتماد الفرق البسيط في السعر بموافقة الإدارة المالية."


def test_standard_invoice_api_endpoints(test_db):
    """Test REST API endpoints for Standard Invoice Hub."""
    app.dependency_overrides[get_db] = lambda: test_db
    client = TestClient(app)

    # Test Download Excel
    res_gen = client.get("/api/v1/cargox/standard-invoice/generate/1")
    assert res_gen.status_code == 200
    assert "application/vnd.openxmlformats-officedocument" in res_gen.headers["content-type"]
    excel_bytes = res_gen.content

    # Test Upload & Parse Excel
    res_parse = client.post(
        "/api/v1/cargox/standard-invoice/parse",
        files={"file": ("test_invoice.xlsx", excel_bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
    )
    assert res_parse.status_code == 200
    parsed_json = res_parse.json()
    assert parsed_json["acid_number"] == "7595528271020210010"
    assert len(parsed_json["items"]) == 2

    # Test Compare Endpoint
    res_comp = client.post(
        "/api/v1/cargox/standard-invoice/compare/1",
        json=parsed_json,
    )
    assert res_comp.status_code == 200
    comp_json = res_comp.json()
    assert comp_json["has_discrepancies"] is False

    # Test Save Session
    session_payload = {
        "import_file_id": 1,
        "import_file_code": "IMP-2026-009",
        "acid_number": "7595528271020210010",
        "invoice_number": "INV-2026-009",
        "currency_code": "EUR",
        "subtotal_amount": 5000.0,
        "total_amount": 5350.0,
        "line_items_count": 2,
        "status": "APPROVED",
        "has_discrepancies": False,
    }
    res_save = client.post("/api/v1/cargox/standard-invoice/session", json=session_payload)
    assert res_save.status_code == 200
    assert res_save.json()["status"] == "APPROVED"

    # Test Get by file
    res_by_file = client.get("/api/v1/cargox/standard-invoice/session/by-file/1")
    assert res_by_file.status_code == 200
    assert res_by_file.json()["session_code"].startswith("CX-INV-")

    app.dependency_overrides.clear()


def test_cargox_excel_structure_and_named_ranges(test_db):
    """Rigorous test verifying 100% compliance with official CargoX template structure, sheets, fonts, and named ranges."""
    import io
    import openpyxl

    snapshot = CargoXStandardInvoiceService.build_system_snapshot(test_db, 1)
    excel_bytes = generate_standard_invoice_excel_bytes(snapshot)

    wb = openpyxl.load_workbook(io.BytesIO(excel_bytes), data_only=False)

    # 1. Verify 8 Sheet Names in Exact Order
    expected_sheets = [
        "Invoice",
        "Package Type list",
        "Unit of measure list",
        "Cities",
        "Currency List",
        "UOM List",
        "Country List",
        "City List",
    ]
    assert wb.sheetnames == expected_sheets

    # 2. Main Sheet Structure & Gridlines
    ws = wb["Invoice"]
    assert ws.views.sheetView[0].showGridLines is False

    # 3. Merged Cells Check (All 10 required ranges)
    merged_ranges = [str(m) for m in ws.merged_cells.ranges]
    totals_start_row = 13 + len(snapshot.items)
    expected_merges = [
        "B1:C2", "B3:C3", "D1:D2", "F3:G3", "F4:G4",
        "F5:G5", "H7:J7", "H8:J8",
        f"B{totals_start_row+2}:J{totals_start_row+2}",
        f"B{totals_start_row+4}:J{totals_start_row+4}",
    ]
    for mr in expected_merges:
        assert mr in merged_ranges, f"Missing merged range: {mr}"

    assert ws["B1"].value == "Narbutas International UAB"
    assert ws["B1"].font.name == "Calibri"
    assert ws["B3"].font.size == 18.0
    assert ws["B3"].font.bold is True

    # 4. Critical Named Ranges Check
    assert "SellerName" in wb.defined_names
    assert "SellerRegistrationCode" in wb.defined_names
    assert "BuyerName" in wb.defined_names
    assert "BuyerCode" in wb.defined_names
    assert "ACIDNumber" in wb.defined_names
    assert "TotalInvoiceLinesNo" in wb.defined_names
    assert "InvoiceSubtotal" in wb.defined_names
    assert "FreightCost" in wb.defined_names
    assert "InsuranceCost" in wb.defined_names
    assert "OtherCosts" in wb.defined_names
    assert "TotalAmount" in wb.defined_names

    # 5. Exact Labels Check
    assert ws["E1"].value == "Registration # :"
    assert ws["E2"].value == "City Code :"
    assert ws["H2"].value == "Phone:"
    assert ws["E3"].value == "Web Site :"
    assert ws["H3"].value == "Fax:"
    assert ws["D4"].value == "Exporter Contact :"
    assert ws["B5"].value == "Export To:"
    assert ws["D5"].value == "Importer Contact :"
    assert ws["H5"].value == "Phone:"
    assert ws["K5"].value == "Gross Weight:"
    assert ws["D7"].value == "ACID #:"
    assert ws["F7"].value == "Origin Port:"
    assert ws["K7"].value == "Weight Unit:"
    assert ws["B8"].value == "Purchase Order #:"
    assert ws["D8"].value == "Purchase Order Date:"
    assert ws["F8"].value == "Destination Port:"
    assert ws["B9"].value == "Invoice #:"
    assert ws["D9"].value == "Invoice Date:"
    assert ws["B10"].value == "Currency:"
    assert ws["D10"].value == "Inco Term:"
    assert ws["K4"].value == "Proforma invoice number:"

    # 6. Formulas Check
    totals_row = 13 + len(snapshot.items)
    assert "=ROWS(InvoiceItems[])" in ws[f"C{totals_row}"].value or "=ROWS(" in ws[f"C{totals_row}"].value
    assert "=SUM(InvoiceItems[Total])" in ws[f"P{totals_row}"].value or "=SUM(" in ws[f"P{totals_row}"].value
    assert "=ROWS(InvoiceItems[])" in ws["H11"].value or "=ROWS(" in ws["H11"].value

    # 7. Table Check
    assert "InvoiceItems" in ws.tables

    # 8. Exact Row 12 Headers Check (16 Columns)
    expected_row12 = [
        "#", "Product Code", "TradeMarkOwner/Manufacturer", "Brand Name", "Model",
        "HS Tariff Code", "Country of Origin", "Description", "Quantity", "Qty Unit",
        "Expiry Date", "Unit Price", "Gross Weight", "Net Weight", "Weight Unit", "Total",
    ]
    actual_row12 = [ws.cell(row=12, column=col).value for col in range(1, 17)]
    assert actual_row12 == expected_row12

    # 9. Line Item Row 13 Structure Check
    assert ws["M13"].value == snapshot.items[0].gross_weight_kg
    assert ws["N13"].value == snapshot.items[0].net_weight_kg
    assert ws["O13"].value == (snapshot.items[0].weight_unit or "KGM")
    assert ws["P13"].value == "=I13*L13"


# ============================================================================
# CGX-003: Multi-Path Extraction Engine Tests
# ============================================================================

from modules.cargox.service import CargoXExtractionEngine
from modules.cargox.schemas import ExtractionRequest, ExtractionResponse, CustomsInvoiceTrackCreate


def test_extraction_all_consolidated_mode(test_db):
    """
    Test all_consolidated mode:
    - يجب أن يُرجع result واحد فقط
    - بنود مجمعة بـ HS Code (سطر واحد لكل HS Code)
    - يطبق weighted average price
    """
    request = ExtractionRequest(mode="all_consolidated", grouping_mode="by_hs_code")
    response = CargoXExtractionEngine.extract(test_db, 1, request)

    assert response.import_file_id == 1
    assert response.mode == "all_consolidated"
    assert response.invoices_count == 1  # all modes → result واحد
    assert len(response.results) == 1

    payload = response.results[0].payload
    # كلا البندين بدون tariff → نفس HS Code الافتراضي "940310" → يتجمعوا في سطر واحد
    assert len(payload.items) == 1

    item = payload.items[0]
    assert item.hs_code == "940310"
    assert item.quantity == 30.0  # 10 + 20

    # Weighted Average Price: (10×300 + 20×100) / 30 = 5000 / 30 ≈ 166.6667
    expected_avg_price = round((10 * 300 + 20 * 100) / 30, 4)
    assert abs(item.unit_price - expected_avg_price) < 0.001

    # Total = 30 × 166.6667 ≈ 5000
    assert abs(item.total_amount - 5000.0) < 0.1
    assert abs(payload.subtotal - 5000.0) < 0.1


def test_extraction_all_detailed_mode(test_db):
    """
    Test all_detailed mode:
    - يجب أن يُرجع result واحد فقط
    - بنود مفصلة (كل سطر منفصل حتى لو نفس HS Code)
    """
    request = ExtractionRequest(mode="all_detailed", grouping_mode="by_hs_code")
    response = CargoXExtractionEngine.extract(test_db, 1, request)

    assert response.mode == "all_detailed"
    assert response.invoices_count == 1
    assert len(response.results) == 1

    payload = response.results[0].payload
    # detailed mode → flat → 2 بنود منفصلة
    assert len(payload.items) == 2

    # التحقق من الترتيب والكميات
    assert payload.items[0].quantity == 10.0
    assert payload.items[0].unit_price == 300.0
    assert payload.items[1].quantity == 20.0
    assert payload.items[1].unit_price == 100.0


def test_extraction_per_invoice_consolidated_mode(test_db):
    """
    Test per_invoice_consolidated mode:
    - كلا البندين لهم نفس invoice_number (PO-level)
    - يجب أن يُرجع result واحد (فاتورة واحدة) مجمع
    """
    request = ExtractionRequest(mode="per_invoice_consolidated", grouping_mode="by_hs_code")
    response = CargoXExtractionEngine.extract(test_db, 1, request)

    assert response.mode == "per_invoice_consolidated"
    # كلا البندين تحت نفس الـ PO وproforma_invoice_number → فاتورة واحدة
    assert response.invoices_count >= 1

    # كل ملف مجمع → 1 بند لكل HS Code
    for result in response.results:
        hs_codes_seen = set()
        for item in result.payload.items:
            assert item.hs_code not in hs_codes_seen, f"HS Code {item.hs_code} مكرر في consolidated mode!"
            hs_codes_seen.add(item.hs_code)


def test_extraction_per_invoice_detailed_mode(test_db):
    """
    Test per_invoice_detailed mode:
    - بنود مفصلة لكل فاتورة
    """
    request = ExtractionRequest(mode="per_invoice_detailed", grouping_mode="flat")
    response = CargoXExtractionEngine.extract(test_db, 1, request)

    assert response.mode == "per_invoice_detailed"
    assert response.invoices_count >= 1

    # التحقق أن كل البنود موجودة
    total_items = sum(len(r.payload.items) for r in response.results)
    assert total_items == 2  # DSK-001 + CHR-002


def test_weighted_average_price_calculation(test_db):
    """
    Test خوارزمية Weighted Average Price بدقة:
    100 PCS × $5 + 500 PCS × $7 = $4,000 / 600 = $6.6667
    """
    # نبني raw items مباشرة لاختبار الـ grouping logic
    raw_items = [
        {
            "item_code": "A001",
            "hs_code": "620000",
            "description": "Fabric Type A",
            "quantity": 100.0,
            "qty_unit": "PCS",
            "unit_price": 5.0,
            "country_of_origin": "CN",
            "gross_weight_kg": 50.0,
            "net_weight_kg": 45.0,
        },
        {
            "item_code": "A002",
            "hs_code": "620000",  # نفس HS Code — سيتم تجميعهم
            "description": "Fabric Type B",
            "quantity": 500.0,
            "qty_unit": "PCS",
            "unit_price": 7.0,
            "country_of_origin": "CN",
            "gross_weight_kg": 250.0,
            "net_weight_kg": 225.0,
        },
    ]

    items = CargoXExtractionEngine._group_items(raw_items, "by_hs_code", "all_consolidated")

    assert len(items) == 1, "يجب تجميع البندين في سطر واحد لنفس HS Code"
    item = items[0]

    # Weighted Average Price = (100×5 + 500×7) / (100+500) = 4000/600 ≈ 6.6667
    expected_price = round((100 * 5 + 500 * 7) / 600, 4)
    assert abs(item.unit_price - expected_price) < 0.0001

    # Total = 600 × 6.6667 = 4000
    assert item.quantity == 600.0
    assert abs(item.total_amount - 4000.0) < 0.1

    # Gross Weight = 50 + 250 = 300
    assert abs(item.gross_weight_kg - 300.0) < 0.01


def test_by_price_group_grouping(test_db):
    """
    Test by_price_group mode:
    نفس HS Code لكن أسعار مختلفة → سطرين منفصلين
    """
    raw_items = [
        {"item_code": "B001", "hs_code": "940310", "description": "Desk A", "quantity": 10.0, "qty_unit": "PCS", "unit_price": 200.0, "country_of_origin": "DE", "gross_weight_kg": 100.0, "net_weight_kg": 90.0},
        {"item_code": "B002", "hs_code": "940310", "description": "Desk B", "quantity": 5.0, "qty_unit": "PCS", "unit_price": 350.0, "country_of_origin": "DE", "gross_weight_kg": 60.0, "net_weight_kg": 55.0},
    ]

    # by_price_group → سطرين (أسعار مختلفة)
    items_grouped = CargoXExtractionEngine._group_items(raw_items, "by_price_group", "all_consolidated")
    assert len(items_grouped) == 2, "بالـ by_price_group يجب أن يكون 2 سطور لأن الأسعار مختلفة"

    # by_hs_code → سطر واحد مع weighted average
    items_consolidated = CargoXExtractionEngine._group_items(raw_items, "by_hs_code", "all_consolidated")
    assert len(items_consolidated) == 1, "بالـ by_hs_code يجب أن يكون سطر واحد"
    expected_avg = round((10 * 200 + 5 * 350) / 15, 4)
    assert abs(items_consolidated[0].unit_price - expected_avg) < 0.001


def test_extraction_response_structure(test_db):
    """
    Test هيكل الـ ExtractionResponse الكامل.
    """
    request = ExtractionRequest(mode="all_consolidated", grouping_mode="by_hs_code")
    response = CargoXExtractionEngine.extract(test_db, 1, request)

    # التحقق من هيكل الاستجابة
    assert isinstance(response, ExtractionResponse)
    assert response.import_file_id == 1
    assert response.import_file_code == "IMP-2026-009"
    assert response.invoices_count == len(response.results)
    assert response.total_line_items == sum(len(r.payload.items) for r in response.results)

    # كل result له payload صحيح
    for result in response.results:
        assert result.payload.acid_number == "7595528271020210010"
        assert result.payload.seller_name == "Narbutas International UAB"
        assert result.payload.currency_code == "EUR"
        assert len(result.payload.items) > 0


def test_zip_generation_multi_invoice(test_db):
    """
    Test توليد ZIP يحتوي على Excel files من محرك الاستخراج.
    """
    import io
    import zipfile as zipfile_module
    from modules.cargox.excel_invoice_service import generate_standard_invoice_excel_bytes

    request = ExtractionRequest(mode="all_consolidated", grouping_mode="by_hs_code")
    extraction = CargoXExtractionEngine.extract(test_db, 1, request)

    zip_buffer = io.BytesIO()
    with zipfile_module.ZipFile(zip_buffer, "w", zipfile_module.ZIP_DEFLATED) as zf:
        for result in extraction.results:
            excel_bytes = generate_standard_invoice_excel_bytes(result.payload)
            safe_inv = (result.invoice_number or "Invoice_default").replace("/", "-")
            filename = f"Commercial_Invoice_{safe_inv}.xlsx"
            zf.writestr(filename, excel_bytes)

    zip_buffer.seek(0)
    zip_data = zip_buffer.read()

    assert len(zip_data) > 100, "ZIP يجب أن يكون أكبر من 100 bytes"

    # التحقق من محتوى الـ ZIP
    zip_buffer.seek(0)
    with zipfile_module.ZipFile(zip_buffer, "r") as zf:
        file_list = zf.namelist()
        assert len(file_list) == extraction.invoices_count
        for fn in file_list:
            assert fn.endswith(".xlsx"), f"الملف {fn} يجب أن يكون .xlsx"


def test_customs_packing_list_generation_and_track_crud(test_db):
    """
    Test توليد شيت الباكينج ليست الجمركي وعمليات الـ CRUD وتصدير الإكسل للمسار الجمركي.
    """
    from modules.cargox.excel_invoice_service import generate_customs_packing_list_excel_bytes
    from modules.cargox.schemas import CustomsInvoiceTrackCreate, CustomsInvoiceTrackUpdate

    app.dependency_overrides[get_db] = lambda: test_db
    client = TestClient(app)

    # 1. Create Track
    req = CustomsInvoiceTrackCreate(
        import_file_id=1,
        extraction_mode="all_consolidated",
        grouping_mode="by_hs_code",
        notes="مسار تجريبي للباكينج ليست",
    )
    track = CargoXExtractionEngine.create_customs_track(test_db, req, created_by="TESTER")
    assert track.track_id is not None
    assert track.track_code.startswith("CX-CUST-")
    assert track.customs_packing_list_data is not None
    assert track.customs_packages_count > 0

    # 2. Test Packing List Excel Bytes Generation
    extraction = CargoXExtractionEngine.extract(test_db, 1, ExtractionRequest())
    payload = extraction.results[0].payload
    pl_bytes = generate_customs_packing_list_excel_bytes(payload, track_code=track.track_code)
    assert len(pl_bytes) > 500
    assert pl_bytes[:2] == b"PK"  # Valid ZIP/XLSX magic bytes

    # 3. Test Update Track via API
    res_up = client.put(
        f"/api/v1/cargox/customs-track/{track.track_id}",
        json={"status": "APPROVED", "notes": "تم الاعتماد الجمركي بنجاح"},
    )
    assert res_up.status_code == 200
    up_json = res_up.json()
    assert up_json["status"] == "APPROVED"
    assert up_json["notes"] == "تم الاعتماد الجمركي بنجاح"

    # 4. Test Export Invoice Excel via API
    res_inv_ex = client.get(f"/api/v1/cargox/customs-track/{track.track_id}/export-excel")
    assert res_inv_ex.status_code == 200
    assert len(res_inv_ex.content) > 1000

    # 5. Test Export Packing List Excel via API
    res_pl_ex = client.get(f"/api/v1/cargox/customs-track/{track.track_id}/export-packing-list-excel")
    assert res_pl_ex.status_code == 200
    assert len(res_pl_ex.content) > 1000

    # 6. Test Delete Track via API
    res_del = client.delete(f"/api/v1/cargox/customs-track/{track.track_id}")
    assert res_del.status_code == 200
    assert res_del.json()["status"] == "success"

    # Verify soft deletion in list
    res_list = client.get("/api/v1/cargox/customs-track/by-file/1")
    assert res_list.status_code == 200
    assert all(t["track_id"] != track.track_id for t in res_list.json())


def test_city_and_port_resolution_and_excel_cells(test_db):
    """
    Test UN/LOCODE City Code resolution, Origin & Destination Port resolution,
    and their exact cell coordinates, formulas, and defined names in generated Excel.
    """
    import io
    import openpyxl

    # 1. Test City Code Resolution
    # Changshu address example from user
    changshu_addr = "No.16 Kangsheng Road, Zhitang Town, Changshu City, Suzhou City,China"
    assert resolve_city_code(changshu_addr, "CN") == "CNCGS"

    # Lithuania Vilnius address
    assert resolve_city_code("Ukmerges g. 308, Vilnius", "LT") == "LTVNO"

    # Italy Milan address
    assert resolve_city_code("Via Monte Napoleone 8, Milan", "IT") == "ITMIL"

    # 2. Test Port Display Name Resolution
    pol_name = resolve_port_display_name("KRSEL")
    assert "Seoul" in pol_name
    assert "KOREA" in pol_name.upper()

    pod_name = resolve_port_display_name("EGALY")
    assert "Alexandria" in pod_name

    # 3. Test System Snapshot Generation includes city_code and port codes
    snapshot = CargoXStandardInvoiceService.build_system_snapshot(test_db, 1)
    assert snapshot.seller_city_code == "LTVNO"
    assert snapshot.origin_port == "LTKLJ"
    assert snapshot.destination_port == "EGALY"

    # 4. Test Excel Generation writes exact cells: F2, G7, H7:J7, G8, H8:J8
    excel_bytes = generate_standard_invoice_excel_bytes(snapshot)
    wb = openpyxl.load_workbook(io.BytesIO(excel_bytes), data_only=False)
    ws = wb["Invoice"]

    # F2: City Code
    assert ws["E2"].value == "City Code :"
    assert ws["F2"].value == "LTVNO"

    # F7 / G7 / H7: Origin Port
    assert ws["F7"].value == "Origin Port:"
    assert ws["G7"].value == "LTKLJ"
    assert "=IFERROR(VLOOKUP(G7,'City List'!$A$1:$C$34274,2,FALSE)&\"/\"&VLOOKUP(G7,'City List'!$A$1:$C$34274,3,FALSE)" in ws["H7"].value
    assert ws["H7"].font.bold is True

    # F8 / G8 / H8: Destination Port
    assert ws["F8"].value == "Destination Port:"
    assert ws["G8"].value == "EGALY"
    assert "=IFERROR(VLOOKUP(G8,'City List'!$A$1:$C$34274,2,FALSE)&\"/\"&VLOOKUP(G8,'City List'!$A$1:$C$34274,3,FALSE)" in ws["H8"].value
    assert ws["H8"].font.bold is True

    # PortCodes Defined Name Check
    assert "PortCodes" in wb.defined_names

    # 5. Parse back and verify seller_city_code and items weights are preserved
    parsed = parse_standard_invoice_excel_bytes(excel_bytes)
    assert parsed.seller_city_code == "LTVNO"
    assert parsed.origin_port == "LTKLJ"
    assert parsed.destination_port == "EGALY"
    assert len(parsed.items) > 0
    assert parsed.items[0].gross_weight_kg == snapshot.items[0].gross_weight_kg
    assert parsed.items[0].net_weight_kg == snapshot.items[0].net_weight_kg
    assert parsed.items[0].weight_unit == "KGM"


def test_weight_unit_uom_list_and_self_healing_extraction(test_db):
    """
    Tests:
    1. Normalization to official CargoX 'Unit of measure list' codes: GRM, KGM, SET, STN.
    2. Extraction of Gross Weight, Net Weight, and Weight Unit from packing list items for file 4.
    3. Proper writing of row 12 headers and row 13 data (M=Gross Weight, N=Net Weight, O=Weight Unit, P=Total).
    4. Self-healing parser handling files where columns were shifted (Carton in M, Gross in N, Net in O).
    """
    from modules.cargox.excel_invoice_service import (
        normalize_cargox_weight_unit,
        CARGOX_WEIGHT_UOMS,
    )
    from modules.cargox.service import CargoXExtractionEngine
    from modules.cargox.schemas import ExtractionRequest

    # 1. Normalization unit tests
    assert normalize_cargox_weight_unit("kg") == "KGM"
    assert normalize_cargox_weight_unit("KGS") == "KGM"
    assert normalize_cargox_weight_unit("kilogram") == "KGM"
    assert normalize_cargox_weight_unit("gram") == "GRM"
    assert normalize_cargox_weight_unit("g") == "GRM"
    assert normalize_cargox_weight_unit("ton") == "STN"
    assert normalize_cargox_weight_unit("MT") == "STN"
    assert normalize_cargox_weight_unit("set") == "SET"
    assert normalize_cargox_weight_unit(None) == "KGM"
    for code, name in CARGOX_WEIGHT_UOMS.items():
        assert normalize_cargox_weight_unit(code) == code

    # 2. Extract file 1 with PackingListItem
    from modules.purchase_orders.model import PackingListItem
    pl = PackingListItem(
        po_id=1,
        hs_code="940310",
        item_code="DSK-001",
        package_type="Carton",
        qty_pcs=10.0,
        qty_pkg=10.0,
        total_gross_weight_kg=10510.0,
        total_net_weight_kg=10080.0,
        weight_unit="KGM",
    )
    test_db.add(pl)
    test_db.commit()

    ext = CargoXExtractionEngine.extract(
        test_db, 1, ExtractionRequest(mode="all_consolidated", grouping_mode="by_hs_code")
    )
    assert len(ext.results) > 0
    payload = ext.results[0].payload
    assert payload.gross_weight == 10510.0
    assert payload.net_weight == 10080.0
    assert payload.weight_unit == "KGM"
    assert len(payload.items) > 0
    assert payload.items[0].gross_weight_kg == 10510.0
    assert payload.items[0].net_weight_kg == 10080.0
    assert payload.items[0].weight_unit == "KGM"

    # 3. Verify Excel workbook generated
    excel_bytes = generate_standard_invoice_excel_bytes(payload)
    wb = openpyxl.load_workbook(io.BytesIO(excel_bytes), data_only=False)
    ws = wb["Invoice"]

    # Header check
    assert ws["M12"].value == "Gross Weight"
    assert ws["N12"].value == "Net Weight"
    assert ws["O12"].value == "Weight Unit"
    assert ws["P12"].value == "Total"

    # Data check
    assert ws["M13"].value == 10510.0
    assert ws["N13"].value == 10080.0
    assert ws["O13"].value == "KGM"
    assert ws["P13"].value == "=I13*L13"
    assert ws["L7"].value == "KGM"

    # Verify UOM sheet
    assert "Unit of measure list" in wb.sheetnames
    ws_uom = wb["Unit of measure list"]
    assert ws_uom["A2"].value == "GRM"
    assert ws_uom["A3"].value == "KGM"
    assert ws_uom["A4"].value == "SET"
    assert ws_uom["A5"].value == "STN"

    # 4. Normal parsing of the newly generated workbook
    parsed_normal = parse_standard_invoice_excel_bytes(excel_bytes)
    assert parsed_normal.gross_weight == 10510.0
    assert parsed_normal.net_weight == 10080.0
    assert parsed_normal.weight_unit == "KGM"
    assert parsed_normal.items[0].gross_weight_kg == 10510.0
    assert parsed_normal.items[0].net_weight_kg == 10080.0
    assert parsed_normal.items[0].weight_unit == "KGM"

    # 5. Self-healing parser test: simulate a legacy shifted workbook
    # (where M13 was 'Carton', N13 was 10510.0, O13 was 10080.0, P13 was 43704.0)
    wb_shifted = openpyxl.load_workbook(io.BytesIO(excel_bytes), data_only=False)
    ws_s = wb_shifted["Invoice"]
    ws_s["M13"].value = "Carton"
    ws_s["N13"].value = 10510.0
    ws_s["O13"].value = 10080.0
    ws_s["P13"].value = 43704.0
    buf_s = io.BytesIO()
    wb_shifted.save(buf_s)

    parsed_shifted = parse_standard_invoice_excel_bytes(buf_s.getvalue())
    assert parsed_shifted.items[0].gross_weight_kg == 10510.0
    assert parsed_shifted.items[0].net_weight_kg == 10080.0
    assert parsed_shifted.items[0].weight_unit == "KGM"
    assert parsed_shifted.items[0].total_amount == 43704.0
    assert parsed_shifted.items[0].unit_price_basis == "Carton"


def test_cargox_po_invoice_date_qty_unit_and_main_description_extraction(test_db):
    """
    Verify:
    1. po.order_date (e.g., 2026-07-30) is propagated to invoice_date (E9 in Excel).
    2. pi.unit_of_measure (e.g., PCS) is propagated to qty_unit (J13 in Excel).
    3. pi.main_description (e.g., Acoustic Panels) is prioritized over detailed item descriptions (H13 in Excel).
    """
    from datetime import date
    from modules.purchase_orders.model import PurchaseOrder, POLineItem
    from modules.cargox.service import CargoXStandardInvoiceService, CargoXExtractionEngine
    from modules.cargox.schemas import ExtractionRequest
    from modules.cargox.excel_invoice_service import generate_standard_invoice_excel_bytes
    import io
    import openpyxl

    po = test_db.query(PurchaseOrder).filter(PurchaseOrder.po_id == 1).first()
    po.order_date = date(2026, 7, 30)

    # Set main_description and unit_of_measure on line items
    item1 = test_db.query(POLineItem).filter(POLineItem.item_code == "DSK-001").first()
    item1.main_description = "Acoustic Panels"
    item1.description_en = "PET Acoustic Panels (YH-652)"
    item1.unit_of_measure = "PCS"

    test_db.commit()

    # 1. System Snapshot verification
    snapshot = CargoXStandardInvoiceService.build_system_snapshot(test_db, 1)
    assert snapshot.invoice_date == "2026-07-30"
    matched_item = next(it for it in snapshot.items if it.product_code == "DSK-001")
    assert matched_item.description == "Acoustic Panels"
    assert matched_item.qty_unit == "PCS"

    # 2. Multi-path Extraction Engine verification
    ext_resp = CargoXExtractionEngine.extract(
        test_db, 1, ExtractionRequest(mode="all_consolidated", grouping_mode="by_hs_code")
    )
    assert len(ext_resp.results) == 1
    ext_payload = ext_resp.results[0].payload
    assert ext_payload.invoice_date == "2026-07-30"
    assert ext_payload.items[0].description == "Acoustic Panels"
    assert ext_payload.items[0].qty_unit == "PCS"

    # 3. Excel cell coordinates verification
    excel_bytes = generate_standard_invoice_excel_bytes(ext_payload)
    wb = openpyxl.load_workbook(io.BytesIO(excel_bytes), data_only=True)
    ws = wb["Invoice"]

    assert ws["E9"].value == "2026-07-30"  # Invoice Date
    assert ws["H13"].value == "Acoustic Panels"  # Description
    assert ws["J13"].value == "PCS"  # Qty Unit


def test_cgx_customs_guard_acoustic_panels_real_case():
    """
    CGX-CUSTOMS-COMPLIANCE: حالة الألواح الصوتية الحقيقية (YH-625 و YH-808)
    نفس بند التعريفة الجمركية HS Code (5602290000) ولكن بسعرين مختلفين:
      - YH-625: 400 PCS × $17.30 (ألواح 9mm)
      - YH-808: 1400 PCS × $23.50 (ألواح 12mm)

    المتطلبات الجمركية المصرية:
      1. الافتراضي في ExtractionRequest هو by_price_group لضمان الامتثال الجمركي
      2. عند التجميع المجمع (all_consolidated) بـ by_price_group:
         - لا يتم عمل متوسط سعر وهمي ($22.12 المرفوض جمركياً)
         - يتم إخراج سطرين منفصلين: كل صنف بسعره الحقيقي ومواصفاته
    """
    from modules.cargox.service import CargoXExtractionEngine
    from modules.cargox.schemas import ExtractionRequest

    # 1. التحقق من أن القيمة الافتراضية للطلب هي by_price_group لحماية الجمارك
    default_req = ExtractionRequest()
    assert default_req.grouping_mode == "by_price_group", "الافتراضي يجب أن يكون by_price_group للامتثال الجمركي"

    raw_items = [
        {
            "item_code": "YH-625",
            "hs_code": "5602290000",
            "description": "Acoustic Panel 9mm — Felt Board",
            "quantity": 400.0,
            "qty_unit": "PCS",
            "unit_price": 17.30,
            "country_of_origin": "CN",
            "gross_weight_kg": 480.0,
            "net_weight_kg": 440.0,
        },
        {
            "item_code": "YH-808",
            "hs_code": "5602290000",
            "description": "Acoustic Panel 12mm — Heavy Felt Board",
            "quantity": 1400.0,
            "qty_unit": "PCS",
            "unit_price": 23.50,
            "country_of_origin": "CN",
            "gross_weight_kg": 2800.0,
            "net_weight_kg": 2580.0,
        },
    ]

    # استخراج بنمط التجميع الجمركي المعتمد (by_price_group)
    items = CargoXExtractionEngine._group_items(raw_items, "by_price_group", "all_consolidated")

    # يجب أن ينتج سطرين منفصلين وليس سطراً مدمجاً بسعر متوسط
    assert len(items) == 2, f"يجب إخراج سطرين منفصلين ولكن تم استخراج {len(items)}"

    # التحقق من دقة الأسعار الحقيقية
    prices = {round(i.unit_price, 4) for i in items}
    assert 17.30 in prices, "السعر الحقيقي للبند YH-625 ($17.30) يجب أن يظهر كما هو"
    assert 23.50 in prices, "السعر الحقيقي للبند YH-808 ($23.50) يجب أن يظهر كما هو"

    # التحقق من عدم وجود المتوسط الموزون المرفوض جمركياً ($22.1222)
    WRONG_WEIGHTED_AVG = round((400 * 17.30 + 1400 * 23.50) / 1800, 4)
    for i in items:
        assert abs(i.unit_price - WRONG_WEIGHTED_AVG) > 0.01, "المتوسط الموزون غير مقبول جمركياً!"

    # التحقق من الكميات
    qtys = {round(i.quantity, 2) for i in items}
    assert 400.0 in qtys
    assert 1400.0 in qtys

def test_normalize_cargox_country_code_iso2():
    """Verify country of origin normalization to clean 2-letter uppercase ISO code."""
    from modules.cargox.excel_invoice_service import normalize_cargox_country_code

    assert normalize_cargox_country_code("CN - الصين (China)") == "CN"
    assert normalize_cargox_country_code("CN - China") == "CN"
    assert normalize_cargox_country_code("CN (China)") == "CN"
    assert normalize_cargox_country_code("DE - ألمانيا") == "DE"
    assert normalize_cargox_country_code("CN") == "CN"
    assert normalize_cargox_country_code("cn") == "CN"
    assert normalize_cargox_country_code("China") == "CN"
    assert normalize_cargox_country_code("الصين") == "CN"
    assert normalize_cargox_country_code("Italy") == "IT"
    assert normalize_cargox_country_code("China (CN)") == "CN"
    assert normalize_cargox_country_code("Germany (DE)") == "DE"


def test_normalize_cargox_country_code_never_invents_origin():
    """An empty or unrecognised origin must not be silently declared as China."""
    from modules.cargox.excel_invoice_service import normalize_cargox_country_code

    assert normalize_cargox_country_code("") == ""
    assert normalize_cargox_country_code(None) == ""
    assert normalize_cargox_country_code("Vietnam") == "VIETNAM"
    assert normalize_cargox_country_code("Netherlands") == "NETHERLANDS"
    assert normalize_cargox_country_code("Ukraine") == "UKRAINE"
    assert normalize_cargox_country_code("Indonesia") == "INDONESIA"


def test_build_system_snapshot_preserves_actual_po_weights(test_db):
    """
    Verify that when PO line items specify explicit gross and net weights,
    build_system_snapshot does NOT overwrite them with naive quantity-based proration!
    """
    snapshot = CargoXStandardInvoiceService.build_system_snapshot(test_db, 1)
    # Item 1: DSK-001 (10 pcs) was seeded with gross_weight_kg=250.0, net_weight_kg=220.0
    item1 = next(it for it in snapshot.items if it.product_code == "DSK-001")
    assert item1.gross_weight_kg == 250.0, "Actual line gross weight must be preserved"
    assert item1.net_weight_kg == 220.0, "Actual line net weight must be preserved"

    # Item 2: CHR-002 (20 pcs) was seeded with gross_weight_kg=200.0, net_weight_kg=180.0
    item2 = next(it for it in snapshot.items if it.product_code == "CHR-002")
    assert item2.gross_weight_kg == 200.0, "Actual line gross weight must be preserved"
    assert item2.net_weight_kg == 180.0, "Actual line net weight must be preserved"


def test_discrepancy_matrix_matches_split_price_groups_real_case(test_db):
    """
    Verify that comparing system snapshot against a supplier invoice with
    multiple price groups under the same HS code (YH-625 @ 17.30 and YH-808 @ 23.50)
    pairs items accurately and produces 0 false discrepancies!
    """
    # Build supplier payload with 2 lines sharing HS 5602290000 but different prices
    from modules.cargox.schemas import StandardInvoicePayload, StandardInvoiceLineItem
    from modules.cargox.excel_invoice_service import compare_standard_invoice_data

    sys_payload = StandardInvoicePayload(
        acid_number="5281534391025810014",
        seller_name="Suzhou Yuheng Textile Co.,Ltd",
        currency_code="USD",
        items=[
            StandardInvoiceLineItem(
                index=1,
                product_code="YH-625",
                hs_code="5602290000",
                description="Acoustic Panels 9mm",
                quantity=400.0,
                qty_unit="PCS",
                unit_price=17.30,
                gross_weight_kg=2480.0,
                net_weight_kg=2400.0,
                weight_unit="KGM",
                country_of_origin="CN",
                total_amount=6920.0,
            ),
            StandardInvoiceLineItem(
                index=2,
                product_code="YH-808",
                hs_code="5602290000",
                description="Acoustic Panels 12mm",
                quantity=1400.0,
                qty_unit="PCS",
                unit_price=23.50,
                gross_weight_kg=10360.0,
                net_weight_kg=10080.0,
                weight_unit="KGM",
                country_of_origin="CN",
                total_amount=32900.0,
            ),
        ],
        subtotal=39820.0,
        total_amount=39820.0,
    )

    # Supplier data matching exactly
    sup_payload = sys_payload.model_copy(deep=True)

    result = compare_standard_invoice_data(
        import_file_id=5,
        import_file_code="IMP-2026-0005",
        system_snapshot=sys_payload,
        supplier_data=sup_payload,
    )

    assert result.has_discrepancies is False
    assert result.has_critical_mismatch is False
    assert result.total_discrepancies_count == 0
    assert len(result.line_item_comparisons) == 2
    for row in result.line_item_comparisons:
        assert row.status == "MATCH"
        assert row.notes == "Perfect Match"

