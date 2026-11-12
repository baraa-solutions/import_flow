"""air freight suite: air_shipment_records and draft_awb_review_sessions

Trello 6wcX4CQ6. New tables only (no change to existing rows): one air waybill per record (MAWB / HAWB,
airline + airports as master-data FKs, gross / volumetric / chargeable weight components, airport storage) and
the draft AWB review sessions. Soft delete columns; no cascade delete.

Revision ID: c4a8e2f6b1d3
Revises: b8d2f4a6c1e3
Create Date: 2026-11-12 14:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c4a8e2f6b1d3'
down_revision: Union[str, Sequence[str], None] = 'b8d2f4a6c1e3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

RECORDS = 'air_shipment_records'
REVIEWS = 'draft_awb_review_sessions'


def _audit_columns():
    return [
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('created_by', sa.String(length=100), nullable=True),
        sa.Column('updated_by', sa.String(length=100), nullable=True),
        sa.Column('deleted_at', sa.DateTime(), nullable=True),
        sa.Column('deleted_by', sa.String(length=100), nullable=True),
    ]


def upgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if RECORDS not in tables:
        op.create_table(
            RECORDS,
            sa.Column('air_record_id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('air_record_code', sa.String(length=30), nullable=False),
            sa.Column('import_file_id', sa.Integer(), nullable=False),
            sa.Column('shipment_mode', sa.String(length=20), nullable=False, server_default=sa.text("'AIR'")),
            sa.Column('shipment_sub_mode', sa.String(length=30), nullable=True),
            sa.Column('mawb_number', sa.String(length=11), nullable=True),
            sa.Column('hawb_number', sa.String(length=50), nullable=True),
            sa.Column('airline_prefix', sa.String(length=3), nullable=True),
            sa.Column('airline_id', sa.Integer(), nullable=True),
            sa.Column('origin_airport_id', sa.Integer(), nullable=True),
            sa.Column('destination_airport_id', sa.Integer(), nullable=True),
            sa.Column('flight_number', sa.String(length=20), nullable=True),
            sa.Column('flight_date', sa.Date(), nullable=True),
            sa.Column('arrival_date', sa.Date(), nullable=True),
            sa.Column('pieces_count', sa.Integer(), nullable=True),
            sa.Column('gross_weight_kg', sa.Float(), nullable=True),
            sa.Column('volume_cbm', sa.Float(), nullable=True),
            sa.Column('volumetric_weight_kg', sa.Float(), nullable=True),
            sa.Column('chargeable_weight_kg', sa.Float(), nullable=True),
            sa.Column('volumetric_divisor', sa.Float(), nullable=True),
            sa.Column('package_lines', sa.JSON(), nullable=True),
            sa.Column('air_release_no', sa.String(length=100), nullable=True),
            sa.Column('airport_storage_start_date', sa.Date(), nullable=True),
            sa.Column('free_storage_days', sa.Integer(), nullable=True),
            sa.Column('goods_description', sa.Text(), nullable=True),
            sa.Column('notes', sa.Text(), nullable=True),
            *_audit_columns(),
            sa.ForeignKeyConstraint(['import_file_id'], ['import_files.import_file_id'],
                                    name='fk_air_shipment_records_import_file_id_import_files'),
            sa.ForeignKeyConstraint(['airline_id'], ['external_service_providers.provider_id'],
                                    name='fk_air_shipment_records_airline_id_external_service_providers'),
            sa.ForeignKeyConstraint(['origin_airport_id'], ['transport_locations.location_id'],
                                    name='fk_air_shipment_records_origin_airport_id_transport_locations'),
            sa.ForeignKeyConstraint(['destination_airport_id'], ['transport_locations.location_id'],
                                    name='fk_air_shipment_records_destination_airport_id_transport_locations'),
            sa.UniqueConstraint('mawb_number', 'hawb_number', name='uq_air_shipment_records_mawb_hawb'),
        )
        for column, unique in (
            ('air_record_id', False), ('air_record_code', True), ('import_file_id', False),
            ('airline_prefix', False), ('airline_id', False), ('origin_airport_id', False),
            ('destination_airport_id', False), ('is_active', False),
        ):
            op.create_index(f'ix_{RECORDS}_{column}', RECORDS, [column], unique=unique)

    if REVIEWS not in tables:
        op.create_table(
            REVIEWS,
            sa.Column('awb_review_id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('awb_review_code', sa.String(length=30), nullable=False),
            sa.Column('air_record_id', sa.Integer(), nullable=False),
            sa.Column('import_file_id', sa.Integer(), nullable=False),
            sa.Column('version_number', sa.Integer(), nullable=False, server_default=sa.text('1')),
            sa.Column('draft_awb_number', sa.String(length=20), nullable=True),
            sa.Column('draft_input_data', sa.JSON(), nullable=True),
            sa.Column('system_snapshot_data', sa.JSON(), nullable=True),
            sa.Column('checklist_data', sa.JSON(), nullable=True),
            sa.Column('blocking_reasons_coded', sa.JSON(), nullable=True),
            sa.Column('has_blocking_mismatch', sa.Boolean(), nullable=False, server_default=sa.text('0')),
            sa.Column('open_discrepancies_count', sa.Integer(), nullable=False, server_default=sa.text('0')),
            sa.Column('status', sa.String(length=30), nullable=False, server_default=sa.text("'REVIEWED'")),
            sa.Column('reviewed_by', sa.String(length=100), nullable=True),
            sa.Column('reviewed_at', sa.DateTime(), nullable=True),
            sa.Column('approved_by', sa.String(length=100), nullable=True),
            sa.Column('approved_at', sa.DateTime(), nullable=True),
            sa.Column('decision_notes', sa.Text(), nullable=True),
            *_audit_columns(),
            sa.ForeignKeyConstraint(['air_record_id'], ['air_shipment_records.air_record_id'],
                                    name='fk_draft_awb_review_sessions_air_record_id_air_shipment_records'),
            sa.ForeignKeyConstraint(['import_file_id'], ['import_files.import_file_id'],
                                    name='fk_draft_awb_review_sessions_import_file_id_import_files'),
        )
        for column, unique in (
            ('awb_review_id', False), ('awb_review_code', True), ('air_record_id', False),
            ('import_file_id', False), ('status', False), ('is_active', False),
        ):
            op.create_index(f'ix_{REVIEWS}_{column}', REVIEWS, [column], unique=unique)


def downgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if REVIEWS in tables:
        op.drop_table(REVIEWS)
    if RECORDS in tables:
        op.drop_table(RECORDS)
