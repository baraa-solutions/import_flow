"""
Draft Bill of Lading (B/L) 5-stage review engine & approval service (Phase 3 - BP-017).
"""

import logging
import re
from datetime import date, datetime, timezone, timedelta
from typing import Any, Dict, List, Optional, Set, Tuple
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

logger = logging.getLogger(__name__)

from modules.freight_booking.model import ShipmentBooking
from modules.import_companies.model import ImportCompany
from modules.cargo_shipping.model import CargoShippingRecord
from modules.suppliers.model import Supplier
from modules.import_documentation.model import POPackingReconciliationSession, DraftBLReviewSession, ShipmentDocumentItem, BankingDocumentSession, AcidRegistrationSession, CertificateOfOriginReviewSession, InspectionCertificateReviewSession, InvoiceBLMatchSession


from modules.import_documentation.model import DraftBLReviewSession, POPackingReconciliationSession
from modules.freight_booking.model import ShipmentBooking
from modules.import_companies.model import ImportCompany
from modules.import_files.model import ImportFile
from modules.purchase_orders.model import PurchaseOrder, POLineItem, PackingListItem
from modules.import_documentation.schemas import *
from modules.import_documentation.validators import validate_status
import modules.import_documentation.repository as repo
from modules.common.system_messages import coded_text, msg, render_en
from modules.common.enum_codes import Placeholder, finalize_structured_values
from modules.common.file_tracking import set_file_tracking
from modules.common.errors import best_effort
from modules.common.validators import not_found, require_active
from modules.import_files.repository import codes_by_ids

from modules.import_documentation.ai_document_parser import (
    extract_draft_bl_with_ai,
    _heuristic_multi_carrier_extractor as extract_draft_bl_data,
)
from modules.import_documentation.document_upload_ocr_service import (
    extract_text_and_boxes_from_uploaded_file,
    parse_draft_bl_raw_text,
)
from modules.import_documentation.doc_common import (
    SYSTEM_ACTOR,
    LABEL_IMPORT_FILE,
    LABEL_PURCHASE_ORDER,
    LABEL_DRAFT_BL_REVIEW,
    DRAFT_BL_TERMINAL_STATUSES,
    DRAFT_BL_APPROVAL_ROLES,
    DRAFT_BL_APPROVAL_ACTIONS,
    _DRAFT_BL_SERVER_OWNED,
    _actor,
    _bad_request,
    _conflict,
    _active_import_file,
    _get_active_import_file,
    _require_active_po,
    _commit_follow_up,
    _lifecycle_follow_up,
    _fuzzy_match,
    _numeric_match,
)

def _party_block(name: Optional[str], address: Optional[str], phone: Optional[str]) -> Optional[str]:
    """Shipper / consignee block from the known parts only: a missing part is left out, never invented (DOC-03)."""
    parts = [name] if name else []
    if address:
        parts.append(f"Address: {address}")
    if phone:
        parts.append(f"Phone: {phone}")
    return "\n".join(parts).strip() or None


def _build_system_bl_snapshot(db: Session, import_file_id: int) -> dict:
    """System side of the draft B/L comparison. A value the system does not have is ``None`` (DOC-03): the
    comparison then takes the draft value instead of flagging a placeholder as a mismatch."""
    imp_file = _get_active_import_file(db, import_file_id)
    booking = db.query(ShipmentBooking).filter(ShipmentBooking.import_file_id == import_file_id, ShipmentBooking.is_active == True).first()
    cargo_shp = db.query(CargoShippingRecord).filter(CargoShippingRecord.import_file_id == import_file_id, CargoShippingRecord.is_active == True).first()
    company = db.query(ImportCompany).filter(ImportCompany.company_id == imp_file.company_id).first() if imp_file and imp_file.company_id else None
    supplier = db.query(Supplier).filter(Supplier.supplier_id == imp_file.supplier_id).first() if imp_file and imp_file.supplier_id else None
    pos = db.query(PurchaseOrder).filter(PurchaseOrder.import_file_id == import_file_id, PurchaseOrder.is_active == True).all()

    # Containers from Phase 5 Cargo Shipping
    containers = []
    cargo_gw = 0.0
    cargo_nw = 0.0
    hs_codes = set()
    goods_desc = []
    container_str_parts = []

    if cargo_shp and cargo_shp.containers_loading_data:
        for c in cargo_shp.containers_loading_data:
            c_dict = dict(c)
            c_no = c_dict.get("container_no", "")
            s_no = c_dict.get("seal_no", "")
            c_sz = c_dict.get("container_type", "40HC")
            containers.append({
                "container_no": c_no,
                "seal_no": s_no,
                "container_type": c_sz,
                "gross_weight_kg": float(c_dict.get("gross_weight_kg") or 0.0),
                "net_weight_kg": float(c_dict.get("net_weight_kg") or 0.0),
                "vgm_status": c_dict.get("vgm_status", "Submitted"),
            })
            cargo_gw += float(c_dict.get("gross_weight_kg") or 0.0)
            cargo_nw += float(c_dict.get("net_weight_kg") or 0.0)
            if c_no:
                container_str_parts.append(f"{c_no} / Seal: {s_no} ({c_sz})")

    has_any_pl = any(bool(po.packing_list_items) for po in pos)

    pl_total_cbm = 0.0
    pl_total_gw = 0.0
    pl_total_nw = 0.0
    pl_total_pkgs = 0
    pl_total_pcs = 0

    inv_total_cbm = 0.0
    inv_total_gw = 0.0
    inv_total_nw = 0.0
    inv_total_pkgs = 0
    inv_total_pcs = 0

    for po in pos:
        # 1. Line items
        if po.line_items:
            for itm in po.line_items:
                desc = itm.description_en or itm.description_ar or itm.item_code
                if desc and desc not in goods_desc:
                    goods_desc.append(desc)
                qty = float(itm.quantity or 0.0)
                inv_total_pcs += int(qty)
                inv_total_pkgs += int(qty)
                inv_total_cbm += float(itm.total_cbm or 0.0)
                inv_total_gw += float(itm.gross_weight_kg or 0.0)
                inv_total_nw += float(itm.net_weight_kg or 0.0)
                if itm.tariff and itm.tariff.hs_code:
                    hs_codes.add(itm.tariff.hs_code)

        # 2. Packing list items
        if po.packing_list_items:
            for pl in po.packing_list_items:
                p_code = pl.item_code or pl.hs_code
                if p_code and p_code not in goods_desc:
                    goods_desc.append(p_code)
                q_pkg = float(pl.qty_pkg or 0.0)
                q_pcs = float(pl.qty_pcs or 0.0)
                pl_total_pkgs += int(q_pkg)
                pl_total_pcs += int(q_pcs)

                # CBM
                cbm_val = float(pl.total_cbm or 0.0)
                if cbm_val <= 0:
                    l_m = float(pl.length_cm or 0.0) / 100.0
                    w_m = float(pl.width_cm or 0.0) / 100.0
                    h_m = float(pl.height_cm or 0.0) / 100.0
                    cbm_val = round(q_pkg * (l_m * w_m * h_m), 4) if (l_m > 0 and w_m > 0 and h_m > 0) else 0.0
                pl_total_cbm += cbm_val

                # Gross Weight
                gw_val = float(pl.total_gross_weight_kg or 0.0)
                if gw_val <= 0 and float(pl.gross_weight_unit_kg or 0.0) > 0:
                    gw_val = round(q_pkg * float(pl.gross_weight_unit_kg), 2)
                pl_total_gw += gw_val

                # Net Weight
                nw_val = float(pl.total_net_weight_kg or 0.0)
                if nw_val <= 0 and float(pl.net_weight_unit_kg or 0.0) > 0:
                    nw_val = round(q_pkg * float(pl.net_weight_unit_kg), 2)
                pl_total_nw += nw_val

                if pl.hs_code:
                    hs_codes.add(pl.hs_code)

    # Determine final totals with priority to detailed Packing List
    if has_any_pl and (pl_total_pkgs > 0 or pl_total_gw > 0 or pl_total_cbm > 0):
        total_cbm = pl_total_cbm
        total_gw = pl_total_gw
        total_nw = pl_total_nw
        total_pkgs = pl_total_pkgs
        total_pcs = pl_total_pcs if pl_total_pcs > 0 else inv_total_pcs
    else:
        total_cbm = inv_total_cbm
        total_gw = cargo_gw if cargo_gw > 0 else inv_total_gw
        total_nw = cargo_nw if cargo_nw > 0 else inv_total_nw
        total_pkgs = inv_total_pkgs
        total_pcs = inv_total_pcs

    shipper_name = supplier.company_name if supplier else (imp_file.supplier_name if imp_file else None)
    shipper_addr = supplier.address if (supplier and supplier.address) else None
    shipper_phone = getattr(supplier, 'phone', None) or getattr(supplier, 'contact_phone', None)
    shipper_full = _party_block(shipper_name, shipper_addr, shipper_phone)

    consignee_name = company.importer_name if company else (imp_file.company_name if imp_file else None)
    consignee_addr = company.address if (company and company.address) else None
    consignee_phone = getattr(company, 'phone', None)
    consignee_full = _party_block(consignee_name, consignee_addr, consignee_phone)

    notify_party_full = consignee_full
    vessel = booking.vessel_name if (booking and booking.vessel_name) else None
    voyage = getattr(booking, 'voyage_number', None) or getattr(booking, 'voyage_no', None)
    pol = booking.pol_name if (booking and booking.pol_name) else None
    pod = booking.pod_name if (booking and booking.pod_name) else None
    freight_terms = getattr(booking, 'freight_terms', None) or None
    place_of_deliv = getattr(booking, 'place_of_delivery', None) or pod
    # CargoShippingRecord has no booking number / shipping line columns: fall back through its booking relation.
    cargo_booking = cargo_shp.booking if cargo_shp is not None else None
    bkg_no = (booking.booking_confirmation_no if booking else None) or (cargo_booking.booking_confirmation_no if cargo_booking else None) or None
    acid_no = imp_file.acid_number if (imp_file and imp_file.acid_number) else None
    tax_id = (company.vat_id or None) if company else None
    shipper_reg = getattr(supplier, 'registration_id', None) or getattr(supplier, 'tax_id', None)
    shp_mode = booking.shipment_type if (booking and booking.shipment_type) else None
    container_summary_str = "; ".join(container_str_parts) if container_str_parts else None

    return {
        "forwarder_name": booking.freight_forwarder_name if (booking and booking.freight_forwarder_name) else None,
        "shipping_line": (booking.shipping_line_name if booking else None) or (cargo_booking.shipping_line_name if cargo_booking else None) or None,
        "vessel_name": vessel,
        "voyage_number": voyage,
        "pol": pol,
        "pod": pod,
        "freight_terms": freight_terms,
        "place_of_delivery": place_of_deliv,
        "booking_no": bkg_no,
        "acid_number": acid_no,
        "importer_tax_id": tax_id,
        "shipper_reg_id": shipper_reg,
        "shipping_mode": shp_mode,
        "container_summary": container_summary_str,
        "hbl_no": None,
        "mbl_no": None,
        "shipper": shipper_full,
        "consignee": consignee_full,
        "notify_party": notify_party_full,
        "hs_codes": list(hs_codes),
        "goods_description": ", ".join(goods_desc) if goods_desc else None,
        # Unknown measurements are None, not 0 (review #15): the comparison then takes the draft value.
        "qty_pcs": total_pcs or None,
        "qty_pkg": total_pkgs or None,
        "total_net_weight_kg": round(total_nw, 2) if total_nw else None,
        "total_gross_weight_kg": round(total_gw, 2) if total_gw else None,
        "cbm": round(total_cbm, 4) if total_cbm else None,
        "containers": containers,
        "container_count": len(containers),
    }






def _drop_stale_reason_code(item_dict: Dict[str, Any]) -> Dict[str, Any]:
    """A checklist reason edited by the user no longer matches its system message: keep the text, drop the code."""
    code = item_dict.get("reason_code")
    if code and item_dict.get("reason") != render_en(code, item_dict.get("reason_params"), "note"):
        item_dict["reason_code"] = None
        item_dict["reason_params"] = None
    return item_dict


_LETTER_COMPARE = {
    "intro": "upon verification of the Draft Bill of Lading received for Booking No: {booking}, the following discrepancies were identified and require immediate amendment prior to final B/L issuance:",
    "item": "{idx}. Item: {item}\n",
    "reason": "   - Reason / Details: {reason}\n\n",
    "closing": "Please provide the revised Draft B/L with the requested corrections at your earliest convenience.\n\nBest Regards,\nImport Operations Department",
}
_LETTER_CHECKLIST = {
    "intro": "upon review of the Draft Bill of Lading received for Booking No: {booking}, the following corrections are required:",
    "item": "{idx}. {item}:\n",
    "reason": "   - Reason: {reason}\n\n",
    "closing": "Please reissue the draft B/L with these corrections at your earliest convenience.\n\nBest Regards,\nImport Operations Department",
}


def _letter_value(value: Any) -> Any:
    return "N/A" if value is None or str(value).strip() == "" else value


def _build_bl_correction_letter(sys_data: Dict[str, Any], revision_report: List[Dict[str, Any]], variant: Dict[str, str]) -> str:
    """The carrier correction request for a draft B/L (one builder for compare and checklist review, DOC-23).
    Empty report -> "". A value the system does not know prints as N/A, never as a placeholder."""
    if not revision_report:
        return ""
    booking = _letter_value(sys_data.get("booking_no"))
    acid = _letter_value(sys_data.get("acid_number"))
    letter = (
        f"Subject: Urgent: Draft B/L Correction Request - Booking Ref: {booking} / ACID: {acid}\n\n"
        "Dear Shipping Line / Forwarder Operations Team,\n\n"
        f"Please be advised that {variant['intro'].format(booking=booking)}\n\n"
    )
    for idx, itm in enumerate(revision_report, 1):
        letter += variant["item"].format(idx=idx, item=itm["item"])
        letter += f"   - Required Action: {itm['required_action']}\n"
        letter += f"   - Responsible Party: {itm['responsible']}\n"
        letter += variant["reason"].format(reason=itm["reason"])
    return letter + variant["closing"]


def compare_draft_bl_service(db: Session, request: DraftBLComparisonRequest) -> dict:
    from modules.import_documentation import service as _facade
    build_snapshot = getattr(_facade, '_build_system_bl_snapshot', _build_system_bl_snapshot)
    sys_data = build_snapshot(db, request.import_file_id)
    draft_fields = dict(request.draft_fields or {})

    raw_input = getattr(request, "raw_draft_text", None) or getattr(request, "raw_text", None)
    if raw_input:
        extracted = parse_draft_bl_raw_text(raw_input)
        for k, v in extracted.items():
            if k not in draft_fields or not draft_fields[k]:
                draft_fields[k] = v

    if "container_summary" not in draft_fields and "containers" in draft_fields:
        c_parts = []
        for c in draft_fields["containers"]:
            c_no = c.get("container_no", "")
            s_no = c.get("seal_no", "")
            if c_no:
                c_parts.append(f"{c_no} / Seal: {s_no}" if s_no else c_no)
        if c_parts:
            draft_fields["container_summary"] = "; ".join(c_parts)

    # Field Mappings & Rules
    fields_spec = [
        ("shipper", "المصدر / الشاحن (Shipper)", "Shipper Name, Address & Phone", "Supplier Master Data", False, "fuzzy", "Supplier"),
        ("consignee", "المستورد / المرسل إليه (Consignee)", "Consignee Name, Address & Phone", "Importer Company Master Data", True, "fuzzy", "Importer"),
        ("notify_party", "جهة الإخطار (Notify Party)", "Notify Party Name, Address & Phone", "Importer / Contract", False, "fuzzy", "Importer"),
        ("vessel_name", "اسم الباخرة (Vessel)", "Vessel Name", "Final Booking", False, "text", "Shipping Provider"),
        ("voyage_number", "رقم الرحلة (Voyage)", "Voyage Number", "Final Booking", False, "text", "Shipping Provider"),
        ("pol", "ميناء الشحن (POL)", "Port of Loading (POL)", "Final Booking", False, "text", "Shipping Provider"),
        ("pod", "ميناء التفريغ (POD)", "Port of Discharge (POD)", "Final Booking", False, "text", "Shipping Provider"),
        ("freight_terms", "شروط النولون (Freight Terms)", "Freight Terms (Prepaid/Collect)", "Final Booking", False, "text", "Shipping Provider"),
        ("place_of_delivery", "مكان التسليم (Place of Delivery)", "Place of Delivery", "Final Booking", False, "text", "Shipping Provider"),
        ("booking_no", "رقم الحجز (Booking Number)", "Booking Number", "Final Booking", True, "text", "Shipping Provider"),
        ("acid_number", "رقم القيد الجمركي المبدئي (ACID)", "ACID Number", "Import File & Nafeza", True, "text", "Importer"),
        ("importer_tax_id", "البطاقة الضريبية للمستورد (Importer Tax ID)", "Egyptian Importer Tax ID", "Importer Company", True, "text", "Importer"),
        ("shipper_reg_id", "رقم تسجيل المصدر (Shipper Reg ID)", "Shipper Registration/ID", "Supplier", False, "text", "Supplier"),
        ("shipping_mode", "نمط الشحن (Shipping Mode)", "Shipping Mode (FCL/LCL/Air)", "Final Booking", False, "text", "Shipping Provider"),
        ("container_summary", "بيان الحاويات والسيل (Container Summary)", "Container No + Seal No + Size", "Container Allocation", True, "fuzzy", "Shipping Provider"),
        ("goods_description", "بيان التعبئة والوصف (Packing Summary)", "Packing Summary & Goods Description", "Final Approved Packing List", False, "fuzzy", "Supplier"),
        ("total_gross_weight_kg", "الوزن القائم (Gross Weight)", "Gross Weight (KG)", "Final Approved Packing List", False, "numeric_05", "Shipping Provider"),
        ("total_net_weight_kg", "الوزن الصافي (Net Weight)", "Net Weight (KG)", "Final Approved Packing List", False, "numeric_05", "Supplier"),
        ("cbm", "الحجم الإجمالي (Measurement CBM)", "Measurement (CBM)", "Final Approved Packing List", False, "numeric_05", "Shipping Provider"),
        ("qty_pkg", "عدد الطرود (Number of Packages)", "Number of Packages", "Final Approved Packing List", False, "numeric_strict", "Supplier"),
    ]

    matrix = []
    checklist = []
    blocking_reasons = []
    blocking_reasons_coded = []

    def _block(code: str, field_key: str) -> None:
        # English text (legacy column) + coded twin for Flutter: [{code, params}] in the same order.
        params = {"field_enum_draft_bl_field": field_key.upper()}
        blocking_reasons.append(render_en(code, params, "reason"))
        blocking_reasons_coded.append({"code": code, "params": params})

    for key, label_ar, label_en, source, is_critical, match_type, resp_default in fields_spec:
        sys_val = sys_data.get(key)
        draft_val = draft_fields.get(key)

        if draft_val is None or str(draft_val).strip() == "":
            match_status = "MISSING_IN_DRAFT"
            is_explicitly_empty = key in draft_fields and draft_fields[key] == ""
            severity = "BLOCKING" if (is_critical and is_explicitly_empty) else "WARNING"
            details_fields = coded_text("details", "DOC_DRAFT_FIELD_MISSING")
            if is_critical and is_explicitly_empty:
                _block("DOC_DRAFT_BLOCKING_FIELD_EMPTY", key)
            tolerance_pct = 0.0
        elif sys_val is None or str(sys_val).strip() == "":
            match_status = "MATCH"
            severity = "NONE"
            details_fields = coded_text("details", "DOC_DRAFT_VALUE_FROM_DRAFT", draft_value=draft_val)
            tolerance_pct = 0.0
        elif match_type == "fuzzy":
            matched, ratio = _fuzzy_match(sys_val, draft_val, threshold=0.85)
            tolerance_pct = round((1.0 - ratio) * 100.0, 1)
            if matched:
                match_status = "MATCH"
                severity = "NONE"
                details_fields = coded_text("details", "DOC_DRAFT_FUZZY_MATCH", match_pct=round(ratio * 100, 1))
            else:
                match_status = "MISMATCH_CRITICAL" if is_critical else "MISMATCH_MINOR"
                severity = "BLOCKING" if is_critical else "WARNING"
                details_fields = coded_text(
                    "details", "DOC_DRAFT_VALUE_MISMATCH", system_value=sys_val, draft_value=draft_val
                )
                if is_critical:
                    _block("DOC_DRAFT_BLOCKING_CRITICAL_MISMATCH", key)
        elif match_type == "numeric_05":
            try:
                s_num = float(sys_val)
                d_num = float(draft_val)
                diff = abs(s_num - d_num)
                pct = (diff / s_num * 100.0) if s_num > 0 else 0.0
                tolerance_pct = round(pct, 2)
                if pct <= 0.5:
                    match_status = "MATCH"
                    severity = "NONE"
                    details_fields = coded_text(
                        "details", "DOC_DRAFT_NUMERIC_MATCH", diff_pct=tolerance_pct, tolerance_pct=0.5
                    )
                else:
                    match_status = "MISMATCH_MINOR"
                    severity = "WARNING"
                    details_fields = coded_text(
                        "details", "DOC_DRAFT_NUMERIC_VARIANCE", diff_pct=tolerance_pct, system_qty=s_num, draft_qty=d_num
                    )
            except Exception:
                match_status = "MISMATCH_MINOR"
                severity = "WARNING"
                details_fields = coded_text("details", "DOC_DRAFT_NUMERIC_UNVERIFIABLE", draft_value=draft_val)
        else: # text
            s_clean = str(sys_val).strip().upper()
            d_clean = str(draft_val).strip().upper()
            if s_clean == d_clean:
                match_status = "MATCH"
                severity = "NONE"
                details_fields = coded_text("details", "DOC_DRAFT_TEXT_MATCH")
            else:
                match_status = "MISMATCH_CRITICAL" if is_critical else "MISMATCH_MINOR"
                severity = "BLOCKING" if is_critical else "WARNING"
                details_fields = coded_text(
                    "details", "DOC_DRAFT_APPROVED_VALUE_MISMATCH", system_value=sys_val, draft_value=draft_val
                )
                if is_critical:
                    _block("DOC_DRAFT_BLOCKING_CRITICAL_MISMATCH", key)

        matrix.append({
            "field_key": key,
            "field_label_ar": label_ar,
            "field_label_en": label_en,
            "source_entity": source,
            "system_value": sys_val,
            "draft_value": draft_val,
            "match_status": match_status,
            "severity": severity,
            "tolerance_pct": tolerance_pct,
            **details_fields,
        })

        is_match = (match_status == "MATCH")
        checklist.append({
            "field_key": key,
            "field_label_ar": label_ar,
            "field_label_en": label_en,
            "source_entity": source,
            "system_value": sys_val,
            "draft_value": draft_val,
            "status": "Correct" if is_match else ("Missing" if (draft_val is None or str(draft_val).strip() == "") else "Incorrect"),
            "required_correction": f"Enter {label_en} (expected: {sys_val})" if (draft_val is None or str(draft_val).strip() == "") else f"Correct {label_en} to: {sys_val}",
            "reason": details_fields["details"] if not is_match else None,
            "reason_code": details_fields["details_code"] if not is_match else None,
            "reason_params": details_fields["details_params"] if not is_match else None,
            "notes": None,
            "responsible_party": resp_default,
            "is_locked": False,
            "previous_status": None,
        })

    has_blocking = len(blocking_reasons) > 0
    open_discrepancies = [c for c in checklist if c["status"] == "Incorrect"]

    # Generate Revision Report Items
    revision_report = []
    for itm in open_discrepancies:
        revision_report.append({
            "item": itm["field_label_en"],
            "required_action": itm["required_correction"] or f"Update {itm['field_label_en']} to match system value ({itm['system_value']})",
            "responsible": itm["responsible_party"] or "Shipping Provider",
            "reason": itm["reason"] or "Value mismatch with master reference",
            "notes": itm["notes"],
        })

    # Auto-generate Correction Letter
    correction_letter = _build_bl_correction_letter(sys_data, revision_report, _LETTER_COMPARE)


    stage_calc = "Stage 2: Revision Required" if open_discrepancies else "Stage 4: Dual Approval"
    status_calc = "REVISION_REQUIRED" if open_discrepancies else "REVIEWED_PENDING_APPROVAL"

    return {
        "import_file_id": request.import_file_id,
        "draft_source": request.draft_source,
        "stage": stage_calc,
        "system_snapshot_data": sys_data,
        "draft_input_data": draft_fields,
        "comparison_matrix": matrix,
        "checklist_data": checklist,
        "revision_report_data": revision_report,
        "has_blocking_mismatch": has_blocking,
        "open_discrepancies_count": len(open_discrepancies),
        "blocking_reasons": blocking_reasons,
        "blocking_reasons_coded": blocking_reasons_coded,
        "correction_request_letter": correction_letter,
        "status": status_calc,
    }


def _complete_draft_bl_review_workflow(
    db: Session, session: DraftBLReviewSession, approved_by: Optional[str] = None
) -> None:
    """
    Handles end-to-end operational sync upon final approval / certification of Draft B/L (SH-02):
    1. Updates ImportFile (bl_number, booking_no, vessel_name, stage progression to CargoX, progress >= 65%).
    2. Updates CargoShippingRecord & CustomsDocumentApproval.
    3. Advances Lifecycle Board to STEP_08_COO & STEP_09_CARGOX.
    4. Auto-completes pending SH-02 SmartTasks.
    5. Dispatches downstream SH-03 SmartTask (CargoX Digital Transfer & Sealing).
    6. Emits SystemNotification.

    Runs after the approval commit: every step is a best-effort follow-up that commits its own work, in this
    order (DOC-11). One failing step no longer blocks the next ones.
    """
    file_id = session.import_file_id
    bl_number = session.draft_bl_number
    booking_no = session.booking_no
    vessel_name = session.vessel_name
    approver = approved_by or session.approved_by or "Compliance Officer"
    imp_file = _get_active_import_file(db, file_id)
    file_code = imp_file.import_file_code if imp_file else f"FILE-{file_id}"
    has_real_bl_number = bool(bl_number and bl_number != "DRAFT-BL")

    def _sync_import_file() -> None:
        imp = _get_active_import_file(db, file_id)
        if not imp:
            return
        if hasattr(imp, "bl_number") and has_real_bl_number:
            imp.bl_number = bl_number
        if hasattr(imp, "booking_no") and booking_no:
            imp.booking_no = booking_no
        if hasattr(imp, "vessel_name") and vessel_name:
            imp.vessel_name = vessel_name
        imp.current_module = "STEP_09 CargoX Digital Transfer (SH-03)"
        set_file_tracking(imp, next_action=msg("NA_STEP09_CARGOX_ENVELOPE"))
        if (imp.progress_percent or 0.0) < 65.0:
            imp.progress_percent = 65.0

    _commit_follow_up(db, _sync_import_file, "Draft B/L import file sync")

    # CargoShippingRecord has no B/L number / vessel columns (the old sync wrote nothing): the import file above
    # carries them. A cargo-side B/L column needs a schema change (deferred).

    def _sync_customs_approval() -> None:
        from modules.docs_customs_approval.model import CustomsDocumentApproval
        bl_app = db.query(CustomsDocumentApproval).filter(
            CustomsDocumentApproval.import_file_id == file_id,
            CustomsDocumentApproval.document_type == "Bill of Lading",
            CustomsDocumentApproval.is_active == True,
        ).first()
        if bl_app:
            bl_app.document_reference_no = bl_number or bl_app.document_reference_no
            bl_app.commercial_status = "Approved"
            bl_app.commercial_reviewed_by = approver
            bl_app.commercial_reviewed_at = datetime.now(timezone.utc)
            bl_app.commercial_notes = f"Draft B/L {bl_number} approved (SH-02 / STEP_08_BL)."
            if bl_app.customs_status == "Approved":
                bl_app.overall_status = "Approved for Clearance"
            else:
                bl_app.overall_status = "Under Review"

    _commit_follow_up(db, _sync_customs_approval, "Draft B/L CustomsDocumentApproval sync")

    _lifecycle_follow_up(
        db, "Lifecycle advance STEP_08_BL->STEP_08_COO",
        import_file_id=file_id,
        completed_step_code="STEP_08_BL",
        target_step_codes=["STEP_08_COO"],
        notes_msg=msg("DOC_DRAFT_BL_REVIEWED", draft_bl_number=bl_number),
        assigned_user=approver,
    )

    def _close_prior_tasks() -> None:
        from modules.smart_tasks.model import SmartTask
        prior_tasks = db.query(SmartTask).filter(
            SmartTask.import_file_id == file_id,
            SmartTask.status != "Completed",
            SmartTask.is_active == True,
        ).all()
        for pt in prior_tasks:
            notes_str = pt.notes or ""
            title_str = pt.title or ""
            if "SH-02" in notes_str or "SH-02" in title_str or pt.reminder_type == "Draft B/L Dual Review" or "DRAFT_BL" in notes_str:
                pt.status = "Completed"
                pt.is_auto_closed = True
                pt.completion_date = date.today()

    _commit_follow_up(db, _close_prior_tasks, "Auto-close prior SH-02 smart tasks")

    def _dispatch_sh03() -> None:
        from modules.smart_tasks.model import SmartTask
        from modules.smart_tasks.service import create_task_service
        from modules.smart_tasks.schemas import SmartTaskCreate
        existing_sh03 = db.query(SmartTask).filter(
            SmartTask.import_file_id == file_id,
            SmartTask.status != "Completed",
            SmartTask.is_active == True,
        ).all()
        if any("SH-03" in (t.notes or "") or "SH-03" in (t.title or "") for t in existing_sh03):
            return
        cargox_task_msg = msg("DOC_TASK_CARGOX_TRANSFER", import_file_code=file_code, draft_bl_number=bl_number)
        task_schema = SmartTaskCreate(
            title=render_en(cargox_task_msg.code, cargox_task_msg.params, "title"),
            description=render_en(cargox_task_msg.code, cargox_task_msg.params, "body"),
            task_type="System Generated",
            import_file_id=file_id,
            import_file_code=file_code,
            phase_name="Phase 3: Booking & Doc Prep",
            assigned_user="Logistics Officer",
            priority="High",
            reminder_type="CargoX Digital Transfer",
            due_date=str(date.today() + timedelta(days=3)),
            status="Pending",
            notes=f"ACTION:CARGOX_SEAL | File: {file_code} | BL: {bl_number}",
        )
        create_task_service(
            db, task_schema, user_name="Draft B/L Dual Review Engine",
            msg_code=cargox_task_msg.code, msg_params=cargox_task_msg.params, commit=False,
        )

    _commit_follow_up(db, _dispatch_sh03, "Dispatch SH-03 smart task")

    def _notify() -> None:
        from modules.notifications.model import SystemNotification
        bl_msg = msg("DOC_DRAFT_BL_REVIEWED", import_file_code=file_code, draft_bl_number=bl_number)
        db.add(SystemNotification(
            title=render_en(bl_msg.code, bl_msg.params, "title"),
            message=render_en(bl_msg.code, bl_msg.params, "body"),
            msg_code=bl_msg.code,
            msg_params=bl_msg.params,
            severity="INFO",
            category="STAGE_PROGRESSION",
            entity_type="ImportFile",
            entity_id=file_id,
            target_role="ALL",
            is_read=False,
        ))

    _commit_follow_up(db, _notify, "Draft B/L review notification")


def _audit_draft_bl(db: Session, saved: DraftBLReviewSession, action: str, new_data: Dict[str, Any], actor: str) -> None:
    from modules.audit_logs.service import AuditLogService
    best_effort(
        db, AuditLogService(db).log_activity, "AuditLog for DraftBLReviewSession",
        entity_type="DraftBLReviewSession",
        entity_id=saved.bl_review_id,
        entity_code=saved.bl_review_code,
        action=action,
        new_data=new_data,
        performed_by=actor,
    )


def _reset_server_owned_draft_bl_fields(schema: DraftBLReviewCreate) -> None:
    """DOC-04 / C2: status, stage, approvals and reviewer identity sent by the client are ignored on create."""
    schema.status = "AUTO_COMPARISON_RUN"
    schema.stage = "Stage 1: Draft Review"
    schema.importer_approval_status = "Pending"
    schema.broker_approval_status = "Pending"
    for field in ("importer_approved_by", "importer_approval_date", "importer_approval_notes",
                  "broker_approved_by", "broker_approval_date", "broker_approval_notes",
                  "approved_by", "approved_at", "reviewed_by", "reviewed_at"):
        setattr(schema, field, None)
    schema.has_blocking_mismatch = False
    schema.open_discrepancies_count = 0
    schema.revision_report_data = None


# Critical fields of the draft B/L comparison (is_critical in compare_draft_bl_service's field list).
_DRAFT_BL_CRITICAL_FIELDS = frozenset({"consignee", "booking_no", "acid_number", "importer_tax_id", "container_summary"})
_DRAFT_BL_APPROVAL_RESET = {
    "importer_approval_status": "Pending", "importer_approved_by": None, "importer_approval_date": None,
    "importer_approval_notes": None, "broker_approval_status": "Pending", "broker_approved_by": None,
    "broker_approval_date": None, "broker_approval_notes": None,
}


def _checklist_has_blocking(checklist: List[Any]) -> bool:
    return any(
        isinstance(c, dict) and c.get("status") in ("Incorrect", "Missing") and c.get("field_key") in _DRAFT_BL_CRITICAL_FIELDS
        for c in checklist or []
    )


def _require_pending_approval(review: DraftBLReviewSession) -> None:
    """Approval acts only on a certified review waiting for approval, with no blocking mismatch."""
    if review.is_draft or review.status != "REVIEWED_PENDING_APPROVAL" or review.has_blocking_mismatch:
        raise _bad_request(
            f"لا يمكن اعتماد مراجعة مسودة البوليصة ({review.bl_review_code}) إلا وهي معتمدة كمراجعة نهائية "
            f"وفي انتظار الاعتماد وبدون أخطاء حرجة (الحالة الحالية: {review.status})."
        )


def _draft_bl_stage_and_status(is_draft: bool, open_count: int, has_blocking: bool) -> Tuple[str, str]:
    """Server-computed stage/status of a saved review: never beyond REVIEWED_PENDING_APPROVAL (Q4: approval only
    through dual approval or /approve)."""
    if is_draft:
        return "Stage 1: Draft Review", "DRAFT"
    if open_count > 0 or has_blocking:
        return "Stage 2: Revision Required", "REVISION_REQUIRED"
    return "Stage 4: Dual Approval", "REVIEWED_PENDING_APPROVAL"


def create_draft_bl_review_service(
    db: Session, schema: DraftBLReviewCreate, user: Optional[str] = None
) -> DraftBLReviewSession:
    _active_import_file(db, schema.import_file_id)
    _require_active_po(db, schema.po_id)
    actor = _actor(user, schema.approved_by)
    _reset_server_owned_draft_bl_fields(schema)
    is_draft = bool(getattr(schema, "is_draft", False))

    if schema.checklist_data:
        # Convert any Pydantic models to dicts
        raw_checklist = []
        revision_report = []
        open_count = 0
        for item in schema.checklist_data:
            item_dict = item.model_dump() if hasattr(item, "model_dump") else (item.dict() if hasattr(item, "dict") else item)
            if isinstance(item_dict, dict):
                _drop_stale_reason_code(item_dict)
            status_val = item_dict.get("status", "Correct")
            if status_val == "Incorrect":
                if not is_draft and not (item_dict.get("required_correction") and item_dict.get("reason")):
                    raise HTTPException(
                        status_code=400,
                        detail=f"الحقول 'Required Correction' و 'Reason' إلزامية للبند غير المطابق: {item_dict.get('field_label_ar') or item_dict.get('field_key')}",
                    )
                open_count += 1
                revision_report.append({
                    # DOC-19: the stored revision report carries the English label.
                    "item": item_dict.get("field_label_en") or item_dict.get("field_label_ar", ""),
                    "required_action": item_dict.get("required_correction", ""),
                    "responsible": item_dict.get("responsible_party") or "Shipping Provider",
                    "reason": item_dict.get("reason", ""),
                    "notes": item_dict.get("notes"),
                })
            raw_checklist.append(item_dict)
        schema.checklist_data = raw_checklist
        schema.revision_report_data = revision_report
        schema.open_discrepancies_count = open_count
        # Server-computed: an open item on a critical B/L field blocks approval (client flag ignored).
        schema.has_blocking_mismatch = _checklist_has_blocking(raw_checklist)
    elif not is_draft or not schema.comparison_matrix:
        comp_req = DraftBLComparisonRequest(
            import_file_id=schema.import_file_id,
            draft_source=schema.draft_source,
            draft_fields=schema.draft_input_data,
        )
        comp_res = compare_draft_bl_service(db, comp_req)
        schema.system_snapshot_data = comp_res["system_snapshot_data"]
        schema.comparison_matrix = comp_res["comparison_matrix"]
        schema.checklist_data = comp_res["checklist_data"]
        schema.revision_report_data = comp_res["revision_report_data"]
        schema.has_blocking_mismatch = comp_res["has_blocking_mismatch"]
        schema.open_discrepancies_count = comp_res["open_discrepancies_count"]
        schema.blocking_reasons = comp_res["blocking_reasons"]
        schema.blocking_reasons_coded = comp_res["blocking_reasons_coded"]
        schema.correction_request_letter = comp_res["correction_request_letter"]

    schema.stage, schema.status = _draft_bl_stage_and_status(
        is_draft, schema.open_discrepancies_count or 0, bool(schema.has_blocking_mismatch)
    )
    if not is_draft:
        schema.reviewed_by = actor
        schema.reviewed_at = datetime.now(timezone.utc)

    existing_draft = repo.get_draft_bl_review_by_file_id(db, schema.import_file_id, include_inactive=False, include_drafts=True)
    is_update = False

    if is_draft:
        if existing_draft and existing_draft.is_draft:
            update_schema = _drop_stale_blocking_codes(DraftBLReviewUpdate(**schema.model_dump(exclude_unset=True)))
            saved_session = repo.update_draft_bl_review(db, existing_draft.bl_review_id, update_schema, user=actor)
            is_update = True
        else:
            saved_session = repo.create_draft_bl_review(db, schema, user=actor)
    else:
        existing_certified = repo.get_draft_bl_review_by_file_id(db, schema.import_file_id, include_inactive=False, include_drafts=False)
        if existing_certified:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"يوجد بالفعل مراجعة معتمدة لمسودة البوليصة لهذا الملف (رمز المراجعة: {existing_certified.bl_review_code}). "
                    f"يرجى استعراض المراجعة الحالية أو إنشاء إصدار جديد (Version) بدلاً من إنشاء جلسة مكررة."
                ),
            )
        saved_session = repo.create_draft_bl_review(db, schema, user=actor)

    _audit_draft_bl(db, saved_session, "UPDATE" if is_update else "CREATE", schema.model_dump(mode="json", exclude_unset=True), actor)
    # No approval side effects here any more: a saved review waits for dual approval (DOC-04 a, Q4).
    return saved_session


def _drop_stale_blocking_codes(schema: DraftBLReviewUpdate) -> DraftBLReviewUpdate:
    """A client that replaces blocking_reasons without sending blocking_reasons_coded invalidates the codes."""
    if "blocking_reasons" in schema.model_fields_set and "blocking_reasons_coded" not in schema.model_fields_set:
        schema.blocking_reasons_coded = None
    return schema


def _get_active_draft_bl_review(db: Session, review_id: int) -> DraftBLReviewSession:
    review = repo.get_draft_bl_review_by_id(db, review_id)
    if not review:
        raise not_found(LABEL_DRAFT_BL_REVIEW, review_id)
    return review


def _reject_terminal_draft_bl(review: DraftBLReviewSession) -> None:
    if review.status in DRAFT_BL_TERMINAL_STATUSES:
        raise _conflict(
            f"مراجعة مسودة البوليصة ({review.bl_review_code}) معتمدة نهائياً ولا يمكن تعديلها أو اعتمادها مرة أخرى. "
            f"أنشئ إصداراً جديداً (Version) عند الحاجة."
        )


def get_draft_bl_review_service(db: Session, review_id: int) -> DraftBLReviewSession:
    """Single review (soft-deleted rows included, as the screen opens history) or 404."""
    review = repo.get_draft_bl_review_by_id(db, review_id, include_inactive=True)
    if not review:
        raise not_found(LABEL_DRAFT_BL_REVIEW, review_id)
    return review


def update_draft_bl_review_service(
    db: Session, review_id: int, schema: DraftBLReviewUpdate, user: Optional[str] = None
) -> DraftBLReviewSession:
    review = _get_active_draft_bl_review(db, review_id)
    _reject_terminal_draft_bl(review)
    actor = _actor(user, getattr(schema, "approved_by", None))

    # DOC-04 b: status, stage and approval fields are server-owned.
    data = schema.model_dump(exclude_unset=True)
    for field in _DRAFT_BL_SERVER_OWNED:
        data.pop(field, None)
    clean = DraftBLReviewUpdate(**data)

    review_inputs = {"checklist_data", "open_discrepancies_count", "has_blocking_mismatch", "is_draft", "revision_report_data"}
    if (review_inputs & clean.model_fields_set) or (review_inputs & schema.model_fields_set):
        is_draft = bool(clean.is_draft if "is_draft" in clean.model_fields_set else review.is_draft)
        merged_checklist = clean.checklist_data if "checklist_data" in clean.model_fields_set and clean.checklist_data is not None else review.checklist_data
        open_count = sum(1 for c in (merged_checklist or []) if isinstance(c, dict) and c.get("status") in ("Incorrect", "Missing"))
        has_blocking = _checklist_has_blocking(merged_checklist or [])
        clean.open_discrepancies_count = open_count
        clean.has_blocking_mismatch = has_blocking
        if "checklist_data" in clean.model_fields_set and clean.checklist_data is not None:
            clean.revision_report_data = [
                {
                    "item": c.get("field_label_en") or c.get("field_label_ar", ""),
                    "required_action": c.get("required_correction", ""),
                    "responsible": c.get("responsible_party") or "Shipping Provider",
                    "reason": c.get("reason", ""),
                    "notes": c.get("notes"),
                }
                for c in (clean.checklist_data or [])
                if isinstance(c, dict) and c.get("status") == "Incorrect"
            ]
        clean.stage, clean.status = _draft_bl_stage_and_status(is_draft, open_count, has_blocking)
    if clean.model_fields_set:
        # Content changed: earlier approvals no longer cover it.
        for field, value in _DRAFT_BL_APPROVAL_RESET.items():
            setattr(clean, field, value)
    clean.reviewed_by = actor
    clean.reviewed_at = datetime.now(timezone.utc)

    updated = repo.update_draft_bl_review(db, review_id, _drop_stale_blocking_codes(clean), user=actor)
    _audit_draft_bl(db, updated, "UPDATE", schema.model_dump(mode="json", exclude_unset=True), actor)
    return updated


def update_draft_bl_checklist_service(
    db: Session, review_id: int, checklist_items: List[DraftBLChecklistItem], reviewer_name: Optional[str] = None,
    user: Optional[str] = None,
) -> DraftBLReviewSession:
    review = _get_active_draft_bl_review(db, review_id)
    _reject_terminal_draft_bl(review)

    updated_checklist = []
    revision_report = []
    open_count = 0

    for item in checklist_items:
        item_dict = _drop_stale_reason_code(item.model_dump())
        if item.status == "Incorrect":
            if not item.required_correction or not item.reason:
                raise HTTPException(
                    status_code=400,
                    detail=f"الحقول 'Required Correction' و 'Reason' إلزامية للبند غير المطابق: {item.field_label_ar}"
                )
            open_count += 1
            revision_report.append({
                "item": item.field_label_en,
                "required_action": item.required_correction,
                "responsible": item.responsible_party or "Shipping Provider",
                "reason": item.reason,
                "notes": item.notes,
            })
        updated_checklist.append(item_dict)

    review.checklist_data = updated_checklist
    for field, value in _DRAFT_BL_APPROVAL_RESET.items():
        setattr(review, field, value)
    review.has_blocking_mismatch = _checklist_has_blocking(updated_checklist)
    review.revision_report_data = revision_report
    review.open_discrepancies_count = open_count
    actor = _actor(user, reviewer_name)
    review.reviewed_by = actor
    review.updated_by = actor
    review.reviewed_at = datetime.now(timezone.utc)

    # Re-generate correction letter
    if revision_report:
        review.correction_request_letter = _build_bl_correction_letter(review.system_snapshot_data or {}, revision_report, _LETTER_CHECKLIST)
        review.stage = "Stage 2: Revision Required"
        review.status = "REVISION_REQUIRED"
    else:
        review.stage = "Stage 4: Dual Approval"
        review.status = "REVIEWED_PENDING_APPROVAL"

    db.commit()
    db.refresh(review)
    return review


def process_dual_approval_service(
    db: Session, request: DualApprovalRequest, user: Optional[str] = None
) -> DraftBLReviewSession:
    if request.role not in DRAFT_BL_APPROVAL_ROLES:
        raise HTTPException(status_code=400, detail="Invalid approval role. Must be 'importer' or 'customs_broker'.")
    if request.action not in DRAFT_BL_APPROVAL_ACTIONS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="إجراء الاعتماد غير صالح: القيم المسموحة Approved أو Rejected.",
        )

    review = _get_active_draft_bl_review(db, request.bl_review_id)
    _reject_terminal_draft_bl(review)
    _require_pending_approval(review)

    if review.open_discrepancies_count > 0:
        raise HTTPException(
            status_code=400,
            detail="لا يمكن اعتماد درافت البوليصة طالما توجد بنود غير مطابقة (Open Discrepancies) لم يتم إغلاقها."
        )

    approver = _actor(user, request.approved_by)
    review.updated_by = approver
    now = datetime.now(timezone.utc)
    approving = request.action == "Approved"

    # DOC-04 d: one person cannot hold both approval roles.
    if approving:
        other_status, other_by = (
            (review.broker_approval_status, review.broker_approved_by)
            if request.role == "importer"
            else (review.importer_approval_status, review.importer_approved_by)
        )
        if other_status == "Approved" and (other_by or "").strip().lower() == approver.lower():
            raise _conflict("لا يمكن لنفس المستخدم اعتماد مسودة البوليصة بصفتي المستورد والمخلص الجمركي معاً.")

    if request.role == "importer":
        if approving:
            review.importer_approval_status = "Approved"
            review.importer_approved_by = approver
            review.importer_approval_date = now
            review.importer_approval_notes = request.notes
        else:
            review.importer_approval_status = "Rejected"
            review.importer_approval_notes = request.notes
            review.stage = "Stage 2: Revision Required"
            review.status = "REVISION_REQUIRED"
    else:
        if approving:
            review.broker_approval_status = "Approved"
            review.broker_approved_by = approver
            review.broker_approval_date = now
            review.broker_approval_notes = request.notes
        else:
            review.broker_approval_status = "Rejected"
            review.broker_approval_notes = request.notes
            review.stage = "Stage 2: Revision Required"
            review.status = "REVISION_REQUIRED"

    # If BOTH approved -> Stage 5 Final
    became_final = review.importer_approval_status == "Approved" and review.broker_approval_status == "Approved"
    if became_final:
        review.stage = "Stage 5: Final"
        review.status = "FINAL"
        review.approved_by = f"{review.importer_approved_by} & {review.broker_approved_by}"
        review.approved_at = now

    db.commit()
    db.refresh(review)
    if became_final:
        _complete_draft_bl_review_workflow(db, review, approved_by=review.approved_by)
        db.refresh(review)
    return review


def _draft_bl_version_chain(db: Session, parent: DraftBLReviewSession) -> Tuple[str, List[DraftBLReviewSession]]:
    """(root code, every review of the version chain). Versions are coded ``<root>-v<n>``."""
    root_code = re.sub(r"-v\d+$", "", parent.bl_review_code or "")
    chain = db.query(DraftBLReviewSession).filter(
        (DraftBLReviewSession.bl_review_code == root_code)
        | (DraftBLReviewSession.bl_review_code.like(f"{root_code}-v%"))
    ).all()
    return root_code, chain


def create_new_draft_version_service(
    db: Session, request: NewDraftVersionRequest, user: Optional[str] = None
) -> DraftBLReviewSession:
    parent = repo.get_draft_bl_review_by_id(db, request.parent_session_id, include_inactive=True)
    if not parent:
        raise not_found(LABEL_DRAFT_BL_REVIEW, request.parent_session_id)
    _active_import_file(db, parent.import_file_id)

    # DOC-05: branch only from the latest active version; the version number keeps rising across the chain.
    root_code, chain = _draft_bl_version_chain(db, parent)
    active_versions = [s for s in chain if s.is_active]
    latest_active = max(active_versions, key=lambda s: (s.version_number or 1, s.bl_review_id)) if active_versions else parent
    if latest_active.bl_review_id != parent.bl_review_id:
        raise _conflict(
            f"لا يمكن إنشاء إصدار جديد إلا من أحدث إصدار نشط لمسودة البوليصة ({latest_active.bl_review_code})."
        )
    new_version_num = max((s.version_number or 1) for s in chain) + 1 if chain else (parent.version_number or 1) + 1

    # Run new comparison
    comp_req = DraftBLComparisonRequest(
        import_file_id=parent.import_file_id,
        draft_source=request.draft_source,
        raw_draft_text=request.raw_draft_text,
        draft_fields=request.draft_fields,
    )
    comp_res = compare_draft_bl_service(db, comp_req)

    # Carry forward locks for previously approved items whose draft value didn't change
    parent_checklist_map = {c["field_key"]: c for c in (parent.checklist_data or [])}
    new_checklist = []

    for itm in comp_res["checklist_data"]:
        f_key = itm["field_key"]
        prev_itm = parent_checklist_map.get(f_key)
        if prev_itm and prev_itm.get("status") == "Correct" and str(prev_itm.get("draft_value")) == str(itm.get("draft_value")):
            itm["status"] = "Correct"
            itm["is_locked"] = True
            itm["previous_status"] = "Correct"
        else:
            itm["is_locked"] = False
            itm["previous_status"] = prev_itm.get("status") if prev_itm else None
        new_checklist.append(itm)

    open_count = len([c for c in new_checklist if isinstance(c, dict) and c.get("status") in ("Incorrect", "Missing")])
    has_blocking = _checklist_has_blocking(new_checklist)
    stage_val, status_val = _draft_bl_stage_and_status(False, open_count, has_blocking)
    new_session = DraftBLReviewSession(
        bl_review_code=f"{root_code}-v{new_version_num}",
        import_file_id=parent.import_file_id,
        po_id=parent.po_id,
        booking_id=parent.booking_id,
        # DOC-05 a: the B/L number stays the carrier's number; version_number carries the version.
        draft_bl_number=parent.draft_bl_number,
        shipping_line=parent.shipping_line,
        vessel_name=parent.vessel_name,
        voyage_number=parent.voyage_number,
        booking_no=parent.booking_no,
        hbl_no=parent.hbl_no,
        mbl_no=parent.mbl_no,
        freight_terms=parent.freight_terms,
        place_of_delivery=parent.place_of_delivery,
        importer_tax_id=parent.importer_tax_id,
        shipper_reg_id=parent.shipper_reg_id,
        measurement_cbm=parent.measurement_cbm,
        net_weight_kg=parent.net_weight_kg,
        packages_count=parent.packages_count,
        container_summary=parent.container_summary,
        draft_source=request.draft_source,
        version_number=new_version_num,
        parent_session_id=parent.bl_review_id,
        stage=stage_val,
        system_snapshot_data=comp_res["system_snapshot_data"],
        draft_input_data=request.draft_fields,
        comparison_matrix=comp_res["comparison_matrix"],
        checklist_data=new_checklist,
        revision_report_data=comp_res["revision_report_data"],
        has_blocking_mismatch=has_blocking,
        open_discrepancies_count=open_count,
        blocking_reasons=comp_res["blocking_reasons"],
        blocking_reasons_coded=comp_res["blocking_reasons_coded"],
        correction_request_letter=comp_res["correction_request_letter"],
        status=status_val,
        reviewed_by=_actor(user),
        reviewed_at=datetime.now(timezone.utc),
        created_by=_actor(user),
        updated_by=_actor(user),
    )
    if parent.status not in DRAFT_BL_TERMINAL_STATUSES:
        parent.is_active = False
        parent.updated_by = _actor(user)
    db.add(new_session)
    db.commit()
    db.refresh(new_session)
    return new_session


def approve_draft_bl_service(
    db: Session, review_id: int, approved_by: Optional[str] = None, user: Optional[str] = None
) -> DraftBLReviewSession:
    """Completes a half-approved review for ``import_documentation.approve`` holders: fills the ONE missing role
    (importer or customs broker) with the caller, who must differ from the user who approved the other role.
    Nothing approved yet -> 409 (use dual approval)."""
    review = _get_active_draft_bl_review(db, review_id)
    _reject_terminal_draft_bl(review)
    _require_pending_approval(review)
    if review.open_discrepancies_count > 0 or review.has_blocking_mismatch:
        raise HTTPException(
            status_code=400,
            detail=f"لا يمكن اعتماد درافت البوليصة لوجود بنود غير مطابقة أو أخطاء حرجة (Blocking Discrepancies)."
        )
    approver = _actor(user, approved_by)
    review.updated_by = approver
    importer_done = review.importer_approval_status == "Approved"
    broker_done = review.broker_approval_status == "Approved"
    if importer_done == broker_done:
        raise _conflict(
            "الاعتماد المباشر يكمل دوراً واحداً ناقصاً فقط: يرجى استخدام الاعتماد المزدوج "
            "(المستورد ثم المخلص الجمركي) لهذه المراجعة."
        )
    other_by = review.importer_approved_by if importer_done else review.broker_approved_by
    if (other_by or "").strip().lower() == approver.lower():
        raise _conflict("لا يمكن لنفس المستخدم اعتماد مسودة البوليصة بصفتي المستورد والمخلص الجمركي معاً.")

    now = datetime.now(timezone.utc)
    if importer_done:
        review.broker_approval_status = "Approved"
        review.broker_approved_by = approver
        review.broker_approval_date = now
    else:
        review.importer_approval_status = "Approved"
        review.importer_approved_by = approver
        review.importer_approval_date = now
    review.stage = "Stage 5: Final"
    review.status = "FINAL"
    review.approved_by = f"{review.importer_approved_by} & {review.broker_approved_by}"
    review.approved_at = now
    db.commit()
    db.refresh(review)
    _complete_draft_bl_review_workflow(db, review, approved_by=review.approved_by)
    db.refresh(review)
    return review



def get_draft_bl_reviews_service(
    db: Session,
    include_inactive: bool = False,
    import_file_id: int = None,
    status: str = None,
    search: str = None,
    is_draft: bool = None,
    skip: int = 0,
    limit: int | None = None,
    return_total: bool = False,
):
    return repo.get_draft_bl_reviews(
        db,
        include_inactive=include_inactive,
        import_file_id=import_file_id,
        status=status,
        search=search,
        is_draft=is_draft,
        skip=skip,
        limit=limit,
        return_total=return_total,
    )

def get_draft_bl_review_by_id_service(db: Session, review_id: int, include_inactive: bool = True):
    return repo.get_draft_bl_review_by_id(db, review_id, include_inactive=include_inactive)

def delete_draft_bl_review_service(db: Session, review_id: int, user: Optional[str] = None) -> dict:
    review = repo.get_draft_bl_review_by_id(db, review_id, include_inactive=True)
    if not review:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"جلسة مراجعة مسودة البوليصة رقم {review_id} غير موجودة للحذف.",
        )
    _reject_terminal_draft_bl(review)  # an approved (FINAL) review is a record of the approval: never deleted
    repo.delete_draft_bl_review(db, review_id)
    # The table has no updated_by / deleted_by column (DOC-26, deferred): the deleting user goes to the audit log.
    _audit_draft_bl(db, review, "DELETE", {"is_active": False}, _actor(user))
    db.commit()
    return {"message": f"تم حذف جلسة مراجعة مسودة البوليصة رقم {review_id} بنجاح", "deleted": True}



def extract_draft_bl_file_service(db: Session, filename: str, content: bytes, import_file_id: Optional[int]) -> dict:
    raw_text, spatial_boxes = extract_text_and_boxes_from_uploaded_file(filename, content)
    extracted_fields = parse_draft_bl_raw_text(raw_text, spatial_boxes=spatial_boxes)
    comp_result = None
    if import_file_id:
        comp_result = compare_draft_bl_service(db, DraftBLComparisonRequest(
            import_file_id=import_file_id,
            draft_source="FILE_UPLOAD",
            raw_draft_text=raw_text,
            draft_fields=extracted_fields,
        ))
    guardrails = extracted_fields.get("_guardrails", {})
    return {
        "filename": filename,
        "raw_text": raw_text,
        "extracted_fields": extracted_fields,
        "extraction_status": guardrails.get("extraction_status", "EXTRACTION_COMPLETE"),
        "missing_critical_fields": guardrails.get("missing_critical_fields", []),
        "safety_warning": guardrails.get("safety_warning"),
        "comparison_result": comp_result,
    }

