"""
Core AI and OCR Utilities, Normalization, and LLM Bridges
Specialized for Egyptian Import Operations & Smart Document Extraction.
"""

import os
import re
import io
import json
import logging
import urllib.request
import urllib.error
import difflib
from typing import Any, Dict, List, Optional, Tuple

logger = logging.getLogger(__name__)

# List of critical fields that MUST be validated in Draft B/L
CRITICAL_DRAFT_BL_FIELDS = [
    ("draft_bl_number", "رقم بوليصة الشحن (B/L Number)"),
    ("booking_no", "رقم الحجز الملاحي (Booking Ref)"),
    ("consignee", "المستورد / المرسل إليه (Consignee)"),
    ("acid_number", "رقم القيد الجمركي المسبق (ACID Number)"),
    ("importer_tax_id", "البطاقة الضريبية للمستورد (Importer Tax ID)"),
    ("containers", "بيان وأرقام الحاويات (Container Numbers)"),
]

# List of critical fields in Commercial Invoice
CRITICAL_INVOICE_FIELDS = [
    ("invoice_number", "رقم الفاتورة / أمر التوريد (Invoice / Order No)"),
    ("acid_number", "رقم القيد الجمركي المسبق (ACID Number)"),
    ("importer_tax_id", "البطاقة الضريبية للمستورد (Importer Tax ID)"),
    ("shipper", "المصدر الأجنبي (Shipper / Exporter)"),
    ("consignee", "الشركة المستوردة (Consignee / Importer)"),
    ("total_amount", "إجمالي قيمة الفاتورة (Total Invoice Amount)"),
]

DRAFT_BL_JSON_SCHEMA = {
    "type": "object",
    "properties": {
        "draft_bl_number": {"type": "string", "description": "Bill of Lading number"},
        "booking_no": {"type": "string", "description": "Booking reference number"},
        "shipping_line": {"type": "string", "description": "Shipping line / carrier name"},
        "vessel_name": {"type": "string", "description": "Vessel name"},
        "voyage_number": {"type": "string", "description": "Voyage number"},
        "pol": {"type": "string", "description": "Port of loading"},
        "pod": {"type": "string", "description": "Port of discharge"},
        "place_of_delivery": {"type": "string", "description": "Final place of delivery"},
        "freight_terms": {"type": "string", "enum": ["Freight Prepaid", "Freight Collect"], "description": "Freight terms"},
        "shipper": {"type": "string", "description": "Shipper / Exporter full company name and address"},
        "consignee": {"type": "string", "description": "Consignee full name and address"},
        "notify_party": {"type": "string", "description": "Notify party name and address"},
        "acid_number": {"type": "string", "description": "Egyptian 19-digit ACID number"},
        "importer_tax_id": {"type": "string", "description": "Egyptian 9-digit Importer Tax ID"},
        "shipper_reg_type": {"type": "string", "description": "Shipper Registration Type"},
        "shipper_reg_id": {"type": "string", "description": "Foreign Shipper registration ID / number"},
        "shipper_country": {"type": "string", "description": "Foreign Shipper country"},
        "shipper_country_code": {"type": "string", "description": "Foreign Shipper 2-letter ISO country code"},
        "containers": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "container_no": {"type": "string"},
                    "seal_no": {"type": "string"},
                    "size": {"type": "string"},
                    "gross_weight_kg": {"type": "number"}
                },
                "required": ["container_no"]
            }
        },
        "qty_pkg": {"type": "integer", "description": "Total package count"},
        "package_type": {"type": "string", "description": "Package unit type"},
        "goods_description": {"type": "string", "description": "Commercial description of packages and cargo"},
        "total_gross_weight_kg": {"type": "number", "description": "Total gross weight in kilograms"},
        "total_net_weight_kg": {"type": "number", "description": "Total net weight in kilograms"},
        "cbm": {"type": "number", "description": "Total measurement in cubic meters (CBM)"},
    }
}


def _normalize_text(s: Any) -> str:
    if s is None:
        return ""
    # Strip whitespace, dashes, slashes for numeric/code matching
    return " ".join(str(s).strip().split())


def _fuzzy_match_strings(s1: Any, s2: Any, threshold: float = 0.75) -> Tuple[bool, float]:
    n1 = _normalize_text(s1).lower()
    n2 = _normalize_text(s2).lower()
    if not n1 and not n2:
        return True, 1.0
    if not n1 or not n2:
        return False, 0.0
    if n1 == n2 or n1 in n2 or n2 in n1:
        return True, 1.0
    
    # Strip common corporate headers/suffixes for higher business match precision
    clean_suffixes = [
        "ltd", "limited", "s.p.a", "spa", "llc", "corp", "inc", "co.", "co",
        "trading", "group", "floor", "corpet", "carpet", "commercial", "invoice", "proforma",
        "bill", "to", "ship", "shipper", "consignee", "notify"
    ]
    w1 = [w for w in re.split(r'[\s,.-]+', n1) if w and w not in clean_suffixes]
    w2 = [w for w in re.split(r'[\s,.-]+', n2) if w and w not in clean_suffixes]
    
    if w1 and w2:
        s_w1 = set(w1)
        s_w2 = set(w2)
        inter = s_w1.intersection(s_w2)
        min_len = min(len(s_w1), len(s_w2))
        max_len = max(len(s_w1), len(s_w2))
        # If key corporate terms match (e.g. "shaw europe" inside full address)
        if len(inter) >= 2 and (len(inter) / min_len >= 0.75):
            return True, max(0.92, len(inter) / min_len)
        overlap = len(inter) / max_len
        if overlap >= 0.40:
            return True, max(0.85, overlap)
            
    ratio = difflib.SequenceMatcher(None, n1, n2).ratio()
    return ratio >= threshold, ratio


def _numeric_tolerance_match(v1: Any, v2: Any, tolerance_pct: float = 1.0) -> Tuple[bool, float, float]:
    try:
        f1 = float(str(v1 or "0").replace(",", ""))
        f2 = float(str(v2 or "0").replace(",", ""))
    except (ValueError, TypeError):
        return False, 100.0, 0.0
    if f1 == 0.0 and f2 == 0.0:
        return True, 0.0, 0.0
    base = max(abs(f1), abs(f2))
    diff = abs(f1 - f2)
    pct = (diff / base) * 100.0 if base > 0 else 0.0
    return pct <= tolerance_pct, pct, diff


def _parse_flexible_number(val: Any) -> float:
    if val is None:
        return 0.0
    s = str(val).strip()
    if not s:
        return 0.0
    # Strip currency symbols and letters
    s = re.sub(r'[$€£¥a-zA-Z]', '', s).strip()
    # Normalize OCR whitespace inside formatted numbers e.g. "37. 204, 75" -> "37.204,75"
    s = re.sub(r'([.,])\s+(\d+)', r'\1\2', s)
    s = re.sub(r'(\d+)\s+([.,])', r'\1\2', s)
    s = s.replace(' ', '')
    if not s:
        return 0.0
    
    if '.' in s and ',' in s:
        if s.rfind(',') > s.rfind('.'):
            # European format: 37.741,00 or 18.602,37500 -> 37741.00, 18602.375
            s = s.replace('.', '').replace(',', '.')
        else:
            # US format: 37,741.00 -> 37741.00
            s = s.replace(',', '')
    elif ',' in s and '.' not in s:
        parts = s.split(',')
        if len(parts) == 2:
            # European decimal comma e.g. "268,12500" -> "268.12500", "536,25" -> "536.25", "2,000" -> "2.000"
            s = parts[0] + '.' + parts[1]
        else:
            s = s.replace(',', '')
    elif '.' in s and ',' not in s:
        parts = s.split('.')
        # If e.g. "2.274" (European thousand without decimals), convert if context indicates thousands
        if len(parts) == 2 and len(parts[0]) <= 3 and len(parts[1]) == 3 and int(parts[0]) < 100:
            pass
    try:
        return float(s)
    except (ValueError, TypeError):
        return 0.0


def validate_iso_container_number(cntr_no: str) -> Dict[str, Any]:
    """
    Validates container number according to ISO 6346 check digit algorithm
    and detects provisional/dummy container numbers (e.g. AAAA0000001, TEMP..., DUMMY...).
    """
    if not cntr_no or not isinstance(cntr_no, str):
        return {"is_valid_iso": False, "is_provisional_dummy": True, "dummy_reason": "EMPTY"}

    clean = re.sub(r'[\s/-]', '', cntr_no.strip()).upper()

    # Detect provisional or dummy patterns
    if any(clean.startswith(p) for p in ("DUMM", "TEMP", "TEST", "XXXX", "ZZZZ", "NONE", "TBA", "PROV")):
        return {"is_valid_iso": False, "is_provisional_dummy": True, "dummy_reason": "PROVISIONAL_PREFIX"}

    if re.match(r'^[A-Z]{4}0{5,}\d$', clean) or re.match(r'^([A-Z0-9])\1{9,}$', clean):
        return {"is_valid_iso": False, "is_provisional_dummy": True, "dummy_reason": "DUMMY_SEQUENCE"}

    if len(clean) != 11 or not re.match(r'^[A-Z]{4}\d{7}$', clean):
        return {"is_valid_iso": False, "is_provisional_dummy": False, "dummy_reason": "INVALID_FORMAT"}

    char_map = {
        'A': 10, 'B': 12, 'C': 13, 'D': 14, 'E': 15, 'F': 16, 'G': 17, 'H': 18, 'I': 19, 'J': 20,
        'K': 21, 'L': 23, 'M': 24, 'N': 25, 'O': 26, 'P': 27, 'Q': 28, 'R': 29, 'S': 30, 'T': 31,
        'U': 32, 'V': 34, 'W': 35, 'X': 36, 'Y': 37, 'Z': 38
    }

    total = 0
    for i in range(10):
        ch = clean[i]
        val = char_map[ch] if ch in char_map else int(ch)
        total += val * (2 ** i)

    rem = total % 11
    calc_digit = rem if rem != 10 else 0
    declared_digit = int(clean[10])
    is_valid = (calc_digit == declared_digit)

    return {
        "is_valid_iso": is_valid,
        "is_provisional_dummy": False,
        "dummy_reason": None if is_valid else "CHECK_DIGIT_MISMATCH",
        "calculated_check_digit": calc_digit,
        "declared_check_digit": declared_digit,
    }


def extract_spatial_pdf_text_and_boxes(content_bytes: bytes) -> Tuple[str, dict]:
    """
    Extracts text from PDF preserving 2D spatial layout and bounding boxes
    specifically for multi-column shipping Bills of Lading and Invoices.
    Uses ultra-fast PyMuPDF (fitz) with fallback to pdfplumber/pypdf.
    """
    spatial_boxes: Dict[str, str] = {}
    full_text = ""

    # 1. Ultra-fast PyMuPDF (fitz) primary path (<10ms)
    try:
        import fitz
        doc = fitz.open(stream=content_bytes, filetype="pdf")
        parts = []
        for idx, page in enumerate(doc):
            w = page.rect.width
            h = page.rect.height
            if idx == 0:
                try:
                    spatial_boxes["shipper_box"] = page.get_text("text", clip=fitz.Rect(0, 0.050 * h, 0.46 * w, 0.148 * h)) or ""
                    spatial_boxes["consignee_box"] = page.get_text("text", clip=fitz.Rect(0, 0.145 * h, 0.46 * w, 0.212 * h)) or ""
                    spatial_boxes["notify_box"] = page.get_text("text", clip=fitz.Rect(0, 0.210 * h, 0.46 * w, 0.285 * h)) or ""
                    spatial_boxes["header_box"] = page.get_text("text", clip=fitz.Rect(0.48 * w, 0, w, 0.20 * h)) or ""
                    spatial_boxes["vessel_ports_box"] = page.get_text("text", clip=fitz.Rect(0, 0.285 * h, w, 0.340 * h)) or ""
                    spatial_boxes["cargo_table_box"] = page.get_text("text", clip=fitz.Rect(0, 0.33 * h, w, 0.82 * h)) or ""
                    spatial_boxes["weight_column_box"] = page.get_text("text", clip=fitz.Rect(0.65 * w, 0.40 * h, w, 0.82 * h)) or ""
                except Exception as crop_err:
                    logger.debug(f"fitz spatial crop note: {crop_err}")

            page_text = page.get_text("text", sort=True) or page.get_text("text") or ""
            if page_text and page_text.strip():
                parts.append(page_text)

        full_text = "\n\n".join(parts)
        if full_text and len(full_text.strip()) > 30:
            return full_text, spatial_boxes
    except Exception as fitz_err:
        logger.warning(f"fitz extraction error: {fitz_err}. Trying pdfplumber...")

    try:
        import pdfplumber
        with pdfplumber.open(io.BytesIO(content_bytes)) as pdf:
            parts = []
            for idx, page in enumerate(pdf.pages):
                w = float(page.width)
                h = float(page.height)

                # Page 1 Spatial Bounding Boxes for Bill of Lading
                if idx == 0:
                    try:
                        # Shipper Box (Top Left Column: x 0..46%, y 5.0..14.8%)
                        shipper_crop = page.crop((0, 0.050 * h, 0.46 * w, 0.148 * h))
                        spatial_boxes["shipper_box"] = shipper_crop.extract_text(layout=True) or ""

                        # Consignee Box (Middle Left Column: x 0..46%, y 14.5..21.2%)
                        consignee_crop = page.crop((0, 0.145 * h, 0.46 * w, 0.212 * h))
                        spatial_boxes["consignee_box"] = consignee_crop.extract_text(layout=True) or ""

                        # Notify Box (Lower Left Column: x 0..46%, y 21.0..28.5%)
                        notify_crop = page.crop((0, 0.210 * h, 0.46 * w, 0.285 * h))
                        spatial_boxes["notify_box"] = notify_crop.extract_text(layout=True) or ""

                        # Header Top Right (Carrier, B/L No, SCAC)
                        header_crop = page.crop((0.48 * w, 0, w, 0.20 * h))
                        spatial_boxes["header_box"] = header_crop.extract_text(layout=True) or ""

                        # Vessel / Ports Box (Middle: y 28.5..34%)
                        vessel_crop = page.crop((0, 0.285 * h, w, 0.340 * h))
                        spatial_boxes["vessel_ports_box"] = vessel_crop.extract_text(layout=True) or ""

                        # Cargo & Weights Table (Middle-Bottom: y 33..82%)
                        cargo_crop = page.crop((0, 0.33 * h, w, 0.82 * h))
                        spatial_boxes["cargo_table_box"] = cargo_crop.extract_text(layout=True) or ""

                        # Weight Column (Right side of cargo table: x 65..100%)
                        weight_crop = page.crop((0.65 * w, 0.40 * h, w, 0.82 * h))
                        spatial_boxes["weight_column_box"] = weight_crop.extract_text(layout=True) or ""
                    except Exception as crop_err:
                        logger.debug(f"Spatial crop note: {crop_err}")

                # Extract full layout text
                page_layout_text = page.extract_text(layout=True)
                if page_layout_text and page_layout_text.strip():
                    parts.append(page_layout_text)
                else:
                    parts.append(page.extract_text() or "")

            full_text = "\n\n".join(parts)
    except Exception as e:
        logger.warning(f"pdfplumber extraction failed: {e}. Falling back to pypdf layout mode.")
        try:
            import pypdf
            reader = pypdf.PdfReader(io.BytesIO(content_bytes))
            parts = []
            for p in reader.pages:
                try:
                    t = p.extract_text(extraction_mode="layout")
                except Exception:
                    t = p.extract_text()
                if t:
                    parts.append(t)
            full_text = "\n\n".join(parts)
        except Exception as e2:
            full_text = f"PDF extraction error: {e2}"

    return full_text, spatial_boxes


AI_BL_SYSTEM_PROMPT = (
    "You are an expert maritime shipping documentation & customs parser for Egyptian and international trade.\n"
    "CRITICAL RULES:\n"
    "1. Ignore standard pre-printed terms, clauses, and legal boilerplate (e.g. 'This B/L is not negotiable...', 'Clause 20', 'see Clause 1', 'Lloyds/IMO Number', carrier liability clauses). Extract only actual business entities.\n"
    "2. Shipper: Extract the actual foreign exporter company name and physical address.\n"
    "3. Consignee: Extract the actual Egyptian importing company name and address (e.g. 'ARCHI Brands for Corpet and Floor Trading'), discarding the 'This B/L is not negotiable' clause.\n"
    "4. Total Gross Weight: Must extract the actual weight in kilograms (e.g. 20030.0 from '20,030.000 kgs.'). Never return 0 if cargo weight appears in the container row or Total summary.\n"
    "5. Containers: Extract container number, seal number, size (e.g. 40' HIGH CUBE), and gross weight in kg.\n\n"
)


def _call_gemini_api(raw_text: str, api_key: str) -> Optional[dict]:
    try:
        url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
        prompt = (
            f"{AI_BL_SYSTEM_PROMPT}"
            "Extract structured Bill of Lading fields into valid JSON matching this schema:\n"
            f"{json.dumps(DRAFT_BL_JSON_SCHEMA, indent=2)}\n\n"
            f"DOCUMENT TEXT:\n{raw_text[:8000]}"
        )
        data = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": 0.1, "responseMimeType": "application/json"}
        }
        req = urllib.request.Request(
            url,
            data=json.dumps(data).encode("utf-8"),
            headers={"Content-Type": "application/json", "x-goog-api-key": api_key},
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=12) as response:
            resp_body = json.loads(response.read().decode("utf-8"))
            candidate_text = resp_body["candidates"][0]["content"]["parts"][0]["text"]
            return json.loads(candidate_text.strip())
    except Exception as e:
        logger.warning(f"Gemini API document extraction failed: {e}. Falling back.")
        return None


def _call_anthropic_api(raw_text: str, api_key: str) -> Optional[dict]:
    try:
        url = "https://api.anthropic.com/v1/messages"
        prompt = (
            f"{AI_BL_SYSTEM_PROMPT}"
            "Extract structured Bill of Lading fields matching this schema into valid JSON:\n"
            f"{json.dumps(DRAFT_BL_JSON_SCHEMA, indent=2)}\n\n"
            f"DOCUMENT TEXT:\n{raw_text[:8000]}"
        )
        data = {
            "model": "claude-3-haiku-20240307",
            "max_tokens": 2048,
            "temperature": 0.1,
            "messages": [{"role": "user", "content": prompt}]
        }
        req = urllib.request.Request(
            url,
            data=json.dumps(data).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "x-api-key": api_key,
                "anthropic-version": "2023-06-01"
            },
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=12) as response:
            resp_body = json.loads(response.read().decode("utf-8"))
            content = resp_body["content"][0]["text"].strip()
            if content.startswith("```"):
                content = re.sub(r'^```(?:json)?\n', '', content)
                content = re.sub(r'\n```$', '', content)
            return json.loads(content)
    except Exception as e:
        logger.warning(f"Anthropic API document extraction failed: {e}. Falling back.")
        return None


def _call_openai_api(raw_text: str, api_key: str) -> Optional[dict]:
    try:
        url = "https://api.openai.com/v1/chat/completions"
        prompt = (
            f"{AI_BL_SYSTEM_PROMPT}"
            "Extract structured Bill of Lading fields matching this schema into valid JSON:\n"
            f"{json.dumps(DRAFT_BL_JSON_SCHEMA, indent=2)}\n\n"
            f"DOCUMENT TEXT:\n{raw_text[:8000]}"
        )
        data = {
            "model": "gpt-4o-mini",
            "temperature": 0.1,
            "response_format": {"type": "json_object"},
            "messages": [
                {"role": "system", "content": AI_BL_SYSTEM_PROMPT},
                {"role": "user", "content": prompt}
            ]
        }
        req = urllib.request.Request(
            url,
            data=json.dumps(data).encode("utf-8"),
            headers={"Content-Type": "application/json", "Authorization": f"Bearer {api_key}"},
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=12) as response:
            resp_body = json.loads(response.read().decode("utf-8"))
            content = resp_body["choices"][0]["message"]["content"].strip()
            return json.loads(content)
    except Exception as e:
        logger.warning(f"OpenAI API document extraction failed: {e}. Falling back.")
        return None


__all__ = [
    "logger",
    "CRITICAL_DRAFT_BL_FIELDS",
    "CRITICAL_INVOICE_FIELDS",
    "DRAFT_BL_JSON_SCHEMA",
    "AI_BL_SYSTEM_PROMPT",
    "_normalize_text",
    "_fuzzy_match_strings",
    "_numeric_tolerance_match",
    "_parse_flexible_number",
    "validate_iso_container_number",
    "extract_spatial_pdf_text_and_boxes",
    "_call_gemini_api",
    "_call_anthropic_api",
    "_call_openai_api",
]
