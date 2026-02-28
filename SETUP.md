# GitHub Setup Commands

This document contains the exact Git commands for setting up the GuideVR repository and getting started.

---

## For Team Lead (you):

```bash
# Initialize and push to GitHub
cd guidevr
git init
git add .
git commit -m "feat: initial project scaffold with stubs and planning docs"
git branch -M main
git remote add origin https://github.com/Yuvraajb/H4H-2026.git
git push -u origin main

# Create all feature branches so teammates can just checkout
git checkout -b feature/spatial-ui
git push origin feature/spatial-ui

git checkout -b feature/voice-pipeline
git push origin feature/voice-pipeline

git checkout -b feature/backend-core
git push origin feature/backend-core

git checkout -b feature/backend-services
git push origin feature/backend-services

git checkout -b feature/training-mode
git push origin feature/training-mode

git checkout -b feature/integration
git push origin feature/integration

git checkout main

# Add teammates as collaborators on GitHub:
# Go to repo → Settings → Collaborators → Add people
```

---

## For Each Teammate:

```bash
# Clone the repo
git clone https://github.com/Yuvraajb/H4H-2026.git
cd H4H-2026

# Install everything
npm install
cd backend && pip install -r requirements.txt && cd ..

# Copy env file and add your API keys
cp .env.example .env
# Edit .env with your keys

# Verify it runs
npm run dev          # frontend should show placeholder panels
cd backend && python run.py  # backend should start on :8000

# Switch to your assigned branch
git checkout feature/[your-workstream]

# Start coding! Only edit files listed under your workstream in PLANNING.md
```

---

## Merging Back:

```bash
# When your feature is done:
git add .
git commit -m "feat: complete [workstream description]"
git push origin feature/[your-workstream]

# Go to GitHub → Pull Requests → New Pull Request
# Base: main ← Compare: feature/[your-workstream]
# Add description of what you built
# Request review from a teammate
# Merge after approval

# After someone else merges, update your branch:
git checkout feature/[your-workstream]
git fetch origin
git rebase origin/main
# Fix any conflicts if they exist
git push --force-with-lease
```

---

## Integration Order:

Merge workstreams in this order to minimize conflicts:

1. `feature/backend-core` (C) — backend foundation
2. `feature/backend-services` (D) — adds image + report endpoints
3. `feature/spatial-ui` (A) — frontend components
4. `feature/voice-pipeline` (B) — voice services
5. `feature/training-mode` (E) — training feature
6. `feature/integration` — wires everything together
