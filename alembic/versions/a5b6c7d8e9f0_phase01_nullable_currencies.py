"""make currency fields nullable across phase 01 modules (BE01-T18)

Invented defaults ('USD', 'EGP') were removed across:
- shipping_scenario_items (22 currency columns + quotation_currency)
- import_requirement_assessments (currency)
- clearance_expense_types (default_currency)
- broker_price_list_items (currency)
- customs_broker_quote_items (currency)
- freight_quotation_items (currency_code)

Revision ID: a5b6c7d8e9f0
Revises: f4b5c6d7e8f9
Create Date: 2026-10-18
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers
revision: str = "a5b6c7d8e9f0"
down_revision: Union[str, Sequence[str], None] = "f4b5c6d7e8f9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE_COLUMNS = {
    "shipping_scenario_items": [
        "quotation_currency",
        "container_40ft_currency",
        "container_20ft_currency",
        "lcl_cbm_currency",
        "express_courier_currency",
        "eur_atr_currency",
        "solas_vgm_currency",
        "vgm_notification_currency",
        "telex_release_currency",
        "insurance_currency",
        "booking_cancellation_currency",
        "ics2_filing_fee_currency",
        "others_fee_currency",
        "document_fees_currency",
        "waiver_letter_fee_currency",
        "dthc_currency",
        "storage_per_week_currency",
        "extra_day_storage_currency",
        "clearance_fee_currency",
        "inspection_fee_currency",
        "inland_transport_fee_currency",
        "port_expenses_currency",
    ],
    "import_requirement_assessments": ["currency"],
    "clearance_expense_types": ["default_currency"],
    "broker_price_list_items": ["currency"],
    "customs_broker_quote_items": ["currency"],
    "freight_quotation_items": ["currency_code"],
}


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing_tables = set(inspector.get_table_names())

    for table_name, cols_to_check in TABLE_COLUMNS.items():
        if table_name not in existing_tables:
            continue
        cols = {c["name"].lower(): c for c in inspector.get_columns(table_name)}
        to_alter = [name for name in cols_to_check if name in cols and not cols[name].get("nullable", True)]
        if not to_alter:
            continue
        with op.batch_alter_table(table_name) as batch_op:
            for name in to_alter:
                batch_op.alter_column(name, existing_type=sa.String(length=10), nullable=True)


def downgrade() -> None:
    # Restoring NOT NULL would fail on legitimate rows with no applicable charge, so columns stay nullable.
    pass
