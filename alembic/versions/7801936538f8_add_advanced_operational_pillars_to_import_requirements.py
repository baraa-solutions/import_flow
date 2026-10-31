"""add_advanced_operational_pillars_to_import_requirements

Revision ID: 7801936538f8
Revises: e1a2b3c4d5e6
Create Date: 2026-10-29 00:46:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '7801936538f8'
down_revision: Union[str, Sequence[str], None] = 'e1a2b3c4d5e6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()

    if 'import_requirement_assessments' in tables:
        columns = [c['name'] for c in inspector.get_columns('import_requirement_assessments')]
        
        with op.batch_alter_table('import_requirement_assessments', schema=None) as batch_op:
            # 1. CargoX & Pre-ACID Readiness
            if 'cargox_verified' not in columns:
                batch_op.add_column(sa.Column('cargox_verified', sa.Boolean(), server_default=sa.text('0'), nullable=False))
            if 'cargox_status' not in columns:
                batch_op.add_column(sa.Column('cargox_status', sa.String(50), server_default=sa.text("'Not Verified'"), nullable=True))
            if 'ready_for_acid' not in columns:
                batch_op.add_column(sa.Column('ready_for_acid', sa.Boolean(), server_default=sa.text('0'), nullable=False))
            if 'triple_match_status' not in columns:
                batch_op.add_column(sa.Column('triple_match_status', sa.String(50), server_default=sa.text("'Pending'"), nullable=True))

            # 2. Import Card & Commodity Group
            if 'commodity_group_matched' not in columns:
                batch_op.add_column(sa.Column('commodity_group_matched', sa.Boolean(), server_default=sa.text('1'), nullable=False))
            if 'import_card_group_code' not in columns:
                batch_op.add_column(sa.Column('import_card_group_code', sa.String(100), nullable=True))

            # 3. Adaptive Shelf-Life & Labeling
            if 'is_shelflife_applicable' not in columns:
                batch_op.add_column(sa.Column('is_shelflife_applicable', sa.Boolean(), server_default=sa.text('0'), nullable=False))
            if 'shelf_life_total_days' not in columns:
                batch_op.add_column(sa.Column('shelf_life_total_days', sa.Integer(), nullable=True))
            if 'shelf_life_remaining_percent' not in columns:
                batch_op.add_column(sa.Column('shelf_life_remaining_percent', sa.Float(), nullable=True))
            if 'artwork_arabic_approved' not in columns:
                batch_op.add_column(sa.Column('artwork_arabic_approved', sa.Boolean(), nullable=True))
            if 'labeling_notes' not in columns:
                batch_op.add_column(sa.Column('labeling_notes', sa.Text(), nullable=True))

            # 4. Testing & Physical Sampling
            if 'sampling_required' not in columns:
                batch_op.add_column(sa.Column('sampling_required', sa.Boolean(), server_default=sa.text('0'), nullable=False))
            if 'lab_type' not in columns:
                batch_op.add_column(sa.Column('lab_type', sa.String(100), nullable=True))
            if 'detention_allowed' not in columns:
                batch_op.add_column(sa.Column('detention_allowed', sa.Boolean(), server_default=sa.text('0'), nullable=False))
            if 'estimated_lab_fees' not in columns:
                batch_op.add_column(sa.Column('estimated_lab_fees', sa.Float(), server_default=sa.text('0.0'), nullable=False))

            # 5. Special Logistics: Cold Chain & Hazmat
            if 'cold_chain_required' not in columns:
                batch_op.add_column(sa.Column('cold_chain_required', sa.Boolean(), server_default=sa.text('0'), nullable=False))
            if 'target_temperature' not in columns:
                batch_op.add_column(sa.Column('target_temperature', sa.String(50), nullable=True))
            if 'data_logger_verified' not in columns:
                batch_op.add_column(sa.Column('data_logger_verified', sa.Boolean(), server_default=sa.text('0'), nullable=False))
            if 'is_hazmat' not in columns:
                batch_op.add_column(sa.Column('is_hazmat', sa.Boolean(), server_default=sa.text('0'), nullable=False))
            if 'imo_class' not in columns:
                batch_op.add_column(sa.Column('imo_class', sa.String(50), nullable=True))

            # 6. Governance: Maker-Checker & Overrides
            if 'checker_user_id' not in columns:
                batch_op.add_column(sa.Column('checker_user_id', sa.Integer(), nullable=True))
            if 'checker_approved' not in columns:
                batch_op.add_column(sa.Column('checker_approved', sa.Boolean(), server_default=sa.text('0'), nullable=False))
            if 'checker_notes' not in columns:
                batch_op.add_column(sa.Column('checker_notes', sa.Text(), nullable=True))
            if 'is_overridden' not in columns:
                batch_op.add_column(sa.Column('is_overridden', sa.Boolean(), server_default=sa.text('0'), nullable=False))
            if 'override_reason' not in columns:
                batch_op.add_column(sa.Column('override_reason', sa.Text(), nullable=True))


def downgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()

    if 'import_requirement_assessments' in tables:
        with op.batch_alter_table('import_requirement_assessments', schema=None) as batch_op:
            batch_op.drop_column('override_reason')
            batch_op.drop_column('is_overridden')
            batch_op.drop_column('checker_notes')
            batch_op.drop_column('checker_approved')
            batch_op.drop_column('checker_user_id')
            batch_op.drop_column('imo_class')
            batch_op.drop_column('is_hazmat')
            batch_op.drop_column('data_logger_verified')
            batch_op.drop_column('target_temperature')
            batch_op.drop_column('cold_chain_required')
            batch_op.drop_column('estimated_lab_fees')
            batch_op.drop_column('detention_allowed')
            batch_op.drop_column('lab_type')
            batch_op.drop_column('sampling_required')
            batch_op.drop_column('labeling_notes')
            batch_op.drop_column('artwork_arabic_approved')
            batch_op.drop_column('shelf_life_remaining_percent')
            batch_op.drop_column('shelf_life_total_days')
            batch_op.drop_column('is_shelflife_applicable')
            batch_op.drop_column('import_card_group_code')
            batch_op.drop_column('commodity_group_matched')
            batch_op.drop_column('triple_match_status')
            batch_op.drop_column('ready_for_acid')
            batch_op.drop_column('cargox_status')
            batch_op.drop_column('cargox_verified')
