"""Orchestrator: fans out the prompt to all providers concurrently."""

import asyncio

from muse.engine.providers.base import Provider
from muse.engine.types import ModelResult

SYSTEM_PROMPT = """You are an expert advisor responding to an ideation prompt.
Structure your response as a markdown document with these sections:
## Summary
## Key Recommendations
## Implementation Approach
## Risks & Considerations
## Verdict
Be specific, actionable, and honest about trade-offs."""


def get_all_providers() -> list[Provider]:
    """Return all registered providers (only those with API keys configured)."""
    from muse.engine.providers.anthropic import AnthropicProvider
    from muse.engine.providers.gemini import GeminiProvider
    from muse.engine.providers.openai_provider import OpenAIProvider
    from muse.engine.providers.qwen import QwenProvider

    all_providers: list[Provider] = [
        AnthropicProvider(),
        OpenAIProvider(),
        GeminiProvider(),
        QwenProvider(),
    ]
    return [p for p in all_providers if p.is_available()]


async def _safe_call(
    provider: Provider,
    prompt: str,
    system: str,
    max_tokens: int,
) -> ModelResult:
    try:
        return await provider.generate(prompt, system, max_tokens)
    except Exception as exc:
        return ModelResult(
            name=provider.name,
            slug=provider.slug,
            content="",
            error=str(exc),
        )


async def fan_out(
    prompt: str,
    providers: list[Provider] | None = None,
    enabled_models: list[str] | None = None,
    system: str = SYSTEM_PROMPT,
    persona: str | None = None,
    max_tokens: int = 2048,
) -> list[ModelResult]:
    """Call all providers concurrently and return their results."""
    if providers is None:
        providers = get_all_providers()

    if enabled_models:
        providers = [p for p in providers if p.slug in enabled_models]

    if persona:
        system = f"You are acting as: {persona}\n\n{system}"

    tasks = [_safe_call(p, prompt, system, max_tokens) for p in providers]
    return list(await asyncio.gather(*tasks))
