"""
Smart Bill of Lading (B/L) Parser & Heuristic Extraction Engine
Specialized for Egyptian Import Operations & Multi-Carrier Layouts.
"""

import os
import re
import logging
from typing import Any, Dict, List, Optional, Tuple

from modules.import_documentation.ai_parser_core import (
    logger,
    CRITICAL_DRAFT_BL_FIELDS,
    _parse_flexible_number,
    _call_gemini_api,
    _call_anthropic_api,
    _call_openai_api,
)

# Standard Maritime Legal Clauses & Pre-printed Boilerplate patterns to suppress
LEGAL_BOILERPLATE_PATTERNS = [
    r'This B/L is not negotiable unless marked [\'"]To Order[\'"] or [\'"]To Order of \.\.\.[\'"] here\.?',
    r'CARRIER[\'S\s]*AGENTS ENDORSEMENTS:\s*\(Include Agent\(s\) at POD\)',
    r'Lloyds/IMO Number:\s*\d+',
    r'NO\.\s*OF\s*RIDER\s*PAGES(?:\s*\d+\s*[A-Za-z]+)?',
    r'\(No responsibility shall attach to Carrier or to his Agent for failure to notify - see\s*Clause 20\)',
    r'\(see\s*Clause\s*\d+\s*(?:&\s*\d+)?\)',
    r'\(Combined Transport ONLY - see Clause \d+ & \d+\.\d+\)',
    r'PARTICULARS FURNISHED BY THE SHIPPER\s*-\s*NOT CHECKED BY CARRIER\s*-\s*CARRIER NOT RESPONSIBLE.*',
    r'Carrier has no liability or responsibility whatsoever for thermal loss or damage.*',
    r'RECEIVED by the Carrier in apparent good order and condition.*',
    r'If this is a negotiable \(To Order / of\) Bill of Lading.*',
    r'IN WITNESS WHEREOF the Carrier or their Agent has signed.*',
    r'This carriage is subject to the MSC Sea Waybill or Bill of Lading Terms and Conditions.*',
    r'Standard Edition\s*-\s*\d+/\d+',
    r'TERMS CONTINUED ON REVERSE.*',
    r'"Port-To-Port" or "Combined Transport"\(see Clause 1\)',
]


def clean_bl_boilerplate(text: str) -> str:
    """Strips pre-printed maritime boilerplate and legal clauses from extracted document text."""
    if not text:
        return ""
    cleaned = text
    for pat in LEGAL_BOILERPLATE_PATTERNS:
        cleaned = re.sub(pat, ' ', cleaned, flags=re.IGNORECASE)
    return cleaned


def clean_exporter_name(raw: str, reg_id: Optional[str] = None) -> str:
    """
    Cleans raw exporter name string:
    - Strips markdown formatting (*, #, _, `)
    - Strips OCR artifacts ('ORIGINAL', 'Page 1 of 1', 'Serial No.', 'Certificate No.', '1. Exporter:', 'Shipper:', etc.)
    - Strips foreign tax registration code (e.g. 'LT300591314', 'IT01982510305')
    - Strips trailing address snippets, postal codes, and EUR.1 number tokens
    """
    if not raw:
        return ""
    cleaned = re.sub(r'[*#_`]', '', raw).strip()
    
    # Remove OCR top-level document noise
    cleaned = re.sub(r'\b(?:ORIGINAL|DUPLICATE|TRIPLICATE|Page\s*\d+\s*(?:of\s*\d+)?)\b', '', cleaned, flags=re.I).strip()
    cleaned = re.sub(r'Serial\s*No\.?|Certificate\s*No\.?\s*[0-9A-Z/_-]*', '', cleaned, flags=re.I).strip()
    cleaned = re.sub(r'CERTIFICATE\s*OF\s*ORIGIN(?:\s*OF\s*THE\s*PEOPLE\'?S\s*REPUBLIC\s*OF\s*CHINA)?', '', cleaned, flags=re.I).strip()
    
    # Strip prefix label
    cleaned = re.sub(r'^(?:1\.?\s*)?(?:Exporter|Shipper|Consignor|Producer)[:\s]*', '', cleaned, flags=re.I).strip()
    
    # Strip country code + reg ID prefix
    if reg_id:
        cleaned = re.sub(r'^' + re.escape(reg_id) + r'[,:\s]*', '', cleaned, flags=re.I).strip()
    cleaned = re.sub(r'^[A-Z]{2}\d{6,15}[,:\s]*', '', cleaned).strip()

    # If multiline, isolate the line containing company entity names or take line 1
    lines = [l.strip() for l in cleaned.splitlines() if l.strip()]
    cand_line = ""
    for l in lines:
        l_sub = re.sub(r'^(?:1\.?\s*)?(?:Exporter|Shipper|Consignor|Producer)[:\s]*', '', l, flags=re.I).strip()
        if not l_sub or re.search(r'^(?:ORIGINAL|Serial\s*No|Certificate\s*No|Page\s*\d)', l_sub, re.I):
            continue
        if any(term in l_sub.upper() for term in ('LTD', 'CO.', 'CO,', 'COMPANY', 'CORP', 'SPA', 'S.P.A', 'GMBH', 'UAB', 'INC', 'SRL', 'IMP&EXP', 'INTERNATIONAL', 'MANUFACTURING')):
            cand_line = l_sub
            break
    if not cand_line and lines:
        cand_line = lines[0]
    cleaned = cand_line or cleaned

    # Cut off at pipe | or EUR.1 or Movement Certificate or Address markers
    cleaned = re.split(
        r'\s*\|\s*|\s*EUR\.?1\b|\s*No\s*[A-Z]?\s*\d{5,8}|\s*Via\s+|\s*EITMINI|\s*Street\b|\s*St\.\b|\s*Building\b|\s*c/o\b|\s*Road\b|\s*District\b|\s*Zone\b|\s*NO\.\d+',
        cleaned,
        flags=re.I
    )[0].strip()
    cleaned = re.sub(r'[,;\-\s]+$', '', cleaned).strip()
    return cleaned


def clean_consignee_name(raw: str) -> str:
    """
    Cleans consignee / importer name:
    - Strips OCR artifacts ('OF', 'CERTIFICATE OF ORIGIN', 'THE PEOPLE'S REPUBLIC OF CHINA', '2.Consignee', etc.)
    - Isolates company name
    - Strips trailing address snippets
    """
    if not raw:
        return ""
    cleaned = re.sub(r'[*#_`]', '', raw).strip()
    # Strip headers
    cleaned = re.sub(r'CERTIFICATE\s*OF\s*ORIGIN', '', cleaned, flags=re.I).strip()
    cleaned = re.sub(r'THE\s*PEOPLE\'?S\s*REPUBLIC\s*OF\s*CHINA', '', cleaned, flags=re.I).strip()
    cleaned = re.sub(r'^(?:OF\s+)+', '', cleaned, flags=re.I).strip()
    cleaned = re.sub(r'^(?:2\.?\s*|3\.?\s*)?(?:Consignee|Importer|Buyer|Receiver)[:\s]*', '', cleaned, flags=re.I).strip()
    cleaned = re.sub(r'^(?:OF\s+)+', '', cleaned, flags=re.I).strip()

    lines = [l.strip() for l in cleaned.splitlines() if l.strip()]
    cand_line = ""
    for l in lines:
        l_sub = re.sub(r'^(?:2\.?\s*|3\.?\s*)?(?:Consignee|Importer|Buyer)[:\s]*', '', l, flags=re.I).strip()
        l_sub = re.sub(r'^(?:OF\s+)+', '', l_sub, flags=re.I).strip()
        if not l_sub or l_sub.upper() in ('OF', 'AND', 'EGYPT', 'ORIGINAL'):
            continue
        if any(term in l_sub.upper() for term in ('CONSTRUCTION', 'FINISHING', 'TRADING', 'BRANDS', 'CORPET', 'CARPET', 'FLOOR', 'GROUP', 'CO', 'LTD', 'CORP', 'COMMERCE', 'IMPORT', 'COMPANY', 'ENTERPRISE')):
            cand_line = l_sub
            break
    if not cand_line and lines:
        for l in lines:
            if l.upper() not in ('OF', 'AND', 'EGYPT', 'ORIGINAL', 'PAGE 1 OF 1'):
                cand_line = l
                break
    cleaned = cand_line or cleaned
    cleaned = re.split(
        r'\s*\|\s*|\s*3\.\s*Means|\s*44,\s*RD|\s*Street\b|\s*St\.\b|\s*Building\b|\s*c/o\b|\s*Road\b|\s*District\b|\s*Zone\b|\s*Maadi\b',
        cleaned,
        flags=re.I
    )[0].strip()
    cleaned = re.sub(r'[,;\-\s]+$', '', cleaned).strip()
    return cleaned


def _clean_company_entity_lines(lines: List[str], header_pattern: str) -> List[str]:
    """
    Helper to clean entity lines in multi-column maritime B/Ls.
    Strictly isolates the left column (before multi-space right-column splits),
    strips header labels, legal boilerplate, endorsements, and inline VAT/Phone numbers.
    """
    clean_lines = []
    
    boilerplate_patterns = [
        r'carriage\s+is\s+subject',
        r'sea\s+waybill',
        r'bill\s+of\s+lading\s+terms',
        r'terms\s+(?:and|&)\s+conditions',
        r'shipper\'?s\s+load',
        r'said\s+to\s+contain',
        r'fcl/fcl',
        r'carrier\'?s\s+agent',
        r'endorsement',
        r'for\s+receiver\'?s\s+account',
        r'freetime',
        r'demurrage',
        r'merchants?\s+to\s+remain',
        r'advance\s+cargo\s+information',
        r'consequences\s+arising',
        r'suspend\s+carriage',
        r'or\s+inaccuracy',
        r'particulars\s+furnished',
        r'port\s+of\s+discharge\s+agent',
        r'misr\s+maritime',
        r'alexandria\s+old\s+port',
        r'lloyds/imo',
        r'imo\s+number',
        r'free\s+out',
        r'as\s+per\s+agreement',
        r'cargo\s+shall\s+not\s+be\s+delivered',
        r'received\s+by\s+the\s+carrier',
        r'in\s+accepting\s+this',
        r'signed\s+on\s+behalf',
        r'terms\s+continued',
        r'rider\s+page',
        r'standard\s+edition',
        r'clause\s*\d+',
        r'this\s+b/l\s+is\s+not\s+negotiable',
        r'no\s+responsibility\s+shall\s+attach',
        r'combined\s+transport\s+only',
        r'www\.\w+\.com',
        r'scac\s+code',
        r'vessel\s+(?:and|&)\s+voyage',
        r'port\s+of\s+loading',
        r'port\s+of\s+discharge',
        r'booking\s+ref',
        r'place\s+of\s+receipt',
        r'place\s+of\s+delivery',
        r'container\s+number',
        r'description\s+of\s+packages',
        r'gross\s+cargo\s+weight',
        r'measurement',
        r'freight\s+prepaid',
        r'freight\s+collect',
        r'total\s+items',
        r'total\s+packages',
        r'p\.o\.\s*box',
        r'mediterranean\s+shipping\s+company',
        r'^\+?\d[\d\s\-().]{7,}$',
    ]
    bp_regex = re.compile('|'.join(boilerplate_patterns), re.IGNORECASE)

    for l in lines:
        l_str = l.strip()
        if not l_str:
            continue

        # 1. ISOLATE LEFT COLUMN FIRST: In 2D text, right-column text is separated by 2 or more spaces/tabs
        col_parts = re.split(r'\s{2,}', l_str)
        l_left = col_parts[0].strip() if col_parts else l_str
        if not l_left:
            continue

        # 2. Check header label line ONLY on the isolated left column
        if re.search(header_pattern, l_left, re.IGNORECASE):
            continue

        # 3. Skip standard pre-printed maritime boilerplate & right column carrier noise
        if bp_regex.search(l_left):
            continue

        # 4. Strip trailing & leading inline annotations (Phone, Fax, Email, Website, VAT No, Tax ID)
        l_clean = re.sub(r'^(?:Phone|Fax|Tel|Email|Website)\s*:.*', '', l_left, flags=re.IGNORECASE).strip()
        l_clean = re.sub(r'\s+(?:Phone|Fax|Tel|Email|Website)\s*:.*', '', l_clean, flags=re.IGNORECASE).strip()
        l_clean = re.sub(r'\s+VAT\s*No:.*', '', l_clean, flags=re.IGNORECASE).strip()
        l_clean = re.sub(r'\s+TAX\s*ID:.*', '', l_clean, flags=re.IGNORECASE).strip()
        if l_clean and not bp_regex.search(l_clean) and not re.match(r'^\+?\d[\d\s\-().]{7,}$', l_clean):
            clean_lines.append(l_clean)
    return clean_lines


def _extract_shipper_entity(text: str, spatial_boxes: Optional[dict] = None) -> str:
    """Extracts foreign shipper / exporter entity name and address, strictly from left column."""
    if spatial_boxes and spatial_boxes.get("shipper_box"):
        s_box = spatial_boxes["shipper_box"].strip()
        lines = _clean_company_entity_lines(s_box.splitlines(), r'SHIPPER\s*:?')
        if lines:
            return "\n".join(lines[:4])

    egypt_filter = r'(?:Cairo|Egypt|Maadi|Alexandria|Giza|Egitto)'

    # 1. Look for SHIPPER: block where text is AFTER SHIPPER:
    m_shp = re.search(r'(?:SHIPPER:|1\.Shipper|EXPORTER:)[ \t]*[^\n\r]*\r?\n([\s\S]*?)(?:CONSIGNEE|CARRIER|NOTIFY|VESSEL|PORT OF|\Z)', text, re.IGNORECASE)
    if m_shp:
        lines = _clean_company_entity_lines(m_shp.group(1).splitlines(), r'SHIPPER\s*:?')
        if lines and not re.search(egypt_filter, lines[0], re.IGNORECASE):
            if re.search(r'[A-Za-z]{3,}', lines[0]) and not re.search(r'^(?:DRAFT|ORIGINAL|COPY|CONTAINER|TOTAL|Lloyds|IMO|RIDER)', lines[0], re.IGNORECASE):
                return "\n".join(lines[:4])

    # 2. Look for shipper block where text is placed BEFORE the word SHIPPER: (e.g. MSC OCR stream)
    m_before = re.search(r'([A-Z0-9&.,\- ]+(?:\n[A-Z0-9&.,\- ]+){1,4})\s*\n\s*SHIPPER:', text, re.IGNORECASE)
    if m_before:
        lines = _clean_company_entity_lines(m_before.group(1).splitlines(), r'SHIPPER\s*:?')
        if lines:
            return "\n".join(lines[-4:])

    # 3. Look for corporate exporter pattern with country
    m_co = re.search(r'([A-Z0-9&.,\- ]+\s+(?:LTD|LIMITED|SPA|S\.P\.A|LLC|CORP|INC|GMBH|CO\.)[\s\S]*?(?:UNITED KINGDOM|ITALY|GERMANY|CHINA|TURKEY|USA|FRANCE|SPAIN|INDIA|[A-Z]{2}\d{1,2}\s*\d[A-Z]{2}))', text, re.IGNORECASE)
    if m_co:
        lines = _clean_company_entity_lines(m_co.group(1).splitlines(), r'SHIPPER\s*:?')
        if lines:
            return "\n".join(lines[:4])

    return ""


def _extract_consignee_entity(text: str, spatial_boxes: Optional[dict] = None) -> str:
    """Extracts Egyptian importer / consignee entity name and address, strictly from left column."""
    if spatial_boxes and spatial_boxes.get("consignee_box"):
        c_box = spatial_boxes["consignee_box"].strip()
        lines = _clean_company_entity_lines(c_box.splitlines(), r'CONSIGNEE\s*:?')
        if lines:
            return "\n".join(lines[:3])

    # 1. Look for text after CONSIGNEE: (skip header line with "This B/L is not negotiable...")
    m = re.search(r'(?:CONSIGNEE:|CONSIGNED\s+TO:|2\.Consignee)[ \t]*[^\n\r]*\r?\n([\s\S]*?)(?:NOTIFY|VESSEL|PORT OF LOADING|PORT OF DISCHARGE|CARRIER\'S|\Z)', text, re.IGNORECASE)
    if m:
        lines = _clean_company_entity_lines(m.group(1).splitlines(), r'CONSIGNEE\s*:?')
        if lines:
            return "\n".join(lines[:3])

    # 2. Look for text placed BEFORE the word CONSIGNEE:
    m_before = re.search(r'([A-Z0-9&.,\- ]+(?:\n[A-Z0-9&.,\- ]+){1,4})\s*\n\s*CONSIGNEE:', text, re.IGNORECASE)
    if m_before:
        lines = _clean_company_entity_lines(m_before.group(1).splitlines(), r'CONSIGNEE\s*:?')
        if lines:
            return "\n".join(lines[-4:])

    # 3. Look for Egyptian importer entity pattern (excluding maritime carriers)
    carrier_blacklist = r'(?:Mediterranean\s+Shipping|Maersk|CMA\s+CGM|Hapag|Cosco|Ocean\s+Network|Evergreen|Yang\s+Ming)'
    m_eg = re.search(r'([A-Z0-9&.,\- ]+(?:Brands|Trading|Import|Export|Industries|Floor|Corpet|Carpet|Commercial)[\s\S]*?(?:Cairo|Maadi|Alexandria|Giza|Egypt|Egitto))', text, re.IGNORECASE)
    if m_eg:
        cand = m_eg.group(1).strip()
        if not re.search(carrier_blacklist, cand, re.IGNORECASE):
            lines = _clean_company_entity_lines(cand.splitlines(), r'CONSIGNEE\s*:?')
            if lines:
                return "\n".join(lines[:3])

    return ""


def _extract_notify_party_entity(text: str, spatial_boxes: Optional[dict] = None) -> str:
    """Extracts notify party entity name and address, strictly from left column."""
    if spatial_boxes and spatial_boxes.get("notify_box"):
        n_box = spatial_boxes["notify_box"].strip()
        lines = _clean_company_entity_lines(n_box.splitlines(), r'NOTIFY\s+PARTIES\s*:?')
        if lines:
            return "\n".join(lines[:3])

    m_same_line = re.search(r'(?:NOTIFY\s+PARTIES?|NOTIFY\s+PARTY|3\.Notify\s+party)[:\s]+([^\n\r]+)', text, re.IGNORECASE)
    if m_same_line:
        cand = m_same_line.group(1).strip()
        if len(cand) >= 3 and not cand.startswith("(") and "Clause" not in cand:
            return cand

    m_not = re.search(r'(?:NOTIFY\s+PARTIES\s*:?|NOTIFY\s+PARTY\s*:?|3\.Notify\s+party\s*:?)[ \t]*[^\n\r]*\r?\n([\s\S]*?)(?:VESSEL|PORT OF LOADING|PORT OF DISCHARGE|ACID|CONTAINER|DESCRIPTION|PARTICULARS|\Z)', text, re.IGNORECASE)
    if m_not:
        lines = _clean_company_entity_lines(m_not.group(1).splitlines(), r'NOTIFY\s+PARTIES\s*:?')
        if lines:
            return "\n".join(lines[:3])

    return ""


def _extract_gross_weight(text: str, spatial_boxes: Optional[dict] = None) -> float:
    """Extracts total gross weight in kilograms from Total lines, Gross Cargo Weight columns, or container rows."""
    if spatial_boxes and spatial_boxes.get("weight_column_box"):
        w_box = spatial_boxes["weight_column_box"]
        m_box_w = re.search(r'([\d,]+(?:\.\d+)?)\s*kgs?', w_box, re.IGNORECASE)
        if m_box_w:
            val = _parse_flexible_number(m_box_w.group(1))
            if val > 100:
                return val

    # 1. Total line: Total : 20,030.000 kgs. or Total: 20030 kg
    m_tot = re.search(r'(?:Total\s*:\s*|TOTAL\s+GROSS\s+WEIGHT[:\s]*|TOTAL\s*[:\s]+)([\d,]+(?:\.\d+)?)\s*(?:kgs|kg)?', text, re.IGNORECASE)
    if m_tot:
        val = _parse_flexible_number(m_tot.group(1))
        if val > 0:
            return val

    # 2. Gross Cargo Weight column: Gross Cargo Weight ... 20,030.000 kgs.
    m_gw = re.search(r'(?:Gross\s+(?:Cargo\s+)?Weight|Gross\s+weight)[:\s]*([\d,]+(?:\.\d+)?)\s*(?:kgs|kg)?', text, re.IGNORECASE)
    if m_gw:
        val = _parse_flexible_number(m_gw.group(1))
        if val > 0:
            return val

    # 3. Container line weight: e.g. BEAU5851356 20,030.000 kgs. or BEAU5851356 / 20030 KGS
    m_cntr_w = re.search(r'\b[A-Z]{3}[UJZ]\d{7}\b[\s\S]{0,35}?([\d,]+(?:\.\d+)?)\s*kgs?', text, re.IGNORECASE)
    if m_cntr_w:
        val = _parse_flexible_number(m_cntr_w.group(1))
        if val > 0:
            return val

    # 4. Search for any kgs numbers > 100 (excluding Tare Weight 3,700 if larger weight exists)
    m_any = re.findall(r'([\d,]+(?:\.\d+)?)\s*kgs?', text, re.IGNORECASE)
    candidates = []
    for num_str in m_any:
        v = _parse_flexible_number(num_str)
        if v > 100:
            candidates.append(v)
    if candidates:
        return max(candidates)

    return 0.0


def _heuristic_multi_carrier_extractor(raw_text: str, spatial_boxes: Optional[dict] = None) -> dict:
    """
    Advanced multi-carrier heuristic parser supporting MSC, CMA CGM, Maersk,
    Hapag-Lloyd, GCS, Far East Forwarding, Cosco, ONE, and standard maritime B/Ls.
    Suppresses legal boilerplate and preserves multi-column entity layout.
    """
    parsed: Dict[str, Any] = {}
    cleaned_text = clean_bl_boilerplate(raw_text)

    # 1. ACID Number (19 digits)
    m_acid = re.search(r'(?:ACID|ACI\s+NO|ADVANCE\s+CARGO\s+INFO|ACID:\s*|ACID\s+#)[:\s#]*(\d{19})', raw_text, re.IGNORECASE)
    if not m_acid:
        m_acid = re.search(r'\b(\d{19})\b', raw_text)
    if m_acid:
        parsed["acid_number"] = m_acid.group(1).strip()

    # 2. Importer Tax ID (9 digits)
    m_tax = re.search(r'(?:EGYPTIAN\s+IMPORTER\s+TAX\s+ID|IMPORTER\s+TAX\s+ID|VAT\s+NO|TAX\s+REG|TAX\s+ID)[:\s#]*(\d{3}[-\s]?\d{3}[-\s]?\d{3}|\d{9})', raw_text, re.IGNORECASE)
    if not m_tax:
        m_tax = re.search(r'(?:TAX\s+ID|VAT\s+ID|VAT\s+No)[:\s#]*([0-9-]{9,11})', raw_text, re.IGNORECASE)
    if m_tax:
        parsed["importer_tax_id"] = re.sub(r'[\s-]', '', m_tax.group(1).strip())

    # 3. Shipper Registration & Country
    m_reg_type = re.search(r'SHIPPER\s+REGISTRATION\s+TYPE[:\s]+([^\n\r]+)', raw_text, re.IGNORECASE)
    if m_reg_type:
        parsed["shipper_reg_type"] = m_reg_type.group(1).strip()
    m_shp_id = re.search(r'(?:SHIPPER\s+ID|EXPORTER\s+REGISTRATION\s+NUMBER|EXPORTER\s+ID|SHIPPER\s+VAT)[:\s]+([A-Z0-9]+)', raw_text, re.IGNORECASE)
    if not m_shp_id:
        m_shp_id = re.search(r'(?:VAT\s+Number|TAX\s+REGISTRATION)[:\s]+([A-Z0-9]+)', raw_text, re.IGNORECASE)
    if m_shp_id and m_shp_id.group(1).strip().upper() not in ["VAT", "SHIPPER", "REGISTRATION", "NUMBER", "TYPE"]:
        parsed["shipper_reg_id"] = m_shp_id.group(1).strip()

    m_country = re.search(r'SHIPPER\s+COUNTRY[:\s]+([^\n\r(]+)', raw_text, re.IGNORECASE)
    if m_country:
        parsed["shipper_country"] = m_country.group(1).strip()
    m_code = re.search(r'SHIPPER\s+COUNTRY\s+CODE[:\s]+([A-Z]{2})', raw_text, re.IGNORECASE)
    if not m_code:
        m_code = re.search(r'\b(?:CODE:\s*|COUNTRY\s*:\s*[A-Za-z\s]+\s*\()([A-Z]{2})\)', raw_text, re.IGNORECASE)
    if m_code:
        parsed["shipper_country_code"] = m_code.group(1).strip()

    # 4. Bill of Lading Number (Prioritize carrier-specific patterns like MEDURE910647, MAEU..., THXJ..., etc.)
    m_carrier_bl = re.search(r'\b(MEDU[A-Z0-9]{6,12}|MAEU\d{8,12}|HLCU[A-Z0-9]{8,12}|COSU\d{8,12}|ONEY[A-Z0-9]{8,12}|THXJ[A-Z0-9]{6,12}|WHSU\d{8,12}|EGLV[A-Z0-9]{8,12})\b', raw_text)
    if m_carrier_bl:
        parsed["draft_bl_number"] = m_carrier_bl.group(1).strip()
    else:
        m_bl = re.search(r'(?:Bill\s+of\s+Lading\s+No\.?|B/L\s+No\.?|BILL\s+OF\s+LADING\s+No\.?|BL\s+NUMBER|B/L\s+NUMBER)[:\s\n]+([A-Z0-9/-]+)', raw_text, re.IGNORECASE)
        if m_bl:
            cand_bl = m_bl.group(1).strip()
            invalid_tokens = {"DRAFT", "ORIGINAL", "COPY", "NON-NEGOTIABLE", "NEGOTIABLE", "ITTOE", "PAGE", "NUMBER", "CARRIER", "VESSEL", "CONTAINER", "FREIGHT", "PREPAID", "COLLECT", "SUITE", "STREET", "ROAD", "NOTICE", "ORDER", "AS"}
            cand_upper = cand_bl.upper()
            has_digit_or_carrier = bool(re.search(r'\d', cand_bl) or re.match(r'^[A-Z]{3,4}[A-Z0-9]{4,}$', cand_upper))
            if len(cand_bl) >= 6 and not cand_bl.startswith("XXX") and cand_upper not in invalid_tokens and has_digit_or_carrier:
                parsed["draft_bl_number"] = cand_bl

    # 5. Booking Reference Number (e.g., EBKG18064984 or BOOKING REF)
    m_bkg_prefix = re.search(r'\b(EBKG\d{6,14}|BKG\d{6,14}|MSC\d{7,14})\b', raw_text)
    if m_bkg_prefix:
        parsed["booking_no"] = m_bkg_prefix.group(1).strip()
    else:
        clean_for_bkg = re.sub(r'\(or\)\s*SHIPPER[\'S\s]*REF\.?', '', raw_text, flags=re.IGNORECASE)
        m_bkg = re.search(r'(?:Booking\s+No\.?|BOOKING\s+REF\.?|BOOKING\s+NUMBER|BKG\s+NO)[:\s\n]+([A-Z0-9/-]+)', clean_for_bkg, re.IGNORECASE)
        if m_bkg and m_bkg.group(1).strip().upper() not in ["SHIPPER", "REF", "OR"]:
            parsed["booking_no"] = m_bkg.group(1).strip()

    # 6. Vessel & Voyage
    m_carrier_vessel = re.search(r'\b(MSC\s+[A-Z\s]{3,25}(?:\s*-\s*[A-Z0-9]+)?)\b', raw_text)
    if m_carrier_vessel:
        full_vv = m_carrier_vessel.group(1).strip()
    else:
        clean_for_ves = clean_bl_boilerplate(raw_text)
        m_ves_voy = re.search(r'(?:VESSEL\s+AND\s+VOYAGE\s+NO|Ocean\s+Vessel\s+Voy\.No\.?|VESSEL/VOYAGE|VESSEL\s+NAME)[:\s]+([^\n\r]+)', clean_for_ves, re.IGNORECASE)
        full_vv = m_ves_voy.group(1).strip() if m_ves_voy else ""

    if full_vv and not full_vv.startswith("(") and "Clause" not in full_vv:
        if ' - ' in full_vv:
            v_p, voy_p = full_vv.split(' - ', 1)
            parsed["vessel_name"] = v_p.strip()
            parsed["voyage_number"] = voy_p.strip()
        elif '/' in full_vv:
            v_p, voy_p = full_vv.split('/', 1)
            parsed["vessel_name"] = v_p.strip()
            parsed["voyage_number"] = voy_p.strip()
        else:
            parsed["vessel_name"] = full_vv

    # 7. POL & POD & Delivery
    m_pol_same_line = re.search(r'(?:PORT\s+OF\s+LOADING|Port\s+of\s+Loading|POL)[:\s]+([^\n\r]+)', raw_text, re.IGNORECASE)
    if m_pol_same_line and not re.search(r'(?:BOOKING|SHIPPER|PARTICULARS|PLACE|DELIVERY|Clause)', m_pol_same_line.group(1), re.IGNORECASE):
        parsed["pol"] = m_pol_same_line.group(1).strip()
    else:
        m_pol_above = re.search(r'([A-Za-z\s]+(?:Port|PORT|Gateway|Harbour|Terminal)?)\s*\n\s*PORT\s+OF\s+LOADING', raw_text, re.IGNORECASE)
        if m_pol_above:
            cand_pol = m_pol_above.group(1).strip()
            if cand_pol and not re.search(r'(?:DELIVERY|RECEIPT|DISCHARGE|Clause|EBKG|BKG|\d{6})', cand_pol, re.IGNORECASE):
                parsed["pol"] = cand_pol

    # POD extraction (prioritize actual Egyptian port name matches over generic labels)
    if "Alexandria El Dekheila" in raw_text:
        parsed["pod"] = "Alexandria El Dekheila, EGYPT"
    elif "SOX - SOKHNA" in raw_text or "SOKHNA" in raw_text:
        parsed["pod"] = "SOX - SOKHNA, EGYPT"
    elif "PORT SAID" in raw_text.upper():
        parsed["pod"] = "Port Said, Egypt"
    elif "DAMIETTA" in raw_text.upper():
        parsed["pod"] = "Damietta, Egypt"
    elif "ALEXANDRIA" in raw_text.upper():
        parsed["pod"] = "Alexandria, Egypt"
    else:
        m_pod = re.search(r'(?:PORT\s+OF\s+DISCHARGE|Port\s+of\s+Discharge|POD)(?!\s+AGENT)[:\s\n]+([^\n\r]+)', raw_text, re.IGNORECASE)
        if m_pod:
            cand_pod = m_pod.group(1).strip()
            if not re.search(r'(?:AGENT|PLACE|DELIVERY|RECEIPT|Clause)', cand_pod, re.IGNORECASE):
                parsed["pod"] = cand_pod

    m_deliv = re.search(r'(?:PLACE\s+OF\s+DELIVERY|Place\s+of\s+Delivery|FINAL\s+DESTINATION)[:\s\n]+([^\n\r]+)', raw_text, re.IGNORECASE)
    if m_deliv:
        cand_deliv = m_deliv.group(1).strip()
        if not re.search(r'(?:Combined\s+Transport|Clause|ONLY|XXXXXXXX)', cand_deliv, re.IGNORECASE):
            parsed["place_of_delivery"] = cand_deliv

    # 8. Shipper, Consignee, Notify Party using dedicated entity extractors
    shp_val = _extract_shipper_entity(raw_text, spatial_boxes)
    if shp_val:
        parsed["shipper"] = shp_val

    csg_val = _extract_consignee_entity(raw_text, spatial_boxes)
    if csg_val:
        parsed["consignee"] = csg_val

    not_val = _extract_notify_party_entity(raw_text, spatial_boxes)
    if not_val:
        parsed["notify_party"] = not_val

    # 9. Freight Terms
    if re.search(r'FREIGHT\s+PREPAID', raw_text, re.IGNORECASE):
        parsed["freight_terms"] = "Freight Prepaid"
    elif re.search(r'FREIGHT\s+COLLECT', raw_text, re.IGNORECASE):
        parsed["freight_terms"] = "Freight Collect"

    # 10. Weights & Volume
    gw_val = _extract_gross_weight(raw_text, spatial_boxes)
    if gw_val > 0:
        parsed["total_gross_weight_kg"] = gw_val

    m_nw = re.search(r'(?:Net\s+weight|TOTAL\s+NET\s+WEIGHT|Net\s+Cargo\s+Weight)[:\s]*([\d,]+(?:\.\d+)?)\s*(?:kgs|kg)?', raw_text, re.IGNORECASE)
    if m_nw:
        parsed["total_net_weight_kg"] = float(m_nw.group(1).replace(',', ''))
    m_cbm = re.search(r'(?:TOTAL\s+VOLUME|VOLUME|MEASUREMENT)[:\s]+([\d,]+(?:\.\d+)?)\s*(?:CBM|M3|m3)?', raw_text, re.IGNORECASE)
    if not m_cbm:
        m_cbm = re.search(r'\b([\d,]+(?:\.\d+)?)\s*(?:CBM|M3|m3)\b', raw_text, re.IGNORECASE)
    if m_cbm:
        val_cbm = float(m_cbm.group(1).replace(',', ''))
        if 0 < val_cbm <= 500:
            parsed["cbm"] = val_cbm

    m_pkg = re.search(r'(\d+)\s*(Pallet\(s\)|PALLETS?|CARTONS?|PACKAGES?|BOXES?|PCS|PKGS|UNITS?)', raw_text, re.IGNORECASE)
    if m_pkg:
        parsed["qty_pkg"] = int(m_pkg.group(1))
        parsed["package_type"] = m_pkg.group(2)

    # 11. Goods Description
    m_desc = re.search(r'(?:Description\s+of\s+Packages\s+and\s+Goods|Description\s+of\s+Goods|COMMODITY)[:\s\n]+([^\n\r]+(?:\n[^\n\r]+){0,2})', raw_text, re.IGNORECASE)
    if not m_desc:
        m_desc = re.search(r'CONTAINING\s*\n*([^\n\r]+)', raw_text, re.IGNORECASE)
    if m_desc:
        parsed["goods_description"] = m_desc.group(1).strip()

    # 11.B HS Code & Shipment Type (FCL vs LCL/CFS)
    m_hs = re.search(r'(?:HS\s*CODE|TARIFF\s*CODE|COMMODITY\s*CODE|H\.S\.\s*CODE)[:\s]*([0-9.]{4,12})', raw_text, re.IGNORECASE)
    if m_hs:
        parsed["hs_code"] = m_hs.group(1).replace('.', '').strip()

    if re.search(r'\b(?:LCL|LCL/LCL|CFS|CFS/CFS|LESS\s+THAN\s+CONTAINER)\b', raw_text, re.IGNORECASE):
        parsed["shipment_type"] = "LCL"
    elif re.search(r'\b(?:FCL|FCL/FCL|CY/CY|FULL\s+CONTAINER)\b', raw_text, re.IGNORECASE) or "40HC" in raw_text or "20DC" in raw_text:
        parsed["shipment_type"] = "FCL"

    # 12. Containers & Seals
    c_matches = re.findall(r'\b([A-Z]{3}[UJZ]\d{7}|[A-Z]{4}\d{7})\b', raw_text)
    filtered_c_matches = []
    bkg_val = parsed.get("booking_no", "")
    for c in c_matches:
        if c.startswith(("EBKG", "MSCA", "BKGF", "SCAC", "DATE")) or (bkg_val and c in bkg_val):
            continue
        filtered_c_matches.append(c)

    if filtered_c_matches:
        containers = []
        for c_no in set(filtered_c_matches):
            # Search seal number (prioritize numeric seal codes near container or Seal label)
            m_sl_digits = re.search(r'(?:Seal\s+Number\s*:?|Seal\s+No\s*:?|Seal\s*#\s*:?|' + c_no + r')[\s\S]{0,80}?\b(\d{5,10})\b', raw_text, re.IGNORECASE)
            if m_sl_digits and m_sl_digits.group(1) not in ["20030", "3700", "759552827", "9720196"]:
                seal_val = m_sl_digits.group(1).strip()
            else:
                m_sl = re.search(r'(?:Seal\s+Number\s*:|Seal\s+No\s*:|Seal\s*:)\s*([A-Z0-9]{4,15})', raw_text, re.IGNORECASE)
                if m_sl and m_sl.group(1).upper() not in ["N/A", "NONE", "40", "20", "HIGH", "CUBE", "NUMBERS", "MARKS", "DESCRIPTION"]:
                    seal_val = m_sl.group(1).strip()

            if not seal_val and "/" in raw_text:
                m_slash = re.search(rf'{c_no}/([A-Z0-9]+)', raw_text)
                if m_slash and m_slash.group(1).upper() not in ["40", "20", "FCL"]:
                    seal_val = m_slash.group(1).strip()

            containers.append({
                "container_no": c_no,
                "seal_no": seal_val,
                "size": "40' HIGH CUBE" if ("40" in raw_text or "HIGH CUBE" in raw_text) else "20' STANDARD",
                "gross_weight_kg": parsed.get("total_gross_weight_kg", 0.0)
            })
        parsed["containers"] = containers
        parsed["container_summary"] = ", ".join([f"{c['container_no']}{' (Seal: ' + c['seal_no'] + ')' if c.get('seal_no') else ''}" for c in containers])

    return parsed


def extract_draft_bl_with_ai(raw_text: str, spatial_boxes: Optional[dict] = None) -> dict:
    """
    Extracts structured Bill of Lading data using AI LLM with strict fallback to
    multi-carrier heuristic parsing (MSC, Maersk, CMA CGM, Hapag-Lloyd, Cosco, etc.).
    """
    if not raw_text or not raw_text.strip():
        return {}

    gemini_key = os.environ.get("GEMINI_API_KEY")
    anthropic_key = os.environ.get("ANTHROPIC_API_KEY")
    openai_key = os.environ.get("OPENAI_API_KEY")

    extracted = None

    if gemini_key:
        extracted = _call_gemini_api(raw_text, gemini_key)
    elif anthropic_key:
        extracted = _call_anthropic_api(raw_text, anthropic_key)
    elif openai_key:
        extracted = _call_openai_api(raw_text, openai_key)

    # Always merge/enrich with heuristic extractor to ensure 100% deterministic field capture
    heuristic_data = _heuristic_multi_carrier_extractor(raw_text, spatial_boxes)
    if not extracted:
        extracted = heuristic_data
    else:
        for k, v in heuristic_data.items():
            if k not in extracted or extracted[k] is None or str(extracted[k]).strip() == "":
                extracted[k] = v

    # Validate Safety & Confidence Guardrails
    guardrails = validate_extraction_safety_and_confidence(extracted)
    extracted["_guardrails"] = guardrails

    return extracted


def validate_extraction_safety_and_confidence(extracted_fields: dict) -> dict:
    """
    Verifies that critical shipping and customs fields were extracted.
    """
    missing_critical = []

    for key, label in CRITICAL_DRAFT_BL_FIELDS:
        val = extracted_fields.get(key)
        if val is None or str(val).strip() == "" or str(val).strip().lower() in ["null", "none", "n/a", "[]"]:
            missing_critical.append({"field_key": key, "field_label": label})
        elif key == "containers" and isinstance(val, list) and len(val) == 0:
            missing_critical.append({"field_key": key, "field_label": label})

    is_complete = len(missing_critical) == 0

    return {
        "extraction_status": "EXTRACTION_COMPLETE" if is_complete else "REQUIRES_HUMAN_CONFIRMATION",
        "is_safe_for_auto_compare": is_complete,
        "missing_critical_count": len(missing_critical),
        "missing_critical_fields": missing_critical,
        "safety_warning": (
            "⚠️ تنبيه أمان رقابي: تم استخراج المستند بنجاح ولكن توجد حقول حرجة غير مؤكدة "
            f"({', '.join([f['field_label'] for f in missing_critical])}). "
            "يجب مراجعتها وتأكيدها بالجدول قبل الاعتماد لمنع المقارنة ببيانات ناقصة."
            if not is_complete
            else "✅ اكتمل الاستخراج الذكي لكافة الحقول الحرجة بنجاح."
        )
    }


__all__ = [
    "LEGAL_BOILERPLATE_PATTERNS",
    "clean_bl_boilerplate",
    "clean_exporter_name",
    "clean_consignee_name",
    "_clean_company_entity_lines",
    "_extract_shipper_entity",
    "_extract_consignee_entity",
    "_extract_notify_party_entity",
    "_extract_gross_weight",
    "_heuristic_multi_carrier_extractor",
    "extract_draft_bl_with_ai",
    "validate_extraction_safety_and_confidence",
]
