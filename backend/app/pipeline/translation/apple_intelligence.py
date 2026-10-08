import json
import asyncio
from pathlib import Path
from typing import Optional
from backend.app.config import settings
from backend.app.pipeline.translation.base import TranslationEngine, TranslationResult

class AppleIntelligenceTranslationEngine(TranslationEngine):
    """Zero-cloud, on-device translation using Apple Intelligence FoundationModels."""

    def __init__(self, bridge_path: Optional[Path] = None):
        self.bridge_path = bridge_path or (settings.BASE_DIR / "bin" / "apple_intelligence_bridge")

    async def is_available(self) -> bool:
        if not self.bridge_path.exists():
            return False
        try:
            proc = await asyncio.create_subprocess_exec(
                str(self.bridge_path),
                "--status",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, _ = await proc.communicate()
            if proc.returncode == 0:
                data = json.loads(stdout.decode("utf-8"))
                return data.get("available", False)
        except Exception:
            return False
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
        if not await self.is_available():
            raise RuntimeError("Apple Intelligence FoundationModels is not available on this device")

        system_prompt = (
            "You are a professional anime dubbing director and Hindi localization expert. "
            "Translate the source dialogue into natural, punchy, spoken Hindi dub dialogue in Devanagari script. "
            "Avoid bookish or literal translation. Match typical Indian anime dubs (like Animax / Crunchyroll). "
            f"Character: {character_name or 'Speaker'}. Personality: {personality or 'anime character'}. "
            "Output ONLY the Hindi dialogue in Devanagari script. No commentary."
        )

        prompt = f"Source ({source_lang}): {text}\nTranslate to natural spoken Hindi:"

        cmd = [
            str(self.bridge_path),
            "--prompt", prompt,
            "--system", system_prompt
        ]

        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, stderr = await proc.communicate()

        if proc.returncode != 0:
            raise RuntimeError(f"Apple Intelligence bridge error: {stderr.decode('utf-8')}")

        data = json.loads(stdout.decode("utf-8"))
        if data.get("status") != "success":
            raise RuntimeError(f"Apple Intelligence failed: {data.get('error')}")

        content = data.get("content", "").strip().strip('"').strip("'")
        
        # Clean any accidental prefixes
        for prefix in ["Hindi:", "हिंदी:", "Dub:", "अनुवाद:"]:
            if content.startswith(prefix):
                content = content[len(prefix):].strip()

        return TranslationResult(
            source_text=text,
            translated_text=content,
            adapted_hindi=content,
            provider="Apple Intelligence (FoundationModels)",
            emotion=emotion_hint or "neutral",
            intensity=0.8
        )
