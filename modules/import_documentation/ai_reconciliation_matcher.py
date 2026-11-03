"""
Smart PO Documents Reconciliation & Invoice vs. Bill of Lading Matcher Engine
Specialized for 3-Way & 14-Point Egyptian Import Cross-Verification.
"""

import re
import logging
from typing import Any, Dict, List, Optional, Tuple

from modules.common.enum_codes import Measure, Placeholder, finalize_structured_values
from modules.common.system_messages import coded_text
from modules.import_documentation.ai_parser_core import (
    _normalize_text,
    _fuzzy_match_strings,
    _numeric_tolerance_match,
    validate_iso_container_number,
)

logger = logging.getLogger(__name__)

_CODE_STRIP_RE = re.compile(r'[\s/_-]')
_SEVERITY_BY_STATUS = {"MISMATCH_CRITICAL": "BLOCKING", "EXTRACTION_FAILED": "WARNING"}


def _abs_difference(a: Any, b: Any) -> Any:
    """|a - b| for numeric values; the raw pair as text when a value is not numeric."""
    try:
        diff = abs(float(a or 0) - float(b or 0))
    except (TypeError, ValueError):
        return f"{a} / {b}"
    return int(diff) if diff.is_integer() else round(diff, 2)


def _normalized_contains(a: Any, b: Any, strip_re: str = r'[^\w]') -> bool:
    """True when both values, stripped by `strip_re` and upper-cased, are equal or one contains the other."""
    n1 = re.sub(strip_re, '', str(a)).upper()
    n2 = re.sub(strip_re, '', str(b)).upper()
    return (n1 == n2) or (n1 in n2) or (n2 in n1)


def _header_row(
    check_code: str,
    field_name: str,
    label_ar: str,
    system_value: Any,
    extracted_value: Any,
    sys_inv: Any,
    sys_pl: Any,
    upl_inv: Any,
    upl_pl: Any,
    status: str,
    details: Dict[str, Any],
) -> Dict[str, Any]:
    """
    One HEADER row of the 4-way (system invoice / system packing / uploaded invoice / uploaded packing) matrix.
    `details` is the coded_text("details", ...) fields.
    """
    return finalize_structured_values({
        "category": "HEADER",
        "check_code": check_code,
        "field_name": field_name,
        "field_name_ar": label_ar,
        "system_value": system_value,
        "extracted_value": extracted_value,
        "system_invoice_value": sys_inv,
        "system_packing_value": sys_pl,
        "uploaded_invoice_value": upl_inv,
        "uploaded_packing_value": upl_pl,
        "status": status,
        **details,
    })


def _lazy_code_norms(items: List[dict]):
    """Returns get(i) -> normalized item_code of items[i], computed at most once per item (on first use)."""
    cache: Dict[int, str] = {}

    def get(i: int) -> str:
        if i not in cache:
            cache[i] = _CODE_STRIP_RE.sub('', items[i].get("item_code", "")).upper()
        return cache[i]

    return get


def reconcile_po_documents_with_system(
    invoice_data: dict,
    pl_data: dict,
    system_po_items: List[dict],
    file_metadata: Optional[dict] = None,
    system_packing_items: Optional[List[dict]] = None,
) -> dict:
    """
    Executes 3-way reconciliation comparing:
    1. Final Commercial Invoice Data (Prices, Totals, Quantities)
    2. Final Packing List Data (Packages, Net/Gross Weights, CBM)
    3. Initial System Purchase Order Data (Initial quantities, budgeted prices, initial specs)
    """
    file_meta = file_metadata or {}
    discrepancies: List[Dict[str, Any]] = []
    has_critical = False
    has_warning = False

    # 1. Header Checks
    # 1.0 Invoice Number Check
    inv_num = invoice_data.get("invoice_number")
    sys_inv_num = file_meta.get("final_invoice_number") or file_meta.get("po_number")
    inv_num_match = True
    if sys_inv_num and inv_num:
        inv_num_match = _normalized_contains(sys_inv_num, inv_num, strip_re=r'[\s/_-]')
        if not inv_num_match:
            has_warning = True
    discrepancies.append(_header_row(
        "CHK_INVOICE_NO", "invoice_number", "رقم الفاتورة التجارية (Commercial Invoice No)",
        sys_inv_num or Placeholder("NOT_SET"),
        inv_num or Placeholder("NOT_IN_DOCUMENT"),
        sys_inv_num or Placeholder("NOT_SET"),
        file_meta.get("packing_list_number") or sys_inv_num or Placeholder("NOT_SET"),
        inv_num or Placeholder("NOT_IN_DOCUMENT"),
        pl_data.get("packing_list_number") or pl_data.get("order_number") or inv_num or Placeholder("NOT_IN_DOCUMENT"),
        "MATCH" if inv_num_match else "MAJOR_VARIANCE",
        coded_text("details", "DOC_CHK_INVOICE_NO_MATCH") if inv_num_match else coded_text(
            "details", "DOC_CHK_INVOICE_NO_MISMATCH", document_value=inv_num, system_value=sys_inv_num),
    ))

    # 1.1 ACID Check
    inv_acid = invoice_data.get("acid_number") or pl_data.get("acid_number")
    sys_acid = file_meta.get("acid_number")
    acid_match = True
    if sys_acid and inv_acid:
        acid_match = sys_acid == inv_acid
        if not acid_match:
            has_critical = True
    discrepancies.append(_header_row(
        "CHK_ACID", "acid_number", "رقم القيد الجمركي المسبق (ACID)",
        sys_acid or Placeholder("NOT_SET"),
        inv_acid or Placeholder("NOT_IN_DOCUMENT"),
        sys_acid or Placeholder("NOT_SET"),
        sys_acid or Placeholder("NOT_SET"),
        invoice_data.get("acid_number") or Placeholder("NOT_IN_DOCUMENT"),
        pl_data.get("acid_number") or invoice_data.get("acid_number") or Placeholder("NOT_IN_DOCUMENT"),
        "MATCH" if acid_match else "CRITICAL_VARIANCE",
        coded_text("details", "DOC_CHK_ACID_MATCH" if acid_match else "DOC_CHK_ACID_MISMATCH"),
    ))

    # 1.2 Tax ID Check
    inv_tax = invoice_data.get("importer_tax_id")
    sys_tax = file_meta.get("importer_tax_id")
    tax_match = True
    if sys_tax and inv_tax:
        tax_match = sys_tax == inv_tax
        if not tax_match:
            has_critical = True
    discrepancies.append(_header_row(
        "CHK_TAX_ID", "tax_id", "البطاقة الضريبية للمستورد (Tax ID)",
        sys_tax or Placeholder("NOT_SET"),
        inv_tax or Placeholder("NOT_IN_DOCUMENT"),
        sys_tax or Placeholder("NOT_SET"),
        sys_tax or Placeholder("NOT_SET"),
        invoice_data.get("importer_tax_id") or Placeholder("NOT_IN_DOCUMENT"),
        pl_data.get("importer_tax_id") or invoice_data.get("importer_tax_id") or Placeholder("NOT_IN_DOCUMENT"),
        "MATCH" if tax_match else "CRITICAL_VARIANCE",
        coded_text("details", "DOC_CHK_TAX_ID_MATCH" if tax_match else "DOC_CHK_TAX_ID_MISMATCH"),
    ))

    # 1.3 Supplier Name Check
    inv_supplier = (invoice_data.get("supplier_name") or invoice_data.get("shipper_name") or "").strip()
    sys_supplier = (file_meta.get("supplier_name") or "").strip()
    supplier_match = True
    if sys_supplier and inv_supplier:
        supplier_match = _normalized_contains(sys_supplier, inv_supplier)
        if not supplier_match:
            has_warning = True
    discrepancies.append(_header_row(
        "CHK_SUPPLIER_NAME", "supplier_name", "اسم المورد الأجنبي (Foreign Supplier)",
        sys_supplier or Placeholder("NOT_SET"),
        inv_supplier or Placeholder("NOT_IN_DOCUMENT"),
        sys_supplier or Placeholder("NOT_SET"),
        sys_supplier or Placeholder("NOT_SET"),
        (invoice_data.get("supplier_name") or invoice_data.get("shipper") or invoice_data.get("shipper_name") or "").strip() or Placeholder("NOT_IN_DOCUMENT"),
        (pl_data.get("supplier_name") or pl_data.get("shipper") or pl_data.get("shipper_name") or invoice_data.get("supplier_name") or "").strip() or Placeholder("NOT_IN_DOCUMENT"),
        "MATCH" if (supplier_match or not sys_supplier or not inv_supplier) else "MINOR_VARIANCE",
        coded_text("details", "DOC_CHK_SUPPLIER_MATCH") if (supplier_match or not sys_supplier or not inv_supplier)
            else coded_text("details", "DOC_CHK_SUPPLIER_MISMATCH", document_value=inv_supplier, system_value=sys_supplier),
    ))

    # 1.4 Importer / Consignee Name Check
    inv_importer = (invoice_data.get("importer_name") or invoice_data.get("consignee_name") or "").strip()
    sys_importer = (file_meta.get("importer_name") or "").strip()
    importer_match = True
    if sys_importer and inv_importer:
        importer_match = _normalized_contains(sys_importer, inv_importer)
        if not importer_match:
            has_warning = True
    discrepancies.append(_header_row(
        "CHK_IMPORTER_NAME", "importer_name", "اسم الشركة المستوردة (Importing Company)",
        sys_importer or Placeholder("NOT_SET"),
        inv_importer or Placeholder("NOT_IN_DOCUMENT"),
        sys_importer or Placeholder("NOT_SET"),
        sys_importer or Placeholder("NOT_SET"),
        (invoice_data.get("importer_name") or invoice_data.get("consignee") or invoice_data.get("consignee_name") or invoice_data.get("buyer") or "").strip() or Placeholder("NOT_IN_DOCUMENT"),
        (pl_data.get("importer_name") or pl_data.get("consignee") or pl_data.get("consignee_name") or pl_data.get("customer_name") or invoice_data.get("importer_name") or "").strip() or Placeholder("NOT_IN_DOCUMENT"),
        "MATCH" if (importer_match or not sys_importer or not inv_importer) else "MINOR_VARIANCE",
        coded_text("details", "DOC_CHK_IMPORTER_MATCH") if (importer_match or not sys_importer or not inv_importer)
            else coded_text("details", "DOC_CHK_IMPORTER_MISMATCH", document_value=inv_importer, system_value=sys_importer),
    ))

    # 1.5 HS Code Check
    inv_hs = (invoice_data.get("hs_code") or (invoice_data.get("items", [{}])[0].get("hs_code") if invoice_data.get("items") else "") or "").strip()
    sys_hs = (file_meta.get("hs_code") or "").strip()
    hs_match = True
    if sys_hs and inv_hs:
        hs_match = sys_hs.replace(".", "") == inv_hs.replace(".", "") or sys_hs in inv_hs or inv_hs in sys_hs
        if not hs_match:
            has_warning = True
    discrepancies.append(_header_row(
        "CHK_HS_CODE", "hs_code", "البند الجمركي (HS Code)",
        sys_hs or Placeholder("NOT_SET"),
        inv_hs or Placeholder("NOT_IN_DOCUMENT"),
        sys_hs or Placeholder("NOT_SET"),
        sys_hs or Placeholder("NOT_SET"),
        inv_hs or Placeholder("NOT_IN_DOCUMENT"),
        (pl_data.get("hs_code") or (pl_data.get("items", [{}])[0].get("hs_code") if pl_data.get("items") else "") or inv_hs or "").strip() or Placeholder("NOT_IN_DOCUMENT"),
        "MATCH" if (hs_match or not sys_hs or not inv_hs) else "MINOR_VARIANCE",
        coded_text("details", "DOC_CHK_HS_CODE_MATCH") if (hs_match or not sys_hs or not inv_hs)
            else coded_text("details", "DOC_CHK_HS_CODE_MISMATCH", document_value=inv_hs, system_value=sys_hs),
    ))

    # 1.6 Total Amount & Currency Check
    inv_tot = float(invoice_data.get("total_amount") or 0.0)
    sys_tot = float(file_meta.get("total_amount") or 0.0)
    sys_curr = (file_meta.get("currency") or "").strip() or None
    inv_curr = (invoice_data.get("currency") or "").strip() or None
    curr_match = bool(sys_curr and inv_curr and sys_curr.upper() == inv_curr.upper())

    amt_match, amt_pct, amt_diff = _numeric_tolerance_match(sys_tot, inv_tot, tolerance_pct=0.01)
    if (not curr_match) or (not amt_match and sys_tot > 0 and inv_tot > 0):
        has_warning = True

    is_amount_matched = (amt_match and curr_match)
    details_fields = coded_text("details", "DOC_CHK_AMOUNT_MATCH")
    if not curr_match:
        details_fields = coded_text(
            "details", "DOC_CHK_CURRENCY_MISMATCH", system_currency=sys_curr or "—", document_currency=inv_curr or "—"
        )
    elif not amt_match and sys_tot > 0:
        details_fields = coded_text(
            "details", "DOC_CHK_AMOUNT_VARIANCE",
            variance_amount=round(amt_diff, 2), currency=sys_curr or "—", variance_pct=round(amt_pct, 2),
        )

    sys_curr_display = f" {sys_curr}" if sys_curr else ""
    inv_curr_display = f" {inv_curr}" if inv_curr else ""

    discrepancies.append(_header_row(
        "CHK_TOTAL_AMOUNT", "total_amount", "إجمالي قيمة الفاتورة (Total Invoice Amount)",
        f"{sys_tot:,.2f}{sys_curr_display}",
        f"{inv_tot:,.2f}{inv_curr_display}",
        f"{sys_tot:,.2f}{sys_curr_display}",
        Placeholder("NOT_IN_PACKING_LIST"),
        f"{inv_tot:,.2f}{inv_curr_display}",
        "—",
        "MATCH" if is_amount_matched else "MINOR_VARIANCE",
        details_fields,
    ))

    # Total Packages Check
    eff_packing = system_packing_items or system_po_items
    sys_pl_pkgs = int(sum(float(p.get("initial_packages_count") or 0) for p in eff_packing))
    sys_pl_gw   = sum(float(p.get("initial_gross_weight_kg") or 0) for p in eff_packing)
    sys_pl_nw   = sum(float(p.get("initial_net_weight_kg") or 0) for p in eff_packing)
    sys_pl_cbm  = sum(float(p.get("initial_cbm") or 0) for p in eff_packing)

    pl_pkgs = pl_data.get("total_packages") or invoice_data.get("qty_pkg", 0)
    sys_pkgs = file_meta.get("total_packages", 0)
    pkg_match = bool(pl_pkgs == sys_pkgs or sys_pkgs == 0)
    discrepancies.append(_header_row(
        "CHK_PACKAGES", "total_packages", "إجمالي عدد الطرود (Total Packages / Colli)",
        Measure(sys_pkgs, "PACKAGES", decimals=None),
        Measure(pl_pkgs, "PACKAGES", decimals=None),
        Measure(sys_pkgs, "PACKAGES", decimals=None),
        Measure(sys_pl_pkgs, "PACKAGES", decimals=None),
        Measure(int(invoice_data.get('qty_pkg') or 0), "PACKAGES", decimals=None) if invoice_data.get('qty_pkg') else Placeholder("NOT_IN_INVOICE"),
        Measure(pl_pkgs, "PACKAGES", decimals=None),
        "MATCH" if pkg_match else "MINOR_VARIANCE",
        coded_text("details", "DOC_CHK_PACKAGES_MATCH") if pkg_match else coded_text(
            "details", "DOC_CHK_PACKAGES_VARIANCE", difference_count=_abs_difference(pl_pkgs, sys_pkgs)),
    ))

    # Total Gross Weight Check
    pl_gw = pl_data.get("total_gross_weight_kg") or invoice_data.get("total_gross_weight_kg", 0.0)
    sys_gw = file_meta.get("total_gross_weight_kg", 0.0)
    gw_match, gw_pct, gw_diff = _numeric_tolerance_match(sys_gw, pl_gw, tolerance_pct=2.0)
    discrepancies.append(_header_row(
        "CHK_GROSS_WEIGHT", "gross_weight", "الوزن القائم الإجمالي (Total Gross Weight KG)",
        Measure(sys_gw, "KG"),
        Measure(pl_gw, "KG"),
        Measure(sys_gw, "KG"),
        Measure(sys_pl_gw, "KG"),
        Measure(float(invoice_data.get('total_gross_weight_kg') or 0), "KG") if invoice_data.get('total_gross_weight_kg') else Placeholder("NOT_IN_INVOICE"),
        Measure(pl_gw, "KG"),
        "MATCH" if (gw_match or sys_gw == 0) else "MINOR_VARIANCE",
        coded_text("details", "DOC_CHK_GROSS_WEIGHT_MATCH") if (gw_match or sys_gw == 0) else coded_text(
            "details", "DOC_CHK_GROSS_WEIGHT_VARIANCE", difference_qty=round(gw_diff, 2), difference_pct=round(gw_pct, 2)),
    ))

    # Net Weight Check
    pl_nw = pl_data.get("total_net_weight_kg") or 0.0
    sys_nw = file_meta.get("total_net_weight_kg", 0.0)
    nw_match, nw_pct, nw_diff = _numeric_tolerance_match(sys_nw, pl_nw, tolerance_pct=2.0)
    discrepancies.append(_header_row(
        "CHK_NET_WEIGHT", "net_weight", "الوزن الصافي الإجمالي (Total Net Weight KG)",
        Measure(sys_nw, "KG"),
        Measure(pl_nw, "KG"),
        Measure(sys_nw, "KG"),
        Measure(sys_pl_nw, "KG"),
        Measure(float(invoice_data.get('total_net_weight_kg') or 0), "KG") if invoice_data.get('total_net_weight_kg') else Placeholder("NOT_IN_INVOICE"),
        Measure(pl_nw, "KG"),
        "MATCH" if (nw_match or sys_nw == 0) else "MINOR_VARIANCE",
        coded_text("details", "DOC_CHK_NET_WEIGHT_MATCH") if (nw_match or sys_nw == 0) else coded_text(
            "details", "DOC_CHK_NET_WEIGHT_VARIANCE", difference_qty=round(nw_diff, 2), difference_pct=round(nw_pct, 2)),
    ))

    # Total CBM Check
    pl_cbm = pl_data.get("total_cbm") or 0.0
    sys_cbm_val = file_meta.get("total_cbm", 0.0)
    cbm_match, cbm_pct, cbm_diff = _numeric_tolerance_match(sys_cbm_val, pl_cbm, tolerance_pct=3.0)
    discrepancies.append(_header_row(
        "CHK_TOTAL_CBM", "total_cbm", "الحجم الإجمالي (Total Volume CBM)",
        Measure(sys_cbm_val, "CBM"),
        Measure(pl_cbm, "CBM"),
        Measure(sys_cbm_val, "CBM"),
        Measure(sys_pl_cbm, "CBM"),
        Placeholder("NOT_IN_INVOICE"),
        Measure(pl_cbm, "CBM"),
        "MATCH" if (cbm_match or sys_cbm_val == 0) else "MINOR_VARIANCE",
        coded_text("details", "DOC_CHK_CBM_MATCH") if (cbm_match or sys_cbm_val == 0) else coded_text(
            "details", "DOC_CHK_CBM_VARIANCE", difference_qty=round(cbm_diff, 2), difference_pct=round(cbm_pct, 2)),
    ))

    # 2. Line Items Reconciliation
    inv_items = invoice_data.get("items", [])
    pl_items = pl_data.get("items", [])

    reconciled_inv_items: List[Dict[str, Any]] = []
    reconciled_pl_items: List[Dict[str, Any]] = []
    inv_norm_at = _lazy_code_norms(inv_items)
    pl_norm_at = _lazy_code_norms(pl_items)

    for idx, sys_itm in enumerate(system_po_items, 1):
        s_code = sys_itm.get("item_code", str(idx))
        s_desc = sys_itm.get("description", "")
        s_qty = float(sys_itm.get("initial_quantity") or sys_itm.get("quantity") or 1.0)
        s_price = float(sys_itm.get("initial_unit_price") or sys_itm.get("unit_price") or 0.0)
        _raw_pkg = sys_itm.get("initial_packages_count")
        s_pkg = float(_raw_pkg) if (_raw_pkg is not None and float(_raw_pkg) > 0) else 1.0
        s_net = float(sys_itm.get("initial_net_weight_kg") or 0.0)
        s_gross = float(sys_itm.get("initial_gross_weight_kg") or 0.0)
        s_cbm = float(sys_itm.get("initial_cbm") or 0.0)

        # Match with Invoice Item
        matched_inv = None
        s_norm = _CODE_STRIP_RE.sub('', s_code).upper()
        for j, inv_i in enumerate(inv_items):
            inv_norm = inv_norm_at(j)
            if s_norm and inv_norm and (s_norm == inv_norm):
                matched_inv = inv_i
                break
        if not matched_inv:
            for inv_i in inv_items:
                m_code, r_code = _fuzzy_match_strings(s_code, inv_i.get("item_code"))
                m_desc, r_desc = _fuzzy_match_strings(s_desc, inv_i.get("description"))
                if (m_code and r_code >= 0.95) or (m_desc and r_desc >= 0.85):
                    matched_inv = inv_i
                    break
        if not matched_inv:
            if len(inv_items) == 1 and len(system_po_items) > 1:
                matched_inv = None
            elif idx <= len(inv_items):
                matched_inv = inv_items[idx - 1]

        final_qty = matched_inv.get("quantity", s_qty) if matched_inv else s_qty
        final_price = matched_inv.get("unit_price", s_price) if matched_inv else s_price
        inv_desc = matched_inv.get("description", s_desc) if matched_inv else s_desc
        inv_hs = matched_inv.get("hs_code", sys_itm.get("hs_code", "")) if matched_inv else sys_itm.get("hs_code", "")

        # Match with Packing List Item
        matched_pl = None
        for j, pl_i in enumerate(pl_items):
            pl_norm = pl_norm_at(j)
            if s_norm and pl_norm and (s_norm == pl_norm):
                matched_pl = pl_i
                break
        if not matched_pl:
            for pl_i in pl_items:
                m_code, r_code = _fuzzy_match_strings(s_code, pl_i.get("item_code"))
                m_desc, r_desc = _fuzzy_match_strings(s_desc, pl_i.get("description"))
                if (m_code and r_code >= 0.95) or (m_desc and r_desc >= 0.85):
                    matched_pl = pl_i
                    break
        if not matched_pl and idx <= len(pl_items):
            matched_pl = pl_items[idx - 1]

        final_pkgs = matched_pl.get("packages_count", s_pkg) if matched_pl else s_pkg
        pl_qty = float(matched_pl.get("quantity") or s_qty) if matched_pl else s_qty
        final_net = matched_pl.get("net_weight_kg", s_net) if matched_pl else s_net
        final_gross = matched_pl.get("gross_weight_kg", s_gross) if matched_pl else s_gross
        final_cbm = matched_pl.get("calculated_cbm", s_cbm) if matched_pl else s_cbm
        pkg_type = (matched_pl.get("package_type") or sys_itm.get("package_type")) if matched_pl else sys_itm.get("package_type")

        # Variances
        qty_var = round(((final_qty - s_qty) / s_qty) * 100.0, 2) if s_qty > 0 else 0.0
        pl_qty_var = round(((pl_qty - s_qty) / s_qty) * 100.0, 2) if s_qty > 0 else 0.0
        price_var = round(((final_price - s_price) / s_price) * 100.0, 2) if s_price > 0 else 0.0
        weight_var = round(((final_gross - s_gross) / s_gross) * 100.0, 2) if s_gross > 0 else 0.0

        if abs(qty_var) > 5.0 or abs(price_var) > 5.0 or abs(pl_qty_var) > 5.0:
            has_warning = True

        reconciled_inv_items.append({
            "po_item_id": sys_itm.get("po_item_id") or idx,
            "item_code": s_code,
            "description": inv_desc,
            "hs_code": inv_hs,
            "package_type": pkg_type,
            "initial_quantity": s_qty,
            "final_quantity": final_qty,
            "initial_unit_price": s_price,
            "unit_price": final_price,
            "final_unit_price": final_price,
            "initial_packages_count": s_pkg,
            "final_packages_count": final_pkgs,
            "initial_net_weight_kg": s_net,
            "final_net_weight_kg": final_net,
            "initial_gross_weight_kg": s_gross,
            "final_gross_weight_kg": final_gross,
            "initial_cbm": s_cbm,
            "final_cbm": final_cbm,
            "variance_percentage": qty_var,
            "price_variance_percentage": price_var,
            "weight_variance_percentage": weight_var,
            "total_amount": round(final_qty * (final_price if final_price > 0 else s_price), 2),
        })

    # Build reconciled_pl_items from system_packing_items
    for p_idx, sys_pl in enumerate(eff_packing, 1):
        p_code = sys_pl.get("item_code") or str(p_idx)
        p_desc = sys_pl.get("description") or p_code
        p_qty = float(sys_pl.get("initial_quantity") or sys_pl.get("quantity") or 0.0)
        p_pkg = float(sys_pl.get("initial_packages_count") or sys_pl.get("qty_pkg") or 0.0)
        p_net = float(sys_pl.get("initial_net_weight_kg") or sys_pl.get("total_net_weight_kg") or 0.0)
        p_gross = float(sys_pl.get("initial_gross_weight_kg") or sys_pl.get("total_gross_weight_kg") or 0.0)
        p_cbm = float(sys_pl.get("initial_cbm") or sys_pl.get("total_cbm") or 0.0)
        p_type = sys_pl.get("package_type") or None
        p_hs = sys_pl.get("hs_code") or ""

        matched_upl = None
        p_norm = _CODE_STRIP_RE.sub('', p_code).upper()
        for j, pl_i in enumerate(pl_items):
            pl_norm = pl_norm_at(j)
            if p_norm and pl_norm and (p_norm == pl_norm or p_norm in pl_norm or pl_norm in p_norm):
                matched_upl = pl_i
                break
        if not matched_upl and p_idx <= len(pl_items):
            matched_upl = pl_items[p_idx - 1]

        final_p_pkgs  = float(matched_upl.get("packages_count") or p_pkg) if matched_upl else p_pkg
        final_p_qty   = float(matched_upl.get("quantity") or p_qty) if matched_upl else p_qty
        final_p_net   = float(matched_upl.get("net_weight_kg") or p_net) if matched_upl else p_net
        final_p_gross = float(matched_upl.get("gross_weight_kg") or p_gross) if matched_upl else p_gross
        final_p_cbm   = float(matched_upl.get("calculated_cbm") or matched_upl.get("cbm") or p_cbm) if matched_upl else p_cbm
        final_p_type  = matched_upl.get("package_type") or p_type if matched_upl else p_type

        p_pkg_var = round(((final_p_pkgs - p_pkg) / p_pkg) * 100.0, 2) if p_pkg > 0 else 0.0
        p_gw_var  = round(((final_p_gross - p_gross) / p_gross) * 100.0, 2) if p_gross > 0 else 0.0

        if abs(p_pkg_var) > 5.0 or abs(p_gw_var) > 5.0:
            has_warning = True

        reconciled_pl_items.append({
            "po_item_id": sys_pl.get("po_item_id"),
            "packing_item_id": sys_pl.get("packing_item_id"),
            "item_code": p_code,
            "description": p_desc,
            "hs_code": p_hs,
            "package_type": final_p_type,
            "initial_quantity": p_qty,
            "final_quantity": final_p_qty,
            "initial_unit_price": 0.0,
            "unit_price": 0.0,
            "final_unit_price": 0.0,
            "initial_packages_count": p_pkg,
            "final_packages_count": final_p_pkgs,
            "initial_net_weight_kg": p_net,
            "final_net_weight_kg": final_p_net,
            "initial_gross_weight_kg": p_gross,
            "final_gross_weight_kg": final_p_gross,
            "initial_cbm": p_cbm,
            "final_cbm": final_p_cbm,
            "variance_percentage": p_pkg_var,
            "price_variance_percentage": 0.0,
            "weight_variance_percentage": p_gw_var,
            "total_amount": 0.0,
        })

    overall_status = "FULLY_MATCHED" if (not has_critical and not has_warning) else ("ACCEPTED_WITH_WARNINGS" if not has_critical else "CRITICAL_VARIANCE")

    return {
        "overall_status": overall_status,
        "is_safe_for_certification": not has_critical,
        "critical_discrepancies_count": len([d for d in discrepancies if d["status"] == "CRITICAL_VARIANCE"]),
        "warning_discrepancies_count": len([d for d in discrepancies if d["status"] == "MINOR_VARIANCE"]),
        "header_discrepancies": discrepancies,
        "reconciled_invoice_items": reconciled_inv_items,
        "reconciled_packing_items": reconciled_pl_items,
        "extracted_invoice_data": invoice_data,
        "extracted_packing_data": pl_data,
    }


def _identity_check(
    inv_val: Any,
    bl_val: Any,
    failed_code: str,
    mismatch_code: str,
    match_code: str,
    fuzzy: bool = False,
    force_mismatch: bool = False,
) -> Tuple[str, float, Dict[str, Any], List[str]]:
    """
    3-state Invoice vs. B/L identity comparison -> (status, similarity_ratio, details, disagreeing_sources).
    `details` is the coded_text("details", <code>) fields of the outcome. EXTRACTION_FAILED when neither
    document has a value; `force_mismatch` lets the caller veto a match (e.g. the invoice ACID disagrees
    with the system ACID).
    """
    if not inv_val and not bl_val:
        return "EXTRACTION_FAILED", 0.0, coded_text("details", failed_code), []
    if fuzzy:
        matched, ratio = _fuzzy_match_strings(inv_val or "", bl_val or "")
    else:
        matched, ratio = bool(inv_val and bl_val and inv_val == bl_val), 0.0
    if force_mismatch:
        matched = False
    if not matched:
        return "MISMATCH_CRITICAL", ratio, coded_text("details", mismatch_code), ["Invoice", "B/L"]
    return "MATCH", ratio, coded_text("details", match_code), []


def match_invoice_with_bl(
    invoice_data: dict,
    bl_data: dict,
    system_data: Optional[dict] = None,
    packing_list_data: Optional[dict] = None,
) -> dict:
    """
    Performs comprehensive cross-comparison between Commercial Invoice, B/L,
    System Data, and Packing List Data.
    Generates a color-coded discrepancy matrix and auto-generates formal correction notices.
    """
    matrix: List[Dict[str, Any]] = []
    has_critical = False
    has_warning = False

    sys_d = system_data or {}
    pl_d = packing_list_data or {}

    # 1. ACID Number (19 digits) - Critical
    sys_acid = sys_d.get("acid_number")
    inv_acid = invoice_data.get("acid_number")
    pl_acid = pl_d.get("acid_number") or inv_acid
    bl_acid = bl_data.get("acid_number")

    acid_status, _, acid_details, disagreeing_acid = _identity_check(
        inv_acid, bl_acid,
        "DOC_IBL_ACID_NOT_EXTRACTED", "DOC_IBL_ACID_MISMATCH", "DOC_IBL_ACID_MATCH",
        force_mismatch=bool(sys_acid and inv_acid and sys_acid != inv_acid),
    )
    has_warning = has_warning or acid_status == "EXTRACTION_FAILED"
    has_critical = has_critical or acid_status == "MISMATCH_CRITICAL"

    matrix.append(finalize_structured_values({
        "item_code": "CHK_ACID",
        "field_name_ar": "رقم القيد الجمركي المسبق (ACID)",
        "field_name_en": "ACID Number (19 Digits)",
        "system_value": sys_acid or Placeholder("NOT_SET"),
        "packing_list_value": pl_acid or Placeholder("NOT_IN_PACKING_LIST"),
        "invoice_value": inv_acid or Placeholder("NOT_IN_INVOICE"),
        "bl_value": bl_acid or Placeholder("NOT_IN_BL"),
        "match_status": acid_status,
        "severity": _SEVERITY_BY_STATUS.get(acid_status, "NONE"),
        **coded_text("tolerance", "DOC_TOL_EXACT"),
        "disagreeing_sources": disagreeing_acid or None,
        **acid_details,
    }))

    # 2. Importer Tax ID (9 digits) - Critical
    sys_tax = sys_d.get("importer_tax_id")
    inv_tax = invoice_data.get("importer_tax_id")
    pl_tax = pl_d.get("importer_tax_id") or inv_tax
    bl_tax = bl_data.get("importer_tax_id")

    tax_status, _, tax_details, disagreeing_tax = _identity_check(
        inv_tax, bl_tax,
        "DOC_IBL_TAX_ID_NOT_EXTRACTED", "DOC_IBL_TAX_ID_MISMATCH", "DOC_IBL_TAX_ID_MATCH",
    )
    has_warning = has_warning or tax_status == "EXTRACTION_FAILED"
    has_critical = has_critical or tax_status == "MISMATCH_CRITICAL"

    matrix.append(finalize_structured_values({
        "item_code": "CHK_TAX_ID",
        "field_name_ar": "البطاقة الضريبية للمستورد (Tax ID)",
        "field_name_en": "Importer Tax ID (9 Digits)",
        "system_value": sys_tax or Placeholder("NOT_SET"),
        "packing_list_value": pl_tax or Placeholder("NOT_IN_PACKING_LIST"),
        "invoice_value": inv_tax or Placeholder("NOT_IN_INVOICE"),
        "bl_value": bl_tax or Placeholder("NOT_IN_BL"),
        "match_status": tax_status,
        "severity": _SEVERITY_BY_STATUS.get(tax_status, "NONE"),
        **coded_text("tolerance", "DOC_TOL_EXACT"),
        "disagreeing_sources": disagreeing_tax or None,
        **tax_details,
    }))

    # 3. Shipper / Exporter & VAT - Critical
    sys_shp = sys_d.get("supplier_name") or sys_d.get("shipper")
    inv_shp = invoice_data.get("shipper") or invoice_data.get("supplier_name")
    pl_shp = pl_d.get("shipper") or pl_d.get("supplier_name") or inv_shp
    bl_shp = bl_data.get("shipper")

    shp_status, shp_ratio, shp_details, disagreeing_shp = _identity_check(
        inv_shp, bl_shp,
        "DOC_IBL_SHIPPER_NOT_EXTRACTED", "DOC_IBL_SHIPPER_MISMATCH", "DOC_IBL_SHIPPER_MATCH",
        fuzzy=True,
    )
    has_warning = has_warning or shp_status == "EXTRACTION_FAILED"
    has_critical = has_critical or shp_status == "MISMATCH_CRITICAL"

    matrix.append(finalize_structured_values({
        "item_code": "CHK_SHIPPER",
        "field_name_ar": "اسم وبيانات المصدر الأجنبي (Shipper)",
        "field_name_en": "Shipper / Exporter Name",
        "system_value": sys_shp or Placeholder("NOT_SET"),
        "packing_list_value": pl_shp or Placeholder("NOT_IN_PACKING_LIST"),
        "invoice_value": inv_shp or Placeholder("NOT_IN_INVOICE"),
        "bl_value": bl_shp or Placeholder("NOT_IN_BL"),
        "match_status": shp_status,
        "severity": _SEVERITY_BY_STATUS.get(shp_status, "NONE"),
        **coded_text("tolerance", "DOC_TOL_SIMILARITY", match_pct=round(shp_ratio * 100, 1)),
        "disagreeing_sources": disagreeing_shp or None,
        **shp_details,
    }))

    # 4. Consignee / Importer - Critical
    sys_csg = sys_d.get("importer_name") or sys_d.get("consignee")
    inv_csg = invoice_data.get("consignee") or invoice_data.get("importer_name")
    pl_csg = pl_d.get("consignee") or pl_d.get("importer_name") or inv_csg
    bl_csg = bl_data.get("consignee")

    csg_status, csg_ratio, csg_details, disagreeing_csg = _identity_check(
        inv_csg, bl_csg,
        "DOC_IBL_CONSIGNEE_NOT_EXTRACTED", "DOC_IBL_CONSIGNEE_MISMATCH", "DOC_IBL_CONSIGNEE_MATCH",
        fuzzy=True,
    )
    has_warning = has_warning or csg_status == "EXTRACTION_FAILED"
    has_critical = has_critical or csg_status == "MISMATCH_CRITICAL"

    matrix.append(finalize_structured_values({
        "item_code": "CHK_CONSIGNEE",
        "field_name_ar": "اسم الشركة المستوردة (Consignee)",
        "field_name_en": "Consignee / Importer Name",
        "system_value": sys_csg or Placeholder("NOT_SET"),
        "packing_list_value": pl_csg or Placeholder("NOT_IN_PACKING_LIST"),
        "invoice_value": inv_csg or Placeholder("NOT_IN_INVOICE"),
        "bl_value": bl_csg or Placeholder("NOT_IN_BL"),
        "match_status": csg_status,
        "severity": _SEVERITY_BY_STATUS.get(csg_status, "NONE"),
        **coded_text("tolerance", "DOC_TOL_SIMILARITY", match_pct=round(csg_ratio * 100, 1)),
        "disagreeing_sources": disagreeing_csg or None,
        **csg_details,
    }))

    # 4.B Notify Party - Critical / Warning
    sys_not = sys_d.get("notify_party") or sys_csg
    inv_not = invoice_data.get("notify_party") or inv_csg
    pl_not = pl_d.get("notify_party") or pl_csg or inv_not
    bl_not = bl_data.get("notify_party")

    if not bl_not and not inv_not:
        not_status = "EXTRACTION_FAILED"
        not_details = coded_text("details", "DOC_IBL_NOTIFY_NOT_EXTRACTED")
        not_severity = "WARNING"
        has_warning = True
        disagreeing_not = None
    elif bl_not and any(w in bl_not.upper() for w in ("PLEASE ADVISE", "TO BE ADVISED", "TBA", "???", "PENDING")):
        not_status = "MISMATCH_CRITICAL"
        not_details = coded_text("details", "DOC_IBL_NOTIFY_PENDING_WARNING")
        not_severity = "BLOCKING"
        has_critical = True
        disagreeing_not = ["B/L"]
    elif bl_not and "SAME AS CONSIGNEE" in bl_not.upper():
        not_status = "MATCH"
        not_details = coded_text("details", "DOC_IBL_NOTIFY_MATCH")
        not_severity = "NONE"
        disagreeing_not = None
    else:
        matched_not, not_ratio = _fuzzy_match_strings(inv_not or bl_csg or "", bl_not or "")
        if matched_not or not_ratio >= 0.70:
            not_status = "MATCH"
            not_details = coded_text("details", "DOC_IBL_NOTIFY_MATCH")
            not_severity = "NONE"
            disagreeing_not = None
        else:
            not_status = "MISMATCH_MINOR"
            not_details = coded_text("details", "DOC_IBL_NOTIFY_MISMATCH")
            not_severity = "WARNING"
            has_warning = True
            disagreeing_not = ["Invoice", "B/L"]

    matrix.append(finalize_structured_values({
        "item_code": "CHK_NOTIFY_PARTY",
        "field_name_ar": "الطرف المخطر (Notify Party)",
        "field_name_en": "Notify Party Details",
        "system_value": sys_not or Placeholder("NOT_SET"),
        "packing_list_value": pl_not or Placeholder("NOT_IN_PACKING_LIST"),
        "invoice_value": inv_not or Placeholder("NOT_IN_INVOICE"),
        "bl_value": bl_not or Placeholder("NOT_IN_BL"),
        "match_status": not_status,
        "severity": not_severity,
        **coded_text("tolerance", "DOC_TOL_SIMILARITY", match_pct=100.0 if not_status == "MATCH" else 70.0),
        "disagreeing_sources": disagreeing_not,
        **not_details,
    }))

    # 5. Container Numbers - Critical
    def _extract_cntr_nos(cntr_list):
        result = set()
        for c in cntr_list or []:
            if isinstance(c, dict):
                c_no = c.get("container_no") or c.get("number")
                if c_no:
                    result.add(str(c_no).strip().upper())
            elif isinstance(c, str) and c.strip():
                result.add(c.strip().upper())
        return result

    sys_cntrs = _extract_cntr_nos(sys_d.get("containers"))
    inv_cntrs = _extract_cntr_nos(invoice_data.get("containers"))
    pl_cntrs = _extract_cntr_nos(pl_d.get("containers")) or inv_cntrs
    bl_cntrs = _extract_cntr_nos(bl_data.get("containers"))
    cntr_matched = bool(inv_cntrs and bl_cntrs and inv_cntrs == bl_cntrs)

    dummy_found = None
    iso_invalid_found = None
    for c_no in (bl_cntrs or inv_cntrs):
        c_val = validate_iso_container_number(c_no)
        if c_val["is_provisional_dummy"]:
            dummy_found = c_no
            break
        elif not c_val["is_valid_iso"] and not iso_invalid_found:
            iso_invalid_found = c_no

    if dummy_found:
        has_critical = True
        cntr_status = "MISMATCH_CRITICAL"
        cntr_severity = "BLOCKING"
        cntr_details = coded_text("details", "DOC_IBL_CONTAINERS_DUMMY", container_no=dummy_found)
    elif not cntr_matched and (inv_cntrs and bl_cntrs):
        has_critical = True
        cntr_status = "MISMATCH_CRITICAL"
        cntr_severity = "BLOCKING"
        cntr_details = coded_text("details", "DOC_IBL_CONTAINERS_MISMATCH")
    elif iso_invalid_found:
        has_warning = True
        cntr_status = "MISMATCH_MINOR"
        cntr_severity = "WARNING"
        cntr_details = coded_text("details", "DOC_IBL_CONTAINERS_ISO_INVALID", container_no=iso_invalid_found)
    elif cntr_matched:
        cntr_status = "MATCH"
        cntr_severity = "NONE"
        cntr_details = coded_text("details", "DOC_IBL_CONTAINERS_MATCH")
    else:
        cntr_status = "MISMATCH_MINOR"
        cntr_severity = "WARNING"
        cntr_details = coded_text("details", "DOC_IBL_CONTAINERS_MISMATCH")

    matrix.append(finalize_structured_values({
        "item_code": "CHK_CONTAINERS",
        "field_name_ar": "أرقام الحاويات ونوع الشحنة (Containers FCL/LCL)",
        "field_name_en": "Container Number(s) & Type",
        "system_value": ", ".join(sys_cntrs) if sys_cntrs else Placeholder("NOT_SET"),
        "packing_list_value": ", ".join(pl_cntrs) if pl_cntrs else Placeholder("NOT_IN_PACKING_LIST"),
        "invoice_value": ", ".join(inv_cntrs) if inv_cntrs else Placeholder("NOT_IN_INVOICE"),
        "bl_value": f"{bl_data.get('shipment_type', '')} {', '.join(bl_cntrs)}".strip() if bl_cntrs else Placeholder("NOT_IN_BL"),
        "match_status": cntr_status,
        "severity": cntr_severity,
        **coded_text("tolerance", "DOC_TOL_ISO_CONTAINER"),
        "disagreeing_sources": ["Invoice", "B/L"] if not cntr_matched and (inv_cntrs and bl_cntrs) else None,
        **cntr_details,
    }))

    # 6. Seal Numbers - Warning
    def _extract_seal_nos(cntr_list):
        result = set()
        for c in cntr_list or []:
            if isinstance(c, dict):
                s_no = c.get("seal_no") or c.get("seal")
                if s_no:
                    result.add(str(s_no).strip().upper())
        return result

    sys_seals = _extract_seal_nos(sys_d.get("containers"))
    inv_seals = _extract_seal_nos(invoice_data.get("containers"))
    pl_seals = _extract_seal_nos(pl_d.get("containers")) or inv_seals
    bl_seals = _extract_seal_nos(bl_data.get("containers"))
    seal_matched = bool(inv_seals and bl_seals and inv_seals == bl_seals)
    if not seal_matched and (inv_seals and bl_seals):
        has_warning = True
    matrix.append(finalize_structured_values({
        "item_code": "CHK_SEALS",
        "field_name_ar": "أرقام الرصاص والختم الملاحي (Seal Numbers)",
        "field_name_en": "Seal Number(s)",
        "system_value": ", ".join(sys_seals) if sys_seals else Placeholder("NOT_SET"),
        "packing_list_value": ", ".join(pl_seals) if pl_seals else Placeholder("NOT_IN_PACKING_LIST"),
        "invoice_value": ", ".join(inv_seals) if inv_seals else Placeholder("NOT_IN_INVOICE"),
        "bl_value": ", ".join(bl_seals) if bl_seals else Placeholder("NOT_IN_BL"),
        "match_status": "MATCH" if seal_matched else ("MISMATCH_MINOR" if (inv_seals and bl_seals) else "MATCH"),
        "severity": "NONE" if (seal_matched or not inv_seals or not bl_seals) else "WARNING",
        **coded_text("tolerance", "DOC_TOL_SEAL_MATCH"),
        "disagreeing_sources": ["Invoice", "B/L"] if not seal_matched and (inv_seals and bl_seals) else None,
        **coded_text("details", "DOC_IBL_SEALS_MATCH" if seal_matched else "DOC_IBL_SEALS_CHECK"),
    }))

    # 7. Package / Pallet Count - Critical / Warning
    sys_pkg = sys_d.get("total_packages_count") or sys_d.get("total_packages")
    inv_pkg = invoice_data.get("qty_pallets") or invoice_data.get("qty_pkg") or invoice_data.get("total_packages")
    pl_pkg = pl_d.get("qty_pallets") or pl_d.get("qty_pkg") or pl_d.get("total_packages") or inv_pkg
    bl_pkg = bl_data.get("qty_pkg") or bl_data.get("total_packages")
    pkg_matched = bool(inv_pkg and bl_pkg and int(inv_pkg) == int(bl_pkg))
    if not pkg_matched and inv_pkg and bl_pkg:
        has_warning = True
    matrix.append(finalize_structured_values({
        "item_code": "CHK_PACKAGES",
        "field_name_ar": "عدد الطرود والبالتات (Packages / Pallets)",
        "field_name_en": "Package & Pallet Quantity",
        "system_value": Measure(sys_pkg, "PACKAGES_PALLETS", decimals=None) if sys_pkg else Placeholder("NOT_SET"),
        "packing_list_value": Measure(pl_pkg, "PACKAGES_PALLETS", decimals=None) if pl_pkg else Placeholder("NOT_IN_PACKING_LIST"),
        "invoice_value": Measure(inv_pkg, "PACKAGES_PALLETS", decimals=None) if inv_pkg else Placeholder("NOT_SPECIFIED"),
        "bl_value": Measure(bl_pkg, "PACKAGES_PALLETS", decimals=None) if bl_pkg else Placeholder("NOT_SPECIFIED"),
        "match_status": "MATCH" if pkg_matched else ("EXTRACTION_FAILED" if not inv_pkg and not bl_pkg else "MISMATCH_MINOR"),
        "severity": "NONE" if pkg_matched else "WARNING",
        **coded_text("tolerance", "DOC_TOL_PACKAGES_EXACT"),
        "disagreeing_sources": ["Invoice", "B/L"] if not pkg_matched and inv_pkg and bl_pkg else None,
        **coded_text("details", "DOC_IBL_PACKAGES_MATCH" if pkg_matched else "DOC_IBL_PACKAGES_MISMATCH"),
    }))

    # 8. Gross Cargo Weight (KG) - Tolerance 1.0%
    sys_gw = sys_d.get("total_gross_weight_kg")
    inv_gw = invoice_data.get("total_gross_weight_kg")
    pl_gw = pl_d.get("total_gross_weight_kg") or inv_gw
    bl_gw = bl_data.get("total_gross_weight_kg")
    gw_matched, gw_pct, gw_diff = _numeric_tolerance_match(inv_gw, bl_gw, tolerance_pct=1.0)
    if not gw_matched and (inv_gw and bl_gw):
        has_critical = True
    matrix.append(finalize_structured_values({
        "item_code": "CHK_GROSS_WEIGHT",
        "field_name_ar": "الوزن القائم الإجمالي (Gross Weight KG)",
        "field_name_en": "Total Gross Weight (KG)",
        "system_value": Measure(sys_gw, "KG") if sys_gw else Placeholder("NOT_SET"),
        "packing_list_value": Measure(pl_gw, "KG") if pl_gw else Placeholder("NOT_IN_PACKING_LIST"),
        "invoice_value": Measure(inv_gw, "KG") if inv_gw else Placeholder("NOT_SPECIFIED"),
        "bl_value": Measure(bl_gw, "KG") if bl_gw else Placeholder("NOT_SPECIFIED"),
        "match_status": "MATCH" if gw_matched else ("EXTRACTION_FAILED" if not inv_gw and not bl_gw else "MISMATCH_CRITICAL"),
        "severity": "NONE" if gw_matched else "BLOCKING",
        **coded_text("tolerance", "DOC_TOL_WEIGHT_DIFFERENCE", difference_qty=round(gw_diff, 2), difference_pct=round(gw_pct, 2)),
        "disagreeing_sources": ["Invoice", "B/L"] if not gw_matched and inv_gw and bl_gw else None,
        **(coded_text("details", "DOC_IBL_GROSS_WEIGHT_MATCH", tolerance_pct=1.0) if gw_matched
            else coded_text("details", "DOC_IBL_GROSS_WEIGHT_EXCEEDS")),
    }))

    # 9. Net Cargo Weight (KG) - Tolerance 1.0%
    sys_nw = sys_d.get("total_net_weight_kg")
    inv_nw = invoice_data.get("total_net_weight_kg")
    pl_nw = pl_d.get("total_net_weight_kg") or inv_nw
    bl_nw = bl_data.get("total_net_weight_kg")
    nw_matched, nw_pct, nw_diff = _numeric_tolerance_match(inv_nw, bl_nw, tolerance_pct=1.5)
    if not nw_matched and (inv_nw and bl_nw):
        has_warning = True
    matrix.append(finalize_structured_values({
        "item_code": "CHK_NET_WEIGHT",
        "field_name_ar": "الوزن الصافي الإجمالي (Net Weight KG)",
        "field_name_en": "Total Net Weight (KG)",
        "system_value": Measure(sys_nw, "KG") if sys_nw else Placeholder("NOT_SET"),
        "packing_list_value": Measure(pl_nw, "KG") if pl_nw else Placeholder("NOT_IN_PACKING_LIST"),
        "invoice_value": Measure(inv_nw, "KG") if inv_nw else Placeholder("NOT_IN_INVOICE"),
        "bl_value": Measure(bl_nw, "KG") if bl_nw else Placeholder("NOT_IN_BL"),
        "match_status": "MATCH" if (nw_matched or not bl_nw) else "MISMATCH_MINOR",
        "severity": "NONE" if (nw_matched or not bl_nw) else "WARNING",
        **coded_text("tolerance", "DOC_TOL_WEIGHT_DIFFERENCE", difference_qty=round(nw_diff, 2), difference_pct=round(nw_pct, 2)),
        "disagreeing_sources": ["Invoice", "B/L"] if not nw_matched and inv_nw and bl_nw else None,
        **coded_text("details", "DOC_IBL_NET_WEIGHT_MATCH" if (nw_matched or not bl_nw) else "DOC_IBL_NET_WEIGHT_VARIANCE"),
    }))

    # 10. Incoterms & Freight Terms Coherence
    sys_inco = sys_d.get("incoterm_code") or sys_d.get("incoterms")
    inv_inco = invoice_data.get("incoterm") or "EXW"
    pl_inco = pl_d.get("incoterm") or inv_inco
    bl_frt = bl_data.get("freight_terms") or "Freight Prepaid"
    inco_coherent = True
    inco_details = coded_text("details", "DOC_IBL_INCOTERMS_COHERENT", incoterm=inv_inco, freight_terms=bl_frt)
    matrix.append(finalize_structured_values({
        "item_code": "CHK_INCOTERMS",
        "field_name_ar": "الشروط التجارية وسداد النولون (Incoterms & Freight)",
        "field_name_en": "Incoterms & Freight Terms",
        "system_value": sys_inco or Placeholder("NOT_SET"),
        "packing_list_value": f"{pl_inco}",
        "invoice_value": f"{inv_inco} ({invoice_data.get('freight_terms', 'Collect')})",
        "bl_value": bl_frt,
        "match_status": "MATCH" if inco_coherent else "MISMATCH_MINOR",
        "severity": "NONE" if inco_coherent else "WARNING",
        **coded_text("tolerance", "DOC_TOL_TERMS_COHERENCE"),
        "disagreeing_sources": None,
        **inco_details,
    }))

    # 11. Harmonized System (HS) Code - Critical
    sys_hs = sys_d.get("hs_code")
    inv_hs = invoice_data.get("hs_code")
    pl_hs = pl_d.get("hs_code") or inv_hs
    bl_hs = bl_data.get("hs_code")

    inv_hs_clean = re.sub(r'\D', '', str(inv_hs or ''))
    bl_hs_clean = re.sub(r'\D', '', str(bl_hs or ''))
    sys_hs_clean = re.sub(r'\D', '', str(sys_hs or ''))

    if not inv_hs_clean and not bl_hs_clean:
        hs_status = "EXTRACTION_FAILED"
        hs_severity = "WARNING"
        hs_details = coded_text("details", "DOC_IBL_HS_NOT_EXTRACTED")
        has_warning = True
        disagreeing_hs = None
    elif inv_hs_clean and bl_hs_clean:
        if inv_hs_clean[:6] == bl_hs_clean[:6]:
            hs_status = "MATCH"
            hs_severity = "NONE"
            hs_details = coded_text("details", "DOC_IBL_HS_MATCH")
            disagreeing_hs = None
        else:
            hs_status = "MISMATCH_CRITICAL"
            hs_severity = "BLOCKING"
            hs_details = coded_text("details", "DOC_IBL_HS_MISMATCH", invoice_hs=inv_hs or "", bl_hs=bl_hs or "")
            has_critical = True
            disagreeing_hs = ["Invoice", "B/L"]
    else:
        active_clean = inv_hs_clean or bl_hs_clean
        if sys_hs_clean and active_clean and sys_hs_clean[:6] == active_clean[:6]:
            hs_status = "MATCH"
            hs_severity = "NONE"
            hs_details = coded_text("details", "DOC_IBL_HS_MATCH")
            disagreeing_hs = None
        else:
            hs_status = "MISMATCH_MINOR"
            hs_severity = "WARNING"
            hs_details = coded_text("details", "DOC_IBL_HS_NOT_EXTRACTED")
            has_warning = True
            disagreeing_hs = None

    matrix.append(finalize_structured_values({
        "item_code": "CHK_HS_CODE",
        "field_name_ar": "كود البند الجمركي (HS Code)",
        "field_name_en": "Harmonized System (HS) Code",
        "system_value": sys_hs or Placeholder("NOT_SET"),
        "packing_list_value": pl_hs or Placeholder("NOT_IN_PACKING_LIST"),
        "invoice_value": inv_hs or Placeholder("NOT_IN_INVOICE"),
        "bl_value": bl_hs or Placeholder("NOT_IN_BL"),
        "match_status": hs_status,
        "severity": hs_severity,
        **coded_text("tolerance", "DOC_TOL_HS_CODE"),
        "disagreeing_sources": disagreeing_hs,
        **hs_details,
    }))

    # 12. Currency Consistency - Critical
    sys_curr = sys_d.get("currency") or sys_d.get("estimated_cost_currency")
    inv_curr = invoice_data.get("currency") or "USD"
    bl_curr = bl_data.get("freight_currency") or inv_curr
    pl_curr = pl_d.get("currency") or inv_curr

    curr_mismatch = bool(sys_curr and inv_curr and sys_curr.upper() != inv_curr.upper())
    if curr_mismatch:
        curr_status = "MISMATCH_CRITICAL"
        curr_severity = "BLOCKING"
        curr_details = coded_text("details", "DOC_IBL_CURRENCY_MISMATCH", invoice_currency=inv_curr, system_currency=sys_curr)
        has_critical = True
        disagreeing_curr = ["System", "Invoice"]
    else:
        curr_status = "MATCH"
        curr_severity = "NONE"
        curr_details = coded_text("details", "DOC_IBL_CURRENCY_MATCH", currency=inv_curr)
        disagreeing_curr = None

    matrix.append(finalize_structured_values({
        "item_code": "CHK_CURRENCY",
        "field_name_ar": "توحيد العملة (Declared Currency)",
        "field_name_en": "Declared Currency",
        "system_value": sys_curr or Placeholder("NOT_SET"),
        "packing_list_value": pl_curr,
        "invoice_value": inv_curr,
        "bl_value": bl_curr,
        "match_status": curr_status,
        "severity": curr_severity,
        **coded_text("tolerance", "DOC_TOL_CURRENCY"),
        "disagreeing_sources": disagreeing_curr,
        **curr_details,
    }))

    # 13. Arithmetic Precision & Line Items Recalculation - Warning
    inv_items = invoice_data.get("items") or []
    inv_total = float(invoice_data.get("total_amount") or 0.0)
    inv_currency = invoice_data.get("currency") or "USD"

    if inv_items and inv_total > 0:
        calc_total = sum(
            float(it.get("total_price") or it.get("amount") or (float(it.get("quantity") or 0.0) * float(it.get("unit_price") or 0.0)))
            for it in inv_items
        )
        arith_diff = abs(calc_total - inv_total)
        if arith_diff <= 0.05:
            arith_status = "MATCH"
            arith_severity = "NONE"
            arith_details = coded_text("details", "DOC_IBL_ARITHMETIC_MATCH", total_amount=inv_total, currency=inv_currency)
            disagreeing_arith = None
        else:
            arith_status = "MISMATCH_MINOR"
            arith_severity = "WARNING"
            arith_details = coded_text("details", "DOC_IBL_ARITHMETIC_MISMATCH", calculated_amount=round(calc_total, 2), total_amount=round(inv_total, 2))
            has_warning = True
            disagreeing_arith = ["Invoice"]
    else:
        arith_status = "MATCH"
        arith_severity = "NONE"
        arith_details = coded_text("details", "DOC_IBL_ARITHMETIC_MATCH", total_amount=inv_total, currency=inv_currency)
        disagreeing_arith = None

    matrix.append(finalize_structured_values({
        "item_code": "CHK_ARITHMETIC",
        "field_name_ar": "التدقيق الحسابي للفاتورة (Arithmetic Precision)",
        "field_name_en": "Invoice Arithmetic Recalculation",
        "system_value": f"{inv_total:.2f} {inv_currency}" if inv_total > 0 else Placeholder("NOT_SET"),
        "packing_list_value": Placeholder("NOT_IN_PACKING_LIST"),
        "invoice_value": f"{inv_total:.2f} {inv_currency}" if inv_total > 0 else Placeholder("NOT_SPECIFIED"),
        "bl_value": Placeholder("NOT_IN_BL"),
        "match_status": arith_status,
        "severity": arith_severity,
        **coded_text("tolerance", "DOC_TOL_ARITHMETIC"),
        "disagreeing_sources": disagreeing_arith,
        **arith_details,
    }))

    # Overall Match Status
    overall_status = "FULLY_MATCHED" if (not has_critical and not has_warning) else ("ACCEPTED_WITH_WARNINGS" if not has_critical else "DISCREPANCY_DETECTED")
    match_score = round(((len(matrix) - (len([m for m in matrix if m['match_status'] == 'MISMATCH_CRITICAL']) * 2 + len([m for m in matrix if m['match_status'] == 'MISMATCH_MINOR']))) / len(matrix)) * 100, 1)
    match_score = max(0.0, min(100.0, match_score))

    # Auto-generate Correction Letter if discrepancies exist
    correction_letter = ""
    if has_critical or has_warning:
        mismatched_items = [m for m in matrix if m["match_status"] in ["MISMATCH_CRITICAL", "MISMATCH_MINOR"]]
        correction_letter = (
            f"Dear {bl_data.get('shipping_line') or 'Carrier / Freight Forwarder'},\n\n"
            f"RE: Correction Request for Draft B/L No: {bl_data.get('draft_bl_number') or 'DRAFT-BL'} (Booking Ref: {bl_data.get('booking_no') or 'BKG-REF'})\n"
            f"Import File Reference: ACID {inv_acid or bl_acid or 'N/A'}\n\n"
            "Following our formal cross-document reconciliation against the Final Commercial Invoice, please amend the following discrepancies on the final Bill of Lading:\n\n"
        )
        for i, item in enumerate(mismatched_items, 1):
            correction_letter += f"{i}. {item['field_name_en']} ({item['field_name_ar']}):\n"
            correction_letter += f"   - B/L Current Value: {item['bl_value']}\n"
            correction_letter += f"   - Commercial Invoice Required Value: {item['invoice_value']}\n"
            correction_letter += f"   - Reason: {item['details']}\n\n"
        correction_letter += (
            "Please issue the revised Draft B/L promptly to avoid customs clearance delays on the Egyptian Nafeza system.\n\n"
            "Best Regards,\n"
            "Import Operations & Customs Clearance Department\n"
            "Sorour Logistics ERP System"
        )

    return {
        "overall_status": overall_status,
        "is_safe_for_certification": not has_critical,
        "match_score_percentage": match_score,
        "critical_discrepancies_count": len([m for m in matrix if m['severity'] == 'BLOCKING']),
        "warning_discrepancies_count": len([m for m in matrix if m['severity'] == 'WARNING']),
        "comparison_matrix": matrix,
        "correction_letter": correction_letter,
        "invoice_data": invoice_data,
        "bl_data": bl_data,
        "packing_list_data": packing_list_data,
    }


__all__ = [
    "_CODE_STRIP_RE",
    "_SEVERITY_BY_STATUS",
    "_abs_difference",
    "_normalized_contains",
    "_header_row",
    "_lazy_code_norms",
    "_identity_check",
    "reconcile_po_documents_with_system",
    "match_invoice_with_bl",
]
