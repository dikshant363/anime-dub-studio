# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 2.1.x   | :white_check_mark: |
| 2.0.x   | :white_check_mark: |
| < 2.0   | :x:                |

## Security Architecture & Local-First Invariants

Anime Dub Studio is designed from the ground up as a **local-first, privacy-respecting workstation** for macOS:

1. **Local-Only Media Processing:** All video probing, audio extraction, transcription, diarization, translation, speech synthesis, and video multiplexing occur locally on-device. Media files and subtitles never leave your Mac.
2. **Subprocess Sanitization:** All external process invocations (`ffmpeg`, `ffprobe`) use explicit argument arrays via `ProcessRunner` with asynchronous standard I/O pipe consumption. No raw shell strings (`/bin/sh -c`) are ever executed, eliminating shell injection vulnerabilities.
3. **Atomic State & Checkpoints:** Project manifests and stage checkpoints are written to temporary files and atomically swapped into place via `FileManager.replaceItemAt` to prevent partial corruption.
4. **Credential Boundaries:** No cloud credentials, API tokens, or secrets are required or stored in plaintext, environment files, or application bundles.

## Reporting a Vulnerability

If you discover a security vulnerability in Anime Dub Studio:

1. Please do **not** open a public issue.
2. Report the vulnerability via GitHub Private Vulnerability Reporting or contact the maintainer directly at:
   `https://github.com/dikshant363/anime-dub-studio/security/advisories/new`
3. Include the affected version, reproduction steps, and proof-of-concept media if applicable.
4. You will receive an acknowledgment within 48 hours, followed by a remediation plan and release timeline.
