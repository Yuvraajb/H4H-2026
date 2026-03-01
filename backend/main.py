"""
Crisis Copilot FastAPI backend.
- POST /api/chat — conversation with LLM, session stored in memory
- GET/POST /api/tts — ElevenLabs TTS proxy
- POST /api/report/{session_id}/generate — PDF report
- POST /api/step-image — get instructional image from web (image_query)
"""
from __future__ import annotations

import base64
import os
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Optional

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel

from services.session_manager import session_manager
from services import llm_service

# Load .env from backend directory so it works when run from project root or backend/
_env_path = Path(__file__).resolve().parent / ".env"
load_dotenv(_env_path)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Log so you can confirm .env is loaded when running the backend
    provider = os.getenv("LLM_PROVIDER", "groq").lower()
    groq_ok = bool(os.getenv("GROQ_API_KEY"))
    print(f"[Crisis Copilot] LLM_PROVIDER={provider}, GROQ_API_KEY set={groq_ok}")
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
    image_base64: Optional[str] = None
    user_visible: Optional[bool] = None


class ChatResponse(BaseModel):
    response: dict  # { spoken_text, metadata }
    session_id: str


class TTSRequest(BaseModel):
    text: str


class StepImageRequest(BaseModel):
    image_query: str
    display_text: Optional[str] = None
    context: Optional[str] = None


class StepImageResponse(BaseModel):
    image_base64: str
    content_type: str


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

    # Optional: add visibility context for the LLM when no image is sent
    if req.user_visible is not None and not req.image_base64:
        visibility_note = " (User is visible in camera frame.)" if req.user_visible else " (User not visible in frame.)"
        if messages and messages[-1]["role"] == "user":
            messages[-1] = {"role": "user", "content": messages[-1]["content"] + visibility_note}

    try:
        if req.image_base64:
            import base64
            try:
                image_bytes = base64.b64decode(req.image_base64)
            except Exception:
                image_bytes = None
            if image_bytes:
                result = await llm_service.get_response_with_vision(messages, image_bytes)
            else:
                result = await llm_service.get_response(messages)
        else:
            result = await llm_service.get_response(messages)
    except Exception as e:
        # Return 200 with error message so the app can show it (connection worked, LLM failed)
        spoken = f"AI temporarily unavailable: {str(e)} Check API keys in backend/.env and that the backend is running."
        metadata = {"step": 0, "urgency": "low", "image_query": None, "category": "other", "display_text": "Retry or check backend."}
        session_manager.append_message(session_id, "assistant", spoken)
        session_manager.append_metadata(session_id, metadata)
        return ChatResponse(response={"spoken_text": spoken, "metadata": metadata}, session_id=session_id)

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


# --- Step image (from web) ---

@app.post("/api/step-image", response_model=StepImageResponse)
async def step_image(req: StepImageRequest):
    """Search the web for an image matching image_query, fetch it, return as base64."""
    from services.step_image_service import get_step_image
    query = (req.image_query or "").strip()
    if not query:
        raise HTTPException(status_code=400, detail="image_query required")
    result = await get_step_image(query)
    if not result:
        raise HTTPException(
            status_code=502,
            detail="Could not get image. Set GOOGLE_CSE_ID and GOOGLE_CSE_API_KEY (or GOOGLE_API_KEY) in backend/.env for web image search.",
        )
    image_bytes, content_type = result
    return StepImageResponse(
        image_base64=base64.b64encode(image_bytes).decode("ascii"),
        content_type=content_type,
    )


# --- Health ---

@app.get("/health")
async def health():
    return {"status": "ok"}
