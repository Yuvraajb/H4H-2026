# GuideVR

An AI-powered spatial assistant that turns untrained community responders into confident first responders — and gives professionals a head start before they even arrive.

## Overview

GuideVR is a VR/AR spatial assistant deployed on shared devices in schools, clinics, shelters, and community centers. The AI listens, coaches the user with voice + visual instructions, adapts in real time, and auto-generates a handoff report for arriving professionals.

### Problem

In underserved communities, the gap between "something happened" and "help arrives" is where outcomes are decided. Most bystanders freeze because they lack training, not because they lack willingness.

### Solution

GuideVR democratizes real-time guidance for anyone, regardless of training or background. Expertise shouldn't be gatekept.

### Target Users

- School staff
- Community health workers
- Shelter employees
- Workplace safety officers
- Disaster response volunteers

## Quick Start

### Prerequisites

- Node.js 18+ and npm
- Python 3.11+
- Xcode with visionOS Simulator (for spatial testing)
- API keys for:
  - ElevenLabs (TTS)
  - OpenAI or Anthropic (LLM)
  - Google Custom Search (images)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/Yuvraajb/H4H-2026.git
cd H4H-2026
```

2. Install frontend dependencies:
```bash
npm install
```

3. Install backend dependencies:
```bash
cd backend
pip install -r requirements.txt
cd ..
```

4. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your API keys
```

5. Run the backend:
```bash
cd backend
python run.py
```

6. Run the frontend (in a new terminal):
```bash
npm run dev
```

7. For visionOS testing:
```bash
XR_ENV=avp npm run dev
# In another terminal:
npx webspatial-builder run --base=http://localhost:5175/webspatial/avp
```

## Project Structure

See [PLANNING.md](./PLANNING.md) for the complete project overview, architecture, and file structure.

## Team Collaboration

- **Getting Started**: See [CONTRIBUTING.md](./CONTRIBUTING.md) for workflow and branch strategy
- **Git Setup**: See [SETUP.md](./SETUP.md) for exact Git commands
- **API Documentation**: See [docs/API.md](./docs/API.md) for API contracts

## Features

### P0 - Core Features (MUST demo)
- Voice conversation with AI
- Spatial UI with floating panels
- Adaptive AI for ANY scenario
- Instructional image retrieval and display
- Urgency detection and visual indicators
- Session recording and PDF report generation

### P1 - Should Have
- Training/simulation mode with scoring
- Continuous listening mode
- Report auto-sent to first responders (simulated)

### P2 - Nice to Have
- Multiple language support
- Session replay as web page
- Sound design
- Landing screen with onboarding

## Tech Stack

- **Frontend**: React 18+, TypeScript, Vite, TailwindCSS, WebSpatial SDK
- **Backend**: Python 3.11+, FastAPI, Uvicorn, WebSockets
- **External APIs**: ElevenLabs (TTS), OpenAI/Anthropic (LLM), Google Custom Search (images)

See [PLANNING.md](./PLANNING.md) for complete tech stack details.

## License

[Add your license here]

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for contribution guidelines.
