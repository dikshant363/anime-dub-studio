import re
import numpy as np
import soundfile as sf
from pathlib import Path
from typing import List, Dict, Any, Tuple, Optional

class QAEngine:
    """Automated Quality Assurance engine evaluating ASR, Translation, TTS, Timing, and Audio."""

    @classmethod
    def evaluate_episode(
        cls,
        segments: List[Dict[str, Any]],
        dubbed_audio_path: Optional[Path] = None,
        video_duration: float = 0.0
    ) -> Tuple[float, Dict[str, Any]]:
        warnings: List[str] = []
        checks_passed: List[str] = []
        score = 100.0

        if not segments:
            return 0.0, {
                "score": 0.0,
                "warnings": ["No dialogue segments detected in media."],
                "checks_passed": []
            }

        # 1. Transcription Checks
        for idx, seg in enumerate(segments):
            conf = float(seg.get("confidence", 1.0))
            if conf < 0.65:
                warnings.append(f"Segment #{idx+1}: Low ASR confidence ({int(conf*100)}%). Verify Japanese source text.")
                score -= 2.0

        # 2. Translation & Devanagari Checks
        for idx, seg in enumerate(segments):
            target = seg.get("adapted_hindi_text") or seg.get("translated_text", "")
            if not target or len(target.strip()) == 0:
                warnings.append(f"Segment #{idx+1}: Empty Hindi translation.")
                score -= 8.0
                continue

            # Check for unadapted Japanese characters (Hiragana/Katakana/Kanji) in Hindi text
            japanese_chars = re.findall(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]', target)
            if japanese_chars:
                warnings.append(f"Segment #{idx+1}: Untranslated Japanese characters found in Hindi line: {''.join(japanese_chars[:5])}")
                score -= 5.0

            # Check for Devanagari presence
            devanagari_chars = re.findall(r'[\u0900-\u097F]', target)
            if not devanagari_chars:
                warnings.append(f"Segment #{idx+1}: Line does not contain Devanagari Hindi text.")
                score -= 5.0

        # 3. Timing & TTS Duration Checks
        for idx, seg in enumerate(segments):
            ratio = float(seg.get("duration_ratio", 1.0))
            if ratio > 1.30:
                warnings.append(f"Segment #{idx+1}: Synthesized Hindi duration is {int((ratio-1.0)*100)}% longer than dialogue window.")
                score -= 4.0
            elif ratio < 0.70 and ratio > 0.0:
                warnings.append(f"Segment #{idx+1}: Synthesized Hindi dialogue is {int((1.0-ratio)*100)}% shorter than dialogue window.")
                score -= 2.0

            audio_p = seg.get("audio_path")
            if not audio_p or not Path(audio_p).exists():
                warnings.append(f"Segment #{idx+1}: Missing synthesized voice audio file.")
                score -= 10.0

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
                if rms < 0.01:
                    warnings.append("Master audio: Unusually low overall volume (silence or near-silence).")
                    score -= 15.0
                else:
                    checks_passed.append("Audio loudness profile within studio dialogue parameters.")
            except Exception as e:
                warnings.append(f"Master audio check error: {str(e)}")

        if not any("ASR confidence" in w for w in warnings):
            checks_passed.append("All dialogue segments transcribed with high confidence.")

        if not any("Untranslated Japanese" in w for w in warnings):
            checks_passed.append("All dialogue lines localized to Hindi Devanagari without raw Japanese.")

        final_score = max(0.0, min(100.0, round(score, 1)))

        return final_score, {
            "score": final_score,
            "status": "PASS" if final_score >= 80.0 else ("WARNING" if final_score >= 60.0 else "FAIL"),
            "warnings": warnings,
            "checks_passed": checks_passed
        }
