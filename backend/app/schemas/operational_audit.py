from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


class OperationalAuditAnswerCreate(BaseModel):
    criterion_id: int
    answer_text: str | None = None
    answer_score: float | None = Field(default=None, ge=0)
    notes: str | None = None

    @model_validator(mode="after")
    def validate_answer_content(self) -> "OperationalAuditAnswerCreate":
        if self.answer_text is None and self.answer_score is None:
            raise ValueError("answer_text or answer_score is required")
        return self


class OperationalAuditCreate(BaseModel):
    template_id: int
    target_type: Literal["employee", "area"]
    target_reference: str = Field(min_length=1, max_length=120)
    auditor_name: str = Field(min_length=1, max_length=120)
    status: Literal["draft", "completed"] = "completed"
    score: float | None = Field(default=None, ge=0)
    notes: str | None = None
    answers: list[OperationalAuditAnswerCreate] = Field(min_length=1)

    @model_validator(mode="after")
    def validate_unique_answers(self) -> "OperationalAuditCreate":
        criterion_ids = [answer.criterion_id for answer in self.answers]
        if len(criterion_ids) != len(set(criterion_ids)):
            raise ValueError("answer criterion_id values must be unique")
        return self


class OperationalAuditAnswerRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    criterion_id: int
    answer_text: str | None
    answer_score: float | None
    notes: str | None
    criterion_label: str
    sort_order: int
    created_at: datetime
    updated_at: datetime


class OperationalAuditFindingRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    audit_id: int
    severity: str
    finding_type: str | None
    description: str
    status: str
    employee_reference: str | None
    created_at: datetime
    updated_at: datetime


class OperationalAuditRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    template_id: int
    target_type: str
    target_reference: str
    auditor_name: str
    status: str
    score: float | None
    notes: str | None
    created_at: datetime
    updated_at: datetime
    completed_at: datetime | None
    answers: list[OperationalAuditAnswerRead]
    findings: list[OperationalAuditFindingRead]
