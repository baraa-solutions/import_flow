import io
from datetime import datetime, date
from typing import List, Dict, Any, Optional
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from reportlab.lib.pagesizes import A4, landscape
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors
from fastapi import Response, HTTPException, status


class MasterDataExportImportHelper:
    @staticmethod
    def standard_export_filename(entity_prefix: str, extension: str, doc_code: Optional[str] = None) -> str:
        """Generates standardized filename: Prefix_YYYY-MM-DD.ext or Prefix_CODE_YYYY-MM-DD.ext."""
        date_str = date.today().strftime("%Y-%m-%d")
        clean_prefix = entity_prefix.strip().replace(" ", "_")
        ext = extension.lstrip(".")
        if doc_code:
            clean_code = str(doc_code).strip().replace(" ", "_").replace("/", "-")
            return f"{clean_prefix}_{clean_code}_{date_str}.{ext}"
        return f"{clean_prefix}_{date_str}.{ext}"

    @staticmethod
    def as_excel_response(filename: str, content: bytes) -> Response:
        """Constructs a standard attachment response for downloadable Excel spreadsheets."""
        return Response(
            content=content,
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={"Content-Disposition": f"attachment; filename={filename}"},
        )

    @staticmethod
    def as_pdf_response(filename: str, content: bytes) -> Response:
        """Constructs a standard attachment response for downloadable PDF reports."""
        return Response(
            content=content,
            media_type="application/pdf",
            headers={"Content-Disposition": f"attachment; filename={filename}"},
        )

    @staticmethod
    def parse_date_safe(val: Any, default: Optional[date] = None) -> Optional[date]:
        """Safely parses string/object to date without raising exceptions on corrupt inputs."""
        if not val:
            return default
        try:
            return datetime.strptime(str(val)[:10], "%Y-%m-%d").date()
        except Exception:
            return default

    @staticmethod
    def format_date_safe(val: Any, default: str = "") -> str:
        """Standardized YYYY-MM-DD date formatter for export outputs."""
        if not val:
            return default
        if isinstance(val, (date, datetime)):
            return val.strftime("%Y-%m-%d")
        s = str(val).strip()
        if len(s) >= 10 and s[4] == '-' and s[7] == '-':
            return s[:10]
        return s

    @staticmethod
    def parse_bool_safe(val: Any) -> bool:
        """Standardized boolean converter supporting common Arabic and English truthy literals."""
        if not val:
            return False
        return str(val).strip().lower() in ['true', '1', 'yes', 'نعم', 't']

    @staticmethod
    def create_excel_template(columns: List[str], sample_row: Dict[str, Any] = None) -> bytes:
        wb = openpyxl.Workbook()
        ws = wb.active
        ws.title = "Sample Template"

        # Headers styling
        header_fill = PatternFill(start_color="2C3E50", end_color="2C3E50", fill_type="solid")
        header_font = Font(name="Arial", size=11, bold=True, color="FFFFFF")
        align_center = Alignment(horizontal="center", vertical="center")

        ws.append(columns)
        for col_num, _ in enumerate(columns, 1):
            cell = ws.cell(row=1, column=col_num)
            cell.fill = header_fill
            cell.font = header_font
            cell.alignment = align_center

        if sample_row:
            row_vals = [sample_row.get(col, "") for col in columns]
            ws.append(row_vals)

        # Auto-adjust column widths
        for col in ws.columns:
            max_len = max(len(str(cell.value or '')) for cell in col)
            col_letter = openpyxl.utils.get_column_letter(col[0].column)
            ws.column_dimensions[col_letter].width = max(max_len + 4, 15)

        buf = io.BytesIO()
        wb.save(buf)
        buf.seek(0)
        return buf.getvalue()

    MAX_EXCEL_FILE_SIZE: int = 20 * 1024 * 1024  # 20 MB

    @staticmethod
    def parse_excel_file(
        file_bytes: bytes,
        required_columns: List[str],
        max_size_bytes: int = MAX_EXCEL_FILE_SIZE,
    ) -> List[Dict[str, Any]]:
        if not file_bytes:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Uploaded Excel file is empty.",
            )

        if len(file_bytes) > max_size_bytes:
            max_mb = max_size_bytes / (1024 * 1024)
            raise HTTPException(
                status_code=status.HTTP_413_CONTENT_TOO_LARGE,
                detail=f"Excel file size ({len(file_bytes) / (1024 * 1024):.1f} MB) exceeds maximum allowed limit of {max_mb:.0f} MB.",
            )

        try:
            wb = openpyxl.load_workbook(filename=io.BytesIO(file_bytes), data_only=True)
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid or corrupted Excel spreadsheet: {str(e)}",
            )

        ws = wb.active
        if ws is None:
            return []

        rows = list(ws.iter_rows(values_only=True))
        if not rows:
            return []

        headers = [str(h).strip() if h is not None else "" for h in rows[0]]
        
        parsed_data = []
        for row in rows[1:]:
            if not any(row):
                continue
            row_dict = {}
            for idx, h in enumerate(headers):
                if h and idx < len(row):
                    val = row[idx]
                    row_dict[h] = str(val).strip() if val is not None else ""
            parsed_data.append(row_dict)

        return parsed_data

    @staticmethod
    def export_to_excel(filename_title: str, headers: List[str], rows_data: List[List[Any]]) -> bytes:
        wb = openpyxl.Workbook()
        ws = wb.active
        clean_sheet_title = (
            filename_title[:30]
            .replace("/", "-")
            .replace("\\", "-")
            .replace(":", "-")
            .replace("*", "")
            .replace("?", "")
            .replace("[", "")
            .replace("]", "")
            .strip()
        )
        ws.title = clean_sheet_title or "Sheet1"

        # Header Row
        header_fill = PatternFill(start_color="34495E", end_color="34495E", fill_type="solid")
        header_font = Font(name="Arial", size=11, bold=True, color="FFFFFF")
        align_center = Alignment(horizontal="center", vertical="center")
        thin_border = Border(
            left=Side(style='thin', color='CCCCCC'),
            right=Side(style='thin', color='CCCCCC'),
            top=Side(style='thin', color='CCCCCC'),
            bottom=Side(style='thin', color='CCCCCC')
        )

        ws.append(headers)
        for col_num in range(1, len(headers) + 1):
            cell = ws.cell(row=1, column=col_num)
            cell.fill = header_fill
            cell.font = header_font
            cell.alignment = align_center

        for r_idx, r_data in enumerate(rows_data, start=2):
            clean_row = []
            for v in r_data:
                if v is None:
                    clean_row.append("")
                elif isinstance(v, bool):
                    clean_row.append("Yes" if v else "No")
                elif isinstance(v, (date, datetime)):
                    clean_row.append(MasterDataExportImportHelper.format_date_safe(v))
                else:
                    clean_row.append(str(v))
            ws.append(clean_row)
            fill_color = "F8F9FA" if r_idx % 2 == 0 else "FFFFFF"
            row_fill = PatternFill(start_color=fill_color, end_color=fill_color, fill_type="solid")
            for c_num in range(1, len(headers) + 1):
                cell = ws.cell(row=r_idx, column=c_num)
                cell.fill = row_fill
                cell.border = thin_border

        for col in ws.columns:
            max_len = max(len(str(cell.value or '')) for cell in col)
            col_letter = openpyxl.utils.get_column_letter(col[0].column)
            ws.column_dimensions[col_letter].width = min(max(max_len + 4, 12), 45)

        buf = io.BytesIO()
        wb.save(buf)
        buf.seek(0)
        return buf.getvalue()

    @staticmethod
    def export_to_pdf(title: str, headers: List[str], rows_data: List[List[Any]]) -> bytes:
        buf = io.BytesIO()
        doc = SimpleDocTemplate(
            buf,
            pagesize=landscape(A4),
            rightMargin=20,
            leftMargin=20,
            topMargin=35,
            bottomMargin=35,
        )

        styles = getSampleStyleSheet()
        company_style = ParagraphStyle(
            name="CompanyStyle",
            parent=styles["Heading1"],
            fontSize=13,
            leading=16,
            textColor=colors.HexColor("#2C3E50"),
            fontName="Helvetica-Bold",
        )
        title_style = ParagraphStyle(
            name="TitleStyle",
            parent=styles["Normal"],
            fontSize=10,
            leading=13,
            textColor=colors.HexColor("#3498DB"),
            fontName="Helvetica-Bold",
        )
        meta_style = ParagraphStyle(
            name="MetaStyle",
            parent=styles["Normal"],
            fontSize=8,
            leading=10,
            alignment=2,  # Right align
            textColor=colors.HexColor("#5D6D7E"),
        )
        cell_style = ParagraphStyle(
            name="CellStyle",
            parent=styles["Normal"],
            fontSize=8,
            leading=10,
        )
        header_cell_style = ParagraphStyle(
            name="HeaderCellStyle",
            parent=styles["Normal"],
            fontSize=9,
            leading=11,
            fontName="Helvetica-Bold",
            textColor=colors.white,
        )

        now_str = datetime.now().strftime("%Y-%m-%d %H:%M UTC")
        doc_id = f"RPT-{datetime.now().strftime('%Y%m%d%H%M%S')}"

        elements = []

        # 1. Corporate Header Block
        left_header = [
            Paragraph("<b>SOROUR LOGISTICS & IMPORT SERVICES</b>", company_style),
            Paragraph(f"<b>ImportFlow ERP -- {title}</b>", title_style),
        ]
        right_header = [
            Paragraph(f"<b>Doc Ref:</b> {doc_id}", meta_style),
            Paragraph(f"<b>Generated:</b> {now_str}", meta_style),
            Paragraph("<b>Classification:</b> OFFICIAL & CONFIDENTIAL", meta_style),
        ]
        header_table = Table([[left_header, right_header]], colWidths=[500, 300])
        header_table.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
        ]))
        elements.append(header_table)
        elements.append(Spacer(1, 10))

        # 2. Main Data Table
        table_data = []
        table_data.append([Paragraph(h, header_cell_style) for h in headers])
        for row in rows_data:
            clean_cells = []
            for v in row:
                if v is None:
                    txt = "-"
                elif isinstance(v, bool):
                    txt = "Yes" if v else "No"
                elif isinstance(v, (date, datetime)):
                    txt = MasterDataExportImportHelper.format_date_safe(v)
                else:
                    txt = str(v)
                clean_cells.append(Paragraph(txt if txt.strip() else "-", cell_style))
            table_data.append(clean_cells)

        t = Table(table_data, repeatRows=1)
        t.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#2C3E50")),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 5),
            ('TOPPADDING', (0, 0), (-1, 0), 5),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#BDC3C7")),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor("#F8F9FA")]),
        ]))
        elements.append(t)
        elements.append(Spacer(1, 15))

        # 3. Running Header/Footer Callback
        def draw_page_decorations(canvas, doc_obj):
            canvas.saveState()
            page_w, page_h = doc_obj.pagesize

            # Top Accent Line
            canvas.setStrokeColor(colors.HexColor("#3498DB"))
            canvas.setLineWidth(2)
            canvas.line(20, page_h - 20, page_w - 20, page_h - 20)

            # Bottom Footer Divider Line
            canvas.setStrokeColor(colors.HexColor("#BDC3C7"))
            canvas.setLineWidth(0.75)
            canvas.line(20, 22, page_w - 20, 22)

            # Footer Text & Page Number
            canvas.setFont("Helvetica", 7.5)
            canvas.setFillColor(colors.HexColor("#7F8C8D"))
            canvas.drawString(20, 12, "ImportFlow ERP Enterprise System -- Official Operational Record -- Sorour Logistics")
            canvas.drawRightString(page_w - 20, 12, f"Page {canvas.getPageNumber()}")
            canvas.restoreState()

        doc.build(elements, onFirstPage=draw_page_decorations, onLaterPages=draw_page_decorations)
        buf.seek(0)
        return buf.getvalue()
