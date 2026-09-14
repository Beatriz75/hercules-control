from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.db.session import get_db
from app.models.course import (
    Course,
    CourseLesson,
    CourseLessonTheoryImage,
    CourseStore,
    TrainingQuestion,
    TrainingQuestionOption,
)
from app.schemas.course import CourseActiveUpdate, CourseCreate, CourseRead

router = APIRouter(prefix="/courses", tags=["courses"])

_COURSE_LOAD_OPTIONS = (
    selectinload(Course.stores),
    selectinload(Course.lessons).selectinload(CourseLesson.theory_images),
    selectinload(Course.lessons).selectinload(CourseLesson.questions).selectinload(TrainingQuestion.options),
)


def _get_course_or_404(db: Session, course_id: int) -> Course:
    course = db.scalar(select(Course).options(*_COURSE_LOAD_OPTIONS).where(Course.id == course_id))
    if course is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Course not found")
    return course


def _build_lessons(payload: CourseCreate) -> list[CourseLesson]:
    return [
        CourseLesson(
            title=lesson.title,
            summary=lesson.summary,
            theory=lesson.theory,
            required_approval_percent=lesson.required_approval_percent,
            sort_order=lesson.sort_order,
            theory_images=[
                CourseLessonTheoryImage(url=image.url, sort_order=image.sort_order)
                for image in lesson.theory_images
            ],
            questions=[
                TrainingQuestion(
                    prompt=question.prompt,
                    question_type=question.question_type,
                    answer_mode=question.answer_mode,
                    image_url=question.image_url,
                    sort_order=question.sort_order,
                    options=[
                        TrainingQuestionOption(
                            label=option.label,
                            media_url=option.media_url,
                            option_type=option.option_type,
                            is_correct=option.is_correct,
                            sort_order=option.sort_order,
                        )
                        for option in question.options
                    ],
                )
                for question in lesson.questions
            ],
        )
        for lesson in payload.lessons
    ]


@router.post("", response_model=CourseRead, status_code=status.HTTP_201_CREATED)
def create_course(payload: CourseCreate, db: Session = Depends(get_db)) -> Course:
    course = Course(
        title=payload.title,
        description=payload.description,
        status=payload.status,
        sort_order=payload.sort_order,
        active=payload.active,
        stores=[CourseStore(store_code=store_code) for store_code in payload.stores],
        lessons=_build_lessons(payload),
    )
    db.add(course)
    db.commit()
    db.refresh(course)
    return _get_course_or_404(db, course.id)


@router.get("", response_model=list[CourseRead])
def list_courses(db: Session = Depends(get_db)) -> list[Course]:
    return list(
        db.scalars(
            select(Course).options(*_COURSE_LOAD_OPTIONS).order_by(Course.sort_order, Course.id)
        )
    )


@router.get("/{course_id}", response_model=CourseRead)
def get_course(course_id: int, db: Session = Depends(get_db)) -> Course:
    return _get_course_or_404(db, course_id)


@router.put("/{course_id}", response_model=CourseRead)
def replace_course(course_id: int, payload: CourseCreate, db: Session = Depends(get_db)) -> Course:
    course = _get_course_or_404(db, course_id)
    course.title = payload.title
    course.description = payload.description
    course.status = payload.status
    course.sort_order = payload.sort_order
    course.active = payload.active

    # Clear children first so the unique (parent_id, sort_order) constraints don't
    # collide with the replacement rows reusing the same sort_order values.
    course.stores = []
    course.lessons = []
    db.flush()

    course.stores = [CourseStore(store_code=store_code) for store_code in payload.stores]
    course.lessons = _build_lessons(payload)
    db.commit()
    db.refresh(course)
    return _get_course_or_404(db, course.id)


@router.patch("/{course_id}/active", response_model=CourseRead)
def update_course_active(
    course_id: int,
    payload: CourseActiveUpdate,
    db: Session = Depends(get_db),
) -> Course:
    course = _get_course_or_404(db, course_id)
    course.active = payload.is_active
    db.commit()
    db.refresh(course)
    return _get_course_or_404(db, course.id)
