"""foreign vendor multi-currency sub-ledger, credit limit governance and aging (Trello GzFff0Pc)

Adds ``supplier_ledger_entries`` (system-generated supplier account movements per currency),
``supplier_credit_overrides`` (ADMIN overrides of a BLOCK credit limit) and the credit limit currency / policy
columns on ``suppliers``. Existing suppliers keep ``credit_limit`` (0 = no limit) with policy BLOCK.

Revision ID: d5f1a3c7e9b2
Revises: c4a8e2f6b1d3
Create Date: 2026-11-12 18:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd5f1a3c7e9b2'
down_revision: Union[str, Sequence[str], None] = 'c4a8e2f6b1d3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

LEDGER = 'supplier_ledger_entries'
OVERRIDES = 'supplier_credit_overrides'
SUPPLIERS = 'suppliers'

# (column, SQL) added to suppliers. Column-level CHECK so SQLite can DROP the column on downgrade.
SUPPLIER_COLUMNS = (
    ('credit_limit_currency', 'VARCHAR(10)'),
    ('credit_limit_policy',
     "VARCHAR(10) NOT NULL DEFAULT 'BLOCK' CONSTRAINT ck_suppliers_credit_limit_policy "
     "CHECK (credit_limit_policy IN ('WARN', 'BLOCK'))"),
)


def upgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    tables = inspector.get_table_names()

    if SUPPLIERS in tables:
        existing = {c['name'] for c in inspector.get_columns(SUPPLIERS)}
        for name, sql in SUPPLIER_COLUMNS:
            if name not in existing:
                op.execute(f"ALTER TABLE {SUPPLIERS} ADD COLUMN {name} {sql}")

    if LEDGER not in tables:
        op.create_table(
            LEDGER,
            sa.Column('entry_id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('entry_code', sa.String(length=30), nullable=False),
            sa.Column('supplier_id', sa.Integer(), sa.ForeignKey('suppliers.supplier_id'), nullable=False),
            sa.Column('import_file_id', sa.Integer(), sa.ForeignKey('import_files.import_file_id'), nullable=True),
            sa.Column('payment_id', sa.Integer(), sa.ForeignKey('payment_request_sessions.payment_id'), nullable=True),
            sa.Column('finance_instrument_id', sa.Integer(), sa.ForeignKey('import_finance_instruments.id'),
                      nullable=True),
            sa.Column('source_key', sa.String(length=160), nullable=False),
            sa.Column('entry_type', sa.String(length=20), nullable=False),
            sa.Column('direction', sa.String(length=10), nullable=False),
            sa.Column('payment_pathway', sa.String(length=20), nullable=True),
            sa.Column('reference', sa.String(length=120), nullable=True),
            sa.Column('entry_date', sa.Date(), nullable=False),
            sa.Column('due_date', sa.Date(), nullable=True),
            sa.Column('currency', sa.String(length=10), nullable=False),
            sa.Column('amount_fx', sa.Float(), nullable=False),
            sa.Column('exchange_rate', sa.Float(), nullable=True),
            sa.Column('amount_egp', sa.Float(), nullable=False, server_default='0'),
            sa.Column('open_amount_fx', sa.Float(), nullable=False, server_default='0'),
            sa.Column('status', sa.String(length=10), nullable=False, server_default='OPEN'),
            sa.Column('description', sa.Text(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('deleted_at', sa.DateTime(), nullable=True),
            sa.Column('deleted_by', sa.String(length=100), nullable=True),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('created_by', sa.String(length=100), nullable=True),
            sa.Column('updated_by', sa.String(length=100), nullable=True),
            sa.UniqueConstraint('supplier_id', 'source_key', name='uq_supplier_ledger_source'),
            sa.CheckConstraint(
                "entry_type IN ('ADVANCE_PAID', 'LC_COMMITTED', 'CAD_ACCEPTED', 'INVOICE_BILLED', "
                "'PAYMENT_SETTLED')",
                name='ck_supplier_ledger_entries_entry_type',
            ),
            sa.CheckConstraint("direction IN ('CREDIT', 'DEBIT', 'MEMO')",
                               name='ck_supplier_ledger_entries_direction'),
            sa.CheckConstraint("amount_fx >= 0", name='ck_supplier_ledger_entries_amount_fx'),
            sa.CheckConstraint("status IN ('OPEN', 'PARTIAL', 'SETTLED', 'UNAPPLIED')",
                               name='ck_supplier_ledger_entries_status'),
        )
        op.create_index('ix_supplier_ledger_entries_entry_code', LEDGER, ['entry_code'], unique=True)
        op.create_index('ix_supplier_ledger_entries_supplier_id', LEDGER, ['supplier_id'], unique=False)
        op.create_index('ix_supplier_ledger_entries_import_file_id', LEDGER, ['import_file_id'], unique=False)
        op.create_index('ix_supplier_ledger_entries_payment_id', LEDGER, ['payment_id'], unique=False)
        op.create_index('ix_supplier_ledger_entries_finance_instrument_id', LEDGER, ['finance_instrument_id'],
                        unique=False)
        op.create_index('ix_supplier_ledger_supplier_currency', LEDGER, ['supplier_id', 'currency'], unique=False)

    if OVERRIDES not in tables:
        op.create_table(
            OVERRIDES,
            sa.Column('override_id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('supplier_id', sa.Integer(), sa.ForeignKey('suppliers.supplier_id'), nullable=False),
            sa.Column('context', sa.String(length=30), nullable=False),
            sa.Column('reference', sa.String(length=100), nullable=True),
            sa.Column('currency', sa.String(length=10), nullable=False),
            sa.Column('limit_amount', sa.Float(), nullable=False),
            sa.Column('utilization_amount', sa.Float(), nullable=False),
            sa.Column('requested_amount', sa.Float(), nullable=False),
            sa.Column('projected_amount', sa.Float(), nullable=False),
            sa.Column('reason', sa.Text(), nullable=False),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('created_by', sa.String(length=100), nullable=False),
            sa.Column('updated_by', sa.String(length=100), nullable=True),
        )
        op.create_index('ix_supplier_credit_overrides_supplier_id', OVERRIDES, ['supplier_id'], unique=False)


def downgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    tables = inspector.get_table_names()
    if OVERRIDES in tables:
        op.drop_table(OVERRIDES)
    if LEDGER in tables:
        op.drop_table(LEDGER)
    if SUPPLIERS in tables:
        existing = {c['name'] for c in inspector.get_columns(SUPPLIERS)}
        for name, _sql in reversed(SUPPLIER_COLUMNS):
            if name in existing:
                op.execute(f"ALTER TABLE {SUPPLIERS} DROP COLUMN {name}")
