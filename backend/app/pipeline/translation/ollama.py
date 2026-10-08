import re
import httpx
from typing import Optional
from backend.app.config import settings
from backend.app.pipeline.translation.base import TranslationEngine, TranslationResult

class OllamaTranslationEngine(TranslationEngine):
    """Local LLM translation using Ollama (Qwen 3.5 / Gemma 4)."""

    def __init__(self, model_name: Optional[str] = None, base_url: Optional[str] = None):
        self.model_name = model_name or settings.OLLAMA_TRANSLATION_MODEL
        self.base_url = (base_url or settings.OLLAMA_BASE_URL).rstrip("/")

    async def is_available(self) -> bool:
        try:
            async with httpx.AsyncClient(timeout=3.0) as client:
                res = await client.get(f"{self.base_url}/api/tags")
                return res.status_code == 200
        except Exception:
            return False

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
        prompt = (
            f"You are an anime dub dialogue localization director.\n"
            f"Translate this {source_lang} dialogue into natural spoken Hindi dub dialogue (Devanagari script).\n"
            f"Character: {character_name or 'Speaker'}, Personality: {personality or 'anime character'}\n"
            f"Original Line: {text}\n"
            f"Return ONLY the Hindi dialogue in Devanagari script. Do not output English or explanations."
        )

        async with httpx.AsyncClient(timeout=60.0) as client:
            payload = {
                "model": self.model_name,
                "messages": [
                    {"role": "user", "content": prompt}
                ],
                "stream": False,
                "options": {
                    "temperature": 0.2,
                    "num_predict": 300
                }
            }
            res = await client.post(f"{self.base_url}/api/chat", json=payload)
            if res.status_code != 200:
                raise RuntimeError(f"Ollama request failed with code {res.status_code}: {res.text}")

            data = res.json()
            message = data.get("message", {})
            content = message.get("content", "").strip()

            # If model generated inside thinking field instead of content
            if not content:
                thinking = message.get("thinking", "")
                hindi_matches = re.findall(r'[\u0900-\u097F\s\?!।॥,]+', thinking)
                if hindi_matches:
                    # Pick longest coherent Hindi substring
                    valid_spans = [m.strip() for m in hindi_matches if len(m.strip()) > 3]
                    if valid_spans:
                        content = valid_spans[-1]

            if not content:
                content = text # Fallback to original

            content = content.strip().strip('"').strip("'")
            for prefix in ["Hindi:", "हिंदी:", "Dub:", "अनुवाद:"]:
                if content.startswith(prefix):
                    content = content[len(prefix):].strip()

            return TranslationResult(
                source_text=text,
                translated_text=content,
                adapted_hindi=content,
                provider=f"Ollama ({self.model_name})",
                emotion=emotion_hint or "neutral",
                intensity=0.75
            )
