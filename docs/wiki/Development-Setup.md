# Development Setup & Contributor Guide

This guide describes how to clone, build, test, and contribute to Anime Dub Studio on Apple Silicon macOS.

---

## 1. Prerequisites

* **Hardware:** Apple Silicon Mac (M1/M2/M3/M4) running macOS 14 Sonoma or macOS 15 Sequoia (or newer).
* **Toolchain:** Xcode 16+ or Swift 6.0+ toolchain (`swift --version`).
* **Homebrew Dependencies:**
  ```bash
  brew install ffmpeg
  ```

---

## 2. Cloning & Building

```bash
# Clone the repository
git clone https://github.com/dikshant363/anime-dub-studio.git
cd anime-dub-studio

# Build debug targets
swift build -c debug

# Build production release binary
swift build -c release
```

---

## 3. Running Automated Tests

```bash
# Run core unit and integration test suites
swift test --filter "QualityAssuranceTests|SecurityAndResilienceTests|HindiAdaptationTests|HinglishLocalizationTests|DialogueTimingTests|SpeakerSimilarityAndAccentTests|FinishedVideoWorkflowTests|PipelineIntegrationTests|ProviderCapabilitiesAndCacheTests"
```

---

## 4. Packaging Release Artifacts

To compile the native `.app` bundle, generate the drag-and-drop `.dmg` installer, and create distributable `.zip` archives with SHA-256 checksums:
```bash
chmod +x scripts/package_native_app.sh
./scripts/package_native_app.sh
```

Artifacts will be generated in `dist/`:
* `dist/Anime Dub Studio.app`
* `dist/Anime Dub Studio.dmg`
* `dist/Anime-Dub-Studio-v2.1.1-macos-arm64.zip`
* `dist/SHA256SUMS.txt`

---

## 5. Coding & Contribution Conventions

1. **Strictly Native Swift:** No Python code, web servers, Node.js packages, or Tauri shells.
2. **Swift 6 Concurrency:** Always use structured async/await with Sendable conformance.
3. **Apple HIG Design:** Follow Apple Human Interface Guidelines for typography, layout, sheets, and panels.
4. **Pull Requests:** Open a pull request against `main` using `.github/PULL_REQUEST_TEMPLATE.md`.
