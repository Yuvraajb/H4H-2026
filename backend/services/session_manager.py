"""
Session Manager - Workstream C
Manages session state, transcripts, and metadata.
"""
import uuid
from datetime import datetime
from typing import Dict, Any, Optional, List

class SessionManager:
    def __init__(self):
        self.sessions: Dict[str, Dict[str, Any]] = {}

    def create_session(
        self,
        mode: str = "live",
        scenario: Optional[str] = None
    ) -> str:
        """
        Create a new session and return its ID.
        """
        session_id = str(uuid.uuid4())
        self.sessions[session_id] = {
            "id": session_id,
            "mode": mode,
            "scenario": scenario,
            "start_time": datetime.now().isoformat(),
            "end_time": None,
            "transcript": [],
            "metadata": [],
        }
        return session_id

    def get_session(self, session_id: str) -> Optional[Dict[str, Any]]:
        """
        Get session by ID.
        """
        return self.sessions.get(session_id)

    def add_transcript_entry(
        self,
        session_id: str,
        speaker: str,
        text: str,
        timestamp: Optional[str] = None
    ) -> bool:
        """
        Add a transcript entry to the session.
        """
        if session_id not in self.sessions:
            return False

        entry = {
            "id": str(uuid.uuid4()),
            "speaker": speaker,
            "text": text,
            "timestamp": timestamp or datetime.now().isoformat(),
        }

        self.sessions[session_id]["transcript"].append(entry)
        return True

    def add_metadata(
        self,
        session_id: str,
        metadata: Dict[str, Any]
    ) -> bool:
        """
        Add metadata entry to the session.
        """
        if session_id not in self.sessions:
            return False

        self.sessions[session_id]["metadata"].append(metadata)
        return True

    def end_session(self, session_id: str) -> Optional[Dict[str, Any]]:
        """
        End a session and return summary.
        """
        if session_id not in self.sessions:
            return None

        session = self.sessions[session_id]
        session["end_time"] = datetime.now().isoformat()

        start = datetime.fromisoformat(session["start_time"])
        end = datetime.fromisoformat(session["end_time"])
        duration = int((end - start).total_seconds())

        return {
            "session_id": session_id,
            "duration": duration,
            "transcript_count": len(session["transcript"]),
            "metadata_count": len(session["metadata"]),
        }

    def get_all_sessions(self) -> List[Dict[str, Any]]:
        """
        Get all sessions (for debugging/admin).
        """
        return list(self.sessions.values())

    def delete_session(self, session_id: str) -> bool:
        """
        Delete a session.
        """
        if session_id in self.sessions:
            del self.sessions[session_id]
            return True
        return False
