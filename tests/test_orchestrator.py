"""Tests for the muse orchestrator."""

from unittest.mock import AsyncMock, patch

import pytest

from muse.orchestrator import ModelResult, fan_out


@pytest.mark.asyncio
async def test_fan_out_returns_all_models() -> None:
    mock_content = "## Summary\nTest response"

    with (
        patch("muse.orchestrator.call_claude", new=AsyncMock(return_value=mock_content)),
        patch("muse.orchestrator.call_openai", new=AsyncMock(return_value=mock_content)),
        patch("muse.orchestrator.call_gemini", new=AsyncMock(return_value=mock_content)),
        patch("muse.orchestrator.call_qwen", new=AsyncMock(return_value=mock_content)),
    ):
        results = await fan_out("test prompt")

    assert len(results) == 4
    slugs = {r.slug for r in results}
    assert slugs == {"claude", "openai", "gemini", "qwen"}
    assert all(r.error is None for r in results)


@pytest.mark.asyncio
async def test_fan_out_handles_partial_failure() -> None:
    async def fail(_: str) -> str:
        raise RuntimeError("API timeout")

    with (
        patch("muse.orchestrator.call_claude", new=AsyncMock(return_value="ok")),
        patch("muse.orchestrator.call_openai", new=fail),
        patch("muse.orchestrator.call_gemini", new=AsyncMock(return_value="ok")),
        patch("muse.orchestrator.call_qwen", new=AsyncMock(return_value="ok")),
    ):
        results = await fan_out("test prompt")

    failed = [r for r in results if r.error]
    assert len(failed) == 1
    assert failed[0].slug == "openai"
    assert "API timeout" in (failed[0].error or "")


@pytest.mark.asyncio
async def test_fan_out_enabled_models_filter() -> None:
    mock_content = "response"

    with (
        patch("muse.orchestrator.call_claude", new=AsyncMock(return_value=mock_content)),
        patch("muse.orchestrator.call_openai", new=AsyncMock(return_value=mock_content)),
        patch("muse.orchestrator.call_gemini", new=AsyncMock(return_value=mock_content)),
        patch("muse.orchestrator.call_qwen", new=AsyncMock(return_value=mock_content)),
    ):
        results = await fan_out("test prompt", enabled_models=["claude", "gemini"])

    assert len(results) == 2
    assert {r.slug for r in results} == {"claude", "gemini"}
