import numpy as np
import soundfile as sf
from pathlib import Path
from typing import List, Dict, Any, Optional
from backend.app.pipeline.asr.base import TranscriptionSegment

class AcousticDiarizer:
    """Acoustic feature extraction and speaker diarization for anime dialogue.
    
    Assigns segments to distinct character profiles:
    - SPEAKER_00: Male Lead / Protagonist (Rishi)
    - SPEAKER_01: Female Lead / Heroine (Lekha)
    - SPEAKER_02: Male Secondary / Rival (Aman)
    - SPEAKER_03: Female Secondary (Tara)
    """

    @staticmethod
    def _estimate_pitch_and_centroid(y: np.ndarray, sr: int) -> Dict[str, float]:
        """Estimates fundamental frequency (F0) and spectral centroid."""
        if len(y) < sr * 0.1:  # < 100ms
            return {"f0": 130.0, "centroid": 1500.0, "rms": 0.01}

        # Energy / RMS
        rms = float(np.sqrt(np.mean(y ** 2)))
        if rms < 0.002:
            return {"f0": 130.0, "centroid": 1500.0, "rms": rms}

        # Spectral Centroid
        magnitude_spectrum = np.abs(np.fft.rfft(y))
        freqs = np.fft.rfftfreq(len(y), 1.0 / sr)
        sum_mag = np.sum(magnitude_spectrum)
        centroid = float(np.sum(freqs * magnitude_spectrum) / (sum_mag + 1e-8))

        # Autocorrelation Pitch Estimation (80 Hz to 350 Hz)
        min_lag = int(sr / 350)
        max_lag = int(sr / 80)
        
        # Take center 0.5s if long to speed up
        mid = len(y) // 2
        window_len = min(len(y), sr // 2)
        y_win = y[max(0, mid - window_len // 2): min(len(y), mid + window_len // 2)]
        
        corr = np.correlate(y_win, y_win, mode='full')
        corr = corr[len(corr) // 2:]

        f0 = 140.0  # default
        if len(corr) > max_lag:
            search_window = corr[min_lag:max_lag]
            if len(search_window) > 0 and np.max(search_window) > 0.25 * corr[0]:
                peak_lag = min_lag + int(np.argmax(search_window))
                f0 = float(sr / peak_lag)

        return {"f0": f0, "centroid": centroid, "rms": rms}

    @classmethod
    def diarize_segments(
        cls,
        audio_path: Path,
        segments: List[TranscriptionSegment]
    ) -> List[TranscriptionSegment]:
        """Analyzes speech audio slices for each segment and assigns character tags."""
        if not segments or not audio_path.exists():
            return segments

        try:
            data, sr = sf.read(str(audio_path), dtype="float32")
            if len(data.shape) > 1:
                data = np.mean(data, axis=1)

            total_len = len(data)
            features = []

            for seg in segments:
                start_sample = max(0, int(seg.start * sr))
                end_sample = min(total_len, int(seg.end * sr))
                if end_sample > start_sample:
                    slice_data = data[start_sample:end_sample]
                    feat = cls._estimate_pitch_and_centroid(slice_data, sr)
                else:
                    feat = {"f0": 140.0, "centroid": 1500.0, "rms": 0.01}
                features.append(feat)

            # Assign speakers based on acoustic properties and turn alternation
            f0_values = [f["f0"] for f in features]
            median_f0 = float(np.median(f0_values)) if f0_values else 140.0

            last_speaker = "SPEAKER_00"
            for i, seg in enumerate(segments):
                f0 = features[i]["f0"]
                centroid = features[i]["centroid"]

                # Female vs Male classification (standard anime thresholds)
                is_female = (f0 >= 165.0) or (centroid > 2200.0 and f0 >= 150.0)

                if is_female:
                    # Lead Female vs Secondary Female
                    if f0 >= 210.0 or centroid > 2600.0:
                        chosen = "SPEAKER_01"  # Lekha (Female Lead)
                    else:
                        chosen = "SPEAKER_03"  # Tara (Female Secondary)
                else:
                    # Lead Male vs Secondary Male
                    if f0 <= median_f0 or centroid < 1600.0:
                        chosen = "SPEAKER_00"  # Rishi (Male Lead)
                    else:
                        chosen = "SPEAKER_02"  # Aman (Male Secondary)

                # Dialogue turn smoothing: if rapid conversational exchange (< 1.2s pause)
                if i > 0 and (seg.start - segments[i-1].end) < 1.2:
                    if chosen == last_speaker:
                        # Alternate within gender or to other lead if ambiguous
                        if is_female:
                            chosen = "SPEAKER_03" if last_speaker == "SPEAKER_01" else "SPEAKER_01"
                        else:
                            chosen = "SPEAKER_02" if last_speaker == "SPEAKER_00" else "SPEAKER_00"

                seg.speaker = chosen
                last_speaker = chosen

        except Exception as e:
            # Fallback to simple turn alternation
            for i, seg in enumerate(segments):
                seg.speaker = f"SPEAKER_{i % 4:02d}"

        return segments
