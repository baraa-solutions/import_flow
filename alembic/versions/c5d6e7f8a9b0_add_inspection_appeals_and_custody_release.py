"""add_inspection_appeals_and_custody_release

Revision ID: c5d6e7f8a9b0
Revises: b4c5d6e7f8a9
Create Date: 2026-10-20
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = 'c5d6e7f8a9b0'
down_revision: Union[str, Sequence[str], None] = 'b4c5d6e7f8a9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = inspector.get_table_names()

    # 1. inspection_appeals table
    if 'inspection_appeals' not in tables:
        op.create_table(
            'inspection_appeals',
            sa.Column('appeal_id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('appeal_code', sa.String(length=50), unique=True, nullable=False),
            sa.Column('import_file_id', sa.Integer(), sa.ForeignKey('import_files.import_file_id'), nullable=False),
            sa.Column('clearance_id', sa.Integer(), sa.ForeignKey('customs_clearance_records.customs_clearance_id'), nullable=True),
            sa.Column('regulatory_authority', sa.String(length=50), nullable=False),
            sa.Column('sample_number', sa.String(length=100), nullable=True),
            sa.Column('sample_draw_date', sa.DateTime(), nullable=True),
            sa.Column('initial_test_result', sa.String(length=50), nullable=False),
            sa.Column('rejection_reason', sa.Text(), nullable=True),
            sa.Column('appeal_tier', sa.String(length=50), nullable=False, server_default=sa.text("'FIRST_APPEAL'")),
            sa.Column('appeal_submission_date', sa.DateTime(), nullable=True),
            sa.Column('appeal_committee_date', sa.DateTime(), nullable=True),
            sa.Column('triplicate_lab_assigned', sa.String(length=150), nullable=True),
            sa.Column('appeal_result', sa.String(length=50), nullable=False, server_default=sa.text("'PENDING'")),
            sa.Column('official_letter_ref', sa.String(length=100), nullable=True),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('created_by', sa.String(length=50), nullable=False, server_default=sa.text("'system'")),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_by', sa.String(length=50), nullable=False, server_default=sa.text("'system'")),
        )
        op.create_index('ix_inspection_appeals_appeal_id', 'inspection_appeals', ['appeal_id'])
        op.create_index('ix_inspection_appeals_appeal_code', 'inspection_appeals', ['appeal_code'])
        op.create_index('ix_inspection_appeals_import_file_id', 'inspection_appeals', ['import_file_id'])
        op.create_index('ix_inspection_appeals_clearance_id', 'inspection_appeals', ['clearance_id'])
        op.create_index('ix_inspection_appeals_regulatory_authority', 'inspection_appeals', ['regulatory_authority'])
        op.create_index('ix_inspection_appeals_sample_number', 'inspection_appeals', ['sample_number'])

    # 2. custody_release_dossiers table
    if 'custody_release_dossiers' not in tables:
        op.create_table(
            'custody_release_dossiers',
            sa.Column('custody_id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('custody_code', sa.String(length=50), unique=True, nullable=False),
            sa.Column('import_file_id', sa.Integer(), sa.ForeignKey('import_files.import_file_id'), nullable=False),
            sa.Column('warehouse_id', sa.Integer(), nullable=True),
            sa.Column('warehouse_address', sa.String(length=255), nullable=True),
            sa.Column('custody_undertaking_number', sa.String(length=100), unique=True, nullable=False),
            sa.Column('judicial_officer_name', sa.String(length=150), nullable=True),
            sa.Column('lead_seals_count', sa.Integer(), nullable=False, server_default=sa.text('0')),
            sa.Column('lead_seal_numbers', sa.JSON(), nullable=False, server_default=sa.text("'[]'")),
            sa.Column('transport_permit_number', sa.String(length=100), nullable=True),
            sa.Column('status', sa.String(length=50), nullable=False, server_default=sa.text("'RELEASED_UNDER_CUSTODY'")),
            sa.Column('lock_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('final_clearance_letter_number', sa.String(length=100), nullable=True),
            sa.Column('release_approved_at', sa.DateTime(), nullable=True),
            sa.Column('breach_reason', sa.Text(), nullable=True),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('created_by', sa.String(length=50), nullable=False, server_default=sa.text("'system'")),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_by', sa.String(length=50), nullable=False, server_default=sa.text("'system'")),
        )
        op.create_index('ix_custody_release_dossiers_custody_id', 'custody_release_dossiers', ['custody_id'])
        op.create_index('ix_custody_release_dossiers_custody_code', 'custody_release_dossiers', ['custody_code'])
        op.create_index('ix_custody_release_dossiers_import_file_id', 'custody_release_dossiers', ['import_file_id'])
        op.create_index('ix_custody_release_dossiers_warehouse_id', 'custody_release_dossiers', ['warehouse_id'])
        op.create_index('ix_custody_release_dossiers_custody_undertaking_number', 'custody_release_dossiers', ['custody_undertaking_number'])


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = inspector.get_table_names()

    if 'custody_release_dossiers' in tables:
        op.drop_table('custody_release_dossiers')
    if 'inspection_appeals' in tables:
        op.drop_table('inspection_appeals')
