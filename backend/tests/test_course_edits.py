from fastapi.testclient import TestClient

from tests.conftest import post_attempt

from app.core.permissions import Role


def _lesson(title: str, sort_order: int, prompt: str = "Pregunta") -> dict:
    return {
        "title": title,
        "summary": "Summary",
        "theory": "Theory",
        "sort_order": sort_order,
        "questions": [
            {
                "prompt": prompt,
                "sort_order": 1,
                "options": [
                    {"label": "Bien", "is_correct": True, "sort_order": 1},
                    {"label": "Mal", "is_correct": False, "sort_order": 2},
                ],
            }
        ],
    }


def _create(client: TestClient) -> dict:
    client.act_as(Role.ADMINISTRADOR, "admin")
    response = client.post(
        "/courses",
        json={"title": "Ruta", "stores": ["Ofertas"], "lessons": [_lesson("L1", 1), _lesson("L2", 2)]},
    )
    assert response.status_code == 201
    return response.json()


def _as_payload(course: dict) -> dict:
    """Turn a CourseRead into the PUT payload the editor sends back (keeps ids)."""
    return {
        "title": course["title"],
        "description": course["description"],
        "status": course["status"],
        "sort_order": course["sort_order"],
        "active": course["active"],
        "stores": [store["store_code"] for store in course["stores"]],
        "lessons": [
            {
                "id": lesson["id"],
                "title": lesson["title"],
                "summary": lesson["summary"],
                "theory": lesson["theory"],
                "required_approval_percent": lesson["required_approval_percent"],
                "sort_order": lesson["sort_order"],
                "theory_images": [{"url": i["url"], "sort_order": i["sort_order"]} for i in lesson["theory_images"]],
                "questions": [
                    {
                        "id": question["id"],
                        "prompt": question["prompt"],
                        "answer_mode": question["answer_mode"],
                        "sort_order": question["sort_order"],
                        "options": [
                            {
                                "id": option["id"],
                                "label": option["label"],
                                "is_correct": option["is_correct"],
                                "sort_order": option["sort_order"],
                            }
                            for option in question["options"]
                        ],
                    }
                    for question in lesson["questions"]
                ],
            }
            for lesson in course["lessons"]
        ],
    }


def _answer_first_lesson(client: TestClient, course: dict, student: str = "cobrador1") -> None:
    lesson = course["lessons"][0]
    question = lesson["questions"][0]
    client.act_as(Role.ALUMNO, student, "Ofertas")
    client.patch(f"/lesson-progress/{lesson['id']}/theory-completed")
    response = post_attempt(
        client,
        {
            "lesson_id": lesson["id"],
            "answers": [{"question_id": question["id"], "selected_option_ids": [question["options"][0]["id"]]}],
        },
    )
    assert response.status_code == 201
    client.act_as(Role.ADMINISTRADOR, "admin")


def test_editing_a_course_keeps_ids_and_student_progress(client: TestClient) -> None:
    course = _create(client)
    _answer_first_lesson(client, course)

    payload = _as_payload(course)
    payload["lessons"][0]["title"] = "L1 corregida"
    payload["lessons"][0]["questions"][0]["options"][1]["label"] = "Mal (editada)"
    response = client.put(f"/courses/{course['id']}", json=payload)

    assert response.status_code == 200
    updated = response.json()
    assert [lesson["id"] for lesson in updated["lessons"]] == [lesson["id"] for lesson in course["lessons"]]
    assert updated["lessons"][0]["title"] == "L1 corregida"
    assert updated["lessons"][0]["questions"][0]["options"][1]["label"] == "Mal (editada)"

    client.act_as(Role.ALUMNO, "cobrador1", "Ofertas")
    progress = client.get("/lesson-progress").json()
    assert progress[0]["lesson_id"] == course["lessons"][0]["id"]
    assert progress[0]["practice_approved"] is True


def test_lessons_can_swap_order(client: TestClient) -> None:
    course = _create(client)
    payload = _as_payload(course)
    payload["lessons"][0]["sort_order"], payload["lessons"][1]["sort_order"] = 2, 1

    response = client.put(f"/courses/{course['id']}", json=payload)

    assert response.status_code == 200
    assert [lesson["title"] for lesson in response.json()["lessons"]] == ["L2", "L1"]


def test_removed_lesson_is_hidden_and_new_lesson_added(client: TestClient) -> None:
    course = _create(client)
    _answer_first_lesson(client, course)
    payload = _as_payload(course)
    payload["lessons"] = [payload["lessons"][1] | {"sort_order": 1}, _lesson("L3", 2)]

    response = client.put(f"/courses/{course['id']}", json=payload)

    assert response.status_code == 200
    assert [lesson["title"] for lesson in response.json()["lessons"]] == ["L2", "L3"]

    client.act_as(Role.ALUMNO, "cobrador1", "Ofertas")
    assigned = client.get("/courses/assigned").json()
    assert [lesson["title"] for lesson in assigned[0]["lessons"]] == ["L2", "L3"]
    # History of the removed lesson is still there.
    assert len(client.get("/training-attempts").json()) == 1


def test_removing_an_answered_option_replaces_the_question(client: TestClient) -> None:
    course = _create(client)
    _answer_first_lesson(client, course)
    old_question = course["lessons"][0]["questions"][0]

    payload = _as_payload(course)
    question = payload["lessons"][0]["questions"][0]
    question["options"] = [
        {"label": "Nueva correcta", "is_correct": True, "sort_order": 1},
        question["options"][1],
    ]
    response = client.put(f"/courses/{course['id']}", json=payload)

    assert response.status_code == 200
    new_question = response.json()["lessons"][0]["questions"][0]
    assert new_question["id"] != old_question["id"]
    assert [option["label"] for option in new_question["options"]] == ["Nueva correcta", "Mal"]

    client.act_as(Role.ALUMNO, "cobrador1", "Ofertas")
    attempts = client.get("/training-attempts").json()
    assert attempts[0]["answers"][0]["question_id"] == old_question["id"]


def test_rejects_ids_from_another_course(client: TestClient) -> None:
    course = _create(client)
    other = _create(client)
    payload = _as_payload(course)
    payload["lessons"][0]["id"] = other["lessons"][0]["id"]

    assert client.put(f"/courses/{course['id']}", json=payload).status_code == 400


def test_progress_summary_for_supervisors(client: TestClient) -> None:
    course = _create(client)
    for username, store in (("cobrador1", "Ofertas"), ("cobrador2", "Ofertas"), ("cobrador3", "Mexi")):
        client.post(
            "/users",
            json={"username": username, "full_name": username.title(), "password": "pass-1234", "role": "alumno", "store_code": store},
        )
    _answer_first_lesson(client, course, "cobrador1")

    client.act_as(Role.SUPERVISOR, "sup")
    response = client.get("/courses/progress")
    assert response.status_code == 200
    rows = {row["username"]: row for row in response.json()}
    assert set(rows) == {"cobrador1", "cobrador2"}  # cobrador3 is Mexi, course is Ofertas only
    assert rows["cobrador1"]["lessons_completed"] == 1
    assert rows["cobrador1"]["lessons_total"] == 2
    assert rows["cobrador2"]["lessons_completed"] == 0
    assert rows["cobrador2"]["last_activity"] is None

    client.act_as(Role.ALUMNO, "cobrador1", "Ofertas")
    assert client.get("/courses/progress").status_code == 403


def test_lessons_unlock_in_order(client: TestClient) -> None:
    course = _create(client)
    second = course["lessons"][1]
    question = second["questions"][0]

    client.act_as(Role.ALUMNO, "cobrador1", "Ofertas")
    assert client.patch(f"/lesson-progress/{second['id']}/theory-completed").status_code == 409
    early = post_attempt(
        client,
        {
            "lesson_id": second["id"],
            "answers": [{"question_id": question["id"], "selected_option_ids": [question["options"][0]["id"]]}],
        },
    )
    assert early.status_code == 409

    _answer_first_lesson(client, course)
    client.act_as(Role.ALUMNO, "cobrador1", "Ofertas")
    assert client.patch(f"/lesson-progress/{second['id']}/theory-completed").status_code == 200


def _bank_lesson(size: int, per_attempt: int | None) -> dict:
    return {
        "title": "Banco",
        "summary": "s",
        "theory": "t",
        "sort_order": 1,
        "questions_per_attempt": per_attempt,
        "questions": [
            {
                "prompt": f"P{n}",
                "sort_order": n,
                "options": [
                    {"label": "Bien", "is_correct": True, "sort_order": 1},
                    {"label": "Mal", "is_correct": False, "sort_order": 2},
                    {"label": "Otra", "is_correct": False, "sort_order": 3},
                ],
            }
            for n in range(1, size + 1)
        ],
    }


def test_question_bank_draws_a_random_subset_each_practice(client: TestClient) -> None:
    client.act_as(Role.ADMINISTRADOR, "admin")
    course = client.post("/courses", json={"title": "Banco", "stores": ["Ofertas"], "lessons": [_bank_lesson(12, 4)]}).json()
    assert course["lessons"][0]["questions_per_attempt"] == 4
    lesson_id = course["lessons"][0]["id"]

    client.act_as(Role.ALUMNO, "cobrador1", "Ofertas")
    draws = []
    for _ in range(8):
        started = client.post("/training-attempts/start", json={"lesson_id": lesson_id}).json()
        prompts = [question["prompt"] for question in started["questions"]]
        assert len(prompts) == 4 and len(set(prompts)) == 4
        draws.append(tuple(prompts))
    assert len(set(draws)) > 1  # 8 draws of 4-of-12 being identical is practically impossible


def test_attempt_must_answer_the_drawn_questions_once(client: TestClient) -> None:
    client.act_as(Role.ADMINISTRADOR, "admin")
    course = client.post("/courses", json={"title": "Banco", "stores": ["Ofertas"], "lessons": [_bank_lesson(6, 3)]}).json()
    lesson = course["lessons"][0]
    correct = {q["id"]: next(o["id"] for o in q["options"] if o["is_correct"]) for q in lesson["questions"]}

    client.act_as(Role.ALUMNO, "cobrador1", "Ofertas")
    started = client.post("/training-attempts/start", json={"lesson_id": lesson["id"]}).json()
    drawn = [question["id"] for question in started["questions"]]
    not_drawn = next(question_id for question_id in correct if question_id not in drawn)

    wrong_set = [{"question_id": qid, "selected_option_ids": [correct[qid]]} for qid in drawn[:2] + [not_drawn]]
    assert client.post("/training-attempts", json={"session_id": started["session_id"], "answers": wrong_set}).status_code == 400

    answers = [{"question_id": qid, "selected_option_ids": [correct[qid]]} for qid in drawn]
    submitted = client.post("/training-attempts", json={"session_id": started["session_id"], "answers": answers})
    assert submitted.status_code == 201
    assert submitted.json()["score_percent"] == 100
    again = client.post("/training-attempts", json={"session_id": started["session_id"], "answers": answers})
    assert again.status_code == 409

    client.act_as(Role.ALUMNO, "cobrador2", "Ofertas")
    stolen = client.post("/training-attempts", json={"session_id": started["session_id"], "answers": answers})
    assert stolen.status_code == 404


def test_bank_size_validation_is_in_spanish(client: TestClient) -> None:
    client.act_as(Role.ADMINISTRADOR, "admin")
    response = client.post("/courses", json={"title": "Banco", "stores": ["Ofertas"], "lessons": [_bank_lesson(2, 5)]})
    assert response.status_code == 422
    assert "pide 5 preguntas por práctica pero su banco tiene 2" in response.json()["detail"][0]["msg"]

    short = client.post("/users", json={"username": "ab", "full_name": "X", "password": "123", "role": "supervisor"})
    messages = [error["msg"] for error in short.json()["detail"]]
    assert "El campo usuario debe tener al menos 3 caracteres." in messages
    assert "El campo contraseña debe tener al menos 8 caracteres." in messages
