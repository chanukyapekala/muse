"""Tests for MLX on-device provider (mocked — no actual model needed)."""

import sys
from types import ModuleType
from unittest.mock import MagicMock, patch

import pytest

from muse.engine.types import ModelResult


@pytest.mark.asyncio
async def test_mlx_generate() -> None:
    mock_model = MagicMock()
    mock_tokenizer = MagicMock()
    mock_tokenizer.apply_chat_template.return_value = "formatted prompt"
    mock_tokenizer.encode.return_value = [1, 2, 3, 4, 5]

    # Create a fake mlx_lm module so we can patch it without installing
    fake_mlx_lm = ModuleType("mlx_lm")
    fake_mlx_lm.generate = MagicMock(return_value="MLX response text")  # type: ignore[attr-defined]

    with (
        patch.dict(sys.modules, {"mlx_lm": fake_mlx_lm}),
        patch("muse.engine.providers.mlx_local.MLXLocalProvider._ensure_loaded"),
    ):
        from muse.engine.providers.mlx_local import MLXLocalProvider

        provider = MLXLocalProvider(model_name="test-model")
        provider._model = mock_model
        provider._tokenizer = mock_tokenizer

        result = await provider.generate("test prompt", "system prompt", max_tokens=100)

    assert isinstance(result, ModelResult)
    assert result.slug == "mlx"
    assert result.content == "MLX response text"
    assert result.cost_usd == 0.0
    assert result.provider_type == "local"
    assert result.latency_ms >= 0


def test_mlx_not_available_without_package() -> None:
    with (
        patch.dict("sys.modules", {"mlx_lm": None}),
        patch("muse.engine.providers.mlx_local._is_apple_silicon", return_value=True),
    ):
        from muse.engine.providers.mlx_local import MLXLocalProvider

        provider = MLXLocalProvider()
        # Will be False because mlx_lm import fails
        assert not provider.is_available()


def test_mlx_not_available_on_non_apple() -> None:
    with patch("muse.engine.providers.mlx_local._is_apple_silicon", return_value=False):
        from muse.engine.providers.mlx_local import MLXLocalProvider

        provider = MLXLocalProvider()
        assert not provider.is_available()
