"""
Seed initial dependency relationships into recalculation_dependency_map.

Run once after migration, or idempotently at startup.
Each row defines ONE directed edge:
  source_entity_type.source_field → target_entity_type.target_field

To add a new relationship in the future:
  1. Add ONE row here.
  2. Use <RecalculateButton entityType="..." entityId="..."/> in the UI.
  Done. No other code changes needed.
"""

import logging
from sqlalchemy.orm import Session
import modules.recalculation.repository as repo

logger = logging.getLogger("recalculation_seed")

# ─── Blocked statuses for import budgets ────────────────────────────────────
_BUDGET_BLOCKED_STATUSES = ["Budget Approved", "Superseded"]
_BUDGET_PERMISSION = "budget.sync_variance"

# ─── Blocked statuses for financial settlement ──────────────────────────────
_SETTLEMENT_BLOCKED_STATUSES = ["Approved", "Closed"]
_SETTLEMENT_PERMISSION = "financial_settlement.calculate"


DEPENDENCY_SEEDS = [
    # ── import_budget ← customs_consultation ────────────────────────────────
    {
        "target_entity_type": "import_budget",
        "target_field": "clearance_inland_egp",
        "source_entity_type": "customs_consultation",
        "source_field": "total_broker_fees_egp",
        "join_key": "import_file_id",
        "aggregation_function": "max",
        "blocked_statuses": _BUDGET_BLOCKED_STATUSES,
        "required_permission": _BUDGET_PERMISSION,
        "label_ar": "مصاريف التخليص من دراسة الجمارك",
        "label_en": "Clearance Inland Fees from Customs Consultation",
        "display_order": 10,
    },
    {
        "target_entity_type": "import_budget",
        "target_field": "customs_duties_egp",
        "source_entity_type": "customs_consultation",
        "source_field": "estimated_duties_egp",
        "join_key": "import_file_id",
        "aggregation_function": "max",
        "blocked_statuses": _BUDGET_BLOCKED_STATUSES,
        "required_permission": _BUDGET_PERMISSION,
        "label_ar": "الضرائب والرسوم الجمركية من دراسة الجمارك",
        "label_en": "Customs Duties & Taxes from Customs Consultation",
        "display_order": 20,
    },
    # ── import_budget ← shipping_scenarios ──────────────────────────────────
    {
        "target_entity_type": "import_budget",
        "target_field": "freight_cost_egp",
        "source_entity_type": "shipping_scenarios",
        "source_field": "total_quotation_amount",
        "join_key": "import_file_id",
        "aggregation_function": "max",
        "blocked_statuses": _BUDGET_BLOCKED_STATUSES,
        "required_permission": _BUDGET_PERMISSION,
        "label_ar": "النولون والشحن الدولي من دراسة الشحن",
        "label_en": "Freight & Shipping Cost from Shipping Scenarios",
        "display_order": 30,
    },
    # ── import_budget ← purchase_orders ─────────────────────────────────────
    {
        "target_entity_type": "import_budget",
        "target_field": "invoice_amount_egp",
        "source_entity_type": "purchase_orders",
        "source_field": "total_amount_fob",
        "join_key": "import_file_id",
        "aggregation_function": "sum",
        "blocked_statuses": _BUDGET_BLOCKED_STATUSES,
        "required_permission": _BUDGET_PERMISSION,
        "label_ar": "قيمة الفاتورة (FOB) من أوامر الشراء",
        "label_en": "Invoice Amount (FOB) from Purchase Orders",
        "display_order": 40,
    },

    # ── financial_settlement ← purchase_orders ──────────────────────────────
    {
        "target_entity_type": "financial_settlement",
        "target_field": "total_fob_egp",
        "source_entity_type": "purchase_orders",
        "source_field": "total_amount_fob",
        "join_key": "import_file_id",
        "aggregation_function": "sum",
        "blocked_statuses": _SETTLEMENT_BLOCKED_STATUSES,
        "required_permission": _SETTLEMENT_PERMISSION,
        "label_ar": "إجمالي قيمة البضاعة (FOB) من أوامر الشراء",
        "label_en": "Total FOB Value from Purchase Orders",
        "display_order": 10,
    },
]


RETIRED_DEPENDENCY_SEEDS = [
    # ── financial_settlement ← shipping_scenarios ───────────────────────────
    {
        "target_entity_type": "financial_settlement",
        "target_field": "freight_cost_egp",
        "source_entity_type": "shipping_scenarios",
        "source_field": "total_quotation_amount",
        "join_key": "import_file_id",
        "aggregation_function": "max",
        "blocked_statuses": _SETTLEMENT_BLOCKED_STATUSES,
        "required_permission": _SETTLEMENT_PERMISSION,
        "label_ar": "نولون الشحن الدولي من دراسة الشحن",
        "label_en": "Freight & Shipping Cost from Shipping Scenarios",
        "display_order": 20,
    },
    # ── financial_settlement ← customs_consultation ─────────────────────────
    {
        "target_entity_type": "financial_settlement",
        "target_field": "customs_duties_egp",
        "source_entity_type": "customs_consultation",
        "source_field": "estimated_duties_egp",
        "join_key": "import_file_id",
        "aggregation_function": "max",
        "blocked_statuses": _SETTLEMENT_BLOCKED_STATUSES,
        "required_permission": _SETTLEMENT_PERMISSION,
        "label_ar": "الضرائب والرسوم الجمركية من دراسة الجمارك",
        "label_en": "Customs Duties & Taxes from Customs Consultation",
        "display_order": 30,
    },
    {
        "target_entity_type": "financial_settlement",
        "target_field": "clearance_fees_egp",
        "source_entity_type": "customs_consultation",
        "source_field": "total_broker_fees_egp",
        "join_key": "import_file_id",
        "aggregation_function": "max",
        "blocked_statuses": _SETTLEMENT_BLOCKED_STATUSES,
        "required_permission": _SETTLEMENT_PERMISSION,
        "label_ar": "أتعاب التخليص والنقل من دراسة الجمارك",
        "label_en": "Clearance & Inland Fees from Customs Consultation",
        "display_order": 40,
    },
]



def run_seed(db: Session) -> int:
    """
    Idempotently seeds all dependency rows and deactivates retired seeds.
    Returns count of active rows upserted.
    """
    count = 0
    for seed in DEPENDENCY_SEEDS:
        repo.upsert_dependency(db=db, **seed)
        count += 1
    for retired in RETIRED_DEPENDENCY_SEEDS:
        repo.deactivate_dependency(
            db=db,
            target_entity_type=retired["target_entity_type"],
            target_field=retired["target_field"],
            source_entity_type=retired["source_entity_type"],
            source_field=retired["source_field"],
        )
    db.commit()
    logger.info("[RecalculationEngine] Seeded %d dependency rows and deactivated retired seeds.", count)
    print(f"[RecalculationEngine] Seeded {count} dependency rows.")
    return count



if __name__ == "__main__":
    from database.database import SessionLocal
    db = SessionLocal()
    try:
        run_seed(db)
    finally:
        db.close()
