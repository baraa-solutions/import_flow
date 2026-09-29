"""add users.must_change_password

Forced password change for the seeded default admin. Existing users keep ``false`` (server default 0).

Defensive (see e1f2a3b4c5d6): a DB built by ``create_all`` from the current models already has the
column, so it is only added when missing.

Revision ID: f7a1c3e5b9d2
Revises: e1f2a3b4c5d6
Create Date: 2026-09-29 12:00:00.000000
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "f7a1c3e5b9d2"
down_revision: Union[str, Sequence[str], None] = "e1f2a3b4c5d6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE = "users"
COLUMN = "must_change_password"


def _has_column() -> bool:
    inspector = sa.inspect(op.get_bind())
    if TABLE not in inspector.get_table_names():
        return True  # no users table yet: create_all builds it from the models, column included
    return any(c["name"].lower() == COLUMN for c in inspector.get_columns(TABLE))


def upgrade() -> None:
    if _has_column():
        return
    with op.batch_alter_table(TABLE) as batch_op:
        batch_op.add_column(sa.Column(COLUMN, sa.Boolean(), nullable=False, server_default=sa.text("0")))


def downgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    if TABLE not in inspector.get_table_names():
        return
    if not any(c["name"].lower() == COLUMN for c in inspector.get_columns(TABLE)):
        return
    with op.batch_alter_table(TABLE) as batch_op:
        batch_op.drop_column(COLUMN)
