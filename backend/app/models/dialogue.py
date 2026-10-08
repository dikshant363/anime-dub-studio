import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Integer, Float, DateTime, Text, JSON, ForeignKey
from sqlalchemy.orm import relationship
from backend.app.database import Base

class DialogueSegment(Base):
    __tablename__ = "dialogue_segments"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    episode_id = Column(String(36), ForeignKey("episodes.id"), nullable=False)
    character_id = Column(String(36), ForeignKey("characters.id"), nullable=True)
    
    segment_index = Column(Integer, nullable=False)
    start_time = Column(Float, nullable=False) # In seconds
    end_time = Column(Float, nullable=False)   # In seconds
    target_duration = Column(Float, nullable=False)
    
    speaker_label = Column(String(50), default="SPEAKER_00")
    source_language = Column(String(10), default="ja")
    target_language = Column(String(10), default="hi")
    
    source_text = Column(Text, nullable=False)
    translated_text = Column(Text, nullable=True)
    adapted_hindi_text = Column(Text, nullable=True)
    adapted_hinglish_text = Column(Text, nullable=True)
    tts_pronunciation_text = Column(Text, nullable=True)
    
    confidence = Column(Float, default=1.0)
    emotion = Column(String(50), default="neutral") # neutral, angry, excited, happy, sad, etc.
    intensity = Column(Float, default=0.7)
    
    # Audio synthesis & timing
    audio_path = Column(String(512), nullable=True)
    synthesized_duration = Column(Float, nullable=True)
    duration_ratio = Column(Float, nullable=True) # synthesized_duration / target_duration
    speed_factor = Column(Float, default=1.0)
    
    status = Column(String(50), default="PENDING") # PENDING, TRANSLATED, SYNTHESIZED, READY, WARNING
    qa_flags = Column(JSON, default=list)

    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    episode = relationship("Episode", back_populates="dialogues")
    character = relationship("Character", back_populates="dialogues")
