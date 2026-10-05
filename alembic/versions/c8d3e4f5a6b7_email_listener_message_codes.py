"""email listener message codes (single-language storage, Phase B)

Adds nullable ``msg_code`` / ``msg_params`` to ``inbound_email_logs`` (for ``notes``) and ``email_settings``
(for ``last_sync_message``). No data migration: legacy rows keep NULL codes and render their stored text.

Defensive like b7c1d2e3f4a5: per column, added only when missing; a missing table is skipped (create_all
builds it from the models, columns included).

Revision ID: c8d3e4f5a6b7
Revises: b7c1d2e3f4a5
Create Date: 2026-09-29 21:00:00.000000
"""
from typing import Dict, List, Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "c8d3e4f5a6b7"
down_revision: Union[str, Sequence[str], None] = "b7c1d2e3f4a5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _columns() -> Dict[str, List[sa.Column]]:
    return {
        table: [sa.Column("msg_code", sa.String(80), nullable=True), sa.Column("msg_params", sa.JSON(), nullable=True)]
        for table in ("inbound_email_logs", "email_settings")
    }


def upgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    tables = set(inspector.get_table_names())
    for table, columns in _columns().items():
        if table not in tables:
            continue
        existing = {c["name"].lower() for c in inspector.get_columns(table)}
        missing = [c for c in columns if c.name.lower() not in existing]
        if not missing:
            continue
        with op.batch_alter_table(table) as batch_op:
            for column in missing:
                batch_op.add_column(column)


def downgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    tables = set(inspector.get_table_names())
    for table, columns in _columns().items():
        if table not in tables:
            continue
        existing = {c["name"].lower() for c in inspector.get_columns(table)}
        present = [c.name for c in columns if c.name.lower() in existing]
        if not present:
            continue
        with op.batch_alter_table(table) as batch_op:
            for name in present:
                batch_op.drop_column(name)
