# Anime Dub Studio v1.0
> **Native Apple Silicon macOS Application for Local-First Japanese Anime & Video → Hindi/Hinglish Dubbing.**

Anime Dub Studio is a production-grade macOS desktop application designed to transcribe Japanese anime dialogue, cluster and assign characters, localize the script into natural colloquial spoken Hindi or Hinglish, synthesize authentic character voices on-device, synchronize dialogue pacing, master the soundtrack with BGM preservation, and export high-definition dubbed video without cloud subscription fees.

Packaged as a standalone macOS `.app` and `.dmg`, it requires no manual terminal startup, no uvicorn, and no dev servers.

---

## Key Features

* **🖥 Standalone macOS Desktop Application:** Tauri 2 (Rust) + React 19 + TypeScript + Swift native bridge packaged into `Anime Dub Studio.app` and `.dmg` installer with official app icon.
* **🇯🇵 Japanese → 🇮🇳 Hindi & Hinglish Dubbing:** First-class anime localization engine preserving character personality, emotion, and anime honorifics in Devanagari Hindi or Latin Roman Hinglish (e.g. *"Tum kya kar rahe ho?"*).
* **🔒 100% Local-First by Default:** On-device speech synthesis using `MacNativeSpeechProvider` (`/usr/bin/say` Indian voices `Rishi`, `Lekha`, `Aman`, `Tara`) operates entirely offline with zero network API dependency.
* **🌐 Transparent Cloud Option:** Optional Microsoft Edge TTS is strictly labeled `ONLINE / CLOUD FALLBACK • Requires Internet`.
* **👥 Multi-Character Cast Voice Diversity:** Automatically assigns distinct voice profiles across cast members (e.g. `Lead Protagonist`, `Lead Heroine`, `Supporting Male`, `Supporting Female`); QA fails if cast voices collapse into a single voice.
* **⏱ Automated Timing & WSOLA Sync:** Intelligently measures synthesized duration against target video windows, applying WSOLA time-stretching (`atempo`) and syllable contraction to avoid robotic speech.
* **🎚 Lossless Video Multiplexing (`-c:v copy`):** Masters dubbed audio with EBU R128 loudness normalization (-23 LUFS), background music ducking, and remuxes video bitstreams losslessly with zero generational loss.
* **💾 Checkpoint & Resilient Recovery:** Saves stage checkpoints on disk; UI supports clean `[ Pause ]`, `[ Resume ]`, `[ Cancel ]`, and `[ Retry from checkpoint ]`.
* **🔍 Automated Quality Assurance (QA):** Automatically scans outputs for untranslated characters, digital clipping, timing drift, and voice diversity.


---

## Architecture Overview

```text
                     Anime Dub Studio Workspace
                                 │
                   Next.js 15+ Frontend (React, Tailwind)
                                 │
                     FastAPI REST & WebSocket API
                                 │
                     Job Scheduler & State Machine
                                 │
              ┌──────────────────┴──────────────────┐
              │                                     │
      Local M4 Worker                        Colab Worker
    (MLX, Metal, Ollama)                    (CUDA, PyTorch)
              │                                     │
              └──────────────────┬──────────────────┘
                                 │
                         DUBBING PIPELINE
                                 │
   ┌──────────────┬──────────────┼──────────────┬──────────────┐
   ▼              ▼              ▼              ▼              ▼
Ingestion   Separation         ASR         Diarization    Translation
 (FFmpeg)   (Demucs-MLX)   (MLX-Whisper)  (PyAnnote/VAD)  (Apple/Ollama)
                                                               │
                                                               ▼
                                                       Hindi Adaptation
                                                               │
                                                               ▼
                                                       Character Voices
                                                         (Edge/Piper)
                                                               │
                                                               ▼
                                                         Timing Sync
                                                         (WSOLA/atempo)
                                                               │
                                                               ▼
                                                       Mixer & Ducking
                                                       (Loudnorm EBU)
                                                               │
                                                               ▼
                                                       Automated QA
                                                               │
                                                               ▼
                                                         Render & Mux
                                                       (Final Dub MP4)
```

---

## Quickstart Guide

### 1. Requirements
* macOS (Apple Silicon M-series recommended) or Linux
* FFmpeg (`brew install ffmpeg`)
* Python 3.11+ with `uv` (`brew install uv`)
* Node.js v20+ with `pnpm` (`npm install -g pnpm`)

### 2. Run the One-Command Demo

```bash
# 1. Create Python virtual environment and install backend
uv venv .venv --python 3.12
source .venv/bin/activate
uv pip install fastapi "uvicorn[standard]" pydantic pydantic-settings sqlalchemy aiosqlite edge-tts soundfile librosa numpy httpx pytest python-multipart psutil greenlet pytest-asyncio mlx-whisper

# 2. Compile Apple Intelligence native bridge (macOS 26+)
swiftc -O scripts/apple_intelligence_bridge.swift -o bin/apple_intelligence_bridge

# 3. Check hardware & provider status
.venv/bin/python cli/anime_dub.py status

# 4. Generate a synthetic test video clip
.venv/bin/python scripts/generate_synthetic_sample.py

# 5. Run the complete end-to-end dubbing demo
.venv/bin/python cli/anime_dub.py demo ./tests/test_data/sample.mp4 --target hi
```

The dubbed video and Hindi subtitles will be generated in:
`storage/projects/<project_id>/episodes/<episode_id>/export/sample_hindi_dub.mp4`

---

### 3. Launch Native macOS Desktop Studio (Tauri 2 + Swift + Rust)

To run Anime Dub Studio as a real native macOS desktop application:

```bash
# 1. Install root & frontend dependencies
pnpm install

# 2. Run Desktop App in development mode
pnpm tauri dev

# 3. Build standalone macOS .app bundle and .dmg installer
npx tauri build --debug
```

The compiled native macOS application and installer will be located in:
* **Application Bundle:** `src-tauri/target/debug/bundle/macos/Anime Dub Studio.app`
* **Disk Image Installer:** `src-tauri/target/debug/bundle/dmg/Anime Dub Studio_1.0.0_aarch64.dmg`

---

### 4. Start the Web Studio UI (Optional localhost mode)

**Terminal 1 — Backend:**
```bash
.venv/bin/uvicorn backend.app.main:app --host 127.0.0.1 --port 8000 --reload
```

**Terminal 2 — Frontend:**
```bash
pnpm --dir frontend dev
```
Open [http://localhost:3000](http://localhost:3000) in your browser.

---

## Project Documentation

* [macOS Native Desktop Studio Architecture](docs/MACOS_DESKTOP.md)
* [Reuse Audit (Existing Open-Source Research)](docs/REUSE_AUDIT.md)
* [System Architecture Specification](docs/ARCHITECTURE.md)
* [Dependency & Compatibility Matrix](docs/DEPENDENCY_MATRIX.md)
* [Setup & Installation Guide](docs/SETUP.md)
* [Apple Silicon M4 Guide](docs/M4_SETUP.md)
* [Google Colab Setup & GPU Offloading](docs/COLAB_SETUP.md)
* [Model Catalog & Licenses](docs/MODELS.md)
* [Troubleshooting & Diagnostics](docs/TROUBLESHOOTING.md)
* [Final Status Report](docs/FINAL_STATUS.md)
* [M4 Benchmark Results](benchmarks/m4/RESULTS.md)

---

## License

This project is licensed under the MIT License. Models used adhere to their respective licenses detailed in [docs/MODELS.md](docs/MODELS.md).
