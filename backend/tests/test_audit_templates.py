from fastapi.testclient import TestClient


def test_create_audit_template_returns_ordered_criteria(client: TestClient) -> None:
    response = client.post(
        "/audit-templates",
        json={
            "name": "Store audit",
            "description": "Daily store quality review",
            "criteria": [
                {"label": "Evidence attached", "sort_order": 2, "is_required": False},
                {"label": "Greeting quality", "sort_order": 1, "is_required": True},
            ],
        },
    )

    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "Store audit"
    assert body["is_active"] is True
    assert [criterion["sort_order"] for criterion in body["criteria"]] == [1, 2]
    assert [criterion["label"] for criterion in body["criteria"]] == [
        "Greeting quality",
        "Evidence attached",
    ]


def test_list_and_get_audit_template(client: TestClient) -> None:
    created = client.post(
        "/audit-templates",
        json={
            "name": "Supervisor audit",
            "criteria": [{"label": "Response quality", "sort_order": 1}],
        },
    ).json()

    list_response = client.get("/audit-templates")
    get_response = client.get(f"/audit-templates/{created['id']}")

    assert list_response.status_code == 200
    assert [template["id"] for template in list_response.json()] == [created["id"]]
    assert get_response.status_code == 200
    assert get_response.json()["criteria"][0]["label"] == "Response quality"


def test_update_audit_template_active_state(client: TestClient) -> None:
    created = client.post(
        "/audit-templates",
        json={
            "name": "Activation audit",
            "criteria": [{"label": "Required check", "sort_order": 1}],
        },
    ).json()

    response = client.patch(f"/audit-templates/{created['id']}/active", json={"is_active": False})

    assert response.status_code == 200
    assert response.json()["is_active"] is False


def test_rejects_empty_criteria(client: TestClient) -> None:
    response = client.post("/audit-templates", json={"name": "Invalid audit", "criteria": []})

    assert response.status_code == 422


def test_rejects_duplicate_sort_orders(client: TestClient) -> None:
    response = client.post(
        "/audit-templates",
        json={
            "name": "Invalid audit",
            "criteria": [
                {"label": "First", "sort_order": 1},
                {"label": "Second", "sort_order": 1},
            ],
        },
    )

    assert response.status_code == 422
