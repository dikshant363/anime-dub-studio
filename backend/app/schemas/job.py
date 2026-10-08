from typing import Optional, List, Dict, Any
from datetime import datetime
from pydantic import BaseModel, Field

class JobBase(BaseModel):
    stage: str
    status: str = "QUEUED"
    progress: float = 0.0
    worker: str = "m4_apple_silicon"
    model_used: Optional[str] = None
    error_message: Optional[str] = None
    error_details: Dict[str, Any] = {}
    logs: List[Dict[str, Any]] = []

class JobResponse(JobBase):
    id: str
    episode_id: str
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
