"""Add pre-Form 4 readiness pipeline fields to banking_document_sessions

Includes:
- Tax coding sheet tracking (status, file url, pull date/broker, upload date/accountant)
- Items pull & verification tracking (verified boolean, date, counts, regulatory bodies)
- Nafeza bank linkage (status, date, linked bank, swift bank matching)

Revision ID: e4f5a6b7c8d9
Revises: d4e5f6a7b8c9
Create Date: 2026-10-10 02:00:00.000000
"""
from typing import Sequence, Union
import sqlalchemy as sa
from alembic import op

revision: str = "e4f5a6b7c8d9"
down_revision: Union[str, Sequence[str], None] = "d4e5f6a7b8c9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if "banking_document_sessions" in tables:
        existing = {c["name"].lower() for c in inspector.get_columns("banking_document_sessions")}
        with op.batch_alter_table("banking_document_sessions") as batch_op:
            if "tax_coding_sheet_status" not in existing:
                batch_op.add_column(
                    sa.Column("tax_coding_sheet_status", sa.String(50), server_default="NOT_STARTED", nullable=False)
                )
            if "tax_coding_sheet_file_url" not in existing:
                batch_op.add_column(sa.Column("tax_coding_sheet_file_url", sa.String(500), nullable=True))
            if "tax_coding_pulled_date" not in existing:
                batch_op.add_column(sa.Column("tax_coding_pulled_date", sa.Date(), nullable=True))
            if "tax_coding_broker_id" not in existing:
                batch_op.add_column(sa.Column("tax_coding_broker_id", sa.Integer(), nullable=True))
            if "tax_coding_broker_name" not in existing:
                batch_op.add_column(sa.Column("tax_coding_broker_name", sa.String(200), nullable=True))
            if "tax_coding_uploaded_date" not in existing:
                batch_op.add_column(sa.Column("tax_coding_uploaded_date", sa.Date(), nullable=True))
            if "tax_coding_accountant_name" not in existing:
                batch_op.add_column(sa.Column("tax_coding_accountant_name", sa.String(200), nullable=True))

            if "items_pulled_verified" not in existing:
                batch_op.add_column(
                    sa.Column("items_pulled_verified", sa.Boolean(), server_default="0", nullable=False)
                )
            if "items_pulled_date" not in existing:
                batch_op.add_column(sa.Column("items_pulled_date", sa.Date(), nullable=True))
            if "items_count_total" not in existing:
                batch_op.add_column(sa.Column("items_count_total", sa.Integer(), server_default="0", nullable=True))
            if "items_count_coded" not in existing:
                batch_op.add_column(sa.Column("items_count_coded", sa.Integer(), server_default="0", nullable=True))
            if "regulatory_bodies_detected" not in existing:
                batch_op.add_column(sa.Column("regulatory_bodies_detected", sa.JSON(), nullable=True))

            if "nafeza_bank_link_status" not in existing:
                batch_op.add_column(
                    sa.Column("nafeza_bank_link_status", sa.String(50), server_default="PENDING", nullable=False)
                )
            if "nafeza_bank_link_date" not in existing:
                batch_op.add_column(sa.Column("nafeza_bank_link_date", sa.Date(), nullable=True))
            if "nafeza_linked_bank_id" not in existing:
                batch_op.add_column(sa.Column("nafeza_linked_bank_id", sa.Integer(), nullable=True))
            if "nafeza_linked_bank_name" not in existing:
                batch_op.add_column(sa.Column("nafeza_linked_bank_name", sa.String(200), nullable=True))
            if "swift_executing_bank_id" not in existing:
                batch_op.add_column(sa.Column("swift_executing_bank_id", sa.Integer(), nullable=True))
            if "swift_executing_bank_name" not in existing:
                batch_op.add_column(sa.Column("swift_executing_bank_name", sa.String(200), nullable=True))
            if "swift_reference_no" not in existing:
                batch_op.add_column(sa.Column("swift_reference_no", sa.String(100), nullable=True))
            if "is_bank_matching_swift" not in existing:
                batch_op.add_column(
                    sa.Column("is_bank_matching_swift", sa.Boolean(), server_default="1", nullable=False)
                )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if "banking_document_sessions" in tables:
        indexes = {idx["name"] for idx in inspector.get_indexes("banking_document_sessions")}
        with op.batch_alter_table("banking_document_sessions") as batch_op:
            if "ix_banking_document_sessions_tax_coding_sheet_status" in indexes:
                batch_op.drop_index("ix_banking_document_sessions_tax_coding_sheet_status")
            if "ix_banking_document_sessions_nafeza_bank_link_status" in indexes:
                batch_op.drop_index("ix_banking_document_sessions_nafeza_bank_link_status")
            cols = [
                "tax_coding_sheet_status",
                "tax_coding_sheet_file_url",
                "tax_coding_pulled_date",
                "tax_coding_broker_id",
                "tax_coding_broker_name",
                "tax_coding_uploaded_date",
                "tax_coding_accountant_name",
                "items_pulled_verified",
                "items_pulled_date",
                "items_count_total",
                "items_count_coded",
                "regulatory_bodies_detected",
                "nafeza_bank_link_status",
                "nafeza_bank_link_date",
                "nafeza_linked_bank_id",
                "nafeza_linked_bank_name",
                "swift_executing_bank_id",
                "swift_executing_bank_name",
                "swift_reference_no",
                "is_bank_matching_swift",
            ]
            for c in cols:
                try:
                    batch_op.drop_column(c)
                except Exception:
                    pass
