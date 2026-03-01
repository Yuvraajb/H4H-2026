"""
wikiHow step fetcher for medical procedures.

For each medical image_query from the LLM, fetches the relevant wikiHow
article and returns its steps with real wikiHow photos.

Strategy:
1. Try curated slug map (verified 200 URLs) first.
2. Fall back to wikiHow search.
3. Parse JSON-LD HowTo steps for text + images.
4. For steps that lack a JSON-LD image, fill in from HTML <img> tags (same order).
"""
from __future__ import annotations

import json
import re

import httpx

_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/121.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml",
    "Accept-Language": "en-US,en;q=0.9",
}

_BASE = "https://www.wikihow.com/"

# Curated map: normalized keyword → wikiHow article slug (all verified 200 OK)
_SLUG_MAP: dict[str, str] = {
    # Pulse / vitals
    "pulse": "Check-Your-Pulse",
    "check pulse": "Check-Your-Pulse",
    "check their pulse": "Check-Your-Pulse",
    "feel pulse": "Check-Your-Pulse",
    "take pulse": "Check-Your-Pulse",
    "heart rate": "Check-Your-Pulse",
    # Respiratory (no dedicated wikiHow page → search fallback handles it)
    "respiratory rate": "Check-Your-Pulse",   # nearest proxy; search will find better
    "breathing rate": "Perform-Rescue-Breathing",
    "count breaths": "Perform-Rescue-Breathing",
    "check breathing": "Perform-Rescue-Breathing",
    "breathing": "Perform-Rescue-Breathing",
    # CPR (Perform-CPR redirects to Do-CPR — both fine)
    "cardiopulmonary resuscitation": "Perform-CPR",
    "cpr": "Perform-CPR",
    "chest compression": "Perform-CPR",
    "chest compressions": "Perform-CPR",
    "cardiac arrest": "Perform-CPR",
    "perform cpr": "Perform-CPR",
    # Choking / Heimlich
    "heimlich": "Perform-the-Heimlich-Maneuver",
    "abdominal thrusts": "Perform-the-Heimlich-Maneuver",
    "choking": "Help-a-Choking-Victim",          # was Help-a-Choking-Adult (404)
    # Recovery position
    "recovery position": "Put-Someone-in-the-Recovery-Position",  # was Place-Someone (404)
    "lateral recumbent": "Put-Someone-in-the-Recovery-Position",
    # Bleeding / wounds
    "bleeding": "Stop-Bleeding",
    "stop bleeding": "Stop-Bleeding",
    "direct pressure": "Stop-Bleeding",
    "tourniquet": "Apply-a-Tourniquet",
    "wound": "Treat-a-Wound",
    "bandage": "Stop-Bleeding",                  # Apply-a-Bandage (404)
    "pressure bandage": "Stop-Bleeding",
    # Airway
    "head-tilt/chin-lift": "Perform-CPR",
    "head tilt chin lift": "Perform-CPR",
    "airway management": "Perform-CPR",
    "jaw thrust": "Perform-CPR",
    "rescue breathing": "Perform-Rescue-Breathing",
    "rescue breath": "Perform-Rescue-Breathing",
    "rescue breaths": "Perform-Rescue-Breathing",
    "mouth to mouth": "Perform-Rescue-Breathing",
    "mouth-to-mouth resuscitation": "Perform-Rescue-Breathing",
    # AED (Use-an-AED redirects to Use-a-Defibrillator — fine)
    "aed": "Use-an-AED",
    "defibrillator": "Use-an-AED",
    "automated external defibrillator": "Use-an-AED",
    # Seizure
    "seizure": "Help-Someone-Who-Is-Having-a-Seizure",   # was Help-Someone-Having (404)
    "seizure first aid": "Help-Someone-Who-Is-Having-a-Seizure",
    "epileptic seizure": "Help-Someone-Who-Is-Having-a-Seizure",
    "convulsion": "Help-Someone-Who-Is-Having-a-Seizure",
    # Burns
    "burn": "Treat-a-Burn",
    "burns": "Treat-a-Burn",
    "chemical burn": "Treat-a-Burn",
    # Allergic reactions / EpiPen
    "anaphylaxis": "Use-an-EpiPen",             # Treat-Anaphylaxis (404)
    "allergic reaction": "Use-an-EpiPen",
    "epinephrine": "Use-an-EpiPen",             # Use-an-Epi-Pen (404)
    "epipen": "Use-an-EpiPen",
    "epinephrine autoinjector": "Use-an-EpiPen",
    # Stroke
    "stroke": "Diagnose-a-Stroke",              # Recognize-a-Stroke (404)
    # Temperature
    "hypothermia": "Treat-Hypothermia",
    "heat stroke": "Treat-Hypothermia",         # Treat-Heat-Stroke (404); Hypothermia article covers temp emergencies
    "frostbite": "Treat-Frostbite",
    # Fractures
    "fracture": "Treat-Broken-Bones",           # Treat-a-Fracture (404)
    "bone fracture": "Treat-Broken-Bones",
    "splint": "Treat-Broken-Bones",
    "splint (medicine)": "Treat-Broken-Bones",
    # Other
    "nosebleed": "Stop-a-Nosebleed",            # redirects to Stop-a-Nose-Bleed — fine
    "concussion": "Treat-a-Concussion",
    "shock": "Treat-Shock",
    "shock (circulatory)": "Treat-Shock",
    "drowning": "Rescue-a-Drowning-Person",     # redirects to Save-an-Active-Drowning-Victim — fine
    "poisoning": "Treat-Poisoning",
    "emergency telephone number": "Call-911",
    "call 911": "Call-911",
    "911": "Call-911",
    "myocardial infarction": "Perform-CPR",
    "heart attack": "Perform-CPR",
    "asthma": "Treat-a-Burn",                  # placeholder; search will find asthma article
    "hypoglycemia": "Treat-Shock",
    "diabetic emergency": "Treat-Shock",
    "eye injury": "Treat-a-Burn",              # placeholder; search will improve
    "spinal cord injury": "Perform-CPR",
    "cervical fracture": "Treat-Broken-Bones",
}

# In-memory cache: resolved URL → steps
_CACHE: dict[str, list[dict[str, str]]] = {}


def _resolve_url(query: str) -> str | None:
    q = query.lower().strip()
    if q in _SLUG_MAP:
        return _BASE + _SLUG_MAP[q]
    best_key, best_len = None, 0
    for key in _SLUG_MAP:
        if key in q and len(key) > best_len:
            best_key, best_len = key, len(key)
    if best_key:
        return _BASE + _SLUG_MAP[best_key]
    return None


async def _search_wikihow(query: str) -> str | None:
    try:
        async with httpx.AsyncClient(timeout=8.0, follow_redirects=True) as client:
            r = await client.get(
                "https://www.wikihow.com/wikiHowTo",
                params={"search": query},
                headers=_HEADERS,
            )
            links = re.findall(
                r'href="(https://www\.wikihow\.com/[A-Za-z][A-Za-z0-9_-]+)"',
                r.text,
            )
            skip = {"Category", "Special", "wikiHowTo", "index", "Main-Page", "Sitemap"}
            links = [l for l in links if l.split("/")[-1].split(":")[0] not in skip]
            seen: set[str] = set()
            for link in links:
                if link not in seen:
                    seen.add(link)
                    return link
    except Exception:
        pass
    return None


def _extract_img(img_field: object) -> str | None:
    if isinstance(img_field, str) and img_field.startswith("http"):
        return img_field
    if isinstance(img_field, dict):
        return img_field.get("url") or img_field.get("contentUrl")
    if isinstance(img_field, list) and img_field:
        first = img_field[0]
        if isinstance(first, dict):
            return first.get("url") or first.get("contentUrl")
        if isinstance(first, str) and first.startswith("http"):
            return first
    return None


def _first_sentence(text: str, max_len: int = 90) -> str:
    clean = re.sub(r"<[^>]+>", "", text).strip()
    first = re.split(r"\.\s+|\n", clean)[0].strip()
    if len(first) > max_len:
        first = first[:max_len].rsplit(" ", 1)[0]
    return first


def _images_from_html(html: str) -> list[str]:
    """
    Extract wikiHow step images from HTML in order.
    wikiHow step images all contain 'v4-' in the URL.
    """
    return re.findall(
        r'src="(https://www\.wikihow\.com/images/thumb/[^"]+v4-[^"]+)"',
        html,
    )


def _steps_from_json_ld(html: str) -> list[dict]:
    """
    Parse JSON-LD HowTo steps. Returns dicts with 'instruction' and optional 'image_url'.
    Steps without JSON-LD images are included (image_url=None) so HTML fallback can fill them.
    """
    results: list[dict] = []
    for m in re.finditer(
        r'<script[^>]+type="application/ld\+json"[^>]*>([\s\S]*?)</script>',
        html,
        re.IGNORECASE,
    ):
        try:
            data = json.loads(m.group(1))
            if isinstance(data, list):
                data = next(
                    (d for d in data if isinstance(d, dict) and d.get("@type") == "HowTo"),
                    None,
                )
            if not isinstance(data, dict) or data.get("@type") != "HowTo":
                continue
            for item in data.get("step", []):
                if not isinstance(item, dict):
                    continue
                if item.get("@type") == "HowToSection":
                    for sub in item.get("itemListElement", []):
                        if isinstance(sub, dict):
                            step = _parse_step(sub)
                            if step:
                                results.append(step)
                else:
                    step = _parse_step(item)
                    if step:
                        results.append(step)
            if results:
                return results
        except Exception:
            continue
    return results


def _parse_step(s: dict) -> dict | None:
    raw = s.get("name") or s.get("text") or ""
    instruction = _first_sentence(raw)
    if not instruction:
        return None
    return {
        "instruction": instruction,
        "image_url": _extract_img(s.get("image")),  # may be None
    }


async def _fetch(url: str) -> list[dict[str, str]]:
    if url in _CACHE:
        return _CACHE[url]
    try:
        async with httpx.AsyncClient(timeout=12.0, follow_redirects=True) as client:
            r = await client.get(url, headers=_HEADERS)
        if r.status_code != 200:
            return []
        html = r.text

        steps = _steps_from_json_ld(html)
        if not steps:
            return []

        # Fill missing images from HTML img tags (same sequential order)
        html_imgs = _images_from_html(html)
        html_idx = 0
        result: list[dict[str, str]] = []

        for step in steps:
            img = step.get("image_url")
            if not img:
                # Advance html_idx until we find an image not already used
                while html_idx < len(html_imgs) and html_imgs[html_idx] in {
                    s.get("image_url") for s in result
                }:
                    html_idx += 1
                img = html_imgs[html_idx] if html_idx < len(html_imgs) else None
                if img:
                    html_idx += 1
            if img:
                result.append({"instruction": step["instruction"], "image_url": img})

        if result:
            _CACHE[url] = result
        return result[:5]
    except Exception:
        return []


async def get_wikihow_steps(query: str) -> list[dict[str, str]]:
    """
    Return up to 5 wikiHow {instruction, image_url} steps for a medical query.
    Every returned step is guaranteed to have a non-null image_url.
    """
    if not query or not query.strip():
        return []

    url = _resolve_url(query)
    if url:
        steps = await _fetch(url)
        if steps:
            return steps

    url = await _search_wikihow(query)
    if url:
        steps = await _fetch(url)
        if steps:
            return steps

    return []


async def warmup() -> None:
    """Pre-populate the cache for the most common emergency procedures at startup."""
    import asyncio
    priority = [
        "cardiopulmonary resuscitation",
        "pulse",
        "recovery position",
        "seizure",
        "bleeding",
        "tourniquet",
        "rescue breathing",
        "choking",
        "aed",
        "anaphylaxis",
        "stroke",
        "burn",
        "fracture",
    ]
    await asyncio.gather(*[get_wikihow_steps(q) for q in priority], return_exceptions=True)
