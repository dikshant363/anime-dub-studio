import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Integer, Float, DateTime, Text, JSON, ForeignKey
from sqlalchemy.orm import relationship
from backend.app.database import Base

class Episode(Base):
    __tablename__ = "episodes"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    project_id = Column(String(36), ForeignKey("projects.id"), nullable=False)
    episode_number = Column(Integer, default=1)
    title = Column(String(255), nullable=False)
    
    # Media paths and metadata
    source_media_path = Column(String(512), nullable=True)
    master_audio_path = Column(String(512), nullable=True)
    vocals_path = Column(String(512), nullable=True)
    background_path = Column(String(512), nullable=True)
    dubbed_audio_path = Column(String(512), nullable=True)
    exported_video_path = Column(String(512), nullable=True)
    subtitle_srt_path = Column(String(512), nullable=True)
    subtitle_ass_path = Column(String(512), nullable=True)
    
    duration = Column(Float, default=0.0)
    fps = Column(Float, default=24.0)
    resolution = Column(String(32), default="1920x1080")
    
    # Pipeline execution state
    current_stage = Column(String(50), default="CREATED")
    status = Column(String(50), default="IDLE") # IDLE, PROCESSING, COMPLETED, FAILED
    qa_score = Column(Float, nullable=True)
    qa_report = Column(JSON, default=dict)
    
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    project = relationship("Project", back_populates="episodes")
    dialogues = relationship("DialogueSegment", back_populates="episode", cascade="all, delete-orphan", order_by="DialogueSegment.segment_index")
    jobs = relationship("Job", back_populates="episode", cascade="all, delete-orphan")
