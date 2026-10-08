from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from backend.app.config import settings
from backend.app.database import init_db
from backend.app.api.routes_system import router as system_router
from backend.app.api.routes_projects import router as projects_router
from backend.app.api.routes_episodes import router as episodes_router
from backend.app.api.routes_characters import router as characters_router
from backend.app.api.routes_jobs import router as jobs_router
from backend.app.api.routes_dub import router as dub_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize database schemas
    await init_db()
    yield

app = FastAPI(
    title=settings.APP_NAME,
    description="Local-First Anime Dub Studio API — Japanese to Natural Hindi Dubbing",
    version="1.0.0",
    lifespan=lifespan
)

# CORS configuration for Next.js frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:3000", "*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount local storage directory for media streaming
app.mount("/storage", StaticFiles(directory=str(settings.STORAGE_DIR)), name="storage")

# Include API routes
app.include_router(system_router)
app.include_router(projects_router)
app.include_router(episodes_router)
app.include_router(characters_router)
app.include_router(jobs_router)
app.include_router(dub_router)

@app.get("/api/health")
async def health_check():
    return {
        "status": "healthy",
        "app": settings.APP_NAME,
        "is_apple_silicon": settings.is_apple_silicon,
        "total_ram_gb": settings.total_memory_gb
    }
