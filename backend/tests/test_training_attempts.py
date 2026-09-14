from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db.base import Base
from app.db.session import get_db
from app.main import create_app
import app.models  # noqa: F401


@pytest.fixture()
def client() -> Generator[TestClient, None, None]:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)

    def override_get_db() -> Generator[Session, None, None]:
        with Session(engine) as session:
            yield session

    app = create_app()
    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as test_client:
        yield test_client


def _create_course(client: TestClient, required_approval_percent: int = 80) -> dict:
    response = client.post(
        "/courses",
        json={
            "title": "Ruta Ofertas",
            "stores": ["Ofertas"],
            "lessons": [
                {
                    "title": "Calentamiento seguro de lineas",
                    "summary": "Summary",
                    "theory": "Theory text",
                    "required_approval_percent": required_approval_percent,
                    "sort_order": 1,
                    "questions": [
                        {
                            "prompt": "Single choice question",
                            "sort_order": 1,
                            "options": [
                                {"label": "Correct", "is_correct": True, "sort_order": 1},
                                {"label": "Incorrect", "is_correct": False, "sort_order": 2},
                            ],
                        },
                        {
                            "prompt": "Multiple choice question",
                            "answer_mode": "multiple",
                            "sort_order": 2,
                            "options": [
                                {"label": "Correct A", "is_correct": True, "sort_order": 1},
                                {"label": "Correct B", "is_correct": True, "sort_order": 2},
                                {"label": "Incorrect", "is_correct": False, "sort_order": 3},
                            ],
                        },
                    ],
                }
            ],
        },
    )
    assert response.status_code == 201
    return response.json()


def _question_ids(course: dict) -> tuple[int, int]:
    questions = course["lessons"][0]["questions"]
    return questions[0]["id"], questions[1]["id"]


def _option_ids(course: dict, question_index: int) -> list[int]:
    return [option["id"] for option in course["lessons"][0]["questions"][question_index]["options"]]


def test_fully_correct_attempt_is_approved_and_updates_progress(client: TestClient) -> None:
    course = _create_course(client)
    lesson_id = course["lessons"][0]["id"]
    single_question_id, multiple_question_id = _question_ids(course)
    single_options = _option_ids(course, 0)
    multiple_options = _option_ids(course, 1)

    response = client.post(
        "/training-attempts",
        json={
            "employee_reference": "EMP-1",
            "lesson_id": lesson_id,
            "answers": [
                {"question_id": single_question_id, "selected_option_ids": [single_options[0]]},
                {
                    "question_id": multiple_question_id,
                    "selected_option_ids": [multiple_options[0], multiple_options[1]],
                },
            ],
        },
    )

    assert response.status_code == 201
    body = response.json()
    assert body["score_percent"] == 100
    assert body["approved"] is True
    assert body["required_approval_percent"] == 80

    progress = client.get("/lesson-progress", params={"employee_reference": "EMP-1"}).json()
    assert len(progress) == 1
    assert progress[0]["practice_approved"] is True
    assert progress[0]["best_score_percent"] == 100
    assert progress[0]["completed_at"] is not None


def test_multiple_choice_requires_exact_set_to_be_correct(client: TestClient) -> None:
    course = _create_course(client)
    lesson_id = course["lessons"][0]["id"]
    single_question_id, multiple_question_id = _question_ids(course)
    single_options = _option_ids(course, 0)
    multiple_options = _option_ids(course, 1)

    response = client.post(
        "/training-attempts",
        json={
            "employee_reference": "EMP-1",
            "lesson_id": lesson_id,
            "answers": [
                {"question_id": single_question_id, "selected_option_ids": [single_options[0]]},
                # Only one of the two correct options selected -> not correct.
                {"question_id": multiple_question_id, "selected_option_ids": [multiple_options[0]]},
            ],
        },
    )

    assert response.status_code == 201
    body = response.json()
    assert body["score_percent"] == 50
    assert body["approved"] is False
    assert body["answers"][1]["is_correct"] is False


def test_approval_is_sticky_across_failed_reattempts(client: TestClient) -> None:
    course = _create_course(client)
    lesson_id = course["lessons"][0]["id"]
    single_question_id, multiple_question_id = _question_ids(course)
    single_options = _option_ids(course, 0)
    multiple_options = _option_ids(course, 1)

    approved_payload = {
        "employee_reference": "EMP-1",
        "lesson_id": lesson_id,
        "answers": [
            {"question_id": single_question_id, "selected_option_ids": [single_options[0]]},
            {
                "question_id": multiple_question_id,
                "selected_option_ids": [multiple_options[0], multiple_options[1]],
            },
        ],
    }
    client.post("/training-attempts", json=approved_payload)

    failing_payload = {
        "employee_reference": "EMP-1",
        "lesson_id": lesson_id,
        "answers": [
            {"question_id": single_question_id, "selected_option_ids": [single_options[1]]},
            {"question_id": multiple_question_id, "selected_option_ids": [multiple_options[0]]},
        ],
    }
    client.post("/training-attempts", json=failing_payload)

    progress = client.get("/lesson-progress", params={"employee_reference": "EMP-1"}).json()
    assert progress[0]["practice_approved"] is True
    assert progress[0]["best_score_percent"] == 100


def test_rejects_attempt_missing_a_question(client: TestClient) -> None:
    course = _create_course(client)
    lesson_id = course["lessons"][0]["id"]
    single_question_id, _ = _question_ids(course)
    single_options = _option_ids(course, 0)

    response = client.post(
        "/training-attempts",
        json={
            "employee_reference": "EMP-1",
            "lesson_id": lesson_id,
            "answers": [{"question_id": single_question_id, "selected_option_ids": [single_options[0]]}],
        },
    )

    assert response.status_code == 400


def test_rejects_option_not_belonging_to_question(client: TestClient) -> None:
    course = _create_course(client)
    lesson_id = course["lessons"][0]["id"]
    single_question_id, multiple_question_id = _question_ids(course)
    multiple_options = _option_ids(course, 1)

    response = client.post(
        "/training-attempts",
        json={
            "employee_reference": "EMP-1",
            "lesson_id": lesson_id,
            "answers": [
                # multiple_options belong to the other question.
                {"question_id": single_question_id, "selected_option_ids": [multiple_options[0]]},
                {
                    "question_id": multiple_question_id,
                    "selected_option_ids": [multiple_options[0], multiple_options[1]],
                },
            ],
        },
    )

    assert response.status_code == 400


def test_mark_theory_completed_does_not_affect_practice_approved(client: TestClient) -> None:
    course = _create_course(client)
    lesson_id = course["lessons"][0]["id"]

    response = client.patch(
        f"/lesson-progress/{lesson_id}/theory-completed",
        json={"employee_reference": "EMP-2"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["theory_completed"] is True
    assert body["practice_approved"] is False


def test_list_lesson_progress_filters_by_course(client: TestClient) -> None:
    course = _create_course(client)
    other_course = _create_course(client)
    lesson_id = course["lessons"][0]["id"]
    other_lesson_id = other_course["lessons"][0]["id"]

    client.patch(f"/lesson-progress/{lesson_id}/theory-completed", json={"employee_reference": "EMP-3"})
    client.patch(f"/lesson-progress/{other_lesson_id}/theory-completed", json={"employee_reference": "EMP-3"})

    response = client.get(
        "/lesson-progress",
        params={"employee_reference": "EMP-3", "course_id": course["id"]},
    )

    assert response.status_code == 200
    body = response.json()
    assert [row["lesson_id"] for row in body] == [lesson_id]
