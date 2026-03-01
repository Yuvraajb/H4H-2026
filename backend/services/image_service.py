"""
Medical image lookup with curated Wikipedia article mapping.
Uses exact article titles for known procedures (accurate results),
falls back to Wikipedia search for unknown terms.
"""
from __future__ import annotations
import httpx
import re

_HEADERS = {
    "User-Agent": "PersonalDoctorApp/1.0 (medical-assistant; contact@example.com)",
    "Accept": "application/json",
}

# Curated map: normalized keyword → exact Wikipedia article title
# These articles are confirmed to have good thumbnail images.
_ARTICLE_MAP: dict[str, str] = {
    # CPR / Cardiac
    "cardiopulmonary resuscitation": "Cardiopulmonary resuscitation",
    "cpr": "Cardiopulmonary resuscitation",
    "chest compression": "Cardiopulmonary resuscitation",
    "chest compressions": "Cardiopulmonary resuscitation",
    "hand on chest": "Cardiopulmonary resuscitation",
    "center of chest": "Cardiopulmonary resuscitation",
    "heel of hand": "Cardiopulmonary resuscitation",
    "cardiac arrest": "Cardiac arrest",
    "heart attack": "Myocardial infarction",
    "myocardial infarction": "Myocardial infarction",
    "aed": "Automated external defibrillator",
    "defibrillator": "Automated external defibrillator",
    "automated external defibrillator": "Automated external defibrillator",
    "pulse check": "Pulse",
    "check pulse": "Pulse",
    "take pulse": "Pulse",
    "feel pulse": "Pulse",
    "check their pulse": "Pulse",
    "pulse": "Pulse",
    # Breathing / Respiratory
    "respiratory rate": "Respiratory rate",
    "check respiratory rate": "Respiratory rate",
    "count breaths": "Respiratory rate",
    "count breathing": "Respiratory rate",
    "breathing rate": "Respiratory rate",
    "check breathing": "Breathing",
    "check if they are breathing": "Breathing",
    "look listen feel": "Breathing",
    "rescue breath": "Rescue breathing",
    "rescue breaths": "Rescue breathing",
    # Airway
    "rescue breathing": "Rescue breathing",
    "mouth to mouth": "Mouth-to-mouth resuscitation",
    "mouth-to-mouth": "Mouth-to-mouth resuscitation",
    "head tilt chin lift": "Head-tilt/chin-lift",
    "head-tilt/chin-lift": "Head-tilt/chin-lift",
    "airway management": "Airway management",
    "jaw thrust": "Jaw thrust",
    "nasopharyngeal airway": "Nasopharyngeal airway",
    # Choking
    "abdominal thrusts": "Abdominal thrusts",
    "heimlich maneuver": "Abdominal thrusts",
    "heimlich": "Abdominal thrusts",
    "choking": "Choking",
    "back blow": "Choking",
    "back blows": "Choking",
    # Bleeding / Wounds
    "tourniquet": "Tourniquet",
    "direct pressure": "Bleeding",
    "bleeding": "Bleeding",
    "wound": "Wound",
    "wound care": "Wound",
    "bandage": "Bandage",
    "pressure bandage": "Pressure bandage",
    "hemostasis": "Hemostasis",
    # Burns
    "burn": "Burn",
    "burns": "Burn",
    "burn treatment": "Burn",
    "chemical burn": "Chemical burn",
    # Fractures / Trauma
    "splint": "Splint (medicine)",
    "splinting": "Splint (medicine)",
    "fracture": "Bone fracture",
    "bone fracture": "Bone fracture",
    "spinal injury": "Spinal cord injury",
    "cervical collar": "Cervical collar",
    "neck injury": "Cervical fracture",
    # Positioning
    "recovery position": "Recovery position",
    "lateral recumbent": "Recovery position",
    # Allergic reactions
    "anaphylaxis": "Anaphylaxis",
    "epinephrine": "Epinephrine autoinjector",
    "epinephrine autoinjector": "Epinephrine autoinjector",
    "epipen": "Epinephrine autoinjector",
    "allergic reaction": "Anaphylaxis",
    # Seizures
    "seizure": "Seizure first aid",
    "seizure first aid": "Seizure first aid",
    "epileptic seizure": "Epileptic seizure",
    "convulsion": "Epileptic seizure",
    # Stroke
    "stroke": "Stroke",
    "fast stroke": "Stroke",
    "facial droop": "Stroke",
    # Other emergencies
    "heat stroke": "Heat stroke",
    "hyperthermia": "Hyperthermia",
    "hypothermia": "Hypothermia",
    "frostbite": "Frostbite",
    "poisoning": "Poisoning",
    "nosebleed": "Nosebleed",
    "epistaxis": "Nosebleed",
    "eye injury": "Eye injury",
    "diabetic emergency": "Diabetic emergency",
    "hypoglycemia": "Hypoglycemia",
    "asthma attack": "Asthma",
    "asthma": "Asthma",
    "drowning": "Drowning",
    "shock": "Shock (circulatory)",
    "anaphylactic shock": "Anaphylaxis",
    "concussion": "Concussion",
    "head injury": "Head injury",
    "emergency telephone": "Emergency telephone number",
    "call 911": "Emergency telephone number",
    "911": "Emergency telephone number",
}


def derive_image_query_from_instruction(instruction: str) -> str:
    """Derive a Wikipedia image search query from a step instruction when the LLM omits image_query."""
    if not instruction or not instruction.strip():
        return ""
    text = instruction.strip()
    article = _match_article(text)
    if article:
        return article
    # Use first few words as search query (Wikipedia search will add "medical procedure first aid")
    words = text.split()[:6]
    return " ".join(words) if words else text


def _match_article(query: str) -> str | None:
    """Return exact Wikipedia article title if query matches a known procedure."""
    q = query.lower().strip()
    # Exact match
    if q in _ARTICLE_MAP:
        return _ARTICLE_MAP[q]
    # Substring match — find the longest key that appears in the query
    best_key = None
    best_len = 0
    for key, article in _ARTICLE_MAP.items():
        if key in q and len(key) > best_len:
            best_key = key
            best_len = len(key)
    if best_key:
        return _ARTICLE_MAP[best_key]
    # Reverse: does any key word appear in query tokens?
    tokens = set(re.split(r"[\s/\-]+", q))
    for key, article in _ARTICLE_MAP.items():
        key_tokens = set(re.split(r"[\s/\-]+", key))
        if len(key_tokens) == 1 and key_tokens & tokens:
            return article
    return None


async def _fetch_thumbnail(title: str, client: httpx.AsyncClient) -> str | None:
    """Fetch thumbnail URL directly from Wikipedia page summary."""
    try:
        import urllib.parse
        encoded = urllib.parse.quote(title, safe="")
        r = await client.get(
            f"https://en.wikipedia.org/api/rest_v1/page/summary/{encoded}",
            headers=_HEADERS,
        )
        data = r.json()
        return data.get("thumbnail", {}).get("source") or data.get("originalimage", {}).get("source")
    except Exception:
        return None


async def get_image_url(query: str) -> str | None:
    if not query or not query.strip():
        return None
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            # 1. Try curated exact-title lookup first (most accurate)
            article = _match_article(query)
            if article:
                url = await _fetch_thumbnail(article, client)
                if url:
                    return url

            # 2. Fall back to Wikipedia search API
            r = await client.get(
                "https://en.wikipedia.org/w/api.php",
                params={
                    "action": "query",
                    "list": "search",
                    "srsearch": query + " medical procedure first aid",
                    "srlimit": 3,
                    "format": "json",
                },
                headers=_HEADERS,
            )
            results = r.json().get("query", {}).get("search", [])
            for result in results:
                url = await _fetch_thumbnail(result["title"], client)
                if url:
                    return url

    except Exception:
        pass
    return None
