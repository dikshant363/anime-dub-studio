import sys
import json
import asyncio
import argparse
from pathlib import Path

# Add project root to path
ROOT_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT_DIR))

from backend.app.config import settings
from backend.app.database import AsyncSessionLocal, init_db
from backend.app.models.project import Project
from backend.app.models.episode import Episode
from backend.app.models.job import Job
from backend.app.models.character import Character
from backend.app.schemas.dub import DubCreateRequest
from backend.app.pipeline.orchestrator import PipelineOrchestrator
from backend.app.pipeline.translation.apple_intelligence import AppleIntelligenceTranslationEngine
from backend.app.pipeline.translation.ollama import OllamaTranslationEngine

def print_banner():
    print("""
    ========================================================
             ANIME DUB STUDIO — LOCAL-FIRST CLI
        Japanese Anime → Natural Hindi Dubbing Engine
        Target Hardware: Apple Silicon M4 & Google Colab
    ========================================================
    """)

async def cmd_status():
    print_banner()
    print("Checking on-device hardware and AI provider status...")
    apple_engine = AppleIntelligenceTranslationEngine()
    ollama_engine = OllamaTranslationEngine()

    apple_avail = await apple_engine.is_available()
    ollama_avail = await ollama_engine.is_available()

    info = settings.system_info
    print(f"\n[Hardware Platform]")
    print(f"  OS:             {info['os']} ({info['machine']})")
    print(f"  Apple Silicon:  {'YES (M4 Detected)' if info['is_apple_silicon'] else 'NO'}")
    print(f"  Unified RAM:    {info['total_ram_gb']} GB")
    print(f"  Python Version: {info['python_version']}")

    print(f"\n[Local AI Providers]")
    print(f"  Apple Intelligence (FoundationModels): {'ONLINE (On-Device Neural Engine)' if apple_avail else 'UNAVAILABLE'}")
    print(f"  Ollama Server:                         {'ONLINE (' + settings.OLLAMA_TRANSLATION_MODEL + ')' if ollama_avail else 'OFFLINE'}")
    print(f"  MLX Acceleration:                      {'READY (Apple Metal GPU)' if settings.is_apple_silicon else 'N/A'}")
    print(f"  TTS Provider:                          EdgeTTS Neural (Hindi Madhur/Swara) + Piper ONNX")

    print("\nSystem is ready for local-first Hindi dubbing workflows.")

async def cmd_demo(sample_path_str: str, target_lang: str):
    print_banner()
    sample_path = Path(sample_path_str).resolve()
    if not sample_path.exists():
        print(f"Error: Sample file not found at {sample_path}")
        sys.exit(1)

    print(f"[*] Initiating One-Command End-to-End Demo")
    print(f"    Source Media:    {sample_path.name}")
    print(f"    Source Language: ja (Japanese)")
    print(f"    Target Language: {target_lang} (Hindi)")
    print(f"    Worker Mode:     auto (Apple Silicon M4)\n")

    await init_db()

    async with AsyncSessionLocal() as session:
        # Create Project
        project = Project(
            name=f"Demo: {sample_path.stem}",
            source_language="ja",
            target_language=target_lang
        )
        session.add(project)
        await session.commit()
        await session.refresh(project)

        # Create Episode
        episode = Episode(
            project_id=project.id,
            episode_number=1,
            title=sample_path.stem,
            source_media_path=str(sample_path),
            current_stage="INGESTION"
        )
        session.add(episode)
        await session.commit()
        await session.refresh(episode)

        # Create Job
        job = Job(
            episode_id=episode.id,
            stage="UPLOADING",
            status="RUNNING",
            worker="m4_apple_silicon"
        )
        session.add(job)
        await session.commit()
        await session.refresh(job)

        # Progress Callback
        async def on_progress(log):
            stage = log["stage"]
            prog = log["progress"]
            msg = log["message"]
            bar_len = 20
            filled = int(bar_len * (prog / 100.0))
            bar = "█" * filled + "░" * (bar_len - filled)
            print(f"  [{stage:<16}] {bar} {prog:>5.1f}% | {msg}")

        orchestrator = PipelineOrchestrator(db_session=session, progress_callback=on_progress)
        options = DubCreateRequest(
            source_language="ja",
            target_language=target_lang,
            translation_model="auto",
            translation_style="natural_anime"
        )

        try:
            rendered_video = await orchestrator.execute_dubbing_job(
                episode=episode,
                job=job,
                options=options
            )
            print(f"\n========================================================")
            print(f"  DEMO EXECUTION SUCCESSFUL!")
            print(f"  Final Dubbed Video: {rendered_video}")
            print(f"  QA Score:          {episode.qa_score}/100 ({episode.qa_report.get('status')})")
            if episode.subtitle_srt_path:
                print(f"  Hindi Subtitles:   {episode.subtitle_srt_path}")
            print(f"========================================================\n")
        except Exception as e:
            print(f"\n[!] Dubbing Pipeline Error: {e}")
            sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="Anime Dub Studio CLI")
    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # status
    subparsers.add_parser("status", help="Check hardware and AI provider status")

    # demo
    demo_parser = subparsers.add_parser("demo", help="Run end-to-end dubbing demo on a sample file")
    demo_parser.add_argument("sample", help="Path to input media file")
    demo_parser.add_argument("--target", default="hi", help="Target language (default: hi)")

    args = parser.parse_args()

    if args.command == "status":
        asyncio.run(cmd_status())
    elif args.command == "demo":
        asyncio.run(cmd_demo(args.sample, args.target))
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
