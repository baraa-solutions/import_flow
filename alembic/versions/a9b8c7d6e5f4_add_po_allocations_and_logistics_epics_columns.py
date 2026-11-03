"""add_po_allocations_and_logistics_epics_columns

Revision ID: a9b8c7d6e5f4
Revises: 7801936538f8
Create Date: 2026-10-31 17:30:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a9b8c7d6e5f4'
down_revision: Union[str, Sequence[str], None] = '7801936538f8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()

    # 1. Create or update table po_shipment_allocations
    if 'po_shipment_allocations' not in tables:
        op.create_table(
            'po_shipment_allocations',
            sa.Column('allocation_id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('po_id', sa.Integer(), sa.ForeignKey('purchase_orders.po_id', ondelete='CASCADE'), nullable=False),
            sa.Column('po_line_item_id', sa.Integer(), sa.ForeignKey('po_line_items.item_id', ondelete='CASCADE'), nullable=True),
            sa.Column('po_item_id', sa.Integer(), sa.ForeignKey('po_line_items.item_id', ondelete='CASCADE'), nullable=True),
            sa.Column('import_file_id', sa.Integer(), sa.ForeignKey('import_files.import_file_id', ondelete='CASCADE'), nullable=True),
            sa.Column('shipment_batch_no', sa.String(length=100), nullable=True),
            sa.Column('shipment_ref', sa.String(length=100), nullable=True),
            sa.Column('allocated_quantity', sa.Numeric(12, 2), nullable=False, server_default=sa.text('0.0')),
            sa.Column('shipped_quantity', sa.Numeric(12, 2), nullable=False, server_default=sa.text('0.0')),
            sa.Column('allocated_fob_amount', sa.Numeric(14, 2), nullable=False, server_default=sa.text('0.0')),
            sa.Column('shipped_amount_fob', sa.Numeric(14, 2), nullable=False, server_default=sa.text('0.0')),
            sa.Column('shipping_date', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('status', sa.String(length=50), nullable=False, server_default=sa.text("'In Transit'")),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('created_by', sa.String(length=100), nullable=True),
            sa.Column('updated_at', sa.DateTime(), nullable=True),
            sa.Column('updated_by', sa.String(length=100), nullable=True),
        )
        op.create_index('idx_po_alloc_po', 'po_shipment_allocations', ['po_id'])
        op.create_index('idx_po_alloc_item', 'po_shipment_allocations', ['po_item_id'])
        op.create_index('idx_po_alloc_line_item', 'po_shipment_allocations', ['po_line_item_id'])
        op.create_index('idx_po_alloc_file', 'po_shipment_allocations', ['import_file_id'])
    else:
        po_alloc_cols = [c['name'] for c in inspector.get_columns('po_shipment_allocations')]
        with op.batch_alter_table('po_shipment_allocations', schema=None) as batch_op:
            if 'po_line_item_id' not in po_alloc_cols:
                batch_op.add_column(sa.Column('po_line_item_id', sa.Integer(), nullable=True))
            if 'allocated_quantity' not in po_alloc_cols:
                batch_op.add_column(sa.Column('allocated_quantity', sa.Numeric(12, 2), server_default=sa.text('0.0'), nullable=False))
            if 'allocated_fob_amount' not in po_alloc_cols:
                batch_op.add_column(sa.Column('allocated_fob_amount', sa.Numeric(14, 2), server_default=sa.text('0.0'), nullable=False))
            if 'shipment_batch_no' not in po_alloc_cols:
                batch_op.add_column(sa.Column('shipment_batch_no', sa.String(100), nullable=True))

    # 2. Add columns to purchase_orders (EPIC-PO-PART)
    if 'purchase_orders' in tables:
        po_cols = [c['name'] for c in inspector.get_columns('purchase_orders')]
        with op.batch_alter_table('purchase_orders', schema=None) as batch_op:
            if 'total_shipped_quantity' not in po_cols:
                batch_op.add_column(sa.Column('total_shipped_quantity', sa.Numeric(14, 2), server_default=sa.text('0.0'), nullable=False))
            if 'total_received_quantity' not in po_cols:
                batch_op.add_column(sa.Column('total_received_quantity', sa.Numeric(14, 2), server_default=sa.text('0.0'), nullable=False))
            if 'remaining_balance_quantity' not in po_cols:
                batch_op.add_column(sa.Column('remaining_balance_quantity', sa.Numeric(14, 2), server_default=sa.text('0.0'), nullable=False))
            if 'fulfillment_status' not in po_cols:
                batch_op.add_column(sa.Column('fulfillment_status', sa.String(50), server_default=sa.text("'OPEN'"), nullable=False))

    # Also support purchase_order_items if present
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
                batch_op.add_column(sa.Column('flight_number', sa.String(50), nullable=True))
            if 'airline_code' not in sb_cols:
                batch_op.add_column(sa.Column('airline_code', sa.String(50), nullable=True))
            if 'airport_terminal_name' not in sb_cols:
                batch_op.add_column(sa.Column('airport_terminal_name', sa.String(150), nullable=True))
            if 'cfs_terminal_name' not in sb_cols:
                batch_op.add_column(sa.Column('cfs_terminal_name', sa.String(150), nullable=True))
            if 'stripping_fees_egp' not in sb_cols:
                batch_op.add_column(sa.Column('stripping_fees_egp', sa.Float(), server_default=sa.text('0.0'), nullable=True))
            if 'chargeable_weight_kg' not in sb_cols:
                batch_op.add_column(sa.Column('chargeable_weight_kg', sa.Float(), server_default=sa.text('0.0'), nullable=True))

    # 4. Add columns to shipment_containers (DEV-OPS-01)
    target_container_table = 'shipment_containers' if 'shipment_containers' in tables else ('containers' if 'containers' in tables else None)
    if target_container_table:
        cont_cols = [c['name'] for c in inspector.get_columns(target_container_table)]
        with op.batch_alter_table(target_container_table, schema=None) as batch_op:
            if 'gate_out_timestamp' not in cont_cols:
                batch_op.add_column(sa.Column('gate_out_timestamp', sa.DateTime(), nullable=True))
            if 'eir_timestamp' not in cont_cols:
                batch_op.add_column(sa.Column('eir_timestamp', sa.DateTime(), nullable=True))
            if 'customs_inspection_seal' not in cont_cols:
                batch_op.add_column(sa.Column('customs_inspection_seal', sa.String(100), nullable=True))
            if 'truck_plate_number' not in cont_cols:
                batch_op.add_column(sa.Column('truck_plate_number', sa.String(50), nullable=True))
            if 'eir_condition_status' not in cont_cols:
                batch_op.add_column(sa.Column('eir_condition_status', sa.String(50), server_default=sa.text("'Good'"), nullable=True))
            if 'individual_demurrage_cost' not in cont_cols:
                batch_op.add_column(sa.Column('individual_demurrage_cost', sa.Float(), server_default=sa.text('0.0'), nullable=False))
            if 'eir_number' not in cont_cols:
                batch_op.add_column(sa.Column('eir_number', sa.String(100), nullable=True))

    # 5. Add columns to customs_clearance_records
    target_cc_table = 'customs_clearance_records' if 'customs_clearance_records' in tables else ('customs_clearance' if 'customs_clearance' in tables else None)
    if target_cc_table:
        cc_cols = [c['name'] for c in inspector.get_columns(target_cc_table)]
        with op.batch_alter_table(target_cc_table, schema=None) as batch_op:
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
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()

    def _drop_col_indexes(table_name, cols_to_drop, batch_op):
        try:
            indexes = inspector.get_indexes(table_name)
            for idx in indexes:
                idx_cols = idx.get('column_names') or []
                if any(c in cols_to_drop for c in idx_cols):
                    batch_op.drop_index(idx['name'])
        except Exception:
            pass

    target_cc_table = 'customs_clearance_records' if 'customs_clearance_records' in tables else ('customs_clearance' if 'customs_clearance' in tables else None)
    if target_cc_table:
        cc_drop = ['valuation_uplift_reason', 'valuation_uplift_amount_egp', 'is_valuation_uplifted', 'customs_assessed_cif_usd', 'customs_assessed_cif_egp', 'commercial_cif_base_amount']
        with op.batch_alter_table(target_cc_table, schema=None) as batch_op:
            _drop_col_indexes(target_cc_table, cc_drop, batch_op)
            for col in cc_drop:
                batch_op.drop_column(col)

    target_container_table = 'shipment_containers' if 'shipment_containers' in tables else ('containers' if 'containers' in tables else None)
    if target_container_table:
        cont_drop = ['eir_number', 'individual_demurrage_cost', 'eir_condition_status', 'truck_plate_number', 'customs_inspection_seal', 'eir_timestamp', 'gate_out_timestamp']
        with op.batch_alter_table(target_container_table, schema=None) as batch_op:
            _drop_col_indexes(target_container_table, cont_drop, batch_op)
            for col in cont_drop:
                batch_op.drop_column(col)

    if 'shipment_bookings' in tables:
        sb_drop = ['chargeable_weight_kg', 'stripping_fees_egp', 'cfs_terminal_name', 'airport_terminal_name', 'airline_code', 'flight_number', 'house_air_waybill', 'master_air_waybill', 'transport_mode']
        with op.batch_alter_table('shipment_bookings', schema=None) as batch_op:
            _drop_col_indexes('shipment_bookings', sb_drop, batch_op)
            for col in sb_drop:
                batch_op.drop_column(col)

    if 'purchase_orders' in tables:
        po_drop = ['fulfillment_status', 'remaining_balance_quantity', 'total_received_quantity', 'total_shipped_quantity']
        with op.batch_alter_table('purchase_orders', schema=None) as batch_op:
            _drop_col_indexes('purchase_orders', po_drop, batch_op)
            for col in po_drop:
                batch_op.drop_column(col)

    if 'po_shipment_allocations' in tables:
        op.drop_table('po_shipment_allocations')
