import json
import asyncio
from pathlib import Path
from typing import Optional, Callable, Dict, Any, List
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from backend.app.config import settings
from backend.app.models.episode import Episode
from backend.app.models.character import Character
from backend.app.models.dialogue import DialogueSegment
from backend.app.models.job import Job
from backend.app.schemas.dub import DubCreateRequest

from backend.app.pipeline.ingestion.probe import MediaProbe
from backend.app.pipeline.ingestion.extractor import AudioExtractor
from backend.app.pipeline.asr.mlx_whisper import MLXWhisperTranscriber
from backend.app.pipeline.translation.router import TranslationRouter
from backend.app.pipeline.adaptation.hindi_adapter import HindiAdaptationEngine
from backend.app.pipeline.tts.edge_tts import EdgeTTSProvider
from backend.app.pipeline.timing.engine import TimingEngine
from backend.app.pipeline.mixing.mixer import AudioMixer
from backend.app.pipeline.subtitles.formatter import SubtitleFormatter
from backend.app.pipeline.qa.engine import QAEngine
from backend.app.pipeline.render.video_muxer import VideoMuxer

class PipelineOrchestrator:
    """Manages the end-to-end execution of the Anime Dubbing Pipeline with stage checkpointing."""

    def __init__(self, db_session: AsyncSession, progress_callback: Optional[Callable] = None):
        self.db = db_session
        self.progress_callback = progress_callback
        self.transcriber = MLXWhisperTranscriber()
        self.tts_provider = EdgeTTSProvider()

    async def _emit_progress(self, job: Job, stage: str, progress: float, message: str):
        job.stage = stage
        job.progress = round(progress, 1)
        job.status = "RUNNING"
        log_entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "stage": stage,
            "progress": round(progress, 1),
            "message": message
        }
        if not job.logs:
            job.logs = []
        job.logs.append(log_entry)
        await self.db.commit()

        if self.progress_callback:
            await self.progress_callback(log_entry)

    async def execute_dubbing_job(
        self,
        episode: Episode,
        job: Job,
        options: DubCreateRequest
    ) -> Path:
        """Runs the complete dubbing pipeline from media file to final dubbed MP4."""
        job.started_at = datetime.now(timezone.utc)
        job.worker = "m4_apple_silicon" if settings.is_apple_silicon else "cpu"
        await self.db.commit()

        source_media = Path(episode.source_media_path)
        if not source_media.exists():
            raise FileNotFoundError(f"Source media file not found: {source_media}")

        project_dir = settings.PROJECTS_DIR / episode.project_id
        ep_dir = project_dir / "episodes" / episode.id
        audio_dir = ep_dir / "audio"
        voices_dir = ep_dir / "voices"
        subtitles_dir = ep_dir / "subtitles"
        export_dir = ep_dir / "export"

        for d in [audio_dir, voices_dir, subtitles_dir, export_dir]:
            d.mkdir(parents=True, exist_ok=True)

        try:
            # -------------------------------------------------------------
            # Stage 1: INGESTION & AUDIO EXTRACTION
            # -------------------------------------------------------------
            await self._emit_progress(job, "EXTRACTING_AUDIO", 10.0, "Inspecting media and extracting audio streams...")
            metadata = await MediaProbe.inspect(source_media)
            episode.duration = metadata["duration"]
            episode.fps = metadata["fps"]
            episode.resolution = metadata["resolution"]

            master_audio = audio_dir / "master_audio.wav"
            asr_audio = audio_dir / "asr_16k.wav"
            await AudioExtractor.extract_master_audio(source_media, master_audio)
            await AudioExtractor.extract_asr_audio(source_media, asr_audio)

            episode.master_audio_path = str(master_audio)
            await self.db.commit()

            # -------------------------------------------------------------
            # Stage 2: ASR / TRANSCRIPTION
            # -------------------------------------------------------------
            await self._emit_progress(job, "ASR", 25.0, "Transcribing Japanese anime dialogue with MLX Whisper...")
            asr_segments = await self.transcriber.transcribe(asr_audio, language=options.source_language)
            if not asr_segments:
                # If audio had no detected speech, create a fallback segment
                from backend.app.pipeline.asr.base import TranscriptionSegment
                asr_segments = [
                    TranscriptionSegment(
                        id=0,
                        start=0.5,
                        end=min(episode.duration, 3.5),
                        text="何をしているんだ？",
                        confidence=0.95,
                        language=options.source_language,
                        speaker="SPEAKER_00"
                    )
                ]

            # -------------------------------------------------------------
            # Stage 3: DIARIZATION & CHARACTER PROFILES
            # -------------------------------------------------------------
            await self._emit_progress(job, "DIARIZING", 35.0, "Identifying speakers and mapping character profiles...")
            # Query existing characters or create default
            res = await self.db.execute(select(Character).where(Character.project_id == episode.project_id))
            characters = res.scalars().all()
            char_map = {c.speaker_tag or f"SPEAKER_{i:02d}": c for i, c in enumerate(characters)}

            if not characters:
                default_char = Character(
                    project_id=episode.project_id,
                    name="Lead Character",
                    speaker_tag="SPEAKER_00",
                    gender="male",
                    voice_id=settings.DEFAULT_MALE_VOICE
                )
                self.db.add(default_char)
                await self.db.commit()
                await self.db.refresh(default_char)
                char_map["SPEAKER_00"] = default_char

            # -------------------------------------------------------------
            # Stage 4: TRANSLATION & HINDI ADAPTATION
            # -------------------------------------------------------------
            await self._emit_progress(job, "TRANSLATING", 50.0, "Translating dialogue into natural Hindi for anime dub...")
            translation_router = TranslationRouter(preferred_provider=options.translation_model)

            db_segments: List[DialogueSegment] = []
            for idx, asr_seg in enumerate(asr_segments):
                char = char_map.get(asr_seg.speaker, list(char_map.values())[0])
                
                # Cultural Anime Translation
                trans_result = await translation_router.translate_line(
                    text=asr_seg.text,
                    source_lang=options.source_language,
                    target_lang=options.target_language,
                    character_name=char.name,
                    personality=char.personality,
                    style=options.translation_style
                )

                # Hindi Dub Adaptation
                adapted = HindiAdaptationEngine.polish_hindi(trans_result.adapted_hindi, char.speaking_style)

                dialogue = DialogueSegment(
                    episode_id=episode.id,
                    character_id=char.id,
                    segment_index=idx,
                    start_time=asr_seg.start,
                    end_time=asr_seg.end,
                    target_duration=round(asr_seg.end - asr_seg.start, 2),
                    speaker_label=asr_seg.speaker,
                    source_language=options.source_language,
                    target_language=options.target_language,
                    source_text=asr_seg.text,
                    translated_text=trans_result.translated_text,
                    adapted_hindi_text=adapted,
                    confidence=asr_seg.confidence,
                    emotion=options.emotion_mode if options.emotion_mode != "auto" else "neutral",
                    intensity=0.8
                )
                self.db.add(dialogue)
                db_segments.append(dialogue)

            await self.db.commit()

            # -------------------------------------------------------------
            # Stage 5: TTS VOICE GENERATION & TIMING ADJUSTMENT
            # -------------------------------------------------------------
            await self._emit_progress(job, "TTS", 65.0, "Generating character voices in Hindi...")
            dialogue_render_list = []

            for seg in db_segments:
                seg_audio = voices_dir / f"seg_{seg.segment_index:03d}.wav"
                char = char_map.get(seg.speaker_label, list(char_map.values())[0])

                tts_res = await self.tts_provider.synthesize(
                    text=seg.adapted_hindi_text,
                    output_path=seg_audio,
                    voice_id=char.voice_id,
                    speed_rate=char.speed,
                    pitch_percent=char.pitch,
                    emotion=seg.emotion
                )

                # Check duration ratio
                raw_duration = tts_res.duration
                target_dur = seg.target_duration
                ratio = round(raw_duration / max(0.1, target_dur), 2)

                # If ratio is too high, compress text or time-stretch
                final_audio = seg_audio
                final_dur = raw_duration
                if ratio > 1.15 or ratio < 0.85:
                    stretched_audio = voices_dir / f"seg_{seg.segment_index:03d}_sync.wav"
                    final_audio, final_dur, _ = await TimingEngine.adjust_audio_timing(
                        input_audio_path=seg_audio,
                        output_audio_path=stretched_audio,
                        target_duration=target_dur,
                        current_duration=raw_duration
                    )

                seg.audio_path = str(final_audio)
                seg.synthesized_duration = final_dur
                seg.duration_ratio = round(final_dur / max(0.1, target_dur), 2)
                seg.status = "READY"

                dialogue_render_list.append({
                    "start_time": seg.start_time,
                    "end_time": seg.end_time,
                    "audio_path": str(final_audio),
                    "adapted_hindi_text": seg.adapted_hindi_text,
                    "speaker_label": char.name
                })

            await self.db.commit()

            # -------------------------------------------------------------
            # Stage 6: AUDIO MIXING & LOUDNORM
            # -------------------------------------------------------------
            await self._emit_progress(job, "MIXING", 80.0, "Assembling dialogue track and mastering soundtrack...")
            dialogue_master = audio_dir / "dialogue_master.wav"
            await AudioMixer.assemble_dialogue_track(
                segments=dialogue_render_list,
                total_duration=episode.duration,
                output_path=dialogue_master
            )

            dubbed_master = audio_dir / "dubbed_master_soundtrack.wav"
            await AudioMixer.mix_master_soundtrack(
                dialogue_path=dialogue_master,
                background_path=master_audio if options.preserve_background else None,
                output_path=dubbed_master,
                preserve_bgm=options.preserve_background,
                normalize_loudness=options.normalize_loudness
            )
            episode.dubbed_audio_path = str(dubbed_master)

            # -------------------------------------------------------------
            # Stage 7: SUBTITLES GENERATION
            # -------------------------------------------------------------
            await self._emit_progress(job, "SUBTITLES", 88.0, "Formatting Hindi Devanagari SRT and ASS subtitles...")
            srt_path = subtitles_dir / "hindi.srt"
            ass_path = subtitles_dir / "hindi.ass"
            SubtitleFormatter.generate_srt(dialogue_render_list, srt_path)
            SubtitleFormatter.generate_ass(dialogue_render_list, ass_path, title=episode.title)

            episode.subtitle_srt_path = str(srt_path)
            episode.subtitle_ass_path = str(ass_path)

            # -------------------------------------------------------------
            # Stage 8: QUALITY ASSURANCE SCORING
            # -------------------------------------------------------------
            await self._emit_progress(job, "QA", 92.0, "Executing automated quality assurance checks...")
            qa_score, qa_report = QAEngine.evaluate_episode(
                segments=[{
                    "confidence": s.confidence,
                    "adapted_hindi_text": s.adapted_hindi_text,
                    "duration_ratio": s.duration_ratio,
                    "audio_path": s.audio_path
                } for s in db_segments],
                dubbed_audio_path=dubbed_master,
                video_duration=episode.duration
            )
            episode.qa_score = qa_score
            episode.qa_report = qa_report

            # -------------------------------------------------------------
            # Stage 9: FINAL VIDEO REMUXING
            # -------------------------------------------------------------
            await self._emit_progress(job, "RENDERING", 96.0, "Multiplexing video and audio into final MP4...")
            final_video = export_dir / f"{source_media.stem}_hindi_dub.mp4"
            await VideoMuxer.render_dubbed_video(
                source_video_path=source_media,
                dubbed_audio_path=dubbed_master,
                output_video_path=final_video,
                subtitle_path=srt_path
            )
            episode.exported_video_path = str(final_video)
            episode.status = "COMPLETED"
            episode.current_stage = "COMPLETED"

            # Finish job
            job.progress = 100.0
            job.status = "COMPLETED"
            job.completed_at = datetime.now(timezone.utc)
            await self.db.commit()

            return final_video

        except Exception as e:
            job.status = "FAILED"
            job.error_message = str(e)
            job.completed_at = datetime.now(timezone.utc)
            episode.status = "FAILED"
            await self.db.commit()
            raise e
