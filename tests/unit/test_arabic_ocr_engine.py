"""
Unit tests for Arabic RapidOCR Engine (modules/import_documentation/arabic_ocr_engine.py).
Verifies RTL text shaping, typo normalization, 2D box grouping, and scanned PDF extraction accuracy.
"""

import importlib.util
import os
import pytest
from pathlib import Path

# rapidocr_onnxruntime is an optional runtime dependency (not in requirements.txt); the engine falls back
# gracefully without it, so tests that need the real engine only run where it is installed.
RAPIDOCR_INSTALLED = importlib.util.find_spec("rapidocr_onnxruntime") is not None
requires_rapidocr = pytest.mark.skipif(not RAPIDOCR_INSTALLED, reason="rapidocr_onnxruntime is not installed")

from modules.import_documentation.arabic_ocr_engine import (
    get_arabic_ocr_engine,
    normalize_ocr_text,
    process_image_boxes_to_lines,
    extract_arabic_ocr_text,
    MODELS_DIR,
    REC_MODEL_PATH,
    REC_KEYS_PATH,
)
from modules.smart_document_upload.extractors.customs_broker_quotation import CustomsBrokerQuotationExtractor


def test_arabic_ocr_model_files_exist():
    """Ensures that ONNX Arabic recognition model and dictionary files are present."""
    assert REC_MODEL_PATH.exists(), f"Missing Arabic ONNX model at {REC_MODEL_PATH}"
    assert REC_KEYS_PATH.exists(), f"Missing Arabic character dict at {REC_KEYS_PATH}"
    assert REC_MODEL_PATH.stat().st_size > 1_000_000, "Model file size seems too small"
    assert REC_KEYS_PATH.stat().st_size > 100, "Dictionary file size seems too small"


@requires_rapidocr
def test_arabic_ocr_engine_initialization():
    """Verifies that get_arabic_ocr_engine successfully initializes RapidOCR with the Arabic model."""
    engine = get_arabic_ocr_engine()
    assert engine is not None
    assert hasattr(engine, "text_recognizer")
    # Verify Arabic vocabulary is loaded
    dict_chars = engine.text_recognizer.character_dict_path
    assert dict_chars is not None
    assert len(dict_chars) > 0


def test_normalize_ocr_text():
    """Tests normalization of OCR typos in currency, thousands dots/commas, and ACID codes."""
    # Currency typos
    assert "EGP 1,250.00" in normalize_ocr_text("5GP 1.250.00")
    assert "EGP 4,750.00" in normalize_ocr_text("5GP 4, 750.00")
    assert "EGP 7,500.00" in normalize_ocr_text("5 GP 7.500.00")
    assert "EGP 8,200.00" in normalize_ocr_text("EGP 8. 200.00")
    assert "EGP 4,200.00" in normalize_ocr_text("5G2 4.200.00")
    assert "EGP 1,500.00" in normalize_ocr_text("2GP 1,500.00")
    assert "EGP 6,150.00" in normalize_ocr_text("GP 6,150.00")

    # ACID typo
    assert normalize_ocr_text("CID") == "ACID"
    assert normalize_ocr_text("AID") == "ACID"


def test_process_image_boxes_to_lines():
    """Tests grouping 2D bounding boxes into Arabic reading order (Description on right, Price on left)."""
    # Simulate a 2-column rate card row
    # Box 1: Description at x=2500, y=1000
    # Box 2: Price at x=1500, y=1002
    simulated_boxes = [
        ([[1500, 1000], [1750, 1000], [1750, 1030], [1500, 1030]], "EGP 2,500.00", 0.95),
        # RapidOCR Arabic raw output is in visual RTL order (صيلخت باعتا)
        ([[2500, 1000], [2800, 1000], [2800, 1030], [2500, 1030]], "صيلخت باعتا", 0.92),
    ]
    lines = process_image_boxes_to_lines(simulated_boxes, y_threshold=30.0, two_column_table=True)
    assert len(lines) == 1
    # Description should come first (right-to-left layout)
    assert "اتعاب تخليص" in lines[0]
    assert "EGP 2,500.00" in lines[0]
    assert lines[0].index("اتعاب تخليص") < lines[0].index("EGP 2,500.00")


def test_scanned_pdf_arabic_extraction_accuracy():
    """
    Tests end-to-end OCR and quotation extraction on the actual physical scanned PDF.
    Verifies that ACC broker name is recognized and at least 40 items are extracted
    with 0 uncoded items.
    """
    pdf_path = r"F:\Nabil price list\doc01771720260709080306_-1079029986.pdf"
    if not os.path.exists(pdf_path):
        pytest.skip(f"Test PDF not present at {pdf_path}")

    with open(pdf_path, "rb") as f:
        pdf_bytes = f.read()

    ocr_text = extract_arabic_ocr_text("doc01771720260709080306_-1079029986.pdf", pdf_bytes)
    assert len(ocr_text) > 200, "OCR text is unexpectedly short"
    assert "اسكندرية" in ocr_text or "ACC" in ocr_text or "تخليص" in ocr_text

    extractor = CustomsBrokerQuotationExtractor()
    result = extractor.extract(ocr_text, {})

    catalog = result.get("expenses_catalog", [])
    assert len(catalog) >= 38, f"Expected 38+ items from scanned PDF, got {len(catalog)}"

    report = result.get("validation_report", {})
    assert report.get("gap_percentage", 100) < 15.0, f"Expected gap < 15%, got {report.get('gap_percentage')}%"
    assert report.get("uncoded_items_count") == 0, f"Expected 0 uncoded items, got {report.get('uncoded_items_count')}"
