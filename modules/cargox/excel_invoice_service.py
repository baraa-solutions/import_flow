"""
Standard Excel Commercial Invoice Service (BP-025 / CGX-002).
Generates authentic Excel Commercial Invoice workbooks (.xlsx) matching 100% with the official CargoX blank template:
- Exact 6 sheets: Invoice, Package Type list, Unit of measure list, Cities, Currency List, Country List.
- Exact Named Ranges (36+ defined names) matching official coordinate mapping.
- Merged B1:C2 Exporter Company Name.
- Calibri font exclusively, brown (#735223) labels, green (#77A337) headers, and hidden gridlines.
- Dynamic formulas preserved: =ROWS(InvoiceItems), =SUM(InvoiceItems[Total]), =I{r}*L{r}, and grand total.
- Exact literal labels without abbreviations or typo fixes (e.g. Weigh unitt:, Proforma invoice number:, Purchase Order #:).
"""

import io
import re
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional
import openpyxl
from openpyxl.styles import Font, Alignment, PatternFill, Border, Side
from openpyxl.worksheet.table import Table, TableStyleInfo
from openpyxl.workbook.defined_name import DefinedName

from modules.cargox.schemas import (
    StandardInvoicePayload,
    StandardInvoiceLineItem,
    StandardInvoiceComparisonResponse,
    StandardInvoiceComparisonRow,
    StandardInvoiceLineComparisonRow,
)
from modules.cargox.city_port_resolver import (
    resolve_city_code,
    resolve_port_display_name,
    resolve_port_code,
)


def _sanitize_str(val: Any) -> str:
    if val is None:
        return ""
    return str(val).strip()


def _safe_float(val: Any, default: float = 0.0) -> float:
    if val is None:
        return default
    if isinstance(val, (int, float)):
        return float(val)
    try:
        s = str(val).replace(",", "").replace("$", "").replace("€", "").replace("EGP", "").strip()
        return float(s)
    except (ValueError, TypeError):
        return default


def _is_numeric(val: Any) -> bool:
    if val is None:
        return False
    if isinstance(val, (int, float)):
        return True
    try:
        s = str(val).replace(",", "").replace("$", "").replace("€", "").replace("EGP", "").strip()
        if not s:
            return False
        float(s)
        return True
    except (ValueError, TypeError):
        return False


CARGOX_WEIGHT_UOMS = {
    "GRM": "gram",
    "KGM": "kilogram",
    "SET": "set",
    "STN": "ton (US) or short ton (UK/US)",
}


def normalize_cargox_weight_unit(val: Optional[str]) -> str:
    """
    Normalizes any weight unit string to one of the 4 official
    CargoX 'Unit of measure list' Common Codes: GRM, KGM, SET, STN.
    """
    if not val:
        return "KGM"
    clean = str(val).strip().upper()
    if clean in ("KGM", "KG", "KGS", "KILOGRAM", "KILOGRAMS", "كجم", "كيلو", "كيلوجرام", "كيلوغرام"):
        return "KGM"
    if clean in ("GRM", "G", "GM", "GMS", "GRAM", "GRAMS", "جرام", "غرام"):
        return "GRM"
    if clean in ("STN", "TON", "TONS", "T", "MT", "طن"):
        return "STN"
    if clean in ("SET", "SETS", "طقم", "مجموعة"):
        return "SET"
    if clean in CARGOX_WEIGHT_UOMS:
        return clean
    return "KGM"


# ─────────────────────────────────────────────────────────────────────────────
# Reference Data Definitions for Data Validation Sheets (2 to 6)
# ─────────────────────────────────────────────────────────────────────────────

PACKAGE_TYPES_LIST = [
    ("B4", "Belt"),
    ("BD", "Board"),
    ("BE", "Bundle"),
    ("BG", "Bag"),
    ("BK", "Basket"),
    ("BL", "Bale, compressed"),
    ("BX", "Box"),
    ("CA", "Can, rectangular"),
    ("CH", "Chest"),
    ("CL", "Coil"),
    ("CR", "Crate"),
    ("CT", "Carton"),
    ("DR", "Drum"),
    ("PF", "Pen"),
    ("PG", "Plate"),
    ("PK", "Package"),
    ("PL", "Pail"),
    ("PR", "Receptacle, plastic"),
    ("RL", "Reel"),
    ("RO", "Roll"),
    ("TN", "Tin"),
    ("VQ", "Bulk, liquefied gas (at abnormal temperature/pressure)"),
]

UOM_LIST = [
    ("GRM", "gram"),
    ("KGM", "kilogram"),
    ("SET", "set"),
    ("STN", "ton (US) or short ton (UK/US)"),
]

CITIES_LIST = [
    ("EGALY", "Alexandria"),
    ("EGCAI", "Cairo"),
    ("EGPSD", "Port Said"),
    ("EGDAM", "Damietta"),
    ("EGSUZ", "Suez"),
    ("EGAIS", "Ain Sokhna"),
    ("CNSHA", "Shanghai"),
    ("CNNGB", "Ningbo"),
    ("CNSZX", "Shenzhen"),
    ("CNCAN", "Guangzhou"),
    ("CNYIW", "Yiwu"),
    ("CNTAO", "Qingdao"),
    ("CNTSN", "Tianjin"),
    ("CNXMN", "Xiamen"),
    ("HKHKG", "Hong Kong"),
    ("NLRTM", "Rotterdam"),
    ("DEHAM", "Hamburg"),
    ("BEANR", "Antwerp"),
    ("ITGOA", "Genoa"),
    ("ESVLC", "Valencia"),
    ("TRIST", "Istanbul"),
    ("AEJEA", "Jebel Ali"),
    ("SADMM", "Dammam"),
    ("SAJED", "Jeddah"),
    ("SGSIN", "Singapore"),
    ("USLAX", "Los Angeles"),
    ("USNYC", "New York"),
    ("LTKLJ", "Klaipeda"),
    ("ITMIL", "Milan"),
    ("ITROM", "Rome"),
    ("FRLEH", "Le Havre"),
    ("FRMRS", "Marseille"),
    ("GBFXT", "Felixstowe"),
    ("GBLON", "London"),
    ("JPTYO", "Tokyo"),
    ("JPYOK", "Yokohama"),
    ("KRPUS", "Busan"),
    ("KRINC", "Incheon"),
    ("INNSA", "Nhava Sheva"),
    ("INBOM", "Mumbai"),
    ("THBKK", "Bangkok"),
    ("MYPKG", "Port Klang"),
    ("VNSGN", "Ho Chi Minh City"),
    ("VNVDG", "Da Nang"),
    ("GRPIR", "Piraeus"),
    ("KWKWI", "Kuwait"),
    ("QAHMD", "Hamad Port"),
    ("OMMCT", "Muscat"),
    ("JOAQB", "Aqaba"),
    ("LBBEY", "Beirut"),
]

CURRENCIES_LIST = [
    ("Euro", "EUR"),
    ("US Dollar", "USD"),
    ("Egyptian Pound", "EGP"),
    ("Yuan Renminbi", "CNY"),
    ("Pound Sterling", "GBP"),
    ("Yen", "JPY"),
    ("Swiss Franc", "CHF"),
    ("UAE Dirham", "AED"),
    ("Saudi Riyal", "SAR"),
    ("Kuwaiti Dinar", "KWD"),
    ("Canadian Dollar", "CAD"),
    ("Australian Dollar", "AUD"),
    ("Turkish Lira", "TRY"),
    ("Russian Ruble", "RUB"),
    ("Indian Rupee", "INR"),
    ("Swedish Krona", "SEK"),
    ("Norwegian Krone", "NOK"),
    ("Danish Krone", "DKK"),
    ("Singapore Dollar", "SGD"),
]

# Note: Preserving authentic CargoX country spelling quirks (e.g. BAHRIN., PAKISTan., KAZAKSTAN.)
COUNTRIES_LIST = [
    ("EG", "EGYPT."),
    ("CN", "CHINA."),
    ("IT", "ITALY."),
    ("DE", "GERMANY."),
    ("FR", "FRANCE."),
    ("ES", "SPAIN."),
    ("TR", "TURKEY."),
    ("US", "UNITED STATES."),
    ("GB", "UNITED KINGDOM."),
    ("AE", "UNITED ARAB EMIRATES."),
    ("SA", "SAUDI ARABIA."),
    ("LT", "LITHUANIA."),
    ("PL", "POLAND."),
    ("NL", "NETHERLANDS."),
    ("BE", "BELGIUM."),
    ("IN", "INDIA."),
    ("JP", "JAPAN."),
    ("KR", "KOREA, REPUBLIC OF."),
    ("RU", "RUSSIAN FEDERATION."),
    ("BR", "BRAZIL."),
    ("VN", "VIET NAM."),
    ("TH", "THAILAND."),
    ("MY", "MALAYSIA."),
    ("ID", "INDONESIA."),
    ("BH", "BAHRIN."),
    ("PK", "PAKISTan."),
    ("KZ", "KAZAKSTAN."),
    ("GR", "GREECE."),
    ("KW", "KUWAIT."),
    ("QA", "QATAR."),
    ("OM", "OMAN."),
    ("JO", "JORDAN."),
    ("LB", "LEBANON."),
    ("CH", "SWITZERLAND."),
    ("AT", "AUSTRIA."),
    ("SE", "SWEDEN."),
    ("NO", "NORWAY."),
    ("DK", "DENMARK."),
    ("FI", "FINLAND."),
    ("CZ", "CZECH REPUBLIC."),
    ("HU", "HUNGARY."),
    ("RO", "ROMANIA."),
    ("BG", "BULGARIA."),
    ("PT", "PORTUGAL."),
    ("IE", "IRELAND."),
    ("MX", "MEXICO."),
    ("CA", "CANADA."),
    ("ZA", "SOUTH AFRICA."),
    ("AU", "AUSTRALIA."),
    ("NZ", "NEW ZEALAND."),
]


import os

TEMPLATE_PATH = os.path.join(os.path.dirname(__file__), "templates", "cargox_invoice_template.xlsx")


def generate_standard_invoice_excel_bytes(payload: StandardInvoicePayload) -> bytes:
    """
    Generates an authentic Excel Commercial Invoice workbook (.xlsx) matching 100% with the official CargoX template.
    Loads the official 8-sheet master template with full reference lists (112k cities, 169 currencies, 244 countries, etc.),
    all 10 merged cell ranges, 18pt title, exact Named Ranges, and dynamic table formulas.
    """
    if os.path.exists(TEMPLATE_PATH):
        wb = openpyxl.load_workbook(TEMPLATE_PATH, data_only=False)
        ws = wb["Invoice"] if "Invoice" in wb.sheetnames else wb.active

        # Ensure gridlines hidden
        if ws.views.sheetView:
            ws.views.sheetView[0].showGridLines = False

        # Exporter / Seller Block
        ws["B1"].value = payload.seller_name or "Foreign Exporter Name"
        ws["D1"].value = payload.seller_address or ""
        ws["F1"].value = payload.seller_tax_id or ""
        city_code = payload.seller_city_code or resolve_city_code(
            payload.seller_address, payload.seller_country_code, payload.seller_city
        )
        ws["F2"].value = city_code
        ws["I2"].value = payload.seller_phone or ""
        ws["D3"].value = payload.seller_city or ""
        ws["F3"].value = payload.seller_website or ""
        ws["I3"].value = payload.seller_fax or ""
        ws["E4"].value = payload.seller_contact_name or ""
        ws["F4"].value = payload.seller_email or ""

        # Title & Divider
        ws["B3"].value = payload.invoice_type or "Commercial Invoice"

        # Importer / Buyer Block
        ws["C5"].value = payload.buyer_name or "Egyptian Importing Company"
        ws["E5"].value = payload.buyer_contact_name or ""
        ws["F5"].value = payload.buyer_email or ""
        ws["I5"].value = payload.buyer_phone or ""
        ws["C6"].value = payload.buyer_address or ""
        ws["I6"].value = payload.buyer_fax or ""
        ws["C7"].value = payload.buyer_tax_id or "123456789"
        ws["E7"].value = payload.acid_number or "PENDING"
        pol_code = resolve_port_code(payload.origin_port, default_code="CNSHA")
        ws["G7"].value = pol_code
        origin_display = resolve_port_display_name(pol_code)
        safe_orig_disp = origin_display.replace('"', '""')
        ws["H7"].value = f"=IFERROR(VLOOKUP(G7,'City List'!$A$1:$C$34274,2,FALSE)&\"/\"&VLOOKUP(G7,'City List'!$A$1:$C$34274,3,FALSE),\"{safe_orig_disp}\")"
        ws["H7"].font = Font(name="Calibri", size=11, bold=True, color="735223")
        ws["H7"].alignment = Alignment(horizontal="left", vertical="center")

        # Metadata & Dates
        ws["C8"].value = payload.purchase_order_number or ""
        ws["E8"].value = payload.purchase_order_date or ""
        pod_code = resolve_port_code(payload.destination_port or "EGALY", default_code="EGALY")
        ws["G8"].value = pod_code
        dest_display = resolve_port_display_name(pod_code)
        safe_dest_disp = dest_display.replace('"', '""')
        ws["H8"].value = f"=IFERROR(VLOOKUP(G8,'City List'!$A$1:$C$34274,2,FALSE)&\"/\"&VLOOKUP(G8,'City List'!$A$1:$C$34274,3,FALSE),\"{safe_dest_disp}\")"
        ws["H8"].font = Font(name="Calibri", size=11, bold=True, color="735223")
        ws["H8"].alignment = Alignment(horizontal="left", vertical="center")

        if "PortCodes" not in wb.defined_names:
            wb.defined_names.add(DefinedName("PortCodes", attr_text="'City List'!$A$2:$A$34274"))

        ws["C9"].value = payload.invoice_number or "INV-2026-001"
        ws["E9"].value = payload.invoice_date or "2026-08-21"
        ws["C10"].value = payload.currency_code or "EUR"
        ws["E10"].value = payload.incoterm or "EXW"

        # Weights & Proforma Header Block
        ws["K4"].value = "Proforma invoice number:"
        ws["L4"].value = payload.proforma_invoice_number or ""
        ws["K5"].value = "Gross Weight:"
        ws["L5"].value = "=SUM(InvoiceItems[Gross Weight])"
        ws["L5"].number_format = "#,##0.00"
        ws["K6"].value = "Net Weight:"
        ws["L6"].value = "=SUM(InvoiceItems[Net Weight])"
        ws["L6"].number_format = "#,##0.00"
        ws["K7"].value = "Weight Unit:"

        # Populate Items in Table
        items = payload.items or [
            StandardInvoiceLineItem(
                index=1,
                product_code="ITEM-001",
                manufacturer=payload.seller_name or "Manufacturer",
                brand_name="Standard",
                model="Model-A",
                hs_code="940310",
                country_of_origin=payload.seller_country_code or "IT",
                description="Standard Commercial Goods",
                quantity=10.0,
                qty_unit="SET",
                expiry_date="",
                unit_price=250.0,
                unit_price_basis="SET",
                gross_weight_kg=120.0,
                net_weight_kg=110.0,
                weight_unit="KGM",
                total_amount=2500.0,
            )
        ]

        primary_uom = "KGM"
        for it in items:
            if getattr(it, "weight_unit", None):
                primary_uom = it.weight_unit
                break
        if not primary_uom and payload.weight_unit:
            primary_uom = payload.weight_unit
        ws["L7"].value = normalize_cargox_weight_unit(primary_uom)

        # 1. Unmerge old totals cell ranges before shifting
        for mr in ["B18:J18", "B20:J20"]:
            if mr in [str(x) for x in ws.merged_cells.ranges]:
                ws.unmerge_cells(mr)

        num_items = len(items)
        if num_items > 3:
            ws.insert_rows(16, amount=num_items - 3)
        elif num_items < 3:
            ws.delete_rows(13 + num_items, amount=3 - num_items)

        # 2. Clear item rows
        for r in range(13, 13 + num_items):
            for c in range(1, 17):
                ws.cell(row=r, column=c).value = None

        thin_border = Border(
            left=Side(style="thin", color="D3D3D3"),
            right=Side(style="thin", color="D3D3D3"),
            top=Side(style="thin", color="D3D3D3"),
            bottom=Side(style="thin", color="D3D3D3"),
        )
        zebra_fill = PatternFill(start_color="F2F2F2", end_color="F2F2F2", fill_type="solid")
        white_fill = PatternFill(start_color="FFFFFF", end_color="FFFFFF", fill_type="solid")

        # Column widths & header height
        col_widths = {
            "A": 8.3, "B": 16.3, "C": 35.5, "D": 31.7, "E": 25.7, "F": 16.3,
            "G": 13.0, "H": 30.0, "I": 19.0, "J": 14.3, "K": 25.0, "L": 17.3,
            "M": 21.9, "N": 13.0, "O": 16.6, "P": 21.3,
        }
        for col_letter, width in col_widths.items():
            ws.column_dimensions[col_letter].width = width

        ws.row_dimensions[12].height = 30.0

        table_headers = [
            "#", "Product Code", "TradeMarkOwner/Manufacturer", "Brand Name", "Model",
            "HS Tariff Code", "Country of Origin", "Description", "Quantity", "Qty Unit",
            "Expiry Date", "Unit Price", "Gross Weight", "Net Weight", "Weight Unit", "Total",
        ]
        for col_idx, h in enumerate(table_headers, 1):
            cl = openpyxl.utils.get_column_letter(col_idx)
            ws[f"{cl}12"].value = h
            ws[f"{cl}12"].font = Font(name="Calibri", size=10, bold=True, color="735223")

        current_row = 13
        for idx, item in enumerate(items, 1):
            r = current_row
            ws.row_dimensions[r].height = 28.0
            fill = zebra_fill if idx % 2 == 0 else white_fill

            ws[f"A{r}"] = item.index
            ws[f"B{r}"] = item.product_code or ""
            ws[f"C{r}"] = item.manufacturer or ""
            ws[f"D{r}"] = item.brand_name or ""
            ws[f"E{r}"] = item.model or ""
            ws[f"F{r}"] = item.hs_code
            ws[f"G{r}"] = item.country_of_origin
            ws[f"H{r}"] = item.description
            ws[f"I{r}"] = item.quantity
            ws[f"J{r}"] = item.qty_unit
            ws[f"K{r}"] = item.expiry_date or ""
            ws[f"L{r}"] = item.unit_price
            ws[f"M{r}"] = item.gross_weight_kg
            ws[f"N{r}"] = item.net_weight_kg
            ws[f"O{r}"] = normalize_cargox_weight_unit(getattr(item, "weight_unit", None) or payload.weight_unit)
            ws[f"P{r}"] = f"=I{r}*L{r}"

            alignments = {
                "A": Alignment(horizontal="center", vertical="center"),
                "B": Alignment(horizontal="left", vertical="center"),
                "C": Alignment(horizontal="center", vertical="center"),
                "D": Alignment(horizontal="center", vertical="center"),
                "E": Alignment(horizontal="left", vertical="center"),
                "F": Alignment(horizontal="center", vertical="center"),
                "G": Alignment(horizontal="center", vertical="center"),
                "H": Alignment(horizontal="left", vertical="center", wrap_text=True),
                "I": Alignment(horizontal="center", vertical="center"),
                "J": Alignment(horizontal="center", vertical="center"),
                "K": Alignment(horizontal="center", vertical="center"),
                "L": Alignment(horizontal="right", vertical="center"),
                "M": Alignment(horizontal="right", vertical="center"),
                "N": Alignment(horizontal="right", vertical="center"),
                "O": Alignment(horizontal="center", vertical="center"),
                "P": Alignment(horizontal="right", vertical="center"),
            }

            num_formats = {
                "A": "0", "I": "#,##0.00", "L": "#,##0.00", "M": "#,##0.00", "N": "#,##0.00", "O": "@", "P": "#,##0.00"
            }

            for c in range(1, 17):
                cl = openpyxl.utils.get_column_letter(c)
                cell = ws[f"{cl}{r}"]
                cell.font = Font(name="Calibri", size=10, bold=(cl == "A" or cl == "P"))
                cell.alignment = alignments.get(cl, Alignment(horizontal="center", vertical="center"))
                if cl in num_formats:
                    cell.number_format = num_formats[cl]
                cell.border = thin_border
                cell.fill = fill

            current_row += 1

        end_row = 12 + num_items
        if "InvoiceItems" in ws.tables:
            ws.tables["InvoiceItems"].ref = f"A12:P{end_row}"
            if ws.tables["InvoiceItems"].autoFilter:
                ws.tables["InvoiceItems"].autoFilter.ref = f"A12:P{end_row}"
            for c_idx, col in enumerate(ws.tables["InvoiceItems"].tableColumns):
                if c_idx < len(table_headers):
                    col.name = table_headers[c_idx]


        totals_start_row = 13 + num_items
        # 5. Re-merge new totals rows
        ws.merge_cells(f"B{totals_start_row+2}:J{totals_start_row+2}")
        ws.merge_cells(f"B{totals_start_row+4}:J{totals_start_row+4}")

        brown_bold_font = Font(name="Calibri", size=11, bold=True, color="735223")
        bold_val_font = Font(name="Calibri", size=11, bold=True, color="000000")
        reg_val_font = Font(name="Calibri", size=11, bold=False, color="000000")

        for r_tot in range(totals_start_row, totals_start_row + 5):
            ws.row_dimensions[r_tot].height = 30.0

        # 6. Set Totals with Structured Dynamic References
        ws[f"B{totals_start_row}"].value = "Lines #:"
        ws[f"B{totals_start_row}"].font = brown_bold_font
        ws[f"B{totals_start_row}"].alignment = Alignment(horizontal="right", vertical="center")

        ws[f"C{totals_start_row}"].value = "=ROWS(InvoiceItems[])"
        ws[f"C{totals_start_row}"].font = bold_val_font
        ws[f"C{totals_start_row}"].alignment = Alignment(horizontal="center", vertical="center")

        ws["H11"].value = "=ROWS(InvoiceItems[])"
        ws["H11"].font = bold_val_font

        ws[f"O{totals_start_row}"].value = "Invoice Subtotal"
        ws[f"O{totals_start_row}"].font = brown_bold_font
        ws[f"O{totals_start_row}"].alignment = Alignment(horizontal="right", vertical="center")

        ws[f"P{totals_start_row}"].value = "=SUM(InvoiceItems[Total])"
        ws[f"P{totals_start_row}"].font = bold_val_font
        ws[f"P{totals_start_row}"].number_format = "#,##0.00"
        ws[f"P{totals_start_row}"].alignment = Alignment(horizontal="right", vertical="center")

        ws[f"O{totals_start_row+1}"].value = "Freight Cost"
        ws[f"O{totals_start_row+1}"].font = brown_bold_font
        ws[f"O{totals_start_row+1}"].alignment = Alignment(horizontal="right", vertical="center")

        ws[f"P{totals_start_row+1}"].value = payload.freight_cost or 0.0
        ws[f"P{totals_start_row+1}"].font = reg_val_font
        ws[f"P{totals_start_row+1}"].number_format = "#,##0.00"
        ws[f"P{totals_start_row+1}"].alignment = Alignment(horizontal="right", vertical="center")

        ws[f"O{totals_start_row+2}"].value = "Insurance Cost"
        ws[f"O{totals_start_row+2}"].font = brown_bold_font
        ws[f"O{totals_start_row+2}"].alignment = Alignment(horizontal="right", vertical="center")

        ws[f"P{totals_start_row+2}"].value = payload.insurance_cost or 0.0
        ws[f"P{totals_start_row+2}"].font = reg_val_font
        ws[f"P{totals_start_row+2}"].number_format = "#,##0.00"
        ws[f"P{totals_start_row+2}"].alignment = Alignment(horizontal="right", vertical="center")

        ws[f"O{totals_start_row+3}"].value = "Other Costs"
        ws[f"O{totals_start_row+3}"].font = brown_bold_font
        ws[f"O{totals_start_row+3}"].alignment = Alignment(horizontal="right", vertical="center")

        ws[f"P{totals_start_row+3}"].value = payload.other_costs or 0.0
        ws[f"P{totals_start_row+3}"].font = reg_val_font
        ws[f"P{totals_start_row+3}"].number_format = "#,##0.00"
        ws[f"P{totals_start_row+3}"].alignment = Alignment(horizontal="right", vertical="center")

        ws[f"O{totals_start_row+4}"].value = "Total"
        ws[f"O{totals_start_row+4}"].font = brown_bold_font
        ws[f"O{totals_start_row+4}"].alignment = Alignment(horizontal="right", vertical="center")

        ws[f"P{totals_start_row+4}"].value = "=InvoiceSubtotal+FreightCost+InsuranceCost+OtherCosts"
        ws[f"P{totals_start_row+4}"].font = bold_val_font
        ws[f"P{totals_start_row+4}"].number_format = "#,##0.00"
        ws[f"P{totals_start_row+4}"].alignment = Alignment(horizontal="right", vertical="center")

        # 7. Upsert DefinedNames — delete first if already present in template to avoid duplicates
        _defined_names_to_set = {
            "TotalInvoiceLinesNo": f"'{ws.title}'!$C${totals_start_row}",
            "InvoiceSubtotal":     f"'{ws.title}'!$P${totals_start_row}",
            "FreightCost":         f"'{ws.title}'!$P${totals_start_row+1}",
            "InsuranceCost":       f"'{ws.title}'!$P${totals_start_row+2}",
            "OtherCosts":          f"'{ws.title}'!$P${totals_start_row+3}",
            "TotalAmount":         f"'{ws.title}'!$P${totals_start_row+4}",
            "GrossWeight":         f"'{ws.title}'!$L$5",
            "NetWeight":           f"'{ws.title}'!$L$6",
            "WeightUnit":          f"'{ws.title}'!$L$7",
            "ProformaInvoiceNumber": f"'{ws.title}'!$L$4",
            "OriginPort":          f"'{ws.title}'!$G$7",
            "DestinationPort":     f"'{ws.title}'!$G$8",
        }
        for _dn_name, _dn_ref in _defined_names_to_set.items():
            if _dn_name in wb.defined_names:
                del wb.defined_names[_dn_name]
            wb.defined_names[_dn_name] = DefinedName(_dn_name, attr_text=_dn_ref)

        output = io.BytesIO()
        wb.save(output)
        return output.getvalue()


    # Programmatic full fallback
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Invoice"
    ws.views.sheetView[0].showGridLines = False

    brown_label_font = Font(name="Calibri", size=11, bold=False, color="735223")
    brown_bold_font = Font(name="Calibri", size=11, bold=True, color="735223")
    title_green_font = Font(name="Calibri", size=18, bold=True, color="77A337")
    regular_val_font = Font(name="Calibri", size=11, color="000000")
    bold_val_font = Font(name="Calibri", size=11, bold=True, color="000000")
    bold_seller_font = Font(name="Calibri", size=14, bold=True, color="000000")

    divider_green_border = Border(
        left=Side(style="medium", color="77A337"),
        right=Side(style=None),
        top=Side(style=None),
        bottom=Side(style=None),
    )

    # 10 Merged cell ranges in Invoice
    ws.merge_cells("B1:C2")
    ws.merge_cells("B3:C3")
    ws.merge_cells("D1:D2")
    ws.merge_cells("F3:G3")
    ws.merge_cells("F4:G4")
    ws.merge_cells("F5:G5")
    ws.merge_cells("H7:J7")
    ws.merge_cells("H8:J8")
    ws.merge_cells("B18:J18")
    ws.merge_cells("B20:J20")

    ws["B1"].value = payload.seller_name or "Foreign Exporter Name"
    ws["B1"].font = bold_seller_font
    ws["B1"].alignment = Alignment(vertical="top", horizontal="left", wrap_text=True)

    ws["B3"].value = payload.invoice_type or "Commercial Invoice"
    ws["B3"].font = title_green_font
    ws["B3"].alignment = Alignment(vertical="center", horizontal="left")

    ws["D3"].value = "INVOICE"
    ws["D3"].font = brown_bold_font
    ws["D3"].alignment = Alignment(vertical="center", horizontal="left")
    ws["D1"].border = divider_green_border
    ws["D2"].border = divider_green_border
    ws["D3"].border = divider_green_border

    labels = {
        "E1": "Registration # :",
        "E2": "City Code :",
        "H2": "Phone:",
        "E3": "Web Site :",
        "H3": "Fax:",
        "D4": "Exporter Contact :",
        "B5": "Export To:",
        "D5": "Importer Contact :",
        "H5": "Phone:",
        "K5": "Gross Weight",
        "B6": " Address:",
        "H6": "Fax:",
        "K6": "Net Weight: ",
        "B7": "Egypt Tax Code :",
        "D7": "ACID #:",
        "F7": "Origin Port:",
        "K7": "Weigh unitt:",
        "B8": "Purchase Order #:",
        "D8": "Purchase Order Date:",
        "F8": "Destination Port:",
        "B9": "Invoice #:",
        "D9": "Invoice Date:",
        "B10": "Currency:",
        "D10": "Inco Term:",
        "K4": "Proforma invoice number:",
    }

    for cell_pos, label_text in labels.items():
        cell = ws[cell_pos]
        cell.value = label_text
        cell.font = brown_label_font

    ws["L7"] = "KG"
    ws["L7"].font = brown_bold_font

    city_code = payload.seller_city_code or resolve_city_code(
        payload.seller_address, payload.seller_country_code, payload.seller_city
    )

    pol_code = resolve_port_code(payload.origin_port, default_code="CNSHA")
    pod_code = resolve_port_code(payload.destination_port or "EGALY", default_code="EGALY")

    named_range_mapping = {
        "SellerName": ("B1", payload.seller_name or "Foreign Exporter Name"),
        "SellerAddress": ("D1", payload.seller_address or ""),
        "SellerRegistrationCode": ("F1", payload.seller_tax_id or "VAT/TAX ID"),
        "SellerCode": ("F1", payload.seller_tax_id or "VAT/TAX ID"),
        "SellerCountryCode": ("F2", city_code),
        "SellerPhone": ("I2", payload.seller_phone or ""),
        "SellerCity": ("D3", payload.seller_city or ""),
        "SellerFax": ("I3", payload.seller_fax or ""),
        "SellerWebSite": ("F3", payload.seller_website or ""),
        "SellerContactName": ("E4", payload.seller_contact_name or ""),
        "SellerContactEmail": ("F4", payload.seller_email or ""),
        "BuyerName": ("C5", payload.buyer_name or "Egyptian Importing Company"),
        "BuyerContactName": ("E5", payload.buyer_contact_name or ""),
        "BuyerContactEmail": ("F5", payload.buyer_email or ""),
        "BuyerPhone": ("I5", payload.buyer_phone or ""),
        "BuyerAddress": ("C6", payload.buyer_address or ""),
        "BuyerFax": ("I6", payload.buyer_fax or ""),
        "BuyerCode": ("C7", payload.buyer_tax_id or "123456789"),
        "ACIDNumber": ("E7", payload.acid_number or "PENDING"),
        "InvoiceType": ("B3", payload.invoice_type or "Commercial Invoice"),
        "PurchaseOrderNumber": ("C8", payload.purchase_order_number or ""),
        "PurchaseOrderDate": ("E8", payload.purchase_order_date or ""),
        "InvoiceNumber": ("C9", payload.invoice_number or "INV-2026-001"),
        "InvoiceDate": ("E9", payload.invoice_date or "2026-08-21"),
        "CurrencyCode": ("C10", payload.currency_code or "EUR"),
        "IncoTerm": ("E10", payload.incoterm or "EXW"),
        "ProformaInvoiceNumber": ("L4", payload.proforma_invoice_number or ""),
        "GrossWeight": ("L5", "=SUM(InvoiceItems[Gross Weight])"),
        "NetWeight": ("L6", "=SUM(InvoiceItems[Net Weight])"),
        "WeightUnit": ("L7", normalize_cargox_weight_unit(payload.weight_unit)),
        "OriginPort": ("G7", pol_code),
        "DestinationPort": ("G8", pod_code),
    }

    for name, (cell_coord, val) in named_range_mapping.items():
        cell = ws[cell_coord]
        if cell_coord not in ("B1", "B3"):
            cell.value = val
            cell.font = regular_val_font
        wb.defined_names.add(DefinedName(name, attr_text=f"'{ws.title}'!${cell_coord[0]}${cell_coord[1:]}"))

    origin_display = resolve_port_display_name(pol_code)
    safe_orig_disp = origin_display.replace('"', '""')
    ws["H7"].value = f"=IFERROR(VLOOKUP(G7,'City List'!$A$1:$C$34274,2,FALSE)&\"/\"&VLOOKUP(G7,'City List'!$A$1:$C$34274,3,FALSE),\"{safe_orig_disp}\")"
    ws["H7"].font = brown_bold_font
    ws["H7"].alignment = Alignment(horizontal="left", vertical="center")

    dest_display = resolve_port_display_name(pod_code)
    safe_dest_disp = dest_display.replace('"', '""')
    ws["H8"].value = f"=IFERROR(VLOOKUP(G8,'City List'!$A$1:$C$34274,2,FALSE)&\"/\"&VLOOKUP(G8,'City List'!$A$1:$C$34274,3,FALSE),\"{safe_dest_disp}\")"
    ws["H8"].font = brown_bold_font
    ws["H8"].alignment = Alignment(horizontal="left", vertical="center")

    if "PortCodes" not in wb.defined_names:
        wb.defined_names.add(DefinedName("PortCodes", attr_text="'City List'!$A$2:$A$34274"))

    ws["H11"] = "=ROWS(InvoiceItems[])"
    ws["H11"].font = brown_bold_font

    table_headers = [
        "#", "Product Code", "TradeMarkOwner/Manufacturer", "Brand Name", "Model",
        "HS Tariff Code", "Country of Origin", "Description", "Quantity", "Qty Unit",
        "Expiry Date", "Unit Price", "Gross Weight", "Net Weight", "Weight Unit", "Total",
    ]

    for col_idx, header_title in enumerate(table_headers, start=1):
        col_letter = openpyxl.utils.get_column_letter(col_idx)
        cell = ws[f"{col_letter}12"]
        cell.value = header_title
        cell.font = brown_bold_font

    items = payload.items or [
        StandardInvoiceLineItem(
            index=1,
            product_code="ITEM-001",
            manufacturer=payload.seller_name or "Manufacturer",
            brand_name="Standard",
            model="Model-A",
            hs_code="940310",
            country_of_origin=payload.seller_country_code or "IT",
            description="Standard Commercial Goods",
            quantity=10.0,
            qty_unit="SET",
            expiry_date="",
            unit_price=250.0,
            unit_price_basis="SET",
            gross_weight_kg=120.0,
            net_weight_kg=110.0,
            weight_unit="KGM",
            total_amount=2500.0,
        )
    ]

    current_row = 13
    for item in items:
        ws[f"A{current_row}"] = item.index
        ws[f"B{current_row}"] = item.product_code or ""
        ws[f"C{current_row}"] = item.manufacturer or ""
        ws[f"D{current_row}"] = item.brand_name or ""
        ws[f"E{current_row}"] = item.model or ""
        ws[f"F{current_row}"] = item.hs_code
        ws[f"G{current_row}"] = item.country_of_origin
        ws[f"H{current_row}"] = item.description
        ws[f"I{current_row}"] = item.quantity
        ws[f"J{current_row}"] = item.qty_unit
        ws[f"K{current_row}"] = item.expiry_date or ""
        ws[f"L{current_row}"] = item.unit_price
        ws[f"M{current_row}"] = item.gross_weight_kg
        ws[f"N{current_row}"] = item.net_weight_kg
        ws[f"O{current_row}"] = normalize_cargox_weight_unit(getattr(item, "weight_unit", None) or payload.weight_unit)
        ws[f"P{current_row}"] = f"=I{current_row}*L{current_row}"
        for col_idx in range(1, 17):
            col_letter = openpyxl.utils.get_column_letter(col_idx)
            ws[f"{col_letter}{current_row}"].font = regular_val_font
        current_row += 1

    end_row = current_row - 1
    tab = Table(displayName="InvoiceItems", ref=f"A12:P{end_row}")
    tab.tableStyleInfo = TableStyleInfo(name="TableStyleLight1", showFirstColumn=False, showLastColumn=False, showRowStripes=True, showColumnStripes=False)
    ws.add_table(tab)

    totals_start_row = current_row
    # Totals
    ws[f"B{totals_start_row}"] = "Lines #:"
    ws[f"B{totals_start_row}"].font = brown_bold_font
    ws[f"C{totals_start_row}"] = "=ROWS(InvoiceItems[])"
    ws[f"C{totals_start_row}"].font = brown_bold_font
    wb.defined_names.add(DefinedName("TotalInvoiceLinesNo", attr_text=f"'{ws.title}'!$C${totals_start_row}"))

    ws[f"O{totals_start_row}"] = "Invoice Subtotal"
    ws[f"O{totals_start_row}"].font = brown_bold_font
    ws[f"P{totals_start_row}"] = "=SUM(InvoiceItems[Total])"
    ws[f"P{totals_start_row}"].font = bold_val_font
    wb.defined_names.add(DefinedName("InvoiceSubtotal", attr_text=f"'{ws.title}'!$P${totals_start_row}"))

    ws[f"O{totals_start_row+1}"] = "Freight Cost"
    ws[f"O{totals_start_row+1}"].font = brown_bold_font
    ws[f"P{totals_start_row+1}"] = payload.freight_cost or 0.0
    ws[f"P{totals_start_row+1}"].font = regular_val_font
    wb.defined_names.add(DefinedName("FreightCost", attr_text=f"'{ws.title}'!$P${totals_start_row+1}"))

    ws[f"O{totals_start_row+2}"] = "Insurance Cost"
    ws[f"O{totals_start_row+2}"].font = brown_bold_font
    ws[f"P{totals_start_row+2}"] = payload.insurance_cost or 0.0
    ws[f"P{totals_start_row+2}"].font = regular_val_font
    wb.defined_names.add(DefinedName("InsuranceCost", attr_text=f"'{ws.title}'!$P${totals_start_row+2}"))

    ws[f"O{totals_start_row+3}"] = "Other Costs"
    ws[f"O{totals_start_row+3}"].font = brown_bold_font
    ws[f"P{totals_start_row+3}"] = payload.other_costs or 0.0
    ws[f"P{totals_start_row+3}"].font = regular_val_font
    wb.defined_names.add(DefinedName("OtherCosts", attr_text=f"'{ws.title}'!$P${totals_start_row+3}"))

    ws[f"O{totals_start_row+4}"] = "Total"
    ws[f"O{totals_start_row+4}"].font = brown_bold_font
    ws[f"P{totals_start_row+4}"] = "=InvoiceSubtotal+FreightCost+InsuranceCost+OtherCosts"
    ws[f"P{totals_start_row+4}"].font = bold_val_font
    wb.defined_names.add(DefinedName("TotalAmount", attr_text=f"'{ws.title}'!$P${totals_start_row+4}"))

    # Reference Sheets (2 to 8)
    ws_pac = wb.create_sheet(title="Package Type list")
    ws_pac.views.sheetView[0].showGridLines = False
    ws_pac["A1"] = "Code"
    ws_pac["B1"] = "Name"
    for idx, (c, n) in enumerate(PACKAGE_TYPES_LIST, start=2):
        ws_pac[f"A{idx}"] = c
        ws_pac[f"B{idx}"] = n
    wb.defined_names.add(DefinedName("PAC", attr_text=f"'Package Type list'!$A$2:$A${len(PACKAGE_TYPES_LIST)+1}"))

    ws_uom = wb.create_sheet(title="Unit of measure list")
    ws_uom.views.sheetView[0].showGridLines = False
    ws_uom["A1"] = "Common Code"
    ws_uom["B1"] = "Name"
    uom_4 = [("GRM", "gram"), ("KGM", "kilogram"), ("SET", "set"), ("STN", "ton (US) or short ton (UK/US)")]
    for idx, (c, n) in enumerate(uom_4, start=2):
        ws_uom[f"A{idx}"] = c
        ws_uom[f"B{idx}"] = n
    wb.defined_names.add(DefinedName("UOM", attr_text=f"'Unit of measure list'!$A$2:$A$5"))

    ws_cities = wb.create_sheet(title="Cities")
    ws_cities.views.sheetView[0].showGridLines = False
    ws_cities["A1"] = "CityCode"
    ws_cities["B1"] = "City"
    for idx, (c, n) in enumerate(CITIES_LIST, start=2):
        ws_cities[f"A{idx}"] = c
        ws_cities[f"B{idx}"] = n

    ws_curr = wb.create_sheet(title="Currency List")
    ws_curr.views.sheetView[0].showGridLines = False
    ws_curr["A1"] = "Currency Name"
    ws_curr["B1"] = "Alphabetic Code"
    for idx, (n, c) in enumerate(CURRENCIES_LIST, start=2):
        ws_curr[f"A{idx}"] = n
        ws_curr[f"B{idx}"] = c

    ws_uom_list = wb.create_sheet(title="UOM List")
    ws_uom_list.views.sheetView[0].showGridLines = False
    wb.defined_names.add(DefinedName("Currency", attr_text=f"'UOM List'!$C$2:$C$6"))
    wb.defined_names.add(DefinedName("CurrencySymbols", attr_text=f"'UOM List'!$D$2:$D$6"))

    ws_countries = wb.create_sheet(title="Country List")
    ws_countries.views.sheetView[0].showGridLines = False
    ws_countries["A1"] = "Code"
    ws_countries["B1"] = "EnglishName"
    for idx, (c, n) in enumerate(COUNTRIES_LIST, start=2):
        ws_countries[f"A{idx}"] = c
        ws_countries[f"B{idx}"] = n

    ws_city_list = wb.create_sheet(title="City List")
    ws_city_list.views.sheetView[0].showGridLines = False
    wb.defined_names.add(DefinedName("CityCodes", attr_text=f"CityList[CityCode]"))

    output = io.BytesIO()
    wb.save(output)
    return output.getvalue()



def parse_standard_invoice_excel_bytes(file_bytes: bytes) -> StandardInvoicePayload:
    """
    Parses a supplier-uploaded Excel Commercial Invoice workbook (.xlsx)
    using Named Ranges (wb.defined_names) and the InvoiceItems structured Table.
    """
    wb = openpyxl.load_workbook(io.BytesIO(file_bytes), data_only=True)
    # Prefer sheet named 'Invoice' or active sheet
    ws = wb["Invoice"] if "Invoice" in wb.sheetnames else wb.active

    def get_defined_val(name_key: str) -> Any:
        try:
            if name_key in wb.defined_names:
                dn = wb.defined_names[name_key]
                destinations = list(dn.destinations)
                if destinations:
                    sheet_title, cell_coord = destinations[0]
                    target_ws = wb[sheet_title] if sheet_title in wb.sheetnames else ws
                    return target_ws[cell_coord].value
        except Exception:
            pass
        return None

    # Exact fallbacks matching official CargoX coordinates
    fallback_coords = {
        "SellerName": "B1",
        "SellerRegistrationCode": "F1",
        "SellerCode": "F1",
        "SellerAddress": "D1",
        "SellerCity": "D3",
        "SellerCityCode": "F2",
        "SellerCountryCode": "F2",
        "SellerContactName": "E4",
        "SellerPhone": "I2",
        "SellerFax": "I3",
        "SellerContactEmail": "F4",
        "SellerWebSite": "F3",
        "BuyerName": "C5",
        "BuyerAddress": "C6",
        "BuyerCode": "C7",
        "BuyerContactName": "E5",
        "BuyerPhone": "I5",
        "BuyerFax": "I6",
        "BuyerContactEmail": "F5",
        "ACIDNumber": "E7",
        "InvoiceType": "B3",
        "InvoiceNumber": "C9",
        "InvoiceDate": "E9",
        "PurchaseOrderNumber": "C8",
        "PurchaseOrderDate": "E8",
        "ProformaInvoiceNumber": "L4",
        "OriginPort": "G7",
        "DestinationPort": "G8",
        "CurrencyCode": "C10",
        "IncoTerm": "E10",
        "GrossWeight": "L5",
        "NetWeight": "L6",
        "WeightUnit": "L7",
    }

    def fetch_field(field_name: str) -> Any:
        val = get_defined_val(field_name)
        if val is not None and str(val).strip() != "":
            return val
        coord = fallback_coords.get(field_name)
        if coord and coord in ws:
            return ws[coord].value
        return None

    seller_name = _sanitize_str(fetch_field("SellerName"))
    seller_tax_id = _sanitize_str(fetch_field("SellerRegistrationCode") or fetch_field("SellerCode"))
    seller_address = _sanitize_str(fetch_field("SellerAddress"))
    seller_city = _sanitize_str(fetch_field("SellerCity"))
    seller_raw_code = _sanitize_str(fetch_field("SellerCityCode") or fetch_field("SellerCountryCode"))
    seller_city_code = seller_raw_code if len(seller_raw_code) >= 4 else ""
    seller_country_code = seller_raw_code[:2] if len(seller_raw_code) >= 2 else "CN"
    seller_contact_name = _sanitize_str(fetch_field("SellerContactName"))
    seller_phone = _sanitize_str(fetch_field("SellerPhone"))
    seller_fax = _sanitize_str(fetch_field("SellerFax"))
    seller_email = _sanitize_str(fetch_field("SellerContactEmail"))
    seller_website = _sanitize_str(fetch_field("SellerWebSite"))

    buyer_name = _sanitize_str(fetch_field("BuyerName"))
    buyer_address = _sanitize_str(fetch_field("BuyerAddress"))
    buyer_tax_id = _sanitize_str(fetch_field("BuyerCode"))
    buyer_contact_name = _sanitize_str(fetch_field("BuyerContactName"))
    buyer_phone = _sanitize_str(fetch_field("BuyerPhone"))
    buyer_fax = _sanitize_str(fetch_field("BuyerFax"))
    buyer_email = _sanitize_str(fetch_field("BuyerContactEmail"))
    acid_number = _sanitize_str(fetch_field("ACIDNumber"))

    invoice_type = _sanitize_str(fetch_field("InvoiceType")) or "Commercial Invoice"
    invoice_number = _sanitize_str(fetch_field("InvoiceNumber"))
    invoice_date = _sanitize_str(fetch_field("InvoiceDate"))
    purchase_order_number = _sanitize_str(fetch_field("PurchaseOrderNumber"))
    purchase_order_date = _sanitize_str(fetch_field("PurchaseOrderDate"))
    proforma_invoice_number = _sanitize_str(fetch_field("ProformaInvoiceNumber"))
    origin_port = _sanitize_str(fetch_field("OriginPort"))
    if not origin_port and "H7" in ws:
        h7_val = _sanitize_str(ws["H7"].value)
        if not h7_val.startswith("="):
            origin_port = h7_val
    destination_port = _sanitize_str(fetch_field("DestinationPort"))
    if not destination_port and "H8" in ws:
        h8_val = _sanitize_str(ws["H8"].value)
        if not h8_val.startswith("="):
            destination_port = h8_val
    currency_code = _sanitize_str(fetch_field("CurrencyCode")) or "EUR"
    incoterm = _sanitize_str(fetch_field("IncoTerm")) or "EXW"
    gross_weight = _safe_float(fetch_field("GrossWeight"))
    net_weight = _safe_float(fetch_field("NetWeight"))
    weight_unit = normalize_cargox_weight_unit(_sanitize_str(fetch_field("WeightUnit")))

    freight_cost = _safe_float(fetch_field("FreightCost"))
    insurance_cost = _safe_float(fetch_field("InsuranceCost"))
    other_costs = _safe_float(fetch_field("OtherCosts"))

    items: List[StandardInvoiceLineItem] = []
    table_range = None
    for tbl in ws.tables.values():
        if tbl.displayName == "InvoiceItems" or "Invoice" in tbl.displayName:
            table_range = tbl.ref
            break

    if table_range:
        col13_header = _sanitize_str(ws.cell(row=12, column=13).value).lower()
        col15_header = _sanitize_str(ws.cell(row=12, column=15).value).lower()
        is_new_layout = ("gross" in col13_header) or ("weight" in col15_header)

        min_col, min_row, max_col, max_row = openpyxl.utils.range_boundaries(table_range)
        for row_idx in range(min_row + 1, max_row + 1):
            hs_code = _sanitize_str(ws.cell(row=row_idx, column=6).value)
            desc = _sanitize_str(ws.cell(row=row_idx, column=8).value)
            if not hs_code and not desc:
                continue

            c13_raw = ws.cell(row=row_idx, column=13).value
            c14_raw = ws.cell(row=row_idx, column=14).value
            c15_raw = ws.cell(row=row_idx, column=15).value
            c16_raw = ws.cell(row=row_idx, column=16).value

            # Self-healing detection for legacy shifted columns:
            # If col 13 contains a non-numeric string (e.g. "Carton") and col 14 & 15 are numeric (e.g. 10510 and 10080)
            is_shifted_row = (not _is_numeric(c13_raw)) and _is_numeric(c14_raw) and _is_numeric(c15_raw)

            if is_shifted_row:
                basis_val = _sanitize_str(c13_raw) or _sanitize_str(ws.cell(row=row_idx, column=10).value) or "PCS"
                gw_val = _safe_float(c14_raw)
                nw_val = _safe_float(c15_raw)
                wu_val = normalize_cargox_weight_unit(weight_unit)
                tot_val = _safe_float(c16_raw)
            elif is_new_layout:
                gw_val = _safe_float(c13_raw)
                nw_val = _safe_float(c14_raw)
                wu_val = normalize_cargox_weight_unit(_sanitize_str(c15_raw) or weight_unit)
                tot_val = _safe_float(c16_raw)
                basis_val = _sanitize_str(ws.cell(row=row_idx, column=10).value) or "PCS"
            else:
                basis_val = _sanitize_str(c13_raw) or "PCS"
                gw_val = _safe_float(c14_raw)
                nw_val = _safe_float(c15_raw)
                wu_val = normalize_cargox_weight_unit(weight_unit)
                tot_val = _safe_float(c16_raw)

            item = StandardInvoiceLineItem(
                index=int(_safe_float(ws.cell(row=row_idx, column=1).value, len(items) + 1)),
                product_code=_sanitize_str(ws.cell(row=row_idx, column=2).value),
                manufacturer=_sanitize_str(ws.cell(row=row_idx, column=3).value),
                brand_name=_sanitize_str(ws.cell(row=row_idx, column=4).value),
                model=_sanitize_str(ws.cell(row=row_idx, column=5).value),
                hs_code=hs_code,
                country_of_origin=_sanitize_str(ws.cell(row=row_idx, column=7).value),
                description=desc,
                quantity=_safe_float(ws.cell(row=row_idx, column=9).value, 1.0),
                qty_unit=_sanitize_str(ws.cell(row=row_idx, column=10).value) or "PCE",
                expiry_date=_sanitize_str(ws.cell(row=row_idx, column=11).value),
                unit_price=_safe_float(ws.cell(row=row_idx, column=12).value),
                unit_price_basis=basis_val,
                gross_weight_kg=gw_val,
                net_weight_kg=nw_val,
                weight_unit=wu_val,
                total_amount=tot_val,
            )
            if item.total_amount == 0.0 and item.quantity > 0 and item.unit_price > 0:
                item.total_amount = round(item.quantity * item.unit_price, 2)
            items.append(item)
    else:
        col13_header = _sanitize_str(ws.cell(row=12, column=13).value).lower()
        col15_header = _sanitize_str(ws.cell(row=12, column=15).value).lower()
        is_new_layout = ("gross" in col13_header) or ("weight" in col15_header)

        for r in range(13, ws.max_row + 1):
            col1_val = str(ws.cell(row=r, column=1).value or "").strip()
            col6_hs = str(ws.cell(row=r, column=6).value or "").strip()
            col8_desc = str(ws.cell(row=r, column=8).value or "").strip()
            if "Subtotal" in str(ws.cell(row=r, column=15).value or "") or "Total" in str(ws.cell(row=r, column=15).value or ""):
                break
            if col6_hs or col8_desc:
                c13_raw = ws.cell(row=r, column=13).value
                c14_raw = ws.cell(row=r, column=14).value
                c15_raw = ws.cell(row=r, column=15).value
                c16_raw = ws.cell(row=r, column=16).value

                is_shifted_row = (not _is_numeric(c13_raw)) and _is_numeric(c14_raw) and _is_numeric(c15_raw)

                if is_shifted_row:
                    basis_val = _sanitize_str(c13_raw) or _sanitize_str(ws.cell(row=r, column=10).value) or "PCS"
                    gw_val = _safe_float(c14_raw)
                    nw_val = _safe_float(c15_raw)
                    wu_val = normalize_cargox_weight_unit(weight_unit)
                    tot_val = _safe_float(c16_raw)
                elif is_new_layout:
                    gw_val = _safe_float(c13_raw)
                    nw_val = _safe_float(c14_raw)
                    wu_val = normalize_cargox_weight_unit(_sanitize_str(c15_raw) or weight_unit)
                    tot_val = _safe_float(c16_raw)
                    basis_val = _sanitize_str(ws.cell(row=r, column=10).value) or "PCS"
                else:
                    basis_val = _sanitize_str(c13_raw) or "PCS"
                    gw_val = _safe_float(c14_raw)
                    nw_val = _safe_float(c15_raw)
                    wu_val = normalize_cargox_weight_unit(weight_unit)
                    tot_val = _safe_float(c16_raw)

                item = StandardInvoiceLineItem(
                    index=int(_safe_float(col1_val, len(items) + 1)),
                    product_code=_sanitize_str(ws.cell(row=r, column=2).value),
                    manufacturer=_sanitize_str(ws.cell(row=r, column=3).value),
                    brand_name=_sanitize_str(ws.cell(row=r, column=4).value),
                    model=_sanitize_str(ws.cell(row=r, column=5).value),
                    hs_code=col6_hs,
                    country_of_origin=_sanitize_str(ws.cell(row=r, column=7).value),
                    description=col8_desc,
                    quantity=_safe_float(ws.cell(row=r, column=9).value, 1.0),
                    qty_unit=_sanitize_str(ws.cell(row=r, column=10).value) or "PCE",
                    expiry_date=_sanitize_str(ws.cell(row=r, column=11).value),
                    unit_price=_safe_float(ws.cell(row=r, column=12).value),
                    unit_price_basis=basis_val,
                    gross_weight_kg=gw_val,
                    net_weight_kg=nw_val,
                    weight_unit=wu_val,
                    total_amount=tot_val,
                )
                if item.total_amount == 0.0:
                    item.total_amount = round(item.quantity * item.unit_price, 2)
                items.append(item)

    subtotal = sum(i.total_amount for i in items)
    total_amount = round(subtotal + freight_cost + insurance_cost + other_costs, 2)

    if gross_weight == 0.0 and items:
        gross_weight = round(sum(i.gross_weight_kg for i in items), 2)
    if net_weight == 0.0 and items:
        net_weight = round(sum(i.net_weight_kg for i in items), 2)
    if items and items[0].weight_unit:
        weight_unit = normalize_cargox_weight_unit(items[0].weight_unit)

    return StandardInvoicePayload(
        seller_name=seller_name,
        seller_address=seller_address,
        seller_city=seller_city,
        seller_city_code=seller_city_code,
        seller_country_code=seller_country_code,
        seller_tax_id=seller_tax_id,
        seller_contact_name=seller_contact_name,
        seller_phone=seller_phone,
        seller_fax=seller_fax,
        seller_email=seller_email,
        seller_website=seller_website,
        buyer_name=buyer_name,
        buyer_address=buyer_address,
        buyer_tax_id=buyer_tax_id,
        buyer_contact_name=buyer_contact_name,
        buyer_phone=buyer_phone,
        buyer_fax=buyer_fax,
        buyer_email=buyer_email,
        acid_number=acid_number,
        invoice_type=invoice_type,
        invoice_number=invoice_number,
        invoice_date=invoice_date,
        purchase_order_number=purchase_order_number,
        purchase_order_date=purchase_order_date,
        proforma_invoice_number=proforma_invoice_number,
        origin_port=origin_port,
        destination_port=destination_port,
        currency_code=currency_code,
        incoterm=incoterm,
        gross_weight=gross_weight,
        net_weight=net_weight,
        weight_unit=weight_unit,
        items=items,
        subtotal=subtotal,
        freight_cost=freight_cost,
        insurance_cost=insurance_cost,
        other_costs=other_costs,
        total_amount=total_amount,
    )



def compare_standard_invoice_data(
    import_file_id: int,
    import_file_code: str,
    system_snapshot: StandardInvoicePayload,
    supplier_data: StandardInvoicePayload,
) -> StandardInvoiceComparisonResponse:
    header_comparisons: List[StandardInvoiceComparisonRow] = []
    financial_comparisons: List[StandardInvoiceComparisonRow] = []
    line_item_comparisons: List[StandardInvoiceLineComparisonRow] = []

    critical_count = 0
    warning_count = 0

    sys_acid = _sanitize_str(system_snapshot.acid_number)
    sup_acid = _sanitize_str(supplier_data.acid_number)
    if sys_acid and sup_acid and sys_acid != sup_acid:
        status = "CRITICAL_MISMATCH"
        critical_count += 1
        diff = f"System: {sys_acid} vs Excel: {sup_acid}"
    elif not sup_acid:
        status = "CRITICAL_MISMATCH"
        critical_count += 1
        diff = "Missing in Excel"
    else:
        status = "MATCH"
        diff = None
    header_comparisons.append(
        StandardInvoiceComparisonRow(
            field_key="acid_number",
            field_label_ar="رقم القيد الجمركي المسبق (ACID #)",
            field_label_en="Egyptian ACID Number",
            system_value=sys_acid,
            supplier_value=sup_acid,
            status=status,
            difference=diff,
            notes="19-digit Egyptian Customs Reference",
        )
    )

    sys_exp_tax = _sanitize_str(system_snapshot.seller_tax_id)
    sup_exp_tax = _sanitize_str(supplier_data.seller_tax_id)
    sys_digits = re.sub(r"\D", "", sys_exp_tax)
    sup_digits = re.sub(r"\D", "", sup_exp_tax)
    if sys_digits and sup_digits and sys_digits != sup_digits:
        status = "CRITICAL_MISMATCH"
        critical_count += 1
        diff = f"{sys_exp_tax} != {sup_exp_tax}"
    else:
        status = "MATCH"
        diff = None
    header_comparisons.append(
        StandardInvoiceComparisonRow(
            field_key="seller_tax_id",
            field_label_ar="الرقم الضريبي / تسجيل المصدر (Seller Tax ID)",
            field_label_en="Seller Registration Code",
            system_value=sys_exp_tax,
            supplier_value=sup_exp_tax,
            status=status,
            difference=diff,
        )
    )

    sys_imp_tax = _sanitize_str(system_snapshot.buyer_tax_id)
    sup_imp_tax = _sanitize_str(supplier_data.buyer_tax_id)
    sys_imp_dig = re.sub(r"\D", "", sys_imp_tax)
    sup_imp_dig = re.sub(r"\D", "", sup_imp_tax)
    if sys_imp_dig and sup_imp_dig and sys_imp_dig != sup_imp_dig:
        status = "CRITICAL_MISMATCH"
        critical_count += 1
        diff = f"{sys_imp_tax} != {sup_imp_tax}"
    else:
        status = "MATCH"
        diff = None
    header_comparisons.append(
        StandardInvoiceComparisonRow(
            field_key="buyer_tax_id",
            field_label_ar="الرقم الضريبي للمستورد (Egypt Tax Code)",
            field_label_en="Buyer Egypt Tax Code",
            system_value=sys_imp_tax,
            supplier_value=sup_imp_tax,
            status=status,
            difference=diff,
        )
    )

    sys_curr = (system_snapshot.currency_code or "").upper().strip()
    sup_curr = (supplier_data.currency_code or "").upper().strip()
    if sys_curr and sup_curr and sys_curr != sup_curr:
        status = "CRITICAL_MISMATCH"
        critical_count += 1
        diff = f"Currency Mismatch ({sys_curr} vs {sup_curr})"
    else:
        status = "MATCH"
        diff = None
    header_comparisons.append(
        StandardInvoiceComparisonRow(
            field_key="currency_code",
            field_label_ar="عملة الفاتورة (Currency)",
            field_label_en="Invoice Currency Code",
            system_value=sys_curr,
            supplier_value=sup_curr,
            status=status,
            difference=diff,
        )
    )

    sys_inco = (system_snapshot.incoterm or "").upper().strip()
    sup_inco = (supplier_data.incoterm or "").upper().strip()
    if sys_inco and sup_inco and sys_inco != sup_inco:
        status = "WARNING"
        warning_count += 1
        diff = f"{sys_inco} vs {sup_inco}"
    else:
        status = "MATCH"
        diff = None
    header_comparisons.append(
        StandardInvoiceComparisonRow(
            field_key="incoterm",
            field_label_ar="شرط التسليم (Incoterm)",
            field_label_en="Delivery Incoterm",
            system_value=sys_inco,
            supplier_value=sup_inco,
            status=status,
            difference=diff,
        )
    )

    sys_city_code = _sanitize_str(system_snapshot.seller_city_code).upper()
    sup_city_code = _sanitize_str(supplier_data.seller_city_code).upper()
    if sys_city_code and sup_city_code and sys_city_code != sup_city_code:
        status = "WARNING"
        warning_count += 1
        diff = f"{sys_city_code} vs {sup_city_code}"
    else:
        status = "MATCH"
        diff = None
    header_comparisons.append(
        StandardInvoiceComparisonRow(
            field_key="seller_city_code",
            field_label_ar="كود مدينة المصدر (City Code)",
            field_label_en="Exporter City Code",
            system_value=sys_city_code,
            supplier_value=sup_city_code,
            status=status,
            difference=diff,
        )
    )

    sys_pol = (system_snapshot.origin_port or "").strip().upper()
    sup_pol = (supplier_data.origin_port or "").strip().upper()
    sys_pol_code = resolve_port_code(sys_pol)
    sup_pol_code = resolve_port_code(sup_pol)
    sys_pol_disp = resolve_port_display_name(sys_pol_code)
    sup_pol_disp = resolve_port_display_name(sup_pol_code)
    sys_pol_full = f"{sys_pol_code} — {sys_pol_disp}" if sys_pol_disp and sys_pol_disp != sys_pol_code else sys_pol_code
    sup_pol_full = f"{sup_pol_code} — {sup_pol_disp}" if sup_pol_disp and sup_pol_disp != sup_pol_code else sup_pol_code

    if sys_pol_code and sup_pol_code and sys_pol_code != sup_pol_code:
        status = "WARNING"
        warning_count += 1
        diff = f"{sys_pol_code} vs {sup_pol_code}"
    else:
        status = "MATCH"
        diff = None
    header_comparisons.append(
        StandardInvoiceComparisonRow(
            field_key="origin_port",
            field_label_ar="ميناء الشحن / القيام (Origin Port)",
            field_label_en="Origin Port (POL)",
            system_value=sys_pol_full,
            supplier_value=sup_pol_full,
            status=status,
            difference=diff,
        )
    )

    sys_pod = (system_snapshot.destination_port or "").strip().upper()
    sup_pod = (supplier_data.destination_port or "").strip().upper()
    sys_pod_code = resolve_port_code(sys_pod)
    sup_pod_code = resolve_port_code(sup_pod)
    sys_pod_disp = resolve_port_display_name(sys_pod_code)
    sup_pod_disp = resolve_port_display_name(sup_pod_code)
    sys_pod_full = f"{sys_pod_code} — {sys_pod_disp}" if sys_pod_disp and sys_pod_disp != sys_pod_code else sys_pod_code
    sup_pod_full = f"{sup_pod_code} — {sup_pod_disp}" if sup_pod_disp and sup_pod_disp != sup_pod_code else sup_pod_code

    if sys_pod_code and sup_pod_code and sys_pod_code != sup_pod_code:
        status = "WARNING"
        warning_count += 1
        diff = f"{sys_pod_code} vs {sup_pod_code}"
    else:
        status = "MATCH"
        diff = None
    header_comparisons.append(
        StandardInvoiceComparisonRow(
            field_key="destination_port",
            field_label_ar="ميناء الوصول (Destination Port)",
            field_label_en="Destination Port (POD)",
            system_value=sys_pod_full,
            supplier_value=sup_pod_full,
            status=status,
            difference=diff,
        )
    )

    sys_sub = round(system_snapshot.subtotal, 2)
    sup_sub = round(supplier_data.subtotal, 2)
    diff_val = round(abs(sys_sub - sup_sub), 2)
    if diff_val > 5.0:
        status = "CRITICAL_MISMATCH"
        critical_count += 1
        diff_str = f"Diff: {sup_sub - sys_sub:+.2f} {sys_curr}"
    elif diff_val > 0.01:
        status = "WARNING"
        warning_count += 1
        diff_str = f"Diff: {sup_sub - sys_sub:+.2f} {sys_curr}"
    else:
        status = "MATCH"
        diff_str = None
    financial_comparisons.append(
        StandardInvoiceComparisonRow(
            field_key="subtotal",
            field_label_ar="مجموع البنود (Invoice Subtotal)",
            field_label_en="Invoice Subtotal",
            system_value=f"{sys_sub:,.2f} {sys_curr}",
            supplier_value=f"{sup_sub:,.2f} {sup_curr}",
            status=status,
            difference=diff_str,
        )
    )

    sys_tot = round(system_snapshot.total_amount, 2)
    sup_tot = round(supplier_data.total_amount, 2)
    diff_tot = round(abs(sys_tot - sup_tot), 2)
    if diff_tot > 5.0:
        status = "CRITICAL_MISMATCH"
        critical_count += 1
        diff_str = f"Diff: {sup_tot - sys_tot:+.2f} {sys_curr}"
    elif diff_tot > 0.01:
        status = "WARNING"
        warning_count += 1
        diff_str = f"Diff: {sup_tot - sys_tot:+.2f} {sys_curr}"
    else:
        status = "MATCH"
        diff_str = None
    financial_comparisons.append(
        StandardInvoiceComparisonRow(
            field_key="total_amount",
            field_label_ar="الإجمالي النهائي (Total Amount)",
            field_label_en="Total Commercial Invoice Amount",
            system_value=f"{sys_tot:,.2f} {sys_curr}",
            supplier_value=f"{sup_tot:,.2f} {sup_curr}",
            status=status,
            difference=diff_str,
        )
    )

    sys_items = system_snapshot.items or []
    sup_items = supplier_data.items or []
    max_lines = max(len(sys_items), len(sup_items))

    for idx in range(max_lines):
        s_item = sys_items[idx] if idx < len(sys_items) else None
        u_item = sup_items[idx] if idx < len(sup_items) else None

        line_status = "MATCH"
        note_parts = []

        if s_item and u_item:
            s_hs = re.sub(r"\D", "", s_item.hs_code)
            u_hs = re.sub(r"\D", "", u_item.hs_code)
            if s_hs and u_hs and s_hs[:6] != u_hs[:6]:
                line_status = "CRITICAL_MISMATCH"
                critical_count += 1
                note_parts.append(f"HS Code Mismatch: {s_item.hs_code} vs {u_item.hs_code}")

            if abs(s_item.quantity - u_item.quantity) > 0.01:
                if line_status != "CRITICAL_MISMATCH":
                    line_status = "WARNING"
                warning_count += 1
                note_parts.append(f"Qty Diff: {u_item.quantity - s_item.quantity:+.2f}")

            if abs(s_item.unit_price - u_item.unit_price) > 0.01:
                if line_status != "CRITICAL_MISMATCH":
                    line_status = "WARNING"
                warning_count += 1
                note_parts.append(f"Price Diff: {u_item.unit_price - s_item.unit_price:+.2f}")

            line_item_comparisons.append(
                StandardInvoiceLineComparisonRow(
                    index=idx + 1,
                    product_code=u_item.product_code or s_item.product_code or f"LINE-{idx+1}",
                    hs_code_system=s_item.hs_code,
                    hs_code_supplier=u_item.hs_code,
                    description_system=s_item.description,
                    description_supplier=u_item.description,
                    qty_system=s_item.quantity,
                    qty_supplier=u_item.quantity,
                    unit_price_system=s_item.unit_price,
                    unit_price_supplier=u_item.unit_price,
                    total_system=s_item.total_amount,
                    total_supplier=u_item.total_amount,
                    gross_weight_system=s_item.gross_weight_kg,
                    gross_weight_supplier=u_item.gross_weight_kg,
                    status=line_status,
                    notes=", ".join(note_parts) if note_parts else "Perfect Match",
                )
            )
        elif u_item and not s_item:
            line_item_comparisons.append(
                StandardInvoiceLineComparisonRow(
                    index=idx + 1,
                    product_code=u_item.product_code or f"EXTRA-{idx+1}",
                    hs_code_system=None,
                    hs_code_supplier=u_item.hs_code,
                    description_system=None,
                    description_supplier=u_item.description,
                    qty_system=0.0,
                    qty_supplier=u_item.quantity,
                    unit_price_system=0.0,
                    unit_price_supplier=u_item.unit_price,
                    total_system=0.0,
                    total_supplier=u_item.total_amount,
                    gross_weight_system=0.0,
                    gross_weight_supplier=u_item.gross_weight_kg,
                    status="WARNING",
                    notes="Extra item in Supplier Excel not in PO",
                )
            )
            warning_count += 1
        elif s_item and not u_item:
            line_item_comparisons.append(
                StandardInvoiceLineComparisonRow(
                    index=idx + 1,
                    product_code=s_item.product_code or f"MISSING-{idx+1}",
                    hs_code_system=s_item.hs_code,
                    hs_code_supplier=None,
                    description_system=s_item.description,
                    description_supplier=None,
                    qty_system=s_item.quantity,
                    qty_supplier=0.0,
                    unit_price_system=s_item.unit_price,
                    unit_price_supplier=0.0,
                    total_system=s_item.total_amount,
                    total_supplier=0.0,
                    gross_weight_system=s_item.gross_weight_kg,
                    gross_weight_supplier=0.0,
                    status="CRITICAL_MISMATCH",
                    notes="Item from PO missing in Supplier Excel",
                )
            )
            critical_count += 1

    has_discrepancies = (critical_count > 0 or warning_count > 0)
    has_critical = critical_count > 0

    notice_en = None
    notice_ar = None
    if has_discrepancies:
        notice_en = (
            f"Dear {supplier_data.seller_name or 'Supplier'},\n\n"
            f"We reviewed the Standard Commercial Invoice Excel for Import File [{import_file_code}] (ACID: {sys_acid}).\n"
            f"Please amend the following discrepancies to comply with Egyptian Customs Nafeza requirements:\n"
        )
        notice_ar = (
            f"السادة / {supplier_data.seller_name or 'المورد الأجنبي'},\n\n"
            f"تحية طيبة وبعد، بخصوص مراجعة الفاتورة التجارية المعيارية للملف [{import_file_code}] (رقم ACID: {sys_acid}):\n"
            f"يرجى تصحيح الفروق التالية لتتوافق مع متطلبات مصلحة الجمارك المصرية ومنظومة نافذة:\n"
        )
        for h in header_comparisons:
            if h.status != "MATCH":
                notice_en += f"- {h.field_label_en}: Expected '{h.system_value}' but found '{h.supplier_value}'.\n"
                notice_ar += f"- {h.field_label_ar}: المتوقع '{h.system_value}' والمسجل بالفاتورة '{h.supplier_value}'.\n"
        for l in line_item_comparisons:
            if l.status != "MATCH":
                notice_en += f"- Item #{l.index} [{l.product_code}]: {l.notes}.\n"
                notice_ar += f"- البند #{l.index} [{l.product_code}]: {l.notes}.\n"
        notice_en += "\nThank you for your prompt cooperation.\nImport Documentation Team"
        notice_ar += "\nشاكرين حسن تعاونكم الدائم.\nإدارة التوثيق والاستيراد"

    return StandardInvoiceComparisonResponse(
        import_file_id=import_file_id,
        import_file_code=import_file_code,
        acid_number=sys_acid or sup_acid,
        has_discrepancies=has_discrepancies,
        has_critical_mismatch=has_critical,
        total_discrepancies_count=critical_count + warning_count,
        critical_mismatches_count=critical_count,
        warnings_count=warning_count,
        header_comparisons=header_comparisons,
        financial_comparisons=financial_comparisons,
        line_item_comparisons=line_item_comparisons,
        system_snapshot=system_snapshot,
        supplier_data=supplier_data,
        rectification_notice_en=notice_en,
        rectification_notice_ar=notice_ar,
    )


def generate_customs_packing_list_excel_bytes(
    payload: StandardInvoicePayload,
    track_code: str = "",
) -> bytes:
    """
    توليد ملف إكسل رسمي لقائمة التعبئة الجمركية (Customs Packing List Excel).
    متوافق مع معايير الجمارك المصرية، منظومة نافذة، و CargoX.
    """
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Packing List"
    ws.views.sheetView[0].showGridLines = True

    # 1. Header Styles
    header_fill = PatternFill(start_color="27AE60", end_color="27AE60", fill_type="solid")
    header_font = Font(name="Calibri", size=16, bold=True, color="FFFFFF")
    section_fill = PatternFill(start_color="2C3E50", end_color="2C3E50", fill_type="solid")
    section_font = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
    tbl_hdr_fill = PatternFill(start_color="ECF0F1", end_color="ECF0F1", fill_type="solid")
    tbl_hdr_font = Font(name="Calibri", size=10, bold=True, color="2C3E50")
    bold_font = Font(name="Calibri", size=10, bold=True)
    regular_font = Font(name="Calibri", size=10)
    zebra_fill = PatternFill(start_color="F8F9F9", end_color="F8F9F9", fill_type="solid")
    white_fill = PatternFill(start_color="FFFFFF", end_color="FFFFFF", fill_type="solid")

    thin_border = Border(
        left=Side(style="thin", color="BDC3C7"),
        right=Side(style="thin", color="BDC3C7"),
        top=Side(style="thin", color="BDC3C7"),
        bottom=Side(style="thin", color="BDC3C7"),
    )
    total_border = Border(
        top=Side(style="thin", color="2C3E50"),
        bottom=Side(style="double", color="2C3E50"),
    )

    # 2. Main Title Banner
    ws.merge_cells("A1:J2")
    title_cell = ws["A1"]
    title_cell.value = "CUSTOMS PACKING LIST / قائمة التعبئة الجمركية"
    title_cell.font = header_font
    title_cell.fill = header_fill
    title_cell.alignment = Alignment(horizontal="center", vertical="center")

    # 3. Metadata Header Section
    ws["A4"] = "Shipper / Exporter (المصدر):"
    ws["B4"] = payload.seller_name or "N/A"
    ws["F4"] = "Invoice Ref (رقم الفاتورة):"
    ws["G4"] = payload.invoice_number or "N/A"

    ws["A5"] = "Importer / Buyer (المستورد):"
    ws["B5"] = payload.buyer_name or "N/A"
    ws["F5"] = "Customs Track (المسار الجمركي):"
    ws["G5"] = track_code or f"CUST-TRK-{payload.acid_number or '001'}"

    ws["A6"] = "ACID Number (رقم القيد الجمركي):"
    ws["B6"] = payload.acid_number or "N/A"
    ws["F6"] = "Date (تاريخ الإقرار):"
    ws["G6"] = payload.invoice_date or datetime.now(timezone.utc).strftime("%Y-%m-%d")

    ws["A7"] = "Port of Loading (ميناء الشحن):"
    ws["B7"] = payload.origin_port or "Origin Port"
    ws["F7"] = "Port of Discharge (ميناء الوصول):"
    ws["G7"] = payload.destination_port or "EGALY"

    for r in range(4, 8):
        ws[f"A{r}"].font = bold_font
        ws[f"B{r}"].font = regular_font
        ws[f"F{r}"].font = bold_font
        ws[f"G{r}"].font = bold_font
        ws[f"G{r}"].alignment = Alignment(horizontal="left")

    # 4. Table Columns Header
    headers = [
        ("#", "A9"),
        ("Package / CTN #", "B9"),
        ("Product Code", "C9"),
        ("HS Tariff Code", "D9"),
        ("Manufacturer", "E9"),
        ("Description of Goods", "F9"),
        ("Quantity", "G9"),
        ("Unit", "H9"),
        ("Net Weight (KG)", "I9"),
        ("Gross Weight (KG)", "J9"),
    ]

    for title, cell_ref in headers:
        cell = ws[cell_ref]
        cell.value = title
        cell.font = tbl_hdr_font
        cell.fill = tbl_hdr_fill
        cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        cell.border = thin_border

    ws.row_dimensions[9].height = 25.0

    # 5. Populate Data Rows
    current_row = 10
    items = payload.items or []
    for idx, item in enumerate(items, start=1):
        r = current_row
        ws.row_dimensions[r].height = 22.0
        fill = zebra_fill if idx % 2 == 0 else white_fill

        ws[f"A{r}"] = item.index
        ws[f"B{r}"] = f"PKG {idx:02d}"
        ws[f"C{r}"] = item.product_code or ""
        ws[f"D{r}"] = item.hs_code
        ws[f"E{r}"] = item.manufacturer or payload.seller_name or ""
        ws[f"F{r}"] = item.description
        ws[f"G{r}"] = item.quantity
        ws[f"H{r}"] = item.qty_unit
        ws[f"I{r}"] = item.net_weight_kg
        ws[f"J{r}"] = item.gross_weight_kg

        alignments = {
            "A": Alignment(horizontal="center", vertical="center"),
            "B": Alignment(horizontal="center", vertical="center"),
            "C": Alignment(horizontal="left", vertical="center"),
            "D": Alignment(horizontal="center", vertical="center"),
            "E": Alignment(horizontal="left", vertical="center"),
            "F": Alignment(horizontal="left", vertical="center"),
            "G": Alignment(horizontal="right", vertical="center"),
            "H": Alignment(horizontal="center", vertical="center"),
            "I": Alignment(horizontal="right", vertical="center"),
            "J": Alignment(horizontal="right", vertical="center"),
        }

        for col_idx in range(1, 11):
            cl = openpyxl.utils.get_column_letter(col_idx)
            cell = ws[f"{cl}{r}"]
            cell.font = regular_font
            cell.alignment = alignments.get(cl, Alignment(horizontal="center", vertical="center"))
            cell.border = thin_border
            cell.fill = fill
            if cl in ["G", "I", "J"]:
                cell.number_format = "#,##0.00"

        current_row += 1

    # 6. Totals Row
    tot_row = current_row
    ws[f"A{tot_row}"] = "TOTAL / الإجمالي"
    ws.merge_cells(f"A{tot_row}:F{tot_row}")
    ws[f"A{tot_row}"].font = Font(name="Calibri", size=11, bold=True, color="2C3E50")
    ws[f"A{tot_row}"].alignment = Alignment(horizontal="right", vertical="center")

    last_data_row = tot_row - 1
    ws[f"G{tot_row}"] = f"=SUM(G10:G{last_data_row})"
    ws[f"H{tot_row}"] = "PCS"
    ws[f"I{tot_row}"] = f"=SUM(I10:I{last_data_row})"
    ws[f"J{tot_row}"] = f"=SUM(J10:J{last_data_row})"

    for col_idx in range(1, 11):
        cl = openpyxl.utils.get_column_letter(col_idx)
        cell = ws[f"{cl}{tot_row}"]
        cell.font = Font(name="Calibri", size=11, bold=True, color="27AE60")
        cell.border = total_border
        if cl in ["G", "I", "J"]:
            cell.number_format = "#,##0.00"
            cell.alignment = Alignment(horizontal="right", vertical="center")
        elif cl == "H":
            cell.alignment = Alignment(horizontal="center", vertical="center")

    # 7. Signatures / Nafeza Compliance Footer
    sig_row = tot_row + 3
    ws[f"A{sig_row}"] = "Authorized Signatory / المفوض بالتوقيع"
    ws[f"A{sig_row}"].font = bold_font
    ws[f"G{sig_row}"] = "Customs Stamp / خاتم التخليص الجمركي"
    ws[f"G{sig_row}"].font = bold_font

    # Set Column Widths
    col_widths = {
        "A": 6, "B": 14, "C": 16, "D": 16, "E": 26, "F": 34, "G": 14, "H": 10, "I": 16, "J": 16
    }
    for col_letter, width in col_widths.items():
        ws.column_dimensions[col_letter].width = width

    buf = io.BytesIO()
    wb.save(buf)
    buf.seek(0)
    return buf.read()
