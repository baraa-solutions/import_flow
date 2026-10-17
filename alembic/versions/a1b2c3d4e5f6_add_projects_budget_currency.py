"""Add budget_currency to projects

Revision ID: a1b2c3d4e5f6
Revises: e4f5a6b7c8d9
Create Date: 2026-10-10 02:15:00.000000
"""
from typing import Sequence, Union
import sqlalchemy as sa
from alembic import op

revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, Sequence[str], None] = "e4f5a6b7c8d9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if "projects" in tables:
        existing = {c["name"].lower() for c in inspector.get_columns("projects")}
        with op.batch_alter_table("projects") as batch_op:
            if "budget_currency" not in existing:
                batch_op.add_column(
                    sa.Column("budget_currency", sa.String(10), server_default="USD", nullable=False)
                )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if "projects" in tables:
        existing = {c["name"].lower() for c in inspector.get_columns("projects")}
        with op.batch_alter_table("projects") as batch_op:
            if "budget_currency" in existing:
                batch_op.drop_column("budget_currency")
