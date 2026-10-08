import pytest
from backend.app.pipeline.translation.router import DeterministicTranslationEngine, TranslationRouter

@pytest.mark.asyncio
async def test_deterministic_translation_dictionary():
    engine = DeterministicTranslationEngine()
    res = await engine.translate_line("何をしているんだ？", source_lang="ja", target_lang="hi")
    assert res.adapted_hindi == "तुम क्या कर रहे हो?"
    assert res.provider == "Deterministic Fallback"

@pytest.mark.asyncio
async def test_translation_router_fallback():
    # Test router fallback
    router = TranslationRouter(preferred_provider="deterministic")
    res = await router.translate_line("ありがとう", source_lang="ja", target_lang="hi")
    assert "शुक्रिया" in res.adapted_hindi
