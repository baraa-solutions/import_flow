import json
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.purchase_orders.model import PurchaseOrder, POShipmentAllocation, POLineItem
from modules.purchase_orders.repository import PurchaseOrderRepository
from modules.purchase_orders.schemas import (
    ClonePurchaseOrderRequest,
    POLineItemCreate,
    POLineItemResponse,
    PackingListItemCreate,
    PackingListItemResponse,
    PackingListSummaryByHSCode,
    PackingListValidationReport,
    PalletPlanItem,
    PurchaseOrderCreate,
    PurchaseOrderResponse,
    PurchaseOrderUpdate,
    POShipmentAllocationCreate,
    POShipmentAllocationResponse,
    POLineItemBalanceItem,
    POBalanceSummaryResponse,
)
from modules.purchase_orders.validators import PurchaseOrderValidator



PO_REFERENCE_MAX_LENGTH = 200
COPY_CODE_SUFFIX = "-COPY"


def _copy_reference(reference: Optional[str]) -> Optional[str]:
    """Default clone reference: ``<reference>-COPY``; the base is truncated so the result fits the column."""
    if not reference:
        return None
    base = reference[: PO_REFERENCE_MAX_LENGTH - len(COPY_CODE_SUFFIX)]
    return f"{base}{COPY_CODE_SUFFIX}"


class PurchaseOrderService:

    def __init__(self, db: Session):
        self.db = db
        self.repo = PurchaseOrderRepository(db)
        self.validator = PurchaseOrderValidator(db)

    def get_packing_list_report(self, po_id: int) -> PackingListValidationReport:
        po = self.repo.get_by_id(po_id)
        if not po:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Purchase Order with ID {po_id} not found.",
            )

        errors = []
        warnings = []
        hs_map = {}

        tot_pcs = 0.0
        tot_pkg = 0.0
        tot_net = 0.0
        tot_gross = 0.0
        tot_cbm = 0.0
        tot_chg = 0.0

        if not po.packing_list_items:
            warnings.append("No packing list items recorded for this purchase order.")

        for idx, item in enumerate(po.packing_list_items, start=1):
            q_pcs = float(item.qty_pcs or 0.0)
            q_pkg = float(item.qty_pkg or 0.0)
            net_u = float(item.net_weight_unit_kg or 0.0)
            gross_u = float(item.gross_weight_unit_kg or 0.0)
            l_cm = float(item.length_cm or 0.0)
            w_cm = float(item.width_cm or 0.0)
            h_cm = float(item.height_cm or 0.0)

            t_net = float(item.total_net_weight_kg or 0.0)
            if t_net <= 0 and net_u > 0 and q_pkg > 0:
                t_net = q_pkg * net_u
            t_gross = float(item.total_gross_weight_kg or 0.0)
            if t_gross <= 0 and gross_u > 0 and q_pkg > 0:
                t_gross = q_pkg * gross_u
            t_cbm = float(item.total_cbm or 0.0)
            chg_wt = float(item.chargeable_weight_kg or 0.0)

            # Validation Rule: Gross Weight >= Net Weight
            if gross_u < net_u:
                errors.append(f"Item #{idx} ({item.item_code}): Gross weight per unit ({gross_u} kg) cannot be less than Net weight ({net_u} kg).")

            # Validation Rule: No negative weights
            if net_u < 0 or gross_u < 0:
                errors.append(f"Item #{idx} ({item.item_code}): Unit weights cannot be negative.")

            # Validation Rule: Dimensions zero warning
            if l_cm <= 0 or w_cm <= 0 or h_cm <= 0:
                warnings.append(f"Item #{idx} ({item.item_code}): Package dimensions missing or zero; CBM cannot be computed accurately.")

            tot_pcs += q_pcs
            tot_pkg += q_pkg
            tot_net += t_net
            tot_gross += t_gross
            tot_cbm += t_cbm
            tot_chg += chg_wt

            hs = item.hs_code or "UNSPECIFIED"
            if hs not in hs_map:
                hs_map[hs] = {
                    "hs_code": hs,
                    "qty_pcs": 0.0,
                    "qty_pkg": 0.0,
                    "total_net_weight_kg": 0.0,
                    "total_gross_weight_kg": 0.0,
                    "total_cbm": 0.0,
                }
            hs_map[hs]["qty_pcs"] += q_pcs
            hs_map[hs]["qty_pkg"] += q_pkg
            hs_map[hs]["total_net_weight_kg"] += t_net
            hs_map[hs]["total_gross_weight_kg"] += t_gross
            hs_map[hs]["total_cbm"] += t_cbm

        if abs(tot_net - round(tot_net)) < 0.005:
            tot_net = float(round(tot_net))
        if abs(tot_gross - round(tot_gross)) < 0.005:
            tot_gross = float(round(tot_gross))

        for hs_val in hs_map.values():
            if abs(hs_val["total_net_weight_kg"] - round(hs_val["total_net_weight_kg"])) < 0.005:
                hs_val["total_net_weight_kg"] = float(round(hs_val["total_net_weight_kg"]))
            if abs(hs_val["total_gross_weight_kg"] - round(hs_val["total_gross_weight_kg"])) < 0.005:
                hs_val["total_gross_weight_kg"] = float(round(hs_val["total_gross_weight_kg"]))

        # Invoice HS Code Map
        invoice_hs_map = {}
        po_total_pcs = 0.0
        for l_item in po.line_items:
            l_qty = float(l_item.quantity or 0.0)
            po_total_pcs += l_qty
            l_hs = l_item.tariff.hs_code if (l_item.tariff and l_item.tariff.hs_code) else "UNASSIGNED"
            invoice_hs_map[l_hs] = invoice_hs_map.get(l_hs, 0.0) + l_qty

        # Detect Missing HS Codes
        missing_hs_in_packing = []
        if po.line_items and po.packing_list_items:
            for inv_hs in invoice_hs_map.keys():
                if inv_hs not in hs_map:
                    missing_hs_in_packing.append(inv_hs)
                    warnings.append(f"HS Code '{inv_hs}' exists in Commercial Invoice but is missing from Packing List.")

        missing_hs_in_invoice = []
        if po.line_items and po.packing_list_items:
            for pkg_hs in hs_map.keys():
                if pkg_hs not in invoice_hs_map:
                    missing_hs_in_invoice.append(pkg_hs)
                    warnings.append(f"HS Code '{pkg_hs}' exists in Packing List but is missing from Commercial Invoice.")

        # Populate all combined HS codes in summary
        all_hs_keys = set(hs_map.keys()).union(set(invoice_hs_map.keys()))
        has_qty_mismatch = False

        hs_summary = []
        for hs_key in sorted(all_hs_keys):
            pkg_data = hs_map.get(hs_key, {
                "hs_code": hs_key,
                "qty_pcs": 0.0,
                "qty_pkg": 0.0,
                "total_net_weight_kg": 0.0,
                "total_gross_weight_kg": 0.0,
                "total_cbm": 0.0,
            })
            inv_qty = invoice_hs_map.get(hs_key, 0.0)
            pkg_qty = pkg_data["qty_pcs"]
            diff = pkg_qty - inv_qty
            matched = abs(diff) < 0.001

            if not matched and po.line_items and po.packing_list_items:
                has_qty_mismatch = True
                warnings.append(f"HS Code '{hs_key}': Packing List Qty ({pkg_qty}) differs from Invoice Qty ({inv_qty}) [Diff: {diff:+.2f}].")

            hs_summary.append(
                PackingListSummaryByHSCode(
                    hs_code=pkg_data["hs_code"],
                    qty_pcs=pkg_data["qty_pcs"],
                    qty_pkg=pkg_data["qty_pkg"],
                    total_net_weight_kg=pkg_data["total_net_weight_kg"],
                    total_gross_weight_kg=pkg_data["total_gross_weight_kg"],
                    total_cbm=pkg_data["total_cbm"],
                    invoice_pcs=inv_qty,
                    discrepancy_pcs=diff,
                    is_matched=matched,
                )
            )

        # Check total PCS vs PO Invoice Line Items
        total_qty_mismatch = False
        if po.line_items and po.packing_list_items and abs(tot_pcs - po_total_pcs) > 0.01:
            total_qty_mismatch = True
            warnings.append(f"Total Quantity Mismatch: Packing List total PCS ({tot_pcs}) differs from Invoice total PCS ({po_total_pcs}) [Diff: {tot_pcs - po_total_pcs:+.2f}].")

        has_discrepancy = bool(
            missing_hs_in_packing
            or missing_hs_in_invoice
            or has_qty_mismatch
            or total_qty_mismatch
        )

        return PackingListValidationReport(
            is_valid=len(errors) == 0,
            has_discrepancy=has_discrepancy,
            errors=errors,
            warnings=warnings,
            total_items=len(po.packing_list_items),
            total_pcs=tot_pcs,
            total_pkg=tot_pkg,
            total_net_weight_kg=tot_net,
            total_gross_weight_kg=tot_gross,
            total_cbm=tot_cbm,
            chargeable_weight_kg=tot_chg,
            total_invoice_pcs=po_total_pcs,
            total_packing_pcs=tot_pcs,
            missing_hs_in_packing=missing_hs_in_packing,
            missing_hs_in_invoice=missing_hs_in_invoice,
            hs_code_summary=hs_summary,
        )


    def _to_response(self, po: PurchaseOrder) -> PurchaseOrderResponse:
        items_resp = []
        for item in po.line_items:
            items_resp.append(
                POLineItemResponse(
                    item_id=item.item_id,
                    po_id=item.po_id,
                    item_code=item.item_code,
                    main_description=item.main_description,
                    description_ar=item.description_ar,
                    description_en=item.description_en,
                    country_of_origin=item.country_of_origin,
                    tariff_id=item.tariff_id,
                    quantity=float(item.quantity),
                    unit_of_measure=item.unit_of_measure,
                    unit_price=float(item.unit_price),
                    total_price=float(item.total_price),
                    cbm_per_unit=float(item.cbm_per_unit),
                    total_cbm=float(item.total_cbm),
                    gross_weight_kg=float(item.gross_weight_kg),
                    net_weight_kg=float(item.net_weight_kg),
                    created_at=item.created_at,
                    hs_code=item.tariff.hs_code if item.tariff else None,
                    duty_rate=float(item.tariff.customs_duty_rate) if item.tariff and item.tariff.customs_duty_rate is not None else None,
                    vat_rate=float(item.tariff.vat_rate) if item.tariff and item.tariff.vat_rate is not None else None,
                )
            )

        packing_items_resp = []
        for pitem in po.packing_list_items:
            packing_items_resp.append(
                PackingListItemResponse(
                    packing_item_id=pitem.packing_item_id,
                    po_id=pitem.po_id,
                    hs_code=pitem.hs_code,
                    item_code=pitem.item_code,
                    main_description=getattr(pitem, "main_description", None),
                    description=getattr(pitem, "description", None),
                    qty_pcs=float(pitem.qty_pcs),
                    qty_pkg=float(pitem.qty_pkg),
                    package_type=pitem.package_type,
                    weight_unit=getattr(pitem, "weight_unit", "KGM") or "KGM",
                    length_cm=float(pitem.length_cm or 0.0),
                    width_cm=float(pitem.width_cm or 0.0),
                    height_cm=float(pitem.height_cm or 0.0),
                    net_weight_unit_kg=float(pitem.net_weight_unit_kg),
                    gross_weight_unit_kg=float(pitem.gross_weight_unit_kg),
                    total_net_weight_kg=float(pitem.total_net_weight_kg),
                    total_gross_weight_kg=float(pitem.total_gross_weight_kg),
                    total_cbm=float(pitem.total_cbm),
                    chargeable_weight_kg=float(pitem.chargeable_weight_kg),
                    is_stackable=bool(pitem.is_stackable) if pitem.is_stackable is not None else True,
                    created_at=pitem.created_at,
                )
            )

        import_file_code = None
        if hasattr(po, "import_file") and po.import_file:
            import_file_code = getattr(po.import_file, "import_file_code", None) or getattr(po.import_file, "custom_file_number", None)

        return PurchaseOrderResponse(
            po_id=po.po_id,
            po_number=po.po_number,
            version=getattr(po, "version", 1) or 1,
            po_reference=getattr(po, "po_reference", None),
            import_file_id=po.import_file_id,
            import_file_code=import_file_code,
            proforma_invoice_number=po.proforma_invoice_number,
            country_of_origin=po.country_of_origin,
            project_id=po.project_id,
            company_id=po.company_id,
            supplier_id=po.supplier_id,
            incoterm_id=po.incoterm_id,
            currency_id=po.currency_id,
            order_date=po.order_date,
            expected_delivery_date=po.expected_delivery_date,
            exchange_rate=float(po.exchange_rate),
            payment_terms=po.payment_terms,
            total_amount_fob=float(po.total_amount_fob),
            total_cbm=float(po.total_cbm),
            total_gross_weight_kg=float(po.total_gross_weight_kg),
            total_net_weight_kg=float(po.total_net_weight_kg),
            total_packages_count=po.total_packages_count,
            pallet_count=getattr(po, "pallet_count", 0) or 0,
            pallet_type=getattr(po, "pallet_type", "Euro Pallet (120x80)") or "Euro Pallet (120x80)",
            is_pallet_stackable=bool(getattr(po, "is_pallet_stackable", False)),
            pallet_length_cm=float(getattr(po, "pallet_length_cm", 120.0) or 120.0),
            pallet_width_cm=float(getattr(po, "pallet_width_cm", 80.0) or 80.0),
            pallet_height_cm=float(getattr(po, "pallet_height_cm", 150.0) or 150.0),
            pallet_plan=(
                [PalletPlanItem(**p) if isinstance(p, dict) else p for p in json.loads(po.pallet_plan)]
                if getattr(po, "pallet_plan", None) and isinstance(po.pallet_plan, str)
                else (po.pallet_plan if isinstance(getattr(po, "pallet_plan", None), list) else [])
            ),
            status=po.status,
            notes=po.notes,
            is_active=po.is_active,
            created_at=po.created_at,
            updated_at=po.updated_at,
            project_name=po.project.project_name if po.project else None,
            company_name=po.company.importer_name if po.company else None,
            supplier_name=po.supplier.company_name if po.supplier else None,
            incoterm_code=po.incoterm.incoterm_code if po.incoterm else None,
            currency_code=po.currency.currency_code if po.currency else None,
            items=items_resp,
            packing_list_items=packing_items_resp,
        )

    def get_all(
        self,
        include_inactive: bool = False,
        status_filter: Optional[str] = None,
        project_id: Optional[int] = None,
        company_id: Optional[int] = None,
        supplier_id: Optional[int] = None,
        search: Optional[str] = None,
    ) -> List[PurchaseOrderResponse]:
        pos = self.repo.get_all(
            include_inactive=include_inactive,
            status_filter=status_filter,
            project_id=project_id,
            company_id=company_id,
            supplier_id=supplier_id,
            search=search,
        )
        return [self._to_response(po) for po in pos]

    def get_by_id(self, po_id: int) -> PurchaseOrderResponse:
        po = self.repo.get_by_id(po_id)
        if not po:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Purchase Order with ID {po_id} not found.",
            )
        return self._to_response(po)

    def _sync_import_file_po_link(self, import_file_id: int, po: PurchaseOrder):
        from modules.import_files.model import ImportFile
        import_file = self.db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
        if import_file:
            po_ids = list(import_file.po_ids or [])
            if po.po_id not in po_ids:
                po_ids.append(po.po_id)
                import_file.po_ids = po_ids
            if not import_file.po_number:
                import_file.po_number = po.po_number
            if not import_file.pi_number and po.proforma_invoice_number:
                import_file.pi_number = po.proforma_invoice_number
            self.db.commit()

    def _remove_import_file_po_link(self, import_file_id: int, po_id: int):
        from modules.import_files.model import ImportFile
        import_file = self.db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
        if import_file and import_file.po_ids:
            po_ids = [pid for pid in import_file.po_ids if pid != po_id]
            import_file.po_ids = po_ids
            self.db.commit()

    def create(self, data: PurchaseOrderCreate) -> PurchaseOrderResponse:
        self.validator.validate_foreign_keys(
            project_id=data.project_id,
            company_id=data.company_id,
            supplier_id=data.supplier_id,
            incoterm_id=data.incoterm_id,
            currency_id=data.currency_id,
            import_file_id=data.import_file_id,
        )
        if data.items:
            self.validator.validate_line_items(data.items)
        if data.po_number:
            self.validator.validate_po_number_unique(data.po_number)

        po = self.repo.create(data)
        if po.import_file_id:
            self._sync_import_file_po_link(po.import_file_id, po)

        return self._to_response(po)

    def update(self, po_id: int, data: PurchaseOrderUpdate, current_user_name: Optional[str] = None) -> PurchaseOrderResponse:
        po = self.repo.get_by_id(po_id)
        if not po:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Purchase Order with ID {po_id} not found.",
            )

        # Fail-fast Optimistic Concurrency Check
        submitted_version = getattr(data, "version", None)
        fresh_version = (
            self.db.query(PurchaseOrder.version)
            .filter(PurchaseOrder.po_id == po_id)
            .scalar()
        )
        current_version = fresh_version if fresh_version is not None else (getattr(po, "version", 1) or 1)
        if submitted_version is not None and submitted_version != current_version:
            from modules.common.concurrency import ConcurrencyConflictException, log_concurrency_conflict
            log_concurrency_conflict(
                db=self.db,
                entity_name="PurchaseOrder",
                record_id=po.po_id,
                current_version=current_version,
                submitted_version=submitted_version,
                attempted_by=current_user_name,
                details=f"Conflict detected while updating PO #{po.po_number}",
            )
            raise ConcurrencyConflictException(
                entity="PurchaseOrder",
                record_id=po.po_id,
                current_version=current_version,
                submitted_version=submitted_version,
                updated_at=po.updated_at,
                updated_by=getattr(po, "updated_by", None),
            )

        p_id = data.project_id or po.project_id
        c_id = data.company_id or po.company_id
        s_id = data.supplier_id or po.supplier_id
        i_id = data.incoterm_id or po.incoterm_id
        cur_id = data.currency_id or po.currency_id
        f_id = data.import_file_id if data.import_file_id is not None else po.import_file_id

        self.validator.validate_foreign_keys(
            project_id=p_id,
            company_id=c_id,
            supplier_id=s_id,
            incoterm_id=i_id,
            currency_id=cur_id,
            import_file_id=f_id,
        )
        if data.items:
            self.validator.validate_line_items(data.items)

        old_file_id = po.import_file_id
        updated_po = self.repo.update(po, data, current_user_name=current_user_name)

        if updated_po.import_file_id:
            self._sync_import_file_po_link(updated_po.import_file_id, updated_po)
        if old_file_id and old_file_id != updated_po.import_file_id:
            self._remove_import_file_po_link(old_file_id, po_id)

        return self._to_response(updated_po)

    def soft_delete(self, po_id: int) -> PurchaseOrderResponse:
        po = self.repo.get_by_id(po_id)
        if not po:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Purchase Order with ID {po_id} not found.",
            )
        file_id = po.import_file_id
        deleted_po = self.repo.soft_delete(po)
        if file_id:
            self._remove_import_file_po_link(file_id, po_id)
        return self._to_response(deleted_po)

    def restore(self, po_id: int) -> PurchaseOrderResponse:
        po = self.repo.get_by_id(po_id)
        if not po:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Purchase Order with ID {po_id} not found.",
            )
        restored_po = self.repo.restore(po)
        if restored_po.import_file_id:
            self._sync_import_file_po_link(restored_po.import_file_id, restored_po)
        return self._to_response(restored_po)

    # =========================================================================
    # LOG-PART-004: Partial Shipments & PO Balance Ledger Engine
    # =========================================================================

    def allocate_shipment(self, po_id: int, data: POShipmentAllocationCreate) -> POShipmentAllocationResponse:
        """
        Allocates a partial shipment quantity to an active Purchase Order.
        Updates PO fulfillment status accordingly.
        """
        po = self.repo.get_by_id(po_id)
        if not po:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Purchase Order with ID {po_id} not found.",
            )

        if data.po_item_id:
            item = self.db.query(POLineItem).filter(
                POLineItem.item_id == data.po_item_id,
                POLineItem.po_id == po_id,
            ).first()
            if not item:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"البند رقم #{data.po_item_id} غير مرتبط بأمر الشراء #{po.po_number}.",
                )

        from datetime import datetime, timezone
        allocation = POShipmentAllocation(
            po_id=po_id,
            po_item_id=data.po_item_id,
            import_file_id=data.import_file_id,
            shipment_ref=data.shipment_ref.strip(),
            shipped_quantity=data.shipped_quantity,
            shipped_amount_fob=data.shipped_amount_fob,
            shipping_date=data.shipping_date or datetime.now(timezone.utc),
            status=data.status,
            notes=data.notes,
        )
        self.db.add(allocation)
        self.db.commit()
        self.db.refresh(allocation)

        # Trigger auto status update
        self._sync_po_fulfillment_status(po)

        return POShipmentAllocationResponse.model_validate(allocation)

    def _sync_po_fulfillment_status(self, po: PurchaseOrder):
        """Updates PO status based on total shipped vs ordered quantities."""
        total_ordered = sum(float(it.quantity or 0.0) for it in (po.line_items or []))
        allocations = self.db.query(POShipmentAllocation).filter(
            POShipmentAllocation.po_id == po.po_id
        ).all()
        total_shipped = sum(float(a.shipped_quantity or 0.0) for a in allocations)

        if total_ordered > 0:
            if total_shipped >= total_ordered:
                po.status = "Fully Shipped"
            elif total_shipped > 0:
                po.status = "Partially Shipped"
            self.db.commit()

    def compute_po_balance(self, po_id: int) -> POBalanceSummaryResponse:
        """
        LOG-PART-004: Computes the comprehensive remaining balance of a PO
        including ordered, shipped, and remaining quantities and amounts.
        """
        po = self.repo.get_by_id(po_id)
        if not po:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Purchase Order with ID {po_id} not found.",
            )

        allocations = self.db.query(POShipmentAllocation).filter(
            POShipmentAllocation.po_id == po_id
        ).order_by(POShipmentAllocation.shipping_date.desc()).all()

        line_items = po.line_items or []
        items_balance: List[POLineItemBalanceItem] = []

        total_ordered_qty = 0.0
        total_shipped_qty = 0.0
        total_ordered_fob = 0.0
        total_shipped_fob = 0.0

        for it in line_items:
            ord_q = float(it.quantity or 0.0)
            u_price = float(it.unit_price or 0.0)
            ord_fob = float(it.total_price or (ord_q * u_price))

            # Shipped qty for this item
            item_allocs = [a for a in allocations if a.po_item_id == it.item_id]
            shipped_q = sum(float(a.shipped_quantity or 0.0) for a in item_allocs)
            shipped_fob = sum(float(a.shipped_amount_fob or 0.0) for a in item_allocs)

            # If no item-level allocations, check if order has general allocations
            if not item_allocs and allocations and len(line_items) == 1:
                shipped_q = sum(float(a.shipped_quantity or 0.0) for a in allocations)
                shipped_fob = sum(float(a.shipped_amount_fob or 0.0) for a in allocations)

            rem_q = max(0.0, ord_q - shipped_q)
            rem_fob = max(0.0, ord_fob - shipped_fob)
            fulfillment = round((shipped_q / ord_q * 100.0) if ord_q > 0 else 0.0, 1)

            items_balance.append(
                POLineItemBalanceItem(
                    item_id=it.item_id,
                    item_code=it.item_code,
                    description_ar=it.description_ar,
                    ordered_qty=ord_q,
                    shipped_qty=shipped_q,
                    remaining_qty=rem_q,
                    unit_price=u_price,
                    ordered_amount_fob=ord_fob,
                    shipped_amount_fob=shipped_fob,
                    remaining_amount_fob=rem_fob,
                    fulfillment_percent=fulfillment,
                )
            )

            total_ordered_qty += ord_q
            total_shipped_qty += shipped_q
            total_ordered_fob += ord_fob
            total_shipped_fob += shipped_fob

        # If general allocations without items
        if not line_items and allocations:
            total_shipped_qty = sum(float(a.shipped_quantity or 0.0) for a in allocations)
            total_shipped_fob = sum(float(a.shipped_amount_fob or 0.0) for a in allocations)

        total_rem_qty = max(0.0, total_ordered_qty - total_shipped_qty)
        total_rem_fob = max(0.0, total_ordered_fob - total_shipped_fob)

        overall_percent = round(
            (total_shipped_qty / total_ordered_qty * 100.0) if total_ordered_qty > 0 else 0.0, 1
        )

        if overall_percent == 0:
            fulfillment_status = "Pending"
        elif overall_percent < 100:
            fulfillment_status = "Partially Shipped"
        elif overall_percent == 100:
            fulfillment_status = "Fully Shipped"
        else:
            fulfillment_status = "Over-Shipped"

        curr_code = "USD"
        if hasattr(po, "currency") and po.currency:
            curr_code = getattr(po.currency, "currency_code", "USD")

        summary_ar = (
            f"ميزان أمر الشراء #{po.po_number}: تم شحن {total_shipped_qty:,.0f} من إجمالي {total_ordered_qty:,.0f} وحدة "
            f"({overall_percent}% إنجاز توريد)، والمتبقي للتوريد {total_rem_qty:,.0f} وحدة "
            f"بقيمة تعاقدية متبقية {total_rem_fob:,.2f} {curr_code} عبر {len(allocations)} شحنات مجزأة."
        )

        return POBalanceSummaryResponse(
            po_id=po.po_id,
            po_number=po.po_number,
            total_ordered_qty=round(total_ordered_qty, 2),
            total_shipped_qty=round(total_shipped_qty, 2),
            total_remaining_qty=round(total_rem_qty, 2),
            total_ordered_amount_fob=round(total_ordered_fob, 2),
            total_shipped_amount_fob=round(total_shipped_fob, 2),
            total_remaining_amount_fob=round(total_rem_fob, 2),
            currency_code=curr_code,
            overall_fulfillment_percent=overall_percent,
            fulfillment_status=fulfillment_status,
            line_items_balance=items_balance,
            allocations=[POShipmentAllocationResponse.model_validate(a) for a in allocations],
            executive_summary_ar=summary_ar,
        )

    # =========================================================================
    # UX-CLONE-011: Universal Entity-Level Clone Engine for Purchase Orders
    # =========================================================================

    def clone_purchase_order(self, po_id: int, payload: ClonePurchaseOrderRequest) -> PurchaseOrderResponse:
        """
        UX-CLONE-011: Universal Entity-Level Clone for Purchase Orders.
        Preserves: company, supplier, project, incoterm, currency, exchange_rate, payment_terms, country_of_origin.
        Mandatory Resets:
          - po_id -> new PK autoincrement
          - po_number -> payload.new_po_number (validated unique)
          - po_reference -> payload.new_po_reference or original.po_reference
          - import_file_id -> None (cleared / unlinked from shipment)
          - status -> 'Draft' (forced to Draft)
          - order_date -> datetime.now(timezone.utc)
          - expected_delivery_date -> None
          - partial allocations -> reset / empty
          - items copied if copy_items (item_id reset)
          - packing_list_items copied if copy_packing_list (packing_item_id reset)
          - pallet_plan copied if copy_pallet_plan
        """
        original = self.repo.get_by_id(po_id)
        if not original:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"أمر الشراء الأصلي #{po_id} غير موجود.",
            )

        target_po_number = payload.new_po_number.strip().upper()
        self.validator.validate_po_number_unique(target_po_number)

        # Build items
        new_items: List[POLineItemCreate] = []
        if payload.copy_items and original.line_items:
            for it in original.line_items:
                new_items.append(
                    POLineItemCreate(
                        item_code=it.item_code,
                        main_description=it.main_description,
                        description_ar=it.description_ar,
                        description_en=it.description_en,
                        country_of_origin=it.country_of_origin,
                        tariff_id=it.tariff_id,
                        quantity=float(it.quantity or 1.0),
                        unit_of_measure=it.unit_of_measure or "PCS",
                        unit_price=float(it.unit_price or 0.0),
                        cbm_per_unit=float(it.cbm_per_unit or 0.0),
                        gross_weight_kg=float(it.gross_weight_kg or 0.0),
                        net_weight_kg=float(it.net_weight_kg or 0.0),
                    )
                )

        # Build packing list items
        new_packing_items: List[PackingListItemCreate] = []
        if payload.copy_packing_list and original.packing_list_items:
            for p in original.packing_list_items:
                new_packing_items.append(
                    PackingListItemCreate(
                        hs_code=p.hs_code,
                        item_code=p.item_code,
                        main_description=getattr(p, "main_description", None),
                        description=getattr(p, "description", None),
                        qty_pcs=float(p.qty_pcs or 1.0),
                        qty_pkg=float(p.qty_pkg or 1.0),
                        package_type=p.package_type or "Carton",
                        unit=getattr(p, "unit", "cm") or "cm",
                        weight_unit=getattr(p, "weight_unit", "KGM") or "KGM",
                        length_cm=float(p.length_cm or 0.0),
                        width_cm=float(p.width_cm or 0.0),
                        height_cm=float(p.height_cm or 0.0),
                        net_weight_unit_kg=float(p.net_weight_unit_kg or 0.0),
                        gross_weight_unit_kg=float(p.gross_weight_unit_kg or 0.0),
                        is_stackable=bool(p.is_stackable),
                        total_cbm=float(p.total_cbm or 0.0),
                        total_net_weight_kg=float(p.total_net_weight_kg or 0.0),
                        total_gross_weight_kg=float(p.total_gross_weight_kg or 0.0),
                    )
                )

        # Build pallet plan
        new_pallet_plan: List[PalletPlanItem] = []
        if payload.copy_pallet_plan and original.pallet_plan:
            try:
                raw_plans = json.loads(original.pallet_plan)
                if isinstance(raw_plans, list):
                    for rp in raw_plans:
                        new_pallet_plan.append(PalletPlanItem(**rp))
            except Exception:
                pass

        cloned_create = PurchaseOrderCreate(
            po_number=target_po_number,
            po_reference=payload.new_po_reference or _copy_reference(original.po_reference),
            import_file_id=None,  # Reset shipment link
            proforma_invoice_number=original.proforma_invoice_number,
            country_of_origin=original.country_of_origin,
            project_id=original.project_id,
            company_id=original.company_id,
            supplier_id=original.supplier_id,
            incoterm_id=original.incoterm_id,
            currency_id=original.currency_id,
            order_date=datetime.now(timezone.utc),
            expected_delivery_date=None,
            exchange_rate=float(original.exchange_rate or 1.0),
            payment_terms=original.payment_terms,
            notes=payload.notes or f"Cloned from: {original.po_number}",
            pallet_count=original.pallet_count if payload.copy_pallet_plan else 0,
            pallet_type=original.pallet_type or "Euro Pallet (120x80)",
            is_pallet_stackable=bool(original.is_pallet_stackable),
            pallet_length_cm=float(original.pallet_length_cm or 120.0),
            pallet_width_cm=float(original.pallet_width_cm or 80.0),
            pallet_height_cm=float(original.pallet_height_cm or 150.0),
            pallet_plan=new_pallet_plan if payload.copy_pallet_plan else [],
            items=new_items,
            packing_list_items=new_packing_items,
        )

        cloned_po = self.repo.create(cloned_create)
        return self._to_response(cloned_po)

