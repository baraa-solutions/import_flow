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
from contextlib import contextmanager
from typing import Callable
from sqlalchemy.orm import Session


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
    def as_csv_response(filename: str, content: bytes) -> Response:
        """Constructs a standard attachment response for downloadable CSV files with UTF-8 BOM."""
        return Response(
            content=content,
            media_type="text/csv; charset=utf-8",
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
    @contextmanager
    def atomic_transaction(db: Session):
        """
        Guarantees atomic All-or-Nothing execution via savepoint/nested transaction.
        If an exception is raised, rolls back immediately to prevent partial database mutations.
        """
        is_nested = db.in_transaction()
        savepoint = db.begin_nested() if is_nested else db.begin()
        try:
            yield savepoint
            savepoint.commit()
        except Exception:
            savepoint.rollback()
            raise

    @staticmethod
    def execute_atomic_import(
        db: Session,
        rows: List[Dict[str, Any]],
        process_row_fn: Callable[[int, Dict[str, Any]], Any],
    ) -> Dict[str, Any]:
        """
        Executes an atomic import (All-or-Nothing) using an isolated transaction savepoint.
        If ANY row fails validation or DB insertion, the entire batch is rolled back immediately,
        guaranteeing zero partial records remain committed in the database.
        """
        if not rows:
            return {"message": "No rows to import.", "imported_count": 0, "errors": []}

        errors: List[str] = []
        is_nested = db.in_transaction()
        savepoint = db.begin_nested() if is_nested else db.begin()
        imported_count = 0

        try:
            for idx, row in enumerate(rows, start=2):
                try:
                    process_row_fn(idx, row)
                    imported_count += 1
                except Exception as ex:
                    errors.append(f"Row {idx}: {str(ex)}")

            if errors:
                savepoint.rollback()
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail={
                        "message": f"Import aborted: {len(errors)} error(s) encountered. All changes were rolled back (All-or-Nothing).",
                        "errors": errors,
                        "imported_count": 0,
                    },
                )

            savepoint.commit()
            return {
                "message": f"Successfully imported {imported_count} records.",
                "imported_count": imported_count,
                "errors": [],
            }
        except HTTPException:
            if getattr(savepoint, "is_active", False):
                savepoint.rollback()
            raise
        except Exception as e:
            if getattr(savepoint, "is_active", False):
                savepoint.rollback()
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "message": f"Unexpected error during import: {str(e)}. All changes rolled back.",
                    "errors": [str(e)],
                    "imported_count": 0,
                },
            )

    @staticmethod
    def export_to_excel(filename_title: str, headers: List[str], rows_data: List[List[Any]], lang: str = "ar") -> bytes:
        wb = openpyxl.Workbook()
        ws = wb.active
        if lang == "ar" and hasattr(ws, "views") and ws.views.sheetView:
            ws.views.sheetView[0].rightToLeft = True

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

    LOCALIZED_HEADERS = {
        "import_companies": {
            "ar": ['كود الشركة', 'اسم الشركة المستوردة', 'رقم البطاقة الاستيرادية', 'انتهاء الاستيرادية', 'رقم التسجيل الضريبي', 'انتهاء الضريبية', 'رقم السجل التجاري', 'انتهاء السجل', 'العنوان', 'الدولة', 'الهاتف', 'البريد الإلكتروني', 'الملاحظات', 'الحالة'],
            "en": ['ID', 'Company Name', 'Importer Card ID', 'Importer Expiry', 'VAT Registration ID', 'VAT Expiry', 'Commercial Reg #', 'Reg Expiry', 'Address', 'Country', 'Phone', 'Email', 'Notes', 'Status'],
        },
        "import_companies_pdf": {
            "ar": ['كود الشركة', 'اسم الشركة المستوردة', 'البطاقة الاستيرادية', 'انتهاء الاستيرادية', 'التسجيل الضريبي', 'انتهاء الضريبية', 'السجل التجاري', 'انتهاء السجل', 'الهاتف', 'البريد الإلكتروني', 'الحالة'],
            "en": ['ID', 'Company Name', 'Importer Card ID', 'Importer Expiry', 'VAT Registration ID', 'VAT Expiry', 'Commercial Reg #', 'Reg Expiry', 'Phone', 'Email', 'Status'],
        },
        "suppliers": {
            "ar": ['كود المورد', 'اسم الشركة', 'النوع', 'نوع القيد', 'رقم المصدر (نافذة)', 'كود كارجو إكس', 'الدولة', 'كود الدولة', 'العنوان', 'الهاتف', 'المحمول', 'الفاكس', 'البريد الإلكتروني', 'البريد الثانوي', 'الموقع الإلكتروني', 'اسم البنك', 'سويفت كود', 'رقم الحساب', 'الآيبان', 'آيزو', 'قرار 43', 'القائمة البيضاء', 'العلامات التجارية', 'الملاحظات', 'الحالة'],
            "en": ['Code', 'Company Name', 'Type', 'Reg Type', 'Exporter ID (Nafeza)', 'CargoX ID', 'Country', 'Country Code', 'Address', 'Phone', 'Mobile', 'Fax', 'Email', 'Secondary Email', 'Website', 'Bank Name', 'SWIFT Code', 'Account Number', 'IBAN', 'ISO', 'Decree 43', 'White List', 'Brands', 'Notes', 'Status'],
        },
        "suppliers_pdf": {
            "ar": ['الكود', 'اسم الشركة', 'النوع', 'رقم المصدر', 'كارجو إكس', 'الدولة', 'الهاتف', 'البريد', 'البنك / سويفت', 'الاعتمادات', 'الحالة'],
            "en": ['Code', 'Company Name', 'Type', 'Exporter ID', 'CargoX ID', 'Country', 'Phone', 'Email', 'Bank/SWIFT', 'Compliance', 'Status'],
        },
        "partners": {
            "ar": ['كود الشريك', 'اسم الشريك / البنك', 'التصنيف / النوع', 'السجل الضريبي', 'السجل التجاري', 'رقم ترخيص التخليص', 'الموانئ المرخصة', 'كود SCAC', 'أيام السماح الافتراضية', 'معرف فياتا', 'طرق الشحن', 'العملات المدعومة', 'رقم ترخيص النقل', 'أنواع الأسطول', 'نطاق التغطية', 'رقم وثيقة التأمين', 'أنواع التغطية', 'سويفت كود', 'كود البنك', 'اسم الفرع', 'شروط الدفع', 'الحد الائتماني', 'التقييم', 'الشخص المسؤول', 'الهاتف', 'المحمول', 'الفاكس', 'البريد الإلكتروني', 'البريد الثانوي', 'الموقع الإلكتروني', 'العنوان', 'الدولة', 'الملاحظات', 'الحالة'],
            "en": ['Code', 'Partner Name', 'Category / Type', 'Tax ID', 'Commercial Reg #', 'Clearance License #', 'Authorized Ports', 'SCAC Code', 'Default Free Days', 'FIATA ID', 'Shipping Modes', 'Supported Currencies', 'Transport License #', 'Fleet Types', 'Coverage Areas', 'Insurance License #', 'Coverage Types', 'SWIFT Code', 'Bank Code', 'Branch Name', 'Payment Terms', 'Credit Limit', 'Rating', 'Contact Person', 'Phone', 'Mobile', 'Fax', 'Email', 'Secondary Email', 'Website', 'Address', 'Country', 'Notes', 'Status'],
        },
        "partners_pdf": {
            "ar": ['الكود', 'اسم الشريك', 'التصنيف', 'الرقم الضريبي', 'الترخيص / سويفت', 'الهاتف', 'البريد الإلكتروني', 'الدفع / الائتمان', 'الحالة'],
            "en": ['Code', 'Partner Name', 'Category', 'Tax ID', 'License/SCAC/SWIFT', 'Phone', 'Email', 'Payment / Credit', 'Status'],
        },
        "projects": {
            "ar": ['المعرف', 'كود المشروع', 'اسم المشروع / مركز التكلفة', 'العميل', 'مدير المشروع', 'الميزانية', 'العملة', 'الحالة'],
            "en": ['ID', 'Project Code', 'Project Name', 'Client Name', 'Manager Name', 'Budget', 'Currency', 'Status'],
        },
        "projects_pdf": {
            "ar": ['المعرف', 'كود المشروع', 'اسم المشروع', 'العميل', 'المدير', 'الميزانية', 'الحالة'],
            "en": ['ID', 'Project Code', 'Project Name', 'Client', 'Manager', 'Budget', 'Status'],
        },
        "transport_locations": {
            "ar": ['المعرف', 'كود لوكود (UN/LOCODE)', 'اسم الموقع / الميناء', 'النوع', 'الدولة', 'المدينة', 'الحالة', 'الملاحظات'],
            "en": ['ID', 'UN/LOCODE', 'Location Name', 'Type', 'Country', 'City', 'Status', 'Notes'],
        },
        "transport_locations_pdf": {
            "ar": ['المعرف', 'كود لوكود', 'اسم الموقع', 'النوع', 'الدولة', 'المدينة', 'الحالة'],
            "en": ['ID', 'UN/LOCODE', 'Location Name', 'Type', 'Country', 'City', 'Status'],
        },
        "incoterms": {
            "ar": ['شرط الشحن (Incoterm)', 'الاسم الكامل', 'الإصدار', 'الوصف', 'الحالة'],
            "en": ['Incoterm Code', 'Incoterm Name', 'Version', 'Description', 'Status'],
        },
        "incoterms_pdf": {
            "ar": ['الكود', 'اسم القاعدة', 'الإصدار', 'الوصف', 'الحالة'],
            "en": ['Code', 'Rule Name', 'Version', 'Description', 'Status'],
        },
        "currencies": {
            "ar": ['كود العملة', 'اسم العملة', 'الرمز', 'عملة أساسية', 'الكسور العشرية', 'سعر الصرف التجاري (ج.م)', 'سعر الصرف الجمركي (ج.م)', 'الحالة'],
            "en": ['Currency Code', 'Currency Name', 'Symbol', 'Base Currency', 'Decimals', 'Commercial Rate (EGP)', 'Customs Rate (EGP)', 'Status'],
        },
        "currencies_pdf": {
            "ar": ['الكود', 'الاسم', 'الرمز', 'أساسية', 'السعر التجاري', 'السعر الجمركي', 'الحالة'],
            "en": ['Code', 'Name', 'Symbol', 'Base', 'Commercial Rate', 'Customs Rate', 'Status'],
        },
        "customs_tariff": {
            "ar": ['بند التعريفة (HS Code)', 'الوصف الجمركي', 'التصنيف', 'الضريبة الجمركية %', 'ضريبة القيمة المضافة %', 'ضريبة الجدول %', 'رسم تنمية الموارد %', 'رسم الخدمات الجمركية %', 'يتطلب ACID', 'يتطلب شهادة منشأ', 'يتطلب فحص نوعي', 'الجهات العارضة والرقابية', 'ساري من', 'ساري حتى', 'الحالة'],
            "en": ['HS Code', 'Description', 'Category', 'Duty %', 'VAT %', 'Schedule Tax %', 'Development Fee %', 'Service Fee %', 'ACID Req', 'COO Req', 'Inspection Req', 'Regulatory Authorities', 'Effective From', 'Effective To', 'Status'],
        },
        "customs_tariff_pdf": {
            "ar": ['بند التعريفة', 'الوصف الجمركي', 'التصنيف', 'الجمرك %', 'القيمة المضافة %', 'ACID', 'الحالة'],
            "en": ['HS Code', 'Description', 'Category', 'Duty %', 'VAT %', 'ACID', 'Status'],
        },
        "import_files": {
            "ar": ['كود الملف', 'رقم الملف المخصص', 'اسم الشركة', 'اسم المورد', 'رقم أمر الشراء', 'رقم الفاتورة المبدئية', 'طريقة الشحن', 'شرط الشحن', 'الأولوية', 'المرحلة الحالية', 'نسبة الإنجاز', 'الإجراء التالي', 'المسؤول', 'الحالة', 'التكلفة التقديرية', 'العملة', 'ميناء الشحن', 'ميناء الوصول', 'رقم ACID', 'نموذج 4', 'نموذج 46'],
            "en": ['File Code', 'Custom File No', 'Company Name', 'Supplier Name', 'PO Number', 'PI Number', 'Shipment Mode', 'Incoterm', 'Priority', 'Current Stage', 'Progress %', 'Next Action', 'Owner', 'Status', 'Estimated Cost', 'Currency', 'POL', 'POD', 'ACID Number', 'Form 4', 'Form 46'],
        },
        "import_files_pdf": {
            "ar": ['الملف / الكود', 'الشركة', 'المورد', 'أمر الشراء / الفاتورة', 'الشحن / الشرط', 'المرحلة', 'الإنجاز', 'الحالة'],
            "en": ['File / Code', 'Company', 'Supplier', 'PO/PI', 'Mode/Inco', 'Stage', 'Progress', 'Status'],
        },
    }

    LOCALIZED_TITLES = {
        "import_companies": {"ar": "تقرير الشركات المستوردة المصرية", "en": "Egyptian Import Companies Report"},
        "suppliers": {"ar": "تقرير الموردين والمصدرين الأجانب", "en": "Foreign Suppliers & Exporters Report"},
        "partners": {"ar": "تقرير الشركاء ومقدمي الخدمات والبنوك", "en": "External Service Providers & Banks Report"},
        "projects": {"ar": "تقرير المشاريع ومراكز التكلفة", "en": "Projects & Cost Centers Report"},
        "transport_locations": {"ar": "تقرير الموانئ ومواقع النقل", "en": "Transport Locations & Ports Report"},
        "incoterms": {"ar": "تقرير شروط الشحن الدولية (Incoterms)", "en": "Official Incoterms Rules Report"},
        "currencies": {"ar": "تقرير العملات وأسعار الصرف", "en": "Currencies & Exchange Rates Report"},
        "customs_tariff": {"ar": "تقرير جدول التعريفة الجمركية المصرية", "en": "Egyptian Customs Tariff Schedule Report"},
        "import_files": {"ar": "تقرير السجل الشامل لملفات الاستيراد", "en": "Import Files Master Tracking Report"},
    }

    @classmethod
    def get_localized_headers(cls, entity: str, lang: str = "ar", is_pdf: bool = False) -> List[str]:
        target_key = f"{entity}_pdf" if is_pdf else entity
        entity_dict = cls.LOCALIZED_HEADERS.get(target_key) or cls.LOCALIZED_HEADERS.get(entity, {})
        return entity_dict.get(lang) or entity_dict.get("ar") or []

    @classmethod
    def get_localized_title(cls, entity: str, lang: str = "ar") -> str:
        entity_titles = cls.LOCALIZED_TITLES.get(entity, {})
        return entity_titles.get(lang) or entity_titles.get("ar") or entity

    @staticmethod
    def format_status(is_active: bool, lang: str = "ar") -> str:
        if lang == "ar":
            return "نشط" if is_active else "غير نشط"
        return "Active" if is_active else "Inactive"

    @staticmethod
    def format_bool(val: bool, lang: str = "ar") -> str:
        if lang == "ar":
            return "نعم" if val else "لا"
        return "Yes" if val else "No"

    @staticmethod
    def export_to_csv(filename_title: str, headers: List[str], rows_data: List[List[Any]], lang: str = "ar") -> bytes:
        import csv
        buf = io.StringIO()
        # UTF-8 BOM for Arabic support in Microsoft Excel
        buf.write('\ufeff')
        writer = csv.writer(buf, lineterminator='\r\n')
        writer.writerow(headers)
        for r_data in rows_data:
            clean_row = []
            for v in r_data:
                if v is None:
                    clean_row.append("")
                elif isinstance(v, bool):
                    clean_row.append(MasterDataExportImportHelper.format_bool(v, lang))
                elif isinstance(v, (date, datetime)):
                    clean_row.append(MasterDataExportImportHelper.format_date_safe(v))
                else:
                    clean_row.append(str(v))
            writer.writerow(clean_row)
        return buf.getvalue().encode('utf-8')

    @staticmethod
    def _shape_text_if_arabic(text: Any, lang: str) -> str:
        if not text:
            return ""
        s = str(text)
        if lang == "ar":
            try:
                import arabic_reshaper
                from bidi.algorithm import get_display
                # Check if contains Arabic characters
                if any('\u0600' <= ch <= '\u06FF' for ch in s):
                    return get_display(arabic_reshaper.reshape(s))
            except Exception:
                pass
        return s

    @staticmethod
    def export_to_pdf(title: str, headers: List[str], rows_data: List[List[Any]], lang: str = "ar") -> bytes:
        import os
        from reportlab.pdfbase import pdfmetrics
        from reportlab.pdfbase.ttfonts import TTFont

        # Try to register Arial for Arabic Unicode support on Windows
        has_arial = False
        if os.path.exists(r"C:\Windows\Fonts\arial.ttf"):
            try:
                if "Arial" not in pdfmetrics.getRegisteredFontNames():
                    pdfmetrics.registerFont(TTFont("Arial", r"C:\Windows\Fonts\arial.ttf"))
                if "Arial-Bold" not in pdfmetrics.getRegisteredFontNames() and os.path.exists(r"C:\Windows\Fonts\arialbd.ttf"):
                    pdfmetrics.registerFont(TTFont("Arial-Bold", r"C:\Windows\Fonts\arialbd.ttf"))
                has_arial = True
            except Exception:
                has_arial = False

        font_regular = "Arial" if (has_arial and lang == "ar") else "Helvetica"
        font_bold = "Arial-Bold" if (has_arial and lang == "ar") else ("Arial" if has_arial and lang == "ar" else "Helvetica-Bold")
        is_rtl = (lang == "ar")

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
            fontSize=12,
            leading=15,
            textColor=colors.HexColor("#2C3E50"),
            fontName=font_bold,
            alignment=2 if is_rtl else 0,
        )
        title_style = ParagraphStyle(
            name="TitleStyle",
            parent=styles["Normal"],
            fontSize=10,
            leading=13,
            textColor=colors.HexColor("#3498DB"),
            fontName=font_bold,
            alignment=2 if is_rtl else 0,
        )
        meta_style = ParagraphStyle(
            name="MetaStyle",
            parent=styles["Normal"],
            fontSize=8,
            leading=10,
            alignment=0 if is_rtl else 2,
            textColor=colors.HexColor("#5D6D7E"),
            fontName=font_regular,
        )
        cell_style = ParagraphStyle(
            name="CellStyle",
            parent=styles["Normal"],
            fontSize=8,
            leading=10,
            fontName=font_regular,
            alignment=2 if is_rtl else 0,
        )
        header_cell_style = ParagraphStyle(
            name="HeaderCellStyle",
            parent=styles["Normal"],
            fontSize=8.5,
            leading=11,
            fontName=font_bold,
            textColor=colors.white,
            alignment=2 if is_rtl else 0,
        )

        now_str = datetime.now().strftime("%Y-%m-%d %H:%M UTC")
        doc_id = f"RPT-{datetime.now().strftime('%Y%m%d%H%M%S')}"

        elements = []

        # 1. Corporate Header Block
        company_name_text = "شركة سرور للخدمات اللوجستية والاستيراد" if is_rtl else "SOROUR LOGISTICS & IMPORT SERVICES"
        shaped_company = MasterDataExportImportHelper._shape_text_if_arabic(company_name_text, lang)
        shaped_title = MasterDataExportImportHelper._shape_text_if_arabic(title, lang)

        if is_rtl:
            left_header = [
                Paragraph(f"<b>رقم المرجع:</b> {doc_id}", meta_style),
                Paragraph(f"<b>تاريخ الإصدار:</b> {now_str}", meta_style),
                Paragraph("<b>درجة السرية:</b> وثيقة رسمية داخلية", meta_style),
            ]
            right_header = [
                Paragraph(f"<b>{shaped_company}</b>", company_style),
                Paragraph(f"<b>ImportFlow ERP -- {shaped_title}</b>", title_style),
            ]
            header_table = Table([[left_header, right_header]], colWidths=[300, 500])
        else:
            left_header = [
                Paragraph(f"<b>{shaped_company}</b>", company_style),
                Paragraph(f"<b>ImportFlow ERP -- {shaped_title}</b>", title_style),
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
        # If RTL, reverse columns order for native Arabic view
        effective_headers = list(reversed(headers)) if is_rtl else list(headers)
        table_data = []
        table_data.append([
            Paragraph(MasterDataExportImportHelper._shape_text_if_arabic(h, lang), header_cell_style)
            for h in effective_headers
        ])

        for row in rows_data:
            effective_row = list(reversed(row)) if is_rtl else list(row)
            clean_cells = []
            for v in effective_row:
                if v is None:
                    txt = "-"
                elif isinstance(v, bool):
                    txt = MasterDataExportImportHelper.format_bool(v, lang)
                elif isinstance(v, (date, datetime)):
                    txt = MasterDataExportImportHelper.format_date_safe(v)
                else:
                    txt = str(v)
                shaped_val = MasterDataExportImportHelper._shape_text_if_arabic(txt if txt.strip() else "-", lang)
                clean_cells.append(Paragraph(shaped_val, cell_style))
            table_data.append(clean_cells)

        t = Table(table_data, repeatRows=1)
        t.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#2C3E50")),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('ALIGN', (0, 0), (-1, -1), 'RIGHT' if is_rtl else 'LEFT'),
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
            canvas.setFont(font_regular, 7.5)
            canvas.setFillColor(colors.HexColor("#7F8C8D"))
            if is_rtl:
                footer_text = "ImportFlow ERP -- سجل العمليات الرسمي الموحد -- سرور للخدمات اللوجستية"
                canvas.drawRightString(page_w - 20, 12, footer_text)
                canvas.drawString(20, 12, f"صفحة {canvas.getPageNumber()}")
            else:
                footer_text = "ImportFlow ERP Enterprise System -- Official Operational Record -- Sorour Logistics"
                canvas.drawString(20, 12, footer_text)
                canvas.drawRightString(page_w - 20, 12, f"Page {canvas.getPageNumber()}")
            canvas.restoreState()

        doc.build(elements, onFirstPage=draw_page_decorations, onLaterPages=draw_page_decorations)
        buf.seek(0)
        return buf.getvalue()
