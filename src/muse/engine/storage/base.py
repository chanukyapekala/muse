"""Storage protocol — all backends implement this."""

from __future__ import annotations

from typing import Protocol

from muse.engine.types import MuseResponse


class StorageBackend(Protocol):
    """Interface for persisting and retrieving muse sessions."""

    async def save(self, response: MuseResponse) -> str:
        """Save a session. Returns the session ID."""
        ...

    async def get(self, session_id: str) -> MuseResponse | None:
        """Retrieve a session by ID."""
        ...

    async def list_sessions(self, limit: int = 50) -> list[MuseResponse]:
        """List recent sessions, newest first."""
        ...
