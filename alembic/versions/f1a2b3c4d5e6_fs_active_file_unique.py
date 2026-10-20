"""create partial unique index uq_fs_records_active_file on financial_settlement_records (BE09-T07)

Revision ID: f1a2b3c4d5e6
Revises: c9d0e1f2a3b4
Create Date: 2026-10-19
"""

from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers
revision: str = "f1a2b3c4d5e6"
down_revision: Union[str, Sequence[str], None] = "c9d0e1f2a3b4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

INDEX_NAME = "uq_fs_records_active_file"
TABLE_NAME = "financial_settlement_records"


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if TABLE_NAME not in set(inspector.get_table_names()):
        return

    # 1. Deduplicate existing active records: keep newest Approved, else highest settlement_id
    rows = bind.execute(sa.text("""
        SELECT settlement_id, import_file_id, status
        FROM financial_settlement_records
        WHERE is_active = 1
        ORDER BY import_file_id,
                 CASE WHEN status = 'Approved' THEN 1 ELSE 0 END DESC,
                 settlement_id DESC
    """)).fetchall()

    seen_files = set()
    to_deactivate = []
    for r in rows:
        fid = r.import_file_id
        sid = r.settlement_id
        if fid in seen_files:
            to_deactivate.append(sid)
        else:
            seen_files.add(fid)

    if to_deactivate:
        print(f"BE09-T07: Deactivating {len(to_deactivate)} duplicate active settlement records: {to_deactivate}")
        for sid in to_deactivate:
            bind.execute(
                sa.text("UPDATE financial_settlement_records SET is_active = 0 WHERE settlement_id = :sid"),
                {"sid": sid},
            )
    else:
        print("BE09-T07: No duplicate active settlement records found.")

    # 2. Check if index already exists
    existing_indexes = {idx["name"] for idx in inspector.get_indexes(TABLE_NAME)}
    if INDEX_NAME not in existing_indexes:
        op.create_index(
            INDEX_NAME,
            TABLE_NAME,
            ["import_file_id"],
            unique=True,
            sqlite_where=sa.text("is_active = 1"),
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if TABLE_NAME in set(inspector.get_table_names()):
        existing_indexes = {idx["name"] for idx in inspector.get_indexes(TABLE_NAME)}
        if INDEX_NAME in existing_indexes:
            op.drop_index(INDEX_NAME, table_name=TABLE_NAME)
