"""net FOB valuation snapshot on import_files (single net FOB engine, FX anchor, zero double counting)

Trello qJZNzixC. Adds the persisted FOB valuation snapshot (currency, foreign amount, applied FX anchor rate and
source, EGP total, separated supplier financing markup, customs base at the Form 46 rate, Open Account
mark-to-market). Existing rows stay NULL ("not valued yet"); the next CLO-01 / CLO-02 / revaluation writes them.

Revision ID: c4e8a2f6b1d9
Revises: b8d2f4a6c1e3
Create Date: 2026-11-12 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c4e8a2f6b1d9'
down_revision: Union[str, Sequence[str], None] = 'b8d2f4a6c1e3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE = 'import_files'

# (column, SQL type, CHECK expression or None). SQLite accepts a column-level CHECK on ADD COLUMN (NULL passes).
COLUMNS = (
    ('fob_currency', 'VARCHAR(10)', None),
    ('fob_foreign_amount', 'FLOAT', 'fob_foreign_amount IS NULL OR fob_foreign_amount >= 0'),
    ('fob_exchange_rate', 'FLOAT', 'fob_exchange_rate IS NULL OR fob_exchange_rate > 0'),
    ('fob_total_egp', 'FLOAT', 'fob_total_egp IS NULL OR fob_total_egp >= 0'),
    ('financing_markup_amount', 'FLOAT', 'financing_markup_amount IS NULL OR financing_markup_amount >= 0'),
    ('financing_markup_egp', 'FLOAT', 'financing_markup_egp IS NULL OR financing_markup_egp >= 0'),
    ('fob_rate_source', 'VARCHAR(40)', None),
    ('fob_rate_date', 'DATE', None),
    ('fob_customs_exchange_rate', 'FLOAT', None),
    ('fob_customs_value_egp', 'FLOAT', None),
    ('fob_unrealized_fx_egp', 'FLOAT', None),
    ('fob_valued_at', 'DATETIME', None),
    ('fob_valued_by', 'VARCHAR(100)', None),
)


def _columns(inspector) -> set:
    return {c['name'] for c in inspector.get_columns(TABLE)}


def upgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    if TABLE not in inspector.get_table_names():
        return
    existing = _columns(inspector)
    for name, sql_type, check in COLUMNS:
        if name in existing:
            continue
        clause = f" CONSTRAINT ck_{TABLE}_{name} CHECK ({check})" if check else ""
        op.execute(f"ALTER TABLE {TABLE} ADD COLUMN {name} {sql_type}{clause}")


def downgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    if TABLE not in inspector.get_table_names():
        return
    existing = _columns(inspector)
    for name, _sql_type, _check in reversed(COLUMNS):
        if name in existing:
            # Native DROP COLUMN (SQLite >= 3.35) drops the column-level CHECK with it.
            op.execute(f"ALTER TABLE {TABLE} DROP COLUMN {name}")
