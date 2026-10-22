# Getting Started with Anime Dub Studio

This guide walks you through system requirements, installation, and your first end-to-end anime dubbing run using Anime Dub Studio.

---

## 1. System Requirements

* **Operating System:** macOS 14 Sonoma or macOS 15 Sequoia (or newer).
* **Architecture:** Apple Silicon (M1, M2, M3, M4, Pro, Max, Ultra). Intel Macs are not supported.
* **Unified Memory:** 16 GB unified memory recommended (minimum 8 GB for short clips).
* **Disk Space:** 500 MB free for app and cache stems, plus space for your source video files.

---

## 2. Installation

1. Download the latest release from the [GitHub Releases](https://github.com/dikshant363/anime-dub-studio/releases) page:
   - `Anime Dub Studio.dmg` (Drag-and-Drop installer)
   - Or `Anime-Dub-Studio-v2.1.1-macos-arm64.zip`
2. Open `Anime Dub Studio.dmg` and drag **Anime Dub Studio** to your `/Applications` folder.
3. Install external multimedia tools via Homebrew:
   ```bash
   brew install ffmpeg
   ```
4. Verify Indian English/Hindi voice assets in macOS System Settings:
   - Go to **System Settings > Accessibility > Spoken Content > System Voice**.
   - Ensure high-quality Indian English voices (`Rishi`, `Lekha`, `Aman`, `Tara`) are downloaded.

---

## 3. Your First Dubbing Workflow

### Step 1: Open Application & Create Project
- Launch **Anime Dub Studio** from `/Applications` or Spotlight.
- On the sidebar, click **Studio Projects**, then click **Create New Dub** (`+`).

### Step 2: Select Source Anime Media
- Select any local anime file (`.mkv`, `.mp4`, or `.mov`).
- The application automatically probes the container, detects audio streams, and maps the authentic Japanese dialogue stream (e.g. Stream #2 Opus/AAC).

### Step 3: Configure Localization & Voice Settings
- **Target Language:** Select **Hindi (Devanagari)** or **Hinglish (Colloquial Roman)**.
- **English Mixing Level:** Low, Medium, or High loanword density.
- **Speaker Similarity (0–100%):** Set acoustic timbre targeting toward the source Japanese voice actor.
- **Target Naturalness (0–100%):** Set conversational fluency and prosody variability.
- **Accent Preset:** Select *Preserve Original Accent*, *Balanced*, or *Natural Hindi/Hinglish*.

### Step 4: Run Live Pipeline
- Click **Start Dubbing Pipeline**.
- Monitor the live 8-stage progress tracker in `LiveProcessingView`:
  1. Media Probing & Stream Discovery
  2. Dialogue Extraction & Audio Filtering
  3. ASR & Character Diarization
  4. Localization & Script Sanitization
  5. Speech Synthesis & Dynamic Formant Shaping
  6. Audio Mastering & EBU R128 Loudness Normalization
  7. Subtitle Synchronization
  8. Lossless Video Remuxing

### Step 5: Finished-Video Results & Studio Editing
- When complete, the app automatically navigates to **FinishedVideoResultView**:
  - Watch the dubbed video with embedded `AVPlayer`.
  - Use the **Audio Track Switcher** to compare *Dubbed Audio* vs *Original Japanese* in real time.
  - Review the **5-Pillar QA Scorecard**.
  - Click **Save Video As...** to export your deliverable, or click **Edit in Studio** to adjust dialogue lines and re-export with instant cache reuse.
