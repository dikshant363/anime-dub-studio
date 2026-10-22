# Speaker Similarity & Voice Quality

This document explains the acoustic principles, capability models, and configuration options governing voice synthesis and character preservation in Anime Dub Studio.

---

## 1. Truthful Capability Model

Anime Dub Studio strictly separates **acoustic presence/timbre coloration** from **neural zero-shot voice cloning**.

Native macOS speech synthesis uses Apple's built-in Indian English and Hindi voice cast (`Rishi`, `Lekha`, `Aman`, `Tara`). While these voices provide exceptional clarity and natural Indian prosody, they are **not** neural cloning engines.

The provider declares this model truthfully in code:
```swift
SpeechSynthesisCapabilities(
    providerId: "com.apple.speech.native_cast",
    providerName: "macOS Native Speech (Indian Cast Voices)",
    technologyType: .nativeAcousticCast,
    supportsVoiceCloning: false,
    supportsReferenceAudioConditioning: false,
    supportsIndependentNaturalnessControl: true,
    supportedVoiceIds: ["Rishi", "Lekha", "Aman", "Tara"],
    disclosureNotice: "Native Indian cast voices with prosodic cadence adaptation and acoustic presence coloration. Zero-shot neural voice cloning from reference audio is not supported by macOS native speech."
)
```

---

## 2. Configurable Acoustic Controls

### Speaker Similarity (0–100%)
* Controls dynamic frequency shaping, presence filtering, and resonance targeting.
* At higher values ($> 70\%$), the pipeline applies parametric equalization (`equalizer`, `treble`, `lowpass`, and dynamic compression) to shape the native voice's spectral distribution toward the measured fundamental frequency ($F_0$) and timbre of the source Japanese voice actor.
* At lower values ($< 30\%$), the native voice retains its standard acoustic studio profile.

### Target Naturalness (0–100%)
* Regulates conversational fluency, cadence variability, syllable pacing, and pause duration.
* High naturalness ($> 75\%$) introduces natural breath pauses between clauses, micro-cadence variation, and dynamic speed modulation (140–165 WPM).
* Low naturalness ($< 40\%$) enforces rigid, metronomic timing.

### Accent Preservation Modes
1. **Preserve Original Accent (Source Vocal Timbre):**
   - Emphasizes sharp, punchy Japanese anime cadence (185 WPM baseline).
   - Tighter high-mid formant filters for expressive, theatrical anime delivery.
2. **Balanced (Recognizable Voice + Natural Speech):**
   - Blends character identity with conversational Hindi/Hinglish flow (155 WPM baseline).
   - Recommended default for general anime viewing.
3. **Natural Hindi/Hinglish (Max Intelligibility):**
   - Prioritizes fluent colloquial Indian phonetics, relaxed phrasing, and maximum audience comprehension (142 WPM baseline).

---

## 3. Character Cast Consistency & Reference Extraction

* **Reference Audio Extraction:** During Stage 3 diarization, the cleanest dialogue slice ($\ge 1.2\text{s}$) for each speaker is extracted to `voices/ref_<tag>.wav`.
* **Provenance Tracking:** Slices record their origin (e.g. *"Extracted from segment seg_002, duration 2.80s"*) and assignment confidence in `CharacterProfile`.
* **Studio Auditioning:** In the `DubbingEditorView`, users can open the **Character Cast Manager** to play reference audio clips side-by-side with synthesized preview clips and reassign voices across the cast.
