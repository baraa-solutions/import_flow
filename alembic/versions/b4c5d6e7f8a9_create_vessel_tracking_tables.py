"""create_vessel_tracking_tables (LOG-TRACK-001/002/003)

Revision ID: b4c5d6e7f8a9
Revises: f3a1b2c4d5e6
Create Date: 2026-10-20
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = 'b4c5d6e7f8a9'
down_revision: Union[str, Sequence[str], None] = 'f3a1b2c4d5e6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = inspector.get_table_names()

    # 1. vessels master table
    if 'vessels' not in tables:
        op.create_table(
            'vessels',
            sa.Column('vessel_id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('vessel_name', sa.String(length=150), nullable=False),
            sa.Column('imo_number', sa.String(length=20), unique=True, nullable=True),
            sa.Column('mmsi_number', sa.String(length=20), unique=True, nullable=True),
            sa.Column('call_sign', sa.String(length=30), nullable=True),
            sa.Column('flag_country', sa.String(length=50), nullable=False, server_default=sa.text("'Panama'")),
            sa.Column('vessel_type', sa.String(length=50), nullable=False, server_default=sa.text("'Container Ship'")),
            sa.Column('built_year', sa.Integer(), nullable=True),
            sa.Column('capacity_teu', sa.Integer(), nullable=True),
            sa.Column('shipping_line_name', sa.String(length=150), nullable=True),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('created_by', sa.String(length=100), nullable=True, server_default=sa.text("'System'")),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_by', sa.String(length=100), nullable=True, server_default=sa.text("'System'")),
        )
        op.create_index('ix_vessels_vessel_id', 'vessels', ['vessel_id'])
        op.create_index('ix_vessels_vessel_name', 'vessels', ['vessel_name'])
        op.create_index('ix_vessels_imo_number', 'vessels', ['imo_number'])
        op.create_index('ix_vessels_mmsi_number', 'vessels', ['mmsi_number'])
        op.create_index('ix_vessels_shipping_line_name', 'vessels', ['shipping_line_name'])
        op.create_index('ix_vessels_is_active', 'vessels', ['is_active'])

    # 2. vessel_position_logs telemetry table
    if 'vessel_position_logs' not in tables:
        op.create_table(
            'vessel_position_logs',
            sa.Column('position_id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('vessel_id', sa.Integer(), sa.ForeignKey('vessels.vessel_id'), nullable=False),
            sa.Column('timestamp', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('latitude', sa.Float(), nullable=False),
            sa.Column('longitude', sa.Float(), nullable=False),
            sa.Column('speed_knots', sa.Float(), nullable=False, server_default=sa.text('14.5')),
            sa.Column('course_degrees', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('heading_degrees', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('nav_status', sa.String(length=50), nullable=False, server_default=sa.text("'Underway Using Engine'")),
            sa.Column('current_zone', sa.String(length=100), nullable=False, server_default=sa.text("'Open Sea'")),
            sa.Column('destination_port_code', sa.String(length=50), nullable=True),
            sa.Column('distance_remaining_nm', sa.Float(), nullable=True),
            sa.Column('eta_predicted', sa.DateTime(), nullable=True),
            sa.Column('source', sa.String(length=50), nullable=False, server_default=sa.text("'AIS_LIVE'")),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        )
        op.create_index('ix_vessel_position_logs_position_id', 'vessel_position_logs', ['position_id'])
        op.create_index('ix_vessel_position_logs_vessel_id', 'vessel_position_logs', ['vessel_id'])
        op.create_index('ix_vessel_position_logs_timestamp', 'vessel_position_logs', ['timestamp'])
        op.create_index('idx_vessel_pos_vessel_time', 'vessel_position_logs', ['vessel_id', 'timestamp'])

    # 3. shipment_vessel_trackings table
    if 'shipment_vessel_trackings' not in tables:
        op.create_table(
            'shipment_vessel_trackings',
            sa.Column('tracking_id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('tracking_code', sa.String(length=50), unique=True, nullable=False),
            sa.Column('import_file_id', sa.Integer(), sa.ForeignKey('import_files.import_file_id'), unique=True, nullable=False),
            sa.Column('booking_id', sa.Integer(), sa.ForeignKey('shipment_bookings.booking_id'), nullable=True),
            sa.Column('vessel_id', sa.Integer(), sa.ForeignKey('vessels.vessel_id'), nullable=False),
            sa.Column('voyage_number', sa.String(length=50), nullable=True),
            sa.Column('pol_port_code', sa.String(length=50), nullable=False),
            sa.Column('pol_port_name', sa.String(length=150), nullable=False),
            sa.Column('pod_port_code', sa.String(length=50), nullable=False),
            sa.Column('pod_port_name', sa.String(length=150), nullable=False),
            sa.Column('scheduled_departure', sa.DateTime(), nullable=True),
            sa.Column('actual_departure', sa.DateTime(), nullable=True),
            sa.Column('scheduled_arrival', sa.DateTime(), nullable=True),
            sa.Column('estimated_arrival', sa.DateTime(), nullable=True),
            sa.Column('actual_arrival', sa.DateTime(), nullable=True),
            sa.Column('tracking_milestone', sa.String(length=50), nullable=False, server_default=sa.text("'In Transit'")),
            sa.Column('voyage_progress_pct', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('delay_hours', sa.Float(), nullable=False, server_default=sa.text('0.0')),
            sa.Column('delay_severity', sa.String(length=20), nullable=False, server_default=sa.text("'ON_TIME'")),
            sa.Column('last_polled_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('route_waypoints', sa.JSON(), nullable=True),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('created_by', sa.String(length=100), nullable=True, server_default=sa.text("'System'")),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_by', sa.String(length=100), nullable=True, server_default=sa.text("'System'")),
        )
        op.create_index('ix_shipment_vessel_trackings_tracking_id', 'shipment_vessel_trackings', ['tracking_id'])
        op.create_index('ix_shipment_vessel_trackings_tracking_code', 'shipment_vessel_trackings', ['tracking_code'])
        op.create_index('ix_shipment_vessel_trackings_import_file_id', 'shipment_vessel_trackings', ['import_file_id'])
        op.create_index('ix_shipment_vessel_trackings_booking_id', 'shipment_vessel_trackings', ['booking_id'])
        op.create_index('ix_shipment_vessel_trackings_vessel_id', 'shipment_vessel_trackings', ['vessel_id'])
        op.create_index('ix_shipment_vessel_trackings_tracking_milestone', 'shipment_vessel_trackings', ['tracking_milestone'])
        op.create_index('ix_shipment_vessel_trackings_is_active', 'shipment_vessel_trackings', ['is_active'])


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = inspector.get_table_names()

    if 'shipment_vessel_trackings' in tables:
        op.drop_table('shipment_vessel_trackings')
    if 'vessel_position_logs' in tables:
        op.drop_table('vessel_position_logs')
    if 'vessels' in tables:
        op.drop_table('vessels')
