"""Tests for the muse API server."""

from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from muse.engine.types import ModelResult


@pytest.fixture
def client():
    from muse.api import app

    return TestClient(app)


def test_health(client) -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_ideate_endpoint(client) -> None:
    mock_results = [
        ModelResult(name="Claude", slug="claude", content="response A"),
        ModelResult(name="GPT", slug="openai", content="response B"),
    ]
    mock_synthesis = "## Trust Score\n0.88\n\n## Synthesis\nCombined."

    with (
        patch("muse.api.fan_out", new=AsyncMock(return_value=mock_results)),
        patch("muse.api.judge", new=AsyncMock(return_value=(mock_synthesis, 0.88))),
    ):
        response = client.post("/muse", json={"prompt": "test prompt"})

    assert response.status_code == 200
    data = response.json()
    assert data["answer"] == mock_synthesis
    assert data["trust_score"] == 0.88
    assert len(data["raw_responses"]) == 2


def test_ideate_skip_judge(client) -> None:
    mock_results = [
        ModelResult(name="Claude", slug="claude", content="response"),
    ]

    with patch("muse.api.fan_out", new=AsyncMock(return_value=mock_results)):
        response = client.post("/muse", json={"prompt": "test", "skip_judge": True})

    assert response.status_code == 200
    data = response.json()
    assert data["answer"] == ""
    assert data["trust_score"] is None


def test_list_sessions(client) -> None:
    response = client.get("/sessions")
    assert response.status_code == 200
    assert isinstance(response.json(), list)
