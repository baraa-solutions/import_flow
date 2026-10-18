"""create shipment tracking logs, clearance followup, and 25-stage timeline snapshots (TASK-DB-04 to TASK-DB-08)

Revision ID: d0e1f2a3b4c5
Revises: c9d0e1f2a3b4
Create Date: 2026-10-18
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers
revision: str = "d0e1f2a3b4c5"
down_revision: Union[str, Sequence[str], None] = "c9d0e1f2a3b4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    # 1. Create shipment_eta_tracking_logs (TASK-DB-04)
    if "shipment_eta_tracking_logs" not in tables:
        op.create_table(
            "shipment_eta_tracking_logs",
            sa.Column("log_id", sa.Integer(), autoincrement=True, nullable=False, primary_key=True),
            sa.Column("booking_id", sa.Integer(), sa.ForeignKey("shipment_bookings.booking_id"), nullable=False, index=True),
            sa.Column("import_file_id", sa.Integer(), sa.ForeignKey("import_files.import_file_id"), nullable=False, index=True),
            sa.Column("tracking_date", sa.DateTime(), nullable=False),
            sa.Column("vessel_location", sa.String(length=200), nullable=True),
            sa.Column("current_eta", sa.DateTime(), nullable=False),
            sa.Column("delay_days", sa.Integer(), nullable=False, server_default=sa.text("0")),
            sa.Column("remarks", sa.Text(), nullable=True),
            sa.Column("is_ata_confirmed", sa.Boolean(), nullable=False, server_default=sa.text("0")),
            sa.Column("confirmed_ata", sa.DateTime(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("created_by", sa.String(length=100), nullable=True),
        )

    # 2. Create clearance_followup_logs (TASK-DB-05)
    if "clearance_followup_logs" not in tables:
        op.create_table(
            "clearance_followup_logs",
            sa.Column("log_id", sa.Integer(), autoincrement=True, nullable=False, primary_key=True),
            sa.Column("customs_clearance_id", sa.Integer(), sa.ForeignKey("customs_clearance_records.customs_clearance_id"), nullable=False, index=True),
            sa.Column("import_file_id", sa.Integer(), sa.ForeignKey("import_files.import_file_id"), nullable=False, index=True),
            sa.Column("followup_seq", sa.Integer(), nullable=False, server_default=sa.text("1")),
            sa.Column("followup_date", sa.DateTime(), nullable=False),
            sa.Column("authority_type", sa.String(length=100), nullable=False),
            sa.Column("official_contact", sa.String(length=150), nullable=True),
            sa.Column("status_summary", sa.String(length=255), nullable=False),
            sa.Column("action_required", sa.Text(), nullable=True),
            sa.Column("next_visit_date", sa.DateTime(), nullable=True),
            sa.Column("is_completed", sa.Boolean(), nullable=False, server_default=sa.text("0")),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("created_by", sa.String(length=100), nullable=True),
        )

    # 3. Create shipment_timeline_snapshots (TASK-DB-06)
    if "shipment_timeline_snapshots" not in tables:
        op.create_table(
            "shipment_timeline_snapshots",
            sa.Column("snapshot_id", sa.Integer(), autoincrement=True, nullable=False, primary_key=True),
            sa.Column("import_file_id", sa.Integer(), sa.ForeignKey("import_files.import_file_id"), nullable=False, index=True),
            sa.Column("stage_code", sa.String(length=50), nullable=False, index=True),
            sa.Column("stage_name_ar", sa.String(length=200), nullable=False),
            sa.Column("stage_name_en", sa.String(length=200), nullable=False),
            sa.Column("phase_number", sa.Integer(), nullable=False, server_default=sa.text("1")),
            sa.Column("status", sa.String(length=50), nullable=False, server_default=sa.text("'PENDING'")),
            sa.Column("planned_date", sa.DateTime(), nullable=True),
            sa.Column("actual_date", sa.DateTime(), nullable=True),
            sa.Column("variance_days", sa.Integer(), nullable=True, server_default=sa.text("0")),
            sa.Column("sla_days", sa.Integer(), nullable=False, server_default=sa.text("1")),
            sa.Column("is_bottleneck", sa.Boolean(), nullable=False, server_default=sa.text("0")),
            sa.Column("delay_reason", sa.Text(), nullable=True),
            sa.Column("event_details_json", sa.JSON(), nullable=True),
            sa.Column("completed_by", sa.String(length=100), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
        )
        op.create_index(
            "uq_timeline_file_stage",
            "shipment_timeline_snapshots",
            ["import_file_id", "stage_code"],
            unique=True,
        )

    # 4. Add missing columns to shipment_bookings (TASK-DB-07)
    if "shipment_bookings" in tables:
        booking_cols = {c["name"] for c in inspector.get_columns("shipment_bookings")}
        with op.batch_alter_table("shipment_bookings") as batch_op:
            if "agent_data_received_date" not in booking_cols:
                batch_op.add_column(sa.Column("agent_data_received_date", sa.DateTime(), nullable=True))
            if "agent_data_sent_to_supplier_date" not in booking_cols:
                batch_op.add_column(sa.Column("agent_data_sent_to_supplier_date", sa.DateTime(), nullable=True))
            if "factory_loading_date" not in booking_cols:
                batch_op.add_column(sa.Column("factory_loading_date", sa.DateTime(), nullable=True))
            if "ata" not in booking_cols:
                batch_op.add_column(sa.Column("ata", sa.DateTime(), nullable=True))
            if "is_ata_confirmed" not in booking_cols:
                batch_op.add_column(sa.Column("is_ata_confirmed", sa.Boolean(), nullable=False, server_default=sa.text("0")))

    # 5. Add missing columns to customs_clearance_records (TASK-DB-07)
    if "customs_clearance_records" in tables:
        clearance_cols = {c["name"] for c in inspector.get_columns("customs_clearance_records")}
        with op.batch_alter_table("customs_clearance_records") as batch_op:
            if "tariff_coding_date" not in clearance_cols:
                batch_op.add_column(sa.Column("tariff_coding_date", sa.DateTime(), nullable=True))
            if "bank_link_accepted_date" not in clearance_cols:
                batch_op.add_column(sa.Column("bank_link_accepted_date", sa.DateTime(), nullable=True))
            if "duty_payment_requested_date" not in clearance_cols:
                batch_op.add_column(sa.Column("duty_payment_requested_date", sa.DateTime(), nullable=True))


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if "customs_clearance_records" in tables:
        clearance_cols = {c["name"] for c in inspector.get_columns("customs_clearance_records")}
        with op.batch_alter_table("customs_clearance_records") as batch_op:
            if "duty_payment_requested_date" in clearance_cols:
                batch_op.drop_column("duty_payment_requested_date")
            if "bank_link_accepted_date" in clearance_cols:
                batch_op.drop_column("bank_link_accepted_date")
            if "tariff_coding_date" in clearance_cols:
                batch_op.drop_column("tariff_coding_date")

    if "shipment_bookings" in tables:
        booking_cols = {c["name"] for c in inspector.get_columns("shipment_bookings")}
        with op.batch_alter_table("shipment_bookings") as batch_op:
            if "is_ata_confirmed" in booking_cols:
                batch_op.drop_column("is_ata_confirmed")
            if "ata" in booking_cols:
                batch_op.drop_column("ata")
            if "factory_loading_date" in booking_cols:
                batch_op.drop_column("factory_loading_date")
            if "agent_data_sent_to_supplier_date" in booking_cols:
                batch_op.drop_column("agent_data_sent_to_supplier_date")
            if "agent_data_received_date" in booking_cols:
                batch_op.drop_column("agent_data_received_date")

    if "shipment_timeline_snapshots" in tables:
        op.drop_table("shipment_timeline_snapshots")

    if "clearance_followup_logs" in tables:
        op.drop_table("clearance_followup_logs")

    if "shipment_eta_tracking_logs" in tables:
        op.drop_table("shipment_eta_tracking_logs")
