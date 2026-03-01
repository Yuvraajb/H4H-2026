"""
LLM integration — Personal Doctor persona.
3-phase flow: questioning → assessment → treatment with step images.
Vision: uses llama-4-scout (multimodal) when a camera frame is provided.
"""
from __future__ import annotations

import json
import os
import re
from typing import Any

SYSTEM_PROMPT = """You are a Personal Doctor AI — calm, methodical, and genuinely helpful. You guide users through medical situations step by step.

PHASES — move through them in order:

PHASE 1 — QUESTIONING (first 2-3 turns):
  Ask ONE targeted question per response. Gather:
  - Primary symptom and where/how it feels
  - How long it has been happening
  - Severity on a scale of 1-10
  - Any relevant history (allergies, conditions, medications)
  If a camera image is provided, briefly note what you observe (visible injuries, skin colour, posture, etc.) and factor it into your questions.

PHASE 2 — ASSESSMENT:
  After gathering enough information, summarise your findings clearly.
  State your working diagnosis and a confidence level (e.g. "I believe this is a sprained ankle — 80% confidence").
  State the urgency level. If urgency is critical, instruct the user to call emergency services immediately.

PHASE 3 — TREATMENT:
  Give numbered, actionable steps. Each step must be short (imperative sentence, max 12 words).
  Every step must include an image_query — a short phrase to find a helpful illustration.
  After the final step, ask "Does that help? What are you seeing now?"

RESPONSE FORMAT — strict JSON, no markdown, no extra text:
{
  "spoken_text": "1-2 sentences spoken aloud. During questioning this is your question. During assessment this is your summary. During treatment this is a brief intro.",
  "phase": "questioning",
  "steps": [],
  "metadata": {
    "urgency": "low",
    "diagnosis": null,
    "call_emergency": false
  }
}

During treatment phase only, steps is populated:
{
  "spoken_text": "Here is what to do. Follow these steps carefully.",
  "phase": "treatment",
  "steps": [
    {"instruction": "Call 911 immediately", "image_query": "call 911 emergency phone"},
    {"instruction": "Tilt head back and lift chin", "image_query": "head tilt chin lift airway"},
    {"instruction": "Give 30 chest compressions", "image_query": "CPR chest compression technique"}
  ],
  "metadata": {
    "urgency": "critical",
    "diagnosis": "Cardiac arrest",
    "call_emergency": true
  }
}

RULES:
- Always return valid JSON. Never include markdown fences or explanation outside the JSON.
- During questioning and assessment, steps must be an empty array [].
- urgency values: "low", "medium", "high", "critical"
- diagnosis is null until assessment phase.
- call_emergency is true only when the situation is life-threatening.
- Keep spoken_text under 40 words — it will be read aloud.
"""


def _parse_llm_json(content: str) -> dict[str, Any] | None:
    content = content.strip()
    match = re.search(r"\{[\s\S]*\}", content)
    if match:
        try:
            return json.loads(match.group(0))
        except json.JSONDecodeError:
            pass
    try:
        return json.loads(content)
    except json.JSONDecodeError:
        return None


async def get_response(
    messages: list[dict[str, Any]],
    image_b64: str | None = None,
) -> dict[str, Any]:
    provider = os.getenv("LLM_PROVIDER", "groq").lower()
    if provider == "anthropic":
        return await _get_response_anthropic(messages, image_b64)
    if provider == "gemini":
        return await _get_response_gemini(messages)
    if provider == "groq":
        return await _get_response_groq(messages, image_b64)
    return await _get_response_openai(messages, image_b64)


# ---------------------------------------------------------------------------
# Groq (primary)
# ---------------------------------------------------------------------------

async def _get_response_groq(
    messages: list[dict[str, Any]],
    image_b64: str | None = None,
) -> dict[str, Any]:
    from openai import AsyncOpenAI
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        return _error_response("Configure GROQ_API_KEY in backend/.env")

    client = AsyncOpenAI(base_url="https://api.groq.com/openai/v1", api_key=api_key)

    # Build base conversation
    full_messages: list[dict[str, Any]] = [{"role": "system", "content": SYSTEM_PROMPT}]
    for m in messages[:-1]:
        full_messages.append({"role": m["role"], "content": m["content"]})

    last = messages[-1] if messages else {"role": "user", "content": ""}

    if image_b64:
        last_content: Any = [
            {"type": "text", "text": last["content"]},
            {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"}},
        ]
        vision_model = os.getenv("GROQ_VISION_MODEL", "meta-llama/llama-4-scout-17b-16e-instruct")
        text_model = os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile")

        full_messages.append({"role": last["role"], "content": last_content})
        try:
            resp = await client.chat.completions.create(
                model=vision_model, messages=full_messages, max_tokens=800, temperature=0.3,
            )
            return _parse_groq_response(resp)
        except Exception:
            # Vision model unavailable — retry without image
            full_messages[-1] = {
                "role": last["role"],
                "content": last["content"] + " [Camera image provided but vision model unavailable]",
            }
            resp = await client.chat.completions.create(
                model=text_model, messages=full_messages, max_tokens=800, temperature=0.3,
            )
            return _parse_groq_response(resp)
    else:
        full_messages.append({"role": last["role"], "content": last["content"]})
        model = os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile")
        try:
            resp = await client.chat.completions.create(
                model=model, messages=full_messages, max_tokens=800, temperature=0.3,
            )
            return _parse_groq_response(resp)
        except Exception as e:
            raise RuntimeError(f"Groq API error: {e!s}")


def _parse_groq_response(resp: Any) -> dict[str, Any]:
    content = resp.choices[0].message.content or ""
    parsed = _parse_llm_json(content)
    if parsed and "spoken_text" in parsed:
        return {
            "spoken_text": parsed.get("spoken_text", ""),
            "phase": parsed.get("phase", "questioning"),
            "steps": parsed.get("steps") or [],
            "metadata": parsed.get("metadata") or _default_metadata(),
        }
    return {
        "spoken_text": content[:300] if content else "I'm here. Tell me what's happening.",
        "phase": "questioning",
        "steps": [],
        "metadata": _default_metadata(),
    }


# ---------------------------------------------------------------------------
# OpenAI fallback
# ---------------------------------------------------------------------------

async def _get_response_openai(
    messages: list[dict[str, Any]],
    image_b64: str | None = None,
) -> dict[str, Any]:
    from openai import AsyncOpenAI
    client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))
    model = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
    full = [{"role": "system", "content": SYSTEM_PROMPT}] + [
        {"role": m["role"], "content": m["content"]} for m in messages
    ]
    resp = await client.chat.completions.create(model=model, messages=full, max_tokens=800)
    content = resp.choices[0].message.content or ""
    parsed = _parse_llm_json(content)
    if parsed and "spoken_text" in parsed:
        return {
            "spoken_text": parsed.get("spoken_text", ""),
            "phase": parsed.get("phase", "questioning"),
            "steps": parsed.get("steps") or [],
            "metadata": parsed.get("metadata") or _default_metadata(),
        }
    return {"spoken_text": content[:300], "phase": "questioning", "steps": [], "metadata": _default_metadata()}


# ---------------------------------------------------------------------------
# Anthropic fallback
# ---------------------------------------------------------------------------

async def _get_response_anthropic(
    messages: list[dict[str, Any]],
    image_b64: str | None = None,
) -> dict[str, Any]:
    from anthropic import AsyncAnthropic
    client = AsyncAnthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
    model = os.getenv("ANTHROPIC_MODEL", "claude-haiku-4-5-20251001")
    api_messages = []
    for i, m in enumerate(messages):
        role = "assistant" if m.get("role") == "assistant" else "user"
        if image_b64 and i == len(messages) - 1 and role == "user":
            api_messages.append({"role": role, "content": [
                {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": image_b64}},
                {"type": "text", "text": m.get("content", "")},
            ]})
        else:
            api_messages.append({"role": role, "content": m.get("content", "")})
    resp = await client.messages.create(model=model, max_tokens=800, system=SYSTEM_PROMPT, messages=api_messages)
    content = (resp.content[0].text if resp.content else "") or ""
    parsed = _parse_llm_json(content)
    if parsed and "spoken_text" in parsed:
        return {
            "spoken_text": parsed.get("spoken_text", ""),
            "phase": parsed.get("phase", "questioning"),
            "steps": parsed.get("steps") or [],
            "metadata": parsed.get("metadata") or _default_metadata(),
        }
    return {"spoken_text": content[:300], "phase": "questioning", "steps": [], "metadata": _default_metadata()}


# ---------------------------------------------------------------------------
# Gemini fallback
# ---------------------------------------------------------------------------

async def _get_response_gemini(messages: list[dict[str, Any]]) -> dict[str, Any]:
    import httpx
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        return _error_response("Configure GEMINI_API_KEY.")
    model = os.getenv("GEMINI_MODEL", "gemini-2.0-flash-lite")
    parts = [SYSTEM_PROMPT + "\n\nConversation:\n"]
    for m in messages:
        parts.append(f"{m.get('role','user').upper()}: {m.get('content','')}\n")
    parts.append("ASSISTANT: ")
    prompt = "".join(parts)
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"maxOutputTokens": 800, "temperature": 0.3},
    }
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.post(url, json=payload)
        resp.raise_for_status()
        data = resp.json()
    text = "".join(
        p.get("text", "")
        for c in data.get("candidates", [])
        for p in c.get("content", {}).get("parts", [])
    )
    parsed = _parse_llm_json(text)
    if parsed and "spoken_text" in parsed:
        return {
            "spoken_text": parsed.get("spoken_text", ""),
            "phase": parsed.get("phase", "questioning"),
            "steps": parsed.get("steps") or [],
            "metadata": parsed.get("metadata") or _default_metadata(),
        }
    return {"spoken_text": text[:300], "phase": "questioning", "steps": [], "metadata": _default_metadata()}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _default_metadata() -> dict[str, Any]:
    return {"urgency": "medium", "diagnosis": None, "call_emergency": False}


def _error_response(msg: str) -> dict[str, Any]:
    return {"spoken_text": msg, "phase": "questioning", "steps": [], "metadata": _default_metadata()}
