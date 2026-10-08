import re
from typing import Optional, Dict

class HindiAdaptationEngine:
    """Specialized Hindi Dub localization and timing-constrained compression engine."""

    # Common formal/bookish phrasing mappings to natural colloquial Hindi anime dub dialogue
    COLLOQUIAL_REPLACEMENTS = [
        (r"तुम किस चीज़ को कर रहे हो\??", "तुम क्या कर रहे हो?"),
        (r"आप क्या कर रहे हैं\??", "तुम क्या कर रहे हो?"),
        (r"मैं तुम्हें समाप्त कर दूंगा", "तुझे खत्म कर दूँगा मैं!"),
        (r"यह असंभव प्रतीत होता है", "यह नामुमकिन है!"),
        (r"कृपया मेरी सहायता करें", "मेरी मदद करो!"),
        (r"मुझे इस पर विश्वास नहीं है", "मुझे यकीन नहीं हो रहा!"),
        (r"हमको प्रस्थान करना चाहिए", "अब चलना चाहिए!"),
        (r"वह बहुत शक्तिशाली प्राणी है", "वो बहुत ताकतवर है!"),
        (r"क्या आप ठीक हैं\??", "सब ठीक तो है ना?"),
    ]

    # Contractions for syllable reduction when speech duration exceeds target window
    COMPACT_REPLACEMENTS = [
        (r"तुम क्या कर रहे हो", "क्या कर रहे हो"),
        (r"मुझे समझ नहीं आ रहा है", "समझ नहीं आ रहा"),
        (r"मुझे यकीन नहीं हो रहा है", "यकीन नहीं हो रहा"),
        (r"मैं ऐसा नहीं कर सकता हूँ", "मैं ऐसा नहीं कर सकता"),
        (r"हमको आगे बढ़ना होगा", "आगे बढ़ो"),
        (r"कृपया शांत हो जाइए", "शांत रहो"),
    ]

    @classmethod
    def polish_hindi(cls, text: str, character_style: Optional[str] = None) -> str:
        """Polishes raw translated text into natural spoken Hindi dub dialogue."""
        polished = text.strip()
        for pattern, replacement in cls.COLLOQUIAL_REPLACEMENTS:
            polished = re.sub(pattern, replacement, polished, flags=re.IGNORECASE)

        # Normalize Hindi punctuation (ensure proper danda '।' or question mark '?')
        if not polished.endswith(('?', '!', '।', '.')):
            polished += "।"

        return polished

    @classmethod
    def compress_for_duration(cls, text: str, duration_ratio: float) -> str:
        """If Hindi speech is too long (ratio > 1.15), applies colloquial contractions to reduce syllable count."""
        if duration_ratio <= 1.15:
            return text

        compressed = text
        for pattern, replacement in cls.COMPACT_REPLACEMENTS:
            compressed = re.sub(pattern, replacement, compressed, flags=re.IGNORECASE)

        return compressed
