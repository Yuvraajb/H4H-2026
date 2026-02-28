"""
Crisis Copilot FastAPI backend.
- POST /api/chat — conversation with LLM, session stored in memory
- GET/POST /api/tts — ElevenLabs TTS proxy
- POST /api/report/{session_id}/generate — PDF report
"""
from __future__ import annotations

import os
from contextlib import asynccontextmanager
from typing import Optional

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel

from services.session_manager import session_manager
from services import llm_service

load_dotenv()


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    # cleanup if needed


app = FastAPI(title="Crisis Copilot API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --- Request/Response models ---

class ChatRequest(BaseModel):
    session_id: Optional[str] = None
    message: str


class ChatResponse(BaseModel):
    response: dict  # { spoken_text, metadata }
    session_id: str


class TTSRequest(BaseModel):
    text: str


# --- Chat endpoint ---

@app.post("/api/chat", response_model=ChatResponse)
async def chat(req: ChatRequest):
    message = (req.message or "").strip()
    session_id = req.session_id

    if not session_id:
        session_id = session_manager.create_session()
        if not message:
            return ChatResponse(
                response={
                    "spoken_text": "I'm Crisis Copilot. Tell me what's happening. If this is life-threatening, call emergency services now.",
                    "metadata": {"step": 0, "urgency": "medium", "image_query": None, "category": "other", "display_text": "Session started."},
                },
                session_id=session_id,
            )

    if not message:
        raise HTTPException(status_code=400, detail="Message required when session_id is provided")

    session = session_manager.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    session_manager.append_message(session_id, "user", message)

    messages = [
        {"role": m["role"], "content": m["text"]}
        for m in session["messages"]
    ]

    try:
        result = await llm_service.get_response(messages)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"LLM error: {str(e)}")

    spoken = result.get("spoken_text", "")
    metadata = result.get("metadata") or {}

    session_manager.append_message(session_id, "assistant", spoken)
    session_manager.append_metadata(session_id, metadata)

    return ChatResponse(response={"spoken_text": spoken, "metadata": metadata}, session_id=session_id)


# --- TTS endpoint (ElevenLabs proxy) ---

@app.get("/api/tts")
async def tts_get(text: str = ""):
    if not text.strip():
        raise HTTPException(status_code=400, detail="Missing text")
    return await _tts_response(text.strip())


@app.post("/api/tts")
async def tts_post(req: TTSRequest):
    if not (req.text or "").strip():
        raise HTTPException(status_code=400, detail="Missing text")
    return await _tts_response(req.text.strip())


async def _tts_response(text: str):
    from services.tts_service import get_audio_bytes
    try:
        data, content_type = await get_audio_bytes(text)
        return Response(content=data, media_type=content_type)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"TTS error: {str(e)}")


# --- Report endpoint ---

@app.post("/api/report/{session_id}/generate")
async def generate_report(session_id: str):
    session = session_manager.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    from services.report_generator import generate_pdf
    try:
        pdf_bytes = generate_pdf(session)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Report error: {str(e)}")

    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="crisis-copilot-report-{session_id[:8]}.pdf"'},
    )


# --- Health ---

@app.get("/health")
async def health():
    return {"status": "ok"}
