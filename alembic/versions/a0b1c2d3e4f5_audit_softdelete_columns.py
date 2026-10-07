"""Audit and soft-delete columns across models (Wave 0, BEW0-05)

- created_by / updated_by VARCHAR(100), nullable on 25 tables.
- deleted_at DATETIME, nullable and deleted_by VARCHAR(100), nullable on
  customs_tariffs and financial_settlement_records.
- Backfill shipment_bookings.created_by / updated_by from owner where created_by is NULL.

Defensive and additive: columns are added only when missing (create_all or
prior steps may already have added them).
Downgrade drops the added columns safely using batch_alter_table.

Revision ID: a0b1c2d3e4f5
Revises: f6a7b8c9d0e1
Create Date: 2026-10-06 22:00:00.000000
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "a0b1c2d3e4f5"
down_revision: Union[str, Sequence[str], None] = "f6a7b8c9d0e1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

AUDIT_TABLES: Sequence[str] = (
    "clearance_expense_types",
    "broker_price_lists",
    "freight_rfq_requests",
    "payment_request_sessions",
    "import_budget_approvals",
    "acid_registration_sessions",
    "banking_document_sessions",
    "shipment_document_items",
    "customs_declaration_drafts",
    "draft_bl_review_sessions",
    "certificate_of_origin_review_sessions",
    "inspection_certificate_review_sessions",
    "po_packing_reconciliation_sessions",
    "invoice_bl_match_sessions",
    "shipment_bookings",
    "customs_tariffs",
    "preferential_agreements",
    "fee_codes",
    "customs_clearance_rfqs",
    "customs_clearance_quotations",
    "clearance_price_list_items",
    "projects",
    "transport_locations",
    "expense_catalog",
    "currencies",
)

SOFT_DELETE_TABLES: Sequence[str] = (
    "customs_tariffs",
    "financial_settlement_records",
)


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    # 1. Audit columns on 25 tables
    for table_name in AUDIT_TABLES:
        if table_name not in tables:
            continue
        existing = {c["name"].lower() for c in inspector.get_columns(table_name)}
        to_add = []
        if "created_by" not in existing:
            to_add.append(sa.Column("created_by", sa.String(100), nullable=True))
        if "updated_by" not in existing:
            to_add.append(sa.Column("updated_by", sa.String(100), nullable=True))
        if to_add:
            with op.batch_alter_table(table_name) as batch_op:
                for col in to_add:
                    batch_op.add_column(col)

    # 2. Soft-delete columns on customs_tariffs and financial_settlement_records
    for table_name in SOFT_DELETE_TABLES:
        if table_name not in tables:
            continue
        existing = {c["name"].lower() for c in inspector.get_columns(table_name)}
        to_add = []
        if "deleted_at" not in existing:
            to_add.append(sa.Column("deleted_at", sa.DateTime(), nullable=True))
        if "deleted_by" not in existing:
            to_add.append(sa.Column("deleted_by", sa.String(100), nullable=True))
        if to_add:
            with op.batch_alter_table(table_name) as batch_op:
                for col in to_add:
                    batch_op.add_column(col)

    # 3. Backfill shipment_bookings.created_by / updated_by from owner
    if "shipment_bookings" in tables:
        op.execute(
            "UPDATE shipment_bookings "
            "SET created_by = COALESCE(NULLIF(owner, ''), 'system'), "
            "    updated_by = COALESCE(NULLIF(owner, ''), 'system') "
            "WHERE created_by IS NULL"
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    # 1. Soft-delete columns
    for table_name in SOFT_DELETE_TABLES:
        if table_name not in tables:
            continue
        existing = {c["name"].lower() for c in inspector.get_columns(table_name)}
        to_drop = [name for name in ("deleted_by", "deleted_at") if name in existing]
        if to_drop:
            with op.batch_alter_table(table_name) as batch_op:
                for name in to_drop:
                    batch_op.drop_column(name)

    # 2. Audit columns
    for table_name in AUDIT_TABLES:
        if table_name not in tables:
            continue
        existing = {c["name"].lower() for c in inspector.get_columns(table_name)}
        to_drop = [name for name in ("updated_by", "created_by") if name in existing]
        if to_drop:
            with op.batch_alter_table(table_name) as batch_op:
                for name in to_drop:
                    batch_op.drop_column(name)
