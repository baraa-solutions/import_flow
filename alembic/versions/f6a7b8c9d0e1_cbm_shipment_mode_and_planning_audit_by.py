"""CBM shipment_mode + created_by / updated_by on planning sessions (Phase 1, package B)

- ``cbm_calculations.shipment_mode`` String(10), nullable: SHIPMENT_MODE code (AIR / SEA). Legacy rows keep
  NULL (= unknown; the old API always answered "air" because the column did not exist).
- ``created_by`` / ``updated_by`` String(100), nullable on ``cbm_calculations``,
  ``shipping_evaluation_sessions`` and ``customs_consultation_sessions`` (audit trail). Legacy rows keep NULL.

Defensive and additive: columns are added only when missing (create_all / startup step 4b may already
have added them on an unstamped database). No data is written.

Revision ID: f6a7b8c9d0e1
Revises: e5f6a7b8c9d0
Create Date: 2026-10-05 20:00:00.000000
"""
from typing import Sequence, Tuple, Union

import sqlalchemy as sa
from alembic import op

revision: str = "f6a7b8c9d0e1"
down_revision: Union[str, Sequence[str], None] = "e5f6a7b8c9d0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# table -> ((column, length), ...)
NEW_COLUMNS: Tuple[Tuple[str, Tuple[Tuple[str, int], ...]], ...] = (
    ("cbm_calculations", (("shipment_mode", 10), ("created_by", 100), ("updated_by", 100))),
    ("shipping_evaluation_sessions", (("created_by", 100), ("updated_by", 100))),
    ("customs_consultation_sessions", (("created_by", 100), ("updated_by", 100))),
)


def upgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    tables = set(inspector.get_table_names())
    for table_name, columns in NEW_COLUMNS:
        if table_name not in tables:
            continue
        existing = {c["name"].lower() for c in inspector.get_columns(table_name)}
        missing = [(name, length) for name, length in columns if name not in existing]
        if missing:
            with op.batch_alter_table(table_name) as batch_op:
                for name, length in missing:
                    batch_op.add_column(sa.Column(name, sa.String(length), nullable=True))


def downgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    tables = set(inspector.get_table_names())
    for table_name, columns in NEW_COLUMNS:
        if table_name not in tables:
            continue
        existing = {c["name"].lower() for c in inspector.get_columns(table_name)}
        present = [name for name, _ in columns if name in existing]
        if present:
            with op.batch_alter_table(table_name) as batch_op:
                for name in present:
                    batch_op.drop_column(name)
