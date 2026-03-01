"""
Fetch an instructional image from the web using the AI's image_query.
Uses Google Custom Search (image search) when configured; fetches the first result and returns bytes.
"""
from __future__ import annotations

import os
from typing import Tuple

import httpx

# Google Custom Search: https://developers.google.com/custom-search/v1/overview
# Create a Programmable Search Engine with "Search the entire web" and enable Image search.
GOOGLE_CSE_URL = "https://www.googleapis.com/customsearch/v1"


async def get_step_image(image_query: str) -> Tuple[bytes, str] | None:
    """
    Search the web for an image matching image_query, fetch it, return (bytes, content_type).
    Returns None if search/fetch fails or API keys are not set.
    """
    api_key = os.getenv("GOOGLE_CSE_API_KEY") or os.getenv("GOOGLE_API_KEY")
    cse_id = os.getenv("GOOGLE_CSE_ID")
    if not api_key or not cse_id:
        return None

    query = (image_query or "").strip()
    if not query:
        return None

    async with httpx.AsyncClient(timeout=15.0) as client:
        # Image search
        resp = await client.get(
            GOOGLE_CSE_URL,
            params={
                "key": api_key,
                "cx": cse_id,
                "q": query,
                "searchType": "image",
                "num": 1,
                "alt": "json",
            },
        )
        if resp.status_code != 200:
            return None
        data = resp.json()
        items = data.get("items") or []
        if not items:
            return None
        image_url = items[0].get("link") or items[0].get("image", {}).get("contextLink")
        if not image_url:
            return None

        # Fetch the image from the web
        img_resp = await client.get(image_url)
        if img_resp.status_code != 200:
            return None
        content_type = img_resp.headers.get("content-type", "image/jpeg").split(";")[0].strip()
        if not content_type.startswith("image/"):
            content_type = "image/jpeg"
        return (img_resp.content, content_type)
