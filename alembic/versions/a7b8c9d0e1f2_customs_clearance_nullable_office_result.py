"""make customs_office_name and inspection_result nullable in customs_clearance_records (BE67-T17)

The invented defaults ("Alexandria Port Customs", "Conforming") were removed, so a record that has no office or
inspection result yet stores NULL instead of a made-up value.

Revision ID: a7b8c9d0e1f2
Revises: 73cee71ca978
Create Date: 2026-10-17
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers
revision: str = "a7b8c9d0e1f2"
down_revision: Union[str, Sequence[str], None] = "73cee71ca978"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE = "customs_clearance_records"
COLUMNS = (("customs_office_name", 200), ("inspection_result", 50))


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if TABLE not in set(inspector.get_table_names()):
        return
    cols = {c["name"].lower(): c for c in inspector.get_columns(TABLE)}
    to_alter = [(name, length) for name, length in COLUMNS if name in cols and not cols[name].get("nullable", True)]
    if not to_alter:
        return
    with op.batch_alter_table(TABLE) as batch_op:
        for name, length in to_alter:
            batch_op.alter_column(name, existing_type=sa.String(length=length), nullable=True)


def downgrade() -> None:
    # Restoring NOT NULL would need invented values for NULL rows, so the columns stay nullable.
    pass
