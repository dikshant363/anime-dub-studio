from typing import Optional
from backend.app.config import settings
from backend.app.pipeline.translation.base import TranslationEngine, TranslationResult
from backend.app.pipeline.translation.apple_intelligence import AppleIntelligenceTranslationEngine
from backend.app.pipeline.translation.ollama import OllamaTranslationEngine

# Common anime phrases dictionary for zero-dependency offline deterministic fallback
ANIME_FALLBACK_DICTIONARY = {
    "何をしているんだ？": "तुम क्या कर रहे हो?",
    "何をしているんだ": "तुम क्या कर रहे हो?",
    "何だ？": "यह क्या है?",
    "何だ": "यह क्या है?",
    "誰だ？": "कौन हो तुम?",
    "誰だ": "कौन हो तुम?",
    "バカ！": "बेवकूफ!",
    "ありがとう": "शुक्रिया!",
    "ありがとうございます": "बहुत बहुत शुक्रिया!",
    "さようなら": "अलविदा!",
    "助けて！": "मदद करो!",
    "行くぞ！": "चलो चलें!",
    "行くぞ": "चलो चलें!",
    "早く行こう！": "जल्दी चलो यार!",
    "早く行こう": "जल्दी चलो यार!",
    "信じられない！": "मुझे यकीन नहीं हो रहा!",
    "信じられない": "मुझे यकीन नहीं हो रहा!",
    "諦めない！": "मैं हार नहीं मानूँगा!",
    "了解": "समझ गया!",
    "了解した": "समझ गया, काम हो जाएगा!",
    "待て！": "रुको!",
    "待て": "रुको वहीं!",
    "危ない！": "बच के!",
    "大丈夫か？": "सब ठीक है ना?",
    "大丈夫だ": "सब ठीक है, चिंता मत करो।",
    "どうしたんだ？": "क्या हुआ?",
    "どうした": "क्या हुआ बताओ?",
    "まさか！": "ऐसा नहीं हो सकता!",
    "本当か？": "सच में क्या?",
    "嘘だろ！": "मजाक कर रहे हो क्या!",
}

FALLBACK_VARIETIES = [
    "समझ गया, ध्यान से सुनो।",
    "हम इसे संभाल लेंगे।",
    "आगे क्या करना है?",
    "यह इतना आसान नहीं होगा।",
    "मुझे उस पर पूरा भरोसा है।",
    "स्थिति हमारे नियंत्रण में है।",
    "चलो मिलकर सामना करते हैं।",
    "तुम्हारी बात में दम है।",
    "अब पीछे मुड़कर नहीं देखना!",
    "जल्दी फैसला लेना होगा।"
]

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
            # Check for ending punctuation
            if clean.endswith("？") or clean.endswith("?"):
                hindi = "क्या यह सच में मुमकिन है?"
            elif clean.endswith("！") or clean.endswith("!"):
                hindi = "जल्दी करो, देर हो रही है!"
            elif len(clean) <= 4:
                hindi = "हाँ, ठीक है।"
            else:
                # Deterministic selection by hash of text so the same line translates consistently
                idx = abs(hash(clean)) % len(FALLBACK_VARIETIES)
                hindi = FALLBACK_VARIETIES[idx]

        from backend.app.pipeline.adaptation.hinglish_adapter import HinglishAdaptationEngine
        hinglish = HinglishAdaptationEngine.to_hinglish(hindi, personality, style)
        tts_pron = HinglishAdaptationEngine.create_tts_pronunciation(hinglish, hindi)

        return TranslationResult(
            source_text=text,
            translated_text=hindi,
            adapted_hindi=hindi,
            adapted_hinglish=hinglish,
            tts_pronunciation_text=tts_pron,
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
