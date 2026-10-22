#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Anime Dub Studio"
DIST_DIR="${REPO_ROOT}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
DMG_PATH="${DIST_DIR}/${APP_NAME}.dmg"
ZIP_PATH="${DIST_DIR}/Anime-Dub-Studio-v2.0.0-macos-arm64.zip"

echo "=========================================================="
echo " Packaging ${APP_NAME} Native Swift macOS Application"
echo " Platform: macOS Apple Silicon (arm64)"
echo " Repo Root: ${REPO_ROOT}"
echo "=========================================================="

# 1. Compile Release Binary with Swift 6
echo "--> [1/6] Building native Swift release binary..."
cd "${REPO_ROOT}"
swift build -c release

RELEASE_BIN="${REPO_ROOT}/.build/release/AnimeDubStudio"
if [ ! -f "${RELEASE_BIN}" ]; then
    echo "ERROR: Release binary not found at ${RELEASE_BIN}"
    exit 1
fi

# 2. Assemble .app Bundle Directory
echo "--> [2/6] Assembling native .app bundle structure..."
rm -rf "${DIST_DIR}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
cp "${RELEASE_BIN}" "${APP_BUNDLE}/Contents/MacOS/AnimeDubStudio"
chmod +x "${APP_BUNDLE}/Contents/MacOS/AnimeDubStudio"

# 3. Create Info.plist
echo "--> [3/6] Writing Info.plist and application metadata..."
cat << 'EOF' > "${APP_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>Anime Dub Studio</string>
	<key>CFBundleExecutable</key>
	<string>AnimeDubStudio</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon.icns</string>
	<key>CFBundleIdentifier</key>
	<string>com.animedubstudio.desktop</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Anime Dub Studio</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>2.0.0</string>
	<key>CFBundleVersion</key>
	<string>2.0.0</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.entertainment</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSMicrophoneUsageDescription</key>
	<string>Anime Dub Studio requires microphone and audio access to audition and record audio tracks.</string>
	<key>NSSpeechRecognitionUsageDescription</key>
	<string>Anime Dub Studio uses speech recognition to transcribe anime dialogue tracks.</string>
	<key>NSSupportsAutomaticGraphicsSwitching</key>
	<true/>
</dict>
</plist>
EOF

# Copy app icon
if [ -f "${REPO_ROOT}/Sources/AnimeDubStudio/Resources/AppIcon.icns" ]; then
    cp "${REPO_ROOT}/Sources/AnimeDubStudio/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc code sign the native app bundle
echo "--> [4/6] Ad-hoc code signing .app bundle..."
codesign --force --deep --sign - "${APP_BUNDLE}"

# 4. Generate Drag-and-Drop DMG Installer
echo "--> [5/6] Building release DMG installer with /Applications symlink..."
DMG_STAGING="${DIST_DIR}/dmg_staging"
rm -rf "${DMG_STAGING}"
mkdir -p "${DMG_STAGING}"
cp -R "${APP_BUNDLE}" "${DMG_STAGING}/"
ln -s /Applications "${DMG_STAGING}/Applications"

hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_STAGING}" -ov -format UDZO "${DMG_PATH}"
rm -rf "${DMG_STAGING}"

# 5. Generate Distributable ZIP & Checksums
echo "--> [6/6] Generating ZIP archive and SHA-256 checksums..."
cd "${DIST_DIR}"
zip -q -r "${ZIP_PATH}" "${APP_NAME}.app"
shasum -a 256 "${APP_NAME}.dmg" > SHA256SUMS.txt
shasum -a 256 "$(basename "${ZIP_PATH}")" >> SHA256SUMS.txt

echo "=========================================================="
echo " Native Release Artifacts successfully generated:"
echo " • .app Bundle:    ${APP_BUNDLE} ($(du -sh "${APP_BUNDLE}" | cut -f1))"
echo " • DMG Installer:  ${DMG_PATH} ($(du -sh "${DMG_PATH}" | cut -f1))"
echo " • ZIP Archive:    ${ZIP_PATH} ($(du -sh "${ZIP_PATH}" | cut -f1))"
echo " • Checksums:      ${DIST_DIR}/SHA256SUMS.txt"
echo "=========================================================="
