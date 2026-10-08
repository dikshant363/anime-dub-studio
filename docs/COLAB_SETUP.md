# Google Colab Setup & CUDA Offloading Guide

This guide describes how to run Anime Dub Studio on **Google Colab** with NVIDIA CUDA acceleration.

---

## 1. When to Use Google Colab

Use the Google Colab worker when:
1. You are running on a non-Mac or low-memory CPU workstation.
2. You want to batch-transcribe full-season episodes with `whisper-large-v3`.
3. You want to offload heavy 4-stem Demucs stem separation to dedicated GPU VRAM.

---

## 2. Using the Colab Notebook

1. Open Google Colab: [https://colab.research.google.com](https://colab.research.google.com)
2. Upload the notebook from this repository:
   `notebooks/anime_dub_colab.ipynb`
3. In Colab, navigate to **Runtime > Change runtime type** and select:
   - **Hardware accelerator:** T4 GPU, L4 GPU, or A100 GPU
4. Run the notebook cells sequentially:
   - **Step 1:** Verifies CUDA availability and detects VRAM.
   - **Step 2:** Installs FFmpeg, `faster-whisper`, `edge-tts`, and audio libraries.
   - **Step 3:** Uploads your media file.
   - **Step 4:** Executes Whisper transcription with word timestamps.
   - **Step 5:** Adapts Japanese dialogue into natural Hindi.
   - **Step 6:** Synthesizes Hindi neural character speech.
   - **Step 7:** Mixes soundtrack and exports final dubbed MP4.

---

## 3. GPU VRAM Adaptation Matrix

The Colab worker automatically sizes models to match the detected NVIDIA GPU:

| Detected GPU | VRAM | Selected Whisper Model | Recommended Batch Size |
|---|---|---|---|
| **NVIDIA A100** | 40 GB / 80 GB | `large-v3` | 16 |
| **NVIDIA L4** | 24 GB | `large-v3` | 8 |
| **NVIDIA T4** | 15 GB / 16 GB | `medium` | 4 |
| **CPU Fallback** | N/A | `tiny` | 1 |
