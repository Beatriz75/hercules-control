from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.api.deps import require_permission
from app.core.permissions import Permission, Role
from app.db.session import get_db
from app.models.course import (
    Course,
    CourseLesson,
    CourseLessonTheoryImage,
    CourseLessonTheoryVideo,
    CourseStore,
    TrainingQuestion,
    TrainingQuestionOption,
)
from app.models.training_attempt import LessonProgress, TrainingAnswerOption
from app.models.user import User
from app.schemas.course import (
    CourseActiveUpdate,
    CourseCreate,
    CourseLessonCreate,
    CourseProgressRow,
    CourseRead,
    StudentCourseRead,
    StudentLessonRead,
    TrainingQuestionCreate,
)

router = APIRouter(prefix="/courses", tags=["courses"])

CourseManager = Annotated[User, Depends(require_permission(Permission.COURSES_MANAGE))]
CourseViewer = Annotated[User, Depends(require_permission(Permission.COURSES_VIEW))]
CourseStudent = Annotated[User, Depends(require_permission(Permission.COURSES_TAKE))]
ProgressViewer = Annotated[User, Depends(require_permission(Permission.COURSES_PROGRESS_VIEW))]

_COURSE_LOAD_OPTIONS = (
    selectinload(Course.stores),
    selectinload(Course.lessons).selectinload(CourseLesson.theory_images),
    selectinload(Course.lessons).selectinload(CourseLesson.theory_videos),
    selectinload(Course.lessons).selectinload(CourseLesson.questions).selectinload(TrainingQuestion.options),
)


def _get_course_or_404(db: Session, course_id: int) -> Course:
    course = db.scalar(select(Course).options(*_COURSE_LOAD_OPTIONS).where(Course.id == course_id))
    if course is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No se encontró el curso.")
    return course


def _build_lessons(payload: CourseCreate) -> list[CourseLesson]:
    return [
        CourseLesson(
            title=lesson.title,
            summary=lesson.summary,
            theory=lesson.theory,
            required_approval_percent=lesson.required_approval_percent,
            questions_per_attempt=lesson.questions_per_attempt,
            sort_order=lesson.sort_order,
            active=True,
            theory_images=[
                CourseLessonTheoryImage(url=image.url, sort_order=image.sort_order)
                for image in lesson.theory_images
            ],
            theory_videos=[
                CourseLessonTheoryVideo(url=video.url, title=video.title, sort_order=video.sort_order)
                for video in lesson.theory_videos
            ],
            questions=[
                TrainingQuestion(
                    prompt=question.prompt,
                    question_type=question.question_type,
                    answer_mode=question.answer_mode,
                    image_url=question.image_url,
                    video_url=question.video_url,
                    sort_order=question.sort_order,
                    active=True,
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
def create_course(payload: CourseCreate, _: CourseManager, db: Session = Depends(get_db)) -> Course:
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


def assigned_courses_query(store_code: str | None):
    """Courses a student of the given store can take: active, published and assigned to the store."""
    return (
        select(Course)
        .join(CourseStore, CourseStore.course_id == Course.id)
        .where(Course.active.is_(True), Course.status == "active", CourseStore.store_code == store_code)
    )


def practice_size(questions_per_attempt: int | None, bank_size: int) -> int:
    return bank_size if questions_per_attempt is None else min(questions_per_attempt, bank_size)


def ensure_student_can_access_lesson(db: Session, student: User, lesson: CourseLesson) -> None:
    course_id = db.scalar(assigned_courses_query(student.store_code).where(Course.id == lesson.course_id).with_only_columns(Course.id))
    if course_id is None or not lesson.active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No se encontró la lección o no está asignada a tu tienda.")

    # Lessons unlock in order: every earlier active lesson needs theory read and practice approved.
    previous_ids = set(
        db.scalars(
            select(CourseLesson.id).where(
                CourseLesson.course_id == lesson.course_id,
                CourseLesson.active.is_(True),
                CourseLesson.sort_order < lesson.sort_order,
            )
        )
    )
    if previous_ids:
        completed_ids = set(
            db.scalars(
                select(LessonProgress.lesson_id).where(
                    LessonProgress.employee_reference == student.username,
                    LessonProgress.lesson_id.in_(previous_ids),
                    LessonProgress.theory_completed.is_(True),
                    LessonProgress.practice_approved.is_(True),
                )
            )
        )
        if completed_ids != previous_ids:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Completa la lección anterior (teoría y práctica) antes de continuar.")


@router.get("/assigned", response_model=list[StudentCourseRead])
def list_assigned_courses(student: CourseStudent, db: Session = Depends(get_db)) -> list[StudentCourseRead]:
    courses = db.scalars(
        assigned_courses_query(student.store_code).options(*_COURSE_LOAD_OPTIONS).order_by(Course.sort_order, Course.id)
    ).unique()
    result: list[StudentCourseRead] = []
    for course in courses:
        lessons = []
        for lesson in course.lessons:
            if not lesson.active:
                continue
            bank_size = sum(1 for question in lesson.questions if question.active)
            lessons.append(
                StudentLessonRead(
                    id=lesson.id,
                    course_id=lesson.course_id,
                    title=lesson.title,
                    summary=lesson.summary,
                    theory=lesson.theory,
                    required_approval_percent=lesson.required_approval_percent,
                    sort_order=lesson.sort_order,
                    theory_images=lesson.theory_images,
                    theory_videos=lesson.theory_videos,
                    question_bank_size=bank_size,
                    questions_per_attempt=practice_size(lesson.questions_per_attempt, bank_size),
                )
            )
        result.append(
            StudentCourseRead(
                id=course.id,
                title=course.title,
                description=course.description,
                sort_order=course.sort_order,
                stores=course.stores,
                lessons=lessons,
            )
        )
    return result


@router.get("", response_model=list[CourseRead])
def list_courses(_: CourseViewer, db: Session = Depends(get_db)) -> list[Course]:
    return list(
        db.scalars(
            select(Course).options(*_COURSE_LOAD_OPTIONS).order_by(Course.sort_order, Course.id)
        )
    )


_RETIRED_SORT_OFFSET = 1_000_000


def _retire(item: CourseLesson | TrainingQuestion) -> None:
    """Hide a removed lesson/question instead of deleting it, so progress and answers keep their history."""
    item.active = False
    item.sort_order = _RETIRED_SORT_OFFSET + item.id


def _check_ids(kind: str, payload_ids: list[int | None], existing_ids: set[int]) -> None:
    sent = [item_id for item_id in payload_ids if item_id is not None]
    unknown = [item_id for item_id in sent if item_id not in existing_ids]
    if unknown or len(sent) != len(set(sent)):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"El curso cambió mientras lo editabas ({kind}: {unknown or sent}). Recarga e intenta de nuevo.")


def _referenced_option_ids(db: Session, option_ids: set[int]) -> set[int]:
    if not option_ids:
        return set()
    return set(db.scalars(select(TrainingAnswerOption.option_id).where(TrainingAnswerOption.option_id.in_(option_ids))))


def _new_question(payload: TrainingQuestionCreate) -> TrainingQuestion:
    return TrainingQuestion(
        prompt=payload.prompt,
        question_type=payload.question_type,
        answer_mode=payload.answer_mode,
        image_url=payload.image_url,
        video_url=payload.video_url,
        sort_order=payload.sort_order,
        active=True,
        options=[
            TrainingQuestionOption(
                label=option.label,
                media_url=option.media_url,
                option_type=option.option_type,
                is_correct=option.is_correct,
                sort_order=option.sort_order,
            )
            for option in payload.options
        ],
    )


def _apply_question(
    db: Session, lesson: CourseLesson, question: TrainingQuestion, payload: TrainingQuestionCreate
) -> None:
    existing_options = {option.id: option for option in question.options}
    _check_ids("option", [option.id for option in payload.options], set(existing_options))
    kept_ids = {option.id for option in payload.options if option.id is not None}
    removed_ids = set(existing_options) - kept_ids

    if _referenced_option_ids(db, removed_ids):
        # Someone already answered with an option being removed: keep the old question for history.
        _retire(question)
        db.flush()
        lesson.questions.append(_new_question(payload))
        return

    question.prompt = payload.prompt
    question.question_type = payload.question_type
    question.answer_mode = payload.answer_mode
    question.image_url = payload.image_url
    question.video_url = payload.video_url
    question.active = True
    for option_id in removed_ids:
        question.options.remove(existing_options[option_id])
    for option in question.options:
        option.sort_order = -option.id
    db.flush()

    for option_payload in payload.options:
        option = existing_options.get(option_payload.id) if option_payload.id is not None else None
        if option is None:
            option = TrainingQuestionOption()
            question.options.append(option)
        option.label = option_payload.label
        option.media_url = option_payload.media_url
        option.option_type = option_payload.option_type
        option.is_correct = option_payload.is_correct
        option.sort_order = option_payload.sort_order
    question.sort_order = payload.sort_order


def _apply_lesson(db: Session, lesson: CourseLesson, payload: CourseLessonCreate) -> None:
    lesson.title = payload.title
    lesson.summary = payload.summary
    lesson.theory = payload.theory
    lesson.required_approval_percent = payload.required_approval_percent
    lesson.questions_per_attempt = payload.questions_per_attempt
    lesson.active = True
    lesson.theory_images = [
        CourseLessonTheoryImage(url=image.url, sort_order=image.sort_order) for image in payload.theory_images
    ]
    lesson.theory_videos = [
        CourseLessonTheoryVideo(url=video.url, title=video.title, sort_order=video.sort_order)
        for video in payload.theory_videos
    ]

    existing_questions = {question.id: question for question in lesson.questions}
    _check_ids("question", [question.id for question in payload.questions], set(existing_questions))
    kept_ids = {question.id for question in payload.questions if question.id is not None}
    for question_id, question in existing_questions.items():
        if question_id in kept_ids:
            question.sort_order = -question.id
        elif question.active:
            _retire(question)
    db.flush()

    for question_payload in payload.questions:
        if question_payload.id is None:
            lesson.questions.append(_new_question(question_payload))
        else:
            _apply_question(db, lesson, existing_questions[question_payload.id], question_payload)


@router.put("/{course_id}", response_model=CourseRead)
def replace_course(course_id: int, payload: CourseCreate, _: CourseManager, db: Session = Depends(get_db)) -> Course:
    """Update a course in place.

    Lessons, questions and options sent with an `id` are updated; ones without `id` are created; existing ones
    left out are retired (hidden) rather than deleted, so student progress and past answers survive edits.
    """
    course = _get_course_or_404(db, course_id)
    course.title = payload.title
    course.description = payload.description
    course.status = payload.status
    course.sort_order = payload.sort_order
    course.active = payload.active

    course.stores = []
    db.flush()
    course.stores = [CourseStore(store_code=store_code) for store_code in payload.stores]

    existing_lessons = {lesson.id: lesson for lesson in course.lessons}
    _check_ids("lesson", [lesson.id for lesson in payload.lessons], set(existing_lessons))
    kept_ids = {lesson.id for lesson in payload.lessons if lesson.id is not None}
    for lesson_id, lesson in existing_lessons.items():
        if lesson_id in kept_ids:
            lesson.sort_order = -lesson.id
        elif lesson.active:
            _retire(lesson)
    db.flush()

    new_lessons = [lesson for lesson in payload.lessons if lesson.id is None]
    for lesson_payload in payload.lessons:
        if lesson_payload.id is not None:
            lesson = existing_lessons[lesson_payload.id]
            _apply_lesson(db, lesson, lesson_payload)
            lesson.sort_order = lesson_payload.sort_order
    course.lessons.extend(_build_lessons(payload.model_copy(update={"lessons": new_lessons})))

    db.commit()
    db.expire_all()
    return _get_course_or_404(db, course.id)


@router.get("/progress", response_model=list[CourseProgressRow])
def course_progress_summary(_: ProgressViewer, db: Session = Depends(get_db)) -> list[CourseProgressRow]:
    """One row per (student, course assigned to the student's store) with completed lessons."""
    courses = list(
        db.scalars(
            select(Course)
            .options(selectinload(Course.stores), selectinload(Course.lessons))
            .where(Course.active.is_(True), Course.status == "active")
            .order_by(Course.sort_order, Course.id)
        )
    )
    students = list(
        db.scalars(select(User).where(User.role == Role.ALUMNO, User.active.is_(True)).order_by(User.full_name))
    )
    progress_rows = db.scalars(
        select(LessonProgress).where(LessonProgress.employee_reference.in_([student.username for student in students]))
    )
    progress = {(row.employee_reference, row.lesson_id): row for row in progress_rows}

    result: list[CourseProgressRow] = []
    for student in students:
        for course in courses:
            if student.store_code not in {store.store_code for store in course.stores}:
                continue
            lessons = [lesson for lesson in course.lessons if lesson.active]
            rows = [progress.get((student.username, lesson.id)) for lesson in lessons]
            completed = sum(1 for row in rows if row is not None and row.theory_completed and row.practice_approved)
            activity = [row.updated_at for row in rows if row is not None]
            result.append(
                CourseProgressRow(
                    username=student.username,
                    full_name=student.full_name,
                    store_code=student.store_code,
                    course_id=course.id,
                    course_title=course.title,
                    lessons_total=len(lessons),
                    lessons_completed=completed,
                    last_activity=max(activity) if activity else None,
                )
            )
    return result


@router.get("/{course_id}", response_model=CourseRead)
def get_course(course_id: int, _: CourseViewer, db: Session = Depends(get_db)) -> Course:
    return _get_course_or_404(db, course_id)


@router.patch("/{course_id}/active", response_model=CourseRead)
def update_course_active(
    course_id: int,
    payload: CourseActiveUpdate,
    _: CourseManager,
    db: Session = Depends(get_db),
) -> Course:
    course = _get_course_or_404(db, course_id)
    course.active = payload.is_active
    db.commit()
    db.refresh(course)
    return _get_course_or_404(db, course.id)
