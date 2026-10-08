# Troubleshooting & Diagnostic Guide — Anime Dub Studio

This guide addresses common issues across audio extraction, MLX Whisper transcription, Apple Intelligence, Ollama, TTS synthesis, and video multiplexing.

---

## 1. Apple Intelligence Bridge Diagnostics

**Symptom:** `Apple Intelligence (FoundationModels): UNAVAILABLE` in status output.
* **Cause 1:** Device is not running macOS 26.0 or higher.
  - *Fix:* Ensure macOS is updated.
* **Cause 2:** Apple Intelligence is disabled in macOS System Settings.
  - *Fix:* Open **System Settings > Apple Intelligence & Siri** and confirm Apple Intelligence is turned ON.
* **Cause 3:** Bridge binary needs recompilation.
  - *Fix:* Run `swiftc -O scripts/apple_intelligence_bridge.swift -o bin/apple_intelligence_bridge`
* **Fallback Behavior:** The application automatically falls back to Ollama (`qwen3.5:4b`) or the deterministic dictionary with zero interruption.

---

## 2. Ollama Connection or Model Issues

**Symptom:** `Ollama request failed: connection refused`.
* **Fix:** Ensure Ollama is running:
  ```bash
  ollama serve
  ```
* **Symptom:** Ollama model missing:
  ```bash
  ollama pull qwen3.5:4b
  ```

---

## 3. Audio Extraction & FFmpeg Errors

**Symptom:** `ffprobe failed` or `ffmpeg not found`.
* **Fix:** Ensure FFmpeg is on your system PATH:
  ```bash
  which ffmpeg
  which ffprobe
  ```
  On macOS: `brew install ffmpeg`

---

## 4. Hindi Subtitle Display Issues in Video Players

**Symptom:** Devanagari characters appear disconnected or with square placeholder glyphs.
* **Fix:** Ensure your media player (e.g., VLC, IINA, mpv) uses a font supporting Devanagari (such as Arial, Noto Sans Devanagari, or Kohinoor Devanagari). The `.ass` subtitle generator embeds standard Arial styling by default.

---

## 5. TTS Rate & Clipping Warnings in QA Report

**Symptom:** QA Score flagged `Synthesized Hindi duration is >25% longer than target duration`.
* **Fix:**
  1. Open the Dubbing Editor.
  2. Shorten the Hindi translation text or choose a higher speed factor (e.g. 1.1x).
  3. Click **Preview Audio** to verify natural dialogue pacing before re-exporting.
