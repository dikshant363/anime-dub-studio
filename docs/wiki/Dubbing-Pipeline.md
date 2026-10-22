# The 8-Stage Dubbing Pipeline

This document explains the internal execution model of the 8-stage dubbing pipeline implemented in `JobOrchestrator.swift`.

---

## Pipeline Overview

```text
[Input Video]
      ↓
[1. Media Probe & Stream Discovery]
      ↓
[2. Audio Extraction & Isolation]
      ↓
[3. ASR & Character Diarization]  ──► [Extracts Reference Audio & Character Profiles]
      ↓
[4. Hindi/Hinglish Localization]  ──► [Devanagari / Roman Script Normalization]
      ↓
[5. Speech Synthesis & Shaping]   ──► [Signature-Based Cache Check: seg_%03d.sig]
      ↓
[6. Audio Mastering & Normalization] (EBU R128 -23 LUFS & BGM Sidechain Ducking)
      ↓
[7. Subtitle Formatting]          (SRT & ASS Timestamps)
      ↓
[8. Lossless Video Remuxing]      (-c:v copy + AAC Stereo)
      ↓
[Finished Video Deliverable]
```

---

## Detailed Stage Execution

### Stage 1: Media Probing & Stream Discovery (`0% - 10%`)
* Uses AVFoundation (`AVURLAsset`) and `ffprobe` to inspect video dimensions, framerate, duration, and all embedded audio streams.
* Automatically selects the authentic Japanese dialogue stream (matching `ja`, `jpn`, or highest stream priority).

### Stage 2: Audio Extraction & Isolation (`10% - 20%`)
* Extracts master 48kHz stereo WAV from the identified Japanese stream using `-map 0:<idx>`.
* Generates a 16kHz mono speech-isolation stem optimized for automatic speech recognition.

### Stage 3: ASR & Character Diarization (`20% - 40%`)
* Transcribes speech utterances using Apple Speech framework or on-device MLX Whisper.
* Groups individual word tokens into natural conversational phrase segments based on silence pauses ($> 300\text{ ms}$).
* Measures fundamental pitch ($F_0$) and spectral distribution to cluster dialogue into character archetypes (Lead Protagonist, Lead Heroine, Supporting Male, Supporting Female).
* **Reference Audio Extraction:** Extracts the cleanest dialogue segment ($\ge 1.2\text{s}$) for each speaker and saves it to `voices/ref_<tag>.wav`, storing provenance and confidence in `CharacterProfile`.

### Stage 4: Hindi & Hinglish Localization (`40% - 55%`)
* Localizes dialogue into natural spoken Hindi or colloquial Roman Hinglish using Apple `FoundationModels` or offline lexical models.
* Strips all Devanagari characters when Hinglish is chosen, guaranteeing clean Latin phonetics for speech synthesis.
* Normalizes anime honorifics (e.g. *-san*, *-senpai*, *-kun*) into natural Indian address terms.

### Stage 5: Speech Synthesis & Cache Invalidation (`55% - 80%`)
* Checks segment signature `seg_%03d.sig` on disk. If signature matches existing WAV, synthesis is skipped (instant cache hit).
* If dirty, synthesizes the line using native macOS Indian cast voices (`Rishi`, `Lekha`, etc.).
* Applies dynamic acoustic formant shaping (EQ filters, pitch curve modulation) according to the user's **Speaker Similarity** and **Accent Preservation** mode.

### Stage 6: Audio Mastering & Normalization (`80% - 90%`)
* Time-aligns dialogue segments to their original video timestamps using WSOLA (`atempo`).
* Masters the dialogue track alongside background music, applying sidechain ducking (attenuates BGM by 45% during active speech).
* Applies two-pass EBU R128 loudness normalization to meet broadcast standard (-23.0 LUFS, -1.0 dB True Peak).

### Stage 7: Subtitle Formatting (`90% - 95%`)
* Formats synchronized dialogue cues into `.srt` (SubRip) and `.ass` (Advanced SubStation Alpha) subtitle files with exact millisecond precision.

### Stage 8: Lossless Video Remuxing (`95% - 100%`)
* Remuxes the original video bitstream losslessly (`-c:v copy`) with the newly mastered AAC stereo audio track into a pristine MP4 container.
* Zero generational re-encoding loss.
