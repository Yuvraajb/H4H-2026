"""
LLM integration — Survivor persona.
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
- spoken_text MUST be plain spoken words ONLY — absolutely NO markdown, NO numbered lists, NO bullet points, NO "##" headings, NO "Image references", NO "Step-by-step instructions". spoken_text is purely what the doctor says out loud.
- Every instruction, numbered step, and image reference MUST go in the "steps" array — NEVER in spoken_text.

STEPS WITH IMAGES — MANDATORY for any action you suggest:
  Whenever you tell the user to DO something (check pulse, check breathing, count respiratory rate, apply pressure, do CPR, tilt head, etc.), you MUST include a "steps" array. Every actionable instruction gets its own step. Each step MUST have:
  - "instruction": one clear imperative sentence (max 15 words), e.g. "Place two fingers on the wrist below the thumb to feel the pulse"
  - "image_query": a Wikipedia article title or medical term so we can show a step-by-step image. Use exact titles when possible: "Pulse", "Respiratory rate", "Cardiopulmonary resuscitation", "Head-tilt/chin-lift", "Recovery position", "Abdominal thrusts", "Tourniquet", "Bleeding", "Recovery position"
  This applies in ALL phases: if you say "check their pulse" or "count their breaths per minute", you must output steps with instruction + image_query for each action so the app can show step-by-step images.

THREE PHASES — execute in strict order:

PHASE 1 — RAPID TRIAGE (turns 1-3 max):
  Ask ONE high-yield clinical question per turn. If you also suggest the user check something (e.g. "While I ask — check if they have a pulse"), include steps with instruction + image_query for that check.
  Turn 1: Chief complaint + mechanism of injury/onset ("What exactly happened and when did it start?")
  Turn 2: Severity + key associated symptoms ("Rate the pain 1-10. Any difficulty breathing, chest pain, or loss of consciousness?")
  Turn 3: Medical history + allergies ("Any relevant medical conditions, medications, or allergies I should know about?")
  If camera image provided: describe what you observe (bleeding, skin color, posture, visible injuries) and factor this into your questions.
  If "[Vision detection: ...]" context is provided, the app's body pose detector has identified anatomical landmarks and pulse points on the patient. Use this information to guide the bystander — e.g. if the radial pulse point (wrist) is visible, tell them to check pulse there. Reference the specific detected landmarks to give targeted instructions.
  SKIP DIRECTLY TO ASSESSMENT if the situation is obviously critical (e.g., not breathing, unresponsive, heavy bleeding).

PHASE 2 — CLINICAL ASSESSMENT:
  Summarize your findings. Commit to a working diagnosis with confidence percentage.
  State urgency level clearly. List 2-3 clinical findings that support the diagnosis.
  If you ask the user to check vitals (pulse, breathing, etc.), include steps with instruction + image_query for each check.
  If call_emergency = true, say "Call 911 immediately" as the FIRST sentence of spoken_text.
  Extract any vitals mentioned by the user (HR, RR, SpO2, GCS, temperature).

PHASE 3 — TREATMENT PROTOCOL:
  Provide evidence-based numbered steps. Each step must be:
  - Imperative sentence, maximum 12 words
  - Clinically specific (include timing, depth, rate, position where relevant)
  - Paired with an image_query that is the EXACT Wikipedia article title or a very specific anatomical term
  Maximum 8 steps. Final step: ask "What are you seeing now?"
  Good image_query examples: "Cardiopulmonary resuscitation", "Recovery position", "Abdominal thrusts", "Tourniquet", "Pulse", "Respiratory rate", "Head-tilt/chin-lift", "Automated external defibrillator"

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

When you ask the user to check something, always include steps so they see step-by-step images:
Example — you say "First check their pulse":
"steps": [{"instruction": "Place two fingers on the inner wrist below the thumb", "image_query": "Pulse"}, {"instruction": "Count the beats for 15 seconds and multiply by 4", "image_query": "Pulse"}]
Example — you say "Count their breaths per minute":
"steps": [{"instruction": "Watch their chest rise and fall for 30 seconds", "image_query": "Respiratory rate"}, {"instruction": "Count each breath (in + out = 1). Multiply by 2 for breaths per minute", "image_query": "Respiratory rate"}]

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


def _sanitize_spoken_text(result: dict[str, Any]) -> dict[str, Any]:
    """
    Fix cases where the LLM puts markdown / numbered steps inside spoken_text
    instead of the steps array.  Extracts a clean spoken sentence and recovers
    any embedded instructions into the steps array.
    """
    spoken: str = result.get("spoken_text", "")

    # Markers that indicate the model leaked structured content into spoken_text
    _MARKDOWN_MARKERS = ("##", "**", "- \"", "Image reference", "Step-by-step", "step-by-step")
    _NUMBERED_LINE = re.compile(r"^\s*\d+\.\s+\S")

    has_markdown = any(m in spoken for m in _MARKDOWN_MARKERS) or bool(
        _NUMBERED_LINE.search(spoken)
    )
    if not has_markdown:
        return result

    lines = spoken.splitlines()

    # First non-empty, non-markdown line becomes the spoken text
    clean_spoken = ""
    for line in lines:
        stripped = line.strip()
        if stripped and not stripped.startswith("#") and not stripped.startswith("-"):
            # Stop at the first numbered item or section header
            if _NUMBERED_LINE.match(stripped):
                break
            clean_spoken = stripped
            break

    # Limit to 35 words
    words = clean_spoken.split()
    result["spoken_text"] = " ".join(words[:35])

    # If steps are missing, try to recover them from the numbered list in spoken_text
    if not result.get("steps"):
        extracted: list[dict[str, Any]] = []

        # Collect image queries from "Image references" section
        image_queries: list[str] = []
        in_images = False
        for line in lines:
            stripped = line.strip()
            if "image reference" in stripped.lower():
                in_images = True
                continue
            if in_images:
                m = re.match(r'^[-•]\s*"?([^"]+)"?', stripped)
                if m:
                    image_queries.append(m.group(1).strip())
                elif stripped.startswith("#") or not stripped:
                    in_images = False

        # Extract numbered steps
        for line in lines:
            m = _NUMBERED_LINE.match(line)
            if m:
                instruction = re.sub(r"^\s*\d+\.\s+", "", line).strip()
                idx = len(extracted)
                image_query = image_queries[idx] if idx < len(image_queries) else ""
                extracted.append({"instruction": instruction, "image_query": image_query})

        if extracted:
            result["steps"] = extracted

    return result


def _parse_groq_response(resp: Any) -> dict[str, Any]:
    content = resp.choices[0].message.content or ""
    parsed = _parse_llm_json(content)
    if parsed and "spoken_text" in parsed:
        result = {
            "spoken_text": parsed.get("spoken_text", ""),
            "phase": parsed.get("phase", "questioning"),
            "steps": parsed.get("steps") or [],
            "vitals": parsed.get("vitals") or {},
            "metadata": parsed.get("metadata") or _default_metadata(),
        }
        return _sanitize_spoken_text(result)
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
