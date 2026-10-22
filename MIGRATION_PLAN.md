# Anime Dub Studio — Native Swift macOS Migration Plan
**Document Version:** 1.0.0  
**Target Platform:** macOS 26+ (Apple Silicon M-Series, verified on M4 16GB Unified Memory)  
**Target Languages:** Swift 6.4, SwiftUI, AppKit, AVFoundation, FoundationModels  
**Specification Reference:** Master Engineering Prompt — Native Swift macOS Rewrite, Apple HIG Redesign & Production Hardening

---

## 1. Executive Summary & Audit Baseline

### 1.1 Current Architecture Analysis
The current application is a hybrid multi-runtime composite stack:
1. **Frontend UI Shell:** Next.js 15+ (React 19, Tailwind CSS, TypeScript, Lucide Icons) bundled as a static export into Tauri's WebKit WKWebView.
2. **Desktop Application Host:** Tauri 2 (Rust) managing IPC commands, system information probing, and window lifecycle.
3. **Subprocess Pipeline Runner:** Rust spawned Python scripts (`backend/app/pipeline/runner_cli.py` or FastAPI uvicorn daemon).
4. **Backend Processing Engine:** Python 3.12 using FastAPI, Pydantic, SQLite (via SQLAlchemy/aiosqlite), NumPy, SoundFile, Librosa, MLX-Whisper, and Edge-TTS.
5. **AI Acceleration Layer:** A separate auxiliary Swift binary (`AppleFoundationModelService` / `apple_intelligence_bridge.swift`) spawned as an external process by Python for Apple Intelligence Foundation Models.

### 1.2 Resource and Deployment Footprint
* **Installed Bundle Size:** ~1.6 GB (dominated by bundled Python `.venv` runtime copied into `Contents/Resources/python`).
* **Runtime Processes:** 4 concurrent runtimes in flight (`anime-dub-studio` binary, WebKit WebProcess, Python 3.12 interpreter, and child FFmpeg / Swift subprocesses).
* **Launch Latency:** 2.5–4.5 seconds cold launch due to WebKit view initialization and Python interpreter instantiation.

---

## 2. Confirmed Defects and Root Causes

| Defect ID | Component | Description | Root Cause |
| :--- | :--- | :--- | :--- |
| **DEF-001** | Subprocess Environment | `ModuleNotFoundError: No module named 'backend'` when executed outside developer terminal or when launched via Finder | Python interpreter defaults `sys.path` to root `/` when invoked from standalone GUI bundle; requires complex `PYTHONPATH` injection hacks. |
| **DEF-002** | Multi-Runtime IPC Latency | Redundant serialization hops (Rust JSON-RPC -> WebView postMessage -> Python stdout JSON -> Swift CLI JSON) | 4 disparate runtimes communicating over stdio and webview IPC creates serialization bottlenecks and potential pipe buffer deadlocks on long logs. |
| **DEF-003** | macOS HIG Non-Compliance | WebKit-rendered UI lacks genuine macOS controls, native menus, standard keyboard shortcuts, accessibility traits (AX), and VoiceOver tree integration | Custom web HTML buttons, scrollbars, and divs mimic macOS aesthetics rather than leveraging native AppKit/SwiftUI controls. |
| **DEF-004** | Speech Recognition Fallback | Apple Speech framework (`SFSpeechRecognizer`) cannot perform reliable offline Japanese transcription without downloaded Assistant assets | Runtime inspection reveals `ja-JP` locale has `supportsOnDeviceRecognition: false` unless Apple assistant assets are pre-installed. |
| **DEF-005** | Memory Overhead | 1.6 GB application size and ~650 MB idle RAM footprint | Packaging complete Python virtual environment, site-packages, dynamic C-extensions, and WebKit engine. |

---

## 3. Component Reuse vs Replacement Matrix

| Component | Current Implementation | Disposition | Replacement Strategy in Native Swift |
| :--- | :--- | :--- | :--- |
| **UI Shell** | Next.js / React 19 / Tailwind / Tauri 2 | **REPLACE** | Pure SwiftUI + AppKit native macOS application conforming to Apple HIG. |
| **App Lifecycle & Menus** | Tauri Rust `main.rs` + capabilities JSON | **REPLACE** | Swift 6 `@main struct AnimeDubStudioApp: App` with native MenuBar commands and Settings scene. |
| **Media Probing** | `MediaProbe` (Python ffprobe json wrapper) | **REPLACE** | Native Swift `MediaProbeService` using AVFoundation (`AVAssetTrack`) with FFprobe fallback. |
| **Audio Extraction** | `AudioExtractor` (Python ffmpeg wrapper) | **REPLACE** | Native Swift `AudioExtractionService` using structured `Process` execution. |
| **Speech Recognition (ASR)** | `MLXWhisperTranscriber` (Python mlx-whisper) | **REPLACE** | Modular `ASRProvider` protocol with `MLXWhisperASRProvider`, `AppleSpeechASRProvider`, and `DeterministicASRProvider`. |
| **Acoustic Diarization** | `AcousticDiarizer` (NumPy FFT / pitch autocorrelation) | **REPLACE** | Native Swift `AcousticDiarizer` implementing spectral centroid, RMS energy, and pitch autocorrelation directly in Swift. |
| **Semantic Translation** | `TranslationRouter` & Apple Intelligence bridge | **REPLACE** | Native Swift `TranslationRouter` directly importing `FoundationModels` (`SystemLanguageModel` / `LanguageModelSession`) with zero subprocesses. |
| **Hindi & Hinglish Adaptation** | `HinglishAdaptationEngine` & `HindiAdapter` | **REPLACE** | Native Swift `HinglishLocalizationService` and `HindiAdaptationService` porting all 150+ vocabulary rules, syllable compression, and loanword mixing. |
| **Speech Synthesis (TTS)** | `MacNativeSpeechProvider` (`/usr/bin/say` wrapper) | **REPLACE** | Native Swift `SpeechSynthesisProvider` utilizing `AVSpeechSynthesizer` and native macOS Indian voices (`Rishi`, `Lekha`, `Aman`, `Tara`). |
| **Timing & WSOLA** | `TimingEngine` (Python atempo wrapper) | **REPLACE** | Native Swift `DialogueTimingService` managing duration calculations, WSOLA time-stretch ratio limits (0.75x–1.30x). |
| **Audio Mixing** | `AudioMixer` (NumPy timeline + ffmpeg loudnorm) | **REPLACE** | Native Swift `AudioMixingService` combining timeline dialogue stems and applying EBU R128 loudness normalization (-23 LUFS). |
| **Subtitle Generation** | `SubtitleFormatter` (Python string templates) | **REPLACE** | Native Swift `SubtitleService` producing compliant SRT and stylized ASS subtitles with millisecond/centisecond precision. |
| **Video Rendering** | `VideoMuxer` (Python ffmpeg `-c:v copy`) | **REPLACE** | Native Swift `VideoRenderService` performing stream-copy remuxing into MP4 with AAC 256kbps audio. |
| **Automated QA** | `QAEngine` (Python 5-pillar validation) | **REPLACE** | Native Swift `QualityAssuranceService` executing full automated validation (Kanji leak check, Devanagari leak check, clipping, timing drift, voice diversity). |
| **State Persistence** | SQLite via SQLAlchemy | **REPLACE** | Native Swift `ProjectStore` using lightweight JSON file persistence / SwiftData in Application Support. |
| **External Codec Tools** | Homebrew / bundled `ffmpeg` & `ffprobe` | **REUSE** | Retain `ffmpeg` and `ffprobe` as explicitly managed native binary dependencies for universal multimedia container support. |

---

## 4. Dependency and Licensing Review

| Dependency / Tool | Role in Swift Architecture | License | Distribution & Integrity Strategy |
| :--- | :--- | :--- | :--- |
| **Swift Standard Library** | Core language runtime | Apache 2.0 with LLVM Exception | Bundled natively with macOS Darwin 27. |
| **SwiftUI & AppKit** | Native macOS interface | Apple Proprietary / System Framework | Bundled with macOS. Zero disk overhead. |
| **AVFoundation** | Media playback, inspection, audio handling | Apple Proprietary / System Framework | Bundled with macOS. Zero disk overhead. |
| **FoundationModels** | On-device Apple Intelligence LLM | Apple Proprietary / System Framework | Bundled with macOS 26+. Zero cloud dependency. |
| **FFmpeg / FFprobe** | Multimedia demuxing, atempo filter, loudnorm | LGPL v2.1+ / GPL v3 | Dynamically located via Homebrew (`/opt/homebrew/bin/ffmpeg`) or bundled in `Contents/MacOS/tools/`. |
| **MLX Whisper Models** | Local speech recognition models | MIT / Apache 2.0 | Cached locally in `~/.cache/huggingface/hub/` without cloud telemetry. |

---

## 5. Target Native Swift Architecture

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                       Anime Dub Studio (Native macOS)                       │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                     SwiftUI + AppKit Native Views                     │  │
│  │  • ProjectHomeView        • CreateDubSheet       • LiveProcessingView │  │
│  │  • DubbingEditorView      • ExportQualitySheet   • SettingsView       │  │
│  └──────────────────────────────────┬────────────────────────────────────┘  │
│                                     │ @EnvironmentObject / Observation       │
│  ┌──────────────────────────────────▼────────────────────────────────────┐  │
│  │                         AppState & ViewModels                         │  │
│  │  • AppState               • JobProgressViewModel • DubEditorViewModel │  │
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
│  │  • FFmpeg    ││  • Fallback ││    Fallback ││  • /say IN  ││  • EBU-R │  │
│  └──────────────┘└─────────────┘└─────────────┘└─────────────┘└──────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Migration Milestones & Verification Gates

### Milestone 1 — Repository Audit & Baseline Verification (Completed)
- Inspect existing Python, Tauri, Rust, React, and Swift components.
- Establish verified baseline: 16 Python unit tests pass, Apple Intelligence Foundation Models functional on device, sample media verified.
- Create `MIGRATION_PLAN.md`.

### Milestone 2 — Swift Package & Core Domain Architecture
- Scaffold standalone Swift Package / Xcode project: `AnimeDubStudio`.
- Define typed domain models: `Project`, `Episode`, `DialogueSegment`, `CharacterProfile`, `JobState`, `ProcessingStage`, `QAReport`.
- Implement `CheckpointStore` and `TypedError` hierarchies.

### Milestone 3 — Native Swift Media Pipeline Implementation
- Implement `MediaProbeService` and `AudioExtractionService` in Swift.
- Implement `AcousticDiarizer` in Swift with FFT spectral centroid and autocorrelation pitch estimation.
- Implement `HindiAdaptationService` and `HinglishLocalizationService` with full phonetic transliteration and loanword mixing.
- Implement `TranslationRouter` with direct `FoundationModels` integration.
- Implement `SpeechSynthesisProvider` with local Indian voices (`Rishi`, `Lekha`, `Aman`, `Tara`).
- Implement `DialogueTimingService`, `AudioMixingService`, `SubtitleService`, and `VideoRenderService`.
- Implement `QualityAssuranceService` with 5-pillar checks.

### Milestone 4 — Native SwiftUI Apple HIG User Interface
- Implement `StudioContentView` with macOS sidebar, toolbar, and content-first layout.
- Implement `ProjectHomeView` with recents, search, sorting, and empty states.
- Implement `CreateDubSheet` with native file drag-and-drop, video preview, audio track selector, and Hinglish preferences.
- Implement `LiveProcessingView` with real determinate progress, stage metrics, memory monitoring, pause/resume, and diagnostic logs.
- Implement `DubbingEditorView` with timeline, video preview, line-by-line editor, and line audio auditioning.
- Implement `ExportQualitySheet` with QA scorecard, codec details, and file export actions.

### Milestone 5 — Pipeline Integration & Automated Test Suite
- Port all Python unit test cases to Swift Testing (`@Test` / `XCTest`).
- Implement end-to-end media integration tests on `storage/generic_shonen_ep01.mkv` and `tests/test_data/sample.mp4`.
- Verify output video decodes cleanly, audio has zero clipping, and subtitles synchronize.

### Milestone 6 — Standalone Packaging & Release Verification
- Build native `.app` bundle: `Anime Dub Studio.app`.
- Package release disk image installer: `Anime Dub Studio.dmg`.
- Test launching artifact from outside development environment.
- Update project documentation (`README.md`, `ARCHITECTURE.md`, `PRODUCTION.md`, `TROUBLESHOOTING.md`).
