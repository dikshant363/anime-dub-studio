# Changelog

All notable changes to **Anime Dub Studio** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.1.1] - 2026-10-23

### Speaker-Preserving Dubbing, Truthful Capabilities & Finished-Video Studio

### Added
- **Speaker Similarity & Naturalness Controls:** Independent user sliders for Speaker Similarity (0–100%) and Target Naturalness (0–100%) with 3 Accent Preservation presets (*Preserve Original Accent*, *Balanced*, *Natural Hindi/Hinglish*).
- **Truthful Speech Synthesis Capabilities Model:** Introduced `SpeechSynthesisCapabilities` protocol declaration transparently disclosing acoustic presence shaping and Indian cast allocation without false voice cloning claims.
- **Reference Audio Extraction & Provenance:** Automated Stage 3 extraction of clean reference audio slices (`voices/ref_<tag>.wav`) from the source dialogue, storing duration, provenance, and assignment confidence in `CharacterProfile`.
- **Character Cast Manager Sheet:** Native Studio sheet in `DubbingEditorView` for inspecting character reference clips and reassigning voices across the cast.
- **Dedicated Finished-Video Results Screen (`FinishedVideoResultView`):** Post-render workspace featuring playable `AVPlayer` preview, dual-track A/B audio switcher (*Dubbed* vs *Original Japanese*), technical specifications grid, 5-pillar QA scorecard, and native macOS export actions.
- **Granular Signature Cache Invalidation:** Segment signature hashing (`seg_%03d.sig`) invalidates and re-synthesizes only modified dialogue lines during Studio re-edits, eliminating redundant transcription and re-processing.
- **Automated Test Coverage:** Added `SpeakerSimilarityAndAccentTests`, `FinishedVideoWorkflowTests`, and `ProviderCapabilitiesAndCacheTests` (34 total tests passing).

---

## [2.0.0] - 2026-10-23

### Major Architecture Milestone: Native Swift macOS Rewrite & Hardening

Anime Dub Studio 2.0 is a complete ground-up rewrite from the legacy hybrid Python/Tauri/Next.js stack into a high-performance, native Swift 6.4 macOS desktop application adhering strictly to Apple's Human Interface Guidelines (HIG).

### Added
- **Native Swift Engine (`AnimeDubCore`):**
  - High-throughput asynchronous pipeline engine built with Swift 6 structured concurrency.
  - Native media probing via AVFoundation (`AVURLAsset`) and `ffprobe`.
  - Multi-stream discovery and automatic Japanese dialogue track selection (`-map 0:<idx>`).
  - Phrase-level utterance grouping from Apple Speech (`SFSpeechRecognizer`) on-device recognition.
  - Pitch $F_0$ and spectral centroid acoustic diarization clustering into anime character archetypes.
  - Colloquial Hindi and Roman Hinglish translation router with anime honorific preservation.
  - Native macOS multi-voice speech synthesis with Indian cast voices (`Rishi`, `Lekha`, `Aman`, `Tara`).
  - WSOLA time-stretching and duration contraction (`atempo`) to ensure lip-sync cadence.
  - 48kHz stereo timeline assembly and mastering with sidechain background audio ducking (45% attenuation).
  - Two-pass broadcast EBU R128 loudness normalization (-23.0 LUFS, -1.0 dB True Peak).
  - Synchronized SRT and styled ASS subtitle generation.
  - Lossless stream-copy video multiplexing (`-c:v copy`) preserving pristine 1080p HEVC image quality.
  - 5-Pillar automated Quality Assurance (QA) engine.
- **Native SwiftUI User Interface (`AnimeDubStudio`):**
  - Standalone macOS app bundle (`Anime Dub Studio.app`, 5.3 MB) and Apple Silicon DMG installer.
  - Apple HIG-compliant sidebar navigation: Studio Projects, Live Processing, Dubbing Editor, and Settings.
  - High-fidelity Timeline Waveform Editor with per-character voice assignment and audio playback.
  - Export Quality sheet with broadcast compliance badges and instant QuickLook video preview.
- **Security & Resilience:**
  - Non-blocking asynchronous pipe read handlers in `ProcessRunner` eliminating standard I/O deadlocks.
  - `withTaskCancellationHandler` for sub-second subprocess termination on job cancellation.
  - Atomic checkpoint persistence with crash-resilient stage resumption.
  - Bounded memory streaming (< 2 MB buffer) across multi-gigabyte audio files.
- **Packaging & Delivery:**
  - Standalone packaging script `scripts/package_native_app.sh` producing self-contained DMG installer.
  - Automated test suite `tests/AnimeDubCoreTests/` with 24 tests across 7 suites covering all pipeline modules.

### Removed
- **8.4+ GB of Dead Code Eliminated:**
  - Removed legacy FastAPI Python backend (`backend/app/`).
  - Removed Next.js 14 frontend and Tailwind components (`frontend/`).
  - Removed Tauri 2 / Rust desktop shell and Cargo dependencies (`src-tauri/`).
  - Removed Python virtual environment (`.venv/`), pycache, and notebooks.
  - Removed obsolete development servers, shell bootstrap scripts, and package manifests.

---

## [2.1.1] - 2026-10-23

### Speaker-Preserving Dubbing, Truthful Capabilities & Finished-Video Studio

### Added
- **Speaker Similarity & Naturalness Controls:** Independent user sliders for Speaker Similarity (0–100%) and Target Naturalness (0–100%) with 3 Accent Preservation presets (*Preserve Original Accent*, *Balanced*, *Natural Hindi/Hinglish*).
- **Truthful Speech Synthesis Capabilities Model:** Introduced `SpeechSynthesisCapabilities` protocol declaration transparently disclosing acoustic presence shaping and Indian cast allocation without false voice cloning claims.
- **Reference Audio Extraction & Provenance:** Automated Stage 3 extraction of clean reference audio slices (`voices/ref_<tag>.wav`) from the source dialogue, storing duration, provenance, and assignment confidence in `CharacterProfile`.
- **Character Cast Manager Sheet:** Native Studio sheet in `DubbingEditorView` for inspecting character reference clips and reassigning voices across the cast.
- **Dedicated Finished-Video Results Screen (`FinishedVideoResultView`):** Post-render workspace featuring playable `AVPlayer` preview, dual-track A/B audio switcher (*Dubbed* vs *Original Japanese*), technical specifications grid, 5-pillar QA scorecard, and native macOS export actions.
- **Granular Signature Cache Invalidation:** Segment signature hashing (`seg_%03d.sig`) invalidates and re-synthesizes only modified dialogue lines during Studio re-edits, eliminating redundant transcription and re-processing.
- **Automated Test Coverage:** Added `SpeakerSimilarityAndAccentTests`, `FinishedVideoWorkflowTests`, and `ProviderCapabilitiesAndCacheTests` (34 total tests passing).

---

## [1.0.0] - 2026-10-08

### Initial Release (Legacy Prototype)
- Hybrid prototype using FastAPI Python backend, Next.js frontend, and Tauri 2 wrapper.
- Proof-of-concept pipeline for Whisper transcription, Edge-TTS synthesis, and basic video muxing.
