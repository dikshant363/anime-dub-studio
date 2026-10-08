# DEPENDENCY MATRIX — ANIME DUB STUDIO
**Milestone 0 Research & Compatibility Matrix**

This document details all third-party software, libraries, AI models, and command-line utilities across the local Apple Silicon M4 environment and the Google Colab CUDA environment.

---

## 1. System & Binary Tools

| Tool | Required Version | Target Hardware | Purpose | License | Host Status |
|---|---|---|---|---|---|
| **FFmpeg** | 6.0+ (with libmp3lame, libx264, libass) | Universal | Video/audio extraction, time-stretch filters, loudness normalization, muxing | LGPL-2.1+ | **Installed** (`/opt/homebrew/bin/ffmpeg`) |
| **FFprobe** | Matching FFmpeg | Universal | Media container and codec metadata inspection | LGPL-2.1+ | **Installed** (`/opt/homebrew/bin/ffprobe`) |
| **Ollama** | 0.3.0+ | M4 Local / Linux | Local LLM server hosting Qwen and Gemma models | MIT | **Installed & Running** (`qwen3.5:4b`, `gemma4:e2b`) |
| **Swift Toolchain** | Swift 6.0+ | Apple Silicon M4 | macOS `FoundationModels` bridge for Apple Intelligence | Apache-2.0 | **Installed** (Swift 6.4 Apple Swift) |
| **Node.js** | 20.0+ | Universal | Next.js 15 frontend runtime | MIT | **Installed** (v22.23.2) |
| **pnpm** | 9.0+ | Universal | High-speed frontend package manager | MIT | **Installed** (v9.x) |
| **Python** | 3.11 - 3.12 | Universal | Core backend, AI pipeline, CLI | PSF | **Installed** (Python 3.12.14) |
| **uv** | 0.4+ | Universal | Ultra-fast Python package and venv manager | Apache-2.0 / MIT | **Installed** (`/opt/homebrew/bin/uv`) |

---

## 2. Python Backend & ML Libraries

| Library | Version | Hardware Target | Purpose | Fallback Provider | Status |
|---|---|---|---|---|---|
| **fastapi** | >=0.115.0 | Universal | REST API & WebSocket endpoints | N/A | Active in venv |
| **uvicorn** | >=0.30.0 | Universal | ASGI web server | N/A | Active in venv |
| **pydantic** | >=2.9.0 | Universal | Strict schema validation and typed settings | N/A | Active in venv |
| **aiosqlite** | >=0.20.0 | Universal | Async SQLite database driver | SQLite synchronous | Active in venv |
| **sqlalchemy** | >=2.0.0 | Universal | Project and episode persistence ORM | SQLite raw SQL | Active in venv |
| **edge-tts** | >=6.1.18 | Universal | High-quality neural Hindi TTS streams | Piper TTS | Active in venv |
| **mlx-whisper** | >=0.4.0 | Apple Silicon M4 | Metal-accelerated speech recognition | faster-whisper | Compatible |
| **faster-whisper** | >=1.0.0 | Colab CUDA / CPU | CTranslate2 Whisper engine | mlx-whisper | Universal |
| **soundfile** | >=0.12.1 | Universal | High-fidelity audio I/O | wave / scipy | Active in venv |
| **librosa** | >=0.10.2 | Universal | Audio analysis, VAD feature extraction | scipy.signal | Active in venv |
| **numpy** | >=1.26.0 | Universal | Signal processing & array math | Pure Python math | Active in venv |
| **httpx** | >=0.27.0 | Universal | Async HTTP client for Ollama & Colab worker | aiohttp | Active in venv |
| **pytest** | >=8.0.0 | Universal | Unit and integration test suite | unittest | Active in venv |

---

## 3. AI Models & Checkpoints

| Model ID | Provider | Parameter Size | Memory Footprint | Primary Hardware | Localization Role |
|---|---|---|---|---|---|
| **`qwen3.5:4b`** | Ollama | 4.2B (Q4_K_M) | ~3.3 GB Unified RAM | M4 Apple Silicon | Japanese-to-Hindi translation & cultural adaptation |
| **`gemma4:e2b`** | Ollama | 4.6B (Q4_K_M) | ~4.6 GB Unified RAM | M4 Apple Silicon | Alternative Hindi adaptation & QA evaluation |
| **`SystemLanguageModel`** | Apple Intelligence | System Native | On-device Neural Engine | macOS 26+ Apple Silicon | Zero-RAM on-device translation & text compression |
| **`whisper-large-v3-turbo`** | MLX / HuggingFace | 800M (FP16) | ~1.6 GB Unified RAM | M4 Apple Silicon | Japanese dialogue transcription with timestamps |
| **`whisper-large-v3`** | faster-whisper | 1.5B (INT8) | ~3.0 GB VRAM | Google Colab CUDA | High-accuracy batched Japanese ASR |
| **`hi-IN-SwaraNeural`** | Edge-TTS | Cloud Neural | 0 MB Local | Universal | Female Hindi anime character voice |
| **`hi-IN-MadhurNeural`** | Edge-TTS | Cloud Neural | 0 MB Local | Universal | Male Hindi anime character voice |
| **`hi_IN-rohan-medium`** | Piper TTS | ONNX Neural | ~65 MB Local | CPU / M4 / Offline | 100% offline male Hindi anime voice |
| **`hi_IN-priyamvada-medium`** | Piper TTS | ONNX Neural | ~65 MB Local | CPU / M4 / Offline | 100% offline female Hindi anime voice |
| **`htdemucs`** | Demucs-MLX / Demucs | 4-stem U-Net | ~800 MB | M4 Metal / CUDA | Speech vs BGM/SFX audio separation |

---

## 4. Frontend Architecture (Next.js & React)

| Package | Version | Purpose |
|---|---|---|
| **next** | ^15.0.0 | Server-side rendering, routing, static optimization |
| **react** / **react-dom** | ^19.0.0 | Interactive component tree and waveform canvas |
| **tailwindcss** | ^4.0.0 | Apple-inspired minimal dark/light design system |
| **lucide-react** | ^0.450.0 | Modern SVG iconography |
| **wavesurfer.js** | ^7.8.0 | Interactive audio waveform preview and region selection |

---
*Matrix validated against active Apple M4 16GB host configuration.*
