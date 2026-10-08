import asyncio
from pathlib import Path
from typing import Optional

class VideoMuxer:
    """Remuxes original video with the new dubbed soundtrack without re-encoding video."""

    @staticmethod
    async def render_dubbed_video(
        source_video_path: Path,
        dubbed_audio_path: Path,
        output_video_path: Path,
        subtitle_path: Optional[Path] = None
    ) -> Path:
        output_video_path.parent.mkdir(parents=True, exist_ok=True)

        cmd = [
            "ffmpeg",
            "-y",
            "-i", str(source_video_path),
            "-i", str(dubbed_audio_path),
            "-c:v", "copy",            # Never re-encode video stream!
            "-c:a", "aac",             # Clean universal AAC audio codec
            "-b:a", "256k",
            "-map", "0:v:0",           # First video stream from source
            "-map", "1:a:0",           # Dubbed audio track
            "-shortest",               # Match duration
            str(output_video_path)
        ]

        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        _, stderr = await proc.communicate()

        if proc.returncode != 0:
            raise RuntimeError(f"Video muxing failed: {stderr.decode('utf-8')}")

        return output_video_path
