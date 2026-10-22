# ARCHITECTURE SPECIFICATION — ANIME DUB STUDIO
**Native Apple Silicon macOS Local-First AI Dubbing Workstation**
**Version:** 2.0.0
**Target Platforms:** Apple Silicon macOS 14+, macOS 15+, macOS 26+ (Optimized for M4 16GB Unified Memory)
**Primary Stack:** Swift 6.4, SwiftUI, AppKit, AVFoundation, FoundationModels

---

## 1. System Philosophy & Non-Negotiables

Anime Dub Studio is an on-device, local-first studio for voice dubbing and localization, engineered around four core tenets:

1. **Native Apple Silicon Architecture:** Replaced the multi-runtime Tauri, Node.js, and Python application shell with a unified Swift 6.4 and SwiftUI macOS application conforming to Apple's Human Interface Guidelines.
2. **Deterministic Safety Boundaries:** Probabilistic AI models (LLMs, neural ASR, neural TTS) are strictly wrapped in typed models, timing boundary enforcers, and transactional stage checkpoints.
3. **Natural Hindi & Roman Hinglish Localization:** Cultural anime translation is treated as a multi-stage localization process: Japanese transcription → semantic translation → colloquial Hindi interpretation → Roman-script Hinglish localization → timing-aware editing → phonetic pronunciation representation for speech synthesis.
4. **Resilience & Stage Checkpointing:** Every processing stage produces immutable JSON checkpoints. If a stage fails or is interrupted, the job resumes from the last valid checkpoint without duplicating work.

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                       Anime Dub Studio Architecture                         │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    SwiftUI + AppKit HIG Native Views                  │  │
│  │  • ProjectHomeView        • CreateDubSheet       • LiveProcessingView │  │
│  │  • DubbingEditorView      • ExportQualitySheet   • SettingsView       │  │
│  └──────────────────────────────────┬────────────────────────────────────┘  │
│                                     │ @EnvironmentObject / Observation       │
│  ┌──────────────────────────────────▼────────────────────────────────────┐  │
│  │                         AppState & ViewModels                         │  │
│  │  • StudioViewModel       • DubbingEditorViewModel                     │  │
│  └──────────────────────────────────┬────────────────────────────────────┘  │
│                                     │ Structured Concurrency (async/await)   │
│  ┌──────────────────────────────────▼────────────────────────────────────┐  │
│  │                       Pipeline Orchestration Core                     │  │
│  │  • JobOrchestrator        • CheckpointStore      • ModelCapabilityReg │  │
│  └───────┬──────────────┬──────────────┬──────────────┬──────────────┬───┘  │
│          │              │              │              │              │      │
│  ┌───────▼──────┐┌──────▼──────┐┌──────▼──────┐┌──────▼──────┐┌──────▼───┐  │
│  │ MediaProbe & ││ ASRProvider ││ Translation ││ Speech      ││ Mixing & │  │
│  │ Extraction   ││  • MLX-Whis ││  • Apple FMs││  Synthesis  ││ Render   │  │
│  │  • AVAsset   ││  • SFSpeech ││  • Offline  ││  • AVSpeech ││  • WSOLA │  │
│  │  • FFprobe   ││  • Fallback ││    Fallback ││  • /say IN  ││  • EBU-R │  │
│  └──────────────┘└─────────────┘└─────────────┘└─────────────┘└──────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Subsystem Specifications

### 2.1 Media Ingestion & Deep Stream Probing (`MediaProbeService`)
- Uses `AVURLAsset` from AVFoundation for direct hardware-accelerated container inspection.
- Supplements with `ffprobe` JSON stream inspection to extract:
  - Track indices
  - Audio and video codecs
  - Channels and sample rates
  - Explicit language tags (specifically identifying `[JPN]` tracks in dual-audio MKV files).
- Never assumes audio stream 0 is Japanese.

### 2.2 Audio Extraction (`AudioExtractionService`)
- Extracts 48kHz 24-bit stereo PCM WAV for high-fidelity master mixing and BGM preservation.
- Extracts 16kHz 16-bit mono PCM WAV for Whisper speech recognition.
- Maps directly to the user-selected audio track index or falls back to language tag mapping.

### 2.3 Japanese Speech Recognition (`ASRProvider`)
- Implements `ASRProviderProtocol` with three interchangeable providers:
  1. `MLXWhisperASRProvider`: Apple Silicon MLX Whisper executable running on-device with segment-level timestamps and logprob confidence scores.
  2. `AppleSpeechASRProvider`: Apple `Speech` framework (`SFSpeechRecognizer`) for supported locales.
  3. `DeterministicASRProvider`: Offline deterministic fallback for hermetic test execution.

### 2.4 Acoustic Speaker Diarization (`AcousticDiarizer`)
- Analyzes speech audio slices for each segment directly in Swift:
  - RMS energy calculation
  - Spectral centroid estimation
  - Autocorrelation fundamental frequency (F0) estimation (80 Hz to 350 Hz)
- Assigns character voice tags (`SPEAKER_00` to `SPEAKER_03`) based on gender acoustic thresholds and conversational turn smoothing.

### 2.5 Translation & Localization (`TranslationRouter`)
- Integrates Apple's `FoundationModels` framework (`SystemLanguageModel` / `LanguageModelSession`) directly in Swift on macOS 26+.
- Provides an offline deterministic fallback dictionary for 30+ high-frequency anime phrases and hashing fallback.
- Interfaces with `HindiAdaptationService` and `HinglishLocalizationService`.

### 2.6 Spoken Hinglish Localization (`HinglishLocalizationService`)
- 120+ word conversational anime vocabulary dictionary.
- Phonetic Devanagari transliteration fallback ensuring zero Devanagari codepoints leak into Roman Hinglish.
- Loanword mixing levels (`low`, `medium`, `high`) inserting natural spoken loanwords (e.g. `believe`, `help`, `danger`).
- Special `createTTSPronunciation` representation preserving Devanagari structure for native Hindi phonology with embedded English words.

### 2.7 Character Speech Synthesis (`SpeechSynthesisProvider`)
- Uses macOS native Indian voices (`Rishi`, `Lekha`, `Aman`, `Tara`) via `/usr/bin/say` process invocation.
- Modulates speaking rate (standard 175 wpm) and pitch per character profile.
- Converts to 24kHz 16-bit mono PCM WAV.
- 100% offline, zero network API dependency.

### 2.8 Timing Adjustment (`DialogueTimingService`)
- Measures duration ratio `current_duration / target_duration`.
- Applies FFmpeg WSOLA `atempo` time-stretching within safe bounds (0.75x to 1.30x).
- Leaves audio untouched if within 5% tolerance window (0.95 to 1.05).

### 2.9 Soundtrack Mixing (`AudioMixingService`)
- Assembles individual dialogue files into a continuous 48kHz 24-bit stereo timeline track directly in Swift memory.
- Prevents digital clipping by scaling master peak if > 0.95.
- Mixes with background audio track using sidechain ducking (`volume=0.55` for BGM, `volume=1.0` for dialogue).
- Normalizes loudness to broadcast standard EBU R128 (-23 LUFS / -1.0 dB True Peak).

### 2.10 Subtitle Generation (`SubtitleService`)
- Generates compliant SRT subtitles with `HH:mm:ss,SSS` timestamp precision.
- Generates stylized ASS subtitles with `H:mm:ss.SS` precision, font styling, and actor name mapping.

### 2.11 Video Multiplexing (`VideoRenderService`)
- Remuxes the original video stream losslessly using stream-copy (`-c:v copy`).
- Encodes mastered audio track as AAC 256kbps stereo.
- Produces clean MP4 playable in QuickTime, Safari, and standard video players.

### 2.12 Automated Quality Assurance (`QualityAssuranceService`)
- Scans completed episodes across 5 quality pillars:
  1. Low ASR confidence detection
  2. Script integrity (empty lines, repeated consecutive lines, Kanji/Kana leaks, Devanagari leaks in Roman Hinglish)
  3. Excessive English density check (> 75%)
  4. Timing and audio integrity (duration ratio > 1.30x or < 0.65x, missing voice files)
  5. Master audio clipping (peak >= 0 dBFS) and low volume (< 0.005 RMS)
  6. Voice diversity verification (cast voices must not collapse to a single voice)
- Emits numeric score (0–100) and status (`PASS`, `WARNING`, `FAIL`).
