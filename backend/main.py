"""
Personal Doctor FastAPI backend.
- POST /api/chat      — conversation with vision-capable LLM; returns steps + image URLs
- GET  /api/images    — Wikipedia image lookup for a query
- GET/POST /api/tts   — ElevenLabs TTS proxy
- POST /api/stt       — ElevenLabs STT proxy
- POST /api/report/{session_id}/generate — PDF report
"""
from __future__ import annotations

import asyncio
import os
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Optional

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel

from services.session_manager import session_manager
from services import llm_service

_env_path = Path(__file__).resolve().parent / ".env"
load_dotenv(_env_path)


@asynccontextmanager
async def lifespan(app: FastAPI):
    provider = os.getenv("LLM_PROVIDER", "groq").lower()
    groq_ok = bool(os.getenv("GROQ_API_KEY"))
    eleven_ok = bool(os.getenv("ELEVENLABS_API_KEY"))
    print(f"[Personal Doctor] LLM={provider} groq={groq_ok} elevenlabs={eleven_ok}")
    yield


app = FastAPI(title="Personal Doctor API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Request / Response models
# ---------------------------------------------------------------------------

class ChatRequest(BaseModel):
    session_id: Optional[str] = None
    message: str
    image_base64: Optional[str] = None   # base64 JPEG from camera frame


class ChatResponse(BaseModel):
    response: dict
    session_id: str


class TTSRequest(BaseModel):
    text: str


# ---------------------------------------------------------------------------
# Chat endpoint
# ---------------------------------------------------------------------------

@app.post("/api/chat", response_model=ChatResponse)
async def chat(req: ChatRequest):
    message = (req.message or "").strip()
    session_id = req.session_id

    if not session_id:
        session_id = session_manager.create_session()
        if not message:
            # Opening greeting (no image needed)
            greeting = "Hey! I'm your personal doctor. What's going on — tell me what's happening and I'll help you through it."
            return ChatResponse(
                response={
                    "spoken_text": greeting,
                    "phase": "questioning",
                    "steps": [],
                    "metadata": {"urgency": "low", "diagnosis": None, "call_emergency": False},
                },
                session_id=session_id,
            )

    if not message:
        raise HTTPException(status_code=400, detail="Message required when session_id is provided")

    session = session_manager.get_session(session_id)
    if not session:
        session_id = session_manager.create_session()
        session = session_manager.get_session(session_id)

    session_manager.append_message(session_id, "user", message)

    messages = [
        {"role": m["role"], "content": m["text"]}
        for m in session["messages"]
    ]

    try:
        result = await llm_service.get_response(messages, image_b64=req.image_base64)
    except Exception as e:
        spoken = f"I'm having trouble reaching the AI right now. Please try again. ({e!s})"
        return ChatResponse(
            response={"spoken_text": spoken, "phase": "questioning", "steps": [], "metadata": {"urgency": "low", "diagnosis": None, "call_emergency": False}},
            session_id=session_id,
        )

    spoken = result.get("spoken_text", "")
    phase = result.get("phase", "questioning")
    steps_raw: list[dict] = result.get("steps") or []
    metadata = result.get("metadata") or {}
    vitals = result.get("vitals") or {}

    session_manager.append_message(session_id, "assistant", spoken)

    # Store metadata on session for report generation
    if metadata:
        session_manager.append_metadata(session_id, metadata)

    # Fetch Wikipedia images for each step concurrently
    steps: list[dict] = []
    if steps_raw:
        from services.image_service import get_image_url
        queries = [s.get("image_query", "") for s in steps_raw]
        image_urls = await asyncio.gather(*[get_image_url(q) for q in queries])
        steps = [
            {"instruction": s.get("instruction", ""), "image_url": url}
            for s, url in zip(steps_raw, image_urls)
        ]

    return ChatResponse(
        response={
            "spoken_text": spoken,
            "phase": phase,
            "steps": steps,
            "vitals": vitals,
            "metadata": metadata,
        },
        session_id=session_id,
    )


# ---------------------------------------------------------------------------
# Image lookup (Wikipedia)
# ---------------------------------------------------------------------------

@app.get("/api/images")
async def image_lookup(q: str = ""):
    if not q.strip():
        raise HTTPException(status_code=400, detail="Missing query")
    from services.image_service import get_image_url
    url = await get_image_url(q.strip())
    if not url:
        raise HTTPException(status_code=404, detail="No image found")
    return {"url": url}


# ---------------------------------------------------------------------------
# TTS endpoint
# ---------------------------------------------------------------------------

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
        raise HTTPException(status_code=502, detail=f"TTS error: {e!s}")


# ---------------------------------------------------------------------------
# STT endpoint
# ---------------------------------------------------------------------------

@app.post("/api/stt")
async def speech_to_text(request: Request):
    audio_data = await request.body()
    if not audio_data:
        raise HTTPException(status_code=400, detail="No audio data")
    content_type = request.headers.get("content-type", "audio/wav")
    from services.stt_service import transcribe_audio
    try:
        text = await transcribe_audio(audio_data, content_type)
        return {"text": text}
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"STT error: {e!s}")


# ---------------------------------------------------------------------------
# Report endpoint
# ---------------------------------------------------------------------------

@app.post("/api/report/{session_id}/generate")
async def generate_report(session_id: str):
    session = session_manager.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    from services.report_generator import generate_pdf
    try:
        pdf_bytes = generate_pdf(session)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Report error: {e!s}")
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="report-{session_id[:8]}.pdf"'},
    )


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

@app.get("/health")
async def health():
    return {"status": "ok"}
