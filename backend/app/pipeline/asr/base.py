from abc import ABC, abstractmethod
from pathlib import Path
from typing import List, Optional
from pydantic import BaseModel

class TranscriptionSegment(BaseModel):
    id: int
    start: float
    end: float
    text: str
    confidence: float = 1.0
    language: str = "ja"
    speaker: str = "SPEAKER_00"

class Transcriber(ABC):
    @abstractmethod
    async def transcribe(
        self,
        audio_path: Path,
        language: Optional[str] = "ja"
    ) -> List[TranscriptionSegment]:
        """Transcribes audio file and returns structured segments with timestamps."""
        pass
