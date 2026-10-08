import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Float, DateTime, Text, JSON, ForeignKey
from sqlalchemy.orm import relationship
from backend.app.database import Base

class Job(Base):
    __tablename__ = "jobs"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    episode_id = Column(String(36), ForeignKey("episodes.id"), nullable=False)
    
    stage = Column(String(50), nullable=False) # EXTRACTING_AUDIO, ASR, DIARIZING, TRANSLATING, ADAPTING, TTS, TIMING, MIXING, QA, RENDERING
    status = Column(String(50), default="QUEUED") # QUEUED, RUNNING, COMPLETED, FAILED, CANCELLED
    progress = Column(Float, default=0.0) # 0.0 to 100.0
    
    worker = Column(String(50), default="m4_apple_silicon") # m4_apple_silicon, colab_cuda
    model_used = Column(String(100), nullable=True)
    
    error_message = Column(Text, nullable=True)
    error_details = Column(JSON, default=dict)
    logs = Column(JSON, default=list) # Array of log entries with timestamps
    
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    episode = relationship("Episode", back_populates="jobs")
