"""exclusive payment pathway: import_files.payment_term + one active finance instrument per file

Revision ID: a7c1e9d3f5b2
Revises: ff11aa22bb33
Create Date: 2026-11-09 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a7c1e9d3f5b2'
down_revision: Union[str, Sequence[str], None] = 'ff11aa22bb33'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

FILES = 'import_files'
INSTRUMENTS = 'import_finance_instruments'
TERM_INDEX = 'ix_import_files_payment_term'
UNIQUE_INSTRUMENT = 'uq_finance_instrument_active_per_file'
TERMS_SQL = "'ADVANCE_PAYMENT', 'LC', 'CAD', 'OPEN_ACCOUNT'"
ACTIVE_PRIMARY = "is_active = 1 AND status != 'CANCELLED'"


def _columns(inspector, table: str) -> set:
    return {c['name'] for c in inspector.get_columns(table)}


def _indexes(inspector, table: str) -> set:
    return {ix['name'] for ix in inspector.get_indexes(table)}


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if FILES in tables:
        if 'payment_term' not in _columns(inspector, FILES):
            # SQLite accepts a CHECK clause on ADD COLUMN (existing rows are NULL, which passes it).
            op.execute(
                f"ALTER TABLE {FILES} ADD COLUMN payment_term VARCHAR(20) "
                f"CONSTRAINT ck_import_files_payment_term "
                f"CHECK (payment_term IS NULL OR payment_term IN ({TERMS_SQL}))"
            )
        if TERM_INDEX not in _indexes(inspector, FILES):
            op.create_index(TERM_INDEX, FILES, ['payment_term'], unique=False)

    if INSTRUMENTS in tables and UNIQUE_INSTRUMENT not in _indexes(inspector, INSTRUMENTS):
        duplicates = bind.execute(sa.text(
            f"SELECT import_file_id FROM {INSTRUMENTS} WHERE {ACTIVE_PRIMARY} "
            f"GROUP BY import_file_id HAVING COUNT(*) > 1"
        )).fetchall()
        if duplicates:
            # Existing conflicting financing must be resolved by finance first; the application guard
            # (trade_finance.payment_pathway) still blocks new conflicts meanwhile.
            print(
                f"[a7c1e9d3f5b2] skipped {UNIQUE_INSTRUMENT}: import files with several active instruments: "
                f"{[row[0] for row in duplicates]}"
            )
        else:
            op.create_index(
                UNIQUE_INSTRUMENT,
                INSTRUMENTS,
                ['import_file_id'],
                unique=True,
                sqlite_where=sa.text(ACTIVE_PRIMARY),
            )


def downgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    tables = set(inspector.get_table_names())
    if INSTRUMENTS in tables and UNIQUE_INSTRUMENT in _indexes(inspector, INSTRUMENTS):
        op.drop_index(UNIQUE_INSTRUMENT, table_name=INSTRUMENTS)
    if FILES in tables:
        if TERM_INDEX in _indexes(inspector, FILES):
            op.drop_index(TERM_INDEX, table_name=FILES)
        if 'payment_term' in _columns(inspector, FILES):
            # Native DROP COLUMN (SQLite >= 3.35) drops the column-level CHECK with it; a batch rebuild
            # would copy the reflected CHECK onto the new table and fail on the missing column.
            op.execute(f"ALTER TABLE {FILES} DROP COLUMN payment_term")
