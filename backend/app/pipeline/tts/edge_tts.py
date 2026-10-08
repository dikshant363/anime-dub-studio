import asyncio
import soundfile as sf
from pathlib import Path
from typing import Optional
import edge_tts
from backend.app.config import settings
from backend.app.pipeline.tts.base import TTSProvider, TTSResult

class EdgeTTSProvider(TTSProvider):
    """High-fidelity neural Hindi speech synthesis using Edge TTS."""

    DEFAULT_VOICES = {
        "male": "hi-IN-MadhurNeural",
        "female": "hi-IN-SwaraNeural"
    }

    async def synthesize(
        self,
        text: str,
        output_path: Path,
        voice_id: Optional[str] = None,
        speed_rate: float = 1.0,
        pitch_percent: float = 0.0,
        emotion: str = "neutral",
        **kwargs
    ) -> TTSResult:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        chosen_voice = voice_id or self.DEFAULT_VOICES["male"]

        # Format rate modifier (+10%, -15%)
        rate_diff = int(round((speed_rate - 1.0) * 100))
        rate_str = f"{rate_diff:+d}%" if rate_diff != 0 else "+0%"

        # Format pitch modifier (+5Hz, -5Hz)
        pitch_val = int(round(pitch_percent))
        pitch_str = f"{pitch_val:+d}Hz" if pitch_val != 0 else "+0Hz"

        # Edge TTS saves as mp3, convert to WAV for pipeline manipulation
        temp_mp3 = output_path.with_suffix(".temp.mp3")
        success = False
        last_err = None

        for attempt in range(3):
            try:
                communicate = edge_tts.Communicate(
                    text=text,
                    voice=chosen_voice,
                    rate=rate_str,
                    pitch=pitch_str
                )
                await communicate.save(str(temp_mp3))

                if temp_mp3.exists() and temp_mp3.stat().st_size > 500:
                    # Convert to PCM 16-bit 24kHz mono WAV using ffmpeg
                    cmd = [
                        "ffmpeg",
                        "-y",
                        "-i", str(temp_mp3),
                        "-acodec", "pcm_s16le",
                        "-ar", "24000",
                        "-ac", "1",
                        str(output_path)
                    ]
                    proc = await asyncio.create_subprocess_exec(
                        *cmd,
                        stdout=asyncio.subprocess.PIPE,
                        stderr=asyncio.subprocess.PIPE
                    )
                    await proc.communicate()
                    if output_path.exists() and output_path.stat().st_size > 1000:
                        success = True
                        break
            except Exception as e:
                last_err = e
                await asyncio.sleep(0.5 * (attempt + 1))
            finally:
                if temp_mp3.exists():
                    temp_mp3.unlink()

        if not success:
            # Fall back seamlessly to local synthetic tone provider
            from backend.app.pipeline.tts.tone_fallback import SyntheticToneTTSProvider
            fallback = SyntheticToneTTSProvider()
            return await fallback.synthesize(
                text=text,
                output_path=output_path,
                voice_id=chosen_voice,
                speed_rate=speed_rate,
                pitch_percent=pitch_percent,
                emotion=emotion
            )

        # Measure accurate duration
        info = sf.info(str(output_path))
        duration = float(info.duration)

        return TTSResult(
            audio_path=output_path,
            duration=round(duration, 3),
            voice_id=chosen_voice,
            provider="Microsoft Edge-TTS (ONLINE Cloud Service)",
            sample_rate=info.samplerate
        )
