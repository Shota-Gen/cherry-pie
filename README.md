# UM EECS 498-002 W25 CherryPie

| Video  |  Wiki |  Agile |
|:-----:|:-----:|:--------:|
|[<img src="https://eecs441.eecs.umich.edu/img/admin/video.png">][video]|[<img src="https://eecs441.eecs.umich.edu/img/admin/wiki.png">][wiki]|[<img src="https://eecs441.eecs.umich.edu/img/admin/trello.png">][agile]|
<!-- reusing the icons from eecs441 -->

![Elevator Pitch](/imgs/title.png) <!-- MUST be placed in publicly accessible github -->
![Team](/imgs/team.png)

[video]: https://youtu.be/zx3ITjAUZ78
[wiki]: https://github.com/Shota-Gen/cherry-pie/wiki
[agile]: https://trello.com/b/rTodfQt7/studyconnect-workspace <!-- MUST be made public –>

# 🎓 StudyConnect

> High-precision student collaboration platform built for the University of Michigan.

StudyConnect is a hybrid **iOS + Cloud** platform that enables real-time student coordination using location intelligence, calendar integration, and AR-enhanced spatial awareness.

---

## ✨ Features

- 📱 Native iOS app (Swift 6 + RealityKit)
- 🧠 FastAPI backend (Python 3.12)
- 🗺 PostGIS-powered geospatial database
- 🔐 Supabase authentication
- 📅 Google Calendar integration
- 🚀 Automated CI/CD via GitHub Actions

---

## 🏗 Architecture Overview

```
iOS App (Swift)
        ↓
FastAPI Backend (Railway)
        ↓
PostgreSQL + PostGIS (Supabase)
```

---

## 🛠 Tech Stack

| Layer            | Technology              |
| ---------------- | ----------------------- |
| Mobile           | Swift 6, RealityKit     |
| API              | FastAPI, Uvicorn        |
| Database         | PostgreSQL 15 + PostGIS |
| Auth             | Supabase                |
| Deployment       | Railway                 |
| CI/CD            | GitHub Actions          |
| Containerization | Docker                  |

---

## 🚀 Getting Started (Local Development)

### 1️⃣ Prerequisites

Install the following:

- [Docker w/ OrbStack](https://orbstack.dev/)
- [Supabase CLI](https://supabase.com/docs/guides/cli) — `brew install supabase/tap/supabase`
- Xcode 16+ (for iOS team)
- Git

---

### 2️⃣ Clone the Repository

```bash
git clone https://github.com/your-username/StudyConnect.git
cd StudyConnect
```

---

### 3️⃣ Configure Environment Variables

```bash
cp .env.example .env
```

Request production Supabase keys from Shota and fill them in.

---

### 4️⃣ Start Local Supabase

```bash
supabase start
```

This spins up a full local Supabase stack (Postgres, Auth, Realtime, Storage, etc.).

Local services will be available at:

- **Supabase Studio** (Database GUI) → http://localhost:54323
- **Supabase API** → http://localhost:54321
- **Postgres** → localhost:54322

---

### 5️⃣ Start Backend Services

```bash
docker compose up --build
```

This starts your app services that connect to the local Supabase:

- **API** → http://localhost:8080

---

### 6️⃣ Common Commands

```bash
# Reset database (re-runs all migrations + seeds)
supabase db reset

# Push migration changes to remote
supabase db push

# Stop everything
docker compose down
supabase stop

# View database in browser
open http://localhost:54323
```

---

### 5 Python Venv (for Anant & Josh)

1. Navigate to the backend folder: cd backend-api
2. Create the environment: python3 -m venv .venv (using python 3.12)
3. Activate it:
   Mac/Linux: source .venv/bin/activate
4. Install the requirements locally: pip install -r requirements.txt

---

## 📁 Project Structure

```
StudyConnect/
│
├── ios-app/          # iOS client (Swift, AR)
├── backend-api/      # FastAPI backend
├── supabase/         # DB migrations & configs
├── docker-compose.yml
└── README.md
```

---

## 🔄 Deployment Workflow

We use a trunk-based workflow with automated deployment.

1. Create a feature branch  
   `feature/your-feature-name`

2. Open a Pull Request into `main`

3. Once merged:
   - `/backend-api` auto-deploys to Railway

---

## 🧪 Development Guidelines

- Use feature branches for all work
- Keep PRs small and reviewable
- Write descriptive commit messages
- Never commit `.env` or secrets
- Ensure Docker builds locally before opening PR

---

## 🚨 Troubleshooting

**Port 54322 already in use**

- Another Supabase instance may be running. Run `supabase stop` first.
- Or stop any local PostgreSQL instances: `brew services stop postgresql`

**`supabase start` failing**

- Make sure Docker Desktop is running first.
- Try `supabase stop && supabase start` to restart cleanly.

**UWB / Nearby Interaction not working**

- Requires physical iPhone 11+ device.
- Does NOT work in the Xcode Simulator.

**Docker build failing**

- Try:
  ```bash
  docker compose down
  docker system prune -f
  ```

**API can't connect to database**

- Make sure `supabase start` is running before `docker compose up`.
- Verify Docker Desktop's `host.docker.internal` is working (should be automatic on Mac).

---

## 📦 Core Backend Files

### docker-compose.yml

Orchestrates:

- FastAPI API container
- Connects to local Supabase via `host.docker.internal`

### supabase/

- `config.toml` — Local Supabase configuration
- `migrations/` — Database schema migrations (auto-applied by `supabase db reset`)
- `seed.sql` — Test data (auto-applied by `supabase db reset`)

### backend-api/Dockerfile

Defines the Python runtime environment for the API service.

### backend-api/requirements.txt

Locks backend dependencies for deterministic builds.

---

## 🔐 Security Notes

- Secrets are managed via environment variables.
- Production secrets are stored in Railway.
- Never hardcode API keys.
- Use HTTPS in production.

---

## 📈 Roadmap (High-Level)

- [ ] Google OAuth login flow
- [ ] Friend proximity detection
- [ ] Study session creation
- [ ] Real-time spatial visualization
- [ ] Push notifications
- [ ] Production observability & logging

---

## 👥 Contributors

| Domain           | Team           |
| ---------------- | -------------- |
| iOS              | Ayah, Jawad    |
| Precise Location | Jeffrey, Josh  |
| Backend & Infra  | Shota          |
| Google Sign In   | David          |
| Sessions         | Anant          |

---

## 📜 License

Private academic project.  
All rights reserved.

---

## 🏁 Status

🚧 Active Development

---

Built with precision and ambition.
