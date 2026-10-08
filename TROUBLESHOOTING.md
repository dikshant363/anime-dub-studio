# Anime Dub Studio — Troubleshooting Guide v1.0

This guide provides solutions and diagnostics for common questions and potential failure scenarios when running Anime Dub Studio on macOS.

---

## 1. Speech Synthesis & Voices

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
- **Answer:** Anime Dub Studio is local-first by design. Edge TTS requires an active internet connection to contact Microsoft's cloud neural synthesis servers. If you select Edge TTS, the app transparently marks the engine as `ONLINE / CLOUD FALLBACK • Requires Internet`. For offline operation, select **Local Apple Silicon (macOS Speech)**.

---

## 2. Media Probing & Codecs

### Issue: "Audio stream is not Japanese by default"
- **Behavior:** The app automatically parses metadata tags (`language`, `title`) across all audio tracks using `ffprobe`. If an audio stream is tagged `jpn`, `ja`, or contains `Japanese`, Anime Dub Studio auto-selects it.
- **Resolution:** If a video file has unlabeled audio streams (e.g. `und`), the Create Dub modal displays a track selector showing stream index, channel count, sample rate, and codec so you can manually select the intended track before starting.

### Issue: "Video stream failed to copy directly"
- **Behavior:** By default, Anime Dub Studio utilizes `-c:v copy` to avoid re-encoding the video. If the container or codec has unsupported timestamps or requires re-multiplexing, the pipeline automatically falls back to `-c:v libx264` or `-c:v libx265` with hardware acceleration (`h264_videotoolbox` / `hevc_videotoolbox`).

---

## 3. Pipeline Checkpoints & Job Recovery

### Issue: "Pipeline was interrupted or stopped mid-episode"
- **Behavior:** Every stage of the dubbing workflow writes structured checkpoints to `storage/projects/<project_id>/episodes/<episode_id>/checkpoints/`:
  - `checkpoint_asr.json`
  - `checkpoint_diarization.json`
  - `checkpoint_translations.json`
  - `voices/seg_*.wav`
- **Resolution:**
  - On the Live Processing UI, click **[ Retry from checkpoint ]**.
  - The pipeline automatically loads existing completed segments and resumes from the exact stage that was unfinished without recomputing prior stages.

---

## 4. Subtitle Encoding & Fonts

### Issue: "Hindi Devanagari or Roman Hinglish characters not rendering correctly in video player"
- **Resolution:**
  - Both `.srt` (SubRip) and `.ass` (Advanced SubStation Alpha) are exported to `subtitles/`.
  - `.ass` subtitles use UTF-8 formatting with Arial / system fonts with drop-shadow margins to ensure readability against dynamic video backgrounds.
  - VLC, IINA, and QuickTime all natively support the generated `.mp4` embedded subtitles or external `.srt`/`.ass` subtitle files.
