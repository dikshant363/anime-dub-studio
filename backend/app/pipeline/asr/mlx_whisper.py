import math
import asyncio
from pathlib import Path
from typing import List, Optional
from backend.app.pipeline.asr.base import Transcriber, TranscriptionSegment

class MLXWhisperTranscriber(Transcriber):
    """Whisper ASR inference accelerated by Apple Silicon MLX & Metal GPU."""

    def __init__(self, model_name: str = "mlx-community/whisper-tiny-mlx"):
        self.model_name = model_name

    async def transcribe(
        self,
        audio_path: Path,
        language: Optional[str] = "ja"
    ) -> List[TranscriptionSegment]:
        if not audio_path.exists():
            raise FileNotFoundError(f"Audio file does not exist: {audio_path}")

        # Execute MLX Whisper in a thread pool to preserve event loop reactivity
        result = await asyncio.to_thread(self._run_transcription, str(audio_path), language)
        return self._format_segments(result, language or "ja")

    def _run_transcription(self, audio_str: str, language: Optional[str]) -> dict:
        import mlx_whisper
        kwargs = {
            "path_or_hf_repo": self.model_name,
            "word_timestamps": True
        }
        if language:
            kwargs["language"] = language

        return mlx_whisper.transcribe(audio_str, **kwargs)

    def _format_segments(self, raw_result: dict, language: str) -> List[TranscriptionSegment]:
        formatted = []
        raw_segments = raw_result.get("segments", [])

        for idx, seg in enumerate(raw_segments):
            text = seg.get("text", "").strip()
            if not text:
                continue

            start = float(seg.get("start", 0.0))
            end = float(seg.get("end", start + 1.0))
            if end <= start:
                end = start + 0.5

            logprob = seg.get("avg_logprob", 0.0)
            confidence = round(max(0.0, min(1.0, math.exp(logprob))), 3) if logprob else 0.95

            formatted.append(
                TranscriptionSegment(
                    id=idx,
                    start=round(start, 2),
                    end=round(end, 2),
                    text=text,
                    confidence=confidence,
                    language=language,
                    speaker="SPEAKER_00"
                )
            )

        return formatted
