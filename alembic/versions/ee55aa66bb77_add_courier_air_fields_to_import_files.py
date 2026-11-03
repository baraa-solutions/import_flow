"""add_courier_air_fields_to_import_files

Revision ID: ee55aa66bb77
Revises: ee44aa55bb66
Create Date: 2026-11-03 00:00:00.000000

Adds air freight and express courier columns to import_files:
- shipment_sub_mode
- courier_operator
- chargeable_divisor
- acid_requirement
- acid_exemption_reason
- courier_tracking_no
"""

from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ee55aa66bb77'
down_revision: Union[str, Sequence[str], None] = 'ee44aa55bb66'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    existing_cols = {col['name'] for col in inspector.get_columns('import_files')}

    if 'shipment_sub_mode' not in existing_cols:
        op.add_column('import_files', sa.Column('shipment_sub_mode', sa.String(length=50), nullable=True, server_default=sa.text("'General Air Cargo'")))
    if 'courier_operator' not in existing_cols:
        op.add_column('import_files', sa.Column('courier_operator', sa.String(length=50), nullable=True))
    if 'chargeable_divisor' not in existing_cols:
        op.add_column('import_files', sa.Column('chargeable_divisor', sa.Integer(), nullable=True, server_default=sa.text('6000')))
    if 'acid_requirement' not in existing_cols:
        op.add_column('import_files', sa.Column('acid_requirement', sa.String(length=50), nullable=True, server_default=sa.text("'MANDATORY'")))
    if 'acid_exemption_reason' not in existing_cols:
        op.add_column('import_files', sa.Column('acid_exemption_reason', sa.String(length=255), nullable=True))
    if 'courier_tracking_no' not in existing_cols:
        op.add_column('import_files', sa.Column('courier_tracking_no', sa.String(length=100), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table('import_files') as batch_op:
        batch_op.drop_column('courier_tracking_no')
        batch_op.drop_column('acid_exemption_reason')
        batch_op.drop_column('acid_requirement')
        batch_op.drop_column('chargeable_divisor')
        batch_op.drop_column('courier_operator')
        batch_op.drop_column('shipment_sub_mode')
