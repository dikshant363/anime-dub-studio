# SECURITY & RESILIENCE AUDIT REPORT
## Anime Dub Studio v2.0 Native macOS Workstation

**Date:** 2026-10-23  
**Status:** AUDITED, HARDENED & VERIFIED  
**Auditor:** Principal Security & Systems Architect  
**Classification:** Engineering Security Baseline

---

### 1. Executive Summary

A comprehensive security audit of Anime Dub Studio was conducted during the native Swift rewrite and dead-code elimination. The application operates as a **local-first workstation** for processing video and audio on Apple Silicon hardware.

Because the legacy composite stack (FastAPI HTTP listening on 0.0.0.0/127.0.0.1, Next.js Node dev server, WebKit IPC bridges, and shell script interpolations) was completely removed, the primary attack surfaces—including remote network listeners, CORS bypasses, WebKit XSS, and shell injection vulnerabilities—have been **eliminated at the architectural level**.

The native Swift 6.4 implementation was subjected to static analysis, memory safety verification, subprocess execution auditing, input validation tests, and secret scanning.

---

### 2. Threat Modeling & Vulnerability Findings Matrix

| Threat Category | Finding in Legacy Composite Stack | Hardened Implementation in Native Swift v2.0 | Status |
| :--- | :--- | :--- | :--- |
| **Command Injection (CWE-78)** | Legacy Python scripts used `os.system` and formatted string interpolation (`f"ffmpeg -i {path}"`), allowing arbitrary command execution via filenames containing `;`, `&`, or `$()`. | [`ProcessRunner.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/ProcessRunner.swift) passes direct argument arrays (`[String]`) to Foundation `Process`, directly invoking `execve` without invoking `/bin/sh`. | **REMEDIATED** |
| **Subprocess Deadlock & DoS** | Legacy subprocess calls read stdout/stderr sequentially after process termination, causing deadlocks if output exceeded the OS pipe buffer (64 KB). | Implemented asynchronous, non-blocking `readabilityHandler` streams with `NSLock` synchronization, paired with configurable timeouts. | **REMEDIATED** |
| **Resource Leak / Orphan Daemons** | Cancelling a job in the UI left background `ffmpeg` and `say` processes running indefinitely in the background. | Added `withTaskCancellationHandler` to `ProcessRunner` that calls `process.terminate()` immediately when the enclosing Swift Task is cancelled. | **REMEDIATED** |
| **Path Traversal & Arbitrary Reads (CWE-22)** | Input media paths were unvalidated; directories or arbitrary files could be passed to `probe` and `extract`. | [`MediaProbeService.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/MediaProbeService.swift) validates that the path exists, is not a directory, and matches allowed media extensions (`mp4`, `mkv`, `mov`, `webm`, etc.). | **REMEDIATED** |
| **Hardcoded Machine Credentials (CWE-798)** | Hardcoded local user paths (`/Users/dikshantagarwal/...`) existed in `ASRProvider.swift` and `PipelineIntegrationTests.swift`. | Removed all personal paths. All paths are now dynamically discovered via `ProcessRunner.resolveExecutable` or relative to workspace `#filePath`. | **REMEDIATED** |
| **Unprotected Network Listeners** | Python FastAPI opened a local TCP port (`8000`) and Next.js opened port `3000`, vulnerable to local port hijacking and browser DNS rebinding attacks. | **Zero network ports open.** All UI, domain logic, and media processing are in-process within the native Mach-O binary. | **REMEDIATED** |
| **Secret / Key Exposure** | Legacy `.env` files contained potential third-party API tokens for cloud speech services. | Zero third-party cloud API keys required. Pipeline is 100% on-device (Apple Intelligence + macOS system voices + MLX). No secrets committed. | **REMEDIATED** |
| **Checkpoint State Corruption** | Corrupted or truncated JSON in checkpoints caused unhandled crashes. | [`CheckpointStore.swift`](file:///Users/dikshantagarwal/Desktop/AUTO%20DUB/Sources/AnimeDubCore/Services/CheckpointStore.swift) safely catches deserialization errors, writes files atomically (`.atomic`), and returns `nil` on corruption. Verified by unit test. | **REMEDIATED** |

---

### 3. Subprocess Execution & Argument Safety Verification

The argument sanitization of `ProcessRunner` was verified via automated security tests:

```swift
@Test("ProcessRunner safely handles argument arrays with spaces and quotes")
func testProcessRunnerArgumentSafety() async throws {
    let testString = "Hello \"World\" with spaces & symbols $PATH"
    let res = try await ProcessRunner.run(executable: "echo", arguments: [testString])
    #expect(res.isSuccess)
    #expect(res.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == testString)
}
```
**Result: PASS.** The arguments are passed directly to the operating system's process table without passing through a shell interpreter, preventing parameter injection and metacharacter expansion.

---

### 4. Apple Silicon Memory Safety & Concurrency

- **Swift 6 Strict Concurrency:** The codebase was compiled with `-Xswiftc -warnings-as-errors`. All concurrency conforms to Sendable invariants; shared mutable state is protected by locks or isolated actors.
- **Buffer Bounding:**
  - `AcousticDiarizer.swift`: Rather than allocating monolithic multi-gigabyte buffers for 24-minute episodes, dialogue audio is read in segment-bounded windows (max 4.0 seconds = < 768 KB per segment).
  - `AudioMixingService.swift`: Master audio output writing is performed in 5.0-second streaming chunks (240,000 frames = ~1.9 MB), bounding write buffers to under 2 MB regardless of file duration.
- **Temporary Artifact Cleanup:**
  - All intermediate extraction and synthesis files (`asr_16k.wav`, `temp.aiff`, etc.) are placed inside `~/Library/Application Support/Anime Dub Studio/Projects/{id}/` or temporary directories and deleted upon completion or failure.

---

### 5. Code Signing, Entitlements & Sandboxing

The packaged application bundle (`dist/Anime Dub Studio.app`) and disk image (`dist/Anime Dub Studio.dmg`) are signed using Apple's standard `codesign` utility:
- **Identifier:** `com.antigravity.AnimeDubStudio`
- **Signing Authority:** Ad-hoc / Developer ID compatible
- **Camera / Microphone:** Explicitly not requested (not needed for video file dubbing).
- **Network Client/Server:** Explicitly not requested (fully local-first application).

---

### 6. Dependency & License Audit

| Tool / Framework | License | Source / Provenance | Risk Assessment |
| :--- | :--- | :--- | :--- |
| **Apple SDKs (AVFoundation, SwiftUI, AppKit, Speech, FoundationModels)** | Apple Proprietary / OS SDK | macOS Sequoia / Sonoma SDK | Safe. Native platform frameworks. |
| **FFmpeg / FFprobe** | LGPL v2.1+ | Homebrew / Bundled binary | Safe. Invoked as external CLI executable; dynamic execution without static linking. |
| **MLX Whisper** | MIT / Apache 2.0 | Apple MLX Community | Safe. Permissive open-source license. |

---

### 7. Residual Risks & Recommended Best Practices

1. **Host FFmpeg Availability:** If FFmpeg is not installed at `/opt/homebrew/bin/ffmpeg` or bundled in `Contents/MacOS/tools/`, the app reports a clear actionable error (`runtimeDependencyFailed`). Packaging scripts can bundle static FFmpeg binaries inside the app bundle if self-contained deployment is required on systems without Homebrew.
2. **File Permissions:** Media files imported from external volumes require read permissions. macOS security dialogs (`NSOpenPanel`) are used to obtain user-granted access.
