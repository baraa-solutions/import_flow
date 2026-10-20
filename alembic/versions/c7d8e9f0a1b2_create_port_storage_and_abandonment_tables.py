"""create_port_storage_and_abandonment_tables

Revision ID: c7d8e9f0a1b2
Revises: b4c5d6e7f8a9
Create Date: 2026-10-20
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = 'c7d8e9f0a1b2'
down_revision: Union[str, Sequence[str], None] = 'c5d6e7f8a9b0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = inspector.get_table_names()

    # 1. port_terminal_rates
    if 'port_terminal_rates' not in tables:
        op.create_table(
            'port_terminal_rates',
            sa.Column('rate_id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('terminal_code', sa.String(length=50), nullable=False),
            sa.Column('terminal_name', sa.String(length=150), nullable=False),
            sa.Column('container_size', sa.String(length=20), nullable=False),
            sa.Column('is_reefer', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('free_days', sa.Integer(), nullable=False, server_default=sa.text('3')),
            sa.Column('tier1_rate_per_day', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('tier2_rate_per_day', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('penal_rate_per_day', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('reefer_plugging_daily_fee', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('xray_scan_fee', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('scale_fee', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('currency', sa.String(length=10), nullable=False, server_default=sa.text("'EGP'")),
            sa.Column('effective_date', sa.Date(), nullable=False),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('created_by', sa.String(length=100), nullable=False, server_default=sa.text("'System'")),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_by', sa.String(length=100), nullable=False, server_default=sa.text("'System'")),
            sa.UniqueConstraint('terminal_code', 'container_size', 'is_reefer', 'effective_date', name='uq_port_terminal_rate_unique'),
        )
        op.create_index('ix_port_terminal_rates_rate_id', 'port_terminal_rates', ['rate_id'])
        op.create_index('ix_port_terminal_rates_terminal_code', 'port_terminal_rates', ['terminal_code'])
        op.create_index('ix_port_terminal_rates_container_size', 'port_terminal_rates', ['container_size'])
        op.create_index('ix_port_terminal_rates_is_reefer', 'port_terminal_rates', ['is_reefer'])
        op.create_index('ix_port_terminal_rates_effective_date', 'port_terminal_rates', ['effective_date'])
        op.create_index('ix_port_terminal_rates_is_active', 'port_terminal_rates', ['is_active'])

    # 2. port_storage_accruals
    if 'port_storage_accruals' not in tables:
        op.create_table(
            'port_storage_accruals',
            sa.Column('accrual_id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('import_file_id', sa.Integer(), sa.ForeignKey('import_files.import_file_id'), nullable=True),
            sa.Column('terminal_code', sa.String(length=50), nullable=False),
            sa.Column('container_number', sa.String(length=50), nullable=False),
            sa.Column('container_size_type', sa.String(length=50), nullable=False),
            sa.Column('is_reefer', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('gate_in_date', sa.Date(), nullable=False),
            sa.Column('customs_release_date', sa.Date(), nullable=True),
            sa.Column('gate_out_date', sa.Date(), nullable=True),
            sa.Column('free_days_allowed', sa.Integer(), nullable=False, server_default=sa.text('3')),
            sa.Column('chargeable_days', sa.Integer(), nullable=False, server_default=sa.text('0')),
            sa.Column('storage_charges_egp', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('reefer_plugging_charges_egp', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('xray_scan_fee_egp', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('scale_fee_egp', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('total_port_storage_egp', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('status', sa.String(length=50), nullable=False, server_default=sa.text("'ESTIMATED'")),
            sa.Column('invoice_number', sa.String(length=100), nullable=True),
            sa.Column('invoice_date', sa.Date(), nullable=True),
            sa.Column('paid_amount_egp', sa.Float(), nullable=True),
            sa.Column('payment_reference', sa.String(length=100), nullable=True),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('created_by', sa.String(length=100), nullable=False, server_default=sa.text("'System'")),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_by', sa.String(length=100), nullable=False, server_default=sa.text("'System'")),
        )
        op.create_index('ix_port_storage_accruals_accrual_id', 'port_storage_accruals', ['accrual_id'])
        op.create_index('ix_port_storage_accruals_import_file_id', 'port_storage_accruals', ['import_file_id'])
        op.create_index('ix_port_storage_accruals_terminal_code', 'port_storage_accruals', ['terminal_code'])
        op.create_index('ix_port_storage_accruals_container_number', 'port_storage_accruals', ['container_number'])
        op.create_index('ix_port_storage_accruals_gate_in_date', 'port_storage_accruals', ['gate_in_date'])
        op.create_index('ix_port_storage_accruals_status', 'port_storage_accruals', ['status'])
        op.create_index('ix_port_storage_accruals_is_active', 'port_storage_accruals', ['is_active'])

    # 3. customs_abandonment_radars
    if 'customs_abandonment_radars' not in tables:
        op.create_table(
            'customs_abandonment_radars',
            sa.Column('radar_id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('import_file_id', sa.Integer(), sa.ForeignKey('import_files.import_file_id'), nullable=True),
            sa.Column('import_file_code', sa.String(length=50), nullable=False),
            sa.Column('port_type', sa.String(length=20), nullable=False),
            sa.Column('port_name', sa.String(length=100), nullable=True),
            sa.Column('arrival_date', sa.Date(), nullable=False),
            sa.Column('max_legal_days', sa.Integer(), nullable=False),
            sa.Column('days_in_port', sa.Integer(), nullable=False),
            sa.Column('days_remaining', sa.Integer(), nullable=False),
            sa.Column('risk_level', sa.String(length=50), nullable=False),
            sa.Column('extension_requested', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('extension_request_date', sa.Date(), nullable=True),
            sa.Column('extension_reason', sa.Text(), nullable=True),
            sa.Column('extension_request_ref', sa.String(length=100), nullable=True),
            sa.Column('extension_granted_until', sa.Date(), nullable=True),
            sa.Column('official_letter_issued', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('abandonment_status', sa.String(length=50), nullable=False, server_default=sa.text("'ACTIVE_CLEARING'")),
            sa.Column('importer_name', sa.String(length=255), nullable=True),
            sa.Column('cargo_description', sa.String(length=255), nullable=True),
            sa.Column('customs_declaration_no', sa.String(length=100), nullable=True),
            sa.Column('bl_number', sa.String(length=100), nullable=True),
            sa.Column('acid_number', sa.String(length=50), nullable=True),
            sa.Column('container_numbers', sa.JSON(), nullable=True),
            sa.Column('action_plan', sa.Text(), nullable=True),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('created_by', sa.String(length=100), nullable=False, server_default=sa.text("'System'")),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_by', sa.String(length=100), nullable=False, server_default=sa.text("'System'")),
        )
        op.create_index('ix_customs_abandonment_radars_radar_id', 'customs_abandonment_radars', ['radar_id'])
        op.create_index('ix_customs_abandonment_radars_import_file_id', 'customs_abandonment_radars', ['import_file_id'])
        op.create_index('ix_customs_abandonment_radars_import_file_code', 'customs_abandonment_radars', ['import_file_code'])
        op.create_index('ix_customs_abandonment_radars_port_type', 'customs_abandonment_radars', ['port_type'])
        op.create_index('ix_customs_abandonment_radars_arrival_date', 'customs_abandonment_radars', ['arrival_date'])
        op.create_index('ix_customs_abandonment_radars_risk_level', 'customs_abandonment_radars', ['risk_level'])
        op.create_index('ix_customs_abandonment_radars_abandonment_status', 'customs_abandonment_radars', ['abandonment_status'])
        op.create_index('ix_customs_abandonment_radars_is_active', 'customs_abandonment_radars', ['is_active'])


def downgrade() -> None:
    op.drop_table('customs_abandonment_radars')
    op.drop_table('port_storage_accruals')
    op.drop_table('port_terminal_rates')
