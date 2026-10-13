from fastapi.testclient import TestClient


def _create_template(client: TestClient, is_active: bool = True) -> dict:
    response = client.post(
        "/audit-templates",
        json={
            "name": "Operational checklist",
            "is_active": is_active,
            "criteria": [
                {"label": "Second check", "sort_order": 2, "is_required": False},
                {"label": "First check", "sort_order": 1},
            ],
        },
    )
    assert response.status_code == 201
    return response.json()


def test_create_operational_audit_from_active_template_orders_answers_and_computes_score(
    client: TestClient,
) -> None:
    template = _create_template(client)
    criteria = template["criteria"]

    response = client.post(
        "/operational-audits",
        json={
            "template_id": template["id"],
            "target_type": "employee",
            "target_reference": "EMP-42",
            "auditor_name": "Alex Auditor",
            "answers": [
                {"criterion_id": criteria[1]["id"], "answer_score": 80, "answer_text": "Optional ok"},
                {"criterion_id": criteria[0]["id"], "answer_score": 100, "answer_text": "Required ok"},
            ],
        },
    )

    assert response.status_code == 201
    body = response.json()
    assert body["score"] == 90
    assert [answer["sort_order"] for answer in body["answers"]] == [1, 2]
    assert [answer["criterion_label"] for answer in body["answers"]] == ["First check", "Second check"]
    assert body["findings"] == []


def test_rejects_missing_template(client: TestClient) -> None:
    response = client.post(
        "/operational-audits",
        json={
            "template_id": 999,
            "target_type": "area",
            "target_reference": "Support",
            "auditor_name": "Alex Auditor",
            "answers": [{"criterion_id": 1, "answer_score": 80}],
        },
    )

    assert response.status_code == 404


def test_rejects_inactive_template(client: TestClient) -> None:
    template = _create_template(client, is_active=False)

    response = client.post(
        "/operational-audits",
        json={
            "template_id": template["id"],
            "target_type": "employee",
            "target_reference": "EMP-42",
            "auditor_name": "Alex Auditor",
            "answers": [{"criterion_id": template["criteria"][0]["id"], "answer_score": 100}],
        },
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "La plantilla de auditoría está inactiva."


def test_rejects_answer_criterion_not_in_template(client: TestClient) -> None:
    template = _create_template(client)

    response = client.post(
        "/operational-audits",
        json={
            "template_id": template["id"],
            "target_type": "employee",
            "target_reference": "EMP-42",
            "auditor_name": "Alex Auditor",
            "answers": [
                {"criterion_id": template["criteria"][0]["id"], "answer_score": 100},
                {"criterion_id": 999, "answer_score": 80},
            ],
        },
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Las respuestas deben corresponder a criterios de la plantilla elegida."


def test_get_operational_audit(client: TestClient) -> None:
    template = _create_template(client)
    created = client.post(
        "/operational-audits",
        json={
            "template_id": template["id"],
            "target_type": "area",
            "target_reference": "Warehouse",
            "auditor_name": "Alex Auditor",
            "score": 75,
            "answers": [{"criterion_id": template["criteria"][0]["id"], "answer_score": 75}],
        },
    ).json()

    get_response = client.get(f"/operational-audits/{created['id']}")

    assert get_response.status_code == 200
    assert get_response.json()["id"] == created["id"]


def test_list_operational_audits(client: TestClient) -> None:
    template = _create_template(client)
    created = client.post(
        "/operational-audits",
        json={
            "template_id": template["id"],
            "target_type": "employee",
            "target_reference": "EMP-42",
            "auditor_name": "Alex Auditor",
            "answers": [{"criterion_id": template["criteria"][0]["id"], "answer_score": 100}],
        },
    ).json()

    response = client.get("/operational-audits")

    assert response.status_code == 200
    assert [audit["id"] for audit in response.json()] == [created["id"]]
