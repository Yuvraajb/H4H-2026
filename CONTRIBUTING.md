# Contributing to GuideVR

## Getting Started
1. Clone the repo: `git clone https://github.com/Yuvraajb/H4H-2026.git`
2. Install frontend deps: `npm install`
3. Install backend deps: `cd backend && pip install -r requirements.txt`
4. Copy `.env.example` to `.env` and fill in your API keys
5. Check PLANNING.md for the full project overview and your assigned workstream

## Branch Strategy
We use feature branches that merge into `main` via pull requests.

### Branch Naming
- `feature/spatial-ui` — Workstream A
- `feature/voice-pipeline` — Workstream B
- `feature/backend-core` — Workstream C
- `feature/backend-services` — Workstream D
- `feature/training-mode` — Workstream E
- `feature/integration` — Final wiring
- `fix/[description]` — Bug fixes
- `hotfix/[description]` — Urgent fixes to main

### Workflow
1. Pull latest main: `git checkout main && git pull`
2. Create your branch: `git checkout -b feature/[your-workstream]`
3. Work on your files ONLY (see PLANNING.md for file ownership)
4. Commit often with clear messages: `git commit -m "feat: add HUD panel component"`
5. Push your branch: `git push origin feature/[your-workstream]`
6. Create a Pull Request when your workstream deliverable is complete
7. Get at least one teammate to review before merging
8. After merge, pull main and rebase your branch if continuing work

### Commit Message Format
- `feat: [description]` — new feature
- `fix: [description]` — bug fix
- `docs: [description]` — documentation
- `refactor: [description]` — code restructuring
- `style: [description]` — formatting, styling
- `test: [description]` — adding tests

### Avoiding Merge Conflicts
Each workstream owns specific files. DO NOT edit files outside your workstream without coordinating with the owner. The file ownership is listed in PLANNING.md under each workstream.

Shared files that multiple people may need to touch (coordinate before editing):
- `src/App.tsx` (mainly Integration workstream)
- `src/context/SessionContext.tsx` (mainly Integration workstream)
- `src/types/index.ts` (anyone can add types, but don't modify existing ones)
- `backend/main.py` (mainly Workstream C, then Integration)

### Running the Project
```bash
# Terminal 1: Backend
cd backend && python run.py

# Terminal 2: Frontend (regular web for quick testing)
npm run dev

# Terminal 3: Frontend (WebSpatial for visionOS)
XR_ENV=avp npm run dev

# Terminal 4: Launch visionOS simulator
npx webspatial-builder run --base=http://localhost:5175/webspatial/avp
```

### Testing Your Workstream in Isolation
- **Frontend (A):** Use mock data in SessionContext, no backend needed
- **Voice (B):** Test in regular browser, console.log outputs, no backend needed
- **Backend Core (C):** Use wscat or Postman to test WebSocket: `wscat -c ws://localhost:8000/ws/session`
- **Backend Services (D):** Use curl to test endpoints: `curl http://localhost:8000/api/images?q=CPR`
- **Training (E):** Needs backend running, test via wscat first then frontend

## API Keys
Never commit API keys. They go in `.env` which is gitignored.
Share keys with teammates through a secure channel (DM, not group chat).
