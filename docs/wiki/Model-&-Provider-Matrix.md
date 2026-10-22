# Model & Provider Matrix

This matrix documents all supported models, providers, runtime execution environments, hardware requirements, and licensing for Anime Dub Studio.

---

## 1. Subsystem Capabilities Matrix

| Subsystem | Primary Provider | Fallback Provider | Local / Offline | Hardware Target | Licensing & Privacy |
| :--- | :--- | :--- | :---: | :--- | :--- |
| **Media Probe** | `AVFoundation` (`AVURLAsset`) | `ffprobe` | 100% Local | All Apple Silicon | Native Apple API / LGPL |
| **Audio Extraction** | `ffmpeg` (Stream Mapping) | Direct AVAsset Export | 100% Local | All Apple Silicon | LGPL 2.1+ |
| **ASR (Speech)** | `MLX Whisper` (Metal/ANE) | Apple Speech (`SFSpeechRecognizer`) | 100% Local | Apple M1–M4 | MIT / Apple Platform |
| **Diarization** | Acoustic Pitch ($F_0$) & Spectral Clustering | Energy VAD Clustering | 100% Local | All Apple Silicon | Proprietary Studio Algorithm |
| **Translation** | Apple `FoundationModels` (`SystemLanguageModel`) | Offline Rule-Based Lexicon | 100% Local | macOS 26+ / Offline fallback | Apple Platform / Apache 2.0 |
| **Speech Synthesis** | Native macOS Indian Cast (`AVSpeechSynthesizer`) | `/usr/bin/say` Subprocess | 100% Local | macOS 14+ | Apple Platform |
| **Audio Mastering** | FFmpeg EBU R128 (`loudnorm` + `sidechain`) | CoreAudio Graph | 100% Local | All Apple Silicon | LGPL 2.1+ |
| **Video Remuxing** | FFmpeg Stream Copy (`-c:v copy`) | AVAssetWriter | 100% Local | All Apple Silicon | LGPL 2.1+ |

---

## 2. Voice Cast Roster (Indian Cast Archetypes)

| Character Archetype | Assigned System Voice | Gender | Target Character Style |
| :--- | :--- | :--- | :--- |
| **Lead Protagonist** | `Rishi (Enhanced)` | Male | Disciplined, heroic, measured anime protagonist |
| **Lead Heroine** | `Lekha (Enhanced)` | Female | Expressive, vibrant, high-clarity anime heroine |
| **Supporting Male** | `Aman (Enhanced)` | Male | Deeper pitch, comic relief or authoritative elder |
| **Supporting Female** | `Tara (Enhanced)` | Female | Gentle, soft-spoken secondary character |

---

## 3. Hardware & Memory Footprint

* **Apple Silicon M4 / M3 / M2 / M1:**
  - Base Memory Budget: $< 600\text{ MB}$ RSS during full 23-minute timeline processing.
  - Multi-Core CPU Utilization: ~340% (3.4 active cores during parallel synthesis).
  - Storage Footprint: Application binary is 6.3 MB; temporary audio stems for a 23-minute episode require ~450 MB disk space.
