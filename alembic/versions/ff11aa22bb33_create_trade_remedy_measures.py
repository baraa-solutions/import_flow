"""create trade_remedy_measures (anti-dumping, safeguard and countervailing duties)

Revision ID: ff11aa22bb33
Revises: ee66aa77bb88
Create Date: 2026-11-06 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ff11aa22bb33'
down_revision: Union[str, Sequence[str], None] = 'ee66aa77bb88'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE = 'trade_remedy_measures'


def upgrade() -> None:
    if TABLE in sa.inspect(op.get_bind()).get_table_names():
        return
    op.create_table(
        TABLE,
        sa.Column('measure_id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
        sa.Column('measure_code', sa.String(length=30), nullable=False),
        sa.Column('measure_type', sa.String(length=30), nullable=False),
        sa.Column('hs_code', sa.String(length=20), nullable=False),
        sa.Column('origin_country', sa.String(length=2), nullable=True),
        sa.Column('exporter_name', sa.String(length=200), nullable=True),
        sa.Column('duty_basis', sa.String(length=30), nullable=False),
        sa.Column('rate_percent', sa.Numeric(7, 3), nullable=True),
        sa.Column('fixed_amount', sa.Numeric(14, 2), nullable=True),
        sa.Column('fixed_currency', sa.String(length=3), nullable=True),
        sa.Column('decree_ref', sa.String(length=100), nullable=False),
        sa.Column('effective_from', sa.Date(), nullable=False),
        sa.Column('effective_to', sa.Date(), nullable=True),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('created_by', sa.String(length=100), nullable=True),
        sa.Column('updated_by', sa.String(length=100), nullable=True),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('deleted_by', sa.String(length=100), nullable=True),
        sa.UniqueConstraint('measure_code', name='uq_trade_remedy_measure_code'),
    )
    op.create_index('ix_trade_remedy_measures_measure_code', TABLE, ['measure_code'], unique=False)
    op.create_index('ix_trade_remedy_measures_measure_type', TABLE, ['measure_type'], unique=False)
    op.create_index('ix_trade_remedy_measures_hs_code', TABLE, ['hs_code'], unique=False)
    op.create_index('ix_trade_remedy_measures_origin_country', TABLE, ['origin_country'], unique=False)
    op.create_index('ix_trade_remedy_measures_is_active', TABLE, ['is_active'], unique=False)
    op.create_index('ix_trade_remedy_measures_measure_id', TABLE, ['measure_id'], unique=False)


def downgrade() -> None:
    if TABLE in sa.inspect(op.get_bind()).get_table_names():
        op.drop_table(TABLE)
