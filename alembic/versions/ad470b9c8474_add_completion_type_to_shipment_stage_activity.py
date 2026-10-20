"""add completion_type to shipment_stage_activity

Tracks how each lifecycle step was transitioned:
'real' (actual action/data), 'auto' (auto-reconciled prior step),
'skipped' (authorized skip), 'bypassed' (initialization bypass).

Revision ID: ad470b9c8474
Revises: d0e1f2a3b4c5
Create Date: 2026-10-19
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "ad470b9c8474"
down_revision: Union[str, Sequence[str], None] = "d0e1f2a3b4c5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE = "shipment_stage_activity"
COLUMN = "completion_type"


def _has_column() -> bool:
    inspector = sa.inspect(op.get_bind())
    if TABLE not in inspector.get_table_names():
        return True
    return any(c["name"].lower() == COLUMN for c in inspector.get_columns(TABLE))


def upgrade() -> None:
    if _has_column():
        return
    with op.batch_alter_table(TABLE) as batch_op:
        batch_op.add_column(sa.Column(COLUMN, sa.String(length=30), nullable=True))


def downgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    if TABLE not in inspector.get_table_names():
        return
    if not any(c["name"].lower() == COLUMN for c in inspector.get_columns(TABLE)):
        return
    with op.batch_alter_table(TABLE) as batch_op:
        batch_op.drop_column(COLUMN)
