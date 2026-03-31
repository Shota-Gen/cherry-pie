"""
StudyConnect API — The "Brain"
FastAPI backend for the StudyConnect platform.
"""

import os
 
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers.studyspots import studyspots_router as studyspots_router
from routers.sessions import router as sessions_router
app = FastAPI(
    title="StudyConnect API",
    description="Backend API for the StudyConnect platform",
    version="0.1.0",
)

# Allow the iOS app and local dev tools to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def root():
    return {"status": "online", "service": "StudyConnect API"}


@app.get("/health")
async def health():
    """Health check endpoint for monitoring and Docker."""
    return {
        "status": "healthy",
        "environment": os.getenv("ENVIRONMENT", "development"),
    }


# -- Routers --
app.include_router(studyspots_router)
app.include_router(sessions_router)
