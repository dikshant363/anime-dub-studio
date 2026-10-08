import json
import asyncio
from pathlib import Path
from typing import Dict, Any, Optional

class MediaProbe:
    """Probes media container and stream metadata using ffprobe."""

    @staticmethod
    async def inspect(media_path: Path) -> Dict[str, Any]:
        if not media_path.exists():
            raise FileNotFoundError(f"Media file does not exist: {media_path}")

        cmd = [
            "ffprobe",
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            str(media_path)
        ]

        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, stderr = await proc.communicate()

        if proc.returncode != 0:
            raise RuntimeError(f"ffprobe failed: {stderr.decode('utf-8')}")

        data = json.loads(stdout.decode("utf-8"))
        format_info = data.get("format", {})
        streams = data.get("streams", [])

        video_stream = next((s for s in streams if s.get("codec_type") == "video"), None)
        audio_stream = next((s for s in streams if s.get("codec_type") == "audio"), None)

        fps = 24.0
        if video_stream and "r_frame_rate" in video_stream:
            try:
                num, den = video_stream["r_frame_rate"].split("/")
                fps = round(float(num) / float(den), 2)
            except Exception:
                fps = 24.0

        resolution = "1920x1080"
        if video_stream:
            w = video_stream.get("width", 1920)
            h = video_stream.get("height", 1080)
            resolution = f"{w}x{h}"

        duration = float(format_info.get("duration", 0.0))
        if duration == 0.0 and audio_stream:
            duration = float(audio_stream.get("duration", 0.0))

        return {
            "duration": duration,
            "fps": fps,
            "resolution": resolution,
            "has_video": video_stream is not None,
            "has_audio": audio_stream is not None,
            "video_codec": video_stream.get("codec_name") if video_stream else None,
            "audio_codec": audio_stream.get("codec_name") if audio_stream else None,
            "audio_sample_rate": int(audio_stream.get("sample_rate", 44100)) if audio_stream else None,
            "audio_channels": int(audio_stream.get("channels", 2)) if audio_stream else None,
            "bitrate": int(format_info.get("bit_rate", 0)),
            "size_bytes": int(format_info.get("size", media_path.stat().st_size))
        }
