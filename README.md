# Anime Dub Studio
> **Local-first AI workstation for creating natural Hindi anime dubs on Apple Silicon & Google Colab.**

Anime Dub Studio is a production-grade, local-first application designed to transcribe Japanese anime dialogue, identify characters, localize the script into natural, colloquial spoken Hindi, synthesize authentic character voices, synchronize dialogue pacing, master the soundtrack with BGM preservation, and export high-definition dubbed video without cloud subscription fees.

---

## Key Features

* **🇯🇵 Japanese → 🇮🇳 Natural Hindi Dubbing:** First-class anime localization engine preserving character personality, emotion, and anime honorifics (avoiding literal, bookish translations).
* **🍎 Apple Silicon M4 Native:** Accelerated by Apple MLX Metal GPU for speech recognition, on-device Apple Intelligence Foundation Models via the Apple Neural Engine, and zero-RAM overhead execution.
* **☁️ Optional Google Colab Worker:** Offload intensive batch processing or long episodes to NVIDIA CUDA GPUs (T4 / L4 / A100) with adaptive VRAM model selection.
* **🎙 Neural Character Voice Engine:** High-fidelity Hindi character voices with pitch, speed, and emotion conditioning using EdgeTTS and offline Piper ONNX runtimes.
* **⏱ Automated Timing & WSOLA Sync:** Intelligently measures synthesized duration against target video windows, applying WSOLA time-stretching (`atempo`) and Hindi syllable contraction to avoid robotic speech.
* **🎚 Lossless Video Multiplexing & BGM Ducking:** Masters dubbed audio with EBU R128 loudness normalization (-23 LUFS), background music ducking, and remuxes video bitstreams (`-c:v copy`) with zero video quality loss.
* **🔍 Automated Quality Assurance (QA):** Automatically scans outputs for untranslated characters, missing speech files, digital clipping, and timing drift, generating studio readiness scores (0-100).
* **🖥 Modern Studio UI:** Focused Apple-inspired "Create a Dub" modal, persistent real-time job progress monitor, and a multi-track Dubbing Editor.

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

### 3. Start the Web Studio UI

**Terminal 1 — Backend:**
```bash
.venv/bin/uvicorn backend.app.main:app --host 127.0.0.1 --port 8000 --reload
```

**Terminal 2 — Frontend:**
```bash
cd frontend
pnpm install --ignore-scripts
pnpm dev
```
Open [http://localhost:3000](http://localhost:3000) in your browser.

---

## Project Documentation

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
