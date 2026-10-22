# Anime Dub Studio v2.0
> **Native Swift & SwiftUI macOS Workstation for Local-First Japanese Video → Natural Hindi/Hinglish Dubbing.**

Anime Dub Studio is a native macOS application engineered in Swift 6.4 and SwiftUI to transcribe Japanese anime dialogue, cluster and assign character voices, localize the script into natural colloquial spoken Hindi or Roman Hinglish, synthesize authentic character voices on-device, synchronize dialogue pacing, master the soundtrack with BGM preservation, and export high-definition dubbed video without cloud subscription fees.

Packaged as a standalone 5.3 MB native Apple Silicon `.app` and `.dmg` installer, it requires no Python runtime server, no virtual environments, no Node.js, and no dev servers.

---

## Key Features

* **🖥 100% Native Swift & SwiftUI macOS Application:** Built with Swift 6.4, SwiftUI, and AppKit following Apple's Human Interface Guidelines (HIG). Bundled as a 5.3 MB native `.app` and 3.4 MB `.dmg` with official app icon.
* **🇯🇵 Japanese → 🇮🇳 Hindi & Hinglish Dubbing:** First-class anime localization engine preserving character personality, emotion, and anime honorifics in Devanagari Hindi or Latin Roman Hinglish (e.g. *"Tum kya kar rahe ho?"*).
* **🧠 On-Device Apple Intelligence:** Integrates Apple's `FoundationModels` framework (`SystemLanguageModel` / `LanguageModelSession`) directly in Swift on macOS 26+ with zero-cloud offline fallback.
* **🎙 Configurable Speaker Similarity (0–100%):** User-facing slider actively controls acoustic formant shaping and pitch conditioning (`equalizer`, `treble`, `lowpass`) to converge synthesized speech toward source anime vocal resonance.
* **🌐 Target-Language Naturalness & Accent Presets:** 0–100% naturalness slider and 3 distinct presets (*Preserve Original Accent*, *Balanced*, *Natural Hindi/Hinglish*) to balance character fidelity against colloquial flow.
* **👥 Character Voice Auditioning & Consistency:** Pre-dub voice auditioning with live audio preview; character profiles persist across re-runs and multi-episode timelines.
* **🎬 Dedicated Finished-Video Result Screen:** Post-render workspace inspired by modern dubbing workflows with playable `AVPlayer` preview, real-time specifications grid, 5-pillar QA scorecard, and one-click actions (*Edit in Studio*, *Save Video As...*, *Export Audio*, *Export Subtitles*, *Re-export with Settings*).
* **🎧 Seamless Dual-Track A/B Audio Switch:** Instant one-click toggle between Master Dubbed and Original Japanese audio during video playback with zero position drift.
* **🔁 Segment-Level A/B Auditioning:** Compare original Japanese dialogue slices directly against dubbed lines inside the `DubbingEditorView` timeline.
* **🔒 100% Local-First by Default:** On-device speech synthesis using native macOS Indian voices (`Rishi`, `Lekha`, `Aman`, `Tara`) operates entirely offline with zero network API dependency.
* **👥 Multi-Character Cast Voice Diversity:** Automatically assigns distinct voice profiles across cast members (Lead Protagonist, Lead Heroine, Supporting Male, Supporting Female); QA fails if cast voices collapse into a single voice.
* **⏱ Automated Timing & WSOLA Sync:** Intelligently measures synthesized duration against target video windows, applying WSOLA time-stretching (`atempo`) and syllable contraction to avoid robotic speech.
* **🎚 Lossless Video Multiplexing (`-c:v copy`):** Masters dubbed audio with EBU R128 loudness normalization (-23 LUFS), background music ducking, and remuxes video bitstreams losslessly with zero generational loss.
* **💾 Checkpoint & Resilient Recovery:** Saves stage checkpoints on disk; UI supports clean `Pause`, `Resume`, and `Cancel` with stage-level recovery.
* **🔍 Automated Quality Assurance (QA):** Automatically scans outputs for untranslated Japanese characters, Devanagari leaks in Hinglish, digital clipping, timing drift, and voice diversity.

---

## Architecture Overview

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                       Anime Dub Studio (Native Swift)                       │
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

## Quickstart & Verification

### 1. Requirements
* Apple Silicon Mac (M1, M2, M3, M4) running macOS 14+ (macOS 26+ for Apple Foundation Models)
* FFmpeg (`brew install ffmpeg`)
* Swift 6.4 / Xcode 27+

### 2. Run Automated Test Suite
Execute the complete test suite verifying unit tests, Roman script guarantees, and end-to-end media pipeline runs:

```bash
swift test
```

### 3. Build Release Application & DMG Installer
Build the standalone native macOS `.app` bundle and `.dmg` disk image:

```bash
./scripts/package_native_app.sh
```

The output artifacts are generated at:
* **Application Bundle:** `dist/Anime Dub Studio.app` (5.3 MB)
* **DMG Installer:** `dist/Anime Dub Studio.dmg` (3.4 MB)
* **Installed Application:** `/Applications/Anime Dub Studio.app`

---

## Project Documentation

* [Migration Plan (Tauri/Python to Native Swift)](MIGRATION_PLAN.md)
* [System Architecture Specification](docs/ARCHITECTURE.md)
* [Production Verification Report](PRODUCTION.md)
* [Troubleshooting Guide](TROUBLESHOOTING.md)
