"""MLX on-device provider — local inference on Apple Silicon, zero cost, fully offline."""

from __future__ import annotations

import time
from pathlib import Path
from typing import Any

from muse.engine.types import ModelResult

DEFAULT_MODEL = "mlx-community/Llama-3.2-3B-Instruct-4bit"
MODELS_DIR = Path.home() / ".muse" / "models"


def _is_apple_silicon() -> bool:
    import platform

    return platform.system() == "Darwin" and platform.machine() == "arm64"


class MLXLocalProvider:
    slug = "mlx"
    name = "MLX Local"

    def __init__(self, model_name: str | None = None) -> None:
        from muse.config import settings

        self.model_name = model_name or getattr(settings, "mlx_model", DEFAULT_MODEL)
        self._model: Any = None
        self._tokenizer: Any = None

    def _ensure_loaded(self) -> None:
        if self._model is not None:
            return
        from mlx_lm import load  # type: ignore[import-not-found]

        self._model, self._tokenizer = load(self.model_name)

    def _format_chat(self, prompt: str, system: str) -> str:
        """Format prompt using the tokenizer's chat template if available."""
        messages = []
        if system:
            messages.append({"role": "system", "content": system})
        messages.append({"role": "user", "content": prompt})

        if hasattr(self._tokenizer, "apply_chat_template"):
            result: str = self._tokenizer.apply_chat_template(
                messages, tokenize=False, add_generation_prompt=True
            )
            return result
        return f"{system}\n\n{prompt}" if system else prompt

    def _generate_sync(self, formatted: str, max_tokens: int) -> str:
        """Run MLX generation on the main thread (Metal requires it)."""
        from mlx_lm import generate as mlx_generate

        output = mlx_generate(
            self._model,
            self._tokenizer,
            prompt=formatted,
            max_tokens=max_tokens,
        )
        return output if isinstance(output, str) else str(output)

    async def generate(self, prompt: str, system: str, max_tokens: int = 2048) -> ModelResult:
        self._ensure_loaded()

        formatted = self._format_chat(prompt, system)

        start = time.perf_counter()
        # MLX uses Metal GPU — must run on the main thread, not in a thread pool.
        # Blocking the event loop briefly is acceptable for local inference.
        output = self._generate_sync(formatted, max_tokens)
        latency = int((time.perf_counter() - start) * 1000)

        content = output if isinstance(output, str) else str(output)

        input_tokens = len(self._tokenizer.encode(formatted))
        output_tokens = len(self._tokenizer.encode(content))

        return ModelResult(
            name=self.name,
            slug=self.slug,
            content=content,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            cost_usd=0.0,
            provider_type="local",
            latency_ms=latency,
        )

    def is_available(self) -> bool:
        if not _is_apple_silicon():
            return False
        try:
            import mlx_lm  # noqa: F401

            return True
        except ImportError:
            return False
