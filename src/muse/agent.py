"""muse agent — autonomous AI agent powered by on-device LLM.

This is a demo/learning module showing how an agent loop works:
  1. Takes a goal
  2. Plans its approach by asking muse
  3. Executes each step autonomously
  4. Observes results and adapts
  5. Produces a final output

Run it:
  muse agent "help me study for my CS algorithms exam"
  muse agent "research whether I should learn Rust or Go"
  muse agent "plan a weekend trip to Austin on a student budget"
"""

import re
import time

import requests

MUSE_API = "http://localhost:8000/v1/chat/completions"

# ANSI colors
BOLD = "\033[1m"
DIM = "\033[2m"
BLUE = "\033[1;34m"
GREEN = "\033[1;32m"
YELLOW = "\033[1;33m"
CYAN = "\033[0;36m"
RED = "\033[1;31m"
RESET = "\033[0m"


def _ask(prompt: str, system: str = "", max_tokens: int = 300) -> str:
    """Send a single request to the muse API and return the response text."""
    try:
        r = requests.post(
            MUSE_API,
            json={
                "model": "mlx",
                "messages": [
                    {"role": "system", "content": system},
                    {"role": "user", "content": prompt},
                ],
                "max_tokens": max_tokens,
            },
            timeout=120,
        )
        r.raise_for_status()
        return r.json()["choices"][0]["message"]["content"]
    except Exception as e:
        return f"[ERROR: {e}]"


def _log(icon: str, label: str, message: str) -> None:
    """Print a formatted log line."""
    print(f"\n{icon} {BOLD}{label}{RESET}")
    print(f"{DIM}{'─' * 50}{RESET}")
    print(f"{CYAN}{message}{RESET}")
    print()


def _log_step(step: int, total: int, action: str) -> None:
    """Print a step indicator."""
    print(f"\n{YELLOW}[Step {step}/{total}]{RESET} {BOLD}{action}{RESET}")


def _extract_items(text: str) -> list[str]:
    """Extract numbered or bulleted items from LLM output."""
    lines = text.strip().split("\n")
    items = []
    for line in lines:
        cleaned = re.sub(r"^[\s]*[\d]+[\.\)]\s*", "", line).strip()
        cleaned = re.sub(r"^[\s]*[-*]\s*", "", cleaned).strip()
        cleaned = re.sub(r"^\*\*(.+?)\*\*.*", r"\1", cleaned).strip()
        if cleaned and len(cleaned) > 3 and not cleaned.startswith("#"):
            items.append(cleaned)
    return items[:7]  # cap at 7 items


def run_agent(goal: str, max_steps: int = 5) -> None:
    """Run the autonomous agent loop."""
    start_time = time.time()
    total_calls = 0
    notes: list[dict] = []

    print(f"\n{BOLD}{'═' * 55}{RESET}")
    print(f"{BOLD}  muse agent — autonomous on-device AI{RESET}")
    print(f"{BOLD}{'═' * 55}{RESET}")
    print(f"\n{GREEN}Goal:{RESET} {goal}")
    print(f"{DIM}Model: Llama 3.2 1B via MLX | Cost: $0.00 | Internet: not required{RESET}")

    # ── Phase 1: PLAN ──
    _log("🧠", "THINKING", "Breaking down the goal into steps...")

    plan_prompt = f"""I need to accomplish this goal: "{goal}"

Break this down into exactly {max_steps} concrete steps I should take.
Return ONLY a numbered list, one step per line. Be specific."""

    plan = _ask(
        plan_prompt, system="You are a planning assistant. Be concise and specific.", max_tokens=300
    )
    total_calls += 1

    _log("📋", "PLAN", plan)

    steps = _extract_items(plan)
    if not steps:
        steps = [f"Research and analyze: {goal}"]

    steps = steps[:max_steps]

    # ── Phase 2: EXECUTE each step ──
    for i, step in enumerate(steps, 1):
        _log_step(i, len(steps), step)

        # ACT — ask muse to execute this step
        print(f"{DIM}>>> Asking muse...{RESET}")
        result = _ask(
            f"""I'm working on this goal: "{goal}"

Current step: {step}

Please complete this step. Be thorough but concise. Give specific, actionable content.""",
            system="You are an expert assistant. Provide detailed, useful answers.",
            max_tokens=400,
        )
        total_calls += 1

        # OBSERVE — show the result
        preview = result[:300] + "..." if len(result) > 300 else result
        print(f"{CYAN}{preview}{RESET}")

        # EVALUATE — ask muse if the result is good enough
        print(f"\n{DIM}>>> Self-evaluating quality...{RESET}")
        evaluation = _ask(
            f"""Rate this response on a scale of 1-10 for usefulness. Just give the number and one sentence why.

Question: {step}
Response: {result[:500]}""",
            system="You are a quality evaluator. Be brief.",
            max_tokens=50,
        )
        total_calls += 1
        print(f"{DIM}Quality check: {evaluation.strip()}{RESET}")

        # ADAPT — if quality is low, retry with a different approach
        score_match = re.search(r"(\d+)", evaluation)
        score = int(score_match.group(1)) if score_match else 5

        if score <= 4:
            print(f"{RED}>>> Low quality detected. Retrying with a different angle...{RESET}")
            result = _ask(
                f"""My previous attempt at "{step}" wasn't good enough.
Try a completely different approach. Be more specific and practical.""",
                system="You are an expert. The previous answer was too vague. Be concrete.",
                max_tokens=400,
            )
            total_calls += 1
            preview = result[:300] + "..." if len(result) > 300 else result
            print(f"{CYAN}{preview}{RESET}")

        notes.append({"step": step, "result": result, "quality": score})
        print(f"{GREEN}✓ Step {i} complete{RESET}")

    # ── Phase 3: SYNTHESIZE ──
    _log("📝", "SYNTHESIZING", "Combining all findings into a final output...")

    notes_summary = "\n\n".join(f"## {n['step']}\n{n['result'][:300]}" for n in notes)

    synthesis = _ask(
        f"""I've completed research on: "{goal}"

Here are my findings:

{notes_summary}

Write a concise, well-structured final summary that combines the best insights.
Include a "Key Takeaways" section with 3-5 bullet points and a "Next Steps" section.""",
        system="You are a synthesis expert. Create a clear, actionable summary.",
        max_tokens=500,
    )
    total_calls += 1

    _log("✅", "FINAL OUTPUT", synthesis)

    # ── Summary ──
    elapsed = time.time() - start_time
    avg_quality = sum(n["quality"] for n in notes) / len(notes) if notes else 0

    print(f"{BOLD}{'═' * 55}{RESET}")
    print(f"{BOLD}  AGENT COMPLETE{RESET}")
    print(f"{BOLD}{'═' * 55}{RESET}")
    print(f"  Goal:           {goal}")
    print(f"  Steps executed: {GREEN}{len(notes)}/{len(steps)}{RESET}")
    print(f"  LLM calls:      {GREEN}{total_calls}{RESET}")
    print(f"  Avg quality:    {GREEN}{avg_quality:.1f}/10{RESET}")
    print(f"  Time:           {GREEN}{elapsed:.1f}s{RESET}")
    print(f"  Cost:           {GREEN}$0.00{RESET}")
    print(f"  Internet:       {GREEN}not used{RESET}")
    print(f"{BOLD}{'═' * 55}{RESET}")


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("Usage: python -m muse.agent 'your goal here'")
        sys.exit(1)

    run_agent(" ".join(sys.argv[1:]))
