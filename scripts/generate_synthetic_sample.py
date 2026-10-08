import asyncio
import subprocess
from pathlib import Path

async def generate_synthetic_anime_sample(output_mp4: Path) -> Path:
    """
    Generates a 6-second synthetic anime clip with animated visuals and Japanese speech audio
    for legal, reproducible, local-first testing of the entire dubbing pipeline.
    """
    output_mp4.parent.mkdir(parents=True, exist_ok=True)
    temp_wav = output_mp4.with_suffix(".temp_audio.wav")

    # Generate synthetic speech audio with Japanese dialogue
    # We use edge-tts ja-JP-NanamiNeural if available, or generate a rich tone with ffmpeg
    try:
        import edge_tts
        communicate = edge_tts.Communicate(
            text="何をしているんだ？早く行こう！",
            voice="ja-JP-NanamiNeural"
        )
        await communicate.save(str(temp_wav))
    except Exception:
        # Fallback to pure ffmpeg audio generation
        cmd_audio = [
            "ffmpeg", "-y",
            "-f", "lavfi",
            "-i", "sine=frequency=440:duration=5",
            "-acodec", "pcm_s16le",
            "-ar", "24000",
            "-ac", "1",
            str(temp_wav)
        ]
        subprocess.run(cmd_audio, check=True, capture_output=True)

    # Generate animated video combining test pattern with the audio track
    cmd_video = [
        "ffmpeg", "-y",
        "-f", "lavfi",
        "-i", "testsrc=size=1280x720:rate=24:duration=5",
        "-i", str(temp_wav),
        "-c:v", "libx264",
        "-preset", "ultrafast",
        "-pix_fmt", "yuv420p",
        "-c:a", "aac",
        "-b:a", "192k",
        "-shortest",
        str(output_mp4)
    ]

    proc = await asyncio.create_subprocess_exec(
        *cmd_video,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    await proc.communicate()

    if temp_wav.exists():
        temp_wav.unlink()

    return output_mp4

if __name__ == "__main__":
    out_file = Path(__file__).resolve().parent.parent / "tests" / "test_data" / "sample.mp4"
    asyncio.run(generate_synthetic_anime_sample(out_file))
    print(f"Generated synthetic test video at: {out_file}")
