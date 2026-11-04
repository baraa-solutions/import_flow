"""add_anti_dumping_fields

Revision ID: ee66aa77bb88
Revises: ee55aa66bb77
Create Date: 2026-11-03 15:30:00.000000

Adds anti-dumping duty & safeguard measures risk tracking:
- customs_tariffs.has_anti_dumping_risk
- customs_tariffs.anti_dumping_notes
- import_requirement_assessments.has_anti_dumping_risk
- import_requirement_assessments.anti_dumping_notes
- import_requirement_assessments.anti_dumping_status
"""

from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ee66aa77bb88'
down_revision: Union[str, Sequence[str], None] = 'ee55aa66bb77'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)

    # 1. customs_tariffs
    if 'customs_tariffs' in inspector.get_table_names():
        existing_tariff_cols = {col['name'] for col in inspector.get_columns('customs_tariffs')}
        if 'has_anti_dumping_risk' not in existing_tariff_cols:
            op.add_column(
                'customs_tariffs',
                sa.Column('has_anti_dumping_risk', sa.Boolean(), nullable=False, server_default=sa.text('0'))
            )
        if 'anti_dumping_notes' not in existing_tariff_cols:
            op.add_column(
                'customs_tariffs',
                sa.Column('anti_dumping_notes', sa.Text(), nullable=True)
            )
        existing_indexes = {idx['name'] for idx in inspector.get_indexes('customs_tariffs')}
        if 'ix_customs_tariffs_has_anti_dumping_risk' not in existing_indexes:
            op.create_index('ix_customs_tariffs_has_anti_dumping_risk', 'customs_tariffs', ['has_anti_dumping_risk'])

    # 2. import_requirement_assessments (if table exists)
    if 'import_requirement_assessments' in inspector.get_table_names():
        existing_assessment_cols = {col['name'] for col in inspector.get_columns('import_requirement_assessments')}
        if 'has_anti_dumping_risk' not in existing_assessment_cols:
            op.add_column(
                'import_requirement_assessments',
                sa.Column('has_anti_dumping_risk', sa.Boolean(), nullable=False, server_default=sa.text('0'))
            )
        if 'anti_dumping_notes' not in existing_assessment_cols:
            op.add_column(
                'import_requirement_assessments',
                sa.Column('anti_dumping_notes', sa.Text(), nullable=True)
            )
        if 'anti_dumping_status' not in existing_assessment_cols:
            op.add_column(
                'import_requirement_assessments',
                sa.Column('anti_dumping_status', sa.String(length=50), nullable=False, server_default=sa.text("'Not Applicable'"))
            )


def downgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    if 'customs_tariffs' in inspector.get_table_names():
        indexes = {idx['name'] for idx in inspector.get_indexes('customs_tariffs')}
        with op.batch_alter_table('customs_tariffs') as batch_op:
            if 'ix_customs_tariffs_has_anti_dumping_risk' in indexes:
                batch_op.drop_index('ix_customs_tariffs_has_anti_dumping_risk')
            batch_op.drop_column('anti_dumping_notes')
            batch_op.drop_column('has_anti_dumping_risk')

    if 'import_requirement_assessments' in inspector.get_table_names():
        with op.batch_alter_table('import_requirement_assessments') as batch_op:
            batch_op.drop_column('anti_dumping_status')
            batch_op.drop_column('anti_dumping_notes')
            batch_op.drop_column('has_anti_dumping_risk')
