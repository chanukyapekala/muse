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
