# Model Catalog & License Specifications — Anime Dub Studio

This document defines all supported models, their licensing terms, hardware requirements, and intended roles in Anime Dub Studio.

---

## 1. Speech Recognition (ASR)

### `whisper-tiny-mlx` / `whisper-large-v3-turbo`
* **Provider:** MLX Community / OpenAI
* **License:** MIT
* **Parameters:** 39M (tiny) / 800M (large-v3-turbo)
* **Weights Size:** ~74 MB (tiny) / ~1.6 GB (large-v3-turbo)
* **Execution:** Metal GPU on Apple Silicon via `mlx-whisper`
* **Commercial Restrictions:** None (MIT permissive)

### `faster-whisper` (`whisper-large-v3`)
* **Provider:** SYSTRAN / OpenAI
* **License:** MIT
* **Parameters:** 1.5B (INT8 quantization)
* **Execution:** CTranslate2 on NVIDIA CUDA / Google Colab
* **Commercial Restrictions:** None (MIT permissive)

---

## 2. Translation & Hindi Localization

### `SystemLanguageModel` (Apple Intelligence)
* **Provider:** Apple Inc.
* **License:** macOS Software License Agreement
* **Execution:** Apple Neural Engine on macOS 26+
* **Capabilities:** Multilingual translation, natural Hindi Devanagari localization, context-aware prompt adaptation
* **Privacy:** Strictly on-device; zero network transmission

### `qwen3.5:4b`
* **Provider:** Alibaba Cloud / Qwen Team
* **License:** Apache-2.0
* **Parameters:** 4.2B (Q4_K_M GGUF)
* **Weights Size:** ~3.3 GB
* **Execution:** Ollama local server on Apple Silicon / CPU
* **Capabilities:** High reasoning capability, anime cultural localization, Devanagari generation

---

## 3. Speech Synthesis (TTS)

### `EdgeTTS Neural` (`hi-IN-MadhurNeural`, `hi-IN-SwaraNeural`)
* **Provider:** Microsoft Edge Neural Services
* **License:** Microsoft Terms of Service / Client Protocol (Personal / Experimental)
* **Format:** 24kHz High-Fidelity Audio
* **Capabilities:** Pitch adjustment (±50Hz), speech rate adjustment (±50%), natural Indian anime prosody

### `Piper TTS` (`hi_IN-rohan-medium`, `hi_IN-priyamvada-medium`)
* **Provider:** Rhasspy / Open Home Foundation
* **License:** MIT / GPL-3.0
* **Format:** ONNX runtime local inference
* **Capabilities:** 100% offline, air-gapped CPU inference, zero cloud dependency

---

## 4. Audio Separation

### `Demucs-MLX` / `HTDemucs`
* **Provider:** Meta Research / MLX Port
* **License:** MIT
* **Parameters:** 4-stem Hybrid Transformer
* **Execution:** Metal GPU kernels on Apple Silicon M4 / PyTorch CUDA on Colab
* **Capabilities:** Isolates clean speech vocals from background anime soundtrack and battle sound effects
