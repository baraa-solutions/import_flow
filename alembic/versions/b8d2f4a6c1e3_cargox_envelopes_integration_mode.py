"""cargox_envelopes.integration_mode: flag envelopes produced by the simulated (MOCK) CargoX client

Production Mock Guard (Trello NLv0Dpj5). Existing rows stay NULL ("unknown / not sent").

Revision ID: b8d2f4a6c1e3
Revises: a7c1e9d3f5b2
Create Date: 2026-11-12 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b8d2f4a6c1e3'
down_revision: Union[str, Sequence[str], None] = 'a7c1e9d3f5b2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE = 'cargox_envelopes'
COLUMN = 'integration_mode'
INDEX = 'ix_cargox_envelopes_integration_mode'


def upgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    if TABLE not in inspector.get_table_names():
        return
    if COLUMN not in {c['name'] for c in inspector.get_columns(TABLE)}:
        op.add_column(TABLE, sa.Column(COLUMN, sa.String(length=16), nullable=True))
    if INDEX not in {ix['name'] for ix in inspector.get_indexes(TABLE)}:
        op.create_index(INDEX, TABLE, [COLUMN], unique=False)


def downgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    if TABLE not in inspector.get_table_names():
        return
    if INDEX in {ix['name'] for ix in inspector.get_indexes(TABLE)}:
        op.drop_index(INDEX, table_name=TABLE)
    if COLUMN in {c['name'] for c in inspector.get_columns(TABLE)}:
        with op.batch_alter_table(TABLE) as batch_op:
            batch_op.drop_column(COLUMN)
