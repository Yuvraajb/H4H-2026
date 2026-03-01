# Survivor MVP / Crisis Copilot

visionOS app (Apple Vision Pro) with a Python backend for chat (LLM) and TTS.

## Run order

### 1. Start the backend

```bash
cd backend
pip install -r requirements.txt   # first time only
cp .env.example .env              # first time only; then edit .env with your API keys
python3 run.py
```

Leave this terminal open. You should see: `Uvicorn running on http://0.0.0.0:8000` and `[Crisis Copilot] LLM_PROVIDER=groq, GROQ_API_KEY set=True` (or your provider).

### 2. Run the app in Xcode

1. Open **`Survivor MVP.xcodeproj`** in Xcode.
2. Select the **Survivor MVP** scheme.
3. Choose a destination (e.g. **Apple Vision Pro** or **Any visionOS Simulator Device**).
4. Press **Run** (⌘R).

The app talks to the backend at `http://127.0.0.1:8000`. No extra config needed for the simulator.

### Physical device

If you run the app on a real Vision Pro, the device must reach your Mac’s backend:

1. Find your Mac’s IP (e.g. System Settings → Network).
2. In the app target, set `BackendService.deviceBaseURLOverride` (e.g. in `BackendService.swift` or via a build flag) to `"http://YOUR_MAC_IP:8000"`.
3. Keep the backend running on your Mac with `python3 run.py` (it already binds to `0.0.0.0:8000`).

## Backend API keys (.env)

| Variable | Required for | Notes |
|----------|----------------|-------|
| `LLM_PROVIDER` | Chat | `groq`, `openai`, `anthropic`, or `gemini` |
| `GROQ_API_KEY` | Chat (when using groq) | From [console.groq.com](https://console.groq.com) |
| `ELEVENLABS_API_KEY` | TTS (voice) | From [elevenlabs.io](https://elevenlabs.io). If missing or invalid, chat still works; voice will show an error. If you get **401 Unauthorized** from TTS, regenerate the key at [ElevenLabs API keys](https://elevenlabs.io/app/settings/api-keys) and update `backend/.env`. |

Other providers: set the matching key (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`) and `LLM_PROVIDER`.

| `GOOGLE_CSE_ID` + `GOOGLE_CSE_API_KEY` | Step images (right panel) | [Programmable Search Engine](https://programmablesearchengine.google.com/) with **Image search** enabled. If unset, steps still show but without images. |

## Quick checks

- **Backend health:** `curl http://127.0.0.1:8000/health` → `{"status":"ok"}`
- **Chat:** `curl -X POST http://127.0.0.1:8000/api/chat -H "Content-Type: application/json" -d '{"message":"Hi"}'`

If the app says the backend is unreachable, make sure the backend is running and you’re using the simulator (or set `deviceBaseURLOverride` on device).
