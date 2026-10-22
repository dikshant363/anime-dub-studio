# Installation & Dependencies

This document provides complete instructions for installing Anime Dub Studio, configuring external dependencies, managing disk space, and resolving runtime prerequisites.

---

## 1. Installing from Official Binaries

Anime Dub Studio is distributed as a pre-compiled native Apple Silicon binary.

### Option A: Drag-and-Drop DMG Installer (Recommended)
1. Download `Anime Dub Studio.dmg` from [GitHub Releases](https://github.com/dikshant363/anime-dub-studio/releases).
2. Double-click the DMG to mount the disk image.
3. Drag the **Anime Dub Studio** icon into the `/Applications` shortcut.
4. Eject the disk image.

### Option B: Standalone ZIP Archive
1. Download `Anime-Dub-Studio-v2.1.1-macos-arm64.zip`.
2. Extract the archive:
   ```bash
   unzip Anime-Dub-Studio-v2.1.1-macos-arm64.zip -d /Applications/
   ```

---

## 2. Gatekeeper & Code Signing Verification

Releases are ad-hoc signed for Apple Silicon execution:
```bash
codesign -dv --verbose=4 "/Applications/Anime Dub Studio.app"
```

If macOS Gatekeeper prevents opening because the app is from an independent open-source developer:
1. Right-click (or Control-click) **Anime Dub Studio.app** in `/Applications` and select **Open**.
2. Click **Open** in the confirmation dialog.
3. Or clear the quarantine attribute via Terminal:
   ```bash
   xattr -cr "/Applications/Anime Dub Studio.app"
   ```

---

## 3. External Dependencies & Tools

Anime Dub Studio requires **FFmpeg** for lossless stream copying, Opus decoding, and audio mastering:

### Installing via Homebrew
```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install FFmpeg with essential multimedia codecs
brew install ffmpeg
```

### Verifying FFmpeg Installation
```bash
which ffmpeg ffprobe
# Expected output:
# /opt/homebrew/bin/ffmpeg
# /opt/homebrew/bin/ffprobe
```

---

## 4. Voice Packages & macOS System Voices

On-device voice synthesis utilizes native macOS Indian English and Hindi voices (`Rishi`, `Lekha`, `Aman`, `Tara`):

1. Open **System Settings**.
2. Navigate to **Accessibility > Spoken Content**.
3. Under **System Voice**, select **Manage Voices...**.
4. In the search box, type `English (India)` and `Hindi (India)`.
5. Click the download cloud icon next to:
   - `Rishi (Enhanced)`
   - `Lekha (Enhanced)`
   - `Aman (Enhanced)`
   - `Tara (Enhanced)`

These voices provide authentic cadence and pronunciation and run offline with zero internet connectivity.
