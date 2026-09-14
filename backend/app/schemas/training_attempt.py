from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, model_validator


class TrainingAnswerCreate(BaseModel):
    question_id: int
    selected_option_ids: list[int] = Field(min_length=1)

    @model_validator(mode="after")
    def validate_unique_selected_options(self) -> "TrainingAnswerCreate":
        if len(self.selected_option_ids) != len(set(self.selected_option_ids)):
            raise ValueError("selected_option_ids values must be unique")
        return self


class TrainingAttemptCreate(BaseModel):
    employee_reference: str = Field(min_length=1, max_length=120)
    lesson_id: int
    answers: list[TrainingAnswerCreate] = Field(min_length=1)

    @model_validator(mode="after")
    def validate_unique_questions(self) -> "TrainingAttemptCreate":
        question_ids = [answer.question_id for answer in self.answers]
        if len(question_ids) != len(set(question_ids)):
            raise ValueError("answer question_id values must be unique")
        return self


class TheoryCompletedUpdate(BaseModel):
    employee_reference: str = Field(min_length=1, max_length=120)


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
