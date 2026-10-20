"""add users.token_version (BEX-T08)

Token session versioning for invalidating older tokens upon password change,
admin password reset, role update, and account deactivation.

Revision ID: c9d0e1f2a3b4
Revises: b8c9d0e1f2a3
Create Date: 2026-10-19
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "c9d0e1f2a3b4"
down_revision: Union[str, Sequence[str], None] = "b8c9d0e1f2a3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE = "users"
COLUMN = "token_version"


def _has_column() -> bool:
    inspector = sa.inspect(op.get_bind())
    if TABLE not in inspector.get_table_names():
        return True  # no users table yet: create_all builds it from the models
    return any(c["name"].lower() == COLUMN for c in inspector.get_columns(TABLE))


def upgrade() -> None:
    if _has_column():
        return
    with op.batch_alter_table(TABLE) as batch_op:
        batch_op.add_column(sa.Column(COLUMN, sa.Integer(), nullable=False, server_default=sa.text("0")))


def downgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    if TABLE not in inspector.get_table_names():
        return
    if not any(c["name"].lower() == COLUMN for c in inspector.get_columns(TABLE)):
        return
    with op.batch_alter_table(TABLE) as batch_op:
        batch_op.drop_column(COLUMN)
