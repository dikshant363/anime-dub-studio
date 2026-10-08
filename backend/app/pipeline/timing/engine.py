import asyncio
import soundfile as sf
from pathlib import Path
from typing import Tuple, Dict, Any

class TimingEngine:
    """Manages duration ratio analysis, WSOLA time-stretching, and audio alignment."""

    @staticmethod
    async def adjust_audio_timing(
        input_audio_path: Path,
        output_audio_path: Path,
        target_duration: float,
        current_duration: float,
        max_stretch_factor: float = 1.30,
        min_stretch_factor: float = 0.75,
    ) -> Tuple[Path, float, float]:
        """
        Adjusts audio duration to fit target duration using FFmpeg atempo filter.
        Returns: (output_path, final_duration, speed_ratio)
        """
        if target_duration <= 0 or current_duration <= 0:
            return input_audio_path, current_duration, 1.0

        ratio = current_duration / target_duration

        # If already within 5% tolerance, leave untouched
        if 0.95 <= ratio <= 1.05:
            output_audio_path.parent.mkdir(parents=True, exist_ok=True)
            if input_audio_path != output_audio_path:
                output_audio_path.write_bytes(input_audio_path.read_bytes())
            return output_audio_path, current_duration, 1.0

        # Clamp stretch factor to avoid robotic chipmunk or slow-motion audio
        clamped_ratio = max(min_stretch_factor, min(max_stretch_factor, ratio))

        # FFmpeg atempo filter takes tempo change factor (tempo > 1 means faster/shorter)
        # Note: atempo must be between 0.5 and 2.0
        atempo_val = round(clamped_ratio, 3)

        output_audio_path.parent.mkdir(parents=True, exist_ok=True)
        cmd = [
            "ffmpeg",
            "-y",
            "-i", str(input_audio_path),
            "-filter:a", f"atempo={atempo_val}",
            "-acodec", "pcm_s16le",
            "-ar", "24000",
            "-ac", "1",
            str(output_audio_path)
        ]

        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        _, stderr = await proc.communicate()

        if proc.returncode != 0:
            # Fall back to original file if stretching failed
            return input_audio_path, current_duration, 1.0

        final_duration = float(sf.info(str(output_audio_path)).duration)
        return output_audio_path, round(final_duration, 3), clamped_ratio
