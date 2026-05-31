"""Judge: synthesizes all model outputs into one authoritative answer with trust score."""

import re

from muse.engine.providers.base import Provider
from muse.engine.types import ModelResult

JUDGE_SYSTEM = """You are an expert synthesis judge evaluating multiple AI responses
to the same prompt. Your job is to:

1. Score each response on three dimensions (1-10 each):
   - Feasibility: Is the recommendation realistic and actionable?
   - Novelty: Does it offer fresh angles or just the obvious?
   - Specificity: Are recommendations concrete or vague?

2. Determine a trust score (0.0 to 1.0) representing your confidence in the
   synthesized answer. Consider model agreement, response quality, and coverage.

3. Write a synthesis that takes the best elements from all responses.

Output strictly in this markdown format:

## Trust Score
[A single float 0.0–1.0, e.g. 0.85]

## Scores
| Model | Feasibility | Novelty | Specificity | Total |
|-------|-------------|---------|-------------|-------|
(one row per model)

## Consensus
[What most or all models agreed on — 1-2 paragraphs]

## Disagreements
[Where models diverged and why it matters — 1-2 paragraphs]

## Synthesis
[3-5 paragraphs — the definitive combined answer]

## Next actions
[3-5 bullet points the user should do immediately]
"""


def _extract_trust_score(synthesis: str) -> float | None:
    """Parse the trust score from the judge's markdown output."""
    match = re.search(r"## Trust Score\s*\n\s*([\d.]+)", synthesis)
    if match:
        try:
            return float(match.group(1))
        except ValueError:
            return None
    return None


async def judge(
    prompt: str,
    results: list[ModelResult],
    judge_provider: Provider | None = None,
) -> tuple[str, float | None]:
    """Synthesize all model outputs into a final verdict.

    Returns:
        Tuple of (synthesis markdown, trust score or None).
    """
    successful = [r for r in results if not r.error and r.content]

    if not successful:
        return "# Synthesis\n\nAll models failed — no synthesis possible.", None

    sections = "\n\n".join(f"---\n## {r.name} response\n\n{r.content}" for r in successful)

    user_message = f"""Original prompt: {prompt}

Here are the responses from {len(successful)} AI models:

{sections}

Please synthesize these into a final verdict following your instructions."""

    if judge_provider is None:
        from muse.engine.providers.anthropic import AnthropicProvider

        judge_provider = AnthropicProvider()

    result = await judge_provider.generate(user_message, JUDGE_SYSTEM, max_tokens=3000)
    trust_score = _extract_trust_score(result.content)
    return result.content, trust_score
