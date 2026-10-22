# System Architecture & Component Boundaries

Anime Dub Studio is structured as a clean, decoupled Swift 6 desktop application composed of two primary targets: `AnimeDubCore` and `AnimeDubStudio`.

---

## 1. High-Level Component Topology

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                       Anime Dub Studio (Native Swift 6)                     │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    SwiftUI + AppKit HIG Native Views                  │  │
│  │  • ProjectHomeView        • CreateDubSheet       • LiveProcessingView │  │
│  │  • DubbingEditorView      • FinishedVideoResult  • CharacterCastSheet │  │
│  └──────────────────────────────────┬────────────────────────────────────┘  │
│                                     │ @EnvironmentObject / Observation       │
│  ┌──────────────────────────────────▼────────────────────────────────────┐  │
│  │                         AppState & ViewModels                         │  │
│  │  • StudioViewModel       • DubbingEditorViewModel                     │  │
│  └──────────────────────────────────┬────────────────────────────────────┘  │
│                                     │ Structured Concurrency (async/await)   │
│  ┌──────────────────────────────────▼────────────────────────────────────┐  │
│  │                       Pipeline Orchestration Core                     │  │
│  │  • JobOrchestrator        • CheckpointStore      • ProjectStore       │  │
│  │  • CacheSignatureManager  • CapabilityRegistry   • QAValidator        │  │
│  └───────┬──────────────┬──────────────┬──────────────┬──────────────┬───┘  │
│          │              │              │              │              │      │
│  ┌───────▼──────┐┌──────▼──────┐┌──────▼──────┐┌──────▼──────┐┌──────▼───┐  │
│  │ MediaProbe & ││ ASRProvider ││ Translation ││ Speech      ││ Mixing & │  │
│  │ Extraction   ││  • Apple SF ││  • Apple FMs││ Synthesis   ││ Render   │  │
│  │  • AVAsset   ││  • MLX Whisp││  • Colloquial│  • Cast Map ││  • WSOLA │  │
│  │  • FFprobe   ││  • Utterance││    Hinglish ││  • Formant  ││  • EBU R │  │
│  │  • Slicing   ││    Grouping ││  • Script   ││    Shaping  ││  • Dual- │  │
│  │  • Ref Audio ││             ││    Sanitize ││  • Signatures││    Track│  │
│  └──────────────┘└─────────────┘└─────────────┘└─────────────┘└──────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Target Boundaries

### `AnimeDubCore` (Framework Target)
* **Domain Models:** `Project`, `Episode`, `DialogueSegment`, `CharacterProfile`, `DubOptions`, `ASRSegment`, `TranslationResult`.
* **Services & Orchestration:**
  - `JobOrchestrator`: Asynchronous 8-stage state machine driving dub execution.
  - `ProcessRunner`: Asynchronous, deadlock-safe subprocess pipe consumption with cancellation handlers.
  - `ProjectStore`: Thread-safe JSON persistence with reader-writer synchronization.
  - `CheckpointStore`: Atomic disk checkpointing for resilient crash recovery.
  - `SpeechSynthesisProvider`: Native macOS Indian cast voice synthesis with formant shaping and truthful capability reporting.
  - `AudioMixerService`: Sidechain BGM ducking and two-pass EBU R128 loudness normalization.
  - `VideoRendererService`: Stream-copy remuxing (`-c:v copy`).
  - `QualityAssuranceService`: 5-pillar technical compliance scoring.

### `AnimeDubStudio` (AppKit & SwiftUI Application Target)
* **State & ViewModels:**
  - `StudioViewModel`: High-level application state, active projects, and pipeline progress events.
  - `DubbingEditorViewModel`: Project re-editability, timeline scrubbing, segment updates, and cache invalidation.
* **Views:**
  - `ProjectHomeView`: Project gallery, disk space overview, and new project launcher.
  - `LiveProcessingView`: Live 8-stage progress tracker with elapsed time and cancellation controls.
  - `DubbingEditorView`: Timeline waveform editor, per-segment text editing, and character cast assignment.
  - `FinishedVideoResultView`: AVPlayer preview, dual-track A/B audio switcher, technical grid, QA scorecard, and export actions.

---

## 3. Concurrency & Safety Principles

1. **Approachable Concurrency:** Built with Swift 6 structured concurrency (`async/await`, `actor`, `Sendable`).
2. **Subprocess Pipe Deadlock Immunity:** Standard output and error streams are read via asynchronous GCD `readabilityHandler` callbacks protected by recursive locks, preventing pipe deadlocks on outputs $> 64\text{ KB}$.
3. **Subsecond Cancellation:** Wrapped subprocesses register cancellation handlers via `withTaskCancellationHandler` to immediately dispatch `SIGTERM` signals upon user cancel.
4. **Shell Injection Prevention:** Raw shell string execution (`/bin/sh -c`) is strictly forbidden; all system utilities are invoked via typed argument arrays (`[String]`).
