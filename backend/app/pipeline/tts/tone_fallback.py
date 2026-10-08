import math
import numpy as np
import soundfile as sf
from pathlib import Path
from typing import Optional
from backend.app.pipeline.tts.base import TTSProvider, TTSResult

class SyntheticToneTTSProvider(TTSProvider):
    """Generates synthetic speech tones for air-gapped testing and deterministic validation."""

    async def synthesize(
        self,
        text: str,
        output_path: Path,
        voice_id: Optional[str] = None,
        speed_rate: float = 1.0,
        pitch_percent: float = 0.0,
        emotion: str = "neutral",
    ) -> TTSResult:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        sample_rate = 24000
        
        # Estimate duration based on text length: ~12 characters per second in Hindi
        base_duration = max(0.8, len(text.strip()) * 0.08)
        duration = base_duration / max(0.5, speed_rate)

        # Base frequency: male ~130Hz, female ~220Hz
        freq = 220.0 if "female" in (voice_id or "").lower() or "swara" in (voice_id or "").lower() else 130.0
        freq = freq * (1.0 + (pitch_percent / 100.0))

        t = np.linspace(0, duration, int(sample_rate * duration), endpoint=False)
        # Generate soft harmonic tone with envelope
        envelope = np.sin(np.pi * np.linspace(0, 1, len(t)))
        audio = (0.3 * np.sin(2 * np.pi * freq * t) + 0.15 * np.sin(4 * np.pi * freq * t)) * envelope
        audio = audio.astype(np.float32)

        sf.write(str(output_path), audio, sample_rate)

        return TTSResult(
            audio_path=output_path,
            duration=round(duration, 3),
            voice_id=voice_id or "synthetic-tone",
            provider="Synthetic Tone Fallback",
            sample_rate=sample_rate
        )
