from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


def _duplicate_sort_orders(items: list) -> bool:
    sort_orders = [item.sort_order for item in items]
    return len(sort_orders) != len(set(sort_orders))


class TrainingQuestionOptionCreate(BaseModel):
    label: str = Field(min_length=1, max_length=2000)
    media_url: str | None = None
    option_type: Literal["text", "image"] = "text"
    is_correct: bool = False
    sort_order: int = Field(ge=1)


class TrainingQuestionCreate(BaseModel):
    prompt: str = Field(min_length=1, max_length=4000)
    question_type: Literal["text", "image"] = "text"
    answer_mode: Literal["single", "multiple"] = "single"
    image_url: str | None = None
    sort_order: int = Field(ge=1)
    options: list[TrainingQuestionOptionCreate] = Field(min_length=2)

    @model_validator(mode="after")
    def validate_options(self) -> "TrainingQuestionCreate":
        if _duplicate_sort_orders(self.options):
            raise ValueError("option sort_order values must be unique")

        correct_count = sum(1 for option in self.options if option.is_correct)
        if self.answer_mode == "single" and correct_count != 1:
            raise ValueError("single answer_mode questions require exactly one correct option")
        if self.answer_mode == "multiple" and correct_count < 1:
            raise ValueError("multiple answer_mode questions require at least one correct option")
        return self


class CourseLessonTheoryImageCreate(BaseModel):
    url: str = Field(min_length=1)
    sort_order: int = Field(ge=1)


class CourseLessonCreate(BaseModel):
    title: str = Field(min_length=1, max_length=160)
    summary: str = Field(min_length=1)
    theory: str = Field(min_length=1)
    required_approval_percent: int = Field(default=80, ge=1, le=100)
    sort_order: int = Field(ge=1)
    theory_images: list[CourseLessonTheoryImageCreate] = Field(default_factory=list)
    questions: list[TrainingQuestionCreate] = Field(min_length=1)

    @model_validator(mode="after")
    def validate_children(self) -> "CourseLessonCreate":
        if _duplicate_sort_orders(self.questions):
            raise ValueError("question sort_order values must be unique")
        if _duplicate_sort_orders(self.theory_images):
            raise ValueError("theory_image sort_order values must be unique")
        return self


class CourseCreate(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    description: str | None = None
    status: Literal["draft", "active", "archived"] = "active"
    sort_order: int = Field(default=1, ge=1)
    active: bool = True
    stores: list[str] = Field(min_length=1)
    lessons: list[CourseLessonCreate] = Field(min_length=1)

    @model_validator(mode="after")
    def validate_children(self) -> "CourseCreate":
        if len(self.stores) != len(set(self.stores)):
            raise ValueError("stores values must be unique")
        if _duplicate_sort_orders(self.lessons):
            raise ValueError("lesson sort_order values must be unique")
        return self


class CourseActiveUpdate(BaseModel):
    is_active: bool


class TrainingQuestionOptionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    label: str
    media_url: str | None
    option_type: str
    is_correct: bool
    sort_order: int


class TrainingQuestionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    lesson_id: int
    prompt: str
    question_type: str
    answer_mode: str
    image_url: str | None
    sort_order: int
    active: bool
    created_at: datetime
    updated_at: datetime
    options: list[TrainingQuestionOptionRead]


class CourseLessonTheoryImageRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    url: str
    sort_order: int


class CourseLessonRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    course_id: int
    title: str
    summary: str
    theory: str
    required_approval_percent: int
    sort_order: int
    active: bool
    created_at: datetime
    updated_at: datetime
    theory_images: list[CourseLessonTheoryImageRead]
    questions: list[TrainingQuestionRead]


class CourseStoreRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    store_code: str


class CourseRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    description: str | None
    status: str
    sort_order: int
    active: bool
    created_at: datetime
    updated_at: datetime
    stores: list[CourseStoreRead]
    lessons: list[CourseLessonRead]
