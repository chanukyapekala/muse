"""Google Gemini provider."""

import asyncio
import time

from google import genai

from muse.config import settings
from muse.engine.types import ModelResult


class GeminiProvider:
    slug = "gemini"
    name = "Gemini"

    async def generate(self, prompt: str, system: str, max_tokens: int = 2048) -> ModelResult:
        client = genai.Client(api_key=settings.google_api_key)
        full_prompt = f"{system}\n\n{prompt}"
        start = time.perf_counter()
        response = await asyncio.to_thread(
            client.models.generate_content,
            model=settings.gemini_model,
            contents=full_prompt,
        )
        latency = int((time.perf_counter() - start) * 1000)
        usage = response.usage_metadata
        return ModelResult(
            name=self.name,
            slug=self.slug,
            content=response.text or "",
            input_tokens=usage.prompt_token_count or 0 if usage else 0,
            output_tokens=usage.candidates_token_count or 0 if usage else 0,
            latency_ms=latency,
        )

    def is_available(self) -> bool:
        return bool(settings.google_api_key)
