from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, model_validator


class TrainingAnswerCreate(BaseModel):
    question_id: int
    selected_option_ids: list[int] = Field(min_length=1)

    @model_validator(mode="after")
    def validate_unique_selected_options(self) -> "TrainingAnswerCreate":
        if len(self.selected_option_ids) != len(set(self.selected_option_ids)):
            raise ValueError("Elegiste la misma opción dos veces.")
        return self


class TrainingAttemptCreate(BaseModel):
    session_id: int
    answers: list[TrainingAnswerCreate] = Field(min_length=1)

    @model_validator(mode="after")
    def validate_unique_questions(self) -> "TrainingAttemptCreate":
        question_ids = [answer.question_id for answer in self.answers]
        if len(question_ids) != len(set(question_ids)):
            raise ValueError("Respondiste la misma pregunta dos veces.")
        return self


class TrainingAnswerOptionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    option_id: int


class TrainingAnswerRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    question_id: int
    is_correct: bool
    selected_options: list[TrainingAnswerOptionRead]
    correct_option_ids: list[int]
    explanation: str | None


class TrainingAttemptRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    employee_reference: str
    lesson_id: int
    score_percent: float
    required_approval_percent: int
    approved: bool
    created_at: datetime
    answers: list[TrainingAnswerRead]


class LessonProgressRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    employee_reference: str
    lesson_id: int
    theory_completed: bool
    practice_approved: bool
    best_score_percent: float | None
    completed_at: datetime | None
    updated_at: datetime


class AnswerReviewRead(BaseModel):
    """One answered question of an attempt, readable by staff."""

    question_id: int
    code: str | None
    prompt: str
    is_correct: bool
    selected_labels: list[str]
    correct_labels: list[str]


class AttemptReviewRead(BaseModel):
    """A student's attempt with lesson context and numbered per lesson (1 = first try)."""

    id: int
    employee_reference: str
    course_id: int
    course_title: str
    lesson_id: int
    lesson_title: str
    lesson_sort_order: int
    attempt_number: int
    created_at: datetime
    score_percent: float
    required_approval_percent: int
    approved: bool
    answers: list[AnswerReviewRead]


class MissedQuestionRow(BaseModel):
    """How often students failed one question (only students' attempts count)."""

    question_id: int
    code: str | None
    prompt: str
    course_id: int
    course_title: str
    lesson_id: int
    lesson_title: str
    times_answered: int
    times_failed: int
    fail_percent: float
