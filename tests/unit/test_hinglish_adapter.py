import pytest
from backend.app.pipeline.adaptation.hinglish_adapter import HinglishAdaptationEngine
from backend.app.pipeline.qa.engine import QAEngine

def test_canonical_phrases_roman_hinglish():
    # Canonical Example 1: 何をしているんだ？ -> तुम क्या कर रहे हो? -> Tum kya kar rahe ho?
    hi1 = "तुम क्या कर रहे हो?"
    hgl1 = HinglishAdaptationEngine.to_hinglish(hi1, english_mixing="low")
    assert "Tum kya kar rahe ho?" in hgl1

    # Canonical Example 2: 早く行こう！ -> जल्दी चलो! -> Jaldi chalo!
    hi2 = "जल्दी चलो!"
    hgl2 = HinglishAdaptationEngine.to_hinglish(hi2, english_mixing="low")
    assert "Jaldi chalo!" in hgl2

    # Canonical Example 3: 信じられない！ -> मुझे यकीन नहीं हो रहा! -> Mujhe yakeen nahi ho raha!
    hi3 = "मुझे यकीन नहीं हो रहा!"
    hgl3 = HinglishAdaptationEngine.to_hinglish(hi3, english_mixing="low")
    assert "Mujhe yakeen nahi ho raha!" in hgl3

def test_roman_script_guarantee():
    hi = "मुझे यकीन नहीं हो रहा! जल्दी चलो तुम क्या कर रहे हो?"
    hgl = HinglishAdaptationEngine.to_hinglish(hi)
    # Must NOT contain Devanagari characters (Unicode range U+0900 to U+097F)
    import re
    has_devanagari = bool(re.search(r'[\u0900-\u097F]', hgl))
    assert not has_devanagari, f"Devanagari script detected in Hinglish output: {hgl}"

def test_english_mixing_levels():
    hi = "मुझे यकीन नहीं हो रहा!"
    # Low mixing: keep natural Hindi vocabulary in Roman script
    low = HinglishAdaptationEngine.to_hinglish(hi, english_mixing="low")
    assert "yakeen" in low.lower()

    # Medium mixing: natural urban loanwords like 'believe'
    medium = HinglishAdaptationEngine.to_hinglish(hi, english_mixing="medium")
    assert "believe" in medium.lower()

    # High mixing: urban anime style
    high = HinglishAdaptationEngine.to_hinglish("मेरी मदद करो!", english_mixing="high")
    assert "help" in high.lower()

def test_tts_pronunciation_representation():
    # Hinglish with loanword 'believe'
    hinglish = "Mujhe believe nahi ho raha!"
    devanagari = "मुझे यकीन नहीं हो रहा!"
    pronunciation = HinglishAdaptationEngine.create_tts_pronunciation(hinglish, devanagari)
    
    # Pronunciation representation preserves Devanagari structure for native Hindi phonology
    # while embedding loanword in English script
    assert "believe" in pronunciation
    assert "नहीं हो रहा" in pronunciation

def test_qa_validates_hinglish():
    # Valid Hinglish dialogue
    segments = [{
        "confidence": 0.95,
        "adapted_hinglish_text": "Tum kya kar rahe ho?",
        "duration_ratio": 1.0,
        "audio_path": None
    }]
    score, report = QAEngine.evaluate_episode(segments, target_lang="hinglish")
    assert not any("Unexpected Devanagari" in w for w in report.get("warnings", []))
    assert score >= 90.0

def test_qa_rejects_devanagari_in_hinglish():
    # Invalid: Devanagari leaked into Hinglish text
    segments = [{
        "confidence": 0.95,
        "adapted_hinglish_text": "Tum kya कर रहे हो?",
        "duration_ratio": 1.0,
        "audio_path": None
    }]
    score, report = QAEngine.evaluate_episode(segments, target_lang="hinglish")
    assert any("Unexpected Devanagari characters in Roman Hinglish" in w for w in report.get("warnings", []))
    assert score < 90.0

def test_qa_detects_excessive_english_in_hinglish():
    # Invalid: High density of English words exceeding threshold
    segments = [{
        "confidence": 0.95,
        "adapted_hinglish_text": "what are you doing here right now my friend with that problem",
        "duration_ratio": 1.0,
        "audio_path": None
    }]
    score, report = QAEngine.evaluate_episode(segments, target_lang="hinglish")
    assert any("exceeds expected threshold" in w for w in report.get("warnings", []))
