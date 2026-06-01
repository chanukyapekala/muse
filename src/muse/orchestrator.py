"""Orchestrator: fans out the prompt to all models concurrently."""

import asyncio
from collections.abc import Callable, Coroutine
from dataclasses import dataclass
from typing import Any


@dataclass
class ModelResult:
    name: str
    slug: str  # used as filename stem: claude, openai, gemini, qwen
    content: str
    error: str | None = None


async def _safe_call(
    name: str,
    slug: str,
    fn: Callable[[str], Coroutine[Any, Any, str]],
    prompt: str,
) -> ModelResult:
    try:
        content = await fn(prompt)
        return ModelResult(name=name, slug=slug, content=content)
    except Exception as exc:
        return ModelResult(name=name, slug=slug, content="", error=str(exc))


async def fan_out(
    prompt: str,
    enabled_models: list[str] | None = None,
) -> list[ModelResult]:
    """Call all enabled models concurrently and return their results.

    Args:
        prompt: The ideation prompt to send to all models.
        enabled_models: Optional list of slugs to restrict which models run.
                        Defaults to all four if None.

    Returns:
        List of ModelResult, one per model (including failures).
    """
    from muse.models.adapters import call_claude, call_gemini, call_openai, call_qwen

    candidates = [
        ("Claude", "claude", call_claude),
        ("OpenAI GPT", "openai", call_openai),
        ("Gemini", "gemini", call_gemini),
        ("Qwen", "qwen", call_qwen),
    ]

    if enabled_models:
        candidates = [(n, s, f) for n, s, f in candidates if s in enabled_models]

    tasks = [_safe_call(name, slug, fn, prompt) for name, slug, fn in candidates]
    return await asyncio.gather(*tasks)
