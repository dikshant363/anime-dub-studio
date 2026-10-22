# Contributing to Anime Dub Studio

Thank you for your interest in contributing to Anime Dub Studio! We welcome community contributions that improve the quality, accessibility, localization, and performance of our native macOS dubbing workstation.

## Code of Conduct

All contributors and maintainers are expected to adhere to our [Code of Conduct](CODE_OF_CONDUCT.md). Please be respectful, collaborative, and constructive when opening issues, participating in discussions, or submitting pull requests.

## Architecture & Technology Stack

Anime Dub Studio is written in **Swift 6** using **SwiftUI**, **AppKit**, and **AVFoundation**:

- **No Python Servers or Web Frameworks:** The app must remain a native standalone binary without runtime dependencies on Python virtualenvs, Node.js, or Tauri.
- **Structured Concurrency:** Use `async/await`, `Sendable`, and typed errors. Avoid unstructured detachment without explicit cancellation handling.
- **Pipe & Resource Safety:** All subprocess execution must pass through `ProcessRunner` with asynchronous standard I/O consumption to prevent buffer deadlocks.
- **Human Interface Guidelines:** UI components must follow Apple HIG aesthetics (SF Pro, SF Symbols, standard macOS sheets, panels, and sidebars).

## Development Setup

1. **Prerequisites:**
   - Apple Silicon Mac (M1/M2/M3/M4) running macOS 14 Sonoma or macOS 15 Sequoia (or newer).
   - Xcode 16+ or Swift 6.0+ toolchain (`swift --version`).
   - FFmpeg with Opus and AAC support (`brew install ffmpeg`).

2. **Building the Project:**
   ```bash
   swift build
   ```

3. **Running Automated Tests:**
   ```bash
   swift test
   ```

4. **Building Distributable macOS Application & DMG:**
   ```bash
   ./scripts/package_native_app.sh
   ```

## Pull Request Guidelines

1. **Scope:** Keep pull requests focused on a single feature, bugfix, or optimization.
2. **Tests:** All existing tests in `tests/AnimeDubCoreTests/` must pass. Add new unit tests for any new service or parsing logic.
3. **No Committed Binaries:** Never commit videos, audio recordings, or compiled `.app` / `.dmg` bundles to git.
4. **Documentation:** Update relevant documents in `docs/` and `README.md` if public APIs or UI workflows change.
