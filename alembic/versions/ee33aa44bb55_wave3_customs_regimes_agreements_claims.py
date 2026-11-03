"""wave3_customs_regimes_agreements_claims

Revision ID: ee33aa44bb55
Revises: ee22aa33bb44
Create Date: 2026-11-02 22:30:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ee33aa44bb55'
down_revision: Union[str, Sequence[str], None] = 'ee22aa33bb44'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()

    # 1. customs_special_regimes
    if 'customs_special_regimes' not in tables:
        op.create_table(
            'customs_special_regimes',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('regime_code', sa.String(length=50), nullable=False),
            sa.Column('import_file_id', sa.Integer(), sa.ForeignKey('import_files.import_file_id', ondelete='CASCADE'), nullable=False),
            sa.Column('shipment_id', sa.Integer(), nullable=True),
            sa.Column('regime_type', sa.String(length=50), nullable=False),
            sa.Column('status', sa.String(length=30), nullable=False, server_default='ACTIVE'),
            sa.Column('customs_office', sa.String(length=100), nullable=True),
            sa.Column('release_form_number', sa.String(length=100), nullable=True),
            sa.Column('release_date', sa.Date(), nullable=True),
            sa.Column('guarantee_type', sa.String(length=50), nullable=True),
            sa.Column('guarantee_reference', sa.String(length=100), nullable=True),
            sa.Column('guarantee_bank', sa.String(length=100), nullable=True),
            sa.Column('guarantee_amount', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('guarantee_currency', sa.String(length=10), nullable=False, server_default='EGP'),
            sa.Column('guarantee_issue_date', sa.Date(), nullable=True),
            sa.Column('guarantee_expiry_date', sa.Date(), nullable=True),
            sa.Column('re_export_deadline', sa.Date(), nullable=True),
            sa.Column('actual_re_export_date', sa.Date(), nullable=True),
            sa.Column('re_export_export_declaration_no', sa.String(length=100), nullable=True),
            sa.Column('drawback_reconciliation_ref', sa.String(length=100), nullable=True),
            sa.Column('drawback_refund_amount', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('reconciled_date', sa.Date(), nullable=True),
            sa.Column('is_settled', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('is_deleted', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('created_by_user_id', sa.Integer(), sa.ForeignKey('users.user_id', ondelete='SET NULL'), nullable=True),
            sa.Column('updated_by_user_id', sa.Integer(), sa.ForeignKey('users.user_id', ondelete='SET NULL'), nullable=True),
        )
        op.create_index('ix_customs_special_regimes_id', 'customs_special_regimes', ['id'])
        op.create_index('ix_customs_special_regimes_regime_code', 'customs_special_regimes', ['regime_code'], unique=True)
        op.create_index('ix_customs_special_regimes_import_file_id', 'customs_special_regimes', ['import_file_id'])
        op.create_index('ix_customs_special_regimes_regime_type', 'customs_special_regimes', ['regime_type'])
        op.create_index('ix_customs_special_regimes_status', 'customs_special_regimes', ['status'])
        op.create_index('ix_customs_special_regimes_is_deleted', 'customs_special_regimes', ['is_deleted'])

    # 2. preferential_origin_verifications
    if 'preferential_origin_verifications' not in tables:
        op.create_table(
            'preferential_origin_verifications',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('verification_code', sa.String(length=50), nullable=False),
            sa.Column('import_file_id', sa.Integer(), sa.ForeignKey('import_files.import_file_id', ondelete='CASCADE'), nullable=False),
            sa.Column('shipment_id', sa.Integer(), nullable=True),
            sa.Column('agreement_name', sa.String(length=50), nullable=False),
            sa.Column('certificate_type', sa.String(length=50), nullable=False),
            sa.Column('certificate_number', sa.String(length=100), nullable=False),
            sa.Column('issuing_country', sa.String(length=100), nullable=False),
            sa.Column('issuing_authority', sa.String(length=150), nullable=True),
            sa.Column('issuing_date', sa.Date(), nullable=False),
            sa.Column('validity_months', sa.Integer(), nullable=False, server_default='4'),
            sa.Column('expiry_date', sa.Date(), nullable=True),
            sa.Column('submission_status', sa.String(length=50), nullable=False, server_default='COPY_SUBMITTED'),
            sa.Column('has_original_received', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('original_received_date', sa.Date(), nullable=True),
            sa.Column('provisional_escrow_required', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('provisional_escrow_amount', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('provisional_escrow_receipt', sa.String(length=100), nullable=True),
            sa.Column('provisional_escrow_deadline', sa.Date(), nullable=True),
            sa.Column('provisional_escrow_refunded', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('refund_date', sa.Date(), nullable=True),
            sa.Column('direct_transport_compliant', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('rules_of_origin_criterion', sa.String(length=50), nullable=True),
            sa.Column('verification_notes', sa.Text(), nullable=True),
            sa.Column('is_deleted', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('created_by_user_id', sa.Integer(), sa.ForeignKey('users.user_id', ondelete='SET NULL'), nullable=True),
            sa.Column('updated_by_user_id', sa.Integer(), sa.ForeignKey('users.user_id', ondelete='SET NULL'), nullable=True),
        )
        op.create_index('ix_preferential_origin_verifications_id', 'preferential_origin_verifications', ['id'])
        op.create_index('ix_preferential_origin_verifications_code', 'preferential_origin_verifications', ['verification_code'], unique=True)
        op.create_index('ix_preferential_origin_verifications_file_id', 'preferential_origin_verifications', ['import_file_id'])
        op.create_index('ix_preferential_origin_verifications_agreement', 'preferential_origin_verifications', ['agreement_name'])
        op.create_index('ix_preferential_origin_verifications_cert_no', 'preferential_origin_verifications', ['certificate_number'])
        op.create_index('ix_preferential_origin_verifications_status', 'preferential_origin_verifications', ['submission_status'])
        op.create_index('ix_preferential_origin_verifications_is_deleted', 'preferential_origin_verifications', ['is_deleted'])

    # 3. cargo_claims_and_reservations
    if 'cargo_claims_and_reservations' not in tables:
        op.create_table(
            'cargo_claims_and_reservations',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('claim_code', sa.String(length=50), nullable=False),
            sa.Column('import_file_id', sa.Integer(), sa.ForeignKey('import_files.import_file_id', ondelete='CASCADE'), nullable=False),
            sa.Column('shipment_id', sa.Integer(), nullable=True),
            sa.Column('claim_type', sa.String(length=50), nullable=False),
            sa.Column('damage_nature', sa.String(length=30), nullable=False),
            sa.Column('delivery_date', sa.Date(), nullable=True),
            sa.Column('latent_notice_deadline', sa.Date(), nullable=True),
            sa.Column('apparent_notice_date', sa.Date(), nullable=True),
            sa.Column('time_bar_statute_of_limitations_date', sa.Date(), nullable=False),
            sa.Column('status', sa.String(length=50), nullable=False, server_default='RESERVATION_ISSUED'),
            sa.Column('reservation_letter_ref', sa.String(length=100), nullable=True),
            sa.Column('reservation_letter_date', sa.Date(), nullable=True),
            sa.Column('target_party', sa.String(length=100), nullable=False),
            sa.Column('survey_requested', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('survey_date', sa.Date(), nullable=True),
            sa.Column('surveyor_company', sa.String(length=150), nullable=True),
            sa.Column('survey_report_ref', sa.String(length=100), nullable=True),
            sa.Column('claimed_amount', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('claimed_currency', sa.String(length=10), nullable=False, server_default='USD'),
            sa.Column('settled_amount', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('settlement_date', sa.Date(), nullable=True),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('is_deleted', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('created_by_user_id', sa.Integer(), sa.ForeignKey('users.user_id', ondelete='SET NULL'), nullable=True),
            sa.Column('updated_by_user_id', sa.Integer(), sa.ForeignKey('users.user_id', ondelete='SET NULL'), nullable=True),
        )
        op.create_index('ix_cargo_claims_and_reservations_id', 'cargo_claims_and_reservations', ['id'])
        op.create_index('ix_cargo_claims_and_reservations_code', 'cargo_claims_and_reservations', ['claim_code'], unique=True)
        op.create_index('ix_cargo_claims_and_reservations_file_id', 'cargo_claims_and_reservations', ['import_file_id'])
        op.create_index('ix_cargo_claims_and_reservations_type', 'cargo_claims_and_reservations', ['claim_type'])
        op.create_index('ix_cargo_claims_and_reservations_status', 'cargo_claims_and_reservations', ['status'])
        op.create_index('ix_cargo_claims_and_reservations_time_bar', 'cargo_claims_and_reservations', ['time_bar_statute_of_limitations_date'])
        op.create_index('ix_cargo_claims_and_reservations_is_deleted', 'cargo_claims_and_reservations', ['is_deleted'])


def downgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()

    if 'cargo_claims_and_reservations' in tables:
        op.drop_table('cargo_claims_and_reservations')

    if 'preferential_origin_verifications' in tables:
        op.drop_table('preferential_origin_verifications')

    if 'customs_special_regimes' in tables:
        op.drop_table('customs_special_regimes')
