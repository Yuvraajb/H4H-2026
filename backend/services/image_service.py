"""
Wikipedia image search — no API key required.
Searches Wikipedia for a query, returns a thumbnail URL or None.
"""
import httpx


_HEADERS = {
    "User-Agent": "PersonalDoctorApp/1.0 (medical-assistant; contact@example.com)",
    "Accept": "application/json",
}


async def get_image_url(query: str) -> str | None:
    try:
        async with httpx.AsyncClient(timeout=8.0, headers=_HEADERS) as client:
            # Step 1: find the best-matching Wikipedia article title
            r = await client.get(
                "https://en.wikipedia.org/w/api.php",
                params={
                    "action": "query",
                    "list": "search",
                    "srsearch": query,
                    "srlimit": 1,
                    "format": "json",
                },
            )
            results = r.json().get("query", {}).get("search", [])
            if not results:
                return None
            title = results[0]["title"]

            # Step 2: get page summary → thumbnail URL
            r2 = await client.get(
                f"https://en.wikipedia.org/api/rest_v1/page/summary/{title}",
            )
            return r2.json().get("thumbnail", {}).get("source")
    except Exception:
        return None
