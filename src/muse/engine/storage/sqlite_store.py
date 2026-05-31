"""SQLite storage backend — local-first session persistence."""

import sqlite3
import uuid
from datetime import UTC, datetime
from pathlib import Path

from muse.engine.types import ModelResult, MuseResponse

DEFAULT_DB_PATH = Path.home() / ".muse" / "history.db"


class SQLiteStore:
    def __init__(self, db_path: Path | str = DEFAULT_DB_PATH) -> None:
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def _init_db(self) -> None:
        with sqlite3.connect(self.db_path) as conn:
            conn.executescript("""
                CREATE TABLE IF NOT EXISTS sessions (
                    id TEXT PRIMARY KEY,
                    created_at TEXT NOT NULL,
                    prompt TEXT NOT NULL,
                    answer TEXT NOT NULL DEFAULT '',
                    trust_score REAL,
                    total_cost_usd REAL DEFAULT 0
                );
                CREATE TABLE IF NOT EXISTS model_results (
                    id TEXT PRIMARY KEY,
                    session_id TEXT NOT NULL REFERENCES sessions(id),
                    name TEXT NOT NULL,
                    slug TEXT NOT NULL,
                    content TEXT NOT NULL DEFAULT '',
                    error TEXT,
                    input_tokens INTEGER DEFAULT 0,
                    output_tokens INTEGER DEFAULT 0,
                    cost_usd REAL DEFAULT 0,
                    provider_type TEXT NOT NULL DEFAULT 'cloud',
                    latency_ms INTEGER DEFAULT 0
                );
                CREATE INDEX IF NOT EXISTS idx_sessions_created
                    ON sessions(created_at DESC);
                CREATE INDEX IF NOT EXISTS idx_results_session
                    ON model_results(session_id);
            """)

    async def save(self, response: MuseResponse) -> str:
        session_id = response.session_id or str(uuid.uuid4())
        created_at = response.created_at or datetime.now(UTC).isoformat()

        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                """INSERT OR REPLACE INTO sessions
                   (id, created_at, prompt, answer, trust_score, total_cost_usd)
                   VALUES (?, ?, ?, ?, ?, ?)""",
                (
                    session_id,
                    created_at,
                    response.prompt,
                    response.answer,
                    response.trust_score,
                    response.total_cost_usd,
                ),
            )
            for r in response.raw_responses:
                conn.execute(
                    """INSERT INTO model_results
                       (id, session_id, name, slug, content, error,
                        input_tokens, output_tokens, cost_usd, provider_type, latency_ms)
                       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                    (
                        str(uuid.uuid4()),
                        session_id,
                        r.name,
                        r.slug,
                        r.content,
                        r.error,
                        r.input_tokens,
                        r.output_tokens,
                        r.cost_usd,
                        r.provider_type,
                        r.latency_ms,
                    ),
                )
        return session_id

    async def get(self, session_id: str) -> MuseResponse | None:
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            row = conn.execute("SELECT * FROM sessions WHERE id = ?", (session_id,)).fetchone()
            if not row:
                return None

            results_rows = conn.execute(
                "SELECT * FROM model_results WHERE session_id = ?", (session_id,)
            ).fetchall()

            raw_responses = [
                ModelResult(
                    name=r["name"],
                    slug=r["slug"],
                    content=r["content"],
                    error=r["error"],
                    input_tokens=r["input_tokens"],
                    output_tokens=r["output_tokens"],
                    cost_usd=r["cost_usd"],
                    provider_type=r["provider_type"],
                    latency_ms=r["latency_ms"],
                )
                for r in results_rows
            ]

            return MuseResponse(
                session_id=row["id"],
                prompt=row["prompt"],
                answer=row["answer"],
                trust_score=row["trust_score"],
                raw_responses=raw_responses,
                total_cost_usd=row["total_cost_usd"],
                created_at=row["created_at"],
            )

    async def list_sessions(self, limit: int = 50) -> list[MuseResponse]:
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            rows = conn.execute(
                "SELECT * FROM sessions ORDER BY created_at DESC LIMIT ?", (limit,)
            ).fetchall()

            return [
                MuseResponse(
                    session_id=row["id"],
                    prompt=row["prompt"],
                    answer=row["answer"],
                    trust_score=row["trust_score"],
                    total_cost_usd=row["total_cost_usd"],
                    created_at=row["created_at"],
                )
                for row in rows
            ]
