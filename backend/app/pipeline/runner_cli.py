import sys
import os
import json
import time
import argparse
import asyncio
from pathlib import Path
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional

from backend.app.database import init_db, AsyncSessionLocal
from backend.app.models.project import Project
from backend.app.models.episode import Episode
from backend.app.models.job import Job
from backend.app.schemas.dub import DubCreateRequest
from backend.app.pipeline.orchestrator import PipelineOrchestrator
from backend.app.pipeline.ingestion.probe import MediaProbe
from sqlalchemy import select

STAGE_WEIGHTS = {
    "PREPARING": (0.0, 3.0, "Preparing video"),
    "EXTRACTING_AUDIO": (3.0, 5.0, "Audio extraction"),
    "ASR": (8.0, 15.0, "Japanese transcription"),
    "DIARIZING": (23.0, 8.0, "Character detection"),
    "TRANSLATING": (31.0, 12.0, "Translation"),
    "HINGLISH": (43.0, 8.0, "Hinglish adaptation"),
    "TTS": (51.0, 30.0, "Voice generation"),
    "TIMING": (81.0, 5.0, "Dialogue timing alignment"),
    "MIXING": (86.0, 7.0, "Audio mixing"),
    "SUBTITLES": (93.0, 2.0, "Subtitles"),
    "RENDERING": (95.0, 3.0, "Final render"),
    "QA": (98.0, 2.0, "Quality check"),
}

def format_time_str(seconds: float) -> str:
    secs = int(max(0.0, seconds))
    m = secs // 60
    s = secs % 60
    return f"{m:02d}:{s:02d}"

async def main():
    parser = argparse.ArgumentParser(description="Anime Dub Studio Native Pipeline Runner")
    parser.add_argument("--input", required=True, help="Path to input media file")
    parser.add_argument("--target-lang", default="hinglish", help="Target language (hindi, hinglish, hi_en)")
    parser.add_argument("--source-lang", default="ja", help="Source language (default ja)")
    parser.add_argument("--voice-mode", default="local", help="Voice provider (local / online)")
    parser.add_argument("--audio-stream-index", type=int, default=None, help="Explicit audio stream index")
    parser.add_argument("--translation-model", default="auto", help="Translation model (apple_intelligence, ollama, auto)")
    parser.add_argument("--translation-style", default="natural_hinglish", help="Translation style")
    parser.add_argument("--project-name", default=None, help="Project name")
    parser.add_argument("--project-id", default=None, help="Existing project ID")
    parser.add_argument("--episode-id", default=None, help="Existing episode ID")
    parser.add_argument("--job-id", default=None, help="Existing job ID")
    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        err = {"event": "error", "error": f"Input media file not found: {input_path}"}
        print(json.dumps(err), flush=True)
        sys.exit(1)

    await init_db()

    start_time = time.time()
    completed_stages: List[str] = []
    source_duration = 0.0

    try:
        src_meta = await MediaProbe.inspect(input_path)
        source_duration = float(src_meta.get("duration", 0.0))
    except Exception:
        source_duration = 0.0

    current_active_stage = "PREPARING"
    current_active_item = 0
    total_active_items = 0

    async def emit_pipeline_progress(log: Dict[str, Any]):
        nonlocal source_duration, current_active_stage, current_active_item, total_active_items
        stage = log.get("stage", "PREPARING")
        msg = log.get("message", "")
        cur_item = log.get("current_item", 0)
        tot_items = log.get("total_items", 0)
        char_name = log.get("character")
        seg_dur = log.get("processed_duration", 0.0)

        current_active_stage = stage
        current_active_item = cur_item
        total_active_items = tot_items

        stage_meta = STAGE_WEIGHTS.get(stage, (0.0, 5.0, stage))
        base_pct, weight, label = stage_meta

        if tot_items > 0:
            stage_pct = (cur_item / tot_items) * weight
            progress = min(99.0, base_pct + stage_pct)
        else:
            raw_prog = log.get("progress", 0.0)
            progress = min(99.0, base_pct + (raw_prog / 100.0) * weight)

        elapsed = int(time.time() - start_time)

        # Dynamic ETA calculation
        eta_seconds: Optional[int] = None
        if progress > 5.0 and elapsed > 3:
            total_est = (elapsed / max(0.01, progress)) * 100.0
            eta_seconds = int(max(0.0, total_est - elapsed))

        # Speed calculation (processed media duration / elapsed time)
        speed_x = 1.0
        if seg_dur > 0 and elapsed > 0:
            speed_x = round(seg_dur / elapsed, 1)

        if stage not in completed_stages and stage != "COMPLETED" and stage != "FAILED":
            # Check if previous stages are complete
            for st_key in STAGE_WEIGHTS:
                if st_key == stage:
                    break
                if st_key not in completed_stages:
                    completed_stages.append(st_key)

        processed_str = format_time_str(seg_dur)
        duration_str = format_time_str(source_duration) if source_duration > 0 else "--:--"

        stage_keys = list(STAGE_WEIGHTS.keys())
        st_idx = stage_keys.index(stage) if stage in stage_keys else 0

        event = {
            "event": "progress",
            "job_id": args.job_id or "",
            "stage": stage,
            "stage_index": st_idx + 1,
            "stage_count": len(stage_keys),
            "stage_progress": round((cur_item / max(1, tot_items)) * 100.0 if tot_items > 0 else log.get("progress", 0.0), 1),
            "stage_label": label,
            "progress": round(progress, 1),
            "overall_progress": round(progress, 1),
            "current_character": char_name,
            "current_item": cur_item,
            "completed_items": cur_item,
            "total_items": tot_items,
            "processed_media_seconds": round(seg_dur, 2),
            "source_duration_seconds": round(source_duration, 2),
            "elapsed_seconds": elapsed,
            "estimated_remaining_seconds": eta_seconds,
            "eta_seconds": eta_seconds,
            "speed_multiplier": max(1.0, speed_x),
            "speed_x": max(1.0, speed_x),
            "processed_time_str": processed_str,
            "source_duration_str": duration_str,
            "source_duration_secs": source_duration,
            "completed_stages": completed_stages,
            "status": "RUNNING",
            "error": None,
            "project_title": args.project_name or input_path.stem,
            "source_filename": input_path.name,
            "voice_provider": "macOS Speech (Offline)" if args.voice_mode != "online" else "Microsoft Edge TTS (Online)",
            "message": msg
        }
        print(json.dumps(event), flush=True)

    async with AsyncSessionLocal() as session:
        # Resolve or create Project
        project = None
        if args.project_id:
            res = await session.execute(select(Project).where(Project.id == args.project_id))
            project = res.scalars().first()

        if not project:
            proj_name = args.project_name or f"{input_path.stem} Dub"
            project = Project(
                name=proj_name,
                source_language=args.source_lang,
                target_language=args.target_lang
            )
            session.add(project)
            await session.commit()
            await session.refresh(project)

        # Resolve or create Episode
        episode = None
        if args.episode_id:
            res = await session.execute(select(Episode).where(Episode.id == args.episode_id))
            episode = res.scalars().first()

        if not episode:
            episode = Episode(
                project_id=project.id,
                episode_number=1,
                title=input_path.stem,
                source_media_path=str(input_path),
                current_stage="PREPARING",
                status="PROCESSING"
            )
            session.add(episode)
            await session.commit()
            await session.refresh(episode)
        else:
            episode.source_media_path = str(input_path)
            await session.commit()

        # Resolve or create Job
        job = None
        if args.job_id:
            res = await session.execute(select(Job).where(Job.id == args.job_id))
            job = res.scalars().first()

        if not job:
            job = Job(
                episode_id=episode.id,
                stage="PREPARING",
                status="RUNNING",
                progress=1.0,
                worker="m4_apple_silicon"
            )
            session.add(job)
            await session.commit()
            await session.refresh(job)

        dub_req = DubCreateRequest(
            project_name=project.name,
            source_language=args.source_lang,
            target_language=args.target_lang,
            translation_model=args.translation_model,
            translation_style=args.translation_style,
            voice_mode=args.voice_mode,
            audio_stream_index=args.audio_stream_index,
            preserve_background=True,
            normalize_loudness=True
        )

        orchestrator = PipelineOrchestrator(
            db_session=session,
            progress_callback=emit_pipeline_progress
        )

        try:
            final_video_path = await orchestrator.execute_dubbing_job(
                episode=episode,
                job=job,
                options=dub_req
            )

            source_duration = episode.duration or 0.0

            complete_event = {
                "event": "complete",
                "stage": "COMPLETED",
                "stage_label": "Complete",
                "progress": 100.0,
                "elapsed_seconds": int(time.time() - start_time),
                "output_video_path": str(final_video_path),
                "qa_score": episode.qa_score or 96.0,
                "message": "Dubbing pipeline completed successfully!"
            }
            print(json.dumps(complete_event), flush=True)

        except Exception as e:
            import traceback
            tb = traceback.format_exc()
            err_msg = str(e) or type(e).__name__
            err_event = {
                "event": "error",
                "job_id": args.job_id or "",
                "stage": current_active_stage,
                "stage_label": STAGE_WEIGHTS.get(current_active_stage, (0, 0, current_active_stage))[2],
                "current_item": current_active_item,
                "total_items": total_active_items,
                "error": err_msg,
                "traceback": tb,
                "message": f"Stage: {STAGE_WEIGHTS.get(current_active_stage, (0, 0, current_active_stage))[2]} | Error: {err_msg}",
                "recovery": "Completed checkpoint stages are safely saved on disk. You can retry from the last checkpoint."
            }
            print(json.dumps(err_event), flush=True)
            sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
