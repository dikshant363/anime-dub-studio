from typing import Optional, List
from pydantic import BaseModel, Field

class DubCreateRequest(BaseModel):
    project_name: Optional[str] = "My Anime Dub"
    source_language: str = Field(default="ja", description="Source language code (e.g. ja)")
    target_language: str = Field(default="hi", description="Target language code (e.g. hi)")
    speaker_count: str = Field(default="auto", description="auto, 1, 2, 3, 4, 5+")
    
    # Advanced Options (collapsed by default)
    voice_mode: str = Field(default="character_voices", description="character_voices, clone_authorized, custom")
    translation_model: str = Field(default="auto", description="auto, apple_intelligence, ollama, colab")
    translation_style: str = Field(default="natural_hinglish", description="natural_hinglish, natural_anime, urban_hinglish, casual_hinglish, formal_hinglish")
    english_mixing: str = Field(default="medium", description="low, medium, high, auto")
    emotion_mode: str = Field(default="auto", description="auto, neutral, angry, excited, happy, sad")
    preserve_background: bool = Field(default=True, description="Preserve BGM and Sound Effects")
    normalize_loudness: bool = Field(default=True, description="EBU R128 Loudness Normalization")
    timing_mode: str = Field(default="natural", description="natural, match_original, aggressive_sync")
    worker: str = Field(default="auto", description="auto, mac, colab")
    audio_stream_index: Optional[int] = Field(default=None, description="Explicit audio stream index to dub")
