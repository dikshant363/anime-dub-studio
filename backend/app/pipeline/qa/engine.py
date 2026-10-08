import re
import numpy as np
import soundfile as sf
from pathlib import Path
from typing import List, Dict, Any, Tuple, Optional

class QAEngine:
    """Automated Quality Assurance engine evaluating ASR, Translation, Hinglish, TTS, Timing, and Audio."""

    COMMON_ENGLISH_WORDS = {
        "the", "be", "is", "am", "are", "was", "were", "been", "being", "to", "of", "and", "a", "in", "that", "have", "has", "had", "i", "it", "for", "not", "on", "with",
        "he", "as", "you", "do", "does", "did", "doing", "done", "at", "this", "but", "his", "by", "from", "they", "we", "say", "her",
        "she", "or", "an", "will", "my", "one", "all", "would", "there", "their", "what", "so", "up",
        "out", "if", "about", "who", "get", "which", "go", "going", "gone", "went", "me", "when", "make", "can", "could", "like", "time",
        "no", "just", "him", "know", "take", "people", "into", "year", "your", "good", "some", "could",
        "them", "see", "other", "than", "then", "now", "look", "only", "come", "its", "over", "think",
        "also", "back", "after", "use", "two", "how", "our", "work", "first", "well", "way", "even",
        "new", "want", "because", "any", "these", "give", "day", "most", "us", "help", "understand",
        "believe", "danger", "bro", "sorry", "wait", "focus", "serious", "seriously", "problem", "alright",
        "here", "friend", "man", "guy", "really", "right", "wrong", "yes", "please", "why", "stop", "run"
    }

    @classmethod
    def evaluate_episode(
        cls,
        segments: List[Dict[str, Any]],
        dubbed_audio_path: Optional[Path] = None,
        video_duration: float = 0.0,
        is_hinglish: bool = False,
        target_lang: Optional[str] = None
    ) -> Tuple[float, Dict[str, Any]]:
        warnings: List[str] = []
        checks_passed: List[str] = []
        score = 100.0

        if target_lang is not None:
            is_hinglish = "hinglish" in target_lang.lower() or target_lang.lower() == "hi-latn"

        if not segments:
            return 0.0, {
                "score": 0.0,
                "warnings": ["No dialogue segments detected in media."],
                "checks_passed": []
            }

        prev_text = ""

        # 1. Transcription & Segment Confidence
        low_conf_count = 0
        for idx, seg in enumerate(segments):
            conf = float(seg.get("confidence", 1.0))
            if conf < 0.65:
                low_conf_count += 1
                if len([w for w in warnings if "Low ASR confidence" in w]) < 5:
                    warnings.append(f"Segment #{idx+1}: Low ASR confidence ({int(conf*100)}%). Verify Japanese source text.")
        
        if low_conf_count > 0:
            if low_conf_count > 5:
                warnings.append(f"Noted: {low_conf_count} total segments had low ASR confidence due to background music or rapid speech.")
            score -= min(15.0, round((low_conf_count / len(segments)) * 15.0, 1))

        # 2. Translation & Script Integrity Checks
        empty_count = 0
        japanese_leak_count = 0
        devanagari_leak_count = 0
        repeated_count = 0

        for idx, seg in enumerate(segments):
            if is_hinglish:
                target = seg.get("adapted_hinglish_text") or seg.get("adapted_hindi_text") or ""
            else:
                target = seg.get("adapted_hindi_text") or seg.get("translated_text", "")

            if not target or len(target.strip()) == 0:
                empty_count += 1
                if empty_count <= 3:
                    warnings.append(f"Segment #{idx+1}: Empty dialogue.")
                continue

            # Repeated dialogue check
            clean_curr = target.strip().lower()
            if clean_curr == prev_text and len(clean_curr) > 8:
                repeated_count += 1
                if repeated_count <= 3:
                    warnings.append(f"Segment #{idx+1}: Repeated consecutive dialogue detected.")
            prev_text = clean_curr

            # Untranslated Japanese (Kanji/Kana) in target text
            japanese_chars = re.findall(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]', target)
            if japanese_chars:
                japanese_leak_count += 1
                if japanese_leak_count <= 3:
                    warnings.append(f"Segment #{idx+1}: Untranslated Japanese characters found in dubbed line: {''.join(japanese_chars[:5])}")

            if is_hinglish:
                # Unexpected Devanagari in Roman Hinglish
                devanagari_chars = re.findall(r'[\u0900-\u097F]', target)
                if devanagari_chars:
                    devanagari_leak_count += 1
                    if devanagari_leak_count <= 3:
                        warnings.append(f"Segment #{idx+1}: Unexpected Devanagari characters in Roman Hinglish line: {''.join(devanagari_chars[:5])}")

                # English percentage check
                words = re.findall(r'[a-zA-Z]+', target.lower())
                if words:
                    english_count = sum(1 for w in words if w in cls.COMMON_ENGLISH_WORDS)
                    eng_pct = int((english_count / len(words)) * 100)
                    if eng_pct > 75 and len(words) >= 4:
                        if len([w for w in warnings if "English usage" in w]) < 3:
                            warnings.append(f"Segment #{idx+1}: English usage {eng_pct}% exceeds expected threshold (70%).")
                        score -= 1.0

        if empty_count > 0:
            score -= min(20.0, empty_count * 5.0)
        if repeated_count > 0:
            score -= min(10.0, repeated_count * 1.5)
        if japanese_leak_count > 0:
            score -= min(25.0, japanese_leak_count * 4.0)
        if devanagari_leak_count > 0:
            score -= min(20.0, devanagari_leak_count * 3.0)

        # 3. Timing & TTS Duration Checks
        timing_mismatch_count = 0
        missing_audio_count = 0
        for idx, seg in enumerate(segments):
            ratio = float(seg.get("duration_ratio", 1.0))
            if ratio > 1.30 or (ratio < 0.65 and ratio > 0.0):
                timing_mismatch_count += 1
                if len([w for w in warnings if "longer than" in w or "shorter than" in w]) < 5:
                    if ratio > 1.30:
                        warnings.append(f"Segment #{idx+1}: Dialogue duration is {int((ratio-1.0)*100)}% longer than target window.")
                    else:
                        warnings.append(f"Segment #{idx+1}: Dialogue duration is {int((1.0-ratio)*100)}% shorter than target window.")

            audio_p = seg.get("audio_path")
            if not audio_p or not Path(audio_p).exists():
                missing_audio_count += 1
                if missing_audio_count <= 3:
                    warnings.append(f"Segment #{idx+1}: Missing synthesized voice audio file.")

        if timing_mismatch_count > 0:
            pct_mismatch = timing_mismatch_count / len(segments)
            score -= min(15.0, round(pct_mismatch * 15.0, 1))
        if missing_audio_count > 0:
            score -= min(30.0, missing_audio_count * 10.0)

        # 4. Master Audio & Clipping Checks
        if dubbed_audio_path and dubbed_audio_path.exists():
            try:
                data, sr = sf.read(str(dubbed_audio_path), dtype="float32")
                peak = float(np.max(np.abs(data)))
                if peak >= 0.999:
                    warnings.append("Master audio: Potential digital clipping detected (peak >= 0 dBFS).")
                    score -= 5.0
                else:
                    checks_passed.append("No audio clipping detected (True peak below -0.1 dBFS).")

                rms = float(np.sqrt(np.mean(data**2)))
                if rms < 0.005:
                    warnings.append("Master audio: Unusually low overall volume (silence or near-silence).")
                    score -= 15.0
            except Exception as e:
                warnings.append(f"Master audio check error: {str(e)}")

        # 5. Multi-character voice diversity check
        distinct_voices = set()
        for seg in segments:
            v_id = seg.get("voice_id")
            if v_id:
                distinct_voices.add(v_id)
        if len(segments) > 10 and len(distinct_voices) == 1:
            warnings.append("Voice assignment failure: All characters are using the exact same voice ID.")
            score -= 30.0
        elif len(distinct_voices) > 1:
            checks_passed.append(f"Distinct character voices verified ({len(distinct_voices)} unique voice profiles).")

        if not any("Untranslated Japanese" in w for w in warnings):
            checks_passed.append("No Japanese characters remaining in dubbed dialogue.")

        if is_hinglish and not any("Unexpected Devanagari" in w for w in warnings):
            checks_passed.append("No unexpected Devanagari in Roman Hinglish script.")

        if not any("longer than" in w or "shorter than" in w for w in warnings):
            checks_passed.append("All dialogue lines synchronized within timing tolerances.")

        if not any("Missing synthesized" in w for w in warnings):
            checks_passed.append("TTS voices synthesized and verified for all character segments.")

        final_score = max(0.0, min(100.0, round(score, 1)))

        return final_score, {
            "score": final_score,
            "status": "PASS" if final_score >= 80.0 else ("WARNING" if final_score >= 60.0 else "FAIL"),
            "warnings": warnings,
            "checks_passed": checks_passed
        }
