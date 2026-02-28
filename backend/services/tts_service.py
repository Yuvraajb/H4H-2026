"""
ElevenLabs TTS proxy. API key stays on server.
Returns audio bytes (mp3) for given text.
"""
import os
from typing import Tuple

import httpx

# Calm, clear voices: Rachel or Josh
ELEVENLABS_VOICE_ID = os.getenv("ELEVENLABS_VOICE_ID", "21m00Tcm4TlvDq8ikWAM")  # Rachel
ELEVENLABS_URL = "https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"


async def get_audio_bytes(text: str) -> Tuple[bytes, str]:
    api_key = os.getenv("ELEVENLABS_API_KEY")
    if not api_key:
        raise RuntimeError("ELEVENLABS_API_KEY not set")

    url = ELEVENLABS_URL.format(voice_id=ELEVENLABS_VOICE_ID)
    payload = {
        "text": text[:1000],  # limit length
        "model_id": "eleven_monolingual_v1",
    }
    headers = {
        "Accept": "audio/mpeg",
        "Content-Type": "application/json",
        "xi-api-key": api_key,
    }

    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.post(url, json=payload, headers=headers)
        resp.raise_for_status()
        return resp.content, "audio/mpeg"
