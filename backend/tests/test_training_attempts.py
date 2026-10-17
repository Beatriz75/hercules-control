from fastapi.testclient import TestClient

from tests.conftest import post_attempt

from app.core.permissions import Role


def _create_course(client: TestClient, required_approval_percent: int = 80, student: str = "EMP-1") -> dict:
    """Create the course as an administrator, then act as an Ofertas student."""
    client.act_as(Role.ADMINISTRADOR, "admin")
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
                            "explanation": "  Because the first option is the rule.  ",
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
    client.act_as(Role.ALUMNO, student, "Ofertas")
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

    response = post_attempt(
        client,
        {
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

    progress = client.get("/lesson-progress").json()
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

    response = post_attempt(
        client,
        {
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
        "lesson_id": lesson_id,
        "answers": [
            {"question_id": single_question_id, "selected_option_ids": [single_options[0]]},
            {
                "question_id": multiple_question_id,
                "selected_option_ids": [multiple_options[0], multiple_options[1]],
            },
        ],
    }
    post_attempt(client, approved_payload)

    failing_payload = {
        "lesson_id": lesson_id,
        "answers": [
            {"question_id": single_question_id, "selected_option_ids": [single_options[1]]},
            {"question_id": multiple_question_id, "selected_option_ids": [multiple_options[0]]},
        ],
    }
    post_attempt(client, failing_payload)

    progress = client.get("/lesson-progress").json()
    assert progress[0]["practice_approved"] is True
    assert progress[0]["best_score_percent"] == 100


def test_rejects_attempt_missing_a_question(client: TestClient) -> None:
    course = _create_course(client)
    lesson_id = course["lessons"][0]["id"]
    single_question_id, _ = _question_ids(course)
    single_options = _option_ids(course, 0)

    response = post_attempt(
        client,
        {
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

    response = post_attempt(
        client,
        {
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

    response = client.patch(f"/lesson-progress/{lesson_id}/theory-completed")

    assert response.status_code == 200
    body = response.json()
    assert body["theory_completed"] is True
    assert body["practice_approved"] is False


def test_list_lesson_progress_filters_by_course(client: TestClient) -> None:
    course = _create_course(client)
    other_course = _create_course(client)
    lesson_id = course["lessons"][0]["id"]
    other_lesson_id = other_course["lessons"][0]["id"]

    client.patch(f"/lesson-progress/{lesson_id}/theory-completed")
    client.patch(f"/lesson-progress/{other_lesson_id}/theory-completed")

    response = client.get(
        "/lesson-progress",
        params={"course_id": course["id"]},
    )

    assert response.status_code == 200
    body = response.json()
    assert [row["lesson_id"] for row in body] == [lesson_id]


def test_result_shows_correct_options_and_explanation_after_submitting(client: TestClient) -> None:
    course = _create_course(client)
    lesson_id = course["lessons"][0]["id"]
    single_question_id, multiple_question_id = _question_ids(course)
    single_options = _option_ids(course, 0)
    multiple_options = _option_ids(course, 1)
    # Stored trimmed; questions without one return None.
    assert course["lessons"][0]["questions"][0]["explanation"] == "Because the first option is the rule."
    assert course["lessons"][0]["questions"][1]["explanation"] is None

    response = post_attempt(
        client,
        {
            "lesson_id": lesson_id,
            "answers": [
                {"question_id": single_question_id, "selected_option_ids": [single_options[1]]},
                {"question_id": multiple_question_id, "selected_option_ids": [multiple_options[0]]},
            ],
        },
    )

    assert response.status_code == 201
    single, multiple = response.json()["answers"]
    assert single["is_correct"] is False
    assert single["correct_option_ids"] == [single_options[0]]
    assert single["explanation"] == "Because the first option is the rule."
    assert multiple["correct_option_ids"] == [multiple_options[0], multiple_options[1]]
    assert multiple["explanation"] is None

    # The student's own attempt history keeps showing it.
    history = client.get("/training-attempts").json()
    assert history[0]["answers"][0]["explanation"] == "Because the first option is the rule."


def test_explanation_and_correct_answers_are_hidden_before_submitting(client: TestClient) -> None:
    course = _create_course(client)
    lesson_id = course["lessons"][0]["id"]

    started = client.post("/training-attempts/start", json={"lesson_id": lesson_id})
    assert started.status_code == 201
    assigned = client.get("/courses/assigned").json()

    for payload in (started.json(), assigned):
        text = str(payload)
        assert "explanation" not in text
        assert "is_correct" not in text
        assert "correct_option_ids" not in text



def _students_answer(client: TestClient) -> tuple[dict, list[int], list[int]]:
    """emp-1 fails then passes; emp-2 fails both questions. Both are real Ofertas students."""
    client.act_as(Role.ADMINISTRADOR, "admin")
    for username in ("emp-1", "emp-2"):
        created = client.post(
            "/users",
            json={"username": username, "full_name": username, "password": "pass-1234", "role": "alumno", "store_code": "Ofertas"},
        )
        assert created.status_code == 201
    course = _create_course(client, student="emp-1")
    lesson_id = course["lessons"][0]["id"]
    single_id, multiple_id = _question_ids(course)
    single, multiple = _option_ids(course, 0), _option_ids(course, 1)

    def answer(single_option: int, multiple_options: list[int]) -> None:
        response = post_attempt(
            client,
            {
                "lesson_id": lesson_id,
                "answers": [
                    {"question_id": single_id, "selected_option_ids": [single_option]},
                    {"question_id": multiple_id, "selected_option_ids": multiple_options},
                ],
            },
        )
        assert response.status_code == 201

    answer(single[1], [multiple[0], multiple[1]])
    answer(single[0], [multiple[0], multiple[1]])
    client.act_as(Role.ALUMNO, "emp-2", "Ofertas")
    answer(single[1], [multiple[2]])
    return course, [single_id, multiple_id], single


def test_staff_reviews_a_students_attempts_newest_first(client: TestClient) -> None:
    course, (single_id, _), _ = _students_answer(client)

    client.act_as(Role.SUPERVISOR, "sup")
    response = client.get("/training-attempts/review", params={"employee_reference": "emp-1"})
    assert response.status_code == 200
    second, first = response.json()
    assert (second["attempt_number"], second["approved"], second["score_percent"]) == (2, True, 100)
    assert (first["attempt_number"], first["approved"], first["score_percent"]) == (1, False, 50)
    assert first["course_title"] == "Ruta Ofertas"
    assert first["lesson_title"] == "Calentamiento seguro de lineas"
    wrong = first["answers"][0]
    assert wrong["question_id"] == single_id
    assert wrong["prompt"] == "Single choice question"
    assert wrong["is_correct"] is False
    assert wrong["selected_labels"] == ["Incorrect"]
    assert wrong["correct_labels"] == ["Correct"]
    assert first["answers"][1]["correct_labels"] == ["Correct A", "Correct B"]

    other_course = client.get(
        "/training-attempts/review", params={"employee_reference": "emp-1", "course_id": course["id"] + 99}
    )
    assert other_course.json() == []


def test_missed_questions_rank_by_failures_and_filter_by_store(client: TestClient) -> None:
    course, (single_id, multiple_id), _ = _students_answer(client)

    client.act_as(Role.SUPERVISOR, "sup")
    rows = client.get("/training-attempts/missed-questions", params={"course_id": course["id"]}).json()
    assert [(row["question_id"], row["times_answered"], row["times_failed"]) for row in rows] == [
        (single_id, 3, 2),
        (multiple_id, 3, 1),
    ]
    assert round(rows[0]["fail_percent"], 1) == 66.7
    assert rows[0]["course_title"] == "Ruta Ofertas"

    assert client.get("/training-attempts/missed-questions", params={"store_code": "Mexi"}).json() == []


def test_students_cannot_review_attempts_or_missed_questions(client: TestClient) -> None:
    _students_answer(client)

    client.act_as(Role.ALUMNO, "emp-1", "Ofertas")
    assert client.get("/training-attempts/review", params={"employee_reference": "emp-2"}).status_code == 403
    assert client.get("/training-attempts/missed-questions").status_code == 403
