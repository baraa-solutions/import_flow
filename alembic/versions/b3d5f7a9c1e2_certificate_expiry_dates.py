"""certificate & Nafeza token expiry dates on import companies and suppliers

Revision ID: b3d5f7a9c1e2
Revises: a7c1e9d3f5b2
Create Date: 2026-11-09 14:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b3d5f7a9c1e2'
down_revision: Union[str, Sequence[str], None] = 'a7c1e9d3f5b2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

CERTIFICATES = ('wipo_expiry', 'euipo_expiry', 'global_brand_expiry', 'iso_9001_expiry')
COLUMNS = {
    'import_companies': ('nafeza_token_expiry',) + CERTIFICATES,
    'suppliers': CERTIFICATES,
}


def _existing(table: str) -> set:
    return {c['name'] for c in sa.inspect(op.get_bind()).get_columns(table)}


def upgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    for table, columns in COLUMNS.items():
        if table not in tables:
            continue
        present = _existing(table)
        for column in columns:
            if column not in present:
                op.add_column(table, sa.Column(column, sa.Date(), nullable=True))


def downgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    for table, columns in COLUMNS.items():
        if table not in tables:
            continue
        present = _existing(table)
        for column in columns:
            if column in present:
                op.execute(f'ALTER TABLE {table} DROP COLUMN {column}')
