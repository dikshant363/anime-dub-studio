# Project Format & Data Management

This document details the disk structure, JSON schemas, atomic persistence mechanics, and cache invalidation rules used by Anime Dub Studio.

---

## 1. Project Directory Structure

Projects are stored locally in `~/Library/Application Support/AnimeDubStudio/projects/<projectId>/`:

```text
projects/<projectId>/
├── project.json                       # Master Project Metadata
└── episodes/<episodeId>/
    ├── episode.json                   # Episode Specifications & Deliverables
    ├── checkpoints/
    │   └── stage_<stageNumber>.json   # Atomic Stage Checkpoint Snapshots
    ├── audio/
    │   ├── master.wav                 # Extracted Master Dialogue (48kHz)
    │   ├── asr_input.wav              # 16kHz Speech Isolation Stem
    │   └── dubbed_master.wav          # Mastered Soundtrack (EBU R128)
    ├── voices/
    │   ├── ref_SPEAKER_00.wav         # Reference Audio Slice for Speaker 00
    │   ├── ref_SPEAKER_01.wav         # Reference Audio Slice for Speaker 01
    │   ├── seg_001.wav                # Synthesized Segment #1 Audio
    │   ├── seg_001.sig                # Signature Hash for Segment #1
    │   └── ...
    ├── subtitles/
    │   ├── subtitles.srt              # Synchronized SubRip Subtitles
    │   └── subtitles.ass              # Styled Advanced SubStation Alpha Subtitles
    └── export/
        └── final_dubbed_video.mp4     # Lossless Remuxed Finished Deliverable
```

---

## 2. Master Schemas

### `project.json`
Contains project identification, creation timestamp, status, dubbing options (`DubOptions`), and an array of contained `Episode` references.

### `CharacterProfile`
Persisted in the episode metadata to record voice assignment and acoustic analysis:
```json
{
  "speakerTag": "SPEAKER_00",
  "name": "Lead Protagonist",
  "voiceId": "com.apple.speech.synthesis.voice.rishi",
  "gender": "male",
  "speakerSimilarity": 82.0,
  "targetNaturalness": 75.0,
  "accentMode": "balanced",
  "providerId": "com.apple.speech.native_cast",
  "referenceAudioPath": ".../voices/ref_SPEAKER_00.wav",
  "referenceProvenance": "Extracted from source Japanese dialogue (segment seg_002, duration 2.80s)",
  "assignmentConfidence": 0.94,
  "measuredPitchF0": 128.5,
  "measuredDurationSeconds": 2.80
}
```

---

## 3. Atomic Persistence & Crash Recovery

1. **Atomic File Swapping:** All manifests and stage checkpoints are written to `.tmp` files first and atomically replaced via `FileManager.default.replaceItemAt`. This guarantees that system crashes or power losses never produce corrupt, partially written JSON manifests.
2. **Reader-Writer Synchronization:** `ProjectStore` serializes all writes through a concurrent dispatch queue with barrier execution (`flags: .barrier`), eliminating concurrent read/write data races.
3. **Resilient Stage Resumption:** Checkpoint files record completed stage output. If an export is interrupted, restarting the project resumes directly from the last valid checkpoint without repeating expensive transcription stages.

---

## 4. Granular Cache Invalidation

Dialogue synthesis caching uses signature files (`seg_%03d.sig`):
$$\text{sig} = \text{text} \mid \text{voiceId} \mid \text{speedRate} \mid \text{similarity} \mid \text{naturalness} \mid \text{accentMode}$$

When a line is edited in the Studio:
* Only the modified line's `.sig` file is updated.
* Unmodified lines match their existing signatures on disk and are reused immediately.
* Re-exporting recalculates audio mixing and remuxes the video in seconds without re-synthesizing untouched dialogue.
