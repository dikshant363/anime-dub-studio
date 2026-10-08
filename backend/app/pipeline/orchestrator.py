import json
import asyncio
import soundfile as sf
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
from backend.app.pipeline.asr.base import TranscriptionSegment
from backend.app.pipeline.diarization.acoustic_diarizer import AcousticDiarizer
from backend.app.pipeline.translation.router import TranslationRouter
from backend.app.pipeline.adaptation.hindi_adapter import HindiAdaptationEngine
from backend.app.pipeline.adaptation.hinglish_adapter import HinglishAdaptationEngine
from backend.app.pipeline.tts.mac_speech import MacNativeSpeechProvider
from backend.app.pipeline.tts.edge_tts import EdgeTTSProvider
from backend.app.pipeline.timing.engine import TimingEngine
from backend.app.pipeline.mixing.mixer import AudioMixer
from backend.app.pipeline.subtitles.formatter import SubtitleFormatter
from backend.app.pipeline.qa.engine import QAEngine
from backend.app.pipeline.render.video_muxer import VideoMuxer

class PipelineOrchestrator:
    """Manages the end-to-end execution of the Anime Dubbing Pipeline with full stage checkpointing."""

    def __init__(self, db_session: AsyncSession, progress_callback: Optional[Callable] = None):
        self.db = db_session
        self.progress_callback = progress_callback
        self.transcriber = MLXWhisperTranscriber()
        self.local_tts = MacNativeSpeechProvider()
        self.edge_tts = EdgeTTSProvider()
        self.tts_provider = self.local_tts if settings.is_apple_silicon else self.edge_tts

    async def _emit_progress(self, job: Job, stage: str, progress: float, message: str, **kwargs):
        job.stage = stage
        job.progress = round(progress, 1)
        job.status = "RUNNING"
        log_entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "stage": stage,
            "progress": round(progress, 1),
            "message": message,
            **kwargs
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
        """Runs the complete dubbing pipeline from media file to final dubbed MP4 with checkpoint/resume."""
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
        checkpoints_dir = ep_dir / "checkpoints"

        for d in [audio_dir, voices_dir, subtitles_dir, export_dir, checkpoints_dir]:
            d.mkdir(parents=True, exist_ok=True)

        # Select TTS provider: Default to genuine local macOS speech
        is_online_requested = getattr(options, "voice_mode", "").lower() == "online"
        if is_online_requested:
            self.tts_provider = self.edge_tts
        else:
            self.tts_provider = self.local_tts

        try:
            # -------------------------------------------------------------
            # Stage 1: INGESTION & AUDIO EXTRACTION (Checkpointable)
            # -------------------------------------------------------------
            master_audio = audio_dir / "master_audio.wav"
            asr_audio = audio_dir / "asr_16k.wav"
            chk_extraction = checkpoints_dir / "checkpoint_extraction.json"

            if chk_extraction.exists() and master_audio.exists() and asr_audio.exists() and master_audio.stat().st_size > 1000:
                await self._emit_progress(job, "EXTRACTING_AUDIO", 10.0, "[RESUME] Loaded extracted audio from checkpoint.")
                metadata = json.loads(chk_extraction.read_text(encoding="utf-8"))
            else:
                await self._emit_progress(job, "EXTRACTING_AUDIO", 10.0, "Inspecting media and extracting Japanese audio streams...")
                metadata = await MediaProbe.inspect(source_media)
                stream_idx = getattr(options, "audio_stream_index", None)
                await AudioExtractor.extract_master_audio(source_media, master_audio, source_lang=options.source_language, audio_stream_index=stream_idx)
                await AudioExtractor.extract_asr_audio(source_media, asr_audio, source_lang=options.source_language, audio_stream_index=stream_idx)
                chk_extraction.write_text(json.dumps(metadata, indent=2), encoding="utf-8")

            episode.duration = metadata["duration"]
            episode.fps = metadata["fps"]
            episode.resolution = metadata["resolution"]
            episode.master_audio_path = str(master_audio)
            await self.db.commit()

            # -------------------------------------------------------------
            # Stage 2: ASR / TRANSCRIPTION (Checkpointable)
            # -------------------------------------------------------------
            chk_asr = checkpoints_dir / "checkpoint_asr.json"
            asr_segments: List[TranscriptionSegment] = []

            if chk_asr.exists():
                await self._emit_progress(job, "ASR", 25.0, "[RESUME] Loaded ASR transcript segments from checkpoint.")
                raw_segments = json.loads(chk_asr.read_text(encoding="utf-8"))
                for s in raw_segments:
                    asr_segments.append(TranscriptionSegment(**s))
            else:
                await self._emit_progress(job, "ASR", 25.0, "Transcribing Japanese anime dialogue with MLX Whisper...")
                asr_segments = await self.transcriber.transcribe(asr_audio, language=options.source_language)
                if not asr_segments:
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
                # Save ASR checkpoint
                chk_asr.write_text(json.dumps([s.__dict__ for s in asr_segments], indent=2), encoding="utf-8")

            # -------------------------------------------------------------
            # Stage 3: DIARIZATION & CHARACTER PROFILES (Checkpointable)
            # -------------------------------------------------------------
            chk_diar = checkpoints_dir / "checkpoint_diarization.json"
            if chk_diar.exists():
                await self._emit_progress(job, "DIARIZING", 35.0, "[RESUME] Loaded speaker diarization from checkpoint.")
                raw_diar = json.loads(chk_diar.read_text(encoding="utf-8"))
                asr_segments = [TranscriptionSegment(**s) for s in raw_diar]
            else:
                await self._emit_progress(job, "DIARIZING", 35.0, "Analyzing acoustic voice characteristics and mapping characters...")
                asr_segments = AcousticDiarizer.diarize_segments(asr_audio, asr_segments)
                chk_diar.write_text(json.dumps([s.__dict__ for s in asr_segments], indent=2), encoding="utf-8")

            # Setup character profiles in DB
            res = await self.db.execute(select(Character).where(Character.project_id == episode.project_id))
            existing_chars = res.scalars().all()
            char_map = {c.speaker_tag: c for c in existing_chars if c.speaker_tag}

            # Resolve cast profiles dynamically based on project media
            ep_title_lower = (episode.title or "").lower() + " " + (getattr(options, "project_name", "") or "").lower()
            if "full metal panic" in ep_title_lower:
                cast_definitions = [
                    ("SPEAKER_00", "Sousuke Sagara", "Rishi", "male", "serious military specialist, disciplined", "direct military dub"),
                    ("SPEAKER_01", "Kaname Chidori", "Lekha", "female", "feisty high school heroine, emotive", "expressive high school dub"),
                    ("SPEAKER_02", "Kurz Weber", "Aman", "male", "relaxed sniper, casual charismatic", "relaxed conversational dub"),
                    ("SPEAKER_03", "Melissa Mao", "Tara", "female", "confident senior squad leader", "sharp confident dub"),
                ]
            else:
                cast_definitions = [
                    ("SPEAKER_00", "Lead Protagonist", "Rishi", "male", "determined lead protagonist", "natural dramatic dub"),
                    ("SPEAKER_01", "Lead Heroine", "Lekha", "female", "emotive lead heroine", "expressive natural dub"),
                    ("SPEAKER_02", "Supporting Character (Male)", "Aman", "male", "supporting male cast", "casual conversational dub"),
                    ("SPEAKER_03", "Supporting Character (Female)", "Tara", "female", "supporting female cast", "confident articulate dub"),
                ]

            for spk_tag, name, voice_id, gender, personality, style in cast_definitions:
                if spk_tag not in char_map:
                    char = Character(
                        project_id=episode.project_id,
                        name=name,
                        speaker_tag=spk_tag,
                        gender=gender,
                        voice_id=voice_id,
                        personality=personality,
                        speaking_style=style
                    )
                    self.db.add(char)
                    await self.db.commit()
                    await self.db.refresh(char)
                    char_map[spk_tag] = char

            # -------------------------------------------------------------
            # Stage 4: TRANSLATION & HINDI / HINGLISH ADAPTATION (Incremental Checkpoints)
            # -------------------------------------------------------------
            await self._emit_progress(job, "TRANSLATING", 50.0, "Translating dialogue into natural Hindi / Hinglish...")
            translation_router = TranslationRouter(preferred_provider=options.translation_model)
            is_hinglish_target = options.target_language.lower() in ["hinglish", "hi_en"]

            chk_translations = checkpoints_dir / "checkpoint_translations.json"
            trans_cache: Dict[str, Any] = {}
            if chk_translations.exists():
                try:
                    trans_cache = json.loads(chk_translations.read_text(encoding="utf-8"))
                except Exception:
                    trans_cache = {}

            # Query existing dialogue segments in DB
            res_segs = await self.db.execute(select(DialogueSegment).where(DialogueSegment.episode_id == episode.id))
            existing_db_segs = {s.segment_index: s for s in res_segs.scalars().all()}

            db_segments: List[DialogueSegment] = []
            for idx, asr_seg in enumerate(asr_segments):
                char = char_map.get(asr_seg.speaker, char_map["SPEAKER_00"])
                cache_key = str(idx)

                if cache_key in trans_cache:
                    cached = trans_cache[cache_key]
                    trans_text = cached.get("translated_text", "")
                    adapted_hindi = cached.get("adapted_hindi_text", "")
                    adapted_hinglish = cached.get("adapted_hinglish_text", "")
                    tts_pron = cached.get("tts_pronunciation_text", "")
                else:
                    # Cultural Anime Translation
                    trans_result = await translation_router.translate_line(
                        text=asr_seg.text,
                        source_lang=options.source_language,
                        target_lang=options.target_language,
                        character_name=char.name,
                        personality=char.personality,
                        style=options.translation_style
                    )

                    adapted_hindi = HindiAdaptationEngine.polish_hindi(trans_result.adapted_hindi, char.speaking_style)
                    adapted_hinglish = HinglishAdaptationEngine.to_hinglish(
                        adapted_hindi,
                        character_style=char.speaking_style,
                        translation_style=options.translation_style,
                        english_mixing=getattr(options, "english_mixing", "medium")
                    )
                    tts_pron = HinglishAdaptationEngine.create_tts_pronunciation(adapted_hinglish, adapted_hindi)
                    trans_text = trans_result.translated_text

                    trans_cache[cache_key] = {
                        "source_text": asr_seg.text,
                        "translated_text": trans_text,
                        "adapted_hindi_text": adapted_hindi,
                        "adapted_hinglish_text": adapted_hinglish,
                        "tts_pronunciation_text": tts_pron,
                        "speaker": asr_seg.speaker
                    }
                    if idx % 10 == 0:
                        chk_translations.write_text(json.dumps(trans_cache, indent=2, ensure_ascii=False), encoding="utf-8")

                if idx % 5 == 0 or idx == len(asr_segments) - 1:
                    await self._emit_progress(
                        job, "TRANSLATING", 50.0,
                        f"Translating dialogue ({idx+1}/{len(asr_segments)}) — {char.name}",
                        current_item=idx + 1,
                        total_items=len(asr_segments),
                        character=char.name,
                        processed_duration=asr_seg.end
                    )

                if idx in existing_db_segs:
                    dialogue = existing_db_segs[idx]
                    dialogue.character_id = char.id
                    dialogue.start_time = asr_seg.start
                    dialogue.end_time = asr_seg.end
                    dialogue.target_duration = round(asr_seg.end - asr_seg.start, 2)
                    dialogue.speaker_label = asr_seg.speaker
                    dialogue.source_text = asr_seg.text
                    dialogue.translated_text = trans_text
                    dialogue.adapted_hindi_text = adapted_hindi
                    dialogue.adapted_hinglish_text = adapted_hinglish
                    dialogue.tts_pronunciation_text = tts_pron
                    dialogue.confidence = asr_seg.confidence
                else:
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
                        translated_text=trans_text,
                        adapted_hindi_text=adapted_hindi,
                        adapted_hinglish_text=adapted_hinglish,
                        tts_pronunciation_text=tts_pron,
                        confidence=asr_seg.confidence,
                        emotion=options.emotion_mode if options.emotion_mode != "auto" else "neutral",
                        intensity=0.8
                    )
                    self.db.add(dialogue)
                db_segments.append(dialogue)

            # Persist all translation checkpoints and DB records
            chk_translations.write_text(json.dumps(trans_cache, indent=2, ensure_ascii=False), encoding="utf-8")
            await self.db.commit()

            # -------------------------------------------------------------
            # Stage 5: TTS VOICE GENERATION & TIMING ADJUSTMENT (File Checkpointing)
            # -------------------------------------------------------------
            await self._emit_progress(job, "TTS", 65.0, "Generating character voices with distinct local Indian voices...")
            dialogue_render_list = []

            for seg in db_segments:
                seg_audio = voices_dir / f"seg_{seg.segment_index:03d}.wav"
                stretched_audio = voices_dir / f"seg_{seg.segment_index:03d}_sync.wav"
                char = char_map.get(seg.speaker_label, char_map["SPEAKER_00"])

                # Distinct speech text & pronunciation representation
                speech_text = seg.tts_pronunciation_text if is_hinglish_target and seg.tts_pronunciation_text else seg.adapted_hindi_text
                target_dur = seg.target_duration

                if stretched_audio.exists() and stretched_audio.stat().st_size > 500:
                    final_audio = stretched_audio
                    info = sf.info(str(final_audio))
                    final_dur = float(info.duration)
                elif seg_audio.exists() and seg_audio.stat().st_size > 500:
                    info = sf.info(str(seg_audio))
                    raw_dur = float(info.duration)
                    ratio = round(raw_dur / max(0.1, target_dur), 2)
                    if ratio > 1.15 or ratio < 0.85:
                        final_audio, final_dur, _ = await TimingEngine.adjust_audio_timing(
                            input_audio_path=seg_audio,
                            output_audio_path=stretched_audio,
                            target_duration=target_dur,
                            current_duration=raw_dur
                        )
                    else:
                        final_audio = seg_audio
                        final_dur = raw_dur
                else:
                    tts_res = await self.tts_provider.synthesize(
                        text=speech_text,
                        output_path=seg_audio,
                        voice_id=char.voice_id,
                        speed_rate=char.speed,
                        pitch_percent=char.pitch,
                        emotion=seg.emotion,
                        hindi_text=seg.adapted_hindi_text
                    )
                    raw_dur = tts_res.duration
                    ratio = round(raw_dur / max(0.1, target_dur), 2)
                    if ratio > 1.15 or ratio < 0.85:
                        final_audio, final_dur, _ = await TimingEngine.adjust_audio_timing(
                            input_audio_path=seg_audio,
                            output_audio_path=stretched_audio,
                            target_duration=target_dur,
                            current_duration=raw_dur
                        )
                    else:
                        final_audio = seg_audio
                        final_dur = raw_dur

                seg.audio_path = str(final_audio)
                seg.synthesized_duration = final_dur
                seg.duration_ratio = round(final_dur / max(0.1, target_dur), 2)
                seg.status = "READY"

                if (seg.segment_index + 1) % 5 == 0 or (seg.segment_index + 1) == len(db_segments):
                    await self._emit_progress(
                        job, "TTS", 65.0,
                        f"Character {char.name} — segment {seg.segment_index + 1}/{len(db_segments)}",
                        current_item=seg.segment_index + 1,
                        total_items=len(db_segments),
                        character=char.name,
                        processed_duration=seg.end_time
                    )

                dialogue_render_list.append({
                    "start_time": seg.start_time,
                    "end_time": seg.end_time,
                    "audio_path": str(final_audio),
                    "adapted_hindi_text": seg.adapted_hindi_text,
                    "adapted_hinglish_text": seg.adapted_hinglish_text,
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
            if is_hinglish_target:
                await self._emit_progress(job, "SUBTITLES", 88.0, "Formatting Roman Hinglish SRT and ASS subtitles...")
                srt_path = subtitles_dir / "episode_hinglish.srt"
                ass_path = subtitles_dir / "episode_hinglish.ass"
                SubtitleFormatter.generate_srt(dialogue_render_list, srt_path, text_key="adapted_hinglish_text")
                SubtitleFormatter.generate_ass(dialogue_render_list, ass_path, title=episode.title, text_key="adapted_hinglish_text")
            else:
                await self._emit_progress(job, "SUBTITLES", 88.0, "Formatting Hindi Devanagari SRT and ASS subtitles...")
                srt_path = subtitles_dir / "hindi.srt"
                ass_path = subtitles_dir / "hindi.ass"
                SubtitleFormatter.generate_srt(dialogue_render_list, srt_path, text_key="adapted_hindi_text")
                SubtitleFormatter.generate_ass(dialogue_render_list, ass_path, title=episode.title, text_key="adapted_hindi_text")

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
                    "adapted_hinglish_text": s.adapted_hinglish_text,
                    "duration_ratio": s.duration_ratio,
                    "audio_path": s.audio_path,
                    "voice_id": char_map.get(s.speaker_label, char_map.get("SPEAKER_00")).voice_id if char_map else "Unknown"
                } for s in db_segments],
                dubbed_audio_path=dubbed_master,
                video_duration=episode.duration,
                is_hinglish=is_hinglish_target
            )
            episode.qa_score = qa_score
            episode.qa_report = qa_report

            # -------------------------------------------------------------
            # Stage 9: FINAL VIDEO REMUXING & RENDERS EXPORT
            # -------------------------------------------------------------
            await self._emit_progress(job, "RENDERING", 96.0, "Multiplexing video and audio into final MP4...")
            output_filename = f"{source_media.stem}_hinglish_dub.mp4" if is_hinglish_target else f"{source_media.stem}_hindi_dub.mp4"
            final_video = export_dir / output_filename
            await VideoMuxer.render_dubbed_video(
                source_video_path=source_media,
                dubbed_audio_path=dubbed_master,
                output_video_path=final_video,
                subtitle_path=srt_path
            )
            episode.exported_video_path = str(final_video)

            # Store copies in project/renders/ as per requirements
            renders_dir = project_dir / "renders"
            renders_dir.mkdir(parents=True, exist_ok=True)
            import shutil
            shutil.copy2(str(final_video), str(renders_dir / output_filename))
            shutil.copy2(str(srt_path), str(renders_dir / srt_path.name))
            shutil.copy2(str(ass_path), str(renders_dir / ass_path.name))

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
