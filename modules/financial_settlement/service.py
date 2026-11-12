
from .repository import (
    get_settlement_by_id,
    get_settlement_by_import_file_id,
    add_with_new_code,
    list_settlements,
    apply_settlement_update,
    soft_delete_settlement,
    restore_settlement,
)

from .schemas import (
    ConfirmInvoicesSettlementRequest,
    ConfirmInvoicesSettlementResponse,
    ActualLandedCostCalculationRequest,
    ActualLandedCostCalculationResponse,
    ApproveActualLandedCostRequest,
    ApproveActualLandedCostResponse,
)

from .landed_cost_engine_service import (
    PARAM_VARIANCE_UNIT_TOLERANCE_EGP,
    PARAM_VARIANCE_FILE_TOLERANCE_EGP,
    DEFAULT_VARIANCE_UNIT_TOLERANCE_EGP,
    DEFAULT_VARIANCE_FILE_TOLERANCE_EGP,
)

"""Financial Settlement & Landed Cost Module Service Facade.

Decomposed domain architecture:
- landed_cost_engine_service.py: Allocation ratios, CIF/FOB conversion, SettlementFx, build_initial
- settlement_crud_service.py: Settlement record CRUD, recalculation, list, soft delete, restore
- landed_cost_simulation_service.py: Pre-import estimated landed cost simulation (PL-08)
- actual_settlement_service.py: Invoice aggregation, actual landed cost calculation, WHT, Odoo sync
"""

from .landed_cost_engine_service import (
    _message,
    actual_expense_bucket,
    settlement_expense_field,
    recalc_adjustment_invoice_no,
    _counts_for_field,
    settlement_field_total,
    apply_settlement_field_total,
    allocation_ratios,
    row_amount_egp,
    calculate_landed_cost_engine,
    _unit_qty,
    is_seller_paid_expense,
    SettlementFx,
    _as_date,
    purchase_order_rate_to_egp,
    _purchase_orders_of_file,
    _line_item_name,
    file_po_line_shares,
    _items_from_purchase_orders,
    _resolve_client_expense_rates,
    _derive_expense_egp,
    _validate_client_expenses,
    _duty_row,
    _customs_duty_rows,
    _recalculate_in_place,
    recalculate_settlement_totals,
    _audit,
    _audit_import_file,
    _settlement_snapshot_dict,
    build_initial_settlement,
)

from .settlement_crud_service import (
    create_settlement_service,
    recalculate_settlement_service,
    update_settlement_service,
    get_settlement_service,
    list_settlements_service,
    soft_delete_settlement_service,
    restore_settlement_service,
)

from .landed_cost_simulation_service import (
    _estimate_parameter,
    simulate_estimated_landed_cost_service,
)

from .fob_valuation_service import (
    resolve_fob_valuation,
    snapshot_fob_valuation,
    ensure_no_fob_double_count,
    get_fob_valuation_service,
    revalue_fob_valuation_service,
)

from .actual_settlement_service import (
    WHT_RATE_NOT_CONFIGURED,
    _cairo_tz,
    cairo_date,
    cairo_today,
    get_wht_rate_percent,
    resolve_wht_rate_percent,
    wht_amount_for,
    _wht_rate_missing_warning,
    aggregate_shipment_invoices_service,
    confirm_invoices_settlement_service,
    _is_goods_invoice,
    scale_item_fobs_to_header,
    calculate_actual_landed_cost_service,
    _calculate_actual_landed_cost,
    settlement_expense_row,
    settlement_item_row,
    approve_actual_landed_cost_service,
    get_shipment_fx_reconciliation,
)

__all__ = [
    "resolve_fob_valuation",
    "snapshot_fob_valuation",
    "ensure_no_fob_double_count",
    "get_fob_valuation_service",
    "revalue_fob_valuation_service",
    "actual_expense_bucket",
    "settlement_expense_field",
    "recalc_adjustment_invoice_no",
    "settlement_field_total",
    "apply_settlement_field_total",
    "allocation_ratios",
    "row_amount_egp",
    "calculate_landed_cost_engine",
    "is_seller_paid_expense",
    "SettlementFx",
    "purchase_order_rate_to_egp",
    "file_po_line_shares",
    "recalculate_settlement_totals",
    "build_initial_settlement",
    "create_settlement_service",
    "recalculate_settlement_service",
    "update_settlement_service",
    "get_settlement_service",
    "list_settlements_service",
    "soft_delete_settlement_service",
    "restore_settlement_service",
    "simulate_estimated_landed_cost_service",
    "cairo_date",
    "cairo_today",
    "get_wht_rate_percent",
    "resolve_wht_rate_percent",
    "wht_amount_for",
    "aggregate_shipment_invoices_service",
    "confirm_invoices_settlement_service",
    "scale_item_fobs_to_header",
    "calculate_actual_landed_cost_service",
    "settlement_expense_row",
    "settlement_item_row",
    "approve_actual_landed_cost_service",
    "get_shipment_fx_reconciliation",
]

# Module-level constants re-exported so the facade keeps the pre-decomposition API.
from .actual_settlement_service import (  # noqa: F401
    ACTUAL_BUCKETS,
    ACTUAL_SOURCE_MISSING,
    ALLOCATION_BASIS_INCOMPLETE,
    BUCKET_ENGINE_CATEGORY,
    ESTIMATE_PARAMETER_DEFAULTS,
    ESTIMATE_UNAVAILABLE,
    IMPORT_FILE_LABEL_AR,
    PARAM_DEEMED_FREIGHT_PCT,
    PARAM_DEEMED_INSURANCE_PCT,
    PARAM_DEFAULT_BANK_FEES_EGP,
    PARAM_DEFAULT_CLEARANCE_EGP,
    PARAM_DEFAULT_INLAND_TRANSPORT_EGP,
    PARAM_DEFAULT_OTHER_EXPENSES_EGP,
    PARAM_DEFAULT_PORT_HANDLING_EGP,
    PAYMENT_STATUS_UNKNOWN,
    SETTLEMENT_LINE_NO_HS,
    SETTLEMENT_LINE_ZERO_VALUE,
    SETTLEMENT_UNPAID_INVOICE,
    WHT_RATE_MISSING_WARNING,
)
from .landed_cost_engine_service import (  # noqa: F401
    CUSTOMS_COMPONENT_BUCKET,
    DUTY_COMPONENT_CATEGORIES,
    ENGINE_CLEARANCE_CATEGORIES,
    ENGINE_CUSTOMS_CATEGORIES,
    ENGINE_FREIGHT_CATEGORIES,
    ENGINE_TRANSPORT_CATEGORIES,
    SETTLEMENT_RECALC_FIELDS,
)
from .settlement_crud_service import (  # noqa: F401
    _NON_NULL_UPDATE_FIELDS,
)
from .landed_cost_simulation_service import (  # noqa: F401
    _CAIRO_FALLBACK_TZ,
)
