from typing import Optional, List, Dict, Any
from datetime import datetime
from pydantic import BaseModel, Field

class DialogueSegmentBase(BaseModel):
    segment_index: int
    start_time: float
    end_time: float
    target_duration: float
    speaker_label: str = "SPEAKER_00"
    source_language: str = "ja"
    target_language: str = "hi"
    source_text: str
    translated_text: Optional[str] = None
    adapted_hindi_text: Optional[str] = None
    adapted_hinglish_text: Optional[str] = None
    tts_pronunciation_text: Optional[str] = None
    confidence: float = 1.0
    emotion: str = "neutral"
    intensity: float = 0.7
    character_id: Optional[str] = None
    voice_id: Optional[str] = None
    speed_factor: float = 1.0

class DialogueSegmentUpdate(BaseModel):
    character_id: Optional[str] = None
    speaker_label: Optional[str] = None
    adapted_hindi_text: Optional[str] = None
    adapted_hinglish_text: Optional[str] = None
    emotion: Optional[str] = None
    intensity: Optional[float] = None
    speed_factor: Optional[float] = None
    start_time: Optional[float] = None
    end_time: Optional[float] = None

class DialogueSegmentResponse(DialogueSegmentBase):
    id: str
    episode_id: str
    audio_path: Optional[str] = None
    synthesized_duration: Optional[float] = None
    duration_ratio: Optional[float] = None
    status: str
    qa_flags: List[str] = []
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
