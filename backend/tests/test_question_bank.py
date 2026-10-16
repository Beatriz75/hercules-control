from fastapi.testclient import TestClient

from app.core.permissions import Role
from tests.conftest import post_attempt


def _course(client: TestClient, title: str, stores: list[str], prompts: list[str]) -> dict:
    client.act_as(Role.ADMINISTRADOR, "admin")
    response = client.post(
        "/courses",
        json={
            "title": title,
            "stores": stores,
            "lessons": [
                {
                    "title": f"{title} L1",
                    "summary": "s",
                    "theory": "t",
                    "sort_order": 1,
                    "questions": [
                        {
                            "prompt": prompt,
                            "sort_order": n,
                            "options": [
                                {"label": "Bien", "is_correct": True, "sort_order": 1},
                                {"label": "Mal", "is_correct": False, "sort_order": 2},
                            ],
                        }
                        for n, prompt in enumerate(prompts, start=1)
                    ],
                }
            ],
        },
    )
    assert response.status_code == 201
    return response.json()


def test_bank_lists_every_question_with_its_course_and_lesson(client: TestClient) -> None:
    first = _course(client, "Cobranza", ["Ofertas"], ["P1", "P2"])
    _course(client, "Líneas", ["Mexi"], ["P3"])

    client.act_as(Role.SUPERVISOR, "sup")
    rows = client.get("/questions").json()
    assert [row["prompt"] for row in rows] == ["P1", "P2", "P3"]
    assert rows[0]["course_title"] == "Cobranza"
    assert rows[0]["lesson_title"] == "Cobranza L1"
    assert rows[0]["stores"] == ["Ofertas"]
    assert rows[0]["options"][0]["is_correct"] is True  # staff see the correct answers

    only_first = client.get("/questions", params={"course_id": first["id"]}).json()
    assert [row["prompt"] for row in only_first] == ["P1", "P2"]


def test_bank_permissions(client: TestClient) -> None:
    course = _course(client, "Cobranza", ["Ofertas"], ["P1"])
    question = course["lessons"][0]["questions"][0]
    body = {"prompt": "Editada", "options": [{"label": "A", "is_correct": True, "sort_order": 1}, {"label": "B", "sort_order": 2}]}

    for role in (Role.ALUMNO, Role.AUDITOR):
        client.act_as(role, "x", "Ofertas")
        assert client.get("/questions").status_code == 403
    client.act_as(Role.SUPERVISOR, "sup")
    assert client.put(f"/questions/{question['id']}", json=body).status_code == 403


def test_edit_question_from_bank_keeps_id_when_not_answered(client: TestClient) -> None:
    course = _course(client, "Cobranza", ["Ofertas"], ["P1", "P2"])
    question = course["lessons"][0]["questions"][1]
    options = question["options"]

    response = client.put(
        f"/questions/{question['id']}",
        json={
            "prompt": "P2 corregida",
            "answer_mode": "single",
            "options": [
                {"id": options[0]["id"], "label": "Bien (texto nuevo)", "is_correct": True, "sort_order": 1},
                {"id": options[1]["id"], "label": "Mal", "is_correct": False, "sort_order": 2},
                {"label": "Otra", "is_correct": False, "sort_order": 3},
            ],
        },
    )
    assert response.status_code == 200
    row = response.json()
    assert row["id"] == question["id"]
    assert row["prompt"] == "P2 corregida"
    assert row["sort_order"] == 2
    assert [o["label"] for o in row["options"]] == ["Bien (texto nuevo)", "Mal", "Otra"]


def test_edit_answered_question_replaces_it_and_keeps_history(client: TestClient) -> None:
    course = _course(client, "Cobranza", ["Ofertas"], ["P1"])
    lesson = course["lessons"][0]
    question = lesson["questions"][0]
    client.act_as(Role.ALUMNO, "cobrador1", "Ofertas")
    client.patch(f"/lesson-progress/{lesson['id']}/theory-completed")
    post_attempt(
        client,
        {"lesson_id": lesson["id"], "answers": [{"question_id": question["id"], "selected_option_ids": [question["options"][0]["id"]]}]},
    )

    client.act_as(Role.ADMINISTRADOR, "admin")
    response = client.put(
        f"/questions/{question['id']}",
        json={"prompt": "P1 v2", "options": [{"label": "Nueva", "is_correct": True, "sort_order": 1}, {"label": "Mal", "sort_order": 2}]},
    )
    assert response.status_code == 200
    assert response.json()["id"] != question["id"]
    assert [row["prompt"] for row in client.get("/questions").json()] == ["P1 v2"]

    client.act_as(Role.ALUMNO, "cobrador1", "Ofertas")
    assert client.get("/training-attempts").json()[0]["answers"][0]["question_id"] == question["id"]


def test_edit_question_validation_in_spanish(client: TestClient) -> None:
    course = _course(client, "Cobranza", ["Ofertas"], ["P1"])
    question = course["lessons"][0]["questions"][0]
    response = client.put(
        f"/questions/{question['id']}",
        json={"prompt": "P1", "options": [{"label": "A", "is_correct": True, "sort_order": 1}, {"label": "B", "is_correct": True, "sort_order": 2}]},
    )
    assert response.status_code == 422
    assert "exactamente una opción correcta" in response.json()["detail"][0]["msg"]
    assert client.put("/questions/9999", json={"prompt": "x", "options": [{"label": "A", "is_correct": True, "sort_order": 1}, {"label": "B", "sort_order": 2}]}).status_code == 404


def test_add_question_from_bank_goes_to_the_end_of_the_lesson(client: TestClient) -> None:
    course = _course(client, "Cobranza", ["Ofertas"], ["P1", "P2"])
    lesson = course["lessons"][0]
    body = {
        "lesson_id": lesson["id"],
        "prompt": "P3 nueva",
        "answer_mode": "multiple",
        "options": [
            {"label": "A", "is_correct": True, "sort_order": 1},
            {"label": "B", "is_correct": True, "sort_order": 2},
            {"label": "C", "sort_order": 3},
        ],
    }
    created = client.post("/questions", json=body)
    assert created.status_code == 201
    row = created.json()
    assert row["lesson_id"] == lesson["id"] and row["sort_order"] == 3
    assert [r["prompt"] for r in client.get("/questions").json()] == ["P1", "P2", "P3 nueva"]

    client.act_as(Role.ALUMNO, "cobrador1", "Ofertas")
    assert client.get("/courses/assigned").json()[0]["lessons"][0]["question_bank_size"] == 3

    client.act_as(Role.SUPERVISOR, "sup")
    assert client.post("/questions", json=body).status_code == 403
    client.act_as(Role.ADMINISTRADOR, "admin")
    assert client.post("/questions", json=body | {"lesson_id": 9999}).status_code == 404
    assert client.post("/questions", json=body | {"prompt": ""}).status_code == 422


def test_similar_questions_detects_repeats_across_courses(client: TestClient) -> None:
    _course(client, "Cobranza", ["Ofertas"], ["¿Cuál es el tiempo máximo de respuesta establecido?", "¿Dónde se valida una transferencia?"])
    _course(client, "Líneas", ["Mexi"], ["¿Qué foto de perfil se coloca el Día 1?"])

    similar = client.get("/questions/similar", params={"prompt": "cual es el tiempo maximo de respuesta"}).json()
    assert [row["prompt"] for row in similar] == ["¿Cuál es el tiempo máximo de respuesta establecido?"]
    assert similar[0]["similarity"] >= 0.6 and similar[0]["course_title"] == "Cobranza"

    reordered = client.get("/questions/similar", params={"prompt": "¿Se valida dónde una transferencia?"}).json()
    assert reordered and reordered[0]["prompt"] == "¿Dónde se valida una transferencia?"

    assert client.get("/questions/similar", params={"prompt": "¿Cuántas llamadas diarias exige la etapa Llamar?"}).json() == []

    own = similar[0]["id"]
    assert client.get("/questions/similar", params={"prompt": similar[0]["prompt"], "exclude_id": own}).json() == []

    client.act_as(Role.SUPERVISOR, "sup")
    assert client.get("/questions/similar", params={"prompt": "tiempo de respuesta"}).status_code == 403


def _with_code(prompt: str, code: str | None, sort_order: int = 1) -> dict:
    return {
        "code": code,
        "prompt": prompt,
        "sort_order": sort_order,
        "options": [
            {"label": "Bien", "is_correct": True, "sort_order": 1},
            {"label": "Mal", "is_correct": False, "sort_order": 2},
        ],
    }


def _lesson(title: str, questions: list[dict]) -> dict:
    return {"title": title, "summary": "s", "theory": "t", "sort_order": 1, "questions": questions}


def test_question_code_is_normalized_saved_and_filterable(client: TestClient) -> None:
    client.act_as(Role.ADMINISTRADOR, "admin")
    first = client.post(
        "/courses",
        json={"title": "Cobranza", "stores": ["Ofertas"], "lessons": [_lesson("L1", [_with_code("Común", " p 97 "), _with_code("Sin código", "", 2)])]},
    )
    assert first.status_code == 201
    questions = first.json()["lessons"][0]["questions"]
    assert [q["code"] for q in questions] == ["P97", None]
    # The same common question can share its code in another course.
    second = client.post(
        "/courses",
        json={"title": "Líneas", "stores": ["Mexi"], "lessons": [_lesson("L1", [_with_code("Común", "P97")])]},
    )
    assert second.status_code == 201

    client.act_as(Role.SUPERVISOR, "sup")
    rows = client.get("/questions").json()
    assert [row["code"] for row in rows] == ["P97", None, "P97"]
    matches = client.get("/questions", params={"code": "p97"}).json()
    assert [(row["course_title"], row["code"]) for row in matches] == [("Cobranza", "P97"), ("Líneas", "P97")]
    assert client.get("/questions", params={"code": "P9"}).json() == []

    client.act_as(Role.ADMINISTRADOR, "admin")
    too_long = client.post("/courses", json={"title": "X", "stores": ["Ofertas"], "lessons": [_lesson("L1", [_with_code("Q", "P" * 21)])]})
    assert too_long.status_code == 422


def test_question_code_survives_course_update_and_bank_edits(client: TestClient) -> None:
    client.act_as(Role.ADMINISTRADOR, "admin")
    course = client.post(
        "/courses",
        json={"title": "Cobranza", "stores": ["Ofertas"], "lessons": [_lesson("L1", [_with_code("Uno", "P1")])]},
    ).json()
    lesson = course["lessons"][0]
    question = lesson["questions"][0]

    # PUT /courses/{id} in place keeps and changes the code.
    lesson_body = _lesson("L1", [_with_code("Uno", "p2") | {"id": question["id"], "options": [
        {"id": question["options"][0]["id"], "label": "Bien", "is_correct": True, "sort_order": 1},
        {"id": question["options"][1]["id"], "label": "Mal", "is_correct": False, "sort_order": 2},
    ]}]) | {"id": lesson["id"]}
    updated = client.put(f"/courses/{course['id']}", json={"title": "Cobranza", "stores": ["Ofertas"], "lessons": [lesson_body]})
    assert updated.status_code == 200
    updated_question = updated.json()["lessons"][0]["questions"][0]
    assert updated_question["id"] == question["id"] and updated_question["code"] == "P2"

    # PUT /questions/{id} edits the code; POST /questions saves it.
    edited = client.put(f"/questions/{question['id']}", json=_with_code("Uno", "P3"))
    assert edited.status_code == 200 and edited.json()["code"] == "P3"
    cleared = client.put(f"/questions/{question['id']}", json=_with_code("Uno", None))
    assert cleared.json()["code"] is None
    created = client.post("/questions", json=_with_code("Dos", "p 4") | {"lesson_id": lesson["id"]})
    assert created.status_code == 201 and created.json()["code"] == "P4"
