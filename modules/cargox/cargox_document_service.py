"""
CargoX Document Extraction, Commercial Invoices & Packaging Engine (CGX-002 / CGX-003)
Handles document extraction, decryption, attachment management, Excel template generation,
multi-path extraction, and customs track lifecycle.
"""

import io
import base64
import uuid
import hashlib
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
from collections import OrderedDict, defaultdict
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from .model import (
    CargoXEnvelope,
    CargoXEnvelopeDocument,
    CargoXStandardInvoiceReviewSession,
    CargoXCustomsInvoiceTrack,
)
from .schemas import (
    StandardInvoicePayload,
    StandardInvoiceLineItem,
    StandardInvoiceComparisonResponse,
    StandardInvoiceSessionCreate,
    StandardInvoiceStatusUpdateRequest,
    ExtractionRequest,
    ExtractionResponse,
    ExtractionResultItem,
    CustomsInvoiceTrackCreate,
    CargoXDocumentCreate,
)
from .repository import CargoXRepository, CargoXStandardInvoiceRepository
from .excel_invoice_service import (
    generate_standard_invoice_excel_bytes,
    parse_standard_invoice_excel_bytes,
    compare_standard_invoice_data,
    normalize_cargox_weight_unit,
)
from .city_port_resolver import (
    resolve_city_code,
    resolve_port_code,
)
from ..import_files.model import ImportFile
from ..import_companies.model import ImportCompany
from ..suppliers.model import Supplier
from ..purchase_orders.model import PurchaseOrder, POLineItem
from ..import_documentation.model import POPackingReconciliationSession


class CargoXDocumentService:
    """
    Sub-service for CargoX document extraction, decryption, PDF/XML processing,
    and attachment handling.
    """

    @staticmethod
    def extract_envelope_documents(db: Session, envelope_id: int) -> List[CargoXEnvelopeDocument]:
        """Extract all active documents attached to a CargoX envelope."""
        envelope = CargoXRepository.get_by_id(db, envelope_id)
        if not envelope:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"مظروف CargoX برقم المعرف {envelope_id} غير موجود.",
            )
        return [doc for doc in envelope.documents if doc.is_active]

    @staticmethod
    def attach_documents_to_envelope(
        db: Session,
        envelope_id: int,
        documents: List[CargoXDocumentCreate],
        updated_by: str = "SYSTEM",
    ) -> CargoXEnvelope:
        """Attach new documents to an existing CargoX envelope."""
        envelope = CargoXRepository.get_by_id(db, envelope_id)
        if not envelope:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"مظروف CargoX برقم المعرف {envelope_id} غير موجود.",
            )

        for d in documents:
            file_hash = d.file_hash or hashlib.sha256(f"{d.file_name}-{envelope.acid_number}".encode()).hexdigest()
            doc_item = CargoXEnvelopeDocument(
                envelope_id=envelope.envelope_id,
                doc_type=d.doc_type,
                doc_number=d.doc_number,
                file_name=d.file_name,
                file_hash=file_hash,
                file_size_kb=d.file_size_kb if d.file_size_kb > 0 else 256.0,
                is_mandatory=d.is_mandatory,
                is_uploaded=True,
                verified_against_acid=d.verified_against_acid,
                pki_signature=f"SIG-DOC-{uuid.uuid4().hex[:12].upper()}",
                notes=d.notes,
            )
            envelope.documents.append(doc_item)

        envelope.updated_by = updated_by
        return CargoXRepository.update(db, envelope)

    @staticmethod
    def validate_document_hash(file_bytes: bytes, expected_hash: str) -> bool:
        """Validate SHA256 cryptographic hash of document bytes."""
        if not file_bytes or not expected_hash:
            return False
        computed_hash = hashlib.sha256(file_bytes).hexdigest()
        return computed_hash.lower() == expected_hash.strip().lower()

    @staticmethod
    def decrypt_document_payload(encrypted_payload: str, key: Optional[str] = None) -> bytes:
        """
        Process or decode base64/encrypted payload for CargoX attachments.
        """
        try:
            return base64.b64decode(encrypted_payload)
        except Exception:
            return encrypted_payload.encode("utf-8")

    @staticmethod
    def verify_document_acid_match(doc: CargoXEnvelopeDocument, target_acid: str) -> bool:
        """Verify whether document metadata corresponds with shipment ACID."""
        return bool(doc.verified_against_acid and doc.is_active)


# ============================================================================
# STANDARD EXCEL COMMERCIAL INVOICE SERVICE (BP-025 / CGX-002)
# ============================================================================


class CargoXStandardInvoiceService:

    @staticmethod
    def list_customs_tracks_by_file(db: Session, import_file_id: int):
        return CargoXRepository.list_customs_tracks_by_file(db, import_file_id)

    @staticmethod
    def get_customs_track_by_id(db: Session, track_id: int):
        track = CargoXRepository.get_customs_track_by_id(db, track_id)
        if not track:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"المسار الجمركي {track_id} غير موجود.",
            )
        return track

    @staticmethod
    def build_system_snapshot(db: Session, import_file_id: int) -> StandardInvoicePayload:
        file = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
        if not file:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"ملف الاستيراد برقم {import_file_id} غير موجود.",
            )

        company = None
        if file.company_id:
            company = db.query(ImportCompany).filter(ImportCompany.company_id == file.company_id).first()

        supplier = None
        if file.supplier_id:
            supplier = db.query(Supplier).filter(Supplier.supplier_id == file.supplier_id).first()

        # Check for reconciled PO Packing session
        reconciled_session = (
            db.query(POPackingReconciliationSession)
            .filter(
                POPackingReconciliationSession.import_file_id == import_file_id,
                POPackingReconciliationSession.is_active.is_(True),
            )
            .order_by(POPackingReconciliationSession.session_id.desc())
            .first()
        )

        # Fallback to PO items if no reconciliation session
        po = (
            db.query(PurchaseOrder)
            .filter(
                PurchaseOrder.import_file_id == import_file_id,
                PurchaseOrder.is_active.is_(True),
            )
            .order_by(PurchaseOrder.po_id.desc())
            .first()
        )

        # 1. Invoice Number resolution from invoices_data or Proforma Invoice
        inv_number = None
        if file.invoices_data and isinstance(file.invoices_data, list) and len(file.invoices_data) > 0:
            first_inv = file.invoices_data[0]
            if isinstance(first_inv, dict):
                inv_number = first_inv.get("invoice_number") or first_inv.get("invoice_no")
            elif isinstance(first_inv, str):
                inv_number = first_inv
        if not inv_number:
            inv_number = (po.proforma_invoice_number if po and po.proforma_invoice_number else None) or file.pi_number or f"INV-{file.import_file_code}"

        # 2. Total Weights & Unit resolution from Packing List / PO / File
        total_gross = 0.0
        total_net = 0.0
        weight_uom = "KGM"

        if po and po.packing_list_items:
            pl_g = sum(float(pl.total_gross_weight_kg or 0.0) for pl in po.packing_list_items)
            pl_n = sum(float(pl.total_net_weight_kg or 0.0) for pl in po.packing_list_items)
            if pl_g > 0:
                total_gross = pl_g
            if pl_n > 0:
                total_net = pl_n
            for pl in po.packing_list_items:
                if pl.weight_unit:
                    weight_uom = pl.weight_unit
                    break

        if po:
            po_gw = float(po.total_gross_weight_kg or 0.0)
            po_nw = float(po.total_net_weight_kg or 0.0)
            if total_gross == 0.0:
                total_gross = po_gw
            elif po_gw > 0 and abs(po_gw - total_gross) <= 1.0:
                total_gross = po_gw
            if total_net == 0.0:
                total_net = po_nw
            elif po_nw > 0 and abs(po_nw - total_net) <= 1.0:
                total_net = po_nw

        if total_gross == 0.0 and file.packing_lists_data and isinstance(file.packing_lists_data, list):
            for pld in file.packing_lists_data:
                if isinstance(pld, dict):
                    total_gross += float(pld.get("total_gross_weight_kg") or pld.get("gross_weight") or 0.0)
                    total_net += float(pld.get("total_net_weight_kg") or pld.get("net_weight") or 0.0)
                    u = pld.get("weight_unit") or pld.get("weight_uom")
                    if u:
                        weight_uom = u
                        break

        if total_gross == 0.0:
            total_gross = float(getattr(file, "gross_weight_kg", 0.0) or 0.0)
        if total_net == 0.0:
            total_net = float(getattr(file, "net_weight_kg", 0.0) or 0.0)

        weight_uom = normalize_cargox_weight_unit(weight_uom)

        # 3. Collect Raw Line Items
        raw_items_source = []
        reconciled_items = (
            getattr(reconciled_session, "reconciled_invoice_items", None)
            or getattr(reconciled_session, "reconciled_packing_items", None)
        ) if reconciled_session else None

        supplier_country = (
            getattr(supplier, "foreign_exporter_country_code", None)
            or getattr(supplier, "foreign_exporter_country", None)
            or "CN"
        )

        if reconciled_items:
            po_items = po.line_items if po and po.line_items else []
            po_by_id = {pi.item_id: pi for pi in po_items if pi.item_id}
            po_by_code = {pi.item_code: pi for pi in po_items if pi.item_code}

            for raw_item in reconciled_items:
                pi = po_by_id.get(raw_item.get("po_item_id")) or po_by_code.get(raw_item.get("item_code"))
                desc = (pi.main_description if pi and pi.main_description else None) or raw_item.get("main_description") or raw_item.get("item_name") or raw_item.get("description") or "Imported Goods"
                uom = (pi.unit_of_measure if pi and pi.unit_of_measure else None) or raw_item.get("unit_of_measure") or raw_item.get("unit") or "PCS"
                hs_val = raw_item.get("hs_code") or (pi.tariff.hs_code if pi and hasattr(pi, "tariff") and pi.tariff else "940310")

                raw_items_source.append({
                    "item_code": raw_item.get("item_code"),
                    "hs_code": hs_val,
                    "description": desc,
                    "quantity": float(raw_item.get("actual_quantity") or raw_item.get("po_quantity") or raw_item.get("final_quantity") or 1.0),
                    "qty_unit": uom,
                    "unit_price": float(raw_item.get("unit_price") or raw_item.get("final_unit_price") or 0.0),
                    "country_of_origin": raw_item.get("country_of_origin") or supplier_country,
                    "gross_weight_kg": float(raw_item.get("final_gross_weight_kg") or raw_item.get("gross_weight") or 0.0),
                    "net_weight_kg": float(raw_item.get("final_net_weight_kg") or raw_item.get("net_weight") or 0.0),
                    "weight_unit": weight_uom,
                })
        elif po and po.line_items:
            for pi in po.line_items:
                hs_code_val = "940310"
                if hasattr(pi, "tariff") and pi.tariff and pi.tariff.hs_code:
                    hs_code_val = pi.tariff.hs_code
                raw_items_source.append({
                    "item_code": pi.item_code,
                    "hs_code": hs_code_val,
                    "description": pi.main_description or pi.description_en or pi.description_ar or "Imported Goods",
                    "quantity": float(pi.quantity),
                    "qty_unit": pi.unit_of_measure or "PCS",
                    "unit_price": float(pi.unit_price),
                    "country_of_origin": pi.country_of_origin or supplier_country,
                    "gross_weight_kg": float(pi.gross_weight_kg or 0.0),
                    "net_weight_kg": float(pi.net_weight_kg or 0.0),
                    "weight_unit": weight_uom,
                })
        else:
            raw_items_source.append({
                "item_code": "ITEM-001",
                "hs_code": "940310",
                "description": "Standard Commercial Goods",
                "quantity": 1.0,
                "qty_unit": "SET",
                "unit_price": float(file.estimated_cost or 1000.0),
                "country_of_origin": supplier.country.iso2 if supplier and supplier.country else "IT",
                "gross_weight_kg": total_gross or 100.0,
                "net_weight_kg": total_net or 90.0,
            })

        # 4. Pro-rate Unit Weights
        total_all_qty = sum(r["quantity"] for r in raw_items_source) if raw_items_source else 1.0
        unit_gross_rate = (total_gross / total_all_qty) if (total_gross > 0 and total_all_qty > 0) else 0.0
        unit_net_rate = (total_net / total_all_qty) if (total_net > 0 and total_all_qty > 0) else 0.0

        # 5. Group by HS Code (Consolidation to prevent duplicate HS Code rows)
        grouped = OrderedDict()
        for r in raw_items_source:
            hs = r["hs_code"]
            if hs not in grouped:
                grouped[hs] = {
                    "hs_code": hs,
                    "item_codes": [],
                    "descriptions": [],
                    "total_qty": 0.0,
                    "qty_unit": r["qty_unit"],
                    "total_amount": 0.0,
                    "total_gross_weight": 0.0,
                    "total_net_weight": 0.0,
                    "country_of_origin": r["country_of_origin"],
                }
            qty = r["quantity"]
            price = r["unit_price"]
            amount = qty * price
            item_g = (qty * unit_gross_rate) if unit_gross_rate > 0 else r["gross_weight_kg"]
            item_n = (qty * unit_net_rate) if unit_net_rate > 0 else r["net_weight_kg"]

            if r["item_code"] and r["item_code"] not in grouped[hs]["item_codes"]:
                grouped[hs]["item_codes"].append(r["item_code"])
            if r["description"] and r["description"] not in grouped[hs]["descriptions"]:
                grouped[hs]["descriptions"].append(r["description"])

            grouped[hs]["total_qty"] += qty
            grouped[hs]["total_amount"] += amount
            grouped[hs]["total_gross_weight"] += item_g
            grouped[hs]["total_net_weight"] += item_n

        items: List[StandardInvoiceLineItem] = []
        for idx, (hs, grp) in enumerate(grouped.items(), start=1):
            tot_qty = grp["total_qty"]
            tot_amt = grp["total_amount"]
            avg_price = round(tot_amt / tot_qty, 4) if tot_qty > 0 else 0.0
            code_str = grp["item_codes"][0] if grp["item_codes"] else f"ITEM-{idx:03d}"
            desc_str = grp["descriptions"][0] if grp["descriptions"] else "Imported Goods"

            items.append(
                StandardInvoiceLineItem(
                    index=idx,
                    product_code=code_str,
                    manufacturer=supplier.company_name if supplier else "Manufacturer",
                    brand_name="Standard",
                    model="Standard",
                    hs_code=hs,
                    country_of_origin=grp["country_of_origin"],
                    description=desc_str,
                    quantity=round(tot_qty, 2),
                    qty_unit=grp["qty_unit"],
                    expiry_date=None,
                    unit_price=round(avg_price, 4),
                    unit_price_basis=grp["qty_unit"],
                    gross_weight_kg=round(grp["total_gross_weight"], 2),
                    net_weight_kg=round(grp["total_net_weight"], 2),
                    weight_unit=weight_uom,
                    total_amount=round(tot_amt, 2),
                )
            )

        subtotal = sum(i.total_amount for i in items)
        freight = float(getattr(file, "freight_amount", 0.0) or 0.0)
        insurance = float(getattr(file, "insurance_amount", 0.0) or 0.0)
        other = float(getattr(file, "other_cost", 0.0) or 0.0)
        total = round(subtotal + freight + insurance + other, 2)

        po_date_str = None
        if po and po.order_date:
            po_date_str = po.order_date.strftime("%Y-%m-%d")

        seller_addr = supplier.address if supplier else ""
        seller_country = (supplier.foreign_exporter_country_code if supplier else None) or "CN"
        seller_city_code = resolve_city_code(seller_addr, seller_country)

        return StandardInvoicePayload(
            seller_name=supplier.company_name if supplier else file.supplier_name,
            seller_address=seller_addr,
            seller_city="",
            seller_city_code=seller_city_code,
            seller_country_code=seller_country,
            seller_tax_id=supplier.foreign_exporter_id if supplier else "",
            seller_contact_name="",
            seller_phone=supplier.phone if supplier else "",
            seller_fax=supplier.fax if supplier else "",
            seller_email=supplier.email if supplier else "",
            seller_website=supplier.website if supplier else "",
            buyer_name=company.importer_name if company else file.company_name,
            buyer_address=company.address if company else "",
            buyer_tax_id=company.vat_id or company.importer_id if company else "",
            buyer_contact_name="",
            buyer_phone="",
            buyer_fax="",
            buyer_email="",
            acid_number=file.acid_number or "PENDING",
            invoice_type="Commercial Invoice",
            invoice_number=inv_number,
            invoice_date=po.order_date.strftime("%Y-%m-%d") if (po and po.order_date) else datetime.now(timezone.utc).strftime("%Y-%m-%d"),
            purchase_order_number=po.po_number if po else f"PO-{file.import_file_code}",
            purchase_order_date=po_date_str,
            proforma_invoice_number=po.proforma_invoice_number if po else None,
            origin_port=resolve_port_code(file.port_of_loading or "CNSHA"),
            destination_port=resolve_port_code(file.port_of_discharge or "EGALY"),
            currency_code=file.estimated_cost_currency or "EUR",
            incoterm=file.incoterm_code or "EXW",
            gross_weight=round(total_gross, 2),
            net_weight=round(total_net, 2),
            weight_unit=weight_uom,
            items=items,
            subtotal=subtotal,
            freight_cost=freight,
            insurance_cost=insurance,
            other_costs=other,
            total_amount=total,
        )

    @staticmethod
    def generate_excel_template(db: Session, import_file_id: int) -> bytes:
        snapshot = CargoXStandardInvoiceService.build_system_snapshot(db, import_file_id)
        return generate_standard_invoice_excel_bytes(snapshot)

    @staticmethod
    def parse_excel_file(file_bytes: bytes) -> StandardInvoicePayload:
        return parse_standard_invoice_excel_bytes(file_bytes)

    @staticmethod
    def compare_invoices(
        db: Session, import_file_id: int, supplier_data: StandardInvoicePayload
    ) -> StandardInvoiceComparisonResponse:
        file = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
        file_code = file.import_file_code if file else f"IMP-{import_file_id}"
        system_snapshot = CargoXStandardInvoiceService.build_system_snapshot(db, import_file_id)
        return compare_standard_invoice_data(
            import_file_id=import_file_id,
            import_file_code=file_code,
            system_snapshot=system_snapshot,
            supplier_data=supplier_data,
        )

    @staticmethod
    def save_or_upsert_session(
        db: Session, payload: StandardInvoiceSessionCreate, created_by: str = "SYSTEM"
    ) -> CargoXStandardInvoiceReviewSession:
        # Check mandatory override justification
        if payload.status == "APPROVED" and (payload.has_discrepancies or payload.has_critical_mismatch):
            reason = (payload.discrepancy_override_reason or "").strip()
            if not reason:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="يجب كتابة مبرر وسبب الموافقة على الاختلافات الجمركية (Discrepancy Override Justification) قبل اعتماد الفاتورة.",
                )

        existing = CargoXStandardInvoiceRepository.get_by_import_file(db, payload.import_file_id)
        if existing:
            # Update in-place (Anti-duplicate rule)
            existing.invoice_number = payload.invoice_number or existing.invoice_number
            existing.invoice_date = payload.invoice_date or existing.invoice_date
            existing.invoice_type = payload.invoice_type
            existing.purchase_order_id = payload.purchase_order_id or existing.purchase_order_id
            existing.purchase_order_number = payload.purchase_order_number or existing.purchase_order_number
            existing.supplier_id = payload.supplier_id or existing.supplier_id
            existing.exporter_name = payload.exporter_name or existing.exporter_name
            existing.exporter_tax_id = payload.exporter_tax_id or existing.exporter_tax_id
            existing.exporter_country_code = payload.exporter_country_code or existing.exporter_country_code
            existing.importer_company_id = payload.importer_company_id or existing.importer_company_id
            existing.importer_name = payload.importer_name or existing.importer_name
            existing.importer_tax_id = payload.importer_tax_id or existing.importer_tax_id
            existing.currency_code = payload.currency_code
            existing.incoterm = payload.incoterm or existing.incoterm
            existing.pol_code = payload.pol_code or existing.pol_code
            existing.pod_code = payload.pod_code or existing.pod_code
            existing.gross_weight_kg = payload.gross_weight_kg
            existing.net_weight_kg = payload.net_weight_kg
            existing.weight_unit = payload.weight_unit
            existing.subtotal_amount = payload.subtotal_amount
            existing.freight_cost = payload.freight_cost
            existing.insurance_cost = payload.insurance_cost
            existing.other_costs = payload.other_costs
            existing.total_amount = payload.total_amount
            existing.line_items_count = payload.line_items_count
            existing.system_snapshot_data = payload.system_snapshot_data or existing.system_snapshot_data
            existing.supplier_invoice_data = payload.supplier_invoice_data or existing.supplier_invoice_data
            existing.comparison_data = payload.comparison_data or existing.comparison_data
            existing.has_discrepancies = payload.has_discrepancies
            existing.has_critical_mismatch = payload.has_critical_mismatch
            existing.discrepancy_override_reason = payload.discrepancy_override_reason or existing.discrepancy_override_reason
            existing.status = payload.status
            existing.notes = payload.notes or existing.notes
            existing.updated_by = created_by
            return CargoXStandardInvoiceRepository.update(db, existing)

        # Create new record
        session_code = CargoXStandardInvoiceRepository.get_next_code(db)
        new_session = CargoXStandardInvoiceReviewSession(
            session_code=session_code,
            import_file_id=payload.import_file_id,
            import_file_code=payload.import_file_code,
            acid_number=payload.acid_number,
            invoice_number=payload.invoice_number,
            invoice_date=payload.invoice_date,
            invoice_type=payload.invoice_type,
            purchase_order_id=payload.purchase_order_id,
            purchase_order_number=payload.purchase_order_number,
            supplier_id=payload.supplier_id,
            exporter_name=payload.exporter_name,
            exporter_tax_id=payload.exporter_tax_id,
            exporter_country_code=payload.exporter_country_code,
            importer_company_id=payload.importer_company_id,
            importer_name=payload.importer_name,
            importer_tax_id=payload.importer_tax_id,
            currency_code=payload.currency_code,
            incoterm=payload.incoterm,
            pol_code=payload.pol_code,
            pod_code=payload.pod_code,
            gross_weight_kg=payload.gross_weight_kg,
            net_weight_kg=payload.net_weight_kg,
            weight_unit=payload.weight_unit,
            subtotal_amount=payload.subtotal_amount,
            freight_cost=payload.freight_cost,
            insurance_cost=payload.insurance_cost,
            other_costs=payload.other_costs,
            total_amount=payload.total_amount,
            line_items_count=payload.line_items_count,
            system_snapshot_data=payload.system_snapshot_data,
            supplier_invoice_data=payload.supplier_invoice_data,
            comparison_data=payload.comparison_data,
            has_discrepancies=payload.has_discrepancies,
            has_critical_mismatch=payload.has_critical_mismatch,
            discrepancy_override_reason=payload.discrepancy_override_reason,
            status=payload.status,
            notes=payload.notes,
            created_by=created_by,
            updated_by=created_by,
        )
        return CargoXStandardInvoiceRepository.create(db, new_session)

    @staticmethod
    def get_session_by_file(db: Session, import_file_id: int) -> Optional[CargoXStandardInvoiceReviewSession]:
        return CargoXStandardInvoiceRepository.get_by_import_file(db, import_file_id)

    @staticmethod
    def list_sessions(
        db: Session,
        search: Optional[str] = None,
        status: Optional[str] = None,
        import_file_id: Optional[int] = None,
        limit: int = 100,
        offset: int = 0,
    ) -> List[CargoXStandardInvoiceReviewSession]:
        return CargoXStandardInvoiceRepository.get_all(
            db, search=search, status=status, import_file_id=import_file_id, limit=limit, offset=offset
        )

    @staticmethod
    def update_session_status(
        db: Session, session_id: int, payload: StandardInvoiceStatusUpdateRequest, updated_by: str = "SYSTEM"
    ) -> CargoXStandardInvoiceReviewSession:
        session = CargoXStandardInvoiceRepository.get_by_id(db, session_id)
        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"جلسة مراجعة الفاتورة برقم المعرف {session_id} غير موجودة.",
            )

        if payload.status == "APPROVED" and (session.has_discrepancies or session.has_critical_mismatch):
            reason = (payload.discrepancy_override_reason or session.discrepancy_override_reason or "").strip()
            if not reason:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="يجب كتابة مبرر وسبب الموافقة على الاختلافات الجمركية (Discrepancy Override Justification) قبل اعتماد الفاتورة.",
                )
            session.discrepancy_override_reason = reason

        session.status = payload.status
        if payload.notes:
            session.notes = payload.notes
        session.updated_by = updated_by
        return CargoXStandardInvoiceRepository.update(db, session)


# ============================================================================
# CGX-003: Multi-Path Extraction Engine
# ============================================================================


class CargoXExtractionEngine:
    """
    محرك استخراج مستندات CargoX متعدد المسارات (CGX-003).

    يدعم 4 modes للاستخراج:
    - all_consolidated:         ملف Excel واحد — بنود مجمعة بـ HS Code (weighted avg price)
    - all_detailed:             ملف Excel واحد — بنود مفصلة (كل سطر منفصل)
    - per_invoice_consolidated: ZIP بعدد الفواتير — كل ملف مجمع بـ HS Code
    - per_invoice_detailed:     ZIP بعدد الفواتير — كل ملف مفصل

    ويدعم 3 modes للتجميع:
    - by_hs_code:     تجميع + weighted average price لكل HS Code (الافتراضي للجمرك)
    - by_price_group: تجميع لكل HS Code + مجموعة سعر (أسعار مختلفة = سطور مختلفة)
    - flat:           بدون تجميع — كل سطر منفصل
    """

    # -------------------------------------------------------------------------
    # Public Interface
    # -------------------------------------------------------------------------

    @staticmethod
    def extract(
        db: Session,
        import_file_id: int,
        request: ExtractionRequest,
    ) -> ExtractionResponse:
        """
        المدخل الرئيسي لمحرك الاستخراج.
        يُرجع ExtractionResponse يحتوي على قايمة من StandardInvoicePayload.
        """
        file = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
        if not file:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"ملف الاستيراد برقم {import_file_id} غير موجود.",
            )

        # حفظ آخر preference
        file.extraction_preference = request.mode
        db.flush()

        # جلب البيانات المشتركة
        company, supplier, pos = CargoXExtractionEngine._load_entities(db, file)
        reconciled_session = CargoXExtractionEngine._load_reconciled_session(db, import_file_id)
        base_raw = CargoXExtractionEngine._build_base_payload(file, company, supplier)

        # تجميع البيانات الخام مع الفواتير
        invoices_raw = CargoXExtractionEngine._collect_invoices_raw(
            file, pos, reconciled_session, supplier, request
        )

        # استخراج حسب mode
        mode = request.mode
        results: List[ExtractionResultItem] = []

        # ── استخلاص تاريخ الفاتورة من PO مباشرة (order_date هو تاريخ الفاتورة المبدئية) ──
        po_invoice_date: Optional[str] = None
        if pos:
            first_po = pos[0]
            if first_po.order_date:
                po_invoice_date = first_po.order_date.strftime("%Y-%m-%d")

        if mode in ("all_consolidated", "all_detailed"):
            # دمج كل بيانات الفواتير في payload واحد
            all_items_raw = []
            for inv_no, items_raw in invoices_raw.items():
                all_items_raw.extend(items_raw)

            grouped_items = CargoXExtractionEngine._group_items(
                all_items_raw, request.grouping_mode, mode
            )
            total_gross, total_net, weight_uom = CargoXExtractionEngine._resolve_weights(file, pos)
            payload = CargoXExtractionEngine._build_payload(
                base_raw, grouped_items, total_gross, total_net, weight_uom,
                inv_number=CargoXExtractionEngine._resolve_invoice_number(file, pos),
                po_date=po_invoice_date,
            )
            results.append(ExtractionResultItem(invoice_number=payload.invoice_number, payload=payload))

        else:
            # per_invoice: ملف منفصل لكل فاتورة
            for inv_no, items_raw in invoices_raw.items():
                if request.invoice_filter and inv_no != request.invoice_filter:
                    continue
                grouped_items = CargoXExtractionEngine._group_items(
                    items_raw, request.grouping_mode, mode
                )
                # استخلاص أوزان هذه الفاتورة تحديداً (نسبة بيانات هذه الفاتورة)
                inv_gross, inv_net, weight_uom = CargoXExtractionEngine._resolve_per_invoice_weights(
                    file, pos, inv_no, items_raw, invoices_raw
                )
                payload = CargoXExtractionEngine._build_payload(
                    base_raw, grouped_items, inv_gross, inv_net, weight_uom,
                    inv_number=inv_no,
                    po_date=po_invoice_date,
                )
                results.append(ExtractionResultItem(invoice_number=inv_no, payload=payload))

        total_line_items = sum(len(r.payload.items) for r in results)

        return ExtractionResponse(
            import_file_id=import_file_id,
            import_file_code=file.import_file_code,
            mode=request.mode,
            grouping_mode=request.grouping_mode,
            invoices_count=len(results),
            total_line_items=total_line_items,
            results=results,
        )

    @staticmethod
    def create_customs_track(
        db: Session,
        payload: CustomsInvoiceTrackCreate,
        created_by: str = "SYSTEM",
    ) -> CargoXCustomsInvoiceTrack:
        """إنشاء وحفظ نسخة جمركية مستقلة في DB."""
        file = db.query(ImportFile).filter(
            ImportFile.import_file_id == payload.import_file_id
        ).first()
        if not file:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"ملف الاستيراد برقم {payload.import_file_id} غير موجود.",
            )

        # تشغيل محرك الاستخراج
        ext_req = ExtractionRequest(
            mode=payload.extraction_mode,
            grouping_mode=payload.grouping_mode,
            invoice_filter=payload.invoice_filter,
        )
        extraction = CargoXExtractionEngine.extract(db, payload.import_file_id, ext_req)

        # بناء الـ track code
        existing_count = (
            db.query(CargoXCustomsInvoiceTrack)
            .filter(CargoXCustomsInvoiceTrack.import_file_id == payload.import_file_id)
            .count()
        )
        track_code = f"CX-CUST-{file.import_file_code}-{existing_count + 1:03d}"

        # تجميع الأوزان والمجاميع من نتائج الاستخراج
        all_results_data = [r.payload.model_dump() for r in extraction.results]
        total_amount = sum(r.payload.total_amount for r in extraction.results)
        total_gross = sum(r.payload.gross_weight for r in extraction.results)
        total_net = sum(r.payload.net_weight for r in extraction.results)
        source_invs = [r.invoice_number for r in extraction.results if r.invoice_number]

        # بناء لقطة الباكينج ليست الجمركي (Customs Packing List Data)
        packing_items = []
        for res_idx, r in enumerate(extraction.results, start=1):
            for itm in r.payload.items:
                packing_items.append({
                    "package_no": f"PKG-{len(packing_items)+1:02d}",
                    "invoice_number": r.invoice_number,
                    "product_code": itm.product_code,
                    "hs_code": itm.hs_code,
                    "manufacturer": itm.manufacturer,
                    "description": itm.description,
                    "quantity": itm.quantity,
                    "qty_unit": itm.qty_unit,
                    "net_weight_kg": itm.net_weight_kg,
                    "gross_weight_kg": itm.gross_weight_kg,
                })

        packing_list_snapshot = {
            "track_code": track_code,
            "import_file_code": file.import_file_code,
            "acid_number": file.acid_number,
            "seller_name": file.supplier_name,
            "buyer_name": file.company_name,
            "total_packages": len(packing_items),
            "total_gross_weight": round(total_gross, 2),
            "total_net_weight": round(total_net, 2),
            "items": packing_items,
        }

        track = CargoXCustomsInvoiceTrack(
            track_code=track_code,
            import_file_id=payload.import_file_id,
            import_file_code=file.import_file_code,
            source_invoice_numbers=source_invs,
            extraction_mode=payload.extraction_mode,
            grouping_mode=payload.grouping_mode,
            customs_total_amount=round(total_amount, 2),
            customs_gross_weight=round(total_gross, 2),
            customs_net_weight=round(total_net, 2),
            customs_packages_count=len(packing_items),
            line_items_count=extraction.total_line_items,
            customs_invoice_data=all_results_data if len(all_results_data) > 1 else (all_results_data[0] if all_results_data else {}),
            customs_packing_list_data=packing_list_snapshot,
            status="DRAFT",
            notes=payload.notes,
            created_by=created_by,
            updated_by=created_by,
        )
        db.add(track)
        db.commit()
        db.refresh(track)
        return track

    @staticmethod
    def update_customs_track(
        db: Session,
        track_id: int,
        payload_dict: Dict,
        updated_by: str = "SYSTEM",
    ) -> CargoXCustomsInvoiceTrack:
        """تحديث بيانات المسار الجمركي (الحالة، الملاحظات، المجاميع)."""
        track = db.query(CargoXCustomsInvoiceTrack).filter(
            CargoXCustomsInvoiceTrack.track_id == track_id,
            CargoXCustomsInvoiceTrack.is_active.is_(True),
        ).first()
        if not track:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"المسار الجمركي رقم {track_id} غير موجود.",
            )

        for field in [
            "status", "notes", "customs_total_amount", "customs_gross_weight",
            "customs_net_weight", "customs_packages_count", "customs_invoice_data",
            "customs_packing_list_data"
        ]:
            if field in payload_dict and payload_dict[field] is not None:
                setattr(track, field, payload_dict[field])

        track.updated_by = updated_by
        track.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(track)
        return track

    @staticmethod
    def delete_customs_track(
        db: Session,
        track_id: int,
        deleted_by: str = "SYSTEM",
    ) -> bool:
        """حذف منطقي (Soft Delete) للمسار الجمركي."""
        track = db.query(CargoXCustomsInvoiceTrack).filter(
            CargoXCustomsInvoiceTrack.track_id == track_id,
            CargoXCustomsInvoiceTrack.is_active.is_(True),
        ).first()
        if not track:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"المسار الجمركي رقم {track_id} غير موجود.",
            )

        track.is_active = False
        track.updated_by = deleted_by
        track.updated_at = datetime.now(timezone.utc)
        db.commit()
        return True

    # -------------------------------------------------------------------------
    # Private Helpers
    # -------------------------------------------------------------------------

    @staticmethod
    def _load_entities(db: Session, file: ImportFile):
        company = None
        if file.company_id:
            company = db.query(ImportCompany).filter(ImportCompany.company_id == file.company_id).first()
        supplier = None
        if file.supplier_id:
            supplier = db.query(Supplier).filter(Supplier.supplier_id == file.supplier_id).first()
        pos = (
            db.query(PurchaseOrder)
            .filter(PurchaseOrder.import_file_id == file.import_file_id, PurchaseOrder.is_active.is_(True))
            .all()
        )
        return company, supplier, pos

    @staticmethod
    def _load_reconciled_session(db: Session, import_file_id: int):
        return (
            db.query(POPackingReconciliationSession)
            .filter(
                POPackingReconciliationSession.import_file_id == import_file_id,
                POPackingReconciliationSession.is_active.is_(True),
            )
            .order_by(POPackingReconciliationSession.session_id.desc())
            .first()
        )

    @staticmethod
    def _resolve_invoice_number(file: ImportFile, pos: list) -> Optional[str]:
        if file.invoices_data and isinstance(file.invoices_data, list) and len(file.invoices_data) > 0:
            first_inv = file.invoices_data[0]
            if isinstance(first_inv, dict):
                n = first_inv.get("invoice_number") or first_inv.get("invoice_no")
                if n:
                    return n
        if pos:
            po = pos[0]
            if po.proforma_invoice_number:
                return po.proforma_invoice_number
        return file.pi_number or f"INV-{file.import_file_code}"

    @staticmethod
    def _resolve_weights(file: ImportFile, pos: list):
        total_gross = 0.0
        total_net = 0.0
        weight_uom = "KGM"
        for po in pos:
            po_gw = float(po.total_gross_weight_kg or 0)
            po_nw = float(po.total_net_weight_kg or 0)
            if po_gw > 0:
                total_gross += po_gw
                total_net += po_nw
                if po.packing_list_items:
                    for pl in po.packing_list_items:
                        if pl.weight_unit:
                            weight_uom = pl.weight_unit
                            break
            elif po.packing_list_items:
                pl_g = sum(float(pl.total_gross_weight_kg or 0) for pl in po.packing_list_items)
                pl_n = sum(float(pl.total_net_weight_kg or 0) for pl in po.packing_list_items)
                if pl_g > 0:
                    total_gross += pl_g
                if pl_n > 0:
                    total_net += pl_n
                for pl in po.packing_list_items:
                    if pl.weight_unit:
                        weight_uom = pl.weight_unit
                        break
        if total_gross == 0 and file.packing_lists_data and isinstance(file.packing_lists_data, list):
            for pld in file.packing_lists_data:
                if isinstance(pld, dict):
                    total_gross += float(pld.get("total_gross_weight_kg") or pld.get("gross_weight") or 0.0)
                    total_net += float(pld.get("total_net_weight_kg") or pld.get("net_weight") or 0.0)
                    u = pld.get("weight_unit") or pld.get("weight_uom")
                    if u:
                        weight_uom = u
                        break
        if total_gross == 0:
            total_gross = float(getattr(file, "gross_weight_kg", 0.0) or 0.0)
        if total_net == 0:
            total_net = float(getattr(file, "net_weight_kg", 0.0) or 0.0)
        weight_uom = normalize_cargox_weight_unit(weight_uom)
        return round(total_gross, 2), round(total_net, 2), weight_uom

    @staticmethod
    def _resolve_per_invoice_weights(file: ImportFile, pos: list, inv_no: str, inv_items: list, all_invoices: dict):
        """حساب الأوزان النسبية لكل فاتورة بناءً على حصتها من إجمالي الكميات."""
        total_gross, total_net, weight_uom = CargoXExtractionEngine._resolve_weights(file, pos)
        all_qty = sum(r["quantity"] for invs in all_invoices.values() for r in invs)
        inv_qty = sum(r["quantity"] for r in inv_items)
        if all_qty > 0 and total_gross > 0:
            ratio = inv_qty / all_qty
            return round(total_gross * ratio, 2), round(total_net * ratio, 2), weight_uom
        return total_gross, total_net, weight_uom

    @staticmethod
    def _collect_invoices_raw(
        file: ImportFile,
        pos: list,
        reconciled_session,
        supplier,
        request: ExtractionRequest,
    ) -> Dict[str, List[Dict]]:
        """
        تجميع البنود الخام مُنظَّمة حسب رقم الفاتورة.
        يُرجع: { invoice_number: [raw_item_dict, ...] }
        """
        invoices_dict: Dict[str, List[Dict]] = defaultdict(list)

        country_fallback = "CN"
        supplier_name_fallback = (
            getattr(supplier, "company_name", None)
            or getattr(file, "supplier_name", None)
            or "Manufacturer"
        )
        if supplier:
            country_fallback = (
                getattr(supplier, "foreign_exporter_country_code", None)
                or getattr(supplier, "foreign_exporter_country", None)
                or "CN"
            )

        total_resolved_gross, total_resolved_net, resolved_weight_uom = CargoXExtractionEngine._resolve_weights(file, pos)

        # مصدر 1: reconciled session
        reconciled_items = (
            getattr(reconciled_session, "reconciled_invoice_items", None)
            or getattr(reconciled_session, "reconciled_packing_items", None)
            or getattr(reconciled_session, "matched_items_data", None)
        )
        if reconciled_items:
            rec_total_qty = sum(
                float(it.get("final_quantity") or it.get("actual_quantity") or it.get("po_quantity") or it.get("initial_quantity") or 1.0)
                for it in reconciled_items
            ) or 1.0
            raw_sum_gross = sum(
                float(it.get("final_gross_weight_kg") or it.get("gross_weight") or it.get("initial_gross_weight_kg") or 0.0)
                for it in reconciled_items
            )
            raw_sum_net = sum(
                float(it.get("final_net_weight_kg") or it.get("net_weight") or it.get("initial_net_weight_kg") or 0.0)
                for it in reconciled_items
            )

            use_proportional_weight = False
            unit_gross_rate = 0.0
            unit_net_rate = 0.0
            if total_resolved_gross > 0 and (raw_sum_gross == 0 or raw_sum_gross < total_resolved_gross * 0.5):
                use_proportional_weight = True
                unit_gross_rate = total_resolved_gross / rec_total_qty
                unit_net_rate = total_resolved_net / rec_total_qty if total_resolved_net > 0 else 0.0

            po_items = [pi for p in pos for pi in p.line_items] if pos else []
            po_by_id = {pi.item_id: pi for pi in po_items if pi.item_id}
            po_by_code = {pi.item_code: pi for pi in po_items if pi.item_code}

            for raw_item in reconciled_items:
                inv_no = raw_item.get("invoice_number") or CargoXExtractionEngine._resolve_invoice_number(file, pos)
                qty = float(raw_item.get("final_quantity") or raw_item.get("actual_quantity") or raw_item.get("po_quantity") or raw_item.get("initial_quantity") or 1.0)
                if use_proportional_weight:
                    gw = qty * unit_gross_rate
                    nw = qty * unit_net_rate
                else:
                    item_raw_gw = float(raw_item.get("final_gross_weight_kg") or raw_item.get("gross_weight") or raw_item.get("initial_gross_weight_kg") or 0.0)
                    item_raw_nw = float(raw_item.get("final_net_weight_kg") or raw_item.get("net_weight") or raw_item.get("initial_net_weight_kg") or 0.0)
                    gw = item_raw_gw
                    nw = item_raw_nw

                pi = po_by_id.get(raw_item.get("po_item_id")) or po_by_code.get(raw_item.get("item_code"))
                desc = (pi.main_description if pi and pi.main_description else None) or raw_item.get("main_description") or raw_item.get("item_name") or raw_item.get("description") or "Imported Goods"
                uom = (pi.unit_of_measure if pi and pi.unit_of_measure else None) or raw_item.get("unit_of_measure") or raw_item.get("unit") or "PCS"
                hs_val = raw_item.get("hs_code") or (pi.tariff.hs_code if pi and hasattr(pi, "tariff") and pi.tariff else "940310")

                invoices_dict[inv_no].append({
                    "item_code": raw_item.get("item_code"),
                    "manufacturer": raw_item.get("manufacturer") or supplier_name_fallback,
                    "brand_name": raw_item.get("brand_name") or "Standard",
                    "model": raw_item.get("model") or "Standard",
                    "hs_code": hs_val,
                    "description": desc,
                    "quantity": qty,
                    "qty_unit": uom,
                    "unit_price": float(raw_item.get("final_unit_price") or raw_item.get("unit_price") or 0.0),
                    "country_of_origin": raw_item.get("country_of_origin") or country_fallback,
                    "gross_weight_kg": gw,
                    "net_weight_kg": nw,
                    "weight_unit": resolved_weight_uom,
                    "invoice_number": inv_no,
                })
            return dict(invoices_dict)

        # مصدر 2: PO line items (مع دعم invoice_number على البند)
        if pos:
            for po in pos:
                if not po.line_items:
                    continue
                # استخلاص أوزان كل PO
                po_total_gross = float(po.total_gross_weight_kg or 0)
                po_total_net = float(po.total_net_weight_kg or 0)
                if po.packing_list_items:
                    po_total_gross = sum(float(pl.total_gross_weight_kg or 0) for pl in po.packing_list_items)
                    po_total_net = sum(float(pl.total_net_weight_kg or 0) for pl in po.packing_list_items)
                po_total_qty = sum(float(pi.quantity) for pi in po.line_items) or 1.0
                unit_gross_rate = po_total_gross / po_total_qty if po_total_gross > 0 else 0.0
                unit_net_rate = po_total_net / po_total_qty if po_total_net > 0 else 0.0

                for pi in po.line_items:
                    hs_code_val = "940310"
                    if hasattr(pi, "tariff") and pi.tariff and pi.tariff.hs_code:
                        hs_code_val = pi.tariff.hs_code
                    qty = float(pi.quantity)
                    inv_no = (
                        getattr(pi, "invoice_number", None)
                        or po.proforma_invoice_number
                        or file.pi_number
                        or f"INV-{file.import_file_code}"
                    )
                    if request.invoice_filter and inv_no != request.invoice_filter:
                        continue
                    invoices_dict[inv_no].append({
                        "item_code": pi.item_code,
                        "manufacturer": getattr(pi, "manufacturer", None) or getattr(po, "supplier_name", None) or supplier_name_fallback,
                        "brand_name": getattr(pi, "brand_name", None) or "Standard",
                        "model": getattr(pi, "model", None) or "Standard",
                        "hs_code": hs_code_val,
                        "description": pi.main_description or pi.description_en or pi.description_ar or "Imported Goods",
                        "quantity": qty,
                        "qty_unit": pi.unit_of_measure or "PCS",
                        "unit_price": float(getattr(pi, "customs_unit_price", None) or pi.unit_price),
                        "country_of_origin": pi.country_of_origin or country_fallback,
                        "gross_weight_kg": qty * unit_gross_rate if unit_gross_rate > 0 else float(pi.gross_weight_kg or 0),
                        "net_weight_kg": qty * unit_net_rate if unit_net_rate > 0 else float(pi.net_weight_kg or 0),
                        "weight_unit": resolved_weight_uom,
                        "invoice_number": inv_no,
                    })

        if not invoices_dict:
            inv_no = CargoXExtractionEngine._resolve_invoice_number(file, pos)
            invoices_dict[inv_no].append({
                "item_code": "ITEM-001",
                "manufacturer": supplier_name_fallback,
                "brand_name": "Standard",
                "model": "Standard",
                "hs_code": "940310",
                "description": "Standard Commercial Goods",
                "quantity": 1.0,
                "qty_unit": "SET",
                "unit_price": float(getattr(file, "estimated_cost", 0) or 1000.0),
                "country_of_origin": country_fallback,
                "gross_weight_kg": 100.0,
                "net_weight_kg": 90.0,
                "weight_unit": resolved_weight_uom,
                "invoice_number": inv_no,
            })

        return dict(invoices_dict)

    @staticmethod
    def _group_items(
        raw_items: List[Dict],
        grouping_mode: str,
        extraction_mode: str,
    ) -> List[StandardInvoiceLineItem]:
        """
        تجميع البنود حسب grouping_mode:
        - by_hs_code:     سطر واحد لكل HS Code مع متوسط سعر موزون
        - by_price_group: سطر لكل (HS Code, unit_price) — أسعار مختلفة = سطور مختلفة
        - flat:           كل سطر منفصل
        يُراعي extraction_mode:
        - "all_detailed" / "per_invoice_detailed" → يستخدم flat بغض النظر عن grouping_mode
        """
        # الـ detailed modes تفرض flat
        if "detailed" in extraction_mode:
            grouping_mode = "flat"

        if grouping_mode == "flat":
            items = []
            for idx, r in enumerate(raw_items, start=1):
                qty = r["quantity"]
                price = r["unit_price"]
                items.append(StandardInvoiceLineItem(
                    index=idx,
                    product_code=r.get("item_code") or f"ITEM-{idx:03d}",
                    manufacturer=r.get("manufacturer") or "Manufacturer",
                    brand_name=r.get("brand_name") or "Standard",
                    model=r.get("model") or "Standard",
                    hs_code=r["hs_code"],
                    country_of_origin=r["country_of_origin"],
                    description=r["description"],
                    quantity=round(qty, 2),
                    qty_unit=r["qty_unit"],
                    unit_price=round(price, 4),
                    unit_price_basis=r["qty_unit"],
                    gross_weight_kg=round(r["gross_weight_kg"], 2),
                    net_weight_kg=round(r["net_weight_kg"], 2),
                    weight_unit=normalize_cargox_weight_unit(r.get("weight_unit")),
                    total_amount=round(qty * price, 2),
                ))
            return items

        # مفتاح التجميع
        def group_key(r):
            if grouping_mode == "by_price_group":
                return (r["hs_code"], round(r["unit_price"], 4))
            return (r["hs_code"],)  # by_hs_code

        grouped = OrderedDict()
        for r in raw_items:
            key = group_key(r)
            if key not in grouped:
                grouped[key] = {
                    "hs_code": r["hs_code"],
                    "item_codes": [],
                    "manufacturers": [],
                    "descriptions": [],
                    "total_qty": 0.0,
                    "qty_unit": r["qty_unit"],
                    "weighted_sum": 0.0,  # Σ(qty × price)
                    "total_gross": 0.0,
                    "total_net": 0.0,
                    "weight_unit": normalize_cargox_weight_unit(r.get("weight_unit")),
                    "country_of_origin": r["country_of_origin"],
                }
            qty = r["quantity"]
            price = r["unit_price"]
            if r.get("item_code") and r["item_code"] not in grouped[key]["item_codes"]:
                grouped[key]["item_codes"].append(r["item_code"])
            if r.get("manufacturer") and r["manufacturer"] not in grouped[key]["manufacturers"]:
                grouped[key]["manufacturers"].append(r["manufacturer"])
            if r["description"] and r["description"] not in grouped[key]["descriptions"]:
                grouped[key]["descriptions"].append(r["description"])
            grouped[key]["total_qty"] += qty
            grouped[key]["weighted_sum"] += qty * price  # للـ weighted average
            grouped[key]["total_gross"] += r["gross_weight_kg"]
            grouped[key]["total_net"] += r["net_weight_kg"]

        items = []
        for idx, (key, grp) in enumerate(grouped.items(), start=1):
            tot_qty = grp["total_qty"]
            # Weighted Average Price = Σ(qty_i × price_i) / Σ(qty_i)
            avg_price = round(grp["weighted_sum"] / tot_qty, 4) if tot_qty > 0 else 0.0
            tot_amt = round(tot_qty * avg_price, 2)
            code_str = grp["item_codes"][0] if grp["item_codes"] else f"ITEM-{idx:03d}"
            mfg_str = grp["manufacturers"][0] if grp.get("manufacturers") else "Manufacturer"
            desc_str = grp["descriptions"][0] if grp["descriptions"] else "Imported Goods"
            items.append(StandardInvoiceLineItem(
                index=idx,
                product_code=code_str,
                manufacturer=mfg_str,
                brand_name="Standard",
                model="Standard",
                hs_code=grp["hs_code"],
                country_of_origin=grp["country_of_origin"],
                description=desc_str,
                quantity=round(tot_qty, 2),
                qty_unit=grp["qty_unit"],
                unit_price=avg_price,
                unit_price_basis=grp["qty_unit"],
                gross_weight_kg=round(grp["total_gross"], 2),
                net_weight_kg=round(grp["total_net"], 2),
                weight_unit=normalize_cargox_weight_unit(grp.get("weight_unit")),
                total_amount=tot_amt,
            ))
        return items

    @staticmethod
    def _build_base_payload(file: ImportFile, company, supplier) -> Dict:
        seller_addr = supplier.address if supplier else ""
        seller_country = (supplier.foreign_exporter_country_code if supplier else None) or "CN"
        seller_city_code = resolve_city_code(seller_addr, seller_country)

        return {
            "seller_name": supplier.company_name if supplier else file.supplier_name,
            "seller_address": seller_addr,
            "seller_city": "",
            "seller_city_code": seller_city_code,
            "seller_country_code": seller_country,
            "seller_tax_id": supplier.foreign_exporter_id if supplier else "",
            "seller_phone": supplier.phone if supplier else "",
            "seller_fax": supplier.fax if supplier else "",
            "seller_email": supplier.email if supplier else "",
            "seller_website": supplier.website if supplier else "",
            "buyer_name": company.importer_name if company else file.company_name,
            "buyer_address": company.address if company else "",
            "buyer_tax_id": (company.vat_id or company.importer_id) if company else "",
            "acid_number": file.acid_number or "PENDING",
            "invoice_type": "Commercial Invoice",
            "origin_port": file.port_of_loading or "Origin Port",
            "destination_port": file.port_of_discharge or "EGALY",
            "currency_code": file.estimated_cost_currency or "EUR",
            "incoterm": file.incoterm_code or "EXW",
        }

    @staticmethod
    def _build_payload(
        base: Dict,
        items: List[StandardInvoiceLineItem],
        total_gross: float,
        total_net: float,
        weight_uom: str,
        inv_number: Optional[str] = None,
        po_number: Optional[str] = None,
        po_date: Optional[str] = None,
    ) -> StandardInvoicePayload:
        subtotal = sum(i.total_amount for i in items)

        # معايرة وضمان مطابقة أوزان البنود للأوزان الإجمالية للشحنة/الفاتورة:
        # إذا كان هناك سطر واحد مجمع (بند واحد يمثل الـ HS Code)، يحمل 100% من إجمالي الوزن
        if items and total_gross > 0:
            if len(items) == 1:
                items[0].gross_weight_kg = round(total_gross, 2)
                items[0].net_weight_kg = round(total_net, 2)
            else:
                sum_items_gw = sum(i.gross_weight_kg for i in items)
                sum_items_nw = sum(i.net_weight_kg for i in items)
                # إذا كانت أوزان البنود لا تطابق إجمالي الفاتورة بدقة (مثل وجود فروق تقريب أو أوزان وحدات)
                if abs(sum_items_gw - total_gross) > 0.05 or abs(sum_items_nw - total_net) > 0.05:
                    total_qty = sum(i.quantity for i in items) or 1.0
                    running_gw = 0.0
                    running_nw = 0.0
                    for idx, item in enumerate(items):
                        if idx == len(items) - 1:
                            # السطر الأخير يأخذ المتبقي الدقيق لمنع أي فوارق تقريب
                            item.gross_weight_kg = round(total_gross - running_gw, 2)
                            item.net_weight_kg = round(total_net - running_nw, 2)
                        else:
                            ratio = (item.gross_weight_kg / sum_items_gw) if sum_items_gw > 0 else (item.quantity / total_qty)
                            item.gross_weight_kg = round(total_gross * ratio, 2)
                            item.net_weight_kg = round(total_net * ratio, 2)
                            running_gw += item.gross_weight_kg
                            running_nw += item.net_weight_kg

        return StandardInvoicePayload(
            **base,
            seller_contact_name="",
            buyer_contact_name="",
            buyer_phone="",
            buyer_fax="",
            buyer_email="",
            invoice_number=inv_number,
            invoice_date=po_date or datetime.now(timezone.utc).strftime("%Y-%m-%d"),
            purchase_order_number=po_number,
            purchase_order_date=po_date,
            gross_weight=round(total_gross, 2),
            net_weight=round(total_net, 2),
            weight_unit=normalize_cargox_weight_unit(weight_uom),
            items=items,
            subtotal=round(subtotal, 2),
            freight_cost=0.0,
            insurance_cost=0.0,
            other_costs=0.0,
            total_amount=round(subtotal, 2),
        )
