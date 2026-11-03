"""wave1_regulatory_finance_custody

Revision ID: ee11aa22bb33
Revises: d1e2f3a4b5c6
Create Date: 2026-11-02 22:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ee11aa22bb33'
down_revision: Union[str, Sequence[str], None] = 'd1e2f3a4b5c6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()

    # 1. hs_code_regulatory_requirements
    if 'hs_code_regulatory_requirements' not in tables:
        op.create_table(
            'hs_code_regulatory_requirements',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('hs_code', sa.String(length=20), nullable=False, index=True),
            sa.Column('agency_code', sa.String(length=30), nullable=False, index=True),
            sa.Column('agency_name_ar', sa.String(length=255), nullable=False),
            sa.Column('agency_name_en', sa.String(length=255), nullable=False),
            sa.Column('stage_timing', sa.String(length=50), nullable=False, server_default='PRE_ARRIVAL'),
            sa.Column('required_documents', sa.Text(), nullable=True),
            sa.Column('inspection_type', sa.String(length=50), nullable=True),
            sa.Column('regulatory_notes', sa.Text(), nullable=True),
            sa.Column('is_mandatory', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('created_by', sa.String(length=50), nullable=False, server_default='system'),
            sa.Column('updated_by', sa.String(length=50), nullable=False, server_default='system'),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        )
        op.create_index(
            'ix_hs_code_agency',
            'hs_code_regulatory_requirements',
            ['hs_code', 'agency_code'],
            unique=False,
        )

    # 2. import_finance_instruments
    if 'import_finance_instruments' not in tables:
        op.create_table(
            'import_finance_instruments',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('instrument_type', sa.String(length=30), nullable=False),  # LC, CAD, ADVANCE_PAYMENT, OPEN_ACCOUNT
            sa.Column('instrument_number', sa.String(length=100), nullable=False, unique=True, index=True),
            sa.Column('import_file_id', sa.Integer(), sa.ForeignKey('import_files.import_file_id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('issuing_bank', sa.String(length=150), nullable=False),
            sa.Column('advising_bank', sa.String(length=150), nullable=True),
            sa.Column('currency', sa.String(length=10), nullable=False, server_default='USD'),
            sa.Column('amount', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('issue_date', sa.Date(), nullable=True),
            sa.Column('expiry_date', sa.Date(), nullable=True),
            sa.Column('shipment_deadline', sa.Date(), nullable=True),
            sa.Column('presentation_period_days', sa.Integer(), nullable=False, server_default='21'),
            sa.Column('payment_terms', sa.Text(), nullable=True),
            sa.Column('status', sa.String(length=30), nullable=False, server_default='DRAFT'),
            sa.Column('tolerance_percentage', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('created_by', sa.String(length=50), nullable=False, server_default='system'),
            sa.Column('updated_by', sa.String(length=50), nullable=False, server_default='system'),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        )

    # 3. lc_bank_charges
    if 'lc_bank_charges' not in tables:
        op.create_table(
            'lc_bank_charges',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('finance_instrument_id', sa.Integer(), sa.ForeignKey('import_finance_instruments.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('charge_type', sa.String(length=50), nullable=False),  # ISSUANCE_COMMISSION, SWIFT_CHARGE, etc.
            sa.Column('currency', sa.String(length=10), nullable=False, server_default='EGP'),
            sa.Column('amount', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('amount_egp', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('debit_date', sa.Date(), nullable=False),
            sa.Column('debit_account', sa.String(length=50), nullable=True),
            sa.Column('swift_reference', sa.String(length=100), nullable=True),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('created_by', sa.String(length=50), nullable=False, server_default='system'),
            sa.Column('updated_by', sa.String(length=50), nullable=False, server_default='system'),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        )

    # 4. fx_hedging_and_variance
    if 'fx_hedging_and_variance' not in tables:
        op.create_table(
            'fx_hedging_and_variance',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('finance_instrument_id', sa.Integer(), sa.ForeignKey('import_finance_instruments.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('foreign_currency', sa.String(length=10), nullable=False, server_default='USD'),
            sa.Column('original_amount', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('booking_date', sa.Date(), nullable=False),
            sa.Column('booking_rate', sa.Float(), nullable=False, server_default='1.0'),
            sa.Column('booking_total_egp', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('settlement_date', sa.Date(), nullable=True),
            sa.Column('settlement_rate', sa.Float(), nullable=True),
            sa.Column('settlement_total_egp', sa.Float(), nullable=True),
            sa.Column('hedging_contract_ref', sa.String(length=100), nullable=True),
            sa.Column('variance_amount_egp', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('variance_nature', sa.String(length=20), nullable=False, server_default='NEUTRAL'),  # LOSS, GAIN, NEUTRAL
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('created_by', sa.String(length=50), nullable=False, server_default='system'),
            sa.Column('updated_by', sa.String(length=50), nullable=False, server_default='system'),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        )

    # 5. customs_broker_advances
    if 'customs_broker_advances' not in tables:
        op.create_table(
            'customs_broker_advances',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('advance_code', sa.String(length=50), nullable=False, unique=True, index=True),
            sa.Column('import_file_id', sa.Integer(), sa.ForeignKey('import_files.import_file_id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('broker_id', sa.Integer(), sa.ForeignKey('external_service_providers.provider_id', ondelete='RESTRICT'), nullable=False, index=True),
            sa.Column('broker_name', sa.String(length=255), nullable=False),
            sa.Column('advance_amount', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('disbursement_date', sa.Date(), nullable=False),
            sa.Column('payment_method', sa.String(length=50), nullable=False, server_default='BANK_TRANSFER'),
            sa.Column('settled_amount', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('remaining_balance', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('status', sa.String(length=30), nullable=False, server_default='OPEN'),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('created_by', sa.String(length=50), nullable=False, server_default='system'),
            sa.Column('updated_by', sa.String(length=50), nullable=False, server_default='system'),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        )

    # 6. broker_settlement_receipts
    if 'broker_settlement_receipts' not in tables:
        op.create_table(
            'broker_settlement_receipts',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('advance_id', sa.Integer(), sa.ForeignKey('customs_broker_advances.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('receipt_type', sa.String(length=50), nullable=False),  # WHITE_RECEIPT_CUSTOMS_DUTIES, RED_RECEIPT_EXAMINATION_INSPECTION, etc.
            sa.Column('receipt_number', sa.String(length=100), nullable=False),
            sa.Column('receipt_date', sa.Date(), nullable=False),
            sa.Column('issuing_entity', sa.String(length=150), nullable=False),
            sa.Column('amount', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('tax_withholding_rate', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('tax_withheld_amount', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('net_amount', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('e_invoice_uuid', sa.String(length=100), nullable=True),
            sa.Column('is_official_receipt', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('verification_status', sa.String(length=30), nullable=False, server_default='PENDING'),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('created_by', sa.String(length=50), nullable=False, server_default='system'),
            sa.Column('updated_by', sa.String(length=50), nullable=False, server_default='system'),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        )


def downgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()

    if 'broker_settlement_receipts' in tables:
        op.drop_table('broker_settlement_receipts')
    if 'customs_broker_advances' in tables:
        op.drop_table('customs_broker_advances')
    if 'fx_hedging_and_variance' in tables:
        op.drop_table('fx_hedging_and_variance')
    if 'lc_bank_charges' in tables:
        op.drop_table('lc_bank_charges')
    if 'import_finance_instruments' in tables:
        op.drop_table('import_finance_instruments')
    if 'hs_code_regulatory_requirements' in tables:
        op.drop_table('hs_code_regulatory_requirements')
