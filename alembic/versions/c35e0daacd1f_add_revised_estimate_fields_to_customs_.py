"""add_revised_estimate_fields_to_customs_clearance_records

Revision ID: c35e0daacd1f
Revises: a9b8c7d6e5f4
Create Date: 2026-11-01 12:40:16.518759

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c35e0daacd1f'
down_revision: Union[str, Sequence[str], None] = 'a9b8c7d6e5f4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add revised estimate fields to customs_clearance_records."""
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    existing_cols = {col['name'] for col in inspector.get_columns('customs_clearance_records')}

    columns_to_add = [
        ('revised_exchange_rate', sa.Float(), True),
        ('revised_freight_egp', sa.Float(), True),
        ('revised_insurance_egp', sa.Float(), True),
        ('revised_unloading_egp', sa.Float(), True),
        ('revised_duty_rate', sa.Float(), True),
        ('revised_extra_fees_egp', sa.Float(), True),
        ('revised_cif_egp', sa.Float(), True),
        ('revised_import_duty_egp', sa.Float(), True),
        ('revised_vat_egp', sa.Float(), True),
        ('revised_total_duties_egp', sa.Float(), True),
        ('revised_has_exemption', sa.Boolean(), True),
        ('revised_estimate_date', sa.DateTime(), True),
        ('revised_estimate_by', sa.String(length=100), True),
        ('revised_estimate_notes', sa.Text(), True),
    ]

    for col_name, col_type, is_null in columns_to_add:
        if col_name not in existing_cols:
            op.add_column('customs_clearance_records', sa.Column(col_name, col_type, nullable=is_null))


def downgrade() -> None:
    """Drop revised estimate fields from customs_clearance_records."""
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    existing_cols = {col['name'] for col in inspector.get_columns('customs_clearance_records')}

    columns_to_drop = [
        'revised_exchange_rate',
        'revised_freight_egp',
        'revised_insurance_egp',
        'revised_unloading_egp',
        'revised_duty_rate',
        'revised_extra_fees_egp',
        'revised_cif_egp',
        'revised_import_duty_egp',
        'revised_vat_egp',
        'revised_total_duties_egp',
        'revised_has_exemption',
        'revised_estimate_date',
        'revised_estimate_by',
        'revised_estimate_notes',
    ]

    with op.batch_alter_table('customs_clearance_records') as batch_op:
        for col_name in columns_to_drop:
            if col_name in existing_cols:
                batch_op.drop_column(col_name)
