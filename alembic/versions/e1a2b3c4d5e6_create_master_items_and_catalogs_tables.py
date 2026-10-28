"""create_master_items_and_catalogs_tables

Revision ID: e1a2b3c4d5e6
Revises: d8e9f0a1b2c3
Create Date: 2026-10-28 21:15:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.engine.reflection import Inspector


# revision identifiers, used by Alembic.
revision: str = 'e1a2b3c4d5e6'
down_revision: Union[str, Sequence[str], None] = 'd8e9f0a1b2c3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = Inspector.from_engine(conn)
    tables = inspector.get_table_names()

    # 1. master_items table
    if 'master_items' not in tables:
        op.create_table(
            'master_items',
            sa.Column('item_id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('item_code', sa.String(length=100), nullable=False),
            sa.Column('description_ar', sa.String(length=500), nullable=False),
            sa.Column('description_en', sa.String(length=500), nullable=True),
            sa.Column('tariff_id', sa.Integer(), sa.ForeignKey('customs_tariffs.tariff_id', ondelete='SET NULL'), nullable=True),
            sa.Column('default_uom', sa.String(length=30), nullable=True, server_default=sa.text("'PCS'")),
            sa.Column('default_pkg_type', sa.String(length=50), nullable=True, server_default=sa.text("'Carton'")),
            sa.Column('cbm_per_unit', sa.Float(), nullable=True, server_default=sa.text('0.0')),
            sa.Column('gross_weight_kg', sa.Float(), nullable=True, server_default=sa.text('0.0')),
            sa.Column('net_weight_kg', sa.Float(), nullable=True, server_default=sa.text('0.0')),
            sa.Column('last_customs_duty_pct', sa.Float(), nullable=True),
            sa.Column('last_vat_pct', sa.Float(), nullable=True),
            sa.Column('last_schedule_tax_pct', sa.Float(), nullable=True),
            sa.Column('product_category', sa.String(length=100), nullable=True),
            sa.Column('product_subcategory', sa.String(length=100), nullable=True),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('created_by', sa.String(length=100), nullable=True),
            sa.Column('updated_at', sa.DateTime(), nullable=True),
            sa.Column('updated_by', sa.String(length=100), nullable=True),
            sa.Column('deleted_at', sa.DateTime(), nullable=True),
            sa.Column('deleted_by', sa.String(length=100), nullable=True),
        )
        op.create_index('ix_master_items_item_code', 'master_items', ['item_code'], unique=True)
        op.create_index('ix_master_items_description_ar', 'master_items', ['description_ar'], unique=False)
        op.create_index('ix_master_items_product_category', 'master_items', ['product_category'], unique=False)
        op.create_index('ix_master_items_tariff_id', 'master_items', ['tariff_id'], unique=False)
        op.create_index('ix_master_items_is_active', 'master_items', ['is_active'], unique=False)

    # 2. item_supplier_catalog table
    if 'item_supplier_catalog' not in tables:
        op.create_table(
            'item_supplier_catalog',
            sa.Column('catalog_id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('item_id', sa.Integer(), sa.ForeignKey('master_items.item_id', ondelete='CASCADE'), nullable=False),
            sa.Column('supplier_id', sa.Integer(), sa.ForeignKey('suppliers.supplier_id', ondelete='CASCADE'), nullable=False),
            sa.Column('supplier_item_code', sa.String(length=100), nullable=True),
            sa.Column('supplier_description', sa.String(length=500), nullable=True),
            sa.Column('last_confirmed_price', sa.Float(), nullable=True),
            sa.Column('last_confirmed_currency', sa.String(length=10), nullable=True, server_default=sa.text("'USD'")),
            sa.Column('last_confirmed_date', sa.String(length=30), nullable=True),
            sa.Column('last_po_id', sa.Integer(), sa.ForeignKey('purchase_orders.po_id', ondelete='SET NULL'), nullable=True),
            sa.Column('min_order_qty', sa.Float(), nullable=True),
            sa.Column('lead_time_days', sa.Integer(), nullable=True),
            sa.Column('preferred_incoterm', sa.String(length=10), nullable=True),
            sa.Column('is_preferred_supplier', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(), nullable=True),
        )
        op.create_index('ix_item_supplier_catalog_item_id', 'item_supplier_catalog', ['item_id'], unique=False)
        op.create_index('ix_item_supplier_catalog_supplier_id', 'item_supplier_catalog', ['supplier_id'], unique=False)
        op.create_index('ix_item_supplier_catalog_supplier_item_code', 'item_supplier_catalog', ['supplier_item_code'], unique=False)
        op.create_index('ix_item_supplier_catalog_is_active', 'item_supplier_catalog', ['is_active'], unique=False)

    # 3. item_price_history table
    if 'item_price_history' not in tables:
        op.create_table(
            'item_price_history',
            sa.Column('history_id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('item_id', sa.Integer(), sa.ForeignKey('master_items.item_id', ondelete='CASCADE'), nullable=False),
            sa.Column('supplier_id', sa.Integer(), sa.ForeignKey('suppliers.supplier_id', ondelete='SET NULL'), nullable=True),
            sa.Column('po_id', sa.Integer(), sa.ForeignKey('purchase_orders.po_id', ondelete='SET NULL'), nullable=True),
            sa.Column('import_file_id', sa.Integer(), sa.ForeignKey('import_files.import_file_id', ondelete='SET NULL'), nullable=True),
            sa.Column('unit_price_fx', sa.Float(), nullable=False),
            sa.Column('currency', sa.String(length=10), nullable=False, server_default=sa.text("'USD'")),
            sa.Column('exchange_rate', sa.Float(), nullable=True, server_default=sa.text('1.0')),
            sa.Column('unit_price_egp', sa.Float(), nullable=True),
            sa.Column('landed_cost_egp', sa.Float(), nullable=True),
            sa.Column('landed_cost_markup', sa.Float(), nullable=True),
            sa.Column('quantity', sa.Float(), nullable=True),
            sa.Column('po_date', sa.String(length=30), nullable=True),
            sa.Column('recorded_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        )
        op.create_index('ix_item_price_history_item_id', 'item_price_history', ['item_id'], unique=False)
        op.create_index('ix_item_price_history_supplier_id', 'item_price_history', ['supplier_id'], unique=False)
        op.create_index('ix_item_price_history_po_id', 'item_price_history', ['po_id'], unique=False)
        op.create_index('ix_item_price_history_import_file_id', 'item_price_history', ['import_file_id'], unique=False)

    # 4. Linkage to po_line_items
    if 'po_line_items' in tables:
        po_columns = [c['name'] for c in inspector.get_columns('po_line_items')]
        if 'master_item_id' not in po_columns:
            with op.batch_alter_table('po_line_items', schema=None) as batch_op:
                batch_op.add_column(
                    sa.Column(
                        'master_item_id',
                        sa.Integer(),
                        sa.ForeignKey('master_items.item_id', ondelete='SET NULL'),
                        nullable=True,
                    )
                )

    # 5. Linkage to packing_list_items
    if 'packing_list_items' in tables:
        pkg_columns = [c['name'] for c in inspector.get_columns('packing_list_items')]
        if 'master_item_id' not in pkg_columns:
            with op.batch_alter_table('packing_list_items', schema=None) as batch_op:
                batch_op.add_column(
                    sa.Column(
                        'master_item_id',
                        sa.Integer(),
                        sa.ForeignKey('master_items.item_id', ondelete='SET NULL'),
                        nullable=True,
                    )
                )


def downgrade() -> None:
    conn = op.get_bind()
    inspector = Inspector.from_engine(conn)
    tables = inspector.get_table_names()

    if 'packing_list_items' in tables:
        pkg_columns = [c['name'] for c in inspector.get_columns('packing_list_items')]
        if 'master_item_id' in pkg_columns:
            with op.batch_alter_table('packing_list_items', schema=None) as batch_op:
                batch_op.drop_column('master_item_id')

    if 'po_line_items' in tables:
        po_columns = [c['name'] for c in inspector.get_columns('po_line_items')]
        if 'master_item_id' in po_columns:
            with op.batch_alter_table('po_line_items', schema=None) as batch_op:
                batch_op.drop_column('master_item_id')

    if 'item_price_history' in tables:
        op.drop_table('item_price_history')

    if 'item_supplier_catalog' in tables:
        op.drop_table('item_supplier_catalog')

    if 'master_items' in tables:
        op.drop_table('master_items')
