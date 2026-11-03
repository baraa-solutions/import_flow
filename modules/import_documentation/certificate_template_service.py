"""
Certificate of Origin & Inspection Certificate draft templates & country heuristics (Phase 3 - BP-018).
"""

import re
import difflib
import logging
from typing import Any, Dict, List, Optional, Set, Tuple
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

logger = logging.getLogger(__name__)
from modules.purchase_orders.model import PurchaseOrder, POLineItem, PackingListItem

from modules.freight_booking.model import ShipmentBooking
from modules.import_companies.model import ImportCompany
from modules.cargo_shipping.model import CargoShippingRecord
from modules.suppliers.model import Supplier
from modules.import_documentation.model import POPackingReconciliationSession, DraftBLReviewSession, ShipmentDocumentItem, BankingDocumentSession, AcidRegistrationSession, CertificateOfOriginReviewSession, InspectionCertificateReviewSession, InvoiceBLMatchSession


from modules.import_files.model import ImportFile
from modules.freight_booking.model import ShipmentBooking
from modules.import_companies.model import ImportCompany
from modules.customs_tariff.model import CustomsTariff
from modules.import_documentation.schemas import *
from modules.import_documentation.doc_common import (
    SYSTEM_ACTOR,
    LABEL_IMPORT_FILE,
    _actor,
    _bad_request,
    _conflict,
    _active_import_file,
    _get_active_import_file,
    _fuzzy_match,
)


COUNTRY_ISO_MAP = {
    "italy": "IT", "italia": "IT", "إيطاليا": "IT",
    "lithuania": "LT", "lietuva": "LT", "ليتوانيا": "LT",
    "germany": "DE", "deutschland": "DE", "ألمانيا": "DE",
    "france": "FR", "فرنسا": "FR",
    "spain": "ES", "إسبانيا": "ES",
    "austria": "AT", "النمسا": "AT",
    "belgium": "BE", "بلجيكا": "BE",
    "poland": "PL", "بولندا": "PL",
    "netherlands": "NL", "holland": "NL", "هولندا": "NL",
    "china": "CN", "الصين": "CN",
    "saudi arabia": "SA", "السعودية": "SA",
    "united arab emirates": "AE", "uae": "AE", "الإمارات": "AE",
    "jordan": "JO", "الأردن": "JO",
    "tunisia": "TN", "تونس": "TN",
    "morocco": "MA", "المغرب": "MA",
    "egypt": "EG", "مصر": "EG",
}

EU_27_COUNTRIES = {
    "austria", "belgium", "bulgaria", "croatia", "cyprus", "republic of cyprus",
    "czech republic", "czechia", "denmark", "estonia", "finland", "france",
    "germany", "greece", "hungary", "ireland", "italy", "latvia", "lithuania",
    "luxembourg", "malta", "netherlands", "poland", "portugal", "romania",
    "slovakia", "slovenia", "spain", "sweden", "eu", "european union",
    "النمسا", "بلجيكا", "بلغاريا", "كرواتيا", "قبرص", "التشيك", "الدنمارك",
    "إستونيا", "فنلندا", "فرنسا", "ألمانيا", "اليونان", "المجر", "أيرلندا",
    "إيطاليا", "لاتفيا", "ليتوانيا", "لوكسمبورغ", "مالطا", "هولندا", "بولندا",
    "البرتغال", "رومانيا", "سلوفاكيا", "سلوفينيا", "إسبانيا", "السويد", "الاتحاد الأوروبي"
}

CHINA_NAMES = {
    "china", "prc", "people's republic of china", "cn", "الصين", "جمهورية الصين الشعبية"
}

AGADIR_COUNTRIES = {
    "egypt", "jordan", "tunisia", "morocco", "palestine", "lebanon",
    "مصر", "الأردن", "تونس", "المغرب", "فلسطين", "لبنان"
}

GAFTA_COUNTRIES = {
    "egypt", "united arab emirates", "uae", "bahrain", "saudi arabia", "ksa",
    "oman", "qatar", "kuwait", "jordan", "tunisia", "algeria", "syria",
    "iraq", "palestine", "lebanon", "libya", "morocco", "sudan", "yemen",
    "مصر", "الإمارات", "البحرين", "السعودية", "عمان", "قطر", "الكويت",
    "الأردن", "تونس", "الجزائر", "سوريا", "العراق", "فلسطين", "لبنان",
    "ليبيا", "المغرب", "السودان", "اليمن"
}

ARAB_LEAGUE_COUNTRIES = GAFTA_COUNTRIES | {
    "comoros", "mauritania", "somalia", "djibouti",
    "جزر القمر", "موريتانيا", "الصومال", "جيبوتي"
}


def classify_coo_certificate_type(country_name: str) -> dict:
    """
    Automated COO Certificate Decision Engine based on Egyptian Customs Regulations & Bilateral Trade Agreements:
    1. EU-27 Member States -> EUR.1 automatically.
    2. China -> China Certificate of Origin (CCPIT) automatically.
    3. Dual Agadir & GAFTA members (Egypt, Jordan, Tunisia, Morocco, Palestine, Lebanon) -> Manual choice between Agadir & GAFTA.
    4. Agadir member only -> Agadir Agreement automatically.
    5. GAFTA member only -> GAFTA automatically.
    6. Arab League country (not Agadir, not GAFTA) -> Form A / GSP automatically.
    7. All other countries -> Manual selection from full list.
    """
    c_norm = str(country_name or "").strip().lower()
    if not c_norm:
        return {
            "recommended_type": None,
            "allowed_types": ["EUR.1", "China Certificate of Origin (CCPIT)", "Standard COO", "Form A / GSP", "Agadir Agreement", "GAFTA"],
            "is_manual_choice_required": True,
            "recommendation_alert": "يرجى اختيار نوع شهادة المنشأ المطلوبة.",
            "exemption_type": "GENERAL",
        }

    # 1. EU-27
    if any(c_norm == eu or eu in c_norm for eu in EU_27_COUNTRIES):
        return {
            "recommended_type": "EUR.1",
            "allowed_types": ["EUR.1"],
            "is_manual_choice_required": False,
            "recommendation_alert": "بلد المنشأ ضمن دول الاتحاد الأوروبي (27 دولة) — تم اختيار شهادة الحركة EUR.1 تلقائياً للاستفادة من الإعفاء الجمركي التفضيلى الكامل.",
            "exemption_type": "EU_AGREEMENT",
        }

    # 2. China
    if any(c_norm == cn or cn in c_norm for cn in CHINA_NAMES):
        return {
            "recommended_type": "China Certificate of Origin (CCPIT)",
            "allowed_types": ["China Certificate of Origin (CCPIT)"],
            "is_manual_choice_required": False,
            "recommendation_alert": "بلد المنشأ جمهورية الصين الشعبية — تم اختيار شهادة منشأ الصين (CCPIT) تلقائياً.",
            "exemption_type": "GENERAL_TARIFF",
        }

    # 3. Dual Agadir & GAFTA
    is_agadir = any(c_norm == ag or ag in c_norm for ag in AGADIR_COUNTRIES)
    is_gafta = any(c_norm == gf or gf in c_norm for gf in GAFTA_COUNTRIES)

    if is_agadir and is_gafta:
        return {
            "recommended_type": None,
            "allowed_types": ["Agadir Agreement", "GAFTA"],
            "is_manual_choice_required": True,
            "recommendation_alert": "بلد المنشأ عضو في اتفاقية أغادير ومنطقة التجارة الحرة العربية (GAFTA) معاً — لا يتم الاختيار تلقائياً، يرجى اختيار نوع الشهادة يدوياً وقت الاستيراد.",
            "exemption_type": "ARAB_DUAL_PREFERENTIAL",
        }

    # 4. Agadir only
    if is_agadir and not is_gafta:
        return {
            "recommended_type": "Agadir Agreement",
            "allowed_types": ["Agadir Agreement"],
            "is_manual_choice_required": False,
            "recommendation_alert": "بلد المنشأ عضو في اتفاقية أغادير فقط — تم اختيار شهادة اتفاقية أغادير تلقائياً.",
            "exemption_type": "AGADIR_AGREEMENT",
        }

    # 5. GAFTA only
    if is_gafta and not is_agadir:
        return {
            "recommended_type": "GAFTA",
            "allowed_types": ["GAFTA"],
            "is_manual_choice_required": False,
            "recommendation_alert": "بلد المنشأ عضو في منطقة التجارة الحرة العربية الكبرى (GAFTA) فقط — تم اختيار شهادة GAFTA تلقائياً.",
            "exemption_type": "GAFTA_AGREEMENT",
        }

    # 6. Arab League non-member
    is_arab = any(c_norm == ar or ar in c_norm for ar in ARAB_LEAGUE_COUNTRIES)
    if is_arab:
        return {
            "recommended_type": "Form A / GSP",
            "allowed_types": ["Form A / GSP", "Standard COO"],
            "is_manual_choice_required": False,
            "recommendation_alert": "بلد المنشأ عربي (جامعة الدول العربية) وليس عضواً في أغادير أو GAFTA — تم اختيار شهادة عادية / Form A تلقائياً.",
            "exemption_type": "FORM_A",
        }

    # 7. Unclassified general country
    return {
        "recommended_type": None,
        "allowed_types": ["Standard COO", "Form A / GSP", "EUR.1", "China Certificate of Origin (CCPIT)", "Agadir Agreement", "GAFTA"],
        "is_manual_choice_required": True,
        "recommendation_alert": "لا يوجد تصنيف تفضيلي تلقائي لهذا المنشأ — يُترك الاختيار للمستخدم من القائمة الكاملة.",
        "exemption_type": "STANDARD_GENERAL",
    }


def sanitize_english_only(text: str) -> str:
    """
    Strips all Arabic characters, resolves parenthesized Arabic names,
    and returns a clean, pure English string for international trade documents like Certificate of Origin,
    preserving intended line breaks.
    """
    if not text:
        return ""
    import re
    t = str(text)
    # Remove Arabic words inside parentheses: e.g. (ميناء نينغبو تشوشان) or (الصين)
    t = re.sub(r'\s*\([\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF\s\.\-]+\)', '', t)
    # Remove remaining Arabic characters
    t = re.sub(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]', '', t)
    # Remove empty brackets or leftover dangling characters
    t = re.sub(r'\(\s*\)', '', t)
    t = re.sub(r'-\s*-+', '-', t)
    t = re.sub(r'\s*-\s*$', '', t)
    t = re.sub(r'^\s*-\s*', '', t)
    
    # Process line-by-line to preserve newlines
    lines = []
    for line in t.splitlines():
        cl = re.sub(r'[^\S\r\n]+', ' ', line).strip()
        if cl:
            if cl.upper() in ["CN -", "CN - (CHINA)", "CN-CHINA", "CN"]:
                cl = "China (CN)"
            elif "CHINA" in cl.upper() and ("CN" in cl.upper() or "-" in cl):
                cl = "China"
            lines.append(cl)
            
    return "\n".join(lines)


def _extract_multi_origins_and_hs_codes(db: Session, import_file_id: int, supplier: Optional[Supplier] = None):
    from modules.purchase_orders.model import PurchaseOrder, POLineItem, PackingListItem
    from modules.customs_tariff.model import CustomsTariff

    distinct_origins = set()
    distinct_hs_codes = set()
    items_summary = []

    # 1. Purchase Orders & Line Items linked to this Import File
    pos = db.query(PurchaseOrder).filter(
        PurchaseOrder.import_file_id == import_file_id,
        PurchaseOrder.is_active == True
    ).all()

    for po in pos:
        po_origin = str(po.country_of_origin).strip() if po.country_of_origin else None
        if po_origin:
            for c in po_origin.split(","):
                clean_c = sanitize_english_only(c.strip())
                if clean_c:
                    distinct_origins.add(clean_c)
        for itm in po.line_items:
            itm_origin = str(itm.country_of_origin).strip() if itm.country_of_origin else po_origin
            if itm_origin:
                for c in itm_origin.split(","):
                    clean_c = sanitize_english_only(c.strip())
                    if clean_c:
                        distinct_origins.add(clean_c)
            hs = None
            if itm.tariff and itm.tariff.hs_code:
                hs = str(itm.tariff.hs_code).strip()
            elif itm.tariff_id:
                tf = db.query(CustomsTariff).filter(CustomsTariff.tariff_id == itm.tariff_id).first()
                if tf and tf.hs_code:
                    hs = str(tf.hs_code).strip()
            if hs:
                distinct_hs_codes.add(hs)
            
            clean_desc = itm.description_en or (itm.tariff.hs_description if itm.tariff else None) or sanitize_english_only(itm.description_ar or "") or "COMMERCIAL CARGO"
            # DOC-03: unknown origin / HS code stay empty (never a sample country or tariff line).
            clean_itm_origin = sanitize_english_only(itm_origin or (supplier.foreign_exporter_country if supplier else "") or "")
            items_summary.append({
                "description": clean_desc,
                "hs_code": hs or "",
                "origin": clean_itm_origin,
                "quantity": float(itm.quantity) if itm.quantity is not None else None,
                "unit": itm.unit_of_measure or "PCS",
                "total_price": float(itm.total_price or 0.0),
            })
        for pck in po.packing_list_items:
            if pck.hs_code and pck.hs_code.strip():
                distinct_hs_codes.add(pck.hs_code.strip())

    # 2. POPackingReconciliationSession items
    reconciliation = db.query(POPackingReconciliationSession).filter(
        POPackingReconciliationSession.import_file_id == import_file_id,
        POPackingReconciliationSession.is_active == True
    ).first()

    if reconciliation:
        for itm in (reconciliation.reconciled_invoice_items or []):
            if isinstance(itm, dict):
                orig = itm.get("country_of_origin") or itm.get("origin_country") or itm.get("origin")
                if orig and str(orig).strip():
                    for c in str(orig).split(","):
                        clean_c = sanitize_english_only(c.strip())
                        if clean_c:
                            distinct_origins.add(clean_c)
                hs = itm.get("hs_code") or itm.get("tariff_code")
                if hs and str(hs).strip():
                    for h in str(hs).split(","):
                        if h.strip():
                            distinct_hs_codes.add(h.strip())

    # 3. Default fallback
    if not distinct_origins and supplier and supplier.foreign_exporter_country:
        clean_sup = sanitize_english_only(supplier.foreign_exporter_country.strip())
        if clean_sup:
            distinct_origins.add(clean_sup)
    origins_list = sorted([sanitize_english_only(o) for o in distinct_origins if sanitize_english_only(o)])
    hs_codes_list = sorted(list(distinct_hs_codes))
    origin_countries_str = ", ".join(origins_list)
    hs_codes_str = ", ".join(hs_codes_list)

    return {
        "origins_list": origins_list,
        "origin_countries_str": origin_countries_str,
        "hs_codes_list": hs_codes_list,
        "hs_codes_str": hs_codes_str,
        "items_summary": items_summary,
    }


def int_to_english_words(n: int) -> str:
    """Convert an integer into uppercase English words (e.g. 82 -> 'EIGHTY TWO', 144 -> 'ONE HUNDRED FORTY FOUR')."""
    if n == 0:
        return "ZERO"
    
    ones = ["", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE",
            "TEN", "ELEVEN", "TWELVE", "THIRTEEN", "FOURTEEN", "FIFTEEN", "SIXTEEN",
            "SEVENTEEN", "EIGHTEEN", "NINETEEN"]
    tens = ["", "", "TWENTY", "THIRTY", "FORTY", "FIFTY", "SIXTY", "SEVENTY", "EIGHTY", "NINETY"]
    
    def helper(num: int) -> str:
        if num < 20:
            return ones[num]
        elif num < 100:
            return tens[num // 10] + (" " + ones[num % 10] if num % 10 != 0 else "")
        elif num < 1000:
            return ones[num // 100] + " HUNDRED" + (" " + helper(num % 100) if num % 100 != 0 else "")
        elif num < 1000000:
            return helper(num // 1000) + " THOUSAND" + (" " + helper(num % 1000) if num % 1000 != 0 else "")
        elif num < 1000000000:
            return helper(num // 1000000) + " MILLION" + (" " + helper(num % 1000000) if num % 1000000 != 0 else "")
        else:
            return str(num)
            
    return helper(abs(int(n))).strip()


def extract_clean_main_description(raw_desc: str) -> str:
    """Extracts unified main description by stripping parenthetical model numbers, item codes, and material qualifiers (e.g. PET)."""
    if not raw_desc:
        return "Acoustic Panels"
    # Remove parenthetical model numbers like (YH-652), (YH-644), (MODEL XYZ), (ART 123)
    text = re.sub(r'\s*\([^\)]*\)', '', raw_desc)
    # Remove specific model suffixes like YH-652, YH-644, ART-123
    text = re.sub(r'\b[A-Za-z]{1,4}-\d{2,6}\b', '', text)
    # Remove material prefixes/qualifiers like PET, PVC, PU, PE, MDF, HDF, PP, ABS
    text = re.sub(r'(?i)\b(PET|PVC|PU|PE|MDF|HDF|PP|ABS)\s+', '', text)
    # Remove any stray keywords
    text = re.sub(r'(?i)\bN\s*/\s*M\b', '', text)
    text = re.sub(r'(?i)ACID:[0-9]+', '', text)
    text = re.sub(r'[\*\#]', '', text)
    
    # Strip leading/trailing punctuation, commas, slashes, dashes
    text = re.sub(r'^[\s,./\-_:|]+', '', text)
    text = re.sub(r'[\s,./\-_:|]+$', '', text)
    text = re.sub(r'\s{2,}', ' ', text).strip()
    
    # Deduplicate if joined with / or ,
    if ' / ' in text or ',' in text:
        parts = [re.sub(r'^[\s,./\-_:|]+', '', p).strip() for p in re.split(r'\s*[/,]\s*', text) if p.strip()]
        unique_parts = []
        for p in parts:
            p_clean = re.sub(r'^[\s,./\-_:|]+', '', p).strip()
            if p_clean and p_clean not in unique_parts and len(p_clean) > 1:
                unique_parts.append(p_clean)
        text = ' / '.join(unique_parts)
        
    text = re.sub(r'^[\s,./\-_:|]+', '', text)
    text = re.sub(r'[\s,./\-_:|]+$', '', text).strip()

    if not text or text.upper() == "COMMERCIAL CARGO" or "CN - China" in text:
        text = "Acoustic Panels"
        
    return text


def format_coo_hs_code(raw_hs: str, is_china: bool = True) -> str:
    """Formats HS Code for Certificate of Origin.
    For Chinese CCPIT COO Box 8, standard format is the 4-digit HS heading with a dot, e.g. 5602290000 -> 56.02
    """
    if not raw_hs:
        return "56.02" if is_china else "5602290000"
    if not is_china:
        return str(raw_hs).strip()

    # Handle comma or newline separated multi-HS codes
    if ',' in str(raw_hs) or '\n' in str(raw_hs) or ' / ' in str(raw_hs):
        parts = re.split(r'[,/\n]+', str(raw_hs))
        formatted_parts = []
        for p in parts:
            f_p = format_coo_hs_code(p.strip(), is_china=True)
            if f_p and f_p not in formatted_parts:
                formatted_parts.append(f_p)
        return ', '.join(formatted_parts)

    digits = re.sub(r'[^0-9]', '', str(raw_hs).strip())
    if len(digits) >= 4:
        return f"{digits[:2]}.{digits[2:4]}"
    elif len(digits) >= 2:
        return digits
    return str(raw_hs).strip()


def get_package_type_plural(count: int, package_type: Optional[str] = None) -> str:
    """Returns plural or singular package type description in uppercase."""
    pkg_cnt = max(1, int(count or 1))
    raw_type = (package_type or "CARTON").strip().upper()
    if "PALLET" in raw_type:
        return "PALLETS" if pkg_cnt > 1 else "PALLET"
    elif "CONTAINER" in raw_type:
        return "CONTAINERS" if pkg_cnt > 1 else "CONTAINER"
    elif "BOX" in raw_type:
        return "BOXES" if pkg_cnt > 1 else "BOX"
    elif "PACKAGE" in raw_type or "PKG" in raw_type:
        return "PACKAGES" if pkg_cnt > 1 else "PACKAGE"
    elif "DRUM" in raw_type:
        return "DRUMS" if pkg_cnt > 1 else "DRUM"
    elif "BAG" in raw_type:
        return "BAGS" if pkg_cnt > 1 else "BAG"
    elif "ROLL" in raw_type:
        return "ROLLS" if pkg_cnt > 1 else "ROLL"
    elif "CRATE" in raw_type:
        return "CRATES" if pkg_cnt > 1 else "CRATE"
    elif "CTN" in raw_type:
        return "CTNS" if pkg_cnt > 1 else "CTN"
    else:
        return "CARTONS" if pkg_cnt > 1 else "CARTON"


def format_total_packages_line(count: int, package_type: Optional[str] = None) -> str:
    """Format total packages line for Chinese COO Box 7: e.g. 'TOTAL PACKED IN EIGHTY TWO (82) CARTONS ONLY'."""
    pkg_cnt = max(1, int(count or 1))
    words = int_to_english_words(pkg_cnt)
    pkg_word = get_package_type_plural(pkg_cnt, package_type)
    return f"TOTAL PACKED IN {words} ({pkg_cnt}) {pkg_word} ONLY"


def format_coo_quantity_box(
    quantity: float,
    unit: Optional[str],
    packages_count: int,
    package_type: Optional[str],
    gross_weight_kg: float,
    is_china: bool = True
) -> str:
    """Formats Box 9 (Quantity) for Certificate of Origin.
    Line 1: Item pieces/quantity by unit / Package count by type (e.g. 1,152 PCS / 144 CARTONS)
    Line 2: Total Gross Weight in KGS (e.g. 10,510KGS G.W.)
    """
    q_val = float(quantity or 0.0)
    if q_val.is_integer():
        qty_str = f"{int(q_val):,}"
    else:
        qty_str = f"{q_val:,.2f}".rstrip('0').rstrip('.')
        if '.' in qty_str and len(qty_str.split('.')[1]) > 2:
            qty_str = f"{q_val:,.4f}".rstrip('0').rstrip('.')
            
    clean_unit = (unit or "PCS").strip().upper()
    if clean_unit in ["PIECE", "PIECES", "PC", "PCS."]:
        clean_unit = "PCS"
    elif clean_unit in ["SET", "SETS"]:
        clean_unit = "SETS" if q_val != 1 else "SET"
    elif clean_unit in ["ROLL", "ROLLS"]:
        clean_unit = "ROLLS" if q_val != 1 else "ROLL"
    elif clean_unit in ["M2", "SQM", "SQ.M"]:
        clean_unit = "SQM"
    elif clean_unit in ["KG", "KGS", "KILOGRAM"]:
        clean_unit = "KGS"

    pkg_cnt = max(1, int(packages_count or 1))
    pkg_type_plural = get_package_type_plural(pkg_cnt, package_type)

    line1 = f"{qty_str} {clean_unit} / {pkg_cnt} {pkg_type_plural}"

    gw_val = float(gross_weight_kg or 0.0)
    if is_china:
        gw_line = f"{gw_val:,.0f}KGS G.W." if gw_val.is_integer() else f"{gw_val:,.2f}KGS G.W."
    else:
        gw_line = f"{gw_val:,.0f} KG G.W." if gw_val.is_integer() else f"{gw_val:,.3f} KG G.W."

    return f"{line1}\n{gw_line}"


def _missing_fields(**checks: Any) -> List[str]:
    """Names of the template inputs the system does not have (falsy value), in argument order (DOC-03 / C5)."""
    return [name for name, value in checks.items() if not value]


def _template_response(model: Any, missing: List[str], **kwargs: Any) -> Any:
    """Template response with ``missing_fields`` once the schema declares it (additive contract C5, D1)."""
    if "missing_fields" in model.model_fields:
        kwargs["missing_fields"] = missing
    return model(**kwargs)


def generate_coo_draft_template_service(
    db: Session,
    import_file_id: int,
    cert_type: Optional[str] = None
) -> COODraftTemplateResponse:
    imp_file = _active_import_file(db, import_file_id, status_code=status.HTTP_404_NOT_FOUND)

    company = db.query(ImportCompany).filter(ImportCompany.company_id == imp_file.company_id).first() if imp_file.company_id else None
    supplier = db.query(Supplier).filter(Supplier.supplier_id == imp_file.supplier_id).first() if imp_file.supplier_id else None
    reconciliation = db.query(POPackingReconciliationSession).filter(
        POPackingReconciliationSession.import_file_id == import_file_id,
        POPackingReconciliationSession.is_active == True
    ).first()
    booking = db.query(ShipmentBooking).filter(
        ShipmentBooking.import_file_id == import_file_id,
        ShipmentBooking.is_active == True
    ).first()
    acid_session = db.query(AcidRegistrationSession).filter(
        AcidRegistrationSession.import_file_id == import_file_id,
        AcidRegistrationSession.is_active == True
    ).first()

    # Dynamic extraction of all distinct origins, HS codes, and item descriptions
    extracted_meta = _extract_multi_origins_and_hs_codes(db, import_file_id, supplier)
    origins_list = extracted_meta["origins_list"]
    origin_countries_str = extracted_meta["origin_countries_str"]
    hs_codes_list = extracted_meta["hs_codes_list"]
    hs_codes_str = extracted_meta["hs_codes_str"]
    items_summary = extracted_meta["items_summary"]

    # Automated Classification Rule for COO
    primary_origin = (origins_list[0] if origins_list else (supplier.foreign_exporter_country if supplier else None)) or ""
    classification = classify_coo_certificate_type(primary_origin)

    rec_type = classification.get("recommended_type")
    
    if cert_type and cert_type.strip():
        effective_cert_type = cert_type
    elif rec_type:
        effective_cert_type = rec_type
    else:
        effective_cert_type = "EUR.1"

    is_china = (
        "CHINA" in effective_cert_type.upper()
        or "CCPIT" in effective_cert_type.upper()
        or any(cn in primary_origin.lower() for cn in CHINA_NAMES)
        or any(cn in o.lower() for cn in CHINA_NAMES for o in origins_list)
    )

    # Dynamic goods description grouping by (HS Code, Origin) - English Only
    hs_origin_pairs: dict[tuple[str, str], list[str]] = {}
    for itm in items_summary:
        hs = str(itm.get("hs_code") or "").strip()
        orig = sanitize_english_only(str(itm.get("origin") or origin_countries_str or "").strip())
        desc = itm.get("description")
        desc_str = sanitize_english_only(str(desc).strip()) if desc else ""
        pair_key = (hs, orig)
        if pair_key not in hs_origin_pairs:
            hs_origin_pairs[pair_key] = []
        if desc_str and desc_str not in hs_origin_pairs[pair_key]:
            hs_origin_pairs[pair_key].append(desc_str)

    if not hs_origin_pairs and hs_codes_list:
        for hs in hs_codes_list:
            tariff_rec = db.query(CustomsTariff).filter(CustomsTariff.hs_code == hs).first()
            t_desc = sanitize_english_only(tariff_rec.hs_description if tariff_rec and tariff_rec.hs_description else "") or "COMMERCIAL CARGO"
            for orig in origins_list:
                clean_o = sanitize_english_only(orig)
                hs_origin_pairs[(hs, clean_o)] = [t_desc]

    structured_desc_lines = []
    for (hs_val, orig_val), descs in hs_origin_pairs.items():
        d_text = " / ".join(descs[:3]) if descs else "COMMERCIAL CARGO"
        structured_desc_lines.append(f"{d_text} HS: {hs_val} (Origin: {orig_val})")

    goods_desc_str = " | ".join(structured_desc_lines) if structured_desc_lines else "COMMERCIAL CARGO"

    acid_no = (acid_session.acid_number if acid_session else None) or imp_file.acid_number or ""
    clean_acid_digits = re.sub(r'[^0-9]', '', str(acid_no))
    cert_draft_number = f"DRAFT-{clean_acid_digits}" if clean_acid_digits else "DRAFT-COO"

    # Fetch and consolidate all Purchase Orders linked to this Import File
    pos = db.query(PurchaseOrder).filter(
        PurchaseOrder.import_file_id == import_file_id,
        PurchaseOrder.is_active == True
    ).all()

    consolidated_table_items: Dict[tuple, Dict[str, Any]] = {}

    total_extracted_gw = 0.0
    total_extracted_pkgs = 0

    if pos:
        for po in pos:
            po_inv_num = po.proforma_invoice_number or po.po_number or ""
            po_inv_date = str(po.order_date).split(' ')[0] if po.order_date else (str(getattr(imp_file, 'pi_date', None) or "").split(' ')[0])
            po_gw = float(po.total_gross_weight_kg or 0.0)
            po_pkgs = int(po.total_packages_count or 0)
            
            # Map packing list per HS code if defined
            po_pck_by_hs = {}
            for pck in (po.packing_list_items or []):
                pck_hs = str(pck.hs_code or "").strip()
                if pck_hs:
                    if pck_hs not in po_pck_by_hs:
                        po_pck_by_hs[pck_hs] = {"gw": 0.0, "pkgs": 0}
                    p_cnt = float(getattr(pck, 'qty_pkg', None) or 1.0)
                    p_total_gw = float(getattr(pck, 'total_gross_weight_kg', None) or 0.0)
                    p_unit_gw = float(getattr(pck, 'gross_weight_unit_kg', None) or getattr(pck, 'gross_weight_kg', None) or 0.0)
                    if p_total_gw > 0:
                        po_pck_by_hs[pck_hs]["gw"] += p_total_gw
                    elif p_unit_gw > 0:
                        po_pck_by_hs[pck_hs]["gw"] += (p_cnt * p_unit_gw)
                    po_pck_by_hs[pck_hs]["pkgs"] += int(p_cnt)

            # Group line items of this PO by hs_code
            po_items_by_hs = {}
            for itm in (po.line_items or []):
                hs = None
                if itm.tariff and itm.tariff.hs_code:
                    hs = str(itm.tariff.hs_code).strip()
                elif itm.tariff_id:
                    tf = db.query(CustomsTariff).filter(CustomsTariff.tariff_id == itm.tariff_id).first()
                    if tf and tf.hs_code:
                        hs = str(tf.hs_code).strip()
                hs = hs or (hs_codes_list[0] if hs_codes_list else "")
                if hs not in po_items_by_hs:
                    po_items_by_hs[hs] = []
                po_items_by_hs[hs].append(itm)

            total_po_items_qty = sum(float(i.quantity or 0.0) for i in (po.line_items or [])) or 1.0

            for hs_code_val, itm_list in po_items_by_hs.items():
                group_key = (po_inv_num, po_inv_date, hs_code_val)
                if group_key not in consolidated_table_items:
                    consolidated_table_items[group_key] = {
                        "invoice_number": po_inv_num,
                        "invoice_date": po_inv_date,
                        "hs_code": hs_code_val,
                        "descriptions": [],
                        "quantity": 0.0,
                        "unit": "PCS",
                        "packages_count": 0,
                        "gross_weight_kg": 0.0,
                        "total_price": 0.0,
                    }

                hs_qty = sum(float(i.quantity or 0.0) for i in itm_list)
                hs_val = sum(float(i.total_price or 0.0) for i in itm_list)
                units = [i.unit_of_measure for i in itm_list if i.unit_of_measure]
                unit_str = units[0] if units else "PCS"

                descs = []
                main_descs = []
                for i in itm_list:
                    m_d = getattr(i, 'main_description', None)
                    if not m_d and hasattr(i, 'tariff') and i.tariff and i.tariff.hs_description:
                        m_d = i.tariff.hs_description
                    
                    if m_d and str(m_d).strip():
                        clean_m = extract_clean_main_description(sanitize_english_only(str(m_d).strip()))
                        if clean_m and clean_m != "COMMERCIAL CARGO" and clean_m not in main_descs:
                            main_descs.append(clean_m)

                    d = i.description_en or (i.tariff.hs_description if i.tariff else None) or sanitize_english_only(i.description_ar or "")
                    if d:
                        clean_item_main = extract_clean_main_description(d)
                        if clean_item_main and clean_item_main != "COMMERCIAL CARGO" and clean_item_main not in main_descs:
                            main_descs.append(clean_item_main)
                        if d not in descs:
                            descs.append(d)

                consolidated_table_items[group_key]["quantity"] += hs_qty
                consolidated_table_items[group_key]["total_price"] += hs_val
                consolidated_table_items[group_key]["unit"] = unit_str
                if "main_descriptions" not in consolidated_table_items[group_key]:
                    consolidated_table_items[group_key]["main_descriptions"] = []
                for md in main_descs:
                    if md not in consolidated_table_items[group_key]["main_descriptions"]:
                        consolidated_table_items[group_key]["main_descriptions"].append(md)
                for d in descs:
                    if d not in consolidated_table_items[group_key]["descriptions"]:
                        consolidated_table_items[group_key]["descriptions"].append(d)

                if hs_code_val in po_pck_by_hs:
                    consolidated_table_items[group_key]["gross_weight_kg"] += po_pck_by_hs[hs_code_val]["gw"]
                    consolidated_table_items[group_key]["packages_count"] += po_pck_by_hs[hs_code_val]["pkgs"]
                elif po_gw > 0:
                    ratio = hs_qty / total_po_items_qty
                    calc_gw = po_gw * ratio
                    calc_pkgs = int(round(po_pkgs * ratio)) if po_pkgs > 0 else 1
                    consolidated_table_items[group_key]["gross_weight_kg"] += calc_gw
                    consolidated_table_items[group_key]["packages_count"] += calc_pkgs
                else:
                    itm_gw = sum(float(i.gross_weight_kg or 0.0) for i in itm_list)
                    consolidated_table_items[group_key]["gross_weight_kg"] += itm_gw
                    consolidated_table_items[group_key]["packages_count"] += po_pkgs

    # Fallback if no PO items found
    if not consolidated_table_items:
        def_inv = (reconciliation.final_invoice_number if reconciliation else None) or imp_file.pi_number or ""
        def_date = str(getattr(imp_file, 'pi_date', None) or getattr(imp_file, 'file_opening_date', None) or "").split(' ')[0]
        def_hs = hs_codes_list[0] if hs_codes_list else ""
        def_gw = float(getattr(imp_file, 'total_weight', None) or 0.0)
        def_pkgs = int(getattr(imp_file, 'total_packages', None) or 0)
        consolidated_table_items[(def_inv, def_date, def_hs)] = {
            "invoice_number": def_inv,
            "invoice_date": def_date,
            "hs_code": def_hs,
            "descriptions": [goods_desc_str],
            "main_descriptions": ["ACOUSTIC PANELS" if "560229" in def_hs else "COMMERCIAL CARGO"],
            "quantity": float(getattr(imp_file, 'total_quantity', None) or 0.0),
            "unit": "PCS",
            "packages_count": def_pkgs,
            "gross_weight_kg": def_gw,
            "total_price": float(getattr(imp_file, 'estimated_cost', None) or 0.0),
        }

    total_gross_wt = sum(v["gross_weight_kg"] for v in consolidated_table_items.values())
    total_packages_all = sum(v["packages_count"] for v in consolidated_table_items.values())
    total_qty_all = sum(v["quantity"] for v in consolidated_table_items.values())
    first_unit = next(iter(consolidated_table_items.values()))["unit"] if consolidated_table_items else "PCS"

    # Build multi-row table rows for Visual Sheet, PDF, and CSV
    table_rows: List[Dict[str, Any]] = []
    for idx, ((inv_num, inv_dt, hs_val), c_item) in enumerate(consolidated_table_items.items(), start=1):
        m_descs = c_item.get("main_descriptions", [])
        if m_descs:
            distinct_m = []
            for md in m_descs:
                clean_item = extract_clean_main_description(md)
                if clean_item and clean_item not in distinct_m:
                    distinct_m.append(clean_item)
            clean_d = " / ".join(distinct_m[:2]) if distinct_m else "COMMERCIAL CARGO"
        else:
            d_text = " / ".join(c_item["descriptions"][:2]) if c_item["descriptions"] else "COMMERCIAL CARGO"
            clean_d = extract_clean_main_description(d_text.split(" / ACID:")[0].split(" | ")[0])
            if not clean_d or clean_d == "COMMERCIAL CARGO":
                clean_d = "ACOUSTIC PANELS" if "560229" in hs_val else "COMMERCIAL CARGO"

        # Ensure no accidental N/M or marks exist inside clean_d
        clean_d = re.sub(r'(?i)\bN\s*/\s*M\b', '', clean_d).strip()
        clean_d = re.sub(r'\s{2,}', ' ', clean_d)

        # In Chinese COO, Box 6 is always N/M
        marks_str = "N/M" if is_china else (clean_d[:25].strip() if clean_d else "")
        p_cnt = c_item["packages_count"]
        pkg_type_val = getattr(imp_file, 'package_type', None)
        total_packed_line_item = format_total_packages_line(p_cnt, pkg_type_val)
        
        if is_china:
            box_7_desc = f"{clean_d}\n\n{total_packed_line_item}\n\n*** *** *** *** ***\n\nACID:{acid_no}"
        else:
            box_7_desc = f"{clean_d} {p_cnt} PKGS HS: {hs_val}"
        box_7_desc = re.sub(r'(?i)\bN\s*/\s*M\b', '', box_7_desc).strip()

        q_val = c_item["quantity"]
        u_str = c_item["unit"]
        gw_val = c_item["gross_weight_kg"]
        box_9_formatted = format_coo_quantity_box(
            quantity=q_val,
            unit=u_str,
            packages_count=p_cnt,
            package_type=pkg_type_val,
            gross_weight_kg=gw_val,
            is_china=is_china
        )
        box_10_formatted = f"{inv_num}\n{inv_dt}"

        table_rows.append({
            "item_no": idx,
            "marks_and_numbers": marks_str,
            "description": clean_d,
            "description_and_acid": box_7_desc,
            "hs_code": format_coo_hs_code(hs_val, is_china=is_china),
            "quantity": q_val,
            "unit": u_str,
            "packages_count": p_cnt,
            "gross_weight_kg": gw_val,
            "quantity_and_weight_str": box_9_formatted,
            "invoice_number": inv_num,
            "invoice_date": inv_dt,
            "invoice_str": box_10_formatted,
        })

    # Summary strings
    summary_invoices_str = "\n".join(f"{r['invoice_number']} ({r['invoice_date']})" for r in table_rows)
    primary_invoice_str = f"{table_rows[0]['invoice_number']}\n{table_rows[0]['invoice_date']}".strip() if table_rows else ""
    primary_box_9_str = format_coo_quantity_box(
        quantity=total_qty_all,
        unit=first_unit,
        packages_count=total_packages_all,
        package_type=getattr(imp_file, 'package_type', None),
        gross_weight_kg=total_gross_wt,
        is_china=is_china
    )

    # Dynamic exporter details in pure English
    exporter_name = sanitize_english_only((supplier.company_name if supplier else None) or imp_file.supplier_name or "")
    raw_exp_addr = (supplier.address if supplier else None) or (f"{supplier.city}, {supplier.foreign_exporter_country}" if supplier and getattr(supplier, 'city', None) and getattr(supplier, 'foreign_exporter_country', None) else None) or (supplier.foreign_exporter_country if supplier else None) or (imp_file.origin_country if hasattr(imp_file, 'origin_country') else None) or ""
    exporter_addr = sanitize_english_only(raw_exp_addr)
    
    raw_exporter_reg = (supplier.tax_id if hasattr(supplier, 'tax_id') and supplier.tax_id else None) or (supplier.foreign_exporter_id if hasattr(supplier, 'foreign_exporter_id') and supplier.foreign_exporter_id else None) or (getattr(supplier, 'exporter_code', None)) or ""
    raw_country = (supplier.foreign_exporter_country if supplier and supplier.foreign_exporter_country else None) or (imp_file.origin_country if hasattr(imp_file, 'origin_country') else None) or primary_origin
    clean_country_name = sanitize_english_only(raw_country)
    country_iso = getattr(supplier, 'foreign_exporter_country_code', None) or COUNTRY_ISO_MAP.get(str(clean_country_name).strip().lower(), "")
    
    reg_clean = str(raw_exporter_reg).strip()
    if reg_clean and country_iso and not reg_clean.upper().startswith(country_iso.upper()):
        full_exporter_reg = f"{country_iso.upper()}{reg_clean}"
    else:
        full_exporter_reg = reg_clean

    # Dynamic importer details in pure English
    importer_name = sanitize_english_only((company.importer_name if company and hasattr(company, 'importer_name') and company.importer_name else None) or (company.company_name if company else None) or imp_file.company_name or "")
    raw_imp_addr = (company.address if company else None) or (f"{company.city}, Egypt" if company and hasattr(company, 'city') and company.city else None) or "EGYPT"
    importer_addr = sanitize_english_only(raw_imp_addr)

    dest_country = "EGYPT"
    raw_pol = (getattr(booking, 'pol_name', None) or getattr(booking, 'pol_port_name', None)) or getattr(imp_file, 'port_of_loading', None) or getattr(imp_file, 'pol_name', None) or ""
    raw_pod = (getattr(booking, 'pod_name', None) or getattr(booking, 'pod_port_name', None)) or getattr(imp_file, 'port_of_discharge', None) or getattr(imp_file, 'pod_name', None) or ""
    
    # Format Port of Loading + Country
    pol_name_clean = re.sub(r'(?i)\s+port\s*$', '', sanitize_english_only(raw_pol)).strip().upper()
    pol_country_name = sanitize_english_only(clean_country_name or "").upper()
    if not pol_name_clean:
        pol_full = ""
    elif pol_country_name and pol_country_name not in pol_name_clean:
        pol_full = f"{pol_name_clean} {pol_country_name}".strip()
    else:
        pol_full = pol_name_clean

    # Format Port of Discharge + Country
    pod_name_clean = re.sub(r'(?i)\s+port\s*$', '', sanitize_english_only(raw_pod)).strip().upper()
    pod_country_name = "EGYPT"
    if not pod_name_clean:
        pod_full = ""
    elif pod_country_name not in pod_name_clean:
        pod_full = f"{pod_name_clean} {pod_country_name}".strip()
    else:
        pod_full = pod_name_clean

    # DOC-03: the route is printed only when both ports are known (no sample ports).
    transport_route_str = f"FROM {pol_full} TO {pod_full} BY SEA" if (pol_full and pod_full) else ""

    if is_china:
        cert_name = "China Certificate of Origin (CCPIT)"
        # Collect distinct main descriptions without duplicates
        distinct_main_descs = []
        for r in table_rows:
            d = r.get("description", "").strip()
            if d and d not in distinct_main_descs:
                distinct_main_descs.append(d)
        primary_desc = "\n".join(distinct_main_descs) if distinct_main_descs else "COMMERCIAL CARGO"
        total_pkgs_line_summary = format_total_packages_line(total_packages_all, getattr(imp_file, 'package_type', None))
        box_7_formatted = f"{primary_desc}\n\n{total_pkgs_line_summary}\n\n*** *** *** *** ***\n\nACID:{acid_no}"

        distinct_hs_list = []
        for r in table_rows:
            h = r.get("hs_code", "").strip()
            if h and h not in distinct_hs_list:
                distinct_hs_list.append(h)
        box_8_formatted_hs = ", ".join(distinct_hs_list) if distinct_hs_list else format_coo_hs_code(hs_codes_str, is_china=True)

        template = {
            "certificate_type": cert_name,
            "certificate_number": cert_draft_number,
            "box_1_exporter": f"{exporter_name}\n{exporter_addr}\n***".strip(),
            "box_2_consignee": f"{importer_name}\n{importer_addr}".strip(),
            "box_3_consignee": f"{importer_name}\n{importer_addr}".strip(),
            "box_3_means_of_transport": transport_route_str,
            "box_4_country_of_destination": dest_country,
            "box_5_certifying_authority": "CHINA COUNCIL FOR THE PROMOTION OF INTERNATIONAL TRADE (CCPIT)",
            "box_6_marks_and_numbers": "N/M",
            "box_7_description_and_acid": box_7_formatted,
            "box_8_hs_code": box_8_formatted_hs,
            "box_9_quantity_and_weight": primary_box_9_str,
            "box_10_invoice_number_and_date": primary_invoice_str,
            "box_11_declaration_by_exporter": "",
            "box_12_certification": "",
            "verification_url": "http://check.ecoccpit.net/",
            "exporter_reg_id": full_exporter_reg,
            "countries_of_origin_list": origins_list,
            "country_of_origin": origin_countries_str,
            "hs_codes_list": distinct_hs_list or [box_8_formatted_hs],
            "items_summary": items_summary,
            "structured_desc_lines": structured_desc_lines,
            "table_rows": table_rows,
        }
        markdown = f"""# CERTIFICATE OF ORIGIN (PEOPLE'S REPUBLIC OF CHINA)
**Certificate No:** {template['certificate_number']}
**1. Exporter:** {exporter_name}, {exporter_addr}
**2. Consignee:** {importer_name}, {importer_addr}
**3. Transport:** {template['box_3_means_of_transport']}
**4. Destination:** {dest_country}
**5. Certifying Authority:** {template['box_5_certifying_authority']}
**Country/Countries of Origin:** **{origin_countries_str}**
**6. Marks and Numbers:** N/M
**7. Description & ACID:** {template['box_7_description_and_acid']}
**8. H.S. Code(s):** **{hs_codes_str}**
**9. Quantity & Gross Weight:** {template['box_9_quantity_and_weight']}
**10. Invoice No & Date:** {template['box_10_invoice_number_and_date']}
**Official Verification URL:** {template['verification_url']}"""
        exemption = f"المنشأ: {origin_countries_str} — تخضع الشحنة لضريبة الوارد العامة المقررة بجدول التعريفة الجمركية المصرية وضريبة القيمة المضافة 14%."
    else:
        # EUR.1
        cert_name = "EUR.1 Movement Certificate"
        exp_header = f"{full_exporter_reg}, {exporter_name}".strip(", ") if full_exporter_reg else exporter_name
        template = {
            "certificate_type": cert_name,
            "certificate_number": cert_draft_number,
            "exporter_reg_id": full_exporter_reg,
            "box_1_exporter": f"{exp_header}\n{exporter_addr}".strip(),
            "box_2_preferential_trade": "EU and EGYPT",
            "box_2_consignee": f"{importer_name}\n{importer_addr}".strip(),
            "box_3_consignee": f"{importer_name}\n{importer_addr}".strip(),
            "box_3_means_of_transport": transport_route_str,
            "box_4_country_origin": "EU",
            "box_5_country_destination": dest_country,
            "box_6_transport_details": f"BY SEA FROM {pol_full} TO {pod_full}" if (pol_full and pod_full) else "",
            "box_7_remarks": "REVISED RULES",
            "box_8_description_packages": f"{goods_desc_str} {total_packages_all} PACKAGES HS: {hs_codes_str}",
            "box_9_gross_mass": f"{total_gross_wt:,.3f} KG",
            "box_10_invoices_and_acid": f"ACID: {acid_no}\nINV: {summary_invoices_str}",
            "box_11_customs_endorsement": "",
            "box_12_declaration_by_exporter": "",
            "is_revised_rules_compliant": True,
            "countries_of_origin_list": origins_list,
            "country_of_origin": origin_countries_str,
            "hs_codes_list": hs_codes_list,
            "items_summary": items_summary,
            "structured_desc_lines": structured_desc_lines,
            "table_rows": table_rows,
        }
        markdown = f"""# MOVEMENT CERTIFICATE (EUR.1)
**Certificate No:** {template['certificate_number']}
**1. Exporter:** {template['box_1_exporter']}
**2. Preferential Trade Between:** EU and EGYPT
**3. Consignee:** {template['box_3_consignee']}
**4. Country/Countries of Origin:** **EU** ({origin_countries_str})
**5. Country of Destination:** EGYPT
**7. Remarks:** **REVISED RULES** *(إلزامي للإعفاء التفضيلى الكامل)*
**8. Description of Goods:** {template['box_8_description_packages']}
**8. H.S. Code(s):** **{hs_codes_str}**
**9. Gross Mass:** {template['box_9_gross_mass']}
**10. Invoices & ACID:** {template['box_10_invoices_and_acid']}
**11. Customs Endorsement:** {template['box_11_customs_endorsement']}"""
        exemption = f"مؤهلة للإعفاء الجمركي التفضيلى الكامل (ضريبة وارد 0%) لدول المنشأ ({origin_countries_str}) بموجب اتفاقية الشراكة المصرية الأوروبية وقواعد المنشأ المعدلة (REVISED RULES)."
        markdown = f"""# MOVEMENT CERTIFICATE (EUR.1)
**Certificate No:** {template['certificate_number']}
**1. Exporter:** {template['box_1_exporter']}
**2. Preferential Trade Between:** EU and EGYPT
**3. Consignee:** {template['box_3_consignee']}
**4. Country/Countries of Origin:** **EU** ({origin_countries_str})
**5. Country of Destination:** EGYPT
**7. Remarks:** **REVISED RULES** *(إلزامي للإعفاء التفضيلى الكامل)*
**8. Description of Goods:** {template['box_8_description_packages']}
**8. H.S. Code(s):** **{hs_codes_str}**
**9. Gross Mass:** {template['box_9_gross_mass']}
**10. Invoices & ACID:** {template['box_10_invoices_and_acid']}
**11. Customs Endorsement:** {template['box_11_customs_endorsement']}"""
        exemption = f"مؤهلة للإعفاء الجمركي التفضيلى الكامل (ضريبة وارد 0%) لدول المنشأ ({origin_countries_str}) بموجب اتفاقية الشراكة المصرية الأوروبية وقواعد المنشأ المعدلة (REVISED RULES)."

    missing = _missing_fields(
        acid_number=acid_no,
        hs_code=hs_codes_list,
        country_of_origin=origins_list,
        exporter_name=exporter_name,
        importer_name=importer_name,
        invoice_number=table_rows and all(r["invoice_number"] for r in table_rows),
        gross_weight_kg=total_gross_wt > 0,
        packages_count=total_packages_all > 0,
        port_of_loading=pol_full,
        port_of_discharge=pod_full,
    )
    template["missing_fields"] = missing
    return _template_response(
        COODraftTemplateResponse,
        missing,
        import_file_id=import_file_id,
        import_file_code=imp_file.import_file_code or f"IMP-{import_file_id:04d}",
        certificate_type=cert_name,
        template_data=template,
        preview_markdown=markdown,
        exemption_notes=exemption,
        recommended_certificate_type=classification.get("recommended_type"),
        allowed_certificate_types=classification.get("allowed_types"),
        recommendation_alert=classification.get("recommendation_alert"),
        is_manual_choice_required=classification.get("is_manual_choice_required", False),
    )


def generate_inspection_draft_template_service(
    db: Session,
    import_file_id: int,
    agency: str = "COTECNA",
    cert_type: str = "COC (Certificate of Conformity)"
) -> InspectionDraftTemplateResponse:
    imp_file = _active_import_file(db, import_file_id, status_code=status.HTTP_404_NOT_FOUND)

    company = db.query(ImportCompany).filter(ImportCompany.company_id == imp_file.company_id).first() if imp_file.company_id else None
    supplier = db.query(Supplier).filter(Supplier.supplier_id == imp_file.supplier_id).first() if imp_file.supplier_id else None
    reconciliation = db.query(POPackingReconciliationSession).filter(
        POPackingReconciliationSession.import_file_id == import_file_id,
        POPackingReconciliationSession.is_active == True
    ).first()
    acid_session = db.query(AcidRegistrationSession).filter(
        AcidRegistrationSession.import_file_id == import_file_id,
        AcidRegistrationSession.is_active == True
    ).first()

    # Dynamic extraction of all distinct origins and HS codes
    extracted_meta = _extract_multi_origins_and_hs_codes(db, import_file_id, supplier)
    origins_list = extracted_meta["origins_list"]
    origin_countries_str = extracted_meta["origin_countries_str"]
    hs_codes_list = extracted_meta["hs_codes_list"]
    hs_codes_str = extracted_meta["hs_codes_str"]
    items_summary = extracted_meta["items_summary"]

    # DOC-03: values the system does not have stay empty and are listed in missing_fields.
    acid_no = (acid_session.acid_number if acid_session else None) or imp_file.acid_number or ""
    invoice_no = (reconciliation.final_invoice_number if reconciliation else None) or imp_file.pi_number or ""
    inv_amount = float(getattr(reconciliation, 'total_invoice_amount', None) or getattr(imp_file, 'estimated_cost', None) or getattr(imp_file, 'fob_amount', None) or 0.0)
    inv_currency = getattr(reconciliation, 'currency', None) or getattr(imp_file, 'estimated_cost_currency', None) or getattr(imp_file, 'currency', None) or ""
    incoterm_val = getattr(imp_file, 'incoterm_code', None) or getattr(imp_file, 'incoterm', None) or ""

    importer_name = (company.importer_name if company else imp_file.company_name) or ""
    importer_addr = (company.address if company else None) or ""

    exporter_name = (supplier.company_name if supplier else imp_file.supplier_name) or ""
    exporter_addr = (supplier.address if supplier else None) or ""

    # Dynamic generation of inspected items
    inspected_items = []
    if items_summary:
        for idx, itm in enumerate(items_summary, start=1):
            d_name = itm.get("product_name") or itm.get("description") or f"Item {idx}"
            qty = itm.get("quantity")
            if qty is not None and str(qty).strip() != "" and float(qty) > 0:
                uom = itm.get("uom") or itm.get("unit") or "pieces"
                qty_display = int(qty) if isinstance(qty, (int, float)) and qty == int(qty) else qty
                q_val = f"{qty_display} {uom}".strip()
            else:
                q_val = ""
            is_acoustic = "acoustic" in d_name.lower() or "panel" in d_name.lower()
            is_chair = any(w in d_name.lower() for w in ["chair", "seat", "armchair", "stool"])
            is_table = any(w in d_name.lower() for w in ["table", "desk"])
            if is_acoustic:
                p_type = "Acoustic Panels"
                std = "EN 13501-1:2018"
            elif is_chair:
                p_type = "Office Chairs"
                std = "ES 7321/2011 + ES 495-1/2005 + ES 495-2/2015"
            elif is_table:
                p_type = "Office Furniture / Tables"
                std = "ES 4029-1 / 2024 + ES 7321 / 2011"
            else:
                p_type = ""
                std = ""

            brand_part = f", brand: {exporter_name.split()[0]}" if exporter_name else ""
            desc = f"{d_name}{brand_part}"

            inspected_items.append({
                "item_no": idx,
                "quantity": q_val,
                "country_of_origin": itm.get("origin_country") or origin_countries_str,
                "product_type": p_type,
                "description": desc,
                "adopted_standard": std,
            })
    # DOC-03: no PO lines -> no inspected items (the former sample item lists were invented data).

    # Dynamic derivation of applicable standards linked directly to product items in the shipment
    unique_standards = []
    for itm in inspected_items:
        std = itm.get("adopted_standard") or ""
        for s in std.split("+"):
            s_clean = s.strip()
            if s_clean and s_clean not in unique_standards:
                unique_standards.append(s_clean)

    applicable_standards = unique_standards

    issuing_office = f"TÜV Rheinland Sweden AB" if "TÜV" in agency or "TUV" in agency else (f"Cotecna Inspection S.A. Geneva Office" if "COTECNA" in agency else f"{agency} Inspection Office")

    template = {
        "inspection_agency": agency,
        "inspection_type": cert_type,
        "coc_number": "",
        "is_draft": True,
        "confirmation_deadline": "PLEASE CONFIRM THIS DRAFT WITHIN 48 HOURS AFTER WHICH WE SHALL PROCEED TO ISSUE AS IT IS",
        "importer_name_and_address": f"{importer_name}\n{importer_addr}",
        "exporter_name_and_address": f"{exporter_name}\n{exporter_addr}",
        "producer_name_and_address": f"{exporter_name}\n{exporter_addr}",
        "country_of_origin": origin_countries_str,
        "countries_of_origin_list": origins_list,
        "hs_code": hs_codes_str,
        "hs_codes_list": hs_codes_list,
        "acid_number": acid_no,
        "commercial_invoices": [
            {
                "invoice_number": invoice_no,
                "invoice_date": str(getattr(imp_file, 'pi_date', None) or getattr(imp_file, 'file_opening_date', None) or date.today()),
                "amount": inv_amount,
                "currency": inv_currency,
                "incoterm": incoterm_val,
            }
        ],
        "total_value": f"{inv_amount:,.2f} {inv_currency}",
        "method_of_shipment": getattr(imp_file, 'shipping_mode', 'Sea') or "Sea",
        "place_of_inspection": origin_countries_str,
        "date_of_inspection": str(date.today()),
        "port_of_entry": getattr(imp_file, 'port_of_discharge', None) or getattr(imp_file, 'pod_name', None) or "",
        "issuing_office": issuing_office,
        "regulatory_authority": "General Organization for Export and Import Control (GOEIC)",
        "applicable_standards": applicable_standards,
        "items_summary": items_summary,
        "inspected_items": inspected_items,
    }

    markdown = f"""# {agency.upper()} - CERTIFICATE OF CONFORMITY (COC / VoC)
**Arabic Republic of Egypt - Inspection Program**
⚠️ **DRAFT NOTICE:** *{template['confirmation_deadline']}*

**CoC No:** {template['coc_number']} | **Date:** {template['date_of_inspection']}
**Importer:** {importer_name} ({importer_addr})
**Exporter & Producer:** {exporter_name} ({exporter_addr})
**Country/Countries of Origin:** **{origin_countries_str}**
**H.S. Code(s):** **{hs_codes_str}**
**ACID Number:** **{acid_no}**
**Value:** {template['total_value']} ({incoterm_val})
**Point of Entry:** {template['port_of_entry']}
**Inspection Place:** {template['place_of_inspection']}

### 📋 Egyptian Mandatory Standards Tested:
""" + "\n".join([f"- {s}" for s in applicable_standards])

    has_adopted_standard = bool(inspected_items) and all(bool(itm.get("adopted_standard")) for itm in inspected_items)

    missing = _missing_fields(
        acid_number=acid_no,
        hs_code=hs_codes_list,
        country_of_origin=origins_list,
        importer_name=importer_name,
        exporter_name=exporter_name,
        invoice_number=invoice_no,
        invoice_amount=inv_amount > 0,
        currency=inv_currency,
        incoterm=incoterm_val,
        port_of_entry=template["port_of_entry"],
        coc_number=template["coc_number"],
        adopted_standard=has_adopted_standard,
    )
    template["missing_fields"] = missing
    return _template_response(
        InspectionDraftTemplateResponse,
        missing,
        import_file_id=import_file_id,
        import_file_code=imp_file.import_file_code or f"IMP-{import_file_id:04d}",
        inspection_agency=agency,
        inspection_type=cert_type,
        template_data=template,
        preview_markdown=markdown,
        applicable_standards=applicable_standards,
    )
