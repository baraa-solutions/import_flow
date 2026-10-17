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
import logging
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)

# Model directories
MODELS_DIR = Path(__file__).resolve().parent / "models" / "arabic_ocr"
REC_MODEL_PATH = MODELS_DIR / "rec.onnx"
REC_KEYS_PATH = MODELS_DIR / "dict.txt"

# Lazy-loaded singleton
_arabic_ocr_engine: Optional[Any] = None


def get_arabic_ocr_engine():
    """Returns a singleton instance of the Arabic-capable RapidOCR engine."""
    global _arabic_ocr_engine
    if _arabic_ocr_engine is not None:
        return _arabic_ocr_engine

    try:
        from rapidocr_onnxruntime import RapidOCR
        from rapidocr_onnxruntime.rapid_ocr_api import root_dir, read_yaml, concat_model_path
        from rapidocr_onnxruntime.ch_ppocr_v3_rec.text_recognize import TextRecognizer

        if REC_MODEL_PATH.exists() and REC_KEYS_PATH.exists():
            config = read_yaml(str(root_dir / "config.yaml"))
            config = concat_model_path(config)
            config["Rec"]["model_path"] = str(REC_MODEL_PATH)
            config["Rec"]["keys_path"] = str(REC_KEYS_PATH)

            engine = RapidOCR()
            engine.text_recognizer = TextRecognizer(config["Rec"])
            _arabic_ocr_engine = engine
            logger.info("ArabicRapidOCR engine initialized successfully with ONNX Arabic model.")
        else:
            logger.warning(f"Arabic OCR model files not found at {MODELS_DIR}. Falling back to default RapidOCR.")
            _arabic_ocr_engine = RapidOCR()
    except Exception as e:
        logger.warning(f"Failed to initialize ArabicRapidOCR: {e}. Falling back to default RapidOCR.")
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
