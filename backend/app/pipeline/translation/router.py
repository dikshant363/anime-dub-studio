from typing import Optional
from backend.app.config import settings
from backend.app.pipeline.translation.base import TranslationEngine, TranslationResult
from backend.app.pipeline.translation.apple_intelligence import AppleIntelligenceTranslationEngine
from backend.app.pipeline.translation.ollama import OllamaTranslationEngine

# Common anime phrases dictionary for zero-dependency offline deterministic fallback
ANIME_FALLBACK_DICTIONARY = {
    "何をしているんだ？": "तुम क्या कर रहे हो?",
    "何をしているんだ": "तुम क्या कर रहे हो?",
    "誰だ？": "कौन हो तुम?",
    "バカ！": "बेवकूफ!",
    "ありがとう": "शुक्रिया!",
    "さようなら": "अलविदा!",
    "助けて！": "मदद करो!",
    "行くぞ！": "चलो चलें!",
    "信じられない": "मुझे यकीन नहीं हो रहा!",
    "諦めない！": "मैं हार नहीं मानूँगा!"
}

class DeterministicTranslationEngine(TranslationEngine):
    """Reliable offline deterministic fallback for testing and air-gapped environments."""

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
        clean = text.strip()
        hindi = ANIME_FALLBACK_DICTIONARY.get(clean)
        if not hindi:
            # Simple placeholder adaptation for unknown text
            hindi = f"तुम क्या कह रहे हो? ({clean})"

        return TranslationResult(
            source_text=text,
            translated_text=hindi,
            adapted_hindi=hindi,
            provider="Deterministic Fallback",
            emotion=emotion_hint or "neutral",
            intensity=0.7
        )

class TranslationRouter(TranslationEngine):
    """Routes translation requests based on hardware availability and user preference."""

    def __init__(self, preferred_provider: str = "auto"):
        self.preferred_provider = preferred_provider
        self.apple_engine = AppleIntelligenceTranslationEngine()
        self.ollama_engine = OllamaTranslationEngine()
        self.fallback_engine = DeterministicTranslationEngine()

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
        pref = self.preferred_provider.lower()

        # 1. Explicit Apple Intelligence preference
        if pref in ["apple", "apple_intelligence"]:
            if await self.apple_engine.is_available():
                return await self.apple_engine.translate_line(
                    text, source_lang, target_lang, character_name, personality, style, emotion_hint
                )

        # 2. Explicit Ollama preference
        if pref in ["ollama", "qwen"]:
            if await self.ollama_engine.is_available():
                return await self.ollama_engine.translate_line(
                    text, source_lang, target_lang, character_name, personality, style, emotion_hint
                )

        # 3. AUTO mode: Prefer Apple Intelligence on M4 Mac, then Ollama, then Fallback
        if pref == "auto":
            if settings.is_apple_silicon and await self.apple_engine.is_available():
                try:
                    return await self.apple_engine.translate_line(
                        text, source_lang, target_lang, character_name, personality, style, emotion_hint
                    )
                except Exception:
                    pass # Fall through to Ollama

            if await self.ollama_engine.is_available():
                try:
                    return await self.ollama_engine.translate_line(
                        text, source_lang, target_lang, character_name, personality, style, emotion_hint
                    )
                except Exception:
                    pass

        # 4. Fallback
        return await self.fallback_engine.translate_line(
            text, source_lang, target_lang, character_name, personality, style, emotion_hint
        )
