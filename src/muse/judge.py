"""Judge: reads all model outputs and synthesizes a final recommendation."""

import anthropic

from muse.config import settings
from muse.orchestrator import ModelResult

JUDGE_SYSTEM = """You are an expert synthesis judge evaluating multiple AI responses
to the same ideation prompt. Your job is to:

1. Score each response on three dimensions (1-10 each):
   - Feasibility: Is the recommendation realistic and actionable?
   - Novelty: Does it offer fresh angles or just the obvious?
   - Specificity: Are recommendations concrete or vague?

2. Identify the single strongest recommendation from any model.

3. Write a synthesis that takes the best elements from all responses.

Output strictly in this markdown format:

## Scores
| Model | Feasibility | Novelty | Specificity | Total |
|-------|-------------|---------|-------------|-------|
| Claude | X | X | X | X |
| OpenAI GPT | X | X | X | X |
| Gemini | X | X | X | X |
| Qwen | X | X | X | X |

## Strongest single recommendation
[one paragraph — the single best insight across all four]

## Synthesis
[3-5 paragraphs combining the best from all models — the definitive answer]

## Next actions
[3-5 bullet points the user should do immediately]
"""


async def judge(prompt: str, results: list[ModelResult]) -> str:
    """Synthesize all model outputs into a final verdict.

    Args:
        prompt: The original ideation prompt.
        results: List of ModelResult from the orchestrator.

    Returns:
        Markdown string — the synthesis document.
    """
    successful = [r for r in results if not r.error and r.content]

    if not successful:
        return "# Synthesis\n\nAll models failed — no synthesis possible."

    sections = "\n\n".join(
        f"---\n## {r.name} response\n\n{r.content}" for r in successful
    )

    user_message = f"""Original prompt: {prompt}

Here are the responses from {len(successful)} AI models:

{sections}

Please synthesize these into a final verdict following your instructions."""

    client = anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key)
    message = await client.messages.create(
        model=settings.judge_model,
        max_tokens=3000,
        system=JUDGE_SYSTEM,
        messages=[{"role": "user", "content": user_message}],
    )
    return message.content[0].text  # type: ignore[union-attr]
