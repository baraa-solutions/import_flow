"""Add shipped_on_board_date to shipment_bookings (BE45-T11)

Revision ID: b2c3d4e5f6a7
Revises: a0b1c2d3e4f5
Create Date: 2026-10-13 19:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b2c3d4e5f6a7'
down_revision: Union[str, Sequence[str], None] = 'a0b1c2d3e4f5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = [c['name'] for c in inspector.get_columns('shipment_bookings')]
    if 'shipped_on_board_date' not in columns:
        with op.batch_alter_table('shipment_bookings', schema=None) as batch_op:
            batch_op.add_column(sa.Column('shipped_on_board_date', sa.Date(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table('shipment_bookings', schema=None) as batch_op:
        batch_op.drop_column('shipped_on_board_date')
