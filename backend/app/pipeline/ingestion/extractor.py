import asyncio
from pathlib import Path

class AudioExtractor:
    """Extracts master and ASR-normalized audio streams from video files using FFmpeg."""

    @staticmethod
    async def extract_master_audio(media_path: Path, output_path: Path) -> Path:
        """Extracts 48kHz 24-bit stereo WAV for high-fidelity master editing and mixing."""
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        cmd = [
            "ffmpeg",
            "-y",
            "-i", str(media_path),
            "-vn",
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
            raise RuntimeError(f"Audio extraction failed: {stderr.decode('utf-8')}")

        return output_path

    @staticmethod
    async def extract_asr_audio(media_path: Path, output_path: Path) -> Path:
        """Extracts 16kHz 16-bit mono WAV optimal for Whisper/MLX speech recognition."""
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        cmd = [
            "ffmpeg",
            "-y",
            "-i", str(media_path),
            "-vn",
            "-acodec", "pcm_s16le",
            "-ar", "16000",
            "-ac", "1",
            str(output_path)
        ]

        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        _, stderr = await proc.communicate()

        if proc.returncode != 0:
            raise RuntimeError(f"ASR audio extraction failed: {stderr.decode('utf-8')}")

        return output_path
