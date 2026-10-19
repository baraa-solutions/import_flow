"""add paid_amount_egp and paid_exchange_rate to payment_request_sessions (ACC2-T07)

Revision ID: d0e1f2a3b4c5
Revises: c9d0e1f2a3b4
Create Date: 2026-10-19
"""

from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers
revision: str = "d0e1f2a3b4c5"
down_revision: Union[str, Sequence[str], None] = "c9d0e1f2a3b4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE_NAME = "payment_request_sessions"


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if TABLE_NAME not in set(inspector.get_table_names()):
        return

    existing_cols = {col["name"] for col in inspector.get_columns(TABLE_NAME)}

    if "paid_amount_egp" not in existing_cols:
        op.add_column(TABLE_NAME, sa.Column("paid_amount_egp", sa.Float(), nullable=True))

    if "paid_exchange_rate" not in existing_cols:
        op.add_column(TABLE_NAME, sa.Column("paid_exchange_rate", sa.Float(), nullable=True))


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if TABLE_NAME not in set(inspector.get_table_names()):
        return

    existing_cols = {col["name"] for col in inspector.get_columns(TABLE_NAME)}

    if "paid_exchange_rate" in existing_cols:
        op.drop_column(TABLE_NAME, "paid_exchange_rate")

    if "paid_amount_egp" in existing_cols:
        op.drop_column(TABLE_NAME, "paid_amount_egp")
