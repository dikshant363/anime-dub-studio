import asyncio
from pathlib import Path

class AudioExtractor:
    """Extracts master and ASR-normalized audio streams from video files using FFmpeg,
    intelligently selecting the source dialogue track (e.g. Japanese in dual-audio MKVs).
    """

    @staticmethod
    async def extract_master_audio(media_path: Path, output_path: Path, source_lang: str = "ja", audio_stream_index: int = None) -> Path:
        """Extracts 48kHz 24-bit stereo WAV for high-fidelity master editing and mixing."""
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        # 1. Try explicit stream index if provided
        if audio_stream_index is not None:
            cmd_explicit = [
                "ffmpeg", "-y", "-i", str(media_path),
                "-map", f"0:{audio_stream_index}",
                "-vn", "-acodec", "pcm_s24le", "-ar", "48000", "-ac", "2",
                str(output_path)
            ]
            proc = await asyncio.create_subprocess_exec(*cmd_explicit, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
            await proc.communicate()
            if proc.returncode == 0 and output_path.exists() and output_path.stat().st_size > 1000:
                return output_path

        # 2. Try language-mapped stream first (e.g. 'jpn' in dual-audio MKV)
        lang_tag = "jpn" if source_lang in ["ja", "jpn", "japanese"] else source_lang
        cmd_mapped = [
            "ffmpeg", "-y", "-i", str(media_path),
            "-map", f"0:m:language:{lang_tag}",
            "-vn", "-acodec", "pcm_s24le", "-ar", "48000", "-ac", "2",
            str(output_path)
        ]
        proc = await asyncio.create_subprocess_exec(*cmd_mapped, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
        await proc.communicate()
        if proc.returncode == 0 and output_path.exists() and output_path.stat().st_size > 1000:
            return output_path

        # 3. Fallback to default audio stream
        cmd = [
            "ffmpeg", "-y", "-i", str(media_path),
            "-vn", "-acodec", "pcm_s24le", "-ar", "48000", "-ac", "2",
            str(output_path)
        ]
        proc = await asyncio.create_subprocess_exec(*cmd, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
        _, stderr = await proc.communicate()
        if proc.returncode != 0:
            raise RuntimeError(f"Audio extraction failed: {stderr.decode('utf-8')}")

        return output_path

    @staticmethod
    async def extract_asr_audio(media_path: Path, output_path: Path, source_lang: str = "ja", audio_stream_index: int = None) -> Path:
        """Extracts 16kHz 16-bit mono WAV optimal for Whisper/MLX speech recognition."""
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        # 1. Try explicit stream index if provided
        if audio_stream_index is not None:
            cmd_explicit = [
                "ffmpeg", "-y", "-i", str(media_path),
                "-map", f"0:{audio_stream_index}",
                "-vn", "-acodec", "pcm_s16le", "-ar", "16000", "-ac", "1",
                str(output_path)
            ]
            proc = await asyncio.create_subprocess_exec(*cmd_explicit, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
            await proc.communicate()
            if proc.returncode == 0 and output_path.exists() and output_path.stat().st_size > 1000:
                return output_path

        # 2. Try language-mapped stream
        lang_tag = "jpn" if source_lang in ["ja", "jpn", "japanese"] else source_lang
        cmd_mapped = [
            "ffmpeg", "-y", "-i", str(media_path),
            "-map", f"0:m:language:{lang_tag}",
            "-vn", "-acodec", "pcm_s16le", "-ar", "16000", "-ac", "1",
            str(output_path)
        ]
        proc = await asyncio.create_subprocess_exec(*cmd_mapped, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
        await proc.communicate()
        if proc.returncode == 0 and output_path.exists() and output_path.stat().st_size > 1000:
            return output_path

        # 3. Fallback to default
        cmd = [
            "ffmpeg", "-y", "-i", str(media_path),
            "-vn", "-acodec", "pcm_s16le", "-ar", "16000", "-ac", "1",
            str(output_path)
        ]
        proc = await asyncio.create_subprocess_exec(*cmd, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
        _, stderr = await proc.communicate()
        if proc.returncode != 0:
            raise RuntimeError(f"ASR audio extraction failed: {stderr.decode('utf-8')}")

        return output_path

