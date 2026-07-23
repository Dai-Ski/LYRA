#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Find the repository root directory relative to the script location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

echo "=== Building Lyra in Release Configuration ==="
swift build -c release

echo "=== Creating Lyra.app Bundle ==="
APP_DIR="Lyra.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# Recreate directories
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy release binary
cp ".build/release/Lyra" "${MACOS_DIR}/Lyra"
chmod +x "${MACOS_DIR}/Lyra"

# Copy AppIcon resources if available
if [ -f "Assets/AppIcon.icns" ]; then
    cp "Assets/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi
if [ -f "Assets/AppIcon.png" ]; then
    cp "Assets/AppIcon.png" "${RESOURCES_DIR}/AppIcon.png"
fi

# Write Info.plist
cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Lyra</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.daiski.lyra</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Lyra</string>
    <key>CFBundleDisplayName</key>
    <string>Lyra</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <string>1</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Lyra needs permission to control Spotify and Apple Music to display synchronized lyrics in your menu bar.</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Dai-Ski. All rights reserved.</string>
</dict>
</plist>
EOF

echo "=== Clearing Extended Attributes & Ad-Hoc Code Signing ==="
xattr -cr "${APP_DIR}"
codesign --force --deep --options runtime --sign - "${APP_DIR}"

echo "=== Lyra.app Packaged & Code-Signed Successfully! ==="
echo "You can find your application at: ${ROOT_DIR}/Lyra.app"
echo "To install, move it to your Applications folder:"
echo "  mv Lyra.app /Applications/"
