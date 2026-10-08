from typing import Optional, List, Dict, Any
from datetime import datetime
from pydantic import BaseModel, Field
from backend.app.schemas.dialogue import DialogueSegmentResponse

class EpisodeBase(BaseModel):
    title: str
    episode_number: int = 1

class EpisodeCreate(EpisodeBase):
    project_id: str

class EpisodeResponse(EpisodeBase):
    id: str
    project_id: str
    source_media_path: Optional[str] = None
    master_audio_path: Optional[str] = None
    vocals_path: Optional[str] = None
    background_path: Optional[str] = None
    dubbed_audio_path: Optional[str] = None
    exported_video_path: Optional[str] = None
    subtitle_srt_path: Optional[str] = None
    subtitle_ass_path: Optional[str] = None
    duration: float = 0.0
    fps: float = 24.0
    resolution: str = "1920x1080"
    current_stage: str
    status: str
    qa_score: Optional[float] = None
    qa_report: Dict[str, Any] = {}
    dialogues: List[DialogueSegmentResponse] = []
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
