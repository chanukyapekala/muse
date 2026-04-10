"""Writer: persists model outputs and synthesis to disk."""

import hashlib
from datetime import datetime
from pathlib import Path

import aiofiles

from muse.config import settings
from muse.orchestrator import ModelResult


def _session_id(prompt: str) -> str:
    """Short deterministic ID from prompt + timestamp."""
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    slug = hashlib.sha1(prompt.encode()).hexdigest()[:6]
    return f"{ts}_{slug}"


async def write_session(
    prompt: str,
    results: list[ModelResult],
    synthesis: str,
) -> Path:
    """Write all model .md files and synthesis.md to a session folder.

    Args:
        prompt: The original ideation prompt.
        results: Model outputs from the orchestrator.
        synthesis: Judge synthesis markdown.

    Returns:
        Path to the session folder.
    """
    session_dir = Path(settings.output_dir) / _session_id(prompt)
    session_dir.mkdir(parents=True, exist_ok=True)

    # Write each model's output
    for result in results:
        filename = session_dir / f"{result.slug}.md"
        if result.error:
            content = f"# {result.name}\n\n**Error:** {result.error}\n"
        else:
            content = f"# {result.name}\n\n{result.content}\n"
        async with aiofiles.open(filename, "w", encoding="utf-8") as f:
            await f.write(content)

    # Write synthesis
    synthesis_path = session_dir / "synthesis.md"
    header = f"# Muse synthesis\n\n**Prompt:** {prompt}\n\n---\n\n"
    async with aiofiles.open(synthesis_path, "w", encoding="utf-8") as f:
        await f.write(header + synthesis)

    # Write prompt file for reference
    prompt_path = session_dir / "prompt.md"
    async with aiofiles.open(prompt_path, "w", encoding="utf-8") as f:
        await f.write(f"# Prompt\n\n{prompt}\n")

    return session_dir
