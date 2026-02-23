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
- ⚡ Real-time UDP relay for sensor communication
- 🚀 Automated CI/CD via GitHub Actions

---

## 🏗 Architecture Overview

```
iOS App (Swift)
        ↓
FastAPI Backend (Railway)
        ↓
PostgreSQL + PostGIS (Supabase)
        ↓
UDP Relay Service (Fly.io)
```

---

## 🛠 Tech Stack

| Layer            | Technology              |
| ---------------- | ----------------------- |
| Mobile           | Swift 6, RealityKit     |
| API              | FastAPI, Uvicorn        |
| Database         | PostgreSQL 15 + PostGIS |
| Auth             | Supabase                |
| Realtime Relay   | Swift (UDP)             |
| Deployment       | Railway, Fly.io         |
| CI/CD            | GitHub Actions          |
| Containerization | Docker                  |

---

## 🚀 Getting Started (Local Development)

### 1️⃣ Prerequisites

Install the following:

- Docker Desktop
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

Create a `.env` file in the root directory & copy over `.env.example`

Request production keys from Shota.

---

### 4️⃣ Start Backend Services

```bash
docker-compose up --build -d
```

Services will be available at:

- API → http://localhost:8080
- Database → localhost:5432

To stop:

```bash
docker-compose down
```

To reset database:

```bash
docker-compose down -v
```

---

### 5 Python Venv (for Anant & Josh)

1. Navigate to the backend folder: cd backend-api
2. Create the environment: python3 -m venv .venv
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
├── backend-relay/    # UDP real-time relay
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
   - `/backend-relay` auto-deploys to Fly.io

---

## 🧪 Development Guidelines

- Use feature branches for all work
- Keep PRs small and reviewable
- Write descriptive commit messages
- Never commit `.env` or secrets
- Ensure Docker builds locally before opening PR

---

## 🚨 Troubleshooting

**Port 5432 already in use**

- Stop any local PostgreSQL instances running outside Docker.

**UWB / Nearby Interaction not working**

- Requires physical iPhone 11+ device.
- Does NOT work in the Xcode Simulator.

**Docker build failing**

- Try:
  ```bash
  docker-compose down
  docker system prune -f
  ```

---

## 📦 Core Backend Files

### docker-compose.yml

Orchestrates:

- FastAPI container
- PostGIS database container
- Shared internal Docker network

### backend-api/Dockerfile

Defines the Python runtime environment for the API service.

### backend-api/requirements.txt

Locks backend dependencies for deterministic builds.

---

## 🔐 Security Notes

- Secrets are managed via environment variables.
- Production secrets are stored in Railway / Fly.io.
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
| Backend API      | Anant, Josh    |
| Relay            | Jeffrey, David |
| Database & Infra | Shota          |

---

## 📜 License

Private academic project.  
All rights reserved.

---

## 🏁 Status

🚧 Active Development

---

Built with precision and ambition.
