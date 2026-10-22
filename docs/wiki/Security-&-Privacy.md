# Security & Privacy Architecture

This document outlines the security invariants, threat mitigations, and vulnerability disclosure policies of Anime Dub Studio.

---

## 1. Local-First Privacy Invariants

Anime Dub Studio guarantees 100% on-device privacy:
* **Zero Cloud Telemetry:** No user analytics, diagnostic pings, or usage data are sent over the network.
* **Zero Remote Inference:** Media files, speech audio stems, transcriptions, translations, and exported videos are never uploaded to any external server or cloud AI provider.
* **Zero Credential Dependency:** The application does not request, store, or transmit API keys or cloud tokens.

---

## 2. Process Execution & Subprocess Sanitization

Subprocess calls (`ffmpeg`, `ffprobe`) present significant security risks if handled improperly:

1. **Elimination of Shell String Execution:**
   - Invocations never pass strings to `/bin/sh -c` or `/bin/zsh -c`.
   - All commands are passed strictly as immutable arrays of typed arguments (`[String]`), completely eliminating shell command injection vulnerabilities.
2. **Buffer Saturation & Deadlock Prevention:**
   - Standard output and error streams are drained asynchronously via GCD `readabilityHandler` blocks with thread-safe synchronization.
   - Prevents macOS kernel pipe buffer saturation ($> 64\text{ KB}$) from freezing the parent process.
3. **Subsecond Cancellation Handling:**
   - Long-running processes are wrapped in `withTaskCancellationHandler`.
   - When a user clicks **Cancel**, a `SIGTERM` signal is immediately dispatched to child process groups, preventing orphaned background worker processes.

---

## 3. File System Safety

* **Path Traversal Protection:** User-selected media paths and export destinations are validated to ensure they resolve within allowed macOS filesystem hierarchies.
* **Atomic File Swapping:** All configuration and state manifests use atomic renaming (`FileManager.default.replaceItemAt`), preventing corrupt partial writes on power failure.

---

## 4. Vulnerability Disclosure Policy

If you discover a potential security or privacy vulnerability in Anime Dub Studio:
1. Please do **not** open a public GitHub issue.
2. Report the vulnerability privately via [GitHub Security Advisories](https://github.com/dikshant363/anime-dub-studio/security/advisories/new).
3. Provide full reproduction steps and environment details.
4. The project maintainer will respond within 48 hours to confirm the report and coordinate a security release.
