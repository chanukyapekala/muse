"""muse CLI — summon multiple AI minds, let the best idea win."""

import asyncio
import uuid
from typing import Annotated

import typer
from rich.console import Console
from rich.markdown import Markdown
from rich.progress import Progress, SpinnerColumn, TextColumn
from rich.table import Table

from muse.engine.judge import judge
from muse.engine.orchestrator import fan_out
from muse.engine.storage.sqlite_store import SQLiteStore
from muse.engine.types import ModelResult, MuseResponse
from muse.writer import write_session

app = typer.Typer(
    name="muse",
    help="Multi-model AI ideation with a built-in judge.",
    no_args_is_help=True,
)
console = Console()


def _print_scores_table(results: list[ModelResult]) -> None:
    table = Table(title="Model responses", show_lines=True)
    table.add_column("Model", style="bold")
    table.add_column("Status")
    table.add_column("Length")
    table.add_column("Latency")

    for r in results:
        if r.error:
            table.add_row(r.name, "[red]failed[/red]", "-", "-")
        else:
            table.add_row(
                r.name,
                "[green]ok[/green]",
                str(len(r.content)),
                f"{r.latency_ms}ms",
            )

    console.print(table)


async def _run(
    prompt: str,
    models: list[str] | None,
    no_judge: bool,
    show_all: bool,
) -> None:
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console,
        transient=True,
    ) as progress:
        task = progress.add_task("Fanning out to all models...", total=None)
        results = await fan_out(prompt, enabled_models=models)
        progress.update(task, description="Fan-out complete.")

    _print_scores_table(results)

    if show_all:
        for r in results:
            if not r.error:
                console.rule(f"[bold]{r.name}[/bold]")
                console.print(Markdown(r.content))

    synthesis = ""
    trust_score = None
    if not no_judge:
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console,
            transient=True,
        ) as progress:
            progress.add_task("Judge synthesizing...", total=None)
            synthesis, trust_score = await judge(prompt, results)

        if trust_score is not None:
            console.print(f"\n[bold]Trust score:[/bold] {trust_score:.2f}")
        console.rule("[bold green]Synthesis[/bold green]")
        console.print(Markdown(synthesis))

    # Save to filesystem (backward compat)
    session_dir = await write_session(prompt, results, synthesis)
    console.print(f"\n[dim]Session saved to:[/dim] [bold]{session_dir}[/bold]")

    # Save to SQLite history
    store = SQLiteStore()
    response = MuseResponse(
        session_id=str(uuid.uuid4()),
        prompt=prompt,
        answer=synthesis,
        trust_score=trust_score,
        raw_responses=results,
        total_cost_usd=sum(r.cost_usd for r in results),
    )
    await store.save(response)


@app.command()
def ideate(
    prompt: Annotated[str, typer.Argument(help="Your ideation prompt.")],
    models: Annotated[
        list[str] | None,
        typer.Option(
            "--model", "-m", help="Restrict to specific models (claude, openai, gemini, qwen)."
        ),
    ] = None,
    no_judge: Annotated[
        bool,
        typer.Option("--no-judge", help="Skip the judge synthesis step."),
    ] = False,
    show_all: Annotated[
        bool,
        typer.Option("--show-all", "-a", help="Print all model responses before synthesis."),
    ] = False,
) -> None:
    """Summon multiple AI minds. Let the best idea win.

    Examples:\n
      muse "should I build muse as a CLI or WebUI?"\n
      muse --model claude --model openai "is EU lakehouse SaaS viable?"\n
      muse --show-all "build a Databricks cost alerting agent"
    """
    asyncio.run(_run(prompt, models, no_judge, show_all))


@app.command()
def models(
    action: Annotated[str, typer.Argument(help="Action: download, list, or remove.")] = "list",
    model_name: Annotated[
        str | None,
        typer.Argument(help="Model name (e.g. mlx-community/Llama-3.2-3B-Instruct-4bit)."),
    ] = None,
) -> None:
    """Manage on-device MLX models.

    Examples:\n
      muse models list\n
      muse models download mlx-community/Llama-3.2-3B-Instruct-4bit\n
      muse models download mlx-community/Llama-3.2-1B-Instruct-4bit
    """
    if action == "list":
        from muse.engine.providers.mlx_local import MLXLocalProvider

        provider = MLXLocalProvider()
        if not provider.is_available():
            console.print("[red]MLX not available.[/red] Requires Apple Silicon + mlx-lm package.")
            console.print("Install with: [bold]uv pip install mlx-lm[/bold]")
            return
        from muse.config import settings

        console.print(f"[bold]Configured model:[/bold] {settings.mlx_model}")
        console.print("\n[dim]Override via MLX_MODEL in .env[/dim]")

    elif action == "download":
        if not model_name:
            console.print(
                "[red]Specify a model name.[/red] e.g. muse models download mlx-community/Llama-3.2-3B-Instruct-4bit"
            )
            return
        try:
            from mlx_lm import load

            console.print(f"Downloading [bold]{model_name}[/bold]...")
            load(model_name)
            console.print("[green]Done.[/green] Model cached locally.")
            console.print(f"Set [bold]MLX_MODEL={model_name}[/bold] in .env to use it.")
        except ImportError:
            console.print("[red]mlx-lm not installed.[/red] Run: uv pip install mlx-lm")
        except Exception as e:
            console.print(f"[red]Download failed:[/red] {e}")

    else:
        console.print(f"[red]Unknown action:[/red] {action}. Use: list, download")


@app.command()
def agent(
    goal: Annotated[str, typer.Argument(help="The goal for the agent to accomplish.")],
    steps: Annotated[int, typer.Option("--steps", "-s", help="Max steps to execute.")] = 5,
) -> None:
    """Run an autonomous agent powered by on-device LLM.

    Requires the muse server to be running (muse serve).

    Examples:\n
      muse agent "help me study for my CS algorithms exam"\n
      muse agent "research whether I should learn Rust or Go"\n
      muse agent --steps 3 "plan a weekend trip to Austin"
    """
    from muse.agent import run_agent

    run_agent(goal, max_steps=steps)


@app.command()
def serve(
    host: Annotated[str, typer.Option(help="Host to bind to.")] = "127.0.0.1",
    port: Annotated[int, typer.Option(help="Port to listen on.")] = 8000,
) -> None:
    """Start the muse API server (localhost only)."""
    from muse.api import serve as start_server

    console.print(f"[bold]muse API[/bold] starting on http://{host}:{port}")
    console.print("[dim]Press Ctrl+C to stop[/dim]")
    start_server(host=host, port=port)


if __name__ == "__main__":
    app()
