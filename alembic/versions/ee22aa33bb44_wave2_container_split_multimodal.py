"""wave2_container_split_multimodal

Revision ID: ee22aa33bb44
Revises: ee11aa22bb33
Create Date: 2026-11-02 22:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ee22aa33bb44'
down_revision: Union[str, Sequence[str], None] = 'ee11aa22bb33'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()

    # 1. container_lifecycle_units
    if 'container_lifecycle_units' not in tables:
        op.create_table(
            'container_lifecycle_units',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('container_number', sa.String(length=50), nullable=False),
            sa.Column('seal_number', sa.String(length=50), nullable=True),
            sa.Column('iso_type', sa.String(length=20), nullable=False, server_default='40HC'),
            sa.Column('tare_weight', sa.Float(), nullable=True),
            sa.Column('payload_weight', sa.Float(), nullable=True),
            sa.Column('gross_weight', sa.Float(), nullable=True),
            sa.Column('vgm_weight', sa.Float(), nullable=True),
            sa.Column('discharge_date', sa.Date(), nullable=True),
            sa.Column('gate_out_held_date', sa.Date(), nullable=True),
            sa.Column('empty_returned_date', sa.Date(), nullable=True),
            sa.Column('status', sa.String(length=30), nullable=False, server_default='ON_VESSEL'),
            sa.Column('shipment_id', sa.Integer(), sa.ForeignKey('import_files.import_file_id', ondelete='CASCADE'), nullable=False),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('is_deleted', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('created_by_user_id', sa.Integer(), sa.ForeignKey('users.user_id', ondelete='SET NULL'), nullable=True),
            sa.Column('updated_by_user_id', sa.Integer(), sa.ForeignKey('users.user_id', ondelete='SET NULL'), nullable=True),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        )
        op.create_index(
            'ix_container_lifecycle_units_container_number',
            'container_lifecycle_units',
            ['container_number'],
            unique=False,
        )
        op.create_index(
            'ix_container_lifecycle_units_shipment_id',
            'container_lifecycle_units',
            ['shipment_id'],
            unique=False,
        )
        op.create_index(
            'ix_container_lifecycle_units_status',
            'container_lifecycle_units',
            ['status'],
            unique=False,
        )

    # 2. container_demurrage_charges
    if 'container_demurrage_charges' not in tables:
        op.create_table(
            'container_demurrage_charges',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('container_id', sa.Integer(), sa.ForeignKey('container_lifecycle_units.id', ondelete='CASCADE'), nullable=False),
            sa.Column('free_time_days', sa.Integer(), nullable=False, server_default='14'),
            sa.Column('free_time_end_date', sa.Date(), nullable=True),
            sa.Column('daily_demurrage_rate', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('actual_return_date', sa.Date(), nullable=True),
            sa.Column('days_overdue', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('total_demurrage_amount', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('currency', sa.String(length=10), nullable=False, server_default='USD'),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('is_deleted', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('created_by_user_id', sa.Integer(), sa.ForeignKey('users.user_id', ondelete='SET NULL'), nullable=True),
            sa.Column('updated_by_user_id', sa.Integer(), sa.ForeignKey('users.user_id', ondelete='SET NULL'), nullable=True),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        )
        op.create_index(
            'ix_container_demurrage_charges_container_id',
            'container_demurrage_charges',
            ['container_id'],
            unique=False,
        )

    # 3. split_shipment_allocations
    if 'split_shipment_allocations' not in tables:
        op.create_table(
            'split_shipment_allocations',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('shipment_id', sa.Integer(), sa.ForeignKey('import_files.import_file_id', ondelete='CASCADE'), nullable=False),
            sa.Column('parent_bl_number', sa.String(length=100), nullable=False),
            sa.Column('split_bl_number', sa.String(length=100), nullable=False),
            sa.Column('po_id', sa.Integer(), sa.ForeignKey('purchase_orders.po_id', ondelete='SET NULL'), nullable=True),
            sa.Column('po_item_id', sa.Integer(), sa.ForeignKey('po_line_items.item_id', ondelete='SET NULL'), nullable=True),
            sa.Column('item_sku', sa.String(length=100), nullable=False),
            sa.Column('allocated_quantity', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('total_item_quantity', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('allocation_ratio', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('prorated_customs_cost', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('prorated_freight_cost', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('currency', sa.String(length=10), nullable=False, server_default='EGP'),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('is_deleted', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('created_by_user_id', sa.Integer(), sa.ForeignKey('users.user_id', ondelete='SET NULL'), nullable=True),
            sa.Column('updated_by_user_id', sa.Integer(), sa.ForeignKey('users.user_id', ondelete='SET NULL'), nullable=True),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        )
        op.create_index(
            'ix_split_shipment_allocations_shipment_id',
            'split_shipment_allocations',
            ['shipment_id'],
            unique=False,
        )
        op.create_index(
            'ix_split_shipment_allocations_parent_bl_number',
            'split_shipment_allocations',
            ['parent_bl_number'],
            unique=False,
        )
        op.create_index(
            'ix_split_shipment_allocations_split_bl_number',
            'split_shipment_allocations',
            ['split_bl_number'],
            unique=False,
        )

    # 4. multimodal_freight_details
    if 'multimodal_freight_details' not in tables:
        op.create_table(
            'multimodal_freight_details',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('shipment_id', sa.Integer(), sa.ForeignKey('import_files.import_file_id', ondelete='CASCADE'), nullable=False),
            sa.Column('transport_mode', sa.String(length=20), nullable=False, server_default='AIR'),
            sa.Column('awb_number', sa.String(length=100), nullable=True),
            sa.Column('airline_code', sa.String(length=20), nullable=True),
            sa.Column('flight_number', sa.String(length=50), nullable=True),
            sa.Column('terminal_handling_charges', sa.Float(), nullable=True, server_default='0.0'),
            sa.Column('lcl_cbm', sa.Float(), nullable=True, server_default='0.0'),
            sa.Column('lcl_rate_per_cbm', sa.Float(), nullable=True, server_default='0.0'),
            sa.Column('lcl_cfs_fee', sa.Float(), nullable=True, server_default='0.0'),
            sa.Column('roro_vehicle_type', sa.String(length=100), nullable=True),
            sa.Column('roro_dimensions_cbm', sa.Float(), nullable=True, server_default='0.0'),
            sa.Column('bulk_cargo_type', sa.String(length=100), nullable=True),
            sa.Column('bulk_tonnage', sa.Float(), nullable=True, server_default='0.0'),
            sa.Column('special_handling_notes', sa.Text(), nullable=True),
            sa.Column('is_deleted', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('created_by_user_id', sa.Integer(), sa.ForeignKey('users.user_id', ondelete='SET NULL'), nullable=True),
            sa.Column('updated_by_user_id', sa.Integer(), sa.ForeignKey('users.user_id', ondelete='SET NULL'), nullable=True),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        )
        op.create_index(
            'ix_multimodal_freight_details_shipment_id',
            'multimodal_freight_details',
            ['shipment_id'],
            unique=False,
        )
        op.create_index(
            'ix_multimodal_freight_details_transport_mode',
            'multimodal_freight_details',
            ['transport_mode'],
            unique=False,
        )


def downgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()

    if 'multimodal_freight_details' in tables:
        op.drop_table('multimodal_freight_details')

    if 'split_shipment_allocations' in tables:
        op.drop_table('split_shipment_allocations')

    if 'container_demurrage_charges' in tables:
        op.drop_table('container_demurrage_charges')

    if 'container_lifecycle_units' in tables:
        op.drop_table('container_lifecycle_units')
