# DEAD-CODE ELIMINATION & ARCHITECTURAL PURGE AUDIT
## Anime Dub Studio v2.0 Native macOS Transformation

**Date:** 2026-10-23  
**Status:** COMPLETE & VERIFIED  
**Auditor:** Principal macOS & Swift Systems Engineer

---

### 1. Executive Summary

During the transition from the legacy composite architecture (Tauri 2 / Rust + Next.js 15 / React 19 + Python 3.12 / FastAPI + auxiliary shell subprocesses) to the standalone native Swift 6.4 macOS desktop application, a comprehensive dead-code audit was conducted across the entire repository.

Over **8.4 GB** of dead code, obsolete virtual environments, compiled Rust and WebKit build artifacts, legacy Python servers, duplicate models, and retired scripts were safely purged from the repository. The application logic is now 100% contained within the native Swift packages [`AnimeDubCore`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/) and [`AnimeDubStudio`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubStudio/).

---

### 2. Comprehensive Inventory of Eliminated Dead Code

#### A. Legacy Python Backend (`backend/`) — 340 KB (Purged)
- **API Routers:** `routes_characters.py`, `routes_dub.py`, `routes_episodes.py`, `routes_jobs.py`, `routes_projects.py`, `routes_system.py`.
- **Pipeline Submodules:**
  - `ingestion/probe.py` & `ingestion/extractor.py` (replaced by [`MediaProbeService.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/MediaProbeService.swift) and [`AudioExtractionService.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/AudioExtractionService.swift)).
  - `asr/base.py` & `asr/mlx_whisper.py` (replaced by [`ASRProvider.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/ASRProvider.swift)).
  - `diarization/acoustic_diarizer.py` (replaced by [`AcousticDiarizer.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/AcousticDiarizer.swift)).
  - `adaptation/hindi_adapter.py` & `adaptation/hinglish_adapter.py` (replaced by [`HindiAdaptationService.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/HindiAdaptationService.swift) and [`HinglishLocalizationService.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/HinglishLocalizationService.swift)).
  - `translation/router.py`, `translation/apple_intelligence.py`, `translation/ollama.py` (replaced by [`TranslationRouter.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/TranslationRouter.swift)).
  - `tts/mac_speech.py`, `tts/edge_tts.py`, `tts/tone_fallback.py` (replaced by [`SpeechSynthesisProvider.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/SpeechSynthesisProvider.swift)).
  - `timing/engine.py` (replaced by [`DialogueTimingService.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/DialogueTimingService.swift)).
  - `mixing/mixer.py` (replaced by [`AudioMixingService.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/AudioMixingService.swift)).
  - `subtitles/formatter.py` (replaced by [`SubtitleService.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/SubtitleService.swift)).
  - `render/video_muxer.py` (replaced by [`VideoRenderService.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/VideoRenderService.swift)).
  - `qa/engine.py` (replaced by [`QualityAssuranceService.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/QualityAssuranceService.swift)).
  - `orchestrator.py` & `runner_cli.py` (replaced by [`JobOrchestrator.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/JobOrchestrator.swift)).
- **Domain & DB Models:** `database.py`, `config.py`, `models/`, `schemas/` (replaced by Swift Codable structs in [`Sources/AnimeDubCore/Models/`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Models/)).

#### B. Legacy Next.js / React 19 Frontend (`frontend/`) — 376 MB (Purged)
- `frontend/src/app/` (`layout.tsx`, `page.tsx`, `globals.css`).
- `frontend/src/components/` (`CreateDubModal.tsx`, `DubbingEditor.tsx`, `JobProgressView.tsx`).
- `frontend/src/lib/tauriBridge.ts`.
- `frontend/node_modules/`, `frontend/.next/`, `frontend/package.json`, `frontend/pnpm-lock.yaml`, `frontend/tsconfig.json`, `frontend/tailwind.config.js`.
- **Reason:** Fully replaced by native SwiftUI views in [`Sources/AnimeDubStudio/Views/`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubStudio/Views/).

#### C. Legacy Tauri 2 / Rust Desktop Shell (`src-tauri/`) — 6.9 GB (Purged)
- `src-tauri/src/` (`main.rs`, `lib.rs`, `commands.rs`, `job_manager.rs`, `media_probe.rs`, `pipeline_runner.rs`, `swift_bridge.rs`, `system_info.rs`, `ai_router.rs`).
- `src-tauri/target/` (massive compiled Rust intermediate and final artifacts).
- `src-tauri/Cargo.toml`, `src-tauri/Cargo.lock`, `src-tauri/tauri.conf.json`, `src-tauri/build.rs`, `src-tauri/capabilities/`.
- `src-tauri/swift/AppleFoundationModelService.swift` (superseded by in-process `TranslationRouter.swift`).
- **Reason:** Fully replaced by native SwiftUI/AppKit desktop executable [`AnimeDubStudioApp.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubStudio/AnimeDubStudioApp.swift).

#### D. Standalone Legacy CLI & Workers — 120 KB (Purged)
- `cli/anime_dub.py` (old python CLI).
- `bin/apple_intelligence_bridge` (precompiled Mach-O binary from early Apple Intelligence experiments).
- `workers/colab/worker.py` (abandoned remote colab worker).
- `notebooks/anime_dub_colab.ipynb` (experimental prototype notebook).
- `benchmarks/m4/benchmark_runner.py`, `benchmarks/m4/results.json`, `benchmarks/m4/RESULTS.md` (legacy Python benchmark suite).

#### E. Root Web Workspace & Virtualenv — 1.12 GB (Purged)
- `package.json`, `pnpm-lock.yaml`, `node_modules/` (root Node workspace files).
- `.venv/` (1.1 GB Python virtualenv).
- `.pytest_cache/` (temporary test cache).

#### F. Retired Legacy Python Tests (`tests/unit/`, `tests/integration/`) (Purged)
- `tests/unit/test_hindi_adapter.py`, `test_hinglish_adapter.py`, `test_qa.py`, `test_timing.py`, `test_translation.py`.
- `tests/integration/test_pipeline_e2e.py`.
- **Reason:** Fully replaced by 23 native Swift unit and integration tests in [`tests/AnimeDubCoreTests/`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/tests/AnimeDubCoreTests/).

#### G. Superseded Shell & Python Scripts (`scripts/`) (Purged)
- `scripts/package_app.sh` (old Tauri packaging script).
- `scripts/run_full_episode.py` (old hardcoded Python runner).
- `scripts/test_user_video_hinglish.py` (old test script).
- `scripts/apple_intelligence_bridge.swift` (superseded by `TranslationRouter.swift`).
- `scripts/check_apple_intelligence.swift` (superseded by `ModelCapabilityRegistry.swift`).
- `scripts/test_apple_intelligence_session.swift` (superseded by in-process router).
- `scripts/generate_synthetic_sample.py` (superseded by real media fixtures).

---

### 3. Consolidated Implementations & Eliminated Duplications

| Capability | Previous Redundant Implementations | Consolidated Native Implementation |
| :--- | :--- | :--- |
| **Media Probing** | 3 separate probes: Python `probe.py`, Rust `media_probe.rs`, and shell `ffprobe` script. | [`MediaProbeService.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/MediaProbeService.swift) combining AVFoundation `AVURLAsset` with structured JSON `ffprobe`. |
| **Translation** | 4 separate paths: `apple_intelligence.py` via subprocess, `router.py`, `ollama.py`, and standalone binary `bin/apple_intelligence_bridge`. | In-process [`TranslationRouter.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/TranslationRouter.swift) directly importing `FoundationModels` framework on macOS 26+, with deterministic offline fallback. |
| **Speech Synthesis** | 3 engines: `mac_speech.py` calling `/usr/bin/say`, `edge_tts.py` requiring cloud Python package, and `tone_fallback.py`. | Consolidated [`SpeechSynthesisProvider.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/SpeechSynthesisProvider.swift) utilizing native macOS Indian cast voices (`Rishi`, `Lekha`, `Aman`, `Tara`). |
| **Subprocess Execution** | Ad-hoc `subprocess.run` with string interpolation across 10 Python files and Rust `Command::new`. | Thread-safe, non-interpolating, cancellation-aware [`ProcessRunner.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/ProcessRunner.swift). |
| **Pipeline Management** | FastAPI background tasks in Python with transient in-memory dictionaries. | [`JobOrchestrator.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/JobOrchestrator.swift) with atomic JSON persistence via [`CheckpointStore.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/CheckpointStore.swift). |

---

### 4. Retained External Dependencies & Justifications

Only mature multimedia tools with clear justifications were retained:
1. **FFmpeg / FFprobe:**
   - **Justification:** Essential for parsing arbitrary anime containers (MKV with PGS/SSA/ASS subtitles, multi-audio tracks), WSOLA phase-aligned audio time stretching (`atempo`), sidechain loudness mastering (`loudnorm`), and stream-copy video multiplexing (`-c:v copy`). Rewriting these in pure Swift would reinvent hundreds of thousands of lines of C codecs.
   - **Execution Safety:** Invoked via argument arrays in `ProcessRunner` without shell interpolation.
2. **/usr/bin/say:**
   - **Justification:** Built-in macOS speech synthesizer providing on-device Indian English and Hindi voices (`Rishi`, `Lekha`) with zero network access and zero third-party licensing fees.

---

### 5. Verification After Purge

Following the elimination of all dead code:
- **Build Status:** `swift build -Xswiftc -warnings-as-errors` passed with **0 errors and 0 warnings**.
- **Automated Tests:** `swift test` passed **23 of 23 tests across 6 suites in 8.022 seconds**.
- **Packaging:** Standalone `dist/Anime Dub Studio.app` (**5.3 MB**) and `dist/Anime Dub Studio.dmg` (**3.4 MB**) successfully built and verified.
