import pytest
from backend.app.pipeline.qa.engine import QAEngine

def test_qa_empty_segments():
    score, report = QAEngine.evaluate_episode([])
    assert score == 0.0
    assert "No dialogue segments detected" in report["warnings"][0]

def test_qa_detects_untranslated_japanese():
    segments = [{
        "confidence": 0.95,
        "adapted_hindi_text": "तुम क्या 何をしているんだ？", # Contains Japanese Kanji
        "duration_ratio": 1.0,
        "audio_path": None
    }]
    score, report = QAEngine.evaluate_episode(segments)
    assert any("Untranslated Japanese characters" in w for w in report["warnings"])
    assert score < 100.0

def test_qa_detects_missing_audio():
    segments = [{
        "confidence": 0.95,
        "adapted_hindi_text": "तुम क्या कर रहे हो?",
        "duration_ratio": 1.0,
        "audio_path": "/nonexistent/path/to/voice.wav"
    }]
    score, report = QAEngine.evaluate_episode(segments)
    assert any("Missing synthesized voice" in w for w in report["warnings"])
    assert score < 100.0
