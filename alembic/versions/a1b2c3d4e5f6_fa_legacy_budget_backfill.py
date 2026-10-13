"""Backfill legacy budget columns and set server defaults (BE02-T05, BE02-F05)

- Backfill revision_number = 1 on import_budget_approvals where NULL
- Backfill has_unresolved_variance = 0 on import_budget_approvals where NULL
- Backfill version = 1 on import_budget_approvals where NULL
- Backfill version = 1 on payment_request_sessions where NULL
- Defensive: guard each column with inspector.get_columns so it is a no-op when absent.
- Downgrade: no-op.

Revision ID: a1b2c3d4e5f6
Revises: a0b1c2d3e4f5
Create Date: 2026-10-13 10:00:00.000000
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, Sequence[str], None] = "a0b1c2d3e4f5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if "import_budget_approvals" in tables:
        bgt_cols = {c["name"].lower() for c in inspector.get_columns("import_budget_approvals")}
        if "revision_number" in bgt_cols:
            op.execute("UPDATE import_budget_approvals SET revision_number = 1 WHERE revision_number IS NULL")
        if "has_unresolved_variance" in bgt_cols:
            op.execute("UPDATE import_budget_approvals SET has_unresolved_variance = 0 WHERE has_unresolved_variance IS NULL")
        if "version" in bgt_cols:
            op.execute("UPDATE import_budget_approvals SET version = 1 WHERE version IS NULL")

    if "payment_request_sessions" in tables:
        pay_cols = {c["name"].lower() for c in inspector.get_columns("payment_request_sessions")}
        if "version" in pay_cols:
            op.execute("UPDATE payment_request_sessions SET version = 1 WHERE version IS NULL")


def downgrade() -> None:
    pass
