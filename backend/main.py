"""
Survivor FastAPI backend.
- POST /api/chat      — conversation with vision-capable LLM; returns steps + image URLs
- GET  /api/images    — Wikipedia image lookup for a query
- GET/POST /api/tts   — ElevenLabs TTS proxy
- POST /api/stt       — ElevenLabs STT proxy
- POST /api/report/{session_id}/generate — PDF report (returns PDF + download_url)
- GET  /api/report/{session_id}/download — download generated PDF (for QR code scanning)
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
from fastapi.responses import Response, JSONResponse
from pydantic import BaseModel

from services.session_manager import session_manager
from services import llm_service

_env_path = Path(__file__).resolve().parent / ".env"
load_dotenv(_env_path)

# In-memory cache of generated PDF bytes keyed by session_id
_report_cache: dict[str, bytes] = {}


@asynccontextmanager
async def lifespan(app: FastAPI):
    provider = os.getenv("LLM_PROVIDER", "groq").lower()
    groq_ok = bool(os.getenv("GROQ_API_KEY"))
    eleven_ok = bool(os.getenv("ELEVENLABS_API_KEY"))
    print(f"[Survivor] LLM={provider} groq={groq_ok} elevenlabs={eleven_ok}")
    # Pre-populate wikiHow image cache in the background so first requests are instant
    from services.wikihow_service import warmup as wikihow_warmup
    asyncio.create_task(wikihow_warmup())
    yield


app = FastAPI(title="Survivor API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["X-Download-URL"],
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
            # New session, no message yet — user speaks first; just create session and return minimal response.
            return ChatResponse(
                response={
                    "spoken_text": "",
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

    # Fetch wikiHow steps for each unique image_query and expand into full how-to steps
    steps: list[dict] = []
    if steps_raw:
        from services.wikihow_service import get_wikihow_steps
        from services.image_service import derive_image_query_from_instruction

        # Collect unique queries while preserving order
        seen_q: set[str] = set()
        unique_queries: list[str] = []
        for s in steps_raw:
            q = (s.get("image_query") or "").strip()
            if not q:
                q = derive_image_query_from_instruction(s.get("instruction", ""))
            if q.lower() not in seen_q:
                seen_q.add(q.lower())
                unique_queries.append(q)

        # Fetch wikiHow steps for each unique topic concurrently
        results = await asyncio.gather(*[get_wikihow_steps(q) for q in unique_queries])

        for q, wikihow_steps in zip(unique_queries, results):
            if wikihow_steps:
                steps.extend(wikihow_steps)
            else:
                # Fall back to the LLM instruction with no image
                for s in steps_raw:
                    raw_q = (s.get("image_query") or derive_image_query_from_instruction(s.get("instruction", ""))).strip()
                    if raw_q.lower() == q.lower():
                        steps.append({"instruction": s.get("instruction", ""), "image_url": None})
                        break

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
# Visual frame analysis (passive — returns description only, no chat message)
# ---------------------------------------------------------------------------

class FrameAnalysisRequest(BaseModel):
    session_id: Optional[str] = None
    image_base64: str


class FrameAnalysisResponse(BaseModel):
    description: str


@app.post("/api/analyze-frame", response_model=FrameAnalysisResponse)
async def analyze_frame(req: FrameAnalysisRequest):
    """Analyze a camera frame and return a brief description. Does NOT touch conversation history."""
    try:
        result = await llm_service.get_response(
            [{"role": "user", "content": "Briefly describe what you see in this image in 1-2 sentences. Focus on medically relevant details: person's posture, visible injuries, skin color, breathing, consciousness, bleeding, distress."}],
            image_b64=req.image_base64,
        )
        desc = result.get("spoken_text", "").strip()
        return FrameAnalysisResponse(description=desc)
    except Exception:
        return FrameAnalysisResponse(description="")


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
async def generate_report(session_id: str, request: Request):
    session = session_manager.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    from services.report_generator import generate_pdf

    # Build the public download URL so the PDF can embed a QR code pointing to it
    base = str(request.base_url).rstrip("/")
    download_url = f"{base}/api/report/{session_id}/download"

    try:
        pdf_bytes = generate_pdf(session, download_url=download_url)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Report error: {e!s}")

    _report_cache[session_id] = pdf_bytes

    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="report-{session_id[:8]}.pdf"',
            "X-Download-URL": download_url,
        },
    )


@app.get("/api/report/{session_id}/download")
async def download_report(session_id: str):
    """Serve a previously generated PDF — the URL that QR codes on the report point to."""
    pdf_bytes = _report_cache.get(session_id)
    if not pdf_bytes:
        # Try generating on-the-fly if session still exists
        session = session_manager.get_session(session_id)
        if not session:
            raise HTTPException(status_code=404, detail="Report not found")
        from services.report_generator import generate_pdf
        try:
            pdf_bytes = generate_pdf(session)
            _report_cache[session_id] = pdf_bytes
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
