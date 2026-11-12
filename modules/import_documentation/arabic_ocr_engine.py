"""
Arabic RapidOCR Engine for ImportFlow ERP.
Provides high-accuracy Optical Character Recognition (OCR) for Arabic and bilingual (Arabic/English)
scanned customs clearance rate cards, shipping documents, bills of lading, and financial vouchers.
Handles Right-to-Left (RTL) text via python-bidi and normalizes common OCR typos.
"""

from __future__ import annotations

import io
import os
import re
import sys
import logging
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)

# Arabic recognition model (rec.onnx + dict.txt). The default RapidOCR det / cls models stay in use; only the
# text recognizer is swapped, and its dictionary also covers Latin letters and digits (bilingual documents).
# In the PyInstaller build these files are added at ARABIC_OCR_MODELS_BUNDLE_SUBDIR (build_backend_exe.py).
ARABIC_OCR_MODELS_BUNDLE_SUBDIR = "modules/import_documentation/models/arabic_ocr"
REC_MODEL_FILENAME = "rec.onnx"
REC_KEYS_FILENAME = "dict.txt"


def resolve_arabic_models_dir() -> Path:
    """Folder holding the Arabic rec model: the PyInstaller bundle root (``sys._MEIPASS``) when frozen, else
    the source tree next to this module."""
    bundle_root = getattr(sys, "_MEIPASS", None)
    if getattr(sys, "frozen", False) and bundle_root:
        return Path(bundle_root).joinpath(*ARABIC_OCR_MODELS_BUNDLE_SUBDIR.split("/"))
    return Path(__file__).resolve().parent / "models" / "arabic_ocr"


def arabic_rec_model_present(models_dir: Optional[Path] = None) -> bool:
    folder = models_dir or resolve_arabic_models_dir()
    return (folder / REC_MODEL_FILENAME).is_file() and (folder / REC_KEYS_FILENAME).is_file()


MODELS_DIR = resolve_arabic_models_dir()
REC_MODEL_PATH = MODELS_DIR / REC_MODEL_FILENAME
REC_KEYS_PATH = MODELS_DIR / REC_KEYS_FILENAME

# Lazy-loaded singleton
_arabic_ocr_engine: Optional[Any] = None
_arabic_rec_loaded: bool = False


def arabic_rec_model_loaded() -> bool:
    """True once the singleton engine was built with the Arabic recognizer (not the default Chinese/English one)."""
    return _arabic_rec_loaded


def _build_legacy_arabic_engine(rec_model: Path, rec_keys: Path) -> Any:
    """rapidocr_onnxruntime < 1.3 (``rapid_ocr_api`` / ``ch_ppocr_v3_rec`` layout, no keyword overrides)."""
    from rapidocr_onnxruntime import RapidOCR
    from rapidocr_onnxruntime.rapid_ocr_api import root_dir, read_yaml, concat_model_path
    from rapidocr_onnxruntime.ch_ppocr_v3_rec.text_recognize import TextRecognizer

    config = concat_model_path(read_yaml(str(root_dir / "config.yaml")))
    config["Rec"]["model_path"] = str(rec_model)
    config["Rec"]["keys_path"] = str(rec_keys)
    engine = RapidOCR()
    engine.text_recognizer = TextRecognizer(config["Rec"])
    return engine


def build_rapidocr_engine(models_dir: Optional[Path] = None) -> Tuple[Any, bool]:
    """Builds a RapidOCR engine, with the Arabic recognizer when its model files exist.

    Returns ``(engine, arabic_rec_loaded)``. Raises ImportError when rapidocr_onnxruntime is not installed."""
    from rapidocr_onnxruntime import RapidOCR

    folder = models_dir or resolve_arabic_models_dir()
    if not arabic_rec_model_present(folder):
        logger.warning("Arabic OCR model files not found at %s. Using the default RapidOCR recognizer.", folder)
        return RapidOCR(), False

    rec_model, rec_keys = folder / REC_MODEL_FILENAME, folder / REC_KEYS_FILENAME
    try:
        # rapidocr_onnxruntime >= 1.3: keyword overrides of the Rec section
        return RapidOCR(rec_model_path=str(rec_model), rec_keys_path=str(rec_keys)), True
    except TypeError:
        return _build_legacy_arabic_engine(rec_model, rec_keys), True


def get_arabic_ocr_engine():
    """Returns a singleton instance of the Arabic-capable RapidOCR engine (None when RapidOCR is unavailable)."""
    global _arabic_ocr_engine, _arabic_rec_loaded
    if _arabic_ocr_engine is not None:
        return _arabic_ocr_engine

    try:
        _arabic_ocr_engine, _arabic_rec_loaded = build_rapidocr_engine()
        if _arabic_rec_loaded:
            logger.info("ArabicRapidOCR engine initialized successfully with ONNX Arabic model.")
    except Exception as e:
        logger.warning(f"Failed to initialize ArabicRapidOCR: {e}. Falling back to default RapidOCR.")
        _arabic_rec_loaded = False
        try:
            from rapidocr_onnxruntime import RapidOCR
            _arabic_ocr_engine = RapidOCR()
        except Exception:
            _arabic_ocr_engine = None

    return _arabic_ocr_engine


def normalize_ocr_text(text: str) -> str:
    """
    Normalizes common OCR digit, currency, and punctuation errors:
    - Currency prefixes: 5GP, 2GP, 5G2, GP, EGp -> EGP
    - European/OCR double-dot prices: 1.250.00 -> 1,250.00
    - Disjoint comma numbers: 4, 750.00 -> 4,750.00
    - Disjoint dot numbers: 8. 200.00 -> 8,200.00
    - Truncated ACID prefix: CID / AID -> ACID
    """
    if not text:
        return ""

    t = text.strip()

    # 1. Normalize currency tokens
    t = re.sub(r"\b(?:[52sS]\s*G[P2]|5G2|GP|EG[P2]|egp)\b", "EGP", t, flags=re.IGNORECASE)

    # 2. Fix double-dot thousands (e.g. 1.250.00 -> 1,250.00, 7.500.00 -> 7,500.00, 14.800.00 -> 14,800.00)
    t = re.sub(r"\b(\d{1,3})\.(\d{3})\.(\d{2})\b", r"\1,\2.\3", t)

    # 3. Fix spaces in thousands numbers (e.g. 4, 750.00 -> 4,750.00)
    t = re.sub(r"\b(\d{1,3}),\s+(\d{3}(?:\.\d{2})?)\b", r"\1,\2", t)

    # 4. Fix spaces after dot thousands (e.g. 8. 200.00 -> 8,200.00)
    t = re.sub(r"\b(\d{1,3})\.\s+(\d{3}(?:\.\d{2})?)\b", r"\1,\2", t)

    # 5. Fix ACID typos in clearance documents
    if t.upper() in ("CID", "AID", "AGID"):
        t = "ACID"

    return t


def process_image_boxes_to_lines(
    ocr_results: List[Any],
    y_threshold: float = 35.0,
    two_column_table: bool = True,
) -> List[str]:
    """
    Groups 2D OCR bounding boxes into logical document lines.
    In Arabic 2-column quotation rate cards:
      - Arabic descriptions are on the right (higher x coordinates).
      - Price numbers and currency tokens are on the left (lower x coordinates).
    Pairs descriptions with prices into structured lines: '[Description] : [Price]'.
    """
    if not ocr_results:
        return []

    try:
        import bidi.algorithm as bidi
        has_bidi = True
    except ImportError:
        has_bidi = False

    items = []
    for item in ocr_results:
        box, txt, conf = item
        raw_str = str(txt).strip()
        if not raw_str:
            continue

        # Re-order RTL text if bidi is available
        if has_bidi:
            txt_disp = bidi.get_display(raw_str).strip()
        else:
            txt_disp = raw_str

        cleaned_txt = normalize_ocr_text(txt_disp)

        xs = [pt[0] for pt in box]
        ys = [pt[1] for pt in box]
        y_center = sum(ys) / 4.0
        x_min = min(xs)
        x_max = max(xs)

        items.append({
            "y": y_center,
            "x_min": x_min,
            "x_max": x_max,
            "txt": cleaned_txt,
            "conf": conf,
        })

    if not items:
        return []

    # Sort vertically from top to bottom
    items.sort(key=lambda it: it["y"])

    lines: List[str] = []
    current_band: List[Dict[str, Any]] = []
    last_y: Optional[float] = None

    for it in items:
        if last_y is None or abs(it["y"] - last_y) < y_threshold:
            current_band.append(it)
            if last_y is None:
                last_y = it["y"]
            else:
                last_y = (last_y * (len(current_band) - 1) + it["y"]) / len(current_band)
        else:
            # Emit current horizontal line band
            if two_column_table:
                # Right to left: Description (high x) first, Price (low x) second
                current_band.sort(key=lambda b: b["x_min"], reverse=True)
                lines.append(" : ".join(b["txt"] for b in current_band if b["txt"]))
            else:
                current_band.sort(key=lambda b: b["x_min"])
                lines.append(" ".join(b["txt"] for b in current_band if b["txt"]))

            current_band = [it]
            last_y = it["y"]

    if current_band:
        if two_column_table:
            current_band.sort(key=lambda b: b["x_min"], reverse=True)
            lines.append(" : ".join(b["txt"] for b in current_band if b["txt"]))
        else:
            current_band.sort(key=lambda b: b["x_min"])
            lines.append(" ".join(b["txt"] for b in current_band if b["txt"]))

    return lines


def extract_arabic_ocr_text(filename: str, content_bytes: bytes, two_column_table: bool = False) -> str:
    """
    Performs full OCR on a document (PDF or Image) using the Arabic-capable RapidOCR engine.
    Renders PDF pages at scale=2.5 for sharp character segmentation.
    Returns cleaned, multi-line structured text suitable for quotation and document extractors.
    """
    engine = get_arabic_ocr_engine()
    if engine is None:
        logger.warning("Arabic OCR engine is not available.")
        return ""

    lower = filename.lower()
    extracted_lines: List[str] = []
    y_thresh = 35.0 if two_column_table else 15.0

    try:
        if lower.endswith(".pdf"):
            import pypdfium2 as pdfium
            pdf = pdfium.PdfDocument(content_bytes)
            max_pages = min(len(pdf), 8)
            for i in range(max_pages):
                page = pdf.get_page(i)
                # Render at 2.5 scale for optimal OCR accuracy on scanned rate cards
                pil_img = page.render(scale=2.5).to_pil()
                img_np = np.array(pil_img)
                ocr_res, _ = engine(img_np)
                if ocr_res:
                    page_lines = process_image_boxes_to_lines(ocr_res, y_threshold=y_thresh, two_column_table=two_column_table)
                    if max_pages > 1:
                        extracted_lines.append(f"--- PAGE {i+1} ---")
                    extracted_lines.extend(page_lines)

        elif lower.endswith((".png", ".jpg", ".jpeg", ".tiff", ".bmp", ".webp")):
            pil_img = Image.open(io.BytesIO(content_bytes)).convert("RGB")
            img_np = np.array(pil_img)
            ocr_res, _ = engine(img_np)
            if ocr_res:
                lines = process_image_boxes_to_lines(ocr_res, y_threshold=y_thresh, two_column_table=two_column_table)
                extracted_lines.extend(lines)

    except Exception as e:
        logger.warning(f"extract_arabic_ocr_text failed for '{filename}': {e}")

    return "\n".join(extracted_lines)
