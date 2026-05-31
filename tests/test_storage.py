"""Tests for SQLite storage backend."""

from pathlib import Path

import pytest

from muse.engine.storage.sqlite_store import SQLiteStore
from muse.engine.types import ModelResult, MuseResponse


@pytest.fixture
def store(tmp_path: Path) -> SQLiteStore:
    return SQLiteStore(db_path=tmp_path / "test.db")


@pytest.mark.asyncio
async def test_save_and_get(store: SQLiteStore) -> None:
    response = MuseResponse(
        session_id="test-123",
        prompt="test prompt",
        answer="synthesized answer",
        trust_score=0.85,
        raw_responses=[
            ModelResult(name="Claude", slug="claude", content="response A"),
            ModelResult(name="GPT", slug="openai", content="response B"),
        ],
        total_cost_usd=0.02,
    )

    session_id = await store.save(response)
    assert session_id == "test-123"

    retrieved = await store.get("test-123")
    assert retrieved is not None
    assert retrieved.prompt == "test prompt"
    assert retrieved.answer == "synthesized answer"
    assert retrieved.trust_score == 0.85
    assert len(retrieved.raw_responses) == 2


@pytest.mark.asyncio
async def test_get_nonexistent(store: SQLiteStore) -> None:
    result = await store.get("nonexistent")
    assert result is None


@pytest.mark.asyncio
async def test_list_sessions(store: SQLiteStore) -> None:
    for i in range(3):
        await store.save(
            MuseResponse(
                session_id=f"session-{i}",
                prompt=f"prompt {i}",
                answer=f"answer {i}",
            )
        )

    sessions = await store.list_sessions(limit=10)
    assert len(sessions) == 3
