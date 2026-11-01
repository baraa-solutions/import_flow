import json
import logging
from datetime import datetime, timezone
from typing import Any, Callable, Dict, List, Optional, Sequence, Tuple, Union

from fastapi import Response, status
from pydantic import ValidationError
from sqlalchemy import Numeric
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from modules.common import cargo_math, enum_codes
from modules.common.concurrency import ConcurrencyConflictException, log_concurrency_conflict
from modules.common.errors import CodedHTTPException
from modules.common.pagination import PageParams
from modules.common.system_messages import SystemMessageItem, render_en, to_item
from modules.common.system_parameters import air_volumetric_kg_per_cbm
from modules.common.validators import not_found, require_active
from modules.import_files.model import ImportFile
from modules.import_files.repository import codes_by_ids
from modules.purchase_orders.model import POLineItem, POShipmentAllocation, PackingListItem, PurchaseOrder
from modules.purchase_orders.po_allocation_service import POAllocationService
from modules.purchase_orders.po_fulfillment_engine import (
    BALANCE_FULL,
    BALANCE_OVER,
    BALANCE_PARTIAL,
    BALANCE_PENDING,
    POFulfillmentEngine,
    QTY_EPSILON,
)
from modules.purchase_orders.repository import ChildRow, PurchaseOrderRepository
from modules.purchase_orders.schemas import (
    ClonePurchaseOrderRequest,
    DEFAULT_WEIGHT_UNIT,
    stored_weight_unit,
    PaginatedPurchaseOrdersResponse,
    POBalanceSummaryResponse,
    POLineItemBalanceItem,
    POLineItemCreate,
    POLineItemResponse,
    POShipmentAllocationCreate,
    POShipmentAllocationResponse,
    PackingListItemCreate,
    PackingListItemResponse,
    PackingListSummaryByHSCode,
    PackingListValidationReport,
    PalletPlanItem,
    PurchaseOrderCreate,
    PurchaseOrderListItem,
    PurchaseOrderResponse,
    PurchaseOrderUpdate,
)
from modules.purchase_orders.validators import FINAL_STATUSES, PurchaseOrderValidator

logger = logging.getLogger(__name__)

PO_REFERENCE_MAX_LENGTH = 200
COPY_CODE_SUFFIX = "-COPY"
PO_NUMBER_ATTEMPTS = 3
DEFAULT_PALLET_TYPE = "Euro Pallet (120x80)"
DEFAULT_PALLET_DIMS_CM = (120.0, 80.0, 150.0)

# Update payload fields that change the measured totals. Any other field is a header-only change and
# never recomputes the totals (they may have been set by a CBM calculation through apply_measurements).
MEASUREMENT_FIELDS = frozenset({
    "items", "packing_list_items", "pallet_plan",
    "pallet_count", "pallet_length_cm", "pallet_width_cm", "pallet_height_cm",
})


def _copy_reference(reference: Optional[str]) -> Optional[str]:
    """Default clone reference: ``<reference>-COPY``; the base is truncated so the result fits the column."""
    if not reference:
        return None
    base = reference[: PO_REFERENCE_MAX_LENGTH - len(COPY_CODE_SUFFIX)]
    return f"{base}{COPY_CODE_SUFFIX}"


def _strip(value: Optional[str]) -> Optional[str]:
    return value.strip() if value else None


def _load_pallet_plan(po: PurchaseOrder) -> List[Dict[str, Any]]:
    """The stored pallet plan rows (JSON text). A corrupt value is logged and treated as no plan."""
    raw = po.pallet_plan
    if not raw:
        return []
    try:
        rows = json.loads(raw) if isinstance(raw, str) else raw
    except (TypeError, ValueError):
        logger.warning("Purchase order %s has an unreadable pallet_plan; ignoring it", po.po_id)
        return []
    return [r for r in rows if isinstance(r, dict)] if isinstance(rows, list) else []


def _pallet_plan_items(po: PurchaseOrder) -> List[PalletPlanItem]:
    items = []
    for row in _load_pallet_plan(po):
        try:
            items.append(PalletPlanItem.model_validate(row))
        except ValidationError:
            logger.warning("Purchase order %s has an invalid pallet_plan row %r; skipping it", po.po_id, row)
    return items


def _line_values(item: POLineItemCreate) -> Tuple[Dict[str, Any], cargo_math.LineTotals]:
    totals = cargo_math.line_totals(item.quantity, item.unit_price, item.cbm_per_unit, item.gross_weight_kg, item.net_weight_kg)
    values = dict(
        item_code=_strip(item.item_code),
        main_description=_strip(item.main_description),
        description_ar=item.description_ar.strip(),
        description_en=_strip(item.description_en),
        country_of_origin=_strip(item.country_of_origin),
        tariff_id=item.tariff_id,
        quantity=item.quantity,
        unit_of_measure=item.unit_of_measure.strip(),
        unit_price=item.unit_price,
        total_price=totals.total_price,
        cbm_per_unit=item.cbm_per_unit,
        total_cbm=totals.total_cbm,
        gross_weight_kg=item.gross_weight_kg,
        net_weight_kg=item.net_weight_kg,
    )
    return values, totals


def _packing_values(item: PackingListItemCreate, kg_per_cbm: float) -> Tuple[Dict[str, Any], cargo_math.PackingRowTotals]:
    totals = cargo_math.packing_row_totals(
        item.qty_pkg, item.net_weight_unit_kg, item.gross_weight_unit_kg,
        item.length_cm, item.width_cm, item.height_cm, item.unit, item.total_cbm, kg_per_cbm,
    )
    values = dict(
        hs_code=item.hs_code.strip(),
        item_code=item.item_code.strip(),
        main_description=_strip(item.main_description),
        description=_strip(item.description),
        qty_pcs=item.qty_pcs,
        qty_pkg=item.qty_pkg,
        package_type=_strip(item.package_type) or "Carton",
        length_cm=totals.length_cm,
        width_cm=totals.width_cm,
        height_cm=totals.height_cm,
        net_weight_unit_kg=item.net_weight_unit_kg,
        gross_weight_unit_kg=item.gross_weight_unit_kg,
        weight_unit=item.weight_unit or DEFAULT_WEIGHT_UNIT,
        total_net_weight_kg=totals.total_net_weight_kg,
        total_gross_weight_kg=totals.total_gross_weight_kg,
        total_cbm=totals.total_cbm,
        chargeable_weight_kg=totals.chargeable_weight_kg,
        is_stackable=bool(item.is_stackable),
    )
    return values, totals


def _pallet_fallback(po: PurchaseOrder) -> cargo_math.PalletFallback:
    return cargo_math.PalletFallback(
        count=int(po.pallet_count or 0),
        length_cm=float(po.pallet_length_cm or 0),
        width_cm=float(po.pallet_width_cm or 0),
        height_cm=float(po.pallet_height_cm or 0),
    )


def _stored_totals(po: PurchaseOrder) -> cargo_math.CargoTotals:
    return cargo_math.CargoTotals(
        amount_fob=float(po.total_amount_fob or 0.0),
        cbm=float(po.total_cbm or 0.0),
        gross_kg=float(po.total_gross_weight_kg or 0.0),
        net_kg=float(po.total_net_weight_kg or 0.0),
        packages=int(po.total_packages_count or 0),
    )


def _apply_totals(po: PurchaseOrder, totals: cargo_math.CargoTotals) -> None:
    po.total_amount_fob = totals.amount_fob
    po.total_cbm = totals.cbm
    po.total_gross_weight_kg = totals.gross_kg
    po.total_net_weight_kg = totals.net_kg
    po.total_packages_count = totals.packages
    if totals.pallet_count is not None:
        po.pallet_count = totals.pallet_count


def _same_value(model: Any, field: str, new: Any, stored: Any) -> bool:
    """``new`` equals the stored column value at the column's precision (Numeric scale; weight unit by code)."""
    if field == "weight_unit":
        return stored_weight_unit(new) == stored_weight_unit(stored)
    column = model.__table__.columns[field]
    if new is None or stored is None:
        return (new is None or new == 0) and (stored is None or stored == 0) if isinstance(column.type, Numeric) else new == stored
    if isinstance(column.type, Numeric) and column.type.scale is not None:
        return round(float(new), column.type.scale) == round(float(stored), column.type.scale)
    if isinstance(column.type, Numeric):
        return float(new) == float(stored)
    return new == stored


def _rows_changed(model: Any, id_attr: str, stored_rows: Sequence[Any], sent: Sequence[Tuple[Optional[int], Dict[str, Any]]]) -> bool:
    """Sent child rows differ from the stored ones: a new row, a missing row, or any column value."""
    by_id = {getattr(row, id_attr): row for row in stored_rows}
    if len(sent) != len(by_id) or any(row_id not in by_id for row_id, _ in sent):
        return True
    return any(
        not _same_value(model, field, value, getattr(by_id[row_id], field))
        for row_id, values in sent
        for field, value in values.items()
    )


def _status_code(value: Optional[str]) -> Optional[str]:
    """Stored status as a PO_STATUS code (legacy label rows are normalized on read)."""
    return enum_codes.normalize(enum_codes.PO_STATUS, value)


class PurchaseOrderService:

    def __init__(self, db: Session):
        self.db = db
        self.repo = PurchaseOrderRepository(db)
        self.validator = PurchaseOrderValidator(db)
        self.fulfillment_engine = POFulfillmentEngine(db, repo=self.repo)
        self.allocation_service = POAllocationService(
            db, repo=self.repo, validator=self.validator, fulfillment_engine=self.fulfillment_engine
        )

    def _get_or_404(self, po_id: int, active_only: bool = False, label_ar: str = "أمر الشراء") -> PurchaseOrder:
        po = self.repo.get_by_id(po_id, active_only=active_only)
        if po is None:
            raise not_found(label_ar, po_id)
        return po

    # =========================================================================
    # Reads
    # =========================================================================

    def _to_response(self, po: PurchaseOrder, import_file_code: Optional[str] = None) -> PurchaseOrderResponse:
        items_resp = [
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
            for item in po.line_items
        ]
        packing_items_resp = [
            PackingListItemResponse(
                packing_item_id=pitem.packing_item_id,
                po_id=pitem.po_id,
                hs_code=pitem.hs_code,
                item_code=pitem.item_code,
                main_description=pitem.main_description,
                description=pitem.description,
                qty_pcs=float(pitem.qty_pcs),
                qty_pkg=float(pitem.qty_pkg),
                package_type=pitem.package_type,
                weight_unit=stored_weight_unit(pitem.weight_unit),
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
            for pitem in po.packing_list_items
        ]
        if import_file_code is None and po.import_file_id:
            import_file_code = codes_by_ids(self.db, [po.import_file_id]).get(po.import_file_id)

        return PurchaseOrderResponse(
            po_id=po.po_id,
            po_number=po.po_number,
            version=po.version or 1,
            po_reference=po.po_reference,
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
            pallet_count=po.pallet_count or 0,
            pallet_type=po.pallet_type or DEFAULT_PALLET_TYPE,
            is_pallet_stackable=bool(po.is_pallet_stackable),
            pallet_length_cm=float(po.pallet_length_cm or DEFAULT_PALLET_DIMS_CM[0]),
            pallet_width_cm=float(po.pallet_width_cm or DEFAULT_PALLET_DIMS_CM[1]),
            pallet_height_cm=float(po.pallet_height_cm or DEFAULT_PALLET_DIMS_CM[2]),
            pallet_plan=_pallet_plan_items(po),
            status=_status_code(po.status),
            notes=po.notes,
            is_active=po.is_active,
            created_at=po.created_at,
            updated_at=po.updated_at,
            created_by=po.created_by,
            updated_by=po.updated_by,
            project_name=po.project.project_name if po.project else None,
            company_name=po.company.importer_name if po.company else None,
            supplier_name=po.supplier.company_name if po.supplier else None,
            incoterm_code=po.incoterm.incoterm_code if po.incoterm else None,
            currency_code=po.currency.currency_code if po.currency else None,
            items=items_resp,
            packing_list_items=packing_items_resp,
        )

    def _to_list_item(self, po: PurchaseOrder, import_file_code: Optional[str] = None) -> PurchaseOrderListItem:
        total_fob = float(po.total_amount_fob) if po.total_amount_fob is not None else 0.0
        curr_code = po.currency.currency_code if po.currency else None
        return PurchaseOrderListItem(
            id=po.po_id,
            po_id=po.po_id,
            code=po.po_number,
            po_number=po.po_number,
            po_reference=po.po_reference,
            proforma_invoice_number=po.proforma_invoice_number,
            supplier_id=po.supplier_id,
            supplier_name=po.supplier.company_name if po.supplier else None,
            company_id=po.company_id,
            company_name=po.company.importer_name if po.company else None,
            project_id=po.project_id,
            project_name=po.project.project_name if po.project else None,
            import_file_id=po.import_file_id,
            import_file_code=import_file_code,
            total_amount_fob=total_fob,
            total_amount=total_fob,
            currency_id=po.currency_id,
            currency_code=curr_code,
            currency=curr_code,
            status=_status_code(po.status),
            order_date=po.order_date,
            expected_delivery_date=po.expected_delivery_date,
            created_at=po.created_at,
            updated_at=po.updated_at,
            is_active=po.is_active,
        )

    def get_all(
        self,
        include_inactive: bool = False,
        status_filter: Optional[str] = None,
        project_id: Optional[int] = None,
        company_id: Optional[int] = None,
        supplier_id: Optional[int] = None,
        search: Optional[str] = None,
        skip: int = 0,
        limit: Optional[int] = None,
        return_total: bool = False,
    ) -> Union[List[PurchaseOrderResponse], Tuple[List[PurchaseOrderResponse], int]]:
        status_values = None
        if status_filter:
            # rows store the code; legacy rows may still hold a label of the same status
            status_values = enum_codes.legacy_values(enum_codes.PO_STATUS, _status_code(status_filter.strip()))
        res = self.repo.get_all(
            include_inactive=include_inactive,
            status_values=status_values,
            project_id=project_id,
            company_id=company_id,
            supplier_id=supplier_id,
            search=search,
            skip=skip,
            limit=limit,
            return_total=return_total,
        )
        pos, total = res if return_total else (res, len(res))
        file_codes = codes_by_ids(self.db, (po.import_file_id for po in pos))
        responses = [self._to_response(po, file_codes.get(po.import_file_id)) for po in pos]
        if return_total:
            return responses, total
        return responses

    def get_paginated(
        self,
        params: PageParams,
        *,
        status_filter: Optional[str] = None,
        supplier_id: Optional[int] = None,
        company_id: Optional[int] = None,
        project_id: Optional[int] = None,
        currency_id: Optional[int] = None,
        search: Optional[str] = None,
        response: Optional[Response] = None,
    ) -> PaginatedPurchaseOrdersResponse:
        status_values = None
        if status_filter:
            status_values = enum_codes.legacy_values(enum_codes.PO_STATUS, _status_code(status_filter.strip()))
        result = self.repo.get_paginated(
            params=params,
            status_values=status_values,
            supplier_id=supplier_id,
            company_id=company_id,
            project_id=project_id,
            currency_id=currency_id,
            search=search,
            response=response,
        )
        pos = result["items"]
        file_codes = codes_by_ids(self.db, (po.import_file_id for po in pos))
        items = [self._to_list_item(po, file_codes.get(po.import_file_id)) for po in pos]
        return PaginatedPurchaseOrdersResponse(
            items=items,
            total=result["total"],
            page=result["page"],
            page_size=result["page_size"],
            total_pages=result["total_pages"],
        )

    def get_by_id(self, po_id: int) -> PurchaseOrderResponse:
        return self._to_response(self._get_or_404(po_id))

    def get_packing_list_report(self, po_id: int) -> PackingListValidationReport:
        po = self._get_or_404(po_id)

        errors: List[str] = []
        warnings: List[str] = []
        messages: List[SystemMessageItem] = []

        def add(kind: str, code: str, **params: Any) -> None:
            """One finding: coded message + its English render (the legacy errors / warnings text)."""
            item = to_item(code, kind, **params)
            messages.append(item)
            (errors if kind == "error" else warnings).append(render_en(item.code, item.params, "note"))

        hs_map: Dict[str, Dict[str, Any]] = {}
        tot_pcs = tot_pkg = tot_net = tot_gross = tot_cbm = tot_chg = 0.0

        if not po.packing_list_items:
            add("warning", "PO_PL_NO_ITEMS")

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

            if gross_u < net_u:
                add("error", "PO_PL_GROSS_BELOW_NET", line_num=idx, item_code=item.item_code, gross_qty=gross_u, net_qty=net_u)
            if net_u < 0 or gross_u < 0:
                add("error", "PO_PL_NEGATIVE_WEIGHT", line_num=idx, item_code=item.item_code)
            if l_cm <= 0 or w_cm <= 0 or h_cm <= 0:
                add("warning", "PO_PL_DIMENSIONS_MISSING", line_num=idx, item_code=item.item_code)

            tot_pcs += q_pcs
            tot_pkg += q_pkg
            tot_net += t_net
            tot_gross += t_gross
            tot_cbm += t_cbm
            tot_chg += chg_wt

            hs = item.hs_code or "UNSPECIFIED"
            bucket = hs_map.setdefault(hs, {
                "hs_code": hs, "qty_pcs": 0.0, "qty_pkg": 0.0,
                "total_net_weight_kg": 0.0, "total_gross_weight_kg": 0.0, "total_cbm": 0.0,
            })
            bucket["qty_pcs"] += q_pcs
            bucket["qty_pkg"] += q_pkg
            bucket["total_net_weight_kg"] += t_net
            bucket["total_gross_weight_kg"] += t_gross
            bucket["total_cbm"] += t_cbm

        tot_net = cargo_math.snap_weight(tot_net)
        tot_gross = cargo_math.snap_weight(tot_gross)
        for bucket in hs_map.values():
            bucket["total_net_weight_kg"] = cargo_math.snap_weight(bucket["total_net_weight_kg"])
            bucket["total_gross_weight_kg"] = cargo_math.snap_weight(bucket["total_gross_weight_kg"])

        invoice_hs_map: Dict[str, float] = {}
        po_total_pcs = 0.0
        for l_item in po.line_items:
            l_qty = float(l_item.quantity or 0.0)
            po_total_pcs += l_qty
            l_hs = l_item.tariff.hs_code if (l_item.tariff and l_item.tariff.hs_code) else "UNASSIGNED"
            invoice_hs_map[l_hs] = invoice_hs_map.get(l_hs, 0.0) + l_qty

        both_lists = bool(po.line_items and po.packing_list_items)
        missing_hs_in_packing: List[str] = []
        missing_hs_in_invoice: List[str] = []
        if both_lists:
            for inv_hs in invoice_hs_map:
                if inv_hs not in hs_map:
                    missing_hs_in_packing.append(inv_hs)
                    add("warning", "PO_PL_HS_MISSING_IN_PACKING", hs_code=inv_hs)
            for pkg_hs in hs_map:
                if pkg_hs not in invoice_hs_map:
                    missing_hs_in_invoice.append(pkg_hs)
                    add("warning", "PO_PL_HS_MISSING_IN_INVOICE", hs_code=pkg_hs)

        has_qty_mismatch = False
        hs_summary = []
        for hs_key in sorted(set(hs_map) | set(invoice_hs_map)):
            pkg_data = hs_map.get(hs_key, {
                "hs_code": hs_key, "qty_pcs": 0.0, "qty_pkg": 0.0,
                "total_net_weight_kg": 0.0, "total_gross_weight_kg": 0.0, "total_cbm": 0.0,
            })
            inv_qty = invoice_hs_map.get(hs_key, 0.0)
            pkg_qty = pkg_data["qty_pcs"]
            diff = pkg_qty - inv_qty
            matched = abs(diff) < 0.001
            if not matched and both_lists:
                has_qty_mismatch = True
                add("warning", "PO_PL_HS_QTY_MISMATCH", hs_code=hs_key, packing_qty=pkg_qty, invoice_qty=inv_qty,
                    signed_difference=f"{diff:+.2f}")
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

        total_qty_mismatch = False
        if both_lists and abs(tot_pcs - po_total_pcs) > 0.01:
            total_qty_mismatch = True
            add("warning", "PO_PL_TOTAL_QTY_MISMATCH", packing_qty=tot_pcs, invoice_qty=po_total_pcs,
                signed_difference=f"{tot_pcs - po_total_pcs:+.2f}")

        return PackingListValidationReport(
            is_valid=len(errors) == 0,
            has_discrepancy=bool(missing_hs_in_packing or missing_hs_in_invoice or has_qty_mismatch or total_qty_mismatch),
            errors=errors,
            warnings=warnings,
            messages=messages,
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

    # =========================================================================
    # Import file link (no commit: part of the caller's transaction)
    # =========================================================================

    def _link_import_file(self, po: PurchaseOrder) -> None:
        import_file = self.repo.get_import_file(po.import_file_id) if po.import_file_id else None
        if not import_file:
            return
        po_ids = list(import_file.po_ids or [])
        if po.po_id not in po_ids:
            po_ids.append(po.po_id)
            import_file.po_ids = po_ids
        if not import_file.po_number:
            import_file.po_number = po.po_number
        if not import_file.pi_number and po.proforma_invoice_number:
            import_file.pi_number = po.proforma_invoice_number

    def _unlink_import_file(self, import_file_id: Optional[int], po_id: int) -> None:
        import_file = self.repo.get_import_file(import_file_id) if import_file_id else None
        if import_file and import_file.po_ids:
            import_file.po_ids = [pid for pid in import_file.po_ids if pid != po_id]

    def _commit(self, *instances: Any) -> None:
        self.db.commit()
        for instance in instances:
            self.db.refresh(instance)

    # =========================================================================
    # Create / clone
    # =========================================================================

    def _build(self, data: PurchaseOrderCreate, po_number: str, user: Optional[str], kg_per_cbm: float) -> PurchaseOrder:
        po = PurchaseOrder(
            po_number=po_number,
            po_reference=_strip(data.po_reference),
            import_file_id=data.import_file_id,
            proforma_invoice_number=_strip(data.proforma_invoice_number),
            country_of_origin=_strip(data.country_of_origin),
            project_id=data.project_id,
            company_id=data.company_id,
            supplier_id=data.supplier_id,
            incoterm_id=data.incoterm_id,
            currency_id=data.currency_id,
            order_date=data.order_date or datetime.now(timezone.utc),
            expected_delivery_date=data.expected_delivery_date,
            exchange_rate=data.exchange_rate,
            payment_terms=_strip(data.payment_terms),
            notes=_strip(data.notes),
            pallet_count=data.pallet_count or 0,
            pallet_type=data.pallet_type or DEFAULT_PALLET_TYPE,
            is_pallet_stackable=bool(data.is_pallet_stackable),
            pallet_length_cm=float(data.pallet_length_cm or DEFAULT_PALLET_DIMS_CM[0]),
            pallet_width_cm=float(data.pallet_width_cm or DEFAULT_PALLET_DIMS_CM[1]),
            pallet_height_cm=float(data.pallet_height_cm or DEFAULT_PALLET_DIMS_CM[2]),
            pallet_plan=json.dumps([p.model_dump() for p in data.pallet_plan]) if data.pallet_plan else None,
            status="DRAFT",
            is_active=True,
            version=1,
            created_by=user,
            updated_by=user,
        )
        lines = [_line_values(item) for item in data.items]
        packing = [_packing_values(item, kg_per_cbm) for item in data.packing_list_items]
        po.line_items = [POLineItem(**values) for values, _ in lines]
        po.packing_list_items = [PackingListItem(**values) for values, _ in packing]
        _apply_totals(po, cargo_math.compute_po_totals(
            [t for _, t in lines], [t for _, t in packing], data.pallet_plan, _pallet_fallback(po),
        ))
        return po

    def _create(
        self,
        data: PurchaseOrderCreate,
        user: Optional[str],
        decorate: Optional[Callable[[PurchaseOrder], None]] = None,
    ) -> PurchaseOrder:
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
        explicit_number = data.po_number  # trimmed + upper-cased by the schema
        if explicit_number:
            self.validator.validate_po_number_unique(explicit_number)
        kg_per_cbm = air_volumetric_kg_per_cbm(self.db)

        for attempt in range(1, PO_NUMBER_ATTEMPTS + 1):
            number = explicit_number or self.repo.next_po_number()
            po = self._build(data, number, user, kg_per_cbm)
            if decorate:
                decorate(po)
            try:
                self.repo.add(po)
                self._link_import_file(po)
                self.db.commit()
            except IntegrityError:
                self.db.rollback()
                if not self.repo.po_number_exists(number):
                    raise
                if explicit_number or attempt == PO_NUMBER_ATTEMPTS:
                    raise CodedHTTPException(
                        status.HTTP_409_CONFLICT,
                        "PO_NUMBER_TAKEN",
                        f"رقم أمر الشراء '{number}' مستخدم بالفعل، يرجى إعادة المحاولة.",
                        po_number=number,
                    )
                logger.info("PO number %s was taken concurrently; retrying (%s/%s)", number, attempt, PO_NUMBER_ATTEMPTS)
                continue
            self.db.refresh(po)
            from modules.master_items.service import MasterItemService
            MasterItemService.sync_po_items(self.db, po)
            return po
        raise AssertionError("unreachable")  # pragma: no cover

    def create(self, data: PurchaseOrderCreate, current_user_name: Optional[str] = None) -> PurchaseOrderResponse:
        return self._to_response(self._create(data, current_user_name))

    def clone_purchase_order(
        self, po_id: int, payload: ClonePurchaseOrderRequest, current_user_name: Optional[str] = None
    ) -> PurchaseOrderResponse:
        """UX-CLONE-011: copy an active PO through ``create`` (all create validations apply).

        Kept: company, supplier, project, incoterm, currency, exchange_rate, payment_terms, country_of_origin, and
        (optionally) line items, packing list and pallet plan, including the extraction columns the API does not
        carry (invoice numbers, customs unit price, pallet / carton numbers). Reset: number, import file link,
        status (DRAFT), order date (now), expected delivery date, allocations; totals are recomputed.
        """
        original = self._get_or_404(po_id, active_only=True, label_ar="أمر الشراء الأصلي")

        source_lines = list(original.line_items) if payload.copy_items else []
        source_packing = list(original.packing_list_items) if payload.copy_packing_list else []
        new_items = [
            POLineItemCreate(
                item_code=it.item_code,
                main_description=it.main_description,
                description_ar=it.description_ar,
                description_en=it.description_en,
                country_of_origin=it.country_of_origin,
                tariff_id=it.tariff_id,
                quantity=float(it.quantity),
                unit_of_measure=it.unit_of_measure or "PCS",
                unit_price=float(it.unit_price or 0.0),
                cbm_per_unit=float(it.cbm_per_unit or 0.0),
                gross_weight_kg=float(it.gross_weight_kg or 0.0),
                net_weight_kg=float(it.net_weight_kg or 0.0),
            )
            for it in source_lines
        ]
        new_packing = [
            PackingListItemCreate(
                hs_code=p.hs_code,
                item_code=p.item_code,
                main_description=p.main_description,
                description=p.description,
                qty_pcs=float(p.qty_pcs),
                qty_pkg=float(p.qty_pkg),
                package_type=p.package_type or "Carton",
                unit="cm",  # stored dimensions are cm
                weight_unit=stored_weight_unit(p.weight_unit),
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
            for p in source_packing
        ]
        cloned = PurchaseOrderCreate(
            po_number=payload.new_po_number,
            po_reference=payload.new_po_reference or _copy_reference(original.po_reference),
            import_file_id=None,
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
            pallet_type=original.pallet_type or DEFAULT_PALLET_TYPE,
            is_pallet_stackable=bool(original.is_pallet_stackable),
            pallet_length_cm=float(original.pallet_length_cm or DEFAULT_PALLET_DIMS_CM[0]),
            pallet_width_cm=float(original.pallet_width_cm or DEFAULT_PALLET_DIMS_CM[1]),
            pallet_height_cm=float(original.pallet_height_cm or DEFAULT_PALLET_DIMS_CM[2]),
            pallet_plan=_pallet_plan_items(original) if payload.copy_pallet_plan else [],
            items=new_items,
            packing_list_items=new_packing,
        )

        def copy_extraction_columns(po: PurchaseOrder) -> None:
            for src, dst in zip(source_lines, po.line_items):
                dst.invoice_number = src.invoice_number
                dst.invoice_line_number = src.invoice_line_number
                dst.customs_unit_price = src.customs_unit_price
            for src, dst in zip(source_packing, po.packing_list_items):
                dst.invoice_number = src.invoice_number
                dst.pallet_number = src.pallet_number
                dst.carton_numbers = list(src.carton_numbers) if src.carton_numbers is not None else None

        return self._to_response(self._create(cloned, current_user_name, decorate=copy_extraction_columns))

    # =========================================================================
    # Update / delete / restore
    # =========================================================================

    def _check_version(self, po: PurchaseOrder, submitted: Optional[int], user: Optional[str]) -> int:
        version, updated_at, updated_by = self.repo.version_info(po.po_id)
        current = version if version is not None else (po.version or 1)
        if submitted is not None and submitted != current:
            log_concurrency_conflict(
                db=self.db,
                entity_name="PurchaseOrder",
                record_id=po.po_id,
                current_version=current,
                submitted_version=submitted,
                attempted_by=user,
                details=f"Conflict detected while updating PO #{po.po_number}",
            )
            raise ConcurrencyConflictException(
                entity="PurchaseOrder",
                record_id=po.po_id,
                current_version=current,
                submitted_version=submitted,
                updated_at=updated_at,
                updated_by=updated_by,
            )
        return current

    def _touch(self, po: PurchaseOrder, user: Optional[str], current_version: Optional[int] = None) -> None:
        po.version = (current_version if current_version is not None else (po.version or 1)) + 1
        po.updated_at = datetime.now(timezone.utc)
        po.updated_by = user

    def update(self, po_id: int, data: PurchaseOrderUpdate, current_user_name: Optional[str] = None) -> PurchaseOrderResponse:
        po = self._get_or_404(po_id, active_only=True)
        current_status = _status_code(po.status) or po.status
        if current_status in FINAL_STATUSES:
            raise CodedHTTPException(
                status.HTTP_409_CONFLICT,
                "PO_NOT_EDITABLE",
                f"لا يمكن تعديل أمر الشراء في حالة '{current_status}'.",
                status=current_status,
            )
        current_version = self._check_version(po, data.version, current_user_name)

        sent = data.model_fields_set
        changes = data.model_dump(exclude_unset=True, exclude={"version", "items", "packing_list_items", "pallet_plan"})
        self.validator.reject_cleared_required_fields(changes)
        if "status" in changes:
            changes["status"] = self.validator.normalize_status(changes["status"])
            self.validator.validate_status_transition(current_status, changes["status"])
        self.validator.validate_changed_foreign_keys(po, changes)

        items = data.items if "items" in sent else None
        packing = data.packing_list_items if "packing_list_items" in sent else None
        if items is not None:
            self.validator.validate_line_items(items)
            existing_ids = {it.item_id for it in po.line_items}
            sent_ids = [it.item_id for it in items]
            self.validator.validate_row_ids_belong(existing_ids, sent_ids, "البند")
            self.validator.validate_removed_items_not_allocated(po.po_id, existing_ids - set(sent_ids))
        if packing is not None:
            self.validator.validate_row_ids_belong(
                {p.packing_item_id for p in po.packing_list_items}, [p.packing_item_id for p in packing], "بند قائمة التعبئة"
            )

        kg_per_cbm = air_volumetric_kg_per_cbm(self.db)
        measurements_changed = self._measurements_changed(po, data, items, packing, kg_per_cbm)

        old_file_id = po.import_file_id
        for field, value in changes.items():
            setattr(po, field, value.strip() if isinstance(value, str) else value)
        if measurements_changed:
            if "pallet_plan" in sent:
                po.pallet_plan = json.dumps([p.model_dump() for p in data.pallet_plan]) if data.pallet_plan else None
            self._recompute_totals(po, items, packing, data.pallet_plan if "pallet_plan" in sent else None, kg_per_cbm)

        self._touch(po, current_user_name, current_version)
        if old_file_id and old_file_id != po.import_file_id:
            self._unlink_import_file(old_file_id, po.po_id)
        if po.import_file_id:
            self._link_import_file(po)
        self._commit(po)
        from modules.master_items.service import MasterItemService
        MasterItemService.sync_po_items(self.db, po)
        return self._to_response(po)

    def _measurements_changed(
        self,
        po: PurchaseOrder,
        data: PurchaseOrderUpdate,
        items: Optional[Sequence[POLineItemCreate]],
        packing: Optional[Sequence[PackingListItemCreate]],
        kg_per_cbm: float,
    ) -> bool:
        """True when the update really changes what the totals depend on. The PO form always resends lines,
        packing rows and pallet fields: values equal to the stored ones (same ids, compared at the column scale)
        are not a change, so totals pushed by a CBM calculation survive a header edit."""
        sent = data.model_fields_set
        for field in ("pallet_count", "pallet_length_cm", "pallet_width_cm", "pallet_height_cm"):
            if field in sent and not _same_value(PurchaseOrder, field, getattr(data, field), getattr(po, field)):
                return True
        if "pallet_plan" in sent:
            stored_plan = [p.model_dump() for p in _pallet_plan_items(po)]
            if [p.model_dump() for p in (data.pallet_plan or [])] != stored_plan:
                return True
        if items is not None and _rows_changed(
            POLineItem, "item_id", po.line_items, [(it.item_id, _line_values(it)[0]) for it in items]
        ):
            return True
        if packing is not None:
            rows = []
            for pitem in packing:
                values = _packing_values(pitem, kg_per_cbm)[0]
                rows.append((pitem.packing_item_id, values))
            if _rows_changed(PackingListItem, "packing_item_id", po.packing_list_items, rows):
                return True
        return False

    def _recompute_totals(
        self,
        po: PurchaseOrder,
        items: Optional[Sequence[POLineItemCreate]],
        packing: Optional[Sequence[PackingListItemCreate]],
        pallet_plan: Optional[Sequence[PalletPlanItem]],
        kg_per_cbm: float,
    ) -> None:
        """Upsert the sent child rows and recompute the totals: lines not sent keep the stored totals as the
        base, a packing list not sent is not re-applied, the stored pallet plan is re-applied when none is sent."""
        line_totals = None
        if items is not None:
            rows: List[ChildRow] = []
            line_totals = []
            for item in items:
                values, totals = _line_values(item)
                rows.append((item.item_id, values))
                line_totals.append(totals)
            self.repo.upsert_line_items(po, rows)
        packing_totals = None
        if packing is not None:
            prows: List[ChildRow] = []
            packing_totals = []
            for pitem in packing:
                values, totals = _packing_values(pitem, kg_per_cbm)
                prows.append((pitem.packing_item_id, values))
                packing_totals.append(totals)
            self.repo.upsert_packing_items(po, prows)
        plan = pallet_plan if pallet_plan is not None else _load_pallet_plan(po)
        _apply_totals(po, cargo_math.compute_po_totals(
            line_totals, packing_totals, plan, _pallet_fallback(po), base=_stored_totals(po),
        ))

    def apply_measurements(
        self,
        po_id: int,
        cbm: Optional[float],
        gross_kg: Optional[float],
        packages: Optional[int],
        user: Optional[str],
        commit: bool = True,
    ) -> PurchaseOrder:
        """Push measured totals (e.g. from a CBM calculation) onto an active PO: ``None`` keeps a value.
        Bumps the version and records who changed it. ``commit=False`` only flushes, so the caller commits its own
        changes in the same transaction. Returns the PO row (callers that need the API shape use ``get_by_id``)."""
        po = self._get_or_404(po_id, active_only=True)
        if cbm is not None:
            po.total_cbm = cbm
        if gross_kg is not None:
            po.total_gross_weight_kg = gross_kg
        if packages is not None:
            po.total_packages_count = int(packages)
        self._touch(po, user)
        if commit:
            self._commit(po)
        else:
            self.db.flush()
        return po

    def soft_delete(self, po_id: int, current_user_name: Optional[str] = None) -> PurchaseOrderResponse:
        po = self._get_or_404(po_id)
        allocations = self.repo.list_allocations(po_id)
        if allocations:
            raise CodedHTTPException(
                status.HTTP_409_CONFLICT,
                "PO_HAS_ALLOCATIONS",
                f"لا يمكن حذف أمر الشراء '{po.po_number}' لوجود شحنات مسجلة مرتبطة به.",
            )
        self.repo.set_active(po, False)
        self._touch(po, current_user_name)
        self._unlink_import_file(po.import_file_id, po.po_id)
        self._commit(po)
        return self._to_response(po)

    def restore(self, po_id: int, current_user_name: Optional[str] = None) -> PurchaseOrderResponse:
        po = self._get_or_404(po_id)
        if po.import_file_id:
            require_active(self.db, ImportFile, po.import_file_id, "ملف الاستيراد")
        self.repo.set_active(po, True)
        self._touch(po, current_user_name)
        self._link_import_file(po)
        self._commit(po)
        return self._to_response(po)

    # =========================================================================
    # LOG-PART-004: Partial Shipments & PO Balance Ledger Engine (Delegated)
    # =========================================================================

    @staticmethod
    def _shipped_totals(allocations: Sequence[POShipmentAllocation]) -> Tuple[float, float]:
        return POFulfillmentEngine.shipped_totals(allocations)

    @staticmethod
    def _ordered_qty(po: PurchaseOrder) -> float:
        return POFulfillmentEngine.ordered_qty(po)

    @staticmethod
    def _line_progress(
        po: PurchaseOrder, allocations: Sequence[POShipmentAllocation]
    ) -> Tuple[List[Tuple[POLineItem, float, float]], List[POShipmentAllocation]]:
        return POFulfillmentEngine.line_progress(po, allocations)

    @staticmethod
    def _fulfillment_state(
        progress: Sequence[Tuple[POLineItem, float, float]], unattributed: Sequence[POShipmentAllocation]
    ) -> Optional[str]:
        return POFulfillmentEngine.fulfillment_state(progress, unattributed)

    def _sync_po_fulfillment_status(self, po: PurchaseOrder, allocations: Sequence[POShipmentAllocation]) -> bool:
        return self.fulfillment_engine.sync_po_fulfillment_status(po, allocations)

    def allocate_shipment(
        self, po_id: int, data: POShipmentAllocationCreate, current_user_name: Optional[str] = None
    ) -> POShipmentAllocationResponse:
        return self.allocation_service.allocate_shipment(po_id, data, current_user_name)

    def compute_po_balance(self, po_id: int) -> POBalanceSummaryResponse:
        return self.fulfillment_engine.compute_po_balance(po_id)
