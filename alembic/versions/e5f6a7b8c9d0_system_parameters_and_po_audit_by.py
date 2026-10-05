"""system_parameters table + purchase order audit-by columns (Phase 1, package A)

- New table ``system_parameters`` (generic key/value business constants). When THIS migration creates the
  table it also inserts the default ``AIR_VOLUMETRIC_KG_PER_CBM = 167`` (CTO decision Q1, 2026-10-05). A table
  that already exists (built by create_all) is left untouched; readers fall back to the same default when
  the row is missing (``modules.common.system_parameters``).
- ``created_by`` / ``updated_by`` (String(100), nullable) on ``purchase_orders`` and
  ``po_shipment_allocations`` (audit trail, PO-09). Legacy rows keep NULL.

Defensive: tables / columns are created only when missing.

Revision ID: e5f6a7b8c9d0
Revises: d9e4f5a6b7c8
Create Date: 2026-10-05 18:00:00.000000
"""
from datetime import datetime, timezone
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "e5f6a7b8c9d0"
down_revision: Union[str, Sequence[str], None] = "d9e4f5a6b7c8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

SYSTEM_PARAMETERS = "system_parameters"
AUDIT_BY_TABLES = ("purchase_orders", "po_shipment_allocations")
AUDIT_BY_COLUMNS = ("created_by", "updated_by")

DEFAULT_ROWS = (
    (
        "AIR_VOLUMETRIC_KG_PER_CBM",
        "167",
        "Air freight volumetric factor (kg per CBM) for chargeable weight; used by purchase orders and the CBM calculator",
    ),
)


def _create_system_parameters() -> None:
    table = op.create_table(
        SYSTEM_PARAMETERS,
        sa.Column("param_id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("param_key", sa.String(100), nullable=False),
        sa.Column("param_value", sa.String(255), nullable=False),
        sa.Column("description", sa.String(255), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("1")),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("created_by", sa.String(100), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.Column("updated_by", sa.String(100), nullable=True),
    )
    op.create_index("ix_system_parameters_param_id", SYSTEM_PARAMETERS, ["param_id"])
    op.create_index("ix_system_parameters_param_key", SYSTEM_PARAMETERS, ["param_key"], unique=True)
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    op.bulk_insert(
        table,
        [
            {
                "param_key": key,
                "param_value": value,
                "description": description,
                "is_active": True,
                "created_at": now,
                "created_by": "system",
                "updated_at": now,
                "updated_by": "system",
            }
            for key, value, description in DEFAULT_ROWS
        ],
    )


def upgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    tables = set(inspector.get_table_names())
    if SYSTEM_PARAMETERS not in tables:
        _create_system_parameters()

    for table_name in AUDIT_BY_TABLES:
        if table_name not in tables:
            continue
        existing = {c["name"].lower() for c in inspector.get_columns(table_name)}
        missing = [c for c in AUDIT_BY_COLUMNS if c not in existing]
        if missing:
            with op.batch_alter_table(table_name) as batch_op:
                for column in missing:
                    batch_op.add_column(sa.Column(column, sa.String(100), nullable=True))


def downgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    tables = set(inspector.get_table_names())
    for table_name in AUDIT_BY_TABLES:
        if table_name not in tables:
            continue
        existing = {c["name"].lower() for c in inspector.get_columns(table_name)}
        present = [c for c in AUDIT_BY_COLUMNS if c in existing]
        if present:
            with op.batch_alter_table(table_name) as batch_op:
                for column in present:
                    batch_op.drop_column(column)
    if SYSTEM_PARAMETERS in tables:
        op.drop_table(SYSTEM_PARAMETERS)
