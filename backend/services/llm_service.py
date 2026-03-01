"""
LLM integration for Crisis Copilot. Supports OpenAI, Anthropic, Gemini, and Groq.
Returns structured JSON: spoken_text + metadata (step, urgency, image_query, category, display_text).
"""
from __future__ import annotations

import json
import os
import re
from typing import Any

SYSTEM_PROMPT = """You are Crisis Copilot, a calm and knowledgeable AI assistant that helps people through real-life emergencies in real time. You are their co-pilot — an experienced, steady presence.

BEHAVIOR:
- Quickly understand the situation from the user's description (1-2 clarifying questions MAX, then start helping immediately).
- Give short, actionable, step-by-step guidance. Each response should be 1-3 sentences that can be spoken aloud in under 15 seconds.
- Adapt your tone based on urgency:
  * Critical (life-threatening): Direct, commanding, no filler. "Do this now."
  * High (serious but not immediate death): Urgent but calm. Clear instructions.
  * Medium (needs attention): Supportive and structured. Walk them through it.
  * Low (informational/emotional): Warm, patient, conversational.
- Continuously check in: "What's happening now?" "Did that help?" "What do you see?"
- If the situation is medical and serious, tell them to call 911 immediately while you guide them through what to do while waiting.
- Know when you're out of your depth. Say "a professional needs to handle this" when appropriate.
- Never diagnose. Never give legal advice. Always frame as guidance.
- Remember: the user is stressed, possibly panicking. Short sentences. Simple words. Repeat important instructions if needed.

RESPONSE FORMAT:
You must respond with valid JSON only. No markdown, no extra text.
{
  "spoken_text": "What you say out loud to the user (1-3 sentences, conversational)",
  "metadata": {
    "step": 1,
    "urgency": "low" | "medium" | "high" | "critical",
    "image_query": "short search query for a helpful instructional image, or null if no image needed",
    "category": "medical" | "mental_health" | "safety" | "technical" | "social" | "environmental" | "other",
    "display_text": "short 1-line instruction for the HUD, max 10 words"
  }
}
"""


def _parse_llm_json(content: str) -> dict[str, Any] | None:
    """Extract JSON from LLM response (may be wrapped in markdown or have extra text)."""
    content = content.strip()
    # Try to find JSON block
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


async def get_response(messages: list[dict[str, str]]) -> dict[str, Any]:
    """
    Send conversation history to LLM and return parsed { spoken_text, metadata }.
    messages: list of { "role": "user"|"assistant"|"system", "content": "..." }
    """
    provider = os.getenv("LLM_PROVIDER", "groq").lower()

    if provider == "anthropic":
        return await _get_response_anthropic(messages)
    if provider == "gemini":
        return await _get_response_gemini(messages)
    if provider == "groq":
        return await _get_response_groq(messages)
    return await _get_response_openai(messages)


async def _get_response_openai(messages: list[dict[str, str]]) -> dict[str, Any]:
    from openai import AsyncOpenAI
    client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))
    model = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
    full = [{"role": "system", "content": SYSTEM_PROMPT}] + [
        {"role": m["role"], "content": m["content"]} for m in messages
    ]
    resp = await client.chat.completions.create(
        model=model,
        messages=full,
        max_tokens=500,
    )
    content = resp.choices[0].message.content or ""
    parsed = _parse_llm_json(content)
    if parsed and "spoken_text" in parsed:
        return {
            "spoken_text": parsed.get("spoken_text", ""),
            "metadata": parsed.get("metadata") or _default_metadata(),
        }
    return {
        "spoken_text": content[:500] if content else "I'm here. What's happening now?",
        "metadata": _default_metadata(),
    }


async def _get_response_anthropic(messages: list[dict[str, str]]) -> dict[str, Any]:
    from anthropic import AsyncAnthropic
    client = AsyncAnthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
    model = os.getenv("ANTHROPIC_MODEL", "claude-3-5-haiku-20241022")
    system = SYSTEM_PROMPT
    # Anthropic expects alternating user/assistant; skip system in messages
    api_messages = []
    for m in messages:
        role = m.get("role", "user")
        if role == "system":
            continue
        if role == "assistant":
            role = "assistant"
        else:
            role = "user"
        api_messages.append({"role": role, "content": m.get("content", "")})
    resp = await client.messages.create(
        model=model,
        max_tokens=500,
        system=system,
        messages=api_messages,
    )
    content = (resp.content[0].text if resp.content else "") or ""
    parsed = _parse_llm_json(content)
    if parsed and "spoken_text" in parsed:
        return {
            "spoken_text": parsed.get("spoken_text", ""),
            "metadata": parsed.get("metadata") or _default_metadata(),
        }
    return {
        "spoken_text": content[:500] if content else "I'm here. What's happening now?",
        "metadata": _default_metadata(),
    }


async def _get_response_groq(messages: list[dict[str, str]]) -> dict[str, Any]:
    """Groq is OpenAI-compatible; use OpenAI client with Groq base URL."""
    from openai import AsyncOpenAI
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        return {"spoken_text": "Configure GROQ_API_KEY in backend/.env", "metadata": _default_metadata()}
    model = os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile")
    client = AsyncOpenAI(base_url="https://api.groq.com/openai/v1", api_key=api_key)
    full = [{"role": "system", "content": SYSTEM_PROMPT}] + [
        {"role": m["role"], "content": m["content"]} for m in messages
    ]
    try:
        resp = await client.chat.completions.create(
            model=model,
            messages=full,
            max_tokens=500,
            temperature=0.3,
        )
        content = resp.choices[0].message.content or ""
    except Exception as e:
        raise RuntimeError(f"Groq API error: {e!s}")
    parsed = _parse_llm_json(content)
    if parsed and "spoken_text" in parsed:
        return {
            "spoken_text": parsed.get("spoken_text", ""),
            "metadata": parsed.get("metadata") or _default_metadata(),
        }
    return {
        "spoken_text": content[:500] if content else "I'm here. What's happening now?",
        "metadata": _default_metadata(),
    }


async def _get_response_gemini(messages: list[dict[str, str]]) -> dict[str, Any]:
    import httpx
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        return {"spoken_text": "Configure GEMINI_API_KEY.", "metadata": _default_metadata()}
    model = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
    # Build prompt: system + conversation
    parts = [SYSTEM_PROMPT + "\n\nConversation:\n"]
    for m in messages:
        role = m.get("role", "user")
        parts.append(f"{role.upper()}: {m.get('content', '')}\n")
    parts.append("ASSISTANT: ")
    prompt = "".join(parts)
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"maxOutputTokens": 500, "temperature": 0.3},
    }
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.post(url, json=payload)
        if resp.status_code != 200:
            try:
                err_body = resp.json()
                msg = err_body.get("error", {}).get("message", resp.text[:200])
            except Exception:
                msg = resp.text[:200] if resp.text else f"HTTP {resp.status_code}"
            raise RuntimeError(f"Gemini API error: {msg}")
        data = resp.json()
    text = ""
    for c in data.get("candidates", []):
        for p in c.get("content", {}).get("parts", []):
            text += p.get("text", "")
    parsed = _parse_llm_json(text)
    if parsed and "spoken_text" in parsed:
        return {
            "spoken_text": parsed.get("spoken_text", ""),
            "metadata": parsed.get("metadata") or _default_metadata(),
        }
    return {
        "spoken_text": text[:500] if text else "I'm here. What's happening now?",
        "metadata": _default_metadata(),
    }


def _default_metadata() -> dict[str, Any]:
    return {
        "step": 1,
        "urgency": "medium",
        "image_query": None,
        "category": "other",
        "display_text": "Continue as needed.",
    }
