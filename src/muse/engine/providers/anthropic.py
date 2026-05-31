"""Anthropic Claude provider."""

import time

import anthropic

from muse.config import settings
from muse.engine.types import ModelResult


class AnthropicProvider:
    slug = "claude"
    name = "Claude"

    async def generate(self, prompt: str, system: str, max_tokens: int = 2048) -> ModelResult:
        client = anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key)
        start = time.perf_counter()
        message = await client.messages.create(
            model=settings.claude_model,
            max_tokens=max_tokens,
            system=system,
            messages=[{"role": "user", "content": prompt}],
        )
        latency = int((time.perf_counter() - start) * 1000)
        return ModelResult(
            name=self.name,
            slug=self.slug,
            content=message.content[0].text,  # type: ignore[union-attr]
            input_tokens=message.usage.input_tokens,
            output_tokens=message.usage.output_tokens,
            latency_ms=latency,
        )

    def is_available(self) -> bool:
        return bool(settings.anthropic_api_key)
