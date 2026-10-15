"""create_shipment_containers_table

Revision ID: 73cee71ca978
Revises: b2c3d4e5f6a7
Create Date: 2026-10-16 01:39:23.284482

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '73cee71ca978'
down_revision: Union[str, Sequence[str], None] = 'b2c3d4e5f6a7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = inspector.get_table_names()

    if 'shipment_containers' not in tables:
        op.create_table(
            'shipment_containers',
            sa.Column('container_id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('container_number', sa.String(length=50), nullable=False),
            sa.Column('container_type', sa.String(length=50), nullable=False),
            sa.Column('seal_number', sa.String(length=50), nullable=True),
            sa.Column('import_file_id', sa.Integer(), sa.ForeignKey('import_files.import_file_id'), nullable=False),
            sa.Column('booking_id', sa.Integer(), sa.ForeignKey('shipment_bookings.booking_id'), nullable=True),
            sa.Column('shipping_record_id', sa.Integer(), sa.ForeignKey('cargo_shipping_records.cargo_shipping_id'), nullable=True),
            sa.Column('demurrage_tracking_id', sa.Integer(), sa.ForeignKey('demurrage_trackings.tracking_id'), nullable=True),
            sa.Column('carrier_name', sa.String(length=100), nullable=True),
            sa.Column('bill_of_lading_no', sa.String(length=100), nullable=True),
            sa.Column('gate_in_date', sa.DateTime(), nullable=True),
            sa.Column('stuffing_date', sa.DateTime(), nullable=True),
            sa.Column('discharge_date', sa.Date(), nullable=True),
            sa.Column('gate_out_date', sa.Date(), nullable=True),
            sa.Column('empty_return_date', sa.Date(), nullable=True),
            sa.Column('tare_weight_kg', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('net_weight_kg', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('gross_weight_kg', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('vgm_weight_kg', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('vgm_status', sa.String(length=30), nullable=False, server_default=sa.text("'Pending'")),
            sa.Column('vgm_ref_no', sa.String(length=50), nullable=True),
            sa.Column('demurrage_days', sa.Integer(), nullable=False, server_default=sa.text('0')),
            sa.Column('detention_days', sa.Integer(), nullable=False, server_default=sa.text('0')),
            sa.Column('storage_days', sa.Integer(), nullable=False, server_default=sa.text('0')),
            sa.Column('demurrage_cost_fx', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('detention_cost_fx', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('storage_cost_egp', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('total_cost_egp', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('currency', sa.String(length=10), nullable=False, server_default=sa.text("'USD'")),
            sa.Column('status', sa.String(length=50), nullable=False, server_default=sa.text("'Allocated'")),
            sa.Column('eir_number', sa.String(length=100), nullable=True),
            sa.Column('depot_name', sa.String(length=150), nullable=True),
            sa.Column('condition_at_return', sa.String(length=50), nullable=True, server_default=sa.text("'Good'")),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('created_by', sa.String(length=100), nullable=False, server_default=sa.text("'System'")),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_by', sa.String(length=100), nullable=False, server_default=sa.text("'System'")),
        )
        op.create_index('ix_shipment_containers_container_id', 'shipment_containers', ['container_id'])
        op.create_index('ix_shipment_containers_container_number', 'shipment_containers', ['container_number'])
        op.create_index('ix_shipment_containers_import_file_id', 'shipment_containers', ['import_file_id'])
        op.create_index('ix_shipment_containers_booking_id', 'shipment_containers', ['booking_id'])
        op.create_index('ix_shipment_containers_shipping_record_id', 'shipment_containers', ['shipping_record_id'])
        op.create_index('ix_shipment_containers_demurrage_tracking_id', 'shipment_containers', ['demurrage_tracking_id'])
        op.create_index('ix_shipment_containers_bill_of_lading_no', 'shipment_containers', ['bill_of_lading_no'])
        op.create_index('ix_shipment_containers_status', 'shipment_containers', ['status'])
        op.create_index('ix_shipment_containers_is_active', 'shipment_containers', ['is_active'])


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = inspector.get_table_names()

    if 'shipment_containers' in tables:
        op.drop_index('ix_shipment_containers_is_active', table_name='shipment_containers')
        op.drop_index('ix_shipment_containers_status', table_name='shipment_containers')
        op.drop_index('ix_shipment_containers_bill_of_lading_no', table_name='shipment_containers')
        op.drop_index('ix_shipment_containers_demurrage_tracking_id', table_name='shipment_containers')
        op.drop_index('ix_shipment_containers_shipping_record_id', table_name='shipment_containers')
        op.drop_index('ix_shipment_containers_booking_id', table_name='shipment_containers')
        op.drop_index('ix_shipment_containers_import_file_id', table_name='shipment_containers')
        op.drop_index('ix_shipment_containers_container_number', table_name='shipment_containers')
        op.drop_index('ix_shipment_containers_container_id', table_name='shipment_containers')
        op.drop_table('shipment_containers')
