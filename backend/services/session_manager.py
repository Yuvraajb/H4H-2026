"""
In-memory session storage for Crisis Copilot.
Each session tracks transcript and AI metadata for report generation.
"""
from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import uuid4


def _now_iso() -> str:
    return datetime.utcnow().isoformat() + "Z"


class SessionManager:
    def __init__(self) -> None:
        self._sessions: dict[str, dict[str, Any]] = {}

    def create_session(self) -> str:
        session_id = str(uuid4())
        self._sessions[session_id] = {
            "session_id": session_id,
            "start_time": _now_iso(),
            "end_time": None,
            "messages": [],
            "metadata_list": [],
        }
        return session_id

    def get_session(self, session_id: str) -> dict[str, Any] | None:
        return self._sessions.get(session_id)

    def append_message(self, session_id: str, role: str, text: str) -> bool:
        s = self._sessions.get(session_id)
        if not s:
            return False
        s["messages"].append({
            "role": role,
            "text": text,
            "timestamp": _now_iso(),
        })
        return True

    def append_metadata(self, session_id: str, metadata: dict[str, Any]) -> bool:
        s = self._sessions.get(session_id)
        if not s:
            return False
        s["metadata_list"].append(metadata)
        return True

    def end_session(self, session_id: str) -> bool:
        s = self._sessions.get(session_id)
        if not s:
            return False
        s["end_time"] = _now_iso()
        return True


session_manager = SessionManager()
