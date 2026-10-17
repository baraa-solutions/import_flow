"""Add specialized fields for MD-02 (Suppliers) and MD-04 (Shipping Lines / Partners)

MD-02 (suppliers):
- tax_id VARCHAR(50), nullable
- currency VARCHAR(10), server_default="USD", nullable=False
- contact_person VARCHAR(150), nullable
- city VARCHAR(100), nullable
- postal_code VARCHAR(20), nullable
- payment_terms VARCHAR(100), nullable
- credit_limit FLOAT, server_default="0.0", nullable=False
- rating FLOAT, server_default="5.0", nullable=False

MD-04 (external_service_providers):
- account_number VARCHAR(100), nullable
- iban VARCHAR(100), nullable
- local_agent_name VARCHAR(200), nullable
- booking_email VARCHAR(150), nullable

Revision ID: d1a2b3c4e5f6
Revises: c7e1f2a3b4d5
Create Date: 2026-10-09 19:30:00.000000
"""
from typing import Sequence, Union
import sqlalchemy as sa
from alembic import op

revision: str = "d1a2b3c4e5f6"
down_revision: Union[str, Sequence[str], None] = "c7e1f2a3b4d5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    # 1. Update suppliers table (MD-02)
    if "suppliers" in tables:
        existing = {c["name"].lower() for c in inspector.get_columns("suppliers")}
        with op.batch_alter_table("suppliers") as batch_op:
            if "tax_id" not in existing:
                batch_op.add_column(sa.Column("tax_id", sa.String(50), nullable=True))
            if "currency" not in existing:
                batch_op.add_column(sa.Column("currency", sa.String(10), server_default="USD", nullable=False))
            if "contact_person" not in existing:
                batch_op.add_column(sa.Column("contact_person", sa.String(150), nullable=True))
            if "city" not in existing:
                batch_op.add_column(sa.Column("city", sa.String(100), nullable=True))
            if "postal_code" not in existing:
                batch_op.add_column(sa.Column("postal_code", sa.String(20), nullable=True))
            if "payment_terms" not in existing:
                batch_op.add_column(sa.Column("payment_terms", sa.String(100), nullable=True))
            if "credit_limit" not in existing:
                batch_op.add_column(sa.Column("credit_limit", sa.Float(), server_default="0.0", nullable=False))
            if "rating" not in existing:
                batch_op.add_column(sa.Column("rating", sa.Float(), server_default="5.0", nullable=False))

    # 2. Update external_service_providers table (MD-04)
    if "external_service_providers" in tables:
        existing = {c["name"].lower() for c in inspector.get_columns("external_service_providers")}
        with op.batch_alter_table("external_service_providers") as batch_op:
            if "account_number" not in existing:
                batch_op.add_column(sa.Column("account_number", sa.String(100), nullable=True))
            if "iban" not in existing:
                batch_op.add_column(sa.Column("iban", sa.String(100), nullable=True))
            if "local_agent_name" not in existing:
                batch_op.add_column(sa.Column("local_agent_name", sa.String(200), nullable=True))
            if "booking_email" not in existing:
                batch_op.add_column(sa.Column("booking_email", sa.String(150), nullable=True))


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if "external_service_providers" in tables:
        existing = {c["name"].lower() for c in inspector.get_columns("external_service_providers")}
        to_drop = [c for c in ("booking_email", "local_agent_name", "iban", "account_number") if c in existing]
        if to_drop:
            with op.batch_alter_table("external_service_providers") as batch_op:
                for c in to_drop:
                    batch_op.drop_column(c)

    if "suppliers" in tables:
        existing = {c["name"].lower() for c in inspector.get_columns("suppliers")}
        to_drop = [c for c in ("rating", "credit_limit", "payment_terms", "postal_code", "city", "contact_person", "currency", "tax_id") if c in existing]
        if to_drop:
            with op.batch_alter_table("suppliers") as batch_op:
                for c in to_drop:
                    batch_op.drop_column(c)
