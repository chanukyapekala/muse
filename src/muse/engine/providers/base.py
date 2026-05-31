"""Provider protocol — every model adapter implements this."""

from __future__ import annotations

from typing import Protocol

from muse.engine.types import ModelResult


class Provider(Protocol):
    """Interface that all model providers must implement."""

    slug: str
    name: str

    async def generate(self, prompt: str, system: str, max_tokens: int = 2048) -> ModelResult:
        """Generate a response for the given prompt."""
        ...

    def is_available(self) -> bool:
        """Return True if this provider is configured and ready (has API key, model loaded, etc.)."""
        ...
