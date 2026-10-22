# Troubleshooting & Diagnostic Guide

This guide provides solutions to common setup, media format, audio extraction, and synthesis issues.

---

## 1. Installation & Launch Issues

### Problem: "Anime Dub Studio cannot be opened because Apple cannot check it for malicious software"
* **Cause:** The release binary is ad-hoc signed by an independent developer and has not yet been notarized with an Apple Developer Program certificate.
* **Solution:**
  1. Open **System Settings > Privacy & Security**.
  2. Scroll to the bottom and click **Open Anyway** next to Anime Dub Studio.
  3. Or run in Terminal:
     ```bash
     xattr -cr "/Applications/Anime Dub Studio.app"
     ```

### Problem: "FFmpeg or FFprobe executable not found"
* **Cause:** FFmpeg is not installed or not available in the system `$PATH`.
* **Solution:**
  Install FFmpeg via Homebrew:
  ```bash
  brew install ffmpeg
  ```
  Ensure `/opt/homebrew/bin` is in your shell path.

---

## 2. Media Probing & Audio Issues

### Problem: "Selected media file does not contain a supported Japanese audio stream"
* **Cause:** The video container only contains English, Spanish, or comment tracks without Japanese audio.
* **Solution:** Verify with `ffprobe -i "your_video.mkv"` that a Japanese audio stream exists with language tag `ja` or `jpn`.

### Problem: "Synthesized voice sounds like default English voice instead of Indian accent"
* **Cause:** High-quality Indian English voices (`Rishi`, `Lekha`, etc.) have not been downloaded in macOS System Settings.
* **Solution:**
  1. Open **System Settings > Accessibility > Spoken Content > System Voice**.
  2. Select **Manage Voices...** and download `Rishi (Enhanced)` and `Lekha (Enhanced)`.

---

## 3. Performance & Memory Issues

### Problem: "Memory usage climbs during long-form video (>2 hours)"
* **Cause:** Extremely long multi-episode containers held in uncompressed PCM buffers during mastering.
* **Solution:**
  Process the video in single-episode chunks (20–45 minutes each), or upgrade to v2.4.0 where chunked streaming convolution is enabled.

---

## 4. Pipeline Diagnostics

To inspect low-level diagnostic logs for a project:
```bash
# View project episode manifests
cat ~/Library/Application\ Support/AnimeDubStudio/projects/*/episodes/*/episode.json | grep qaScore
```
