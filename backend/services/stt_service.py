"""
STT service with fallback: ElevenLabs (scribe_v1) → Groq (whisper-large-v3-turbo).
Accepts raw audio bytes, returns transcribed text.
"""
import os

import httpx


async def transcribe_audio(audio_bytes: bytes, content_type: str = "audio/wav") -> str:
    print(f"[STT] Received {len(audio_bytes)} bytes, content_type={content_type}")

    # Try ElevenLabs first
    elevenlabs_key = os.getenv("ELEVENLABS_API_KEY")
    if elevenlabs_key:
        try:
            text = await _transcribe_elevenlabs(audio_bytes, content_type, elevenlabs_key)
            return text
        except Exception as e:
            print(f"[STT] ElevenLabs failed: {e!s}, trying Groq Whisper...")

    # Fallback: Groq Whisper
    groq_key = os.getenv("GROQ_API_KEY")
    if groq_key:
        try:
            text = await _transcribe_groq(audio_bytes, content_type, groq_key)
            return text
        except Exception as e:
            print(f"[STT] Groq Whisper also failed: {e!s}")

    raise RuntimeError("All STT providers failed (ElevenLabs quota exceeded, Groq unavailable)")


async def _transcribe_elevenlabs(audio_bytes: bytes, content_type: str, api_key: str) -> str:
    async with httpx.AsyncClient(timeout=60.0) as client:
        resp = await client.post(
            "https://api.elevenlabs.io/v1/speech-to-text",
            headers={"xi-api-key": api_key},
            files={"file": ("audio.wav", audio_bytes, content_type)},
            data={"model_id": "scribe_v1"},
        )
        print(f"[STT] ElevenLabs response: {resp.status_code} {resp.text[:200]}")
        resp.raise_for_status()
        return resp.json().get("text", "")


async def _transcribe_groq(audio_bytes: bytes, content_type: str, api_key: str) -> str:
    ext = "wav" if "wav" in content_type else "webm"
    async with httpx.AsyncClient(timeout=60.0) as client:
        resp = await client.post(
            "https://api.groq.com/openai/v1/audio/transcriptions",
            headers={"Authorization": f"Bearer {api_key}"},
            files={"file": (f"audio.{ext}", audio_bytes, content_type)},
            data={"model": "whisper-large-v3-turbo", "language": "en"},
        )
        print(f"[STT] Groq Whisper response: {resp.status_code} {resp.text[:200]}")
        resp.raise_for_status()
        return resp.json().get("text", "")
