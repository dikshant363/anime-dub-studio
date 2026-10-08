import pytest
from pathlib import Path
from backend.app.database import AsyncSessionLocal, init_db
from backend.app.models.project import Project
from backend.app.models.episode import Episode
from backend.app.models.job import Job
from backend.app.schemas.dub import DubCreateRequest
from backend.app.pipeline.orchestrator import PipelineOrchestrator

@pytest.mark.asyncio
async def test_full_pipeline_e2e():
    await init_db()
    sample_file = Path("tests/test_data/sample.mp4").resolve()
    assert sample_file.exists(), "Sample test file must exist"

    async with AsyncSessionLocal() as session:
        project = Project(name="E2E Test Project", source_language="ja", target_language="hi")
        session.add(project)
        await session.commit()
        await session.refresh(project)

        episode = Episode(
            project_id=project.id,
            title="E2E Test Episode",
            source_media_path=str(sample_file)
        )
        session.add(episode)
        await session.commit()
        await session.refresh(episode)

        job = Job(episode_id=episode.id, stage="UPLOADING", worker="m4_apple_silicon")
        session.add(job)
        await session.commit()
        await session.refresh(job)

        orchestrator = PipelineOrchestrator(db_session=session)
        options = DubCreateRequest(
            source_language="ja",
            target_language="hi",
            translation_model="auto",
            preserve_background=True,
            normalize_loudness=True
        )

        rendered_mp4 = await orchestrator.execute_dubbing_job(episode, job, options)

        # Assertions
        assert rendered_mp4.exists()
        assert episode.status == "COMPLETED"
        assert episode.qa_score is not None
        assert episode.qa_score >= 80.0
        assert episode.subtitle_srt_path is not None
        assert Path(episode.subtitle_srt_path).exists()
        assert Path(episode.dubbed_audio_path).exists()
