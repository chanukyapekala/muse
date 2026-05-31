"""OpenAI GPT provider."""

import time

import openai

from muse.config import settings
from muse.engine.types import ModelResult


class OpenAIProvider:
    slug = "openai"
    name = "OpenAI GPT"

    async def generate(self, prompt: str, system: str, max_tokens: int = 2048) -> ModelResult:
        client = openai.AsyncOpenAI(api_key=settings.openai_api_key)
        start = time.perf_counter()
        response = await client.chat.completions.create(
            model=settings.openai_model,
            max_tokens=max_tokens,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": prompt},
            ],
        )
        latency = int((time.perf_counter() - start) * 1000)
        usage = response.usage
        return ModelResult(
            name=self.name,
            slug=self.slug,
            content=response.choices[0].message.content or "",
            input_tokens=usage.prompt_tokens if usage else 0,
            output_tokens=usage.completion_tokens if usage else 0,
            latency_ms=latency,
        )

    def is_available(self) -> bool:
        return bool(settings.openai_api_key)
