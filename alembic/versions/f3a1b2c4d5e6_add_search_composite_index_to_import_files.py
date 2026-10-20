"""add search composite index to import_files (UX-SEARCH-013)

Revision ID: f3a1b2c4d5e6
Revises: ad470b9c8474
Create Date: 2026-10-20
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "f3a1b2c4d5e6"
down_revision: Union[str, Sequence[str], None] = "ad470b9c8474"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE = "import_files"
INDEX_NAME = "idx_import_files_search_comp"
COLUMNS = ["company_id", "supplier_id", "hs_code"]


def _has_index() -> bool:
    inspector = sa.inspect(op.get_bind())
    if TABLE not in inspector.get_table_names():
        return True
    indexes = inspector.get_indexes(TABLE)
    return any(idx.get("name") == INDEX_NAME for idx in indexes)


def upgrade() -> None:
    if _has_index():
        return
    op.create_index(
        INDEX_NAME,
        TABLE,
        COLUMNS,
        unique=False,
    )


def downgrade() -> None:
    if not _has_index():
        return
    op.drop_index(INDEX_NAME, table_name=TABLE)
