from abc import ABC, abstractmethod
from typing import Optional, Dict, Any
from pydantic import BaseModel

class TranslationResult(BaseModel):
    source_text: str
    translated_text: str
    adapted_hindi: str
    adapted_hinglish: Optional[str] = None
    tts_pronunciation_text: Optional[str] = None
    provider: str
    emotion: str = "neutral"
    intensity: float = 0.7

class TranslationEngine(ABC):
    @abstractmethod
    async def translate_line(
        self,
        text: str,
        source_lang: str = "ja",
        target_lang: str = "hi",
        character_name: Optional[str] = None,
        personality: Optional[str] = None,
        style: str = "natural_anime",
        emotion_hint: Optional[str] = None,
    ) -> TranslationResult:
        """Translates and adapts a dialogue line into natural target language."""
        pass
