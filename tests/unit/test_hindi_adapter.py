import pytest
from backend.app.pipeline.adaptation.hindi_adapter import HindiAdaptationEngine

def test_hindi_adaptation_colloquial_conversion():
    # Formal/stiff bookish translation
    stiff = "तुम किस चीज़ को कर रहे हो?"
    natural = HindiAdaptationEngine.polish_hindi(stiff)
    assert "तुम क्या कर रहे हो?" in natural

def test_hindi_adaptation_punctuation_normalization():
    line = "चलो जल्दी करो"
    polished = HindiAdaptationEngine.polish_hindi(line)
    assert polished.endswith("।")

def test_hindi_adaptation_duration_compression():
    long_line = "तुम क्या कर रहे हो"
    # When duration ratio exceeds 1.15, compress syllable count
    compressed = HindiAdaptationEngine.compress_for_duration(long_line, duration_ratio=1.25)
    assert compressed == "क्या कर रहे हो"

    # When ratio is under tolerance, do not compress
    untouched = HindiAdaptationEngine.compress_for_duration(long_line, duration_ratio=1.05)
    assert untouched == long_line
