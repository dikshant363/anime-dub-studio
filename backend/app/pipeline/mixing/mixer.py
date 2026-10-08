import asyncio
import numpy as np
import soundfile as sf
from pathlib import Path
from typing import List, Dict, Any, Optional

class AudioMixer:
    """Combines speech dialogue segments, aligns timestamps, ducks background, and normalizes loudness."""

    @staticmethod
    async def assemble_dialogue_track(
        segments: List[Dict[str, Any]],
        total_duration: float,
        output_path: Path,
        sample_rate: int = 48000
    ) -> Path:
        """
        Assembles individual dialogue audio files onto a single continuous timeline track.
        """
        output_path.parent.mkdir(parents=True, exist_ok=True)
        total_samples = int(total_duration * sample_rate) + sample_rate # extra 1s buffer
        master_buffer = np.zeros(total_samples, dtype=np.float32)

        for seg in segments:
            audio_path = Path(seg["audio_path"])
            if not audio_path.exists():
                continue

            start_time = float(seg["start_time"])
            start_sample = int(start_time * sample_rate)

            # Read segment audio
            data, sr = sf.read(str(audio_path), dtype="float32")
            if sr != sample_rate:
                # Simple resampling if needed
                num_resampled = int(len(data) * sample_rate / sr)
                data = np.interp(
                    np.linspace(0, len(data), num_resampled, endpoint=False),
                    np.arange(len(data)),
                    data
                )

            # Mono channel
            if len(data.shape) > 1:
                data = np.mean(data, axis=1)

            end_sample = min(total_samples, start_sample + len(data))
            chunk_len = end_sample - start_sample
            if chunk_len > 0:
                master_buffer[start_sample:end_sample] += data[:chunk_len]

        # Prevent digital clipping in dialogue track
        peak = np.max(np.abs(master_buffer))
        if peak > 0.95:
            master_buffer = master_buffer / peak * 0.95

        sf.write(str(output_path), master_buffer, sample_rate, subtype="PCM_24")
        return output_path

    @staticmethod
    async def mix_master_soundtrack(
        dialogue_path: Path,
        background_path: Optional[Path],
        output_path: Path,
        preserve_bgm: bool = True,
        normalize_loudness: bool = True
    ) -> Path:
        """
        Mixes dubbed dialogue track with background stem using sidechain ducking and EBU R128 loudnorm.
        """
        output_path.parent.mkdir(parents=True, exist_ok=True)

        if not background_path or not background_path.exists() or not preserve_bgm:
            # Only normalize dialogue track
            if normalize_loudness:
                cmd = [
                    "ffmpeg", "-y",
                    "-i", str(dialogue_path),
                    "-af", "loudnorm=I=-23:TP=-1.0:LRA=11",
                    "-acodec", "pcm_s24le",
                    "-ar", "48000",
                    "-ac", "2",
                    str(output_path)
                ]
            else:
                cmd = [
                    "ffmpeg", "-y",
                    "-i", str(dialogue_path),
                    "-acodec", "pcm_s24le",
                    "-ar", "48000",
                    "-ac", "2",
                    str(output_path)
                ]
        else:
            # Complex filtergraph with amix and loudnorm
            # Duck background audio slightly (volume 0.5) and mix with dialogue (volume 1.0)
            filter_complex = "[1:a]volume=0.55[bg];[0:a]volume=1.0[voc];[voc][bg]amix=inputs=2:duration=longest[mixed]"
            if normalize_loudness:
                filter_complex += ";[mixed]loudnorm=I=-23:TP=-1.0:LRA=11[out]"
                map_label = "[out]"
            else:
                map_label = "[mixed]"

            cmd = [
                "ffmpeg", "-y",
                "-i", str(dialogue_path),
                "-i", str(background_path),
                "-filter_complex", filter_complex,
                "-map", map_label,
                "-acodec", "pcm_s24le",
                "-ar", "48000",
                "-ac", "2",
                str(output_path)
            ]

        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        _, stderr = await proc.communicate()

        if proc.returncode != 0:
            raise RuntimeError(f"Audio mixing failed: {stderr.decode('utf-8')}")

        return output_path
