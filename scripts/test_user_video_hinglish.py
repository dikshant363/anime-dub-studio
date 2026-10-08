import asyncio
import json
import subprocess
from pathlib import Path
from backend.app.database import init_db, AsyncSessionLocal
from backend.app.models.project import Project
from backend.app.models.episode import Episode
from backend.app.models.job import Job
from backend.app.schemas.dub import DubCreateRequest
from backend.app.pipeline.orchestrator import PipelineOrchestrator

async def run_user_video_acceptance_test():
    print("=" * 60)
    print("STARTING USER VIDEO ACCEPTANCE TEST: Japanese -> Hinglish Dub")
    print("=" * 60)

    sample_media = Path("storage/test_fmp_sample.mkv").resolve()
    if not sample_media.exists():
        raise FileNotFoundError(f"Sample media not found: {sample_media}")

    await init_db()

    async with AsyncSessionLocal() as session:
        # 1. Create Project
        project = Project(
            name="Full Metal Panic - Hinglish Dub Test",
            source_language="ja",
            target_language="hinglish"
        )
        session.add(project)
        await session.commit()
        await session.refresh(project)

        # 2. Create Episode
        episode = Episode(
            project_id=project.id,
            episode_number=1,
            title="Full Metal Panic S01E01 - Hinglish Dub",
            current_stage="INGESTION",
            status="PROCESSING",
            source_media_path=str(sample_media)
        )
        session.add(episode)
        await session.commit()
        await session.refresh(episode)

        # 3. Create Job
        job = Job(
            episode_id=episode.id,
            stage="STARTING",
            status="RUNNING",
            progress=0.0
        )
        session.add(job)
        await session.commit()
        await session.refresh(job)

        dub_options = DubCreateRequest(
            project_name=project.name,
            source_language="ja",
            target_language="hinglish",
            translation_style="natural_hinglish",
            english_mixing="medium",
            translation_model="auto",
            preserve_background=True,
            normalize_loudness=True
        )

        # Progress tracking callback
        async def on_progress(log):
            print(f"[{log.get('stage')}] {log.get('progress')}% - {log.get('message')}")

        orchestrator = PipelineOrchestrator(db_session=session, progress_callback=on_progress)

        print("\nExecuting Pipeline Orchestrator on user anime media...")
        final_video_path = await orchestrator.execute_dubbing_job(
            episode=episode,
            job=job,
            options=dub_options
        )

        print(f"\n[DONE] Pipeline execution completed!")
        print(f"Final Video: {final_video_path}")
        print(f"Subtitle SRT: {episode.subtitle_srt_path}")
        print(f"Subtitle ASS: {episode.subtitle_ass_path}")
        print(f"QA Score: {episode.qa_score}/100")
        print(f"QA Status: {episode.qa_report.get('status')}")

        # -----------------------------------------------------------------
        # VERIFICATION CHECKS
        # -----------------------------------------------------------------
        final_video = Path(final_video_path)
        assert final_video.exists(), "Final video file does not exist!"
        assert final_video.stat().st_size > 50000, "Final video is unusually small!"

        # Probe final video with ffprobe
        probe_cmd = [
            "ffprobe", "-v", "error",
            "-show_entries", "stream=codec_name,codec_type,width,height:format=duration,size",
            "-of", "json",
            str(final_video)
        ]
        res = subprocess.run(probe_cmd, capture_output=True, text=True)
        probe_data = json.loads(res.stdout)
        streams = probe_data.get("streams", [])
        v_stream = next((s for s in streams if s.get("codec_type") == "video"), None)
        a_stream = next((s for s in streams if s.get("codec_type") == "audio"), None)

        print("\n=== FFPROBE INSPECTION OF DUBBED VIDEO ===")
        print(f"Video Codec: {v_stream.get('codec_name')} (Lossless copy)")
        print(f"Resolution:  {v_stream.get('width')}x{v_stream.get('height')}")
        print(f"Audio Codec: {a_stream.get('codec_name')} (Universal AAC)")
        print(f"Duration:    {probe_data.get('format', {}).get('duration')}s")
        print(f"File Size:   {int(probe_data.get('format', {}).get('size', 0)) / (1024*1024):.2f} MB")

        assert v_stream.get("codec_name") == "hevc", "Video was re-encoded! Expected HEVC lossless copy."
        assert a_stream.get("codec_name") == "aac", "Audio codec is not AAC!"

        # Verify SRT subtitles
        srt_p = Path(episode.subtitle_srt_path)
        assert srt_p.exists(), "Hinglish SRT subtitle does not exist!"
        srt_content = srt_p.read_text(encoding="utf-8")
        print("\n=== HINGLISH SUBTITLES (SRT) ===")
        print(srt_content.strip())

        import re
        has_devanagari_in_srt = bool(re.search(r'[\u0900-\u097F]', srt_content))
        assert not has_devanagari_in_srt, "Devanagari detected in Roman Hinglish SRT subtitles!"

        # Verify ASS subtitles
        ass_p = Path(episode.subtitle_ass_path)
        assert ass_p.exists(), "Hinglish ASS subtitle does not exist!"

        print("\n" + "=" * 60)
        print("ACCEPTANCE TEST PASSED SUCCESSFULLY!")
        print("=" * 60)

if __name__ == "__main__":
    asyncio.run(run_user_video_acceptance_test())
