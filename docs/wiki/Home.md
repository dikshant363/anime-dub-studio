# Anime Dub Studio Wiki

Welcome to the official technical documentation and wiki for **Anime Dub Studio**.

**Anime Dub Studio** is a native macOS Apple Silicon workstation engineered in Swift 6 and SwiftUI for local-first, privacy-respecting Japanese video dubbing into natural colloquial Hindi and Roman Hinglish.

---

## Quick Navigation

| Topic | Description | Link |
| :--- | :--- | :--- |
| **Getting Started** | System requirements, installation, and first dub run | [[Getting Started\|Getting-Started]] |
| **Installation & Setup** | DMG/ZIP install, FFmpeg prerequisites, and voice packages | [[Installation & Dependencies\|Installation-&-Dependencies]] |
| **Architecture** | Native Swift 6 engine, SwiftUI HIG views, and service boundaries | [[Architecture\|Architecture]] |
| **Dubbing Pipeline** | 8-stage end-to-end processing from probing to video remux | [[Dubbing Pipeline\|Dubbing-Pipeline]] |
| **Voice Quality & Similarity** | Acoustic presence shaping, naturalness, and accent modes | [[Speaker Similarity & Voice Quality\|Speaker-Similarity-&-Voice-Quality]] |
| **Model & Provider Matrix** | Local Apple Speech, MLX Whisper, FoundationModels, and licensing | [[Model & Provider Matrix\|Model-&-Provider-Matrix]] |
| **Project & Data Format** | Atomic persistence, project JSON, and checkpoint recovery | [[Project Format & Data Management\|Project-Format-&-Data-Management]] |
| **QA & Testing** | 5-pillar QA scorecard, test commands, and media verification | [[Testing & Quality Assurance\|Testing-&-Quality-Assurance]] |
| **Security & Privacy** | Local-first guarantees, subprocess safety, and vulnerability disclosure | [[Security & Privacy\|Security-&-Privacy]] |
| **Development Setup** | Xcode 16 toolchain, repository setup, and contribution guide | [[Development Setup\|Development-Setup]] |
| **Release & Distribution** | Packaging scripts, code signing, and checksum verification | [[Release & Distribution\|Release-&-Distribution]] |
| **Troubleshooting** | Codec errors, memory limits, and timing sync solutions | [[Troubleshooting\|Troubleshooting]] |
| **Roadmap & Changelog** | GitHub milestones, planned releases, and changelog history | [[Roadmap & Changelog\|Roadmap-&-Changelog]] |

---

## Core Product Principles

1. **100% Local-First & Zero Cloud Lock-In:** All audio extraction, transcription, translation, voice synthesis, and video mastering execute entirely on Apple Silicon. Zero network calls, zero subscription fees, zero cloud API keys required.
2. **Native Apple Silicon Engineering:** Written in Swift 6 using AppKit, SwiftUI, AVFoundation, and CoreAudio. No background Python servers, virtual environments, Node.js runtimes, or localhost bridges.
3. **Truthful Capabilities:** Voice synthesis transparently discloses that built-in macOS voices use acoustic presence shaping and prosodic cadence adaptation rather than neural voice cloning.
4. **Broadcast Audio Compliance:** Final soundtracks are mastered with sidechain BGM ducking, WSOLA time-stretching, and two-pass EBU R128 loudness normalization (-23.0 LUFS, -1.0 dB True Peak).
5. **Lossless Video Multiplexing:** Preserves original 1080p/4K HEVC and AVC video bitstreams without re-encoding generational loss (`-c:v copy`).

---

## Repository & Links

* **GitHub Repository:** [https://github.com/dikshant363/anime-dub-studio](https://github.com/dikshant363/anime-dub-studio)
* **Releases & Downloads:** [https://github.com/dikshant363/anime-dub-studio/releases](https://github.com/dikshant363/anime-dub-studio/releases)
* **Milestones & Roadmap:** [https://github.com/dikshant363/anime-dub-studio/milestones](https://github.com/dikshant363/anime-dub-studio/milestones)
* **Issue Tracker:** [https://github.com/dikshant363/anime-dub-studio/issues](https://github.com/dikshant363/anime-dub-studio/issues)
