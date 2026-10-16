"""Add question bank size per lesson and practice sessions.

Revision ID: 20261014_0001
Revises: 20261013_0001
Create Date: 2026-10-14 00:00:00
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "20261014_0001"
down_revision: str | None = "20261013_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("course_lessons", sa.Column("questions_per_attempt", sa.Integer(), nullable=True))

    op.create_table(
        "practice_sessions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("employee_reference", sa.String(length=120), nullable=False),
        sa.Column("lesson_id", sa.Integer(), nullable=False),
        sa.Column("question_ids", sa.JSON(), nullable=False),
        sa.Column("attempt_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["lesson_id"], ["course_lessons.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["attempt_id"], ["training_attempts.id"], ondelete="SET NULL"),
    )
    op.create_index("ix_practice_sessions_employee_reference", "practice_sessions", ["employee_reference"])
    op.create_index("ix_practice_sessions_lesson_id", "practice_sessions", ["lesson_id"])


def downgrade() -> None:
    op.drop_index("ix_practice_sessions_lesson_id", table_name="practice_sessions")
    op.drop_index("ix_practice_sessions_employee_reference", table_name="practice_sessions")
    op.drop_table("practice_sessions")
    op.drop_column("course_lessons", "questions_per_attempt")
