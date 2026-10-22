# Anime Dub Studio — Troubleshooting Guide v2.0
**Platform:** macOS Apple Silicon (arm64)
**Architecture:** Native Swift 6.4 + SwiftUI Application

This guide provides solutions and diagnostics for common questions and potential failure scenarios when running the native Anime Dub Studio application.

---

## 1. Speech Synthesis & Offline Voices

### Issue: "Local speech provider says voice not found"
- **Cause:** The requested Indian voice (`Lekha`, `Rishi`, `Aman`, or `Tara`) is not downloaded or enabled in macOS system speech synthesizer.
- **Resolution:**
  1. Open macOS **System Settings** > **Accessibility** > **Spoken Content**.
  2. Click **System Voice** > **Manage Voices...**.
  3. Search for:
     - `Hindi` > Download **Lekha** (or **Lekha (Enhanced)**)
     - `English (India)` > Download **Rishi**, **Aman**, or **Tara**
  4. Verify installed voices in terminal:
     ```bash
     say -v '?' | grep -E "hi_IN|en_IN"
     ```

### Issue: "Why is Microsoft Edge TTS marked ONLINE?"
- **Answer:** Anime Dub Studio is local-first by design. Edge TTS requires an active internet connection to contact cloud neural synthesis servers. If selected, the app transparently marks the engine as `ONLINE / CLOUD FALLBACK • Requires Internet`. For 100% offline operation, select **On-Device macOS Speech**.

---

## 2. Apple Intelligence & Foundation Models

### Issue: "Apple Intelligence indicates Unavailable"
- **Cause:** Apple Intelligence is disabled in macOS System Settings or the device is running a build prior to macOS 26.
- **Resolution:**
  1. Go to **System Settings** > **Apple Intelligence & Siri**.
  2. Verify that Apple Intelligence is toggled ON and model download is complete.
  3. If unavailable, Anime Dub Studio automatically engages its offline deterministic translation fallback with zero configuration needed.

---

## 3. Media Probing & Audio Tracks

### Issue: "Audio stream is not Japanese by default in Dual-Audio MKVs"
- **Behavior:** The native `MediaProbeService` automatically parses metadata tags (`language`, `title`) across all audio tracks using `ffprobe`. If an audio stream is tagged `jpn`, `ja`, or contains `Japanese`, Anime Dub Studio auto-selects it.
- **Resolution:**
  - In the **Create a Dub** sheet, inspect the **Dialogue Audio Track** picker.
  - All probed streams are clearly listed with index, channels, sample rate, and codec (e.g. `Stream #0:1 [JPN] OPUS Stereo`).
  - Select the Japanese track explicitly before clicking **Start Dubbing**.

---

## 4. Subprocess & Multimedia Dependencies

### Issue: "FFmpeg or FFprobe not found"
- **Behavior:** Anime Dub Studio dynamically searches:
  - `/opt/homebrew/bin/ffmpeg`
  - `/usr/local/bin/ffmpeg`
  - `/usr/bin/ffmpeg`
  - Bundled tools inside `Anime Dub Studio.app/Contents/MacOS/tools/`
- **Resolution:**
  - Install FFmpeg via Homebrew:
    ```bash
    brew install ffmpeg
    ```

---

## 5. Checkpoints & Resuming Interrupted Jobs

### Issue: "Job paused or cancelled mid-episode"
- **Behavior:** Every stage of the dubbing workflow writes atomic JSON checkpoints to:
  `~/Library/Application Support/Anime Dub Studio/projects/<project_id>/episodes/<episode_id>/checkpoints/`
  - `checkpoint_extraction.json`
  - `checkpoint_asr.json`
  - `checkpoint_diarization.json`
  - `checkpoint_translations.json`
  - `voices/seg_*.wav`
- **Resolution:**
  - On the **Live Processing** screen, click **Resume**.
  - The orchestrator automatically loads existing completed segments and resumes without recomputing prior stages.
