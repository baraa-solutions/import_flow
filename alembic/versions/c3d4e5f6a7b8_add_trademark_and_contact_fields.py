"""Add trademark certificates, contact extensions, and payment terms for MD-02, MD-04, and MD-08

MD-04 (import_companies):
- website VARCHAR(200), nullable
- secondary_email VARCHAR(150), nullable
- mobile VARCHAR(50), nullable
- fax VARCHAR(50), nullable
- nafeza_token TEXT, nullable
- has_wipo BOOLEAN, server_default="0", nullable=False
- wipo_number VARCHAR(100), nullable
- has_euipo BOOLEAN, server_default="0", nullable=False
- euipo_number VARCHAR(100), nullable
- has_global_brand BOOLEAN, server_default="0", nullable=False
- global_brand_number VARCHAR(100), nullable
- has_iso_9001 BOOLEAN, server_default="0", nullable=False
- iso_9001_number VARCHAR(100), nullable

MD-02 (suppliers):
- has_wipo BOOLEAN, server_default="0", nullable=False
- wipo_number VARCHAR(100), nullable
- has_euipo BOOLEAN, server_default="0", nullable=False
- euipo_number VARCHAR(100), nullable
- has_global_brand BOOLEAN, server_default="0", nullable=False
- global_brand_number VARCHAR(100), nullable
- has_iso_9001 BOOLEAN, server_default="0", nullable=False
- iso_9001_number VARCHAR(100), nullable

MD-08 (external_service_providers):
- payment_terms VARCHAR(100), nullable

Revision ID: c3d4e5f6a7b8
Revises: d1a2b3c4e5f6
Create Date: 2026-10-09 20:00:00.000000
"""
from typing import Sequence, Union
import sqlalchemy as sa
from alembic import op

revision: str = "c3d4e5f6a7b8"
down_revision: Union[str, Sequence[str], None] = "d1a2b3c4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    # 1. Update import_companies (MD-04)
    if "import_companies" in tables:
        existing = {c["name"].lower() for c in inspector.get_columns("import_companies")}
        with op.batch_alter_table("import_companies") as batch_op:
            if "website" not in existing:
                batch_op.add_column(sa.Column("website", sa.String(200), nullable=True))
            if "secondary_email" not in existing:
                batch_op.add_column(sa.Column("secondary_email", sa.String(150), nullable=True))
            if "mobile" not in existing:
                batch_op.add_column(sa.Column("mobile", sa.String(50), nullable=True))
            if "fax" not in existing:
                batch_op.add_column(sa.Column("fax", sa.String(50), nullable=True))
            if "nafeza_token" not in existing:
                batch_op.add_column(sa.Column("nafeza_token", sa.Text(), nullable=True))
            if "has_wipo" not in existing:
                batch_op.add_column(sa.Column("has_wipo", sa.Boolean(), server_default=sa.false(), nullable=False))
            if "wipo_number" not in existing:
                batch_op.add_column(sa.Column("wipo_number", sa.String(100), nullable=True))
            if "has_euipo" not in existing:
                batch_op.add_column(sa.Column("has_euipo", sa.Boolean(), server_default=sa.false(), nullable=False))
            if "euipo_number" not in existing:
                batch_op.add_column(sa.Column("euipo_number", sa.String(100), nullable=True))
            if "has_global_brand" not in existing:
                batch_op.add_column(sa.Column("has_global_brand", sa.Boolean(), server_default=sa.false(), nullable=False))
            if "global_brand_number" not in existing:
                batch_op.add_column(sa.Column("global_brand_number", sa.String(100), nullable=True))
            if "has_iso_9001" not in existing:
                batch_op.add_column(sa.Column("has_iso_9001", sa.Boolean(), server_default=sa.false(), nullable=False))
            if "iso_9001_number" not in existing:
                batch_op.add_column(sa.Column("iso_9001_number", sa.String(100), nullable=True))

    # 2. Update suppliers (MD-02)
    if "suppliers" in tables:
        existing = {c["name"].lower() for c in inspector.get_columns("suppliers")}
        with op.batch_alter_table("suppliers") as batch_op:
            if "has_wipo" not in existing:
                batch_op.add_column(sa.Column("has_wipo", sa.Boolean(), server_default=sa.false(), nullable=False))
            if "wipo_number" not in existing:
                batch_op.add_column(sa.Column("wipo_number", sa.String(100), nullable=True))
            if "has_euipo" not in existing:
                batch_op.add_column(sa.Column("has_euipo", sa.Boolean(), server_default=sa.false(), nullable=False))
            if "euipo_number" not in existing:
                batch_op.add_column(sa.Column("euipo_number", sa.String(100), nullable=True))
            if "has_global_brand" not in existing:
                batch_op.add_column(sa.Column("has_global_brand", sa.Boolean(), server_default=sa.false(), nullable=False))
            if "global_brand_number" not in existing:
                batch_op.add_column(sa.Column("global_brand_number", sa.String(100), nullable=True))
            if "has_iso_9001" not in existing:
                batch_op.add_column(sa.Column("has_iso_9001", sa.Boolean(), server_default=sa.false(), nullable=False))
            if "iso_9001_number" not in existing:
                batch_op.add_column(sa.Column("iso_9001_number", sa.String(100), nullable=True))

    # 3. Update external_service_providers (MD-08)
    if "external_service_providers" in tables:
        existing = {c["name"].lower() for c in inspector.get_columns("external_service_providers")}
        with op.batch_alter_table("external_service_providers") as batch_op:
            if "payment_terms" not in existing:
                batch_op.add_column(sa.Column("payment_terms", sa.String(100), nullable=True))


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if "external_service_providers" in tables:
        existing = {c["name"].lower() for c in inspector.get_columns("external_service_providers")}
        if "payment_terms" in existing:
            with op.batch_alter_table("external_service_providers") as batch_op:
                batch_op.drop_column("payment_terms")

    if "suppliers" in tables:
        existing = {c["name"].lower() for c in inspector.get_columns("suppliers")}
        to_drop = [c for c in ("iso_9001_number", "has_iso_9001", "global_brand_number", "has_global_brand", "euipo_number", "has_euipo", "wipo_number", "has_wipo") if c in existing]
        if to_drop:
            with op.batch_alter_table("suppliers") as batch_op:
                for c in to_drop:
                    batch_op.drop_column(c)

    if "import_companies" in tables:
        existing = {c["name"].lower() for c in inspector.get_columns("import_companies")}
        to_drop = [c for c in (
            "iso_9001_number", "has_iso_9001", "global_brand_number", "has_global_brand",
            "euipo_number", "has_euipo", "wipo_number", "has_wipo", "nafeza_token",
            "fax", "mobile", "secondary_email", "website"
        ) if c in existing]
        if to_drop:
            with op.batch_alter_table("import_companies") as batch_op:
                for c in to_drop:
                    batch_op.drop_column(c)
