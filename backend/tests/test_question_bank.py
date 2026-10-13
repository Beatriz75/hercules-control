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
