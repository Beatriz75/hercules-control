from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.course import CourseLesson, TrainingQuestion, TrainingQuestionOption


class TrainingAttempt(Base):
    __tablename__ = "training_attempts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    employee_reference: Mapped[str] = mapped_column(String(120), nullable=False, index=True)
    lesson_id: Mapped[int] = mapped_column(
        ForeignKey("course_lessons.id", ondelete="CASCADE"), nullable=False, index=True
    )
    score_percent: Mapped[float] = mapped_column(Float(), nullable=False)
    required_approval_percent: Mapped[int] = mapped_column(Integer, nullable=False)
    approved: Mapped[bool] = mapped_column(Boolean(), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    lesson: Mapped[CourseLesson] = relationship()
    answers: Mapped[list["TrainingAnswer"]] = relationship(
        back_populates="attempt",
        cascade="all, delete-orphan",
        order_by="TrainingAnswer.id",
    )


class TrainingAnswer(Base):
    __tablename__ = "training_answers"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    attempt_id: Mapped[int] = mapped_column(
        ForeignKey("training_attempts.id", ondelete="CASCADE"), nullable=False, index=True
    )
    question_id: Mapped[int] = mapped_column(ForeignKey("training_questions.id"), nullable=False, index=True)
    is_correct: Mapped[bool] = mapped_column(Boolean(), nullable=False)

    attempt: Mapped[TrainingAttempt] = relationship(back_populates="answers")
    question: Mapped[TrainingQuestion] = relationship()
    selected_options: Mapped[list["TrainingAnswerOption"]] = relationship(
        back_populates="answer",
        cascade="all, delete-orphan",
        order_by="TrainingAnswerOption.id",
    )


class TrainingAnswerOption(Base):
    __tablename__ = "training_answer_options"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    answer_id: Mapped[int] = mapped_column(
        ForeignKey("training_answers.id", ondelete="CASCADE"), nullable=False, index=True
    )
    option_id: Mapped[int] = mapped_column(ForeignKey("training_question_options.id"), nullable=False, index=True)

    answer: Mapped[TrainingAnswer] = relationship(back_populates="selected_options")
    option: Mapped[TrainingQuestionOption] = relationship()


class LessonProgress(Base):
    __tablename__ = "lesson_progress"
    __table_args__ = (
        UniqueConstraint("employee_reference", "lesson_id", name="uq_lesson_progress_employee_lesson"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    employee_reference: Mapped[str] = mapped_column(String(120), nullable=False, index=True)
    lesson_id: Mapped[int] = mapped_column(
        ForeignKey("course_lessons.id", ondelete="CASCADE"), nullable=False, index=True
    )
    theory_completed: Mapped[bool] = mapped_column(Boolean(), nullable=False, server_default="false")
    practice_approved: Mapped[bool] = mapped_column(Boolean(), nullable=False, server_default="false")
    best_score_percent: Mapped[float | None] = mapped_column(Float(), nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    lesson: Mapped[CourseLesson] = relationship()
