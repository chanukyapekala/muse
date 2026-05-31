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


# --- OpenAI-compatible endpoint tests ---


def test_v1_chat_completions_single_provider(client) -> None:
    mock_result = ModelResult(
        name="Claude",
        slug="claude",
        content="hello world",
        input_tokens=10,
        output_tokens=5,
    )
    mock_provider = AsyncMock()
    mock_provider.slug = "claude"
    mock_provider.name = "Claude"
    mock_provider.generate.return_value = mock_result

    with patch("muse.api.get_all_providers", return_value=[mock_provider]):
        response = client.post(
            "/v1/chat/completions",
            json={
                "model": "claude",
                "messages": [{"role": "user", "content": "hi"}],
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["model"] == "claude"
    assert data["choices"][0]["message"]["content"] == "hello world"
    assert data["usage"]["prompt_tokens"] == 10
    assert data["usage"]["completion_tokens"] == 5


def test_v1_chat_completions_muse_model(client) -> None:
    mock_results = [
        ModelResult(
            name="Claude", slug="claude", content="resp A", input_tokens=10, output_tokens=5
        ),
        ModelResult(name="GPT", slug="openai", content="resp B", input_tokens=8, output_tokens=6),
    ]

    with (
        patch("muse.api.fan_out", new=AsyncMock(return_value=mock_results)),
        patch("muse.api.judge", new=AsyncMock(return_value=("synthesized", 0.9))),
    ):
        response = client.post(
            "/v1/chat/completions",
            json={
                "model": "muse",
                "messages": [
                    {"role": "system", "content": "be helpful"},
                    {"role": "user", "content": "hello"},
                ],
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["model"] == "muse"
    assert data["choices"][0]["message"]["content"] == "synthesized"


def test_v1_models(client) -> None:
    mock_provider = AsyncMock()
    mock_provider.slug = "mlx"
    mock_provider.name = "MLX Local"

    with patch("muse.api.get_all_providers", return_value=[mock_provider]):
        response = client.get("/v1/models")

    assert response.status_code == 200
    data = response.json()
    ids = [m["id"] for m in data["data"]]
    assert "muse" in ids
    assert "mlx" in ids
