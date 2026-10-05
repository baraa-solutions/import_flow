"""system message codes (single-language storage, Phase A)

Adds nullable message-code / step-code columns next to the legacy text columns. No data migration:
legacy rows keep NULL codes and render their stored text.

Defensive like f7a1c3e5b9d2: per column, added only when missing; a missing table is skipped (create_all
builds it from the models, columns included). Indexes are created only when missing.

Revision ID: b7c1d2e3f4a5
Revises: f7a1c3e5b9d2
Create Date: 2026-09-29 18:00:00.000000
"""
from typing import Dict, List, Sequence, Tuple, Union

import sqlalchemy as sa
from alembic import op

revision: str = "b7c1d2e3f4a5"
down_revision: Union[str, Sequence[str], None] = "f7a1c3e5b9d2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _columns() -> Dict[str, List[sa.Column]]:
    return {
        "smart_tasks": [
            sa.Column("msg_code", sa.String(80), nullable=True),
            sa.Column("msg_params", sa.JSON(), nullable=True),
            sa.Column("step_code", sa.String(50), nullable=True),
        ],
        "system_notifications": [
            sa.Column("msg_code", sa.String(80), nullable=True),
            sa.Column("msg_params", sa.JSON(), nullable=True),
        ],
        "shipment_stage_activity": [
            sa.Column("msg_code", sa.String(80), nullable=True),
            sa.Column("msg_params", sa.JSON(), nullable=True),
        ],
        "import_files": [
            sa.Column("current_step_code", sa.String(50), nullable=True),
            sa.Column("current_phase_id", sa.Integer(), nullable=True),
            sa.Column("current_stage_code", sa.String(50), nullable=True),
            sa.Column("next_action_code", sa.String(80), nullable=True),
            sa.Column("next_action_params", sa.JSON(), nullable=True),
            sa.Column("hold_reason_code", sa.String(50), nullable=True),
        ],
        "guide_entries": [
            sa.Column("msg_code", sa.String(80), nullable=True),
            sa.Column("msg_params", sa.JSON(), nullable=True),
        ],
    }


INDEXES: List[Tuple[str, str, List[str]]] = [
    ("idx_smart_tasks_step_code", "smart_tasks", ["import_file_id", "step_code"]),
    ("idx_import_files_current_phase_id", "import_files", ["current_phase_id"]),
]


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

    inspector = sa.inspect(op.get_bind())
    for name, table, cols in INDEXES:
        if table not in tables:
            continue
        if any(ix["name"] == name for ix in inspector.get_indexes(table)):
            continue
        op.create_index(name, table, cols)


def downgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    tables = set(inspector.get_table_names())
    for name, table, _ in INDEXES:
        if table in tables and any(ix["name"] == name for ix in inspector.get_indexes(table)):
            op.drop_index(name, table_name=table)
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
