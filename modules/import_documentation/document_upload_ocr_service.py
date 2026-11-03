"""
OCR, spatial text parsing, and file content extraction service for uploaded documents.
"""

import io
import logging
from typing import Any, Dict, List, Optional, Tuple

logger = logging.getLogger(__name__)


def _group_ocr_boxes_into_lines(ocr_res, y_threshold: float = 15.0) -> List[str]:
    if not ocr_res:
        return []
    items = []
    for box, txt, conf in ocr_res:
        text_clean = str(txt).strip()
        if not text_clean:
            continue
        y_center = sum(pt[1] for pt in box) / 4.0
        x_min = min(pt[0] for pt in box)
        items.append({"y": y_center, "x": x_min, "txt": text_clean})
    if not items:
        return []

    items.sort(key=lambda item: (item["y"], item["x"]))
    lines = []
    current_line = []
    last_y = None

    for item in items:
        if last_y is None or abs(item["y"] - last_y) < y_threshold:
            current_line.append(item)
            if last_y is None:
                last_y = item["y"]
            else:
                last_y = (last_y * (len(current_line) - 1) + item["y"]) / len(current_line)
        else:
            current_line.sort(key=lambda i: i["x"])
            lines.append(" ".join(i["txt"] for i in current_line))
            current_line = [item]
            last_y = item["y"]

    if current_line:
        current_line.sort(key=lambda i: i["x"])
        lines.append(" ".join(i["txt"] for i in current_line))

    return lines


def _ocr_pdf_or_image(filename: str, content_bytes: bytes, two_column_table: bool = False) -> str:
    """
    High-accuracy optical character recognition (OCR) for scanned PDFs and images.
    Uses ArabicRapidOCREngine as the primary engine with RTL support and spatial line grouping,
    with fallback to pytesseract.
    """
    lower = filename.lower()
    is_two_col = two_column_table or any(
        k in lower for k in ["price", "quotation", "rate", "مستخلص", "مقايسة", "عرض", "اسعار"]
    )
    result_text = ""

    # 1. Primary Engine: Arabic RapidOCR Engine with RTL and spatial line grouping
    try:
        from modules.import_documentation.arabic_ocr_engine import extract_arabic_ocr_text
        result_text = extract_arabic_ocr_text(filename, content_bytes, two_column_table=is_two_col)
    except Exception as e:
        logger.warning(f"Arabic OCR engine failed for '{filename}': {e}")
        result_text = ""

    # 2. Fallback to pytesseract if Arabic OCR produced insufficient output for images
    if len(result_text.strip()) < 15 and lower.endswith((".png", ".jpg", ".jpeg", ".tiff", ".bmp", ".webp")):
        try:
            import pytesseract
            from PIL import Image
            pil_img = Image.open(io.BytesIO(content_bytes))
            tes_text = pytesseract.image_to_string(pil_img, lang="eng+ara")
            if tes_text and len(tes_text.strip()) > len(result_text.strip()):
                result_text = tes_text
        except Exception as te:
            logger.debug(f"Pytesseract fallback note: {te}")

    return result_text


def extract_text_and_boxes_from_uploaded_file(
    filename: str, content_bytes: bytes, two_column_table: bool = False
) -> Tuple[str, dict]:
    """
    Extracts raw text and 2D spatial bounding boxes from uploaded PDF or files.
    Includes automatic OCR fallback for scanned documents and images.
    """
    lower_name = filename.lower()
    text_content = ""
    spatial_boxes: dict = {}

    if lower_name.endswith(".pdf"):
        try:
            from modules.import_documentation.ai_document_parser import extract_spatial_pdf_text_and_boxes
            text_content, spatial_boxes = extract_spatial_pdf_text_and_boxes(content_bytes)
        except Exception as e:
            logger.warning(f"Spatial PDF extraction failed: {e}. Falling back to pypdf.")
            try:
                import pypdf
                reader = pypdf.PdfReader(io.BytesIO(content_bytes))
                parts = []
                for page in reader.pages:
                    try:
                        t = page.extract_text(extraction_mode="layout")
                    except Exception:
                        t = page.extract_text()
                    if t:
                        parts.append(t)
                text_content = "\n\n".join(parts)
            except Exception as e2:
                text_content = f"PDF Extraction Note: {str(e2)}"
    else:
        text_content = extract_text_from_uploaded_file(filename, content_bytes)

    # Automatic OCR fallback if document contains scanned images or no text stream
    is_two_col = two_column_table or any(
        k in lower_name for k in ["price", "quotation", "rate", "مستخلص", "مقايسة", "عرض", "اسعار"]
    )
    if not text_content or len(text_content.strip()) < 30:
        ocr_text = _ocr_pdf_or_image(filename, content_bytes, two_column_table=is_two_col)
        if ocr_text and len(ocr_text.strip()) > len(text_content.strip()):
            text_content = ocr_text

    return text_content, spatial_boxes


def extract_text_from_uploaded_file(filename: str, content_bytes: bytes) -> str:
    """
    Extracts raw text and table structures from uploaded PDF, Word (.docx), Excel (.xlsx), or Text files.
    """
    lower_name = filename.lower()
    text_content = ""

    if lower_name.endswith(".pdf"):
        try:
            from modules.import_documentation.ai_document_parser import extract_spatial_pdf_text_and_boxes
            spatial_text, _ = extract_spatial_pdf_text_and_boxes(content_bytes)
            text_content = spatial_text
        except Exception as e:
            logger.warning(f"Spatial PDF extraction failed: {e}. Falling back to pypdf.")
            try:
                import pypdf
                reader = pypdf.PdfReader(io.BytesIO(content_bytes))
                parts = []
                for page in reader.pages:
                    try:
                        t = page.extract_text(extraction_mode="layout")
                    except Exception:
                        t = page.extract_text()
                    if t:
                        parts.append(t)
                text_content = "\n\n".join(parts)
            except Exception as e2:
                text_content = f"PDF Extraction Note: {str(e2)}"

        if not text_content or len(text_content.strip()) < 30:
            is_two_col = any(
                k in lower_name for k in ["price", "quotation", "rate", "مستخلص", "مقايسة", "عرض", "اسعار"]
            )
            ocr_text = _ocr_pdf_or_image(filename, content_bytes, two_column_table=is_two_col)
            if ocr_text and len(ocr_text.strip()) > len(text_content.strip()):
                text_content = ocr_text

    elif lower_name.endswith((".png", ".jpg", ".jpeg", ".tiff", ".bmp", ".webp")):
        text_content = _ocr_pdf_or_image(filename, content_bytes)

    elif lower_name.endswith(".docx") or lower_name.endswith(".doc"):
        try:
            import docx
            doc = docx.Document(io.BytesIO(content_bytes))
            parts = [p.text for p in doc.paragraphs if p.text]
            for tbl in doc.tables:
                for row in tbl.rows:
                    parts.append(" | ".join([cell.text.strip() for cell in row.cells if cell.text.strip()]))
            text_content = "\n".join(parts)
        except Exception as e:
            text_content = f"Word Document Extraction Note: {str(e)}"

    elif lower_name.endswith(".xlsx") or lower_name.endswith(".xls"):
        try:
            import openpyxl
            wb = openpyxl.load_workbook(io.BytesIO(content_bytes), data_only=True)
            parts = []
            for sheet in wb.sheetnames:
                ws = wb[sheet]
                for row in ws.iter_rows(values_only=True):
                    row_vals = [str(v).strip() for v in row if v is not None and str(v).strip() != ""]
                    if row_vals:
                        parts.append(" | ".join(row_vals))
            text_content = "\n".join(parts)
        except Exception as e:
            text_content = f"Excel Extraction Note: {str(e)}"

    else:
        try:
            text_content = content_bytes.decode("utf-8")
        except UnicodeDecodeError:
            text_content = content_bytes.decode("latin-1", errors="ignore")

    return text_content


def parse_draft_bl_raw_text(raw_text: str, spatial_boxes: Optional[dict] = None) -> dict:
    from modules.import_documentation.ai_document_parser import extract_draft_bl_with_ai
    return extract_draft_bl_with_ai(raw_text, spatial_boxes=spatial_boxes)
