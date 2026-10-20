"""dedupe shipment_stage_activity and enforce unique file_code and step_code (BEX-T16)

Deduplicates any multiple entries for the same (import_file_code, step_code) pair,
retaining the newest row (highest id), and creates a unique index
uq_shipment_stage_activity_file_step to prevent duplicate stage entries under
concurrent advances.

Revision ID: f4b5c6d7e8f9
Revises: d0e1f2a3b4c5
Create Date: 2026-10-18
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers
revision: str = "f4b5c6d7e8f9"
down_revision: Union[str, Sequence[str], None] = "d0e1f2a3b4c5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE = "shipment_stage_activity"
INDEX_NAME = "uq_shipment_stage_activity_file_step"


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if TABLE not in set(inspector.get_table_names()):
        return

    # 1. Deduplicate keeping the latest row (highest id) per (import_file_code, step_code)
    op.execute(
        sa.text(
            f"""
            DELETE FROM {TABLE}
            WHERE id NOT IN (
                SELECT MAX(id)
                FROM {TABLE}
                GROUP BY import_file_code, step_code
            )
            """
        )
    )

    # 2. Create unique index on (import_file_code, step_code)
    existing_indexes = {ix["name"] for ix in inspector.get_indexes(TABLE)}
    if INDEX_NAME not in existing_indexes:
        op.create_index(
            INDEX_NAME,
            TABLE,
            ["import_file_code", "step_code"],
            unique=True,
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if TABLE in set(inspector.get_table_names()):
        existing_indexes = {ix["name"] for ix in inspector.get_indexes(TABLE)}
        if INDEX_NAME in existing_indexes:
            op.drop_index(INDEX_NAME, table_name=TABLE)
