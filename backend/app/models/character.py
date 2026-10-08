import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Float, DateTime, Text, JSON, ForeignKey
from sqlalchemy.orm import relationship
from backend.app.database import Base

class Character(Base):
    __tablename__ = "characters"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    project_id = Column(String(36), ForeignKey("projects.id"), nullable=False)
    
    name = Column(String(255), nullable=False)
    speaker_tag = Column(String(50), nullable=True) # e.g. SPEAKER_00
    gender = Column(String(20), default="male") # male, female, other
    age_group = Column(String(30), default="teen") # child, teen, adult, elder
    
    voice_provider = Column(String(50), default="edge_tts") # edge_tts, piper, qwen
    voice_id = Column(String(100), default="hi-IN-MadhurNeural")
    pitch = Column(Float, default=0.0) # -50 to +50 percent or semitones
    speed = Column(Float, default=1.0) # 0.5 to 1.5
    
    personality = Column(Text, default="energetic, anime protagonist")
    speaking_style = Column(String(100), default="natural anime dub")
    emotion_profile = Column(JSON, default=dict)
    
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    project = relationship("Project", back_populates="characters")
    dialogues = relationship("DialogueSegment", back_populates="character")
