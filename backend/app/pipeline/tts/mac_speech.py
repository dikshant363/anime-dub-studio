import asyncio
import soundfile as sf
from pathlib import Path
from typing import Optional
from backend.app.pipeline.tts.base import TTSProvider, TTSResult

class MacNativeSpeechProvider(TTSProvider):
    """Genuinely local, zero-API, on-device macOS speech synthesis provider.
    
    Uses Apple Silicon native text-to-speech with distinct character voices:
    - Rishi: Male Lead / Protagonist (en_IN / Hinglish)
    - Aman: Male Secondary / Rival (en_IN / Hinglish)
    - Lekha: Female Lead / Heroine (hi_IN / Hindi & Hinglish)
    - Tara: Female Secondary (en_IN / Hinglish)
    """

    VOICE_MAP = {
        "rishi": "Rishi",
        "aman": "Aman",
        "lekha": "Lekha",
        "tara": "Tara",
        "male_lead": "Rishi",
        "male_secondary": "Aman",
        "female_lead": "Lekha",
        "female_secondary": "Tara",
        "speaker_00": "Rishi",
        "speaker_01": "Lekha",
        "speaker_02": "Aman",
        "speaker_03": "Tara",
    }

    async def synthesize(
        self,
        text: str,
        output_path: Path,
        voice_id: Optional[str] = None,
        speed_rate: float = 1.0,
        pitch_percent: float = 0.0,
        emotion: str = "neutral",
        hindi_text: Optional[str] = None,
    ) -> TTSResult:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Resolve voice
        key = (voice_id or "rishi").lower().strip()
        chosen_voice = self.VOICE_MAP.get(key, "Rishi")

        # For Lekha (Hindi voice), prefer Devanagari hindi_text if provided
        speech_input = hindi_text if (chosen_voice == "Lekha" and hindi_text) else text

        # Modulate speaking rate (standard 175 wpm)
        wpm = int(round(175 * max(0.6, min(1.8, speed_rate))))

        temp_aiff = output_path.with_suffix(".temp.aiff")
        
        # Clean text of quotes and shell hazards
        clean_text = speech_input.replace('"', '').replace('`', '').replace('$', '').strip()
        if not clean_text:
            clean_text = "..."

        try:
            cmd_say = [
                "/usr/bin/say",
                "-v", chosen_voice,
                "-r", str(wpm),
                clean_text,
                "-o", str(temp_aiff)
            ]
            proc = await asyncio.create_subprocess_exec(
                *cmd_say,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            _, stderr = await proc.communicate()
            if proc.returncode != 0:
                raise RuntimeError(f"macOS native TTS failed: {stderr.decode('utf-8')}")

            # Convert to PCM 16-bit 24kHz mono WAV
            cmd_ffmpeg = [
                "ffmpeg",
                "-y",
                "-i", str(temp_aiff),
                "-acodec", "pcm_s16le",
                "-ar", "24000",
                "-ac", "1",
                str(output_path)
            ]
            proc_conv = await asyncio.create_subprocess_exec(
                *cmd_ffmpeg,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            await proc_conv.communicate()

        finally:
            if temp_aiff.exists():
                temp_aiff.unlink()

        # Measure accurate duration
        info = sf.info(str(output_path))
        duration = float(info.duration)

        return TTSResult(
            audio_path=output_path,
            duration=round(duration, 3),
            voice_id=chosen_voice,
            provider="macOS Native Speech (Local • No API)",
            sample_rate=24000
        )
