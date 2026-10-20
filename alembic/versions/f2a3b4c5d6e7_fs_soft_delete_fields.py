"""add deleted_at and deleted_by soft delete audit fields to financial_settlement_records (BE09-T14)

Revision ID: f2a3b4c5d6e7
Revises: f1a2b3c4d5e6
Create Date: 2026-10-19
"""

from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers
revision: str = "f2a3b4c5d6e7"
down_revision: Union[str, Sequence[str], None] = "f1a2b3c4d5e6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE_NAME = "financial_settlement_records"


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if TABLE_NAME not in set(inspector.get_table_names()):
        return

    existing_cols = {col["name"] for col in inspector.get_columns(TABLE_NAME)}

    if "deleted_at" not in existing_cols:
        op.add_column(TABLE_NAME, sa.Column("deleted_at", sa.DateTime(), nullable=True))

    if "deleted_by" not in existing_cols:
        op.add_column(TABLE_NAME, sa.Column("deleted_by", sa.String(length=100), nullable=True))


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if TABLE_NAME not in set(inspector.get_table_names()):
        return

    existing_cols = {col["name"] for col in inspector.get_columns(TABLE_NAME)}

    if "deleted_by" in existing_cols:
        op.drop_column(TABLE_NAME, "deleted_by")

    if "deleted_at" in existing_cols:
        op.drop_column(TABLE_NAME, "deleted_at")
