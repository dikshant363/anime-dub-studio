import json
import shutil
import asyncio
from pathlib import Path
from typing import Optional
from fastapi import APIRouter, Depends, UploadFile, File, Form, BackgroundTasks, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from backend.app.config import settings
from backend.app.database import get_db, AsyncSessionLocal
from backend.app.models.project import Project
from backend.app.models.episode import Episode
from backend.app.models.job import Job
from backend.app.schemas.dub import DubCreateRequest
from backend.app.pipeline.orchestrator import PipelineOrchestrator

router = APIRouter(prefix="/api/dub", tags=["Dubbing"])

async def _run_pipeline_background(episode_id: str, job_id: str, dub_options: DubCreateRequest):
    """Background task runner for orchestrating dubbing pipeline across stages."""
    async with AsyncSessionLocal() as session:
        try:
            ep_res = await session.execute(select(Episode).where(Episode.id == episode_id))
            episode = ep_res.scalar_one_or_none()
            job_res = await session.execute(select(Job).where(Job.id == job_id))
            job = job_res.scalar_one_or_none()

            if not episode or not job:
                return

            orchestrator = PipelineOrchestrator(db_session=session)
            await orchestrator.execute_dubbing_job(episode=episode, job=job, options=dub_options)
        except Exception as e:
            # Error is already logged on job within orchestrator
            pass

@router.post("/create")
async def create_dub(
    file: UploadFile = File(...),
    options: str = Form(default="{}"),
    background_tasks: BackgroundTasks = BackgroundTasks(),
    db: AsyncSession = Depends(get_db)
):
    try:
        parsed_options = json.loads(options)
    except Exception:
        parsed_options = {}

    dub_request = DubCreateRequest(**parsed_options)

    # 1. Create or resolve project
    project = Project(
        name=dub_request.project_name or file.filename or "Anime Dub Project",
        source_language=dub_request.source_language,
        target_language=dub_request.target_language
    )
    db.add(project)
    await db.commit()
    await db.refresh(project)

    # 2. Create episode
    episode = Episode(
        project_id=project.id,
        episode_number=1,
        title=Path(file.filename or "Episode 01").stem,
        current_stage="UPLOADING",
        status="PROCESSING"
    )
    db.add(episode)
    await db.commit()
    await db.refresh(episode)

    # 3. Create initial job
    job = Job(
        episode_id=episode.id,
        stage="UPLOADING",
        status="RUNNING",
        progress=5.0,
        worker="m4_apple_silicon" if settings.is_apple_silicon else "colab_cuda"
    )
    db.add(job)
    await db.commit()
    await db.refresh(job)

    # 4. Save uploaded media file
    source_dir = settings.PROJECTS_DIR / project.id / "episodes" / episode.id / "source"
    source_dir.mkdir(parents=True, exist_ok=True)
    file_ext = Path(file.filename or "media.mp4").suffix or ".mp4"
    saved_path = source_dir / f"original{file_ext}"

    with open(saved_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    episode.source_media_path = str(saved_path)
    episode.current_stage = "QUEUED"
    await db.commit()

    # 5. Launch asynchronous pipeline execution
    background_tasks.add_task(
        _run_pipeline_background,
        episode_id=episode.id,
        job_id=job.id,
        dub_options=dub_request
    )

    return {
        "job_id": job.id,
        "episode_id": episode.id,
        "project_id": project.id,
        "status": "QUEUED",
        "message": "Media uploaded and dubbing pipeline initiated successfully."
    }
