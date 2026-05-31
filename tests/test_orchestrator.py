"""Tests for the muse engine orchestrator."""

from unittest.mock import AsyncMock

import pytest

from muse.engine.orchestrator import fan_out
from muse.engine.types import ModelResult


def _make_provider(slug: str, name: str, content: str = "response", fail: bool = False):
    """Create a mock provider."""
    provider = AsyncMock()
    provider.slug = slug
    provider.name = name
    provider.is_available.return_value = True

    if fail:
        provider.generate.side_effect = RuntimeError("API timeout")
    else:
        provider.generate.return_value = ModelResult(name=name, slug=slug, content=content)
    return provider


@pytest.mark.asyncio
async def test_fan_out_returns_all_providers() -> None:
    providers = [
        _make_provider("claude", "Claude"),
        _make_provider("openai", "OpenAI GPT"),
        _make_provider("gemini", "Gemini"),
        _make_provider("qwen", "Qwen"),
    ]
    results = await fan_out("test prompt", providers=providers)

    assert len(results) == 4
    slugs = {r.slug for r in results}
    assert slugs == {"claude", "openai", "gemini", "qwen"}
    assert all(r.error is None for r in results)


@pytest.mark.asyncio
async def test_fan_out_handles_partial_failure() -> None:
    providers = [
        _make_provider("claude", "Claude"),
        _make_provider("openai", "OpenAI GPT", fail=True),
        _make_provider("gemini", "Gemini"),
    ]
    results = await fan_out("test prompt", providers=providers)

    failed = [r for r in results if r.error]
    assert len(failed) == 1
    assert failed[0].slug == "openai"
    assert "API timeout" in (failed[0].error or "")


@pytest.mark.asyncio
async def test_fan_out_enabled_models_filter() -> None:
    providers = [
        _make_provider("claude", "Claude"),
        _make_provider("openai", "OpenAI GPT"),
        _make_provider("gemini", "Gemini"),
    ]
    results = await fan_out("test prompt", providers=providers, enabled_models=["claude", "gemini"])

    assert len(results) == 2
    assert {r.slug for r in results} == {"claude", "gemini"}


@pytest.mark.asyncio
async def test_fan_out_with_persona() -> None:
    provider = _make_provider("claude", "Claude")
    await fan_out("test prompt", providers=[provider], persona="Expert Reviewer")

    call_args = provider.generate.call_args
    system_prompt = call_args[0][1] if len(call_args[0]) > 1 else call_args[1].get("system", "")
    assert "Expert Reviewer" in system_prompt
