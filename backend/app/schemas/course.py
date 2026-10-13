from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.core.video import validate_video_url


def _duplicate_sort_orders(items: list) -> bool:
    sort_orders = [item.sort_order for item in items]
    return len(sort_orders) != len(set(sort_orders))


class TrainingQuestionOptionCreate(BaseModel):
    id: int | None = None
    label: str = Field(min_length=1, max_length=2000)
    media_url: str | None = None
    option_type: Literal["text", "image"] = "text"
    is_correct: bool = False
    sort_order: int = Field(ge=1)


class TrainingQuestionCreate(BaseModel):
    id: int | None = None
    prompt: str = Field(min_length=1, max_length=4000)
    question_type: Literal["text", "image"] = "text"
    answer_mode: Literal["single", "multiple"] = "single"
    image_url: str | None = None
    video_url: str | None = Field(default=None, max_length=2000)
    sort_order: int = Field(ge=1)
    options: list[TrainingQuestionOptionCreate] = Field(min_length=2)

    @field_validator("video_url")
    @classmethod
    def check_video(cls, value: str | None) -> str | None:
        return validate_video_url(value)

    @model_validator(mode="after")
    def validate_options(self) -> "TrainingQuestionCreate":
        if _duplicate_sort_orders(self.options):
            raise ValueError("El orden de las opciones no puede repetirse.")

        correct_count = sum(1 for option in self.options if option.is_correct)
        if self.answer_mode == "single" and correct_count != 1:
            raise ValueError("Una pregunta de respuesta única debe tener exactamente una opción correcta.")
        if self.answer_mode == "multiple" and correct_count < 1:
            raise ValueError("Una pregunta de respuesta múltiple debe tener al menos una opción correcta.")
        return self


class CourseLessonTheoryImageCreate(BaseModel):
    url: str = Field(min_length=1)
    sort_order: int = Field(ge=1)


class CourseLessonTheoryVideoCreate(BaseModel):
    url: str = Field(min_length=1, max_length=2000)
    title: str | None = Field(default=None, max_length=160)
    sort_order: int = Field(ge=1)

    @field_validator("url")
    @classmethod
    def check_video(cls, value: str) -> str:
        return validate_video_url(value) or value


class CourseLessonCreate(BaseModel):
    id: int | None = None
    title: str = Field(min_length=1, max_length=160)
    summary: str = Field(min_length=1)
    theory: str = Field(min_length=1)
    required_approval_percent: int = Field(default=80, ge=1, le=100)
    questions_per_attempt: int | None = Field(default=None, ge=1)
    sort_order: int = Field(ge=1)
    theory_images: list[CourseLessonTheoryImageCreate] = Field(default_factory=list)
    theory_videos: list[CourseLessonTheoryVideoCreate] = Field(default_factory=list)
    questions: list[TrainingQuestionCreate] = Field(min_length=1)

    @model_validator(mode="after")
    def validate_children(self) -> "CourseLessonCreate":
        if _duplicate_sort_orders(self.questions):
            raise ValueError("El orden de las preguntas no puede repetirse.")
        if _duplicate_sort_orders(self.theory_images):
            raise ValueError("El orden de las imágenes no puede repetirse.")
        if _duplicate_sort_orders(self.theory_videos):
            raise ValueError("El orden de los videos no puede repetirse.")
        if self.questions_per_attempt is not None and self.questions_per_attempt > len(self.questions):
            raise ValueError(
                f"La lección \"{self.title}\" pide {self.questions_per_attempt} preguntas por práctica "
                f"pero su banco tiene {len(self.questions)}."
            )
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
            raise ValueError("Una tienda está repetida.")
        if _duplicate_sort_orders(self.lessons):
            raise ValueError("El orden de las lecciones no puede repetirse.")
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
    video_url: str | None
    sort_order: int
    active: bool
    created_at: datetime
    updated_at: datetime
    options: list[TrainingQuestionOptionRead]


class CourseLessonTheoryVideoRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    url: str
    title: str | None
    sort_order: int


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
    questions_per_attempt: int | None
    sort_order: int
    active: bool
    created_at: datetime
    updated_at: datetime
    theory_images: list[CourseLessonTheoryImageRead]
    theory_videos: list[CourseLessonTheoryVideoRead]
    questions: list[TrainingQuestionRead]

    @field_validator("questions")
    @classmethod
    def hide_inactive_questions(cls, questions: list[TrainingQuestionRead]) -> list[TrainingQuestionRead]:
        return [question for question in questions if question.active]


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

    @field_validator("lessons")
    @classmethod
    def hide_inactive_lessons(cls, lessons: list[CourseLessonRead]) -> list[CourseLessonRead]:
        return [lesson for lesson in lessons if lesson.active]


# Student-facing views: same content without the correct answers.
class StudentQuestionOptionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    label: str
    media_url: str | None
    option_type: str
    sort_order: int


class StudentQuestionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    prompt: str
    question_type: str
    answer_mode: str
    image_url: str | None
    video_url: str | None
    sort_order: int
    options: list[StudentQuestionOptionRead]


class StudentLessonRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    course_id: int
    title: str
    summary: str
    theory: str
    required_approval_percent: int
    sort_order: int
    theory_images: list[CourseLessonTheoryImageRead]
    theory_videos: list[CourseLessonTheoryVideoRead]
    question_bank_size: int
    questions_per_attempt: int


class StudentCourseRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    description: str | None
    sort_order: int
    stores: list[CourseStoreRead]
    lessons: list[StudentLessonRead]


class CourseProgressRow(BaseModel):
    username: str
    full_name: str
    store_code: str | None
    course_id: int
    course_title: str
    lessons_total: int
    lessons_completed: int
    last_activity: datetime | None


class PracticeStart(BaseModel):
    lesson_id: int


class PracticeSessionRead(BaseModel):
    session_id: int
    lesson_id: int
    required_approval_percent: int
    questions: list[StudentQuestionRead]


class QuestionUpdate(TrainingQuestionCreate):
    """Body to edit one question from the general bank; sort_order is kept from the stored question."""

    sort_order: int = Field(default=1, ge=1)


class QuestionBankRow(BaseModel):
    id: int
    prompt: str
    question_type: str
    answer_mode: str
    image_url: str | None
    video_url: str | None
    sort_order: int
    options: list[TrainingQuestionOptionRead]
    lesson_id: int
    lesson_title: str
    lesson_sort_order: int
    course_id: int
    course_title: str
    course_status: str
    course_active: bool
    stores: list[str]


class QuestionCreate(QuestionUpdate):
    """Body to add a question to a lesson's bank from the general bank view."""

    lesson_id: int
