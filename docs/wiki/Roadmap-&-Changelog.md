# Product Roadmap & Changelog

This document provides a bird's-eye view of active development milestones, completed releases, and future planned capabilities for Anime Dub Studio.

---

## 1. Active Milestones & GitHub Roadmap

The canonical engineering roadmap is tracked on GitHub Milestones:
👉 [https://github.com/dikshant363/anime-dub-studio/milestones](https://github.com/dikshant363/anime-dub-studio/milestones)

| Milestone | Target Version | State | Primary Focus |
| :--- | :---: | :---: | :--- |
| **Milestone 1** | `v2.1.1` | **CLOSED (100%)** | Core reliability, honest speaker similarity disclosures, reference audio extraction, post-render finished-video results workspace. |
| **Milestone 2** | `v2.2.0` | **OPEN** | Finished-Video Studio enhancements: custom subtitle styling inspector (ASS fonts/colors), drag-and-drop export panel, and stem demuxing. |
| **Milestone 3** | `v2.3.0` | **OPEN** | Character identity & voice quality: on-device zero-shot neural TTS evaluation, objective acoustic distance benchmarks, and listening evaluations. |
| **Milestone 4** | `v2.4.0` | **OPEN** | Media pipeline & editing reliability: memory-bounded chunked audio mastering for >2-hour media, atomic crash recovery. |
| **Milestone 5** | `v2.5.0` | **OPEN** | Native Apple Silicon optimization: VoiceOver accessibility labeling, AppKit keyboard navigation shortcuts, Metal waveform acceleration. |
| **Milestone 6** | `v3.0.0` | **OPEN** | Production-grade distribution: Apple Developer ID signing and notarization, native SPM MLX Swift in-process Whisper integration. |

---

## 2. Release History Summary

* **v2.1.1 (Current):** Speaker-preserving dubbing with independent Similarity and Naturalness controls, 3 Accent presets, truthful capabilities disclosures, authentic reference audio extraction, finished-video AVPlayer results screen, and signature-based cache invalidation.
* **v2.1.0:** Speaker similarity controls, dual-track audio toggle, finished-video results view, and project re-editability in Studio.
* **v2.0.0:** Ground-up native Swift 6.4 rewrite, elimination of 8.4+ GB of legacy Python/Tauri/Next.js code, standalone Apple Silicon `.app` and `.dmg`.
* **v1.0.0:** Initial hybrid proof-of-concept prototype.

For full release notes and line-by-line commit history, see [CHANGELOG.md](../../CHANGELOG.md) or visit [GitHub Releases](https://github.com/dikshant363/anime-dub-studio/releases).
