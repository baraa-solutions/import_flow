"""add_po_allocations_and_logistics_epics_columns

Revision ID: a9b8c7d6e5f4
Revises: 7801936538f8
Create Date: 2026-10-31 17:30:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.engine.reflection import Inspector


# revision identifiers, used by Alembic.
revision: str = 'a9b8c7d6e5f4'
down_revision: Union[str, Sequence[str], None] = '7801936538f8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = Inspector.from_engine(conn)
    tables = inspector.get_table_names()

    # 1. Create table po_shipment_allocations if it doesn't exist
    if 'po_shipment_allocations' not in tables:
        op.create_table(
            'po_shipment_allocations',
            sa.Column('allocation_id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('po_item_id', sa.Integer(), sa.ForeignKey('purchase_order_items.item_id', ondelete='CASCADE'), nullable=False),
            sa.Column('import_file_id', sa.Integer(), sa.ForeignKey('import_files.import_file_id', ondelete='CASCADE'), nullable=False),
            sa.Column('allocated_quantity', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('shipped_quantity', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('received_quantity', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('allocation_notes', sa.Text(), nullable=True),
            sa.Column('status', sa.String(length=50), nullable=False, server_default=sa.text("'Pending'")),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('created_by', sa.String(length=100), nullable=True),
            sa.Column('updated_at', sa.DateTime(), nullable=True),
            sa.Column('updated_by', sa.String(length=100), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
        )
        op.create_index('idx_po_alloc_item', 'po_shipment_allocations', ['po_item_id'])
        op.create_index('idx_po_alloc_file', 'po_shipment_allocations', ['import_file_id'])

    # 2. Add columns to purchase_order_items
    if 'purchase_order_items' in tables:
        poi_cols = [c['name'] for c in inspector.get_columns('purchase_order_items')]
        with op.batch_alter_table('purchase_order_items', schema=None) as batch_op:
            if 'total_shipped_quantity' not in poi_cols:
                batch_op.add_column(sa.Column('total_shipped_quantity', sa.Float(), server_default=sa.text('0.0'), nullable=True))
            if 'total_received_quantity' not in poi_cols:
                batch_op.add_column(sa.Column('total_received_quantity', sa.Float(), server_default=sa.text('0.0'), nullable=True))
            if 'remaining_balance_quantity' not in poi_cols:
                batch_op.add_column(sa.Column('remaining_balance_quantity', sa.Float(), server_default=sa.text('0.0'), nullable=True))
            if 'fulfillment_status' not in poi_cols:
                batch_op.add_column(sa.Column('fulfillment_status', sa.String(50), server_default=sa.text("'Unfulfilled'"), nullable=True))

    # 3. Add columns to shipment_bookings
    if 'shipment_bookings' in tables:
        sb_cols = [c['name'] for c in inspector.get_columns('shipment_bookings')]
        with op.batch_alter_table('shipment_bookings', schema=None) as batch_op:
            if 'transport_mode' not in sb_cols:
                batch_op.add_column(sa.Column('transport_mode', sa.String(50), server_default=sa.text("'SEA_FCL'"), nullable=True))
            if 'master_air_waybill' not in sb_cols:
                batch_op.add_column(sa.Column('master_air_waybill', sa.String(100), nullable=True))
            if 'house_air_waybill' not in sb_cols:
                batch_op.add_column(sa.Column('house_air_waybill', sa.String(100), nullable=True))
            if 'flight_number' not in sb_cols:
                batch_op.add_column(sa.Column('flight_number', sa.String(100), nullable=True))
            if 'airline_code' not in sb_cols:
                batch_op.add_column(sa.Column('airline_code', sa.String(50), nullable=True))
            if 'airport_terminal_name' not in sb_cols:
                batch_op.add_column(sa.Column('airport_terminal_name', sa.String(200), nullable=True))
            if 'cfs_terminal_name' not in sb_cols:
                batch_op.add_column(sa.Column('cfs_terminal_name', sa.String(200), nullable=True))
            if 'stripping_fees_egp' not in sb_cols:
                batch_op.add_column(sa.Column('stripping_fees_egp', sa.Float(), server_default=sa.text('0.0'), nullable=True))
            if 'chargeable_weight_kg' not in sb_cols:
                batch_op.add_column(sa.Column('chargeable_weight_kg', sa.Float(), server_default=sa.text('0.0'), nullable=True))

    # 4. Add columns to containers
    if 'containers' in tables:
        cont_cols = [c['name'] for c in inspector.get_columns('containers')]
        with op.batch_alter_table('containers', schema=None) as batch_op:
            if 'customs_inspection_seal' not in cont_cols:
                batch_op.add_column(sa.Column('customs_inspection_seal', sa.String(100), nullable=True))
            if 'gate_out_timestamp' not in cont_cols:
                batch_op.add_column(sa.Column('gate_out_timestamp', sa.DateTime(), nullable=True))
            if 'truck_plate_number' not in cont_cols:
                batch_op.add_column(sa.Column('truck_plate_number', sa.String(100), nullable=True))
            if 'eir_number' not in cont_cols:
                batch_op.add_column(sa.Column('eir_number', sa.String(100), nullable=True))
            if 'eir_timestamp' not in cont_cols:
                batch_op.add_column(sa.Column('eir_timestamp', sa.DateTime(), nullable=True))
            if 'eir_condition_status' not in cont_cols:
                batch_op.add_column(sa.Column('eir_condition_status', sa.String(50), nullable=True))
            if 'individual_demurrage_cost' not in cont_cols:
                batch_op.add_column(sa.Column('individual_demurrage_cost', sa.Float(), server_default=sa.text('0.0'), nullable=True))

    # 5. Add columns to customs_clearance
    if 'customs_clearance' in tables:
        cc_cols = [c['name'] for c in inspector.get_columns('customs_clearance')]
        with op.batch_alter_table('customs_clearance', schema=None) as batch_op:
            if 'commercial_cif_base_amount' not in cc_cols:
                batch_op.add_column(sa.Column('commercial_cif_base_amount', sa.Float(), nullable=True))
            if 'customs_assessed_cif_egp' not in cc_cols:
                batch_op.add_column(sa.Column('customs_assessed_cif_egp', sa.Float(), nullable=True))
            if 'customs_assessed_cif_usd' not in cc_cols:
                batch_op.add_column(sa.Column('customs_assessed_cif_usd', sa.Float(), nullable=True))
            if 'is_valuation_uplifted' not in cc_cols:
                batch_op.add_column(sa.Column('is_valuation_uplifted', sa.Boolean(), server_default=sa.text('0'), nullable=True))
            if 'valuation_uplift_amount_egp' not in cc_cols:
                batch_op.add_column(sa.Column('valuation_uplift_amount_egp', sa.Float(), server_default=sa.text('0.0'), nullable=True))
            if 'valuation_uplift_reason' not in cc_cols:
                batch_op.add_column(sa.Column('valuation_uplift_reason', sa.Text(), nullable=True))


def downgrade() -> None:
    pass
