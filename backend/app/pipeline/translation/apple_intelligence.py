import os
import json
import re
import asyncio
from pathlib import Path
from typing import Optional
from backend.app.config import settings
from backend.app.pipeline.translation.base import TranslationEngine, TranslationResult

class AppleIntelligenceTranslationEngine(TranslationEngine):
    """Zero-cloud, on-device translation using Apple Intelligence FoundationModels."""

    def __init__(self, bridge_path: Optional[Path] = None):
        self.bridge_path = bridge_path or self._resolve_bridge_path()

    def _resolve_bridge_path(self) -> Path:
        candidates = [
            os.getenv("APPLE_FOUNDATION_MODEL_SERVICE"),
            os.getenv("APPLE_INTELLIGENCE_BRIDGE"),
            str(settings.BASE_DIR / "swift" / "AppleFoundationModelService"),
            str(settings.BASE_DIR.parent / "swift" / "AppleFoundationModelService"),
            "/Applications/Anime Dub Studio.app/Contents/Resources/swift/AppleFoundationModelService",
            "/Users/dikshantagarwal/Desktop/AUTO DUB/src-tauri/swift/AppleFoundationModelService",
            str(settings.BASE_DIR / "bin" / "apple_intelligence_bridge"),
            "/Users/dikshantagarwal/Desktop/AUTO DUB/bin/apple_intelligence_bridge",
        ]
        for c in candidates:
            if c:
                p = Path(c)
                if p.exists() and os.access(p, os.X_OK):
                    return p
        return Path("/Users/dikshantagarwal/Desktop/AUTO DUB/src-tauri/swift/AppleFoundationModelService")

    async def is_available(self) -> bool:
        if not self.bridge_path.exists():
            # Retry resolving
            self.bridge_path = self._resolve_bridge_path()
            if not self.bridge_path.exists():
                return False

        is_foundation_service = "AppleFoundationModelService" in self.bridge_path.name
        cmd = [str(self.bridge_path), "availability" if is_foundation_service else "--status"]

        try:
            proc = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, _ = await proc.communicate()
            if proc.returncode == 0:
                data = json.loads(stdout.decode("utf-8"))
                if is_foundation_service:
                    inner_data = data.get("data", {})
                    return inner_data.get("available", False)
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

        is_hinglish = "hinglish" in target_lang.lower() or target_lang.lower() == "hi-latn"
        is_foundation_service = "AppleFoundationModelService" in self.bridge_path.name

        hindi_text = ""
        if is_foundation_service:
            # AppleFoundationModelService CLI: translate --text <text> --source <source> --target <target>
            cmd = [
                str(self.bridge_path),
                "translate",
                "--text", text,
                "--source", source_lang,
                "--target", "hi",
                "--style", style
            ]
            if character_name:
                cmd.extend(["--character", character_name])

            proc = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await proc.communicate()

            if proc.returncode != 0:
                raise RuntimeError(f"Apple Foundation Model Service error: {stderr.decode('utf-8')}")

            data = json.loads(stdout.decode("utf-8"))
            if data.get("status") != "success":
                raise RuntimeError(f"Apple Foundation Model Service failed: {data.get('error')}")

            svc_data = data.get("data", {})
            hindi_text = (svc_data.get("adaptedHindi") or svc_data.get("translatedText") or "").strip()
        else:
            # apple_intelligence_bridge CLI: --prompt <text> --system <text>
            system_prompt = (
                "You are a professional anime dubbing director and Hindi localization expert. "
                "Translate the source dialogue into natural, punchy, spoken Hindi dub dialogue in Devanagari script. "
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

            hindi_text = data.get("content", "").strip().strip('"').strip("'")

        # Clean any accidental prefixes
        for prefix in ["Hindi:", "हिंदी:", "Dub:", "अनुवाद:"]:
            if hindi_text.lower().startswith(prefix.lower()):
                hindi_text = hindi_text[len(prefix):].strip()

        # Sanitize any untranslated Japanese or non-Devanagari
        cleaned_hindi = re.sub(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]', '', hindi_text).strip()
        if not cleaned_hindi:
            from backend.app.pipeline.translation.router import ANIME_FALLBACK_DICTIONARY
            cleaned_hindi = ANIME_FALLBACK_DICTIONARY.get(text.strip(), "तुम क्या कह रहे हो?")

        from backend.app.pipeline.adaptation.hinglish_adapter import HinglishAdaptationEngine
        hinglish = HinglishAdaptationEngine.to_hinglish(cleaned_hindi, personality, style)
        hinglish = re.sub(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]', '', hinglish).strip()
        tts_pron = HinglishAdaptationEngine.create_tts_pronunciation(hinglish, cleaned_hindi)

        return TranslationResult(
            source_text=text,
            translated_text=hinglish if is_hinglish else cleaned_hindi,
            adapted_hindi=cleaned_hindi,
            adapted_hinglish=hinglish,
            tts_pronunciation_text=tts_pron,
            provider="Apple Intelligence (FoundationModels)",
            emotion=emotion_hint or "neutral",
            intensity=0.8
        )
