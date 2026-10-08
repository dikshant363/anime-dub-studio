import re
from typing import Optional, Tuple, Dict

class HinglishAdaptationEngine:
    """Specialized Hinglish dub localization, Romanization, and TTS pronunciation engine.
    
    Transforms natural Hindi into colloquial Indian spoken Hinglish in Latin/Roman script,
    respecting character personalities, English mixing intensity, and speech durations.
    """

    # Comprehensive Devanagari to spoken Roman Hinglish dictionary for common conversational & anime terms
    DEV_TO_HINGLISH_VOCAB: Dict[str, str] = {
        "तुम": "tum",
        "आप": "aap",
        "तू": "tu",
        "मैं": "main",
        "हम": "hum",
        "मुझे": "mujhe",
        "मुझको": "mujhko",
        "तुझे": "tujhe",
        "तुम्हें": "tumhe",
        "आपको": "aapko",
        "हमें": "humein",
        "क्या": "kya",
        "कर": "kar",
        "रहे": "rahe",
        "रहा": "raha",
        "रही": "rahi",
        "हो": "ho",
        "है": "hai",
        "हैं": "hain",
        "था": "tha",
        "थी": "thi",
        "थे": "the",
        "जल्दी": "jaldi",
        "चलो": "chalo",
        "चलें": "chalein",
        "जाओ": "jao",
        "जाना": "jaana",
        "रुक": "ruk",
        "रुको": "ruko",
        "सुनो": "suno",
        "देख": "dekh",
        "देखो": "dekho",
        "समझ": "samajh",
        "यकीन": "yakeen",
        "विश्वास": "vishwas",
        "नामुमकिन": "namumkin",
        "मुमकिन": "mumkin",
        "मदद": "madad",
        "सहायता": "sahayata",
        "खत्म": "khatam",
        "मार": "maar",
        "माफ": "maaf",
        "अलविदा": "alvida",
        "शुक्रिया": "shukriya",
        "धन्यवाद": "dhanyawad",
        "नमस्ते": "namaste",
        "हाँ": "haan",
        "नहीं": "nahi",
        "मत": "mat",
        "कभी": "kabhi",
        "हमेशा": "hamesha",
        "कौन": "kaun",
        "कहाँ": "kahan",
        "कैसे": "kaise",
        "क्यों": "kyun",
        "कब": "kab",
        "यहाँ": "yahan",
        "वहाँ": "wahan",
        "यह": "yeh",
        "ये": "ye",
        "वह": "woh",
        "वो": "wo",
        "बात": "baat",
        "चीज": "cheez",
        "दोस्त": "dost",
        "यार": "yaar",
        "भाई": "bhai",
        "ताकतवर": "takatwar",
        "शक्तिशाली": "shaktishali",
        "सावधान": "savdhaan",
        "डर": "dar",
        "हिम्मत": "himmat",
        "सच": "sach",
        "झूठ": "jhooth",
        "सब": "sab",
        "ठीक": "theek",
        "अच्छा": "achha",
        "बुरा": "bura",
        "खतरा": "khatra",
        "आगे": "aage",
        "पीछे": "peeche",
        "ऊपर": "upar",
        "नीचे": "neeche",
        "साथ": "saath",
        "पास": "paas",
        "दूर": "door",
        "बचाओ": "bachao",
        "रोक": "rok",
        "रोको": "roko",
        "छोड़ो": "chhoro",
        "पकड़ो": "pakdo",
        "आ": "aa",
        "आओ": "aao",
        "आया": "aaya",
        "गया": "gaya",
        "गए": "gaye",
        "गई": "gayi",
        "ले": "le",
        "लो": "lo",
        "दे": "de",
        "दो": "do",
        "बोल": "bol",
        "बोलो": "bolo",
        "कह": "kah",
        "कहा": "kaha",
    }

    # Canonical conversational phrases
    PHRASE_MAPPINGS = [
        (r"तुम क्या कर रहे हो\??", "Tum kya kar rahe ho?"),
        (r"क्या कर रहे हो\??", "Kya kar rahe ho?"),
        (r"जल्दी चलो!?", "Jaldi chalo!"),
        (r"जल्दी जाओ!?", "Jaldi jao!"),
        (r"चलो चलें!?", "Chalo chalein!"),
        (r"मुझे यकीन नहीं हो रहा!?", "Mujhe yakeen nahi ho raha!"),
        (r"मुझे समझ नहीं आ रहा!?", "Mujhe samajh nahi aa raha!"),
        (r"कौन हो तुम\??", "Kaun ho tum?"),
        (r"कौन है वहाँ\??", "Kaun hai wahan?"),
        (r"तुझे खत्म कर दूँगा!?", "Tujhe khatam kar doonga!"),
        (r"यह नामुमकिन है!?", "Yeh namumkin hai!"),
        (r"मेरी मदद करो!?", "Meri madad karo!"),
        (r"सब ठीक तो है ना\??", "Sab theek toh hai na?"),
        (r"शुक्रिया!?", "Shukriya!"),
        (r"अलविदा!?", "Alvida!"),
        (r"रुको जरा!?", "Ruko zara!"),
    ]

    # Devanagari character mapping fallback for words not in common vocab
    VOWELS = {
        'अ': 'a', 'आ': 'aa', 'इ': 'i', 'ई': 'ee', 'उ': 'u', 'ऊ': 'oo',
        'ए': 'e', 'ऐ': 'ai', 'ओ': 'o', 'औ': 'au', 'ऋ': 'ri',
        'ऑ': 'o', 'ॲ': 'a',
        'ं': 'n', 'ँ': 'n', 'ः': 'h'
    }
    MATRAS = {
        'ा': 'a', 'ि': 'i', 'ी': 'ee', 'ु': 'u', 'ू': 'oo',
        'े': 'e', 'ै': 'ai', 'ो': 'o', 'ौ': 'au', 'ृ': 'ri',
        'ॉ': 'o', 'ॅ': 'e',
        'ं': 'n', 'ँ': 'n', '्': ''
    }
    CONSONANTS = {
        'क': 'k', 'ख': 'kh', 'ग': 'g', 'घ': 'gh', 'ङ': 'ng',
        'च': 'ch', 'छ': 'chh', 'ज': 'j', 'झ': 'jh', 'ञ': 'ny',
        'ट': 't', 'ठ': 'th', 'ड': 'd', 'ढ': 'dh', 'ण': 'n',
        'त': 't', 'थ': 'th', 'द': 'd', 'ध': 'dh', 'न': 'n',
        'प': 'p', 'फ': 'ph', 'ब': 'b', 'भ': 'bh', 'म': 'm',
        'य': 'y', 'र': 'r', 'ल': 'l', 'व': 'v', 'श': 'sh',
        'ष': 'sh', 'स': 's', 'ह': 'h', 'ड़': 'd', 'ढ़': 'dh',
        'फ़': 'f', 'ज़': 'z', 'क़': 'q', 'ख़': 'kh', 'ग़': 'gh'
    }

    @classmethod
    def romanize_devanagari(cls, text: str) -> str:
        """Transliterates any remaining Devanagari tokens into phonetic Roman script."""
        res = []
        i = 0
        n = len(text)
        while i < n:
            ch = text[i]
            if ch in cls.VOWELS:
                res.append(cls.VOWELS[ch])
            elif ch in cls.MATRAS:
                res.append(cls.MATRAS[ch])
            elif ch in cls.CONSONANTS:
                base = cls.CONSONANTS[ch]
                # Check next character
                if i + 1 < n and text[i+1] in cls.MATRAS:
                    matra = text[i+1]
                    res.append(base + cls.MATRAS[matra])
                    i += 1
                elif i + 1 < n and text[i+1] == '्': # Halant
                    res.append(base)
                    i += 1
                else:
                    # Inherited 'a' vowel unless followed by another matra or punctuation/space
                    if i + 1 < n and (text[i+1].isalnum() or text[i+1] in cls.CONSONANTS):
                        res.append(base + 'a')
                    else:
                        res.append(base)
            elif ch in ['।', '|']:
                res.append('.')
            else:
                res.append(ch)
            i += 1
        output = ''.join(res)
        # Strip any stubborn stray Devanagari codepoints if any remain
        output = re.sub(r'[\u0900-\u097F]', '', output)
        return output

    @classmethod
    def to_hinglish(
        cls,
        hindi_text: str,
        character_style: Optional[str] = "casual",
        translation_style: Optional[str] = "natural_hinglish",
        english_mixing: Optional[str] = "medium",
    ) -> str:
        """Converts polished Hindi dialogue into natural Roman Hinglish dub dialogue."""
        text = hindi_text.strip()

        # 1. Match known high-frequency anime phrases
        for pattern, replacement in cls.PHRASE_MAPPINGS:
            text = re.sub(pattern, replacement, text)

        # 2. Token-level dictionary replacement for remaining text
        words = text.split()
        converted_words = []
        for w in words:
            # strip punctuation
            clean_w = re.sub(r'[^\w\s\u0900-\u097F]', '', w)
            punct = w.replace(clean_w, '')
            if clean_w in cls.DEV_TO_HINGLISH_VOCAB:
                roman = cls.DEV_TO_HINGLISH_VOCAB[clean_w]
                converted_words.append(roman + punct)
            elif re.search(r'[\u0900-\u097F]', clean_w):
                # Fallback phonetics
                roman = cls.romanize_devanagari(clean_w)
                converted_words.append(roman + punct)
            else:
                converted_words.append(w)

        result = " ".join(converted_words)

        # 3. Final safety sweep: transliterate any lingering Devanagari glyphs
        if re.search(r'[\u0900-\u097F]', result):
            result = cls.romanize_devanagari(result)

        # 4. Strip any lingering Japanese glyphs (Kanji / Kana)
        result = re.sub(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]', '', result).strip()
        if not result or len(result) < 2:
            result = "Tum kya bol rahe ho?"

        # Capitalize first character of sentences
        result = re.sub(r'(^|[.!?]\s+)([a-z])', lambda m: m.group(1) + m.group(2).upper(), result)
        if result and result[0].islower():
            result = result[0].upper() + result[1:]

        return cls.apply_style_and_mixing(result, character_style, translation_style, english_mixing)

    @classmethod
    def apply_style_and_mixing(
        cls,
        hinglish: str,
        character_style: Optional[str],
        translation_style: Optional[str],
        english_mixing: Optional[str],
    ) -> str:
        """Adjusts English word substitution and tone according to character and mixing settings."""
        res = hinglish

        # English mixing dictionary (natural Indian spoken loan words)
        medium_replacements = [
            (r"\bmadad\b", "help"),
            (r"\byakeen\b", "believe"),
            (r"\bsamajh nahi\b", "understand nahi"),
            (r"\bkhatra\b", "danger"),
            (r"\btheek\b", "fine"),
        ]

        high_replacements = [
            (r"\bmadad\b", "help"),
            (r"\byakeen\b", "believe"),
            (r"\bsamajh nahi aa raha\b", "seriously understand nahi kar paa raha"),
            (r"\bkhatra\b", "danger"),
            (r"\btakatwar\b", "powerful"),
            (r"\btheek\b", "alright"),
            (r"\bshukriya\b", "thank you"),
        ]

        mixing = (english_mixing or "medium").lower()

        if mixing in ["medium", "auto"]:
            # Apply subtle, natural loanwords
            if "urban" in (translation_style or "").lower() or character_style in ["casual", "intellectual"]:
                for pat, rep in medium_replacements:
                    if len(res) > 20: # only in longer sentences
                        res = re.sub(pat, rep, res, flags=re.IGNORECASE)
        elif mixing == "high":
            for pat, rep in high_replacements:
                res = re.sub(pat, rep, res, flags=re.IGNORECASE)

        # Character personality touch
        c_style = (character_style or "").lower()
        if c_style == "casual" and "bro" not in res.lower() and len(res.split()) > 4:
            if not res.startswith("Bro"):
                pass # Natural cadence
        elif c_style == "formal":
            res = re.sub(r"\btum\b", "aap", res, flags=re.IGNORECASE)
            res = re.sub(r"\btujhe\b", "aapko", res, flags=re.IGNORECASE)
        elif c_style == "aggressive":
            if not res.endswith("!"):
                res = res.rstrip(".") + "!"

        # Ensure trailing punctuation
        if not res.endswith(('.', '!', '?')):
            res += "."

        return res

    @classmethod
    def create_tts_pronunciation(cls, hinglish_text: str, hindi_devanagari: str) -> str:
        """Generates the optimal pronunciation representation for the Hindi neural TTS engine.
        
        Neural Hindi voices (Edge-TTS hi-IN, Piper) pronounce Hindi phonemes with highest
        accuracy from Devanagari text, while speaking English loanwords accurately from English script.
        """
        # If Hinglish contains recognized English words, preserve them in English
        # while using Devanagari for the grammatical structure
        english_loanwords = {"help", "understand", "believe", "danger", "powerful", "alright", "thank you", "bro", "sorry", "wait", "focus", "serious", "seriously", "problem"}
        
        words_in_hinglish = hinglish_text.lower().split()
        contained_english = [w.strip(".,!?") for w in words_in_hinglish if w.strip(".,!?") in english_loanwords]

        if not contained_english:
            # Clean Devanagari gives the most natural prosody and pronunciation
            return hindi_devanagari

        # Substitute English words into the Devanagari structure for hybrid neural synthesis
        pronunciation = hindi_devanagari
        for eng in contained_english:
            if eng == "help":
                pronunciation = re.sub(r"मदद", "help", pronunciation)
            elif eng == "understand":
                pronunciation = re.sub(r"समझ", "understand", pronunciation)
            elif eng == "believe":
                pronunciation = re.sub(r"यकीन", "believe", pronunciation)
            elif eng == "danger":
                pronunciation = re.sub(r"खतरा", "danger", pronunciation)

        return pronunciation
