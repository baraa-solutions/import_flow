"""
PO Packing Reconciliation Service & PO final adjustments persistence (Phase 3 - BP-019).
"""

import logging
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


from modules.import_documentation.model import POPackingReconciliationSession
from modules.import_files.model import ImportFile
from modules.purchase_orders.model import PurchaseOrder, POLineItem, PackingListItem
from modules.import_documentation.schemas import *
from modules.import_documentation.validators import (
    validate_unique_po_lines,
    validate_status,
)
import modules.import_documentation.repository as repo
from modules.common.system_messages import coded_text, msg, render_en
from modules.common.enum_codes import Placeholder, finalize_structured_values
from modules.common.file_tracking import set_file_tracking
from modules.common.errors import best_effort
from modules.common.validators import not_found, require_active
from modules.import_files.repository import codes_by_ids

from modules.import_documentation.ai_document_parser import (
    extract_commercial_invoice_data,
    extract_packing_list_data,
)
from modules.import_documentation.document_upload_ocr_service import extract_text_from_uploaded_file
from modules.import_documentation.doc_common import (
    SYSTEM_ACTOR,
    LABEL_IMPORT_FILE,
    LABEL_PURCHASE_ORDER,
    LABEL_PO_RECON_SESSION,
    PO_FINAL_STATUSES,
    _actor,
    _bad_request,
    _conflict,
    _active_import_file,
    _get_active_import_file,
    _require_active_po,
    _validate_currency_code,
    _commit_follow_up,
    _lifecycle_follow_up,
    get_import_files_map,
    _normalize_str,
    _fuzzy_match,
    _numeric_match,
)

def _open_pos_of_file(db: Session, import_file_id: int) -> Dict[int, PurchaseOrder]:
    """Active POs of the import file that are not CLOSED / CANCELLED (legacy labels normalized)."""
    from modules.common import enum_codes
    pos = db.query(PurchaseOrder).filter(
        PurchaseOrder.import_file_id == import_file_id,
        PurchaseOrder.is_active == True,
    ).all()
    return {
        po.po_id: po for po in pos
        if enum_codes.normalize(enum_codes.PO_STATUS, po.status) not in PO_FINAL_STATUSES
    }


def _load_owned_po_rows(
    db: Session, import_file_id: int, po_item_ids: List[int], packing_item_ids: List[int]
) -> Tuple[Dict[int, POLineItem], Dict[int, PackingListItem], Dict[int, PurchaseOrder]]:
    """PO line and packing rows by id, each owned by an active, open PO of the import file (DOC-02 b).
    Any foreign / unknown id -> 400 with an Arabic detail. (D1 may later move this check to
    ``validators.validate_po_lines_belong``.)"""
    open_pos = _open_pos_of_file(db, import_file_id)
    lines: Dict[int, POLineItem] = {}
    packs: Dict[int, PackingListItem] = {}
    if po_item_ids:
        rows = db.query(POLineItem).filter(POLineItem.item_id.in_(set(po_item_ids))).all()
        lines = {r.item_id: r for r in rows if r.po_id in open_pos}
        foreign = sorted({i for i in po_item_ids if i not in lines})
        if foreign:
            raise _bad_request(
                f"بنود أمر الشراء التالية لا تتبع أمر شراء نشطاً ومفتوحاً لملف الاستيراد رقم {import_file_id}: "
                f"{', '.join(str(i) for i in foreign)}"
            )
    if packing_item_ids:
        rows = db.query(PackingListItem).filter(PackingListItem.packing_item_id.in_(set(packing_item_ids))).all()
        packs = {r.packing_item_id: r for r in rows if r.po_id in open_pos}
        foreign = sorted({i for i in packing_item_ids if i not in packs})
        if foreign:
            raise _bad_request(
                f"بنود قائمة التعبئة التالية لا تتبع أمر شراء نشطاً ومفتوحاً لملف الاستيراد رقم {import_file_id}: "
                f"{', '.join(str(i) for i in foreign)}"
            )
    return lines, packs, open_pos


_PO_ADJUSTMENT_NUMBER_FIELDS = (
    "final_quantity", "final_unit_price", "unit_price", "final_packages_count",
    "final_net_weight_kg", "final_gross_weight_kg", "final_cbm",
)


# --- 1. FINAL INVOICE & PACKING LIST PO RECONCILIATION ---
def reconcile_po_final_adjustments_service(
    db: Session, request: POFinalAdjustmentRequest, user: Optional[str] = None
) -> dict:
    imp_file = _active_import_file(db, request.import_file_id, status_code=status.HTTP_404_NOT_FOUND)
    actor = _actor(user)

    for itm in request.items:
        negative = [f for f in _PO_ADJUSTMENT_NUMBER_FIELDS if (getattr(itm, f, 0.0) or 0.0) < 0]
        if negative:
            raise _bad_request(f"لا يمكن أن تكون القيم سالبة للبند '{itm.item_code}': {', '.join(negative)}")

    # BE03-T01: Split into line items and packing items
    line_items = [i for i in request.items if not i.packing_item_id]
    packing_items = [i for i in request.items if i.packing_item_id]

    # Reject duplicate po_item_id in line items (400)
    validate_unique_po_lines(line_items)

    po_item_ids = [itm.po_item_id for itm in line_items if itm.po_item_id]
    packing_item_ids = [itm.packing_item_id for itm in packing_items if itm.packing_item_id]
    lines, packs, open_pos = _load_owned_po_rows(db, request.import_file_id, po_item_ids, packing_item_ids)

    updated_items = []
    touched_po_ids: Set[int] = set()
    line_po_ids: Set[int] = set()
    packing_po_ids: Set[int] = set()
    total_final_amount = 0.0
    total_final_amount_by_currency: Dict[str, float] = {}

    for itm in request.items:
        final_price = itm.final_unit_price if itm.final_unit_price > 0 else itm.unit_price
        itm.unit_price = final_price
        itm.final_unit_price = final_price

        if itm.packing_item_id:
            # DOC-02 a / BE03-T01: packing row is updated only through its own id, never PO line id
            db_pl_item = packs.get(itm.packing_item_id)
            if db_pl_item is not None:
                if itm.final_packages_count > 0:
                    db_pl_item.qty_pkg = itm.final_packages_count
                if itm.final_net_weight_kg > 0:
                    db_pl_item.total_net_weight_kg = itm.final_net_weight_kg
                if itm.final_gross_weight_kg > 0:
                    db_pl_item.total_gross_weight_kg = itm.final_gross_weight_kg
                if itm.final_cbm > 0:
                    db_pl_item.total_cbm = itm.final_cbm
                if itm.package_type:
                    db_pl_item.package_type = itm.package_type
                touched_po_ids.add(db_pl_item.po_id)
                packing_po_ids.add(db_pl_item.po_id)
        else:
            # BE03-T01: PO line writes only from items without packing_item_id
            db_po_item = lines.get(itm.po_item_id) if itm.po_item_id else None
            # A zero final value means "unchanged": the stored line value is kept and counted (review #9).
            line_price = final_price if final_price > 0 else (float(db_po_item.unit_price or 0.0) if db_po_item is not None else 0.0)
            line_total = round(itm.final_quantity * line_price, 2) if line_price > 0 else 0.0
            if db_po_item is not None:
                db_po_item.quantity = itm.final_quantity
                if line_price > 0:
                    db_po_item.unit_price = line_price
                    db_po_item.total_price = line_total
                if itm.final_net_weight_kg > 0:
                    db_po_item.net_weight_kg = itm.final_net_weight_kg
                if itm.final_gross_weight_kg > 0:
                    db_po_item.gross_weight_kg = itm.final_gross_weight_kg
                if itm.final_cbm > 0:
                    db_po_item.total_cbm = itm.final_cbm
                touched_po_ids.add(db_po_item.po_id)
                line_po_ids.add(db_po_item.po_id)

                po = open_pos.get(db_po_item.po_id)
                curr_code = getattr(getattr(po, "currency", None), "currency_code", None) or getattr(itm, "currency", None) or getattr(imp_file, "estimated_cost_currency", None) or "UNKNOWN"
                total_final_amount_by_currency[curr_code] = round(
                    total_final_amount_by_currency.get(curr_code, 0.0) + line_total, 2
                )
            total_final_amount += line_total  # sum of rounded line totals from line_items only

        qty_variance = 0.0
        if itm.initial_quantity > 0:
            qty_variance = ((itm.final_quantity - itm.initial_quantity) / itm.initial_quantity) * 100.0
        itm.variance_percentage = round(qty_variance, 2)

        price_variance = 0.0
        if itm.initial_unit_price > 0:
            price_variance = ((final_price - itm.initial_unit_price) / itm.initial_unit_price) * 100.0
        itm.price_variance_percentage = round(price_variance, 2)

        weight_variance = 0.0
        if itm.initial_gross_weight_kg > 0:
            weight_variance = ((itm.final_gross_weight_kg - itm.initial_gross_weight_kg) / itm.initial_gross_weight_kg) * 100.0
        itm.weight_variance_percentage = round(weight_variance, 2)

        updated_items.append(itm.model_dump())

    # BE03-T01: Weights/CBM per PO: use packing_items for POs that have them, else line_items
    pos_with_packing = {
        packs[itm.packing_item_id].po_id
        for itm in packing_items
        if itm.packing_item_id and itm.packing_item_id in packs
    }
    weight_sources = [
        itm for itm in packing_items
        if itm.packing_item_id and itm.packing_item_id in packs
    ] + [
        itm for itm in line_items
        if not itm.po_item_id or (itm.po_item_id in lines and lines[itm.po_item_id].po_id not in pos_with_packing)
    ]
    total_net_weight = 0.0
    total_gross_weight = 0.0
    total_cbm = 0.0
    for itm in weight_sources:
        if itm.packing_item_id:
            db_row = packs.get(itm.packing_item_id)
            nw = itm.final_net_weight_kg if itm.final_net_weight_kg > 0 or db_row is None else float(getattr(db_row, "total_net_weight_kg", 0.0) or 0.0)
            gw = itm.final_gross_weight_kg if itm.final_gross_weight_kg > 0 or db_row is None else float(getattr(db_row, "total_gross_weight_kg", 0.0) or 0.0)
            cbm = itm.final_cbm if itm.final_cbm > 0 or db_row is None else float(getattr(db_row, "total_cbm", 0.0) or 0.0)
        else:
            db_row = lines.get(itm.po_item_id) if itm.po_item_id else None
            nw = itm.final_net_weight_kg if itm.final_net_weight_kg > 0 or db_row is None else float(getattr(db_row, "net_weight_kg", 0.0) or 0.0)
            gw = itm.final_gross_weight_kg if itm.final_gross_weight_kg > 0 or db_row is None else float(getattr(db_row, "gross_weight_kg", 0.0) or 0.0)
            cbm = itm.final_cbm if itm.final_cbm > 0 or db_row is None else float(getattr(db_row, "total_cbm", 0.0) or 0.0)
        total_net_weight += nw
        total_gross_weight += gw
        total_cbm += cbm

    # DOC-02 c: one version bump + audit stamp per touched PO. Header totals follow the adjusted lines (lead
    # decision on Q2): plain sums of the stored line values, the line math itself is not recomputed.
    now = datetime.now(timezone.utc)
    for po_id in touched_po_ids:
        po = open_pos[po_id]
        if po_id in line_po_ids:
            po_lines = list(po.line_items or [])
            po.total_amount_fob = round(sum(float(l.total_price or 0.0) for l in po_lines), 2)
            po.total_gross_weight_kg = sum(float(l.gross_weight_kg or 0.0) for l in po_lines)
            po.total_net_weight_kg = sum(float(l.net_weight_kg or 0.0) for l in po_lines)
            po.total_cbm = sum(float(l.total_cbm or 0.0) for l in po_lines)
        if po_id in packing_po_ids:
            # BE03-T01: Recompute total_packages_count from packing rows
            po.total_packages_count = int(sum(float(pl.qty_pkg or 0.0) for pl in (po.packing_list_items or [])))
        po.version = (po.version or 1) + 1
        po.updated_at = now
        po.updated_by = actor

    # Update Import File Snapshot (the final amount is not stored on the file: no column yet, deferred)
    imp_file.pi_number = request.final_invoice_number
    imp_file.updated_by = actor
    db.commit()

    return {
        "status": "success",
        "message": "Final Commercial Invoice & Packing List quantities, prices, and weights certified for downstream systems (B/L, Inventory in Transit, Warehouse Receiving).",
        "import_file_id": request.import_file_id,
        "final_invoice_number": request.final_invoice_number,
        "final_packing_list_number": request.final_packing_list_number,
        "total_items_count": len(updated_items),
        "total_net_weight_kg": round(total_net_weight, 2),
        "total_gross_weight_kg": round(total_gross_weight, 2),
        "total_cbm": round(total_cbm, 3),
        "total_final_amount": round(total_final_amount, 2),
        "total_final_amount_by_currency": total_final_amount_by_currency,
        "items": updated_items,
    }



def _build_po_recon_system_inputs(
    db: Session,
    import_file_id: Optional[int],
    inv_data: dict,
    initial_system_items: Optional[List[dict]] = None,
) -> Tuple[List[dict], dict, List[dict]]:
    system_items = list(initial_system_items or [])
    system_packing_items = []
    file_metadata = {}
    if import_file_id:
        imp_file = db.query(ImportFile).filter(
            ImportFile.import_file_id == import_file_id,
            ImportFile.is_active == True,
        ).first()
        if imp_file:
            active_pos = repo.get_active_purchase_orders_for_file(db, import_file_id, imp_file.po_number)
            po = active_pos[0] if active_pos else None
            company = imp_file.company

            tax_no = (company.vat_id or None) if company else None

            po_curr = None
            if po and po.currency and getattr(po.currency, 'currency_code', None):
                po_curr = po.currency.currency_code
            elif imp_file.estimated_cost_currency:
                po_curr = imp_file.estimated_cost_currency

            po_amt = float(po.total_amount_fob) if (po and po.total_amount_fob is not None) else (float(imp_file.estimated_cost) if imp_file.estimated_cost is not None else None)
            po_pkgs = int(po.total_packages_count) if (po and po.total_packages_count is not None) else 0
            po_gw = float(po.total_gross_weight_kg) if (po and po.total_gross_weight_kg is not None) else 0.0
            po_nw = float(po.total_net_weight_kg) if (po and po.total_net_weight_kg is not None) else 0.0
            po_cbm = float(po.total_cbm) if (po and po.total_cbm is not None) else 0.0

            # Resolve supplier name
            supplier_name_val = ""
            if po and po.supplier:
                supplier_name_val = (po.supplier.company_name or "").strip()

            # Resolve importer name
            importer_name_val = (company.importer_name or "").strip() if company else ""
            if not importer_name_val:
                importer_name_val = (imp_file.company_name or "").strip()

            # Resolve primary HS Code (from first PO item)
            hs_code_val = ""
            if po and po.line_items:
                first_item = po.line_items[0]
                if first_item.tariff:
                    hs_code_val = first_item.tariff.hs_code or ""
                if not hs_code_val and po.packing_list_items:
                    hs_code_val = po.packing_list_items[0].hs_code or ""

            file_metadata = {
                "import_file_id": imp_file.import_file_id,
                "import_file_code": imp_file.import_file_code,
                "acid_number": imp_file.acid_number,
                "importer_tax_id": tax_no,
                "po_number": po.po_number if po else imp_file.po_number,
                "final_invoice_number": po.proforma_invoice_number if (po and po.proforma_invoice_number) else imp_file.po_number,
                "total_amount": po_amt,
                "currency": po_curr,
                "total_packages": po_pkgs,
                "total_gross_weight_kg": po_gw,
                "total_net_weight_kg": po_nw,
                "total_cbm": po_cbm,
                "supplier_name": supplier_name_val,
                "importer_name": importer_name_val,
                "hs_code": hs_code_val,
            }
            # system_packing_items always come from the DB packing list (real weights, not PO line item values);
            # system_items are built from PO line items only when the caller did not supply them.
            build_system_items = not system_items
            for p_rec in active_pos:
                line_map = {}
                for itm in p_rec.line_items:
                    if itm.item_code:
                        line_map[itm.item_code.strip().upper()] = itm.item_id

                pkg_map = {}
                for p_item in p_rec.packing_list_items:
                    code_key = (p_item.item_code or "").strip().upper()
                    if p_item.item_code:
                        pkg_map[code_key] = p_item
                    system_packing_items.append({
                        "packing_item_id": p_item.packing_item_id,
                        "po_item_id": line_map.get(code_key),
                        "item_code": p_item.item_code or "",
                        "description": p_item.description or p_item.item_code or "",
                        "hs_code": p_item.hs_code or "",
                        "package_type": p_item.package_type if p_item.package_type else None,
                        "initial_quantity": float(p_item.qty_pcs) if p_item.qty_pcs is not None else None,
                        "initial_packages_count": float(p_item.qty_pkg) if p_item.qty_pkg is not None else None,
                        "initial_net_weight_kg": float(p_item.total_net_weight_kg) if p_item.total_net_weight_kg is not None else 0.0,
                        "initial_gross_weight_kg": float(p_item.total_gross_weight_kg) if p_item.total_gross_weight_kg is not None else 0.0,
                        "initial_cbm": float(p_item.total_cbm) if p_item.total_cbm is not None else 0.0,
                    })

                if not build_system_items:
                    continue
                for itm in p_rec.line_items:
                    code_key = (itm.item_code or "").strip().upper()
                    pkg_info = pkg_map.get(code_key)

                    pkg_count = float(pkg_info.qty_pkg) if (pkg_info and pkg_info.qty_pkg is not None) else None
                    net_w = float(pkg_info.total_net_weight_kg) if (pkg_info and pkg_info.total_net_weight_kg is not None) else (float(itm.net_weight_kg) if itm.net_weight_kg is not None else 0.0)
                    gross_w = float(pkg_info.total_gross_weight_kg) if (pkg_info and pkg_info.total_gross_weight_kg is not None) else (float(itm.gross_weight_kg) if itm.gross_weight_kg is not None else 0.0)
                    cbm_val = float(pkg_info.total_cbm) if (pkg_info and pkg_info.total_cbm is not None) else (float(itm.total_cbm) if itm.total_cbm is not None else 0.0)
                    pkg_type = pkg_info.package_type if (pkg_info and pkg_info.package_type) else None

                    system_items.append({
                        "po_item_id": itm.item_id,
                        "item_code": itm.item_code or str(itm.item_id),
                        "description": itm.description_ar or itm.description_en or itm.main_description or "PO line item",
                        "hs_code": (itm.tariff.hs_code if itm.tariff else "") or (pkg_info.hs_code if pkg_info else ""),
                        "package_type": pkg_type,
                        "initial_quantity": float(itm.quantity) if itm.quantity is not None else 0.0,
                        "initial_unit_price": float(itm.unit_price) if itm.unit_price is not None else 0.0,
                        "initial_packages_count": pkg_count,
                        "initial_net_weight_kg": net_w,
                        "initial_gross_weight_kg": gross_w,
                        "initial_cbm": cbm_val,
                    })

    # Use system_items as packing fallback if no dedicated packing items found
    if not system_packing_items:
        system_packing_items = system_items

    return system_items, file_metadata, system_packing_items


def _compute_po_reconciliation_gate_fields(
    db: Session,
    import_file_id: int,
    extracted_inv_data: Optional[Dict[str, Any]],
    extracted_pl_data: Optional[Dict[str, Any]],
) -> Dict[str, Any]:
    if extracted_inv_data:
        from modules.import_documentation.ai_document_parser import reconcile_po_documents_with_system
        system_items, file_metadata, system_packing_items = _build_po_recon_system_inputs(
            db, import_file_id, extracted_inv_data
        )
        reconciled = reconcile_po_documents_with_system(
            extracted_inv_data,
            extracted_pl_data or {},
            system_items,
            file_metadata,
            system_packing_items=system_packing_items,
        )
        return {
            "overall_status": reconciled["overall_status"],
            "is_safe_for_certification": reconciled["is_safe_for_certification"],
            "critical_discrepancies_count": reconciled["critical_discrepancies_count"],
            "warning_discrepancies_count": reconciled["warning_discrepancies_count"],
            "header_discrepancies": reconciled.get("header_discrepancies"),
            "reconciled_invoice_items": reconciled.get("reconciled_invoice_items"),
            "reconciled_packing_items": reconciled.get("reconciled_packing_items"),
        }
    return {
        "overall_status": "DRAFT",
        "is_safe_for_certification": False,
        "critical_discrepancies_count": 0,
        "warning_discrepancies_count": 0,
    }


def extract_and_compare_po_documents_service(
    db: Session, request: POExtractAndCompareRequest
) -> POExtractAndCompareResponse:
    from modules.import_documentation.ai_document_parser import (
        extract_commercial_invoice_data,
        extract_packing_list_data,
        reconcile_po_documents_with_system,
    )

    # 1. Extract Invoice Data
    inv_data = dict(request.invoice_data or {})
    if request.invoice_raw_text and request.invoice_raw_text.strip():
        extracted_inv = extract_commercial_invoice_data(request.invoice_raw_text)
        for k, v in extracted_inv.items():
            if k not in inv_data or not inv_data[k]:
                inv_data[k] = v

    # 2. Extract Packing List Data
    pl_data = dict(request.packing_data or {})
    if request.packing_list_raw_text and request.packing_list_raw_text.strip():
        extracted_pl = extract_packing_list_data(request.packing_list_raw_text)
        for k, v in extracted_pl.items():
            if k not in pl_data or not pl_data[k]:
                pl_data[k] = v

    # 3. Fetch System PO Items and File Metadata if import_file_id is provided
    system_items, file_metadata, system_packing_items = _build_po_recon_system_inputs(
        db, request.import_file_id, inv_data, initial_system_items=request.system_items
    )
    system_items_missing = not bool(system_items)

    # 4. Perform 4-Way Reconciliation
    reconciled = reconcile_po_documents_with_system(
        inv_data, pl_data, system_items, file_metadata, system_packing_items=system_packing_items
    )

    if system_items_missing:
        overall_status = "DRAFT"
        is_safe_for_certification = False
    else:
        overall_status = reconciled["overall_status"]
        is_safe_for_certification = reconciled["is_safe_for_certification"]

    return POExtractAndCompareResponse(
        import_file_id=request.import_file_id,
        overall_status=overall_status,
        is_safe_for_certification=is_safe_for_certification,
        critical_discrepancies_count=reconciled["critical_discrepancies_count"],
        warning_discrepancies_count=reconciled["warning_discrepancies_count"],
        header_discrepancies=reconciled["header_discrepancies"],
        reconciled_invoice_items=reconciled["reconciled_invoice_items"],
        reconciled_packing_items=reconciled["reconciled_packing_items"],
        extracted_invoice_data=reconciled["extracted_invoice_data"],
        extracted_packing_data=reconciled["extracted_packing_data"],
        system_items_missing=system_items_missing,
    )


# --- PO & PACKING RECONCILIATION SESSIONS SERVICES (BP-016) ---
def enrich_po_reconciliation_session_response(
    db: Session, session: POPackingReconciliationSession, import_files_map: Optional[Dict[int, ImportFile]] = None
) -> POReconciliationSessionResponse:
    import_file_code = None
    importer_name = None

    if session.import_file_id:
        if import_files_map is not None:
            file = import_files_map.get(session.import_file_id)
        else:
            file = get_import_files_map(db, [session.import_file_id]).get(session.import_file_id)
        if file:
            import_file_code = file.import_file_code
            importer_name = file.company_name or (file.company.importer_name if file.company else None)

    resp_dict = {
        "session_id": session.session_id,
        "session_code": session.session_code,
        "import_file_id": session.import_file_id,
        "import_file_code": import_file_code,
        "importer_name": importer_name,
        "final_invoice_number": session.final_invoice_number,
        "final_packing_list_number": session.final_packing_list_number,
        "acid_number": session.acid_number,
        "shipper_name": session.shipper_name,
        "total_invoice_amount": session.total_invoice_amount,
        "currency": session.currency,
        "total_packages": session.total_packages,
        "total_net_weight_kg": session.total_net_weight_kg,
        "total_gross_weight_kg": session.total_gross_weight_kg,
        "total_cbm": session.total_cbm,
        "overall_status": session.overall_status,
        "is_safe_for_certification": session.is_safe_for_certification,
        "critical_discrepancies_count": session.critical_discrepancies_count,
        "warning_discrepancies_count": session.warning_discrepancies_count,
        "header_discrepancies": session.header_discrepancies,
        "reconciled_invoice_items": session.reconciled_invoice_items,
        "reconciled_packing_items": session.reconciled_packing_items,
        "extracted_invoice_data": session.extracted_invoice_data,
        "extracted_packing_data": session.extracted_packing_data,
        "notes": session.notes,
        "certified_by": session.certified_by,
        "is_active": session.is_active,
        "created_by": session.created_by,
        "updated_by": session.updated_by,
        "created_at": session.created_at,
        "updated_at": session.updated_at,
    }
    return POReconciliationSessionResponse(**resp_dict)


_PO_RECON_PASS_STATUSES = ["MATCHED", "APPROVED", "CERTIFIED", "PASS", "CONFORMING"]


def _audit_po_recon(db: Session, session: POPackingReconciliationSession, action: str, actor: str,
                    new_data: Optional[Dict[str, Any]] = None, old_data: Optional[Dict[str, Any]] = None) -> None:
    from modules.audit_logs.service import AuditLogService
    kwargs: Dict[str, Any] = {}
    if new_data is not None:
        kwargs["new_data"] = new_data
    if old_data is not None:
        kwargs["old_data"] = old_data
    best_effort(
        db, AuditLogService(db).log_activity, f"AuditLog for PO reconciliation {action.lower()}",
        entity_type="POPackingReconciliationSession",
        entity_id=session.session_id,
        entity_code=session.session_code,
        action=action,
        performed_by=actor,
        **kwargs,
    )


def _po_recon_lifecycle(db: Session, session: POPackingReconciliationSession, msg_code: str, actor: str) -> None:
    if session.overall_status in _PO_RECON_PASS_STATUSES or session.is_safe_for_certification:
        file_id, code = session.import_file_id, session.session_code
        _lifecycle_follow_up(
            db, "Lifecycle advance STEP_08_PO->STEP_08_BL",
            import_file_id=file_id,
            completed_step_code="STEP_08_PO",
            target_step_codes=["STEP_08_BL"],
            notes_msg=msg(msg_code, session_code=code),
            assigned_user=actor,
        )

        def _close_po_recon_tasks() -> None:
            from modules.smart_tasks.model import SmartTask
            tasks = db.query(SmartTask).filter(
                SmartTask.import_file_id == file_id,
                SmartTask.status.in_(["Pending", "In Progress"]),
                SmartTask.is_active == True,
            ).all()
            for t in tasks:
                title_s = (t.title or "").lower()
                step_s = (t.step_code or "").lower()
                if "step_08_po" in title_s or "step_08_po" in step_s or "مطابقة الفاتورة" in (t.title or ""):
                    t.status = "Completed"
                    t.is_auto_closed = True
            db.commit()

        best_effort(db, _close_po_recon_tasks, "Auto-close STEP_08_PO smart tasks")
        db.refresh(session)


def create_po_reconciliation_session_service(
    db: Session, schema: POReconciliationSessionCreate, user: Optional[str] = None
) -> POReconciliationSessionResponse:
    validate_status("reconciliation", schema.overall_status)
    # 1. Validate import file exists and is active
    _active_import_file(db, schema.import_file_id, status_code=status.HTTP_404_NOT_FOUND)
    actor = _actor(user, schema.certified_by)
    schema.certified_by = actor

    # Currency validation: required 3-letter active currency
    schema.currency = _validate_currency_code(db, schema.currency)

    # Server-owned gate fields (BE03-T05)
    gates = _compute_po_reconciliation_gate_fields(
        db, schema.import_file_id, schema.extracted_invoice_data, schema.extracted_packing_data
    )
    for k, v in gates.items():
        setattr(schema, k, v)

    # 2. Strict Rule: Prevent duplicate session for the same import file!
    existing = repo.get_po_reconciliation_session_by_file_id(db, schema.import_file_id, include_inactive=True)
    if existing and existing.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"يوجد بالفعل جلسة مطابقة محفوظة لهذا الملف الاستيرادي (رمز الجلسة: {existing.session_code}). "
                f"لا يُسمح بإنشاء أكثر من جلسة حفظ لنفس الملف الاستيرادي. يمكنك تحديث الجلسة الحالية أو استعراضها من سجل الجلسات."
            ),
        )

    if existing:
        # DOC-09 / Q5: import_file_id is unique in the table, so a soft-deleted session is reused: overwritten
        # with the new data, reactivated, and audited as CREATE (no schema change this wave).
        for field, value in schema.model_dump().items():
            if field != "import_file_id":
                setattr(existing, field, value)
        existing.is_active = True
        existing.updated_at = datetime.now(timezone.utc)
        existing.updated_by = actor
        db.commit()
        db.refresh(existing)
        session = existing
    else:
        session = repo.create_po_reconciliation_session(db, schema, user=actor)

    _audit_po_recon(db, session, "CREATE", actor, new_data=schema.model_dump(mode="json", exclude_unset=True))
    _po_recon_lifecycle(db, session, "DOC_PO_RECONCILIATION_DONE", actor)
    return enrich_po_reconciliation_session_response(db, session)


def get_po_reconciliation_sessions_service(
    db: Session,
    import_file_id: int | None = None,
    overall_status: str | None = None,
    search: str | None = None,
    skip: int = 0,
    limit: int | None = None,
    return_total: bool = False,
) -> list[POReconciliationSessionResponse] | tuple[list[POReconciliationSessionResponse], int]:
    res = repo.get_po_reconciliation_sessions(
        db,
        import_file_id=import_file_id,
        overall_status=overall_status,
        search=search,
        skip=skip,
        limit=limit,
        return_total=return_total,
    )
    if return_total:
        sessions, total = res
    else:
        sessions, total = res, len(res)

    files_map = get_import_files_map(db, [s.import_file_id for s in sessions])
    enriched = [enrich_po_reconciliation_session_response(db, s, import_files_map=files_map) for s in sessions]
    return (enriched, total) if return_total else enriched


def get_po_reconciliation_session_by_id_service(
    db: Session, session_id: int
) -> POReconciliationSessionResponse:
    session = repo.get_po_reconciliation_session_by_id(db, session_id)
    if not session:
        raise not_found(LABEL_PO_RECON_SESSION, session_id)
    return enrich_po_reconciliation_session_response(db, session)


def update_po_reconciliation_session_service(
    db: Session, session_id: int, schema: POReconciliationSessionUpdate, user: Optional[str] = None
) -> POReconciliationSessionResponse:
    validate_status("reconciliation", schema.overall_status)
    session = repo.get_po_reconciliation_session_by_id(db, session_id)
    if not session:
        raise not_found(LABEL_PO_RECON_SESSION, session_id)
    actor = _actor(user, schema.certified_by)
    schema.certified_by = actor

    if schema.currency is not None:
        schema.currency = _validate_currency_code(db, schema.currency)

    # Server-owned gate fields (BE03-T05)
    if schema.extracted_invoice_data is not None:
        gates = _compute_po_reconciliation_gate_fields(
            db,
            session.import_file_id,
            schema.extracted_invoice_data,
            schema.extracted_packing_data if schema.extracted_packing_data is not None else session.extracted_packing_data,
        )
        for k, v in gates.items():
            setattr(schema, k, v)
    elif schema.extracted_packing_data is not None and session.extracted_invoice_data:
        gates = _compute_po_reconciliation_gate_fields(
            db,
            session.import_file_id,
            session.extracted_invoice_data,
            schema.extracted_packing_data,
        )
        for k, v in gates.items():
            setattr(schema, k, v)
    else:
        # Keep existing server-owned gate fields from session, ignoring client tampering
        schema.overall_status = session.overall_status
        schema.is_safe_for_certification = session.is_safe_for_certification
        schema.critical_discrepancies_count = session.critical_discrepancies_count
        schema.warning_discrepancies_count = session.warning_discrepancies_count

    update_data = schema.model_dump(mode="json", exclude_unset=True, exclude_none=True)
    old_data = {k: getattr(session, k, None) for k in update_data.keys()}
    old_data = {k: (v.isoformat() if hasattr(v, "isoformat") else v) for k, v in old_data.items()}

    updated = repo.update_po_reconciliation_session(db, session_id, schema, user=actor)

    _audit_po_recon(db, updated, "UPDATE", actor, new_data=update_data, old_data=old_data)
    _po_recon_lifecycle(db, updated, "DOC_PO_RECONCILIATION_UPDATED", actor)
    return enrich_po_reconciliation_session_response(db, updated)


def delete_po_reconciliation_session_service(db: Session, session_id: int, user: Optional[str] = None) -> dict:
    session = repo.get_po_reconciliation_session_by_id(db, session_id)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"جلسة المطابقة رقم {session_id} غير موجودة للحذف.",
        )
    repo.delete_po_reconciliation_session(db, session_id)
    _audit_po_recon(db, session, "DELETE", _actor(user, session.certified_by))
    db.commit()
    return {"message": f"تم حذف جلسة المطابقة رقم {session_id} بنجاح", "deleted": True}



def extract_po_files_and_compare_service(
    db: Session,
    invoice: Optional[Tuple[str, bytes]],
    packing: Optional[Tuple[str, bytes]],
    import_file_id: Optional[int],
    invoice_text: Optional[str] = None,
    packing_text: Optional[str] = None,
) -> POExtractAndCompareResponse:
    inv_raw = invoice_text or ""
    pl_raw = packing_text or ""
    if invoice:
        inv_raw = extract_text_from_uploaded_file(invoice[0], invoice[1])
    if packing:
        pl_raw = extract_text_from_uploaded_file(packing[0], packing[1])
    req = POExtractAndCompareRequest(
        import_file_id=import_file_id,
        invoice_raw_text=inv_raw,
        packing_list_raw_text=pl_raw,
    )
    return extract_and_compare_po_documents_service(db, req)

