from typing import Optional, List, Dict, Any
from datetime import datetime
from pydantic import BaseModel, Field
from backend.app.schemas.episode import EpisodeResponse
from backend.app.schemas.character import CharacterResponse

class ProjectBase(BaseModel):
    name: str
    description: Optional[str] = None
    source_language: str = "ja"
    target_language: str = "hi"
    settings: Dict[str, Any] = {}

class ProjectCreate(ProjectBase):
    pass

class ProjectResponse(ProjectBase):
    id: str
    created_at: datetime
    updated_at: datetime
    episodes: List[EpisodeResponse] = []
    characters: List[CharacterResponse] = []

    model_config = {"from_attributes": True}
