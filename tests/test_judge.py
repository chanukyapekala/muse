"""Tests for the muse engine judge."""

from unittest.mock import AsyncMock

import pytest

from muse.engine.judge import _extract_trust_score, judge
from muse.engine.types import ModelResult


def test_extract_trust_score() -> None:
    text = "## Trust Score\n0.85\n\n## Scores\n..."
    assert _extract_trust_score(text) == 0.85


def test_extract_trust_score_missing() -> None:
    assert _extract_trust_score("no trust score here") is None


@pytest.mark.asyncio
async def test_judge_all_failed() -> None:
    results = [
        ModelResult(name="Claude", slug="claude", content="", error="failed"),
    ]
    synthesis, score = await judge("test", results)
    assert "All models failed" in synthesis
    assert score is None


@pytest.mark.asyncio
async def test_judge_calls_provider() -> None:
    results = [
        ModelResult(name="Claude", slug="claude", content="response A"),
        ModelResult(name="GPT", slug="openai", content="response B"),
    ]
    mock_judge = AsyncMock()
    mock_judge.slug = "claude"
    mock_judge.name = "Claude"
    mock_judge.generate.return_value = ModelResult(
        name="Claude",
        slug="claude",
        content="## Trust Score\n0.92\n\n## Synthesis\nCombined answer.",
    )

    synthesis, score = await judge("test", results, judge_provider=mock_judge)
    assert "Combined answer" in synthesis
    assert score == 0.92
    mock_judge.generate.assert_called_once()
