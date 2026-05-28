#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "=== Building Lyra in Release Configuration ==="
swift build -c release

echo "=== Creating Lyra.app Bundle ==="
APP_DIR="Lyra.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

# Recreate directories
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"

# Copy release binary
cp ".build/release/Lyra" "${MACOS_DIR}/Lyra"
chmod +x "${MACOS_DIR}/Lyra"

# Write Info.plist
cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Lyra</string>
    <key>CFBundleIdentifier</key>
    <string>com.daiski.lyra</string>
    <key>CFBundleName</key>
    <string>Lyra</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSUIElement</key>
    <string>1</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Lyra needs permission to control Spotify and Apple Music to display synchronized lyrics in your menu bar.</string>
</dict>
</plist>
EOF

echo "=== Lyra.app Packaged Successfully! ==="
echo "You can find your application at: $(pwd)/Lyra.app"
echo "To install, move it to your Applications folder:"
echo "  mv Lyra.app /Applications/"