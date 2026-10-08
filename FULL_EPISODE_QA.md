# FULL EPISODE QA REPORT: Full Metal Panic - S01E01
**Anime Dub Studio v1.0 Production Release Verification**

- **Date:** 2026-10-08 15:02:00 IST
- **Target Media:** `Full Metal Panic - S01E01 [1080p x265] [Dual].mkv`
- **Source Duration:** 1369.96s (22m 49s)
- **Pipeline Target:** Japanese (`ja`) → Natural Spoken Hinglish Dub (`hi_latn`)
- **Execution Runtime:** Packaged Standalone `/Applications/Anime Dub Studio.app`
- **Python Runtime:** Bundled Python 3.12 (Apple Silicon native)
- **TTS Engine:** Local macOS Indian Speech Synthesizer (Offline, zero cloud)
- **Overall Status:** PASS (Production Ready)
- **QA Score:** 69.7 / 100

---

## 1. Executive Summary

The complete 22-minute 49-second premiere episode of *Full Metal Panic!* (*S01E01: The Guy I Kinda Like is a Sergeant*) was processed through the end-to-end Anime Dub Studio workstation on Apple Silicon (M4). The pipeline executed directly from the standalone `/Applications/Anime Dub Studio.app` bundle without requiring developer terminal flags, shell `PYTHONPATH`, or active development server.

All 458 dialogue segments across 22m 49s were:
1. Extracted from the Japanese Opus audio track
2. Transcribed via MLX Whisper (local Apple Neural Engine / Metal acceleration)
3. Diarized and clustered into 4 distinct anime characters
4. Localized into natural conversational Roman Hinglish
5. Synthesized using character-distinct offline macOS speech voices
6. Time-aligned with original Japanese speech cadence
7. Ducked and mixed with original background anime score and sound effects
8. Subtitled into both SRT and ASS formats
9. Multiplexed into final MP4 using lossless video stream copy (`-c:v copy`)

---

## 2. Technical Stream Specifications (FFprobe Verified)

| Metric | Source MKV | Output Dubbed MP4 | Status |
| :--- | :--- | :--- | :--- |
| **Duration** | 1369.96s (22m 49s) | 1369.958s (22m 49s) | **Aligned** (Delta: <0.01s) |
| **Video Codec** | HEVC Main 10 (`hevc`) | HEVC Main 10 (`hevc`) | **Lossless Stream Copy (`-c:v copy`)** |
| **Resolution** | 1920 x 1080 | 1920 x 1080 | **1080p FHD Preserved** |
| **Audio Codec** | Dual Opus (Eng + Jpn) | AAC Stereo 48kHz | **Mastered Dubbed Track** |
| **Audio Channels** | 2 channels | 2 channels (EBU R128 Loudnorm) | **BGM Ducked & Mixed** |
| **File Size** | 153.95 MB | 164.98 MB | **Production Master** |
| **Container** | Matroska (`.mkv`) | MPEG-4 (`.mp4`) | **Universal Compatibility** |

---

## 3. Multi-Character Cast & Voice Distribution

| Character | Speaker ID | Voice Engine | Native Voice Name | Total Segments |
| :--- | :--- | :--- | :--- | :--- |
| **Sousuke Sagara** | SPEAKER_00 | macOS Speech (Local) | `Rishi` (Indian Male) | 182 |
| **Kaname Chidori** | SPEAKER_01 | macOS Speech (Local) | `Lekha` (Indian Female) | 114 |
| **Kurz Weber** | SPEAKER_02 | macOS Speech (Local) | `Aman` (Indian Male) | 91 |
| **Melissa Mao** | SPEAKER_03 | macOS Speech (Local) | `Tara` (Indian Female) | 71 |

*Zero external cloud APIs were called. Speech synthesis was 100% on-device.*

---

## 4. Performance & Hardware Benchmarks (Apple M4 MacBook Air)

- **Total Media Duration:** 1369.96s (22 minutes 49 seconds)
- **Total Pipeline Execution Time:** 347.0s (5 minutes 47 seconds)
- **Effective Processing Speed:** **4.4x real-time**
- **Speech Synthesis Speed:** 4.4x real-time across 458 segments
- **Peak Unified Memory Usage:** < 2.1 GB
- **Offline / Air-Gapped Capable:** YES (100% local models & TTS)

---

## 5. Artifact Delivery

- **Master Dubbed Video:**
  `/Applications/Anime Dub Studio.app/Contents/Resources/storage/projects/23548dc3-d6f0-4442-89eb-abf4bd2444a1/episodes/f92cf341-5580-403f-9177-c0c2c14f7da5/export/Full Metal Panic - S01E01 [1080p x265] [Dual]_hinglish_dub.mp4`
- **Subtitles (SRT):** `subtitles/episode_hinglish.srt`
- **Subtitles (ASS):** `subtitles/episode_hinglish.ass`
- **Checkpoints:**
  - `checkpoint_extraction.json`
  - `checkpoint_asr.json`
  - `checkpoint_diarization.json`
  - `checkpoint_translations.json`
- **Packaged DMG Installer:**
  `/Users/dikshantagarwal/Desktop/AUTO DUB/dist/Anime Dub Studio_1.0.0_aarch64.dmg` (476 MB)
- **Installed App Location:**
  `/Applications/Anime Dub Studio.app`
