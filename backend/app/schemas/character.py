from typing import Optional, Dict, Any
from datetime import datetime
from pydantic import BaseModel, Field

class CharacterBase(BaseModel):
    name: str
    speaker_tag: Optional[str] = None
    gender: str = "male"
    age_group: str = "teen"
    voice_provider: str = "edge_tts"
    voice_id: str = "hi-IN-MadhurNeural"
    pitch: float = 0.0
    speed: float = 1.0
    personality: str = "energetic, anime protagonist"
    speaking_style: str = "natural anime dub"
    emotion_profile: Dict[str, Any] = {}

class CharacterCreate(CharacterBase):
    project_id: str

class CharacterUpdate(BaseModel):
    name: Optional[str] = None
    speaker_tag: Optional[str] = None
    gender: Optional[str] = None
    age_group: Optional[str] = None
    voice_provider: Optional[str] = None
    voice_id: Optional[str] = None
    pitch: Optional[float] = None
    speed: Optional[float] = None
    personality: Optional[str] = None
    speaking_style: Optional[str] = None

class CharacterResponse(CharacterBase):
    id: str
    project_id: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
