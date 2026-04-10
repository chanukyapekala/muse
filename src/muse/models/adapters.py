"""Individual model adapters. Each returns a markdown string."""

import asyncio

import anthropic
import openai
from google import genai

from muse.config import settings

SYSTEM_PROMPT = """You are an expert advisor responding to an ideation prompt.
Structure your response as a markdown document with these sections:
## Summary
## Key Recommendations
## Implementation Approach
## Risks & Considerations
## Verdict
Be specific, actionable, and honest about trade-offs."""


async def call_claude(prompt: str) -> str:
    client = anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key)
    message = await client.messages.create(
        model=settings.claude_model,
        max_tokens=2048,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text  # type: ignore[union-attr]


async def call_openai(prompt: str) -> str:
    client = openai.AsyncOpenAI(api_key=settings.openai_api_key)
    response = await client.chat.completions.create(
        model=settings.openai_model,
        max_tokens=2048,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": prompt},
        ],
    )
    return response.choices[0].message.content or ""


async def call_gemini(prompt: str) -> str:
    client = genai.Client(api_key=settings.google_api_key)
    full_prompt = f"{SYSTEM_PROMPT}\n\n{prompt}"
    response = await asyncio.to_thread(
        client.models.generate_content,
        model=settings.gemini_model,
        contents=full_prompt,
    )
    return response.text or ""


async def call_qwen(prompt: str) -> str:
    # Qwen via DashScope — OpenAI-compatible endpoint
    client = openai.AsyncOpenAI(
        api_key=settings.qwen_api_key,
        base_url=settings.qwen_base_url,
    )
    response = await client.chat.completions.create(
        model=settings.qwen_model,
        max_tokens=2048,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": prompt},
        ],
    )
    return response.choices[0].message.content or ""
