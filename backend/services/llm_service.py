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

SYSTEM_PROMPT = """You are an emergency medicine physician with 20 years of experience in trauma and critical care. Your role is to guide bystanders through medical emergencies with the precision of a physician speaking directly to them.

CRITICAL RULES — non-negotiable:
- NEVER say "seek medical attention", "consult a doctor", or "call a professional". You ARE the doctor. Give direct care instructions.
- Be specific: say "press down 2 inches at 100-120 compressions per minute", not "press on the chest".
- Commit to a diagnosis. Do not hedge with "it could be many things".
- If the situation is life-threatening, say so immediately and tell them to call 911 NOW before any other instruction.
- Extract any vitals the user mentions (heart rate, breathing rate, SpO2, consciousness level, GCS).
- Keep spoken_text under 35 words — it will be read aloud by TTS. Be calm, clear, direct.

THREE PHASES — execute in strict order:

PHASE 1 — RAPID TRIAGE (turns 1-3 max):
  Ask ONE high-yield clinical question per turn. Prioritize:
  Turn 1: Chief complaint + mechanism of injury/onset ("What exactly happened and when did it start?")
  Turn 2: Severity + key associated symptoms ("Rate the pain 1-10. Any difficulty breathing, chest pain, or loss of consciousness?")
  Turn 3: Medical history + allergies ("Any relevant medical conditions, medications, or allergies I should know about?")
  If camera image provided: describe what you observe (bleeding, skin color, posture, visible injuries) and factor this into your questions.
  SKIP DIRECTLY TO ASSESSMENT if the situation is obviously critical (e.g., not breathing, unresponsive, heavy bleeding).

PHASE 2 — CLINICAL ASSESSMENT:
  Summarize your findings. Commit to a working diagnosis with confidence percentage.
  State urgency level clearly. List 2-3 clinical findings that support the diagnosis.
  If call_emergency = true, say "Call 911 immediately" as the FIRST sentence of spoken_text.
  Extract any vitals mentioned by the user (HR, RR, SpO2, GCS, temperature).

PHASE 3 — TREATMENT PROTOCOL:
  Provide evidence-based numbered steps. Each step must be:
  - Imperative sentence, maximum 12 words
  - Clinically specific (include timing, depth, rate, position where relevant)
  - Paired with an image_query that is the EXACT Wikipedia article title or a very specific anatomical term
  Maximum 8 steps. Final step: ask "What are you seeing now?"
  Good image_query examples: "Cardiopulmonary resuscitation", "Recovery position", "Abdominal thrusts", "Tourniquet", "Automated external defibrillator"

RESPONSE FORMAT — strict JSON, no markdown, no text outside JSON:
{
  "spoken_text": "string, max 35 words, spoken aloud",
  "phase": "questioning",
  "steps": [],
  "vitals": {},
  "metadata": {
    "urgency": "low",
    "diagnosis": null,
    "call_emergency": false,
    "confidence": 0,
    "key_findings": []
  }
}

Treatment phase example:
{
  "spoken_text": "This is cardiac arrest. Call 911 now. Start CPR immediately — I'll guide you.",
  "phase": "treatment",
  "steps": [
    {"instruction": "Call 911 right now before anything else", "image_query": "Emergency telephone number"},
    {"instruction": "Place heel of hand on center of chest", "image_query": "Cardiopulmonary resuscitation"},
    {"instruction": "Push down 2 inches, 30 times, 100 per minute", "image_query": "Cardiopulmonary resuscitation"},
    {"instruction": "Tilt head back, lift chin, pinch nose", "image_query": "Head-tilt/chin-lift"},
    {"instruction": "Give 2 slow breaths, watch chest rise", "image_query": "Rescue breathing"},
    {"instruction": "Repeat 30 compressions then 2 breaths", "image_query": "Cardiopulmonary resuscitation"}
  ],
  "vitals": {},
  "metadata": {
    "urgency": "critical",
    "diagnosis": "Cardiac arrest",
    "call_emergency": true,
    "confidence": 95,
    "key_findings": ["Unresponsive", "Not breathing", "No pulse detected"]
  }
}

Vitals extraction example (if user says "his pulse is 120 and he's barely breathing"):
"vitals": {"hr": 120, "rr": 4, "gcs": 10}

Valid vitals keys: hr (heart rate bpm), rr (respiratory rate /min), spo2 (SpO2 %), gcs (Glasgow Coma Scale 3-15), sbp (systolic BP mmHg), temp (temperature °C)
"""


def _parse_llm_json(content: str) -> dict[str, Any] | None:
    content = content.strip()
    # Strip markdown fences if present
    content = re.sub(r"^```(?:json)?\s*", "", content)
    content = re.sub(r"\s*```$", "", content)
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

    full_messages: list[dict[str, Any]] = [{"role": "system", "content": SYSTEM_PROMPT}]
    for m in messages[:-1]:
        full_messages.append({"role": m["role"], "content": m["content"]})

    last = messages[-1] if messages else {"role": "user", "content": ""}
    vision_model = os.getenv("GROQ_VISION_MODEL", "meta-llama/llama-4-scout-17b-16e-instruct")
    text_model = os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile")

    if image_b64:
        last_content: Any = [
            {"type": "text", "text": last["content"]},
            {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"}},
        ]
        full_messages.append({"role": last["role"], "content": last_content})
        try:
            resp = await client.chat.completions.create(
                model=vision_model,
                messages=full_messages,
                max_tokens=1200,
                temperature=0.1,
            )
            return _parse_groq_response(resp)
        except Exception:
            # Vision model unavailable — retry text-only with JSON mode
            full_messages[-1] = {
                "role": last["role"],
                "content": last["content"] + " [Camera image was provided showing the scene]",
            }
            resp = await client.chat.completions.create(
                model=text_model,
                messages=full_messages,
                max_tokens=1200,
                temperature=0.1,
                response_format={"type": "json_object"},
            )
            return _parse_groq_response(resp)
    else:
        full_messages.append({"role": last["role"], "content": last["content"]})
        try:
            resp = await client.chat.completions.create(
                model=text_model,
                messages=full_messages,
                max_tokens=1200,
                temperature=0.1,
                response_format={"type": "json_object"},
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
            "vitals": parsed.get("vitals") or {},
            "metadata": parsed.get("metadata") or _default_metadata(),
        }
    return {
        "spoken_text": content[:300] if content else "I'm here. Tell me what's happening.",
        "phase": "questioning",
        "steps": [],
        "vitals": {},
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
    resp = await client.chat.completions.create(
        model=model, messages=full, max_tokens=1200, temperature=0.1,
        response_format={"type": "json_object"},
    )
    content = resp.choices[0].message.content or ""
    parsed = _parse_llm_json(content)
    if parsed and "spoken_text" in parsed:
        return {
            "spoken_text": parsed.get("spoken_text", ""),
            "phase": parsed.get("phase", "questioning"),
            "steps": parsed.get("steps") or [],
            "vitals": parsed.get("vitals") or {},
            "metadata": parsed.get("metadata") or _default_metadata(),
        }
    return {"spoken_text": content[:300], "phase": "questioning", "steps": [], "vitals": {}, "metadata": _default_metadata()}


# ---------------------------------------------------------------------------
# Anthropic fallback
# ---------------------------------------------------------------------------

async def _get_response_anthropic(
    messages: list[dict[str, Any]],
    image_b64: str | None = None,
) -> dict[str, Any]:
    from anthropic import AsyncAnthropic
    client = AsyncAnthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
    model = os.getenv("ANTHROPIC_MODEL", "claude-sonnet-4-6")
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
    resp = await client.messages.create(
        model=model, max_tokens=1200, system=SYSTEM_PROMPT, messages=api_messages,
    )
    content = (resp.content[0].text if resp.content else "") or ""
    parsed = _parse_llm_json(content)
    if parsed and "spoken_text" in parsed:
        return {
            "spoken_text": parsed.get("spoken_text", ""),
            "phase": parsed.get("phase", "questioning"),
            "steps": parsed.get("steps") or [],
            "vitals": parsed.get("vitals") or {},
            "metadata": parsed.get("metadata") or _default_metadata(),
        }
    return {"spoken_text": content[:300], "phase": "questioning", "steps": [], "vitals": {}, "metadata": _default_metadata()}


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
        "generationConfig": {"maxOutputTokens": 1200, "temperature": 0.1},
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
            "vitals": parsed.get("vitals") or {},
            "metadata": parsed.get("metadata") or _default_metadata(),
        }
    return {"spoken_text": text[:300], "phase": "questioning", "steps": [], "vitals": {}, "metadata": _default_metadata()}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _default_metadata() -> dict[str, Any]:
    return {"urgency": "medium", "diagnosis": None, "call_emergency": False, "confidence": 0, "key_findings": []}


def _error_response(msg: str) -> dict[str, Any]:
    return {"spoken_text": msg, "phase": "questioning", "steps": [], "vitals": {}, "metadata": _default_metadata()}
