"""
ElevenLabs STT proxy (scribe_v1).
Accepts raw audio bytes, returns transcribed text.
"""
import os

import httpx


async def transcribe_audio(audio_bytes: bytes, content_type: str = "audio/wav") -> str:
    api_key = os.getenv("ELEVENLABS_API_KEY")
    if not api_key:
        raise RuntimeError("ELEVENLABS_API_KEY not set")

    async with httpx.AsyncClient(timeout=60.0) as client:
        resp = await client.post(
            "https://api.elevenlabs.io/v1/speech-to-text",
            headers={"xi-api-key": api_key},
            files={"audio": ("audio.wav", audio_bytes, content_type)},
            data={"model_id": "scribe_v1"},
        )
        resp.raise_for_status()
        return resp.json().get("text", "")
