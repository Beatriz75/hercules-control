"""Add a visible, searchable code to bank questions.

Revision ID: 20261016_0001
Revises: 20261015_0001
Create Date: 2026-10-16 00:00:00
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "20261016_0001"
down_revision: str | None = "20261015_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Not unique: the same common question lives in several courses with the same code.
    op.add_column("training_questions", sa.Column("code", sa.String(length=20), nullable=True))
    op.create_index("ix_training_questions_code", "training_questions", ["code"])


def downgrade() -> None:
    op.drop_index("ix_training_questions_code", table_name="training_questions")
    op.drop_column("training_questions", "code")
