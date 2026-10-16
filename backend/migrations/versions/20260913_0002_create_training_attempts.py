"""Create training attempts and lesson progress.

Revision ID: 20260913_0002
Revises: 20260913_0001
Create Date: 2026-09-13 00:10:00
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "20260913_0002"
down_revision: str | None = "20260913_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "training_attempts",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("employee_reference", sa.String(length=120), nullable=False),
        sa.Column("lesson_id", sa.Integer(), nullable=False),
        sa.Column("score_percent", sa.Float(), nullable=False),
        sa.Column("required_approval_percent", sa.Integer(), nullable=False),
        sa.Column("approved", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["lesson_id"], ["course_lessons.id"], ondelete="CASCADE"),
    )
    op.create_index("ix_training_attempts_employee_reference", "training_attempts", ["employee_reference"])
    op.create_index("ix_training_attempts_lesson_id", "training_attempts", ["lesson_id"])

    op.create_table(
        "training_answers",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("attempt_id", sa.Integer(), nullable=False),
        sa.Column("question_id", sa.Integer(), nullable=False),
        sa.Column("is_correct", sa.Boolean(), nullable=False),
        sa.ForeignKeyConstraint(["attempt_id"], ["training_attempts.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["question_id"], ["training_questions.id"]),
    )
    op.create_index("ix_training_answers_attempt_id", "training_answers", ["attempt_id"])
    op.create_index("ix_training_answers_question_id", "training_answers", ["question_id"])

    op.create_table(
        "training_answer_options",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("answer_id", sa.Integer(), nullable=False),
        sa.Column("option_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["answer_id"], ["training_answers.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["option_id"], ["training_question_options.id"]),
    )
    op.create_index("ix_training_answer_options_answer_id", "training_answer_options", ["answer_id"])
    op.create_index("ix_training_answer_options_option_id", "training_answer_options", ["option_id"])

    op.create_table(
        "lesson_progress",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("employee_reference", sa.String(length=120), nullable=False),
        sa.Column("lesson_id", sa.Integer(), nullable=False),
        sa.Column("theory_completed", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("practice_approved", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("best_score_percent", sa.Float(), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["lesson_id"], ["course_lessons.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("employee_reference", "lesson_id", name="uq_lesson_progress_employee_lesson"),
    )
    op.create_index("ix_lesson_progress_employee_reference", "lesson_progress", ["employee_reference"])
    op.create_index("ix_lesson_progress_lesson_id", "lesson_progress", ["lesson_id"])


def downgrade() -> None:
    op.drop_index("ix_lesson_progress_lesson_id", table_name="lesson_progress")
    op.drop_index("ix_lesson_progress_employee_reference", table_name="lesson_progress")
    op.drop_table("lesson_progress")
    op.drop_index("ix_training_answer_options_option_id", table_name="training_answer_options")
    op.drop_index("ix_training_answer_options_answer_id", table_name="training_answer_options")
    op.drop_table("training_answer_options")
    op.drop_index("ix_training_answers_question_id", table_name="training_answers")
    op.drop_index("ix_training_answers_attempt_id", table_name="training_answers")
    op.drop_table("training_answers")
    op.drop_index("ix_training_attempts_lesson_id", table_name="training_attempts")
    op.drop_index("ix_training_attempts_employee_reference", table_name="training_attempts")
    op.drop_table("training_attempts")
