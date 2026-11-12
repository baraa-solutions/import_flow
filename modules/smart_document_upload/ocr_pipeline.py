"""
Smart Document Upload — Document Text & OCR Pipeline (Universal Entity Extractor)

Turns an uploaded file into plain text for the master-data entity extractor:

* File-type routing by magic bytes first (extension second): PDF / image / Office / plain text.
* PDF: per page, the embedded text layer is used when it carries real text; image-only (scanned) pages are
  rasterized and OCR'd (first ``MAX_OCR_PDF_PAGES`` scanned pages only).
* Images (PNG / JPG / WEBP / TIFF / BMP): EXIF rotation, grayscale, upscaling of small scans and auto-contrast
  before OCR.
* OCR engines are detected at runtime (no hard dependency): the bundled Arabic RapidOCR engine, pytesseract,
  or the ``tesseract`` command line. When none is installed the result says so explicitly
  (``ocr_unavailable``) instead of silently returning empty text.
* All text is normalized: Unicode NFKC (Arabic presentation forms from PDF text layers), Eastern-Arabic /
  Persian digits to ASCII, Arabic decimal / thousands separators, zero-width and bidi control marks, tatweel.
"""

from __future__ import annotations

import io
import logging
import os
import re
import shutil
import subprocess
import unicodedata
from functools import lru_cache
from dataclasses import dataclass, field
from typing import Any, Callable, Dict, List, Optional, Tuple

logger = logging.getLogger(__name__)

# ─── Tunables ─────────────────────────────────────────────────────────────────

MAX_TEXT_LAYER_PDF_PAGES = 10      # text-layer extraction is cheap
MAX_OCR_PDF_PAGES = 3              # OCR is expensive: first 3 scanned pages only
MIN_TEXT_LAYER_CHARS = 25          # a page with fewer meaningful chars is treated as scanned
PDF_RENDER_DPI = 300
MIN_OCR_LONG_EDGE_PX = 1600        # small scans / phone crops are upscaled before OCR
MAX_OCR_LONG_EDGE_PX = 4000
MIN_PDF_RENDER_DPI = 10            # a page so large it would render below this is skipped (not a document scan)
MAX_OCR_IMAGE_PIXELS = 40_000_000  # uploaded images above this are reduced at decode time or refused
OCR_SUBPROCESS_TIMEOUT_S = 90

KIND_PDF = "pdf"
KIND_IMAGE = "image"
KIND_OFFICE = "office"
KIND_TEXT = "text"

IMAGE_EXTENSIONS = (".png", ".jpg", ".jpeg", ".webp", ".tif", ".tiff", ".bmp")
OFFICE_EXTENSIONS = (".docx", ".doc", ".xlsx", ".xls")

OCR_UNAVAILABLE_MESSAGE = (
    "لا يوجد محرك OCR مثبت على الخادم لقراءة الصور والملفات الممسوحة ضوئياً. "
    "انسخ النص والصقه في تبويب \"نص\"، أو ارفع ملف PDF يحتوي على نص قابل للتحديد. "
    "| No OCR engine is installed on the server, so scanned PDFs and images cannot be read. "
    "Paste the text instead, or upload a PDF with a selectable text layer."
)
NO_TEXT_FOUND_MESSAGE = (
    "لم يتم العثور على أي نص مقروء في الملف المرفوع (قد تكون الصورة غير واضحة أو فارغة). "
    "| No readable text was found in the uploaded file (the scan may be blank or too blurry)."
)


class OcrUnavailableError(RuntimeError):
    """Raised when OCR is needed but no OCR engine is installed."""


@dataclass
class DocumentTextResult:
    """Outcome of turning an uploaded file into text (kept with the extraction response for diagnostics)."""

    text: str = ""
    kind: str = KIND_TEXT
    method: str = "none"                 # text_layer | ocr | mixed | office | plain | none
    ocr_engine: Optional[str] = None
    pages_total: int = 0
    pages_processed: int = 0
    ocr_pages: int = 0
    ocr_required: bool = False
    ocr_unavailable: bool = False
    warnings: List[str] = field(default_factory=list)

    @property
    def has_text(self) -> bool:
        return bool(self.text and self.text.strip())

    def to_dict(self) -> Dict[str, Any]:
        return {
            "kind": self.kind,
            "method": self.method,
            "ocr_engine": self.ocr_engine,
            "pages_total": self.pages_total,
            "pages_processed": self.pages_processed,
            "ocr_pages": self.ocr_pages,
            "ocr_required": self.ocr_required,
            "ocr_unavailable": self.ocr_unavailable,
            "text_length": len(self.text or ""),
            "warnings": list(self.warnings),
        }


# ─── Text normalization ───────────────────────────────────────────────────────

_DIGIT_TRANSLATION = str.maketrans(
    "٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹٫٬",
    "01234567890123456789.,",
)
_INVISIBLE_MARKS = re.compile(r"[\u200b-\u200f\u202a-\u202e\u2066-\u2069\ufeff\u0640\u00ad]")
_HORIZONTAL_SPACES = re.compile(r"[ \t\u00a0\u2000-\u200a\u202f\u205f\u3000]+")


def normalize_extracted_text(text: Optional[str]) -> str:
    """Normalizes OCR / PDF text so regex parsing behaves the same for Arabic and English documents."""
    if not text:
        return ""
    t = unicodedata.normalize("NFKC", text)
    t = t.translate(_DIGIT_TRANSLATION)
    t = _INVISIBLE_MARKS.sub("", t)
    t = t.replace("\r\n", "\n").replace("\r", "\n")
    lines = [_HORIZONTAL_SPACES.sub(" ", line).strip() for line in t.split("\n")]
    t = "\n".join(lines)
    t = re.sub(r"\n{3,}", "\n\n", t)
    return t.strip()


def meaningful_char_count(text: Optional[str]) -> int:
    """Letters + digits only (page headers made of dots / lines do not count as a text layer)."""
    if not text:
        return 0
    return sum(1 for ch in text if ch.isalnum())


# ─── File-type routing ────────────────────────────────────────────────────────

def detect_document_kind(filename: str, content_bytes: bytes) -> str:
    """Routes by content signature first (renamed files still work), then by extension."""
    head = content_bytes[:16] if content_bytes else b""
    if head.startswith(b"%PDF-"):
        return KIND_PDF
    if (
        head.startswith(b"\x89PNG\r\n\x1a\n")
        or head.startswith(b"\xff\xd8\xff")
        or (head.startswith(b"RIFF") and head[8:12] == b"WEBP")
        or head.startswith(b"II*\x00")
        or head.startswith(b"MM\x00*")
        or head.startswith(b"BM")
    ):
        return KIND_IMAGE
    if head.startswith(b"PK\x03\x04") or head.startswith(b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1"):
        return KIND_OFFICE

    lower = (filename or "").lower()
    if lower.endswith(".pdf"):
        return KIND_PDF
    if lower.endswith(IMAGE_EXTENSIONS):
        return KIND_IMAGE
    if lower.endswith(OFFICE_EXTENSIONS):
        return KIND_OFFICE
    return KIND_TEXT


# ─── Image pre-processing ─────────────────────────────────────────────────────

def preprocess_image_for_ocr(image: Any) -> Any:
    """EXIF rotation, flatten transparency, grayscale, resize into the OCR sweet spot, auto-contrast."""
    from PIL import Image, ImageOps

    img = ImageOps.exif_transpose(image)
    if img.mode in ("RGBA", "LA", "P"):
        rgba = img.convert("RGBA")
        background = Image.new("RGBA", rgba.size, (255, 255, 255, 255))
        img = Image.alpha_composite(background, rgba)
    img = img.convert("L")

    long_edge = max(img.size)
    if 0 < long_edge < MIN_OCR_LONG_EDGE_PX:
        factor = min(3.0, MIN_OCR_LONG_EDGE_PX / long_edge)
        img = img.resize((int(img.width * factor), int(img.height * factor)), Image.LANCZOS)
    elif long_edge > MAX_OCR_LONG_EDGE_PX:
        factor = MAX_OCR_LONG_EDGE_PX / long_edge
        img = img.resize((int(img.width * factor), int(img.height * factor)), Image.LANCZOS)

    return ImageOps.autocontrast(img, cutoff=1)


def binarize_otsu(gray_image: Any) -> Any:
    """Global Otsu threshold (classic tesseract pre-processing for scanned forms)."""
    histogram = gray_image.histogram()[:256]
    total = sum(histogram)
    if total == 0:
        return gray_image
    sum_all = sum(i * h for i, h in enumerate(histogram))
    sum_bg = 0.0
    weight_bg = 0
    best_threshold, best_variance = 127, -1.0
    for threshold, count in enumerate(histogram):
        weight_bg += count
        if weight_bg == 0:
            continue
        weight_fg = total - weight_bg
        if weight_fg == 0:
            break
        sum_bg += threshold * count
        mean_bg = sum_bg / weight_bg
        mean_fg = (sum_all - sum_bg) / weight_fg
        variance = weight_bg * weight_fg * (mean_bg - mean_fg) ** 2
        if variance > best_variance:
            best_variance, best_threshold = variance, threshold
    return gray_image.point(lambda px: 255 if px > best_threshold else 0)


# ─── OCR engines (runtime detection) ──────────────────────────────────────────

OcrRunner = Callable[[Any], Tuple[str, str]]

_WINDOWS_TESSERACT_PATHS = (
    r"C:\Program Files\Tesseract-OCR\tesseract.exe",
    r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe",
)


def find_tesseract_binary() -> Optional[str]:
    """``TESSERACT_CMD`` env var, then PATH, then the default Windows installer locations."""
    configured = os.environ.get("TESSERACT_CMD")
    if configured and os.path.isfile(configured):
        return configured
    on_path = shutil.which("tesseract")
    if on_path:
        return on_path
    for candidate in _WINDOWS_TESSERACT_PATHS:
        if os.path.isfile(candidate):
            return candidate
    return None


@lru_cache(maxsize=8)
def _tesseract_languages(binary: str) -> str:
    """``ara+eng`` when the Arabic traineddata is installed, otherwise ``eng``."""
    try:
        proc = subprocess.run(
            [binary, "--list-langs"], capture_output=True, timeout=15, check=False
        )
        langs = (proc.stdout or b"").decode("utf-8", errors="ignore").split()
        return "ara+eng" if "ara" in langs else "eng"
    except Exception:
        return "eng"


def _rapidocr_engine() -> Any:
    try:
        from modules.import_documentation.arabic_ocr_engine import get_arabic_ocr_engine
        return get_arabic_ocr_engine()
    except Exception as exc:  # numpy / onnxruntime missing etc.
        logger.debug("RapidOCR engine unavailable: %s", exc)
        return None


def _ocr_with_rapidocr(engine: Any, image: Any) -> str:
    import numpy as np
    from modules.import_documentation.arabic_ocr_engine import process_image_boxes_to_lines

    result, _ = engine(np.array(image.convert("RGB")))
    if not result:
        return ""
    return "\n".join(process_image_boxes_to_lines(result, y_threshold=15.0))


def _ocr_with_pytesseract(image: Any, binary: str) -> str:
    import pytesseract

    pytesseract.pytesseract.tesseract_cmd = binary
    return pytesseract.image_to_string(binarize_otsu(image), lang=_tesseract_languages(binary))


def _ocr_with_tesseract_cli(image: Any, binary: str) -> str:
    buffer = io.BytesIO()
    binarize_otsu(image).save(buffer, format="PNG")
    proc = subprocess.run(
        [binary, "stdin", "stdout", "-l", _tesseract_languages(binary), "--psm", "3"],
        input=buffer.getvalue(),
        capture_output=True,
        timeout=OCR_SUBPROCESS_TIMEOUT_S,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError((proc.stderr or b"").decode("utf-8", errors="ignore")[:200])
    return (proc.stdout or b"").decode("utf-8", errors="ignore")


def _pytesseract_installed() -> bool:
    try:
        import pytesseract  # noqa: F401
        return True
    except Exception:
        return False


def available_ocr_engines() -> List[str]:
    """Names of the OCR engines usable on this machine, in preference order."""
    engines: List[str] = []
    if _rapidocr_engine() is not None:
        engines.append("rapidocr")
    binary = find_tesseract_binary()
    if binary:
        engines.append("pytesseract" if _pytesseract_installed() else "tesseract-cli")
    return engines


def run_ocr_on_image(image: Any) -> Tuple[str, str]:
    """OCR a pre-processed PIL image with the first engine that yields text. Returns ``(text, engine_name)``.

    Raises ``OcrUnavailableError`` when no engine is installed at all."""
    engines_tried = 0
    best_text, best_engine = "", None

    engine = _rapidocr_engine()
    if engine is not None:
        engines_tried += 1
        try:
            best_text, best_engine = _ocr_with_rapidocr(engine, image), "rapidocr"
        except Exception as exc:
            logger.warning("RapidOCR failed: %s", exc)

    if meaningful_char_count(best_text) < MIN_TEXT_LAYER_CHARS:
        binary = find_tesseract_binary()
        if binary:
            engines_tried += 1
            try:
                if _pytesseract_installed():
                    text, name = _ocr_with_pytesseract(image, binary), "pytesseract"
                else:
                    text, name = _ocr_with_tesseract_cli(image, binary), "tesseract-cli"
                if meaningful_char_count(text) > meaningful_char_count(best_text):
                    best_text, best_engine = text, name
            except Exception as exc:
                logger.warning("Tesseract OCR failed: %s", exc)

    if engines_tried == 0:
        raise OcrUnavailableError(OCR_UNAVAILABLE_MESSAGE)
    return best_text or "", best_engine or "none"


# ─── Per-kind extraction ──────────────────────────────────────────────────────

def _ocr_image(image: Any, result: DocumentTextResult, ocr_runner: OcrRunner) -> str:
    result.ocr_required = True
    try:
        text, engine = ocr_runner(preprocess_image_for_ocr(image))
    except OcrUnavailableError:
        result.ocr_unavailable = True
        return ""
    result.ocr_pages += 1
    result.ocr_engine = result.ocr_engine or engine
    return text or ""


def _extract_from_image(content_bytes: bytes, result: DocumentTextResult, ocr_runner: OcrRunner) -> str:
    from PIL import Image

    try:
        image = Image.open(io.BytesIO(content_bytes))  # header only; pixels are decoded by load()
        if image.width * image.height > MAX_OCR_IMAGE_PIXELS:
            # JPEG can be decoded directly at a reduced scale; other formats this large are refused.
            # draft() picks the smallest DCT scale (1/2, 1/4, 1/8) that is still >= the requested size, so ask for
            # half the budget edge to guarantee the decoded image lands within the pixel budget.
            scale = 0.5 * (MAX_OCR_IMAGE_PIXELS / float(image.width * image.height)) ** 0.5
            image.draft("L", (max(1, int(image.width * scale)), max(1, int(image.height * scale))))
            if image.width * image.height > MAX_OCR_IMAGE_PIXELS:
                result.warnings.append(f"image_too_large: {image.width}x{image.height}")
                return ""
        image.load()
    except Exception as exc:  # corrupt file, DecompressionBombError, unsupported mode ...
        result.warnings.append(f"image_unreadable: {type(exc).__name__}")
        return ""
    result.pages_total = getattr(image, "n_frames", 1) or 1
    result.pages_processed = 1
    try:
        return _ocr_image(image, result, ocr_runner)
    except Exception as exc:
        logger.warning("OCR of uploaded image failed: %s", exc)
        result.warnings.append(f"image_ocr_failed: {type(exc).__name__}")
        return ""


def pdf_render_dpi(width_pt: float, height_pt: float) -> float:
    """Render resolution for a page: ``PDF_RENDER_DPI`` for normal paper sizes, lowered so the long edge never
    exceeds ``MAX_OCR_LONG_EDGE_PX`` (a 522-byte PDF can declare a 200-inch page)."""
    long_edge_pt = max(float(width_pt), float(height_pt), 1.0)
    return min(float(PDF_RENDER_DPI), MAX_OCR_LONG_EDGE_PX * 72.0 / long_edge_pt)


def _render_pdf_page(page: Any) -> Optional[Any]:
    """Grayscale raster of the page within the OCR pixel budget, or None when the page is absurdly large."""
    import fitz
    from PIL import Image

    dpi = pdf_render_dpi(page.rect.width, page.rect.height)
    if dpi < MIN_PDF_RENDER_DPI:
        return None
    zoom = dpi / 72.0
    pixmap = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), colorspace=fitz.csGRAY, alpha=False)
    return Image.frombytes("L", (pixmap.width, pixmap.height), pixmap.samples)


def _extract_from_pdf(content_bytes: bytes, result: DocumentTextResult, ocr_runner: OcrRunner) -> str:
    try:
        import fitz  # PyMuPDF
    except Exception:
        return _extract_from_pdf_pypdf(content_bytes, result)

    try:
        document = fitz.open(stream=content_bytes, filetype="pdf")
    except Exception as exc:
        result.warnings.append(f"pdf_unreadable: {type(exc).__name__}")
        return _extract_from_pdf_pypdf(content_bytes, result)

    parts: List[str] = []
    text_pages = 0
    try:
        result.pages_total = document.page_count
        for index in range(min(document.page_count, MAX_TEXT_LAYER_PDF_PAGES)):
            result.pages_processed += 1
            # One bad page (render limit, corrupt stream, OCR crash) is reported and skipped, never a 500.
            try:
                page_text, is_text_page = _read_pdf_page(document, index, result, ocr_runner)
            except Exception as exc:
                logger.warning("PDF page %s could not be read: %s", index + 1, exc)
                result.warnings.append(f"page_{index + 1}_unreadable: {type(exc).__name__}")
                continue
            if page_text.strip():
                parts.append(page_text)
            text_pages += int(is_text_page)
    finally:
        document.close()

    if result.ocr_pages and text_pages:
        result.method = "mixed"
    elif result.ocr_pages:
        result.method = "ocr"
    elif text_pages:
        result.method = "text_layer"
    if result.pages_total > MAX_TEXT_LAYER_PDF_PAGES:
        result.warnings.append(f"pdf_truncated_to_{MAX_TEXT_LAYER_PDF_PAGES}_pages")
    return "\n\n".join(parts)


def _read_pdf_page(document: Any, index: int, result: DocumentTextResult, ocr_runner: OcrRunner) -> Tuple[str, bool]:
    """Text of one page: its text layer, or OCR of its raster for scanned pages. Returns ``(text, from_text_layer)``."""
    page = document.load_page(index)
    page_text = page.get_text("text", sort=True) or ""
    if meaningful_char_count(page_text) >= MIN_TEXT_LAYER_CHARS:
        return page_text, True
    # Scanned / image-only page: rasterize and OCR (bounded page budget)
    if result.ocr_pages >= MAX_OCR_PDF_PAGES or result.ocr_unavailable:
        return page_text, False
    image = _render_pdf_page(page)
    if image is None:
        result.warnings.append(f"page_{index + 1}_too_large")
        return page_text, False
    ocr_text = _ocr_image(image, result, ocr_runner)
    best = ocr_text if meaningful_char_count(ocr_text) > meaningful_char_count(page_text) else page_text
    return best, False


def _extract_from_pdf_pypdf(content_bytes: bytes, result: DocumentTextResult) -> str:
    """Text-layer only fallback when PyMuPDF is missing or cannot open the file."""
    try:
        import pypdf

        reader = pypdf.PdfReader(io.BytesIO(content_bytes))
        result.pages_total = len(reader.pages)
        pages = reader.pages[:MAX_TEXT_LAYER_PDF_PAGES]
        result.pages_processed = len(pages)
        text = "\n\n".join((p.extract_text() or "") for p in pages)
        if meaningful_char_count(text) >= MIN_TEXT_LAYER_CHARS:
            result.method = "text_layer"
        return text
    except Exception as exc:
        result.warnings.append(f"pdf_text_layer_failed: {type(exc).__name__}")
        return ""


def _extract_from_office_or_text(filename: str, content_bytes: bytes, kind: str, result: DocumentTextResult) -> str:
    try:
        from modules.import_documentation.document_upload_ocr_service import extract_text_from_uploaded_file

        text = extract_text_from_uploaded_file(filename, content_bytes)
    except Exception as exc:
        result.warnings.append(f"text_extraction_failed: {type(exc).__name__}")
        return ""
    # The shared helper reports failures as "<Kind> Extraction Note: ..." text; never feed that to the parser.
    if re.match(r"^\s*(?:Word Document|Excel|PDF) Extraction Note:", text or ""):
        result.warnings.append("text_extraction_failed")
        return ""
    result.method = "office" if kind == KIND_OFFICE else "plain"
    return text


# ─── Public entry point ───────────────────────────────────────────────────────

def extract_document_text(
    filename: str,
    content_bytes: bytes,
    ocr_runner: Optional[OcrRunner] = None,
) -> DocumentTextResult:
    """Routes the file to the right reader (text layer / OCR / Office) and returns normalized text plus
    diagnostics. Never raises for unreadable content: the caller decides how to report an empty result."""
    runner = ocr_runner or run_ocr_on_image
    kind = detect_document_kind(filename, content_bytes)
    result = DocumentTextResult(kind=kind)

    try:
        if kind == KIND_PDF:
            raw = _extract_from_pdf(content_bytes, result, runner)
        elif kind == KIND_IMAGE:
            raw = _extract_from_image(content_bytes, result, runner)
            if result.ocr_pages:
                result.method = "ocr"
        else:
            raw = _extract_from_office_or_text(filename, content_bytes, kind, result)
    except Exception as exc:  # last-resort guard: unreadable content becomes "no readable text", not a 500
        logger.exception("Document text extraction failed for '%s'", filename)
        result.warnings.append(f"extraction_failed: {type(exc).__name__}")
        raw = ""

    result.text = normalize_extracted_text(raw)
    if not result.has_text and result.method != "none" and not result.ocr_pages:
        result.method = "none"
    return result
