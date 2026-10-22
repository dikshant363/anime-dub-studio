# Release & Distribution

This document outlines the release engineering lifecycle, versioning policy, packaging automation, and distribution standards for Anime Dub Studio.

---

## 1. Versioning Strategy

Anime Dub Studio follows [Semantic Versioning (SemVer 2.0.0)](https://semver.org/):
* **MAJOR (`v3.0.0`):** Breaking architectural changes, file format shifts, or major redesigns.
* **MINOR (`v2.2.0`):** New functional capabilities, major studio tools, or new voice synthesis engines.
* **PATCH (`v2.1.1`):** Reliability enhancements, bug fixes, performance optimizations, and documentation updates.

---

## 2. Release Packaging Script

Releases are compiled and bundled using `scripts/package_native_app.sh`:

```bash
#!/usr/bin/env bash
# Compiles release binary with Swift 6
swift build -c release

# Assembles native .app bundle structure
# Generates Info.plist with version and privacy usage strings
# Ad-hoc code signs the bundle
codesign --force --deep --sign - "dist/Anime Dub Studio.app"

# Builds UDZO DMG installer with /Applications symlink
hdiutil create -volname "Anime Dub Studio" -srcfolder "dist/dmg_staging" -ov -format UDZO "dist/Anime Dub Studio.dmg"

# Generates ZIP archive and SHA-256 manifest
shasum -a 256 "Anime Dub Studio.dmg" > SHA256SUMS.txt
shasum -a 256 "Anime-Dub-Studio-v2.1.1-macos-arm64.zip" >> SHA256SUMS.txt
```

---

## 3. GitHub Release Publishing

When a release is finalized:
1. All automated tests must pass (`swift test`).
2. Release artifacts are verified with `codesign -dv --verbose=4` and `shasum -a 256`.
3. An annotated git tag is created and pushed to origin:
   ```bash
   git tag -a v2.1.1 -m "Release Anime Dub Studio v2.1.1"
   git push origin v2.1.1
   ```
4. A GitHub Release is created attaching the `.dmg`, `.zip`, and `SHA256SUMS.txt`:
   ```bash
   gh release create v2.1.1 "dist/Anime Dub Studio.dmg" "dist/Anime-Dub-Studio-v2.1.1-macos-arm64.zip" "dist/SHA256SUMS.txt" --title "..." --notes "..."
   ```

---

## 4. Current Release Verification (`v2.1.1`)

* **Release Tag:** `v2.1.1`
* **Release URL:** [https://github.com/dikshant363/anime-dub-studio/releases/tag/v2.1.1](https://github.com/dikshant363/anime-dub-studio/releases/tag/v2.1.1)
* **SHA-256 Manifest:**
  ```text
  c4ce97c7fa3f38d817c924d4e736db448c9be812ff8693629378dd5c9bc931ae  Anime Dub Studio.dmg
  e3022db9eacdae6d6873bfd78324dd8e2f14f39e9c4837fcdd01bc834bec4f74  Anime-Dub-Studio-v2.1.1-macos-arm64.zip
  ```
