from abc import ABC, abstractmethod
from pathlib import Path
from typing import Optional
from pydantic import BaseModel

class TTSResult(BaseModel):
    audio_path: Path
    duration: float
    voice_id: str
    provider: str
    sample_rate: int = 24000

class TTSProvider(ABC):
    @abstractmethod
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
        """Synthesizes target text into an audio file and returns measured duration."""
        pass
