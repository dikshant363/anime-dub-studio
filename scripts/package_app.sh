#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Anime Dub Studio"
APP_BUNDLE="${REPO_ROOT}/dist/${APP_NAME}.app"
APPLICATIONS_APP="/Applications/${APP_NAME}.app"

echo "=========================================================="
echo " Packaging ${APP_NAME} v1.0 Production macOS Bundle"
echo " Target Architecture: Apple Silicon (arm64)"
echo " Repo Root: ${REPO_ROOT}"
echo "=========================================================="

# 1. Build frontend
echo "--> [1/6] Building Next.js Frontend..."
cd "${REPO_ROOT}/frontend"
pnpm build

# 2. Build Rust release binary
echo "--> [2/6] Building Rust Release Binary..."
cd "${REPO_ROOT}/src-tauri"
cargo build --release

# 3. Assemble .app bundle in dist/
echo "--> [3/6] Assembling .app bundle structure in dist/..."
rm -rf "${REPO_ROOT}/dist"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
cp "${REPO_ROOT}/src-tauri/target/release/anime-dub-studio" "${APP_BUNDLE}/Contents/MacOS/"
chmod +x "${APP_BUNDLE}/Contents/MacOS/anime-dub-studio"

# Copy Info.plist
cat << 'EOF' > "${APP_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>English</string>
	<key>CFBundleDisplayName</key>
	<string>Anime Dub Studio</string>
	<key>CFBundleExecutable</key>
	<string>anime-dub-studio</string>
	<key>CFBundleIdentifier</key>
	<string>com.animedubstudio.desktop</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Anime Dub Studio</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0.0</string>
	<key>CFBundleVersion</key>
	<string>1.0.0</string>
	<key>CSResourcesFileMapped</key>
	<true/>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.entertainment</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>CFBundleIconFile</key>
	<string>icon.icns</string>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
EOF

# Copy app icon
if [ -f "${REPO_ROOT}/src-tauri/icons/icon.icns" ]; then
    cp "${REPO_ROOT}/src-tauri/icons/icon.icns" "${APP_BUNDLE}/Contents/Resources/"
fi

# Copy backend code
echo "--> [4/6] Bundling Python backend code & scripts..."
rsync -a --exclude="__pycache__" --exclude="*.pyc" "${REPO_ROOT}/backend" "${APP_BUNDLE}/Contents/Resources/"
rsync -a --exclude="__pycache__" --exclude="*.pyc" "${REPO_ROOT}/scripts" "${APP_BUNDLE}/Contents/Resources/"

# Copy Swift bridge
mkdir -p "${APP_BUNDLE}/Contents/Resources/swift"
if [ -f "${REPO_ROOT}/src-tauri/swift/AppleFoundationModelService" ]; then
    cp "${REPO_ROOT}/src-tauri/swift/AppleFoundationModelService" "${APP_BUNDLE}/Contents/Resources/swift/"
    chmod +x "${APP_BUNDLE}/Contents/Resources/swift/AppleFoundationModelService"
elif [ -f "${REPO_ROOT}/bin/apple_intelligence_bridge" ]; then
    cp "${REPO_ROOT}/bin/apple_intelligence_bridge" "${APP_BUNDLE}/Contents/Resources/swift/AppleFoundationModelService"
    chmod +x "${APP_BUNDLE}/Contents/Resources/swift/AppleFoundationModelService"
fi

# Bundle Python runtime
echo "--> [5/6] Bundling Python 3.12 Apple Silicon runtime..."
if [ -d "${REPO_ROOT}/.venv" ]; then
    rsync -a --delete --exclude="__pycache__" --exclude="*.pyc" --exclude="*.dist-info/RECORD" "${REPO_ROOT}/.venv/" "${APP_BUNDLE}/Contents/Resources/python/"
elif [ -d "${APPLICATIONS_APP}/Contents/Resources/python" ]; then
    rsync -a "${APPLICATIONS_APP}/Contents/Resources/python/" "${APP_BUNDLE}/Contents/Resources/python/"
fi

# 5. Install into /Applications
echo "--> [6/6] Installing into /Applications..."
rm -rf "${APPLICATIONS_APP}"
cp -R "${APP_BUNDLE}" "${APPLICATIONS_APP}"

echo "=========================================================="
echo " Bundle successfully built and installed:"
echo " ${APPLICATIONS_APP}"
echo "=========================================================="
