"""
GuideVR Backend - FastAPI server with WebSocket and REST endpoints.
Workstream C will implement the full LLM integration.
"""
import json
import uuid
from datetime import datetime
from typing import Optional

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel

app = FastAPI(title="GuideVR API")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory session storage (Workstream C will implement proper session manager)
sessions: dict[str, dict] = {}


class StartSessionRequest(BaseModel):
    type: str
    mode: str
    scenario: Optional[str] = None


class UtteranceRequest(BaseModel):
    type: str
    text: str
    timestamp: str


@app.websocket("/ws/session")
async def websocket_endpoint(websocket: WebSocket):
    """
    WebSocket endpoint for real-time session communication.
    Returns mock AI responses for now.
    """
    await websocket.accept()
    session_id = None

    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)

            if message.get("type") == "start_session":
                session_id = str(uuid.uuid4())
                sessions[session_id] = {
                    "id": session_id,
                    "mode": message.get("mode", "live"),
                    "start_time": datetime.now().isoformat(),
                    "transcript": [],
                    "metadata": [],
                }

                await websocket.send_json({
                    "type": "session_started",
                    "session_id": session_id,
                })

            elif message.get("type") == "utterance":
                if not session_id:
                    await websocket.send_json({
                        "type": "error",
                        "message": "Session not started",
                    })
                    continue

                # Mock AI response
                mock_response = {
                    "type": "response",
                    "text": "I understand. Let me guide you through this step by step. First, ensure the area is safe.",
                    "metadata": {
                        "step": 1,
                        "urgency": "medium",
                        "image_query": "first aid safety check",
                        "category": "safety",
                        "display_text": "Step 1: Ensure Safety",
                    },
                }

                # Add to session transcript
                if session_id in sessions:
                    sessions[session_id]["transcript"].append({
                        "id": str(uuid.uuid4()),
                        "speaker": "user",
                        "text": message.get("text", ""),
                        "timestamp": message.get("timestamp", datetime.now().isoformat()),
                    })
                    sessions[session_id]["transcript"].append({
                        "id": str(uuid.uuid4()),
                        "speaker": "ai",
                        "text": mock_response["text"],
                        "timestamp": datetime.now().isoformat(),
                    })
                    sessions[session_id]["metadata"].append(mock_response["metadata"])

                await websocket.send_json(mock_response)

            elif message.get("type") == "end_session":
                if session_id and session_id in sessions:
                    sessions[session_id]["end_time"] = datetime.now().isoformat()
                    await websocket.send_json({
                        "type": "session_ended",
                        "session_id": session_id,
                    })
                break

    except WebSocketDisconnect:
        if session_id and session_id in sessions:
            sessions[session_id]["end_time"] = datetime.now().isoformat()
        print(f"Client disconnected: {session_id}")
    except Exception as e:
        print(f"WebSocket error: {e}")
        await websocket.send_json({
            "type": "error",
            "message": str(e),
        })


@app.get("/api/images")
async def get_image(query: str = Query(..., description="Image search query")):
    """
    Get instructional image for a query.
    Workstream D will implement Google Custom Search integration.
    """
    # Mock response
    return {
        "image_url": f"https://via.placeholder.com/400x300?text={query.replace(' ', '+')}",
        "caption": f"Instructional image for: {query}",
        "source": "Mock",
    }


@app.get("/api/session/{session_id}")
async def get_session(session_id: str):
    """
    Get session details by ID.
    """
    if session_id not in sessions:
        return {"error": "Session not found"}, 404

    return sessions[session_id]


@app.post("/api/session/{session_id}/end")
async def end_session(session_id: str):
    """
    End a session and return summary.
    """
    if session_id not in sessions:
        return {"error": "Session not found"}, 404

    session = sessions[session_id]
    session["end_time"] = datetime.now().isoformat()

    start = datetime.fromisoformat(session["start_time"])
    end = datetime.fromisoformat(session["end_time"])
    duration = int((end - start).total_seconds())

    return {
        "session_id": session_id,
        "duration": duration,
        "summary": f"Session completed with {len(session['transcript'])} transcript entries.",
    }


@app.post("/api/report/{session_id}/generate")
async def generate_report(session_id: str):
    """
    Generate PDF report for a session.
    Workstream D will implement ReportLab PDF generation.
    """
    if session_id not in sessions:
        return {"error": "Session not found"}, 404

    # Mock PDF generation - Workstream D will implement
    # For now, return a simple text file
    return {
        "message": "PDF generation not yet implemented. Workstream D will add this.",
        "session_id": session_id,
    }


@app.get("/")
async def root():
    """Health check endpoint."""
    return {"status": "ok", "message": "GuideVR Backend API"}


@app.get("/health")
async def health():
    """Health check endpoint."""
    return {"status": "healthy"}
