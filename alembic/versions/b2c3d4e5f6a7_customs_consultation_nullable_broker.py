"""make broker_id and broker_name nullable in customs_consultation_sessions

Revision ID: b2c3d4e5f6a7
Revises: a0b1c2d3e4f5
Create Date: 2026-10-10
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers
revision: str = "b2c3d4e5f6a7"
down_revision: Union[str, Sequence[str], None] = "a0b1c2d3e4f5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())
    if "customs_consultation_sessions" not in tables:
        return
    cols = {c["name"].lower(): c for c in inspector.get_columns("customs_consultation_sessions")}
    needs_alter = False
    if "broker_id" in cols and not cols["broker_id"].get("nullable", True):
        needs_alter = True
    if "broker_name" in cols and not cols["broker_name"].get("nullable", True):
        needs_alter = True

    if needs_alter:
        with op.batch_alter_table("customs_consultation_sessions") as batch_op:
            batch_op.alter_column(
                "broker_id",
                existing_type=sa.Integer(),
                nullable=True,
            )
            batch_op.alter_column(
                "broker_name",
                existing_type=sa.String(length=200),
                nullable=True,
            )


def downgrade() -> None:
    with op.batch_alter_table("customs_consultation_sessions") as batch_op:
        batch_op.alter_column(
            "broker_name",
            existing_type=sa.String(length=200),
            nullable=False,
        )
        batch_op.alter_column(
            "broker_id",
            existing_type=sa.Integer(),
            nullable=False,
        )
