# GuideVR — Project Planning Document

This document serves as the single source of truth for the entire GuideVR project. Any teammate can read this and immediately understand the full project, their role, and how to get started.

---

## 1. Project Overview

- **Name**: GuideVR
- **One-liner**: An AI-powered spatial assistant that turns untrained community responders into confident first responders — and gives professionals a head start before they even arrive.
- **Problem**: In underserved communities, the gap between "something happened" and "help arrives" is where outcomes are decided. Most bystanders freeze because they lack training, not because they lack willingness.
- **Solution**: A VR/AR spatial assistant deployed on shared devices in schools, clinics, shelters, and community centers. The AI listens, coaches the user with voice + visual instructions, adapts in real time, and auto-generates a handoff report for arriving professionals.
- **Social Good Angle**: Expertise shouldn't be gatekept. We democratize real-time guidance for anyone, regardless of training or background.
- **Target Users**: School staff, community health workers, shelter employees, workplace safety officers, disaster response volunteers.

---

## 2. Features

List every feature with a brief description and priority (P0 = must have for demo, P1 = should have, P2 = nice to have):

### P0 - Core Features (MUST demo):
- **Voice conversation with AI** (speak → AI responds with guidance)
- **Spatial UI with floating panels** (HUD, images, transcript)
- **Adaptive AI that works for ANY scenario** (not hardcoded)
- **Instructional image retrieval and display**
- **Urgency detection and visual indicators**
- **Session recording and PDF report generation**

### P1 - Should Have:
- **Training/simulation mode with scoring**
- **Continuous listening mode** (not just push-to-talk)
- **Report auto-sent to first responders** (simulated)

### P2 - Nice to Have:
- **Multiple language support**
- **Session replay as web page**
- **Sound design** (chimes for urgency changes)
- **Landing screen with onboarding**

---

## 3. Architecture

Full system architecture:

```
┌─────────────────────────────────────────────────────┐
│                   visionOS Simulator                 │
│  ┌───────────────────────────────────────────────┐  │
│  │         WebSpatial React App (Frontend)        │  │
│  │                                                │  │
│  │  ┌──────────┐ ┌──────────┐ ┌───────────────┐  │  │
│  │  │ HUD Panel│ │Image Panel│ │Transcript Panel│ │  │
│  │  └──────────┘ └──────────┘ └───────────────┘  │  │
│  │  ┌──────────────┐  ┌────────────────────┐     │  │
│  │  │Control Panel  │  │ Voice Pipeline     │     │  │
│  │  └──────────────┘  │ (Mic → STT → TTS)  │     │  │
│  │                     └────────────────────┘     │  │
│  └──────────────────┬────────────────────────────┘  │
│                      │ WebSocket + REST              │
└──────────────────────┼──────────────────────────────┘
                       │
        ┌──────────────┴──────────────────┐
        │      FastAPI Backend (Python)    │
        │                                  │
        │  ┌────────────┐ ┌────────────┐  │
        │  │ LLM Service │ │  Session   │  │
        │  │(Anthropic/  │ │  Manager   │  │
        │  │ OpenAI)     │ │            │  │
        │  └────────────┘ └────────────┘  │
        │  ┌────────────┐ ┌────────────┐  │
        │  │   Image    │ │  Report    │  │
        │  │  Service   │ │ Generator  │  │
        │  └────────────┘ └────────────┘  │
        └─────────────────────────────────┘
                       │
        ┌──────────────┴──────────────────┐
        │         External APIs            │
        │  ElevenLabs │ OpenAI │ Google    │
        └─────────────────────────────────┘
```

---

## 4. Tech Stack

List every technology with version, what it's used for, and a link to docs:

### Frontend:
- **React 18+** (UI framework) - [React Docs](https://react.dev/)
- **TypeScript** (type safety) - [TypeScript Docs](https://www.typescriptlang.org/)
- **Vite** (build tool + dev server) - [Vite Docs](https://vitejs.dev/)
- **TailwindCSS** (styling) - [TailwindCSS Docs](https://tailwindcss.com/)
- **WebSpatial SDK** — `@webspatial/react-sdk`, `@webspatial/core-sdk` (spatial UI on visionOS) - [WebSpatial Docs](https://webspatial.dev/)
- **@webspatial/builder** (packaging for visionOS)
- **@webspatial/platform-visionos** (visionOS app shell)
- **@webspatial/vite-plugin** + `vite-plugin-html` (build integration)
- **Web Speech API** (browser-native STT fallback) - [MDN Web Speech API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Speech_API)
- **Web Audio API** (audio playback) - [MDN Web Audio API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)

### Backend:
- **Python 3.11+** (runtime) - [Python Docs](https://docs.python.org/3/)
- **FastAPI** (API framework) - [FastAPI Docs](https://fastapi.tiangolo.com/)
- **Uvicorn** (ASGI server) - [Uvicorn Docs](https://www.uvicorn.org/)
- **WebSockets** (real-time communication) - [FastAPI WebSockets](https://fastapi.tiangolo.com/advanced/websockets/)
- **httpx** (async HTTP client for external APIs) - [httpx Docs](https://www.python-httpx.org/)
- **python-dotenv** (environment variables) - [python-dotenv Docs](https://pypi.org/project/python-dotenv/)
- **ReportLab** (PDF generation) - [ReportLab Docs](https://www.reportlab.com/docs/reportlab-userguide.pdf)

### External APIs:
- **ElevenLabs** (text-to-speech, primary voice output) - [ElevenLabs API Docs](https://elevenlabs.io/docs)
- **OpenAI or Anthropic** (LLM for AI reasoning) - [OpenAI API](https://platform.openai.com/docs) | [Anthropic API](https://docs.anthropic.com/)
- **Google Custom Search API** (instructional image retrieval) - [Google Custom Search API](https://developers.google.com/custom-search/v1/overview)

### Dev Tools:
- **Xcode + visionOS Simulator** (testing spatial app) - [Apple Developer](https://developer.apple.com/xcode/)
- **Git + GitHub** (version control + collaboration) - [GitHub Docs](https://docs.github.com/)
- **npm/pnpm** (package management) - [npm Docs](https://docs.npmjs.com/)
- **pip** (Python package management) - [pip Docs](https://pip.pypa.io/)

---

## 5. File Structure

Complete planned file structure:

```
guidevr/
├── README.md
├── PLANNING.md
├── CONTRIBUTING.md
├── SETUP.md
├── .env.example
├── .gitignore
├── package.json
├── vite.config.ts
├── tsconfig.json
├── tsconfig.app.json
├── tsconfig.node.json
├── tailwind.config.js
├── manifest.json
├── index.html
│
├── src/
│   ├── App.tsx
│   ├── main.tsx
│   ├── index.css
│   │
│   ├── components/
│   │   ├── LandingScreen.tsx
│   │   ├── HUDPanel.tsx
│   │   ├── ImagePanel.tsx
│   │   ├── TranscriptPanel.tsx
│   │   ├── ControlPanel.tsx
│   │   ├── TrainingMode.tsx
│   │   └── TrainingResults.tsx
│   │
│   ├── context/
│   │   └── SessionContext.tsx
│   │
│   ├── services/
│   │   ├── api.ts
│   │   ├── voiceInput.ts
│   │   ├── voiceOutput.ts
│   │   └── voicePipeline.ts
│   │
│   ├── hooks/
│   │   ├── useVoicePipeline.ts
│   │   └── useSession.ts
│   │
│   ├── types/
│   │   └── index.ts
│   │
│   └── utils/
│       └── helpers.ts
│
├── backend/
│   ├── main.py
│   ├── run.py
│   ├── requirements.txt
│   │
│   └── services/
│       ├── llm_service.py
│       ├── image_service.py
│       ├── session_manager.py
│       └── report_generator.py
│
└── docs/
    ├── DEMO_SCRIPT.md
    └── API.md
```

---

## 6. API Contracts

Document every API endpoint and WebSocket message format so frontend and backend teams can work independently:

### WebSocket: `ws://localhost:8000/ws/session`

#### Client → Server:
```json
{ "type": "start_session", "mode": "live" | "training", "scenario"?: "string" }
{ "type": "utterance", "text": "user's spoken words", "timestamp": "ISO string" }
{ "type": "end_session" }
```

#### Server → Client:
```json
{ "type": "session_started", "session_id": "uuid" }
{ "type": "response", "text": "AI spoken text", "metadata": { "step": 1, "urgency": "medium", "image_query": "string|null", "category": "string", "display_text": "string" } }
{ "type": "training_complete", "score": { "overall": 85, "correct_actions": [], "missed_actions": [], "feedback": "string" } }
{ "type": "session_ended", "session_id": "uuid" }
{ "type": "error", "message": "string" }
```

### REST Endpoints

#### GET `/api/images?q={query}`
Response:
```json
{
  "image_url": "string",
  "caption": "string",
  "source": "string"
}
```

#### GET `/api/session/{session_id}`
Response:
```json
{
  "session_id": "string",
  "start_time": "ISO",
  "transcript": [...],
  "metadata": [...]
}
```

#### POST `/api/session/{session_id}/end`
Response:
```json
{
  "session_id": "string",
  "duration": 120,
  "summary": "string"
}
```

#### POST `/api/report/{session_id}/generate`
Response: PDF file download

---

## 7. Environment Variables

List every env var needed with description:

```
ELEVENLABS_API_KEY=       # ElevenLabs API key for TTS
ELEVENLABS_VOICE_ID=      # Voice ID (default: a calm, clear voice)
OPENAI_API_KEY=           # OpenAI API key (or ANTHROPIC_API_KEY)
LLM_PROVIDER=openai       # "openai" or "anthropic"
LLM_MODEL=gpt-4o          # Model to use
GOOGLE_SEARCH_API_KEY=    # Google Custom Search API key
GOOGLE_SEARCH_CX=         # Google Custom Search engine ID
BACKEND_URL=ws://localhost:8000  # Backend WebSocket URL
```

---

## 8. Team Workstreams

Define these independent workstreams that teammates can work on in parallel without blocking each other:

### Workstream A: Frontend — Spatial UI (branch: `feature/spatial-ui`)
**Owner**: [NAME]  
**Files**: `src/components/*`, `src/context/*`, `src/index.css`, `src/App.tsx`  
**Dependencies**: None (can use mock data)  
**Tasks**:
1. Build all spatial panel components (HUD, Image, Transcript, Control)
2. Set up WebSpatial scene initialization and panel positioning
3. Build LandingScreen component
4. Add urgency-based styling (color borders, animations)
5. Make panels responsive and readable in VR  
**Deliverable**: All panels render correctly in visionOS simulator with mock data

### Workstream B: Voice Pipeline (branch: `feature/voice-pipeline`)
**Owner**: [NAME]  
**Files**: `src/services/voiceInput.ts`, `src/services/voiceOutput.ts`, `src/services/voicePipeline.ts`, `src/hooks/useVoicePipeline.ts`  
**Dependencies**: None (can test with console.log instead of sending to backend)  
**Tasks**:
1. Set up microphone access and browser STT
2. Integrate ElevenLabs TTS streaming
3. Build the voice state machine (IDLE → LISTENING → PROCESSING → SPEAKING)
4. Build push-to-talk and continuous listening modes
5. Handle interruption (new response cancels old audio)  
**Deliverable**: User can speak, see their transcript logged, and hear a hardcoded response through ElevenLabs

### Workstream C: Backend — LLM + WebSocket (branch: `feature/backend-core`)
**Owner**: [NAME]  
**Files**: `backend/main.py`, `backend/services/llm_service.py`, `backend/services/session_manager.py`, `backend/run.py`  
**Dependencies**: None (can test with Postman/wscat)  
**Tasks**:
1. Set up FastAPI with WebSocket endpoint
2. Implement LLM service with the adaptive system prompt
3. Parse LLM JSON responses and extract metadata
4. Build session manager (store transcripts, metadata in memory)
5. Handle error cases (invalid JSON from LLM, connection drops)  
**Deliverable**: Can connect via wscat, send a message, get back a properly formatted AI response with metadata

### Workstream D: Backend — Images + Reports (branch: `feature/backend-services`)
**Owner**: [NAME]  
**Files**: `backend/services/image_service.py`, `backend/services/report_generator.py`  
**Dependencies**: Session manager from Workstream C (but can use mock session data)  
**Tasks**:
1. Build image retrieval endpoint with Google Custom Search
2. Add image caching
3. Build PDF report generator with ReportLab
4. Generate AI summary from transcript
5. Style the PDF professionally  
**Deliverable**: Can call image API and get results. Can generate a PDF from mock session data.

### Workstream E: Training Mode (branch: `feature/training-mode`)
**Owner**: [NAME]  
**Files**: `src/components/TrainingMode.tsx`, `src/components/TrainingResults.tsx`, + modifications to backend LLM prompt  
**Dependencies**: Workstream C (needs WebSocket + LLM working)  
**Tasks**:
1. Build training scenario selection UI
2. Add training mode system prompt to LLM service
3. Build scoring display component
4. Handle mode switching in SessionContext  
**Deliverable**: User can select a scenario, practice it, and see a score

### Integration Workstream (branch: `feature/integration`)
**Owner**: Whoever finishes first, or the team lead  
**Files**: `src/services/api.ts`, `src/context/SessionContext.tsx`, `src/App.tsx`  
**Dependencies**: All other workstreams  
**Tasks**:
1. Wire frontend WebSocket to backend
2. Connect voice pipeline output → WebSocket → LLM → voice pipeline input
3. Connect image responses to ImagePanel
4. Connect session end to report generation
5. End-to-end testing
