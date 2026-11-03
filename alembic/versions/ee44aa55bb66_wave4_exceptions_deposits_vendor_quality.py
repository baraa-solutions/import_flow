"""wave4_exceptions_deposits_vendor_quality

Revision ID: ee44aa55bb66
Revises: ee33aa44bb55
Create Date: 2026-11-02 22:30:00.000000

Wave 4 Migration:
- logistics_exceptions: Vessel roll-over, blank sailing, port congestion, valuation dispute, ACID alignment, delay KPI suspension.
- refundable_deposits_ledger: Shipping line container deposits, customs duty securities, bank letters of guarantee, EIR tracking, refund claims.
- vendor_quality_and_psi: Pre-shipment inspection (PSI - SGS/BV), vendor performance scorecard rating, defect tracking.
"""

from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ee44aa55bb66'
down_revision: Union[str, Sequence[str], None] = 'ee33aa44bb55'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = set(inspector.get_table_names())

    # 1. logistics_exceptions
    if 'logistics_exceptions' not in tables:
        op.create_table(
            'logistics_exceptions',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('exception_code', sa.String(length=50), nullable=False, unique=True),
            sa.Column('import_file_id', sa.Integer(), sa.ForeignKey('import_files.import_file_id', ondelete='SET NULL'), nullable=True),
            sa.Column('shipment_id', sa.Integer(), nullable=True),
            sa.Column('exception_type', sa.String(length=50), nullable=False),
            sa.Column('severity', sa.String(length=20), nullable=False, server_default=sa.text("'MEDIUM'")),
            sa.Column('title_ar', sa.String(length=255), nullable=False),
            sa.Column('title_en', sa.String(length=255), nullable=False),
            sa.Column('description', sa.Text(), nullable=True),
            sa.Column('delay_impact_days', sa.Integer(), nullable=False, server_default=sa.text('0')),
            sa.Column('acid_number', sa.String(length=50), nullable=True),
            sa.Column('acid_original_expiry', sa.Date(), nullable=True),
            sa.Column('acid_adjusted_expiry', sa.Date(), nullable=True),
            sa.Column('acid_impact_status', sa.String(length=30), nullable=False, server_default=sa.text("'NOT_AFFECTED'")),
            sa.Column('delay_kpi_suspended', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('suspension_reason', sa.Text(), nullable=True),
            sa.Column('valuation_dispute_amount', sa.Float(), nullable=True),
            sa.Column('valuation_original_customs_val', sa.Float(), nullable=True),
            sa.Column('valuation_declared_val', sa.Float(), nullable=True),
            sa.Column('appeal_status', sa.String(length=30), nullable=True),
            sa.Column('resolution_strategy', sa.Text(), nullable=True),
            sa.Column('status', sa.String(length=30), nullable=False, server_default=sa.text("'OPEN'")),
            sa.Column('resolved_at', sa.DateTime(), nullable=True),
            sa.Column('resolved_by_user_id', sa.Integer(), sa.ForeignKey('users.user_id', ondelete='SET NULL'), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('is_deleted', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('created_by_user_id', sa.Integer(), sa.ForeignKey('users.user_id', ondelete='SET NULL'), nullable=True),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        )
        op.create_index('ix_logistics_exceptions_import_file', 'logistics_exceptions', ['import_file_id', 'status'])
        op.create_index('ix_logistics_exceptions_code', 'logistics_exceptions', ['exception_code'])
        op.create_index('ix_logistics_exceptions_type', 'logistics_exceptions', ['exception_type'])

    # 2. refundable_deposits_ledger
    if 'refundable_deposits_ledger' not in tables:
        op.create_table(
            'refundable_deposits_ledger',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('deposit_code', sa.String(length=50), nullable=False, unique=True),
            sa.Column('import_file_id', sa.Integer(), sa.ForeignKey('import_files.import_file_id', ondelete='SET NULL'), nullable=True),
            sa.Column('deposit_type', sa.String(length=50), nullable=False),
            sa.Column('beneficiary_type', sa.String(length=30), nullable=False),
            sa.Column('beneficiary_name', sa.String(length=255), nullable=False),
            sa.Column('container_number', sa.String(length=50), nullable=True),
            sa.Column('eir_number', sa.String(length=100), nullable=True),
            sa.Column('eir_return_date', sa.Date(), nullable=True),
            sa.Column('deposit_amount', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('currency', sa.String(length=10), nullable=False, server_default=sa.text("'EGP'")),
            sa.Column('paid_date', sa.Date(), nullable=True),
            sa.Column('payment_reference', sa.String(length=100), nullable=True),
            sa.Column('bank_lg_number', sa.String(length=100), nullable=True),
            sa.Column('bank_lg_issuing_bank', sa.String(length=150), nullable=True),
            sa.Column('bank_lg_expiry_date', sa.Date(), nullable=True),
            sa.Column('recovery_status', sa.String(length=30), nullable=False, server_default=sa.text("'PENDING'")),
            sa.Column('refunded_amount', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('refund_date', sa.Date(), nullable=True),
            sa.Column('refund_reference', sa.String(length=100), nullable=True),
            sa.Column('deduction_amount', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('deduction_reason', sa.Text(), nullable=True),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('is_deleted', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('created_by_user_id', sa.Integer(), sa.ForeignKey('users.user_id', ondelete='SET NULL'), nullable=True),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        )
        op.create_index('ix_refundable_deposits_file_status', 'refundable_deposits_ledger', ['import_file_id', 'recovery_status'])
        op.create_index('ix_refundable_deposits_code', 'refundable_deposits_ledger', ['deposit_code'])
        op.create_index('ix_refundable_deposits_container', 'refundable_deposits_ledger', ['container_number'])
        op.create_index('ix_refundable_deposits_type', 'refundable_deposits_ledger', ['deposit_type'])

    # 3. vendor_quality_and_psi
    if 'vendor_quality_and_psi' not in tables:
        op.create_table(
            'vendor_quality_and_psi',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('assessment_code', sa.String(length=50), nullable=False, unique=True),
            sa.Column('vendor_id', sa.Integer(), sa.ForeignKey('suppliers.supplier_id', ondelete='SET NULL'), nullable=True),
            sa.Column('vendor_name', sa.String(length=255), nullable=False),
            sa.Column('purchase_order_id', sa.Integer(), sa.ForeignKey('purchase_orders.po_id', ondelete='SET NULL'), nullable=True),
            sa.Column('import_file_id', sa.Integer(), sa.ForeignKey('import_files.import_file_id', ondelete='SET NULL'), nullable=True),
            sa.Column('inspection_agency', sa.String(length=50), nullable=False),
            sa.Column('psi_certificate_number', sa.String(length=100), nullable=True),
            sa.Column('inspection_date', sa.Date(), nullable=True),
            sa.Column('psi_result', sa.String(length=30), nullable=False, server_default=sa.text("'PENDING'")),
            sa.Column('defects_count', sa.Integer(), nullable=False, server_default=sa.text('0')),
            sa.Column('critical_defects_count', sa.Integer(), nullable=False, server_default=sa.text('0')),
            sa.Column('inspection_certificate_file', sa.String(length=500), nullable=True),
            sa.Column('quality_score', sa.Float(), nullable=False, server_default=sa.text('100.0')),
            sa.Column('delivery_timeliness_score', sa.Float(), nullable=False, server_default=sa.text('100.0')),
            sa.Column('documentation_accuracy_score', sa.Float(), nullable=False, server_default=sa.text('100.0')),
            sa.Column('compliance_score', sa.Float(), nullable=False, server_default=sa.text('100.0')),
            sa.Column('overall_vendor_rating', sa.Float(), nullable=False, server_default=sa.text('100.0')),
            sa.Column('rating_grade', sa.String(length=10), nullable=False, server_default=sa.text("'A'")),
            sa.Column('corrective_action_required', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('corrective_action_plan', sa.Text(), nullable=True),
            sa.Column('inspector_notes', sa.Text(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('is_deleted', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('created_by_user_id', sa.Integer(), sa.ForeignKey('users.user_id', ondelete='SET NULL'), nullable=True),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        )
        op.create_index('ix_vendor_psi_code', 'vendor_quality_and_psi', ['assessment_code'])
        op.create_index('ix_vendor_psi_vendor', 'vendor_quality_and_psi', ['vendor_id', 'psi_result'])
        op.create_index('ix_vendor_psi_po', 'vendor_quality_and_psi', ['purchase_order_id'])
        op.create_index('ix_vendor_psi_rating', 'vendor_quality_and_psi', ['overall_vendor_rating'])


def downgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = set(inspector.get_table_names())

    if 'vendor_quality_and_psi' in tables:
        op.drop_table('vendor_quality_and_psi')

    if 'refundable_deposits_ledger' in tables:
        op.drop_table('refundable_deposits_ledger')

    if 'logistics_exceptions' in tables:
        op.drop_table('logistics_exceptions')
